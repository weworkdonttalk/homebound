@tool
class_name ClockDialStation
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Jam besar interaktif untuk Puzzle 1 (The Two Clocks).
## Hanya bisa diputar ([E]) pada dimensi yang cocok ("Remembered" / "Forgotten").
## Menampilkan dial angka bercahaya & jarum jam berputar mulus sesuai jam saat ini.

signal hour_changed(station: Node3D, current_hour: int, is_synced: bool)

@export_enum("Remembered", "Forgotten") var active_dimension: String = "Remembered"
@export var start_hour: int = 3
@export var target_hour: int = 12
@export var hour_step: int = 3
@export var interact_range: float = 3.2
@export var show_visual_clock: bool = true
@export var focus_camera_offset: Vector3 = Vector3(0.0, 2.45, 3.35)
@export var focus_look_offset: Vector3 = Vector3(0.0, 2.35, 0.0)
@export var focus_fov: float = 40.0
@export var focus_idle_seconds: float = 1.4

var current_hour: int = 3
var is_locked_synced: bool = false

var _clock_rig: Dictionary = {}
var _glow_light: OmniLight3D = null
var _visual_root: Node3D = null
var _world: Node = null
var _player: CharacterBody3D = null
var _active_in_dim: bool = true
var _player_near: bool = false
var _is_focused: bool = false
var _is_exiting_focus: bool = false
var _focus_timer: float = 0.0
var _focus_cam: Camera3D = null
var _prev_cam: Camera3D = null
var _focus_tween: Tween = null


func _ready() -> void:
	current_hour = start_hour
	_build_clock_rig()
	_apply_hand_rotation(true)
	if Engine.is_editor_hint():
		return
	_world = Ch2Utils.find_world_manager(self)
	_player = Ch2Utils.find_player(self)
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)
	_apply_hand_rotation(true)


func _build_clock_rig() -> void:
	if get_node_or_null("ClockVisual") != null:
		return
	_visual_root = Node3D.new()
	_visual_root.name = "ClockVisual"
	add_child(_visual_root)

	# Pasang jam kuning beranimasi (clock_loop_animation.glb) menghadap kamera 2.5D (+Z)
	if show_visual_clock:
		var clock_holder := Node3D.new()
		clock_holder.name = "YellowClockHolder"
		clock_holder.position = Vector3(0.0, 2.35, 0.0)
		_visual_root.add_child(clock_holder)
		_clock_rig = Ch2Utils.spawn_yellow_clock(clock_holder, 1.35, true)

	# Lampu penunjuk agar terlihat mencolok di ruangan gelap
	_glow_light = OmniLight3D.new()
	_glow_light.name = "ClockGlow"
	_glow_light.position = Vector3(0.0, 2.35, 1.2)
	_glow_light.light_color = _dim_color()
	_glow_light.light_energy = 2.6
	_glow_light.omni_range = 7.0
	_visual_root.add_child(_glow_light)


func _dim_color() -> Color:
	return Color(0.38, 0.88, 1.0) if active_dimension == "Remembered" else Color(1.0, 0.68, 0.30)


func is_synced() -> bool:
	return current_hour == target_hour


func _on_dimension_shifted(is_in_memory: bool) -> void:
	_active_in_dim = (active_dimension == "Remembered" and is_in_memory) or (active_dimension == "Forgotten" and not is_in_memory)
	if _visual_root:
		_visual_root.visible = _active_in_dim
	if _glow_light:
		_glow_light.visible = _active_in_dim
	if not _active_in_dim and _is_focused:
		release_camera_focus(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return
	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var same_floor := absf(_player.global_position.y - global_position.y) < 3.5
	_player_near = same_floor and dist <= interact_range
	if _is_focused and not _is_exiting_focus and not is_locked_synced:
		_focus_timer -= delta
		var player_moving := _player.velocity.length_squared() > 0.08 or not _player_near
		if player_moving or _focus_timer <= 0.0:
			release_camera_focus(true)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_near or is_locked_synced:
		return
	if Ch2Utils.is_player_busy(_player):
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	if not _active_in_dim:
		return
	get_viewport().set_input_as_handled()
	_enter_camera_focus()
	advance_hour()


func advance_hour() -> void:
	current_hour = ((current_hour - 1 + hour_step) % 12) + 1
	_apply_hand_rotation(false)
	hour_changed.emit(self, current_hour, is_synced())


func lock_synced() -> void:
	is_locked_synced = true
	if _glow_light:
		_glow_light.light_color = Color(0.5, 1.0, 0.7)
		_glow_light.light_energy = 3.2


func _apply_hand_rotation(immediate: bool) -> void:
	Ch2Utils.set_yellow_clock_hour(self, _clock_rig, current_hour, 0.0 if immediate else 0.35, true)


func _find_camera_rig() -> Node3D:
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene.find_child("CameraRig", true, false) as Node3D
	return null


func _enter_camera_focus() -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	_focus_timer = focus_idle_seconds
	if _is_focused and not _is_exiting_focus and is_instance_valid(_focus_cam):
		return

	var viewport := get_viewport()
	if viewport == null:
		return
	var rig := _find_camera_rig()
	var base_cam := rig.get("camera") as Camera3D if rig and "camera" in rig and rig.get("camera") is Camera3D else viewport.get_camera_3d()
	if base_cam == null:
		return

	_prev_cam = base_cam
	_is_focused = true
	_is_exiting_focus = false
	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", true)

	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	if is_instance_valid(_focus_cam):
		_focus_cam.queue_free()

	_focus_cam = Camera3D.new()
	_focus_cam.name = "ClockFocusCam"
	_focus_cam.global_transform = base_cam.global_transform
	_focus_cam.fov = base_cam.fov
	add_child(_focus_cam)
	_focus_cam.current = true

	var look_pos := global_transform * focus_look_offset
	var dest_pos := global_transform * focus_camera_offset
	var start_xform := base_cam.global_transform
	var end_basis := Transform3D(Basis.IDENTITY, dest_pos).looking_at(look_pos, Vector3.UP).basis.orthonormalized()
	var end_xform := Transform3D(end_basis, dest_pos)

	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(_focus_cam):
			_focus_cam.global_transform = start_xform.interpolate_with(end_xform, t)
	, 0.0, 1.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(_focus_cam, "fov", focus_fov, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func release_camera_focus(smooth_return: bool = true) -> void:
	if not _is_focused:
		return
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	var rig := _find_camera_rig()
	if not smooth_return or not is_inside_tree() or not is_instance_valid(_focus_cam) or not is_instance_valid(_prev_cam):
		if is_instance_valid(_focus_cam):
			_focus_cam.queue_free()
		_focus_cam = null
		_is_focused = false
		_is_exiting_focus = false
		if smooth_return:
			if is_instance_valid(_prev_cam):
				_prev_cam.current = true
			if rig and "_is_focusing" in rig:
				rig.set("_is_focusing", false)
		return

	_is_exiting_focus = true
	var start_xform := _focus_cam.global_transform
	var target_fov := _prev_cam.fov

	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(_focus_cam) and is_instance_valid(_prev_cam):
			_focus_cam.global_transform = start_xform.interpolate_with(_prev_cam.global_transform, t)
	, 0.0, 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(_focus_cam, "fov", target_fov, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_prev_cam):
			_prev_cam.current = true
		if is_instance_valid(_focus_cam):
			_focus_cam.queue_free()
		_focus_cam = null
		_is_focused = false
		_is_exiting_focus = false
		if rig and "_is_focusing" in rig:
			rig.set("_is_focusing", false)
	)
