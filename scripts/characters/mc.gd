extends CharacterBody3D

# ============================================================================
# MC (Main Character) — Cinematic 2.5D Controller (Little Nightmares Style)
# Responsif, animasi mulus (cross-fade & speed matching), coyote time & jump buffer.
# CLIMB RESTRICTION: Karakter HANYA boleh memanjat objek dengan grup "meja"/"climbable".
# ============================================================================

# =====================================
# MOVEMENT CONSTANTS (Proporsional untuk Karakter Scale 2.2)
# =====================================

const SPEED = 2.2
const RUN_SPEED = 5.0
const CROUCH_SPEED = 1.2
const PULL_SPEED = 2.0
const JUMP_VELOCITY = 7.2
const TURN_SPEED = 18.0
const WALK_ANIM_REF_SPEED = 4.2
const RUN_ANIM_REF_SPEED = 7.2

const ACCELERATION = 28.0
const DECELERATION = 36.0
const AIR_ACCEL = 16.0
const AIR_DECEL = 10.0
const FALL_GRAVITY_MULT = 1.55
const JUMP_CUT_MULT = 0.5

const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12
const JUMP_COOLDOWN = 0.25
const DEPTH_RATIO = 0.85 # Sedikit redam sumbu Z untuk rasa kedalaman 2.5D presisi

# =====================================
# CROUCH SETTINGS
# =====================================

const CROUCH_HEIGHT_RATIO = 0.5
const CROUCH_TRANSITION_SPEED = 12.0

# =====================================
# WALL CLIMBING & MANTLE (RESTRICTED — hanya objek climbable/meja)
# =====================================

const CLIMB_SPEED = 2.4
const WALL_STICK_SPEED = 2.2
const WALL_STRAFE_SPEED = 4.5

const WALL_JUMP_PUSH = 6.0
const WALL_JUMP_LOCK = 0.45

const MANTLE_DURATION = 0.45
const MANTLE_DISTANCE = 1.2
const MANTLE_ARC = 0.6


const JARAK_TEMPEL_TANGAN = 0.65
const RADIUS_PICKUP = 2.4

# =====================================
# NODE REFERENCES & EXPORTS
# =====================================

@export_group("Movement Tuning")
@export var walk_speed: float = SPEED
@export var run_speed: float = RUN_SPEED
@export var crouch_speed: float = CROUCH_SPEED
@export var jump_velocity: float = JUMP_VELOCITY
@export var walk_anim_reference_speed: float = WALK_ANIM_REF_SPEED
@export var run_anim_reference_speed: float = RUN_ANIM_REF_SPEED

@export_group("References")
@export var anim_player: AnimationPlayer = null
@export var visual_node: Node3D = null
@export var visual_scale := Vector3(2.2, 2.2, 2.2)
@export var carry_system: Node = null

@onready var body: Node3D = $body
@onready var hand: Marker3D = $body/Marker3D

@onready var wall_ray: RayCast3D = $WallRayCast3D
@onready var wall_back: RayCast3D = $WallRayBack

@onready var top_ray: RayCast3D = $WallTopRayCast3D
@onready var ledge_ray: RayCast3D = $LedgeRayCast3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# =====================================
# VARIABLES
# =====================================

var hint_label: Label = null

var item_dipegang: RigidBody3D = null
var skala_item_awal := Vector3.ONE
var objek_ditarik: RigidBody3D = null
var offset_pusat_objek := Vector3.ZERO
var arah_pegang_normal := Vector3.ZERO
var sedang_dorong := false

var toggle_lari_state := false
var sedang_lari := false
var sedang_jongkok := false
var sedang_memanjat := false
var sedang_mantle := false

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jump_cooldown_timer := 0.0
var has_jumped := false

var tinggi_berdiri := 1.8
var tinggi_jongkok := 0.9
var pos_y_collision_awal := 0.9
var skala_y_body_awal := 1.0
var pos_y_body_awal := 0.0

var wall_lock_timer := 0.0
var wall_normal := Vector3.ZERO
var ray_aktif: RayCast3D = null

var aksi_manjat := ""
var aksi_turun := ""

var mantle_start := Vector3.ZERO
var mantle_target := Vector3.ZERO
var mantle_timer := 0.0
var input_enabled: bool = true
var is_3d_mode: bool = false
var active_3d_camera: Camera3D = null
var _last_input_dir: Vector2 = Vector2.ZERO
var _use_latched_basis: bool = false
var _latched_basis_forward: Vector3 = Vector3.FORWARD
var _latched_basis_right: Vector3 = Vector3.RIGHT
var _was_in_3d_mode: bool = false

func enter_3d_mode(cam: Camera3D) -> void:
	if not is_3d_mode and _last_input_dir.length() > 0.1:
		# Kunci sumbu 2.5D sementara agar pemain tidak berbelok mendadak saat kamera berputar
		_latched_basis_forward = Vector3(0.0, 0.0, -1.0)
		_latched_basis_right = Vector3(1.0, 0.0, 0.0)
		_use_latched_basis = true
	is_3d_mode = true
	active_3d_camera = cam

