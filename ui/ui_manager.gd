extends Node

## UIManager — Autoload coordinator for Pause Menu, Hint Objective, and Quest Guide
## across gameplay levels (Chapter 1, Chapter 2, etc.) without mutating level .tscn files.

const MAIN_MENU_SCENE_PATH := "res://main_menu.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://pause_menu.tscn")
const QUEST_GUIDE_SCENE: PackedScene = preload("res://quest_guide.tscn")

var brightness_value: float = 0.55

var _in_gameplay: bool = false
var _quest_guide: QuestGuide = null
var _pause_menu: PauseMenu = null
var _last_scene_id: int = 0

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null
var _pending_black_fade_in: bool = false

# Chapter 1 progress tracking guards
var _ch1_boxes_done: bool = false
var _ch1_teddy_carried: bool = false
var _ch1_plate_done: bool = false
var _ch1_stairs_started: bool = false
var _ch1_stairs_done: bool = false
var _ch1_portal_done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_overlay()
	if get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_sync_scene_ui")


func _setup_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "GlobalFadeLayer"
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "BlackFadeRect"
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.modulate.a = 0.0
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)


func fade_to_black(duration: float = 0.55) -> Tween:
	if not is_instance_valid(_fade_rect):
		return null
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _fade_tween


func fade_from_black(duration: float = 0.8) -> void:
	if not is_instance_valid(_fade_rect):
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.modulate.a = 1.0
	_fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(func() -> void:
		if is_instance_valid(_fade_rect):
			_fade_rect.visible = false
	)


func transition_to_scene(scene_path: String) -> void:
	_pending_black_fade_in = true
	if is_instance_valid(_fade_rect):
		_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
		_fade_rect.modulate.a = 1.0
		_fade_rect.visible = true
	get_tree().call_deferred("change_scene_to_file", scene_path)


func _process(_delta: float) -> void:
	var cur := get_tree().current_scene
	var cur_id := cur.get_instance_id() if is_instance_valid(cur) else 0
	if cur_id != _last_scene_id:
		_sync_scene_ui()


func _on_scene_changed() -> void:
	call_deferred("_sync_scene_ui")


func set_brightness(value: float) -> void:
	brightness_value = clampf(value, 0.0, 1.0)
	_apply_brightness_to_current_scene()


func _apply_brightness_to_current_scene() -> void:
	var cur := get_tree().current_scene
	if not is_instance_valid(cur):
		return
	var adj := lerpf(0.65, 1.35, brightness_value)
	for node in cur.find_children("*", "WorldEnvironment", true, false):
		var we := node as WorldEnvironment
		if we and we.environment:
			we.environment.adjustment_enabled = true
			we.environment.adjustment_brightness = adj


func _sync_scene_ui() -> void:
	var cur := get_tree().current_scene
	if not is_instance_valid(cur):
		_last_scene_id = 0
		return
	_last_scene_id = cur.get_instance_id()
	var path := cur.scene_file_path

	_clear_gameplay_ui()

	if path == MAIN_MENU_SCENE_PATH or path.is_empty():
		_in_gameplay = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _pending_black_fade_in:
			_pending_black_fade_in = false
			fade_from_black(0.5)
		return

	_in_gameplay = true
	get_tree().paused = false
	_apply_brightness_to_current_scene()

	if _pending_black_fade_in:
		_pending_black_fade_in = false
		fade_from_black(0.85)

	_quest_guide = QUEST_GUIDE_SCENE.instantiate() as QuestGuide
	_quest_guide.layer = 35
	add_child(_quest_guide)

	if "chapter_2" in path.to_lower():
		_quest_guide.select_quest(1, true)
	else:
		_quest_guide.select_quest(0, true)
		_bind_chapter1_events(cur)


func _clear_gameplay_ui() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null
	if is_instance_valid(_quest_guide):
		_quest_guide.queue_free()
		_quest_guide = null
	_reset_ch1_flags()


func _reset_ch1_flags() -> void:
	_ch1_boxes_done = false
	_ch1_teddy_carried = false
	_ch1_plate_done = false
	_ch1_stairs_started = false
	_ch1_stairs_done = false
	_ch1_portal_done = false


func _unhandled_input(event: InputEvent) -> void:
	if not _in_gameplay:
		return
	if not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	if is_instance_valid(_pause_menu):
		return
	if is_instance_valid(_quest_guide) and _quest_guide.is_journal_open():
		_quest_guide.close_guide()
		get_viewport().set_input_as_handled()
		return
	open_pause_menu()
	get_viewport().set_input_as_handled()


func open_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		return
	if is_instance_valid(_quest_guide):
		_quest_guide.close_guide()
		_quest_guide.set_tab_input_enabled(false)
	_pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	_pause_menu.layer = 50
	_pause_menu.tree_exited.connect(_on_pause_menu_closed)
	add_child(_pause_menu)


func _on_pause_menu_closed() -> void:
	_pause_menu = null
	if is_instance_valid(_quest_guide):
		_quest_guide.set_tab_input_enabled(true)


