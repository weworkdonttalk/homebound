@tool
class_name DivineLight
extends Node3D

## DivineLight
##
## Stylized volumetric divine light beam and heavenly illumination system.
## Highlights the falling character from the celestial void above with:
##   1. Translucent volumetric crepuscular god-rays streaming downward from the heavens.
##   2. Center-softened Fresnel falloff ensuring the character's low-poly facets and details
##      remain crisp, shaded, and distinct inside the light shaft without blowout.
##   3. A targeted celestial SpotLight3D physically illuminating character contours & envelope wax seal.
##
## Engine: Godot 4.x.

# ==============================================================================
# INSPECTOR EXPORTS
# ==============================================================================

@export_group("Divine Light Beam")
## Enable or disable the entire divine light system.
@export var enable_divine_light: bool = true:
	set(value):
		enable_divine_light = value
		visible = enable_divine_light
		_update_visibility()

## Celestial tint and base alpha of the volumetric light shaft.
@export var beam_color: Color = Color(1.0, 0.95, 0.84, 0.18):
	set(value):
		beam_color = value
		_sync_shader_parameters()

## Core luminescence multiplier for the divine shaft.
@export_range(0.5, 4.0, 0.05) var beam_intensity: float = 1.35:
	set(value):
		beam_intensity = value
		_sync_shader_parameters()

## Falloff exponent controlling how smoothly the outer edges of the beam fade into transparency.
@export_range(1.0, 6.0, 0.1) var edge_falloff: float = 2.2:
	set(value):
		edge_falloff = value
		_sync_shader_parameters()

@export_group("Targeted SpotLight")
## Enable physical 3D spotlight highlighting the low-poly character and wax envelope.
@export var enable_spotlight: bool = true:
	set(value):
		enable_spotlight = value
		_update_visibility()

## Energy intensity of the overhead divine spotlight.
@export_range(0.0, 5.0, 0.05) var spotlight_energy: float = 1.35:
	set(value):
		spotlight_energy = value
		_sync_shader_parameters()

## Light color of the overhead spotlight.
@export var spotlight_color: Color = Color(1.0, 0.96, 0.88):
	set(value):
		spotlight_color = value
		_sync_shader_parameters()

@export_group("Editor Preview")
## Preview divine illumination live inside the Godot Editor viewport.
@export var preview_in_editor: bool = false:
	set(value):
		preview_in_editor = value
		if Engine.is_editor_hint() and is_inside_tree():
			if preview_in_editor:
				_setup_system()
			else:
				_cleanup_procedural_nodes()

# ==============================================================================
# CONSTANTS & PRIVATE STATE
# ==============================================================================

const BEAM_NODE_NAME := &"_DivineBeamCone"
const SPOT_NODE_NAME := &"_DivineSpotLight"

var _beam_mesh_inst: MeshInstance3D = null
var _beam_material: ShaderMaterial = null
var _spotlight: SpotLight3D = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		_cleanup_procedural_nodes()
		return

	_setup_system()


func _exit_tree() -> void:
	# Bersihkan node internal saat node keluar dari tree di editor agar tidak bocor
	if Engine.is_editor_hint():
		_cleanup_procedural_nodes()

# ==============================================================================
# SETUP & CLEANUP
# ==============================================================================

func _cleanup_procedural_nodes() -> void:
	# Hapus node internal maupun sisa node lama yang mungkin sempat tersimpan di .tscn
	for child in get_children(true):
		if child.name in [BEAM_NODE_NAME, SPOT_NODE_NAME, &"BeamCone", &"SpotLight", &"DivineMotes"]:
			remove_child(child)
			child.queue_free()

	_beam_mesh_inst = null
	_beam_material = null
	_spotlight = null


