class_name QuestGuide
extends CanvasLayer

## In-game journal overlay. Add this scene to a gameplay scene; it opens and
## closes with Tab and leaves gameplay running underneath.

const HEADING_FONT: Font = preload("res://fonts/AmaticSC-Bold.ttf")
const BODY_FONT: Font = preload("res://fonts/SpecialElite-Regular.ttf")
const TORN_PAPER_SCRIPT: Script = preload("res://ui/torn_paper.gd")
const PAPER := Color("d8d0bd")
const MUTED := Color("898779")
const ACCENT := Color("a12c2c")
const OBJECTIVE_HINT_DURATION := 9.5

var _quests: Array[Dictionary] = [
	{
		"title": "Jalan Pulang",
		"chapter": "BAB I  /  RUMAH MASA KECIL",
		"description": "Temukan jalan keluar dari ruangan ingatan yang terkunci. Gunakan tombol [T] untuk berpindah dimensi dan susun kembali kenangan yang terpecah.",
		"objectives": [
			{"text": "Kumpulkan 3 kotak mainan ke slot ABCD", "complete": false, "progress": "0/3"},
			{"text": "Bawa Teddy Bear ke pressure plate", "complete": false, "progress": ""},
			{"text": "Naiki tangga putih menuju puncak", "complete": false, "progress": "0/19"},
			{"text": "Masuk ke dalam portal pintu", "complete": false, "progress": ""},
		],
	},
	{
		"title": "Balik Pintu",
		"chapter": "BAB II  /  RUANG BARU",
		"description": "Langkahmu menembus cahaya portal membawamu ke ruangan asing. Jelajahi setiap sudut dan temukan petunjuk berikutnya.",
		"objectives": [
			{"text": "Jelajahi ruangan Chapter 2", "complete": false, "progress": ""},
		],
	},
]

var _selected_quest := 0
var _overlay: Control
var _darkness: ColorRect
var _book: PanelContainer
var _page_title: Label
var _chapter_label: Label
var _footer: Label
var _hud_hint: Control
var _objective_hint: Control
var _objective_hint_text: Label
var _objective_hint_progress: Label
var _quest_list: VBoxContainer
var _details: VBoxContainer
var _quest_buttons: Array[Button] = []
var _tab_input_enabled := true
var _journal_open := false
var _transition_tween: Tween
var _hint_tween: Tween
var _transition_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_journal()
	_build_objective_hint()
	_build_hud_hint()
	_overlay.visible = false
	_show_objective_hint()


func _input(event: InputEvent) -> void:
	if not _tab_input_enabled:
		return
	var toggle_pressed := event.is_action_pressed("quest_guide")
	if not toggle_pressed and event is InputEventKey and event.pressed and not event.echo:
		toggle_pressed = event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_J
	if toggle_pressed:
		if _journal_open:
			_close_journal(true)
		else:
			_hide_objective_hint()
			_open_journal()
		get_viewport().set_input_as_handled()


func is_journal_open() -> bool:
	return _journal_open


func close_guide() -> void:
	_close_journal()


func set_tab_input_enabled(enabled: bool) -> void:
	_tab_input_enabled = enabled
	if is_instance_valid(_hud_hint):
		_hud_hint.visible = enabled and not _journal_open
	if not enabled:
		_close_journal()


func select_quest(index: int, show_hint: bool = false) -> void:
	_select_quest(index)
	if show_hint:
		_show_objective_hint()


func show_objective_toast() -> void:
	_show_objective_hint()


