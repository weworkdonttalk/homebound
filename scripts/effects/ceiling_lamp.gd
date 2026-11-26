extends Node3D

# ============================================================================
# Ceiling Lamp Controller — Little Nightmares Psychological Horror Lighting
# Unstable, erratic flickering spotlight with short, unpredictable pauses,
# sudden voltage drops, and sickly filament color shifts.
# Includes slow, tense pendulum swaying.
# ============================================================================

@export_group("Lamp Sway")
## Apakah lampu berayun perlahan seperti digantung kabel
@export var enable_sway: bool = true
## Kecepatan ayunan pendulum
@export var sway_speed: float = 0.85
## Amplitudo ayunan sudut (derajat)
@export var sway_max_angle_deg: float = 2.0

@export_group("Unstable Flickering")
## Apakah lampu mengalami fluktuasi listrik acak tidak stabil
@export var enable_flicker: bool = true
## Jeda minimal antara episode kedipan (detik) - jeda singkat acak
@export var min_flicker_pause: float = 0.25
## Jeda maksimal antara episode kedipan (detik)
@export var max_flicker_pause: float = 1.85
## Kemungkinan terjadi padam total sesaat (blackout) dalam episode kedipan
@export_range(0.0, 1.0) var blackout_chance: float = 0.35

@export_group("Light References")
@export var spot_light: SpotLight3D = null
@export var omni_light: OmniLight3D = null

var _base_spot_energy: float = 2.8
var _base_omni_energy: float = 0.5
var _base_spot_color: Color = Color(0.88, 0.92, 0.84, 1.0)  # Sickly pale greenish-warm
var _dim_color: Color = Color(0.42, 0.32, 0.16, 1.0)        # Dying filament brown/amber

var _sway_time: float = 0.0
var _pause_timer: float = 0.8
var _is_flickering: bool = false
var _initial_rotation_degrees: Vector3 = Vector3.ZERO
var _flicker_tween: Tween = null


func _ready() -> void:
	if spot_light == null:
		spot_light = get_node_or_null("SpotLight3D") as SpotLight3D
	if omni_light == null:
		omni_light = get_node_or_null("OmniLight3D") as OmniLight3D

	if spot_light:
		_base_spot_energy = spot_light.light_energy
		_base_spot_color = spot_light.light_color
	if omni_light:
		_base_omni_energy = omni_light.light_energy

	_initial_rotation_degrees = rotation_degrees
	_pause_timer = randf_range(min_flicker_pause, max_flicker_pause)


func _process(delta: float) -> void:
	# 1. Smooth Creeping Pendulum Sway
	if enable_sway:
		_sway_time += delta * sway_speed
		var sway_x := sin(_sway_time) * sway_max_angle_deg
		var sway_z := cos(_sway_time * 0.74) * (sway_max_angle_deg * 0.6)
		rotation_degrees.x = _initial_rotation_degrees.x + sway_x
		rotation_degrees.z = _initial_rotation_degrees.z + sway_z

	# 2. Unstable Erratic Flicker Timer dengan jeda singkat acak
	if enable_flicker and not _is_flickering:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_trigger_erratic_flicker()
			_pause_timer = randf_range(min_flicker_pause, max_flicker_pause)


func _trigger_erratic_flicker() -> void:
	_is_flickering = true
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()

	_flicker_tween = create_tween()

	# Jumlah stutter dalam 1 episode kedip: 2 hingga 6 hentakan cepat
	var stutters := randi_range(2, 6)
	var has_blackout := randf() < blackout_chance

	for i in range(stutters):
		# Target intensitas: kadang padam total, kadang redup drastis, kadang kedip cepat
		var target_ratio: float
		if has_blackout and i == 1:
			target_ratio = 0.0  # Blackout total sesaat
		else:
			target_ratio = randf_range(0.04, 0.45)

		var drop_dur := randf_range(0.018, 0.055)
		var recover_dur := randf_range(0.025, 0.075)

		# Warna meredup ke arah filamen sekarat
		var target_color := _base_spot_color.lerp(_dim_color, 1.0 - target_ratio)

		if spot_light:
			_flicker_tween.tween_property(spot_light, "light_energy", _base_spot_energy * target_ratio, drop_dur)
			_flicker_tween.parallel().tween_property(spot_light, "light_color", target_color, drop_dur)
			_flicker_tween.tween_property(spot_light, "light_energy", _base_spot_energy * randf_range(0.85, 1.15), recover_dur)
			_flicker_tween.parallel().tween_property(spot_light, "light_color", _base_spot_color, recover_dur)

		if omni_light:
			_flicker_tween.parallel().tween_property(omni_light, "light_energy", _base_omni_energy * target_ratio, drop_dur)
			_flicker_tween.parallel().tween_property(omni_light, "light_energy", _base_omni_energy, recover_dur)

	# Pastikan setelah episode selesai lampu kembali ke kondisi normal
	_flicker_tween.tween_callback(func() -> void:
		_is_flickering = false
		if spot_light:
			spot_light.light_energy = _base_spot_energy
			spot_light.light_color = _base_spot_color
		if omni_light:
			omni_light.light_energy = _base_omni_energy
	)
