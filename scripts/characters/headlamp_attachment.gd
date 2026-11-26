@tool
class_name HeadlampAttachment
extends BoneAttachment3D

## Headlamp Attachment Controller
## Secara otomatis mengikat model 3D headlamp.glb ke tulang kepala (mixamorig_Head)
## baik di editor (preview real-time) maupun saat gameplay berjalan.

const HEADLAMP_SCENE: PackedScene = preload("res://assets/characters/mc/headlamp.glb")

@export var model_scale := Vector3(2.5, 2.5, 2.5):
	set(v):
		model_scale = v
		_update_model_transform()

@export var model_offset := Vector3(0.0, 0.14, 0.04):
	set(v):
		model_offset = v
		_update_model_transform()

@export var model_rotation_degrees := Vector3(0.0, 180.0, 0.0):
	set(v):
		model_rotation_degrees = v
		_update_model_transform()

var _model_instance: Node3D = null

func _enter_tree() -> void:
	bone_name = "mixamorig_Head"
	bone_idx = 5

func _ready() -> void:
	bone_name = "mixamorig_Head"
	bone_idx = 5
	_setup_model()

func _setup_model() -> void:
	_model_instance = get_node_or_null("HeadlampModel") as Node3D
	if _model_instance == null and HEADLAMP_SCENE:
		_model_instance = HEADLAMP_SCENE.instantiate() as Node3D
		_model_instance.name = "HeadlampModel"
		add_child(_model_instance)
	_update_model_transform()

	var spot := get_node_or_null("HeadlampSpotLight") as SpotLight3D
	if spot == null:
		spot = SpotLight3D.new()
		spot.name = "HeadlampSpotLight"
		spot.position = Vector3(0.0, 0.14, 0.194)
		spot.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
		spot.light_color = Color(1.0, 0.85, 0.6)
		spot.light_energy = 2.5
		spot.light_volumetric_fog_energy = 2.5
		spot.shadow_enabled = true
		spot.spot_range = 14.0
		spot.spot_angle = 45.0
		add_child(spot)

func _update_model_transform() -> void:
	if _model_instance and is_instance_valid(_model_instance):
		_model_instance.position = model_offset
		_model_instance.rotation_degrees = model_rotation_degrees
		_model_instance.scale = model_scale
