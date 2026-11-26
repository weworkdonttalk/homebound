extends Node3D
class_name GuidingTrail

# ============================================================================
# GuidingTrail — Sistem Jejak Cahaya / Asap Tipis Pemandu Arah (Little Nightmares Style)
# Mengalirkan 'GuidingWisp' (partikel asap bercahaya + omnilight lembut) dari karakter
# menuju titik tujuan berikutnya tanpa teks petunjuk UI di layar.
# ============================================================================

## Target karakter yang diikuti / asal luncuran trail
@export var player: Node3D = null

## Daftar waypoint utama secara berurutan sesuai progres teka-teki
@export var waypoints: Array[Node3D] = []

@export_group("Wisp Flight Settings")
## Durasi peluncuran wisp dari player ke waypoint (detik)
@export_range(1.0, 5.0) var flight_duration: float = 2.0

## Amplitudo gelombang sinus (ketinggian lengkungan di udara)
@export_range(0.2, 3.0) var arc_height: float = 1.3

## Amplitudo goyangan horizontal gelombang sinus
@export_range(0.0, 2.0) var sway_amplitude: float = 0.55

## Frekuensi gelombang sinus saat terbang
@export_range(0.5, 4.0) var wave_frequency: float = 1.2

@export_group("Trigger Timers")
## Interval pengulangan otomatis kemunculan trail saat player belum sampai (detik)
@export_range(3.0, 15.0) var auto_interval: float = 7.0

## Waktu diam sebelum memicu trail secara otomatis (detik)
@export_range(1.0, 10.0) var idle_trigger_time: float = 3.0

var _current_waypoint_index: int = 0
var _is_flying: bool = false
var _flight_time: float = 0.0
var _start_pos: Vector3 = Vector3.ZERO
var _target_pos: Vector3 = Vector3.ZERO
var _idle_timer: float = 0.0
var _auto_timer: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO

# Sub-nodes
var _wisp: Node3D = null
var _particles: GPUParticles3D = null
var _light: OmniLight3D = null
var _base_light_energy: float = 0.6


func _ready() -> void:
	if player == null:
		player = get_node_or_null("../Player")

	_setup_wisp_nodes()

	if player:
		_last_player_pos = player.global_position


func _setup_wisp_nodes() -> void:
	# Cek apakah sudah ada node GuidingWisp di scene
	_wisp = get_node_or_null("GuidingWisp")
	if _wisp == null:
		_wisp = Node3D.new()
		_wisp.name = "GuidingWisp"
		add_child(_wisp)

	# 1. Setup GPUParticles3D (ekor asap / debu bercahaya halus)
	_particles = _wisp.get_node_or_null("GPUParticles3D") as GPUParticles3D
	if _particles == null:
		_particles = GPUParticles3D.new()
		_particles.name = "GPUParticles3D"
		_wisp.add_child(_particles)

	_particles.amount = 40
	_particles.lifetime = 1.2
	_particles.preprocess = 0.1
	_particles.local_coords = false  # Meninggalkan ekor saat wisp bergerak di dunia
	_particles.emitting = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.4
	_particles.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.18
	pmat.direction = Vector3(0.0, 0.2, 0.0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 0.05
	pmat.initial_velocity_max = 0.25
	pmat.gravity = Vector3(0.0, 0.08, 0.0)  # Perlahan melayang naik seperti uap tipis
	pmat.scale_min = 0.6
	pmat.scale_max = 1.4

	# Warna putih hangat pudar #ffe4b5 dengan alpha ~0.35
	pmat.color = Color(1.0, 0.894, 0.71, 0.35)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.75, 0.0))
	grad.add_point(0.2, Color(1.0, 0.894, 0.71, 0.35))
	grad.add_point(0.7, Color(1.0, 0.85, 0.65, 0.20))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.80, 0.60, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pmat.color_ramp = ramp
	_particles.process_material = pmat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.albedo_color = Color(1.0, 0.894, 0.71, 0.35)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.no_depth_test = false
	quad.material = smat
	_particles.draw_pass_1 = quad

	# 2. Setup OmniLight3D (pantulan lembut di lantai dan perabot)
	_light = _wisp.get_node_or_null("OmniLight3D") as OmniLight3D
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "OmniLight3D"
		_wisp.add_child(_light)

	_light.omni_range = 2.2
	_light.light_energy = _base_light_energy
	_light.light_color = Color("#ffd89b")
	_light.shadow_enabled = false
	_light.visible = false

	_wisp.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Tombol [Q] memicu petunjuk arah trail secara manual
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.physical_keycode == KEY_Q:
			trigger_trail(true)
	elif event.is_action_pressed("hint"):
		trigger_trail(true)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_update_active_waypoint()

	# Cek apakah player bergerak atau diam
	var dist_moved := player.global_position.distance_to(_last_player_pos)
	_last_player_pos = player.global_position

	if dist_moved < 0.05:
		_idle_timer += delta
	else:
		_idle_timer = 0.0

	_auto_timer += delta

	# Memicu trail jika pemain diam > 3 detik atau interval berkala tercapai
	if not _is_flying:
		if _idle_timer >= idle_trigger_time:
			_idle_timer = 0.0
			_auto_timer = 0.0
			trigger_trail()
		elif _auto_timer >= auto_interval:
			_auto_timer = 0.0
			trigger_trail()

	# Jalankan animasi terbang wisp
	if _is_flying:
		_update_flight(delta)


