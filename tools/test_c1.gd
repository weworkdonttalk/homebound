
@tool
extends SceneTree
func _init():
    var sc = load("res://assets/environment/chapter_1/chapter_1_room.glb")
    var inst = sc.instantiate()
    print("Meshes in chapter 1 kosong.glb:")
    for m in inst.find_children("*", "MeshInstance3D", true, false):
        print(" ", m.name, " aabb=", m.get_aabb(), " pos=", m.transform.origin, " scale=", m.scale)
    quit(0)
