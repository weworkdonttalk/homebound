@tool
class_name TwoClocksPuzzle
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")
const DialStationScript := preload("res://scripts/gameplay/clock_dial_station.gd")

## Puzzle 1: The Two Clocks (Zona 1 — Hall Masuk)
## Sinkronkan Jam Remembered (awal 03:00) dan Jam Forgotten (awal 09:00) ke pukul 12:00.
## Setiap jam yang selaras menggerakkan mekanisme tautan di depan pintu2 hingga pintu terbuka.

signal progress_updated(synced_count: int, total_count: int)
signal puzzle_completed

@export var door_node_path: NodePath = NodePath("../pintu2")

var is_solved: bool = false

var _clock_rem: DialStationScript = null
var _clock_forg: DialStationScript = null


func _ready() -> void:
	_setup_puzzle_nodes()
	if Engine.is_editor_hint():
		return
	_lock_exit_door()
	_emit_progress()


func _setup_puzzle_nodes() -> void:
	# Gunakan node yang sudah ada di scene jika sudah dipasang di Godot Editor
	_clock_rem = get_node_or_null("ClockStationRemembered") as DialStationScript
	if _clock_rem == null:
		_clock_rem = DialStationScript.new()
		_clock_rem.name = "ClockStationRemembered"
		_clock_rem.active_dimension = "Remembered"
		_clock_rem.start_hour = 3
		_clock_rem.target_hour = 12
		_clock_rem.position = Vector3(31.2, 0.0, 1.05)
		add_child(_clock_rem)
	if not Engine.is_editor_hint() and not _clock_rem.hour_changed.is_connected(_on_clock_hour_changed):
		_clock_rem.hour_changed.connect(_on_clock_hour_changed)

	_clock_forg = get_node_or_null("ClockStationForgotten") as DialStationScript
	if _clock_forg == null:
		_clock_forg = DialStationScript.new()
		_clock_forg.name = "ClockStationForgotten"
		_clock_forg.active_dimension = "Forgotten"
		_clock_forg.start_hour = 9
		_clock_forg.target_hour = 12
		_clock_forg.position = Vector3(39.8, 0.0, 1.05)
		add_child(_clock_forg)
	if not Engine.is_editor_hint() and not _clock_forg.hour_changed.is_connected(_on_clock_hour_changed):
		_clock_forg.hour_changed.connect(_on_clock_hour_changed)


func _lock_exit_door() -> void:
	var door := get_node_or_null(door_node_path)
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("pintu2", true, false)
	if door:
		door.set("is_locked", true)
		door.set("locked_hint", "[E] Terkunci")


func _on_clock_hour_changed(_station: Node3D, _hour: int, _synced: bool) -> void:
	if is_solved:
		return
	_update_visual_links()
	_emit_progress()


func _update_visual_links() -> void:
	var rem_ok := _clock_rem != null and _clock_rem.is_synced()
	var forg_ok := _clock_forg != null and _clock_forg.is_synced()
	if rem_ok and forg_ok:
		_solve()


func _emit_progress() -> void:
	var count := 0
	if _clock_rem and _clock_rem.is_synced():
		count += 1
	if _clock_forg and _clock_forg.is_synced():
		count += 1
	progress_updated.emit(count, 2)


func _solve() -> void:
	if is_solved:
		return
	is_solved = true
	if _clock_rem:
		_clock_rem.lock_synced()
	if _clock_forg:
		_clock_forg.lock_synced()

	var door := get_node_or_null(door_node_path) as Node3D
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("pintu2", true, false) as Node3D
	if door:
		door.set("is_locked", false)

	puzzle_completed.emit()
	_play_door_open_cutscene(door)


func _play_door_open_cutscene(door: Node3D) -> void:
	if door == null:
		return
	var viewport := get_viewport() if is_inside_tree() else null
	var prev_cam := viewport.get_camera_3d() if viewport else null
	if DisplayServer.get_name() == "headless" or viewport == null or prev_cam == null:
		if door.has_method("unlock_and_open"):
			door.call("unlock_and_open")
		return

	var player := Ch2Utils.find_player(self)
	var scene_root := get_tree().current_scene if get_tree() else null
	var rig := scene_root.find_child("CameraRig", true, false) as Node3D if scene_root else null

	_set_player_cutscene_lock(player, true)
	if rig and "_is_focusing" in rig:
		rig.set("_is_focusing", true)

	var door_center := Vector3(45.02, 1.85, 6.42)
	if "_door_center_world" in door:
		var dc: Variant = door.get("_door_center_world")
		if dc is Vector3 and dc != Vector3.ZERO:
			door_center = dc
	var look_target := door_center + Vector3(0.0, 0.25, 0.0)

	# Jeda singkat setelah jam ke-2 mencapai 12:00 sebelum kamera mengarah ke pintu
	await get_tree().create_timer(0.28).timeout
	if not is_inside_tree():
		return

	var cut_cam := Camera3D.new()
	cut_cam.name = "TwoClocksDoorCutsceneCam"
	cut_cam.fov = 44.0
	add_child(cut_cam)
	var cam_start := door_center + Vector3(-6.8, 0.95, 1.45)
	var cam_end := door_center + Vector3(-4.5, 0.65, 0.65)
	cut_cam.global_position = cam_start
	cut_cam.look_at(look_target, Vector3.UP)
	cut_cam.current = true

	var reveal_light := OmniLight3D.new()
	reveal_light.light_color = Color(1.0, 0.86, 0.62)
	reveal_light.light_energy = 0.0
	reveal_light.omni_range = 9.0
	add_child(reveal_light)
	reveal_light.global_position = door_center + Vector3(-1.4, 0.85, 0.0)

	var cam_tw := create_tween().set_parallel(true)
	cam_tw.tween_method(func(t: float) -> void:
		if is_instance_valid(cut_cam):
			cut_cam.global_position = cam_start.lerp(cam_end, t)
			cut_cam.look_at(look_target, Vector3.UP)
	, 0.0, 1.0, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(reveal_light, "light_energy", 2.2, 0.5).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return

	if is_instance_valid(door):
		door.set("open_duration", 1.25)
		if door.has_method("unlock_and_open"):
			door.call("unlock_and_open")

	# Tunggu pintu berayun terbuka penuh + jeda singkat menyorot lorong terbuka
	await get_tree().create_timer(1.75).timeout
	if not is_inside_tree():
		return

	if is_instance_valid(reveal_light):
		var fade_l := create_tween()
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
	_set_player_cutscene_lock(player, false)


func _set_player_cutscene_lock(player: CharacterBody3D, locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if locked:
		player.velocity = Vector3.ZERO
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not locked)
	player.set_physics_process(not locked)
	player.set_process_unhandled_input(not locked)
