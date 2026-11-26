class_name PauseMenu
extends CanvasLayer

## Add this scene while gameplay is running. It pauses the game immediately,
## and unpauses it when the player resumes or returns to the main menu.

const SETTING_PAGE_SCENE: PackedScene = preload("res://setting.tscn")

@onready var _menu_root: Control = $UI/MenuRoot
@onready var _title: Label = $UI/MenuRoot/Stack/Title
@onready var _rule_gap: Control = $UI/MenuRoot/Stack/RuleGap
@onready var _menu_gap: Control = $UI/MenuRoot/Stack/MenuGap
@onready var _menu: VBoxContainer = $UI/MenuRoot/Stack/Menu
@onready var _continue_button: StoryMenuButton = $UI/MenuRoot/Stack/Menu/Continue
@onready var _settings_button: StoryMenuButton = $UI/MenuRoot/Stack/Menu/Settings
@onready var _exit_button: StoryMenuButton = $UI/MenuRoot/Stack/Menu/ExitToMenu
@onready var _hint: Label = $UI/MenuRoot/Stack/Hint

var _settings_page: Control
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_continue_button.configure("CONTINUE")
	_settings_button.configure("SETTINGS")
	_exit_button.configure("EXIT TO MENU")
	_continue_button.pressed.connect(_resume_game)
	_settings_button.pressed.connect(_open_settings)
	_exit_button.pressed.connect(_exit_to_menu)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if is_instance_valid(_settings_page):
			return
		_resume_game()
		get_viewport().set_input_as_handled()


func _open_settings() -> void:
	if is_instance_valid(_settings_page):
		return
	_menu_root.hide()
	_settings_page = SETTING_PAGE_SCENE.instantiate() as Control
	_settings_page.connect("close_requested", _close_settings)
	if has_node("/root/UIManager"):
		var ui_mgr := get_node("/root/UIManager")
		_settings_page.connect("brightness_changed", ui_mgr.set_brightness)
	add_child(_settings_page)
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if has_node("/root/UIManager"):
		_settings_page.call("set_brightness_value", get_node("/root/UIManager").brightness_value)


func _close_settings() -> void:
	if not is_instance_valid(_settings_page):
		return
	_settings_page.queue_free()
	_settings_page = null
	_menu_root.show()


func _resume_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	queue_free()


func _exit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_free()
	get_tree().call_deferred("change_scene_to_file", "res://main_menu.tscn")


func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 4.0 or viewport_size.y < 4.0:
		return
	var width := viewport_size.x
	var height := viewport_size.y
	var narrow := width < 850.0 or width / height < 1.25
	var block_width := minf(width * (0.86 if narrow else 0.40), 560.0)
	var title_size := int(clampf(width * (0.105 if narrow else 0.080), 64.0, 112.0))
	var menu_size := int(clampf(width * (0.035 if narrow else 0.022), 22.0, 32.0))
	var row_height := clampf(height * 0.075, 50.0, 64.0)
	var gap := 12.0
	var title_gap := 8.0
	var rule_gap := 22.0
	var menu_gap := 24.0
	var hint_gap := 18.0
	var hint_height := 28.0
	var content_height := title_gap + title_size * 1.36 + rule_gap + menu_gap \
		+ row_height * 3.0 + gap * 2.0 + hint_gap + hint_height
	var block_position := Vector2((width - block_width) * 0.5, (height - content_height) * 0.5)
	_menu_root.position = block_position
	_menu_root.size = Vector2(block_width, content_height)
	_title.add_theme_font_size_override("font_size", title_size)
	_rule_gap.custom_minimum_size.y = title_gap
	_menu_gap.custom_minimum_size.y = menu_gap
	$UI/MenuRoot/Stack/HintGap.custom_minimum_size.y = hint_gap
	_menu.add_theme_constant_override("separation", int(gap))
	_hint.add_theme_font_size_override("font_size", int(clampf(width * 0.014, 14.0, 18.0)))
	for button in [_continue_button, _settings_button, _exit_button]:
		button.set_metrics(menu_size, row_height)
