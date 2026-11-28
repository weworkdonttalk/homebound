@tool
class_name TwoClocksPuzzle
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")
const DialStationScript := preload("res://scripts/gameplay/clock_dial_station.gd")

## Puzzle 1: The Two Clocks (Zona 1 — Hall Masuk)
## Sinkronkan Jam Remembered (awal 03:00) dan Jam Forgotten (awal 09:00) ke pukul 12:00.
## Setiap jam yang selaras menggerakkan mekanisme tautan di depan pintu2 hingga pintu terbuka.

signal progress_updated(synced_count: int, total_count: int)
signal puzzle_completed
signal wall_clock_step_changed(synced_count: int, total_count: int, target_hour: int)
signal wall_clocks_reset(new_target_hour: int)
signal safe_room_state_changed(entered: bool)
signal inner_clock_step_changed(current_step: int, target_step: int, solved: bool)

@export var door_node_path: NodePath = NodePath("../pintu2")

@export_group("Wall Clocks Cross-Dimension Mode")
@export var clock_l1_path: NodePath = NodePath("")
@export var clock_l2_path: NodePath = NodePath("")
@export var target_double_door_path: NodePath = NodePath("")
@export var interact_zone_path: NodePath = NodePath("ClockL1InteractZone")
@export var interact_zone_l2_path: NodePath = NodePath("ClockL2InteractZone")
@export_enum("Always", "Remembered", "Forgotten") var l2_visible_dimension: String = "Forgotten"
@export_range(1, 12) var target_hour: int = 9
@export_range(1, 12) var start_hour_l1: int = 6
@export_range(1, 12) var start_hour_l2: int = 4
@export_range(1, 6) var hour_step: int = 1

@export_group("Safe Room Airlock & Inner Clock")
@export var safe_room_zone_path: NodePath = NodePath("")
@export var inner_clock_path: NodePath = NodePath("")
@export var inner_clock_zone_path: NodePath = NodePath("")
@export_range(0, 11) var inner_start_step: int = 3
@export_range(0, 11) var inner_target_step: int = 6
@export var safe_room_entry_threshold_x: float = 57.95
@export var wall_focus_idle_seconds: float = 1.5

var is_solved: bool = false
var current_hour_l1: int = 6
var current_hour_l2: int = 4
var inner_step: int = 3
var inner_solved: bool = false
var player_in_safe_room: bool = false

var _clock_rem: DialStationScript = null
var _clock_forg: DialStationScript = null

var _wall_mode: bool = false
var _clock_l1: Node3D = null
var _clock_l2: Node3D = null
var _clock_inner: Node3D = null
var _double_door: Node3D = null
var _interact_zone: Area3D = null
var _interact_zone_l2: Area3D = null
var _safe_room_zone: Area3D = null
var _inner_clock_zone: Area3D = null
var _rig_l1: Dictionary = {}
var _rig_l2: Dictionary = {}
var _rig_inner: Dictionary = {}
var _prompt_label: Label3D = null
var _prompt_label_l2: Label3D = null
var _prompt_label_inner: Label3D = null
var _l1_light: OmniLight3D = null
var _l2_light: OmniLight3D = null
var _inner_light: OmniLight3D = null
var _tween_l1: Tween = null
var _tween_l2: Tween = null
var _tween_inner: Tween = null
var _world_manager: Node = null
var _player: CharacterBody3D = null
var _player_in_zone: bool = false
var _player_in_zone_l2: bool = false
var _player_in_zone_inner: bool = false
var _player_in_safe_bounds: bool = false
var _l2_active_in_dim: bool = false
var _wall_focus_idx: int = 0
var _wall_focus_exiting: bool = false
var _wall_focus_timer: float = 0.0
var _wall_focus_cam: Camera3D = null
var _wall_focus_prev_cam: Camera3D = null
var _wall_focus_tween: Tween = null
var _in_door_cutscene: bool = false
var _inner_revealed: bool = false
var _inner_revealing: bool = false
var _inner_target_pos: Vector3 = Vector3.ZERO
var _inner_target_scale: Vector3 = Vector3.ONE
var _restored_from_save: bool = false


func _ready() -> void:
	_wall_mode = not clock_l1_path.is_empty()
	if _wall_mode:
		if Engine.is_editor_hint():
			return
		_setup_wall_clocks_mode()
		return

	_setup_puzzle_nodes()
	if Engine.is_editor_hint():
		return
	_lock_exit_door()
	_emit_progress()


func _setup_puzzle_nodes() -> void:
	# Gunakan node yang sudah ada di scene jika sudah dipasang di Godot Editor
	_clock_rem = get_node_or_null("ClockStationRemembered") as DialStationScript
	if _clock_rem == null:
		_clock_rem = DialStationScript.new()
		_clock_rem.name = "ClockStationRemembered"
		_clock_rem.active_dimension = "Remembered"
		_clock_rem.start_hour = 3
		_clock_rem.target_hour = 12
		_clock_rem.position = Vector3(31.2, 0.0, 1.05)
		add_child(_clock_rem)
	if not Engine.is_editor_hint() and not _clock_rem.hour_changed.is_connected(_on_clock_hour_changed):
		_clock_rem.hour_changed.connect(_on_clock_hour_changed)

	_clock_forg = get_node_or_null("ClockStationForgotten") as DialStationScript
	if _clock_forg == null:
		_clock_forg = DialStationScript.new()
		_clock_forg.name = "ClockStationForgotten"
		_clock_forg.active_dimension = "Forgotten"
		_clock_forg.start_hour = 9
		_clock_forg.target_hour = 12
		_clock_forg.position = Vector3(39.8, 0.0, 1.05)
		add_child(_clock_forg)
	if not Engine.is_editor_hint() and not _clock_forg.hour_changed.is_connected(_on_clock_hour_changed):
		_clock_forg.hour_changed.connect(_on_clock_hour_changed)


