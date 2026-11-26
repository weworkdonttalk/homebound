extends Area3D
class_name ParkourCameraZone

# ============================================================================
# ParkourCameraZone — Zoom-out FOV saat karakter masuk area rintangan melayang.
# Ditempatkan sebagai Area3D dengan CollisionShape3D yang mencakup area parkour.
# Otomatis mencari CameraRig di scene dan memanggil enter/exit_parkour_zone().
# ============================================================================

@export var camera_rig_path: NodePath = NodePath("")

var _camera_rig: Node3D = null


func _ready() -> void:
	# Cari CameraRig
	if camera_rig_path != NodePath(""):
		_camera_rig = get_node_or_null(camera_rig_path)
	if _camera_rig == null:
		_camera_rig = get_node_or_null("../CameraRig")
	if _camera_rig == null:
		_camera_rig = get_node_or_null("../../CameraRig")

	# Pastikan Area3D hanya mendeteksi player (layer 2)
	collision_layer = 0
	collision_mask = 2  # Player collision layer
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		if _camera_rig and _camera_rig.has_method("enter_parkour_zone"):
			_camera_rig.call("enter_parkour_zone")


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body is CharacterBody3D:
		if _camera_rig and _camera_rig.has_method("exit_parkour_zone"):
			_camera_rig.call("exit_parkour_zone")
