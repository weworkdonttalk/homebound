@tool
extends Node3D
class_name ABCDPuzzleManager

## ABCDPuzzleManager — Mengelola 3 slot puzzle balok ABCD (Chapter 1)
## Mengunci penyelesaian mutlak pada required_count = 3 unik slot terisi.
## Teddy Bear tetap terkunci rapat saat 0/3, 1/3, maupun 2/3.
## Tepat saat 3/3 kotak terpasang, memicu kemunculan Teddy Bear asli di lemari.

const PuzzleSlotScript = preload("res://scripts/puzzle_slot.gd")

signal puzzle_completed

@export var required_count: int = 3
@export var required_slots: int = 3:
	get:
		return required_count
	set(val):
		required_count = val

var is_puzzle_solved: bool = false

func _ready() -> void:
	is_puzzle_solved = false
	_register_slots()
	if not Engine.is_editor_hint():
		_ensure_teddy_locked()


func _register_slots() -> void:
	for child in get_children():
		if child is Area3D:
			if child.has_signal("slot_filled") and not child.is_connected("slot_filled", Callable(self, "_on_slot_filled_signal")):
				child.connect("slot_filled", Callable(self, "_on_slot_filled_signal"))


## Menghitung jumlah slot unik yang benar-benar terisi box
func get_filled_slot_count() -> int:
	var count := 0
	for child in get_children():
		if child is Area3D and child.get("is_filled") == true:
			count += 1
	return count


func _on_slot_filled_signal(_block: Node3D) -> void:
	_check_puzzle_progress()


func notify_slot_filled(_slot: Area3D, _block: Node3D) -> void:
	_check_puzzle_progress()


func _check_puzzle_progress() -> void:
	if is_puzzle_solved:
		return

	var current_filled := get_filled_slot_count()
	print("[ABCD Puzzle] Progres slot terisi: %d/%d" % [current_filled, required_count])

	if current_filled >= required_count:
		is_puzzle_solved = true
		print("[ABCD Puzzle] 3/3 KOTAK LENGKAP! Membuka akses ke Teddy Bear di rak lemari!")
		puzzle_completed.emit()
		_trigger_teddy_reveal()
	else:
		print("[ABCD Puzzle] Masih butuh %d kotak lagi sebelum Teddy Bear muncul. Teddy Bear tetap terkunci." % [required_count - current_filled])
		_ensure_teddy_locked()


func _ensure_teddy_locked() -> void:
	var teddy = get_tree().root.find_child("TeddyBearPickup", true, false)
	if teddy and teddy.has_method("lock_teddy"):
		teddy.call("lock_teddy")


func _trigger_teddy_reveal() -> void:
	var teddy = get_tree().root.find_child("TeddyBearPickup", true, false)
	if teddy and teddy.has_method("unlock_teddy"):
		teddy.call("unlock_teddy")


func _on_slot_filled(_slot: Area3D, _block: Node3D) -> void:
	_check_puzzle_progress()
