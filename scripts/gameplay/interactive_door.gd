class_name InteractiveDoor
extends Node3D

## ============================================================================
## Interactive Door System (Gimersia 2.5D Horror)
## Mendukung animasi via AnimationPlayer ("buka", "tutup") atau Tween rotasi engsel.
## Dapat dipicu via script (PuzzleManager, pressure_plate), Area3D trigger, atau tombol [E].
## ============================================================================

signal door_opened
signal door_closed
signal door_toggled(is_open: bool)

@export_group("Door State")
## Status pintu saat inisialisasi
@export var is_open: bool = false
## Apakah pintu terkunci
@export var is_locked: bool = false
## Pesan saat pintu terkunci
@export var locked_message: String = "Pintu ini terkunci rapat dari dalam..."

@export_group("Animation Settings")
## Node engsel pintu yang berputar (jika menggunakan tween)
@export var hinge_node: Node3D = null
## Sudut buka pintu (derajat)
@export var open_angle_degrees: float = -90.0
## Durasi animasi buka/tutup (detik)
@export var animation_duration: float = 1.2
## Node AnimationPlayer (otomatis mencari jika null)
@export var anim_player: AnimationPlayer = null

@export_group("Audio Feedback")
## Audio saat pintu dibuka
@export var sfx_open: AudioStream = null
## Audio saat pintu ditutup
@export var sfx_close: AudioStream = null
## Audio saat pintu terkunci ditekan
@export var sfx_locked: AudioStream = null

var _base_rotation: Vector3 = Vector3.ZERO
var _tween: Tween = null
var _audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	if anim_player == null:
		anim_player = find_child("AnimationPlayer", true, false)

	if hinge_node == null:
		hinge_node = _find_hinge(self)

	if hinge_node:
		_base_rotation = hinge_node.rotation_degrees

	# Buat audio player 3D jika ada sfx
	if sfx_open or sfx_close or sfx_locked:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.max_distance = 25.0
		_audio_player.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		add_child(_audio_player)

	# Set state awal
	if is_open:
		_apply_open_state_instant()

func _find_hinge(node: Node) -> Node3D:
	for child in node.get_children():
		var lower_name = child.name.to_lower()
		if "engsel" in lower_name or "hinge" in lower_name or lower_name == "door":
			if child is Node3D:
				return child
		var res = _find_hinge(child)
		if res:
			return res
	return null

func open_door() -> void:
	if is_locked:
		_play_sfx(sfx_locked)
		return
	if is_open:
		return

	is_open = true
	_play_sfx(sfx_open)

	if anim_player and (anim_player.has_animation("buka") or anim_player.has_animation("open")):
		var anim_name = "buka" if anim_player.has_animation("buka") else "open"
		anim_player.play(anim_name)
	elif hinge_node:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var target_rot = _base_rotation + Vector3(0, open_angle_degrees, 0)
		_tween.tween_property(hinge_node, "rotation_degrees", target_rot, animation_duration)

	door_opened.emit()
	door_toggled.emit(true)

func close_door() -> void:
	if not is_open:
		return

	is_open = false
	_play_sfx(sfx_close)

	if anim_player and (anim_player.has_animation("tutup") or anim_player.has_animation("close")):
		var anim_name = "tutup" if anim_player.has_animation("tutup") else "close"
		anim_player.play(anim_name)
	elif hinge_node:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(hinge_node, "rotation_degrees", _base_rotation, animation_duration)

	door_closed.emit()
	door_toggled.emit(false)

func toggle_door() -> void:
	if is_open:
		close_door()
	else:
		open_door()

func unlock_and_open() -> void:
	is_locked = false
	open_door()

func _apply_open_state_instant() -> void:
	if hinge_node:
		hinge_node.rotation_degrees = _base_rotation + Vector3(0, open_angle_degrees, 0)

func _play_sfx(stream: AudioStream) -> void:
	if stream and _audio_player:
		_audio_player.stream = stream
		_audio_player.play()
