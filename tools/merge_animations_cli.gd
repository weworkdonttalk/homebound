extends SceneTree

## Headless merger:
##   godot --headless --path . --script res://tools/merge_animations_cli.gd
##
## Gunakan ini di CI / terminal. Untuk editor, pakai tools/merge_animations.gd
## supaya library otomatis terpasang ke scenes/player.tscn.

const Merger = preload("res://scripts/utils/animation_merge_util.gd")

func _init() -> void:
	print("[merge_animations_cli] Mulai...")
	var library := Merger.save_library(Merger.MERGED_LIBRARY_PATH)
	if library == null:
		printerr("[merge_animations_cli] GAGAL.")
		quit(1)
		return

	for clip_name in library.get_animation_list():
		var anim: Animation = library.get_animation(clip_name)
		var hips_pos := 0
		for i in anim.get_track_count():
			var path := String(anim.track_get_path(i))
			if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and path.contains("mixamorig_Hips"):
				hips_pos += 1
		print("  %-10s length=%5.2f loop=%d tracks=%d hips_pos=%d" % [
			clip_name, anim.length, anim.loop_mode, anim.get_track_count(), hips_pos
		])

	print("[merge_animations_cli] Selesai: %s" % Merger.MERGED_LIBRARY_PATH)
	quit(0)
