class_name ParkourSequencer
extends Node3D

## ============================================================================
## ParkourSequencer — Mengatur Urutan Kemunculan Platform Parkour (Gimersia)
## Memunculkan batu dan item parkour satu per satu (staggered delay).
## ============================================================================

signal sequence_started
signal platform_popped(index: int, platform: Node3D)
signal all_platforms_popped

## Daftar node platform yang akan dimunculkan berurutan
@export var platforms: Array[Node3D] = []

## Jeda waktu antar pemunculan platform (detik)
@export var stagger_delay: float = 0.35

## Durasi naik tiap platform (detik)
@export var rise_duration: float = 0.85

var is_sequence_running: bool = false
var _popped_count: int = 0

func _ready() -> void:
	# Jika platforms belum diisi di Inspector, otomatis cari platform dari interact atau anak bertipe FloatingObject
	if platforms.is_empty():
		var int_node = get_node_or_null("../interact")
		if int_node:
			for p_name in ["Sketchfab_Scene22", "Sketchfab_Scene2", "Sketchfab_Scene3"]:
				var p = int_node.get_node_or_null(p_name)
				if p:
					platforms.append(p)
		if platforms.is_empty():
			for child in get_children():
				if child.has_method("popup_appear"):
					platforms.append(child)

func trigger_popup_sequence() -> void:
	if is_sequence_running:
		return
	is_sequence_running = true
	_popped_count = 0
	sequence_started.emit()

	if platforms.is_empty():
		all_platforms_popped.emit()
		is_sequence_running = false
		return

	for i in range(platforms.size()):
		var plat = platforms[i]
		if plat and plat.has_method("popup_appear"):
			var delay = float(i) * stagger_delay
			plat.call("popup_appear", delay, rise_duration)
			if plat.has_signal("popped_up"):
				plat.connect("popped_up", Callable(self, "_on_platform_popped").bind(i, plat), CONNECT_ONE_SHOT)

func _on_platform_popped(index: int, plat: Node3D) -> void:
	platform_popped.emit(index, plat)
	_popped_count += 1
	if _popped_count >= platforms.size():
		is_sequence_running = false
		all_platforms_popped.emit()

func reset_platforms() -> void:
	is_sequence_running = false
	_popped_count = 0
	for plat in platforms:
		if plat and plat.has_method("hide_immediately"):
			plat.call("hide_immediately")
