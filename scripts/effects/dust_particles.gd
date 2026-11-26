extends GPUParticles3D

# ============================================================================
# DustParticles — Partikel debu melayang atmospheric (Little Nightmares Style)
# Partikel debu halus dan tipis dengan tekstur radial blur lembut (bukan piksel kotak/bintang).
# ============================================================================

@export var player: Node3D = null
@export var follow_player: bool = true

func _ready() -> void:
	if player == null:
		player = get_node_or_null("../Player")

	# Konfigurasi partikel debu halus atmosferik (Little Nightmares Style)
	amount = 90
	preprocess = 4.0
	visibility_aabb = AABB(Vector3(-35, -12, -35), Vector3(70, 24, 70))
	emitting = true
	lifetime = 12.0
	randomness = 0.5

	# Setup Process Material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18.0, 7.0, 12.0)

	mat.direction = Vector3(0.0, 0.3, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.10
	mat.gravity = Vector3(0.0, -0.01, 0.0)
	mat.lifetime_randomness = 0.4

	# Turbulence untuk gerakan organik melayang lembut
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.8
	mat.turbulence_noise_speed_random = 0.25
	mat.turbulence_noise_scale = 3.0
	mat.turbulence_influence_min = 0.10
	mat.turbulence_influence_max = 0.35

	# Variasi ukuran partikel debu mikro (scale_min = 0.4, scale_max = 1.1)
	mat.scale_min = 0.4
	mat.scale_max = 1.1

	# Warna pudar lembut masuk dan keluar
	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.20, Color(1, 1, 1, 1.0))
	gradient.add_point(0.80, Color(1, 1, 1, 0.85))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	process_material = mat

	# Setup Radial GradientTexture2D (buram lembut agar terlihat alami melayang di berkas cahaya)
	var rad_grad := Gradient.new()
	rad_grad.set_color(0, Color(1.0, 1.0, 1.0, 0.28))
	rad_grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var rad_tex := GradientTexture2D.new()
	rad_tex.gradient = rad_grad
	rad_tex.fill = GradientTexture2D.FILL_RADIAL
	rad_tex.fill_from = Vector2(0.5, 0.5)
	rad_tex.fill_to = Vector2(0.5, 0.0)
	rad_tex.width = 64
	rad_tex.height = 64

	# Setup QuadMesh proporsional agar terbaca di jarak kamera 2.5D (~24m)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.065, 0.065)

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.albedo_texture = rad_tex
	mesh_mat.albedo_color = Color(0.95, 0.90, 0.80, 1.0)
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_mat.no_depth_test = false
	mesh_mat.render_priority = -1
	quad.material = mesh_mat

	draw_pass_1 = quad


func _process(_delta: float) -> void:
	# Partikel mengikuti posisi player agar selalu padat melayang di sekitarnya
	if follow_player and player and is_instance_valid(player):
		global_position = player.global_position + Vector3(0.0, 2.5, 0.0)