func exit_3d_mode() -> void:
	if is_3d_mode and _last_input_dir.length() > 0.1 and is_instance_valid(active_3d_camera):
		var fwd := -active_3d_camera.global_transform.basis.z
		fwd.y = 0.0
		var rgt := active_3d_camera.global_transform.basis.x
		rgt.y = 0.0
		if fwd.length_squared() > 0.001 and rgt.length_squared() > 0.001:
			_latched_basis_forward = fwd.normalized()
			_latched_basis_right = rgt.normalized()
			_use_latched_basis = true
	is_3d_mode = false
	active_3d_camera = null

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_use_latched_basis = false
		if anim_player:
			if anim_player.has_animation("Idle"):
				anim_player.play("Idle", 0.15)
			elif anim_player.has_animation("idle"):
				anim_player.play("idle", 0.15)



# =====================================
# READY & SETUP
# =====================================

func _ready() -> void:
	floor_snap_length = 0.4
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(45.0)

	if visual_node == null:
		visual_node = get_node_or_null("../char no light")
	if visual_node == null:
		visual_node = get_node_or_null("char no light")
	if visual_node == null:
		var fbx := load("res://assets/characters/mc/char_no_light.fbx") as PackedScene
		if fbx:
			var v := fbx.instantiate() as Node3D
			v.name = "char no light"
			v.scale = visual_scale
			add_child(v)
			visual_node = v
			var ap := v.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap:
				var anim_lib := load("res://animations/mc/merged_animations.tres") as AnimationLibrary
				if anim_lib:
					if ap.has_animation_library(""):
						ap.remove_animation_library("")
					ap.add_animation_library("", anim_lib)
				anim_player = ap

	if anim_player == null and visual_node:
		anim_player = visual_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		anim_player = get_node_or_null("char no light/AnimationPlayer")
	if anim_player == null:
		anim_player = get_node_or_null("../char no light/AnimationPlayer")
	if anim_player == null:
		anim_player = find_child("AnimationPlayer") as AnimationPlayer

	if anim_player:
		if not anim_player.has_animation("idle") or not anim_player.has_animation("Walk"):
			var anim_lib := load("res://animations/mc/merged_animations.tres") as AnimationLibrary
			if anim_lib:
				if anim_player.has_animation_library(""):
					anim_player.remove_animation_library("")
				anim_player.add_animation_library("", anim_lib)
		if not anim_player.has_animation_library("idle (2)"):
			var idle_lib := load("res://animations/mc/clips/idle (2).fbx") as AnimationLibrary
			if idle_lib:
				anim_player.add_animation_library("idle (2)", idle_lib)

	# Pastikan visual node proporsional
	if visual_node:
		visual_node.scale = visual_scale

	if carry_system == null:
		carry_system = get_node_or_null("CarrySystem")
	if carry_system == null:
		carry_system = get_node_or_null("../Chapter1PuzzleManager/CarrySystem")
	if carry_system == null:
		carry_system = get_node_or_null("../CarrySystem")

	if carry_system:
		if carry_system.has_signal("item_picked_up") and not carry_system.is_connected("item_picked_up", Callable(self, "_on_carry_item_picked_up")):
			carry_system.connect("item_picked_up", Callable(self, "_on_carry_item_picked_up"))
		if carry_system.has_signal("item_dropped") and not carry_system.is_connected("item_dropped", Callable(self, "_on_carry_item_dropped")):
			carry_system.connect("item_dropped", Callable(self, "_on_carry_item_dropped"))

	# Fallback resolusi node-node esensial jika di-instantiate di scene baru (cth: chapter_2)
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape and collision_shape.shape == null:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.65
		cap.height = 3.6
		collision_shape.shape = cap
	if body == null:
		body = get_node_or_null("body") as Node3D
	if hand == null and body:
		hand = body.get_node_or_null("Marker3D") as Marker3D
	if wall_ray == null:
		wall_ray = get_node_or_null("WallRayCast3D") as RayCast3D
	if wall_back == null:
		wall_back = get_node_or_null("WallRayBack") as RayCast3D
	if top_ray == null:
		top_ray = get_node_or_null("WallTopRayCast3D") as RayCast3D
	if ledge_ray == null:
		ledge_ray = get_node_or_null("LedgeRayCast3D") as RayCast3D

	var bentuk = collision_shape.shape if collision_shape else null
	if bentuk is CapsuleShape3D:
		tinggi_berdiri = (bentuk as CapsuleShape3D).height
	elif bentuk is CylinderShape3D:
		tinggi_berdiri = (bentuk as CylinderShape3D).height
	elif bentuk is BoxShape3D:
		tinggi_berdiri = (bentuk as BoxShape3D).size.y

	tinggi_jongkok = tinggi_berdiri * CROUCH_HEIGHT_RATIO
	pos_y_collision_awal = collision_shape.position.y
	skala_y_body_awal = body.scale.y
	pos_y_body_awal = body.position.y

	setup_ui_hint()
	setup_animation_blends()


