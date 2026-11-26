@tool
extends Area3D
class_name PuzzleSlot

## PuzzleSlot — Slot Dudukan Puzzle Balok ABCD (Chapter 1)
## Mendukung deteksi balok mainan (CarrySystem & dropped physics),
## visual ghost silhouette di Forgotten dimension ([T]),
## pelepasan otomatis dari tangan karakter, snapping mulus (0.25s),
## serta feedback sukses ketika balok terpasang.

signal slot_filled(block: Node3D)

@export var target_item_name: String = ""
@export var target_group: String = "puzzle_block"

var is_filled: bool = false
var ghost_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("puzzle_slot")
	monitoring = true
	monitorable = true

	# Pastikan ada CollisionShape3D yang cukup luas mendeteksi box
	var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape and col_shape.shape == null:
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.2, 0.8, 1.2)
		col_shape.shape = bs

	_setup_ghost_mesh()
	_connect_world_dimension()

	if not Engine.is_editor_hint():
		if not is_connected("body_entered", Callable(self, "_on_body_entered")):
			connect("body_entered", Callable(self, "_on_body_entered"))


func _physics_process(_delta: float) -> void:
	if is_filled or Engine.is_editor_hint():
		return

	# Deteksi proaktif jika pemain sedang membawa box mainan mendekati slot
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		var carried: Node3D = null
		if "item_dipegang" in player and player.item_dipegang != null:
			carried = player.item_dipegang

		if carried and _is_valid_block(carried):
			var dist_carried := global_position.distance_to(carried.global_position)
			var dist_player := global_position.distance_to(player.global_position)
			if dist_carried < 1.4 or dist_player < 1.6:
				_snap_block_into_slot(carried)


func _setup_ghost_mesh() -> void:
	ghost_mesh = get_node_or_null("GhostHint") as MeshInstance3D
	if ghost_mesh == null:
		ghost_mesh = MeshInstance3D.new()
		ghost_mesh.name = "GhostHint"
		add_child(ghost_mesh)

	# Duduk pas di lantai celah dasar tumpukan balok (setengah tinggi BoxMesh 0.67 = 0.335)
	ghost_mesh.position = Vector3(0.0, 0.335, 0.0)

	var bm := BoxMesh.new()
	bm.size = Vector3(0.76, 0.67, 0.94)
	ghost_mesh.mesh = bm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 0.9)
	mat.emission_energy_multiplier = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_mesh.material_override = mat
	ghost_mesh.visible = false


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
	if ghost_mesh == null:
		return
	if is_filled:
		ghost_mesh.visible = false
		return
	# Sesuai aturan: Dunia Terlupakan (in_memory == false) menampilkan ghost silhouette hint
	ghost_mesh.visible = not is_in_memory


func _is_valid_block(node: Node3D) -> bool:
	if node == null:
		return false
	if "is_locked_in_slot" in node and node.is_locked_in_slot:
		return false
	if not target_item_name.is_empty() and node.name == target_item_name:
		return true
	if node.is_in_group("puzzle_block") or node.is_in_group("carryable"):
		return true
	if "PushableToyBlock" in node.name:
		return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if is_filled:
		return

	if _is_valid_block(body):
		_snap_block_into_slot(body)


func _snap_block_into_slot(body: Node3D) -> void:
	if is_filled:
		return
	if "is_locked_in_slot" in body and body.is_locked_in_slot:
		return

	is_filled = true

	# 1. Lepas pegangan CarrySystem & Player secara bersih
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		if "item_dipegang" in player and player.item_dipegang == body:
			player.item_dipegang = null
		if player.has_method("update_interact_hint"):
			player.call("update_interact_hint")

	var carry_sys = get_tree().root.find_child("CarrySystem", true, false)
	if carry_sys:
		if "carried_item" in carry_sys and carry_sys.carried_item == body:
			carry_sys.carried_item = null
			if carry_sys.has_method("_play_carry_animation"):
				carry_sys.call("_play_carry_animation", false)

	# 2. Snap balok ke tengah celah slot pas di dasar lantai (0.335m) dengan tween 0.25s
	var snap_target := global_position + Vector3(0.0, 0.335, 0.0)
	if body.has_method("lock_into_slot"):
		body.call("lock_into_slot", snap_target)
	elif body is RigidBody3D:
		var rb := body as RigidBody3D
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.collision_layer = 1
		rb.collision_mask = 1
		var tw := create_tween()
		tw.tween_property(rb, "global_position", snap_target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Feedback visual sukses (pendar hijau lembut pada slot)
	if ghost_mesh and ghost_mesh.material_override is StandardMaterial3D:
		var mat := (ghost_mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = Color(0.2, 0.95, 0.45, 0.55)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.9, 0.35)
		mat.emission_energy_multiplier = 2.0
		ghost_mesh.material_override = mat
		ghost_mesh.visible = true

		var fade_tw := create_tween()
		fade_tw.tween_property(mat, "albedo_color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fade_tw.tween_callback(func() -> void:
			if ghost_mesh:
				ghost_mesh.visible = false
		)

	slot_filled.emit(body)

	var parent = get_parent()
	if parent and parent.has_method("notify_slot_filled"):
		parent.call("notify_slot_filled", self, body)
	elif parent and parent.has_method("_on_slot_filled"):
		parent.call("_on_slot_filled", self, body)
