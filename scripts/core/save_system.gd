class_name SaveSystem
extends RefCounted

## Sistem autosave atomik untuk Chapter 1 dan Chapter 2 (JSON + .tmp + .bak fallback).

const SAVE_VERSION: int = 1
const AUTOSAVE_PATH: String = "user://autosave.json"
const MIN_AUTOSAVE_INTERVAL_MS: int = 15000

static var _last_autosave_ms: int = 0


static func save_atomic(path: String, data: Dictionary) -> int:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	if not payload.has("saved_at_unix"):
		payload["saved_at_unix"] = int(Time.get_unix_time_from_system())

	var json_text := JSON.stringify(payload, "\t")
	if json_text.is_empty():
		return ERR_INVALID_DATA

	var tmp_path := path + ".tmp"
	var bak_path := path + ".bak"
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	var abs_bak := ProjectSettings.globalize_path(bak_path)

	var parent_dir := abs_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var file := FileAccess.open(abs_tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.flush()
	var write_err := file.get_error()
	file.close()
	if write_err != OK:
		DirAccess.remove_absolute(abs_tmp)
		return write_err

	if FileAccess.file_exists(abs_path):
		if FileAccess.file_exists(abs_bak):
			DirAccess.remove_absolute(abs_bak)
		var bak_err := DirAccess.rename_absolute(abs_path, abs_bak)
		if bak_err != OK:
			DirAccess.remove_absolute(abs_tmp)
			return bak_err

	var rename_err := DirAccess.rename_absolute(abs_tmp, abs_path)
	if rename_err != OK:
		if FileAccess.file_exists(abs_bak) and not FileAccess.file_exists(abs_path):
			DirAccess.rename_absolute(abs_bak, abs_path)
		DirAccess.remove_absolute(abs_tmp)
		return rename_err

	return OK


static func load_save(path: String = AUTOSAVE_PATH) -> Dictionary:
	var primary := _read_and_validate(path)
	if not primary.is_empty():
		return primary
	return _read_and_validate(path + ".bak")


static func has_valid_save(path: String = AUTOSAVE_PATH) -> bool:
	return not load_save(path).is_empty()


static func clear_save(path: String = AUTOSAVE_PATH) -> void:
	_last_autosave_ms = 0
	for candidate in [path, path + ".tmp", path + ".bak"]:
		var abs_p := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(abs_p):
			DirAccess.remove_absolute(abs_p)


static func vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec3(raw: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if raw is Array:
		var arr := raw as Array
		if arr.size() >= 3:
			return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback


static func _read_and_validate(path: String) -> Dictionary:
	var abs_p := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_p):
		return {}
	var file := FileAccess.open(abs_p, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {}

	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return {}

	var d := parser.data as Dictionary
	var ver_raw: Variant = d.get("version", 0)
	if typeof(ver_raw) != TYPE_INT and typeof(ver_raw) != TYPE_FLOAT:
		return {}
	var ver := int(ver_raw)
	if ver < 1 or ver > SAVE_VERSION:
		return {}
	var chapter: Variant = d.get("chapter", "")
	if not (chapter is String) or String(chapter).is_empty():
		return {}
	return d


static func detect_chapter(scene_root: Node) -> String:
	if scene_root == null or not is_instance_valid(scene_root):
		return ""
	var p := scene_root.scene_file_path
	if "chapter_1" in p or scene_root.find_child("Chapter1PuzzleManager", true, false) != null:
		return "chapter_1"
	if "chapter_2" in p or scene_root.find_child("Chapter2PuzzleManager", true, false) != null:
		return "chapter_2"
	return ""


static func is_safe_to_autosave(scene_root: Node, allow_during_chase: bool = false) -> bool:
	var ch := detect_chapter(scene_root)
	if ch.is_empty():
		return false
	var player := scene_root.find_child("Player", true, false) as CharacterBody3D
	if player == null or not is_instance_valid(player):
		return false
	if player.global_position.y < -1.5:
		return false
	if "input_enabled" in player and not bool(player.get("input_enabled")):
		return false
	var portal := scene_root.find_child("DoorPortal", true, false)
	if portal and "_is_transitioning" in portal and bool(portal.get("_is_transitioning")):
		return false
	var eraser := scene_root.find_child("TheEraser", true, false)
	if eraser and "current_state" in eraser:
		var st := int(eraser.get("current_state"))
		if st == 3 or st == 5: # ATTACK or CUTSCENE
			return false
		if not allow_during_chase and st == 1: # CHASE
			return false
	return true


static func autosave_scene(scene_root: Node, force: bool = false, path: String = AUTOSAVE_PATH) -> int:
	if not is_safe_to_autosave(scene_root, force):
		return ERR_BUSY
	var now := Time.get_ticks_msec()
	if not force and _last_autosave_ms > 0 and (now - _last_autosave_ms) < MIN_AUTOSAVE_INTERVAL_MS:
		return ERR_SKIP
	var state := capture_scene_state(scene_root)
	if state.is_empty():
		return ERR_INVALID_DATA
	var err := save_atomic(path, state)
	if err == OK:
		_last_autosave_ms = now
	return err


static func setup_chapter_autosave(scene_root: Node, pending_load: Dictionary, ui_manager: Node = null) -> void:
	var ch := detect_chapter(scene_root)
	if ch.is_empty():
		return
	if not pending_load.is_empty() and String(pending_load.get("chapter", "")) == ch:
		restore_scene_state(scene_root, pending_load, ui_manager)
		_last_autosave_ms = Time.get_ticks_msec()
	else:
		autosave_scene(scene_root, true)
	_bind_autosave_signals(scene_root, ch)


static func _connect_once(obj: Object, sig_name: String, cb: Callable) -> void:
	if obj == null or not is_instance_valid(obj) or not obj.has_signal(sig_name):
		return
	if not obj.is_connected(sig_name, cb):
		obj.connect(sig_name, cb)


static func _on_milestone_autosave(scene_root: Node, force: bool) -> void:
	if scene_root == null or not is_instance_valid(scene_root) or not scene_root.is_inside_tree():
		return
	autosave_scene(scene_root, force)


static func _on_ch1_portal_transition_started() -> void:
	save_atomic(AUTOSAVE_PATH, {
		"chapter": "chapter_2",
		"in_memory": true,
	})


static func _bind_autosave_signals(scene_root: Node, ch: String) -> void:
	if ch == "chapter_1":
		var abcd := scene_root.find_child("Puzzle_ABCD", true, false)
		var candles := scene_root.find_child("CandlePuzzleManager", true, false)
		var plate := scene_root.find_child("PressurePlate", true, false)
		var void_zone := scene_root.find_child("VoidRespawnZone", true, false)
		var seq := scene_root.find_child("ParkourSequencer", true, false)
		var portal := scene_root.find_child("DoorPortal", true, false)
		_connect_once(abcd, "puzzle_completed", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		_connect_once(candles, "puzzle_completed", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		_connect_once(plate, "plate_activated", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		if void_zone:
			_connect_once(void_zone, "parkour_progress_updated", func(_step: int, _total: int) -> void:
				_on_milestone_autosave(scene_root, false)
			)
		_connect_once(seq, "all_platforms_popped", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		_connect_once(portal, "transition_started", Callable(SaveSystem, "_on_ch1_portal_transition_started"))
	elif ch == "chapter_2":
		var two_clocks := scene_root.find_child("TwoClocksPuzzle", true, false)
		var wall_clocks := scene_root.find_child("WallClocksPuzzle", true, false)
		var socket := scene_root.find_child("RelicSocketZone", true, false)
		_connect_once(two_clocks, "puzzle_completed", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		_connect_once(wall_clocks, "puzzle_completed", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		if wall_clocks:
			_connect_once(wall_clocks, "safe_room_state_changed", func(_entered: bool) -> void:
				_on_milestone_autosave(scene_root, true)
			)
			_connect_once(wall_clocks, "inner_clock_step_changed", func(_step: int, _target: int, solved: bool) -> void:
				_on_milestone_autosave(scene_root, solved)
			)
		if socket:
			_connect_once(socket, "relic_delivered", func(_relic: Node3D) -> void:
				_on_milestone_autosave(scene_root, true)
			)
			_connect_once(socket, "all_relics_delivered", Callable(SaveSystem, "_on_milestone_autosave").bind(scene_root, true))
		if scene_root.get_tree():
			for r in scene_root.get_tree().get_nodes_in_group("floating_relic_item"):
				_connect_once(r, "relic_collected", func(_relic: Node) -> void:
					_on_milestone_autosave(scene_root, true)
				)


static func capture_scene_state(scene_root: Node) -> Dictionary:
	var ch := detect_chapter(scene_root)
	if ch.is_empty():
		return {}
	var player := scene_root.find_child("Player", true, false) as CharacterBody3D
	var in_mem := bool(scene_root.get("in_memory")) if "in_memory" in scene_root else true
	var state := {
		"version": SAVE_VERSION,
		"chapter": ch,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"in_memory": in_mem,
		"player_pos": vec3_to_array(player.global_position) if player else [0.0, 0.5, 0.0],
	}
	if ch == "chapter_1":
		state["ch1"] = _capture_ch1(scene_root)
	elif ch == "chapter_2":
		state["ch2"] = _capture_ch2(scene_root)
	return state


static func _capture_ch1(scene_root: Node) -> Dictionary:
	var abcd := scene_root.find_child("Puzzle_ABCD", true, false)
	var slots := {}
	if abcd:
		for c in abcd.get_children():
			if "is_filled" in c:
				slots[c.name] = bool(c.get("is_filled"))
	var blocks := {}
	if scene_root.get_tree():
		for b in scene_root.get_tree().get_nodes_in_group("puzzle_block"):
			if b is Node3D:
				blocks[b.name] = vec3_to_array((b as Node3D).global_position)

	var candles_mgr := scene_root.find_child("CandlePuzzleManager", true, false)
	var candles_lit := {}
	var candles_active := false
	if candles_mgr:
		for c in candles_mgr.get_children():
			if "is_lit" in c:
				candles_lit[c.name] = bool(c.get("is_lit"))
				if "puzzle_active" in c and bool(c.get("puzzle_active")):
					candles_active = true

	var teddy := scene_root.find_child("TeddyBearPickup", true, false) as Node3D
	var plate := scene_root.find_child("PressurePlate", true, false)
	var portal := scene_root.find_child("DoorPortal", true, false)
	var void_zone := scene_root.find_child("VoidRespawnZone", true, false)
	var tembok := scene_root.find_child("TembokKebelah", true, false)

	return {
		"abcd_solved": bool(abcd.get("is_puzzle_solved")) if abcd and "is_puzzle_solved" in abcd else false,
		"slots": slots,
		"blocks": blocks,
		"candles_active": candles_active,
		"candles_lit": candles_lit,
		"candles_lit_count": int(candles_mgr.get("_lit_count")) if candles_mgr and "_lit_count" in candles_mgr else 0,
		"candles_solved": bool(candles_mgr.get("_is_solved")) if candles_mgr and "_is_solved" in candles_mgr else false,
		"teddy_unlocked": (not bool(teddy.get("freeze"))) if teddy and "freeze" in teddy else false,
		"teddy_on_plate": bool(teddy.get("is_on_pressure_plate")) if teddy and "is_on_pressure_plate" in teddy else false,
		"teddy_pos": vec3_to_array(teddy.global_position) if teddy else [0.0, 0.0, 0.0],
		"plate_pressed": bool(plate.get("is_pressed")) if plate and "is_pressed" in plate else false,
		"portal_unlocked": (not bool(portal.get("is_locked"))) if portal and "is_locked" in portal else false,
		"highest_rock_index": int(void_zone.get("_highest_rock_index")) if void_zone and "_highest_rock_index" in void_zone else 0,
		"checkpoint_pos": vec3_to_array(void_zone.get("_checkpoint_pos")) if void_zone and "_checkpoint_pos" in void_zone else [25.8, 0.35, 3.8],
		"tembok_open": bool(tembok.get("is_open")) if tembok and "is_open" in tembok else false,
	}


static func _capture_ch2(scene_root: Node) -> Dictionary:
	var two_clocks := scene_root.find_child("TwoClocksPuzzle", true, false)
	var wall_clocks := scene_root.find_child("WallClocksPuzzle", true, false)
	var socket := scene_root.find_child("RelicSocketZone", true, false)
	var tembok1 := scene_root.find_child("TembokKebelah", true, false)

	var clock_rem: Object = two_clocks.get("_clock_rem") if two_clocks and "_clock_rem" in two_clocks else null
	var clock_forg: Object = two_clocks.get("_clock_forg") if two_clocks and "_clock_forg" in two_clocks else null

	var relics := {}
	if scene_root.get_tree():
		for r in scene_root.get_tree().get_nodes_in_group("floating_relic_item"):
			if "relic_id" in r and "state" in r:
				relics[String(r.get("relic_id"))] = int(r.get("state"))

	return {
		"two_clocks_solved": bool(two_clocks.get("is_solved")) if two_clocks and "is_solved" in two_clocks else false,
		"clock_rem_hour": int(clock_rem.get("current_hour")) if clock_rem and "current_hour" in clock_rem else 3,
		"clock_forg_hour": int(clock_forg.get("current_hour")) if clock_forg and "current_hour" in clock_forg else 9,
		"wall_clocks_solved": bool(wall_clocks.get("is_solved")) if wall_clocks and "is_solved" in wall_clocks else false,
		"wall_target_hour": int(wall_clocks.get("target_hour")) if wall_clocks and "target_hour" in wall_clocks else 9,
		"wall_hour_l1": int(wall_clocks.get("current_hour_l1")) if wall_clocks and "current_hour_l1" in wall_clocks else 6,
		"wall_hour_l2": int(wall_clocks.get("current_hour_l2")) if wall_clocks and "current_hour_l2" in wall_clocks else 4,
		"inner_revealed": bool(wall_clocks.get("_inner_revealed")) if wall_clocks and "_inner_revealed" in wall_clocks else false,
		"inner_step": int(wall_clocks.get("inner_step")) if wall_clocks and "inner_step" in wall_clocks else 3,
		"inner_solved": bool(wall_clocks.get("inner_solved")) if wall_clocks and "inner_solved" in wall_clocks else false,
		"player_in_safe_room": bool(wall_clocks.get("player_in_safe_room")) if wall_clocks and "player_in_safe_room" in wall_clocks else false,
		"relics": relics,
		"relics_delivered_count": int(socket.get("delivered_count")) if socket and "delivered_count" in socket else 0,
		"relic_socket_fulfilled": bool(socket.get("is_fulfilled")) if socket and "is_fulfilled" in socket else false,
		"tembok1_open": bool(tembok1.get("is_open")) if tembok1 and "is_open" in tembok1 else false,
	}


static func restore_scene_state(scene_root: Node, data: Dictionary, ui_manager: Node = null) -> void:
	if scene_root == null or not is_instance_valid(scene_root) or data.is_empty():
		return
	var ch := detect_chapter(scene_root)
	if ch.is_empty() or String(data.get("chapter", "")) != ch:
		return

	var in_mem := bool(data.get("in_memory", true))
	if "in_memory" in scene_root:
		scene_root.set("in_memory", in_mem)
	if scene_root.has_method("apply_dimension_state"):
		scene_root.call("apply_dimension_state", in_mem, true)
	if scene_root.has_signal("dimension_shifted"):
		scene_root.emit_signal("dimension_shifted", in_mem)

	var player := scene_root.find_child("Player", true, false) as CharacterBody3D
	if player and data.has("player_pos"):
		var pos := array_to_vec3(data.get("player_pos"), player.global_position)
		if pos.y >= -1.0:
			player.global_position = pos
		player.velocity = Vector3.ZERO

	if ch == "chapter_1" and data.get("ch1") is Dictionary:
		_restore_ch1(scene_root, data.get("ch1") as Dictionary, player, ui_manager)
	elif ch == "chapter_2" and data.get("ch2") is Dictionary:
		_restore_ch2(scene_root, data.get("ch2") as Dictionary, player, ui_manager)


static func _restore_ch1(scene_root: Node, ch1: Dictionary, player: CharacterBody3D, ui_manager: Node) -> void:
	var abcd := scene_root.find_child("Puzzle_ABCD", true, false)
	var slots_data: Dictionary = ch1.get("slots", {}) as Dictionary
	var blocks_data: Dictionary = ch1.get("blocks", {}) as Dictionary
	var block_nodes: Array = scene_root.get_tree().get_nodes_in_group("puzzle_block") if scene_root.get_tree() else []

	for b_var in block_nodes:
		var b := b_var as Node3D
		if b and blocks_data.has(b.name):
			b.global_position = array_to_vec3(blocks_data[b.name], b.global_position)

	if abcd:
		for c in abcd.get_children():
			if bool(slots_data.get(c.name, false)) and not bool(c.get("is_filled")):
				var req_id := String(c.get("required_block_id"))
				for b_var in block_nodes:
					var b := b_var as Node3D
					if b and String(b.get("block_id")) == req_id and c.has_method("_snap_block_into_slot"):
						c.call("_snap_block_into_slot", b)
						break
		if bool(ch1.get("abcd_solved", false)):
			abcd.set("is_puzzle_solved", true)

	var candles_mgr := scene_root.find_child("CandlePuzzleManager", true, false)
	var candles_lit: Dictionary = ch1.get("candles_lit", {}) as Dictionary
	if candles_mgr:
		if bool(ch1.get("candles_active", false)) and candles_mgr.has_method("activate_puzzle"):
			candles_mgr.call("activate_puzzle")
		for c in candles_mgr.get_children():
			if c.has_method("set_lit"):
				c.call("set_lit", bool(candles_lit.get(c.name, false)))
		candles_mgr.set("_lit_count", int(ch1.get("candles_lit_count", 0)))
		candles_mgr.set("_is_solved", bool(ch1.get("candles_solved", false)))

	var teddy := scene_root.find_child("TeddyBearPickup", true, false) as Node3D
	if teddy:
		if bool(ch1.get("teddy_unlocked", false)) and teddy.has_method("unlock_teddy"):
			teddy.call("unlock_teddy")
		if ch1.has("teddy_pos") and not bool(ch1.get("teddy_on_plate", false)):
			teddy.global_position = array_to_vec3(ch1.get("teddy_pos"), teddy.global_position)

	var tembok := scene_root.find_child("TembokKebelah", true, false)
	if tembok and bool(ch1.get("tembok_open", false)) and tembok.has_method("unlock_and_open"):
		tembok.call("unlock_and_open")

	var plate := scene_root.find_child("PressurePlate", true, false) as Node3D
	var ch1_mgr := scene_root.find_child("Chapter1PuzzleManager", true, false)
	var portal := scene_root.find_child("DoorPortal", true, false)
	var seq := scene_root.find_child("ParkourSequencer", true, false)
	var portal_unlocked := bool(ch1.get("portal_unlocked", false))

	if plate and (bool(ch1.get("plate_pressed", false)) or portal_unlocked):
		if teddy:
			teddy.global_position = plate.global_position + Vector3(0.0, 0.35, 0.0)
			if teddy.has_method("mark_placed_on_plate"):
				teddy.call("mark_placed_on_plate")
		plate.set("is_pressed", true)
		if plate.has_method("_activate_meja7_light"):
			plate.call("_activate_meja7_light")
		var pmesh := plate.get("plate_mesh") as Node3D
		if pmesh and "plate_original_position" in plate and "plate_pressed_offset" in plate:
			pmesh.position.y = float((plate.get("plate_original_position") as Vector3).y) + float(plate.get("plate_pressed_offset"))
		if ch1_mgr:
			ch1_mgr.set("teddy_on_plate", true)
			ch1_mgr.set("platforms_activated", portal_unlocked)
			ch1_mgr.set("portal_activated", portal_unlocked)

	if portal_unlocked:
		if seq and "platforms" in seq:
			for plat in seq.get("platforms"):
				if plat and plat.has_method("popup_appear"):
					plat.call("popup_appear", 0.0, 0.01)
		if portal and portal.has_method("activate_portal"):
			portal.call("activate_portal")

	var void_zone := scene_root.find_child("VoidRespawnZone", true, false)
	if void_zone:
		var rock_idx := int(ch1.get("highest_rock_index", 0))
		void_zone.set("_highest_rock_index", rock_idx)
		if ch1.has("checkpoint_pos"):
			var cp := array_to_vec3(ch1.get("checkpoint_pos"), Vector3(25.8, 0.35, 3.8))
			void_zone.set("_checkpoint_pos", cp)
			if player and player.global_position.y < -1.0:
				player.global_position = cp

	if ui_manager:
		ui_manager.set("_ch1_boxes_done", bool(ch1.get("abcd_solved", false)))
		ui_manager.set("_ch1_candles_done", bool(ch1.get("candles_solved", false)))
		ui_manager.set("_ch1_plate_done", bool(ch1.get("plate_pressed", false)) or portal_unlocked)
		ui_manager.set("_ch1_stairs_started", portal_unlocked)
		ui_manager.set("_ch1_stairs_done", portal_unlocked)
		if ui_manager.has_method("_sync_restored_ch1_quest"):
			ui_manager.call("_sync_restored_ch1_quest")


static func _restore_ch2(scene_root: Node, ch2: Dictionary, player: CharacterBody3D, ui_manager: Node) -> void:
	var two_clocks := scene_root.find_child("TwoClocksPuzzle", true, false)
	if two_clocks and two_clocks.has_method("restore_state"):
		two_clocks.call(
			"restore_state",
			bool(ch2.get("two_clocks_solved", false)),
			int(ch2.get("clock_rem_hour", 3)),
			int(ch2.get("clock_forg_hour", 9))
		)

	var wall_clocks := scene_root.find_child("WallClocksPuzzle", true, false)
	if wall_clocks and wall_clocks.has_method("restore_wall_state"):
		wall_clocks.call("restore_wall_state", ch2)

	var relics_map: Dictionary = ch2.get("relics", {}) as Dictionary
	var delivered_list: Array[Node3D] = []
	var collected_count := 0
	if scene_root.get_tree():
		for r_var in scene_root.get_tree().get_nodes_in_group("floating_relic_item"):
			var r := r_var as Node3D
			if r == null:
				continue
			var rid := String(r.get("relic_id"))
			var st := int(relics_map.get(rid, 0))
			if st == 1 and player:
				collected_count += 1
				if r.has_method("force_collected_by"):
					r.call("force_collected_by", player)
			elif st == 2 or st == 3:
				delivered_list.append(r)

	var socket := scene_root.find_child("RelicSocketZone", true, false)
	var fulfilled := bool(ch2.get("relic_socket_fulfilled", false))
	if socket and socket.has_method("restore_delivered_relics"):
		socket.call("restore_delivered_relics", delivered_list, fulfilled)

	var tembok1 := scene_root.find_child("TembokKebelah", true, false)
	if tembok1 and bool(ch2.get("tembok1_open", false)) and tembok1.has_method("unlock_and_open"):
		tembok1.call("unlock_and_open")

	if ui_manager:
		ui_manager.set("_ch2_clocks_done", bool(ch2.get("two_clocks_solved", false)))
		ui_manager.set("_ch2_wall_clocks_done", bool(ch2.get("wall_clocks_solved", false)))
		ui_manager.set("_ch2_relic_collected", (collected_count + delivered_list.size()) >= 3)
		ui_manager.set("_ch2_relic_delivered", fulfilled)
		if ui_manager.has_method("_sync_restored_ch2_quest"):
			ui_manager.call("_sync_restored_ch2_quest")