func setup_animation_blends() -> void:
	if anim_player == null:
		return

	anim_player.playback_default_blend_time = 0.22

	var blends := [
		["Idle", "Walk", 0.22],
		["Walk", "Idle", 0.25],
		["Walk", "Run", 0.18],
		["Run", "Walk", 0.22],
		["Idle", "Run", 0.18],
		["Run", "Idle", 0.25],
		["Idle", "Jump", 0.12],
		["Walk", "Jump", 0.12],
		["Run", "Jump", 0.12],
		["Jump", "Fall", 0.18],
		["Fall", "Land", 0.08],
		["Land", "Idle", 0.22],
		["Land", "Walk", 0.18],
		["Idle", "CrouchIdle", 0.20],
		["CrouchIdle", "Idle", 0.22],
		["CrouchIdle", "CrouchWalk", 0.18],
		["CrouchWalk", "CrouchIdle", 0.22],
		["Idle", "Carrying", 0.22],
		["Carrying", "Idle", 0.25],
		["Carrying", "CarryWalk", 0.20],
		["CarryWalk", "Carrying", 0.25],
		["Idle", "Climb", 0.18],
		["Climb", "Idle", 0.22],
		["Climb", "ClimbUp", 0.15],
		["ClimbUp", "Idle", 0.20],
		["Idle", "ClimbDown", 0.18],
		["ClimbDown", "Idle", 0.22],
		["Idle", "Push", 0.18],
		["Push", "Idle", 0.22],
		["Idle", "Pull", 0.18],
		["Pull", "Idle", 0.22],
		["Fall", "Roll", 0.10],
		["Roll", "Idle", 0.20],
	]

	for pair in blends:
		var from_anim: String = pair[0]
		var to_anim: String = pair[1]
		var duration: float = pair[2]
		if anim_player.has_animation(from_anim) and anim_player.has_animation(to_anim):
			anim_player.set_blend_time(from_anim, to_anim, duration)
			anim_player.set_blend_time(to_anim, from_anim, duration)


func setup_ui_hint() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "InteractHUD"
	canvas.layer = 20
	add_child(canvas)

	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.offset_bottom = -80.0
	hint_label.text = "[E] Ambil"

	var settings := LabelSettings.new()
	settings.font_size = 20
	settings.font_color = Color(0.95, 0.95, 1.0)
	settings.outline_size = 6
	settings.outline_color = Color(0.05, 0.05, 0.08, 0.9)
	hint_label.label_settings = settings
	hint_label.visible = false
	canvas.add_child(hint_label)


# =====================================
# 360-DEGREE PICKUP & INTERACT
# =====================================

func cari_item_pickup_terdekat(radius: float = RADIUS_PICKUP) -> RigidBody3D:
	var shape := SphereShape3D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (0.8 * scale.y))
	query.exclude = [get_rid()]

	var hasil_list := get_world_3d().direct_space_state.intersect_shape(query)
	var item_terdekat: RigidBody3D = null
	var jarak_terdekat := INF

	for item in hasil_list:
		var collider = item.collider
		if collider is RigidBody3D and (collider.is_in_group("pickup") or collider.is_in_group("teddy_bear") or collider.is_in_group("carryable") or collider.is_in_group("puzzle_block")):
			var jarak := global_position.distance_to(collider.global_position)
			if jarak < jarak_terdekat:
				jarak_terdekat = jarak
				item_terdekat = collider

	return item_terdekat


func update_interact_hint() -> void:
	if hint_label == null:
		return

	if item_dipegang != null:
		hint_label.text = "[E] Letakkan"
		hint_label.visible = true
		return

	if objek_ditarik != null:
		hint_label.text = "[F/E] Lepas Pegangan"
		hint_label.visible = true
		return

	if cari_item_pickup_terdekat() != null:
		hint_label.text = "[E] Ambil"
		hint_label.visible = true
		return

	var cek_tarik := cek_ray_objek_tarik()
	if not cek_tarik.is_empty():
		hint_label.text = "[F/E] Tarik / Dorong"
		hint_label.visible = true
		return

	hint_label.visible = false


func _on_carry_item_picked_up(item: RigidBody3D) -> void:
	item_dipegang = item
	update_interact_hint()

func _on_carry_item_dropped(_item: RigidBody3D, _pos: Vector3) -> void:
	item_dipegang = null
	update_interact_hint()


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event.is_action_pressed("shifting") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode == KEY_T or event.physical_keycode == KEY_T)
	):
		var wm = get_node_or_null("../")
		if wm and wm.has_method("toggle_dimension"):
			wm.call("toggle_dimension")

	# Input Dorong / Tarik (Tombol F atau tombol interact E jika di depan objek tarik)
	if event.is_action_pressed("tarik"):
		if objek_ditarik != null:
			lepas_objek_tarik()
			update_interact_hint()
			return
		elif item_dipegang == null:
			if coba_pegang_objek_tarik():
				update_interact_hint()
				return

	if not event.is_action_pressed("interact") or event.is_echo():
		return

	# Jika sedang memegang objek tarik, tekan E juga melepas pegangan
	if objek_ditarik != null:
		lepas_objek_tarik()
		update_interact_hint()
		return

	# E saat membawa barang: taruh dulu, tanpa cek jarak pickup.
	if item_dipegang != null:
		taruh_item()
		return

	# E saat dekat barang pickup: ambil barang.
	if cari_item_pickup_terdekat() != null:
		ambil_item()
		return


