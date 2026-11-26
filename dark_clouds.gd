@tool
class_name DarkClouds
extends Node3D

## DarkClouds
##
## Stylized, atmospheric dark storm cloud and drifting fog system for the Main Menu.
## Creates an organic, dynamic backdrop representing stormy / gloomy skies as the character
## falls into the void, with:
##   1. A procedural domain-warped FBM background cloud bank with upward drift and subtle billow.
##   2. Layered 3D drifting cloud puffs that float upward with organic parallax and shape morphing.
##   3. Strict lateral screen masking (UI protection) ensuring the right-side menu text and buttons
##      remain 100% crisp, unobstructed, and readable.
##
## Engine: Godot 4.x.

# ==============================================================================
# INSPECTOR EXPORTS
# ==============================================================================

@export_group("Dark Clouds Atmosphere")
## Enable or disable the entire dark cloud system.
@export var enable_clouds: bool = true:
	set(value):
		enable_clouds = value
		visible = enable_clouds
		_update_visibility()

## Overall simulation speed multiplier for cloud drift and billowing.
@export_range(0.1, 4.0, 0.05) var cloud_speed: float = 1.0

## Deepest shadow tint of the dark storm cloud underbellies.
@export var dark_belly_color: Color = Color(0.06, 0.07, 0.09, 0.96):
	set(value):
		dark_belly_color = value
		_sync_shader_parameters()

## Smoky mid-tone body of the dark clouds.
@export var cloud_body_color: Color = Color(0.20, 0.22, 0.28, 0.90):
	set(value):
		cloud_body_color = value
		_sync_shader_parameters()

## Soft silver-grey edge highlight catching ambient celestial light on billows.
@export var cloud_highlight_color: Color = Color(0.38, 0.42, 0.50, 0.75):
	set(value):
		cloud_highlight_color = value
		_sync_shader_parameters()

@export_group("3D Drifting Puffs")
## Enable drifting 3D cloud wisps floating past the character.
@export var enable_3d_puffs: bool = true:
	set(value):
		enable_3d_puffs = value
		if _puffs_container != null and is_instance_valid(_puffs_container):
			_puffs_container.visible = enable_3d_puffs

## Upward vertical drift speed of the 3D cloud puffs in meters per second.
@export_range(0.05, 1.5, 0.05) var puff_drift_speed: float = 0.28

@export_group("Editor Preview")
## Preview cloud movement live inside the Godot Editor viewport.
@export var preview_in_editor: bool = false

# ==============================================================================
# PRIVATE STATE & CONFIG
# ==============================================================================

class CloudPuffData:
	var node: MeshInstance3D
	var base_z: float = 0.0
	var speed: float = 0.2
	var sway_freq: float = 1.0
	var sway_phase: float = 0.0

var _bg_plane: MeshInstance3D = null
var _puffs_container: Node3D = null
var _puffs_data: Array[CloudPuffData] = []
var _bg_material: ShaderMaterial = null
var _time: float = 0.0
var _is_initialized: bool = false

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_system()
	_update_visibility()
	_sync_shader_parameters()
	_is_initialized = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return

	if not _is_initialized:
		_setup_system()
		_is_initialized = true

	_time += delta * cloud_speed

	# Update camera-aligned background orientation if camera is present
	_align_bg_with_camera()

	# Frame-rate independent delta accumulation for drifting 3D puffs
	if enable_3d_puffs and _puffs_container != null and _puffs_container.visible:
		var effective_speed: float = puff_drift_speed * cloud_speed
		for puff_data in _puffs_data:
			if puff_data.node == null or not is_instance_valid(puff_data.node):
				continue
			var pos := puff_data.node.position
			pos.y += effective_speed * puff_data.speed * delta
			# Wrap around vertically once past the upper screen bounds (Y ≈ 3.2 -> -2.2)
			if pos.y > 3.2:
				pos.y = -2.2
			# Subtle lateral swaying against wind currents
			pos.z = puff_data.base_z + sin(_time * puff_data.sway_freq + puff_data.sway_phase) * 0.08
			puff_data.node.position = pos

# ==============================================================================
# SETUP & PROCEDURAL CREATION
# ==============================================================================

