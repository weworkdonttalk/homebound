class_name ParkourRock
extends Node3D

## ============================================================================
## ParkourRock — Batu Parkour Terintegrasi Shifting Memory (Remembered/Forgotten)
## - Permanent: Selalu solid di kedua dimensi (titik aman / Anchor).
## - Remembered: Solid saat in_memory = true; jadi Ghost Silhouette saat Forgotten.
## - Forgotten: Solid saat in_memory = false; jadi Ghost Silhouette saat Remembered.
## Dilengkapi phase-out grace 0.35s agar lompatan/shift di udara tetap adil,
## bobbing organik tersinkronisasi fisika, dan detektor checkpoint/quest.
## ============================================================================

@export_enum("Permanent", "Remembered", "Forgotten") var dimension_mode: String = "Permanent"
@export var rock_index: int = 1
@export var is_checkpoint: bool = false
@export var respawn_offset: Vector3 = Vector3(0.0, 1.4, 0.0)

@export_group("Floating Motion")
@export var enable_float: bool = true
@export var float_amplitude: float = 0.14
@export var float_period: float = 3.4
@export var float_phase_offset: float = 0.0
@export var sway_degrees: float = 1.0

@export_group("Shifting Polish")
@export var phase_out_grace: float = 0.35

signal rock_stepped(index: int, rock: ParkourRock)

var _base_pos: Vector3 = Vector3.ZERO
var _base_rot: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _is_solid: bool = true
var _meshes: Array[MeshInstance3D] = []
var _col_shapes: Array[CollisionShape3D] = []
var _bodies: Array[PhysicsBody3D] = []
var _active_mats: Dictionary = {}   # MeshInstance3D -> Array[Material]
var _ghost_mat: ShaderMaterial = null
var _phase_tween: Tween = null
var _sensor_area: Area3D = null


func _ready() -> void:
	_base_pos = position
	_base_rot = rotation
	_collect_nodes()
	_build_materials()
	_setup_step_sensor()

	if Engine.is_editor_hint():
		return

	# Sinkronkan dengan WorldManager jika sudah ada di scene
	var wm := get_tree().root.find_child("WorldManager", true, false)
	if wm == null:
		wm = get_tree().current_scene
	if wm and "in_memory" in wm:
		set_dimension_active(bool(wm.get("in_memory")), true)


func _collect_nodes() -> void:
	_meshes.clear()
	_col_shapes.clear()
	_bodies.clear()
	for mi in find_children("*", "MeshInstance3D", true):
		_meshes.append(mi as MeshInstance3D)
	for sb in find_children("*", "StaticBody3D", true):
		_bodies.append(sb as PhysicsBody3D)
		for col in sb.find_children("*", "CollisionShape3D", true):
			_col_shapes.append(col as CollisionShape3D)
	for ab in find_children("*", "AnimatableBody3D", true):
		_bodies.append(ab as PhysicsBody3D)
		for col in ab.find_children("*", "CollisionShape3D", true):
			_col_shapes.append(col as CollisionShape3D)


func _build_materials() -> void:
	var tint := Color(0.76, 0.78, 0.82, 1.0)
	var em_col := Color(0.0, 0.0, 0.0)
	var em_energy := 0.0
	var ghost_col := Color(0.45, 0.78, 1.0, 1.0)

	if dimension_mode == "Remembered":
		tint = Color(0.95, 0.82, 0.62, 1.0)
		em_col = Color(0.78, 0.52, 0.22)
		em_energy = 0.04
		ghost_col = Color(0.95, 0.66, 0.30, 1.0)
	elif dimension_mode == "Forgotten":
		tint = Color(0.66, 0.84, 1.0, 1.0)
		em_col = Color(0.28, 0.68, 0.98)
		em_energy = 0.05
		ghost_col = Color(0.35, 0.80, 1.0, 1.0)

	var ghost_shader := load("res://shaders/ghost_rock.gdshader") as Shader
	if ghost_shader:
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = ghost_shader
		_ghost_mat.set_shader_parameter("ghost_color", ghost_col)
		_ghost_mat.set_shader_parameter("core_alpha", 0.04)
		_ghost_mat.set_shader_parameter("rim_alpha", 0.44)
		_ghost_mat.set_shader_parameter("fresnel_power", 2.4)

	for mi in _meshes:
		if mi.mesh == null:
			continue
		var mats: Array[Material] = []
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = Color(
					m.albedo_color.r * tint.r,
					m.albedo_color.g * tint.g,
					m.albedo_color.b * tint.b,
					m.albedo_color.a
				)
				m.roughness = maxf(m.roughness, 0.88)
				if em_energy > 0.0:
					m.emission_enabled = true
					m.emission = em_col
					m.emission_energy_multiplier = em_energy
				mats.append(m)
			else:
				mats.append(src)
		_active_mats[mi] = mats


