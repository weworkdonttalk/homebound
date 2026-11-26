extends SceneTree

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	print("=== ENGINE ", Engine.get_version_info()["string"], " ===")
	_dump_map()
	_dump_char()
	_dump_anims()
	return true

func _dump_map() -> void:
	print("\n=== MAP TREE ===")
	var packed: PackedScene = load("res://scenes/levels/chapter_1.tscn")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	_dump_node(root, 0)
	print("\n=== MAP MESH AABB ===")
	_dump_meshes(root, 1)
	root.queue_free()

func _dump_node(n: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + n.name + " [" + n.get_class() + "]"
	if n is Node3D:
		line += " pos=" + str(n.global_position)
	print(line)
	for c in n.get_children():
		_dump_node(c, depth + 1)

func _dump_meshes(n: Node, depth: int) -> void:
	if n is MeshInstance3D:
		var aabb: AABB = n.get_aabb()
		var g: AABB = n.global_transform * aabb
		if g.size.length() > 0.5:
			print("  ".repeat(depth), n.get_path(), " g=", g)
	for c in n.get_children():
		_dump_meshes(c, depth + 1)

func _dump_char() -> void:
	print("\n=== CHARACTER ===")
	var packed: PackedScene = load("res://assets/characters/mc/char_no_light.fbx")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	_dump_skeleton(root)
	_dump_anim_players(root)
	print("\nAABB meshes:")
	_dump_meshes(root, 1)
	root.queue_free()

func _dump_skeleton(n: Node) -> void:
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		print("Skeleton: ", sk.get_path(), " bones=", sk.get_bone_count())
		for i in range(sk.get_bone_count()):
			print("  ", i, ": ", sk.get_bone_name(i), " parent=", sk.get_bone_parent(i), " rest_origin=", sk.get_bone_rest(i).origin)
	for c in n.get_children():
		_dump_skeleton(c)

func _dump_anim_players(n: Node) -> void:
	if n is AnimationPlayer:
		print("AnimationPlayer: ", n.get_path(), " anims=", n.get_animation_list())
		for a in n.get_animation_list():
			var anim: Animation = n.get_animation(a)
			print("  clip=", a, " len=", anim.length, " tracks=", anim.get_track_count())
			for t in range(min(anim.get_track_count(), 4)):
				print("    track ", t, " path=", anim.track_get_path(t), " type=", anim.track_get_type(t))
	for c in n.get_children():
		_dump_anim_players(c)

func _dump_anims() -> void:
	print("\n=== ANIM FBX FILES ===")
	var files := DirAccess.get_files_at("res://animations/mc/clips")
	files.sort()
	for f in files:
		if not f.ends_with(".fbx"):
			continue
		var packed: PackedScene = load("res://animations/mc/clips/" + f)
		if packed == null:
			print(f, " -> LOAD FAIL")
			continue
		var inst := packed.instantiate()
		get_root().add_child(inst)
		var ap := _find_anim(inst)
		if ap:
			var names := ap.get_animation_list()
			var first: Animation = ap.get_animation(names[0]) if names.size() > 0 else null
			var paths := 0
			var sample_paths: Array[String] = []
			if first:
				paths = first.get_track_count()
				for t in range(min(paths, 3)):
					sample_paths.append(str(first.track_get_path(t)))
			print(f, " | clips=", names, " | tracks=", paths, " | sample=", sample_paths)
		else:
			print(f, " -> no AnimationPlayer")
		inst.queue_free()

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
