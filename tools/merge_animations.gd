@tool
extends EditorScript

## Jalankan dari editor Godot:
##   File > Run  (atau Ctrl+Shift+X) saat script ini dibuka.
##
## Hasil:
##   1. res://animations/mc/merged_animations.tres  (12 klip: Idle, Walk, Run, ...)
##   2. Kalau scene Player sedang dibuka, library langsung dipasang ke
##      Player/AnimationPlayer lalu scene disimpan.
##
## Script ini aman dijalankan berulang.

const MERGED_PATH := "res://animations/mc/merged_animations.tres"

func _run() -> void:
	print("\n=== MERGE ANIMASI CHAPTER 1 ===")
	var library := AnimationMergeUtil.save_library(MERGED_PATH)
	if library == null:
		printerr("Merge gagal. Cek path FBX di AnimationMergeUtil.DEFAULT_CLIPS.")
		return

	var edited := EditorInterface.get_edited_scene_root()
	if edited == null:
		print("[MergeAnimations] Tidak ada scene terbuka. Library tetap tersimpan.")
		return

	var player := _find_player_root(edited)
	if player == null:
		print("[MergeAnimations] Scene '%s' bukan Player. Library tersimpan; buka scenes/player.tscn lalu jalankan lagi untuk auto-assign." % edited.name)
		return

	var anim_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		anim_player = AnimationMergeUtil.find_animation_player(player)
	if anim_player == null:
		printerr("[MergeAnimations] AnimationPlayer tidak ditemukan di Player.")
		return

	if AnimationMergeUtil.apply_to_player(anim_player, library):
		EditorInterface.mark_scene_as_unsaved()
		EditorInterface.save_scene()
		print("[MergeAnimations] Library dipasang ke %s dan scene disimpan." % anim_player.get_path())
	else:
		printerr("[MergeAnimations] Gagal memasang library ke AnimationPlayer.")

func _find_player_root(root: Node) -> Node:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	for node in selection:
		if node.name == "Player" or node.get_script() != null and node is CharacterBody3D:
			return node
	if root.name == "Player":
		return root
	return root.find_child("Player", true, false)