func _setup_step_sensor() -> void:
	if Engine.is_editor_hint() or get_node_or_null("StepSensor") != null:
		return
	var area := Area3D.new()
	area.name = "StepSensor"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.6
	cyl.height = 1.8
	col.shape = cyl
	area.add_child(col)
	add_child(area)

	# Posisikan sensor mendatar tepat di permukaan atas tabletop batu (di bawah kaki pemain)
	var center_world := global_position
	if not _col_shapes.is_empty() and is_instance_valid(_col_shapes[0]):
		center_world = _col_shapes[0].global_position
	var y_offset := 2.95 if global_basis.x.length() > 5.0 else 2.25
	area.global_position = center_world + Vector3(0.0, y_offset, 0.0)
	area.global_rotation = Vector3.ZERO
	area.scale = Vector3.ONE / Vector3(
		maxf(global_basis.x.length(), 0.01),
		maxf(global_basis.y.length(), 0.01),
		maxf(global_basis.z.length(), 0.01)
	)
	_sensor_area = area
	area.body_entered.connect(_on_step_body_entered)


func _on_step_body_entered(body: Node3D) -> void:
	if not _is_solid:
		return
	if body.name == "Player" or body is CharacterBody3D:
		rock_stepped.emit(rock_index, self)


func get_respawn_world_position() -> Vector3:
	return global_position + respawn_offset


func set_dimension_active(in_memory: bool, immediate: bool = false) -> void:
	var should_be_active := true
	if dimension_mode == "Remembered":
		should_be_active = in_memory
	elif dimension_mode == "Forgotten":
		should_be_active = not in_memory

	if _phase_tween and _phase_tween.is_valid():
		_phase_tween.kill()

	if should_be_active:
		_is_solid = true
		_set_collisions_enabled(true)
		_apply_active_materials()
	elif immediate or phase_out_grace <= 0.0:
		_is_solid = false
		_set_collisions_enabled(false)
		_apply_ghost_materials()
	else:
		# Grace period singkat sebelum batu dimensi lama kehilangan pijakan fisik
		_phase_tween = create_tween()
		_phase_tween.tween_interval(phase_out_grace)
		_phase_tween.tween_callback(func() -> void:
			_is_solid = false
			_set_collisions_enabled(false)
			_apply_ghost_materials()
		)


func _set_collisions_enabled(enabled: bool) -> void:
	for col in _col_shapes:
		if is_instance_valid(col):
			col.set_deferred("disabled", not enabled)
	if _sensor_area and is_instance_valid(_sensor_area):
		_sensor_area.set_deferred("monitoring", enabled)


func _apply_active_materials() -> void:
	for mi in _meshes:
		if not is_instance_valid(mi) or not _active_mats.has(mi):
			continue
		var mats: Array = _active_mats[mi]
		for s in range(mats.size()):
			mi.set_surface_override_material(s, mats[s])


func _apply_ghost_materials() -> void:
	for mi in _meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(s, _ghost_mat)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not enable_float or float_period <= 0.0:
		return

	_time += delta
	var freq := TAU / float_period
	var wave := sin(_time * freq + float_phase_offset)
	var prev_y := position.y
	var next_y := _base_pos.y + wave * float_amplitude
	position.y = next_y

	if sway_degrees != 0.0:
		var rad := deg_to_rad(sway_degrees)
		rotation.z = _base_rot.z + wave * rad

	var vel_y := (next_y - prev_y) / maxf(delta, 0.0001)
	for body in _bodies:
		if is_instance_valid(body) and body is StaticBody3D:
			(body as StaticBody3D).constant_linear_velocity = Vector3(0.0, vel_y, 0.0)
