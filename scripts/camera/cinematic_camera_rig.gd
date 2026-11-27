extends Node3D
class_name CinematicCameraRig

# ============================================================================
# Cinematic Camera Rig — Little Nightmares / Limbo Style (2.5D Dynamic)
# Fitur:
# 1. Weighted Axis Tracking & Look-Ahead per sumbu (H/V/Depth)
# 2. Organic Breathing Sway via FastNoiseLite
# 3. ParkourCameraZone zoom-out halus
# 4. Anti-Void Bounds (kamera tidak memperlihatkan ruang kosong)
# 5. Stay / Deadzone Camera + Edge Transition (original preserved)
# ============================================================================

## Target yang diikuti oleh kamera (Player)
@export var target: Node3D = null

@export_group("Stay & Edge Transition")
## Jika true, kamera STAY di tempat dan hanya bergeser saat player mencapai ujung batas (Deadzone)
@export var stay_mode: bool = true

## Batas toleransi jarak X (meter) sebelum kamera mulai bergeser ke arah player
@export var edge_threshold_x: float = 7.0

## Batas toleransi jarak Z (kedalaman ruangan) sebelum kamera bergeser
@export var edge_threshold_z: float = 6.0

## Batas toleransi jarak Y (ketinggian)
@export var edge_threshold_y: float = 4.0

## Posisi offset default kamera terhadap target (jarak jauh sinematik)
@export var follow_offset: Vector3 = Vector3(0.0, 8.8, 24.5)
## Offset alternatif saat masuk ParkourCameraZone (jika bukan Vector3.ZERO)
@export var parkour_follow_offset: Vector3 = Vector3.ZERO

@export_group("Weighted Axis Tracking")
## Smooth damping horizontal (responsif) — semakin besar semakin cepat mengikuti
@export_range(0.5, 15.0) var damp_horizontal: float = 4.5
## Smooth damping vertikal (lembut, anti pusing saat lompat)
@export_range(0.5, 15.0) var damp_vertical: float = 2.2
## Smooth damping depth / kedalaman (sangat redam)
@export_range(0.5, 15.0) var damp_depth: float = 1.5

@export_group("Look-Ahead")
## Jumlah offset look-ahead ke arah hadap karakter (meter)
@export_range(0.0, 6.0) var look_ahead_distance: float = 2.5
## Kecepatan lerp look-ahead
@export_range(0.5, 10.0) var look_ahead_speed: float = 3.0

@export_group("Camera Angle & FOV")
## Sudut kemiringan kamera (Pitch menukik ke bawah dalam derajat)
@export_range(-45.0, 45.0) var pitch_degrees: float = -16.5

## Field of view kamera (dasar)
@export_range(20.0, 90.0) var camera_fov: float = 42.0

## FOV saat di dalam Parkour Zone (zoom-out)
@export_range(20.0, 90.0) var parkour_fov: float = 50.0

## Kecepatan transisi FOV
@export_range(0.5, 10.0) var fov_lerp_speed: float = 2.5

@export_group("Organic Motion (FastNoiseLite Sway)")
## Aktifkan goyangan organik halus (breathing sway)
@export var sway_enabled: bool = true

## Intensitas goyangan posisi (X, Y, Z)
@export_range(0.0, 1.0, 0.01) var sway_amount: float = 0.08

## Intensitas goyangan rotasi roll (kemiringan Z halus)
@export_range(0.0, 2.0, 0.05) var sway_roll_degrees: float = 0.25

## Frekuensi noise (semakin rendah semakin lambat/organik)
@export_range(0.01, 2.0) var sway_frequency: float = 0.35

@export_group("Parallax Lean")
## Subtle parallax lean: kamera sedikit miring merespon arah hadap player
@export_range(0.0, 0.2, 0.01) var parallax_lean_amount: float = 0.035

@export_group("Anti-Void Bounds")
## Batas frustum kamera agar tidak pernah menembus dinding ruangan ke ruang kosong (void)
@export var min_bounds: Vector3 = Vector3(-56.5, 8.5, 23.5)
@export var max_bounds: Vector3 = Vector3(82.0, 16.0, 28.5)
## Batas Z maksimum saat berada di dalam ruangan (0 = nonaktif)
@export var indoor_max_z: float = 0.0
## Batas Y khusus Lantai 1 vs Lantai 2 agar kamera tidak menembus pelat lantai (0 = nonaktif)
@export var lower_floor_max_y: float = 0.0
@export var upper_floor_min_y: float = 0.0