func _lock_exit_door() -> void:
	var door := get_node_or_null(door_node_path)
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("pintu2", true, false)
	if door:
		door.set("is_locked", true)
		door.set("locked_hint", "[E] Terkunci")


func _on_clock_hour_changed(_station: Node3D, _hour: int, _synced: bool) -> void:
	if is_solved:
		return
	_update_visual_links()
	_emit_progress()


func _update_visual_links() -> void:
	var rem_ok := _clock_rem != null and _clock_rem.is_synced()
	var forg_ok := _clock_forg != null and _clock_forg.is_synced()
	if rem_ok and forg_ok:
		_solve()


func _emit_progress() -> void:
	var count := 0
	if _clock_rem and _clock_rem.is_synced():
		count += 1
	if _clock_forg and _clock_forg.is_synced():
		count += 1
	progress_updated.emit(count, 2)


func _solve() -> void:
	if is_solved:
		return
	is_solved = true
	if _clock_rem:
		_clock_rem.lock_synced()
	if _clock_forg:
		_clock_forg.lock_synced()

	var door := get_node_or_null(door_node_path) as Node3D
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("pintu2", true, false) as Node3D
	if door:
		door.set("is_locked", false)

	puzzle_completed.emit()
	_play_door_open_cutscene(door)


func _play_door_open_cutscene(door: Node3D) -> void:
	if door == null:
		return
	var door_center := Vector3(45.02, 1.85, 6.42)
	if "_door_center_world" in door:
		var dc: Variant = door.get("_door_center_world")
		if dc is Vector3 and dc != Vector3.ZERO:
			door_center = dc
	var look_target := door_center + Vector3(0.0, 0.25, 0.0)
	var cam_start := door_center + Vector3(-6.8, 0.95, 1.45)
	var cam_end := door_center + Vector3(-4.5, 0.65, 0.65)
	Ch2Utils.play_door_open_cutscene(
		self,
		door,
		cam_start,
		cam_end,
		look_target,
		0.75,
		1.25,
		1.75,
		func() -> void:
			if _clock_rem and _clock_rem.has_method("release_camera_focus"):
				_clock_rem.call("release_camera_focus", false)
			if _clock_forg and _clock_forg.has_method("release_camera_focus"):
				_clock_forg.call("release_camera_focus", false)
	)


# =============================================================================
# Mode Jam Dinding Lintas Dimensi (Lantai 1 <-> Lantai 2) -> Pintu Ganda Lantai 2
# =============================================================================

func _setup_wall_clocks_mode() -> void:
	target_hour = clampi(target_hour, 1, 12)
	current_hour_l1 = clampi(start_hour_l1, 1, 12)
	current_hour_l2 = clampi(start_hour_l2, 1, 12)
	inner_step = posmod(inner_start_step, 12)

	_clock_l1 = get_node_or_null(clock_l1_path) as Node3D
	_clock_l2 = get_node_or_null(clock_l2_path) as Node3D
	_clock_inner = get_node_or_null(inner_clock_path) as Node3D
	_double_door = get_node_or_null(target_double_door_path) as Node3D
	_interact_zone = get_node_or_null(interact_zone_path) as Area3D
	_interact_zone_l2 = get_node_or_null(interact_zone_l2_path) as Area3D
	_safe_room_zone = get_node_or_null(safe_room_zone_path) as Area3D
	_inner_clock_zone = get_node_or_null(inner_clock_zone_path) as Area3D
	_player = Ch2Utils.find_player(self)
	_world_manager = Ch2Utils.find_world_manager(self)

	if _double_door and "requires_relic_unlock" in _double_door:
		_double_door.set("requires_relic_unlock", true)

	_rig_l1 = _build_rig_for_existing_clock(_clock_l1, true)
	_rig_l2 = _build_rig_for_existing_clock(_clock_l2, true)
	_rig_inner = _build_rig_for_existing_clock(_clock_inner, false)

	_l1_light = _ensure_clock_light(_clock_l1, Color(0.55, 0.85, 1.0), 0.7)
	_l2_light = _ensure_clock_light(_clock_l2, Color(1.0, 0.72, 0.35), 1.4)
	_inner_light = _ensure_clock_light(_clock_inner, Color(1.0, 0.78, 0.42), 1.2)
	if _clock_inner:
		_inner_target_pos = _clock_inner.position
		_inner_target_scale = _clock_inner.scale
		_hide_inner_clock()

	_prompt_label = _bind_clock_interact_zone(_interact_zone, 1)
	_prompt_label_l2 = _bind_clock_interact_zone(_interact_zone_l2, 2)
	_prompt_label_inner = _bind_clock_interact_zone(_inner_clock_zone, 3)
	_bind_safe_room_zone(_safe_room_zone)
	_refresh_clock_prompts()

	if _world_manager and _world_manager.has_signal("dimension_shifted"):
		if not _world_manager.is_connected("dimension_shifted", _on_wall_dimension_shifted):
			_world_manager.connect("dimension_shifted", _on_wall_dimension_shifted)
	var in_mem: bool = bool(_world_manager.get("in_memory")) if _world_manager and "in_memory" in _world_manager else true
	_on_wall_dimension_shifted(in_mem)

	call_deferred("_apply_initial_wall_clock_poses")


