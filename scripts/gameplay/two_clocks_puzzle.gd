@tool
class_name TwoClocksPuzzle
extends Node3D

const Ch2Utils := preload("res://scripts/gameplay/chapter2_puzzle_manager.gd")
const DialStationScript := preload("res://scripts/gameplay/clock_dial_station.gd")

## Puzzle 1: The Two Clocks (Zona 1 — Hall Masuk)
## Sinkronkan Jam Remembered (awal 03:00) dan Jam Forgotten (awal 09:00) ke pukul 12:00.
## Setiap jam yang selaras menggerakkan mekanisme tautan di depan pintu2 hingga pintu terbuka.

signal progress_updated(synced_count: int, total_count: int)
signal puzzle_completed

@export var door_node_path: NodePath = NodePath("../pintu2")

var is_solved: bool = false

var _clock_rem: DialStationScript = null
var _clock_forg: DialStationScript = null
var _arch_label: Label3D = null
var _orb_rem_mat: StandardMaterial3D = null
var _orb_forg_mat: StandardMaterial3D = null
var _bridge_rem: MeshInstance3D = null
var _bridge_forg: MeshInstance3D = null


func _ready() -> void:
	_setup_puzzle_nodes()
	if Engine.is_editor_hint():
		return
	_lock_exit_door()
	_emit_progress()


func _setup_puzzle_nodes() -> void:
	# Gunakan node yang sudah ada di scene jika sudah dipasang di Godot Editor
	_clock_rem = get_node_or_null("ClockStationRemembered") as DialStationScript
	if _clock_rem == null:
		_clock_rem = DialStationScript.new()
		_clock_rem.name = "ClockStationRemembered"
		_clock_rem.active_dimension = "Remembered"
		_clock_rem.start_hour = 3
		_clock_rem.target_hour = 12
		_clock_rem.position = Vector3(31.2, 0.0, 1.05)
		add_child(_clock_rem)
	if not Engine.is_editor_hint() and not _clock_rem.hour_changed.is_connected(_on_clock_hour_changed):
		_clock_rem.hour_changed.connect(_on_clock_hour_changed)

	_clock_forg = get_node_or_null("ClockStationForgotten") as DialStationScript
	if _clock_forg == null:
		_clock_forg = DialStationScript.new()
		_clock_forg.name = "ClockStationForgotten"
		_clock_forg.active_dimension = "Forgotten"
		_clock_forg.start_hour = 9
		_clock_forg.target_hour = 12
		_clock_forg.position = Vector3(39.8, 0.0, 1.05)
		add_child(_clock_forg)
	if not Engine.is_editor_hint() and not _clock_forg.hour_changed.is_connected(_on_clock_hour_changed):
		_clock_forg.hour_changed.connect(_on_clock_hour_changed)

	if get_node_or_null("TwoClocksSyncArch") != null:
		return

	# Panel indikator mekanisme & platform tautan di depan pintu2 (x=44.6)
	var arch := Node3D.new()
	arch.name = "TwoClocksSyncArch"
	arch.position = Vector3(44.45, 3.85, 6.42)
	add_child(arch)

	_arch_label = Ch2Utils.create_prompt_label(arch, Vector3(-0.3, 0.55, 0.0), Color(1.0, 0.9, 0.72), 30)
	_arch_label.text = "SINKRONKAN 2 JAM → 12:00"
	_arch_label.visible = true

	_orb_rem_mat = _create_status_orb(arch, "OrbRemembered", Vector3(-0.25, -0.1, -0.55), Color(0.35, 0.85, 1.0))
	_orb_forg_mat = _create_status_orb(arch, "OrbForgotten", Vector3(-0.25, -0.1, 0.55), Color(1.0, 0.68, 0.28))

	# Dua pelat mekanis di lantai menuju pintu2 yang bergeser menutup celah saat jam sinkron
	_bridge_rem = _create_sync_plate("SyncPlateRemembered", Vector3(35.0, 0.04, 6.42), Color(0.24, 0.62, 0.74))
	_bridge_forg = _create_sync_plate("SyncPlateForgotten", Vector3(41.5, 0.04, 6.42), Color(0.75, 0.52, 0.22))


func _create_status_orb(parent: Node3D, node_name: String, pos: Vector3, col: Color) -> StandardMaterial3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	mi.mesh = sph
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col * 0.4
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.45
	mi.material_override = mat
	parent.add_child(mi)
	return mat


func _create_sync_plate(node_name: String, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 0.08, 2.4)
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col * 0.45
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	add_child(mi)
	return mi


func _lock_exit_door() -> void:
	var door := get_node_or_null(door_node_path)
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("pintu2", true, false)
	if door:
		door.set("is_locked", true)
		door.set("locked_hint", "[E] Terkunci — Putar kedua jam ke 12:00")


func _on_clock_hour_changed(_station: Node3D, _hour: int, _synced: bool) -> void:
	if is_solved:
		return
	_update_visual_links()
	_emit_progress()


func _update_visual_links() -> void:
	var rem_ok := _clock_rem != null and _clock_rem.is_synced()
	var forg_ok := _clock_forg != null and _clock_forg.is_synced()

	if _orb_rem_mat:
		_orb_rem_mat.emission = Color(0.4, 1.0, 0.65) if rem_ok else Color(0.35, 0.85, 1.0)
		_orb_rem_mat.emission_energy_multiplier = 2.6 if rem_ok else 0.45
	if _orb_forg_mat:
		_orb_forg_mat.emission = Color(0.4, 1.0, 0.65) if forg_ok else Color(1.0, 0.68, 0.28)
		_orb_forg_mat.emission_energy_multiplier = 2.6 if forg_ok else 0.45

	if _bridge_rem:
		var target_z := 6.42 if rem_ok else 4.9
		create_tween().tween_property(_bridge_rem, "position:z", target_z, 0.4).set_trans(Tween.TRANS_SINE)
	if _bridge_forg:
		var target_z2 := 6.42 if forg_ok else 7.9
		create_tween().tween_property(_bridge_forg, "position:z", target_z2, 0.4).set_trans(Tween.TRANS_SINE)

	if rem_ok and forg_ok:
		_solve()


func _emit_progress() -> void:
	var count := 0
	if _clock_rem and _clock_rem.is_synced():
		count += 1
	if _clock_forg and _clock_forg.is_synced():
		count += 1
	progress_updated.emit(count, 2)


func _solve() -> void:
	if is_solved:
		return
	is_solved = true
	if _clock_rem:
		_clock_rem.lock_synced()
	if _clock_forg:
		_clock_forg.lock_synced()
	if _arch_label:
		_arch_label.text = "JAM SELARAS ✓ — PINTU TERBUKA"
		_arch_label.modulate = Color(0.45, 1.0, 0.68)

	var door := get_node_or_null(door_node_path)
	if door == null and get_tree() and get_tree().current_scene:
		door = get_tree().current_scene.find_child("pintu2", true, false)
	if door and door.has_method("unlock_and_open"):
		door.call("unlock_and_open")

	puzzle_completed.emit()
