extends CharacterBody3D
class_name TheEraser

## TheEraser — AI Pengejar & Mekanik "Memory Theft" untuk Chapter 2.
## Arsitektur berlapis (game-ai): Perceive (timer + raycast stealth) -> Decide (FSM)
## -> Path (NavigationAgent3D) -> Steer (CharacterBody3D) -> Animate (AnimationTree).

signal state_changed(new_state: int)
signal player_hit(player: CharacterBody3D, stole_item: bool)
signal memory_theft_triggered(item: RigidBody3D, target_in_memory: bool, anchor_pos: Vector3)

enum State { PATROL, CHASE, INVESTIGATE, ATTACK, STUNNED, CUTSCENE }

@export_group("Patrol & Movement")
@export var patrol_waypoints: Array[NodePath] = []
@export var patrol_speed: float = 1.65
@export var chase_speed: float = 3.25
@export var turn_speed: float = 8.5
@export var waypoint_pause_seconds: float = 0.9
@export var stuck_timeout_seconds: float = 1.2
@export var stuck_min_progress: float = 0.15

@export_group("Perception & Stealth")
@export var detect_radius_standing: float = 13.0
@export var detect_radius_crouching: float = 4.0
@export var lose_target_radius: float = 17.5
@export var sight_half_angle_deg: float = 82.0
@export var sense_interval_seconds: float = 0.12
@export var repath_interval_seconds: float = 0.25
@export var close_hide_spot_distance: float = 3.5
@export var investigate_duration: float = 2.5

@export_group("Attack & Memory Theft")
@export var attack_trigger_distance: float = 2.35
@export var attack_duration: float = 1.7
@export var stun_duration: float = 1.1
@export var attack_cooldown_seconds: float = 0.6
@export var remembered_anchor: NodePath = NodePath("")
@export var forgotten_anchor: NodePath = NodePath("")

@export_group("Jumpscare & Consciousness Blackout")
@export var jumpscare_duration: float = 2.2
@export var jumpscare_push_distance: float = 0.25
@export var blackout_close_duration: float = 0.25
@export var blackout_hold_duration: float = 0.85
@export var wakeup_duration: float = 1.0
@export var post_hit_grace_seconds: float = 2.0
@export var knockback_distance: float = 2.6
@export var jumpscare_stinger: AudioStream = null

@export_group("Dimension Sync")
@export_enum("Always", "Remembered", "Forgotten") var active_dimension: String = "Always"

@export_group("Floor Teleport & Tactical Blink")
@export var floor_diff_threshold: float = 2.2
@export var floor_tp_delay_seconds: float = 1.5
@export var tp_min_safe_distance: float = 5.5
@export var tp_max_safe_distance: float = 9.5
@export var tactical_tp_distance: float = 11.0
@export var tactical_tp_min_offscreen_dist: float = 6.5
@export var tactical_tp_cooldown_min: float = 6.0
@export var tactical_tp_cooldown_max: float = 9.0
@export var teleport_reaction_pause: float = 0.5

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@onready var hitbox_area: Area3D = get_node_or_null("HitboxArea") as Area3D
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var anim_tree: AnimationTree = get_node_or_null("AnimationTree") as AnimationTree
@onready var visual_model: Node3D = get_node_or_null("VisualModel") as Node3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var jumpscare_cam_point: Marker3D = get_node_or_null("JumpscareCamPoint") as Marker3D
@onready var jumpscare_face_light: Light3D = find_child("JumpscareFaceLight", true, false) as Light3D

var current_state: int = State.PATROL

var _playback: AnimationNodeStateMachinePlayback = null
var _player: CharacterBody3D = null
var _carry_system: Node = null
var _world_manager: Node = null
var _camera_rig: Node = null
var _is_in_memory: bool = true

var _waypoints: Array[Marker3D] = []
var _waypoint_idx: int = 0
var _anchor_remembered: Marker3D = null
var _anchor_forgotten: Marker3D = null

# Blackboard fakta persepsi (diupdate oleh sensor berkala)
var _can_see_player: bool = false
var _last_known_pos: Vector3 = Vector3.ZERO
var _player_crouching: bool = false

# Timer internal & anti-flicker / anti-stuck
var _sense_timer: float = 0.0
var _repath_timer: float = 0.0
var _pause_timer: float = 0.0
var _lost_sight_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _stun_timer: float = 0.0
var _state_time: float = 0.0
var _stuck_timer: float = 0.0
var _last_stuck_check_pos: Vector3 = Vector3.ZERO
var _hit_checked_this_swing: bool = false
var _is_hit_sequence_active: bool = false
var _waiting_at_waypoint: bool = false
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _stuck_sidestep_sign: float = 1.0
var _was_player_hidden: bool = false
var _spotted_player_hiding: bool = false
var _investigate_timer: float = 0.0
var _investigate_arrived: bool = false
var _investigate_base_yaw: float = 0.0
var _investigate_search_time: float = 0.0

var _top_eyelid: ColorRect = null
var _bottom_eyelid: ColorRect = null
var _skeleton: Skeleton3D = null
var _head_bone_idx: int = -1
var _jumpscare_active: bool = false
var _jumpscare_elapsed: float = 0.0
var _active_jumpscare_cam: Camera3D = null

var _floor1_anchors: Array[Marker3D] = []
var _floor2_anchors: Array[Marker3D] = []
var _hide_spot_nodes: Array[Node3D] = []
var _safe_room_zone: Area3D = null
var _safe_door: Node3D = null
var _safe_room_wait_timer: float = 0.0
var _at_safe_room_door: bool = false
var _diff_floor_timer: float = 0.0
var _tactical_tp_cooldown: float = 4.0
var _is_teleporting: bool = false

# Daftar item yang sedang dipindahkan oleh Memory Theft: [{ "item": RigidBody3D, "target_in_memory": bool }]
var _stolen_items: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("eraser_ai")
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	safe_margin = 0.04

	if jumpscare_face_light == null:
		jumpscare_face_light = find_child("JumpscareFaceLight", true, false) as Light3D
	if jumpscare_face_light:
		jumpscare_face_light.light_energy = 0.0
		jumpscare_face_light.shadow_enabled = false

	_resolve_skeleton_head()
	_disable_nested_model_anim_player()
	_setup_animation_tree()
	_setup_nav_agent()
	_resolve_world_manager()
	_resolve_player_and_carry()
	_resolve_camera_rig()
	_resolve_waypoints_and_anchors()
	_resolve_consciousness_eyelids()

	_last_stuck_check_pos = global_position
	_change_state(State.PATROL)
	var init_wps := _get_floor_waypoints()
	if not init_wps.is_empty():
		_set_nav_target(init_wps[0].global_position)


func _exit_tree() -> void:
	_set_camera_chase_shake(0.0)


func _resolve_camera_rig() -> void:
	if _camera_rig and is_instance_valid(_camera_rig):
		return
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		_camera_rig = scene.find_child("CameraRig", true, false)
	if _camera_rig == null and get_tree():
		_camera_rig = get_tree().root.find_child("CameraRig", true, false)


func _set_camera_chase_shake(intensity: float) -> void:
	_resolve_camera_rig()
	if _camera_rig and "chase_shake_intensity" in _camera_rig:
		_camera_rig.set("chase_shake_intensity", clampf(intensity, 0.0, 1.0))


func _resolve_skeleton_head() -> void:
	if visual_model == null:
		return
	_skeleton = visual_model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_head_bone_idx = _skeleton.find_bone("mixamorig_Head")
		if _head_bone_idx < 0:
			_head_bone_idx = _skeleton.find_bone("Head")


func _process(delta: float) -> void:
	if _jumpscare_active:
		_update_jumpscare_frame(delta)