func _process(delta: float) -> void:
	if not _wall_mode or Engine.is_editor_hint() or _wall_focus_idx == 0 or _wall_focus_exiting or _in_door_cutscene:
		return
	_wall_focus_timer -= delta
	var in_zone := (_player_in_zone if _wall_focus_idx == 1 else (_player_in_zone_l2 and _l2_active_in_dim if _wall_focus_idx == 2 else _player_in_zone_inner and player_in_safe_room))
	var player_moving := _player != null and is_instance_valid(_player) and _player.velocity.length_squared() > 0.08
	if player_moving or not in_zone or _wall_focus_timer <= 0.0:
		_release_wall_clock_focus(true)


func _get_wall_clock_focus_targets(clock_idx: int) -> Dictionary:
	var clock: Node3D = _clock_l1 if clock_idx == 1 else (_clock_l2 if clock_idx == 2 else _clock_inner)
	if clock == null or not is_instance_valid(clock):
		return {}
	var offset := Vector3(0.0, -0.25, 4.6) if clock_idx == 1 else (Vector3(0.0, -0.75, 6.4) if clock_idx == 2 else Vector3(0.0, -0.45, 3.3))
	var fov := 44.0 if clock_idx != 3 else 40.0
	var look_pos := clock.global_position
	if clock_idx == 3 and clock.get_parent() is Node3D:
		look_pos = (clock.get_parent() as Node3D).to_global(_inner_target_pos)
	var cam_pos := look_pos + offset
	return {"look": look_pos, "cam_pos": cam_pos, "fov": fov}


func _sync_wall_prompt_visibility(force_hide: bool = false) -> void:
	if _prompt_label:
		_prompt_label.visible = (not force_hide) and _player_in_zone and not is_solved
	if _prompt_label_l2:
		_prompt_label_l2.visible = (not force_hide) and _player_in_zone_l2 and _l2_active_in_dim and not is_solved
	if _prompt_label_inner:
		_prompt_label_inner.visible = (not force_hide) and _player_in_zone_inner and player_in_safe_room and not inner_solved


func _find_wall_camera_rig() -> Node3D:
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene.find_child("CameraRig", true, false) as Node3D
	return null


func _enter_wall_clock_focus(clock_idx: int) -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	_wall_focus_timer = wall_focus_idle_seconds
	if _wall_focus_idx == clock_idx and not _wall_focus_exiting and is_instance_valid(_wall_focus_cam):
		return

	var targets := _get_wall_clock_focus_targets(clock_idx)
	if targets.is_empty():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rig := _find_wall_camera_rig()
	var base_cam := _wall_focus_prev_cam if (_wall_focus_idx != 0 and is_instance_valid(_wall_focus_prev_cam)) else (rig.get("camera") as Camera3D if rig and "camera" in rig and rig.get("camera") is Camera3D else viewport.get_camera_3d())
	if base_cam == null:
		return

	var start_cam: Camera3D = _wall_focus_cam if is_instance_valid(_wall_focus_cam) else base_cam
	var start_xform := start_cam.global_transform
	var start_fov := start_cam.fov

	_wall_focus_prev_cam = base_cam
	_wall_focus_idx = clock_idx
	_wall_focus_exiting = false
	_sync_wall_prompt_visibility(true)
	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", true)

	if _wall_focus_tween and _wall_focus_tween.is_valid():
		_wall_focus_tween.kill()
	if not is_instance_valid(_wall_focus_cam):
		_wall_focus_cam = Camera3D.new()
		_wall_focus_cam.name = "WallClockFocusCam"
		add_child(_wall_focus_cam)
	_wall_focus_cam.global_transform = start_xform
	_wall_focus_cam.fov = start_fov
	_wall_focus_cam.current = true

	var dest_pos: Vector3 = targets["cam_pos"]
	var look_pos: Vector3 = targets["look"]
	var end_basis := Transform3D(Basis.IDENTITY, dest_pos).looking_at(look_pos, Vector3.UP).basis.orthonormalized()
	var end_xform := Transform3D(end_basis, dest_pos)

	_wall_focus_tween = create_tween().set_parallel(true)
	_wall_focus_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(_wall_focus_cam):
			_wall_focus_cam.global_transform = start_xform.interpolate_with(end_xform, t)
	, 0.0, 1.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_wall_focus_tween.tween_property(_wall_focus_cam, "fov", float(targets["fov"]), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _release_wall_clock_focus(smooth_return: bool = true) -> void:
	if _wall_focus_idx == 0:
		return
	if _wall_focus_tween and _wall_focus_tween.is_valid():
		_wall_focus_tween.kill()

	var rig := _find_wall_camera_rig()
	if not smooth_return or not is_inside_tree() or not is_instance_valid(_wall_focus_cam) or not is_instance_valid(_wall_focus_prev_cam):
		if is_instance_valid(_wall_focus_cam):
			_wall_focus_cam.queue_free()
		_wall_focus_cam = null
		_wall_focus_idx = 0
		_wall_focus_exiting = false
		if smooth_return:
			if is_instance_valid(_wall_focus_prev_cam):
				_wall_focus_prev_cam.current = true
			if rig and "_is_focusing" in rig:
				rig.set("_is_focusing", false)
			_sync_wall_prompt_visibility(false)
		return

	_wall_focus_exiting = true
	var start_xform := _wall_focus_cam.global_transform
	var target_fov := _wall_focus_prev_cam.fov

	_wall_focus_tween = create_tween().set_parallel(true)
	_wall_focus_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(_wall_focus_cam) and is_instance_valid(_wall_focus_prev_cam):
			_wall_focus_cam.global_transform = start_xform.interpolate_with(_wall_focus_prev_cam.global_transform, t)
	, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wall_focus_tween.tween_property(_wall_focus_cam, "fov", target_fov, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wall_focus_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_wall_focus_prev_cam):
			_wall_focus_prev_cam.current = true
		if is_instance_valid(_wall_focus_cam):
			_wall_focus_cam.queue_free()
		_wall_focus_cam = null
		_wall_focus_idx = 0
		_wall_focus_exiting = false
		if rig and "_is_focusing" in rig:
			rig.set("_is_focusing", false)
		_sync_wall_prompt_visibility(false)
	)