func _open_journal() -> void:
	_transition_serial += 1
	var serial := _transition_serial
	_journal_open = true
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	if not _overlay.visible:
		_overlay.modulate.a = 0.0
	_book.scale = Vector2.ONE
	_book.rotation = 0.0
	_darkness.modulate.a = 1.0
	_page_title.modulate.a = 1.0
	_footer.modulate.a = 1.0
	_overlay.show()
	if is_instance_valid(_hud_hint):
		_hud_hint.hide()
	if not _journal_open or serial != _transition_serial:
		return
	_transition_tween = create_tween()
	_transition_tween.tween_property(_overlay, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close_journal(show_objective_hint: bool = false) -> void:
	if not _journal_open and not _overlay.visible:
		return
	_transition_serial += 1
	var serial := _transition_serial
	_journal_open = false
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	if not _overlay.visible:
		return
	_transition_tween = create_tween()
	_transition_tween.tween_property(_overlay, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.finished.connect(
		_on_close_animation_finished.bind(serial, show_objective_hint),
		CONNECT_ONE_SHOT
	)


func _on_close_animation_finished(serial: int, show_objective_hint: bool) -> void:
	if not _journal_open and serial == _transition_serial:
		_overlay.hide()
		_overlay.modulate.a = 1.0
		if is_instance_valid(_hud_hint):
			_hud_hint.visible = _tab_input_enabled
		if show_objective_hint:
			_show_objective_hint()


## Connect quest progress from the gameplay systems through these methods.
func set_objective_completed(quest_index: int, objective_index: int, completed: bool) -> void:
	if quest_index < 0 or quest_index >= _quests.size():
		return
	var objectives: Array = _quests[quest_index]["objectives"]
	if objective_index < 0 or objective_index >= objectives.size():
		return
	objectives[objective_index]["complete"] = completed
	_quests[quest_index]["objectives"] = objectives
	if quest_index == _selected_quest:
		_render_details()
		_refresh_objective_hint()


func set_objective_progress(quest_index: int, objective_index: int, progress: String) -> void:
	if quest_index < 0 or quest_index >= _quests.size():
		return
	var objectives: Array = _quests[quest_index]["objectives"]
	if objective_index < 0 or objective_index >= objectives.size():
		return
	objectives[objective_index]["progress"] = progress
	_quests[quest_index]["objectives"] = objectives
	if quest_index == _selected_quest:
		_render_details()
		_refresh_objective_hint()


func _build_journal() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_darkness = ColorRect.new()
	_darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_darkness.color = Color(0.008, 0.009, 0.009, 0.94)
	_darkness.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_darkness)

	_page_title = _label("JURNAL", HEADING_FONT, 44, PAPER)
	_page_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_page_title.offset_left = 30.0
	_page_title.offset_top = 24.0
	_page_title.offset_right = -30.0
	_page_title.offset_bottom = 82.0
	_page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_page_title)

	_book = PanelContainer.new()
	_book.anchor_left = 0.06
	_book.anchor_top = 0.135
	_book.anchor_right = 0.94
	_book.anchor_bottom = 0.88
	_book.add_theme_stylebox_override("panel", _page_style(Color("171613"), Color("4b4034"), 3, 2))
	_overlay.add_child(_book)

	var book_margin := MarginContainer.new()
	book_margin.add_theme_constant_override("margin_left", 8)
	book_margin.add_theme_constant_override("margin_top", 8)
	book_margin.add_theme_constant_override("margin_right", 8)
	book_margin.add_theme_constant_override("margin_bottom", 8)
	_book.add_child(book_margin)

	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	book_margin.add_child(spread)

	var left_page := _make_page(spread, 0.9)
	_build_quest_list(left_page)

	var spine := ColorRect.new()
	spine.custom_minimum_size.x = 4.0
	spine.color = Color("090909")
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spread.add_child(spine)

	var right_page := _make_page(spread, 1.1)
	_build_details_page(right_page)

	_footer = _label("TAB / J  KEMBALI", BODY_FONT, 13, MUTED)
	_footer.anchor_left = 0.70
	_footer.anchor_top = 0.90
	_footer.anchor_right = 0.94
	_footer.anchor_bottom = 0.96
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overlay.add_child(_footer)


func _build_hud_hint() -> void:
	_hud_hint = Control.new()
	_hud_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_hint)

	var hint_panel := PanelContainer.new()
	hint_panel.anchor_left = 0.64
	hint_panel.anchor_top = 0.92
	hint_panel.anchor_right = 0.96
	hint_panel.anchor_bottom = 0.985
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.016, 0.028, 0.78)
	panel_style.border_color = Color(0.631373, 0.172549, 0.172549, 0.50)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(2)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_top = 5.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_bottom = 5.0
	hint_panel.add_theme_stylebox_override("panel", panel_style)
	_hud_hint.add_child(hint_panel)

	var hint := Label.new()
	hint.text = "ESC  PAUSE   /   TAB · J  QUEST GUIDE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", BODY_FONT)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("e8e2d4", 0.80))
	hint_panel.add_child(hint)


func _build_objective_hint() -> void:
	_objective_hint = Control.new()
	_objective_hint.anchor_left = 0.69
	_objective_hint.anchor_top = 0.045
	_objective_hint.anchor_right = 0.96
	_objective_hint.anchor_bottom = 0.205
	_objective_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_hint)

	var paper := Control.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.set_script(TORN_PAPER_SCRIPT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_hint.add_child(paper)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16.0
	content.offset_top = 12.0
	content.offset_right = -16.0
	content.offset_bottom = -12.0
	content.add_theme_constant_override("separation", 1)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_hint.add_child(content)
	var heading := _label("OBJECTIVE", HEADING_FONT, 24, ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(heading)
	_objective_hint_text = _label("", BODY_FONT, 14, PAPER)
	_objective_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_hint_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_hint_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_objective_hint_text)
	_objective_hint_progress = _label("", BODY_FONT, 12, MUTED)
	_objective_hint_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_hint_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_objective_hint_progress)