func _setup_nav_agent() -> void:
	if nav_agent == null:
		return
	if not nav_agent.velocity_computed.is_connected(_on_nav_velocity_computed):
		nav_agent.velocity_computed.connect(_on_nav_velocity_computed)


func _on_nav_velocity_computed(safe_vel: Vector3) -> void:
	_safe_velocity = safe_vel
	_has_safe_velocity = true


func _disable_nested_model_anim_player() -> void:
	if visual_model == null:
		return
	var nested_ap := visual_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if nested_ap:
		nested_ap.stop()
		nested_ap.active = false


func _setup_animation_tree() -> void:
	if anim_tree == null:
		return
	anim_tree.active = true
	_playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _playback:
		_playback.start(&"Idle")


func _resolve_world_manager() -> void:
	var cur := get_parent()
	while cur:
		if cur.has_signal("dimension_shifted"):
			_world_manager = cur
			break
		cur = cur.get_parent()
	if _world_manager == null and get_tree() and get_tree().current_scene:
		var root := get_tree().current_scene
		if root.has_signal("dimension_shifted"):
			_world_manager = root

	if _world_manager:
		if not _world_manager.is_connected("dimension_shifted", Callable(self, "_on_dimension_shifted")):
			_world_manager.connect("dimension_shifted", Callable(self, "_on_dimension_shifted"))
		if "in_memory" in _world_manager:
			_on_dimension_shifted(bool(_world_manager.get("in_memory")))


func _resolve_player_and_carry() -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		_player = scene.find_child("Player", true, false) as CharacterBody3D
	if _player == null and get_tree():
		_player = get_tree().root.find_child("Player", true, false) as CharacterBody3D

	if _player:
		var cs_prop: Variant = _player.get("carry_system")
		if cs_prop is Node:
			_carry_system = cs_prop as Node
		if _carry_system == null:
			_carry_system = _player.get_node_or_null("CarrySystem")
	if _carry_system == null and scene:
		_carry_system = scene.find_child("CarrySystem", true, false)
	if _carry_system == null and get_tree():
		_carry_system = get_tree().root.find_child("CarrySystem", true, false)

	if _carry_system and _carry_system.has_signal("item_picked_up"):
		if not _carry_system.is_connected("item_picked_up", Callable(self, "_on_carry_item_picked_up")):
			_carry_system.connect("item_picked_up", Callable(self, "_on_carry_item_picked_up"))


func _resolve_waypoints_and_anchors() -> void:
	_waypoints.clear()
	for wp_path in patrol_waypoints:
		var node := get_node_or_null(wp_path) as Marker3D
		if node:
			_waypoints.append(node)

	if _waypoints.is_empty() and get_tree():
		for n in get_tree().get_nodes_in_group("eraser_waypoint"):
			if n is Marker3D:
				_waypoints.append(n as Marker3D)

	if _waypoints.is_empty() and get_tree() and get_tree().current_scene:
		var wp_container := get_tree().current_scene.find_child("TheEraserWaypoints", true, false)
		if wp_container:
			for ch in wp_container.get_children():
				if ch is Marker3D:
					_waypoints.append(ch as Marker3D)

	if not remembered_anchor.is_empty():
		_anchor_remembered = get_node_or_null(remembered_anchor) as Marker3D
	if not forgotten_anchor.is_empty():
		_anchor_forgotten = get_node_or_null(forgotten_anchor) as Marker3D

	if get_tree() and get_tree().current_scene:
		var scene := get_tree().current_scene
		if _anchor_remembered == null:
			_anchor_remembered = scene.find_child("AnchorRemembered", true, false) as Marker3D
		if _anchor_forgotten == null:
			_anchor_forgotten = scene.find_child("AnchorForgotten", true, false) as Marker3D
		_resolve_floor_anchors_from(scene.find_child("Floor1_Anchors", true, false), _floor1_anchors)
		_resolve_floor_anchors_from(scene.find_child("Floor2_Anchors", true, false), _floor2_anchors)
		_safe_room_zone = scene.find_child("SafeRoomZone", true, false) as Area3D
		_safe_door = scene.find_child("TembokKebelahDepan", true, false) as Node3D
		_hide_spot_nodes.clear()
		for spot_name in ["TableHideZone", "WardrobeHideSpot", "HideInsidePoint"]:
			var sn := scene.find_child(spot_name, true, false) as Node3D
			if sn:
				_hide_spot_nodes.append(sn)


func _resolve_floor_anchors_from(container: Node, out_list: Array[Marker3D]) -> void:
	out_list.clear()
	if container == null:
		return
	for ch in container.get_children():
		if ch is Marker3D:
			out_list.append(ch as Marker3D)


func _is_dimension_active() -> bool:
	match active_dimension:
		"Remembered":
			return _is_in_memory
		"Forgotten":
			return not _is_in_memory
		_:
			return true


func _on_dimension_shifted(is_in_memory: bool) -> void:
	_is_in_memory = is_in_memory
	var dim_active := true if _jumpscare_active else _is_dimension_active()
	visible = dim_active
	if collision_shape:
		collision_shape.set_deferred("disabled", not dim_active)
	if hitbox_area:
		hitbox_area.set_deferred("monitoring", dim_active)

	if not dim_active:
		_can_see_player = false
		_diff_floor_timer = 0.0
		_is_teleporting = false
		velocity = Vector3.ZERO
		_travel_anim(&"Idle")
		_set_camera_chase_shake(0.0)

	_sync_stolen_items_visibility()


func _on_carry_item_picked_up(item: RigidBody3D) -> void:
	# Jika pemain sudah mengambil kembali item dari dimensi seberang, hentikan override Memory Theft
	for i in range(_stolen_items.size() - 1, -1, -1):
		if _stolen_items[i].get("item") == item:
			_stolen_items.remove_at(i)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player_and_carry()

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	if not _is_dimension_active():
		velocity.x = 0.0
		velocity.z = 0.0
		_set_camera_chase_shake(0.0)
		move_and_slide()
		return

	if _is_teleporting:
		velocity.x = 0.0
		velocity.z = 0.0
		if nav_agent and nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		move_and_slide()
		return

	_state_time += delta
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = sense_interval_seconds
		_update_perception()

	_update_floor_and_tactical_teleport(delta)
	if _is_teleporting:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.ATTACK:
			_process_attack(delta)
		State.STUNNED:
			_process_stunned(delta)
		State.CUTSCENE:
			_process_cutscene(delta)

	move_and_slide()
	if global_position.y >= 5.0 and global_position.x < 59.35 and (_is_player_in_safe_room() or _is_safe_door_locked()):
		global_position.x = 59.35
		velocity.x = maxf(velocity.x, 0.0)


func _is_player_in_safe_room() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if "is_in_safe_room" in _player and bool(_player.get("is_in_safe_room")):
		return true
	return _player.is_in_group("safe_room_player")


func _is_safe_door_locked() -> bool:
	if _safe_door and is_instance_valid(_safe_door) and "requires_relic_unlock" in _safe_door:
		return bool(_safe_door.get("requires_relic_unlock"))
	return false


func _is_point_in_safe_room(world_pos: Vector3) -> bool:
	if _safe_room_zone and is_instance_valid(_safe_room_zone):
		var col := _safe_room_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			var half := (col.shape as BoxShape3D).size * 0.5
			var local_pt := col.global_transform.affine_inverse() * world_pos
			return absf(local_pt.x) <= half.x + 0.35 and absf(local_pt.y) <= half.y + 0.5 and absf(local_pt.z) <= half.z + 0.35
	return world_pos.y >= 5.0 and world_pos.x <= 59.05


func _get_safe_room_door_outer_pos() -> Vector3:
	if _safe_door and is_instance_valid(_safe_door):
		var p := _safe_door.global_position
		return Vector3(p.x + 1.35, maxf(global_position.y, 6.2), p.z)
	return Vector3(60.2, maxf(global_position.y, 6.2), 0.225)


