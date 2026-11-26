@tool
class_name AnimationMergeUtil
extends RefCounted

## Utility untuk menggabungkan banyak file FBX/glTF Mixamo (baik AnimationLibrary
## maupun PackedScene berisi AnimationPlayer) menjadi SATU AnimationLibrary.
## Semua track posisi Hips (root motion) dibuang supaya karakter bergerak murni
## dari CharacterBody3D.

const MERGED_LIBRARY_PATH := "res://animations/mc/merged_animations.tres"
const DEFAULT_TRACK_PREFIX := ""

const DEFAULT_CLIPS := {
	"Idle": {"path": "res://animations/mc/clips/idle (2).fbx", "loop": true},
	"Walk": {"path": "res://animations/mc/clips/walking.fbx", "loop": true},
	"Run": {"path": "res://animations/mc/clips/running.fbx", "loop": true},
	"Jump": {"path": "res://animations/mc/clips/jumping up.fbx", "loop": false},
	"Fall": {"path": "res://animations/mc/clips/falling idle.fbx", "loop": true},
	"Land": {"path": "res://animations/mc/clips/hard landing.fbx", "loop": false},
	"Roll": {"path": "res://animations/mc/clips/falling to roll.fbx", "loop": false},
	"CrouchIdle": {"path": "res://animations/mc/clips/Crouching Idle (1).fbx", "loop": true},
	"CrouchWalk": {"path": "res://animations/mc/clips/crouched sneaking right.fbx", "loop": true},
	"Climb": {"path": "res://animations/mc/clips/Climbing.fbx", "loop": true},
	"ClimbUp": {"path": "res://animations/mc/clips/Climbing Up Wall.fbx", "loop": false},
	"ClimbDown": {"path": "res://animations/mc/clips/Climbing Down Wall.fbx", "loop": false},
	"Carrying": {"path": "res://animations/mc/clips/Carrying.fbx", "loop": true},
	"CarryWalk": {"path": "res://animations/mc/clips/carrying walking.fbx", "loop": true},
	"Push": {"path": "res://animations/mc/clips/Push.fbx", "loop": true},
	"Pull": {"path": "res://animations/mc/clips/Pull Heavy Object.fbx", "loop": true},
}

static func build_library(
	clips: Dictionary = DEFAULT_CLIPS,
	track_prefix: String = DEFAULT_TRACK_PREFIX
) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var report: Array[String] = []

	for clip_name: String in clips.keys():
		var spec: Dictionary = clips[clip_name]
		var source_path: String = spec.get("path", "")
		var source := ResourceLoader.load(source_path)
		if source == null:
			push_error("[AnimationMergeUtil] Gagal load: %s" % source_path)
			continue

		var source_anim := _extract_animation(source)
		if source_anim == null:
			push_error("[AnimationMergeUtil] Tidak ada Animation di: %s" % source_path)
			continue

		var anim: Animation = source_anim.duplicate(true)
		anim.resource_name = clip_name
		anim.loop_mode = Animation.LOOP_LINEAR if bool(spec.get("loop", false)) else Animation.LOOP_NONE

		var removed_positions := _strip_hips_position_tracks(anim)
		_prefix_track_paths(anim, track_prefix)

		library.add_animation(clip_name, anim)
		report.append("%-12s <- %-32s len=%5.2fs tracks=%d hip_pos_removed=%d" % [
			clip_name, source_path.get_file(), anim.length, anim.get_track_count(), removed_positions
		])

	print("[AnimationMergeUtil] Berhasil gabung %d klip:" % library.get_animation_list().size())
	for line in report:
		print("  ", line)
	return library

static func save_library(
	path: String = MERGED_LIBRARY_PATH,
	clips: Dictionary = DEFAULT_CLIPS,
	track_prefix: String = DEFAULT_TRACK_PREFIX
) -> AnimationLibrary:
	var library := build_library(clips, track_prefix)
	if library.get_animation_list().is_empty():
		push_error("[AnimationMergeUtil] Library kosong, tidak disimpan.")
		return null
	var err := ResourceSaver.save(library, path)
	if err != OK:
		push_error("[AnimationMergeUtil] ResourceSaver.save gagal (%d): %s" % [err, path])
		return null
	print("[AnimationMergeUtil] Tersimpan: %s" % path)
	return library

static func apply_to_player(anim_player: AnimationPlayer, library: AnimationLibrary, library_name := "") -> bool:
	if anim_player == null or library == null:
		return false
	if anim_player.has_animation_library(library_name):
		anim_player.remove_animation_library(library_name)
	var err := anim_player.add_animation_library(library_name, library)
	if err != OK:
		push_error("[AnimationMergeUtil] add_animation_library gagal: %d" % err)
		return false
	return true

static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null

static func _extract_animation(source: Resource) -> Animation:
	if source is Animation:
		return source
	if source is AnimationLibrary:
		var list = source.get_animation_list()
		if list.is_empty():
			return null
		return source.get_animation(list[0])
	if source is PackedScene:
		var inst: Node = source.instantiate()
		var ap: AnimationPlayer = _find_ap_in_node(inst)
		var anim: Animation = null
		if ap != null:
			var list = ap.get_animation_list()
			if not list.is_empty():
				anim = ap.get_animation(list[0]).duplicate(true)
		inst.queue_free()
		return anim
	return null

static func _find_ap_in_node(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_ap_in_node(child)
		if found != null:
			return found
	return null

static func _strip_hips_position_tracks(anim: Animation) -> int:
	var removed := 0
	for i in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(anim.track_get_path(i))
		if path.contains("mixamorig_Hips") or path.ends_with("Hips:position"):
			anim.remove_track(i)
			removed += 1
	return removed

static func _prefix_track_paths(anim: Animation, track_prefix: String) -> void:
	var prefix := track_prefix.strip_edges().trim_suffix("/")
	if prefix.is_empty():
		return
	for i in anim.get_track_count():
		var old_path := String(anim.track_get_path(i))
		if old_path.begins_with(prefix + "/"):
			continue
		anim.track_set_path(i, NodePath(prefix + "/" + old_path))
