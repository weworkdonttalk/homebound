class_name Chapter2PuzzleManager
extends Node3D

## Koordinator utama ke-4 puzzle Chapter 2 (CLOCK).
## Menyediakan helper bersama untuk WorldManager/Player lookup & menyalurkan
## progress terpadu ke UIManager / QuestGuide.

signal two_clocks_updated(synced_count: int, total_count: int)
signal two_clocks_completed
signal wall_clocks_updated(current_step: int, target_step: int, total_steps: int)
signal wall_clocks_completed
signal wall_clocks_reset(new_target_hour: int)
signal safe_room_state_changed(entered: bool)
signal inner_clock_step_changed(current_step: int, target_step: int, solved: bool)
signal missing_time_updated(matched_count: int, total_count: int)
signal missing_time_completed
signal erased_progress_updated(collected: int, total_count: int)
signal erased_room_completed
signal pendulum_progress_updated(step_index: int, total_steps: int)
signal pendulum_completed
signal relic_collected_updated(collected: int, total: int)
signal relic_stolen_by_eraser(delivered_count: int, total: int)
signal relic_delivered(delivered_count: int, total: int)
signal all_relics_delivered
signal chapter_completed

var two_clocks_done: bool = false
var wall_clocks_done: bool = false
var missing_time_done: bool = false
var erased_room_done: bool = false
var pendulum_done: bool = false
var relic_delivered_done: bool = false
var total_relics: int = 3
var relics_delivered_count: int = 0

var _two_clocks: Node = null
var _wall_clocks: Node = null
var _missing_time: Node = null
var _erased_room: Node = null
var _pendulum_zone: Node = null
var _world_manager: Node = null


func _ready() -> void:
	add_to_group("chapter2_puzzle_manager")
	_world_manager = find_world_manager(self)
	call_deferred("_wire_subsystems")


func _wire_subsystems() -> void:
	var root := get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
	if root == null:
		return

	_two_clocks = root.find_child("TwoClocksPuzzle", true, false)
	if _two_clocks:
		if _two_clocks.has_signal("progress_updated") and not _two_clocks.is_connected("progress_updated", _on_two_clocks_progress):
			_two_clocks.connect("progress_updated", _on_two_clocks_progress)
		if _two_clocks.has_signal("puzzle_completed") and not _two_clocks.is_connected("puzzle_completed", _on_two_clocks_done):
			_two_clocks.connect("puzzle_completed", _on_two_clocks_done)

	_wall_clocks = root.find_child("WallClocksPuzzle", true, false)
	if _wall_clocks:
		if _wall_clocks.has_signal("wall_clock_step_changed") and not _wall_clocks.is_connected("wall_clock_step_changed", _on_wall_clocks_progress):
			_wall_clocks.connect("wall_clock_step_changed", _on_wall_clocks_progress)
		if _wall_clocks.has_signal("puzzle_completed") and not _wall_clocks.is_connected("puzzle_completed", _on_wall_clocks_done):
			_wall_clocks.connect("puzzle_completed", _on_wall_clocks_done)
		if _wall_clocks.has_signal("wall_clocks_reset") and not _wall_clocks.is_connected("wall_clocks_reset", _on_wall_clocks_reset):
			_wall_clocks.connect("wall_clocks_reset", _on_wall_clocks_reset)
		if _wall_clocks.has_signal("safe_room_state_changed") and not _wall_clocks.is_connected("safe_room_state_changed", _on_safe_room_state_changed):
			_wall_clocks.connect("safe_room_state_changed", _on_safe_room_state_changed)
		if _wall_clocks.has_signal("inner_clock_step_changed") and not _wall_clocks.is_connected("inner_clock_step_changed", _on_inner_clock_step_changed):
			_wall_clocks.connect("inner_clock_step_changed", _on_inner_clock_step_changed)

	_missing_time = root.find_child("MissingTimePuzzle", true, false)
	if _missing_time:
		if _missing_time.has_signal("progress_updated") and not _missing_time.is_connected("progress_updated", _on_missing_time_progress):
			_missing_time.connect("progress_updated", _on_missing_time_progress)
		if _missing_time.has_signal("puzzle_completed") and not _missing_time.is_connected("puzzle_completed", _on_missing_time_done):
			_missing_time.connect("puzzle_completed", _on_missing_time_done)

	_erased_room = root.find_child("ErasedRoomPuzzle", true, false)
	if _erased_room:
		if _erased_room.has_signal("fragment_progress_updated") and not _erased_room.is_connected("fragment_progress_updated", _on_erased_progress):
			_erased_room.connect("fragment_progress_updated", _on_erased_progress)
		if _erased_room.has_signal("puzzle_completed") and not _erased_room.is_connected("puzzle_completed", _on_erased_done):
			_erased_room.connect("puzzle_completed", _on_erased_done)

	_pendulum_zone = root.find_child("PendulumPuzzleZone", true, false)
	if _pendulum_zone:
		if _pendulum_zone.has_signal("step_reached") and not _pendulum_zone.is_connected("step_reached", _on_pendulum_progress):
			_pendulum_zone.connect("step_reached", _on_pendulum_progress)
		if _pendulum_zone.has_signal("pendulum_cleared") and not _pendulum_zone.is_connected("pendulum_cleared", _on_pendulum_done):
			_pendulum_zone.connect("pendulum_cleared", _on_pendulum_done)

	var portal := root.find_child("DoorPortal", true, false)
	if portal and portal.has_signal("transition_started") and not portal.is_connected("transition_started", _on_portal_entered):
		portal.connect("transition_started", _on_portal_entered)

	var socket_zone := root.find_child("RelicSocketZone", true, false)
	if socket_zone:
		if "required_relic_count" in socket_zone:
			total_relics = maxi(int(socket_zone.get("required_relic_count")), 1)
		if socket_zone.has_signal("all_relics_delivered") and not socket_zone.is_connected("all_relics_delivered", notify_all_relics_delivered):
			socket_zone.connect("all_relics_delivered", notify_all_relics_delivered)


