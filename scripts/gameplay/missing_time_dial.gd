class_name MissingTimeDial
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Pedestal mekanisme jam untuk Puzzle 2 (The Missing Time).
## Pemain mengingat angka yang hanya muncul di dimensi Forgotten ([T]),
## lalu mengatur dial ini ke angka Romawi yang tepat di dimensi Remembered ([E]).

signal dial_changed(dial: Node3D, current_value: int, is_matched: bool)

const ROMAN_MAP := {
	1: "I", 2: "II", 3: "III", 4: "IV", 5: "V", 6: "VI",
	7: "VII", 8: "VIII", 9: "IX", 10: "X", 11: "XI", 12: "XII",
}

@export var slot_index: int = 0
@export var target_value: int = 4
@export var options: Array[int] = [2, 4, 6, 9]
@export var interact_range: float = 2.8

var _option_idx: int = 0
var is_locked_solved: bool = false

var _clock_rig: Dictionary = {}
var _value_label: Label3D = null
var _prompt_label: Label3D = null
var _light: OmniLight3D = null
var _in_memory: bool = true
var _player_near: bool = false
var _player: CharacterBody3D = null
var _world: Node = null


func _ready() -> void:
	if options.is_empty():
		options = [1, 4, 8, 11]
	_option_idx = 0
	_world = Ch2Utils.find_world_manager(self)
	_player = Ch2Utils.find_player(self)
	_build_pedestal()
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	_in_memory = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_refresh_visuals()


func _build_pedestal() -> void:
	# Tumpuan batu gelap setinggi pinggang
	var plinth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.85, 1.15, 0.85)
	plinth.mesh = box
	plinth.position = Vector3(0.0, 0.575, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.14, 0.13, 0.16, 1.0)
	pmat.roughness = 0.88
	plinth.material_override = pmat
	add_child(plinth)

	# Collider dasar
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.85, 1.15, 0.85)
	cs.shape = bshape
	cs.position = Vector3(0.0, 0.575, 0.0)
	body.add_child(cs)
	add_child(body)

	# Jam kuning beranimasi di atas pedestal
	var holder := Node3D.new()
	holder.name = "YellowClockHolder"
	holder.position = Vector3(0.0, 1.72, 0.0)
	add_child(holder)
	_clock_rig = Ch2Utils.spawn_yellow_clock(holder, 0.62, true)
	Ch2Utils.set_yellow_clock_hour(self, _clock_rig, get_current_value(), 0.0, false)

	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, 1.9, 0.7)
	_light.light_color = Color(0.45, 0.85, 1.0)
	_light.light_energy = 1.6
	_light.omni_range = 4.5
	add_child(_light)

	_value_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 2.55, 0.0), Color(0.75, 0.94, 1.0), 40)
	_value_label.visible = true
	_prompt_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 3.0, 0.0), Color(1.0, 0.94, 0.78), 30)


func get_current_value() -> int:
	return options[_option_idx]


func is_matched() -> bool:
	return get_current_value() == target_value


func _on_dimension_shifted(is_in_memory: bool) -> void:
	_in_memory = is_in_memory
	_refresh_visuals()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return
	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	_player_near = absf(_player.global_position.y - global_position.y) < 3.2 and dist <= interact_range
	if _prompt_label:
		_prompt_label.visible = _player_near
		_refresh_prompt_text()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or is_locked_solved or not _in_memory:
		return
	if Ch2Utils.is_player_busy(_player):
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	get_viewport().set_input_as_handled()
	cycle_value()


func cycle_value() -> void:
	_option_idx = (_option_idx + 1) % options.size()
	Ch2Utils.set_yellow_clock_hour(self, _clock_rig, get_current_value(), 0.32, true)
	_refresh_visuals()
	dial_changed.emit(self, get_current_value(), is_matched())


func lock_solved() -> void:
	is_locked_solved = true
	_refresh_visuals()


func _refresh_visuals() -> void:
	var val := get_current_value()
	var roman: String = ROMAN_MAP.get(val, str(val))
	if _value_label:
		if is_locked_solved:
			_value_label.text = "%s ✓" % roman
			_value_label.modulate = Color(0.45, 1.0, 0.68)
		elif _in_memory:
			_value_label.text = "[%d] %s" % [slot_index + 1, roman]
			_value_label.modulate = Color(0.65, 0.92, 1.0)
		else:
			_value_label.text = "— %s —" % roman
			_value_label.modulate = Color(0.6, 0.55, 0.45, 0.65)
	if _light:
		if is_locked_solved:
			_light.light_color = Color(0.45, 1.0, 0.68)
			_light.light_energy = 2.6
		else:
			_light.light_color = Color(0.42, 0.84, 1.0) if _in_memory else Color(0.85, 0.6, 0.3)
			_light.light_energy = 1.6 if _in_memory else 0.7
	_refresh_prompt_text()


func _refresh_prompt_text() -> void:
	if _prompt_label == null:
		return
	if is_locked_solved:
		_prompt_label.text = "Mekanisme Terbuka ✓"
	elif not _in_memory:
		_prompt_label.text = "Lihat angka di dinding → [T] ke Remembered untuk atur"
	else:
		var roman: String = ROMAN_MAP.get(get_current_value(), str(get_current_value()))
		_prompt_label.text = "[E] Ubah Angka Jam #%d (%s)" % [slot_index + 1, roman]