func _setup_system() -> void:
	# Avoid duplicate instantiation if nodes already exist in scene
	if _bg_plane == null:
		_bg_plane = get_node_or_null("BackgroundPlane") as MeshInstance3D
	if _puffs_container == null:
		_puffs_container = get_node_or_null("DriftingPuffs") as Node3D

	# 1. Background Stylized Dark Storm Clouds Plane
	if _bg_plane == null:
		_bg_plane = MeshInstance3D.new()
		_bg_plane.name = "BackgroundPlane"
		var qmesh := QuadMesh.new()
		# Size generously covers standard 16:9 and 21:9 ultrawide viewports
		qmesh.size = Vector2(10.0, 5.2)
		_bg_plane.mesh = qmesh
		# Placed cleanly between character (dist ~2.0) and static bg (dist ~3.7)
		_bg_plane.position = Vector3(-1.35, 0.86, -0.73)
		_bg_plane.rotation_degrees = Vector3(0, 91.89, 0)
		add_child(_bg_plane)

	_bg_material = _create_bg_cloud_material()
	_bg_plane.material_override = _bg_material
	_align_bg_with_camera()

	# 2. 3D Drifting Cloud Puffs Container
	if _puffs_container == null:
		_puffs_container = Node3D.new()
		_puffs_container.name = "DriftingPuffs"
		add_child(_puffs_container)

	_build_cloud_puffs()


func _align_bg_with_camera() -> void:
	if _bg_plane == null or not is_instance_valid(_bg_plane):
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null and is_instance_valid(cam):
		# Align plane basis with camera basis for perfect perpendicular framing
		_bg_plane.global_transform.basis = cam.global_transform.basis
		# Place 3.2m along camera forward vector (-basis.z) to avoid clipping background quad
		_bg_plane.global_position = cam.global_position + (-cam.global_transform.basis.z * 3.2)


func _create_bg_cloud_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform vec4 dark_belly : source_color = vec4(0.06, 0.07, 0.09, 0.96);
uniform vec4 cloud_body : source_color = vec4(0.20, 0.22, 0.28, 0.90);
uniform vec4 cloud_highlight : source_color = vec4(0.38, 0.42, 0.50, 0.75);
uniform float drift_speed = 0.04;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm_clouds(vec2 p) {
    float v = 0.0;
    float a = 0.52;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.05 + vec2(1.7, 4.3);
        a *= 0.48;
    }
    return v;
}

