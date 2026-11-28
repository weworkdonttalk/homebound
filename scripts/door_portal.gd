class_name DoorPortal
extends Area3D

# ============================================================================
# DoorPortal — Cinematic Door & Scene Transition (Chapter 1 -> Chapter 2)
# Mengatur cutscene sinematik 4 fase:
# 1. Kunci kontrol & hadapkan karakter ke pintu kayu (0.0s)
# 2. Kamera Over-the-Shoulder sinematik (0.0s - 0.7s)
# 3. Pintu kayu berayun terbuka via DoorHinge & cahaya menyala DoorInnerGlow (0.7s - 1.9s)
# 4. Karakter melangkah masuk & efek cahaya silau putih-keemasan penuh layar (1.9s - 3.4s)
#    lalu transisi scene ke res://scenes/levels/chapter_2.tscn.
# ============================================================================

signal transition_started
signal transition_finished
signal door_opened
signal door_closed

@export_group("Scene Transition")
## Path scene tujuan berikutnya
@export_file("*.tscn") var target_scene_path: String = "res://scenes/levels/chapter_2.tscn"

## Apakah pintu terkunci (pintu keluar Chapter 2 terkunci di awal)
@export var is_locked: bool = false

## Durasi ayunan buka pintu (Fase 3, detik)
@export var open_duration: float = 1.2

## Sudut bukaan pintu (derajat) — 100° ke arah dalam ruangan
@export var open_angle_degrees: float = 100.0

## Intensitas cahaya hangat memancar saat pintu terbuka penuh (Fase 3)
@export var glow_energy: float = 12.0

## Durasi fade cahaya silau putih (detik)
@export var fade_duration: float = 0.9

## Jarak deteksi langsung ke pusat pintu kayu (meter) sebagai pengaman ganda
@export var trigger_distance_threshold: float = 1.8

@export_group("Node References")
## Node engsel daun pintu (Object_3 berada di bawah DoorHinge)
@export var door_hinge: Node3D = null

## Lampu sorot/pendar cahaya hangat di balik pintu
@export var door_inner_glow: Light3D = null

## Label petunjuk interaksi [E] Masuk
@export var interaction_prompt: Label3D = null

## Rig kamera yang dinonaktifkan tracking-nya saat cutscene
@export var camera_rig: Node3D = null

## Target player (CharacterBody3D)
@export var player: CharacterBody3D = null

## CanvasLayer fade overlay
@export var fade_layer: CanvasLayer = null

## ColorRect fade overlay
@export var fade_rect: ColorRect = null

# State Flags
var is_triggered: bool = false
var is_open: bool = false
var _player_in_zone: bool = false
var _is_preloading: bool = false
var _base_hinge_rotation: Vector3 = Vector3.ZERO
var _door_center_world: Vector3 = Vector3.ZERO
var _door_width: float = 1.6
var _door_height: float = 2.8
var _door_min_y: float = 0.0
var _door_facing_x: float = 1.0
var _blinding_quad: MeshInstance3D = null
var _blinding_quad_mat: StandardMaterial3D = null
var _blinding_spot: SpotLight3D = null

func _preload_target_scene() -> void:
	if _is_preloading:
		return
	_is_preloading = true
	var target := target_scene_path if not target_scene_path.is_empty() else "res://scenes/levels/chapter_2.tscn"
	if ResourceLoader.exists(target):
		ResourceLoader.load_threaded_request(target)
		print("[DoorPortal] Background preloading dimulai untuk: ", target)

func _ready() -> void:
	monitoring = true
	collision_mask = 0xFFFFFFFF
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_door_hinge()
	_setup_components()
	_setup_fade_overlay()

