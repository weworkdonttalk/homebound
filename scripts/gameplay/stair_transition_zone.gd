class_name StairTransitionZone
extends Area3D

## ============================================================================
## StairTransitionZone — Transisi Cutscene Tangga Lantai 1 <-> Lantai 2
## Menggantikan panjat tangga manual agar kamera tidak pernah menembus
## pelat lantai Lantai 2, lengkap dengan fade hitam singkat & snap kamera.
## ============================================================================

@export var to_upper_floor: bool = true
@export var target_spawn_pos: Vector3 = Vector3(74.65, 6.32, -7.8)
@export var target_yaw_degrees: float = 0.0
@export var camera_pan_offset: Vector3 = Vector3(0.0, 2.2, -1.8)
@export var cooldown_seconds: float = 1.6
@export var is_locked: bool = false
@export var locked_hint: String = "Tangga terkunci — Susun angka jam terlebih dahulu"

static var _last_transition_time_sec: float = -10.0
static var _transition_active: bool = false

var _lock_label: Label3D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_lock_label()


func _setup_lock_label() -> void:
	if not is_locked:
		return
	_lock_label = Label3D.new()
	_lock_label.name = "StairLockLabel"
	_lock_label.text = locked_hint
	_lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lock_label.no_depth_test = true
	_lock_label.font_size = 34
	_lock_label.outline_size = 8
	_lock_label.modulate = Color(1.0, 0.55, 0.45, 1.0)
	_lock_label.outline_modulate = Color(0.05, 0.04, 0.05, 0.95)
	_lock_label.position = Vector3(0.0, 1.3, 0.0)
	_lock_label.visible = false
	add_child(_lock_label)


func unlock() -> void:
	is_locked = false
	if is_instance_valid(_lock_label):
		_lock_label.visible = false


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" and is_instance_valid(_lock_label):
		_lock_label.visible = false


func _on_body_entered(body: Node3D) -> void:
	if _transition_active:
		return
	if body.name != "Player" and not (body is CharacterBody3D):
		return
	if is_locked:
		if is_instance_valid(_lock_label):
			_lock_label.visible = true
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_transition_time_sec < cooldown_seconds:
		return

	_run_cutscene(body as CharacterBody3D)


func _run_cutscene(player: CharacterBody3D) -> void:
	_transition_active = true
	_last_transition_time_sec = Time.get_ticks_msec() * 0.001

	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", false)

	var scene_root := get_tree().current_scene
	var rig := get_node_or_null("../CameraRig") as Node3D
	if rig == null and scene_root:
		rig = scene_root.find_child("CameraRig", true, false) as Node3D

	var fade_rect: ColorRect = null
	var fade_layer := get_node_or_null("../FadeCanvasLayer")
	if fade_layer == null and scene_root:
		fade_layer = scene_root.find_child("FadeCanvasLayer", true, false)
	if fade_layer:
		fade_rect = fade_layer.get_node_or_null("ColorRect") as ColorRect

	# Fase 1: kamera mencondong halus mengarah ke tangga + fade hitam lembut
	if rig:
		var pan_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pan_tw.tween_property(rig, "global_position", rig.global_position + camera_pan_offset, 0.34)

	if fade_rect:
		fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
		var tw_out := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_out.tween_property(fade_rect, "modulate:a", 1.0, 0.34)
		await tw_out.finished
	else:
		await get_tree().create_timer(0.34).timeout

	if not is_inside_tree() or not is_instance_valid(player):
		_transition_active = false
		return

	# Fase 2: pindahkan pemain & update batas ketinggian kamera sesuai lantai baru
	player.velocity = Vector3.ZERO
	player.global_position = target_spawn_pos
	var body_node := player.get_node_or_null("body") as Node3D
	var vis_node := player.get("visual_node") as Node3D
	var yaw_rad := deg_to_rad(target_yaw_degrees)
	if body_node:
		body_node.rotation.y = yaw_rad
	if vis_node:
		vis_node.global_position = target_spawn_pos
		vis_node.rotation.y = yaw_rad

	if rig:
		if rig.has_method("set_upper_floor"):
			rig.call("set_upper_floor", to_upper_floor)
		if rig.has_method("snap_to_room"):
			rig.call("snap_to_room", target_spawn_pos)

	await get_tree().create_timer(0.14).timeout
	if not is_inside_tree():
		_transition_active = false
		return

	# Fase 3: fade in bersih & pulihkan kontrol
	if fade_rect:
		var tw_in := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(fade_rect, "modulate:a", 0.0, 0.36)
		await tw_in.finished

	if is_instance_valid(player) and player.has_method("set_input_enabled"):
		player.call("set_input_enabled", true)

	_last_transition_time_sec = Time.get_ticks_msec() * 0.001
	_transition_active = false
