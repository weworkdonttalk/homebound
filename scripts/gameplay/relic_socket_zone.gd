class_name RelicSocketZone
extends Area3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## RelicSocketZone — Socket penyerahan 3 FloatingRelic di depan pintu ganda ruangan (TembokKebelah).
## Ketika player mendekat (atau menekan [E]) sambil membawa relic, semua relic yang dibawa
## melesat menempel ke 3 titik di permukaan pintu ganda, lalu membuka pintu ganda saat 3/3 terpasang.

signal relic_delivered(relic: Node3D)
signal all_relics_delivered

@export var required_relic_count: int = 3
@export var target_door_path: NodePath = NodePath("../TembokKebelah")
@export var unlock_delay_seconds: float = 0.55

var is_fulfilled: bool = false
var delivered_count: int = 0

const PARKOUR_PLATFORM_PATHS := [
	"object/Sketchfab_Scene37",
	"object/Sketchfab_Scene38",
	"object/Sketchfab_Scene39",
	"object/Sketchfab_Scene40",
	"object/Sketchfab_Scene41",
	"object/Sketchfab_Scene42",
]

const PARKOUR_CLOCK_PATHS := [
	"Sketchfab_Scene",
	"Sketchfab_Scene14",
	"Sketchfab_Scene2",
	"Sketchfab_Scene7",
	"Sketchfab_Scene3",
	"Sketchfab_Scene8",
	"Sketchfab_Scene4",
	"Sketchfab_Scene9",
	"Sketchfab_Scene5",
	"Sketchfab_Scene10",
]

var _socket_points: Array[Marker3D] = []
var _delivered_relics: Array[Node3D] = []
var _delivering_relics: Array[Node3D] = []
var _beacon_light: OmniLight3D = null
var _prompt_label: Label3D = null
var _player_in_zone: CharacterBody3D = null
var _parkour_platforms: Array[Dictionary] = []
var _parkour_clocks: Array[Dictionary] = []
var _parkour_revealed: bool = false
var _reveal_lights_root: Node3D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	_resolve_socket_points()
	_beacon_light = get_node_or_null("SocketBeaconLight") as OmniLight3D
	_setup_prompt_label()
	call_deferred("_prepare_parkour_reveal_nodes")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _resolve_socket_points() -> void:
	_socket_points.clear()
	for node_name in ["SocketAltarPoint_1", "SocketAltarPoint_2", "SocketAltarPoint_3", "SocketAltarPoint"]:
		var m := get_node_or_null(NodePath(node_name)) as Marker3D
		if m and not _socket_points.has(m):
			_socket_points.append(m)


func _setup_prompt_label() -> void:
	_prompt_label = get_node_or_null("SocketPromptLabel") as Label3D
	if _prompt_label == null:
		_prompt_label = Label3D.new()
		_prompt_label.name = "SocketPromptLabel"
		_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt_label.no_depth_test = true
		_prompt_label.font_size = 32
		_prompt_label.outline_size = 8
		_prompt_label.pixel_size = 0.0085
		_prompt_label.modulate = Color(1.0, 0.9, 0.65, 1.0)
		_prompt_label.outline_modulate = Color(0.04, 0.03, 0.06, 0.95)
		_prompt_label.position = Vector3(0.4, 2.2, 0.0)
		add_child(_prompt_label)
	_prompt_label.text = "Pasang 3 Artefak Waktu (0/%d)" % required_relic_count
	_prompt_label.visible = false


func _get_slot_world_pos(slot_index: int) -> Vector3:
	if not _socket_points.is_empty():
		var m := _socket_points[mini(slot_index, _socket_points.size() - 1)]
		if is_instance_valid(m):
			return m.global_position
	var spread := float(slot_index - 1) * 0.85
	return global_position + Vector3(1.25, 1.25, spread)


func _is_player(body: Node) -> bool:
	return body is CharacterBody3D and (body.name == "Player" or body.is_in_group("player") or "floating_relics" in body)


