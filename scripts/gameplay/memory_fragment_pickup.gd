@tool
class_name MemoryFragmentPickup
extends Node3D

const ORRERY_SCENE_PATH := "res://assets/chap 2/free_celestial_armillary_sphere_steampunk_orrery.glb"
const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")

## Fragmen Ingatan Waktu (Clock Memory Fragment) untuk Puzzle 3 (The Erased Room).
## Dapat diset ke "Remembered" atau "Forgotten" agar pemain memakai [T] untuk menemukannya.

signal collected(fragment: Node3D)
signal erased_by_monster(fragment: Node3D)

@export_enum("Always", "Remembered", "Forgotten") var visible_dimension: String = "Remembered"
@export_enum("Orrery", "Prism") var visual_style: String = "Orrery"
@export var erasable_by_monster: bool = true
@export var interact_range: float = 2.6

var is_collected: bool = false
var is_erased: bool = false

var _visual_core: Node3D = null
var _light: OmniLight3D = null
var _prompt_label: Label3D = null
var _active_in_dim: bool = true
var _player_near: bool = false
var _player: CharacterBody3D = null
var _world: Node = null
var _time_acc: float = 0.0


func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		if _visual_core:
			_visual_core.visible = true
		if _prompt_label:
			var label_tag := "Fragmen Waktu (Orrery)" if visual_style == "Orrery" else "Segel Prisma ▲ (Alternatif)"
			_prompt_label.text = "[E] %s [%s]" % [label_tag, visible_dimension]
			_prompt_label.visible = true
		return
	_world = Ch2Utils.find_world_manager(self)
	_player = Ch2Utils.find_player(self)
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)


func _build_visual() -> void:
	_visual_core = get_node_or_null("FragmentCore") as Node3D
	var expected_tag := "OrreryModel" if visual_style == "Orrery" else "PrismModel"
	if _visual_core != null and _visual_core.get_node_or_null(expected_tag) != null:
		_light = _visual_core.get_node_or_null("FragmentGlow") as OmniLight3D
		_prompt_label = get_node_or_null("InteractionPrompt") as Label3D
		return

	if _visual_core:
		for ch in _visual_core.get_children():
			_visual_core.remove_child(ch)
			ch.queue_free()
	else:
		_visual_core = Node3D.new()
		_visual_core.name = "FragmentCore"
		add_child(_visual_core)

	var col: Color
	if visual_style == "Prism":
		col = Color(0.58, 0.44, 1.0) if visible_dimension != "Forgotten" else Color(1.0, 0.55, 0.85)
		var prism := MeshInstance3D.new()
		prism.name = "PrismModel"
		var pm := PrismMesh.new()
		pm.size = Vector3(0.42, 0.65, 0.42)
		prism.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 2.2
		prism.material_override = mat
		_visual_core.add_child(prism)

		var ring := MeshInstance3D.new()
		ring.name = "PrismRing"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.34
		tm.outer_radius = 0.40
		ring.mesh = tm
		ring.material_override = mat
		_visual_core.add_child(ring)
	else:
		col = Color(0.42, 0.92, 1.0) if visible_dimension != "Forgotten" else Color(1.0, 0.72, 0.32)
		var orrery_res := load(ORRERY_SCENE_PATH) as PackedScene
		if orrery_res:
			var orrery := orrery_res.instantiate() as Node3D
			orrery.name = "OrreryModel"
			orrery.scale = Vector3(0.09, 0.09, 0.09)
			orrery.position = Vector3(0.0, -0.34, 0.0)
			_visual_core.add_child(orrery)

			var ap := orrery.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap and not Engine.is_editor_hint():
				var anims := ap.get_animation_list()
				if not anims.is_empty():
					var anim_name: StringName = anims[0]
					var anim := ap.get_animation(anim_name)
					if anim:
						anim.loop_mode = Animation.LOOP_LINEAR
					ap.play(anim_name)

	_light = OmniLight3D.new()
	_light.name = "FragmentGlow"
	_light.light_color = col
	_light.light_energy = 2.6
	_light.omni_range = 5.5
	_visual_core.add_child(_light)

	_prompt_label = get_node_or_null("InteractionPrompt") as Label3D
	if _prompt_label == null:
		_prompt_label = Ch2Utils.create_prompt_label(self, Vector3(0.0, 0.85, 0.0), Color(1.0, 0.95, 0.78), 32)


func can_be_erased() -> bool:
	return erasable_by_monster and visual_style == "Orrery" and not is_collected and not is_erased


func _on_dimension_shifted(is_in_memory: bool) -> void:
	if is_collected or is_erased:
		return
	match visible_dimension:
		"Remembered":
			_active_in_dim = is_in_memory
		"Forgotten":
			_active_in_dim = not is_in_memory
		_:
			_active_in_dim = true
	if _visual_core:
		_visual_core.visible = _active_in_dim


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or is_collected or is_erased:
		return
	_time_acc += delta
	if _visual_core and _active_in_dim:
		_visual_core.position.y = sin(_time_acc * 2.4) * 0.14
		_visual_core.rotation.y += delta * 1.6

	if _player == null or not is_instance_valid(_player):
		_player = Ch2Utils.find_player(self)
		if _player == null:
			return

	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var same_floor := absf(_player.global_position.y - global_position.y) < 3.0
	_player_near = _active_in_dim and same_floor and dist <= interact_range
	if _prompt_label:
		_prompt_label.visible = _player_near
		if _player_near:
			_prompt_label.text = "[E] Ambil Fragmen Waktu" if visual_style == "Orrery" else "[E] Serap Segel Prisma ▲"


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or is_collected or is_erased or not _player_near or not _active_in_dim:
		return
	if Ch2Utils.is_player_busy(_player):
		return
	if not Ch2Utils.is_interact_pressed(event):
		return
	get_viewport().set_input_as_handled()
	collect()


func collect() -> void:
	if is_collected or is_erased:
		return
	is_collected = true
	_player_near = false
	if _prompt_label:
		_prompt_label.visible = false
	if _visual_core:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_visual_core, "scale", Vector3(1.6, 1.6, 1.6), 0.22)
		tw.tween_property(_visual_core, "position:y", 1.2, 0.22)
		tw.finished.connect(func() -> void:
			if is_instance_valid(_visual_core):
				_visual_core.visible = false
		)
	collected.emit(self)


func erase_by_monster() -> void:
	if not can_be_erased():
		return
	is_erased = true
	_player_near = false
	if _light:
		_light.light_color = Color(1.0, 0.22, 0.22)
		_light.light_energy = 3.4
	if _prompt_label:
		_prompt_label.text = "TERHAPUS OLEH THE ERASER!"
		_prompt_label.modulate = Color(1.0, 0.35, 0.35)
		_prompt_label.visible = true
		get_tree().create_timer(2.4).timeout.connect(func() -> void:
			if is_instance_valid(_prompt_label):
				_prompt_label.visible = false
		)
	if _visual_core:
		var tw := create_tween()
		tw.tween_property(_visual_core, "scale", Vector3(0.02, 0.02, 0.02), 0.35).set_trans(Tween.TRANS_BACK)
		tw.finished.connect(func() -> void:
			if is_instance_valid(_visual_core):
				_visual_core.visible = false
		)
	erased_by_monster.emit(self)
