class_name StepStairRevealer
extends Node3D

## ============================================================================
## StepStairRevealer — Kemunculan Anak Tangga Putih 1 per 1 (Babak 3)
## Mengatur Platform1 s/d Platform19 di GlowingPlatforms muncul bertahap saat
## pemain berjalan maju mendekati masing-masing anak tangga.
## ============================================================================

signal stair_revealed(index: int, platform: StaticBody3D)
signal all_platforms_activated

## Referensi karakter pemain (CharacterBody3D)
@export var player: CharacterBody3D = null

## Jarak pemicu kemunculan sebelum pemain mencapai platform (meter)
@export var trigger_distance: float = 4.0

## Koordinat X minimum sebelum anak tangga mulai terpicu (melewati TembokKebelah Babak 2)
@export var min_activation_x: float = 24.0

## Durasi pop-up animasi tangga (detik)
@export var reveal_duration: float = 0.25

## Referensi DoorPortal di puncak tangga
@export var door_portal: Area3D = null

## Lampu sorot pintu keluar
@export var exit_spotlight: SpotLight3D = null

var platforms: Array[StaticBody3D] = []
var next_stair_index: int = 0
var _original_scales: Dictionary = {}
var _door_activated: bool = false

func _ready() -> void:
	_resolve_references()
	_initialize_platforms()

func _resolve_references() -> void:
	if player == null:
		player = get_node_or_null("../Player") as CharacterBody3D
		if player == null:
			player = get_tree().root.find_child("Player", true, false) as CharacterBody3D

	if door_portal == null:
		door_portal = get_node_or_null("../DoorPortal") as Area3D
		if door_portal == null:
			door_portal = get_tree().root.find_child("DoorPortal", true, false) as Area3D

	if exit_spotlight == null:
		exit_spotlight = get_node_or_null("../SpotLight_DoorWarm") as SpotLight3D
		if exit_spotlight == null:
			exit_spotlight = get_tree().root.find_child("SpotLight_DoorWarm", true, false) as SpotLight3D

	if exit_spotlight:
		exit_spotlight.light_energy = 0.0
		exit_spotlight.visible = false

func _initialize_platforms() -> void:
	platforms.clear()
	_original_scales.clear()
	next_stair_index = 0
	_door_activated = false

	# Kumpulkan Platform1 s/d Platform19
	for i in range(1, 20):
		var p_name := "Platform" + str(i)
		var plat := get_node_or_null(p_name) as StaticBody3D
		if plat:
			platforms.append(plat)
			_original_scales[plat] = plat.scale
			plat.visible = false
			plat.scale = Vector3(0.01, 0.01, 0.01)
			var col := plat.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col:
				col.disabled = true

func _process(_delta: float) -> void:
	if next_stair_index >= platforms.size():
		return

	if player == null:
		player = get_tree().root.find_child("Player", true, false) as CharacterBody3D
		if player == null:
			return

	if player.global_position.x < min_activation_x:
		return

	while next_stair_index < platforms.size():
		var plat := platforms[next_stair_index]
		var target_trigger_x: float = plat.global_position.x - trigger_distance
		if player.global_position.x >= target_trigger_x:
			_reveal_platform(plat, next_stair_index)
			next_stair_index += 1
		else:
			break

func _reveal_platform(plat: StaticBody3D, index: int) -> void:
	plat.visible = true
	var col := plat.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", false)

	var target_scale: Vector3 = _original_scales.get(plat, Vector3.ONE)
	var tw := create_tween()
	tw.tween_property(plat, "scale", target_scale, reveal_duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	var mesh_inst := plat.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.96, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.85, 1.0)
		mat.emission_energy_multiplier = 0.0
		mesh_inst.set_surface_override_material(0, mat)

		tw.parallel().tween_property(mat, "emission_energy_multiplier", 6.0, reveal_duration * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(mat, "emission_energy_multiplier", 1.8, reveal_duration * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	stair_revealed.emit(index, plat)
	print("[StepStairRevealer] Platform", index + 1, " (index ", index, ") muncul pada X=", plat.global_position.x)

	if index == platforms.size() - 1:
		_on_all_stairs_revealed()

func _on_all_stairs_revealed() -> void:
	if _door_activated:
		return
	_door_activated = true
	print("[StepStairRevealer] Semua 19 anak tangga terbuka! Membuka DoorPortal & menyalakan SpotLight_DoorWarm.")

	if door_portal:
		if door_portal.has_method("activate_portal"):
			door_portal.call("activate_portal")
		elif door_portal.has_method("open_door"):
			door_portal.call("open_door")

	if exit_spotlight:
		exit_spotlight.visible = true
		var tw := create_tween()
		tw.tween_property(exit_spotlight, "light_energy", 3.5, 1.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	all_platforms_activated.emit()

## Kompatibilitas mundur jika dipanggil dari luar
func activate_platforms() -> void:
	for i in range(next_stair_index, platforms.size()):
		_reveal_platform(platforms[i], i)
	next_stair_index = platforms.size()
