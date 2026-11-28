extends Area3D
class_name MonsterRevealCutscene

## MonsterRevealCutscene — Cutscene one-shot perkenalan TheEraser di Chapter 2 (~2.8 detik).
## Mengunci kontrol player, memunculkan letterbox sinematik, melakukan tween kamera menuju
## CutsceneCamTarget (low-angle ke tubuh/wajah TheEraser), memicu efek kilatan horor
## & reaksi monster, lalu mengembalikan kamera ke CameraRig dan memulai state CHASE.

signal reveal_started
signal reveal_finished

@export var eraser_path: NodePath = NodePath("../ruangan2/Lantai/TheEraser")
@export var cam_target_path: NodePath = NodePath("../CutsceneCamTarget")
@export var camera_rig_path: NodePath = NodePath("../CameraRig")
@export var stinger_audio: AudioStream = null

@export_group("Cutscene Timing & Framing")
@export var camera_in_duration: float = 0.6
@export var hold_duration: float = 1.7
@export var camera_out_duration: float = 0.5
@export var cutscene_fov: float = 38.0
@export var letterbox_height: float = 84.0
@export var monster_focus_height: float = 3.5

var has_triggered: bool = false

var _the_eraser: Node3D = null
var _cam_target: Marker3D = null
var _camera_rig: Node3D = null
var _letterbox_layer: CanvasLayer = null
var _top_bar: ColorRect = null
var _bottom_bar: ColorRect = null
var _flash_rect: ColorRect = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	_resolve_nodes()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _resolve_nodes() -> void:
	var scene_root := get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
	if not eraser_path.is_empty():
		_the_eraser = get_node_or_null(eraser_path) as Node3D
	if _the_eraser == null and scene_root:
		_the_eraser = scene_root.find_child("TheEraser", true, false) as Node3D

	if not cam_target_path.is_empty():
		_cam_target = get_node_or_null(cam_target_path) as Marker3D
	if _cam_target == null and scene_root:
		_cam_target = scene_root.find_child("CutsceneCamTarget", true, false) as Marker3D

	if not camera_rig_path.is_empty():
		_camera_rig = get_node_or_null(camera_rig_path) as Node3D
	if _camera_rig == null and scene_root:
		_camera_rig = scene_root.find_child("CameraRig", true, false) as Node3D


func _on_body_entered(body: Node3D) -> void:
	if has_triggered:
		return
	if not (body is CharacterBody3D) or (body.name != "Player" and not body.is_in_group("player")):
		return
	trigger_reveal(body as CharacterBody3D)


## Memicu cutscene reveal secara manual atau lewat Area3D (one-shot).
func trigger_reveal(player: CharacterBody3D) -> void:
	if has_triggered:
		return
	has_triggered = true
	set_deferred("monitoring", false)
	_resolve_nodes()
	reveal_started.emit()
	_run_reveal_sequence(player)


