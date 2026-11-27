@tool
class_name ClockPendulum
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Bandul pendulum jam raksasa untuk Puzzle 4 (The Pendulum).
## - Dimensi Remembered: berayun aktif melintasi jalur, mendorong pemain jatuh bila menyentuhnya.
## - Dimensi Forgotten ([T]): membeku diam pada sudut terakhir sehingga aman dilewati.

@export var arm_length: float = 11.4
@export var max_swing_degrees: float = 40.0
@export var swing_speed: float = 1.65
@export var phase_offset: float = 0.0
@export var knockback_speed: float = 9.5

var is_frozen: bool = false

var _arm_pivot: Node3D = null
var _bob_area: Area3D = null
var _bob_mat: StandardMaterial3D = null
var _bob_light: OmniLight3D = null
var _swing_phase: float = 0.0
var _hit_cooldown: float = 0.0
var _world: Node = null


func _ready() -> void:
	_swing_phase = phase_offset
	_build_pendulum()
	_update_arm_angle()
	if Engine.is_editor_hint():
		return
	_world = Ch2Utils.find_world_manager(self)
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)
	_update_arm_angle()


func _build_pendulum() -> void:
	if get_node_or_null("PendulumArmPivot") != null:
		_arm_pivot = get_node_or_null("PendulumArmPivot") as Node3D
		return
	_arm_pivot = Node3D.new()
	_arm_pivot.name = "PendulumArmPivot"
	add_child(_arm_pivot)

	# Batang pendulum panjang
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.14
	rm.bottom_radius = 0.14
	rm.height = arm_length
	rod.mesh = rm
	rod.position = Vector3(0.0, -arm_length * 0.5, 0.0)
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.24, 0.21, 0.18)
	rod_mat.metallic = 0.65
	rod_mat.roughness = 0.4
	rod.material_override = rod_mat
	_arm_pivot.add_child(rod)

	# Bandul raksasa di ujung bawah
	var bob_pos := Vector3(0.0, -arm_length, 0.0)
	var bob_mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.25
	cm.bottom_radius = 1.25
	cm.height = 0.45
	bob_mesh.mesh = cm
	bob_mesh.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	bob_mesh.position = bob_pos
	_bob_mat = StandardMaterial3D.new()
	_bob_mat.albedo_color = Color(0.45, 0.34, 0.16)
	_bob_mat.metallic = 0.85
	_bob_mat.roughness = 0.28
	_bob_mat.emission_enabled = true
	_bob_mat.emission = Color(0.75, 0.44, 0.14)
	_bob_mat.emission_energy_multiplier = 0.28
	bob_mesh.material_override = _bob_mat
	_arm_pivot.add_child(bob_mesh)

	_bob_light = OmniLight3D.new()
	_bob_light.position = bob_pos
	_bob_light.light_color = Color(1.0, 0.72, 0.34)
	_bob_light.light_energy = 2.5
	_bob_light.omni_range = 8.0
	_arm_pivot.add_child(_bob_light)

	_bob_area = Area3D.new()
	_bob_area.name = "PendulumHitArea"
	_bob_area.position = bob_pos
	_bob_area.collision_layer = 0
	_bob_area.collision_mask = 2
	_bob_area.monitoring = true
	_bob_area.monitorable = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
	cs.shape = sph
	_bob_area.add_child(cs)
	_bob_area.body_entered.connect(_on_bob_body_entered)
	_arm_pivot.add_child(_bob_area)


func _on_dimension_shifted(is_in_memory: bool) -> void:
	# Remembered = bergerak & berbahaya; Forgotten = beku & aman dilewati
	is_frozen = not is_in_memory
	if _bob_area:
		_bob_area.set_deferred("monitoring", not is_frozen)
	if _bob_mat:
		if is_frozen:
			_bob_mat.emission = Color(0.28, 0.65, 0.85)
			_bob_mat.emission_energy_multiplier = 0.22
		else:
			_bob_mat.emission = Color(0.75, 0.44, 0.14)
			_bob_mat.emission_energy_multiplier = 0.32
	if _bob_light:
		_bob_light.light_color = Color(0.45, 0.85, 1.0) if is_frozen else Color(1.0, 0.72, 0.34)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _hit_cooldown > 0.0:
		_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if not is_frozen:
		_swing_phase += delta * swing_speed
		_update_arm_angle()


func _update_arm_angle() -> void:
	if _arm_pivot:
		# Ayun di bidang YZ (mengitari sumbu X) melintasi jalur batu loncatan
		_arm_pivot.rotation_degrees.x = sin(_swing_phase) * max_swing_degrees


func _on_bob_body_entered(body: Node3D) -> void:
	if is_frozen or _hit_cooldown > 0.0:
		return
	if not (body is CharacterBody3D):
		return
	_hit_cooldown = 0.65
	var char_body := body as CharacterBody3D
	var push_dir := Vector3(0.0, 0.35, 1.0 if cos(_swing_phase) >= 0.0 else -1.0).normalized()
	char_body.velocity = push_dir * knockback_speed
	var rig := get_tree().current_scene.find_child("CameraRig", true, false) if get_tree() and get_tree().current_scene else null
	if rig and rig.has_method("trigger_dimension_shake"):
		rig.call("trigger_dimension_shake", 0.45, 0.22)
