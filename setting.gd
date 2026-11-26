class_name SettingPage
extends Control

signal close_requested
signal brightness_changed(value: float)

const DARK_BACKGROUND := Color(0.012, 0.016, 0.028)
const LIGHT_BACKGROUND := Color(0.105, 0.12, 0.15)
const CONTROL_PAGE_SCENE: PackedScene = preload("res://control.tscn")
const CREDITS_PAGE_SCENE: PackedScene = preload("res://credits.tscn")

@onready var _background: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _title_rule: ColorRect = $TitleRule
@onready var _menu: VBoxContainer = $ButtonList
@onready var _buttons: Array[StoryMenuButton] = [
	$ButtonList/Controls,
	$ButtonList/Brightness,
	$ButtonList/Credits,
]
@onready var _brightness_panel: Panel = $BrightnessPanel
@onready var _brightness_slider: HSlider = $BrightnessPanel/BrightnessSlider

var _controls_page: Control
var _credits_page: Control
var _subpage_transitioning := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_layout)
	var labels := ["CONTROLS", "BRIGHNESS", "CREDITS"]
	for index in _buttons.size():
		_buttons[index].configure(labels[index])
		_buttons[index].pressed.connect(_on_option_pressed.bind(index))
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	_apply_layout()
	_on_brightness_changed(_brightness_slider.value)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _on_option_pressed(index: int) -> void:
	_set_active_option(index)
	if index == 0:
		_open_controls_page()
	elif index == 2:
		_open_credits_page()


func _open_controls_page() -> void:
	if is_instance_valid(_controls_page) or _subpage_transitioning:
		return
	_controls_page = CONTROL_PAGE_SCENE.instantiate() as Control
	_controls_page.modulate.a = 0.0
	_controls_page.connect("back_requested", _on_controls_back_requested)
	add_child(_controls_page)
	_controls_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subpage_transitioning = true
	var tween := create_tween()
	tween.tween_property(_controls_page, "modulate:a", 1.0, 0.24) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _subpage_transitioning = false)


func _on_controls_back_requested() -> void:
	if not is_instance_valid(_controls_page) or _subpage_transitioning:
		return
	_subpage_transitioning = true
	var page := _controls_page
	var tween := create_tween()
	tween.tween_property(page, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		page.queue_free()
		_controls_page = null
		_subpage_transitioning = false
	)


func _open_credits_page() -> void:
	if is_instance_valid(_credits_page) or _subpage_transitioning:
		return
	_credits_page = CREDITS_PAGE_SCENE.instantiate() as Control
	_credits_page.modulate.a = 0.0
	_credits_page.connect("back_requested", _on_credits_back_requested)
	add_child(_credits_page)
	_credits_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subpage_transitioning = true
	var tween := create_tween()
	tween.tween_property(_credits_page, "modulate:a", 1.0, 0.24) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _subpage_transitioning = false)


func _on_credits_back_requested() -> void:
	if not is_instance_valid(_credits_page) or _subpage_transitioning:
		return
	_subpage_transitioning = true
	var page := _credits_page
	var tween := create_tween()
	tween.tween_property(page, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		page.queue_free()
		_credits_page = null
		_subpage_transitioning = false
	)


func _set_active_option(index: int) -> void:
	_brightness_panel.visible = index == 1


func set_brightness_value(value: float) -> void:
	_brightness_slider.value = clampf(value, _brightness_slider.min_value, _brightness_slider.max_value)
	_on_brightness_changed(_brightness_slider.value)


func _on_brightness_changed(value: float) -> void:
	_background.color = DARK_BACKGROUND.lerp(LIGHT_BACKGROUND, value)
	brightness_changed.emit(value)


func _apply_layout() -> void:
	var viewport_size := size
	if viewport_size.x < 4.0 or viewport_size.y < 4.0:
		return

	var width := viewport_size.x
	var height := viewport_size.y
	var narrow := width < 900.0 or width / height < 1.30
	var left_x := maxf(width * 0.08, 24.0)
	var left_width := width * (0.46 if narrow else 0.40)
	var right_x := width * (0.58 if narrow else 0.57)
	var right_width := maxf(width * (0.34 if narrow else 0.32), 100.0)
	var title_size := int(clampf(width * (0.10 if narrow else 0.070), 42.0, 100.0))
	var menu_size := int(clampf(width * (0.045 if narrow else 0.023), 18.0, 32.0))
	var row_height := clampf(height * 0.085, 44.0, 58.0)

	_title.position = Vector2(left_x, height * 0.20)
	_title.size = Vector2(left_width, title_size * 1.4)
	_title.add_theme_font_size_override("font_size", title_size)
	_title_rule.position = Vector2(left_x, height * 0.20 + title_size * 1.42)
	_title_rule.size = Vector2(48.0, 2.0)
	_menu.position = Vector2(left_x, height * 0.39)
	_menu.size = Vector2(left_width, row_height * 3.0 + 28.0)
	_menu.add_theme_constant_override("separation", 10)
	for button in _buttons:
		button.set_metrics(menu_size, row_height)

	_brightness_panel.position = Vector2(right_x, height * 0.50 - 24.0)
	_brightness_panel.size = Vector2(right_width, 48.0)
	_brightness_slider.position = Vector2(12.0, 4.0)
	_brightness_slider.size = Vector2(right_width - 24.0, 40.0)
