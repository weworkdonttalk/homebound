
@tool
extends SceneTree
func _init():
    var scene = load("res://scenes/levels/chapter_1.tscn")
    var root = scene.instantiate()
    var s11 = root.find_child("Sketchfab_Scene11", true, false)
    var m = s11.find_child("Table_Table_mat_0", true, false)
    if m:
        # MeshInstance3D in s11
        # m.transform relative to s11:
        var cur = m
        var t_rel = Transform3D()
        while cur != s11 and cur != null:
            t_rel = cur.transform * t_rel
            cur = cur.get_parent()
        print("Transform of mesh rel to S11: ", t_rel)
        var aabb_local = m.get_aabb()
        var aabb_in_s11 = t_rel * aabb_local
        print("AABB in S11 local space: pos=", aabb_in_s11.position, " size=", aabb_in_s11.size, " center=", aabb_in_s11.get_center())
    quit(0)
