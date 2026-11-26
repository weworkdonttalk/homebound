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

## Mode Telekinesis 3D (saat true, CameraRig pause dan menyerahkan kendali pada TelekinesisCamera3D)
@export var is_telekinesis_mode: bool = false

@onready var camera: Camera3D = $Camera3D

var _camera_anchor: Vector3 = Vector3(-56.5, 8.8, 27.5)
var _is_focusing: bool = false
var _focus_tween: Tween = null
var _sway_time: float = 0.0
var _current_fov: float = 42.0
var _in_parkour_zone: bool = false
var _look_ahead_offset: Vector3 = Vector3.ZERO

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

	if target == null:
		target = get_node_or_null("../Player")
	if target == null and get_parent():
		target = get_parent().find_child("Player", true, false) as Node3D

	# Inisialisasi FastNoiseLite untuk organic sway
	_setup_noise()

	# Inisialisasi anchor awal di posisi CameraRig yang diset di scene
	_camera_anchor = global_position
	if _camera_anchor == Vector3.ZERO and target != null:
		_camera_anchor = target.global_position + follow_offset

	_camera_anchor = _clamp_bounds(_camera_anchor)
	global_position = _camera_anchor


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
	pos.x = clampf(pos.x, min_bounds.x, max_bounds.x)
	pos.y = clampf(pos.y, min_bounds.y, max_bounds.y)
	pos.z = clampf(pos.z, min_bounds.z, max_bounds.z)
	return pos


func set_telekinesis_mode(_val: bool) -> void:
	is_telekinesis_mode = false
	if camera:
		camera.current = true


func _process(delta: float) -> void:
	if _is_focusing or target == null:
		return

	_sway_time += delta

	# =========================================================================
	# 1. FOV LERP — Parkour Zone zoom-out / normal
	# =========================================================================
	var target_fov := parkour_fov if _in_parkour_zone else camera_fov
	_current_fov = lerpf(_current_fov, target_fov, clampf(fov_lerp_speed * delta, 0.0, 1.0))

	if camera:
		camera.fov = _current_fov
		camera.rotation_degrees.x = pitch_degrees

	# =========================================================================
	# 2. LOOK-AHEAD — offset halus ke arah hadap karakter
	# =========================================================================
	var look_target := Vector3.ZERO
	if target.has_node("body"):
		var body_node: Node3D = target.get_node("body")
		var facing := body_node.global_transform.basis.z.normalized()
		facing.y = 0.0
		look_target = facing * look_ahead_distance
	_look_ahead_offset = _look_ahead_offset.lerp(look_target, clampf(look_ahead_speed * delta, 0.0, 1.0))

	# =========================================================================
	# 3. WEIGHTED AXIS TRACKING & DEADZONE
	# =========================================================================
	var desired_anchor := _camera_anchor

	if stay_mode:
		# Hitung selisih posisi target + look-ahead dengan anchor kamera saat ini
		var target_x := target.global_position.x + _look_ahead_offset.x
		var diff_x := target_x - _camera_anchor.x
		var target_ideal_z := target.global_position.z + follow_offset.z + _look_ahead_offset.z
		var diff_z := target_ideal_z - _camera_anchor.z
		var target_ideal_y := target.global_position.y + follow_offset.y
		var diff_y := target_ideal_y - _camera_anchor.y

		# Hanya jika player keluar dari batas deadzone, anchor bergeser
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

		# Weighted per-axis damping (menggantikan shift_speed_x/y/z yang seragam)
		_camera_anchor.x = lerpf(_camera_anchor.x, desired_anchor.x, clampf(damp_horizontal * delta, 0.0, 1.0))
		_camera_anchor.y = lerpf(_camera_anchor.y, desired_anchor.y, clampf(damp_vertical * delta, 0.0, 1.0))
		_camera_anchor.z = lerpf(_camera_anchor.z, desired_anchor.z, clampf(damp_depth * delta, 0.0, 1.0))
	else:
		# Mode follow langsung konvensional jika stay_mode dimatikan
		var direct_desired := target.global_position + follow_offset + _look_ahead_offset
		direct_desired = _clamp_bounds(direct_desired)
		_camera_anchor.x = lerpf(_camera_anchor.x, direct_desired.x, clampf(damp_horizontal * delta, 0.0, 1.0))
		_camera_anchor.y = lerpf(_camera_anchor.y, direct_desired.y, clampf(damp_vertical * delta, 0.0, 1.0))
		_camera_anchor.z = lerpf(_camera_anchor.z, direct_desired.z, clampf(damp_depth * delta, 0.0, 1.0))

	# =========================================================================
	# 4. ORGANIC SWAY (FastNoiseLite — breathing micro-motion)
	# =========================================================================
	var sway_offset := Vector3.ZERO
	var sway_roll := 0.0

	if sway_enabled and _noise_x:
		sway_offset.x = _noise_x.get_noise_1d(_sway_time) * sway_amount * 1.2
		sway_offset.y = _noise_y.get_noise_1d(_sway_time) * sway_amount * 0.8
		sway_offset.z = _noise_z.get_noise_1d(_sway_time) * sway_amount * 0.4
		sway_roll = _noise_roll.get_noise_1d(_sway_time) * sway_roll_degrees

	# =========================================================================
	# 5. PARALLAX LEAN
	# =========================================================================
	var lean_offset := Vector3.ZERO
	if parallax_lean_amount > 0.0:
		var target_diff_x := target.global_position.x - _camera_anchor.x
		lean_offset.x = clampf(target_diff_x * parallax_lean_amount, -1.0, 1.0)

	# Terapkan posisi akhir: Anchor stabil + goyangan organik + lean
	var final_pos := _camera_anchor + sway_offset + lean_offset
	# Anti-Void: clamp posisi akhir juga
	global_position = _clamp_bounds(final_pos)

	if camera:
		camera.rotation_degrees.z = sway_roll


# =========================================================================
# PARKOUR ZONE — dipanggil oleh ParkourCameraZone (Area3D)
# =========================================================================
func enter_parkour_zone() -> void:
	_in_parkour_zone = true

func exit_parkour_zone() -> void:
	_in_parkour_zone = false


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
	var snap_pos := target_pos + follow_offset
	snap_pos = _clamp_bounds(snap_pos)
	_camera_anchor = snap_pos
	global_position = snap_pos


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
