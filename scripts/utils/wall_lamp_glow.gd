class_name WallLampGlow
extends Node3D

## ============================================================================
## WallLampGlow — Membuat lampu dinding GLB menyala hangat secara visual (emissive)
## dan memancarkan OmniLight3D lembut dengan flicker horor halus.
## ============================================================================

@export var light_color: Color = Color(1.0, 0.72, 0.36, 1.0)
@export var light_energy: float = 3.2
@export var omni_range: float = 9.5
@export var light_local_offset: Vector3 = Vector3(0.0, 0.08, 0.14)
@export var flicker_amount: float = 0.12

var _lamp_light: OmniLight3D = null
var _base_energy: float = 3.2
var _time: float = 0.0


func _ready() -> void:
	_base_energy = light_energy
	_time = randf() * 10.0
	_setup_emissive_materials()
	_setup_omni_light()


func _setup_emissive_materials() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null:
			continue
		var lower := mi.name.to_lower()
		var base_mat := mi.get_active_material(0)
		var mat: StandardMaterial3D = null
		if base_mat is StandardMaterial3D:
			mat = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			mat = StandardMaterial3D.new()

		if "bulb" in lower:
			mat.albedo_color = Color(1.0, 0.9, 0.72, 1.0)
			mat.emission_enabled = true
			mat.emission = light_color
			mat.emission_energy_multiplier = 4.5
			mi.material_override = mat
		elif "cloth" in lower:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.65, 0.28, 1.0)
			mat.emission_energy_multiplier = 0.95
			mi.material_override = mat


func _setup_omni_light() -> void:
	_lamp_light = get_node_or_null("WallLampOmni") as OmniLight3D
	if _lamp_light == null:
		_lamp_light = OmniLight3D.new()
		_lamp_light.name = "WallLampOmni"
		_lamp_light.position = light_local_offset
		_lamp_light.light_color = light_color
		_lamp_light.light_energy = _base_energy
		_lamp_light.omni_range = omni_range
		_lamp_light.omni_attenuation = 1.25
		_lamp_light.shadow_enabled = false
		add_child(_lamp_light)


func _process(delta: float) -> void:
	if _lamp_light == null or flicker_amount <= 0.0:
		return
	_time += delta
	var pulse := sin(_time * 3.1) * 0.55 + sin(_time * 7.9) * 0.45
	_lamp_light.light_energy = _base_energy * (1.0 + pulse * flicker_amount)


func _exit_tree() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi and mi.material_override != null:
			mi.material_override = null
