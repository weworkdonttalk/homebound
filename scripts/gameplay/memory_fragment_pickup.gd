@tool
class_name MemoryFragmentPickup
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Fragmen Ingatan Waktu (Clock Memory Fragment) untuk Puzzle 3 (The Erased Room).
## Dapat diset ke "Remembered" atau "Forgotten" agar pemain memakai [T] untuk menemukannya.

signal collected(fragment: Node3D)

@export_enum("Always", "Remembered", "Forgotten") var visible_dimension: String = "Remembered"
@export var interact_range: float = 2.6

var is_collected: bool = false

var _visual_core: Node3D = null
var _light: OmniLight3D = null
var _prompt_label: Label3D = null
var _active_in_dim: bool = true
var _player_near: bool = false
var _player: CharacterBody3D = null
var _world: Node = null
var _time_acc: float = 0.0


func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		if _visual_core:
			_visual_core.visible = true
		if _prompt_label:
			_prompt_label.text = "[E] Fragmen Waktu (%s)" % visible_dimension
			_prompt_label.visible = true
		return
	_world = Ch2Utils.find_world_manager(self)
	_player = Ch2Utils.find_player(self)
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)


func _build_visual() -> void:
	if get_node_or_null("FragmentCore") != null:
		return
	_visual_core = Node3D.new()
	_visual_core.name = "FragmentCore"
	add_child(_visual_core)

	# Inti kristal berputar + orrery mini
	var crystal := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.42, 0.65, 0.42)
	crystal.mesh = pm
	var mat := StandardMaterial3D.new()
	var col := Color(0.42, 0.92, 1.0) if visible_dimension != "Forgotten" else Color(1.0, 0.72, 0.32)
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.4
	crystal.material_override = mat
	_visual_core.add_child(crystal)

	# Cincin luar melingkari fragmen
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.40
	ring.mesh = tm
	ring.material_override = mat
	_visual_core.add_child(ring)

	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 2.4
	_light.omni_range = 5.0
	_visual_core.add_child(_light)

	_prompt_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 1.05, 0.0), Color(1.0, 0.95, 0.78), 32)


func _on_dimension_shifted(is_in_memory: bool) -> void:
	if is_collected:
		return
	match visible_dimension:
		"Remembered":
			_active_in_dim = is_in_memory
		"Forgotten":
			_active_in_dim = not is_in_memory
		_:
			_active_in_dim = true
	if _visual_core:
		_visual_core.visible = _active_in_dim


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or is_collected:
		return
	_time_acc += delta
	if _visual_core and _active_in_dim:
		_visual_core.position.y = sin(_time_acc * 2.4) * 0.14
		_visual_core.rotation.y += delta * 1.6

	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return

	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var same_floor := absf(_player.global_position.y - global_position.y) < 3.0
	_player_near = _active_in_dim and same_floor and dist <= interact_range
	if _prompt_label:
		_prompt_label.visible = _player_near
		if _player_near:
			_prompt_label.text = "[E] Ambil Fragmen Waktu"


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or is_collected or not _player_near or not _active_in_dim:
		return
	if Ch2Utils.is_player_busy(_player):
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	get_viewport().set_input_as_handled()
	collect()


func collect() -> void:
	if is_collected:
		return
	is_collected = true
	_player_near = false
	if _prompt_label:
		_prompt_label.visible = false
	if _visual_core:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_visual_core, "scale", Vector3(1.6, 1.6, 1.6), 0.22)
		tw.tween_property(_visual_core, "position:y", 1.2, 0.22)
		tw.finished.connect(func() -> void:
			if is_instance_valid(_visual_core):
				_visual_core.visible = false
		)
	collected.emit(self)
