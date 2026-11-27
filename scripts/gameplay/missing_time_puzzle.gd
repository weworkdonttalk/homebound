class_name MissingTimePuzzle
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")
const DialScript := preload("res://scripts/gameplay/missing_time_dial.gd")

## Puzzle 2: The Missing Time (Zona 2 Bawah — Ruang Jam)
## Di dimensi Forgotten ([T]), 3 jam dinding memperlihatkan angka utuh (IV, VIII, XI).
## Di dimensi Remembered, angka dinding hilang/terhapus dan pemain menyusun 3 pedestal
## ke angka yang tepat untuk membuka akses tangga menuju Lantai 2.

signal progress_updated(matched_count: int, total_count: int)
signal puzzle_completed

const TARGET_NUMBERS: Array[int] = [4, 8, 11] # IV, VIII, XI
const SLOT_OPTIONS: Array = [
	[2, 4, 6, 9],
	[3, 5, 8, 12],
	[1, 7, 10, 11],
]
const ROMAN_NAMES: Array[String] = ["IV", "VIII", "XI"]

@export var stair_zone_path: NodePath = NodePath("../StairAscendZone")

var is_solved: bool = false

var _dials: Array[DialScript] = []
var _clue_clocks: Array[Node3D] = []
var _clue_labels_forgotten: Array[Label3D] = []
var _clue_labels_remembered: Array[Label3D] = []
var _stair_seal: Node3D = null
var _world: Node = null


func _ready() -> void:
	_world = Ch2Utils.find_world_manager(self)
	_build_clue_wall_clocks()
	_build_dial_pedestals()
	_lock_staircase()
	if _world and _world.has_signal("dimension_shifted"):
		if not _world.is_connected("dimension_shifted", _on_dimension_shifted):
			_world.connect("dimension_shifted", _on_dimension_shifted)
	var in_mem: bool = bool(_world.get("in_memory")) if _world and "in_memory" in _world else true
	_on_dimension_shifted(in_mem)
	_emit_progress()


func _build_clue_wall_clocks() -> void:
	var xs := [52.0, 56.8, 61.6]
	for i in range(3):
		var anchor := Node3D.new()
		anchor.name = "MissingTimeWallClue_%d" % (i + 1)
		anchor.position = Vector3(xs[i], 2.55, -13.55)
		add_child(anchor)

		# Jam kuning beranimasi di dinding: jarum menunjuk angka target saat di dimensi Forgotten
		var rig := Ch2Utils.spawn_yellow_clock(anchor, 0.88, true)
		var clock_root: Node3D = rig.get("root", null)
		if clock_root:
			_clue_clocks.append(clock_root)
		Ch2Utils.set_yellow_clock_hour(self, rig, TARGET_NUMBERS[i], 0.0, false)

		var spot := OmniLight3D.new()
		spot.position = Vector3(0.0, 0.2, 1.2)
		spot.light_color = Color(1.0, 0.72, 0.34)
		spot.light_energy = 2.2
		spot.omni_range = 5.5
		anchor.add_child(spot)

		var forg_lbl := Ch2Utils.create_prompt_label(anchor, Vector3(0.0, 1.15, 0.45), Color(1.0, 0.82, 0.36), 54)
		forg_lbl.text = "#%d: %s" % [i + 1, ROMAN_NAMES[i]]
		forg_lbl.visible = false
		_clue_labels_forgotten.append(forg_lbl)

		var rem_lbl := Ch2Utils.create_prompt_label(anchor, Vector3(0.0, 0.05, 0.45), Color(0.55, 0.72, 0.88, 0.75), 42)
		rem_lbl.text = "#%d: ??? (Tekan [T])" % (i + 1)
		rem_lbl.visible = true
		_clue_labels_remembered.append(rem_lbl)


func _build_dial_pedestals() -> void:
	var xs := [52.0, 57.5, 63.0]
	for i in range(3):
		var dial := DialScript.new()
		dial.name = "MissingTimeDial_%d" % (i + 1)
		dial.slot_index = i
		dial.target_value = TARGET_NUMBERS[i]
		var typed_opts: Array[int] = []
		for v: int in SLOT_OPTIONS[i]:
			typed_opts.append(v)
		dial.options = typed_opts
		dial.position = Vector3(xs[i], 0.0, -2.0)
		dial.dial_changed.connect(_on_dial_changed)
		add_child(dial)
		_dials.append(dial)


func _lock_staircase() -> void:
	var stair := get_node_or_null(stair_zone_path)
	if stair == null and get_tree() and get_tree().current_scene:
		stair = get_tree().current_scene.find_child("StairAscendZone", true, false)
	if stair:
		stair.set("is_locked", true)

	# Penghalang visual & fisika tipis di kaki tangga (x=68.66, z=-5.8) agar pemain tahu tangga terkunci
	_stair_seal = Node3D.new()
	_stair_seal.name = "StairTimeSeal"
	_stair_seal.position = Vector3(68.66, 1.35, -5.8)
	add_child(_stair_seal)

	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.2, 2.2, 0.14)
	bar.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.25, 0.25, 0.36)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.28)
	mat.emission_energy_multiplier = 1.4
	bar.material_override = mat
	_stair_seal.add_child(bar)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.2, 2.4, 0.3)
	cs.shape = bs
	sb.add_child(cs)
	_stair_seal.add_child(sb)

	var seal_lbl := Ch2Utils.create_prompt_label(_stair_seal, Vector3(0.0, 1.35, 0.2), Color(1.0, 0.65, 0.55), 32)
	seal_lbl.text = "SEGEL WAKTU: Susun Jam 1-2-3 ([T] lihat petunjuk dinding)"
	seal_lbl.visible = true


func _on_dimension_shifted(is_in_memory: bool) -> void:
	for cc in _clue_clocks:
		cc.visible = not is_in_memory
	for lbl in _clue_labels_forgotten:
		lbl.visible = not is_in_memory
	for lbl in _clue_labels_remembered:
		lbl.visible = is_in_memory


func _on_dial_changed(_dial: Node3D, _val: int, _matched: bool) -> void:
	if is_solved:
		return
	var matched := _emit_progress()
	if matched >= _dials.size():
		_solve()


func _emit_progress() -> int:
	var count := 0
	for d in _dials:
		if d.is_matched():
			count += 1
	progress_updated.emit(count, _dials.size())
	return count


func _solve() -> void:
	if is_solved:
		return
	is_solved = true
	for d in _dials:
		d.lock_solved()

	if is_instance_valid(_stair_seal):
		var col := _stair_seal.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred("disabled", true)
		var tw := create_tween()
		tw.tween_property(_stair_seal, "scale", Vector3(0.05, 0.05, 0.05), 0.35).set_trans(Tween.TRANS_BACK)
		tw.finished.connect(func() -> void:
			if is_instance_valid(_stair_seal):
				_stair_seal.queue_free()
		)

	var stair := get_node_or_null(stair_zone_path)
	if stair == null and get_tree() and get_tree().current_scene:
		stair = get_tree().current_scene.find_child("StairAscendZone", true, false)
	if stair and stair.has_method("unlock"):
		stair.call("unlock")

	puzzle_completed.emit()
