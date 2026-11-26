extends SceneTree

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	for f in ["idle (2)", "walking", "running", "jumping up", "falling idle", "hard landing", "Carrying", "carrying walking", "Crouching Idle (1)", "crouched sneaking left", "Climbing"]:
		var lib = load("res://animations/mc/clips/" + f + ".fbx")
		var anim: Animation = null
		if lib is AnimationLibrary:
			var names: PackedStringArray = lib.get_animation_list()
			anim = lib.get_animation(names[0])
		elif lib is PackedScene:
			var inst: Node = lib.instantiate()
			get_root().add_child(inst)
			var ap := _find_anim(inst)
			var names: PackedStringArray = ap.get_animation_list()
			anim = ap.get_animation(names[0])
		if anim == null:
			print(f, " -> null")
			continue
		var hip := -1
		for t in range(anim.get_track_count()):
			if str(anim.track_get_path(t)).ends_with("mixamorig_Hips") and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				hip = t
				break
		var times := PackedFloat32Array()
		if hip >= 0:
			for k in range(anim.track_get_key_count(hip)):
				times.append(anim.track_get_key_time(hip, k))
		print("--- ", f, " len=", anim.length, " keys=", times.size())
		if times.size() > 0:
			var diff := 0.0
			if times.size() > 1:
				diff = times[1] - times[0]
			print("  times[0..5]=", times.slice(0, 6), " last=", times[times.size()-1], " dt=", diff)
			if hip >= 0:
				var vals: Array = []
				for k in range(anim.track_get_key_count(hip)):
					vals.append(anim.track_get_key_value(hip, k))
				if vals.size() > 0:
					print("  hip start=", vals.slice(0, 3), " mid=", vals.slice(int(vals.size()/2), int(vals.size()/2)+3), " end=", vals.slice(vals.size()-3, vals.size()))
	return true

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
