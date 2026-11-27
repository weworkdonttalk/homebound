@tool
class_name AutoTrimeshCollider
extends Node3D

## AutoTrimeshCollider — Membuat StaticBody3D trimesh collision akurat
## pada setiap MeshInstance3D anak (berguna untuk aset GLB batu/lantai tanpa collider).
## Jika jumlah mesh sangat padat (> use_merged_box_above), digabung menjadi satu BoxShape3D
## agar loading editor & runtime tetap instan.

@export var collision_layer_bits: int = 1
@export var collision_mask_bits: int = 0
@export var use_merged_box_above: int = 40


func _ready() -> void:
	_ensure_colliders()


func _ensure_colliders() -> void:
	var mesh_nodes: Array[MeshInstance3D] = []
	for mi in find_children("*", "MeshInstance3D", true):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst != null and mesh_inst.mesh != null:
			mesh_nodes.append(mesh_inst)

	if mesh_nodes.is_empty():
		return

	if mesh_nodes.size() > use_merged_box_above:
		_ensure_merged_box(mesh_nodes)
		return

	for mesh_inst in mesh_nodes:
		if mesh_inst.get_node_or_null("AutoTrimeshBody") != null:
			continue

		var shape := mesh_inst.mesh.create_trimesh_shape()
		if shape == null:
			continue

		var body := StaticBody3D.new()
		body.name = "AutoTrimeshBody"
		body.collision_layer = collision_layer_bits
		body.collision_mask = collision_mask_bits

		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = shape
		body.add_child(col)
		mesh_inst.add_child(body)


func _ensure_merged_box(mesh_nodes: Array[MeshInstance3D]) -> void:
	if get_node_or_null("AutoMergedBoxBody") != null:
		return

	var has_bounds := false
	var merged := AABB()
	for mesh_inst in mesh_nodes:
		var local_xform := _get_relative_transform(mesh_inst)
		var mesh_aabb := mesh_inst.mesh.get_aabb()
		for i in range(8):
			var p := local_xform * mesh_aabb.get_endpoint(i)
			if not has_bounds:
				merged = AABB(p, Vector3.ZERO)
				has_bounds = true
			else:
				merged = merged.expand(p)

	if not has_bounds or merged.size.length_squared() <= 0.0001:
		return

	var body := StaticBody3D.new()
	body.name = "AutoMergedBoxBody"
	body.collision_layer = collision_layer_bits
	body.collision_mask = collision_mask_bits

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = merged.size
	col.shape = box
	col.position = merged.get_center()
	body.add_child(col)
	add_child(body)


func _get_relative_transform(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != self:
		if cur is Node3D:
			xform = (cur as Node3D).transform * xform
		cur = cur.get_parent()
	return xform
