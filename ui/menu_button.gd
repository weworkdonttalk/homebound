class_name StoryMenuButton
extends Button

## A modern horror menu row.
##
## Draws its own tracked uppercase label. The active state (hover or
## keyboard/gamepad focus) is carried by color, not lines: the label
## brightens and leans toward a blood tint, and every couple of seconds it
## glitches in place — a short burst of horizontal jolts, a red ghost copy
## and a few scattered glyphs, smoothed by an attack/decay envelope.
## Letter tracking is applied per glyph because Godot's Font resource is
## shared between every node; per-glyph drawing keeps the spacing local.

@export var label_text: String = "NEW GAME"
@export var display_font: Font

@export_group("Type")
@export var menu_font_size: int = 30
@export var tracking: float = 3.0
@export var centered_label := false

@export_group("Palette")
@export var bone_color: Color = Color("e8e2d4")
@export var accent_color: Color = Color("a12c2c")

@export_group("Glitch")
@export var hover_effect_enabled := true
@export var press_effect_enabled := true
## Seconds until a burst: (minimum, maximum). A fresh activation seeds the
## first burst from first_burst_delay; the loop then uses loop_burst_delay.
@export var first_burst_delay := Vector2(0.5, 0.9)
@export var loop_burst_delay := Vector2(2.0, 3.0)
## Length of one glitch burst and its strength knobs.
@export var burst_duration := 0.35
@export var jolt_strength := 4.0
@export var scatter_strength := 3.0
@export var ghost_alpha := 0.4

var _hover: float = 0.0
var _press: float = 0.0
var _intro_offset: float = 0.0
var _hover_tween: Tween
var _press_tween: Tween

var _rng := RandomNumberGenerator.new()
var _glitch_timer: float = 0.0
var _burst_elapsed: float = -1.0
var _burst_jolts: Array[Dictionary] = []
var _burst_scatter: Dictionary = {}
var _was_active: bool = false
var _selected: bool = false


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rng.randomize()
	_install_empty_styles()
	_connect_interaction()
	queue_redraw()


func _process(delta: float) -> void:
	var active := not disabled and (_selected or (hover_effect_enabled and is_hovered()))

	# Activation bookkeeping: a fresh activation seeds a quick first burst,
	# deactivation cancels anything pending so idle rows never glitch.
	if active and not _was_active:
		_glitch_timer = _rng.randf_range(first_burst_delay.x, first_burst_delay.y)
		_burst_elapsed = -1.0
	elif not active and _was_active:
		_burst_elapsed = -1.0
	_was_active = active

	if _burst_elapsed >= 0.0:
		_burst_elapsed += delta
		if _burst_elapsed >= burst_duration:
			_burst_elapsed = -1.0
			_glitch_timer = _rng.randf_range(loop_burst_delay.x, loop_burst_delay.y)
		queue_redraw()
	elif active:
		_glitch_timer -= delta
		if _glitch_timer <= 0.0:
			_start_burst()


func configure(display_text: String) -> void:
	label_text = display_text.strip_edges().to_upper()
	tooltip_text = ""
	queue_redraw()


func set_metrics(font_size: int, row_height: float) -> void:
	menu_font_size = maxi(14, font_size)
	custom_minimum_size.y = maxf(row_height, 32.0)
	queue_redraw()


func play_intro(delay: float) -> void:
	modulate.a = 0.0
	_intro_offset = -14.0
	queue_redraw()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.38) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_intro_offset, -14.0, 0.0, 0.44) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)


func _install_empty_styles() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)


func _connect_interaction() -> void:
	mouse_entered.connect(_refresh_highlight)
	mouse_exited.connect(_refresh_highlight)
	focus_entered.connect(_refresh_highlight)
	focus_exited.connect(_refresh_highlight)
	if press_effect_enabled:
		button_down.connect(_on_button_down)
		button_up.connect(_on_button_up)


func _refresh_highlight() -> void:
	var active := not disabled and (_selected or (hover_effect_enabled and is_hovered()))
	_animate_hover(1.0 if active else 0.0)


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	_refresh_highlight()


func _animate_hover(target: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_hover, _hover, target, 0.16)


func _set_hover(value: float) -> void:
	_hover = clampf(value, 0.0, 1.0)
	queue_redraw()


func _on_button_down() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_method(_set_press, _press, 1.0, 0.07)


func _on_button_up() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_method(_set_press, _press, 0.0, 0.16)


