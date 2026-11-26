class_name PortalLightGate
extends Node3D

## ============================================================================
## Portal Light Gate — Efek Cahaya Putih Sangat Terang di Dalam Pintu (Gimersia)
## Terdiri dari Core Quad emisi putih HDR + SpotLight3D volumetrik intensitas tinggi.
## Dipicu saat pintu terbuka atau saat transisi dimensi ingatan.
## ============================================================================

signal light_activated
signal light_deactivated

@export_group("Light Settings")
## Energi maksimum SpotLight saat aktif (sangat terang menyilaukan)
@export var max_spot_energy: float = 12.0
## Energi maksimum OmniLight (pendaran sekitar kusen)
@export var max_omni_energy: float = 6.0
## Pengali emisi maksimum pada core quad (HDR Glow)
@export var max_emission_multiplier: float = 16.0
## Durasi fade in cahaya (detik)
@export var fade_in_duration: float = 1.2
## Durasi fade out cahaya (detik)
@export var fade_out_duration: float = 0.5

@export_group("Node References")
@export var core_quad: MeshInstance3D = null
@export var spot_light: SpotLight3D = null
@export var omni_light: OmniLight3D = null

var is_active: bool = false
var _tween: Tween = null
var _core_material: StandardMaterial3D = null

func _ready() -> void:
	if core_quad == null:
		core_quad = get_node_or_null("CoreGlowQuad") as MeshInstance3D
	if spot_light == null:
		spot_light = get_node_or_null("BlindingSpotLight") as SpotLight3D
	if omni_light == null:
		omni_light = get_node_or_null("HaloOmniLight") as OmniLight3D

	if core_quad:
		var mat = core_quad.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			_core_material = mat.duplicate()
		else:
			_core_material = StandardMaterial3D.new()
			_core_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_core_material.emission_enabled = true
			_core_material.emission = Color(1.0, 1.0, 1.0)
		core_quad.set_surface_override_material(0, _core_material)

	# Inisialisasi keadaan mati
	set_light_state_instant(false)

func turn_on(duration: float = -1.0) -> void:
	if is_active:
		return
	is_active = true

	var dur = fade_in_duration if duration < 0 else duration
	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if spot_light:
		spot_light.visible = true
		_tween.tween_property(spot_light, "light_energy", max_spot_energy, dur)

	if omni_light:
		omni_light.visible = true
		_tween.tween_property(omni_light, "light_energy", max_omni_energy, dur)

	if _core_material:
		core_quad.visible = true
		_tween.tween_property(_core_material, "emission_energy_multiplier", max_emission_multiplier, dur)

	light_activated.emit()

func turn_off(duration: float = -1.0) -> void:
	if not is_active:
		return
	is_active = false

	var dur = fade_out_duration if duration < 0 else duration
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if spot_light:
		_tween.tween_property(spot_light, "light_energy", 0.0, dur)

	if omni_light:
		_tween.tween_property(omni_light, "light_energy", 0.0, dur)

	if _core_material:
		_tween.tween_property(_core_material, "emission_energy_multiplier", 0.0, dur)

	_tween.chain().tween_callback(func() -> void:
		visible = false
		if spot_light: spot_light.visible = false
		if omni_light: omni_light.visible = false
		if core_quad: core_quad.visible = false
		light_deactivated.emit()
	)

func set_light_state_instant(active: bool) -> void:
	is_active = active
	visible = active

	if spot_light:
		spot_light.visible = active
		spot_light.light_energy = max_spot_energy if active else 0.0

	if omni_light:
		omni_light.visible = active
		omni_light.light_energy = max_omni_energy if active else 0.0

	if _core_material:
		core_quad.visible = active
		_core_material.emission_energy_multiplier = max_emission_multiplier if active else 0.0
