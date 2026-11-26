extends Area3D

# ============================================================================
# Pressure Plate — Chapter 1 Puzzle
# Mendeteksi objek dalam Group "teddy_bear" dan memicu sekwens puzzle.
# ============================================================================

## Node manajer platform bercahaya
@export var glowing_platforms: Node3D

## Node manajer portal pintu
@export var door_portal: Node3D

## Durasi animasi penurunan pelat (detik)
@export var plate_press_duration := 0.4

## Durasi jeda sebelum kamera pan (detik)
@export var camera_pan_delay := 0.2

## Sinyal saat pelat terpicu / dilepaskan
signal plate_activated
signal plate_deactivated

var is_pressed := false
var bear_on_plate: RigidBody3D = null
var plate_mesh: MeshInstance3D = null
var plate_original_position: Vector3 = Vector3.ZERO
var plate_pressed_offset: float = -0.15  # seberapa jauh pelat turun

var _press_tween: Tween = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Simpan posisi awal pelat
	var mesh = find_child("*", true, false)
	if mesh is MeshInstance3D:
		plate_mesh = mesh
		plate_original_position = mesh.position
	elif get_node_or_null("MeshInstance3D"):
		plate_mesh = get_node("MeshInstance3D")
		plate_original_position = plate_mesh.position

	# Referensi default jika belum diassign via Inspector
	if glowing_platforms == null:
		glowing_platforms = get_node_or_null("../GlowingPlatforms")
	if door_portal == null:
		door_portal = get_node_or_null("../DoorPortal")

	# Pastikan SpotLight_Meja7 padam sebelum puzzle diselesaikan
	_init_meja7_light()

func _on_body_entered(body: Node3D) -> void:
	if is_pressed:
		return

	# Hanya reaksi terhadap Teddy Bear (group "teddy_bear")
	if body.is_in_group("teddy_bear"):
		bear_on_plate = body as RigidBody3D
		if bear_on_plate and bear_on_plate.has_method("mark_placed_on_plate"):
			bear_on_plate.call("mark_placed_on_plate")
		# Nyalakan SpotLight_Meja7 segera saat teddy bear mendarat di pelat
		_activate_meja7_light()
		_press_plate()

func _on_body_exited(body: Node3D) -> void:
	if bear_on_plate == body:
		bear_on_plate = null
		if is_pressed:
			_release_plate()

func _press_plate() -> void:
	is_pressed = true

	# Animasi penurunan pelat via Tween
	if plate_mesh:
		var target_pos = plate_original_position + Vector3.DOWN * abs(plate_pressed_offset)
		if _press_tween:
			_press_tween.kill()
		_press_tween = create_tween()
		_press_tween.tween_property(plate_mesh, "position", target_pos, plate_press_duration)
		_press_tween.tween_callback(_on_press_complete)
		_press_tween.play()
	else:
		_on_press_complete()

func _on_press_complete() -> void:
	# Pastikan SpotLight_Meja7 sudah menyala penuh saat animasi turun pelat selesai
	_activate_meja7_light()
	plate_activated.emit()

	# Sinyal pelat terpicu (Babak 2: membuka TembokKiri & TembokKanan via cutscene)
	# Platform bercahaya (GlowingPlatforms) dan portal kini 100% dikendalikan oleh Babak 3 (step_stair_revealer.gd)

	# Kamera pan ke platform + pintu (dipelopori oleh PuzzleManager)
	# Sinyal ini dihubungkan oleh Chapter1PuzzleManager

func _release_plate() -> void:
	is_pressed = false
	plate_deactivated.emit()

	# Kembalikan pelat ke posisi awal
	if plate_mesh:
		if _press_tween:
			_press_tween.kill()
		_press_tween = create_tween()
		_press_tween.tween_property(plate_mesh, "position", plate_original_position, plate_press_duration)
		_press_tween.play()


## Inisialisasi awal SpotLight_Meja7 agar padam
func _init_meja7_light() -> void:
	var lamp := get_tree().root.find_child("SpotLight_Meja7", true, false) as Light3D
	if lamp:
		lamp.light_energy = 0.0
		lamp.visible = false


## Menyalakan SpotLight_Meja7 saat teddy diletakkan di plate
func _activate_meja7_light() -> void:
	var fader := get_tree().root.find_child("SpotLights_TitikFokus", true, false)
	if fader and fader.has_method("activate_meja7"):
		fader.call("activate_meja7", 0.35)
	else:
		var lamp := get_tree().root.find_child("SpotLight_Meja7", true, false) as Light3D
		if lamp:
			lamp.visible = true
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 4.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			print("[PressurePlate] SpotLight_Meja7 dinyalakan!")
