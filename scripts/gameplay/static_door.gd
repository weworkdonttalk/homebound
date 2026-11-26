extends StaticBody3D

# ============================================================================
# StaticDoor — script sederhana untuk pintu StaticBody3D di Chapter 2
# Mendukung animasi buka daun pintu (Object_3 via DoorHinge) dan interaksi [E].
# Berbeda dari door_portal.gd yang extends Area3D untuk transisi antar scene.
# ============================================================================

@export_file("*.tscn") var target_scene_path: String = ""
@export var is_locked: bool = false
@export var open_angle_degrees: float = 100.0
@export var open_duration: float = 1.2
@export var door_target_node: Node3D = null

var is_open: bool = false
var _door_leaf: Node3D = null
var _hinge: Node3D = null
var _base_y: float = 0.0

func _ready() -> void:
	_setup()

func _setup() -> void:
	# Cari node pintu (Sketchfab_Scene) dan daun pintu Object_3
	if door_target_node == null:
		door_target_node = get_node_or_null("Sketchfab_Scene") as Node3D
	if door_target_node:
		_door_leaf = door_target_node.find_child("Object_3", true, false) as Node3D
	if _door_leaf == null:
		_door_leaf = find_child("Object_3", true, false) as Node3D

	# Cari DoorHinge jika ada
	_hinge = find_child("DoorHinge", true, false) as Node3D
	if _hinge:
		_base_y = _hinge.rotation_degrees.y
	elif _door_leaf:
		_base_y = _door_leaf.rotation_degrees.y

func open_door() -> void:
	if is_open or is_locked:
		return
	is_open = true
	var node := _hinge if _hinge else _door_leaf
	if node:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "rotation_degrees:y", _base_y + open_angle_degrees, open_duration)

func unlock_and_open() -> void:
	is_locked = false
	open_door()