func _setup_door_hinge() -> void:
	# Jika door_hinge sudah ada dan valid, tidak perlu buat ulang
	if door_hinge and is_instance_valid(door_hinge) and door_hinge.get_parent() == self:
		return

	# Cek apakah ada DoorHinge lama yang tertinggal di child DoorPortal
	var existing_hinge := get_node_or_null("DoorHinge") as Node3D
	if existing_hinge:
		door_hinge = existing_hinge
		_base_hinge_rotation = door_hinge.rotation_degrees
		return

	var wooden_door := get_node_or_null("WoodenDoor") as Node3D
	if wooden_door == null:
		wooden_door = find_child("WoodenDoor", true, false) as Node3D

	if wooden_door == null:
		push_warning("[DoorPortal] WoodenDoor tidak ditemukan!")
		return

	# Cari mesh daun pintu di dalam WoodenDoor (panel dengan detail/faces terbanyak, bukan kusen)
	var door_leaf: MeshInstance3D = null
	var meshes := wooden_door.find_children("*", "MeshInstance3D", true, false)
	var max_faces := -1
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi and mi.mesh:
			var faces: int = mi.mesh.get_faces().size()
			if faces > max_faces:
				max_faces = faces
				door_leaf = mi

	if door_leaf == null:
		door_leaf = wooden_door.find_child("Object_2", true, false) as MeshInstance3D
	if door_leaf == null:
		door_leaf = wooden_door.find_child("Object_3", true, false) as MeshInstance3D

	if door_leaf == null:
		push_warning("[DoorPortal] Mesh daun pintu tidak ditemukan di dalam WoodenDoor!")
		return

	print("[DoorPortal] Daun pintu terdeteksi: ", door_leaf.name, " (faces: ", max_faces, ") di path: ", door_leaf.get_path())

	# Hitung posisi titik engsel menggunakan global AABB dari door_leaf
	var aabb: AABB = door_leaf.get_aabb()
	var min_c := Vector3(INF, INF, INF)
	var max_c := Vector3(-INF, -INF, -INF)
	for xi in [0.0, 1.0]:
		for yi in [0.0, 1.0]:
			for zi in [0.0, 1.0]:
				var local_pt := aabb.position + aabb.size * Vector3(xi, yi, zi)
				var world_pt := door_leaf.global_transform * local_pt
				min_c.x = minf(min_c.x, world_pt.x)
				min_c.y = minf(min_c.y, world_pt.y)
				min_c.z = minf(min_c.z, world_pt.z)
				max_c.x = maxf(max_c.x, world_pt.x)
				max_c.y = maxf(max_c.y, world_pt.y)
				max_c.z = maxf(max_c.z, world_pt.z)

	var hinge_pos := Vector3.ZERO
	hinge_pos.y = min_c.y # Alas bawah vertikal

	var span_x := max_c.x - min_c.x
	var span_z := max_c.z - min_c.z

	if span_z >= span_x:
		# Pintu membentang sepanjang Z: engsel fisik berada di tepi min_c.z
		hinge_pos.x = (min_c.x + max_c.x) * 0.5
		hinge_pos.z = min_c.z
	else:
		# Pintu membentang sepanjang X: engsel fisik berada di tepi min_c.x
		hinge_pos.z = (min_c.z + max_c.z) * 0.5
		hinge_pos.x = min_c.x

	# Buat Node3D DoorHinge sebagai child langsung dari DoorPortal (sumbu Y murni tegak lurus)
	door_hinge = Node3D.new()
	door_hinge.name = "DoorHinge"
	add_child(door_hinge)
	door_hinge.global_position = hinge_pos
	door_hinge.global_rotation = Vector3.ZERO
	_base_hinge_rotation = door_hinge.rotation_degrees

	# Pindahkan daun pintu ke dalam DoorHinge (keep_global_transform = true agar posisi 100% tidak berubah)
	door_leaf.reparent(door_hinge, true)
	_door_center_world = Vector3((min_c.x + max_c.x) * 0.5, (min_c.y + max_c.y) * 0.5, (min_c.z + max_c.z) * 0.5)
	_door_width = maxf(span_x, span_z)
	_door_height = maxf(max_c.y - min_c.y, 2.2)
	_door_min_y = min_c.y
	print("[DoorPortal] DoorHinge berhasil dibuat pada global_pos: ", hinge_pos, " dan ", door_leaf.name, " di-reparent!")


