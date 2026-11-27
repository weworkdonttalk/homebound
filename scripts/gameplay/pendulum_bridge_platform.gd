@tool
class_name PendulumBridgePlatform
extends StaticBody3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Jembatan/platform bergantian dimensi untuk Puzzle 4 (The Pendulum).
## Default: solid di Remembered, menghilang (jadi bayangan hantu non-solid) di Forgotten,
## memaksa pemain mengombinasikan beku-pendulum (Forgotten) dan platform solid (Remembered).

@export_enum("Remembered", "Forgotten") var solid_dimension: String = "Remembered"
@export var platform_size: Vector3 = Vector3(3.6, 0.28, 4.0)

var is_solid: bool = true

var _mesh: MeshInstance3D = null
var _col: CollisionShape3D = null
var _solid_mat: StandardMaterial3D = null
var _ghost_mat: StandardMaterial3D = null
var _world: Node = null


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build_platform()
	if Engine.is_editor_hint():
		if _mesh:
			_mesh.material_override = _solid_mat
		return
	_world = Ch2Utils.find_world_manager(self)
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)


func _build_platform() -> void:
	if get_node_or_null("BridgeMesh") != null:
		_mesh = get_node_or_null("BridgeMesh") as MeshInstance3D
		return
	_mesh = MeshInstance3D.new()
	_mesh.name = "BridgeMesh"
	var bm := BoxMesh.new()
	bm.size = platform_size
	_mesh.mesh = bm
	add_child(_mesh)

	_solid_mat = StandardMaterial3D.new()
	_solid_mat.albedo_color = Color(0.18, 0.26, 0.32, 1.0)
	_solid_mat.metallic = 0.32
	_solid_mat.roughness = 0.72
	_solid_mat.emission_enabled = true
	_solid_mat.emission = Color(0.20, 0.55, 0.75)
	_solid_mat.emission_energy_multiplier = 0.28

	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.30, 0.65, 0.88, 0.14)
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(0.30, 0.65, 0.88)
	_ghost_mat.emission_energy_multiplier = 0.18

	_col = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = platform_size
	_col.shape = bs
	add_child(_col)


func _on_dimension_shifted(is_in_memory: bool) -> void:
	is_solid = (solid_dimension == "Remembered" and is_in_memory) or (solid_dimension == "Forgotten" and not is_in_memory)
	if _col:
		_col.set_deferred("disabled", not is_solid)
	if _mesh:
		_mesh.material_override = _solid_mat if is_solid else _ghost_mat