func _update_active_waypoint() -> void:
	if waypoints.is_empty():
		return

	# Otomatis bergeser ke waypoint berikutnya jika player sudah melewati waypoint aktif
	var player_x: float = player.global_position.x
	while _current_waypoint_index < waypoints.size():
		var wp: Node3D = waypoints[_current_waypoint_index]
		if wp and is_instance_valid(wp):
			var dist_to_wp: float = player.global_position.distance_to(wp.global_position)
			# Waypoint dianggap terlewati jika player sudah lebih ke kanan (X lebih besar)
			# dan jarak horizontal sudah lewat atau pemain berada sangat dekat (< 2.2m)
			if dist_to_wp < 2.5 or (player_x > wp.global_position.x + 1.2):
				_current_waypoint_index += 1
			else:
				break
		else:
			_current_waypoint_index += 1

	# Clamp index ke waypoint terakhir jika sudah di ujung
	if _current_waypoint_index >= waypoints.size():
		_current_waypoint_index = waypoints.size() - 1


func trigger_trail(forced: bool = false) -> void:
	if _is_flying and not forced:
		return

	if waypoints.is_empty():
		return

	var target_node: Node3D = waypoints[clampi(_current_waypoint_index, 0, waypoints.size() - 1)]
	if target_node == null or not is_instance_valid(target_node):
		return

	_start_pos = player.global_position + Vector3(0.0, 1.4, 0.0)
	_target_pos = target_node.global_position + Vector3(0.0, 0.9, 0.0)

	# Jika player sudah sangat dekat dengan target akhir (< 1.5m), tidak perlu muncul
	if _start_pos.distance_to(_target_pos) < 1.8:
		return

	_is_flying = true
	_flight_time = 0.0

	if _wisp:
		_wisp.global_position = _start_pos
		_wisp.visible = true

	if _particles:
		_particles.emitting = true
		_particles.restart()

	if _light:
		_light.visible = true
		_light.light_energy = _base_light_energy


func _update_flight(delta: float) -> void:
	_flight_time += delta
	var t: float = clampf(_flight_time / flight_duration, 0.0, 1.0)

	# Interpolasi posisi dasar (garis lurus lerp)
	var base_pos: Vector3 = _start_pos.lerp(_target_pos, t)

	# Lengkungan gelombang sinus (organik & dinamis)
	var sine_progress: float = sin(t * PI)
	var arc_y: float = sine_progress * arc_height
	var sway_z: float = sin(t * PI * 2.0 * wave_frequency) * sway_amplitude

	var cur_pos := Vector3(base_pos.x, base_pos.y + arc_y, base_pos.z + sway_z)
	if _wisp:
		_wisp.global_position = cur_pos

	# Fade-out halus di akhir perjalanan (25% sisa durasi)
	if t > 0.75:
		var fade_t: float = (t - 0.75) / 0.25
		if _light:
			_light.light_energy = lerpf(_base_light_energy, 0.0, fade_t)

	if t >= 1.0:
		_complete_flight()


func _complete_flight() -> void:
	_is_flying = false
	if _particles:
		_particles.emitting = false
	if _light:
		_light.visible = false

	# Beri sedikit jeda agar partikel ekor sempat memudar sebelum menyembunyikan node wisp
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_callback(func() -> void:
		if not _is_flying and _wisp:
			_wisp.visible = false
	)


## Mendapatkan waypoint aktif saat ini
func get_active_waypoint() -> Node3D:
	if waypoints.is_empty():
		return null
	var idx := clampi(_current_waypoint_index, 0, waypoints.size() - 1)
	return waypoints[idx]
