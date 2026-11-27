@tool
class_name ClosetHideSpot
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Lemari tempat bersembunyi aman dari kejaran The Eraser di Puzzle 3.
## Tekan [E] untuk masuk/keluar bersembunyi.

signal hide_state_changed(is_hiding: bool)

@export var interact_range: float = 3.0
@export var exit_offset: Vector3 = Vector3(1.6, 0.0, 0.0)

var is_player_hiding: bool = false

var _prompt_label: Label3D = null
var _player: CharacterBody3D = null
var _player_near: bool = false
var _saved_player_pos: Vector3 = Vector3.ZERO
var _safe_light: OmniLight3D = null


func _ready() -> void:
	_build_closet()
	if Engine.is_editor_hint():
		if _prompt_label:
			_prompt_label.text = "[E] Sembunyi di Lemari"
			_prompt_label.visible = true
		return
	_player = Ch2Utils.find_player(self)


func _build_closet() -> void:
	if get_node_or_null("ClosetModel") != null or get_node_or_null("ClosetCol") != null:
		return
	var closet_res := load("res://assets/chap 2/old_closet.glb") as PackedScene
	if closet_res:
		var mesh := closet_res.instantiate() as Node3D
		mesh.name = "ClosetModel"
		mesh.rotation_degrees.y = 90.0
		add_child(mesh)

	var body := StaticBody3D.new()
	body.name = "ClosetCol"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 3.6, 2.2)
	cs.shape = bs
	cs.position = Vector3(-0.3, 1.8, 0.0)
	body.add_child(cs)
	add_child(body)

	_safe_light = OmniLight3D.new()
	_safe_light.position = Vector3(1.2, 2.1, 0.0)
	_safe_light.light_color = Color(0.55, 0.92, 0.72)
	_safe_light.light_energy = 1.4
	_safe_light.omni_range = 4.5
	add_child(_safe_light)

	_prompt_label = Ch2Utils.create_prompt_label(self, Vector3(0.8, 2.4, 0.0), Color(0.65, 1.0, 0.78), 32)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return
	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var same_floor := absf(_player.global_position.y - global_position.y) < 3.2
	_player_near = is_player_hiding or (same_floor and dist <= interact_range)
	if _prompt_label:
		_prompt_label.visible = _player_near
		if is_player_hiding:
			_prompt_label.text = "[E] Keluar dari Lemari (Aman)"
		elif _player_near:
			_prompt_label.text = "[E] Sembunyi di Lemari"


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_near:
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	if not is_player_hiding and Ch2Utils.is_player_busy(_player):
		return
	get_viewport().set_input_as_handled()
	set_hiding(not is_player_hiding)


func set_hiding(hiding: bool) -> void:
	if _player == null or is_player_hiding == hiding:
		return
	is_player_hiding = hiding
	var vis := _player.get("visual_node") as Node3D
	if hiding:
		_saved_player_pos = global_position + exit_offset
		_saved_player_pos.y = global_position.y + 0.15
		if _player.has_method("set_input_enabled"):
			_player.call("set_input_enabled", false)
		_player.velocity = Vector3.ZERO
		_player.global_position = global_position + Vector3(-0.1, 0.15, 0.0)
		if vis:
			vis.visible = false
	else:
		_player.global_position = _saved_player_pos
		if vis:
			vis.global_position = _saved_player_pos
			vis.visible = true
		if _player.has_method("set_input_enabled"):
			_player.call("set_input_enabled", true)
	hide_state_changed.emit(is_player_hiding)