func _physics_process(_delta: float) -> void:
	if not _wall_mode or Engine.is_editor_hint():
		return
	if _player_in_safe_bounds and not player_in_safe_room and _player and is_instance_valid(_player):
		if _player.global_position.x <= safe_room_entry_threshold_x:
			_activate_safe_room_entry()


func _bind_safe_room_zone(zone: Area3D) -> void:
	if zone == null:
		return
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitoring = true
	zone.monitorable = false
	if not zone.body_entered.is_connected(_on_safe_room_body_entered):
		zone.body_entered.connect(_on_safe_room_body_entered)
	if not zone.body_exited.is_connected(_on_safe_room_body_exited):
		zone.body_exited.connect(_on_safe_room_body_exited)


func _bind_clock_interact_zone(zone: Area3D, clock_idx: int) -> Label3D:
	if zone == null:
		return null
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitoring = true
	zone.monitorable = false
	var enter_cb: Callable = _on_wall_zone_l1_entered if clock_idx == 1 else (_on_wall_zone_l2_entered if clock_idx == 2 else _on_inner_clock_zone_entered)
	var exit_cb: Callable = _on_wall_zone_l1_exited if clock_idx == 1 else (_on_wall_zone_l2_exited if clock_idx == 2 else _on_inner_clock_zone_exited)
	if not zone.body_entered.is_connected(enter_cb):
		zone.body_entered.connect(enter_cb)
	if not zone.body_exited.is_connected(exit_cb):
		zone.body_exited.connect(exit_cb)
	var prompt_offset := Vector3(0.0, 2.25, 0.25) if clock_idx == 3 else Vector3(0.0, 1.45, 0.5)
	return Ch2Utils.create_prompt_label(zone, prompt_offset)


func _build_rig_for_existing_clock(clock_node: Node3D, play_loop: bool = true) -> Dictionary:
	if clock_node == null:
		return {}
	var hour_node := clock_node.find_child("hour_3", true, false) as Node3D
	var minute_node := clock_node.find_child("minute_1", true, false) as Node3D
	var ap := clock_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		if not Engine.is_editor_hint() and ap.has_animation("Animation"):
			var src_anim := ap.get_animation("Animation")
			var ring_anim := src_anim.duplicate(true) as Animation
			for ti in range(ring_anim.get_track_count() - 1, -1, -1):
				var tpath := String(ring_anim.track_get_path(ti))
				if "hour_3" in tpath or "minute_1" in tpath:
					ring_anim.remove_track(ti)
			ring_anim.loop_mode = Animation.LOOP_LINEAR
			var lib := AnimationLibrary.new()
			lib.add_animation("ring_loop", ring_anim)
			if ap.has_animation_library("puzzle_clock"):
				ap.remove_animation_library("puzzle_clock")
			ap.add_animation_library("puzzle_clock", lib)
			ap.play("puzzle_clock/ring_loop")
			if play_loop:
				ap.speed_scale = 0.32
			else:
				ap.pause()
		else:
			ap.stop()
	return {"root": clock_node, "hour": hour_node, "minute": minute_node, "anim": ap}


func _ensure_clock_light(clock_node: Node3D, col: Color, energy: float) -> OmniLight3D:
	if clock_node == null:
		return null
	var light := clock_node.get_node_or_null("PuzzleClockGlow") as OmniLight3D
	if light == null:
		light = OmniLight3D.new()
		light.name = "PuzzleClockGlow"
		light.position = Vector3(0.0, 0.0, 0.35)
		light.omni_range = 4.5
		clock_node.add_child(light)
	light.light_color = col
	light.light_energy = energy
	return light


