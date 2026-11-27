@tool
class_name MemoryCandle
extends Node3D

## MemoryCandle — Lilin Puzzle Babak 2 Chapter 1.
## Urutan nyala (sequence_order: 1..3) tersembunyi di dimensi Forgotten ([T]).
## Pemain menyalakan lilin di dimensi Remembered menggunakan tombol [E].

signal candle_interacted(candle: MemoryCandle)

@export var sequence_order: int = 1
@export var interact_range: float = 2.8

var puzzle_active: bool = false
var is_lit: bool = false

var _flame_mesh: MeshInstance3D = null
var _flame_light: OmniLight3D = null
var _prompt_label: Label3D = null
var _base_light_energy: float = 0.0
var _flicker_time: float = 0.0
var _wrong_flash_until: int = 0
var _wrong_message: String = ""


func _ready() -> void:
	_setup_visuals()
	if not Engine.is_editor_hint():
		_refresh_visual_state()


func _setup_visuals() -> void:
	# 1. Plinth batu gelap agar lilin berdiri setinggi pinggang & jelas di viewport
	var plinth := get_node_or_null("PlinthMesh") as MeshInstance3D
	if plinth == null:
		plinth = MeshInstance3D.new()
		plinth.name = "PlinthMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.42
		cyl.height = 0.95
		plinth.mesh = cyl
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.14, 0.13, 0.14, 1.0)
		pmat.roughness = 0.92
		plinth.material_override = pmat
		plinth.position = Vector3(0.0, 0.475, 0.0)
		add_child(plinth)

	var body := get_node_or_null("PlinthBody") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "PlinthBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var cshape := CylinderShape3D.new()
		cshape.radius = 0.42
		cshape.height = 0.95
		col.shape = cshape
		col.position = Vector3(0.0, 0.475, 0.0)
		body.add_child(col)
		add_child(body)

	# 2. Model lilin dari aset proyek
	var model := get_node_or_null("CandleModel") as Node3D
	if model == null:
		var res := load("res://assets/environment/props/interactables/simple_candle_in_candle_holder.glb") as PackedScene
		if res:
			model = res.instantiate() as Node3D
			model.name = "CandleModel"
			model.position = Vector3(0.0, 0.95, 0.0)
			model.scale = Vector3(0.75, 0.75, 0.75)
			add_child(model)

	# 3. Mesh api & OmniLight3D hangat
	_flame_mesh = get_node_or_null("CandleFlameMesh") as MeshInstance3D
	if _flame_mesh == null:
		_flame_mesh = MeshInstance3D.new()
		_flame_mesh.name = "CandleFlameMesh"
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.16
		_flame_mesh.mesh = sm
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = Color(1.0, 0.76, 0.28, 1.0)
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.58, 0.16)
		fmat.emission_energy_multiplier = 3.2
		_flame_mesh.material_override = fmat
		_flame_mesh.position = Vector3(0.0, 1.48, 0.0)
		add_child(_flame_mesh)

	_flame_light = get_node_or_null("CandleFlameLight") as OmniLight3D
	if _flame_light == null:
		_flame_light = OmniLight3D.new()
		_flame_light.name = "CandleFlameLight"
		_flame_light.position = Vector3(0.0, 1.62, 0.0)
		_flame_light.light_color = Color(1.0, 0.68, 0.30, 1.0)
		_flame_light.omni_range = 6.5
		_flame_light.omni_attenuation = 1.4
		_flame_light.shadow_enabled = false
		add_child(_flame_light)

	# 4. Prompt interaksi 3D
	_prompt_label = get_node_or_null("InteractionPrompt") as Label3D
	if _prompt_label == null:
		_prompt_label = Label3D.new()
		_prompt_label.name = "InteractionPrompt"
		_prompt_label.position = Vector3(0.0, 2.05, 0.0)
		_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt_label.font_size = 34
		_prompt_label.outline_size = 8
		_prompt_label.outline_modulate = Color(0.04, 0.04, 0.05, 0.95)
		add_child(_prompt_label)

	if Engine.is_editor_hint():
		_flame_mesh.visible = true
		_flame_light.light_energy = 0.45
		_prompt_label.visible = false


func set_puzzle_active(active: bool) -> void:
	puzzle_active = active
	_refresh_visual_state()


func set_lit(lit: bool) -> void:
	is_lit = lit
	_refresh_visual_state()


func show_temporary_message(msg: String, color: Color = Color(1.0, 0.45, 0.38)) -> void:
	_wrong_message = msg
	_wrong_flash_until = Time.get_ticks_msec() + 1400
	if _prompt_label:
		_prompt_label.modulate = color
		_prompt_label.text = msg
		_prompt_label.visible = true


func _refresh_visual_state() -> void:
	if _flame_mesh:
		_flame_mesh.visible = is_lit
	if is_lit:
		_base_light_energy = 2.6
	elif puzzle_active:
		_base_light_energy = 0.22
	else:
		_base_light_energy = 0.0
	if _flame_light:
		_flame_light.light_energy = _base_light_energy


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _flame_light and _base_light_energy > 0.0:
		_flicker_time += delta * (8.5 if is_lit else 3.2)
		var jitter := sin(_flicker_time) * 0.14 + sin(_flicker_time * 2.3) * 0.08
		_flame_light.light_energy = maxf(0.05, _base_light_energy + jitter * (_base_light_energy * 0.25))

	_update_prompt()


func _get_player() -> Node3D:
	return get_tree().root.find_child("Player", true, false) as Node3D


func _is_world_in_memory() -> bool:
	var wm := get_tree().root.find_child("WorldManager", true, false)
	if wm == null:
		wm = get_tree().current_scene
	if wm and "in_memory" in wm:
		return bool(wm.get("in_memory"))
	return true


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	var now := Time.get_ticks_msec()
	if now < _wrong_flash_until:
		_prompt_label.text = _wrong_message
		_prompt_label.visible = true
		return

	var player := _get_player()
	if player == null or is_lit:
		_prompt_label.visible = false
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > interact_range:
		_prompt_label.visible = false
		return

	_prompt_label.visible = true
	if not puzzle_active:
		_prompt_label.modulate = Color(0.72, 0.72, 0.76)
		_prompt_label.text = "Lilin Terkunci\n(Susun 3 Balok ABCD dulu)"
	elif not _is_world_in_memory():
		_prompt_label.modulate = Color(0.55, 0.85, 1.0)
		_prompt_label.text = "Gunakan [T] Remembered\nuntuk menyalakan"
	elif "item_dipegang" in player and player.item_dipegang != null:
		_prompt_label.modulate = Color(0.95, 0.80, 0.45)
		_prompt_label.text = "Taruh barang dulu [E]"
	else:
		_prompt_label.modulate = Color(1.0, 0.88, 0.56)
		_prompt_label.text = "[E] Nyalakan Lilin"


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not puzzle_active or is_lit:
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return

	var player := _get_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > interact_range:
		return
	if "item_dipegang" in player and player.item_dipegang != null:
		return

	if not _is_world_in_memory():
		show_temporary_message("Pindah ke [T] Remembered dulu!", Color(0.55, 0.85, 1.0))
		get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()
	candle_interacted.emit(self)
