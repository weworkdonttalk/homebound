class_name MainMenuUI
extends Control

## Modern horror main menu.
##
## Layout: animated 3D scene on the left, a cold gradient scrim on the right
## with the title and menu sitting directly on it. Interactions are
## intentionally safe: New Game / Load / Settings show a toast until
## their screens exist, Quit asks for confirmation.

signal new_game_requested
signal load_game_requested
signal settings_requested
signal quit_confirmed

@onready var _scrim: TextureRect = %Scrim
@onready var _menu_root: Control = %MenuRoot
@onready var _title: Label = %Title
@onready var _title_rule: ColorRect = %TitleRule
@onready var _rule_gap: Control = %RuleGap
@onready var _menu_gap: Control = %MenuGap
@onready var _menu: VBoxContainer = %Menu
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _quit_modal: Control = %QuitModal
@onready var _dim: ColorRect = %Dim
@onready var _dialog: PanelContainer = %Dialog
@onready var _dialog_title: Label = %DialogTitle
@onready var _stay_button: Button = %StayButton
@onready var _leave_button: Button = %LeaveButton

var _buttons: Array[StoryMenuButton] = []
var _toast_tween: Tween
var _block_width: float = 420.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buttons.assign([
		%NewGame,
		%LoadGame,
		%Settings,
		%Quit,	
	])

	_configure_buttons()
	_connect_signals()

	_quit_modal.hide()
	_toast.hide()
	_stay_button.focus_mode = Control.FOCUS_NONE
	_leave_button.focus_mode = Control.FOCUS_NONE
	_dialog.resized.connect(func() -> void: _dialog.pivot_offset = _dialog.size * 0.5)

	resized.connect(_apply_layout)
	_apply_layout()
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _quit_modal.visible:
			_close_quit_modal()
		else:
			_open_quit_modal()
		get_viewport().set_input_as_handled()


func _configure_buttons() -> void:
	var labels := ["NEW GAME", "CONTINUE", "SETTINGS", "QUIT"]
	for index in _buttons.size():
		_buttons[index].configure(labels[index])


func _connect_signals() -> void:
	%NewGame.pressed.connect(_on_new_game_pressed)
	%LoadGame.pressed.connect(_on_load_game_pressed)
	%Settings.pressed.connect(_on_settings_pressed)
	%Quit.pressed.connect(_open_quit_modal)
	_stay_button.pressed.connect(_close_quit_modal)
	_leave_button.pressed.connect(_on_quit_confirmed)
	_dim.gui_input.connect(_on_dim_input)


func _apply_layout() -> void:
	var viewport_size := size
	if viewport_size.x < 4.0 or viewport_size.y < 4.0:
		return

	var narrow := viewport_size.x < 900.0 or viewport_size.x / viewport_size.y < 1.30
	var compact := viewport_size.y < 760.0
	var vw := viewport_size.x

	var block_width: float
	if narrow:
		block_width = clampf(vw * 0.92, 320.0, 640.0)
	else:
		block_width = clampf(vw * 0.26, 340.0, 540.0)
	_block_width = block_width

	var title_size: float
	var menu_size: int
	var row_height: float
	var row_gap: float
	if narrow:
		title_size = clampf(block_width * 0.30, 136.0, 320.0)
		menu_size = int(clampf(block_width * 0.055, 26.0, 36.0))
		row_height = clampf(block_width * 0.085, 48.0, 60.0)
		row_gap = 12.0
	else:
		title_size = clampf(vw * 0.075, 80.0, 160.0)
		menu_size = int(clampf(vw * 0.018, 24.0, 34.0))
		row_height = clampf(vw * 0.028, 44.0, 56.0)
		row_gap = 10.0
	if compact:
		title_size = minf(title_size, 128.0)
		row_height = minf(row_height, 46.0)

	var title_gap := 10.0
	var rule_gap := 24.0
	var menu_gap := 20.0 if compact else 30.0

	# Estimate the block height so it can be centered without waiting a frame
	# for the VBox to sort itself out.
	var estimate := title_gap + title_size * 1.28 + rule_gap + menu_gap \
		+ row_height * 4.0 + row_gap * 3.0

	var block_position: Vector2
	if narrow:
		block_position = Vector2(
			maxf(vw * 0.05, 22.0),
			clampf(viewport_size.y * 0.52, 24.0, _max_block_y(viewport_size.y, estimate))
		)
	else:
		var right_margin := maxf(vw * 0.07, 52.0)
		block_position = Vector2(
			vw - right_margin - block_width,
			clampf((viewport_size.y - estimate) * 0.5, 24.0, _max_block_y(viewport_size.y, estimate))
		)

	_set_block_rect(block_position, Vector2(block_width, estimate))

	_title.add_theme_font_size_override("font_size", int(round(title_size)))
	_rule_gap.custom_minimum_size.y = title_gap
	_menu_gap.custom_minimum_size.y = menu_gap
	_menu.add_theme_constant_override("separation", int(round(row_gap)))

	for button in _buttons:
		button.set_metrics(menu_size, row_height)

	# The scrim follows the menu: sideways in landscape, upward in portrait.
	var scrim := _scrim.texture as GradientTexture2D
	if scrim != null:
		if narrow:
			scrim.fill_from = Vector2(0.0, 0.0)
			scrim.fill_to = Vector2(0.0, 1.0)
		else:
			scrim.fill_from = Vector2(0.0, 0.0)
			scrim.fill_to = Vector2(1.0, 0.0)

	_toast_label.custom_minimum_size.x = minf(block_width - 56.0, 300.0)
	_dialog.custom_minimum_size.x = clampf(block_width * 0.95, 318.0, 460.0)
	_dialog_title.add_theme_font_size_override(
		"font_size", int(clampf(vw * 0.020, 26.0, 36.0))
	)
	if _toast.visible:
		_position_toast.call_deferred()


