extends StaticBody3D

# ============================================================================
# StaticDoor — Pintu Interaktif [E] untuk Chapter 2
# Membuat DoorHinge otomatis pada tepi daun pintu terluas (Object_2 / Object_3),
# menambahkan collider blokir saat pintu tertutup, serta prompt [E] untuk
# membuka dan menutup pintu.
# ============================================================================

@export_file("*.tscn") var target_scene_path: String = ""
@export var is_locked: bool = false
@export var open_angle_degrees: float = 100.0
@export var open_duration: float = 0.9
@export var interact_distance: float = 3.2
@export var door_target_node: Node3D = null
@export var open_hint: String = "[E] Buka Pintu"
@export var close_hint: String = "[E] Tutup Pintu"
@export var locked_hint: String = "[E] Terkunci"

var is_open: bool = false
var _door_leaf: Node3D = null
var _hinge: Node3D = null
var _door_col: CollisionShape3D = null
var _prompt_label: Label3D = null
var _player: Node3D = null
var _door_center_world: Vector3 = Vector3.ZERO
var _base_y: float = 0.0
var _tween: Tween = null
var _player_near: bool = false
var _locked_flash_until: float = 0.0


func _ready() -> void:
	_setup()


func _setup() -> void:
	if door_target_node == null:
		door_target_node = get_node_or_null("Sketchfab_Scene") as Node3D

	if door_target_node:
		var max_faces := -1
		for m in door_target_node.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi and mi.mesh:
				var faces: int = mi.mesh.get_faces().size()
				if faces > max_faces:
					max_faces = faces
					_door_leaf = mi
		if _door_leaf == null:
			_door_leaf = door_target_node.find_child("Object_2", true, false) as Node3D
		if _door_leaf == null:
			_door_leaf = door_target_node.find_child("Object_3", true, false) as Node3D

	_hinge = find_child("DoorHinge", true, false) as Node3D
	if _door_leaf is MeshInstance3D:
		var mesh_inst := _door_leaf as MeshInstance3D
		var aabb: AABB = mesh_inst.get_aabb()
		var min_c := Vector3(INF, INF, INF)
		var max_c := Vector3(-INF, -INF, -INF)
		for xi in [0.0, 1.0]:
			for yi in [0.0, 1.0]:
				for zi in [0.0, 1.0]:
					var world_pt := mesh_inst.global_transform * (aabb.position + aabb.size * Vector3(xi, yi, zi))
					min_c = min_c.min(world_pt)
					max_c = max_c.max(world_pt)

		_door_center_world = (min_c + max_c) * 0.5
		_create_blocking_collider(min_c, max_c)

		if _hinge == null:
			var span_x := max_c.x - min_c.x
			var span_z := max_c.z - min_c.z
			var hinge_pos := Vector3(
				(min_c.x + max_c.x) * 0.5 if span_z >= span_x else min_c.x,
				min_c.y,
				min_c.z if span_z >= span_x else (min_c.z + max_c.z) * 0.5
			)
			_hinge = Node3D.new()
			_hinge.name = "DoorHinge"
			add_child(_hinge)
			_hinge.global_position = hinge_pos
			_hinge.global_rotation = Vector3.ZERO
			_door_leaf.reparent(_hinge, true)
	else:
		_door_center_world = global_position + Vector3(0.0, 2.0, 0.0)

	if _hinge:
		_base_y = _hinge.rotation_degrees.y
	elif _door_leaf:
		_base_y = _door_leaf.rotation_degrees.y

	_create_prompt_label()
	_player = get_node_or_null("../Player") as Node3D
	if _player == null and get_tree():
		_player = get_tree().root.find_child("Player", true, false) as Node3D


func _create_blocking_collider(min_c: Vector3, max_c: Vector3) -> void:
	_door_col = get_node_or_null("DoorLeafCol") as CollisionShape3D
	if _door_col != null:
		return
	var size := (max_c - min_c).max(Vector3(0.35, 1.0, 0.35))
	_door_col = CollisionShape3D.new()
	_door_col.name = "DoorLeafCol"
	var box := BoxShape3D.new()
	box.size = size
	_door_col.shape = box
	add_child(_door_col)
	_door_col.global_position = (min_c + max_c) * 0.5


func _create_prompt_label() -> void:
	_prompt_label = get_node_or_null("InteractionPrompt") as Label3D
	if _prompt_label != null:
		return
	_prompt_label = Label3D.new()
	_prompt_label.name = "InteractionPrompt"
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.render_priority = 10
	_prompt_label.outline_render_priority = 9
	_prompt_label.font_size = 42
	_prompt_label.outline_size = 8
	_prompt_label.pixel_size = 0.008
	_prompt_label.modulate = Color(1.0, 0.94, 0.78, 1.0)
	_prompt_label.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	_prompt_label.visible = false
	add_child(_prompt_label)
	_prompt_label.global_position = Vector3(_door_center_world.x, 2.65, _door_center_world.z)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p_flat := Vector2(_player.global_position.x, _player.global_position.z)
	var d_flat := Vector2(_door_center_world.x, _door_center_world.z)
	var vertical_ok := absf(_player.global_position.y - _door_center_world.y) < 4.5
	_player_near = vertical_ok and p_flat.distance_to(d_flat) <= interact_distance

	if _prompt_label:
		_prompt_label.visible = _player_near
		if _player_near:
			var now := Time.get_ticks_msec() * 0.001
			if now < _locked_flash_until:
				_prompt_label.text = "Terkunci..."
			elif is_locked:
				_prompt_label.text = locked_hint
			else:
				_prompt_label.text = close_hint if is_open else open_hint


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or _player == null:
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if _player.get("item_dipegang") != null or _player.get("objek_ditarik") != null:
		return

	if is_locked:
		_rattle_locked()
		get_viewport().set_input_as_handled()
		return

	toggle_door()
	get_viewport().set_input_as_handled()


func _rattle_locked() -> void:
	_locked_flash_until = Time.get_ticks_msec() * 0.001 + 1.0
	var node := _hinge if _hinge else _door_leaf
	if node == null:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(node, "rotation_degrees:y", _base_y + 2.5, 0.07)
	_tween.tween_property(node, "rotation_degrees:y", _base_y - 2.0, 0.07)
	_tween.tween_property(node, "rotation_degrees:y", _base_y, 0.08)


func toggle_door() -> void:
	if is_open:
		close_door()
	else:
		open_door()


func open_door() -> void:
	if is_open or is_locked:
		return
	is_open = true
	if _door_col:
		_door_col.set_deferred("disabled", true)
	var node := _hinge if _hinge else _door_leaf
	if node:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(node, "rotation_degrees:y", _base_y + open_angle_degrees, open_duration)


func close_door() -> void:
	if not is_open:
		return
	is_open = false
	var node := _hinge if _hinge else _door_leaf
	if node:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(node, "rotation_degrees:y", _base_y, open_duration)
		_tween.finished.connect(func() -> void:
			if not is_open and _door_col:
				_door_col.disabled = false
		)
	elif _door_col:
		_door_col.set_deferred("disabled", false)


func unlock_and_open() -> void:
	is_locked = false
	open_door()