func ambil_item() -> void:
	if sedang_jongkok or item_dipegang != null:
		return

	var benda := cari_item_pickup_terdekat()
	if benda != null:
		item_dipegang = benda
		skala_item_awal = item_dipegang.scale

		# Putar badan menghadap objek secara mulus agar tangan terarah mengambilnya
		var arah_ke_benda := (benda.global_position - global_position)
		arah_ke_benda.y = 0.0
		if arah_ke_benda.length_squared() > 0.01:
			body.rotation.y = atan2(arah_ke_benda.x, arah_ke_benda.z)
			if visual_node:
				visual_node.rotation.y = body.rotation.y

		if carry_system and carry_system.has_method("pick_up"):
			carry_system.call("pick_up", item_dipegang)
		else:
			item_dipegang.freeze = true
			var col := item_dipegang.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col:
				col.disabled = true

		update_interact_hint()


func taruh_item() -> void:
	var benda := item_dipegang
	item_dipegang = null

	if benda != null:
		var arah_depan := body.global_transform.basis.z.normalized()
		var pos_target := global_position + (arah_depan * 1.0) + (Vector3.UP * 0.2)

		if carry_system and carry_system.has_method("drop"):
			carry_system.call("drop", pos_target)
		else:
			benda.scale = skala_item_awal
			benda.freeze = false
			benda.global_position = pos_target
			benda.linear_velocity = arah_depan * 1.0
			benda.angular_velocity = Vector3.ZERO
			var col := benda.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col:
				col.set_deferred("disabled", false)

		update_interact_hint()


# =====================================
# PUSH & PULL SYSTEM
# =====================================

func cek_ray_objek_tarik() -> Dictionary:
	var arah_hadap := body.global_transform.basis.z
	arah_hadap.y = 0.0
	arah_hadap = arah_hadap.normalized()

	var space_state := get_world_3d().direct_space_state
	var ketinggian_cek: Array[float] = [0.3, 0.6, 0.9, 1.2]

	# 1. Cek raycast lurus ke depan di berbagai ketinggian untuk objek ber-grup "tarik" / "pushable" / "puzzle_block"
	for h in ketinggian_cek:
		var titik_awal: Vector3 = global_position + Vector3.UP * h
		var titik_akhir: Vector3 = titik_awal + arah_hadap * 2.5
		var query := PhysicsRayQueryParameters3D.create(titik_awal, titik_akhir)
		query.exclude = [get_rid()]
		var cek := space_state.intersect_ray(query)
		if not cek.is_empty():
			var col = cek.collider
			if col is RigidBody3D and (col.is_in_group("tarik") or col.is_in_group("pushable") or col.is_in_group("puzzle_block")):
				return cek

	# 2. Toleransi kedekatan: jika pemain berdiri dekat balok dan menghadap ke arahnya
	var candidate_groups: Array[String] = ["tarik", "pushable", "puzzle_block"]
	for grp in candidate_groups:
		for b in get_tree().get_nodes_in_group(grp):
			var rb := b as RigidBody3D
			if rb and not rb.freeze:
				var jarak := global_position.distance_to(rb.global_position)
				if jarak < 3.2:
					var ke_objek := (rb.global_position - global_position).normalized()
					ke_objek.y = 0.0
					if arah_hadap.dot(ke_objek) > 0.1:
						var titik_awal: Vector3 = global_position + Vector3.UP * 0.5
						var titik_akhir: Vector3 = rb.global_position + Vector3.UP * 0.5
						var query := PhysicsRayQueryParameters3D.create(titik_awal, titik_akhir)
						query.exclude = [get_rid()]
						var cek := space_state.intersect_ray(query)
						if not cek.is_empty() and cek.collider == rb:
							return cek
						elif cek.is_empty():
							return {"collider": rb, "normal": -ke_objek, "position": rb.global_position}
	return {}


func coba_pegang_objek_tarik() -> bool:
	if sedang_memanjat or sedang_mantle or sedang_jongkok or not is_on_floor():
		return false

	var hasil := cek_ray_objek_tarik()
	if hasil.is_empty():
		return false

	var collider = hasil.collider
	if collider is RigidBody3D and (collider.is_in_group("tarik") or collider.is_in_group("pushable") or collider.is_in_group("puzzle_block")):
		objek_ditarik = collider as RigidBody3D
		arah_pegang_normal = -hasil.normal
		arah_pegang_normal.y = 0.0
		if arah_pegang_normal.length_squared() < 0.01:
			arah_pegang_normal = (objek_ditarik.global_position - global_position).normalized()
			arah_pegang_normal.y = 0.0
		arah_pegang_normal = arah_pegang_normal.normalized()

		body.rotation.y = atan2(arah_pegang_normal.x, arah_pegang_normal.z)
		if visual_node:
			visual_node.rotation.y = body.rotation.y

		offset_pusat_objek = Vector3(
			objek_ditarik.global_position.x - global_position.x,
			0.0,
			objek_ditarik.global_position.z - global_position.z
		)
		objek_ditarik.freeze = false
		update_interact_hint()
		return true
	return false


func lepas_objek_tarik() -> void:
	if objek_ditarik != null:
		objek_ditarik.linear_velocity = Vector3.ZERO
		objek_ditarik = null
		update_interact_hint()


# =====================================
# CROUCH LOGIC & CEILING CHECK
# =====================================