func _ensure_blinding_portal_rig() -> void:
	var door_pos := _get_door_world_pos()
	if _blinding_quad == null or not is_instance_valid(_blinding_quad):
		_blinding_quad = MeshInstance3D.new()
		_blinding_quad.name = "BlindingPortalQuad"
		var quad := QuadMesh.new()
		quad.size = Vector2(maxf(_door_width * 0.92, 1.5), maxf(_door_height * 0.94, 2.4))
		_blinding_quad.mesh = quad
		_blinding_quad_mat = StandardMaterial3D.new()
		_blinding_quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blinding_quad_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_blinding_quad_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		_blinding_quad_mat.emission_enabled = true
		_blinding_quad_mat.emission = Color(1.0, 1.0, 1.0)
		_blinding_quad_mat.emission_energy_multiplier = 0.0
		_blinding_quad.set_surface_override_material(0, _blinding_quad_mat)
		add_child(_blinding_quad)
		_blinding_quad.global_position = Vector3(door_pos.x + 0.35 * _door_facing_x, _door_min_y + _door_height * 0.5, door_pos.z)
		_blinding_quad.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		_blinding_quad.visible = false

	if _blinding_spot == null or not is_instance_valid(_blinding_spot):
		_blinding_spot = SpotLight3D.new()
		_blinding_spot.name = "BlindingPortalSpot"
		_blinding_spot.light_color = Color(1.0, 1.0, 1.0)
		_blinding_spot.light_energy = 0.0
		_blinding_spot.light_volumetric_fog_energy = 6.0
		_blinding_spot.spot_range = 26.0
		_blinding_spot.spot_angle = 68.0
		_blinding_spot.spot_attenuation = 0.85
		add_child(_blinding_spot)
		var spot_y := maxf(_door_min_y + _door_height * 0.35, global_position.y + 1.8)
		_blinding_spot.global_position = Vector3(door_pos.x + 0.85 * _door_facing_x, spot_y, door_pos.z)
		_blinding_spot.look_at(Vector3(door_pos.x - 10.0 * _door_facing_x, spot_y - 0.8, door_pos.z), Vector3.UP)
		_blinding_spot.visible = false

func _setup_components() -> void:
	# 1. DoorHinge (jika belum diinisialisasi oleh _setup_door_hinge)
	if door_hinge == null:
		door_hinge = get_node_or_null("DoorHinge") as Node3D
	if door_hinge == null:
		door_hinge = find_child("DoorHinge", true, false) as Node3D
	if door_hinge:
		_base_hinge_rotation = door_hinge.rotation_degrees

	# 2. DoorInnerGlow
	if door_inner_glow == null:
		door_inner_glow = get_node_or_null("DoorInnerGlow") as Light3D
	if door_inner_glow == null:
		door_inner_glow = find_child("DoorInnerGlow", true, false) as Light3D
	if door_inner_glow:
		door_inner_glow.light_energy = 0.0
	_ensure_blinding_portal_rig()

	# 3. InteractionPrompt
	if interaction_prompt == null:
		interaction_prompt = get_node_or_null("InteractionPrompt") as Label3D
	if interaction_prompt == null:
		interaction_prompt = find_child("InteractionPrompt", true, false) as Label3D
	if interaction_prompt:
		interaction_prompt.visible = false

	# 4. CameraRig
	if camera_rig == null:
		camera_rig = get_node_or_null("../CameraRig")
	if camera_rig == null:
		camera_rig = get_tree().root.find_child("CameraRig", true, false)

	# 5. Cari Player jika belum terpasang
	if player == null:
		player = _find_player()

func _setup_fade_overlay() -> void:
	if fade_layer == null:
		fade_layer = get_node_or_null("../FadeCanvasLayer")
		if fade_layer == null:
			fade_layer = get_tree().root.find_child("FadeCanvasLayer", true, false)

	if fade_layer == null:
		fade_layer = CanvasLayer.new()
		fade_layer.name = "FadeCanvasLayer"
		fade_layer.layer = 100
		add_child(fade_layer)

	if fade_rect == null:
		fade_rect = fade_layer.get_node_or_null("ColorRect")
		if fade_rect == null:
			fade_rect = ColorRect.new()
			fade_rect.name = "ColorRect"
			fade_rect.anchors_preset = Control.PRESET_FULL_RECT
			fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fade_layer.add_child(fade_rect)

	if fade_rect:
		fade_rect.anchors_preset = Control.PRESET_FULL_RECT
		# Biarkan warna tetap hitam di awal scene; warna putih silau diatur saat cutscene portal dimulai.
		fade_rect.modulate.a = 0.0

func _get_door_world_pos() -> Vector3:
	if _door_center_world != Vector3.ZERO:
		return _door_center_world
	if has_node("WoodenDoor"):
		return (get_node("WoodenDoor") as Node3D).global_position
	if door_hinge:
		return door_hinge.global_position
	return global_position