@export_group("Parkour 3D Third-Person Chase")
## Aktifkan kamera third-person 3D SpringArm3D + orbit mouse saat masuk ParkourCameraZone
@export var parkour_3d_chase: bool = false
@export var parkour_chase_pivot_height: float = 1.45
@export var parkour_chase_spring_length: float = 5.2
@export var parkour_chase_shoulder_offset: Vector2 = Vector2(0.6, 0.35)
@export var parkour_chase_yaw_degrees: float = -90.0
@export var parkour_chase_pitch_degrees: float = -10.5
@export var parkour_chase_fov: float = 62.0
@export var parkour_chase_mouse_sensitivity: float = 0.0028
@export var parkour_chase_capture_mouse: bool = true

@export_group("Room Divider & Wall Occlusion")
## Aktifkan pembatas kamera per ruangan & fade tembok tengah jika menghalangi pandangan
@export var room_divider_enabled: bool = true
## Posisi X tembok pembatas antara Ruangan 1 dan Ruangan 2 (Parkour)
@export var room_divider_x: float = 23.6
## Batas X maksimal kamera saat pemain masih di Ruangan 1 agar tembok tidak memotong layar
@export var room1_max_cam_x: float = 14.5
## Batas X minimal kamera saat pemain sudah masuk Ruangan 2 agar tembok tidak menghalangi
@export var room2_min_cam_x: float = 34.5
## Transparansi tembok (0=padat, 0.88=sangat transparan) saat berada di antara kamera dan pemain
@export_range(0.0, 0.98) var occlusion_fade_transparency: float = 0.88
@export var occlusion_fade_speed: float = 10.0

## Mode Telekinesis 3D (saat true, CameraRig pause dan menyerahkan kendali pada TelekinesisCamera3D)
@export var is_telekinesis_mode: bool = false

@onready var camera: Camera3D = $Camera3D

var _camera_anchor: Vector3 = Vector3(-56.5, 8.8, 27.5)
var _is_focusing: bool = false
var _focus_tween: Tween = null
var _sway_time: float = 0.0
var _current_fov: float = 42.0
var _current_follow_offset: Vector3 = Vector3.ZERO
var _in_parkour_zone: bool = false
var is_upper_floor: bool = false
var _chase_blend: float = 0.0
var _chase_yaw: float = -PI * 0.5
var _chase_pitch: float = deg_to_rad(-10.5)
var _chase_target_yaw: float = -PI * 0.5
var _chase_target_pitch: float = deg_to_rad(-10.5)
var _chase_target_length: float = 5.2
var _chase_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _spring_mount: Node3D = null
var _chase_cam_target: Node3D = null
var _look_ahead_offset: Vector3 = Vector3.ZERO
var _has_partition_wall: bool = false
var _partition_wall_meshes: Array[GeometryInstance3D] = []

# FastNoiseLite untuk goyangan organik
var _noise_x: FastNoiseLite = null
var _noise_y: FastNoiseLite = null
var _noise_z: FastNoiseLite = null
var _noise_roll: FastNoiseLite = null


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D")
	if camera:
		camera.current = true
		camera.fov = camera_fov
		camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

	_current_fov = camera_fov
	_current_follow_offset = follow_offset
	_chase_target_length = parkour_chase_spring_length
	_chase_target_yaw = deg_to_rad(parkour_chase_yaw_degrees)
	_chase_target_pitch = deg_to_rad(parkour_chase_pitch_degrees)
	_chase_yaw = _chase_target_yaw
	_chase_pitch = _chase_target_pitch

	if target == null:
		target = get_node_or_null("../Player")
	if target == null and get_parent():
		target = get_parent().find_child("Player", true, false) as Node3D

	if parkour_3d_chase:
		_setup_chase_rig()

	# Inisialisasi FastNoiseLite untuk organic sway
	_setup_noise()
	_cache_partition_walls()

	# Inisialisasi anchor awal di posisi CameraRig yang diset di scene
	_camera_anchor = global_position
	if _camera_anchor == Vector3.ZERO and target != null:
		_camera_anchor = target.global_position + follow_offset

	_camera_anchor = _clamp_bounds(_camera_anchor)
	global_position = _camera_anchor


