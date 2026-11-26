
@tool
extends SceneTree
func _init():
    var scene = load("res://scenes/levels/chapter_1.tscn")
    var root = scene.instantiate()
    var s11 = root.find_child("Sketchfab_Scene11", true, false)
    print("S11 pos:", s11.position, " scale:", s11.scale, " rot:", s11.rotation_degrees)
    for m in s11.find_children("*", "MeshInstance3D", true, false):
        print("  Mesh:", m.name, " aabb:", m.get_aabb(), " pos:", m.position, " scale:", m.scale)
    quit(0)