func bisa_berdiri() -> bool:
	var selisih_tinggi := tinggi_berdiri - tinggi_jongkok
	var asal := global_position + Vector3.UP * pos_y_collision_awal
	var tujuan := asal + Vector3.UP * (selisih_tinggi + 0.1)

	var query := PhysicsRayQueryParameters3D.create(asal, tujuan)
	query.exclude = [get_rid()]
	var hasil := get_world_3d().direct_space_state.intersect_ray(query)
	return hasil.is_empty()


func proses_jongkok(delta: float, ingin_jongkok: bool) -> void:
	if ingin_jongkok:
		sedang_jongkok = true
		sedang_lari = false
	elif sedang_jongkok and bisa_berdiri():
		sedang_jongkok = false

	var target_tinggi := tinggi_jongkok if sedang_jongkok else tinggi_berdiri
	var target_skala_y := (skala_y_body_awal * CROUCH_HEIGHT_RATIO) if sedang_jongkok else skala_y_body_awal

	var bentuk = collision_shape.shape
	if bentuk is CapsuleShape3D:
		var kapsul := bentuk as CapsuleShape3D
		kapsul.height = lerpf(kapsul.height, target_tinggi, CROUCH_TRANSITION_SPEED * delta)
		var selisih := tinggi_berdiri - kapsul.height
		collision_shape.position.y = pos_y_collision_awal - (selisih / 2.0)
	elif bentuk is CylinderShape3D:
		var silinder := bentuk as CylinderShape3D
		silinder.height = lerpf(silinder.height, target_tinggi, CROUCH_TRANSITION_SPEED * delta)
		var selisih := tinggi_berdiri - silinder.height
		collision_shape.position.y = pos_y_collision_awal - (selisih / 2.0)

	body.scale.y = lerpf(body.scale.y, target_skala_y, CROUCH_TRANSITION_SPEED * delta)
	var selisih_visual := (tinggi_berdiri * (1.0 - (body.scale.y / skala_y_body_awal))) / 2.0
	body.position.y = pos_y_body_awal - selisih_visual


# =====================================
# CLIMB PERMISSION CHECK — HANYA objek dengan grup "meja" atau "climbable"
# =====================================

## Mengecek apakah objek yang terdeteksi ray boleh dipanjat.
## HANYA mengizinkan objek yang terdaftar di grup "meja" atau "climbable".
## Menolak: tembok, dinding, pembatas, kusen, pintu, dan segala objek lainnya.
func _is_climbable_surface(collider: Object) -> bool:
	if collider == null:
		return false
	if not (collider is Node):
		return false
	var col_node := collider as Node
	# Cek langsung pada collider
	if col_node.is_in_group("meja") or col_node.is_in_group("climbable"):
		return true
	# Cek parent collider (misalnya StaticBody3D di dalam objek meja)
	var parent: Node = col_node.get_parent()
	if parent and (parent.is_in_group("meja") or parent.is_in_group("climbable")):
		return true
	# Cek grandparent (misalnya collider di dalam StaticBody3D di dalam scene meja)
	if parent:
		var grandparent: Node = parent.get_parent()
		if grandparent and (grandparent.is_in_group("meja") or grandparent.is_in_group("climbable")):
			return true
	# Default: TOLAK memanjat
	return false


# =====================================
# WALL DETECTION & MANTLE (RESTRICTED)
# =====================================

func get_character_half_height() -> float:
	var bentuk = collision_shape.shape
	if bentuk is CapsuleShape3D:
		return ((bentuk as CapsuleShape3D).height * scale.y) / 2.0
	elif bentuk is CylinderShape3D:
		return ((bentuk as CylinderShape3D).height * scale.y) / 2.0
	elif bentuk is BoxShape3D:
		return ((bentuk as BoxShape3D).size.y * scale.y) / 2.0
	return 1.8


func deteksi_tembok() -> void:
	ray_aktif = null
	aksi_manjat = ""
	aksi_turun = ""

	if objek_ditarik != null:
		return

	var daftar_ray := [wall_ray, wall_back]
	var jarak_terdekat := INF
	var kandidat_ray: RayCast3D = null

	for ray in daftar_ray:
		if ray == null:
			continue
		ray.force_raycast_update()
		if ray.is_colliding():
			# === CLIMB RESTRICTION ===
			# Cek apakah collider yang terdeteksi boleh dipanjat
			var collider: Object = ray.get_collider()
			if not _is_climbable_surface(collider):
				continue  # Abaikan — bukan permukaan climbable
			# === END RESTRICTION ===
			var jarak := global_position.distance_to(ray.get_collision_point())
			if jarak < jarak_terdekat:
				jarak_terdekat = jarak
				kandidat_ray = ray

	if kandidat_ray == null:
		return

	if not sedang_memanjat and top_ray != null:
		var jarak_ray := absf(kandidat_ray.target_position.z)
		top_ray.target_position = Vector3(0.0, 0.0, -jarak_ray if kandidat_ray == wall_ray else jarak_ray)
		top_ray.force_raycast_update()
		if not top_ray.is_colliding():
			return

	ray_aktif = kandidat_ray
	if ray_aktif == wall_ray:
		aksi_manjat = "maju"
		aksi_turun = "mundur"
	elif ray_aktif == wall_back:
		aksi_manjat = "mundur"
		aksi_turun = "maju"


