@tool
class_name ErasedRoomPuzzle
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")
const FragmentScript := preload("res://scripts/gameplay/memory_fragment_pickup.gd")
const ClosetScript := preload("res://scripts/gameplay/closet_hide_spot.gd")
const EraserScript := preload("res://scripts/ai/the_eraser_ai.gd")

## Puzzle 3: The Erased Room + The Eraser (Zona 2 Bawah & Atas)
## Jalur Utama: Kumpulkan 3 Fragmen Waktu (Orrery Emas) di Ruang Atas sebelum dihapus The Eraser.
## Jalur Alternatif: 3 Segel Prisma Segitiga tersebar di Lantai Bawah & Atas (kebal dari penghapusan).
## Mengumpulkan 3 total dari kombinasi kedua jalur membuka segel balkon keluar.

signal fragment_progress_updated(collected: int, total: int)
signal puzzle_completed

var is_solved: bool = false
var collected_count: int = 0
var _total_fragments: int = 3

var _fragments: Array[FragmentScript] = []
var _closet: ClosetScript = null
var _eraser: EraserScript = null
var _exit_gate: Node3D = null
var _fade_props: Array[Node3D] = []
var _fade_mats: Array[StandardMaterial3D] = []
var _warning_label: Label3D = null


func _ready() -> void:
	_build_room_props_and_hiding()
	_build_fragments()
	_build_exit_gate()
	_build_eraser_ai()
	if not Engine.is_editor_hint():
		fragment_progress_updated.emit(collected_count, _total_fragments)


func _build_room_props_and_hiding() -> void:
	# Lemari aman tempat sembunyi [E]
	_closet = get_node_or_null("ClosetHideSpot") as ClosetScript
	if _closet == null:
		_closet = ClosetScript.new()
		_closet.name = "ClosetHideSpot"
		_closet.position = Vector3(48.3, 6.3, 9.6)
		add_child(_closet)
	if not Engine.is_editor_hint() and not _closet.hide_state_changed.is_connected(_on_player_hide_changed):
		_closet.hide_state_changed.connect(_on_player_hide_changed)

	if get_node_or_null("ErasedRoomProp_1") != null:
		return

	# Benda-benda kenangan di dalam kamar atas yang memudar saat The Eraser mendekat
	var props := [
		["res://assets/chap 2/fancy_table.glb", Vector3(52.4, 6.3, -1.6), Vector3(0.45, 0.45, 0.45)],
		["res://assets/chap 2/antique_chair.glb", Vector3(51.2, 6.8, 3.2), Vector3(0.24, 0.24, 0.24)],
		["res://assets/chap 2/case_boxes.glb", Vector3(53.8, 6.3, -7.8), Vector3(0.9, 0.9, 0.9)],
	]
	for idx in range(props.size()):
		var spec: Array = props[idx]
		var res := load(spec[0]) as PackedScene
		if res == null:
			continue
		var prop := res.instantiate() as Node3D
		prop.name = "ErasedRoomProp_%d" % (idx + 1)
		prop.position = spec[1]
		prop.scale = spec[2]
		add_child(prop)
		_fade_props.append(prop)
		for mi in prop.find_children("*", "MeshInstance3D", true, false):
			var mesh_inst := mi as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.55, 0.52, 0.58, 1.0)
			mesh_inst.material_override = mat
			_fade_mats.append(mat)


func _build_fragments() -> void:
	_fragments.clear()
	# Jalur Utama (Orrery Emas di Ruang Atas, dapat dihapus oleh The Eraser saat mode HUNTING)
	# + Jalur Alternatif (Prisma Segitiga tersebar di Lantai Bawah & Atas, kebal penghapusan)
	var specs := [
		["MemoryFragment_1", Vector3(52.4, 7.35, -1.6), "Remembered", "Orrery", true],
		["MemoryFragment_2", Vector3(49.2, 7.25, -8.8), "Forgotten", "Orrery", true],
		["MemoryFragment_3", Vector3(54.8, 7.25, 8.2), "Remembered", "Orrery", true],
		["PrismRelic_1", Vector3(55.5, 0.95, 7.8), "Remembered", "Prism", false],
		["PrismRelic_2", Vector3(84.5, 0.95, -2.5), "Forgotten", "Prism", false],
		["PrismRelic_3", Vector3(83.5, 7.25, 6.2), "Remembered", "Prism", false],
	]
	for s: Array in specs:
		var frag := get_node_or_null(NodePath(s[0])) as FragmentScript
		if frag == null:
			frag = FragmentScript.new()
			frag.name = s[0]
			frag.position = s[1]
			frag.visible_dimension = s[2]
			frag.visual_style = s[3]
			frag.erasable_by_monster = s[4]
			add_child(frag)
		if not Engine.is_editor_hint() and not frag.collected.is_connected(_on_fragment_collected):
			frag.collected.connect(_on_fragment_collected)
		_fragments.append(frag)