func _on_body_entered(body: Node3D) -> void:
	if is_fulfilled or not _is_player(body):
		return
	_player_in_zone = body as CharacterBody3D
	_try_deliver_from_player(_player_in_zone)


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_zone:
		_player_in_zone = null
		if _prompt_label and not is_fulfilled:
			_prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_fulfilled or _player_in_zone == null or not is_instance_valid(_player_in_zone):
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		if _try_deliver_from_player(_player_in_zone):
			get_viewport().set_input_as_handled()


func _try_deliver_from_player(player: CharacterBody3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var relics: Variant = player.get("floating_relics") if "floating_relics" in player else null
	var started_any := false
	if relics is Array and not (relics as Array).is_empty():
		for item in (relics as Array).duplicate():
			var relic := item as Node3D
			if relic == null or not is_instance_valid(relic):
				continue
			if _delivered_relics.has(relic) or _delivering_relics.has(relic):
				continue
			if relic.has_method("deliver_to_socket"):
				_start_delivery(relic)
				started_any = true

	if not started_any and _prompt_label:
		_prompt_label.text = "Pintu Terkunci — Pasang 3 Artefak (%d/%d)" % [delivered_count, required_relic_count]
		_prompt_label.visible = true
	return started_any


func _start_delivery(relic: Node3D) -> void:
	var slot_idx := delivered_count + _delivering_relics.size()
	_delivering_relics.append(relic)
	if _prompt_label:
		_prompt_label.text = "Menempatkan Artefak (%d/%d)..." % [mini(slot_idx + 1, required_relic_count), required_relic_count]
		_prompt_label.visible = true

	var target_pos := _get_slot_world_pos(slot_idx)
	relic.call("deliver_to_socket", target_pos, Callable(self, "_on_relic_arrived").bind(relic))


func _on_relic_arrived(relic: Node3D) -> void:
	_delivering_relics.erase(relic)
	if not _delivered_relics.has(relic):
		_delivered_relics.append(relic)
	delivered_count = _delivered_relics.size()
	relic_delivered.emit(relic)

	if delivered_count < required_relic_count:
		if _prompt_label:
			_prompt_label.text = "Artefak Terpasang di Pintu (%d/%d)" % [delivered_count, required_relic_count]
			_prompt_label.visible = true
		return

	is_fulfilled = true
	if _beacon_light:
		_beacon_light.light_color = Color(0.55, 1.0, 0.78)
		_beacon_light.light_energy = 2.8

	if _prompt_label:
		_prompt_label.text = "Pintu Ganda Terbuka (%d/%d) ✓" % [delivered_count, required_relic_count]
		_prompt_label.modulate = Color(0.6, 1.0, 0.78, 1.0)
		_prompt_label.visible = true

	all_relics_delivered.emit()
	if get_tree():
		get_tree().call_group("chapter2_puzzle_manager", "notify_all_relics_delivered")

	# Biarkan ketiga relic bersinar di permukaan pintu sejenak sebelum membuka pintu ganda.
	if unlock_delay_seconds > 0.0 and is_inside_tree() and get_tree():
		await get_tree().create_timer(unlock_delay_seconds).timeout
	_open_target_double_door()


func _prepare_parkour_reveal_nodes() -> void:
	var root := get_tree().current_scene if get_tree() else null
	if root == null or _parkour_revealed:
		return
	_parkour_platforms.clear()
	for p_path in PARKOUR_PLATFORM_PATHS:
		var node := root.get_node_or_null(NodePath(p_path)) as Node3D
		if node:
			var entry := _build_reveal_entry(node, Color(0.55, 0.85, 1.0), 5.5, false)
			_parkour_platforms.append(entry)
			_set_platform_collision_disabled(node, true)

	_parkour_clocks.clear()
	for c_path in PARKOUR_CLOCK_PATHS:
		var node := root.get_node_or_null(NodePath(c_path)) as Node3D
		if node:
			_parkour_clocks.append(_build_reveal_entry(node, Color(1.0, 0.78, 0.34), 10.5, true))


func _build_reveal_entry(node: Node3D, glow_color: Color, drop_y: float, start_straight_y: bool) -> Dictionary:
	var target_pos := node.position
	var target_rot := node.rotation
	var meshes: Array[MeshInstance3D] = []
	var glow_mats: Array[StandardMaterial3D] = []
	for mi_node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		meshes.append(mi)
		mi.transparency = 1.0
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				var dup := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				dup.emission = glow_color
				dup.emission_energy_multiplier = 0.0
				mi.set_surface_override_material(s, dup)
				glow_mats.append(dup)
	node.visible = false
	node.position = target_pos + Vector3(0.0, -drop_y, 0.0)
	if start_straight_y:
		node.rotation = Vector3(target_rot.x, 0.0, target_rot.z)
	return {"node": node, "pos": target_pos, "rot": target_rot, "meshes": meshes, "mats": glow_mats, "glow_color": glow_color}


func _set_platform_collision_disabled(plat: Node3D, disabled: bool) -> void:
	for col_node in plat.find_children("*", "CollisionShape3D", true, false):
		var col := col_node as CollisionShape3D
		if col:
			col.set_deferred("disabled", disabled)


func _open_target_double_door() -> void:
	if not is_inside_tree():
		return
	var door := get_node_or_null(target_door_path) as Node3D
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("TembokKebelah", true, false) as Node3D
	if door:
		var dp := door.global_position
		Ch2Utils.play_door_open_cutscene(
			self,
			door,
			Vector3(dp.x - 6.6, dp.y - 1.5, dp.z + 2.3),
			Vector3(dp.x - 2.2, dp.y - 1.1, dp.z + 0.6),
			Vector3(dp.x + 2.0, dp.y - 0.7, dp.z),
			0.25,
			1.65,
			1.90,
			Callable(),
			Callable(self, "_play_parkour_reveal_sequence")
		)


func _rise_nodes_staggered(entries: Array[Dictionary], stagger: float, base_delay: float, fade_dur: float, rise_dur: float, is_platform: bool) -> void:
	var peak_em := 2.6 if is_platform else 2.8
	var rest_em := 0.58 if is_platform else 0.95
	var light_range := 7.0 if is_platform else 12.0
	var light_peak := 2.2 if is_platform else 3.0
	var light_rest := 0.75 if is_platform else 1.15
	var world_root := get_tree().current_scene if get_tree() else self

	for i in range(entries.size()):
		var entry := entries[i]
		var node := entry["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var target_pos: Vector3 = entry["pos"]
		var drift_pos := node.position + Vector3(0.0, 0.45, 0.0)
		var meshes: Array = entry["meshes"]
		var mats: Array = entry["mats"]

		var glow_light := OmniLight3D.new()
		glow_light.light_color = entry["glow_color"]
		glow_light.light_energy = 0.0
		glow_light.omni_range = light_range
		if _reveal_lights_root and is_instance_valid(_reveal_lights_root):
			_reveal_lights_root.add_child(glow_light)
		else:
			world_root.add_child(glow_light)
		var world_target := (node.get_parent() as Node3D).to_global(target_pos) if node.get_parent() is Node3D else node.global_position
		glow_light.global_position = world_target + (Vector3(0.0, 1.3, 0.0) if is_platform else Vector3(0.0, -1.5, 0.0))

		var tw := create_tween()
		var wait_t := base_delay + float(i) * stagger
		if wait_t > 0.0:
			tw.tween_interval(wait_t)
		tw.tween_callback(func() -> void:
			if is_instance_valid(node):
				node.visible = true
				if is_platform:
					_set_platform_collision_disabled(node, false)
					_play_reveal_chime(580.0 + float(i) * 48.0)
		)
		# Fase 1: Fade in lembut dari kabut void sambil mulai melayang perlahan
		tw.tween_method(func(alpha_progress: float) -> void:
			var tr := 1.0 - alpha_progress
			for m_var in meshes:
				var mi := m_var as MeshInstance3D
				if is_instance_valid(mi):
					mi.transparency = tr
			for mat_var in mats:
				var mat := mat_var as StandardMaterial3D
				if is_instance_valid(mat):
					mat.emission_energy_multiplier = lerpf(0.0, peak_em * 0.65, alpha_progress)
			if is_instance_valid(glow_light):
				glow_light.light_energy = lerpf(0.0, light_peak * 0.55, alpha_progress)
		, 0.0, 1.0, fade_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "position", drift_pos, fade_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Fase 2: Naik pelan & mulus dari bawah ke atas (tanpa hentakan cepat)
		tw.tween_property(node, "position", target_pos, rise_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_method(func(p: float) -> void:
			var em := lerpf(peak_em, rest_em, clampf((p - 0.55) / 0.45, 0.0, 1.0)) if p > 0.55 else lerpf(peak_em * 0.65, peak_em, p / 0.55)
			for mat_var in mats:
				var mat := mat_var as StandardMaterial3D
				if is_instance_valid(mat):
					mat.emission_energy_multiplier = em
			if is_instance_valid(glow_light):
				glow_light.light_energy = lerpf(light_peak, light_rest, clampf((p - 0.55) / 0.45, 0.0, 1.0)) if p > 0.55 else lerpf(light_peak * 0.55, light_peak, p / 0.55)
		, 0.0, 1.0, rise_dur)


func _play_parkour_reveal_sequence(cut_cam: Camera3D, reveal_light: OmniLight3D) -> void:
	if _parkour_revealed:
		return
	_parkour_revealed = true
	if _reveal_lights_root == null or not is_instance_valid(_reveal_lights_root):
		_reveal_lights_root = Node3D.new()
		_reveal_lights_root.name = "ParkourRevealGlowLights"
		var scene_root := get_tree().current_scene if get_tree() else self
		scene_root.add_child(_reveal_lights_root)

	if DisplayServer.get_name() == "headless" or cut_cam == null or not is_inside_tree():
		_reveal_parkour_immediately()
		return

	var cam_from := cut_cam.global_position
	var cam_to := Vector3(106.0, 13.2, 3.2)
	var look_from := Vector3(97.5, 7.8, 2.125)
	var look_to := Vector3(142.0, 9.0, 1.8)
	var start_fov := cut_cam.fov

	var plat_stagger := 0.55
	var plat_fade := 0.60
	var plat_rise := 1.45
	var clock_stagger := 0.42
	var clock_base_delay := 0.35
	var clock_fade := 0.65
	var clock_rise := 1.55

	var total_rise_span := maxf(
		float(maxi(_parkour_platforms.size() - 1, 0)) * plat_stagger + plat_fade + plat_rise,
		clock_base_delay + float(maxi(_parkour_clocks.size() - 1, 0)) * clock_stagger + clock_fade + clock_rise
	)
	var tilt_dur := 1.35
	var cam_dur := total_rise_span + tilt_dur * 0.65

	var glide_tw := create_tween().set_parallel(true)
	glide_tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(cut_cam):
			return
		cut_cam.global_position = cam_from.lerp(cam_to, t)
		cut_cam.look_at(look_from.lerp(look_to, t), Vector3.UP)
	, 0.0, 1.0, cam_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glide_tw.tween_property(cut_cam, "fov", 58.0, cam_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(reveal_light):
		glide_tw.tween_property(reveal_light, "global_position", Vector3(132.0, 12.5, 2.0), cam_dur)

	_rise_nodes_staggered(_parkour_platforms, plat_stagger, 0.0, plat_fade, plat_rise, true)
	_rise_nodes_staggered(_parkour_clocks, clock_stagger, clock_base_delay, clock_fade, clock_rise, false)

	await get_tree().create_timer(total_rise_span + 0.25).timeout
	if not is_inside_tree():
		return

	# Setelah semua jam naik lurus ke atas, miringkan semua jam serentak ke sudut akhir
	_play_reveal_chime(520.0)
	var tilt_tw := create_tween().set_parallel(true)
	for entry in _parkour_clocks:
		var c := entry["node"] as Node3D
		if not is_instance_valid(c):
			continue
		var target_rot: Vector3 = entry["rot"]
		var start_y := c.rotation.y
		var mats: Array = entry["mats"]
		tilt_tw.tween_method(func(t: float) -> void:
			if is_instance_valid(c):
				c.rotation.y = lerp_angle(start_y, target_rot.y, t)
			var em := lerpf(0.95, 1.85, sin(t * PI))
			for mat_var in mats:
				var mat := mat_var as StandardMaterial3D
				if is_instance_valid(mat):
					mat.emission_energy_multiplier = em
		, 0.0, 1.0, tilt_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tilt_tw.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(cut_cam):
		cut_cam.fov = start_fov


func _play_reveal_chime(freq: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var sample_rate := 22050
	var dur := 0.18
	var frames := int(sample_rate * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 14.0)
		var sig := sin(TAU * freq * t) * 0.65 + sin(TAU * freq * 1.5 * t) * 0.35
		data.encode_s16(i * 2, int(clampf(sig * env * 0.28, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	var asp := AudioStreamPlayer.new()
	asp.stream = wav
	asp.volume_db = -8.0
	add_child(asp)
	asp.finished.connect(func() -> void:
		if is_instance_valid(asp):
			asp.queue_free()
	)
	asp.play()


func _reveal_parkour_immediately() -> void:
	_parkour_revealed = true
	for entry in _parkour_platforms:
		var p := entry["node"] as Node3D
		if is_instance_valid(p):
			p.position = entry["pos"]
			p.visible = true
			for m_var in entry["meshes"]:
				if is_instance_valid(m_var):
					(m_var as MeshInstance3D).transparency = 0.0
			for mat_var in entry["mats"]:
				if is_instance_valid(mat_var):
					(mat_var as StandardMaterial3D).emission_energy_multiplier = 0.58
			_set_platform_collision_disabled(p, false)
	for entry in _parkour_clocks:
		var c := entry["node"] as Node3D
		if is_instance_valid(c):
			c.position = entry["pos"]
			c.rotation = entry["rot"]
			c.visible = true
			for m_var in entry["meshes"]:
				if is_instance_valid(m_var):
					(m_var as MeshInstance3D).transparency = 0.0
			for mat_var in entry["mats"]:
				if is_instance_valid(mat_var):
					(mat_var as StandardMaterial3D).emission_energy_multiplier = 0.95


func restore_delivered_relics(delivered_relics: Array[Node3D], fulfilled: bool) -> void:
	_prepare_parkour_reveal_nodes()
	_delivered_relics.clear()
	_delivering_relics.clear()
	for i in range(delivered_relics.size()):
		var relic := delivered_relics[i]
		if not is_instance_valid(relic):
			continue
		_delivered_relics.append(relic)
		var target_pos := _get_slot_world_pos(i)
		if relic.has_method("force_delivered_at"):
			relic.call("force_delivered_at", target_pos)
	delivered_count = _delivered_relics.size()
	is_fulfilled = fulfilled or (delivered_count >= required_relic_count)
	if _prompt_label:
		if is_fulfilled:
			_prompt_label.text = "Pintu Ganda Terbuka (%d/%d) ✓" % [delivered_count, required_relic_count]
			_prompt_label.modulate = Color(0.6, 1.0, 0.78, 1.0)
		elif delivered_count > 0:
			_prompt_label.text = "Artefak Terpasang di Pintu (%d/%d)" % [delivered_count, required_relic_count]
		else:
			_prompt_label.text = "Pasang 3 Artefak Waktu (0/%d)" % required_relic_count
		_prompt_label.visible = delivered_count > 0
	if is_fulfilled:
		if _beacon_light:
			_beacon_light.light_color = Color(0.55, 1.0, 0.78)
			_beacon_light.light_energy = 2.8
		var door := get_node_or_null(target_door_path) as Node3D
		if door == null and get_tree() and get_tree().current_scene:
			door = get_tree().current_scene.find_child("TembokKebelah", true, false) as Node3D
		if door and door.has_method("unlock_and_open"):
			door.call("unlock_and_open")
		_reveal_parkour_immediately()
