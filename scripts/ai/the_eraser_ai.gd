@tool
class_name TheEraserAI
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## AI The Eraser untuk Puzzle 3 (The Erased Room, Lantai 2).
## Arsitektur FSM bersih (game-ai): DORMANT -> STALKING -> HUNTING -> SEARCHING -> VANISHED.
## Memberi peringatan ketegangan sebelum mengejar, menghindari jatuh dari lantai 2,
## dan berhenti mengejar bila pemain bersembunyi di lemari atau keluar zona aman.

signal state_changed(new_state: int)
signal exposure_changed(ratio: float)
signal player_caught

enum State { DORMANT, STALKING, HUNTING, SEARCHING, VANISHED }

@export var spawn_anchor: Vector3 = Vector3(74.0, 6.3, 2.0)
@export var safe_respawn_pos: Vector3 = Vector3(74.65, 6.32, -7.8)
@export var hunt_speed: float = 2.05
@export var search_speed: float = 1.45
@export var catch_distance: float = 1.25
@export var exposure_fill_seconds: float = 6.5

var current_state: int = State.DORMANT
var exposure: float = 0.0
var is_player_hidden: bool = false

var _model: Node3D = null
var _aura_light: OmniLight3D = null
var _status_label: Label3D = null
var _player: CharacterBody3D = null
var _last_known_pos: Vector3 = Vector3.ZERO
var _search_timer: float = 0.0
var _grace_timer: float = 0.0
var _catch_cooldown: float = 0.0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _warned_once: bool = false


func _ready() -> void:
	_build_visuals()
	if Engine.is_editor_hint():
		visible = true
		if position == Vector3.ZERO:
			position = Vector3(64.0, 6.32, 2.0)
		if _status_label:
			_status_label.text = "THE ERASER (AI Patrol)"
			_status_label.visible = true
		return
	_player = Ch2Utils.find_player(self)
	_enter_state(State.DORMANT)


func _build_visuals() -> void:
	if get_node_or_null("EraserMesh") != null:
		return
	var res := load("res://assets/characters/enemies/slender_figure.glb") as PackedScene
	if res:
		_model = res.instantiate() as Node3D
		_model.name = "EraserMesh"
		_model.scale = Vector3(2.05, 2.05, 2.05)
		add_child(_model)
	else:
		var cap := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.35
		cm.height = 2.4
		cap.mesh = cm
		cap.position.y = 1.2
		add_child(cap)
		_model = cap

	_aura_light = OmniLight3D.new()
	_aura_light.position = Vector3(0.0, 1.9, 0.0)
	_aura_light.light_color = Color(1.0, 0.22, 0.18)
	_aura_light.light_energy = 2.8
	_aura_light.omni_range = 6.5
	add_child(_aura_light)

	_status_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 2.8, 0.0), Color(1.0, 0.35, 0.3), 30)


func set_player_hidden(hidden: bool) -> void:
	is_player_hidden = hidden
	if hidden and current_state == State.HUNTING:
		_enter_state(State.SEARCHING)


func vanish() -> void:
	_enter_state(State.VANISHED)


func _enter_state(next_state: int) -> void:
	current_state = next_state
	match next_state:
		State.DORMANT:
			visible = false
			exposure = 0.0
			_warned_once = false
		State.STALKING:
			visible = false
			_warned_once = false
		State.HUNTING:
			visible = true
			global_position = _pick_hunt_spawn()
			_last_pos = global_position
			_stuck_timer = 0.0
			_grace_timer = 1.4
			if _status_label:
				_status_label.text = "THE ERASER MENGEJAR!"
				_status_label.visible = true
			_pulse_camera_warning(0.32, 0.22)
		State.SEARCHING:
			visible = true
			_search_timer = 3.2
			if _status_label:
				_status_label.text = "..."
				_status_label.visible = true
		State.VANISHED:
			if visible:
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
				tw.finished.connect(func() -> void:
					visible = false
					scale = Vector3.ONE
				)
			else:
				visible = false
			if _status_label:
				_status_label.visible = false
	state_changed.emit(current_state)


func _pick_hunt_spawn() -> Vector3:
	if _player == null:
		return spawn_anchor
	# Muncul di lorong lantai 2 di sisi berlawanan pintu agar pemain punya ruang kabur ke lemari
	var px := _player.global_position.x
	var spawn_x := 64.0 if px < 59.0 else 49.0
	return Vector3(spawn_x, 6.32, clampf(_player.global_position.z, -6.0, 7.0))