func _exit_tree() -> void:
	if _in_parkour_zone and parkour_3d_chase and parkour_chase_capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_chase_rig() -> void:
	if _chase_pivot != null:
		return
	_chase_pivot = Node3D.new()
	_chase_pivot.name = "ParkourChasePivot"
	_chase_pivot.top_level = true
	add_child(_chase_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "ParkourSpringArm"
	_spring_arm.spring_length = parkour_chase_spring_length
	_spring_arm.margin = 0.25
	_spring_arm.collision_mask = 1 # Hanya tabrak dinding/lantai world, bukan Player (layer 2)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	_spring_arm.shape = sphere
	_chase_pivot.add_child(_spring_arm)

	_spring_mount = Node3D.new()
	_spring_mount.name = "ParkourSpringMount"
	_spring_arm.add_child(_spring_mount)

	_chase_cam_target = Node3D.new()
	_chase_cam_target.name = "ParkourChaseCamTarget"
	_chase_cam_target.position = Vector3(parkour_chase_shoulder_offset.x, parkour_chase_shoulder_offset.y, 0.0)
	_spring_mount.add_child(_chase_cam_target)


func _unhandled_input(event: InputEvent) -> void:
	if not (_in_parkour_zone and parkour_3d_chase):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_chase_target_yaw -= mm.screen_relative.x * parkour_chase_mouse_sensitivity
		_chase_target_pitch = clampf(
			_chase_target_pitch - mm.screen_relative.y * parkour_chase_mouse_sensitivity,
			deg_to_rad(-48.0),
			deg_to_rad(25.0)
		)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_chase_target_length = clampf(_chase_target_length - 0.45, 3.6, 7.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_chase_target_length = clampf(_chase_target_length + 0.45, 3.6, 7.5)


func _cache_partition_walls() -> void:
	_partition_wall_meshes.clear()
	_has_partition_wall = false
	var scene_root := get_parent()
	if scene_root == null:
		return
	var divider := scene_root.find_child("Plane_004", true, false)
	if divider == null:
		divider = scene_root.get_node_or_null("pintu2")
	if divider:
		_has_partition_wall = true
		for child in divider.find_children("*", "MeshInstance3D", true):
			if child is GeometryInstance3D:
				_partition_wall_meshes.append(child as GeometryInstance3D)


func _setup_noise() -> void:
	_noise_x = FastNoiseLite.new()
	_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_x.frequency = sway_frequency * 0.72
	_noise_x.seed = randi()

	_noise_y = FastNoiseLite.new()
	_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_y.frequency = sway_frequency * 0.91
	_noise_y.seed = randi()

	_noise_z = FastNoiseLite.new()
	_noise_z.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_z.frequency = sway_frequency * 0.55
	_noise_z.seed = randi()

	_noise_roll = FastNoiseLite.new()
	_noise_roll.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_roll.frequency = sway_frequency * 0.48
	_noise_roll.seed = randi()


func _clamp_bounds(pos: Vector3) -> Vector3:
	var min_x := min_bounds.x
	var max_x := max_bounds.x
	if room_divider_enabled and _has_partition_wall and target != null:
		if target.global_position.x < room_divider_x:
			max_x = minf(max_x, room1_max_cam_x)
		else:
			min_x = maxf(min_x, room2_min_cam_x)
	pos.x = clampf(pos.x, min_x, max_x)

	var min_y := min_bounds.y
	var max_y := max_bounds.y
	if not _in_parkour_zone:
		if is_upper_floor and upper_floor_min_y > 0.0:
			min_y = maxf(min_y, upper_floor_min_y)
		elif not is_upper_floor and lower_floor_max_y > 0.0:
			max_y = minf(max_y, lower_floor_max_y)
	pos.y = clampf(pos.y, min_y, max_y)

	var max_z := max_bounds.z
	if indoor_max_z > 0.0 and not _in_parkour_zone:
		max_z = minf(max_z, indoor_max_z)
	pos.z = clampf(pos.z, min_bounds.z, max_z)
	return pos


func _update_wall_occlusion(delta: float) -> void:
	if not _has_partition_wall or _partition_wall_meshes.is_empty() or camera == null or target == null:
		return

	var cam_x := camera.global_position.x
	var player_x := target.global_position.x
	# Tembok pembatas (Plane_004) menghalangi jika berada di antara kamera & pemain atau kamera melintasi zona tembok
	var wall_x := room_divider_x + 0.25
	var crosses_wall := (cam_x - wall_x) * (player_x - wall_x) < 0.0
	var near_wall_transition := cam_x > (room1_max_cam_x + 1.0) and cam_x < (room2_min_cam_x - 1.0)
	var target_trans := occlusion_fade_transparency if (crosses_wall or near_wall_transition) else 0.0
	var t := clampf(occlusion_fade_speed * delta, 0.0, 1.0)

	for mi in _partition_wall_meshes:
		if is_instance_valid(mi):
			mi.transparency = lerpf(mi.transparency, target_trans, t)


func set_telekinesis_mode(_val: bool) -> void:
	is_telekinesis_mode = false
	if camera:
		camera.current = true


func _process(delta: float) -> void:
	_update_wall_occlusion(delta)
	if _is_focusing or target == null:
		return

	_sway_time += delta

	# =========================================================================
	# 1. FOV, CHASE BLEND & 2.5D FOLLOW OFFSET (Frame-rate independent)
	# =========================================================================
	var in_3d_chase := _in_parkour_zone and parkour_3d_chase
	var target_fov := parkour_chase_fov if in_3d_chase else (parkour_fov if _in_parkour_zone else camera_fov)
	var target_follow := parkour_follow_offset if (_in_parkour_zone and not in_3d_chase and parkour_follow_offset != Vector3.ZERO) else follow_offset

	var blend_t := 1.0 - exp(-fov_lerp_speed * delta)
	_current_fov = lerpf(_current_fov, target_fov, blend_t)
	_current_follow_offset = _current_follow_offset.lerp(target_follow, blend_t)
	_chase_blend = move_toward(_chase_blend, 1.0 if in_3d_chase else 0.0, delta * 1.35)

	if camera:
		camera.fov = _current_fov

	# =========================================================================
	# 2. LOOK-AHEAD & 2.5D WEIGHTED TRACKING
	# =========================================================================
	var look_target := Vector3.ZERO
	if target.has_node("body"):
		var body_node: Node3D = target.get_node("body")
		var facing := body_node.global_transform.basis.z.normalized()
		facing.y = 0.0
		look_target = facing * look_ahead_distance
	_look_ahead_offset = _look_ahead_offset.lerp(look_target, 1.0 - exp(-look_ahead_speed * delta))

	var desired_anchor := _camera_anchor

	if stay_mode:
		var target_x := target.global_position.x + _look_ahead_offset.x
		var diff_x := target_x - _camera_anchor.x
		var target_ideal_z := target.global_position.z + _current_follow_offset.z + _look_ahead_offset.z
		var diff_z := target_ideal_z - _camera_anchor.z
		var target_ideal_y := target.global_position.y + _current_follow_offset.y
		var diff_y := target_ideal_y - _camera_anchor.y

		if diff_x > edge_threshold_x:
			desired_anchor.x = target_x - edge_threshold_x
		elif diff_x < -edge_threshold_x:
			desired_anchor.x = target_x + edge_threshold_x

		if diff_z > edge_threshold_z:
			desired_anchor.z = target_ideal_z - edge_threshold_z
		elif diff_z < -edge_threshold_z:
			desired_anchor.z = target_ideal_z + edge_threshold_z

		if diff_y > edge_threshold_y:
			desired_anchor.y = target_ideal_y - edge_threshold_y
		elif diff_y < -edge_threshold_y:
			desired_anchor.y = target_ideal_y + edge_threshold_y

		desired_anchor = _clamp_bounds(desired_anchor)
		_camera_anchor.x = lerpf(_camera_anchor.x, desired_anchor.x, 1.0 - exp(-damp_horizontal * delta))
		_camera_anchor.y = lerpf(_camera_anchor.y, desired_anchor.y, 1.0 - exp(-damp_vertical * delta))
		_camera_anchor.z = lerpf(_camera_anchor.z, desired_anchor.z, 1.0 - exp(-damp_depth * delta))
	else:
		var direct_desired := _clamp_bounds(target.global_position + _current_follow_offset + _look_ahead_offset)
		_camera_anchor.x = lerpf(_camera_anchor.x, direct_desired.x, 1.0 - exp(-damp_horizontal * delta))
		_camera_anchor.y = lerpf(_camera_anchor.y, direct_desired.y, 1.0 - exp(-damp_vertical * delta))
		_camera_anchor.z = lerpf(_camera_anchor.z, direct_desired.z, 1.0 - exp(-damp_depth * delta))

	# =========================================================================
	# 3. ORGANIC SWAY & PARALLAX LEAN
	# =========================================================================
	var sway_offset := Vector3.ZERO
	var sway_roll := 0.0
	if sway_enabled and _noise_x:
		sway_offset.x = _noise_x.get_noise_1d(_sway_time) * sway_amount * 1.2
		sway_offset.y = _noise_y.get_noise_1d(_sway_time) * sway_amount * 0.8
		sway_offset.z = _noise_z.get_noise_1d(_sway_time) * sway_amount * 0.4
		sway_roll = _noise_roll.get_noise_1d(_sway_time) * sway_roll_degrees

	var lean_offset := Vector3.ZERO
	if parallax_lean_amount > 0.0:
		var target_diff_x := target.global_position.x - _camera_anchor.x
		lean_offset.x = clampf(target_diff_x * parallax_lean_amount, -1.0, 1.0)

	var pos_25d := _clamp_bounds(_camera_anchor + sway_offset + lean_offset)
	var xform_25d := Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)), pos_25d)

	# =========================================================================
	# 4. THIRD-PERSON SPRINGARM3D CHASE & SMOOTH BLEND
	# =========================================================================
	if parkour_3d_chase and _chase_pivot != null and _spring_arm != null and _spring_mount != null and _chase_cam_target != null:
		var pivot_goal := target.global_position + Vector3(0.0, parkour_chase_pivot_height, 0.0)
		_chase_pivot.global_position = _chase_pivot.global_position.lerp(pivot_goal, 1.0 - exp(-14.0 * delta))
		var rot_t := 1.0 - exp(-20.0 * delta)
		_chase_yaw = lerp_angle(_chase_yaw, _chase_target_yaw, rot_t)
		_chase_pitch = lerp_angle(_chase_pitch, _chase_target_pitch, rot_t)
		_chase_pivot.rotation = Vector3(_chase_pitch, _chase_yaw, 0.0)
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _chase_target_length, 1.0 - exp(-10.0 * delta))
		_chase_cam_target.position = Vector3(parkour_chase_shoulder_offset.x, parkour_chase_shoulder_offset.y, 0.0)

		if _chase_blend > 0.001:
			var smooth_b := _chase_blend * _chase_blend * (3.0 - 2.0 * _chase_blend)
			var chase_xform := _chase_cam_target.global_transform
			global_transform = Transform3D(
				xform_25d.basis.orthonormalized().slerp(chase_xform.basis.orthonormalized(), smooth_b),
				xform_25d.origin.lerp(chase_xform.origin, smooth_b)
			)
			if camera:
				camera.rotation_degrees = Vector3(0.0, 0.0, sway_roll * (1.0 - smooth_b * 0.6))
			return

	global_transform = Transform3D(Basis.IDENTITY, pos_25d)
	if camera:
		camera.rotation_degrees = Vector3(pitch_degrees, 0.0, sway_roll)