func _max_block_y(viewport_height: float, estimate: float) -> float:
	return maxf(24.0, viewport_height - estimate - 64.0)


func _set_block_rect(target_position: Vector2, target_size: Vector2) -> void:
	_menu_root.anchor_left = 0.0
	_menu_root.anchor_top = 0.0
	_menu_root.anchor_right = 0.0
	_menu_root.anchor_bottom = 0.0
	_menu_root.offset_left = target_position.x
	_menu_root.offset_top = target_position.y
	_menu_root.offset_right = target_position.x + target_size.x
	_menu_root.offset_bottom = target_position.y + target_size.y


func _play_intro() -> void:
	_scrim.modulate.a = 0.0
	var final_position := _menu_root.position
	_menu_root.modulate.a = 0.0
	_menu_root.position = final_position + Vector2(28.0, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_scrim, "modulate:a", 1.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_root, "modulate:a", 1.0, 0.6) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_root, "position", final_position, 0.7) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	_title.modulate.a = 0.0
	tween.tween_property(_title, "modulate:a", 1.0, 0.5) \
		.set_delay(0.16) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	_title_rule.modulate.a = 0.0
	tween.tween_property(_title_rule, "modulate:a", 1.0, 0.4) \
		.set_delay(0.32) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	for index in _buttons.size():
		_buttons[index].play_intro(0.38 + index * 0.07)


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_load_game_pressed() -> void:
	load_game_requested.emit()
	_show_toast("No saved letters were found.")


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _open_quit_modal() -> void:
	if _quit_modal.visible:
		return
	_quit_modal.show()
	_quit_modal.modulate.a = 0.0
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.96, 0.96)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_quit_modal, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _close_quit_modal() -> void:
	if not _quit_modal.visible:
		return
	var tween := create_tween()
	tween.tween_property(_quit_modal, "modulate:a", 0.0, 0.16) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_quit_modal.hide()
	)


func _on_quit_confirmed() -> void:
	quit_confirmed.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		_close_quit_modal()


func _show_toast(message: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = message
	_toast.show()
	_toast.modulate.a = 0.0
	_position_toast.call_deferred()

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.16) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.1)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(_toast.hide)


func _position_toast() -> void:
	if not _toast.visible:
		return
	_toast.reset_size()
	var narrow := size.x < 900.0 or size.x / size.y < 1.30
	if narrow:
		_toast.position = Vector2(
			(size.x - _toast.size.x) * 0.5,
			maxf(18.0, size.y * 0.03)
		)
	else:
		var side_margin := maxf(size.x * 0.06, 22.0)
		var bottom_margin := maxf(size.y * 0.075, 18.0)
		_toast.position = Vector2(
			side_margin,
			size.y - bottom_margin - _toast.size.y
		)
