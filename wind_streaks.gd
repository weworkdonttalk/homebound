@tool
class_name WindStreaks
extends Control

## WindStreaks
##
## Senior Godot 4 Technical Artist & Gameplay Programmer solution.
## Creates high-velocity upward vertical "wind speed lines" simulating rapid falling
## through the air, with hand-drawn / sketchy stylized aesthetic, smooth alpha fade-in/fade-out,
## and strict lateral bounds to protect the right-side main menu UI.
##
## Engine: Godot 4.x (1152x648 viewport target).

# ==============================================================================
# INSPECTOR EXPORTS
# ==============================================================================

@export_group("Speed Lines Velocity & Density")
## Rapid upward speed in pixels per second.
## Values between 900.0 and 1500.0 px/s sell terminal-velocity downward falling.
@export_range(200.0, 3000.0, 50.0) var streak_speed: float = 1100.0

## Number of wind streak lines spawned per second (density).
## Kept at a clean, minimalist 14.0 lines/s to create an atmospheric falling mood without clutter.
@export_range(5.0, 200.0, 1.0) var streak_spawn_rate: float = 14.0

## Base tint and maximum opacity of the sketchy lines.
## Subtle semi-transparent light-grey / white captures an elegant sketch concept art aesthetic.
@export var streak_color: Color = Color(0.92, 0.94, 0.98, 0.32)

@export_group("Spawn Bounds & Framing (UI Protection)")
## Minimum X coordinate for line spawning (left padding).
@export_range(0.0, 500.0, 5.0) var streak_area_min_x: float = 30.0

## Maximum X coordinate for line spawning.
## Keeping this around 500.0 ensures streaks only surround the character & envelope,
## leaving the right-aligned menu text ("JUDUL", "NEW GAME", etc.) completely clear.
@export_range(100.0, 1152.0, 10.0) var streak_area_width: float = 500.0

@export_group("Streak Dimensions & Sketchy Aesthetic")
## Minimum vertical length of an individual streak line in pixels.
@export_range(20.0, 200.0, 5.0) var streak_length_min: float = 50.0

## Maximum vertical length of an individual streak line in pixels.
@export_range(50.0, 500.0, 10.0) var streak_length_max: float = 190.0

## Thickness of the streak lines in pixels.
@export_range(0.5, 6.0, 0.5) var streak_thickness: float = 1.3

## Lateral flutter / turbulent jitter intensity in pixels.
@export_range(0.0, 50.0, 1.0) var streak_horizontal_jitter: float = 8.0

## Enables multi-stroke hand-drawn sketch lines (companion micro-lines and tapered feathered ends).
@export var streak_sketch_effect: bool = true

@export_group("Editor Preview")
## Preview wind streaks live in the Godot Editor viewport.
@export var preview_in_editor: bool = false

# ==============================================================================
# INTERNAL STREAK DATA STRUCTURE & POOL
# ==============================================================================

class StreakItem:
	var base_x: float = 0.0
	var x: float = 0.0
	var y: float = 0.0
	var speed: float = 1100.0
	var length: float = 120.0
	var thickness: float = 1.6
	var max_alpha: float = 0.45
	var horizontal_drift: float = 0.0
	var drift_freq: float = 2.0
	var drift_phase: float = 0.0
	var spawn_y: float = 700.0
	var target_y: float = -250.0
	var is_sketch_double: bool = false
	var double_offset: float = 0.0
	var double_length_mult: float = 0.75
	var depth_scale: float = 1.0
	var active: bool = false

var _streaks: Array[StreakItem] = []
var _pool: Array[StreakItem] = []
var _spawn_accumulator: float = 0.0
var _internal_time: float = 0.0
var _viewport_height: float = 648.0

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_dimensions()
	_prewarm_simulation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_dimensions()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		if not _streaks.is_empty():
			_clear_all()
			queue_redraw()
		return

	_internal_time += delta
	_update_dimensions()

	# Spawn new streaks based on spawn rate, guarded against delta spikes
	var safe_rate: float = maxf(streak_spawn_rate, 1.0)
	var spawn_interval: float = 1.0 / safe_rate
	_spawn_accumulator = minf(_spawn_accumulator + delta, spawn_interval * 3.0)

	var spawns_this_frame: int = 0
	while _spawn_accumulator >= spawn_interval and spawns_this_frame < 4:
		_spawn_streak(false)
		_spawn_accumulator -= spawn_interval
		spawns_this_frame += 1

	# Update active streaks
	var i: int = _streaks.size() - 1
	while i >= 0:
		var s: StreakItem = _streaks[i]
		s.y -= s.speed * delta

		# Non-accumulative lateral flutter (sinusoidal oscillation around base_x)
		if streak_horizontal_jitter > 0.0:
			s.x = s.base_x + sin(_internal_time * s.drift_freq + s.drift_phase) * s.horizontal_drift
		else:
			s.x = s.base_x

		# Recycle once the trailing end has completely cleared the top of the screen
		if s.y + s.length * 0.3 < s.target_y:
			s.active = false
			_pool.append(s)
			_streaks.remove_at(i)
		i -= 1

	queue_redraw()

# ==============================================================================
# DRAWING & PROCEDURAL STYLIZATION
# ==============================================================================

