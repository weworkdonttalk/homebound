extends Area3D
class_name HidingSpot

## HidingSpot — Zona persembunyian non-destruktif untuk Chapter 2 (kolong meja & lemari kayu).
## - CROUCH_ZONE: otomatis menyembunyikan player saat berada di dalam area & status `sedang_jongkok`.
## - WARDROBE_INTERACT: masuk/keluar lemari dengan [E], mengaktifkan kamera intip celah lemari + vignette gelap.

signal player_entered_hiding(player: CharacterBody3D, spot: HidingSpot)
signal player_exited_hiding(player: CharacterBody3D, spot: HidingSpot)

enum HideMode { CROUCH_ZONE, WARDROBE_INTERACT }

@export var hide_mode: HideMode = HideMode.CROUCH_ZONE
@export var spot_display_name: String = "Kolong Meja"
@export var close_spot_distance: float = 3.5

@export_group("Wardrobe Settings")
@export var inside_point_path: NodePath = NodePath("HideInsidePoint")
@export var exit_point_path: NodePath = NodePath("ExitPoint")
@export var peek_cam_point_path: NodePath = NodePath("PeekCamPoint")
@export var peek_fov: float = 52.0
@export var max_peek_yaw_deg: float = 28.0
@export var max_peek_pitch_deg: float = 12.0
@export var peek_look_speed_deg: float = 58.0
@export var peek_vignette_inner: float = 0.13
@export var peek_vignette_outer: float = 0.38
@export var peek_vignette_opacity: float = 0.96
@export var peek_vignette_aspect: float = 0.65

var _overlapping_player: CharacterBody3D = null
var _active_player: CharacterBody3D = null

var _inside_point: Marker3D = null
var _exit_point: Marker3D = null
var _peek_cam_point: Marker3D = null

var _peek_cam: Camera3D = null
var _peek_yaw_deg: float = 0.0
var _peek_pitch_deg: float = 0.0

var _saved_col_disabled: bool = false
var _saved_body_visible: bool = true
var _saved_visual_visible: bool = true
var _saved_vig_state: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	if hide_mode == HideMode.WARDROBE_INTERACT:
		_inside_point = get_node_or_null(inside_point_path) as Marker3D
		_exit_point = get_node_or_null(exit_point_path) as Marker3D
		_peek_cam_point = get_node_or_null(peek_cam_point_path) as Marker3D

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	if _active_player and is_instance_valid(_active_player):
		if hide_mode == HideMode.WARDROBE_INTERACT:
			exit_wardrobe(_active_player)
		else:
			_deactivate_crouch_hide(_active_player)


func _is_player_body(body: Node) -> bool:
	return body is CharacterBody3D and (body.name == "Player" or body.is_in_group("player") or "is_hidden" in body)


func _on_body_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	var player := body as CharacterBody3D
	_overlapping_player = player
	if player.has_method("register_nearby_hiding_spot"):
		player.call("register_nearby_hiding_spot", self)

	if hide_mode == HideMode.CROUCH_ZONE:
		_sync_crouch_hide(player)