func _is_player_hidden() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if "is_hidden" in _player and bool(_player.get("is_hidden")):
		return true
	return _player.is_in_group("hidden_player")


## Dipanggil saat player mulai masuk ke tempat sembunyi (lemari / kolong meja).
## Jika monster aktif dan melihat langsung proses masuk dari jarak dekat (< 3.5m), player tetap ketahuan.
func notify_player_hide_started(entry_world_pos: Vector3) -> void:
	_was_player_hidden = true
	if not _is_dimension_active() or _is_hit_sequence_active:
		_spotted_player_hiding = false
		return

	var dist := global_position.distance_to(entry_world_pos)
	if dist < close_hide_spot_distance and _can_see_entry_point(entry_world_pos):
		_spotted_player_hiding = true
		_last_known_pos = entry_world_pos
	else:
		_spotted_player_hiding = false


func _can_see_entry_point(entry_pos: Vector3) -> bool:
	var to_entry := entry_pos - global_position
	var flat_dist := Vector2(to_entry.x, to_entry.z).length()
	if current_state != State.CHASE and flat_dist > 1.8:
		var forward := global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var dir := Vector3(to_entry.x, 0.0, to_entry.z).normalized()
		if forward.dot(dir) < cos(deg_to_rad(sight_half_angle_deg)):
			return false

	var space_state := get_world_3d().direct_space_state if get_world_3d() else null
	if space_state == null:
		return false
	var origin := global_position + Vector3(0.0, 1.65, 0.0)
	var exclude: Array[RID] = [get_rid()]
	if _player and is_instance_valid(_player):
		exclude.append(_player.get_rid())
	var target_pt := entry_pos + Vector3(0.0, 0.85, 0.0)
	var query := PhysicsRayQueryParameters3D.create(origin, target_pt, 1)
	query.exclude = exclude
	var hit := space_state.intersect_ray(query)
	return hit.is_empty()


func _update_perception() -> void:
	var currently_hidden := _is_player_hidden()
	if currently_hidden and not _was_player_hidden:
		var entry_pos := _player.global_position if _player and is_instance_valid(_player) else global_position
		notify_player_hide_started(entry_pos)
	elif not currently_hidden:
		_was_player_hidden = false
		_spotted_player_hiding = false

	_can_see_player = _can_detect_player()
	if _can_see_player and _player and is_instance_valid(_player) and not (currently_hidden and not _spotted_player_hiding):
		_last_known_pos = _player.global_position


func _can_detect_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _is_player_in_safe_room():
		return false
	if _is_player_hidden() and not _spotted_player_hiding:
		return false

	_player_crouching = _is_player_crouching()
	var max_dist := detect_radius_crouching if _player_crouching else detect_radius_standing
	if current_state == State.CHASE and not _player_crouching:
		max_dist = lose_target_radius
	elif current_state == State.CHASE and _player_crouching:
		max_dist = detect_radius_crouching * 1.35

	var to_player := _player.global_position - global_position
	var flat_dist_sq := to_player.x * to_player.x + to_player.z * to_player.z
	if flat_dist_sq > max_dist * max_dist:
		return false

	if absf(to_player.y) > 2.6:
		return false

	var proximity_dist := 1.4 if _player_crouching else 2.6
	if flat_dist_sq > proximity_dist * proximity_dist:
		var forward := global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var dir := Vector3(to_player.x, 0.0, to_player.z).normalized()
		var cos_limit := cos(deg_to_rad(sight_half_angle_deg))
		if forward.dot(dir) < cos_limit:
			return false

	return _has_line_of_sight_to_player()


func _is_player_crouching() -> bool:
	if _player and "sedang_jongkok" in _player and bool(_player.get("sedang_jongkok")):
		return true
	return Input.is_action_pressed("jongkok")


func _has_line_of_sight_to_player() -> bool:
	var space_state := get_world_3d().direct_space_state
	if space_state == null or _player == null:
		return false

	var origin := global_position + Vector3(0.0, 1.65, 0.0)
	var exclude: Array[RID] = [get_rid()]
	var carried := _get_carried_item(_player)
	if carried:
		exclude.append(carried.get_rid())

	var chest_offset := 0.55 if _player_crouching else 1.05
	var head_offset := 0.85 if _player_crouching else 1.65
	for h in [chest_offset, head_offset]:
		var target_pt := _player.global_position + Vector3(0.0, h, 0.0)
		var query := PhysicsRayQueryParameters3D.create(origin, target_pt, 1 | 2)
		query.exclude = exclude
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		if hit.get("collider") == _player:
			return true
	return false


func _process_patrol(delta: float) -> void:
	if _can_see_player and _state_time >= 0.3:
		_change_state(State.CHASE)
		return

	var floor_wps := _get_floor_waypoints()
	if floor_wps.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_travel_anim(&"Idle")
		return

	if _waiting_at_waypoint:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_travel_anim(&"Idle")
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_waiting_at_waypoint = false
			_waypoint_idx = (_waypoint_idx + 1) % floor_wps.size()
			_set_nav_target(floor_wps[_waypoint_idx].global_position)
			_stuck_timer = 0.0
			_last_stuck_check_pos = global_position
		return

	if _is_waypoint_reached():
		_waiting_at_waypoint = true
		_pause_timer = waypoint_pause_seconds
		return

	_steer_along_nav(patrol_speed, delta)
	_travel_anim(&"Walk")
	_update_anti_stuck(delta, false)


func _process_chase(delta: float) -> void:
	if _is_player_in_safe_room():
		_set_camera_chase_shake(0.0)
		var outer_door := _get_safe_room_door_outer_pos()
		if absf(outer_door.y - global_position.y) > floor_diff_threshold:
			_change_state(State.PATROL)
			return
		if not _at_safe_room_door:
			var flat_to_door := Vector2(outer_door.x - global_position.x, outer_door.z - global_position.z).length()
			_repath_timer -= delta
			if _repath_timer <= 0.0:
				_repath_timer = repath_interval_seconds
				_set_nav_target(outer_door)
			if flat_to_door <= 1.55 or _state_time >= 2.2:
				_at_safe_room_door = true
				_safe_room_wait_timer = 0.85
			else:
				_steer_along_nav(chase_speed, delta)
				_travel_anim(&"Chase")
				return
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		if nav_agent and nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		_travel_anim(&"Idle")
		_face_point(Vector3(58.85, global_position.y, outer_door.z), delta, turn_speed)
		_safe_room_wait_timer -= delta
		if _safe_room_wait_timer <= 0.0:
			_change_state(State.PATROL)
		return

	if _can_see_player:
		_lost_sight_timer = 0.0
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = repath_interval_seconds
			_set_nav_target(_last_known_pos)

		if _player and _attack_cooldown <= 0.0 and _is_player_in_attack_reach():
			_change_state(State.ATTACK)
			return
	else:
		if _is_player_hidden() and not _spotted_player_hiding:
			_change_state(State.INVESTIGATE)
			return
		_lost_sight_timer += delta
		if _state_time >= 0.45 and ((nav_agent and nav_agent.is_navigation_finished()) or _lost_sight_timer >= 2.8):
			_change_state(State.INVESTIGATE)
			return

	var move_spd := chase_speed if _is_in_memory else chase_speed * 1.08
	_steer_along_nav(move_spd, delta)
	_travel_anim(&"Chase")
	_update_anti_stuck(delta, true)

	if _player and is_instance_valid(_player) and _is_dimension_active():
		var dist_to_player := global_position.distance_to(_player.global_position)
		var sight_range := maxf(lose_target_radius, 0.1)
		var proximity := clampf(1.0 - (dist_to_player / sight_range), 0.15, 1.0)
		_set_camera_chase_shake(proximity)
	else:
		_set_camera_chase_shake(0.0)


