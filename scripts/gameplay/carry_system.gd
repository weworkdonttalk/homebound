extends Node3D

# ============================================================================
# Carry & Drop System — Little Nightmares Style Object Interaction
# Pengangkatan objek halus dengan lintasan kurva (parabolic arc tween) ke tangan karakter.
# Menghindari instant snapping, physics jitter, dan benturan collision.
# Mengacu pada pedoman godot-tweening, godot-physics-3d, dan game-feel skills.
# ============================================================================

## Referensi ke skrip pemain (CharacterBody3D / mc.gd)
@export var player: Node3D

## Titik tumpu objek (Marker3D) di tangan karakter
@export var hold_point: Marker3D

## Durasi animasi transisi objek terangkat ke tangan (detik)
@export var pickup_duration: float = 0.32

## Ketinggian lengkungan arc saat objek terangkat (meter)
@export var pickup_arc_height: float = 0.35

## Nama animasi bawa barang di AnimationPlayer / AnimationTree pemain
@export var carry_animation_name := "Carrying"

## Kecepatan transisi animasi bawa (detik)
@export var carry_transition_duration := 0.22

## Sinyal saat objek diambil / dilepas
signal item_picked_up(item: RigidBody3D)
signal item_dropped(item: RigidBody3D, position: Vector3)

var carried_item: RigidBody3D = null
var item_original_collision_layer: int = 4
var item_original_collision_mask: int = 1
var item_original_freeze: bool = false

# --- Status transisi pengambilan (Smooth Arc Tween) ---
var is_transitioning: bool = false
var transition_progress: float = 0.0
var pickup_start_pos: Vector3 = Vector3.ZERO
var pickup_start_rot: Quaternion = Quaternion.IDENTITY
var _pickup_tween: Tween = null

# --- Referensi animasi pemain ---
@onready var anim_player: AnimationPlayer = player.get_node_or_null("AnimationPlayer") if player else null
@onready var anim_tree: AnimationTree = player.get_node_or_null("AnimationTree") if player else null

func _ready() -> void:
	if hold_point == null and player != null:
		hold_point = player.get_node_or_null("body/HoldPoint")
	if hold_point == null and player != null:
		hold_point = player.get_node_or_null("body/Marker3D")
	if anim_player == null and player != null:
		anim_player = player.get_node_or_null("char no light/AnimationPlayer")
	if anim_player == null and player != null:
		anim_player = player.get_node_or_null("../char no light/AnimationPlayer")

# ---------------------------------------------------------------------------
# Ambil objek (pick_up) — Pengangkatan mulus dengan parabolic arc tween
# ---------------------------------------------------------------------------
func pick_up(item: RigidBody3D) -> bool:
	if carried_item != null or item == null:
		return false

	carried_item = item
	item_original_collision_layer = item.collision_layer if item.collision_layer != 0 else 4
	item_original_collision_mask = item.collision_mask if item.collision_mask != 0 else 1
	item_original_freeze = item.freeze

	# 1. Nonaktifkan fisika & collision seketika agar tidak bertabrakan dengan kapsul Player
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0

	# 2. Setup Arc Tween dari posisi dunia asal menuju posisi tangan (hold_point)
	if _pickup_tween and _pickup_tween.is_valid():
		_pickup_tween.kill()

	pickup_start_pos = item.global_position
	pickup_start_rot = item.global_transform.basis.get_rotation_quaternion()
	transition_progress = 0.0
	is_transitioning = true

	_pickup_tween = create_tween()
	_pickup_tween.set_ease(Tween.EASE_OUT)
	_pickup_tween.set_trans(Tween.TRANS_CUBIC)
	_pickup_tween.tween_property(self, "transition_progress", 1.0, pickup_duration)
	_pickup_tween.tween_callback(func():
		is_transitioning = false
		if carried_item and hold_point:
			carried_item.global_position = hold_point.global_position
			carried_item.global_rotation = hold_point.global_rotation
	)

	# 3. Mainkan animasi bawa barang (Carrying)
	_play_carry_animation(true)

	item_picked_up.emit(item)
	return true

# ---------------------------------------------------------------------------
# Lepas objek (drop) — Peletakan mulus & pemulihan fisika
# ---------------------------------------------------------------------------
func drop(override_position: Variant = null) -> bool:
	var item := carried_item
	if item == null:
		return false

	if _pickup_tween and _pickup_tween.is_valid():
		_pickup_tween.kill()

	carried_item = null
	is_transitioning = false

	var drop_position: Vector3 = Vector3.ZERO
	if override_position is Vector3:
		drop_position = override_position
	elif hold_point and player:
		drop_position = hold_point.global_position + player.global_transform.basis.z * 0.9 + Vector3.DOWN * 0.4
	elif player:
		drop_position = player.global_position + player.global_transform.basis.z * 1.0 + Vector3.UP * 0.2

	# Pulihkan properti fisika asli
	item.freeze = false
	item.collision_layer = item_original_collision_layer
	item.collision_mask = item_original_collision_mask
	item.sleeping = false

	if drop_position != Vector3.ZERO:
		item.global_position = drop_position

	# Berikan dorongan kecil natural ke depan-bawah saat diletakkan
	if player:
		item.linear_velocity = player.global_transform.basis.z * 1.2 + Vector3.DOWN * 0.6
	else:
		item.linear_velocity = Vector3.DOWN * 0.5

	# Hentikan animasi bawa, kembali ke normal
	_play_carry_animation(false)

	item_dropped.emit(item, drop_position)
	return true

# ---------------------------------------------------------------------------
# Animasi bawa (Carrying) — AnimationPlayer atau AnimationTree
# ---------------------------------------------------------------------------
func _play_carry_animation(carrying: bool) -> void:
	var clip := carry_animation_name
	if anim_player and anim_player.has_animation(clip):
		if carrying:
			anim_player.play(clip, carry_transition_duration)
		else:
			if anim_player.has_animation("Idle"):
				anim_player.play("Idle", carry_transition_duration)
			else:
				anim_player.stop()

	if anim_tree:
		var sm = anim_tree.get("parameters/playback")
		if sm:
			if carrying:
				sm.travel(StringName(clip))
			else:
				sm.travel(&"Idle")

func _physics_process(_delta: float) -> void:
	if carried_item == null or hold_point == null:
		return

	if is_transitioning:
		# Lintasan parabola mulus (arc lerp) menuju tangan karakter
		var target_pos := hold_point.global_position
		var target_rot := hold_point.global_transform.basis.get_rotation_quaternion()

		var arc_y := sin(transition_progress * PI) * pickup_arc_height
		var current_pos := pickup_start_pos.lerp(target_pos, transition_progress)
		current_pos.y += arc_y

		carried_item.global_position = current_pos
		carried_item.global_transform.basis = Basis(pickup_start_rot.slerp(target_rot, transition_progress))
	else:
		# Terkunci mantap di tangan karakter saat berjalan / idle
		carried_item.global_position = hold_point.global_position
		carried_item.global_rotation = hold_point.global_rotation