func _setup_system() -> void:
	_cleanup_procedural_nodes()

	# 1. Volumetric Light Cone Mesh
	_beam_mesh_inst = MeshInstance3D.new()
	_beam_mesh_inst.name = BEAM_NODE_NAME
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 1.15 # Sedikit diperlebar agar sebaran cahaya lebih natural
	cyl.height = 4.6
	cyl.radial_segments = 64 # Lebih halus agar tidak terlihat segi-segi poligon di tepi
	cyl.rings = 8
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam_mesh_inst.mesh = cyl
	_beam_mesh_inst.position = Vector3(-0.01, 1.5, -0.20)

	_beam_material = _create_beam_material()
	_beam_mesh_inst.material_override = _beam_material
	add_child(_beam_mesh_inst, false, Node.INTERNAL_MODE_FRONT)

	# 2. Celestial Overhead SpotLight3D
	_spotlight = SpotLight3D.new()
	_spotlight.name = SPOT_NODE_NAME
	_spotlight.position = Vector3(-0.01, 3.5, -0.20)
	_spotlight.rotation_degrees = Vector3(-90, 0, 0)
	_spotlight.spot_angle = 28.0
	_spotlight.spot_angle_attenuation = 1.8 # Memperhalus pinggiran sorotan lampu pada karakter
	_spotlight.spot_attenuation = 1.2
	_spotlight.spot_range = 6.5
	_spotlight.light_volumetric_fog_energy = 3.5 # Menerangi kabut volumetrik di sekitar karakter
	add_child(_spotlight, false, Node.INTERNAL_MODE_FRONT)

	_update_visibility()
	_sync_shader_parameters()


func _create_beam_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
// Ubah cull_disabled menjadi cull_back untuk menghilangkan garis tepi ganda
render_mode blend_add, cull_back, depth_draw_never, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.95, 0.84, 0.16);
uniform float core_intensity = 1.35;
uniform float edge_falloff = 3.2;

void fragment() {
	// Transisi vertikal lebih panjang dan lembut dari atas ke bawah
	float v_in = smoothstep(0.0, 0.25, UV.y);
	float v_out = smoothstep(1.0, 0.35, UV.y);
	float v_grad = v_in * v_out;

	// Crepuscular god-ray shafts yang lebih organik
	float ray1 = sin(UV.x * 18.0 + TIME * 0.35) * 0.30;
	float ray2 = sin(UV.x * 38.0 - TIME * 0.55) * 0.22;
	float ray3 = cos(UV.x * 10.0 + TIME * 0.20) * 0.25;
	float rays_raw = 0.55 + ray1 + ray2 + ray3;
	float rays = smoothstep(0.15, 0.90, rays_raw);

	// Fresnel edge falloff murni (0 di pinggir, 1 di tengah)
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(facing, edge_falloff);

	// Center softening agar karakter di tengah tetap kontras dan tidak silau
	float center_soften = mix(0.65, 1.0, pow(1.0 - facing, 1.5));

	// Pulsasi lembut
	float pulse = 0.94 + 0.06 * sin(TIME * 1.2);

	// Pendaran puncak cahaya dari awan atas
	float zenith_glow = smoothstep(0.30, 0.0, UV.y) * 0.30;

	float alpha = v_grad * fresnel * center_soften * (rays + zenith_glow) * pulse * beam_color.a;
	ALBEDO = beam_color.rgb * core_intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""
	mat.shader = shader
	return mat


func _update_visibility() -> void:
	if is_instance_valid(_beam_mesh_inst):
		_beam_mesh_inst.visible = enable_divine_light
	if is_instance_valid(_spotlight):
		_spotlight.visible = enable_divine_light and enable_spotlight


func _sync_shader_parameters() -> void:
	if is_instance_valid(_beam_material):
		_beam_material.set_shader_parameter("beam_color", beam_color)
		_beam_material.set_shader_parameter("core_intensity", beam_intensity)
		_beam_material.set_shader_parameter("edge_falloff", edge_falloff)

	if is_instance_valid(_spotlight):
		_spotlight.light_energy = spotlight_energy
		_spotlight.light_color = spotlight_color
