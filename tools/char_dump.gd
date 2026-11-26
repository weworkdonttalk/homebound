extends SceneTree

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var packed: PackedScene = load("res://assets/characters/mc/char_no_light.fbx")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	_dump(root, 0)
	print("--- idle (2) as AnimationLibrary ---")
	var lib = load("res://animations/mc/clips/idle (2).fbx")
	print("class=", lib.get_class(), " type=", typeof(lib))
	if lib is AnimationLibrary:
		for k in lib.get_animation_list():
			var a: Animation = lib.get_animation(k)
			print("clip=", k, " len=", a.length, " loop=", a.loop_mode, " tracks=", a.get_track_count())
			for t in range(min(a.get_track_count(), 6)):
				print("  ", a.track_get_path(t), " type=", a.track_get_type(t))
	print("--- carrying ---")
	var p2: PackedScene = load("res://animations/mc/clips/Carrying.fbx")
	var i2: Node = p2.instantiate()
	get_root().add_child(i2)
	var ap := _find_anim(i2)
	for k in ap.get_animation_list():
		var a: Animation = ap.get_animation(k)
		print("clip=", k, " len=", a.length, " loop=", a.loop_mode, " tracks=", a.get_track_count())
		for t in range(a.get_track_count()):
			print("  ", a.track_get_path(t), " type=", a.track_get_type(t))
	print("--- rest pose check ---")
	var sk := _find_skel(root)
	print("skel path=", sk.get_path(), " height approx from head top=", sk.get_bone_rest(7).origin)
	return true

func _dump(n: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + n.name + " [" + n.get_class() + "]"
	if n is MeshInstance3D:
		line += " aabb=" + str(n.get_aabb()) + " skel=" + str(n.skeleton)
	if n is Skeleton3D:
		line += " bones=" + str(n.get_bone_count())
	if n is Node3D:
		line += " pos=" + str(n.position)
	print(line)
	for c in n.get_children():
		_dump(c, depth + 1)

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null
