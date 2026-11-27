@tool
class_name PendulumPuzzleZone
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")
const PendulumScript := preload("res://scripts/gameplay/clock_pendulum.gd")
const BridgeScript := preload("res://scripts/gameplay/pendulum_bridge_platform.gd")

## Puzzle 4: The Pendulum (Zona 3 Jurang Jam Raksasa) + Exit DoorPortal menuju Credits/MainMenu.
## Menggabungkan 3 Pendulum raksasa (beku di Forgotten, berayun di Remembered) dan
## platform jembatan yang menghilang di Forgotten sehingga pemain harus mengatur timing [T].

signal step_reached(step_index: int, total_steps: int)
signal pendulum_cleared

var _highest_step: int = 0
var _total_steps: int = 3
var _cleared: bool = false
var _player: CharacterBody3D = null
var _checkpoint_x_thresholds := [116.0, 139.0, 165.0]


func _ready() -> void:
	_build_pendulums()
	_build_dimension_bridges()
	_build_exit_portal()
	if Engine.is_editor_hint():
		return
	_player = Ch2Utils.find_player(self)


func _build_pendulums() -> void:
	var specs := [
		["Pendulum_1", Vector3(110.5, 19.6, 2.0), 11.4, 38.0, 1.55, 0.0],
		["Pendulum_2", Vector3(133.0, 19.6, 2.0), 11.4, 40.0, 1.85, 1.8],
		["Pendulum_3", Vector3(158.5, 19.6, 2.0), 11.4, 42.0, 2.05, 3.1],
	]
	for s: Array in specs:
		if get_node_or_null(NodePath(s[0])) != null:
			continue
		var p := PendulumScript.new()
		p.name = s[0]
		p.position = s[1]
		p.arm_length = s[2]
		p.max_swing_degrees = s[3]
		p.swing_speed = s[4]
		p.phase_offset = s[5]
		add_child(p)


func _build_dimension_bridges() -> void:
	# Platform penghubung Remembered-only: hilang saat Forgotten ([T]) ketika membekukan pendulum
	var bridges := [
		["PendulumBridge_1", Vector3(115.8, 6.62, 2.0), Vector3(3.6, 0.28, 4.0)],
		["PendulumBridge_2", Vector3(139.0, 6.62, 2.0), Vector3(3.6, 0.28, 4.0)],
		["PendulumStep_A", Vector3(164.6, 7.55, 3.5), Vector3(2.8, 0.30, 4.2)],
		["PendulumStep_B", Vector3(166.5, 8.28, 4.4), Vector3(2.8, 0.30, 4.2)],
	]
	for b: Array in bridges:
		if get_node_or_null(NodePath(b[0])) != null:
			continue
		var plat := BridgeScript.new()
		plat.name = b[0]
		plat.solid_dimension = "Remembered"
		plat.position = b[1]
		plat.platform_size = b[2]
		add_child(plat)


func _build_exit_portal() -> void:
	if get_node_or_null("DoorPortal") != null:
		return
	var portal_script := load("res://scripts/door_portal.gd")
	var wooden_door := load("res://assets/wooden_door.glb") as PackedScene
	if portal_script == null:
		return

	var portal := Area3D.new()
	portal.name = "DoorPortal"
	portal.position = Vector3(174.4, 8.76, 4.7)
	portal.rotation_degrees.y = -90.0
	portal.set_script(portal_script)
	portal.set("target_scene_path", "res://main_menu.tscn")
	portal.set("is_locked", false)
	portal.set("trigger_distance_threshold", 2.4)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 4.5, 2.8)
	col.shape = bs
	col.position = Vector3(0.0, 2.2, 0.0)
	portal.add_child(col)

	if wooden_door:
		var wd := wooden_door.instantiate() as Node3D
		wd.name = "WoodenDoor"
		portal.add_child(wd)

	var glow := OmniLight3D.new()
	glow.name = "DoorInnerGlow"
	glow.position = Vector3(0.0, 2.4, -0.8)
	glow.light_color = Color(1.0, 0.88, 0.62)
	glow.light_energy = 0.0
	glow.omni_range = 10.0
	portal.add_child(glow)
	portal.set("door_inner_glow", glow)

	var prompt := Ch2Utils.create_prompt_label(portal, Vector3(0.0, 3.0, 0.4), Color(1.0, 0.94, 0.72), 36)
	prompt.name = "InteractionPrompt"
	prompt.text = "[E] Masuk ke Cahaya"
	if Engine.is_editor_hint():
		prompt.visible = true
	portal.set("interaction_prompt", prompt)

	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0.0, 4.2, 1.4)
	beacon.light_color = Color(1.0, 0.84, 0.56)
	beacon.light_energy = 3.2
	beacon.omni_range = 12.0
	portal.add_child(beacon)

	add_child(portal)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _cleared:
		return
	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return

	var px := _player.global_position.x
	if _player.global_position.y > 5.0:
		for i in range(_checkpoint_x_thresholds.size()):
			if px >= _checkpoint_x_thresholds[i] and (i + 1) > _highest_step:
				_highest_step = i + 1
				step_reached.emit(_highest_step, _total_steps)
				var void_zone := get_tree().current_scene.find_child("VoidRespawnZone", true, false) if get_tree() and get_tree().current_scene else null
				if void_zone and "_checkpoint_pos" in void_zone:
					void_zone.set("_checkpoint_pos", Vector3(px - 1.2, 7.0, 2.0))
				if _highest_step >= _total_steps and not _cleared:
					_cleared = true
					pendulum_cleared.emit()
