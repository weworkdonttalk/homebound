class_name LampProximityFader
extends Node3D

## ============================================================================
## LampProximityFader
## Mengatur animasi fade in dan fade out dinamis pada lampu gantung / spotlight
## di Chapter 1 saat karakter (Player) mendekat atau melewatinya.
## ============================================================================

## Jarak deteksi horizontal (meter) saat mendekat agar lampu menyala (fade in)
@export var trigger_distance: float = 12.0

## Buffer jarak keluar (hysteresis) agar lampu tidak berkedip saat player berdiri di perbatasan
@export var exit_buffer: float = 2.5

## Durasi animasi fade-in dalam detik
@export var fade_in_duration: float = 0.7

## Durasi animasi fade-out dalam detik
@export var fade_out_duration: float = 1.0

## Rasio minimal cahaya lampu saat pemain jauh agar kedalaman ruangan tetap terlihat samar
@export_range(0.0, 0.5, 0.02) var min_energy_ratio: float = 0.28

## Lampu yang memiliki kedipan filamen halus psikologis (tanpa konflik dengan proximity fade)
@export var flicker_lights: Array[String] = ["SpotLight_Meja1", "SpotLight_Meja4", "SpotLight_Babak3Area2"]

## Lampu yang dikecualikan (misal SpotLight_LemariTeddy untuk puzzle teddy bear, SpotLight_Meja7 untuk puzzle pressure plate, SpotLight_Meja8 selalu menyala normal tanpa fade)
@export var exclude_lights: Array[String] = ["SpotLight_LemariTeddy", "SpotLight_Meja7", "SpotLight_Meja8"]

# Struktur pelacak tiap lampu
class LightTrack:
	var light: Light3D
	var target_energy: float = 4.0
	var progress: float = 0.0 # 0.0 (redup baseline) hingga 1.0 (menyala penuh)
	var is_lit: bool = false
	var floor_pos: Vector2 = Vector2.ZERO
	var has_flicker: bool = false
	var flicker_mul: float = 1.0
	var flicker_timer: float = 1.0
	var flicker_phase: float = 0.0

var _tracked_lights: Array[LightTrack] = []
var _player: Node3D = null
var meja7_target_energy: float = 4.0
var _meja7_lamp: Light3D = null
var _meja7_tween: Tween = null


func _ready() -> void:
	_init_tracked_lights()
	_find_player()


## Inisialisasi semua lampu anak di bawah node ini
func _init_tracked_lights() -> void:
	_tracked_lights.clear()
	for child in get_children():
		if child is Light3D:
			if child.name in exclude_lights:
				if child.name == "SpotLight_Meja7":
					_meja7_lamp = child
					meja7_target_energy = child.light_energy if child.light_energy > 0.1 else 4.0
					child.light_energy = 0.0
					child.visible = false
				elif child.name == "SpotLight_Meja8":
					child.visible = true
				continue

			var orig_energy: float = child.light_energy
			var target_energy: float = orig_energy if orig_energy > 0.05 else 4.0

			var lt := LightTrack.new()
			lt.light = child
			lt.target_energy = target_energy
			lt.progress = 0.0
			lt.is_lit = false
			lt.floor_pos = _compute_floor_pos(child)
			lt.has_flicker = child.name in flicker_lights
			lt.flicker_timer = randf_range(0.8, 3.2)
			lt.flicker_phase = randf_range(0.0, TAU)

			# Awalnya lampu redup samar (menjaga kedalaman ruangan tanpa gelap total)
			child.light_energy = target_energy * min_energy_ratio
			child.visible = (min_energy_ratio > 0.001)

			_tracked_lights.append(lt)

	print("[LampProximityFader] Berhasil melacak %d lampu untuk animasi fade in/out." % _tracked_lights.size())