# =========================================================================
# PARKOUR ZONE — dipanggil oleh ParkourCameraZone (Area3D)
# =========================================================================
func set_upper_floor(upper: bool) -> void:
	is_upper_floor = upper


func enter_parkour_zone() -> void:
	_in_parkour_zone = true
	if parkour_3d_chase:
		_setup_chase_rig()
		_chase_target_yaw = deg_to_rad(parkour_chase_yaw_degrees)
		_chase_target_pitch = deg_to_rad(parkour_chase_pitch_degrees)
		_chase_yaw = _chase_target_yaw
		_chase_pitch = _chase_target_pitch
		_chase_target_length = parkour_chase_spring_length
		if _chase_pivot and target:
			_chase_pivot.global_position = target.global_position + Vector3(0.0, parkour_chase_pivot_height, 0.0)
			_chase_pivot.rotation = Vector3(_chase_pitch, _chase_yaw, 0.0)
		if parkour_chase_capture_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if target and target.has_method("enter_3d_mode") and camera:
			target.call("enter_3d_mode", camera)


func exit_parkour_zone() -> void:
	_in_parkour_zone = false
	if parkour_3d_chase:
		if parkour_chase_capture_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if target and target.has_method("exit_3d_mode"):
			target.call("exit_3d_mode")


## Kamera pan singkat saat puzzle aktif (misal melihat platform muncul atau pintu terbuka)
func focus_on_target(target_node: Node3D, duration: float = 1.5, hold_time: float = 0.8) -> void:
	if target_node == null:
		return
	_is_focusing = true
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	var dest := target_node.global_position + follow_offset * 0.88
	dest = _clamp_bounds(dest)

	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "global_position", dest, duration * 0.5)
	_focus_tween.tween_interval(hold_time)

	var return_pos := _camera_anchor
	_focus_tween.tween_property(self, "global_position", return_pos, duration * 0.5)
	_focus_tween.tween_callback(func() -> void: _is_focusing = false)


