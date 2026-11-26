extends Node3D
class_name WorldManager

# ============================================================================
# WorldManager — Memory Shifting System (Remembered / Forgotten)
# Menghubungkan dimensi ingatan dan dimensi terlupakan dengan visual feedback.
# ============================================================================

@onready var remembered: Node3D = get_node_or_null("remembered")
@onready var forgotten: Node3D = get_node_or_null("forgotten")
@onready var puzzle_manager: Node = get_node_or_null("Chapter1PuzzleManager")
@onready var teddy_pickup: RigidBody3D = get_node_or_null("TeddyBearPickup")
@onready var exit_door: Node3D = get_node_or_null("interact/Sketchfab_Scene5")
@onready var door_portal: Area3D = get_node_or_null("DoorPortal")

@export var in_memory: bool = true

signal dimension_shifted(is_in_memory: bool)

var _hud_label: Label = null
var _shift_flash_rect: ColorRect = null
var _shift_distortion_rect: ColorRect = null
var _shift_distortion_mat: ShaderMaterial = null
var _shift_tween: Tween = null

func _ready() -> void:
	if remembered == null:
		remembered = get_node_or_null("../remembered")
	if forgotten == null:
		forgotten = get_node_or_null("../forgotten")
	if puzzle_manager == null:
		puzzle_manager = get_node_or_null("../Chapter1PuzzleManager")
	if teddy_pickup == null:
		teddy_pickup = get_node_or_null("../TeddyBearPickup")
	if exit_door == null:
		exit_door = get_node_or_null("../interact/Sketchfab_Scene5")
	if door_portal == null:
		door_portal = get_node_or_null("../DoorPortal")

	setup_shift_hud()
	apply_dimension_state(in_memory)
	remove_ceiling()
	_sanitize_item_materials(self)

	# Smooth fade-in transisi dari blinding light Chapter 1
	var fade_layer = get_node_or_null("FadeCanvasLayer")
	if fade_layer:
		var rect = fade_layer.get_node_or_null("ColorRect") as ColorRect
		if rect:
			rect.modulate.a = 1.0
			var tw = create_tween()
			tw.tween_property(rect, "modulate:a", 0.0, 0.8)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_OUT)


func remove_ceiling() -> void:
	var room = get_node_or_null("chapter 1 kosong")
	if room == null:
		room = get_node_or_null("../chapter 1 kosong")
	if room:
		for mesh_inst in room.find_children("*", "MeshInstance3D", true):
			var n_name: String = mesh_inst.name.to_lower()
			if "plane_002" in n_name or "plane.002" in n_name:
				mesh_inst.visible = false
				if mesh_inst.get_parent() and mesh_inst.get_parent() is Node3D:
					(mesh_inst.get_parent() as Node3D).visible = false


func setup_shift_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DimensionHUD"
	canvas.layer = 25
	add_child(canvas)

	# Full-screen Post-Processing Shader (Chromatic Aberration + Lens Distortion)
	var shift_shader := load("res://shaders/dimension_shift_transition.gdshader") as Shader
	if shift_shader:
		_shift_distortion_mat = ShaderMaterial.new()
		_shift_distortion_mat.shader = shift_shader
		_shift_distortion_mat.set_shader_parameter("shift_strength", 0.0)
		_shift_distortion_mat.set_shader_parameter("aberration_amount", 0.028)
		_shift_distortion_mat.set_shader_parameter("distortion_amount", 0.032)

		_shift_distortion_rect = ColorRect.new()
		_shift_distortion_rect.name = "ShiftDistortionOverlay"
		_shift_distortion_rect.material = _shift_distortion_mat
		_shift_distortion_rect.anchors_preset = Control.PRESET_FULL_RECT
		_shift_distortion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(_shift_distortion_rect)

	# Flash overlay for memory shift feedback (subtle glow / dim flash)
	_shift_flash_rect = ColorRect.new()
	_shift_flash_rect.name = "ShiftFlash"
	_shift_flash_rect.anchors_preset = Control.PRESET_FULL_RECT
	_shift_flash_rect.color = Color(0.12, 0.35, 0.30, 0.0)
	_shift_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_shift_flash_rect)

	# Text HUD
	_hud_label = Label.new()
	_hud_label.name = "DimensionLabel"
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.anchors_preset = Control.PRESET_TOP_LEFT
	_hud_label.offset_left = 32.0
	_hud_label.offset_top = 28.0

	var settings := LabelSettings.new()
	settings.font_size = 18
	settings.font_color = Color(0.4, 0.85, 1.0)
	settings.outline_size = 5
	settings.outline_color = Color(0.02, 0.04, 0.08, 0.95)
	_hud_label.label_settings = settings
	canvas.add_child(_hud_label)

	_update_hud_display()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shifting"):
		toggle_dimension()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T or event.physical_keycode == KEY_T:
			toggle_dimension()


