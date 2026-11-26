class_name ControlPage
extends Control

signal back_requested

const TITLE_FONT: Font = preload("res://fonts/AmaticSC-Bold.ttf")
const KEY_FONT: Font = preload("res://fonts/SpecialElite-Regular.ttf")
const TEXT_COLOR := Color("e8e2d4")
const MUTED_COLOR := Color("adb0b5")

@onready var _title: Label = $Title
@onready var _title_rule: ColorRect = $TitleRule
@onready var _scroll: ScrollContainer = $CardsScroll
@onready var _grid: GridContainer = $CardsScroll/Cards

var _cards: Array[PanelContainer] = []
var _action_labels: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_cards()
	resized.connect(_apply_layout)
	_apply_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _build_cards() -> void:
	var mappings := [
		{"keys": ["W", "A", "S", "D"], "action": "MOVE"},
		{"keys": ["E"], "action": "INTERACT"},
		{"keys": ["F"], "action": "PUSH / PULL"},
		{"keys": ["T"], "action": "SHIFTING"},
		{"keys": ["SPACE"], "action": "JUMP"},
		{"keys": ["SHIFT"], "action": "RUN"},
		{"keys": ["CTRL"], "action": "CROUCH"},
	]
	for mapping in mappings:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_card_style())
		card.custom_minimum_size.y = 84.0
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(row)

		var key_group := HBoxContainer.new()
		key_group.add_theme_constant_override("separation", 5)
		key_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key_group)
		for key_name in mapping["keys"]:
			var key_cap := PanelContainer.new()
			key_cap.custom_minimum_size = Vector2(maxf(42.0, key_name.length() * 13.0 + 18.0), 42.0)
			key_cap.add_theme_stylebox_override("panel", _make_key_style())
			key_group.add_child(key_cap)

			var key_label := Label.new()
			key_label.text = key_name
			key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			key_label.add_theme_color_override("font_color", TEXT_COLOR)
			key_label.add_theme_font_override("font", KEY_FONT)
			key_label.add_theme_font_size_override("font_size", 18)
			key_cap.add_child(key_label)

		var action_label := Label.new()
		action_label.text = mapping["action"]
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.add_theme_color_override("font_color", MUTED_COLOR)
		action_label.add_theme_font_override("font", TITLE_FONT)
		action_label.add_theme_font_size_override("font_size", 30)
		row.add_child(action_label)
		_cards.append(card)
		_action_labels.append(action_label)
		_grid.add_child(card)


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.043, 0.058, 0.96)
	style.border_color = Color(0.65, 0.68, 0.72, 0.20)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	return style


func _make_key_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.12, 1.0)
	style.border_color = Color(0.72, 0.73, 0.74, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	return style


func _apply_layout() -> void:
	var viewport_size := size
	if viewport_size.x < 4.0 or viewport_size.y < 4.0:
		return
	var width := viewport_size.x
	var height := viewport_size.y
	var narrow := width < 850.0 or width / height < 1.25
	var side_margin := maxf(width * 0.07, 22.0)
	var title_size := int(clampf(width * (0.10 if narrow else 0.075), 48.0, 96.0))
	var columns := 1 if narrow else 2
	var gap := 18.0
	var content_width := minf(width - side_margin * 2.0, 1120.0)
	var content_x := (width - content_width) * 0.5
	var card_width := content_width if columns == 1 else (content_width - gap) * 0.5
	var card_height := clampf(height * 0.13, 78.0, 96.0)

	_title.position = Vector2(side_margin, height * 0.045)
	_title.size = Vector2(content_width, title_size * 1.45)
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", title_size)
	_title_rule.size = Vector2(52.0, 2.0)
	_title_rule.position = Vector2((width - 52.0) * 0.5, height * 0.045 + title_size * 1.48)
	var menu_top := maxf(height * 0.26, _title_rule.position.y + 54.0)
	_scroll.position = Vector2(content_x, menu_top)
	_scroll.size = Vector2(content_width, maxf(120.0, height - menu_top - height * 0.06))
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", int(gap))
	_grid.add_theme_constant_override("v_separation", 14)
	for card in _cards:
		card.custom_minimum_size = Vector2(card_width, card_height)
	for action_label in _action_labels:
		action_label.add_theme_font_size_override("font_size", int(clampf(width * 0.030, 24.0, 34.0)))