func _player_in_floor2_room() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return _player.global_position.y > 5.0 and _player.global_position.x < 61.5 and _player.global_position.x > 44.5


func _player_on_floor2() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return _player.global_position.y > 5.0 and _player.global_position.x < 93.0 and _player.global_position.x > 44.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or current_state == State.VANISHED:
		return
	if _catch_cooldown > 0.0:
		_catch_cooldown = maxf(_catch_cooldown - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return

	match current_state:
		State.DORMANT:
			if _player_in_floor2_room():
				_enter_state(State.STALKING)

		State.STALKING:
			if _player_in_floor2_room() and not is_player_hidden and _catch_cooldown <= 0.0:
				exposure = minf(exposure + delta / exposure_fill_seconds, 1.0)
				if exposure >= 0.72 and not _warned_once:
					_warned_once = true
					_pulse_camera_warning(0.18, 0.14)
				if exposure >= 1.0:
					_last_known_pos = _player.global_position
					_enter_state(State.HUNTING)
			else:
				exposure = maxf(exposure - delta * 0.45, 0.0)
				if exposure <= 0.0 and not _player_on_floor2():
					_enter_state(State.DORMANT)
			exposure_changed.emit(exposure)

		State.HUNTING:
			if _grace_timer > 0.0:
				_grace_timer = maxf(_grace_timer - delta, 0.0)
			if is_player_hidden or not _player_on_floor2():
				_enter_state(State.SEARCHING)
				return

			_last_known_pos = _player.global_position
			_steer_toward(_last_known_pos, hunt_speed, delta)

			if _grace_timer <= 0.0 and _catch_cooldown <= 0.0:
				var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
				if dist <= catch_distance and absf(_player.global_position.y - global_position.y) < 2.2:
					_catch_player()

		State.SEARCHING:
			if not is_player_hidden and _player_in_floor2_room() and _search_timer < 2.5:
				_enter_state(State.HUNTING)
				return
			_steer_toward(_last_known_pos, search_speed, delta)
			_search_timer -= delta
			if _search_timer <= 0.0:
				exposure = 0.0
				exposure_changed.emit(exposure)
				_enter_state(State.STALKING)


func _steer_toward(target: Vector3, speed: float, delta: float) -> void:
	var to_target := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if to_target.length() > 0.25:
		var dir := to_target.normalized()
		# Cegah menyeberangi pembatas rak di x=57.6 jika tidak lewat pintu z=[-2..5.5]
		var next_pos := global_position + dir * speed * delta
		if (global_position.x > 57.9 and next_pos.x <= 57.9) or (global_position.x < 57.2 and next_pos.x >= 57.2):
			if next_pos.z < -1.4 or next_pos.z > 4.9:
				var doorway := Vector3(57.5, global_position.y, 1.8)
				dir = (doorway - global_position)
				dir.y = 0.0
				dir = dir.normalized()
				next_pos = global_position + dir * speed * delta
		# Jaga tetap aman di pelat Lantai 2
		next_pos.x = clampf(next_pos.x, 47.0, 92.2)
		next_pos.z = clampf(next_pos.z, -8.5, 11.8)
		next_pos.y = 6.32
		global_position = next_pos
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 8.0 * delta)

	# Guard anti-macet
	_stuck_timer += delta
	if _stuck_timer > 2.0:
		if global_position.distance_to(_last_pos) < 0.35:
			global_position.z = clampf(global_position.z + (1.2 if global_position.z < 1.8 else -1.2), -8.0, 11.0)
		_last_pos = global_position
		_stuck_timer = 0.0


func _catch_player() -> void:
	_catch_cooldown = 2.5
	exposure = 0.0
	exposure_changed.emit(0.0)
	_pulse_camera_warning(0.55, 0.30)
	player_caught.emit()

	if _player:
		_player.velocity = Vector3.ZERO
		_player.global_position = safe_respawn_pos
		var vis := _player.get("visual_node") as Node3D
		if vis:
			vis.global_position = safe_respawn_pos
	var rig := get_tree().current_scene.find_child("CameraRig", true, false) if get_tree() and get_tree().current_scene else null
	if rig and rig.has_method("snap_to_room"):
		rig.call("snap_to_room", safe_respawn_pos)

	_enter_state(State.DORMANT)


func _pulse_camera_warning(strength: float, dur: float) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	var rig := scene.find_child("CameraRig", true, false)
	if rig and rig.has_method("trigger_dimension_shake"):
		rig.call("trigger_dimension_shake", strength, dur)
