class_name MainMenu
extends "res://zero_gravity_float.gd"

const CHAPTER_1_SCENE_PATH := "res://scenes/levels/chapter_1.tscn"
const SETTING_PAGE_SCENE: PackedScene = preload("res://setting.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://pause_menu.tscn")
const QUEST_GUIDE_SCENE: PackedScene = preload("res://quest_guide.tscn")
const DEBUG_HINT_FONT: Font = preload("res://fonts/SpecialElite-Regular.ttf")

## Main menu controller.
##
## The zero-gravity animation loop is inherited from ZeroGravityFloat.
## All presentation lives in main_menu_ui.tscn; this script only listens for
## the UI's semantic signals and transitions into Chapter 1.

@onready var ui: MainMenuUI = get_node_or_null("MainMenuUI") as MainMenuUI
@onready var _camera: Camera3D = get_node_or_null("SubViewportContainer/Camera3D") as Camera3D
@onready var _main_environment: WorldEnvironment = get_node_or_null("MainEnvironment") as WorldEnvironment
@onready var _subviewport_environment: WorldEnvironment = get_node_or_null(
	"SubViewportContainer/SubViewport/WorldEnvironment"
) as WorldEnvironment
var _settings_page: Control
var _brightness_value := 0.55
var _settings_transitioning := false
var _starting_game := false


func _ready() -> void:
	super._ready()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("/root/UIManager"):
		_brightness_value = get_node("/root/UIManager").brightness_value
		_apply_brightness(_brightness_value)
	_connect_ui()
	get_viewport().size_changed.connect(_update_camera_framing)
	_update_camera_framing()


func _connect_ui() -> void:
	if ui == null:
		push_warning("MainMenuUI instance not found; menu signals will not be connected.")
		return

	ui.new_game_requested.connect(_on_new_game_requested)
	ui.load_game_requested.connect(_on_load_game_requested)
	ui.settings_requested.connect(_on_settings_requested)
	ui.quit_confirmed.connect(_on_quit_confirmed)


func _on_new_game_requested() -> void:
	if _starting_game:
		return
	_starting_game = true

	# Nonaktifkan interaksi UI dan fade out menu secara halus
	if ui != null:
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ui_tw := create_tween()
		ui_tw.tween_property(ui, "modulate:a", 0.0, 0.38) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Hentikan osilasi mengambang dan jatuhkan karakter ke bawah
	_is_dropping_out = true
	var drop_duration := 1.05
	var fall_tw := create_tween()
	fall_tw.set_parallel(true)

	# Percepat garis angin agar sensasi jatuh makin terasa
	fall_tw.tween_property(self, "streak_speed", 2600.0, drop_duration * 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if character_node != null and is_instance_valid(character_node):
		var start_pos := character_node.position
		var start_rot := character_node.rotation_degrees
		fall_tw.tween_property(character_node, "position:y", start_pos.y - 3.8, drop_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tw.tween_property(
			character_node,
			"rotation_degrees",
			start_rot + Vector3(10.0, 0.0, -18.0),
			drop_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if envelope_node != null and is_instance_valid(envelope_node):
		var env_pos := envelope_node.position
		fall_tw.tween_property(envelope_node, "position:y", env_pos.y - 1.4, drop_duration * 0.9) \
			.set_delay(0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Mulai fade ke hitam menjelang karakter menghilang ke bawah
	await get_tree().create_timer(0.45).timeout
	if has_node("/root/UIManager"):
		var ui_mgr := get_node("/root/UIManager")
		var fade_tw: Tween = ui_mgr.call("fade_to_black", 0.60)
		if fade_tw != null and fade_tw.is_valid():
			await fade_tw.finished
		ui_mgr.call("transition_to_scene", CHAPTER_1_SCENE_PATH)
	else:
		if fall_tw.is_running():
			await fall_tw.finished
		get_tree().call_deferred("change_scene_to_file", CHAPTER_1_SCENE_PATH)


func _on_load_game_requested() -> void:
	# TODO: wire to a save-slot screen.
	print("[MainMenu] Load Game requested.")


func _on_settings_requested() -> void:
	if is_instance_valid(_settings_page) or _settings_transitioning:
		return
	_settings_page = SETTING_PAGE_SCENE.instantiate() as Control
	_settings_page.modulate.a = 0.0
	_settings_page.connect("close_requested", _on_settings_close_requested)
	_settings_page.connect("brightness_changed", _on_settings_brightness_changed)
	add_child(_settings_page)
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_page.call("set_brightness_value", _brightness_value)
	_settings_transitioning = true
	var tween := create_tween()
	tween.tween_property(_settings_page, "modulate:a", 1.0, 0.24) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _settings_transitioning = false)


func _on_settings_brightness_changed(value: float) -> void:
	_brightness_value = value
	_apply_brightness(value)
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").set_brightness(value)


func _apply_brightness(value: float) -> void:
	var environment_brightness := lerpf(0.65, 1.35, value)
	for world_environment in [_main_environment, _subviewport_environment]:
		if world_environment != null and world_environment.environment != null:
			world_environment.environment.adjustment_brightness = environment_brightness


func _on_settings_close_requested() -> void:
	if not is_instance_valid(_settings_page) or _settings_transitioning:
		return
	_settings_transitioning = true
	var page := _settings_page
	var tween := create_tween()
	tween.tween_property(page, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		page.queue_free()
		_settings_page = null
		_settings_transitioning = false
	)


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _update_camera_framing() -> void:
	# The panel sits to the right in landscape, so the character is composed
	# left of center. In a portrait/narrow window the panel moves to the bottom
	# and the camera shifts its lens to keep the falling character in view.
	if _camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 900.0 or viewport_size.x / viewport_size.y < 1.30
	_camera.h_offset = -0.78 if narrow else 0.0
	_camera.v_offset = -0.38 if narrow else 0.0