func cari_target_mantle() -> bool:
	if ray_aktif == null:
		return false

	# === MANTLE RESTRICTION ===
	# Double-check: pastikan collider memang climbable sebelum mantle
	var collider: Object = ray_aktif.get_collider()
	if not _is_climbable_surface(collider):
		return false
	# === END RESTRICTION ===

	wall_normal = ray_aktif.get_collision_normal()
	var arah_tembok := -wall_normal
	arah_tembok.y = 0.0
	arah_tembok = arah_tembok.normalized()

	var tinggi := get_character_half_height()
	var origin := global_position + Vector3.UP * tinggi * 0.8
	var query_depan := PhysicsRayQueryParameters3D.create(origin, origin + arah_tembok * 1.5, ray_aktif.collision_mask)
	query_depan.exclude = [get_rid()]

	var hasil_depan := get_world_3d().direct_space_state.intersect_ray(query_depan)
	if not hasil_depan.is_empty():
		return false

	var titik_awal := global_position + arah_tembok * MANTLE_DISTANCE + Vector3.UP * (tinggi + 1.2)
	var titik_akhir := titik_awal + Vector3.DOWN * (tinggi + 3.5)
	var query_bawah := PhysicsRayQueryParameters3D.create(titik_awal, titik_akhir, ray_aktif.collision_mask)
	query_bawah.exclude = [get_rid()]

	var hasil_bawah := get_world_3d().direct_space_state.intersect_ray(query_bawah)
	if hasil_bawah.is_empty():
		return false

	var titik_lantai: Vector3 = hasil_bawah.position
	if titik_lantai.y < global_position.y - tinggi - 0.2:
		return false

	mantle_target = titik_lantai + Vector3.UP * (tinggi + 0.05) + arah_tembok * 0.2
	return true


func mulai_mantle() -> void:
	mantle_start = global_position
	mantle_timer = 0.0
	sedang_mantle = true
	sedang_memanjat = false
	velocity = Vector3.ZERO



func proses_mantle(delta: float) -> void:
	mantle_timer += delta
	var progress := clampf(mantle_timer / MANTLE_DURATION, 0.0, 1.0)
	var posisi_baru := mantle_start.lerp(mantle_target, progress)
	posisi_baru.y += sin(progress * PI) * MANTLE_ARC
	global_position = posisi_baru


	if progress >= 1.0:
		global_position = mantle_target
		sedang_mantle = false
		sedang_memanjat = false
		wall_lock_timer = 0.2
		velocity = Vector3.ZERO


# =====================================
# MAIN PHYSICS PROCESS
# =====================================

