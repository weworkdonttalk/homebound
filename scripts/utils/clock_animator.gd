class_name ClockAnimator
extends Node

## ============================================================================
## ClockAnimator — Mengaktifkan semua animasi jam & roda gigi GLB di Chapter 2
## Mengatur LOOP_LINEAR, variasi kecepatan/fase, dan memutar multi-rotor orrery
## secara bersamaan tanpa mengubah file .glb asli.
## ============================================================================

@export var clock_paths: Array[NodePath] = []
@export var randomize_speed_min: float = 0.8
@export var randomize_speed_max: float = 1.25


func _ready() -> void:
	call_deferred("_start_all_clocks")


func _start_all_clocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261127

	for rel_path in clock_paths:
		var clock_root := get_node_or_null(rel_path)
		if clock_root == null:
			continue

		for ap_node in clock_root.find_children("*", "AnimationPlayer", true, false):
			var ap := ap_node as AnimationPlayer
			if ap == null:
				continue
			var anim_names := ap.get_animation_list()
			if anim_names.is_empty():
				continue

			for anim_name in anim_names:
				var anim := ap.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR

			var spd := rng.randf_range(randomize_speed_min, randomize_speed_max)
			ap.speed_scale = spd
			var first_anim := anim_names[0]
			ap.play(first_anim)
			var first_res := ap.get_animation(first_anim)
			if first_res and first_res.length > 0.05:
				ap.seek(rng.randf_range(0.0, first_res.length), true)

			# Untuk model orrery yang punya beberapa track rotor bersamaan (E01/E02/E03)
			for i in range(1, anim_names.size()):
				var extra_ap := AnimationPlayer.new()
				extra_ap.name = "ExtraRotorPlayer_%d" % i
				extra_ap.root_node = ap.root_node
				var lib := AnimationLibrary.new()
				var extra_anim := ap.get_animation(anim_names[i])
				if extra_anim:
					lib.add_animation(anim_names[i], extra_anim)
					extra_ap.add_animation_library("", lib)
					ap.get_parent().add_child(extra_ap)
					extra_ap.speed_scale = spd * rng.randf_range(0.9, 1.15)
					extra_ap.play(anim_names[i])