func _build_exit_gate() -> void:
	if get_node_or_null("ErasedRoomExitGate") != null:
		_exit_gate = get_node_or_null("ErasedRoomExitGate")
		return
	# Segel penghalang di balkon keluar Lantai 2 menuju Zona 3 (x=94.2, y=6.3, z=2.8)
	_exit_gate = Node3D.new()
	_exit_gate.name = "ErasedRoomExitGate"
	_exit_gate.position = Vector3(94.1, 7.7, 3.0)
	add_child(_exit_gate)

	var barrier := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 3.2, 7.8)
	barrier.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.22, 0.28, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.28, 0.28)
	mat.emission_energy_multiplier = 1.6
	barrier.material_override = mat
	_exit_gate.add_child(barrier)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.45, 3.4, 8.2)
	cs.shape = bs
	sb.add_child(cs)
	_exit_gate.add_child(sb)

	_warning_label = Ch2Utils.create_prompt_label(_exit_gate, Vector3(-0.6, 0.4, 0.0), Color(1.0, 0.65, 0.60), 34)
	_warning_label.no_depth_test = false
	_warning_label.text = "Balkon Tersegel — Kumpulkan 3 Fragmen / Prisma ▲ (0/3)"
	_warning_label.visible = true


func _build_eraser_ai() -> void:
	_eraser = get_node_or_null("TheEraser") as EraserScript
	if _eraser == null:
		_eraser = EraserScript.new()
		_eraser.name = "TheEraser"
		add_child(_eraser)
	if not Engine.is_editor_hint():
		if not _eraser.exposure_changed.is_connected(_on_exposure_changed):
			_eraser.exposure_changed.connect(_on_exposure_changed)
		if _eraser.has_signal("erase_pulse_triggered") and not _eraser.is_connected("erase_pulse_triggered", _on_erase_pulse_triggered):
			_eraser.connect("erase_pulse_triggered", _on_erase_pulse_triggered)


func _on_erase_pulse_triggered(eraser_pos: Vector3) -> void:
	if is_solved:
		return
	# Cari 1 Orrery terdekat yang belum diambil dan hapus oleh The Eraser
	var nearest: FragmentScript = null
	var best_dist := INF
	for frag in _fragments:
		if frag.can_be_erased():
			var d := frag.global_position.distance_to(eraser_pos)
			if d < best_dist:
				best_dist = d
				nearest = frag
	if nearest:
		nearest.erase_by_monster()
		if _warning_label:
			_warning_label.text = "Fragmen dihapus The Eraser! Cari Segel Prisma ▲ (%d/%d)" % [collected_count, _total_fragments]


func _on_player_hide_changed(is_hiding: bool) -> void:
	if _eraser:
		_eraser.set_player_hidden(is_hiding)


func _on_exposure_changed(ratio: float) -> void:
	# Benda-benda di kamar perlahan memudar seiring naiknya ketegangan The Eraser
	var alpha := clampf(1.0 - ratio * 0.85, 0.12, 1.0)
	for m in _fade_mats:
		m.albedo_color.a = alpha


func _on_fragment_collected(_frag: Node3D) -> void:
	if is_solved:
		return
	collected_count += 1
	if _warning_label:
		_warning_label.text = "Balkon Tersegel — Fragmen / Prisma ▲ (%d/%d)" % [collected_count, _total_fragments]
	fragment_progress_updated.emit(collected_count, _total_fragments)
	if collected_count >= _total_fragments:
		_solve()


func _solve() -> void:
	if is_solved:
		return
	is_solved = true
	if _closet and _closet.is_player_hiding:
		_closet.set_hiding(false)
	if _eraser:
		_eraser.vanish()
	for m in _fade_mats:
		m.albedo_color.a = 1.0

	if is_instance_valid(_exit_gate):
		var col := _exit_gate.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred("disabled", true)
		if _warning_label:
			_warning_label.text = "Balkon Terbuka ✓"
			_warning_label.modulate = Color(0.5, 1.0, 0.7)
		var tw := create_tween()
		tw.tween_property(_exit_gate, "scale", Vector3(0.05, 0.05, 0.05), 0.4).set_trans(Tween.TRANS_BACK)
		tw.finished.connect(func() -> void:
			if is_instance_valid(_exit_gate):
				_exit_gate.queue_free()
		)

	puzzle_completed.emit()