func _physics_process(delta: float) -> void:
	if not input_enabled:
		if not is_on_floor():
			velocity += get_gravity() * delta * FALL_GRAVITY_MULT
		else:
			velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
			velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
		move_and_slide()
		return

	wall_lock_timer = maxf(wall_lock_timer - delta, 0.0)
	jump_cooldown_timer = maxf(jump_cooldown_timer - delta, 0.0)

	# 1. Coyote Time & Jump Buffer (strictly single-jump: never re-arm while rising or inside cooldown)
	if is_on_floor() and velocity.y <= 0.05 and jump_cooldown_timer <= 0.0:
		has_jumped = false
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	# 2. Lari: tahan Shift untuk sprint, atau tap Q untuk toggle lari
	if Input.is_key_pressed(KEY_SHIFT):
		toggle_lari_state = false
		sedang_lari = not sedang_jongkok and objek_ditarik == null
	else:
		if Input.is_action_just_pressed("toogle-lari"):
			toggle_lari_state = not toggle_lari_state
		sedang_lari = toggle_lari_state and not sedang_jongkok and objek_ditarik == null

	# 3. Mantle Handle
	if sedang_mantle:
		proses_mantle(delta)
		return

	# 4. Input Direction (WASD & Arrow Keys)
	var input_dir := Input.get_vector("kiri", "kanan", "maju", "mundur")

	# 5. Push & Pull Mode — gerak bebas di bidang lantai dengan animasi Push/Pull
	if objek_ditarik != null:
		if not is_on_floor() or Input.is_action_just_pressed("lompat") or (objek_ditarik is RigidBody3D and (objek_ditarik as RigidBody3D).freeze):
			lepas_objek_tarik()
		else:
			# Pemain tetap menghadap arah pegang benda
			var target_angle := atan2(arah_pegang_normal.x, arah_pegang_normal.z)
			body.rotation.y = lerp_angle(body.rotation.y, target_angle, TURN_SPEED * delta)

			# Input kiri/kanan dan maju/mundur menjadi gerakan dunia
			var arah_gerak := Vector3(input_dir.x, 0.0, input_dir.y)
			if arah_gerak.length_squared() > 1.0:
				arah_gerak = arah_gerak.normalized()

			velocity.x = arah_gerak.x * PULL_SPEED
			velocity.z = arah_gerak.z * PULL_SPEED
			velocity.y = 0.0

			# Arah gerak menentukan animasi dorong (maju) atau tarik (mundur)
			var maju_mundur := arah_gerak.dot(arah_pegang_normal)
			sedang_dorong = maju_mundur > 0.05

			move_and_slide()

			# Posisi balok mengikuti gerakan pemain dengan jarak offset stabil
			var target_block_pos := Vector3(
				global_position.x + offset_pusat_objek.x,
				objek_ditarik.global_position.y,
				global_position.z + offset_pusat_objek.z
			)
			objek_ditarik.global_position.x = lerpf(objek_ditarik.global_position.x, target_block_pos.x, 25.0 * delta)
			objek_ditarik.global_position.z = lerpf(objek_ditarik.global_position.z, target_block_pos.z, 25.0 * delta)
			objek_ditarik.linear_velocity = Vector3.ZERO

			var jarak_sekarang := Vector2(
				global_position.x - (objek_ditarik.global_position.x - offset_pusat_objek.x),
				global_position.z - (objek_ditarik.global_position.z - offset_pusat_objek.z)
			).length()

			if jarak_sekarang > 3.0:
				lepas_objek_tarik()

			if visual_node:
				visual_node.global_position = global_position
				visual_node.rotation.y = body.rotation.y

			_update_animation_playback(delta)
			update_interact_hint()
			return

	# 6. Wall Detection & Climbing (RESTRICTED to climbable surfaces only)
	deteksi_tembok()
	var ada_tembok := (ray_aktif != null and wall_lock_timer <= 0.0)

	if ada_tembok:
		var was_climbing := sedang_memanjat
		proses_jongkok(delta, false)
		wall_normal = ray_aktif.get_collision_normal()
		sedang_memanjat = true

		# Hanya lepas mundur dari objek panjat jika sudah benar-benar menempel;
		# tanpa dorongan vertikal tambahan agar tidak berfungsi sebagai double jump.
		if was_climbing and Input.is_action_just_pressed("ui_accept"):
			velocity = wall_normal * (WALL_JUMP_PUSH * 0.5)
			sedang_memanjat = false
			has_jumped = true
			jump_buffer_timer = 0.0
			wall_lock_timer = WALL_JUMP_LOCK
			move_and_slide()
			return

		var arah_tempel := -wall_normal
		arah_tempel.y = 0.0
		arah_tempel = arah_tempel.normalized()

		var arah_samping := transform.basis.x
		arah_samping.y = 0.0
		arah_samping = arah_samping.normalized()
		var input_samping := Input.get_axis("kiri", "kanan")

		var gerakan_horizontal := arah_tempel * WALL_STICK_SPEED + arah_samping * input_samping * WALL_STRAFE_SPEED
		velocity.x = gerakan_horizontal.x
		velocity.z = gerakan_horizontal.z

		if Input.is_action_pressed(aksi_manjat):
			velocity.y = CLIMB_SPEED
		elif Input.is_action_pressed(aksi_turun):
			velocity.y = -CLIMB_SPEED
		else:
			velocity.y = 0.0

		if Input.is_action_pressed(aksi_manjat) and cari_target_mantle():
			mulai_mantle()
			return

		move_and_slide()
		if visual_node:
			visual_node.global_position = global_position
			visual_node.rotation.y = body.rotation.y
		_update_animation_playback(delta)
		update_interact_hint()
		return

	# 7. Normal Movement
	sedang_memanjat = false
	var tahan_jongkok := Input.is_action_pressed("jongkok")
	proses_jongkok(delta, tahan_jongkok)

	# Gravity dengan bobot jatuh responsif (fall gravity)
	if not is_on_floor():
		var grav := get_gravity()
		if velocity.y < 0.0:
			grav *= FALL_GRAVITY_MULT
		velocity += grav * delta

	# Jump Execution (Coyote Time + Buffer, strictly once per grounded state)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not has_jumped and jump_cooldown_timer <= 0.0 and not sedang_jongkok:
		velocity.y = jump_velocity
		has_jumped = true
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jump_cooldown_timer = JUMP_COOLDOWN

	# Variable Jump Cut
	if Input.is_action_just_released("ui_accept") and velocity.y > 0.0:
		velocity.y *= JUMP_CUT_MULT

	# Target Speed
	var kecepatan_sekarang := walk_speed
	if sedang_jongkok:
		kecepatan_sekarang = crouch_speed
	elif sedang_lari:
		kecepatan_sekarang = run_speed

	var input_vec := _compute_move_vector(input_dir)
	var move_len := input_vec.length()

	if move_len > 1.0:
		input_vec = input_vec.normalized()

	var target_vel_x := input_vec.x * kecepatan_sekarang
	var target_vel_z := input_vec.z * kecepatan_sekarang

	var current_accel: float
	if is_on_floor():
		current_accel = ACCELERATION if move_len > 0.05 else DECELERATION
	else:
		current_accel = AIR_ACCEL if move_len > 0.05 else AIR_DECEL

	velocity.x = move_toward(velocity.x, target_vel_x, current_accel * delta)
	velocity.z = move_toward(velocity.z, target_vel_z, current_accel * delta)

	# Putar badan menghadap arah gerak secara mulus dan responsif
	if move_len > 0.1:
		var target_angle := atan2(input_vec.x, input_vec.z)
		body.rotation.y = lerp_angle(body.rotation.y, target_angle, TURN_SPEED * delta)

	move_and_slide()

	# Dorong objek fisika yang bisa digeser ketika berjalan menabraknya langsung
	if objek_ditarik == null and is_on_floor():
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var collider: Object = col.get_collider()
			if collider is RigidBody3D and (collider as RigidBody3D).is_in_group("tarik"):
				var norm := col.get_normal()
				var push_dir := -Vector3(norm.x, 0.0, norm.z).normalized()
				var push_force: float = (run_speed if sedang_lari else walk_speed) * 55.0
				(collider as RigidBody3D).apply_central_force(push_dir * push_force)

	if visual_node:
		visual_node.global_position = global_position
		visual_node.rotation.y = body.rotation.y

	_update_animation_playback(delta)
	update_interact_hint()


