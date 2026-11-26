extends Node3D

# ============================================================================
# Chapter1 Puzzle Manager — Orketrasi alur puzzle Chapter 1
# 1. Pick Up & Drop (Teddy Bear + animasi Carrying.fbx)
# 2. Pressure Plate -> Glowing Platforms (staggered emission)
# 3. Memory Shifting (forgotten / remembered) — integrasi dengan world.gd
# 4. Portal Activation & Cinematic Room Transition
# ============================================================================

## Referensi ke skrip pemain (mc.gd / CharacterBody3D)
@export var player: Node3D

## Sistem carry & drop
@export var carry_system: Node3D

## Pressure plate (Area3D)
@export var pressure_plate: Area3D

## Parent node dari semua platform bercahaya
@export var glowing_platforms: Node3D

## Portal pintu (Area3D trigger)
@export var door_portal: Area3D

## Marker3D tujuan di ruangan berikutnya
@export var target_room_marker: Marker3D

## CanvasLayer / ColorRect untuk efek fade
@export var fade_layer: CanvasLayer
@export var fade_rect: ColorRect

## Kamera permainan (bisa Camera3D atau CinematicCameraRig)
@export var game_camera: Node3D

## Pintu akses perantara (remembered/Sketchfab_Scene20)
@export var access_door: Node3D = null

## Pengatur kemunculan bertahap platform parkour (ParkourSequencer)
@export var parkour_sequencer: Node3D = null

## Pintu keluar akhir di atas batu (interact/Sketchfab_Scene5)
@export var exit_door: Node3D = null

## Referensi ke world.gd (sistem forgotten / remembered)
@export var world_manager: Node3D

# Status puzzle
var teddy_on_plate := false
var platforms_activated := false
var portal_activated := false
var _is_cinematic_running: bool = false

# Sinyal alur puzzle
signal puzzle_step_completed(step: int)
signal puzzle_completed

func _ready() -> void:
	# Inisialisasi referensi default jika belum diassign Inspector
	if carry_system == null:
		carry_system = get_node_or_null("CarrySystem")
	if pressure_plate == null:
		pressure_plate = get_node_or_null("PressurePlate")
	if glowing_platforms == null:
		glowing_platforms = get_node_or_null("GlowingPlatforms")
	if door_portal == null:
		door_portal = get_node_or_null("DoorPortal")
	if target_room_marker == null:
		target_room_marker = get_node_or_null("TargetRoomMarker")
	if fade_layer == null:
		fade_layer = get_node_or_null("FadeCanvasLayer")
	if fade_rect == null and fade_layer:
		fade_rect = fade_layer.get_node_or_null("ColorRect")
	if game_camera == null:
		game_camera = get_node_or_null("Camera3D")
		if game_camera == null:
			game_camera = get_node_or_null("../CameraRig")
	if world_manager == null:
		world_manager = get_node_or_null("WorldManager")
	if access_door == null:
		access_door = get_node_or_null("../remembered/Sketchfab_Scene20")
	if parkour_sequencer == null:
		parkour_sequencer = get_node_or_null("../ParkourSequencer")
		if parkour_sequencer == null and get_parent():
			var seq_script = load("res://scripts/gameplay/parkour_sequencer.gd")
			if seq_script:
				var seq = Node3D.new()
				seq.name = "ParkourSequencer"
				seq.set_script(seq_script)
				get_parent().add_child(seq)
				parkour_sequencer = seq
	if exit_door == null:
		exit_door = get_node_or_null("../interact/Sketchfab_Scene5")

	# Wiring sinyal Pressure Plate
	if pressure_plate:
		pressure_plate.plate_activated.connect(_on_plate_activated)
		pressure_plate.plate_deactivated.connect(_on_plate_deactivated)

	# Wiring sinyal Glowing Platforms
	if glowing_platforms:
		glowing_platforms.all_platforms_activated.connect(_on_all_platforms_activated)

	# Wiring sinyal Door Portal
	if door_portal:
		door_portal.transition_started.connect(_on_transition_started)
		door_portal.transition_finished.connect(_on_transition_finished)

	# Set collision layer/mask konsisten dengan mc.gd & world.gd
	_setup_collision_layers()