func _on_body_exited(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	var player := body as CharacterBody3D

	if hide_mode == HideMode.CROUCH_ZONE:
		if _active_player == player:
			_deactivate_crouch_hide(player)
		if _overlapping_player == player:
			_overlapping_player = null
		if player.has_method("unregister_nearby_hiding_spot"):
			player.call("unregister_nearby_hiding_spot", self)
	else:
		# Jangan cabut referensi lemari saat player masih berada di dalam lemari
		if _active_player != player:
			if _overlapping_player == player:
				_overlapping_player = null
			if player.has_method("unregister_nearby_hiding_spot"):
				player.call("unregister_nearby_hiding_spot", self)


func _physics_process(delta: float) -> void:
	if hide_mode == HideMode.CROUCH_ZONE:
		if _overlapping_player and is_instance_valid(_overlapping_player):
			_sync_crouch_hide(_overlapping_player)
		elif _active_player and not is_instance_valid(_active_player):
			_active_player = null
	elif hide_mode == HideMode.WARDROBE_INTERACT:
		if _active_player and is_instance_valid(_active_player):
			_update_wardrobe_peek_camera(delta)


func _sync_crouch_hide(player: CharacterBody3D) -> void:
	var crouching := bool(player.get("sedang_jongkok")) if "sedang_jongkok" in player else false
	var in_wardrobe := bool(player.get("is_in_wardrobe")) if "is_in_wardrobe" in player else false
	if crouching and not in_wardrobe:
		if _active_player != player:
			_activate_crouch_hide(player)
	else:
		if _active_player == player:
			_deactivate_crouch_hide(player)


func _activate_crouch_hide(player: CharacterBody3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	_notify_monsters_hide_started(player.global_position)
	_active_player = player
	if player.has_method("set_hiding_state"):
		player.call("set_hiding_state", true, self, false)
	player_entered_hiding.emit(player, self)


func _deactivate_crouch_hide(player: CharacterBody3D) -> void:
	if _active_player == player:
		_active_player = null
	if player and is_instance_valid(player) and player.has_method("set_hiding_state"):
		player.call("set_hiding_state", false, self, false)
		player_exited_hiding.emit(player, self)


func is_wardrobe_spot() -> bool:
	return hide_mode == HideMode.WARDROBE_INTERACT


func get_interact_prompt(player: CharacterBody3D) -> String:
	if hide_mode == HideMode.WARDROBE_INTERACT:
		if _active_player == player:
			return "[E] Keluar dari " + spot_display_name
		return "[E] Sembunyi di " + spot_display_name
	var crouching := bool(player.get("sedang_jongkok")) if player and "sedang_jongkok" in player else false
	if crouching:
		return "Bersembunyi di " + spot_display_name
	return "[Ctrl/C] Jongkok untuk Sembunyi"


func toggle_wardrobe(player: CharacterBody3D) -> bool:
	if hide_mode != HideMode.WARDROBE_INTERACT or player == null or not is_instance_valid(player):
		return false
	if _active_player == player:
		return exit_wardrobe(player)
	if _active_player == null:
		return enter_wardrobe(player)
	return false


func enter_wardrobe(player: CharacterBody3D) -> bool:
	if hide_mode != HideMode.WARDROBE_INTERACT or player == null or not is_instance_valid(player):
		return false
	if _active_player != null:
		return false

	# Evaluasi saksi mata monster dari posisi masuk sebelum player dipindah ke dalam lemari
	_notify_monsters_hide_started(player.global_position)
	_active_player = player

	var col_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		_saved_col_disabled = col_shape.disabled
		col_shape.disabled = true

	var body_node := player.get_node_or_null("body") as Node3D
	if body_node:
		_saved_body_visible = body_node.visible
		body_node.visible = false

	var vis_node := player.get("visual_node") as Node3D if "visual_node" in player else null
	if vis_node:
		_saved_visual_visible = vis_node.visible
		vis_node.visible = false

	player.velocity = Vector3.ZERO
	if _inside_point:
		player.global_position = _inside_point.global_position
		if vis_node:
			vis_node.global_position = _inside_point.global_position

	if player.has_method("set_hiding_state"):
		player.call("set_hiding_state", true, self, true)

	_enter_peek_camera_and_vignette()
	player_entered_hiding.emit(player, self)
	return true


func exit_wardrobe(player: CharacterBody3D) -> bool:
	if _active_player != player and player != null:
		return false
	var target_player := _active_player if _active_player != null else player
	_active_player = null

	_exit_peek_camera_and_vignette(target_player)

	if target_player and is_instance_valid(target_player):
		var col_shape := target_player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col_shape:
			col_shape.disabled = _saved_col_disabled

		var body_node := target_player.get_node_or_null("body") as Node3D
		if body_node:
			body_node.visible = _saved_body_visible

		var vis_node := target_player.get("visual_node") as Node3D if "visual_node" in target_player else null
		if vis_node:
			vis_node.visible = _saved_visual_visible

		if _exit_point:
			target_player.global_position = _exit_point.global_position
			if vis_node:
				vis_node.global_position = _exit_point.global_position
		target_player.velocity = Vector3.ZERO

		if target_player.has_method("set_hiding_state"):
			target_player.call("set_hiding_state", false, self, false)

		if _overlapping_player != target_player and target_player.has_method("unregister_nearby_hiding_spot"):
			target_player.call("unregister_nearby_hiding_spot", self)

		player_exited_hiding.emit(target_player, self)
	return true


func force_exit_for_hit(player: CharacterBody3D) -> void:
	if _active_player == player:
		if hide_mode == HideMode.WARDROBE_INTERACT:
			exit_wardrobe(player)
		else:
			_deactivate_crouch_hide(player)


func _notify_monsters_hide_started(entry_world_pos: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	get_tree().call_group("eraser_ai", "notify_player_hide_started", entry_world_pos)


func _find_camera_rig() -> Node3D:
	if not is_inside_tree() or get_tree() == null:
		return null
	var scene_root := get_tree().current_scene
	if scene_root:
		return scene_root.find_child("CameraRig", true, false) as Node3D
	return get_tree().root.find_child("CameraRig", true, false) as Node3D


func _find_vignette_rect() -> ColorRect:
	if not is_inside_tree() or get_tree() == null:
		return null
	var scene_root := get_tree().current_scene
	if scene_root:
		return scene_root.find_child("VignetteRect", true, false) as ColorRect
	return get_tree().root.find_child("VignetteRect", true, false) as ColorRect


func _enter_peek_camera_and_vignette() -> void:
	var rig := _find_camera_rig()
	if rig:
		if "is_cutscene_override" in rig:
			rig.set("is_cutscene_override", true)
		if "_is_focusing" in rig:
			rig.set("_is_focusing", true)

	_peek_yaw_deg = 0.0
	_peek_pitch_deg = 0.0

	if is_instance_valid(_peek_cam):
		_peek_cam.queue_free()

	_peek_cam = Camera3D.new()
	_peek_cam.name = "WardrobePeekCam"
	_peek_cam.fov = peek_fov
	_peek_cam.near = 0.05
	add_child(_peek_cam)

	var base_xform := _peek_cam_point.global_transform if _peek_cam_point else global_transform
	_peek_cam.global_transform = base_xform
	_peek_cam.current = true

	var vig := _find_vignette_rect()
	if vig:
		_saved_vig_state = {
			"process": vig.is_processing(),
			"inner": float(vig.get("inner_radius")) if "inner_radius" in vig else 0.32,
			"outer": float(vig.get("outer_radius")) if "outer_radius" in vig else 0.75,
			"opacity": float(vig.get("vignette_opacity")) if "vignette_opacity" in vig else 0.78,
			"aspect": float(vig.get("aspect_correction")) if "aspect_correction" in vig else 1.0,
		}
		vig.set_process(false)
		if "inner_radius" in vig:
			vig.set("inner_radius", peek_vignette_inner)
		if "outer_radius" in vig:
			vig.set("outer_radius", peek_vignette_outer)
		if "vignette_opacity" in vig:
			vig.set("vignette_opacity", peek_vignette_opacity)
		if "aspect_correction" in vig:
			vig.set("aspect_correction", peek_vignette_aspect)
		if vig.material is ShaderMaterial:
			(vig.material as ShaderMaterial).set_shader_parameter("center_offset", Vector2(0.5, 0.5))


func _update_wardrobe_peek_camera(delta: float) -> void:
	if not is_instance_valid(_peek_cam):
		return
	var input_dir := Input.get_vector("kiri", "kanan", "maju", "mundur")
	if input_dir.length_squared() > 0.0025:
		_peek_yaw_deg = clampf(_peek_yaw_deg - input_dir.x * peek_look_speed_deg * delta, -max_peek_yaw_deg, max_peek_yaw_deg)
		_peek_pitch_deg = clampf(_peek_pitch_deg - input_dir.y * (peek_look_speed_deg * 0.65) * delta, -max_peek_pitch_deg, max_peek_pitch_deg)

	var base_xform := _peek_cam_point.global_transform if _peek_cam_point else global_transform
	var look_rot := Basis.from_euler(Vector3(deg_to_rad(_peek_pitch_deg), deg_to_rad(_peek_yaw_deg), 0.0))
	_peek_cam.global_transform = Transform3D(base_xform.basis.orthonormalized() * look_rot, base_xform.origin)


func _exit_peek_camera_and_vignette(player: CharacterBody3D) -> void:
	var vig := _find_vignette_rect()
	if vig and not _saved_vig_state.is_empty():
		if "inner_radius" in vig:
			vig.set("inner_radius", float(_saved_vig_state.get("inner", 0.32)))
		if "outer_radius" in vig:
			vig.set("outer_radius", float(_saved_vig_state.get("outer", 0.75)))
		if "vignette_opacity" in vig:
			vig.set("vignette_opacity", float(_saved_vig_state.get("opacity", 0.78)))
		if "aspect_correction" in vig:
			vig.set("aspect_correction", float(_saved_vig_state.get("aspect", 1.0)))
		vig.set_process(bool(_saved_vig_state.get("process", true)))
		_saved_vig_state.clear()

	var rig := _find_camera_rig()
	if rig:
		var rig_cam := rig.get("camera") as Camera3D if "camera" in rig else rig.get_node_or_null("Camera3D") as Camera3D
		if rig_cam:
			rig_cam.current = true
		if "_is_focusing" in rig:
			rig.set("_is_focusing", false)
		if "is_cutscene_override" in rig:
			rig.set("is_cutscene_override", false)
		if rig.has_method("snap_to_room"):
			var snap_target := _exit_point.global_position if _exit_point else (player.global_position if player and is_instance_valid(player) else Vector3.ZERO)
			rig.call("snap_to_room", snap_target)

	if is_instance_valid(_peek_cam):
		_peek_cam.queue_free()
		_peek_cam = null
