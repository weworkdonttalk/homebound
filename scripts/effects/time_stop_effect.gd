extends Node3D
class_name TimeStopEffect

# ============================================================================
# TimeStopEffect — Efek Lingkaran Jam Waktu Saat Dimension Shifting [T]
# Menampilkan gelombang lingkaran jam berputar sinematik (Little Nightmares / Limbo)
# Saat masuk Remembered: Emas pucat #ffe4a0, berputar searah jarum jam.
# Saat masuk Forgotten: Biru dingin pudar #8eb8f5, berputar berlawanan arah jarum jam.
# ============================================================================

const TIME_STOP_SCENE: PackedScene = preload("res://assets/effects/time_stop_effect.glb")

## Skala dasar normalisasi model efek jam (diameter model glb ~21.4 unit)
## Pada 0.12, skala 1.4 menghasilkan diameter ~3.6m (proporsional dengan tinggi karakter)
@export_range(0.02, 1.0, 0.01) var base_scale: float = 0.12

## Durasi animasi ekspansi jam (detik)
@export_range(0.2, 1.5, 0.05) var duration: float = 0.55

## Sudut pitch menghadap kamera 2.5D (derajat)
@export var camera_pitch_degrees: float = -12.0

var _model_instance: Node3D = null
var _material: StandardMaterial3D = null
var _tween: Tween = null


func _ready() -> void:
	visible = false
	_setup_effect_model()


func _setup_effect_model() -> void:
	_model_instance = get_node_or_null("ModelInstance") as Node3D
	if _model_instance == null:
		# Cari child instance dari time_stop_effect.glb
		for child in get_children():
			if "time_stop_effect" in child.name.to_lower() or child is Node3D:
				_model_instance = child as Node3D
				break

	if _model_instance == null and TIME_STOP_SCENE:
		_model_instance = TIME_STOP_SCENE.instantiate() as Node3D
		_model_instance.name = "ModelInstance"
		add_child(_model_instance)

	# Buat material unshaded transparan dengan emisi lembut atmosferik
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true
	_material.emission_energy_multiplier = 2.5
	_material.albedo_color = Color(1.0, 0.894, 0.627, 0.0)
	_material.emission = Color(1.0, 0.894, 0.627)

	# Terapkan material override ke semua mesh di dalam model
	if _model_instance:
		for mesh_inst in _model_instance.find_children("*", "MeshInstance3D", true):
			if mesh_inst is MeshInstance3D:
				mesh_inst.material_override = _material


## Memicu gelombang animasi lingkaran jam saat tombol [T] ditekan
func trigger_shift(is_remembered: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	if _model_instance == null:
		_setup_effect_model()
		if _model_instance == null:
			return

	visible = true

	# Tentukan warna dan arah putaran
	# Remembered: Emas pucat #ffe4a0, putar searah jarum jam
	# Forgotten: Biru dingin pudar #8eb8f5, putar berlawanan jarum jam
	var tint_color: Color = Color("#ffe4a0") if is_remembered else Color("#8eb8f5")
	var rot_sign: float = 1.0 if is_remembered else -1.0
	var start_rot_z: float = 0.0
	var end_rot_z: float = rot_sign * TAU  # Putar 1 putaran penuh (360 derajat)

	# Pastikan material aktif
	if _material:
		_material.albedo_color = Color(tint_color.r, tint_color.g, tint_color.b, 0.95)
		_material.emission = tint_color
		_material.emission_energy_multiplier = 2.5

	# Skala awal: 0.15 x base_scale
	var start_scale := Vector3.ONE * (0.15 * base_scale)
	var end_scale := Vector3.ONE * (1.4 * base_scale)

	_model_instance.scale = start_scale
	# Hadapkan efek ke sudut pandang kamera 2.5D (pitch -12 derajat)
	_model_instance.rotation_degrees = Vector3(camera_pitch_degrees, 0.0, rad_to_deg(start_rot_z))

	# Setup Tween animasi ekspansi cepat memudar (TRANS_EXPO, EASE_OUT)
	_tween = create_tween().set_parallel(true)

	# 1. Ekspansi skala (0.15 -> 1.4)
	_tween.tween_property(_model_instance, "scale", end_scale, duration)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)

	# 2. Rotasi jarum / cincin jam
	_tween.tween_method(func(val: float) -> void:
		if _model_instance:
			_model_instance.rotation_degrees.z = rad_to_deg(val)
	, start_rot_z, end_rot_z, duration)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)

	# 3. Fade-out alpha (0.85 -> 0.0)
	if _material:
		_tween.tween_method(func(alpha: float) -> void:
			if _material:
				_material.albedo_color.a = alpha
		, 0.85, 0.0, duration)\
			.set_trans(Tween.TRANS_EXPO)\
			.set_ease(Tween.EASE_OUT)

	# Selesai: sembunyikan kembali
	_tween.chain().tween_callback(func() -> void:
		visible = false
	)