func _show_objective_hint() -> void:
	if not is_instance_valid(_objective_hint) or _journal_open:
		return
	_refresh_objective_hint()
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_objective_hint.show()
	_objective_hint.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_objective_hint, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hint_tween.tween_interval(OBJECTIVE_HINT_DURATION)
	_hint_tween.tween_property(_objective_hint, "modulate:a", 0.0, 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_hint_tween.tween_callback(_objective_hint.hide)


func _hide_objective_hint() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	if is_instance_valid(_objective_hint):
		_objective_hint.hide()


func _refresh_objective_hint() -> void:
	if not is_instance_valid(_objective_hint_text):
		return
	var objectives: Array = _quests[_selected_quest]["objectives"]
	for objective in objectives:
		if not bool(objective["complete"]):
			_objective_hint_text.text = str(objective["text"])
			_objective_hint_progress.text = str(objective["progress"])
			_objective_hint_progress.visible = not str(objective["progress"]).is_empty()
			return
	_objective_hint_text.text = "Semua objective selesai."
	_objective_hint_progress.text = ""
	_objective_hint_progress.hide()


func _make_page(spread: HBoxContainer, stretch_ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _page_style(Color("12120f"), Color("39352e"), 1, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	spread.add_child(panel)
	var margins := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margins.add_theme_constant_override(side, 26)
	panel.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	margins.add_child(content)
	return content


func _build_quest_list(page: VBoxContainer) -> void:
	page.add_child(_label("QUEST", HEADING_FONT, 36, PAPER))
	_add_rule(page, Color("786d5b", 0.38))
	_add_gap(page, 16)
	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 10)
	_quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_quest_list)
	for index in _quests.size():
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 37
		row.add_theme_font_override("font", HEADING_FONT)
		row.add_theme_font_size_override("font_size", 23)
		row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		row.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		row.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		row.pressed.connect(_select_quest.bind(index))
		_quest_list.add_child(row)
		_quest_buttons.append(row)

	_chapter_label = _label(str(_quests[_selected_quest]["chapter"]), BODY_FONT, 11, MUTED)
	_chapter_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_add_gap(page, 18)
	page.add_child(_chapter_label)
	_update_quest_list()


func _build_details_page(page: VBoxContainer) -> void:
	_details = page
	_render_details()


func _render_details() -> void:
	if not is_instance_valid(_details):
		return
	for child in _details.get_children():
		child.queue_free()
	var quest: Dictionary = _quests[_selected_quest]
	_details.add_child(_label(str(quest["title"]).to_upper(), HEADING_FONT, 36, PAPER))
	_add_rule(_details, Color("786d5b", 0.38))
	_add_gap(_details, 18)
	_details.add_child(_label("D E S K R I P S I", HEADING_FONT, 16, ACCENT))
	_add_gap(_details, 7)
	var description := _label(str(quest["description"]), BODY_FONT, 15, PAPER)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 94
	_details.add_child(description)
	_add_gap(_details, 12)
	_details.add_child(_label("O B J E C T I V E", HEADING_FONT, 16, ACCENT))
	_add_gap(_details, 10)
	for objective in quest["objectives"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 35
		var check := Panel.new()
		check.custom_minimum_size = Vector2(15, 15)
		check.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var check_style := _page_style(
			Color("65705b") if bool(objective["complete"]) else Color("1b1b18"),
			Color("8a8878", 0.55),
			1,
			0
		)
		check.add_theme_stylebox_override("panel", check_style)
		row.add_child(check)
		var text_column := VBoxContainer.new()
		text_column.add_theme_constant_override("separation", 1)
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(text_column)
		var objective_label := _label(str(objective["text"]), BODY_FONT, 13, Color("898779") if objective["complete"] else PAPER)
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_column.add_child(objective_label)
		if not str(objective["progress"]).is_empty():
			text_column.add_child(_label(str(objective["progress"]), BODY_FONT, 10, ACCENT))
		_details.add_child(row)


func _select_quest(index: int) -> void:
	if index < 0 or index >= _quests.size():
		return
	_selected_quest = index
	_update_quest_list()
	_render_details()
	_refresh_objective_hint()


func _update_quest_list() -> void:
	if is_instance_valid(_chapter_label):
		_chapter_label.text = str(_quests[_selected_quest]["chapter"])
	for index in _quest_buttons.size():
		var button := _quest_buttons[index]
		var selected := index == _selected_quest
		button.text = "%02d     %s" % [index + 1, _quests[index]["title"]]
		button.disabled = selected
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if selected else Control.CURSOR_POINTING_HAND
		var row_color := ACCENT if selected else PAPER
		button.add_theme_color_override("font_color", row_color)
		button.add_theme_color_override("font_hover_color", row_color)
		button.add_theme_color_override("font_pressed_color", row_color)
		button.add_theme_color_override("font_disabled_color", ACCENT)
		button.add_theme_font_override("font", HEADING_FONT)
		button.add_theme_font_size_override("font_size", 23)


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _add_rule(parent: Control, color: Color) -> void:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1.0
	rule.color = color
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _add_gap(parent: Control, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)


func _page_style(background: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style
