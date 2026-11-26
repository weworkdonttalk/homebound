@tool
extends SceneTree

func _init() -> void:
	var scene = load("res://scenes/levels/chapter_1.tscn")
	if scene == null:
		print("Failed to load map.tscn")
		quit(1)
		return

	var root = scene.instantiate()
	print("=== SCANNING FOR ALL MESHES AND COLLIDERS ===")

	var all_nodes = []
	_gather(root, all_nodes)

	for node in all_nodes:
		var parent_path = str(node.get_parent().get_path()).replace(str(root.get_path()), "") if node.get_parent() else ""
		if node.name.begins_with("Sketchfab_Scene") or node.name == "chapter 1 kosong":
			var has_col = false
			for c in node.get_children():
				if c is StaticBody3D or c is RigidBody3D or c is Area3D:
					for sub_c in c.get_children():
						if sub_c is CollisionShape3D:
							has_col = true
							break
				elif c is CollisionShape3D:
					has_col = true

			var mesh_aabbs = []
			var meshes = node.find_children("*", "MeshInstance3D")
			for m in meshes:
				mesh_aabbs.append([m.name, m.get_aabb(), m.transform.origin, m.scale])

			print("NODE: ", node.get_parent().name, "/", node.name, " | HAS_COL: ", has_col, " | Transform: pos=", node.position, " rot=", node.rotation_degrees, " scale=", node.scale)
			for ma in mesh_aabbs:
				print("   MESH: ", ma[0], " aabb=", ma[1], " pos=", ma[2], " scale=", ma[3])

	quit(0)

func _gather(n: Node, list: Array) -> void:
	list.append(n)
	for c in n.get_children():
		_gather(c, list)