func _physics_process(_delta: float) -> void:
	if is_triggered or is_locked:
		return

	if player == null:
		player = _find_player()

	if player != null:
		var door_center := _get_door_world_pos()
		var dist := player.global_position.distance_to(door_center)
		var dist_xz := Vector2(player.global_position.x - door_center.x, player.global_position.z - door_center.z).length()

		# Mulai background loading ketika pemain mulai mendekati area pintu di puncak tangga
		if dist < 8.0 or dist_xz < 7.0:
			_preload_target_scene()

		# Tampilkan prompt interaksi jika pemain mendekati puncak batu depan pintu
		if dist < 2.5 or dist_xz < 2.2 or _player_in_zone:
			if interaction_prompt and not interaction_prompt.visible:
				interaction_prompt.visible = true

			# Pengaman ganda: memicu otomatis saat jarak pemain ke ambang pintu < 1.8m atau X mendekati pintu
			if dist < trigger_distance_threshold or dist_xz < 1.6 or (player.global_position.x >= door_center.x - 0.5 and dist_xz < 2.0):
				start_cinematic_cutscene(player)
		else:
			if interaction_prompt and interaction_prompt.visible and not _player_in_zone:
				interaction_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_triggered or is_locked:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		if player == null:
			player = _find_player()
		if player != null:
			var door_center := _get_door_world_pos()
			var dist := player.global_position.distance_to(door_center)
			var dist_xz := Vector2(player.global_position.x - door_center.x, player.global_position.z - door_center.z).length()
			if dist < 3.0 or dist_xz < 2.5 or _player_in_zone:
				start_cinematic_cutscene(player)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.name == "Player":
		player = body as CharacterBody3D
		_player_in_zone = true

		if not is_triggered and not is_locked:
			if interaction_prompt:
				interaction_prompt.visible = true
			start_cinematic_cutscene(player)

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		_player_in_zone = false
		if interaction_prompt and not is_triggered:
			interaction_prompt.visible = false

## Dipanggil saat anak tangga selesai atau dipanggil langsung dari puzzle manager
func activate_portal() -> void:
	print("[DoorPortal] Portal diaktifkan di puncak batu (pintu tetap tertutup hingga pemain mendekat).")
	is_locked = false
	_preload_target_scene()

## Kompatibilitas jika dipanggil dari script level lain
func trigger_portal() -> void:
	if player == null:
		player = _find_player()
	if player:
		start_cinematic_cutscene(player)

func unlock_and_open() -> void:
	is_locked = false
	_preload_target_scene()
	print("[DoorPortal] Portal di-unlock (pintu tetap tertutup hingga cutscene).")