void fragment() {
    // Quad UV: UV.x = 0 (left) to 1 (right), UV.y = 0 (top) to 1 (bottom)
    vec2 uv = vec2(UV.x * 3.2, UV.y * 1.8);

    // Upward drift (rising storm atmosphere) + gentle lateral billowing
    vec2 drift1 = vec2(sin(TIME * 0.15) * 0.08, -TIME * drift_speed);
    vec2 drift2 = vec2(-sin(TIME * 0.12 + 1.2) * 0.06, -TIME * drift_speed * 1.35 + 3.1);

    // Domain warped noise for fluid, curling storm billows
    vec2 warp = vec2(
        noise(uv + drift1 * 0.5),
        noise(uv + vec2(5.2, 1.3) + drift2 * 0.5)
    );

    float n1 = fbm_clouds(uv + drift1 + warp * 0.45);
    float n2 = fbm_clouds(uv * 1.35 + drift2 + warp * 0.35);
    float n = mix(n1, n2, 0.48);

    // Stylized cloud tonal density with crisp billow contrast
    float cloud_mask = smoothstep(0.22, 0.70, n);
    float billow_rim = smoothstep(0.48, 0.60, n) * (1.0 - smoothstep(0.60, 0.74, n));

    // UI protection mask: smoothly fades out on screen-right (UV.x > 0.52)
    // Keeps "JUDUL" and menu buttons completely clear and readable
    float ui_protect = 1.0 - smoothstep(0.50, 0.76, UV.x);

    // Rich dark monochrome cloud gradient with clear tonal definition
    vec3 col = mix(dark_belly.rgb, cloud_body.rgb, smoothstep(0.26, 0.62, n));
    col = mix(col, cloud_highlight.rgb, billow_rim * 0.85);

    ALBEDO = col;
    ALPHA = cloud_mask * ui_protect * dark_belly.a;
}
"""
	mat.shader = shader
	return mat


func _build_cloud_puffs() -> void:
	_puffs_data.clear()
	for child in _puffs_container.get_children():
		child.queue_free()

	var puff_shader := Shader.new()
	puff_shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform vec4 puff_core : source_color = vec4(0.10, 0.11, 0.15, 0.70);
uniform vec4 puff_rim : source_color = vec4(0.32, 0.35, 0.42, 0.55);
uniform float time_offset = 0.0;

void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float angle = atan(p.y, p.x);

    // Dynamic curling lobes rippling gently
    float lobe1 = sin(angle * 3.0 + time_offset + TIME * 0.32) * 0.14;
    float lobe2 = cos(angle * 5.0 - time_offset * 1.2 - TIME * 0.22) * 0.09;
    float boundary = 0.82 + lobe1 + lobe2;

    float alpha = smoothstep(boundary, 0.15, r);
    float rim = smoothstep(boundary - 0.25, boundary, r) * (1.0 - smoothstep(boundary, boundary + 0.05, r));

    vec3 col = mix(puff_core.rgb, puff_rim.rgb, smoothstep(0.12, 0.68, r));
    col += puff_rim.rgb * rim * 0.7;

    ALBEDO = col;
    ALPHA = alpha * puff_core.a;
}
"""
	# Spawn 6 distinct drifting cloud puffs across depths around character
	# Camera is at Z = -0.85, Character is at Z = -0.11
	# Screen left spans Z from -0.6 to +0.6
	var configs: Array[Dictionary] = [
		{"pos": Vector3(-0.95, -0.8, -0.05), "size": Vector2(2.8, 1.8), "offset": 0.0, "speed": 1.05, "freq": 0.8, "phase": 0.0},
		{"pos": Vector3(-1.25, 0.8, 0.25), "size": Vector2(3.2, 2.0), "offset": 1.6, "speed": 0.85, "freq": 0.6, "phase": 1.4},
		{"pos": Vector3(-0.80, 2.0, -0.35), "size": Vector2(2.6, 1.6), "offset": 3.2, "speed": 1.20, "freq": 1.0, "phase": 2.7},
		{"pos": Vector3(-1.10, -1.5, 0.10), "size": Vector2(3.0, 1.9), "offset": 4.5, "speed": 0.95, "freq": 0.7, "phase": 4.1},
		{"pos": Vector3(-0.70, 0.4, 0.35), "size": Vector2(2.4, 1.5), "offset": 2.1, "speed": 1.10, "freq": 0.9, "phase": 5.0},
		{"pos": Vector3(-1.35, -0.2, -0.40), "size": Vector2(3.5, 2.2), "offset": 5.8, "speed": 0.80, "freq": 0.5, "phase": 3.3},
	]

	for cfg in configs:
		var qmesh := QuadMesh.new()
		qmesh.size = cfg["size"]
		var mi := MeshInstance3D.new()
		mi.name = "Puff_" + str(configs.find(cfg))
		mi.mesh = qmesh
		mi.position = cfg["pos"]
		# Face towards camera
		mi.rotation_degrees = Vector3(0, 91.89, 0)

		var mat := ShaderMaterial.new()
		mat.shader = puff_shader
		mat.set_shader_parameter("time_offset", cfg["offset"])
		mat.set_shader_parameter("puff_core", Color(dark_belly_color.r * 1.6, dark_belly_color.g * 1.6, dark_belly_color.b * 1.9, 0.70))
		mat.set_shader_parameter("puff_rim", cloud_highlight_color)
		mi.material_override = mat
		_puffs_container.add_child(mi)

		var pdata := CloudPuffData.new()
		pdata.node = mi
		pdata.base_z = (cfg["pos"] as Vector3).z
		pdata.speed = cfg["speed"]
		pdata.sway_freq = cfg["freq"]
		pdata.sway_phase = cfg["phase"]
		_puffs_data.append(pdata)


func _update_visibility() -> void:
	if _bg_plane != null and is_instance_valid(_bg_plane):
		_bg_plane.visible = enable_clouds
	if _puffs_container != null and is_instance_valid(_puffs_container):
		_puffs_container.visible = enable_clouds and enable_3d_puffs


func _sync_shader_parameters() -> void:
	if _bg_material != null:
		_bg_material.set_shader_parameter("dark_belly", dark_belly_color)
		_bg_material.set_shader_parameter("cloud_body", cloud_body_color)
		_bg_material.set_shader_parameter("cloud_highlight", cloud_highlight_color)

	for pdata in _puffs_data:
		if pdata.node != null and is_instance_valid(pdata.node) and pdata.node.material_override is ShaderMaterial:
			var mat := pdata.node.material_override as ShaderMaterial
			mat.set_shader_parameter("puff_core", Color(dark_belly_color.r * 1.6, dark_belly_color.g * 1.6, dark_belly_color.b * 1.9, 0.70))
			mat.set_shader_parameter("puff_rim", cloud_highlight_color)
