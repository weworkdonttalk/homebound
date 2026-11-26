
@tool
extends SceneTree
func _init():
    var sc = load("res://scenes/levels/chapter_1.tscn")
    var root = sc.instantiate()
    var c1 = root.find_child("chapter 1 kosong", true, false)
    for c in c1.get_children():
        if "Sketchfab_model" in c.name:
            var meshes = c.find_children("*", "MeshInstance3D", true, false)
            var mesh_names = []
            for m in meshes:
                mesh_names.append(m.name + " (aabb=" + str(m.get_aabb().size) + ")")
            print(c.name, " pos=", c.position, " rot=", c.rotation_degrees, " scale=", c.scale, " meshes=", mesh_names)
    quit(0)