## Memulai Cutscene Sinematik 4 Fase
func start_cinematic_cutscene(char_player: CharacterBody3D) -> void:
	if is_triggered or is_locked:
		return
	is_triggered = true
	player = char_player
	_preload_target_scene()
	transition_started.emit()

	if interaction_prompt:
		interaction_prompt.visible = false

	# =========================================================================
	# FASE 1 (0.0s): Kunci Kontrol, Hadapkan Karakter ke Pintu, Mainkan Animasi Idle
	# =========================================================================
	if get_tree():
		for enemy in get_tree().get_nodes_in_group("eraser_ai"):
			if is_instance_valid(enemy):
				enemy.set_physics_process(false)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", false)
	if "input_enabled" in player:
		player.set("input_enabled", false)

	# Putar arah hadap tubuh karakter lurus ke depan pintu kayu
	var door_world_pos := _get_door_world_pos()
	_door_facing_x = 1.0 if door_world_pos.x >= player.global_position.x else -1.0
	_ensure_blinding_portal_rig()
	var dir_to_door := (door_world_pos - player.global_position)
	dir_to_door.y = 0.0
	var target_yaw := atan2(dir_to_door.x, dir_to_door.z) if dir_to_door.length_squared() > 0.01 else PI * 0.5

	if "body" in player and player.get("body"):
		(player.get("body") as Node3D).rotation.y = target_yaw
	if "visual_node" in player and player.get("visual_node"):
		var v_node = player.get("visual_node") as Node3D
		if v_node and v_node != player:
			v_node.rotation.y = target_yaw

	# Mainkan animasi Idle
	var anim_player: AnimationPlayer = _get_player_animation_player(player)
	if anim_player:
		anim_player.speed_scale = 1.0
		if anim_player.has_animation("Idle"):
			anim_player.play("Idle", 0.2)
		elif anim_player.has_animation("idle"):
			anim_player.play("idle", 0.2)

	# =========================================================================
	# FASE 2 (0.0s - 0.8s): Kamera Over-the-Shoulder Sinematik (TRANS_CUBIC)
	# =========================================================================
	if camera_rig:
		camera_rig.set_process(false)
		camera_rig.set_physics_process(false)
		if "is_cutscene_override" in camera_rig:
			camera_rig.set("is_cutscene_override", true)
		if "_is_focusing" in camera_rig:
			camera_rig.set("_is_focusing", true)

	var active_cam: Camera3D = get_viewport().get_camera_3d()
	if active_cam == null and camera_rig:
		active_cam = camera_rig.find_child("Camera3D", true, false) as Camera3D

	var cam_pullback := clampf(_door_width * 1.1, 2.6, 6.8)
	var cam_height := clampf(_door_width * 0.42, 1.85, 2.75)
	var look_height := clampf(_door_width * 0.52, 1.5, 3.2)
	var cam_pos := Vector3(door_world_pos.x - cam_pullback * _door_facing_x, player.global_position.y + cam_height, door_world_pos.z + 1.05)
	var cam_look_target := Vector3(door_world_pos.x + 0.4 * _door_facing_x, player.global_position.y + look_height, door_world_pos.z)
	var target_cam_transform := Transform3D(Basis(), cam_pos).looking_at(cam_look_target, Vector3.UP)

	var tw := create_tween()

	if active_cam:
		tw.tween_property(active_cam, "global_transform", target_cam_transform, 0.8)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(active_cam, "fov", 48.0, 0.8)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_interval(0.8)

	# =========================================================================
	# FASE 3 (0.8s - 2.6s): Pintu Berayun Terbuka & Cahaya Putih Terang Memancar
	# =========================================================================
	if door_hinge == null:
		door_hinge = get_node_or_null("DoorHinge") as Node3D
		if door_hinge == null:
			door_hinge = find_child("DoorHinge", true, false) as Node3D
		if door_hinge:
			_base_hinge_rotation = door_hinge.rotation_degrees

	var swing_dur := maxf(open_duration, 1.45)
	tw.chain().tween_callback(func():
		is_open = true
		door_opened.emit()
		if is_instance_valid(_blinding_quad):
			_blinding_quad.visible = true
		if is_instance_valid(_blinding_spot):
			_blinding_spot.visible = true
		if door_inner_glow:
			door_inner_glow.light_color = Color(1.0, 1.0, 1.0)
	)

	if door_hinge:
		var target_hinge_y := _base_hinge_rotation.y + open_angle_degrees
		print("[DoorPortal] Cutscene Fase 3: Membuka DoorHinge dari ", door_hinge.rotation_degrees.y, " ke ", target_hinge_y)
		tw.tween_property(door_hinge, "rotation_degrees:y", target_hinge_y, swing_dur)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	else:
		push_warning("[DoorPortal] door_hinge is null — skipping door swing!")
		tw.tween_interval(swing_dur)

	if door_inner_glow:
		tw.parallel().tween_property(door_inner_glow, "light_energy", maxf(glow_energy, 22.0), swing_dur)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	if is_instance_valid(_blinding_quad_mat):
		tw.parallel().tween_property(_blinding_quad_mat, "emission_energy_multiplier", 28.0, swing_dur)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
	if is_instance_valid(_blinding_spot):
		tw.parallel().tween_property(_blinding_spot, "light_energy", 45.0, swing_dur)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)

	# Tahan sejenak agar cahaya putih terang di balik pintu terlihat jelas sebelum player melangkah
	tw.chain().tween_interval(0.45)

	# =========================================================================
	# FASE 4: Karakter Otomatis Jalan Masuk -> Layar Fadeout Putih Terang
	# =========================================================================
	tw.chain().tween_callback(func():
		if anim_player:
			anim_player.speed_scale = 0.85
			if anim_player.has_animation("Walk"):
				anim_player.play("Walk", 0.2)
			elif anim_player.has_animation("walk"):
				anim_player.play("walk", 0.2)
	)

	var walk_dur := 1.75
	var walk_depth := clampf(_door_width * 0.42, 1.4, 2.6)
	var walk_target := Vector3(door_world_pos.x + walk_depth * _door_facing_x, player.global_position.y, door_world_pos.z)
	tw.tween_property(player, "global_position", walk_target, walk_dur)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	if "visual_node" in player and player.get("visual_node"):
		var v_node = player.get("visual_node") as Node3D
		if v_node and v_node != player:
			tw.parallel().tween_property(v_node, "global_position", walk_target, walk_dur)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN_OUT)

	if active_cam:
		var push_pos := Vector3(door_world_pos.x - clampf(_door_width * 0.48, 1.2, 2.8) * _door_facing_x, player.global_position.y + 1.95, door_world_pos.z + 0.35)
		var push_look := Vector3(door_world_pos.x + 2.5 * _door_facing_x, player.global_position.y + 2.1, door_world_pos.z)
		var push_xform := Transform3D(Basis(), push_pos).looking_at(push_look, Vector3.UP)
		tw.parallel().tween_property(active_cam, "global_transform", push_xform, walk_dur)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

	if is_instance_valid(_blinding_quad_mat):
		tw.parallel().tween_property(_blinding_quad_mat, "emission_energy_multiplier", 46.0, walk_dur)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)

	# Fade-out putih penuh layar menyilaukan dimulai setelah player mulai melangkah masuk
	if fade_rect:
		fade_rect.visible = true
		fade_rect.color = Color(1.0, 1.0, 1.0, 1.0)
		fade_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var white_dur := maxf(fade_duration, 1.15)
		tw.parallel().tween_property(fade_rect, "modulate:a", 1.0, white_dur)\
			.set_delay(0.55)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)

	# Tahan 0.5 detik di layar putih terang sebelum transisi scene
	tw.chain().tween_interval(0.5)

	# Pindah scene tujuan
	tw.chain().tween_callback(_change_to_next_scene)

