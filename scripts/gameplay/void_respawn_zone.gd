class_name VoidRespawnZone
extends Area3D

## ============================================================================
## VoidRespawnZone — Jaring Pengaman Jurang Parkour (Auto-Respawn)
## Menangkap Player yang jatuh ke jurang Void di area parkour, melakukan fade
## hitam singkat (~0.22s), dan memindahkan Player ke Batu Anchor terakhir.
## ============================================================================

@export var default_spawn_pos: Vector3 = Vector3(25.8, 0.35, 3.8)
@export var fade_rect_path: NodePath = NodePath("../FadeCanvasLayer/ColorRect")

var _checkpoint_pos: Vector3 = Vector3(25.8, 0.35, 3.8)
var _highest_rock_index: int = 0
var _total_rocks: int = 7
var _is_respawning: bool = false
var _fade_rect: ColorRect = null

signal parkour_progress_updated(step_index: int, total_rocks: int)
signal parkour_completed


func _ready() -> void:
	_checkpoint_pos = default_spawn_pos
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	if _fade_rect == null:
		var fl := get_tree().root.find_child("FadeCanvasLayer", true, false)
		if fl:
			_fade_rect = fl.get_node_or_null("ColorRect") as ColorRect

	body_entered.connect(_on_body_entered)
	call_deferred("_wire_parkour_rocks")


func _wire_parkour_rocks() -> void:
	var rocks_root := get_node_or_null("../ParkourRocks")
	if rocks_root == null:
		return
	var count := 0
	for child in rocks_root.get_children():
		if child.has_signal("rock_stepped"):
			count += 1
			if not child.is_connected("rock_stepped", _on_rock_stepped):
				child.connect("rock_stepped", _on_rock_stepped)
	if count > 0:
		_total_rocks = count


func _on_rock_stepped(index: int, rock: Node3D) -> void:
	if rock and bool(rock.get("is_checkpoint")) and rock.has_method("get_respawn_world_position"):
		_checkpoint_pos = rock.call("get_respawn_world_position")

	if index > _highest_rock_index:
		_highest_rock_index = index
		parkour_progress_updated.emit(_highest_rock_index, _total_rocks)
		if _highest_rock_index >= _total_rocks:
			parkour_completed.emit()


func _on_body_entered(body: Node3D) -> void:
	if _is_respawning:
		return
	if body.name != "Player" and not (body is CharacterBody3D):
		return

	_respawn_player(body as CharacterBody3D)


func _respawn_player(player: CharacterBody3D) -> void:
	_is_respawning = true
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", false)

	if _fade_rect:
		_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
		var tw_out := create_tween()
		tw_out.tween_property(_fade_rect, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		await tw_out.finished
	else:
		await get_tree().create_timer(0.18).timeout

	player.velocity = Vector3.ZERO
	player.global_position = _checkpoint_pos

	if _fade_rect:
		var tw_in := create_tween()
		tw_in.tween_property(_fade_rect, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
		await tw_in.finished

	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", true)

	_is_respawning = false