func _process_investigate(delta: float) -> void:
	if _is_player_in_safe_room():
		_change_state(State.PATROL)
		return
	if _can_see_player:
		_change_state(State.CHASE)
		return

	if not _investigate_arrived:
		var flat_dist := Vector2(_last_known_pos.x - global_position.x, _last_known_pos.z - global_position.z).length()
		if flat_dist <= 1.25 or (nav_agent and nav_agent.is_navigation_finished()) or _state_time >= 4.0:
			_investigate_arrived = true
			_investigate_timer = investigate_duration
			_investigate_search_time = 0.0
			_investigate_base_yaw = rotation.y
		else:
			_steer_along_nav(patrol_speed * 1.15, delta)
			_travel_anim(&"Walk")
			_update_anti_stuck(delta, true)
			return

	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(Vector3.ZERO)
	_travel_anim(&"Idle")

	_investigate_search_time += delta
	var look_yaw := _investigate_base_yaw + sin(_investigate_search_time * 2.4) * deg_to_rad(44.0)
	rotation.y = lerp_angle(rotation.y, look_yaw, clampf(4.5 * delta, 0.0, 1.0))

	_investigate_timer -= delta
	if _investigate_timer <= 0.0:
		_change_state(State.PATROL)


func _update_anti_stuck(delta: float, is_chase: bool) -> void:
	_stuck_timer += delta
	if _stuck_timer < stuck_timeout_seconds:
		return
	var moved := Vector2(global_position.x - _last_stuck_check_pos.x, global_position.z - _last_stuck_check_pos.z).length()
	if moved < stuck_min_progress:
		if is_chase:
			_repath_timer = 0.0
			var target_pos := _last_known_pos
			if nav_agent and nav_agent.get_navigation_map().is_valid():
				target_pos = NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), _last_known_pos)
			_set_nav_target(target_pos)
			var side := global_transform.basis.x * _stuck_sidestep_sign
			side.y = 0.0
			if side.length_squared() > 0.001:
				velocity.x += side.normalized().x * 1.6
				velocity.z += side.normalized().z * 1.6
			_stuck_sidestep_sign *= -1.0
		else:
			var floor_wps := _get_floor_waypoints()
			if not floor_wps.is_empty():
				_waypoint_idx = (_waypoint_idx + 1) % floor_wps.size()
				_set_nav_target(floor_wps[_waypoint_idx].global_position)
	_last_stuck_check_pos = global_position
	_stuck_timer = 0.0


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)

	if _player and is_instance_valid(_player):
		_face_point(_player.global_position, delta, turn_speed * 1.4)

	_attack_timer += delta
	if _attack_timer >= attack_duration:
		_attack_cooldown = attack_cooldown_seconds
		if _can_see_player:
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL)


func _process_stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	if _is_hit_sequence_active:
		return
	_travel_anim(&"Idle")

	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_attack_cooldown = attack_cooldown_seconds
		if _can_see_player:
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL)


var _cutscene_look_target: Vector3 = Vector3.ZERO
var _cutscene_twitch_tween: Tween = null


func _process_cutscene(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if _cutscene_look_target != Vector3.ZERO:
		_face_point(_cutscene_look_target, delta, turn_speed * 1.6)


## Memasuki mode cutscene reveal: menghentikan AI patroli, menghadap player, dan memicu reaksi ancaman.
func enter_cutscene_mode(look_target: Vector3) -> void:
	_cutscene_look_target = look_target
	_can_see_player = false
	velocity = Vector3.ZERO
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(Vector3.ZERO)
	_change_state(State.CUTSCENE)
	_face_point(look_target, 1.0, 1.0)
	_play_reveal_reaction()


func _play_reveal_reaction() -> void:
	if _playback:
		_playback.start(&"Idle")
	if _cutscene_twitch_tween and _cutscene_twitch_tween.is_valid():
		_cutscene_twitch_tween.kill()
	if visual_model:
		visual_model.rotation = Vector3.ZERO
		_cutscene_twitch_tween = create_tween()
		# Gerakan menoleh / kedutan patah-patah khas horor sebelum ancang-ancang mengejar
		_cutscene_twitch_tween.tween_interval(0.35)
		_cutscene_twitch_tween.tween_property(visual_model, "rotation_degrees", Vector3(4.0, -9.0, 6.0), 0.06)
		_cutscene_twitch_tween.tween_property(visual_model, "rotation_degrees", Vector3(-3.0, 11.0, -5.0), 0.07)
		_cutscene_twitch_tween.tween_property(visual_model, "rotation_degrees", Vector3(2.0, -5.0, 3.0), 0.06)
		_cutscene_twitch_tween.tween_property(visual_model, "rotation_degrees", Vector3.ZERO, 0.12)
		_cutscene_twitch_tween.tween_callback(func() -> void:
			if current_state == State.CUTSCENE and _playback:
				_playback.start(&"Attack")
		)


## Keluar dari mode cutscene dan langsung masuk ke pengejaran (CHASE) atau PATROL.
func exit_cutscene_mode(start_chase: bool = true) -> void:
	if _cutscene_twitch_tween and _cutscene_twitch_tween.is_valid():
		_cutscene_twitch_tween.kill()
	if visual_model:
		visual_model.rotation = Vector3.ZERO
	if start_chase:
		if _player == null or not is_instance_valid(_player):
			_resolve_player_and_carry()
		if _player and is_instance_valid(_player):
			_can_see_player = true
			_last_known_pos = _player.global_position
			_change_state(State.CHASE)
			return
	_change_state(State.PATROL)


func _is_player_in_attack_reach() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _is_player_in_safe_room():
		return false
	if _is_player_hidden() and not _spotted_player_hiding:
		return false
	if hitbox_area and hitbox_area.overlaps_body(_player):
		return true
	var to_p := _player.global_position - global_position
	var flat_dist := Vector2(to_p.x, to_p.z).length()
	return flat_dist <= attack_trigger_distance and absf(to_p.y) < 2.2


func _is_waypoint_reached() -> bool:
	if nav_agent == null:
		return true
	if nav_agent.is_navigation_finished():
		return true
	var floor_wps := _get_floor_waypoints()
	if floor_wps.is_empty():
		return true
	var wp_pos := floor_wps[_waypoint_idx % floor_wps.size()].global_position
	var flat_dist := Vector2(wp_pos.x - global_position.x, wp_pos.z - global_position.z).length()
	return flat_dist <= nav_agent.target_desired_distance and absf(wp_pos.y - global_position.y) < 1.8


func _steer_along_nav(speed: float, delta: float) -> void:
	var target_pt := _last_known_pos
	if nav_agent and not nav_agent.is_navigation_finished():
		target_pt = nav_agent.get_next_path_position()
		var flat_to_next := Vector2(target_pt.x - global_position.x, target_pt.z - global_position.z).length()
		if flat_to_next <= 0.25:
			var path := nav_agent.get_current_navigation_path()
			var start_idx := maxi(nav_agent.get_current_navigation_path_index(), 0)
			var found_next := false
			for i in range(start_idx, path.size()):
				var p := path[i]
				if Vector2(p.x - global_position.x, p.z - global_position.z).length() > 0.25:
					target_pt = p
					found_next = true
					break
			if not found_next:
				target_pt = nav_agent.target_position
	elif current_state == State.PATROL:
		var floor_wps := _get_floor_waypoints()
		if not floor_wps.is_empty():
			target_pt = floor_wps[_waypoint_idx % floor_wps.size()].global_position

	var dir := target_pt - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0025:
		dir = dir.normalized()
		var desired_vel := dir * speed
		if nav_agent and nav_agent.avoidance_enabled:
			nav_agent.set_velocity(desired_vel)
			if _has_safe_velocity and Vector2(_safe_velocity.x, _safe_velocity.z).length_squared() > 0.04:
				velocity.x = _safe_velocity.x
				velocity.z = _safe_velocity.z
			else:
				velocity.x = desired_vel.x
				velocity.z = desired_vel.z
		else:
			velocity.x = desired_vel.x
			velocity.z = desired_vel.z
		_face_point(global_position + dir, delta, turn_speed)
	else:
		if nav_agent and nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)