func _process(_delta: float) -> void:
	# Fallback poll jika input event terlewat
	if Input.is_action_just_pressed("shifting"):
		toggle_dimension()


func toggle_dimension() -> void:
	in_memory = not in_memory
	apply_dimension_state(in_memory)
	play_shift_effect()
	_update_hud_display()
	dimension_shifted.emit(in_memory)


func play_shift_effect() -> void:
	if _shift_tween and _shift_tween.is_valid():
		_shift_tween.kill()

	_shift_tween = create_tween()

	# Warna kilatan redup psikologis (dim eerie pulse)
	# Dimensi Ingatan (Remembered): Cyan kusam dingin
	# Dimensi Terlupakan (Forgotten): Kuning tembaga kusam pengap
	var pulse_tint := Color(0.10, 0.32, 0.28, 0.26) if in_memory else Color(0.35, 0.22, 0.12, 0.26)

	# 1. Shader Transisi: Chromatic Aberration & Lens Distortion
	if _shift_distortion_mat:
		_shift_distortion_mat.set_shader_parameter("flash_color", pulse_tint)
		_shift_distortion_mat.set_shader_parameter("shift_strength", 1.0)
		_shift_tween.tween_method(
			func(val: float) -> void: _shift_distortion_mat.set_shader_parameter("shift_strength", val),
			1.0, 0.0, 0.38
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 2. Kilatan cahaya redup pudar (fallback & penguat mood)
	if _shift_flash_rect:
		_shift_flash_rect.color = pulse_tint
		_shift_tween.parallel().tween_property(_shift_flash_rect, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 3. Camera shudder / micro-shake untuk sensasi disorientasi psikologis
	var cam_rig = get_node_or_null("CameraRig")
	if cam_rig == null:
		cam_rig = get_node_or_null("../CameraRig")
	if cam_rig and cam_rig.has_method("trigger_dimension_shake"):
		cam_rig.call("trigger_dimension_shake", 0.35, 0.16)

	# 4. Efek Visual Jam Waktu (Time Stop Effect) pada karakter utama
	var player = get_node_or_null("Player")
	if player == null:
		player = get_node_or_null("../Player")
	if player:
		var time_effect = player.get_node_or_null("TimeStopEffect")
		if time_effect and time_effect.has_method("trigger_shift"):
			time_effect.call("trigger_shift", in_memory)


func _update_hud_display() -> void:
	if _hud_label == null:
		return

	if in_memory:
		_hud_label.text = "[T] Dimensi: DUNIA INGATAN (Remembered)"
		if _hud_label.label_settings:
			_hud_label.label_settings.font_color = Color(0.4, 0.88, 1.0)
	else:
		_hud_label.text = "[T] Dimensi: DUNIA TERLUPAKAN (Forgotten)"
		if _hud_label.label_settings:
			_hud_label.label_settings.font_color = Color(1.0, 0.72, 0.35)


func apply_dimension_state(mem_active: bool) -> void:
	if remembered:
		remembered.visible = true
		for child in remembered.get_children():
			var c_name: String = child.name.to_lower()
			# Perabot kamar utama (kasur, meja, rak, lilin, mainan, balok di area x < 22) selalu permanen dan tidak hilang saat shifting
			var is_permanent_furniture: bool = (
				"scene5" in c_name or "scene6" in c_name or "scene7" in c_name or
				"scene8" in c_name or "scene9" in c_name or "scene10" in c_name or
				"scene11" in c_name or "scene12" in c_name or "scene13" in c_name or
				"scene14" in c_name or "scene15" in c_name or "pushabletoyblock" in c_name or
				child.position.x < 22.0
			)
			if is_permanent_furniture:
				child.visible = true
				_set_collisions(child, true)
			else:
				# Objek puzzle platform alternatif dimensi
				child.visible = mem_active
				_set_collisions(child, mem_active)

	if forgotten:
		forgotten.visible = not mem_active
		_set_collisions(forgotten, not mem_active)

	# Objek boneka eksisting hanya dapat diakses setelah di-unlock oleh Puzzle 3 Box
	if teddy_pickup:
		var can_access := true
		if "is_unlocked" in teddy_pickup:
			can_access = teddy_pickup.is_unlocked
		teddy_pickup.visible = can_access
		var col = teddy_pickup.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred("disabled", not can_access)

	# Pintu portal keluar hanya muncul di Dunia Ingatan (Remembered Dimension)
	if exit_door:
		exit_door.visible = mem_active
		_set_collisions(exit_door, mem_active)
	if door_portal:
		door_portal.visible = mem_active
		door_portal.set_deferred("monitoring", mem_active)
		door_portal.set_deferred("monitorable", mem_active)

	if puzzle_manager and puzzle_manager.has_method("validate_dimension_collision"):
		puzzle_manager.call("validate_dimension_collision", "remembered" if mem_active else "forgotten")

	_sanitize_item_materials(self)


func _set_collisions(node: Node, active: bool) -> void:
	if node is CollisionShape3D:
		node.set_deferred("disabled", not active)
	elif node is RigidBody3D:
		node.set_deferred("freeze", not active)

	for child in node.get_children():
		_set_collisions(child, active)


func _sanitize_item_materials(root_node: Node) -> void:
	if root_node == null:
		return
	for mi in root_node.find_children("*", "MeshInstance3D", true):
		var mesh_inst: MeshInstance3D = mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue

		var p_path: String = str(mesh_inst.get_path()).to_lower() if mesh_inst.is_inside_tree() else mesh_inst.name.to_lower()
		# Jangan ubah struktur ruangan/dinding, karakter utama, partikel debu, effect jam, glowing platform, gerbang cahaya portal, atau ghost hint
		if "chapter 1 kosong" in p_path or "char no light" in p_path or "dustparticles" in p_path or "timestop" in p_path or "glowingplatforms" in p_path or "portal" in p_path or "hint" in p_path or "ghost" in p_path:
			continue

		# Deteksi apakah node ini merupakan bagian dari mainan / item interaktif
		var is_toy: bool = false
		var curr: Node = mesh_inst
		while curr and curr != root_node:
			var c_name: String = curr.name.to_lower()
			if c_name in ["sketchfab_scene8", "sketchfab_scene22", "sketchfab_scene2", "sketchfab_scene7", "sketchfab_scene13", "sketchfab_scene19", "pushabletoyblock", "abc_toy_model"]:
				is_toy = true
				break
			if "toy" in c_name or "cube" in c_name or "car" in c_name or "duck" in c_name or "bear" in c_name or "block" in c_name:
				is_toy = true
				break
			curr = curr.get_parent()

		for s in range(mesh_inst.mesh.get_surface_count()):
			var mat: Material = mesh_inst.get_surface_override_material(s)
			if mat == null:
				mat = mesh_inst.mesh.surface_get_material(s)

			if mat is StandardMaterial3D:
				var sm: StandardMaterial3D = mat
				var changed: bool = false
				var new_sm: StandardMaterial3D = sm.duplicate() as StandardMaterial3D

				# 1. Hentikan unshaded (penyebab utama truk mainan / toy_car menyala sendiri di kegelapan)
				if new_sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
					new_sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					changed = true

				# 2. Matikan emission pada props (kecuali api lilin aktif jika ada)
				if new_sm.emission_enabled and not ("candle" in p_path and "flame" in new_sm.resource_name.to_lower()):
					new_sm.emission_enabled = false
					changed = true

				# 3. Kunci roughness >= 0.75 agar material tidak mengkilap berlebihan seperti kaca/plastik basah (khususnya teddybear dan balok mainan)
				if new_sm.roughness < 0.75:
					new_sm.roughness = 0.85
					changed = true

				# 4. Hilangkan metallic pada benda non-logam
				if new_sm.metallic > 0.0 and not ("door" in p_path or "lever" in p_path):
					new_sm.metallic = 0.0
					changed = true

				# 5. Redupkan albedo mainan & item yang terlalu mencolok/jenuh di ruangan horor gelap agar menyatu alami ala Little Nightmares
				if is_toy:
					new_sm.albedo_color = Color(0.42, 0.42, 0.40, 1.0)
					changed = true
				else:
					var c: Color = new_sm.albedo_color
					if (c.r + c.g + c.b) > 2.5:
						new_sm.albedo_color = Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, c.a)
						changed = true

				if changed:
					mesh_inst.set_surface_override_material(s, new_sm)
