@tool
extends SceneTree
func _init():
	var scene = load("res://scenes/levels/chapter_1.tscn")
	var root = scene.instantiate()
	get_root().add_child(root)
	var s15 = root.find_child("Sketchfab_Scene15", true, false)
	
	var mesh_aabb = AABB()
	var first = true
	for m in s15.find_children("*", "MeshInstance3D", true, false):
		var ga = m.global_transform * m.get_aabb()
		if first:
			mesh_aabb = ga
			first = false
		else:
			mesh_aabb = mesh_aabb.merge(ga)
	print("RESULT_MESH_GLOBAL: min=", mesh_aabb.position, " max=", mesh_aabb.end, " size=", mesh_aabb.size, " center=", mesh_aabb.get_center())

	var sb = s15.get_node_or_null("StaticBody3D")
	if sb:
		for c in sb.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D:
				var half = c.shape.size * 0.5
				var local_aabb = AABB(-half, c.shape.size)
				var ga = c.global_transform * local_aabb
				print("RESULT_COL_GLOBAL: ", c.name, " min=", ga.position, " max=", ga.end, " size=", ga.size, " center=", ga.get_center())
	quit(0)