func _apply_initial_wall_clock_poses() -> void:
	if _restored_from_save:
		return
	_set_wall_clock_visual_hour(1, current_hour_l1, 0.0)
	_set_wall_clock_visual_hour(2, current_hour_l2, 0.0)
	_sync_inner_clock_pose(0.0)
	_emit_wall_clock_progress()


func _set_wall_clock_visual_hour(clock_idx: int, hour: int, duration: float) -> void:
	var rig: Dictionary = _rig_l1 if clock_idx == 1 else (_rig_l2 if clock_idx == 2 else _rig_inner)
	var h_node := rig.get("hour", null) as Node3D
	var m_node := rig.get("minute", null) as Node3D
	if h_node == null:
		return
	var target_h := 90.0 - float(hour % 12) * 30.0
	var prev_tw: Tween = _tween_l1 if clock_idx == 1 else (_tween_l2 if clock_idx == 2 else _tween_inner)
	if prev_tw and prev_tw.is_valid():
		prev_tw.kill()

	if duration <= 0.0:
		h_node.rotation_degrees = Vector3(0.0, 0.0, target_h)
		if m_node:
			m_node.rotation_degrees = Vector3.ZERO
		return

	var cur_h := h_node.rotation_degrees.z
	var diff_h := fmod(target_h - cur_h, 360.0)
	if diff_h > 0.0:
		diff_h -= 360.0
	if absf(diff_h) < 1.0:
		diff_h = -360.0

	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(h_node, "rotation_degrees:z", cur_h + diff_h, duration)
	if m_node:
		m_node.rotation_degrees.z = 0.0
		tw.tween_property(m_node, "rotation_degrees:z", -360.0, duration)
	if clock_idx == 1:
		_tween_l1 = tw
	elif clock_idx == 2:
		_tween_l2 = tw
	else:
		_tween_inner = tw


func _sync_inner_clock_pose(duration: float) -> void:
	var ap := _rig_inner.get("anim", null) as AnimationPlayer
	if ap and ap.has_animation("puzzle_clock/ring_loop"):
		var ring_anim := ap.get_animation("puzzle_clock/ring_loop")
		ap.play("puzzle_clock/ring_loop")
		ap.pause()
		if ring_anim and ring_anim.length > 0.01:
			var seek_t := (float(inner_step % 12) / 12.0) * ring_anim.length
			ap.seek(seek_t, true)
	_set_wall_clock_visual_hour(3, inner_step, duration)


func _format_step_clock_str(step_val: int) -> String:
	var h := 12 if (step_val % 12) == 0 else (step_val % 12)
	return "%02d:00" % h


func _get_inner_prompt_text() -> String:
	if not _inner_revealed:
		return "[E] Sentuh Jam Antik"
	return "[E] Putar Jam Dalam (Saat ini: %s | Target: %s)" % [
		_format_step_clock_str(inner_step),
		_format_step_clock_str(inner_target_step),
	]


func _hide_inner_clock() -> void:
	_inner_revealed = false
	_inner_revealing = false
	if _clock_inner:
		_clock_inner.visible = false
		_clock_inner.position = _inner_target_pos + Vector3(0.0, 0.0, -0.68)
		_clock_inner.scale = _inner_target_scale * 0.22
	if _inner_light:
		_inner_light.visible = false
		_inner_light.light_energy = 0.0


func _sync_player_inner_hud_hint() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.has_method("set_custom_interact_hint"):
		return
	if _player_in_zone_inner and player_in_safe_room and not inner_solved:
		_player.call("set_custom_interact_hint", _get_inner_prompt_text())
	else:
		_player.call("set_custom_interact_hint", "")


func _refresh_clock_prompts() -> void:
	if _prompt_label:
		_prompt_label.text = "[E] Putar Jam Lt 1 (%d:00)" % current_hour_l1
	if _prompt_label_l2:
		_prompt_label_l2.text = "[E] Putar Jam Lt 2 (%d:00)" % current_hour_l2
	if _prompt_label_inner:
		_prompt_label_inner.text = _get_inner_prompt_text()
	_sync_player_inner_hud_hint()


func _refresh_clock_lights() -> void:
	if is_solved:
		return
	if _l1_light:
		var ok1 := current_hour_l1 == target_hour
		_l1_light.light_color = Color(0.45, 1.0, 0.65) if ok1 else Color(0.55, 0.85, 1.0)
		_l1_light.light_energy = 1.6 if ok1 else 0.7
	if _l2_light:
		var ok2 := current_hour_l2 == target_hour
		_l2_light.light_color = Color(0.45, 1.0, 0.65) if ok2 else Color(1.0, 0.72, 0.35)
		_l2_light.light_energy = 2.0 if ok2 else 1.4


func _emit_wall_clock_progress() -> int:
	var synced := (1 if current_hour_l1 == target_hour else 0) + (1 if current_hour_l2 == target_hour else 0)
	_refresh_clock_lights()
	wall_clock_step_changed.emit(synced, 2, target_hour)
	return synced


