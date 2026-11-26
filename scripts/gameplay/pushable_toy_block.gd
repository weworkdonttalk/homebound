@tool
extends RigidBody3D
class_name PushableToyBlock

## PushableToyBlock / ToyBoxItem — Balok Mainan Puzzle ABCD (Chapter 1)
## Menggunakan sistem CarrySystem yang identik dengan Teddy Bear (pickup & carrying),
## mendukung Shifting Memory Hint ([T]), dan auto-snapping ke 3 slot tujuan puzzle.

@export var block_id: String = "A"
var is_locked_in_slot: bool = false
var hint_mesh: MeshInstance3D = null

func _ready() -> void:
	# Samakan 100% dengan grup dan konfigurasi fisik TeddyBearPickup
	add_to_group("pickup")
	add_to_group("carryable")
	add_to_group("puzzle_block")

	# Pastikan grup tarik/pushable lama dilepas
	if is_in_group("tarik"):
		remove_from_group("tarik")
	if is_in_group("pushable"):
		remove_from_group("pushable")

	# Physics Layer 3 (Item = 4), Mask 1 (Environment = 1), Bobot ringan 1.0kg
	collision_layer = 4
	collision_mask = 1
	mass = 1.0
	freeze = false

	_setup_visual()
	_setup_hint_mesh()
	_connect_world_dimension()


func _setup_visual() -> void:
	if has_node("abc_toy_model"):
		return

	var glb_res = load("res://assets/environment/props/toys/abc_toy_1_biji.glb")
	if glb_res:
		var model = glb_res.instantiate()
		model.name = "abc_toy_model"
		model.transform = Transform3D(
			Vector3(0.1, 0.0, 0.0),
			Vector3(0.0, 0.09, 0.0),
			Vector3(0.0, 0.0, 0.13),
			Vector3(1.02874, 0.00269, -0.31422)
		)
		add_child(model)

		for mi in model.find_children("*", "MeshInstance3D", true):
			var mesh_inst: MeshInstance3D = mi as MeshInstance3D
			if mesh_inst and mesh_inst.mesh:
				for s in range(mesh_inst.mesh.get_surface_count()):
					var mat = mesh_inst.mesh.surface_get_material(s)
					if mat is StandardMaterial3D:
						var sm: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
						sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
						sm.emission_enabled = false
						sm.roughness = maxf(sm.roughness, 0.85)
						sm.metallic = 0.0
						var c: Color = sm.albedo_color
						if (c.r + c.g + c.b) > 2.0:
							sm.albedo_color = Color(c.r * 0.75, c.g * 0.75, c.b * 0.75, c.a)
						mesh_inst.set_surface_override_material(s, sm)


func _setup_hint_mesh() -> void:
	hint_mesh = get_node_or_null("BlockHiddenHint") as MeshInstance3D
	if hint_mesh == null:
		hint_mesh = MeshInstance3D.new()
		hint_mesh.name = "BlockHiddenHint"
		hint_mesh.position = Vector3(0.00234, 0.3344, 0.03454)
		add_child(hint_mesh)

	var bm := BoxMesh.new()
	bm.size = Vector3(0.76, 0.67, 0.94)
	hint_mesh.mesh = bm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 0.9)
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hint_mesh.material_override = mat
	hint_mesh.visible = false


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
	if hint_mesh == null:
		return
	if is_locked_in_slot:
		hint_mesh.visible = false
		return
	# Sesuai aturan: Dunia Terlupakan (in_memory == false) menampilkan ghost silhouette hint
	hint_mesh.visible = not is_in_memory


func lock_into_slot(target_pos: Vector3) -> void:
	is_locked_in_slot = true
	if hint_mesh:
		hint_mesh.visible = false

	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 1
	collision_mask = 1

	var tw := create_tween()
	tw.tween_property(self, "global_position", target_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
