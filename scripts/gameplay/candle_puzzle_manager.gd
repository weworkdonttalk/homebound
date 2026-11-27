class_name CandlePuzzleManager
extends Node3D

const MemoryCandleType := preload("res://scripts/gameplay/memory_candle.gd")

## CandlePuzzleManager — Mengelola teka-teki urutan 3 Lilin Kenangan (Chapter 1).
## Aktif otomatis setelah Puzzle 3 Balok ABCD selesai (3/3).
## Urutan yang benar (I -> II -> III) tertulis pada clue di dimensi Forgotten ([T]).
## Setelah 3/3 lilin menyala berurutan, segel Teddy Bear di rak lemari terbuka.

signal candle_progress_updated(lit_count: int, total_count: int)
signal candle_wrong_order
signal puzzle_completed

@export var total_candles: int = 3
@export var is_active: bool = false

var _candles: Array[Node] = []
var _lit_count: int = 0
var _is_solved: bool = false


func _ready() -> void:
	_candles.clear()
	for child in get_children():
		if child is MemoryCandleType:
			_candles.append(child)
			child.call("set_puzzle_active", is_active)
			child.call("set_lit", false)
			if child.has_signal("candle_interacted") and not child.is_connected("candle_interacted", Callable(self, "_on_candle_interacted")):
				child.connect("candle_interacted", Callable(self, "_on_candle_interacted"))


func activate_puzzle() -> void:
	if _is_solved or is_active:
		return
	is_active = true
	_lit_count = 0
	for c in _candles:
		c.call("set_puzzle_active", true)
		c.call("set_lit", false)
	candle_progress_updated.emit(0, total_candles)
	print("[CandlePuzzle] Segel 3 Lilin Kenangan aktif! Cek angka I-III di [T] Forgotten lalu nyalakan berurutan.")


func get_lit_count() -> int:
	return _lit_count


func _on_candle_interacted(candle: Node) -> void:
	if not is_active or _is_solved or candle == null:
		return

	var expected_order := _lit_count + 1
	var order := int(candle.get("sequence_order"))
	if order == expected_order:
		candle.call("set_lit", true)
		_lit_count += 1
		candle_progress_updated.emit(_lit_count, total_candles)
		print("[CandlePuzzle] Lilin #%d menyala (%d/%d)" % [order, _lit_count, total_candles])

		if _lit_count >= total_candles:
			_is_solved = true
			print("[CandlePuzzle] 3/3 Lilin menyala berurutan! Segel Teddy Bear terbuka!")
			puzzle_completed.emit()
			_unlock_teddy_bear()
	else:
		print("[CandlePuzzle] Urutan salah (nyalakan #%d, seharusnya #%d). Semua lilin padam!" % [order, expected_order])
		_lit_count = 0
		for c in _candles:
			c.call("set_lit", false)
		candle.call("show_temporary_message", "Urutan salah! Lilin padam...", Color(1.0, 0.35, 0.32))
		_trigger_error_flicker()
		candle_wrong_order.emit()
		candle_progress_updated.emit(0, total_candles)


func _unlock_teddy_bear() -> void:
	var teddy := get_tree().root.find_child("TeddyBearPickup", true, false)
	if teddy and teddy.has_method("unlock_teddy"):
		teddy.call("unlock_teddy")


func _trigger_error_flicker() -> void:
	var lights_parent := get_tree().current_scene.find_child("SpotLights_TitikFokus", true, false) if get_tree().current_scene else null
	if lights_parent == null:
		return
	for node in lights_parent.get_children():
		if node is SpotLight3D and node.light_energy > 0.5:
			var spot := node as SpotLight3D
			var orig_energy := spot.light_energy
			var tw := create_tween()
			tw.tween_property(spot, "light_energy", orig_energy * 0.2, 0.08)
			tw.tween_property(spot, "light_energy", orig_energy, 0.1)
			tw.tween_property(spot, "light_energy", orig_energy * 0.3, 0.08)
			tw.tween_property(spot, "light_energy", orig_energy, 0.14)