func _on_wall_dimension_shifted(is_in_memory: bool) -> void:
	if _clock_l2 == null:
		return
	var should_show := true
	if l2_visible_dimension == "Forgotten":
		should_show = not is_in_memory
	elif l2_visible_dimension == "Remembered":
		should_show = is_in_memory
	_l2_active_in_dim = should_show
	_clock_l2.visible = should_show
	if _l2_light:
		_l2_light.visible = should_show
	if _interact_zone_l2:
		_interact_zone_l2.set_deferred("monitoring", should_show and not is_solved)
	if not should_show:
		_player_in_zone_l2 = false
		if _prompt_label_l2:
			_prompt_label_l2.visible = false
		if _wall_focus_idx == 2 and not _in_door_cutscene:
			_release_wall_clock_focus(true)


func _is_player_node(body: Node) -> bool:
	return body is CharacterBody3D and (body.name == "Player" or body.is_in_group("player"))


func _on_wall_zone_l1_entered(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player = body as CharacterBody3D
	_player_in_zone = true
	if _prompt_label and not is_solved:
		_prompt_label.visible = true
		_emit_wall_clock_progress()


func _on_wall_zone_l1_exited(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player_in_zone = false
	if _prompt_label:
		_prompt_label.visible = false


func _on_wall_zone_l2_entered(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player = body as CharacterBody3D
	_player_in_zone_l2 = true
	if _prompt_label_l2 and _l2_active_in_dim and not is_solved:
		_prompt_label_l2.visible = true
		_emit_wall_clock_progress()


func _on_wall_zone_l2_exited(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player_in_zone_l2 = false
	if _prompt_label_l2:
		_prompt_label_l2.visible = false


func _on_inner_clock_zone_entered(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player = body as CharacterBody3D
	_player_in_zone_inner = true
	if _prompt_label_inner and player_in_safe_room and not inner_solved:
		_prompt_label_inner.visible = true
	_sync_player_inner_hud_hint()


func _on_inner_clock_zone_exited(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player_in_zone_inner = false
	if _prompt_label_inner:
		_prompt_label_inner.visible = false
	_sync_player_inner_hud_hint()


func _on_safe_room_body_entered(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player = body as CharacterBody3D
	_player_in_safe_bounds = true
	if not player_in_safe_room and _player.global_position.x <= safe_room_entry_threshold_x:
		_activate_safe_room_entry()


func _on_safe_room_body_exited(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player_in_safe_bounds = false
	if player_in_safe_room:
		_handle_safe_room_exit()


func _activate_safe_room_entry() -> void:
	if player_in_safe_room:
		return
	player_in_safe_room = true
	if _player and is_instance_valid(_player):
		_player.set("is_in_safe_room", true)
		if not _player.is_in_group("safe_room_player"):
			_player.add_to_group("safe_room_player")
	if _double_door and _double_door.has_method("close_and_lock"):
		_double_door.call("close_and_lock")
	_reset_inner_clock_for_entry()
	safe_room_state_changed.emit(true)


func _reset_inner_clock_for_entry() -> void:
	inner_solved = false
	inner_step = posmod(inner_start_step, 12)
	_sync_inner_clock_pose(0.0)
	_hide_inner_clock()
	if _inner_clock_zone:
		_inner_clock_zone.set_deferred("monitoring", true)
	if _inner_light:
		_inner_light.light_color = Color(1.0, 0.78, 0.42)
	_refresh_clock_prompts()
	if _prompt_label_inner and _player_in_zone_inner:
		_prompt_label_inner.visible = true


func _handle_safe_room_exit() -> void:
	if not player_in_safe_room:
		return
	player_in_safe_room = false
	_inner_revealing = false
	_in_door_cutscene = false
	if _wall_focus_idx == 3:
		_release_wall_clock_focus(false)
	Ch2Utils.set_player_cutscene_lock(_player, false)
	if _player and is_instance_valid(_player):
		_player.set("is_in_safe_room", false)
		if _player.is_in_group("safe_room_player"):
			_player.remove_from_group("safe_room_player")
	_player_in_zone_inner = false
	if _prompt_label_inner:
		_prompt_label_inner.visible = false
	_sync_player_inner_hud_hint()
	if _double_door and _double_door.has_method("close_and_lock"):
		_double_door.call("close_and_lock")
	reset_wall_clocks_puzzle()
	safe_room_state_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _wall_mode or Engine.is_editor_hint():
		return
	if Ch2Utils.is_player_busy(_player):
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	if _player_in_zone_inner and player_in_safe_room and not inner_solved:
		get_viewport().set_input_as_handled()
		advance_inner_clock()
	elif not is_solved and _player_in_zone:
		get_viewport().set_input_as_handled()
		advance_wall_clock(1)
	elif not is_solved and _player_in_zone_l2 and _l2_active_in_dim:
		get_viewport().set_input_as_handled()
		advance_wall_clock(2)


func advance_inner_clock() -> void:
	if not _wall_mode or not player_in_safe_room or inner_solved or _inner_revealing:
		return
	if not _inner_revealed:
		_play_inner_clock_emerge_cutscene()
		return
	_enter_wall_clock_focus(3)
	var anim_dur := 0.0 if DisplayServer.get_name() == "headless" else 0.36
	inner_step = (inner_step + 1) % 12
	_sync_inner_clock_pose(anim_dur)
	_refresh_clock_prompts()
	_play_wall_clock_sfx(false)
	var solved_now := (inner_step == inner_target_step)
	inner_clock_step_changed.emit(inner_step, inner_target_step, solved_now)
	if solved_now:
		_solve_inner_clock()


func _play_inner_clock_emerge_cutscene() -> void:
	if _clock_inner == null or _inner_revealing or _inner_revealed:
		return
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		_clock_inner.position = _inner_target_pos
		_clock_inner.scale = _inner_target_scale
		_clock_inner.visible = true
		if _inner_light:
			_inner_light.visible = true
			_inner_light.light_energy = 1.2
		_inner_revealed = true
		_refresh_clock_prompts()
		return

	_inner_revealing = true
	_in_door_cutscene = true
	Ch2Utils.set_player_cutscene_lock(_player, true)
	_enter_wall_clock_focus(3)

	await get_tree().create_timer(0.28).timeout
	if not is_inside_tree() or not is_instance_valid(_clock_inner):
		return

	_clock_inner.visible = true
	if _inner_light:
		_inner_light.visible = true
		_inner_light.light_energy = 0.0
	_play_wall_clock_sfx(true)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_clock_inner, "position", _inner_target_pos, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_clock_inner, "scale", _inner_target_scale, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _inner_light:
		tw.tween_property(_inner_light, "light_energy", 2.8, 0.60).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(_inner_light, "light_energy", 1.2, 0.55).set_trans(Tween.TRANS_SINE)

	await tw.finished
	if not is_inside_tree():
		return

	_inner_revealed = true
	_inner_revealing = false
	_in_door_cutscene = false
	_wall_focus_timer = wall_focus_idle_seconds
	Ch2Utils.set_player_cutscene_lock(_player, false)
	_refresh_clock_prompts()


func _solve_inner_clock() -> void:
	if inner_solved:
		return
	inner_solved = true
	if _prompt_label_inner:
		_prompt_label_inner.visible = false
	_sync_player_inner_hud_hint()
	if _inner_clock_zone:
		_inner_clock_zone.set_deferred("monitoring", false)
	if _inner_light:
		_inner_light.light_color = Color(0.45, 1.0, 0.65)
		_inner_light.light_energy = 4.2
		var tw := create_tween()
		tw.tween_property(_inner_light, "light_energy", 1.8, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play_wall_clock_sfx(true)
	_play_l2_double_door_cutscene(true)


func reset_wall_clocks_puzzle() -> void:
	if not _wall_mode:
		return
	var old_target := target_hour
	var candidates: Array[int] = [3, 6, 9, 12, 2, 4, 8, 10]
	candidates.erase(old_target)
	target_hour = candidates[randi() % candidates.size()]
	current_hour_l1 = ((target_hour - 1 + 9) % 12) + 1
	current_hour_l2 = ((target_hour - 1 + 7) % 12) + 1
	is_solved = false
	_set_wall_clock_visual_hour(1, current_hour_l1, 0.0)
	_set_wall_clock_visual_hour(2, current_hour_l2, 0.0)
	if _interact_zone:
		_interact_zone.set_deferred("monitoring", true)
	if _interact_zone_l2:
		_interact_zone_l2.set_deferred("monitoring", _l2_active_in_dim)
	_refresh_clock_prompts()
	_emit_wall_clock_progress()
	wall_clocks_reset.emit(target_hour)


func advance_wall_clock(clock_idx: int) -> void:
	if not _wall_mode or is_solved:
		return
	_enter_wall_clock_focus(clock_idx)
	var anim_dur := 0.0 if DisplayServer.get_name() == "headless" else 0.36
	if clock_idx == 1:
		current_hour_l1 = ((current_hour_l1 - 1 + hour_step) % 12) + 1
		_set_wall_clock_visual_hour(1, current_hour_l1, anim_dur)
	else:
		current_hour_l2 = ((current_hour_l2 - 1 + hour_step) % 12) + 1
		_set_wall_clock_visual_hour(2, current_hour_l2, anim_dur)

	_refresh_clock_prompts()
	_play_wall_clock_sfx(false)
	var synced := _emit_wall_clock_progress()
	if synced >= 2:
		_solve_wall_clocks()


func _solve_wall_clocks() -> void:
	if is_solved:
		return
	is_solved = true
	if _prompt_label:
		_prompt_label.visible = false
	if _prompt_label_l2:
		_prompt_label_l2.visible = false
	if _interact_zone:
		_interact_zone.set_deferred("monitoring", false)
	if _interact_zone_l2:
		_interact_zone_l2.set_deferred("monitoring", false)

	for glow in [_l1_light, _l2_light]:
		if glow:
			glow.light_color = Color(0.45, 1.0, 0.65)
			glow.light_energy = 4.2
			var tw := create_tween()
			tw.tween_property(glow, "light_energy", 1.8, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_play_wall_clock_sfx(true)
	puzzle_completed.emit()
	_play_l2_double_door_cutscene(false)


func _play_l2_double_door_cutscene(from_inside: bool) -> void:
	if _double_door == null:
		return
	_in_door_cutscene = true
	var door_pos := _double_door.global_position
	var look_target := Vector3(door_pos.x, 8.6, door_pos.z)
	var cam_start := Vector3(door_pos.x - 6.6, 9.5, door_pos.z + 1.4) if from_inside else Vector3(door_pos.x + 6.9, 9.8, door_pos.z + 1.85)
	var cam_end := Vector3(door_pos.x - 4.0, 9.0, door_pos.z + 0.65) if from_inside else Vector3(door_pos.x + 4.5, 9.1, door_pos.z + 0.75)
	await Ch2Utils.play_door_open_cutscene(
		self,
		_double_door,
		cam_start,
		cam_end,
		look_target,
		0.65,
		1.4,
		1.65,
		func() -> void:
			_release_wall_clock_focus(false)
	)
	_in_door_cutscene = false


func _play_wall_clock_sfx(is_chime: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var sample_rate := 22050
	var dur := 0.55 if is_chime else 0.08
	var frames := int(sample_rate * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * (5.5 if is_chime else 42.0))
		var sig := (sin(TAU * 523.25 * t) * 0.6 + sin(TAU * 783.99 * t) * 0.4) if is_chime else sin(TAU * 920.0 * t)
		var val := int(clampf(sig * env * 0.35, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data

	var asp := AudioStreamPlayer.new()
	asp.stream = wav
	asp.volume_db = -4.0 if is_chime else -9.0
	add_child(asp)
	asp.finished.connect(func() -> void:
		if is_instance_valid(asp):
			asp.queue_free()
	)
	asp.play()


func restore_state(solved: bool, rem_hour: int, forg_hour: int) -> void:
	if _wall_mode:
		return
	is_solved = solved
	if _clock_rem:
		_clock_rem.set("current_hour", clampi(rem_hour, 1, 12))
		if solved:
			_clock_rem.call("lock_synced")
		else:
			_clock_rem.call("_apply_hand_rotation", true)
	if _clock_forg:
		_clock_forg.set("current_hour", clampi(forg_hour, 1, 12))
		if solved:
			_clock_forg.call("lock_synced")
		else:
			_clock_forg.call("_apply_hand_rotation", true)
	if solved:
		var door := get_node_or_null(door_node_path) as Node3D
		if door == null and get_tree() and get_tree().current_scene:
			door = get_tree().current_scene.find_child("pintu2", true, false) as Node3D
		if door and door.has_method("unlock_and_open"):
			door.call("unlock_and_open")
	_emit_progress()


func restore_wall_state(data: Dictionary) -> void:
	if not _wall_mode:
		return
	_restored_from_save = true
	target_hour = clampi(int(data.get("wall_target_hour", target_hour)), 1, 12)
	current_hour_l1 = clampi(int(data.get("wall_hour_l1", current_hour_l1)), 1, 12)
	current_hour_l2 = clampi(int(data.get("wall_hour_l2", current_hour_l2)), 1, 12)
	is_solved = bool(data.get("wall_clocks_solved", false))
	_set_wall_clock_visual_hour(1, current_hour_l1, 0.0)
	_set_wall_clock_visual_hour(2, current_hour_l2, 0.0)
	if is_solved:
		if _interact_zone:
			_interact_zone.set_deferred("monitoring", false)
		if _interact_zone_l2:
			_interact_zone_l2.set_deferred("monitoring", false)
		for glow in [_l1_light, _l2_light]:
			if glow:
				glow.light_color = Color(0.45, 1.0, 0.65)
				glow.light_energy = 1.8
	inner_step = clampi(int(data.get("inner_step", inner_step)), 0, 11)
	inner_solved = bool(data.get("inner_solved", false))
	_inner_revealed = bool(data.get("inner_revealed", false)) or inner_solved
	player_in_safe_room = bool(data.get("player_in_safe_room", false))
	if _inner_revealed and _clock_inner:
		_clock_inner.position = _inner_target_pos
		_clock_inner.scale = _inner_target_scale
		_clock_inner.visible = true
		if _inner_light:
			_inner_light.visible = true
			_inner_light.light_color = Color(0.45, 1.0, 0.65) if inner_solved else Color(1.0, 0.78, 0.42)
			_inner_light.light_energy = 1.8 if inner_solved else 1.2
	else:
		_hide_inner_clock()
	_sync_inner_clock_pose(0.0)
	if _inner_clock_zone:
		_inner_clock_zone.set_deferred("monitoring", not inner_solved)
	if _double_door:
		var door_should_open := (player_in_safe_room and inner_solved) or (not player_in_safe_room and is_solved)
		if door_should_open and _double_door.has_method("unlock_and_open"):
			_double_door.call("unlock_and_open")
		elif not door_should_open and _double_door.has_method("close_and_lock"):
			_double_door.call("close_and_lock")
	if _player and is_instance_valid(_player):
		_player.set("is_in_safe_room", player_in_safe_room)
		if player_in_safe_room and not _player.is_in_group("safe_room_player"):
			_player.add_to_group("safe_room_player")
		elif not player_in_safe_room and _player.is_in_group("safe_room_player"):
			_player.remove_from_group("safe_room_player")
	_refresh_clock_prompts()
	_emit_wall_clock_progress()
	inner_clock_step_changed.emit(inner_step, inner_target_step, inner_solved)
