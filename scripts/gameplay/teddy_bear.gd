@tool
extends RigidBody3D
class_name TeddyBearItem

## Teddy Bear Pickup Item — Chapter 1 Puzzle
## Terkunci sebelum Puzzle 3 Box ABCD selesai (0/3, 1/3, 2/3).
## Tepat saat 3/3 Box selesai: memicu pop-in visual model asli (teddybear.glb) di rak lemari,
## menyalakan SpotLight_LemariTeddy (5.0), mengaktifkan pendar aura Forgotten ([T]),
## dan dapat diangkat dengan CarrySystem ke Pressure Plate.

@export var is_unlocked: bool = false
@export var visual_node: Node3D = null

var is_on_pressure_plate: bool = false
const TARGET_VISUAL_SCALE := Vector3(5.0, 5.0, 5.0)
var _ghost_mat: StandardMaterial3D = null

func _ready() -> void:
	# Bersihkan sisa child mesh placeholder bulat jika sempat dibuat
	var old_hint = get_node_or_null("GhostHint")
	if old_hint:
		old_hint.queue_free()

	_find_visual_node()
	_setup_ghost_material()
	_connect_world_dimension()

	if not Engine.is_editor_hint():
		if not is_unlocked:
			lock_teddy()
		else:
			unlock_teddy()
	else:
		# Di editor: pastikan visual model asli beruang berukuran proporsional 5x5x5
		if visual_node:
			visual_node.scale = TARGET_VISUAL_SCALE


func _find_visual_node() -> void:
	if visual_node == null:
		visual_node = get_node_or_null("../remembered/Sketchfab_Scene7")
	if visual_node == null:
		visual_node = get_tree().root.find_child("Sketchfab_Scene7", true, false) as Node3D

	if visual_node:
		global_position = visual_node.global_position
		global_rotation = visual_node.global_rotation


func _setup_ghost_material() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.45)
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(0.1, 0.7, 1.0)
	_ghost_mat.emission_energy_multiplier = 1.5


func _connect_world_dimension() -> void:
	if Engine.is_editor_hint():
		return

	var wm = get_tree().root.find_child("WorldManager", true, false)
	if wm == null:
		wm = get_tree().root.find_child("main", true, false)
	if wm and wm.has_signal("dimension_shifted"):
		if not wm.is_connected("dimension_shifted", Callable(self, "_on_dimension_shifted")):
			wm.connect("dimension_shifted", Callable(self, "_on_dimension_shifted"))
		if "in_memory" in wm:
			_on_dimension_shifted(wm.in_memory)


func _on_dimension_shifted(is_in_memory: bool) -> void:
	if not is_unlocked or is_on_pressure_plate:
		_apply_ghost_glow(false)
		return

	# Sesuai aturan: Dunia Terlupakan (in_memory == false) menampilkan pendar aura ghost pada model beruang
	_apply_ghost_glow(not is_in_memory)


func _apply_ghost_glow(enable: bool) -> void:
	if visual_node == null:
		return

	for mi in visual_node.find_children("*", "MeshInstance3D", true):
		var mesh_inst: MeshInstance3D = mi as MeshInstance3D
		if mesh_inst and mesh_inst.mesh:
			for s in range(mesh_inst.mesh.get_surface_count()):
				if enable and _ghost_mat:
					mesh_inst.set_surface_override_material(s, _ghost_mat)
				else:
					mesh_inst.set_surface_override_material(s, null)


## Mengunci boneka beruang rapat-rapat selama 0/3, 1/3, 2/3 kotak terpasang
func lock_teddy() -> void:
	is_unlocked = false
	visible = false
	freeze = true

	# Lepas dari grup interaksi agar tidak bisa diambil CarrySystem sebelum waktunya
	if is_in_group("pickup"):
		remove_from_group("pickup")
	if is_in_group("teddy_bear"):
		remove_from_group("teddy_bear")
	if is_in_group("carryable"):
		remove_from_group("carryable")

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)

	if visual_node:
		visual_node.visible = false
		visual_node.scale = Vector3.ZERO
		_apply_ghost_glow(false)

	# Lampu sorot lemari teddy dipadamkan
	var lamp = get_tree().root.find_child("SpotLight_LemariTeddy", true, false)
	if lamp and "light_energy" in lamp:
		lamp.light_energy = 0.0


## Membuka dan memunculkan model 3D asli Teddy Bear tepat saat 3/3 kotak terpasang
func unlock_teddy() -> void:
	if is_unlocked:
		return

	is_unlocked = true
	add_to_group("pickup")
	add_to_group("teddy_bear")
	add_to_group("carryable")

	collision_layer = 4
	collision_mask = 1
	mass = 1.0
	freeze = false

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", false)

	visible = true

	# 1. Animasi kemunculan model 3D asli beruang (teddybear.glb) di lemari
	if visual_node:
		visual_node.visible = true
		visual_node.scale = Vector3(0.01, 0.01, 0.01)
		var tw := create_tween()
		tw.tween_property(visual_node, "scale", TARGET_VISUAL_SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Nyalakan lampu sorot lemari SpotLight_LemariTeddy (5.0)
	var lamp = get_tree().root.find_child("SpotLight_LemariTeddy", true, false)
	if lamp and "light_energy" in lamp:
		var light_tw := create_tween()
		light_tw.tween_property(lamp, "light_energy", 5.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Update status pendar dimensi
	var wm = get_tree().root.find_child("WorldManager", true, false)
	if wm and "in_memory" in wm:
		_on_dimension_shifted(wm.in_memory)

	print("[TeddyBear] Model 3D asli Teddy Bear (teddybear.glb) berhasil dibuka dan muncul di rak lemari!")


func mark_placed_on_plate() -> void:
	is_on_pressure_plate = true
	_apply_ghost_glow(false)


func _physics_process(_delta: float) -> void:
	if visual_node and is_instance_valid(visual_node):
		if is_unlocked:
			visual_node.global_position = global_position
			visual_node.global_rotation = global_rotation
