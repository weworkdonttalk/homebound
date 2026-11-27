@tool
class_name ClockDialStation
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Jam besar interaktif untuk Puzzle 1 (The Two Clocks).
## Hanya bisa diputar ([E]) pada dimensi yang cocok ("Remembered" / "Forgotten").
## Menampilkan dial angka bercahaya & jarum jam berputar mulus sesuai jam saat ini.

signal hour_changed(station: Node3D, current_hour: int, is_synced: bool)

@export_enum("Remembered", "Forgotten") var active_dimension: String = "Remembered"
@export var start_hour: int = 3
@export var target_hour: int = 12
@export var hour_step: int = 3
@export var interact_range: float = 3.2
@export var show_visual_clock: bool = true

var current_hour: int = 3
var is_locked_synced: bool = false

var _clock_rig: Dictionary = {}
var _glow_light: OmniLight3D = null
var _prompt_label: Label3D = null
var _status_label: Label3D = null
var _visual_root: Node3D = null
var _world: Node = null
var _player: CharacterBody3D = null
var _active_in_dim: bool = true
var _player_near: bool = false


func _ready() -> void:
	current_hour = start_hour
	_build_clock_rig()
	_apply_hand_rotation(true)
	if Engine.is_editor_hint():
		if _status_label:
			_status_label.visible = true
		if _prompt_label:
			_prompt_label.text = "[E] Putar Jam (%s)" % active_dimension
			_prompt_label.visible = true
		return
	_world = Ch2Utils.find_world_manager(self)
	_player = Ch2Utils.find_player(self)
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)
	_apply_hand_rotation(true)


func _build_clock_rig() -> void:
	if get_node_or_null("ClockVisual") != null:
		return
	_visual_root = Node3D.new()
	_visual_root.name = "ClockVisual"
	add_child(_visual_root)

	# Pasang jam kuning beranimasi (clock_loop_animation.glb) menghadap kamera 2.5D (+Z)
	if show_visual_clock:
		var clock_holder := Node3D.new()
		clock_holder.name = "YellowClockHolder"
		clock_holder.position = Vector3(0.0, 2.35, 0.0)
		_visual_root.add_child(clock_holder)
		_clock_rig = Ch2Utils.spawn_yellow_clock(clock_holder, 1.35, true)

	# Lampu penunjuk agar terlihat mencolok di ruangan gelap
	_glow_light = OmniLight3D.new()
	_glow_light.name = "ClockGlow"
	_glow_light.position = Vector3(0.0, 2.35, 1.2)
	_glow_light.light_color = _dim_color()
	_glow_light.light_energy = 2.6
	_glow_light.omni_range = 7.0
	_visual_root.add_child(_glow_light)

	# Label angka jam di atas dial & prompt interaksi
	_status_label = get_node_or_null("StatusLabel") as Label3D
	if _status_label == null:
		_status_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 4.05, 0.35), _dim_color(), 30)
		_status_label.name = "StatusLabel"
	_status_label.visible = true
	_prompt_label = get_node_or_null("InteractionPrompt") as Label3D
	if _prompt_label == null:
		_prompt_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 0.85, 0.9), Color(1.0, 0.94, 0.78, 1.0), 34)
	_update_labels()


func _dim_color() -> Color:
	return Color(0.38, 0.88, 1.0) if active_dimension == "Remembered" else Color(1.0, 0.68, 0.30)


func is_synced() -> bool:
	return current_hour == target_hour


func _on_dimension_shifted(is_in_memory: bool) -> void:
	_active_in_dim = (active_dimension == "Remembered" and is_in_memory) or (active_dimension == "Forgotten" and not is_in_memory)
	if _visual_root:
		_visual_root.visible = _active_in_dim
	if _glow_light:
		_glow_light.visible = _active_in_dim
	if _status_label:
		_status_label.visible = _active_in_dim
	_update_labels()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return
	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var same_floor := absf(_player.global_position.y - global_position.y) < 3.5
	_player_near = same_floor and dist <= interact_range
	if _prompt_label:
		_prompt_label.visible = _player_near
		_update_labels()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_near or is_locked_synced:
		return
	if Ch2Utils.is_player_busy(_player):
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	if not _active_in_dim:
		return
	get_viewport().set_input_as_handled()
	advance_hour()


func advance_hour() -> void:
	current_hour = ((current_hour - 1 + hour_step) % 12) + 1
	_apply_hand_rotation(false)
	_update_labels()
	hour_changed.emit(self, current_hour, is_synced())


func lock_synced() -> void:
	is_locked_synced = true
	if _glow_light:
		_glow_light.light_color = Color(0.5, 1.0, 0.7)
		_glow_light.light_energy = 3.2
	_update_labels()


func _apply_hand_rotation(immediate: bool) -> void:
	Ch2Utils.set_yellow_clock_hour(self, _clock_rig, current_hour, 0.0 if immediate else 0.35, true)


func _update_labels() -> void:
	var time_str := "%02d:00" % current_hour
	var target_str := "%02d:00" % target_hour
	if _status_label:
		if is_locked_synced:
			_status_label.text = "%s ✓" % time_str
			_status_label.modulate = Color(0.5, 1.0, 0.7)
		else:
			_status_label.text = "%s (Target %s)" % [time_str, target_str]
			_status_label.modulate = _dim_color()
	if _prompt_label:
		if is_locked_synced:
			_prompt_label.text = "Jam Tersinkron (%s)" % time_str
		elif not _active_in_dim:
			_prompt_label.text = "[T] Ubah ke Dimensi %s" % active_dimension
		elif is_synced():
			_prompt_label.text = "[E] Putar (%s ✓ — Sinkronkan jam satunya!)" % time_str
		else:
			_prompt_label.text = "[E] Putar Jarum Jam (%s → %s)" % [time_str, target_str]