func _get_relic_progress_count() -> int:
	var player := find_player(self)
	var carried := 0
	if player and "floating_relics" in player and player.get("floating_relics") is Array:
		carried = (player.get("floating_relics") as Array).size()
	return mini(relics_delivered_count + carried, total_relics)


func notify_relic_collected(_relic: Node = null) -> void:
	if relic_delivered_done:
		return
	relic_collected_updated.emit(_get_relic_progress_count(), total_relics)


func notify_all_relics_reset() -> void:
	if relic_delivered_done:
		return
	relic_stolen_by_eraser.emit(relics_delivered_count, total_relics)
	relic_collected_updated.emit(relics_delivered_count, total_relics)


func notify_relic_delivered(_relic: Node = null) -> void:
	if relic_delivered_done:
		return
	relics_delivered_count = mini(relics_delivered_count + 1, total_relics)
	relic_delivered.emit(relics_delivered_count, total_relics)
	if relics_delivered_count >= total_relics:
		notify_all_relics_delivered()


func notify_all_relics_delivered() -> void:
	if relic_delivered_done:
		return
	relic_delivered_done = true
	relics_delivered_count = total_relics
	all_relics_delivered.emit()


func _on_two_clocks_progress(synced: int, total: int) -> void:
	two_clocks_updated.emit(synced, total)


func _on_two_clocks_done() -> void:
	if two_clocks_done:
		return
	two_clocks_done = true
	two_clocks_completed.emit()


func _on_wall_clocks_progress(step: int, target: int, total: int) -> void:
	wall_clocks_updated.emit(step, target, total)


func _on_wall_clocks_done() -> void:
	if wall_clocks_done:
		return
	wall_clocks_done = true
	wall_clocks_completed.emit()


func _on_wall_clocks_reset(new_target_hour: int) -> void:
	wall_clocks_done = false
	wall_clocks_reset.emit(new_target_hour)


func _on_safe_room_state_changed(entered: bool) -> void:
	safe_room_state_changed.emit(entered)


func _on_inner_clock_step_changed(current_step: int, target_step: int, solved: bool) -> void:
	inner_clock_step_changed.emit(current_step, target_step, solved)


func _on_missing_time_progress(matched: int, total: int) -> void:
	missing_time_updated.emit(matched, total)


func _on_missing_time_done() -> void:
	if missing_time_done:
		return
	missing_time_done = true
	missing_time_completed.emit()


func _on_erased_progress(collected: int, total: int) -> void:
	erased_progress_updated.emit(collected, total)


func _on_erased_done() -> void:
	if erased_room_done:
		return
	erased_room_done = true
	erased_room_completed.emit()


func _on_pendulum_progress(step_index: int, total_steps: int) -> void:
	pendulum_progress_updated.emit(step_index, total_steps)


func _on_pendulum_done() -> void:
	if pendulum_done:
		return
	pendulum_done = true
	pendulum_completed.emit()


func _on_portal_entered() -> void:
	if not pendulum_done:
		_on_pendulum_done()
	chapter_completed.emit()


static func find_world_manager(from: Node) -> Node:
	if from == null or from.get_tree() == null:
		return null
	var cur := from.get_parent()
	while cur:
		if cur.has_signal("dimension_shifted"):
			return cur
		cur = cur.get_parent()
	var root := from.get_tree().current_scene
	if root and root.has_signal("dimension_shifted"):
		return root
	return null


