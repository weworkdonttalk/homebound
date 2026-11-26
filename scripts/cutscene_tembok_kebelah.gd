extends Camera3D

## ============================================================================
## Cutscene Tembok Kebelah — Chapter 1
## Membelah tembok Plane_004 dengan kamera sinematik, efek debu, dan getaran kamera.
## Dipicu setelah Teddy Bear diletakkan di Pressure Plate.
## ============================================================================

@export_group("Target Node")
@export var tembok_kiri: Node3D = null
@export var tembok_kanan: Node3D = null
@export var partikel_debu: GPUParticles3D = null
@export var suara_geser: AudioStreamPlayer3D = null
@export var player: Node3D = null
@export var pressure_plate: Area3D = null

@export_group("Konfigurasi Animasi Tembok")
@export var arah_geser: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var jarak_geser: float = 6.0
@export var durasi_geser: float = 2.4
@export var delay_setelah_pressure_plate: float = 0.5
@export var delay_selesai_cutscene: float = 0.5

@export_group("Camera Shake")
@export var kekuatan_shake: float = 0.35
@export var durasi_shake: float = 2.0

signal cutscene_dimulai
signal cutscene_selesai

var _sudah_berjalan: bool = false
var _shake_timer: float = 0.0
var _prev_camera: Camera3D = null
var _pos_awal_kiri: Vector3 = Vector3.ZERO
var _pos_awal_kanan: Vector3 = Vector3.ZERO

func _ready() -> void:
	_resolve_references()
	
	if tembok_kiri:
		_pos_awal_kiri = tembok_kiri.position
	if tembok_kanan:
		_pos_awal_kanan = tembok_kanan.position
		
	if partikel_debu:
		partikel_debu.emitting = false

	# Pastikan sisa partition wall bawaan ruangan tidak menghalangi celah bukaan
	var partition_wall = get_tree().root.find_child("CollisionShape3D_PartitionWall", true, false) as CollisionShape3D
	if partition_wall:
		partition_wall.set_deferred("disabled", true)
		
	# Hubungkan sinyal pressure plate jika tersedia
	if pressure_plate and pressure_plate.has_signal("plate_activated"):
		if not pressure_plate.plate_activated.is_connected(_on_pressure_plate_activated):
			pressure_plate.plate_activated.connect(_on_pressure_plate_activated)

func _resolve_references() -> void:
	if tembok_kiri == null or tembok_kanan == null:
		var plane_004 = get_tree().root.find_child("Plane_004", true, false)
		if plane_004:
			if tembok_kiri == null:
				tembok_kiri = plane_004.get_node_or_null("TembokKiri") as Node3D
			if tembok_kanan == null:
				tembok_kanan = plane_004.get_node_or_null("TembokKanan") as Node3D
	if tembok_kiri == null:
		tembok_kiri = get_tree().root.find_child("TembokKiri", true, false) as Node3D
	if tembok_kanan == null:
		tembok_kanan = get_tree().root.find_child("TembokKanan", true, false) as Node3D
	if partikel_debu == null:
		partikel_debu = get_tree().root.find_child("PartikelDebu", true, false) as GPUParticles3D
	if suara_geser == null:
		suara_geser = get_tree().root.find_child("SuaraGeser", true, false) as AudioStreamPlayer3D
	if player == null:
		player = get_tree().root.find_child("Player", true, false) as Node3D
	if pressure_plate == null:
		pressure_plate = get_tree().root.find_child("PressurePlate", true, false) as Area3D

func _on_pressure_plate_activated() -> void:
	if _sudah_berjalan:
		return

	# Pastikan SpotLight_Meja7 sudah mulai/selesai menyala begitu sinyal pressure plate aktif
	_ensure_meja7_light_lit()
	
	# Tunggu hingga sekuens sinematik awal pressure plate selesai jika sedang berjalan
	var puzzle_mgr = get_tree().root.find_child("Chapter1PuzzleManager", true, false)
	if puzzle_mgr:
		await get_tree().create_timer(0.3).timeout
		while puzzle_mgr.get("_is_cinematic_running") == true:
			await get_tree().create_timer(0.2).timeout
			
	# Jeda transisi halus sebelum cutscene tembok dimulai
	await get_tree().create_timer(delay_setelah_pressure_plate).timeout
	mulai_cutscene_tembok()

