extends Node3D

## Mekanik Tembok Kebelah (Splitting Wall)
## Menggeser dua sisi tembok secara berlawanan dengan efek debu dan camera shake.

@export_group("Gerakan Tembok")
@export var arah_geser: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var jarak_belah: float = 2.5
@export var durasi_animasi: float = 1.8
@export var requires_relic_unlock: bool = false

@export_group("Camera Shake")
@export var kekuatan_shake: float = 0.35
@export var durasi_shake: float = 1.2

@onready var tembok_kiri: Node3D = get_node_or_null("TembokKiri")
@onready var tembok_kanan: Node3D = get_node_or_null("TembokKanan")
@onready var partikel_debu: GPUParticles3D = get_node_or_null("PartikelDebu")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")

var is_open: bool = false
var _triggered: bool = false
var _shake_timer: float = 0.0
var _camera: Camera3D = null
var _kiri_closed_pos: Vector3 = Vector3(0.0, 0.0, -1.17)
var _kanan_closed_pos: Vector3 = Vector3(0.0, 0.0, 1.17)
var _door_tween: Tween = null

func _ready() -> void:
	if tembok_kiri:
		_kiri_closed_pos = tembok_kiri.position
	if tembok_kanan:
		_kanan_closed_pos = tembok_kanan.position
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
	if _triggered or requires_relic_unlock:
		return
	if body.is_in_group("player") or body is CharacterBody3D or body.name == "Player":
		_triggered = true
		_start_splitting()


## Membuka pintu ganda (dipanggil oleh puzzle jam / relik).
func unlock_and_open() -> void:
	if is_open:
		return
	requires_relic_unlock = false
	_triggered = true
	is_open = true
	_start_splitting()


## Menutup & mengunci kembali pintu ganda dengan suara/efek bantingan (Airlock Safe Room).
func close_and_lock(slam_duration: float = 0.42) -> void:
	requires_relic_unlock = true
	_triggered = false
	var was_open := is_open
	is_open = false
	_set_doorway_colliders_disabled(false)
	if not was_open and tembok_kiri and tembok_kiri.position.distance_to(_kiri_closed_pos) < 0.05:
		return
	if partikel_debu:
		partikel_debu.emitting = true
	var dir := arah_geser.normalized()
	if _door_tween and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween().set_parallel(true)
	if tembok_kiri:
		_door_tween.tween_property(tembok_kiri, "position", _kiri_closed_pos, slam_duration)\
			.set_trans(Tween.TRANS_QUART)\
			.set_ease(Tween.EASE_IN)
	if tembok_kanan:
		_door_tween.tween_property(tembok_kanan, "position", _kanan_closed_pos, slam_duration)\
			.set_trans(Tween.TRANS_QUART)\
			.set_ease(Tween.EASE_IN)
	_door_tween.chain().tween_callback(func() -> void:
		if partikel_debu:
			partikel_debu.emitting = false
		_trigger_slam_feedback()
	)


func _trigger_slam_feedback() -> void:
	_camera = get_viewport().get_camera_3d() if get_viewport() else null
	if _camera and durasi_shake > 0.0 and kekuatan_shake > 0.0:
		_shake_timer = minf(0.45, durasi_shake)
		set_process(true)
	_play_door_slam_sfx()


func _play_door_slam_sfx() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var sample_rate := 22050
	var dur := 0.34
	var frames := int(sample_rate * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 14.0)
		var thud := sin(TAU * (92.0 - 48.0 * minf(t / dur, 1.0)) * t) * 0.72
		var rattle := sin(TAU * 195.0 * t) * exp(-t * 28.0) * 0.28
		var val := int(clampf((thud + rattle) * env * 0.55, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	var asp := AudioStreamPlayer.new()
	asp.stream = wav
	asp.volume_db = -3.0
	add_child(asp)
	asp.finished.connect(func() -> void:
		if is_instance_valid(asp):
			asp.queue_free()
	)
	asp.play()


func _start_splitting() -> void:
	if partikel_debu:
		partikel_debu.emitting = true

	_start_camera_shake()

	if _door_tween and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween().set_parallel(true)
	var dir := arah_geser.normalized()

	if tembok_kiri:
		var target_kiri := _kiri_closed_pos - (dir * jarak_belah)
		_door_tween.tween_property(tembok_kiri, "position", target_kiri, durasi_animasi)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)

	if tembok_kanan:
		var target_kanan := _kanan_closed_pos + (dir * jarak_belah)
		_door_tween.tween_property(tembok_kanan, "position", target_kanan, durasi_animasi)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)

	_door_tween.chain().tween_callback(func() -> void:
		if partikel_debu:
			partikel_debu.emitting = false
		_disable_doorway_colliders()
	)


func _disable_doorway_colliders() -> void:
	_set_doorway_colliders_disabled(true)


func _set_doorway_colliders_disabled(disabled: bool) -> void:
	var partition_wall = get_tree().root.find_child("CollisionShape3D_PartitionWall", true, false) as CollisionShape3D
	if partition_wall:
		partition_wall.set_deferred("disabled", disabled)

	for wall_node in [tembok_kiri, tembok_kanan]:
		if wall_node:
			for col in wall_node.find_children("*", "CollisionShape3D", true, false):
				if col is CollisionShape3D:
					col.set_deferred("disabled", disabled)
			for body in wall_node.find_children("*", "CollisionObject3D", true, false):
				if body is CollisionObject3D:
					body.set_deferred("collision_layer", 0 if disabled else 1)
					body.set_deferred("collision_mask", 0)

	var plane_004 = get_tree().root.find_child("Plane_004", true, false)
	if plane_004:
		for col in plane_004.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				col.set_deferred("disabled", disabled)

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
