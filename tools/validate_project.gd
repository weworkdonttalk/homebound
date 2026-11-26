@tool
extends SceneTree

func _init():
	print("=== GODOT 4 HEADLESS PROJECT VALIDATION ===")
	var errors := 0

	# 1. Main Scene / Chapter 1
	print("\n--- Validating Chapter 1 Level Scene ---")
	var c1: PackedScene = load("res://scenes/levels/chapter_1.tscn")
	if c1 == null:
		printerr("FAIL: Cannot load res://scenes/levels/chapter_1.tscn")
		errors += 1
	else:
		var inst = c1.instantiate()
		if inst == null:
			printerr("FAIL: Cannot instantiate chapter_1.tscn")
			errors += 1
		else:
			print("SUCCESS: Chapter 1 scene instantiated (", inst.get_child_count(), " direct children)")
			inst.free()

	# 2. Chapter 2 Scene
	print("\n--- Validating Chapter 2 Level Scene ---")
	var c2: PackedScene = load("res://scenes/levels/chapter_2.tscn")
	if c2 == null:
		printerr("FAIL: Cannot load res://scenes/levels/chapter_2.tscn")
		errors += 1
	else:
		var inst2 = c2.instantiate()
		if inst2 == null:
			printerr("FAIL: Cannot instantiate chapter_2.tscn")
			errors += 1
		else:
			print("SUCCESS: Chapter 2 scene instantiated")
			inst2.free()

	# 3. Props Scenes
	print("\n--- Validating Props Scenes ---")
	var props = [
		"res://scenes/props/pushable_toy_block.tscn",
		"res://scenes/props/wooden_door.tscn",
		"res://scenes/props/portal_light_gate.tscn"
	]
	for p in props:
		var sc: PackedScene = load(p)
		if sc == null:
			printerr("FAIL: Cannot load prop scene: ", p)
			errors += 1
		else:
			var inst = sc.instantiate()
			print("SUCCESS: Loaded and instantiated prop: ", p)
			inst.free()

	# 4. Merged Animations Library
	print("\n--- Validating Animation Library ---")
	var anim_lib: AnimationLibrary = load("res://animations/mc/merged_animations.tres")
	if anim_lib == null:
		printerr("FAIL: Cannot load res://animations/mc/merged_animations.tres")
		errors += 1
	else:
		var anims = anim_lib.get_animation_list()
		print("SUCCESS: Loaded merged_animations.tres with ", anims.size(), " animations: ", anims)

	# 5. Materials & Shaders
	print("\n--- Validating Shaders & Materials ---")
	var shaders = [
		"res://shaders/vignette.gdshader",
		"res://shaders/dimension_shift_transition.gdshader"
	]
	for sh in shaders:
		var s: Shader = load(sh)
		if s == null:
			printerr("FAIL: Cannot load shader: ", sh)
			errors += 1
		else:
			print("SUCCESS: Loaded shader: ", sh)

	var mats = [
		"res://assets/textures/dark_wood/dark_wood_wall.tres",
		"res://assets/textures/peeling_painted_wall/peeling_painted_wall.tres"
	]
	for m in mats:
		var mat: Material = load(m)
		if mat == null:
			printerr("FAIL: Cannot load material: ", m)
			errors += 1
		else:
			print("SUCCESS: Loaded material: ", m)

	# 6. Scripts
	print("\n--- Validating Core Scripts ---")
	var scripts = [
		"res://scripts/characters/mc.gd",
		"res://scripts/characters/headlamp_attachment.gd",
		"res://scripts/camera/cinematic_camera_rig.gd",
		"res://scripts/camera/parkour_camera_zone.gd",
		"res://scripts/core/world.gd",
		"res://scripts/core/chapter1_puzzle_manager.gd",
		"res://scripts/gameplay/carry_system.gd",
		"res://scripts/gameplay/pressure_plate.gd",
		"res://scripts/gameplay/glowing_platforms.gd",
		"res://scripts/gameplay/door_portal.gd",
		"res://scripts/gameplay/teddy_bear.gd",
		"res://scripts/gameplay/pushable_toy_block.gd",
		"res://scripts/gameplay/floating_object.gd",
		"res://scripts/gameplay/parkour_sequencer.gd",
		"res://scripts/gameplay/portal_light_gate.gd",
		"res://scripts/gameplay/rock_step_trigger.gd",
		"res://scripts/effects/ceiling_lamp.gd",
		"res://scripts/effects/dust_particles.gd",
		"res://scripts/effects/guiding_trail.gd",
		"res://scripts/effects/time_stop_effect.gd",
		"res://scripts/effects/vignette_controller.gd",
		"res://scripts/utils/animation_merge_util.gd"
	]
	for scr in scripts:
		var s = load(scr)
		if s == null:
			printerr("FAIL: Cannot load script: ", scr)
			errors += 1
		else:
			print("SUCCESS: Loaded script: ", scr)

	print("\n=== VALIDATION RESULT ===")
	if errors == 0:
		print("ALL CHECKS PASSED PERFECTLY! (0 errors)")
		quit(0)
	else:
		printerr("VALIDATION FAILED with ", errors, " errors!")
		quit(1)