static func find_player(from: Node) -> CharacterBody3D:
	if from == null or from.get_tree() == null:
		return null
	var cur := from.get_tree().current_scene
	if cur:
		var p := cur.find_child("Player", true, false) as CharacterBody3D
		if p:
			return p
	return from.get_tree().root.find_child("Player", true, false) as CharacterBody3D


static func create_prompt_label(parent: Node3D, local_pos: Vector3, color: Color = Color(1.0, 0.94, 0.78, 1.0), font_size: int = 34) -> Label3D:
	var lbl := Label3D.new()
	lbl.name = "InteractionPrompt"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 12
	lbl.outline_render_priority = 11
	lbl.font_size = font_size
	lbl.outline_size = 8
	lbl.pixel_size = 0.0085
	lbl.modulate = color
	lbl.outline_modulate = Color(0.04, 0.04, 0.06, 0.95)
	lbl.position = local_pos
	lbl.visible = false
	parent.add_child(lbl)
	return lbl


static func is_player_busy(player: CharacterBody3D) -> bool:
	if player == null:
		return false
	if "item_dipegang" in player and player.get("item_dipegang") != null:
		return true
	if "objek_ditarik" in player and player.get("objek_ditarik") != null:
		return true
	if "input_enabled" in player and not bool(player.get("input_enabled")):
		return true
	return false


static func is_interact_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		return key_ev.pressed and not key_ev.echo and key_ev.physical_keycode == KEY_E
	return false


## Memasang aset jam kuning beranimasi (clock_loop_animation.glb), memisahkan track
## jarum jam/menit agar animasi cincin jam tetap hidup sementara jarum bisa diarahkan
## ke pukul berapa pun secara presisi.
static func spawn_yellow_clock(parent: Node3D, scale_val: float = 1.0, play_ring_anim: bool = true) -> Dictionary:
	var res := load("res://assets/chap 2/clock_loop_animation.glb") as PackedScene
	if res == null:
		return {}
	var inst := res.instantiate() as Node3D
	inst.name = "YellowAnimatedClock"
	inst.scale = Vector3(scale_val, scale_val, scale_val)
	parent.add_child(inst)

	var hour_node := inst.find_child("hour_3", true, false) as Node3D
	var minute_node := inst.find_child("minute_1", true, false) as Node3D
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		if play_ring_anim and not Engine.is_editor_hint() and ap.has_animation("Animation"):
			var src_anim := ap.get_animation("Animation")
			var custom_anim := src_anim.duplicate(true) as Animation
			# Hapus track rotasi hour_3 & minute_1 agar kita bisa kendalikan posisi jam puzzle
			for ti in range(custom_anim.get_track_count() - 1, -1, -1):
				var tpath := String(custom_anim.track_get_path(ti))
				if "hour_3" in tpath or "minute_1" in tpath:
					custom_anim.remove_track(ti)
			custom_anim.loop_mode = Animation.LOOP_LINEAR
			var lib := AnimationLibrary.new()
			lib.add_animation("ring_loop", custom_anim)
			ap.add_animation_library("puzzle_clock", lib)
			ap.play("puzzle_clock/ring_loop")
			ap.speed_scale = 0.85
		else:
			ap.stop()

	return {
		"root": inst,
		"hour": hour_node,
		"minute": minute_node,
		"anim": ap,
	}


static func set_yellow_clock_hour(host: Node, clock_rig: Dictionary, hour: int, duration: float = 0.35, spin_minute: bool = true) -> void:
	var h_node: Node3D = clock_rig.get("hour", null)
	var m_node: Node3D = clock_rig.get("minute", null)
	if h_node == null:
		return
	# hour_3 pada rest pose menunjuk +X (pukul 3); +90 deg menunjuk +Y (pukul 12)
	var target_h_deg := 90.0 - float(hour % 12) * 30.0
	if duration <= 0.0:
		h_node.rotation_degrees = Vector3(0.0, 0.0, target_h_deg)
		if m_node:
			m_node.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		return

	# Ambil delta sudut terpendek searah jarum jam agar putaran tampak natural
	var cur_z := h_node.rotation_degrees.z
	var diff := fmod(target_h_deg - cur_z, 360.0)
	if diff > 0.0:
		diff -= 360.0
	if absf(diff) < 1.0:
		diff = -360.0
	var tw := host.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(h_node, "rotation_degrees:z", cur_z + diff, duration)
	if m_node and spin_minute:
		tw.tween_property(m_node, "rotation_degrees:z", m_node.rotation_degrees.z - 360.0, duration)


