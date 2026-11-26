@tool
extends SceneTree

func _init() -> void:
	var path = "res://assets/environment/props/furniture/wizard_table.glb"
	var scene: PackedScene = load(path)
	if scene == null:
		print("FAILED TO LOAD")
		quit(1)
		return
	var inst = scene.instantiate()
	print("=== MESHES IN WIZARD TABLE ===")
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		print("Mesh: ", m.name, " aabb=", m.get_aabb(), " pos=", m.transform.origin, " basis=", m.transform.basis)
	
	print("\n=== CHECKING MAP SCENE INSTANCE OF SKETCHFAB_SCENE15 ===")
	var map_scene: PackedScene = load("res://scenes/levels/chapter_1.tscn")
	var map_inst = map_scene.instantiate()
	var s15 = map_inst.find_child("Sketchfab_Scene15", true, false)
	if s15:
		print("Found Sketchfab_Scene15: global_pos=", s15.global_position, " pos=", s15.position, " rot=", s15.rotation_degrees)
		for c in s15.get_children():
			print("  Child: ", c.name, " (", c.get_class(), ") pos=", c.position if c is Node3D else "")
			if c is StaticBody3D:
				for sc in c.get_children():
					if sc is CollisionShape3D:
						print("    Col: ", sc.name, " shape=", sc.shape, " pos=", sc.position, " shape_size=", sc.shape.size if sc.shape is BoxShape3D else "")
	quit(0)
