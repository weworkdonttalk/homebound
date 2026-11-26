class_name FloatingObject
extends Node3D

# ============================================================================
# Floating Object — Gimersia Chapter 1
# Animasi mengambang prosedural (sine-wave + subtle sway) dan sistem sequential pop-up
# untuk platform/batu parkour dengan sinkronisasi collision physics.
# ============================================================================

## Jarak naik-turun dalam meter
@export var amplitude: float = 0.18

## Ritme mengambang (detik per satu siklus penuh)
@export var period: float = 2.8

## Offset fase agar objek/batu di dekatnya tidak bergerak serempak
@export var phase_offset: float = 0.0

## Sudut kemiringan melayang halus (derajat)
@export var sway_angle_degrees: float = 1.5

## Status apakah saat ini aktif mengambang
@export var is_floating: bool = false

## Status apakah sudah selesai pop-up
@export var is_popped_up: bool = false

## Apakah mulai dalam kondisi tersembunyi sebelum dipanggil popup
@export var start_hidden: bool = true

## Jarak di bawah tanah saat tersembunyi sebelum pop-up (meter)
@export var underground_offset: float = 2.0

## Sinyal yang dipancarkan saat animasi pop-up selesai dan platform aktif
signal popped_up

var _is_initialized: bool = false
var _original_scale: Vector3 = Vector3.ONE
var _original_y: float = 0.0
var _base_y: float = 0.0
var _original_rotation: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _popup_tween: Tween = null
var _collision_shapes: Array[CollisionShape3D] = []
var _collision_bodies: Array[CollisionObject3D] = []

func _ready() -> void:
	_ensure_initialized()
	if start_hidden:
		hide_immediately()
	elif is_floating:
		is_popped_up = true
		_enable_collision_shapes(true)

func _ensure_initialized() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_original_scale = scale if scale != Vector3.ZERO else Vector3.ONE
	_original_y = position.y
	_base_y = position.y
	_original_rotation = rotation
	_find_collision_nodes(self)

## Memunculkan platform dengan efek pop-up & overshooting scale halus
func popup_appear(delay: float = 0.0, rise_duration: float = 0.8) -> void:
	_ensure_initialized()

	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()

	is_floating = false
	is_popped_up = false
	var effective_duration: float = maxf(rise_duration, 0.05)
	var initial_underground_y: float = _original_y - underground_offset

	_popup_tween = create_tween()

	if delay > 0.0:
		_popup_tween.tween_interval(delay)

	_popup_tween.tween_callback(func() -> void:
		visible = true
		scale = Vector3(0.001, 0.001, 0.001)
		position.y = initial_underground_y
	)

	# Parallel pop-up: scale overshoot (TRANS_BACK, EASE_OUT) dan rise Y
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(self, "scale", _original_scale, effective_duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(self, "position:y", _original_y, effective_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	_popup_tween.set_parallel(false)

	_popup_tween.tween_callback(func() -> void:
		_enable_collision_shapes(true)
		is_floating = true
		is_popped_up = true
		_base_y = _original_y
		popped_up.emit()
	)

## Menyembunyikan objek seketika dan menonaktifkan seluruh CollisionShape3D anak
func hide_immediately() -> void:
	_ensure_initialized()

	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
		_popup_tween = null

	scale = Vector3(0.001, 0.001, 0.001)
	position.y = _original_y - underground_offset
	visible = false
	is_floating = false
	is_popped_up = false
	_enable_collision_shapes(false)

func _process(delta: float) -> void:
	if not is_floating:
		return

	_time += delta
	var frequency: float = (TAU / period) if period > 0.0 else 0.0
	var wave: float = sin(_time * frequency + phase_offset)

	# Pergerakan vertikal melayang
	position.y = _base_y + wave * amplitude

	# Kemiringan melayang halus (sway)
	if sway_angle_degrees != 0.0:
		var sway_rad: float = deg_to_rad(sway_angle_degrees)
		rotation.z = _original_rotation.z + wave * sway_rad
		rotation.x = _original_rotation.x + cos((_time * frequency * 0.7) + phase_offset) * (sway_rad * 0.5)

	# Sinkronisasi fisika static / kinematic collision
	_sync_physics_bodies(frequency)

func _sync_physics_bodies(frequency: float) -> void:
	var vertical_velocity: float = cos(_time * frequency + phase_offset) * frequency * amplitude
	var lin_vel: Vector3 = Vector3(0.0, vertical_velocity, 0.0)

	for body in _collision_bodies:
		if not is_instance_valid(body):
			continue
		if body is AnimatableBody3D:
			body.sync_to_physics = true
		elif body is StaticBody3D:
			body.constant_linear_velocity = lin_vel

func _find_collision_nodes(node: Node) -> void:
	if node == self:
		_collision_shapes.clear()
		_collision_bodies.clear()

	for child in node.get_children():
		if child is CollisionShape3D:
			_collision_shapes.append(child)
		if child is CollisionObject3D:
			_collision_bodies.append(child)
		_find_collision_nodes(child)

func _enable_collision_shapes(enable: bool) -> void:
	for col in _collision_shapes:
		if is_instance_valid(col):
			col.set_deferred("disabled", not enable)