## Pan kamera ke node target tertentu dan tetap berada di sana sampai dipanggil langkah berikutnya
func pan_to_target(target_node: Node3D, duration: float = 1.2, custom_offset: Vector3 = Vector3.ZERO) -> Tween:
	if target_node == null:
		return null
	_is_focusing = true
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	var off := custom_offset if custom_offset != Vector3.ZERO else (follow_offset * 0.88)
	var dest := target_node.global_position + off
	dest = _clamp_bounds(dest)

	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "global_position", dest, duration)
	return _focus_tween


## Kembalikan fokus kamera secara halus ke posisi pemain
func return_to_player(duration: float = 1.0) -> Tween:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	var return_pos := target.global_position + follow_offset if target else _camera_anchor
	return_pos = _clamp_bounds(return_pos)

	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "global_position", return_pos, duration)
	_focus_tween.tween_callback(func() -> void:
		_camera_anchor = return_pos
		_is_focusing = false
	)
	return _focus_tween


## Snap seketika saat berpindah ruangan (teleportasi antar pintu)
func snap_to_room(new_position: Vector3 = Vector3.ZERO) -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_is_focusing = false

	var target_pos := new_position if new_position != Vector3.ZERO else (target.global_position if target else global_position)
	var in_3d_chase := _in_parkour_zone and parkour_3d_chase
	if in_3d_chase and _chase_pivot != null and _spring_arm != null and _spring_mount != null and _chase_cam_target != null:
		_chase_blend = 1.0
		_current_fov = parkour_chase_fov
		_chase_target_yaw = deg_to_rad(parkour_chase_yaw_degrees)
		_chase_target_pitch = deg_to_rad(parkour_chase_pitch_degrees)
		_chase_yaw = _chase_target_yaw
		_chase_pitch = _chase_target_pitch
		_spring_arm.spring_length = _chase_target_length
		_chase_pivot.global_position = target_pos + Vector3(0.0, parkour_chase_pivot_height, 0.0)
		_chase_pivot.rotation = Vector3(_chase_pitch, _chase_yaw, 0.0)
		_spring_mount.position = Vector3(0.0, 0.0, _chase_target_length)
		_chase_cam_target.position = Vector3(parkour_chase_shoulder_offset.x, parkour_chase_shoulder_offset.y, 0.0)
		global_transform = _chase_cam_target.global_transform
		if camera:
			camera.fov = _current_fov
			camera.rotation_degrees = Vector3.ZERO
		return

	_chase_blend = 0.0
	var off := parkour_follow_offset if (_in_parkour_zone and parkour_follow_offset != Vector3.ZERO) else follow_offset
	_current_follow_offset = off
	_current_fov = parkour_fov if _in_parkour_zone else camera_fov
	var snap_pos := _clamp_bounds(target_pos + off)
	_camera_anchor = snap_pos
	global_transform = Transform3D(Basis.IDENTITY, snap_pos)
	if camera:
		camera.fov = _current_fov
		camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)


## Shudder / micro-shake kamera singkat saat berpindah dimensi Remembered/Forgotten
var _shake_tween: Tween = null
func trigger_dimension_shake(duration: float = 0.35, intensity: float = 0.16) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var steps := 5
	var step_dur := duration / float(steps + 1)
	for i in range(steps):
		var damp := 1.0 - (float(i) / float(steps))
		var offset := Vector3(
			randf_range(-intensity, intensity) * damp,
			randf_range(-intensity * 0.6, intensity * 0.6) * damp,
			randf_range(-intensity * 0.4, intensity * 0.4) * damp
		)
		_shake_tween.tween_property(self, "position", _camera_anchor + offset, step_dur)
	_shake_tween.tween_property(self, "position", _camera_anchor, step_dur)