## Menghitung titik jatuh sorotan spotlight di lantai (Y = 0)
func _compute_floor_pos(light: Light3D) -> Vector2:
	var light_pos := light.global_position
	# Dalam Godot, arah sorotan spotlight lokal mengarah ke -Z
	var forward := -light.global_transform.basis.z.normalized()
	if abs(forward.y) > 0.05 and forward.y < 0.0:
		var t := -light_pos.y / forward.y
		var hit := light_pos + forward * t
		return Vector2(hit.x, hit.z)
	return Vector2(light_pos.x, light_pos.z)


## Mencari node karakter pemain
func _find_player() -> void:
	if _player and is_instance_valid(_player):
		return
	_player = get_node_or_null("../Player") as Node3D
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _player:
		_player = get_tree().root.find_child("Player", true, false) as Node3D


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_find_player()
		if not _player:
			return

	var p_pos_2d := Vector2(_player.global_position.x, _player.global_position.z)

	for lt in _tracked_lights:
		if not is_instance_valid(lt.light):
			continue

		var light_pos_2d := Vector2(lt.light.global_position.x, lt.light.global_position.z)
		# Hitung jarak terdekat pemain ke segmen garis berkas lampu (dari sumber ke lantai)
		var closest_pt := Geometry2D.get_closest_point_to_segment(p_pos_2d, light_pos_2d, lt.floor_pos)
		var dist: float = p_pos_2d.distance_to(closest_pt)

		# Hysteresis on/off
		if not lt.is_lit:
			if dist <= trigger_distance:
				lt.is_lit = true
		else:
			if dist > (trigger_distance + exit_buffer):
				lt.is_lit = false

		# Update progress fade in / fade out
		if lt.is_lit:
			lt.progress = move_toward(lt.progress, 1.0, delta / max(fade_in_duration, 0.05))
		else:
			lt.progress = move_toward(lt.progress, 0.0, delta / max(fade_out_duration, 0.05))

		# Interpolasi halus kurva Smoothstep (Hermite): 3x^2 - 2x^3 dari min_energy_ratio -> 1.0
		var smooth_t := lt.progress * lt.progress * (3.0 - 2.0 * lt.progress)
		var energy_ratio := lerpf(min_energy_ratio, 1.0, smooth_t)

		# Kedipan filamen halus psikologis pada lampu terpilih (tanpa mati total mendadak)
		if lt.has_flicker:
			lt.flicker_phase += delta
			lt.flicker_timer -= delta
			if lt.flicker_timer <= 0.0:
				lt.flicker_mul = randf_range(0.42, 0.72)
				lt.flicker_timer = randf_range(1.6, 4.4)
			else:
				var hum := 0.96 + 0.04 * sin(lt.flicker_phase * 17.0)
				lt.flicker_mul = lerpf(lt.flicker_mul, hum, clampf(delta * 10.0, 0.0, 1.0))
			energy_ratio *= lt.flicker_mul

		lt.light.light_energy = energy_ratio * lt.target_energy
		lt.light.visible = (energy_ratio > 0.005)


## Menyalakan SpotLight_Meja7 secara permanen (dipicu saat teddy bear diletakkan di pressure plate)
func activate_meja7(duration: float = 0.35, force_immediate: bool = false) -> void:
	if not _meja7_lamp or not is_instance_valid(_meja7_lamp):
		_meja7_lamp = get_node_or_null("SpotLight_Meja7") as Light3D
	if not _meja7_lamp:
		_meja7_lamp = get_tree().root.find_child("SpotLight_Meja7", true, false) as Light3D
	if _meja7_lamp:
		_meja7_lamp.visible = true
		if _meja7_tween and _meja7_tween.is_valid():
			_meja7_tween.kill()

		if force_immediate or duration <= 0.0:
			_meja7_lamp.light_energy = meja7_target_energy
		else:
			_meja7_tween = create_tween()
			_meja7_tween.tween_property(_meja7_lamp, "light_energy", meja7_target_energy, duration)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_OUT)
		print("[LampProximityFader] SpotLight_Meja7 aktif (energy: %s, immediate: %s)" % [_meja7_lamp.light_energy, force_immediate])