func _bind_chapter1_events(scene_root: Node) -> void:
	# 1. ABCD Puzzle Manager (3 kotak mainan)
	var abcd := scene_root.find_child("ABCDPuzzleManager", true, false)
	if abcd:
		if abcd.has_signal("puzzle_completed"):
			abcd.connect("puzzle_completed", _on_ch1_abcd_completed)
		for child in abcd.get_children():
			if child is Area3D and child.has_signal("slot_filled"):
				child.connect("slot_filled", _on_ch1_slot_filled.bind(abcd))
		_update_ch1_box_progress(abcd)

	# 2. CarrySystem (Teddy Bear diambil)
	var carry := scene_root.find_child("CarrySystem", true, false)
	if carry and carry.has_signal("item_picked_up"):
		carry.connect("item_picked_up", _on_ch1_item_picked_up)

	# 3. Chapter1PuzzleManager & PressurePlate (Teddy Bear ke Pressure Plate)
	var puz := scene_root.find_child("Chapter1PuzzleManager", true, false)
	if puz and puz.has_signal("puzzle_step_completed"):
		puz.connect("puzzle_step_completed", _on_ch1_puzzle_step)

	var plate := scene_root.find_child("PressurePlate", true, false)
	if plate and plate.has_signal("plate_activated"):
		plate.connect("plate_activated", _on_ch1_plate_activated)

	# 4. StepStairRevealer / GlowingPlatforms (Tangga putih)
	var stairs := scene_root.find_child("GlowingPlatforms", true, false)
	if stairs:
		if stairs.has_signal("stair_revealed"):
			stairs.connect("stair_revealed", _on_ch1_stair_revealed)
		if stairs.has_signal("all_platforms_activated"):
			stairs.connect("all_platforms_activated", _on_ch1_all_stairs_activated)

	# 5. DoorPortal (Portal pintu)
	var portal := scene_root.find_child("DoorPortal", true, false)
	if portal:
		if portal.has_signal("transition_started"):
			portal.connect("transition_started", _on_ch1_portal_entered)
		if portal.has_signal("transition_finished"):
			portal.connect("transition_finished", _on_ch1_portal_entered)


func _on_ch1_slot_filled(_block: Node3D, abcd: Node) -> void:
	_update_ch1_box_progress(abcd)


func _update_ch1_box_progress(abcd: Node) -> void:
	if not is_instance_valid(_quest_guide) or not is_instance_valid(abcd):
		return
	var count := 0
	var req := 3
	if abcd.has_method("get_filled_slot_count"):
		count = int(abcd.call("get_filled_slot_count"))
	if "required_count" in abcd:
		req = int(abcd.get("required_count"))
	_quest_guide.set_objective_progress(0, 0, "%d/%d" % [mini(count, req), req])
	if count >= req and not _ch1_boxes_done:
		_on_ch1_abcd_completed()
	elif count > 0 and not _ch1_boxes_done:
		_quest_guide.show_objective_toast()


func _on_ch1_abcd_completed() -> void:
	if _ch1_boxes_done or not is_instance_valid(_quest_guide):
		return
	_ch1_boxes_done = true
	_quest_guide.set_objective_progress(0, 0, "3/3")
	_quest_guide.set_objective_completed(0, 0, true)
	_quest_guide.show_objective_toast()


func _on_ch1_item_picked_up(item: Node) -> void:
	if _ch1_plate_done or _ch1_teddy_carried or not is_instance_valid(_quest_guide) or item == null:
		return
	if item.is_in_group("teddy_bear") or "teddy" in item.name.to_lower():
		_ch1_teddy_carried = true
		_quest_guide.set_objective_progress(0, 1, "Bawa ke plate")
		_quest_guide.show_objective_toast()


func _on_ch1_plate_activated() -> void:
	if _ch1_plate_done or not is_instance_valid(_quest_guide):
		return
	_ch1_plate_done = true
	if not _ch1_boxes_done:
		_on_ch1_abcd_completed()
	_quest_guide.set_objective_progress(0, 1, "")
	_quest_guide.set_objective_completed(0, 1, true)
	_quest_guide.show_objective_toast()


func _on_ch1_stair_revealed(index: int, _plat: Node) -> void:
	if _ch1_stairs_done or not is_instance_valid(_quest_guide):
		return
	if not _ch1_plate_done:
		_on_ch1_plate_activated()
	_quest_guide.set_objective_progress(0, 2, "%d/19" % mini(index + 1, 19))
	if not _ch1_stairs_started:
		_ch1_stairs_started = true
		_quest_guide.show_objective_toast()


func _on_ch1_all_stairs_activated() -> void:
	if _ch1_stairs_done or not is_instance_valid(_quest_guide):
		return
	_ch1_stairs_done = true
	_quest_guide.set_objective_progress(0, 2, "19/19")
	_quest_guide.set_objective_completed(0, 2, true)
	_quest_guide.show_objective_toast()


func _on_ch1_portal_entered() -> void:
	if _ch1_portal_done or not is_instance_valid(_quest_guide):
		return
	_ch1_portal_done = true
	if not _ch1_stairs_done:
		_on_ch1_all_stairs_activated()
	_quest_guide.set_objective_completed(0, 3, true)
	_quest_guide.show_objective_toast()


func _on_ch1_puzzle_step(step: int) -> void:
	match step:
		2:
			_on_ch1_plate_activated()
		3:
			_on_ch1_all_stairs_activated()
		4:
			_on_ch1_portal_entered()