# ---------------------------------------------------------------------------
# Collision Layer / Mask — konsisten dengan arsitektur existing
# Player: Layer 1 (Player), Mask 2 (Environment/Platforms)
# Teddy Bear / Pickup: Layer 3 (Items), Mask 1 & 2 (saat tidak dipegang)
# ---------------------------------------------------------------------------
func _setup_collision_layers() -> void:
	# Catatan: nilai-nilai ini juga bisa diatur langsung di Inspector tiap node.
	# Player (CharacterBody3D) biasanya sudah memiliki collision_layer/mask di mc.gd.
	# Di sini kita hanya memastikan referensi tidak bentrok.
	pass

# ---------------------------------------------------------------------------
# Pressure Plate terpicu — Teddy Bear ditempatkan di atas pelat
# ---------------------------------------------------------------------------
func _on_plate_activated() -> void:
	teddy_on_plate = true
	platforms_activated = true
	puzzle_step_completed.emit(2)  # Step 2: Pressure Plate aktif

	# Eksekusi sekuens sinematik kamera & pintu Little Nightmares style
	_run_cinematic_sequence()

func _on_plate_deactivated() -> void:
	teddy_on_plate = false

# ---------------------------------------------------------------------------
# Alur Sinematik Komprehensif:
# 1. Bekukan input pemain (Little Nightmares cinematic pause).
# 2. Kamera pan ke pintu akses perantara (remembered/Sketchfab_Scene20), pintu terbuka.
# 3. Kamera bergerak menyusuri jurang parkour sementara item/batu parkour muncul berurutan.
# 4. Kamera menyoroti pintu akhir di atas batu (interact/Sketchfab_Scene5), pintu terbuka
#    dengan pancaran semburan cahaya putih menyilaukan.
# 5. Kamera kembali dengan mulus ke posisi karakter pemain & input dipulihkan.
# ---------------------------------------------------------------------------
func _run_cinematic_sequence() -> void:
	if _is_cinematic_running:
		return
	_is_cinematic_running = true

	# Pastikan referensi lengkap
	if player == null:
		player = get_node_or_null("../Player")
	if access_door == null:
		access_door = get_node_or_null("../remembered/Sketchfab_Scene20")
	if parkour_sequencer == null:
		parkour_sequencer = get_node_or_null("../ParkourSequencer")
		if parkour_sequencer == null and get_parent():
			var seq_script = load("res://scripts/gameplay/parkour_sequencer.gd")
			if seq_script:
				var seq = Node3D.new()
				seq.name = "ParkourSequencer"
				seq.set_script(seq_script)
				get_parent().add_child(seq)
				parkour_sequencer = seq
	if exit_door == null:
		exit_door = get_node_or_null("../interact/Sketchfab_Scene5")
	if game_camera == null:
		game_camera = get_node_or_null("../CameraRig")

	# 1. Hentikan kontrol gerak pemain
	if player and player.has_method("set_input_enabled"):
		player.call("set_input_enabled", false)

	# 2. Kamera pan ke pintu akses perantara
	if game_camera and access_door:
		if game_camera.has_method("pan_to_target"):
			var tw = game_camera.call("pan_to_target", access_door, 1.4)
			if tw and tw is Tween:
				await tw.finished
		await get_tree().create_timer(0.2).timeout

	# Buka pintu perantara
	_open_access_door()
	await get_tree().create_timer(1.0).timeout

	# 3. Pemicu kemunculan platform parkour bertahap satu per satu
	if parkour_sequencer and parkour_sequencer.has_method("trigger_popup_sequence"):
		parkour_sequencer.call("trigger_popup_sequence")

	# Kamera bergeser menyoroti platform yang sedang naik
	var mid_target: Node3D = null
	if parkour_sequencer and parkour_sequencer.get("platforms") and parkour_sequencer.platforms.size() > 1:
		mid_target = parkour_sequencer.platforms[1]
	if mid_target == null:
		mid_target = get_node_or_null("../interact/Sketchfab_Scene2")

	if game_camera and mid_target:
		if game_camera.has_method("pan_to_target"):
			var tw2 = game_camera.call("pan_to_target", mid_target, 1.8)
			if tw2 and tw2 is Tween:
				await tw2.finished
		await get_tree().create_timer(0.5).timeout

	# 4. Kamera menyoroti pintu keluar akhir di atas batu
	if game_camera and exit_door:
		if game_camera.has_method("pan_to_target"):
			var tw3 = game_camera.call("pan_to_target", exit_door, 1.4)
			if tw3 and tw3 is Tween:
				await tw3.finished
		await get_tree().create_timer(0.2).timeout

	# Pintu keluar terbuka dan memancarkan cahaya putih terang menyilaukan
	_open_exit_door()
	await get_tree().create_timer(1.2).timeout

	# 5. Kamera kembali dengan mulus ke posisi karakter pemain
	if game_camera and game_camera.has_method("return_to_player"):
		var tw4 = game_camera.call("return_to_player", 1.4)
		if tw4 and tw4 is Tween:
			await tw4.finished
		await get_tree().create_timer(0.2).timeout

	# 6. Pulihkan kendali gerak pemain
	if player and player.has_method("set_input_enabled"):
		player.call("set_input_enabled", true)

	_is_cinematic_running = false