## Fungsi publik untuk memicu sekuens cutscene tembok membelah
func mulai_cutscene_tembok() -> void:
	if _sudah_berjalan:
		return
	_sudah_berjalan = true
	cutscene_dimulai.emit()
	
	_resolve_references()

	# Pastikan SpotLight_Meja7 sudah 100% menyala sebelum kamera beralih ke cutscene
	_ensure_meja7_light_lit(true)
	
	# 1. Kunci Kontrol Player
	_lock_player(true)
	
	# 2. Switch Kamera ke CutsceneCamTembok
	_prev_camera = get_viewport().get_camera_3d()
	current = true
		
	# 3. Efek Debu, Suara, dan Camera Shake
	if partikel_debu:
		partikel_debu.emitting = true
	if suara_geser and suara_geser.stream:
		suara_geser.play()
		
	_start_camera_shake()

	# Nonaktifkan sisa partition wall agar tidak menjadi penghalang statis
	var partition_wall = get_tree().root.find_child("CollisionShape3D_PartitionWall", true, false) as CollisionShape3D
	if partition_wall:
		partition_wall.set_deferred("disabled", true)
	
	# Animasi Tembok Membelah via Tween
	var tween := create_tween().set_parallel(true)
	var dir := arah_geser.normalized()
	
	if tembok_kiri:
		var target_kiri := _pos_awal_kiri - (dir * jarak_geser)
		tween.tween_property(tembok_kiri, "position", target_kiri, durasi_geser)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)
			
	if tembok_kanan:
		var target_kanan := _pos_awal_kanan + (dir * jarak_geser)
		tween.tween_property(tembok_kanan, "position", target_kanan, durasi_geser)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)
			
	# 4. Selesai Cutscene
	tween.chain().tween_interval(delay_selesai_cutscene)
	tween.chain().tween_callback(_on_cutscene_finished)

func _start_camera_shake() -> void:
	if durasi_shake > 0.0 and kekuatan_shake > 0.0:
		_shake_timer = durasi_shake
		set_process(true)
	else:
		set_process(false)

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var progress: float = clampf(_shake_timer / durasi_shake, 0.0, 1.0)
		var amp: float = kekuatan_shake * progress
		h_offset = randf_range(-amp, amp)
		v_offset = randf_range(-amp, amp)
		if _shake_timer <= 0.0:
			h_offset = 0.0
			v_offset = 0.0
			set_process(false)
	else:
		set_process(false)

func _on_cutscene_finished() -> void:
	# Matikan partikel
	if partikel_debu:
		partikel_debu.emitting = false

	# Nonaktifkan seluruh collider penghalang agar Player 100% bisa lewat tanpa nyangkut
	_disable_doorway_colliders()
		
	# Kembalikan kamera aktif sebelumnya
	if is_instance_valid(_prev_camera) and _prev_camera != self:
		_prev_camera.current = true
	else:
		current = false
		
	# Buka kunci kontrol player
	_lock_player(false)
	
	cutscene_selesai.emit()

## Pengaman ekstra untuk menonaktifkan seluruh CollisionShape3D pada area bukaan tembok
func _disable_doorway_colliders() -> void:
	# 1. Nonaktifkan partition wall statis di ruangan
	var partition_wall = get_tree().root.find_child("CollisionShape3D_PartitionWall", true, false) as CollisionShape3D
	if partition_wall:
		partition_wall.set_deferred("disabled", true)

	# 2. Nonaktifkan seluruh CollisionShape3D dan layer di belahan tembok
	for wall_node in [tembok_kiri, tembok_kanan]:
		if wall_node:
			for col in wall_node.find_children("*", "CollisionShape3D", true, false):
				if col is CollisionShape3D:
					col.set_deferred("disabled", true)
			for body in wall_node.find_children("*", "CollisionObject3D", true, false):
				if body is CollisionObject3D:
					body.set_deferred("collision_layer", 0)
					body.set_deferred("collision_mask", 0)

	# 3. Nonaktifkan sisa collider bawaan foreign scene di Plane_004 jika ada
	var plane_004 = get_tree().root.find_child("Plane_004", true, false)
	if plane_004:
		for col in plane_004.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				col.set_deferred("disabled", true)

	# 4. Nonaktifkan collider di node TembokKebelah jika ada
	var tembok_kebelah = get_tree().root.find_child("TembokKebelah", true, false)
	if tembok_kebelah:
		for col in tembok_kebelah.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				col.set_deferred("disabled", true)

func _lock_player(locked: bool) -> void:
	if player == null:
		return
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not locked)
	player.set_physics_process(not locked)
	player.set_process_unhandled_input(not locked)


## Memastikan SpotLight_Meja7 sudah menyala terang sebelum/saat cutscene berjalan
func _ensure_meja7_light_lit(immediate: bool = false) -> void:
	var fader := get_tree().root.find_child("SpotLights_TitikFokus", true, false)
	if fader and fader.has_method("activate_meja7"):
		fader.call("activate_meja7", 0.0 if immediate else 0.35, immediate)
	else:
		var lamp := get_tree().root.find_child("SpotLight_Meja7", true, false) as Light3D
		if lamp:
			lamp.visible = true
			lamp.light_energy = 4.0