# =====================================
# ANIMATION STATE MACHINE & SMOOTH BLEND
# =====================================

func _update_animation_playback(_delta: float) -> void:
	if anim_player == null:
		return

	var horizontal_spd := Vector2(velocity.x, velocity.z).length()
	var target_anim := "Idle"

	if sedang_memanjat:
		# Gunakan animasi climb yang sesuai arah gerakan vertikal
		if velocity.y > 0.3:
			target_anim = "ClimbUp" if anim_player.has_animation("ClimbUp") else "Climb"
		elif velocity.y < -0.3:
			target_anim = "ClimbDown" if anim_player.has_animation("ClimbDown") else "Climb"
		else:
			target_anim = "Climb"
	elif sedang_mantle:
		target_anim = "ClimbUp"
	elif objek_ditarik != null:
		if horizontal_spd > 0.15:
			target_anim = "Push" if sedang_dorong else "Pull"
		else:
			target_anim = "Idle"
	elif item_dipegang != null:
		target_anim = "CarryWalk" if horizontal_spd > 0.15 else "Carrying"
	elif sedang_jongkok:
		target_anim = "CrouchWalk" if horizontal_spd > 0.15 else "CrouchIdle"
	elif not is_on_floor():
		if velocity.y > 0.6:
			target_anim = "Jump"
		else:
			target_anim = "Fall"
	else:
		# Hysteresis pencegah kedip animasi Idle <-> Walk/Run
		var curr := anim_player.current_animation
		if curr in ["Walk", "Run"]:
			if horizontal_spd < 0.12:
				target_anim = "Idle"
			else:
				target_anim = "Run" if sedang_lari else "Walk"
		else:
			if horizontal_spd > 0.22:
				target_anim = "Run" if sedang_lari else "Walk"
			else:
				target_anim = "Idle"

	if anim_player.has_animation(target_anim):
		if anim_player.current_animation != target_anim:
			var blend_duration := 0.22
			if target_anim == "Jump":
				blend_duration = 0.12
			elif target_anim == "Land":
				blend_duration = 0.08
			elif target_anim in ["Climb", "ClimbUp", "ClimbDown"]:
				blend_duration = 0.15
			anim_player.play(target_anim, blend_duration)

	# Sinkronisasi kecepatan animasi dengan panjang langkah kaki sebenarnya agar tidak meluncur
	if anim_player.current_animation == "Walk":
		anim_player.speed_scale = clampf(horizontal_spd / maxf(walk_anim_reference_speed, 0.5), 0.42, 1.30)
	elif anim_player.current_animation == "Run":
		anim_player.speed_scale = clampf(horizontal_spd / maxf(run_anim_reference_speed, 0.5), 0.65, 1.35)
	elif anim_player.current_animation == "CarryWalk":
		anim_player.speed_scale = clampf(horizontal_spd / maxf(walk_speed * 0.85, 0.5), 0.75, 1.30)
	elif anim_player.current_animation == "CrouchWalk":
		anim_player.speed_scale = clampf(horizontal_spd / maxf(crouch_speed, 0.5), 0.75, 1.30)
	elif anim_player.current_animation in ["Climb", "ClimbUp", "ClimbDown"]:
		anim_player.speed_scale = clampf(absf(velocity.y) / CLIMB_SPEED, 0.5, 1.2)
	else:
		anim_player.speed_scale = 1.0


## Menghitung vektor gerak 2.5D atau 3D kamera-relatif dengan basis-latch agar transisi sudut kamera tidak membelokkan arah gerak mendadak.
func _compute_move_vector(input_dir: Vector2) -> Vector3:
	if input_dir.length() < 0.08:
		_use_latched_basis = false
		_last_input_dir = Vector2.ZERO
		return Vector3.ZERO

	if _use_latched_basis and _last_input_dir.length() > 0.1 and input_dir.normalized().dot(_last_input_dir.normalized()) < 0.45:
		_use_latched_basis = false

	_last_input_dir = input_dir

	if _use_latched_basis:
		return (_latched_basis_right * input_dir.x) + (_latched_basis_forward * -input_dir.y)

	if is_3d_mode and is_instance_valid(active_3d_camera):
		var cam_forward := -active_3d_camera.global_transform.basis.z
		cam_forward.y = 0.0
		var cam_right := active_3d_camera.global_transform.basis.x
		cam_right.y = 0.0
		if cam_forward.length_squared() > 0.001 and cam_right.length_squared() > 0.001:
			cam_forward = cam_forward.normalized()
			cam_right = cam_right.normalized()
			return (cam_right * input_dir.x) + (cam_forward * -input_dir.y)

	return Vector3(input_dir.x, 0.0, input_dir.y * DEPTH_RATIO)