func _face_point(world_pt: Vector3, delta: float, rate: float) -> void:
	var to_pt := world_pt - global_position
	to_pt.y = 0.0
	if to_pt.length_squared() < 0.0001:
		return
	var target_yaw := atan2(to_pt.x, to_pt.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(rate * delta, 0.0, 1.0))


func _set_nav_target(world_pos: Vector3) -> void:
	if nav_agent == null:
		return
	nav_agent.target_position = world_pos


func _change_state(next_state: int) -> void:
	current_state = next_state
	_state_time = 0.0
	_at_safe_room_door = false
	_safe_room_wait_timer = 0.0
	if next_state != State.CHASE:
		_set_camera_chase_shake(0.0)
	match next_state:
		State.PATROL:
			_was_player_hidden = false
			_spotted_player_hiding = false
			_waiting_at_waypoint = false
			_stuck_timer = 0.0
			_last_stuck_check_pos = global_position
			var floor_wps := _get_floor_waypoints()
			if not floor_wps.is_empty():
				_waypoint_idx = _waypoint_idx % floor_wps.size()
				_set_nav_target(floor_wps[_waypoint_idx].global_position)
			_travel_anim(&"Walk")
		State.CHASE:
			_repath_timer = 0.0
			_lost_sight_timer = 0.0
			_set_nav_target(_last_known_pos)
			_travel_anim(&"Chase")
		State.INVESTIGATE:
			_investigate_arrived = false
			_investigate_timer = investigate_duration
			_investigate_search_time = 0.0
			_set_nav_target(_last_known_pos)
			_travel_anim(&"Walk")
		State.ATTACK:
			_attack_timer = 0.0
			_hit_checked_this_swing = false
			if _playback:
				_playback.start(&"Attack")
		State.STUNNED:
			_stun_timer = stun_duration
			if _playback:
				_playback.start(&"Idle")
		State.CUTSCENE:
			_waiting_at_waypoint = false
			if _playback:
				_playback.start(&"Idle")
	state_changed.emit(current_state)


func _travel_anim(state_name: StringName) -> void:
	if _playback == null:
		return
	if _playback.get_current_node() != state_name:
		_playback.travel(state_name)


## Dipanggil oleh Call Method Track pada frame puncak animasi `Attack`.
func execute_hit_check() -> void:
	if _hit_checked_this_swing or _is_hit_sequence_active or current_state != State.ATTACK:
		return
	_hit_checked_this_swing = true

	var hit_player := _find_player_in_hitbox()
	if hit_player == null:
		return

	_is_hit_sequence_active = true
	_run_integrated_hit_sequence(hit_player)


func _resolve_consciousness_eyelids() -> void:
	var scene_root := get_tree().current_scene if get_tree() and get_tree().current_scene else null
	if scene_root == null:
		return
	var layer := scene_root.find_child("ConsciousnessLayer", true, false)
	if layer:
		_top_eyelid = layer.get_node_or_null("TopEyelid") as ColorRect
		_bottom_eyelid = layer.get_node_or_null("BottomEyelid") as ColorRect


