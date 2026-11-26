extends Node3D

## Mekanik Tembok Kebelah (Splitting Wall)
## Menggeser dua sisi tembok secara berlawanan dengan efek debu dan camera shake.

@export_group("Gerakan Tembok")
@export var arah_geser: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var jarak_belah: float = 2.5
@export var durasi_animasi: float = 1.8

@export_group("Camera Shake")
@export var kekuatan_shake: float = 0.35
@export var durasi_shake: float = 1.2

@onready var tembok_kiri: Node3D = get_node_or_null("TembokKiri")
@onready var tembok_kanan: Node3D = get_node_or_null("TembokKanan")
@onready var partikel_debu: GPUParticles3D = get_node_or_null("PartikelDebu")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")

var _triggered: bool = false
var _shake_timer: float = 0.0
var _camera: Camera3D = null

func _ready() -> void:
	if trigger_area and not trigger_area.body_entered.is_connected(_on_trigger_area_body_entered):
		trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	_setup_particles_if_needed()

func _setup_particles_if_needed() -> void:
	if not partikel_debu:
		return
	partikel_debu.emitting = false
	if partikel_debu.process_material == null:
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(0.2, 2.0, 0.8)
		mat.direction = Vector3(0.0, 1.0, 0.0)
		mat.spread = 45.0
		mat.initial_velocity_min = 0.5
		mat.initial_velocity_max = 1.5
		mat.gravity = Vector3(0.0, -0.6, 0.0)
		mat.scale_min = 0.1
		mat.scale_max = 0.35
		partikel_debu.process_material = mat
	if partikel_debu.draw_pass_1 == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.15, 0.15)
		var m_mat := StandardMaterial3D.new()
		m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m_mat.albedo_color = Color(0.85, 0.8, 0.75, 0.6)
		m_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = m_mat
		partikel_debu.draw_pass_1 = quad

func _on_trigger_area_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body.is_in_group("player") or body is CharacterBody3D or body.name == "Player":
		_triggered = true
		_start_splitting()

func _start_splitting() -> void:
	if partikel_debu:
		partikel_debu.emitting = true
	
	_start_camera_shake()
	
	var tween := create_tween().set_parallel(true)
	var dir := arah_geser.normalized()
	
	if tembok_kiri:
		var target_kiri := tembok_kiri.position - (dir * jarak_belah)
		tween.tween_property(tembok_kiri, "position", target_kiri, durasi_animasi)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)
			
	if tembok_kanan:
		var target_kanan := tembok_kanan.position + (dir * jarak_belah)
		tween.tween_property(tembok_kanan, "position", target_kanan, durasi_animasi)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)
			
	tween.chain().tween_callback(func() -> void:
		if partikel_debu:
			partikel_debu.emitting = false
		_disable_doorway_colliders()
	)

func _disable_doorway_colliders() -> void:
	var partition_wall = get_tree().root.find_child("CollisionShape3D_PartitionWall", true, false) as CollisionShape3D
	if partition_wall:
		partition_wall.set_deferred("disabled", true)

	for wall_node in [tembok_kiri, tembok_kanan]:
		if wall_node:
			for col in wall_node.find_children("*", "CollisionShape3D", true, false):
				if col is CollisionShape3D:
					col.set_deferred("disabled", true)
			for body in wall_node.find_children("*", "CollisionObject3D", true, false):
				if body is CollisionObject3D:
					body.set_deferred("collision_layer", 0)
					body.set_deferred("collision_mask", 0)

	var plane_004 = get_tree().root.find_child("Plane_004", true, false)
	if plane_004:
		for col in plane_004.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				col.set_deferred("disabled", true)

func _start_camera_shake() -> void:
	_camera = get_viewport().get_camera_3d()
	if _camera and durasi_shake > 0.0 and kekuatan_shake > 0.0:
		_shake_timer = durasi_shake
		set_process(true)
	else:
		set_process(false)

func _process(delta: float) -> void:
	if _shake_timer > 0.0 and _camera:
		_shake_timer -= delta
		var progress: float = clampf(_shake_timer / durasi_shake, 0.0, 1.0)
		var current_amp: float = kekuatan_shake * progress
		_camera.h_offset = randf_range(-current_amp, current_amp)
		_camera.v_offset = randf_range(-current_amp, current_amp)
		if _shake_timer <= 0.0:
			_camera.h_offset = 0.0
			_camera.v_offset = 0.0
			set_process(false)
	else:
		set_process(false)