func _set_press(value: float) -> void:
	_press = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_intro_offset(value: float) -> void:
	_intro_offset = value
	queue_redraw()


func _start_burst() -> void:
	_burst_elapsed = 0.0
	_burst_jolts.clear()
	var start := 0.12
	for _i in 4:
		if start >= burst_duration - 0.08:
			break
		_burst_jolts.append({
			"time": start,
			"duration": _rng.randf_range(0.05, 0.1),
			"offset": _rng.randf_range(jolt_strength * 0.5, jolt_strength)
				* (1.0 if _rng.randf() < 0.5 else -1.0),
		})
		start += _rng.randf_range(0.08, 0.14)
	_burst_scatter.clear()
	var glyph_count := label_text.length()
	if glyph_count > 0:
		var scatter_count := maxi(1, int(round(glyph_count * 0.3)))
		for _i in scatter_count:
			_burst_scatter[_rng.randi_range(0, glyph_count - 1)] = \
				_rng.randf_range(scatter_strength * 0.4, scatter_strength) \
				* (1.0 if _rng.randf() < 0.5 else -1.0)


func _glitch_sample() -> Dictionary:
	if _burst_elapsed < 0.0:
		return {}
	var t := _burst_elapsed
	# Attack/decay envelope: jolts rise fast, the whole burst fades out
	# smoothly so nothing pops in or out hard.
	var env := clampf(t / 0.06, 0.0, 1.0) * clampf((burst_duration - t) / 0.12, 0.0, 1.0)
	var offset := 0.0
	for jolt in _burst_jolts:
		var local: float = t - float(jolt["time"])
		var duration: float = float(jolt["duration"])
		if local >= 0.0 and local <= duration:
			offset += float(jolt["offset"]) * sin(local / duration * PI)
	var scatter: Dictionary = {}
	if env > 0.001:
		for index in _burst_scatter:
			scatter[index] = float(_burst_scatter[index]) * env
	return {
		"offset": offset * env,
		"ghost": ghost_alpha * env,
		"scatter": scatter,
	}


func _draw() -> void:
	if display_font == null:
		return

	var dim := 0.35 if disabled else 1.0
	var h := size.y
	var active := 0.0 if disabled else _hover
	var glitch := _glitch_sample()

	var main_offset := 0.0
	var ghost := 0.0
	var scatter: Dictionary = {}
	if not glitch.is_empty():
		main_offset = float(glitch["offset"])
		ghost = float(glitch["ghost"])
		scatter = glitch["scatter"]

	# Main label: bone white, tracked uppercase, flush with the block's left
	# edge so title, rule and every row share one straight line. Between
	# bursts it never moves — only brightens and leans toward blood red.
	var label_origin := 0.0
	if centered_label:
		label_origin = (size.x - _tracked_width(display_font, label_text, menu_font_size, tracking)) * 0.5
	var label_x := label_origin + _intro_offset + main_offset
	var label_y := (h - display_font.get_height(menu_font_size)) * 0.5 \
		+ display_font.get_ascent(menu_font_size)
	var press_alpha := 1.0 - 0.15 * _press
	var label_color := _alpha(_tinted_bone(active), lerpf(0.60, 1.0, active) * dim * press_alpha)

	# Red ghost copy, offset the other way — chromatic aberration while the
	# glitch is live.
	if ghost > 0.001:
		_draw_tracked(
			display_font, label_text,
			Vector2(label_origin + _intro_offset - main_offset, label_y),
			menu_font_size, tracking,
			_alpha(accent_color, ghost * dim), scatter
		)
	_draw_tracked(display_font, label_text, Vector2(label_x, label_y), menu_font_size, tracking, label_color, scatter)


func _tinted_bone(active: float) -> Color:
	if active <= 0.001:
		return bone_color
	return bone_color.lerp(accent_color, 0.35 * active)


func _draw_tracked(font: Font, text: String, top_left: Vector2, font_size: int, space: float, color: Color, scatter: Dictionary = {}) -> void:
	var x := top_left.x
	for i in text.length():
		var shift := 0.0
		if scatter.has(i):
			shift = float(scatter[i])
		draw_string(font, Vector2(x + shift, top_left.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + space


func _tracked_width(font: Font, text: String, font_size: int, space: float) -> float:
	var width := 0.0
	for i in text.length():
		width += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < text.length() - 1:
			width += space
	return width


func _alpha(color: Color, value: float) -> Color:
	return Color(color.r, color.g, color.b, value)