func _run_integrated_hit_sequence(hit_player: CharacterBody3D) -> void:
	_resolve_consciousness_eyelids()
	if hit_player and is_instance_valid(hit_player) and hit_player.has_method("force_exit_hiding"):
		hit_player.call("force_exit_hiding")
	_was_player_hidden = false
	_spotted_player_hiding = false
	_set_player_locked(hit_player, true)
	velocity = Vector3.ZERO
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(Vector3.ZERO)

	if is_instance_valid(hit_player):
		_face_point(hit_player.global_position, 1.0, 1.0)

	_change_state(State.STUNNED)
	if _playback:
		_playback.start(&"Attack")

	var scene_root := get_tree().current_scene if get_tree() else null
	var rig := scene_root.find_child("CameraRig", true, false) as Node3D if scene_root else null
	var rig_cam: Camera3D = null
	if rig and "camera" in rig and rig.get("camera") is Camera3D:
		rig_cam = rig.get("camera") as Camera3D
	elif get_viewport():
		rig_cam = get_viewport().get_camera_3d()

	if rig and "is_cutscene_override" in rig:
		rig.set("is_cutscene_override", true)
	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", true)

	# =========================================================================
	# TAHAP 1: 3D JUMPSCARE INTENS (2.2 detik)
	# =========================================================================
	visible = true
	var jumpscare_cam := Camera3D.new()
	jumpscare_cam.name = "JumpscareCam"
	jumpscare_cam.fov = 56.0
	jumpscare_cam.near = 0.05
	add_child(jumpscare_cam)

	_active_jumpscare_cam = jumpscare_cam
	_jumpscare_elapsed = 0.0
	_jumpscare_active = true
	_update_jumpscare_frame(0.0)
	jumpscare_cam.current = true

	if jumpscare_face_light:
		jumpscare_face_light.light_color = Color(0.95, 0.92, 0.88)
		jumpscare_face_light.omni_range = 4.0
		jumpscare_face_light.shadow_enabled = false
		jumpscare_face_light.light_energy = 6.5

	var post_state := _spike_horror_overlay()
	_play_jumpscare_stinger()

	# Jaga pose mengancam tetap aktif selama 2.2 detik penuh
	await get_tree().create_timer(jumpscare_duration * 0.5).timeout
	if not is_inside_tree():
		return
	if _jumpscare_active and _playback:
		_playback.start(&"Attack")

	await get_tree().create_timer(jumpscare_duration * 0.5).timeout
	if not is_inside_tree():
		return

	# =========================================================================
	# TAHAP 2: CONSCIOUSNESS BLACKOUT / PINGSAN (1.1 detik total)
	# =========================================================================
	_animate_eyelids(0.0, 0.52, 0.48, 1.0, blackout_close_duration, Tween.TRANS_CUBIC, Tween.EASE_IN)
	await get_tree().create_timer(blackout_close_duration).timeout
	if not is_inside_tree():
		return

	_jumpscare_active = false
	_active_jumpscare_cam = null

	# Di balik layar gelap: matikan lampu wajah, rapikan monster, Memory Theft & Knockback
	if jumpscare_face_light:
		jumpscare_face_light.light_energy = 0.0
	if visual_model:
		visual_model.rotation = Vector3.ZERO
	if _playback:
		_playback.start(&"Idle")
	visible = _is_dimension_active()

	if is_instance_valid(hit_player):
		var stole_item := _erase_or_banish_carried_item(hit_player)
		player_hit.emit(hit_player, stole_item)

		_knockback_player_safely(hit_player)

		if rig and "is_cutscene_override" in rig:
			rig.set("is_cutscene_override", false)
		if rig and rig.has_method("snap_to_room"):
			rig.call("snap_to_room", hit_player.global_position)
		if rig and "is_cutscene_override" in rig:
			rig.set("is_cutscene_override", true)
		if rig and "_is_focusing" in rig:
			rig.set("_is_focusing", true)

	if is_instance_valid(rig_cam):
		rig_cam.current = true
		rig_cam.rotation_degrees.z = 9.0
	if is_instance_valid(jumpscare_cam):
		jumpscare_cam.queue_free()

	await get_tree().create_timer(blackout_hold_duration).timeout
	if not is_inside_tree():
		return

	# =========================================================================
	# TAHAP 3: SADAR KEMBALI / WAKE-UP BLINK (1.0 detik)
	# =========================================================================
	_restore_horror_overlay(post_state, wakeup_duration)
	if is_instance_valid(rig_cam):
		var tilt_tw := create_tween()
		tilt_tw.tween_property(rig_cam, "rotation_degrees:z", 0.0, wakeup_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Buka setengah -> kedip tutup -> buka penuh
	_animate_eyelids(-0.22, 0.30, 0.70, 1.22, wakeup_duration * 0.28, Tween.TRANS_SINE, Tween.EASE_OUT)
	await get_tree().create_timer(wakeup_duration * 0.28).timeout
	if not is_inside_tree():
		return

	_animate_eyelids(0.0, 0.52, 0.48, 1.0, wakeup_duration * 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	await get_tree().create_timer(wakeup_duration * 0.16).timeout
	if not is_inside_tree():
		return

	_animate_eyelids(-0.55, 0.0, 1.0, 1.55, wakeup_duration * 0.56, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	await get_tree().create_timer(wakeup_duration * 0.56).timeout
	if not is_inside_tree():
		return

	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", false)
	if rig and "is_cutscene_override" in rig:
		rig.set("is_cutscene_override", false)
	if is_instance_valid(rig_cam):
		rig_cam.rotation_degrees.z = 0.0

	_set_player_locked(hit_player, false)

	# Beri grace period 1.8 detik sebelum monster kembali ke state CHASE
	_stun_timer = post_hit_grace_seconds
	_is_hit_sequence_active = false


func _update_jumpscare_frame(delta: float) -> void:
	visible = true
	_jumpscare_elapsed = minf(_jumpscare_elapsed + delta, jumpscare_duration)
	var progress := clampf(_jumpscare_elapsed / maxf(jumpscare_duration, 0.01), 0.0, 1.0)
	var desired_dist := lerpf(0.95, maxf(0.95 - jumpscare_push_distance, 0.55), progress)

	var head_pos := _get_monster_head_world_pos()
	var face_fwd := _get_monster_face_forward()
	var cam_pos := _compute_safe_jumpscare_cam_pos(head_pos, face_fwd, desired_dist)

	if jumpscare_cam_point:
		jumpscare_cam_point.global_position = cam_pos
	if is_instance_valid(_active_jumpscare_cam):
		_active_jumpscare_cam.global_position = cam_pos
		_active_jumpscare_cam.look_at(head_pos, Vector3.UP)
		var amp := 0.036 * (1.0 - progress * 0.25)
		_active_jumpscare_cam.h_offset = randf_range(-amp, amp)
		_active_jumpscare_cam.v_offset = randf_range(-amp, amp)

	if jumpscare_face_light:
		jumpscare_face_light.global_position = cam_pos.lerp(head_pos, 0.25) + Vector3(0.0, 0.08, 0.0)
		jumpscare_face_light.light_energy = randf_range(5.8, 7.2)

	if visual_model:
		visual_model.rotation_degrees = Vector3(randf_range(-2.5, 2.5), randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))


func _get_monster_head_world_pos() -> Vector3:
	if _skeleton == null or _head_bone_idx < 0:
		_resolve_skeleton_head()
	if _skeleton and _head_bone_idx >= 0:
		var bone_xform := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone_idx)
		return bone_xform.origin + Vector3(0.0, 0.14, 0.0)
	if visual_model:
		var max_y := global_position.y + 2.0
		for mi in visual_model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m and m.mesh:
				var top_y := (m.global_transform * m.mesh.get_aabb()).end.y
				if top_y > max_y:
					max_y = top_y
		return Vector3(global_position.x, max_y - 0.25, global_position.z)
	return global_position + Vector3(0.0, 2.0, 0.0)


func _get_monster_face_forward() -> Vector3:
	var fwd := global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return fwd.normalized()


func _compute_safe_jumpscare_cam_pos(head_pos: Vector3, face_fwd: Vector3, desired_dist: float) -> Vector3:
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	var safe_dist := desired_dist
	if space:
		var q := PhysicsRayQueryParameters3D.create(head_pos, head_pos + face_fwd * desired_dist, 1)
		var excl: Array[RID] = [get_rid()]
		if _player and is_instance_valid(_player):
			excl.append(_player.get_rid())
		q.exclude = excl
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var hit_pt: Vector3 = hit.get("position", head_pos + face_fwd * desired_dist)
			safe_dist = clampf(head_pos.distance_to(hit_pt) - 0.18, 0.42, desired_dist)
	return head_pos + face_fwd * safe_dist


func _animate_eyelids(top_t: float, top_b: float, bot_t: float, bot_b: float, dur: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if _top_eyelid == null or _bottom_eyelid == null:
		return
	var tw := create_tween().set_parallel(true).set_trans(trans).set_ease(ease_type)
	tw.tween_property(_top_eyelid, "anchor_top", top_t, dur)
	tw.tween_property(_top_eyelid, "anchor_bottom", top_b, dur)
	tw.tween_property(_bottom_eyelid, "anchor_top", bot_t, dur)
	tw.tween_property(_bottom_eyelid, "anchor_bottom", bot_b, dur)


func _knockback_player_safely(player: CharacterBody3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var away := player.global_position - global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = global_transform.basis.z
		away.y = 0.0
	away = away.normalized()

	var space := get_world_3d().direct_space_state
	var target_pos := player.global_position + away * knockback_distance
	if space:
		var wall_q := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3(0.0, 0.85, 0.0),
			target_pos + Vector3(0.0, 0.85, 0.0),
			1
		)
		wall_q.exclude = [get_rid(), player.get_rid()]
		var wall_hit := space.intersect_ray(wall_q)
		if not wall_hit.is_empty():
			var hit_pt: Vector3 = wall_hit.get("position", target_pos)
			var safe_d := maxf(player.global_position.distance_to(Vector3(hit_pt.x, player.global_position.y, hit_pt.z)) - 0.55, 0.35)
			target_pos = player.global_position + away * safe_d

		var floor_q := PhysicsRayQueryParameters3D.create(
			target_pos + Vector3(0.0, 1.0, 0.0),
			target_pos + Vector3(0.0, -2.5, 0.0),
			1
		)
		floor_q.exclude = [get_rid(), player.get_rid()]
		var floor_hit := space.intersect_ray(floor_q)
		if floor_hit.is_empty():
			return

	player.velocity = Vector3.ZERO
	player.global_position = target_pos
	var vis := player.get("visual_node") as Node3D
	if vis:
		vis.global_position = target_pos


func _spike_horror_overlay() -> Dictionary:
	var saved := {"grain": 0.045, "vig": 0.72, "post_mat": null, "vig_rect": null}
	var scene_root := get_tree().current_scene if get_tree() else null
	if scene_root == null:
		return saved
	var post_rect := scene_root.find_child("HorrorPostRect", true, false) as ColorRect
	if post_rect and post_rect.material is ShaderMaterial:
		var sm := post_rect.material as ShaderMaterial
		saved["post_mat"] = sm
		saved["grain"] = float(sm.get_shader_parameter("grain_amount"))
		sm.set_shader_parameter("grain_amount", 0.15)
	var vig_rect := scene_root.find_child("VignetteRect", true, false)
	if vig_rect and "vignette_opacity" in vig_rect:
		saved["vig_rect"] = vig_rect
		saved["vig"] = float(vig_rect.get("vignette_opacity"))
		vig_rect.set("vignette_opacity", 0.94)
	return saved


func _restore_horror_overlay(saved: Dictionary, dur: float) -> void:
	var sm := saved.get("post_mat") as ShaderMaterial
	if sm and is_instance_valid(sm):
		var orig_grain: float = float(saved.get("grain", 0.045))
		var g_tw := create_tween()
		g_tw.tween_method(func(v: float) -> void:
			if is_instance_valid(sm):
				sm.set_shader_parameter("grain_amount", v)
		, 0.15, orig_grain, dur)
	var vig_rect := saved.get("vig_rect") as Node
	if vig_rect and is_instance_valid(vig_rect) and "vignette_opacity" in vig_rect:
		var orig_vig: float = float(saved.get("vig", 0.72))
		var v_tw := create_tween()
		v_tw.tween_property(vig_rect, "vignette_opacity", orig_vig, dur)


func _play_jumpscare_stinger() -> void:
	if jumpscare_stinger == null:
		return
	var asp := AudioStreamPlayer.new()
	asp.stream = jumpscare_stinger
	asp.volume_db = 0.0
	add_child(asp)
	asp.finished.connect(func() -> void:
		if is_instance_valid(asp):
			asp.queue_free()
	)
	asp.play()


func _set_player_locked(player: CharacterBody3D, locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if locked:
		player.velocity = Vector3.ZERO
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not locked)
	player.set_physics_process(not locked)
	player.set_process_unhandled_input(not locked)


func _find_player_in_hitbox() -> CharacterBody3D:
	if _is_player_in_safe_room():
		return null
	if _is_player_hidden() and not _spotted_player_hiding:
		return null
	if hitbox_area:
		for body in hitbox_area.get_overlapping_bodies():
			if body is CharacterBody3D and (body == _player or body.name == "Player"):
				return body as CharacterBody3D
	return null


## Mereset SEMUA floating relic yang sedang dibawa player kembali ke posisi spawn awalnya,
## atau memindahkan item bawaan CarrySystem ke anchor dimensi seberang saat player terkena serangan.
func _erase_or_banish_carried_item(player: CharacterBody3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	if "floating_relics" in player:
		var relics: Variant = player.get("floating_relics")
		if relics is Array and not (relics as Array).is_empty():
			var snapshot := (relics as Array).duplicate()
			var reset_any := false
			for item in snapshot:
				var relic := item as Node3D
				if relic and is_instance_valid(relic) and relic.has_method("reset_to_origin"):
					_spawn_memory_theft_particles(relic.global_position, _is_in_memory)
					relic.call("reset_to_origin")
					_spawn_memory_theft_particles(relic.global_position, _is_in_memory)
					reset_any = true
			(relics as Array).clear()
			if player.has_method("update_interact_hint"):
				player.call("update_interact_hint")
			if reset_any:
				_pulse_camera_shake(0.32, 0.16)
				if get_tree():
					get_tree().call_group("chapter2_puzzle_manager", "notify_all_relics_reset")
				memory_theft_triggered.emit(null, _is_in_memory, global_position)
				return true

	var carried_item := _get_carried_item(player)
	if carried_item != null:
		_perform_memory_theft(player, carried_item)
		return true
	return false


func _get_carried_item(player: CharacterBody3D) -> RigidBody3D:
	if _carry_system and "carried_item" in _carry_system:
		var carried: Variant = _carry_system.get("carried_item")
		if carried is RigidBody3D:
			return carried as RigidBody3D
	if player and "item_dipegang" in player:
		var held: Variant = player.get("item_dipegang")
		if held is RigidBody3D:
			return held as RigidBody3D
	return null


func _perform_memory_theft(player: CharacterBody3D, item: RigidBody3D) -> void:
	var steal_origin := item.global_position
	var target_in_memory := not _is_in_memory
	var anchor_pos := _get_theft_anchor_position(target_in_memory)

	_spawn_memory_theft_particles(steal_origin, target_in_memory)

	# 1. Paksa lepas item melalui CarrySystem & sinkronkan variabel MC agar tidak macet
	if _carry_system and _carry_system.has_method("drop"):
		_carry_system.call("drop", anchor_pos)

	if "item_dipegang" in player and player.get("item_dipegang") == item:
		player.set("item_dipegang", null)
		if player.has_method("update_interact_hint"):
			player.call("update_interact_hint")

	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.global_position = anchor_pos

	# 2. Pindahkan/munculkan kembali ke dimensi seberang (Remembered <-> Forgotten)
	var moved_into_world_container := _try_move_item_dimension_container(item, target_in_memory)
	if not moved_into_world_container:
		_register_stolen_item(item, target_in_memory)
		_apply_stolen_item_dimension(item, target_in_memory)

	_spawn_memory_theft_particles(anchor_pos, target_in_memory)
	_pulse_camera_shake(0.32, 0.16)
	memory_theft_triggered.emit(item, target_in_memory, anchor_pos)


func _get_theft_anchor_position(target_in_memory: bool) -> Vector3:
	var anchor := _anchor_remembered if target_in_memory else _anchor_forgotten
	if anchor and is_instance_valid(anchor):
		return anchor.global_position
	if not _waypoints.is_empty():
		return _waypoints[(_waypoint_idx + 1) % _waypoints.size()].global_position + Vector3(0.0, 0.45, 0.0)
	return global_position + Vector3(0.0, 0.45, 0.0)


func _try_move_item_dimension_container(item: RigidBody3D, target_in_memory: bool) -> bool:
	if _world_manager == null:
		return false
	var rem := _world_manager.get("remembered") as Node3D
	var forg := _world_manager.get("forgotten") as Node3D
	var parent := item.get_parent()
	if (parent == rem or parent == forg) and rem != null and forg != null:
		var dest_parent := rem if target_in_memory else forg
		if parent != dest_parent:
			item.reparent(dest_parent, true)
		if _world_manager.has_method("apply_dimension_state"):
			_world_manager.call("apply_dimension_state", _is_in_memory, false)
		return true
	return false


func _register_stolen_item(item: RigidBody3D, target_in_memory: bool) -> void:
	for entry in _stolen_items:
		if entry.get("item") == item:
			entry["target_in_memory"] = target_in_memory
			return
	_stolen_items.append({"item": item, "target_in_memory": target_in_memory})


func _sync_stolen_items_visibility() -> void:
	for i in range(_stolen_items.size() - 1, -1, -1):
		var item := _stolen_items[i].get("item") as RigidBody3D
		if item == null or not is_instance_valid(item):
			_stolen_items.remove_at(i)
			continue
		var target_mem := bool(_stolen_items[i].get("target_in_memory", false))
		_apply_stolen_item_dimension(item, target_mem)


func _apply_stolen_item_dimension(item: RigidBody3D, target_in_memory: bool) -> void:
	var should_be_active := (_is_in_memory == target_in_memory)
	item.visible = should_be_active
	item.set_deferred("freeze", not should_be_active)
	for ch in item.find_children("*", "CollisionShape3D", true, false):
		(ch as CollisionShape3D).set_deferred("disabled", not should_be_active)


func _spawn_memory_theft_particles(world_pos: Vector3, target_in_memory: bool, tint_override: Color = Color(-1.0, 0.0, 0.0), emission_energy: float = 2.4, gravity_y: float = -1.2) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().current_scene == null:
		return

	var particles := GPUParticles3D.new()
	particles.name = "MemoryTheftBurst"
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 24
	particles.lifetime = 0.75

	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.direction = Vector3(0.0, 1.0, 0.0)
	proc_mat.spread = 180.0
	proc_mat.initial_velocity_min = 1.4
	proc_mat.initial_velocity_max = 3.6
	proc_mat.gravity = Vector3(0.0, gravity_y, 0.0)
	proc_mat.scale_min = 0.6
	proc_mat.scale_max = 1.4
	particles.process_material = proc_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tint := tint_override if tint_override.r >= 0.0 else (Color(0.38, 0.88, 1.0) if target_in_memory else Color(1.0, 0.65, 0.28))
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = emission_energy
	sphere.material = mat
	particles.draw_pass_1 = sphere

	get_tree().current_scene.add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true

	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _pulse_camera_shake(duration: float, intensity: float) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var rig := get_tree().current_scene.find_child("CameraRig", true, false)
	if rig and rig.has_method("trigger_dimension_shake"):
		rig.call("trigger_dimension_shake", duration, intensity)


func _get_floor_waypoints() -> Array[Marker3D]:
	var floor_pool := _floor2_anchors if global_position.y >= 3.0 else _floor1_anchors
	var filtered: Array[Marker3D] = []
	for wp in _waypoints:
		if is_instance_valid(wp) and absf(wp.global_position.y - global_position.y) <= floor_diff_threshold and not _is_point_in_safe_room(wp.global_position):
			filtered.append(wp)
	if filtered.is_empty():
		for a in floor_pool:
			if is_instance_valid(a) and not _is_point_in_safe_room(a.global_position):
				filtered.append(a)
	return filtered if not filtered.is_empty() else _waypoints


func _update_floor_and_tactical_teleport(delta: float) -> void:
	_tactical_tp_cooldown = maxf(_tactical_tp_cooldown - delta, 0.0)
	if _player == null or not is_instance_valid(_player) or _is_hit_sequence_active or _is_player_hidden() or _is_player_in_safe_room():
		_diff_floor_timer = 0.0
		return
	if current_state in [State.CUTSCENE, State.ATTACK, State.STUNNED]:
		_diff_floor_timer = 0.0
		return

	var floor_diff_y := absf(_player.global_position.y - global_position.y)
	if floor_diff_y > floor_diff_threshold:
		_diff_floor_timer += delta
		if _diff_floor_timer > floor_tp_delay_seconds:
			_diff_floor_timer = 0.0
			var tp_pos := _pick_teleport_anchor(_player.global_position, true)
			if tp_pos.is_finite():
				_tactical_tp_cooldown = randf_range(tactical_tp_cooldown_min, tactical_tp_cooldown_max)
				_perform_teleport(tp_pos, current_state == State.CHASE or current_state == State.INVESTIGATE)
		return

	_diff_floor_timer = 0.0
	if current_state == State.CHASE and _tactical_tp_cooldown <= 0.0:
		var flat_dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
		var offscreen := not _is_visible_on_player_camera()
		if flat_dist > tactical_tp_distance or (offscreen and flat_dist > tactical_tp_min_offscreen_dist):
			var tp_pos := _pick_teleport_anchor(_player.global_position, false)
			if tp_pos.is_finite():
				_tactical_tp_cooldown = randf_range(tactical_tp_cooldown_min, tactical_tp_cooldown_max)
				_perform_teleport(tp_pos, true)


func _is_visible_on_player_camera() -> bool:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return false
	for h in [1.4, 3.2]:
		var pt := global_position + Vector3(0.0, h, 0.0)
		if not cam.is_position_behind(pt) and cam.is_position_in_frustum(pt):
			return true
	return false


func _is_point_in_hiding_spot(world_pos: Vector3) -> bool:
	for spot in _hide_spot_nodes:
		if not is_instance_valid(spot):
			continue
		if absf(world_pos.y - spot.global_position.y) > 2.2:
			continue
		if Vector2(world_pos.x - spot.global_position.x, world_pos.z - spot.global_position.z).length() < 4.0:
			return true
	return false


func _pick_teleport_anchor(player_pos: Vector3, allow_fallback: bool) -> Vector3:
	var pool: Array[Marker3D] = []
	pool.append_array(_floor1_anchors)
	pool.append_array(_floor2_anchors)
	if pool.is_empty():
		pool.append_array(_waypoints)

	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var cam_fwd := Vector3.ZERO
	if cam:
		cam_fwd = -cam.global_transform.basis.z
		cam_fwd.y = 0.0
		if cam_fwd.length_squared() > 0.001:
			cam_fwd = cam_fwd.normalized()

	var best_ideal := Vector3.INF
	var best_ideal_score := INF
	var best_fallback := Vector3.INF
	var best_fallback_score := INF

	for anchor in pool:
		if not is_instance_valid(anchor):
			continue
		var p := anchor.global_position
		if absf(p.y - player_pos.y) >= 1.5:
			continue
		if _is_point_in_hiding_spot(p) or _is_point_in_safe_room(p):
			continue
		if not allow_fallback and p.distance_to(global_position) < 3.0:
			continue

		var flat_dist := Vector2(p.x - player_pos.x, p.z - player_pos.z).length()
		var view_dot := 0.0
		if cam_fwd != Vector3.ZERO:
			var to_anchor := Vector3(p.x - cam.global_position.x, 0.0, p.z - cam.global_position.z).normalized()
			view_dot = cam_fwd.dot(to_anchor)

		# Hindari muncul tepat di depan kamera/wajah player; utamakan samping/belakang dalam rentang 5.5m-9.5m
		if flat_dist >= tp_min_safe_distance and flat_dist <= tp_max_safe_distance:
			var ideal_score := view_dot * 4.0 + absf(flat_dist - 7.5) * 0.25
			if ideal_score < best_ideal_score:
				best_ideal_score = ideal_score
				best_ideal = p
		elif allow_fallback and flat_dist >= tp_min_safe_distance:
			var fb_score := flat_dist + view_dot * 2.0
			if fb_score < best_fallback_score:
				best_fallback_score = fb_score
				best_fallback = p

	return best_ideal if best_ideal.is_finite() else best_fallback


func _snap_to_floor_navmesh(world_pos: Vector3) -> Vector3:
	var out := world_pos
	if nav_agent and nav_agent.get_navigation_map().is_valid():
		var nav_pt := NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), world_pos)
		if absf(nav_pt.y - world_pos.y) < 1.5:
			out.x = nav_pt.x
			out.z = nav_pt.z

	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(out + Vector3(0.0, 1.5, 0.0), out + Vector3(0.0, -2.5, 0.0), 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			out.y = (hit.get("position", out) as Vector3).y
	return out


func _perform_teleport(target_pos: Vector3, resume_chase: bool) -> void:
	if _is_teleporting:
		return
	_is_teleporting = true
	velocity = Vector3.ZERO
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(Vector3.ZERO)
	_set_camera_chase_shake(0.0)

	var void_tint := Color(0.16, 0.08, 0.24)
	_spawn_memory_theft_particles(global_position + Vector3(0.0, 1.4, 0.0), false, void_tint, 0.9, 0.6)

	global_position = _snap_to_floor_navmesh(target_pos)
	_last_stuck_check_pos = global_position
	_stuck_timer = 0.0

	_spawn_memory_theft_particles(global_position + Vector3(0.0, 1.4, 0.0), false, void_tint, 1.1, 0.6)
	var saved_overlay := _spike_horror_overlay()
	_restore_horror_overlay(saved_overlay, 0.45)
	_pulse_camera_shake(0.28, 0.14)

	if _player and is_instance_valid(_player):
		_face_point(_player.global_position, 1.0, 1.0)
		_set_nav_target(_player.global_position)
	_travel_anim(&"Idle")

	await get_tree().create_timer(teleport_reaction_pause).timeout
	if not is_inside_tree():
		return
	_is_teleporting = false

	if _is_hit_sequence_active or not _is_dimension_active() or current_state in [State.CUTSCENE, State.ATTACK, State.STUNNED]:
		return

	if resume_chase and _player and is_instance_valid(_player) and not _is_player_hidden() and not _is_player_in_safe_room():
		_last_known_pos = _player.global_position
		_lost_sight_timer = 0.0
		_change_state(State.CHASE)
	else:
		_change_state(State.PATROL)