func _draw() -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return

	if _streaks.is_empty():
		return

	for s in _streaks:
		# Vertical position-based organic fade:
		# Fades in smoothly as it enters from the bottom edge
		var fade_in: float = smoothstep(_viewport_height + 25.0, _viewport_height - 90.0, s.y)
		# Fades out smoothly as the top of the streak reaches the upper edge (no popping)
		var fade_out: float = smoothstep(-25.0, 110.0, s.y - s.length)
		var current_alpha: float = s.max_alpha * fade_in * fade_out

		if current_alpha <= 0.005:
			continue

		var line_color: Color = streak_color
		line_color.a = current_alpha

		var start_pt := Vector2(s.x, s.y)
		var end_pt := Vector2(s.x, s.y - s.length)

		# 1. Primary Wind Streak Line
		draw_line(start_pt, end_pt, line_color, s.thickness, true)

		# 2. Stylized Sketch Effect (Needle Taper & Feathered Base)
		if streak_sketch_effect:
			# Leading tapered needle tip extending FORWARD beyond end_pt
			var tip_color := line_color
			tip_color.a *= 0.45
			var tip_len: float = s.length * 0.22
			var tip_pt := end_pt - Vector2(0.0, tip_len)
			draw_line(end_pt, tip_pt, tip_color, maxf(0.6, s.thickness * 0.5), true)

			# Hairline extension at the very apex of the needle
			var apex_color := line_color
			apex_color.a *= 0.22
			var apex_pt := tip_pt - Vector2(0.0, tip_len * 0.6)
			draw_line(tip_pt, apex_pt, apex_color, maxf(0.4, s.thickness * 0.25), true)

			# Trailing feathered base extending BACKWARD behind start_pt
			var base_color := line_color
			base_color.a *= 0.30
			var base_len: float = s.length * 0.16
			var base_pt := start_pt + Vector2(0.0, base_len)
			draw_line(start_pt, base_pt, base_color, maxf(0.6, s.thickness * 0.55), true)

			# Secondary sketchy companion stroke (mimics hand-drawn manga speed lines)
			if s.is_sketch_double:
				var comp_color := line_color
				comp_color.a *= 0.40
				var comp_x: float = s.x + s.double_offset
				var comp_start := Vector2(comp_x, s.y - s.length * 0.12)
				var comp_end := Vector2(comp_x, s.y - s.length * s.double_length_mult)
				draw_line(comp_start, comp_end, comp_color, maxf(0.6, s.thickness * 0.6), true)

# ==============================================================================
# SPAWNING & PRE-WARMING
# ==============================================================================

func _spawn_streak(random_initial_y: bool = false) -> void:
	var s: StreakItem = null
	if not _pool.is_empty():
		s = _pool.pop_back()
	else:
		s = StreakItem.new()

	var min_x: float = streak_area_min_x
	var max_x: float = streak_area_width
	if max_x <= min_x:
		max_x = min_x + 100.0

	s.base_x = randf_range(min_x, max_x)
	s.x = s.base_x

	# Varied depth planes: creates subtle parallax and natural sketch layering
	s.depth_scale = randf_range(0.80, 1.30)

	s.length = randf_range(streak_length_min, streak_length_max) * s.depth_scale
	s.thickness = streak_thickness * randf_range(0.75, 1.25) * (0.8 + 0.25 * s.depth_scale)
	s.speed = maxf(streak_speed, 100.0) * randf_range(0.88, 1.18) * s.depth_scale
	s.max_alpha = streak_color.a * randf_range(0.70, 1.05)

	s.horizontal_drift = randf_range(-streak_horizontal_jitter, streak_horizontal_jitter)
	s.drift_freq = randf_range(1.5, 3.5)
	s.drift_phase = randf_range(0.0, TAU)

	s.spawn_y = _viewport_height + 40.0
	s.target_y = -s.length - 60.0

	if random_initial_y:
		# Pre-warm distribution across the whole vertical screen span
		s.y = randf_range(s.target_y + 20.0, s.spawn_y)
	else:
		# Normal bottom spawn
		s.y = s.spawn_y

	s.is_sketch_double = randf() < 0.20
	s.double_offset = randf_range(-3.2, 3.2)
	if absf(s.double_offset) < 1.2:
		s.double_offset = 1.8 if s.double_offset >= 0.0 else -1.8
	s.double_length_mult = randf_range(0.55, 0.88)
	s.active = true

	_streaks.append(s)


func _prewarm_simulation() -> void:
	_clear_all()
	# Pre-populate streaks distributed along the height so speed lines
	# are already flying immediately when the scene starts (clean, atmospheric count)
	var prewarm_count: int = clampi(int(streak_spawn_rate * 0.55), 5, 12)
	for i in range(prewarm_count):
		_spawn_streak(true)


func _clear_all() -> void:
	for s in _streaks:
		s.active = false
		_pool.append(s)
	_streaks.clear()
	_spawn_accumulator = 0.0


func _update_dimensions() -> void:
	if size.y > 10.0:
		_viewport_height = size.y
	elif is_inside_tree() and get_viewport() != null:
		_viewport_height = get_viewport_rect().size.y
	else:
		_viewport_height = 648.0