## Buka pintu manual (hanya unlock, pintu fisik tetap tertutup hingga cutscene berjalan)
func open_door() -> void:
	is_locked = false
	print("[DoorPortal] open_door() dipanggil: pintu di-unlock (tetap tertutup hingga cutscene).")

## Tutup pintu manual
func close_door() -> void:
	if not is_open:
		return
	is_open = false

	if door_hinge:
		var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(door_hinge, "rotation_degrees:y", _base_hinge_rotation.y, open_duration)

	if door_inner_glow:
		var tw_glow = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_glow.tween_property(door_inner_glow, "light_energy", 0.0, open_duration)

	door_closed.emit()

func _change_to_next_scene() -> void:
	var target := target_scene_path
	if target.is_empty():
		target = "res://scenes/levels/chapter_2.tscn"

	if not ResourceLoader.exists(target):
		push_error("[DoorPortal] Scene target tidak ditemukan: " + target)
		transition_finished.emit()
		return

	print("[DoorPortal] Berpindah scene ke: ", target)
	transition_finished.emit()

	# Cek apakah preloaded scene di background sudah selesai
	var status := ResourceLoader.load_threaded_get_status(target)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(target) as PackedScene
		if packed:
			get_tree().call_deferred("change_scene_to_packed", packed)
			return

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_wait_and_change_scene(target)
		return

	# Fallback aman
	get_tree().call_deferred("change_scene_to_file", target)

func _wait_and_change_scene(target: String) -> void:
	while ResourceLoader.load_threaded_get_status(target) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(target) == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(target) as PackedScene
		if packed:
			get_tree().call_deferred("change_scene_to_packed", packed)
			return
	get_tree().call_deferred("change_scene_to_file", target)

func _find_player() -> CharacterBody3D:
	var p = get_node_or_null("../Player") as CharacterBody3D
	if p == null:
		p = get_tree().root.find_child("Player", true, false) as CharacterBody3D
	return p

func _get_player_animation_player(char_player: CharacterBody3D) -> AnimationPlayer:
	if char_player == null:
		return null
	if "anim_player" in char_player and char_player.get("anim_player") is AnimationPlayer:
		return char_player.get("anim_player") as AnimationPlayer
	if char_player.has_node("char no light/AnimationPlayer"):
		return char_player.get_node("char no light/AnimationPlayer") as AnimationPlayer
	if char_player.get_parent() and char_player.get_parent().has_node("char no light/AnimationPlayer"):
		return char_player.get_parent().get_node("char no light/AnimationPlayer") as AnimationPlayer
	return char_player.find_child("AnimationPlayer", true, false) as AnimationPlayer