func _run_reveal_sequence(player: CharacterBody3D) -> void:
	_set_player_locked(player, true)

	if _the_eraser and _the_eraser.has_method("enter_cutscene_mode") and player:
		_the_eraser.call("enter_cutscene_mode", player.global_position)

	var viewport := get_viewport() if is_inside_tree() else null
	var prev_cam: Camera3D = null
	if _camera_rig and "camera" in _camera_rig and _camera_rig.get("camera") is Camera3D:
		prev_cam = _camera_rig.get("camera") as Camera3D
	elif viewport:
		prev_cam = viewport.get_camera_3d()

	if _camera_rig and "_is_focusing" in _camera_rig:
		_camera_rig.set("_is_focusing", true)

	if prev_cam == null:
		await get_tree().create_timer(camera_in_duration + hold_duration + camera_out_duration).timeout
		_finish_cutscene(player, null, 46.0)
		return

	var prev_fov: float = prev_cam.fov
	var start_xform: Transform3D = prev_cam.global_transform
	var dest_xform: Transform3D = _compute_cutscene_camera_transform(start_xform)

	var cut_cam := Camera3D.new()
	cut_cam.name = "MonsterRevealCutsceneCam"
	cut_cam.global_transform = start_xform
	cut_cam.fov = prev_fov
	add_child(cut_cam)
	cut_cam.current = true

	_create_letterbox_ui()
	_animate_letterbox(true, camera_in_duration * 0.75)
	_play_stinger_audio()

	# 1. Interpolasi halus dari kamera gameplay ke CutsceneCamTarget (low-angle ke TheEraser)
	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_method(func(t: float) -> void:
		if is_instance_valid(cut_cam):
			cut_cam.global_transform = start_xform.interpolate_with(dest_xform, t)
	, 0.0, 1.0, camera_in_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(cut_cam, "fov", cutscene_fov, camera_in_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if not is_inside_tree():
		return

	# 2. Puncak reveal: kilatan vignette/shader horor + micro-shake
	_trigger_horror_flash()
	_shake_cutscene_camera(cut_cam, dest_xform, hold_duration)

	await get_tree().create_timer(hold_duration).timeout
	if not is_inside_tree():
		return

	# 3. Kembalikan kamera secara mulus ke CameraRig gameplay & hilangkan letterbox
	_animate_letterbox(false, camera_out_duration)
	var return_start: Transform3D = cut_cam.global_transform if is_instance_valid(cut_cam) else dest_xform
	var return_target: Transform3D = prev_cam.global_transform if is_instance_valid(prev_cam) else start_xform

	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_method(func(t: float) -> void:
		if is_instance_valid(cut_cam):
			var live_target := prev_cam.global_transform if is_instance_valid(prev_cam) else return_target
			cut_cam.global_transform = return_start.interpolate_with(live_target, t)
	, 0.0, 1.0, camera_out_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_out.tween_property(cut_cam, "fov", prev_fov, camera_out_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw_out.finished
	if not is_inside_tree():
		return

	_finish_cutscene(player, cut_cam, prev_fov)


func _compute_cutscene_camera_transform(fallback_xform: Transform3D) -> Transform3D:
	var cam_pos := _cam_target.global_position if _cam_target else fallback_xform.origin
	if _the_eraser == null:
		return Transform3D(_cam_target.global_transform.basis, cam_pos) if _cam_target else fallback_xform

	var focus_pt := _the_eraser.global_position + Vector3(0.0, monster_focus_height, 0.0)
	var flat_dist := Vector2(cam_pos.x - _the_eraser.global_position.x, cam_pos.z - _the_eraser.global_position.z).length()
	if flat_dist < 3.4:
		var fwd := _the_eraser.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3(0.0, 0.0, 1.0)
		cam_pos = _the_eraser.global_position + fwd * 4.8 + Vector3(0.0, 1.05, 0.0)

	var basis := Transform3D(Basis.IDENTITY, cam_pos).looking_at(focus_pt, Vector3.UP).basis.orthonormalized()
	return Transform3D(basis, cam_pos)


func _shake_cutscene_camera(cut_cam: Camera3D, base_xform: Transform3D, dur: float) -> void:
	if not is_instance_valid(cut_cam):
		return
	var tw := create_tween()
	var steps := 10
	var step_dur := minf(dur * 0.45, 0.75) / float(steps)
	for i in range(steps):
		var damp := 1.0 - float(i) / float(steps)
		var amp := 0.065 * damp
		var off := Vector3(randf_range(-amp, amp), randf_range(-amp * 0.6, amp * 0.6), 0.0)
		tw.tween_property(cut_cam, "global_position", base_xform.origin + off, step_dur)
	tw.tween_property(cut_cam, "global_position", base_xform.origin, step_dur)


func _create_letterbox_ui() -> void:
	if _letterbox_layer != null and is_instance_valid(_letterbox_layer):
		return
	_letterbox_layer = CanvasLayer.new()
	_letterbox_layer.name = "CutsceneLetterboxLayer"
	_letterbox_layer.layer = 40
	add_child(_letterbox_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "RevealFlashRect"
	_flash_rect.anchors_preset = Control.PRESET_FULL_RECT
	_flash_rect.color = Color(0.75, 0.85, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letterbox_layer.add_child(_flash_rect)

	_top_bar = ColorRect.new()
	_top_bar.name = "TopLetterbox"
	_top_bar.color = Color(0.0, 0.0, 0.0, 1.0)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_top = -letterbox_height
	_top_bar.offset_bottom = 0.0
	_letterbox_layer.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.name = "BottomLetterbox"
	_bottom_bar.color = Color(0.0, 0.0, 0.0, 1.0)
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_top = 0.0
	_bottom_bar.offset_bottom = letterbox_height
	_letterbox_layer.add_child(_bottom_bar)


func _animate_letterbox(show_bars: bool, dur: float) -> void:
	if _top_bar == null or _bottom_bar == null:
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if show_bars:
		tw.tween_property(_top_bar, "offset_top", 0.0, dur)
		tw.tween_property(_top_bar, "offset_bottom", letterbox_height, dur)
		tw.tween_property(_bottom_bar, "offset_top", -letterbox_height, dur)
		tw.tween_property(_bottom_bar, "offset_bottom", 0.0, dur)
	else:
		tw.tween_property(_top_bar, "offset_top", -letterbox_height, dur)
		tw.tween_property(_top_bar, "offset_bottom", 0.0, dur)
		tw.tween_property(_bottom_bar, "offset_top", 0.0, dur)
		tw.tween_property(_bottom_bar, "offset_bottom", letterbox_height, dur)


func _trigger_horror_flash() -> void:
	if _flash_rect:
		_flash_rect.color = Color(0.72, 0.86, 1.0, 0.28)
		var f_tw := create_tween()
		f_tw.tween_property(_flash_rect, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var scene_root := get_tree().current_scene if get_tree() else null
	if scene_root == null:
		return

	var post_rect := scene_root.find_child("HorrorPostRect", true, false) as ColorRect
	if post_rect and post_rect.material is ShaderMaterial:
		var sm := post_rect.material as ShaderMaterial
		var orig_grain: float = float(sm.get_shader_parameter("grain_amount"))
		sm.set_shader_parameter("grain_amount", 0.14)
		var g_tw := create_tween()
		g_tw.tween_method(func(v: float) -> void:
			if is_instance_valid(sm):
				sm.set_shader_parameter("grain_amount", v)
		, 0.14, orig_grain, 0.9)

	var vig_rect := scene_root.find_child("VignetteRect", true, false)
	if vig_rect and "vignette_opacity" in vig_rect:
		var orig_op: float = float(vig_rect.get("vignette_opacity"))
		vig_rect.set("vignette_opacity", 0.92)
		var v_tw := create_tween()
		v_tw.tween_property(vig_rect, "vignette_opacity", orig_op, 0.8)


func _play_stinger_audio() -> void:
	if stinger_audio == null:
		return
	var asp := AudioStreamPlayer.new()
	asp.stream = stinger_audio
	asp.volume_db = -2.0
	add_child(asp)
	asp.finished.connect(func() -> void:
		if is_instance_valid(asp):
			asp.queue_free()
	)
	asp.play()


func _finish_cutscene(player: CharacterBody3D, cut_cam: Camera3D, prev_fov: float) -> void:
	if _camera_rig:
		var rig_cam := _camera_rig.get("camera") as Camera3D if "camera" in _camera_rig else null
		if rig_cam:
			rig_cam.fov = prev_fov
			rig_cam.current = true
		if "_is_focusing" in _camera_rig:
			_camera_rig.set("_is_focusing", false)

	if is_instance_valid(cut_cam):
		cut_cam.queue_free()
	if is_instance_valid(_letterbox_layer):
		_letterbox_layer.queue_free()
		_letterbox_layer = null
		_top_bar = null
		_bottom_bar = null
		_flash_rect = null

	_set_player_locked(player, false)

	if _the_eraser and _the_eraser.has_method("exit_cutscene_mode"):
		_the_eraser.call("exit_cutscene_mode", true)

	reveal_finished.emit()


func _set_player_locked(player: CharacterBody3D, locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if locked:
		player.velocity = Vector3.ZERO
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not locked)
	player.set_physics_process(not locked)
	player.set_process_unhandled_input(not locked)