static func set_player_cutscene_lock(player: CharacterBody3D, locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if locked:
		player.velocity = Vector3.ZERO
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not locked)
	player.set_physics_process(not locked)
	player.set_process_unhandled_input(not locked)


static func play_door_open_cutscene(
	host: Node,
	door: Node3D,
	cam_start: Vector3,
	cam_end: Vector3,
	look_target: Vector3,
	pre_delay: float = 0.65,
	open_dur: float = 1.35,
	hold_after_open: float = 1.65,
	on_pre_delay_done: Callable = Callable(),
	on_after_door_open: Callable = Callable()
) -> void:
	if door == null or host == null or not host.is_inside_tree():
		return
	var tree := host.get_tree()
	var viewport := host.get_viewport()
	var prev_cam := viewport.get_camera_3d() if viewport else null
	if DisplayServer.get_name() == "headless" or viewport == null or prev_cam == null or tree == null:
		if on_pre_delay_done.is_valid():
			on_pre_delay_done.call()
		if door.has_method("unlock_and_open"):
			door.call("unlock_and_open")
		if on_after_door_open.is_valid():
			on_after_door_open.call(null, null)
		return

	var player := find_player(host)
	var scene_root := tree.current_scene
	var rig := scene_root.find_child("CameraRig", true, false) as Node3D if scene_root else null
	if rig and "camera" in rig and rig.get("camera") is Camera3D:
		prev_cam = rig.get("camera") as Camera3D

	var paused_enemies: Array[Node] = []
	for enemy in tree.get_nodes_in_group("eraser_ai"):
		if is_instance_valid(enemy) and enemy.is_physics_processing():
			enemy.set_physics_process(false)
			paused_enemies.append(enemy)

	set_player_cutscene_lock(player, true)
	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", true)

	if pre_delay > 0.0:
		await tree.create_timer(pre_delay).timeout
		if not host.is_inside_tree():
			return

	if on_pre_delay_done.is_valid():
		on_pre_delay_done.call()

	var cut_cam := Camera3D.new()
	cut_cam.name = "DoorRevealCutsceneCam"
	cut_cam.fov = 44.0
	host.add_child(cut_cam)
	cut_cam.global_position = cam_start
	cut_cam.look_at(look_target, Vector3.UP)
	cut_cam.current = true

	var reveal_light := OmniLight3D.new()
	reveal_light.light_color = Color(1.0, 0.86, 0.62)
	reveal_light.light_energy = 0.0
	reveal_light.omni_range = 10.0
	host.add_child(reveal_light)
	var light_dir := (cam_start - look_target)
	light_dir.y = 0.0
	light_dir = light_dir.normalized() if light_dir.length_squared() > 0.001 else Vector3.RIGHT
	reveal_light.global_position = look_target + light_dir * 2.0 + Vector3(0.0, 0.85, 0.0)

	var dolly_dur := maxf(open_dur + 0.55, 1.9)
	var cam_tw := host.create_tween().set_parallel(true)
	cam_tw.tween_method(func(t: float) -> void:
		if is_instance_valid(cut_cam):
			cut_cam.global_position = cam_start.lerp(cam_end, t)
			cut_cam.look_at(look_target, Vector3.UP)
	, 0.0, 1.0, dolly_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(reveal_light, "light_energy", 2.2, 0.45).set_trans(Tween.TRANS_SINE)

	await tree.create_timer(0.32).timeout
	if not host.is_inside_tree():
		return

	if is_instance_valid(door):
		if "open_duration" in door:
			door.set("open_duration", open_dur)
		if "durasi_animasi" in door:
			door.set("durasi_animasi", open_dur)
		if door.has_method("unlock_and_open"):
			door.call("unlock_and_open")

	await tree.create_timer(hold_after_open).timeout
	if not host.is_inside_tree():
		return

	if on_after_door_open.is_valid():
		await on_after_door_open.call(cut_cam, reveal_light)
		if not host.is_inside_tree():
			return

	if is_instance_valid(reveal_light):
		var fade_l := host.create_tween()
		fade_l.tween_property(reveal_light, "light_energy", 0.0, 0.25)
		await fade_l.finished

	if is_instance_valid(prev_cam):
		prev_cam.current = true
	elif rig and "camera" in rig and rig.get("camera") is Camera3D:
		(rig.get("camera") as Camera3D).current = true

	if is_instance_valid(cut_cam):
		cut_cam.queue_free()
	if is_instance_valid(reveal_light):
		reveal_light.queue_free()

	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", false)
	set_player_cutscene_lock(player, false)
	for enemy in paused_enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(true)
