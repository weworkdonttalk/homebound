class_name CreditsPage
extends Control

signal back_requested

const TITLE_FONT: Font = preload("res://fonts/AmaticSC-Bold.ttf")
const BODY_FONT: Font = preload("res://fonts/SpecialElite-Regular.ttf")
const TITLE_COLOR := Color("e8e8e8")
const ROLE_COLOR := Color("aeb1b5")
const NAME_COLOR := Color("f0f0f0")

@onready var _scroll: ScrollContainer = $CreditsScroll
@onready var _credits_list: VBoxContainer = $CreditsScroll/CreditsList


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_credits()
	_credits_list.alignment = BoxContainer.ALIGNMENT_CENTER
	resized.connect(_apply_layout)
	_apply_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _build_credits() -> void:
	var title := Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	_credits_list.add_child(title)

	var credits := [
		{"role": "UI DESIGN", "names": ["I Nyoman Aditya Dharmaputra"]},
		{"role": "3D ASSET", "names": ["I Ketut Sutha Negara"]},
		{"role": "GAME DESIGN", "names": ["Alif Javas Kayana"]},
		{"role": "PROGRAMMER", "names": ["Putu Semara Dananjaya", "Rangga Pradita"]},
	]
	for entry in credits:
		var section := VBoxContainer.new()
		section.alignment = BoxContainer.ALIGNMENT_CENTER
		section.add_theme_constant_override("separation", 2)
		_credits_list.add_child(section)

		var role := Label.new()
		role.text = entry["role"]
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.add_theme_font_override("font", TITLE_FONT)
		role.add_theme_font_size_override("font_size", 28)
		role.add_theme_color_override("font_color", ROLE_COLOR)
		section.add_child(role)

		for person in entry["names"]:
			var name := Label.new()
			name.text = person
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name.add_theme_font_override("font", BODY_FONT)
			name.add_theme_font_size_override("font_size", 21)
			name.add_theme_color_override("font_color", NAME_COLOR)
			section.add_child(name)


func _apply_layout() -> void:
	var viewport_size := size
	if viewport_size.x < 4.0 or viewport_size.y < 4.0:
		return
	var width := viewport_size.x
	var height := viewport_size.y
	var narrow := width < 700.0 or width / height < 1.0
	var content_width := minf(width * 0.82, 760.0)
	var content_x := (width - content_width) * 0.5
	var title_size := int(clampf(width * (0.13 if narrow else 0.09), 48.0, 82.0))
	var role_size := int(clampf(width * 0.038, 22.0, 30.0))
	var name_size := int(clampf(width * 0.026, 17.0, 23.0))

	_scroll.position = Vector2(content_x, height * 0.06)
	_scroll.size = Vector2(content_width, height * 0.88)
	_credits_list.custom_minimum_size.x = content_width
	_credits_list.add_theme_constant_override("separation", int(clampf(height * 0.028, 14.0, 26.0)))
	for index in _credits_list.get_child_count():
		var child := _credits_list.get_child(index)
		if child is Label:
			child.add_theme_font_size_override("font_size", title_size)
		else:
			for section_child in child.get_children():
				if section_child is Label and section_child == child.get_child(0):
					section_child.add_theme_font_size_override("font_size", role_size)
				else:
					section_child.add_theme_font_size_override("font_size", name_size)