func _open_access_door() -> void:
	if access_door == null:
		return
	var ap = access_door.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and (ap.has_animation("buka") or ap.has_animation("open")):
		var a_name = "buka" if ap.has_animation("buka") else "open"
		ap.play(a_name)
	else:
		var d = access_door.find_child("Door", true, false)
		if d:
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(d, "rotation_degrees:y", -85.0, 1.2)

func _open_exit_door() -> void:
	if door_portal and door_portal.has_method("open_door"):
		door_portal.call("open_door")

# ---------------------------------------------------------------------------
# Semua platform bercahaya telah aktif
# ---------------------------------------------------------------------------
func _on_all_platforms_activated() -> void:
	puzzle_step_completed.emit(3)  # Step 3: Platform bercahaya siap
	# Portal pintu menyala (emission glow) — ditangani door_portal.activate_portal()
	if door_portal:
		door_portal.call("activate_portal")
	portal_activated = true

# ---------------------------------------------------------------------------
# Transisi pintu dimulai & selesai
# ---------------------------------------------------------------------------
func _on_transition_started() -> void:
	puzzle_step_completed.emit(4)  # Step 4: Transisi ruangan

func _on_transition_finished() -> void:
	puzzle_completed.emit()

# ---------------------------------------------------------------------------
# Integrasi Carry & Drop dengan mc.gd
# Dipanggil oleh mc.gd saat pemain menekan [E] interact
# ---------------------------------------------------------------------------
func on_player_pick_up(item: RigidBody3D) -> void:
	if carry_system:
		carry_system.call("pick_up", item)

func on_player_drop_item() -> void:
	if carry_system:
		carry_system.call("drop")

# ---------------------------------------------------------------------------
# Memory Shifting integrasi — pastikan CollisionShape3D dimatikan secara dinamis
# saat dimensi tidak aktif (bukan hanya visible = false)
# Dipanggil oleh world.gd saat tombol [T] ditekan
# ---------------------------------------------------------------------------
func validate_dimension_collision(active_dimension: String) -> void:
	# active_dimension: "remembered" atau "forgotten"
	var remembered = world_manager.get_node_or_null("remembered")
	var forgotten = world_manager.get_node_or_null("forgotten")

	var active_node = remembered if active_dimension == "remembered" else forgotten
	var inactive_node = forgotten if active_dimension == "remembered" else remembered

	if active_node:
		_ensure_collisions(active_node, true)
	if inactive_node:
		_ensure_collisions(inactive_node, false)

func _ensure_collisions(node: Node, active: bool) -> void:
	for child in node.get_children():
		var c_name := child.name.to_lower()
		var is_permanent: bool = (
			"scene5" in c_name or "scene6" in c_name or "scene7" in c_name or
			"scene8" in c_name or "scene9" in c_name or "scene10" in c_name or
			"scene11" in c_name or "scene12" in c_name or "scene13" in c_name or
			"scene14" in c_name or "scene15" in c_name or "pushabletoyblock" in c_name or
			(child is Node3D and child.position.x < 22.0)
		)
		var should_be_active: bool = true if is_permanent else active

		if child is CollisionShape3D:
			child.set_deferred("disabled", not should_be_active)
		elif child is RigidBody3D:
			child.set_deferred("freeze", not should_be_active)
		elif child is Node3D:
			_ensure_collisions(child, should_be_active)

# ---------------------------------------------------------------------------
# Helper: cek apakah puzzle diselesaikan
# ---------------------------------------------------------------------------
func is_puzzle_complete() -> bool:
	return teddy_on_plate and platforms_activated and portal_activated