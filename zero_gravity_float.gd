@tool
class_name ZeroGravityFloat
extends Node

const WindStreaksClass = preload("res://wind_streaks.gd")
const DivineLightClass = preload("res://divine_light.gd")
const DarkCloudsClass = preload("res://dark_clouds.gd")

## ZeroGravityFloat
##
## Senior Godot 4 Technical Artist & Gameplay Programmer solution.
## Creates a seamless, stylized "falling through the air / zero-gravity floating" system:
##   1. Upward wind speed lines (falling illusion) with hand-drawn sketch styling & organic fade.
##   2. Weightless floating oscillation for the 3D low-poly character and wax-sealed envelope.
##   3. Desynchronized phase lag & mass flutter for the envelope against air resistance.
##   4. Secondary aerodynamic extremity drag (limbs gently trailing against upward wind).
##   5. Clean UI preservation ensuring right-aligned menu text ("JUDUL", "NEW GAME", etc.)
##      remains 100% unobstructed.
##
## Engine: Godot 4.x (1152x648 viewport target).
## Attachable to:
##   - Root Control (e.g. MainMenu)
##   - Any Node3D (e.g. Falling mesh, letter2, or parent Node3D)
##   - SubViewportContainer / SubViewport
##   - Dedicated standalone Node in the scene tree

# ==============================================================================
# INSPECTOR EXPORTS
# ==============================================================================

@export_group("Target Nodes")
## Character Node3D (auto-detected if null).
@export var character_node: Node3D:
	set(value):
		character_node = value
		if is_inside_tree() and character_node != null:
			_store_char_initial_transform()

## Wax-sealed Envelope Node3D (auto-detected if null).
@export var envelope_node: Node3D:
	set(value):
		envelope_node = value
		if is_inside_tree() and envelope_node != null:
			_store_env_initial_transform()

## Optional Skeleton3D for extremity drag (auto-detected if null).
@export var character_skeleton: Skeleton3D:
	set(value):
		character_skeleton = value
		if is_inside_tree():
			_detect_extremities()

## Optional DivineLight Node3D (auto-detected or spawned if null).
@export var divine_light_node: Node3D:
	set(value):
		divine_light_node = value
		_sync_atmospheric_settings()

## Optional DarkClouds Node3D (auto-detected or spawned if null).
@export var dark_clouds_node: Node3D:
	set(value):
		dark_clouds_node = value
		_sync_atmospheric_settings()

## Optional WindStreaks 2D overlay node (auto-detected or spawned if null).
@export var wind_streaks_node: Control:
	set(value):
		wind_streaks_node = value
		_sync_wind_streak_settings()

const DEFAULT_FLOAT_SPEED: float = 0.6

@export_group("Atmosphere (Divine Light & Dark Clouds)")
## Enable / disable the divine light beam highlighting the falling character from the void above.
@export var enable_divine_light: bool = true:
	set(value):
		enable_divine_light = value
		_sync_atmospheric_settings()

## Luminescence multiplier for the divine volumetric beam.
@export_range(0.5, 3.0, 0.05) var beam_intensity: float = 1.35:
	set(value):
		beam_intensity = value
		_sync_atmospheric_settings()

## Energy intensity of the overhead celestial spotlight highlighting the character and envelope.
@export_range(0.0, 4.0, 0.05) var spotlight_energy: float = 1.35:
	set(value):
		spotlight_energy = value
		_sync_atmospheric_settings()

## Enable celestial sparkling motes (holy dust) drifting within the light shaft.
@export var enable_motes: bool = true:
	set(value):
		enable_motes = value
		_sync_atmospheric_settings()

## Enable / disable stylized dark clouds and drifting fog in the background and atmosphere.
@export var enable_dark_clouds: bool = true:
	set(value):
		enable_dark_clouds = value
		_sync_atmospheric_settings()

## Speed multiplier for storm cloud drift and billowing.
@export_range(0.1, 4.0, 0.05) var cloud_speed: float = 1.0:
	set(value):
		cloud_speed = value
		_sync_atmospheric_settings()

## Enable 3D cloud puffs drifting upward across depths around the character.
@export var enable_3d_puffs: bool = true:
	set(value):
		enable_3d_puffs = value
		_sync_atmospheric_settings()

@export_group("Wind Speed Lines (Falling Effect)")
## Upward velocity of the wind speed lines in pixels per second.
## Values between 900.0 and 1500.0 px/s sell rapid terminal downward falling.
@export_range(200.0, 3000.0, 50.0) var streak_speed: float = 1100.0:
	set(value):
		streak_speed = value
		_sync_wind_streak_settings()

## Density / number of wind streaks spawned per second.
## Kept at a clean, minimalist 14.0 lines/s to create an atmospheric falling mood without clutter.
@export_range(5.0, 200.0, 1.0) var streak_spawn_rate: float = 14.0:
	set(value):
		streak_spawn_rate = value
		_sync_wind_streak_settings()

## Color and base opacity of the wind speed lines.
## Subtle semi-transparent light-grey/white captures an elegant sketch concept art aesthetic.
@export var streak_color: Color = Color(0.92, 0.94, 0.98, 0.32):
	set(value):
		streak_color = value
		_sync_wind_streak_settings()

## Maximum X coordinate for streak spawning.
## Keeps streaks strictly on the left half of the screen (around character and envelope),
## leaving the right-side menu text and buttons completely static and unobstructed.
@export_range(100.0, 1152.0, 10.0) var streak_area_width: float = 500.0:
	set(value):
		streak_area_width = value
		_sync_wind_streak_settings()

## Minimum X coordinate for streak spawning (left margin).
@export_range(0.0, 500.0, 5.0) var streak_area_min_x: float = 30.0:
	set(value):
		streak_area_min_x = value
		_sync_wind_streak_settings()

## Minimum vertical length of an individual streak line in pixels.
@export_range(20.0, 200.0, 5.0) var streak_length_min: float = 50.0:
	set(value):
		streak_length_min = value
		_sync_wind_streak_settings()

## Maximum vertical length of an individual streak line in pixels.
@export_range(50.0, 500.0, 10.0) var streak_length_max: float = 190.0:
	set(value):
		streak_length_max = value
		_sync_wind_streak_settings()

## Line thickness in pixels.
@export_range(0.5, 6.0, 0.5) var streak_thickness: float = 1.3:
	set(value):
		streak_thickness = value
		_sync_wind_streak_settings()

## Lateral turbulence / sketch flutter in pixels.
@export_range(0.0, 50.0, 1.0) var streak_horizontal_jitter: float = 8.0:
	set(value):
		streak_horizontal_jitter = value
		_sync_wind_streak_settings()

## Enables multi-stroke hand-drawn sketch lines (companion micro-lines and feathered ends).
@export var streak_sketch_effect: bool = true:
	set(value):
		streak_sketch_effect = value
		_sync_wind_streak_settings()

## Enable / disable wind speed lines entirely.
@export var enable_wind_streaks: bool = true:
	set(value):
		enable_wind_streaks = value
		_sync_wind_streak_settings()

@export_group("Buoyancy (Primary Float)")
## Vertical amplitude of the primary oscillation in 3D units (meters).
@export_range(0.005, 0.5, 0.005, "or_greater") var float_amplitude: float = 0.06
## Speed of vertical oscillation in radians/sec.
## 0.6 rad/s corresponds to a period of ~10.47s (2*PI / 0.6), producing a serene, ethereal zero-gravity float.
@export_range(0.05, 3.0, 0.05) var float_speed: float = 0.6
## Enable subtle lateral/depth currents in addition to vertical buoyancy.
@export var enable_horizontal_drift: bool = true
## Scale of lateral drift relative to float_amplitude.
@export_range(0.0, 1.0, 0.05) var horizontal_drift_scale: float = 0.25

@export_group("Rotational Drift (Pitch & Roll)")
## Maximum tilt angle in degrees for asynchronous swaying (±3° to 6° recommended).
@export_range(0.5, 15.0, 0.1) var tilt_angle: float = 3.5
## Pitch (X-axis) frequency multiplier relative to float_speed.
## 0.75 gives 3 complete cycles per 4 primary float cycles for seamless looping.
@export_range(0.05, 2.0, 0.05) var pitch_speed_mult: float = 0.75
## Roll (Z-axis) frequency multiplier relative to float_speed.
## 0.50 gives 2 complete cycles per 4 primary float cycles (incommensurate Lissajous drift).
@export_range(0.05, 2.0, 0.05) var roll_speed_mult: float = 0.50
## Yaw (Y-axis) frequency multiplier for subtle orientation drift.
## 0.25 gives 1 complete cycle per 4 primary float cycles.
@export_range(0.05, 2.0, 0.05) var yaw_speed_mult: float = 0.25

@export_group("Envelope Desynchronization")
## Phase lag of the envelope behind the character's movement in radians.
## At float_speed = 0.6, 0.85 rad equates to ~1.42s phase lag (~13.5% of cycle).
@export_range(0.0, 6.283, 0.05) var envelope_phase_offset: float = 0.85
## Amplitude multiplier for the envelope (lighter object displaces slightly more).
@export_range(0.2, 3.0, 0.05) var envelope_amplitude_mult: float = 1.25
## Rotational flutter multiplier for the envelope.
@export_range(0.2, 3.0, 0.05) var envelope_tilt_mult: float = 1.25

@export_group("Secondary Motion (Limb Drag)")
## Drag intensity applied to extremities (arms, legs, head) based on vertical velocity.
@export_range(0.0, 10.0, 0.1) var limb_drag_intensity: float = 1.0
## Smoothing responsiveness rate for limb inertia (exponential decay).
@export_range(0.5, 20.0, 0.5) var limb_drag_responsiveness: float = 4.0

@export_group("Editor Preview")
## Preview animation, wind streaks, divine light, and clouds live in the Godot Editor viewport.
@export var preview_in_editor: bool = false:
	set(value):
		preview_in_editor = value
		if preview_in_editor:
			_resolve_targets()
			_store_initial_transforms()
			_setup_wind_streaks()
			_setup_atmospheric_effects()
		else:
			_reset_transforms()
		_sync_wind_streak_settings()
		_sync_atmospheric_settings()

# ==============================================================================
# PRIVATE STATE
# ==============================================================================

var _time: float = 0.0
var _initial_char_pos: Vector3 = Vector3.ZERO
var _initial_char_rot: Vector3 = Vector3.ZERO
var _initial_env_pos: Vector3 = Vector3.ZERO
var _initial_env_rot: Vector3 = Vector3.ZERO

var _extremity_bones: Array[int] = []
var _bone_rest_rotations: Dictionary = {}
var _limb_nodes: Array[Node3D] = []
var _limb_initial_rotations: Dictionary = {}
var _current_limb_drag: float = 0.0
var _is_initialized: bool = false
var _auto_spawned_wind_streaks: bool = false
var _auto_spawned_divine_light: bool = false
var _auto_spawned_dark_clouds: bool = false
var _is_dropping_out: bool = false

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_resolve_targets()
	_store_initial_transforms()
	_setup_wind_streaks()
	_setup_atmospheric_effects()
	_is_initialized = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return

	if not _is_initialized:
		_resolve_targets()
		_store_initial_transforms()
		_setup_wind_streaks()
		_setup_atmospheric_effects()
		_is_initialized = true

	# Frame-rate independent delta accumulation
	_time += delta

	# Periodic time wrapping after 4 cycles to prevent 32-bit floating point precision loss
	# while preserving exact mathematical phase continuity across cycles
	var safe_speed: float = get_effective_float_speed()
	var four_cycle_period: float = (TAU / safe_speed) * 4.0
	if _time > 10000.0:
		_time = fposmod(_time, four_cycle_period)

	_update_floating_kinematics(delta)


func _notification(what: int) -> void:
	# Protect scene file integrity if saved while editor preview is active
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_reset_transforms()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		if preview_in_editor:
			_update_floating_kinematics(0.0)


func _exit_tree() -> void:
	_reset_transforms()
	if _auto_spawned_wind_streaks and wind_streaks_node != null and is_instance_valid(wind_streaks_node):
		wind_streaks_node.queue_free()
		wind_streaks_node = null
	if _auto_spawned_divine_light and divine_light_node != null and is_instance_valid(divine_light_node):
		divine_light_node.queue_free()
		divine_light_node = null
	if _auto_spawned_dark_clouds and dark_clouds_node != null and is_instance_valid(dark_clouds_node):
		dark_clouds_node.queue_free()
		dark_clouds_node = null

# ==============================================================================
# WIND STREAKS INTEGRATION
# ==============================================================================

func _setup_wind_streaks() -> void:
	if not enable_wind_streaks:
		if wind_streaks_node != null and is_instance_valid(wind_streaks_node):
			wind_streaks_node.visible = false
		return

	var hierarchy_root: Node = _get_hierarchy_root()

	# 1. Check if wind_streaks_node is already assigned or exists in scene
	if wind_streaks_node == null or not is_instance_valid(wind_streaks_node):
		wind_streaks_node = _find_wind_streaks_recursive(hierarchy_root)

	# 2. If not found in tree, create procedural instance automatically
	if wind_streaks_node == null:
		var streaks: Control = WindStreaksClass.new()
		streaks.name = "WindStreaks"
		streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Find best parent: SubViewportContainer (left container) or root Control
		var sub_container: Control = _find_subviewport_container_recursive(hierarchy_root)
		if sub_container != null:
			sub_container.add_child(streaks)
			streaks.set_anchors_preset(Control.PRESET_FULL_RECT)
		elif (self as Object) is Control:
			(self as Object as Control).add_child(streaks)
			streaks.set_anchors_preset(Control.PRESET_FULL_RECT)
		elif hierarchy_root != null:
			hierarchy_root.add_child(streaks)
			streaks.set_anchors_preset(Control.PRESET_FULL_RECT)

		wind_streaks_node = streaks
		_auto_spawned_wind_streaks = true

	_sync_wind_streak_settings()


func _sync_wind_streak_settings() -> void:
	if wind_streaks_node != null and is_instance_valid(wind_streaks_node):
		wind_streaks_node.visible = enable_wind_streaks
		wind_streaks_node.streak_speed = streak_speed
		wind_streaks_node.streak_spawn_rate = streak_spawn_rate
		wind_streaks_node.streak_color = streak_color
		wind_streaks_node.streak_area_width = streak_area_width
		wind_streaks_node.streak_area_min_x = streak_area_min_x
		wind_streaks_node.streak_length_min = streak_length_min
		wind_streaks_node.streak_length_max = streak_length_max
		wind_streaks_node.streak_thickness = streak_thickness
		wind_streaks_node.streak_horizontal_jitter = streak_horizontal_jitter
		wind_streaks_node.streak_sketch_effect = streak_sketch_effect
		wind_streaks_node.preview_in_editor = preview_in_editor

# ==============================================================================
# ATMOSPHERE INTEGRATION (DIVINE LIGHT & DARK CLOUDS)
# ==============================================================================

func _setup_atmospheric_effects() -> void:
	var hierarchy_root: Node = _get_hierarchy_root()
	var sub_container: Control = _find_subviewport_container_recursive(hierarchy_root)
	var parent_node: Node = sub_container if sub_container != null else (hierarchy_root if hierarchy_root != null else self)

	# 1. Divine Light
	if divine_light_node == null or not is_instance_valid(divine_light_node):
		divine_light_node = _find_divine_light_recursive(hierarchy_root)

	if divine_light_node == null and enable_divine_light and parent_node != null:
		var dl: Node3D = DivineLightClass.new()
		dl.name = "DivineLight"
		parent_node.add_child(dl)
		divine_light_node = dl
		_auto_spawned_divine_light = true

	# 2. Dark Clouds
	if dark_clouds_node == null or not is_instance_valid(dark_clouds_node):
		dark_clouds_node = _find_dark_clouds_recursive(hierarchy_root)

	if dark_clouds_node == null and enable_dark_clouds and parent_node != null:
		var dc: Node3D = DarkCloudsClass.new()
		dc.name = "DarkClouds"
		parent_node.add_child(dc)
		dark_clouds_node = dc
		_auto_spawned_dark_clouds = true

	_sync_atmospheric_settings()


func _sync_atmospheric_settings() -> void:
	if divine_light_node != null and is_instance_valid(divine_light_node):
		divine_light_node.visible = enable_divine_light
		if "beam_intensity" in divine_light_node:
			divine_light_node.beam_intensity = beam_intensity
		if "spotlight_energy" in divine_light_node:
			divine_light_node.spotlight_energy = spotlight_energy
		if "enable_motes" in divine_light_node:
			divine_light_node.enable_motes = enable_motes
		if "preview_in_editor" in divine_light_node:
			divine_light_node.preview_in_editor = preview_in_editor

	if dark_clouds_node != null and is_instance_valid(dark_clouds_node):
		dark_clouds_node.visible = enable_dark_clouds
		if "cloud_speed" in dark_clouds_node:
			dark_clouds_node.cloud_speed = cloud_speed
		if "enable_3d_puffs" in dark_clouds_node:
			dark_clouds_node.enable_3d_puffs = enable_3d_puffs
		if "preview_in_editor" in dark_clouds_node:
			dark_clouds_node.preview_in_editor = preview_in_editor

# ==============================================================================
# TARGET RESOLUTION & TRANSFORM CACHING
# ==============================================================================

## Intelligently locate target nodes if not explicitly assigned in the Inspector.
func _resolve_targets() -> void:
	var self_obj: Object = self
	var hierarchy_root: Node = _get_hierarchy_root()

	# 1. Resolve character_node
	if character_node == null:
		if self_obj is Node3D and _matches_names((self_obj as Node3D).name, ["falling", "character", "player"]):
			character_node = self_obj as Node3D
		elif get_parent() is Node3D and _matches_names((get_parent() as Node3D).name, ["falling", "character", "player"]):
			character_node = get_parent() as Node3D
		else:
			character_node = _find_target_node_recursive(hierarchy_root, ["falling", "character", "player"])

	# 2. Resolve envelope_node
	if envelope_node == null:
		if self_obj is Node3D and _matches_names((self_obj as Node3D).name, ["letter", "envelope", "mail"]):
			envelope_node = self_obj as Node3D
		elif get_parent() is Node3D and _matches_names((get_parent() as Node3D).name, ["letter", "envelope", "mail"]):
			envelope_node = get_parent() as Node3D
		else:
			envelope_node = _find_target_node_recursive(hierarchy_root, ["letter2", "letter", "envelope", "mail"])

	# 3. Resolve character_skeleton
	if character_node != null and character_skeleton == null:
		character_skeleton = _find_skeleton_recursive(character_node)


func _store_initial_transforms() -> void:
	_store_char_initial_transform()
	_store_env_initial_transform()
	_detect_extremities()


func _store_char_initial_transform() -> void:
	if character_node != null and is_instance_valid(character_node):
		_initial_char_pos = character_node.position
		_initial_char_rot = character_node.rotation_degrees


func _store_env_initial_transform() -> void:
	if envelope_node != null and is_instance_valid(envelope_node):
		_initial_env_pos = envelope_node.position
		_initial_env_rot = envelope_node.rotation_degrees


func _reset_transforms() -> void:
	_time = 0.0
	_current_limb_drag = 0.0

	if character_node != null and is_instance_valid(character_node):
		character_node.position = _initial_char_pos
		character_node.rotation_degrees = _initial_char_rot

	if envelope_node != null and is_instance_valid(envelope_node):
		envelope_node.position = _initial_env_pos
		envelope_node.rotation_degrees = _initial_env_rot

	if character_skeleton != null and is_instance_valid(character_skeleton):
		for bone_idx in _extremity_bones:
			var rest_rot: Quaternion = _bone_rest_rotations.get(bone_idx, Quaternion.IDENTITY)
			character_skeleton.set_bone_pose_rotation(bone_idx, rest_rot)

	for limb in _limb_nodes:
		if is_instance_valid(limb):
			limb.rotation_degrees = _limb_initial_rotations.get(limb, limb.rotation_degrees)


func _detect_extremities() -> void:
	_extremity_bones.clear()
	_bone_rest_rotations.clear()
	_limb_nodes.clear()
	_limb_initial_rotations.clear()

	if character_skeleton != null and is_instance_valid(character_skeleton):
		var count: int = character_skeleton.get_bone_count()
		for i in range(count):
			var bname: String = character_skeleton.get_bone_name(i).to_lower()
			if _matches_names(bname, ["head", "arm", "hand", "leg", "foot", "wrist", "ankle"]):
				_extremity_bones.append(i)
				_bone_rest_rotations[i] = character_skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
	elif character_node != null and is_instance_valid(character_node):
		for child in character_node.get_children():
			if child is Node3D and child != self and _matches_names(child.name, ["head", "arm", "hand", "leg", "foot"]):
				var limb := child as Node3D
				_limb_nodes.append(limb)
				_limb_initial_rotations[limb] = limb.rotation_degrees

# ==============================================================================
# KINEMATICS & WAVE SYNTHESIS
# ==============================================================================

## Returns the positive, safe floating speed guaranteeing division-by-zero safety
## and positive period calculations even under unexpected user input or negative values.
func get_effective_float_speed() -> float:
	return absf(float_speed) if absf(float_speed) >= 0.01 else DEFAULT_FLOAT_SPEED


func _update_floating_kinematics(delta: float) -> void:
	if _is_dropping_out:
		return
	var eff_speed: float = get_effective_float_speed()

	# --------------------------------------------------------------------------
	# 1. Primary Buoyancy & Rotational Sway for Character
	# --------------------------------------------------------------------------
	# Vertical oscillation: period T = 2*PI / eff_speed (approx 10.47s at default 0.6 rad/s)
	var char_float_y: float = sin(_time * eff_speed) * float_amplitude

	# Asynchronous pitch, roll, and yaw drift
	var char_pitch: float = sin(_time * eff_speed * pitch_speed_mult) * tilt_angle
	var char_roll: float = cos(_time * eff_speed * roll_speed_mult + 1.85) * (tilt_angle * 0.85)
	var char_yaw: float = sin(_time * eff_speed * yaw_speed_mult + 3.41) * (tilt_angle * 0.35)

	# Subtle horizontal drift simulating micro-currents in zero-gravity / falling air column
	var char_drift_x: float = 0.0
	var char_drift_z: float = 0.0
	if enable_horizontal_drift:
		char_drift_x = sin(_time * eff_speed * roll_speed_mult + 0.70) * (float_amplitude * horizontal_drift_scale)
		char_drift_z = cos(_time * eff_speed * yaw_speed_mult + 1.20) * (float_amplitude * horizontal_drift_scale * 0.6)

	if character_node != null and is_instance_valid(character_node):
		character_node.position = _initial_char_pos + Vector3(char_drift_x, char_float_y, char_drift_z)
		character_node.rotation_degrees = _initial_char_rot + Vector3(char_pitch, char_yaw, char_roll)

	# --------------------------------------------------------------------------
	# 2. Desynchronized Envelope Motion (Secondary Lighter Object)
	# --------------------------------------------------------------------------
	# Phase lag shifts envelope reaction slightly behind the falling character
	var env_phase_time: float = (_time * eff_speed) - envelope_phase_offset

	# Envelope shares the driving frequency to maintain constant trailing phase lag,
	# but displaces with higher excursion due to lighter paper mass
	var env_float_y: float = sin(env_phase_time) * (float_amplitude * envelope_amplitude_mult)

	# Independent rotational paper flutter lagging behind character
	var env_pitch: float = sin(env_phase_time * pitch_speed_mult + 0.90) * (tilt_angle * envelope_tilt_mult)
	var env_roll: float = cos(env_phase_time * roll_speed_mult + 2.40) * (tilt_angle * envelope_tilt_mult * 1.10)
	var env_yaw: float = sin(env_phase_time * yaw_speed_mult + 1.50) * (tilt_angle * envelope_tilt_mult * 0.50)

	var env_drift_x: float = 0.0
	var env_drift_z: float = 0.0
	if enable_horizontal_drift:
		env_drift_x = sin(env_phase_time * roll_speed_mult + 2.10) * (float_amplitude * horizontal_drift_scale * 1.30)
		env_drift_z = cos(env_phase_time * yaw_speed_mult + 0.40) * (float_amplitude * horizontal_drift_scale * 0.80)

	if envelope_node != null and is_instance_valid(envelope_node):
		envelope_node.position = _initial_env_pos + Vector3(env_drift_x, env_float_y, env_drift_z)
		envelope_node.rotation_degrees = _initial_env_rot + Vector3(env_pitch, env_yaw, env_roll)

	# --------------------------------------------------------------------------
	# 3. Secondary Extremity Drag (Aerodynamic Resistance)
	# --------------------------------------------------------------------------
	# Aerodynamic drag counteracts velocity (falling down -> extremities gently trail upward)
	var target_drag: float = -cos(_time * eff_speed) * (float_amplitude / 0.06) * limb_drag_intensity * 3.0

	# Frame-rate independent exponential smoothing
	var smooth_factor: float = 1.0 - exp(-limb_drag_responsiveness * maxf(delta, 0.0))
	_current_limb_drag = lerp(_current_limb_drag, target_drag, clampf(smooth_factor, 0.0, 1.0))

	_apply_extremity_drag(_current_limb_drag)


func _apply_extremity_drag(drag_angle: float) -> void:
	if character_skeleton != null and is_instance_valid(character_skeleton):
		for bone_idx in _extremity_bones:
			var rest_rot: Quaternion = _bone_rest_rotations.get(bone_idx, Quaternion.IDENTITY)
			var drag_quat := Quaternion(Vector3.RIGHT, deg_to_rad(drag_angle))
			character_skeleton.set_bone_pose_rotation(bone_idx, rest_rot * drag_quat)

	elif not _limb_nodes.is_empty():
		for limb in _limb_nodes:
			if is_instance_valid(limb):
				var init_rot: Vector3 = _limb_initial_rotations.get(limb, limb.rotation_degrees)
				limb.rotation_degrees = init_rot + Vector3(drag_angle, 0.0, drag_angle * 0.25)

# ==============================================================================
# ANIMATION PLAYER SETUP HELPER (BAKED WORKFLOW)
# ==============================================================================

## Bakes this mathematical simulation into a looped Godot Animation resource
## inside the provided AnimationPlayer node. Creates a seamless closed loop.
func bake_to_animation_player(anim_player: AnimationPlayer, anim_name: String = "zero_gravity_loop", length: float = 0.0, fps: int = 30) -> Animation:
	if anim_player == null:
		push_error("ZeroGravityFloat: AnimationPlayer reference is null.")
		return null

	_resolve_targets()
	_store_initial_transforms()

	var safe_speed: float = get_effective_float_speed()
	var base_period: float = TAU / safe_speed

	# Calculate seamless length: 4 base cycles ensures pitch (0.75), roll (0.50),
	# and yaw (0.25) all complete an exact integer number of cycles!
	var anim_length: float = length
	if anim_length <= 0.0:
		anim_length = base_period * 4.0
	else:
		var cycle_count: int = maxi(1, roundi(anim_length / (base_period * 4.0)))
		anim_length = base_period * 4.0 * float(cycle_count)

	var anim := Animation.new()
	anim.length = anim_length
	anim.loop_mode = Animation.LOOP_LINEAR

	# Resolve track paths relative to AnimationPlayer's root node
	var player_root: Node = anim_player.get_node_or_null(anim_player.root_node)
	if player_root == null:
		player_root = anim_player.get_parent()

	var char_pos_track := -1
	var char_rot_track := -1
	var env_pos_track := -1
	var env_rot_track := -1

	if character_node != null and player_root != null:
		var char_path := str(player_root.get_path_to(character_node))
		if not char_path.is_empty():
			char_pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(char_pos_track, char_path)
			char_rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(char_rot_track, char_path)

	if envelope_node != null and player_root != null:
		var env_path := str(player_root.get_path_to(envelope_node))
		if not env_path.is_empty():
			env_pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(env_pos_track, env_path)
			env_rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(env_rot_track, env_path)

	var total_frames: int = int(anim_length * float(fps))
	for f in range(total_frames + 1):
		var t: float = float(f) / float(fps)
		if t > anim_length:
			t = anim_length

		# Sample character kinematics
		var char_y: float = sin(t * safe_speed) * float_amplitude
		var char_dx: float = sin(t * safe_speed * roll_speed_mult + 0.70) * (float_amplitude * horizontal_drift_scale) if enable_horizontal_drift else 0.0
		var char_dz: float = cos(t * safe_speed * yaw_speed_mult + 1.20) * (float_amplitude * horizontal_drift_scale * 0.6) if enable_horizontal_drift else 0.0
		var c_pos: Vector3 = _initial_char_pos + Vector3(char_dx, char_y, char_dz)

		var c_pitch: float = sin(t * safe_speed * pitch_speed_mult) * tilt_angle
		var c_roll: float = cos(t * safe_speed * roll_speed_mult + 1.85) * (tilt_angle * 0.85)
		var c_yaw: float = sin(t * safe_speed * yaw_speed_mult + 3.41) * (tilt_angle * 0.35)
		var c_euler := _initial_char_rot + Vector3(c_pitch, c_yaw, c_roll)
		var c_quat := Quaternion.from_euler(Vector3(deg_to_rad(c_euler.x), deg_to_rad(c_euler.y), deg_to_rad(c_euler.z)))

		if char_pos_track >= 0:
			anim.position_track_insert_key(char_pos_track, t, c_pos)
		if char_rot_track >= 0:
			anim.rotation_track_insert_key(char_rot_track, t, c_quat)

		# Sample envelope kinematics
		var ep_time: float = (t * safe_speed) - envelope_phase_offset
		var env_y: float = sin(ep_time) * (float_amplitude * envelope_amplitude_mult)
		var env_dx: float = sin(ep_time * roll_speed_mult + 2.10) * (float_amplitude * horizontal_drift_scale * 1.30) if enable_horizontal_drift else 0.0
		var env_dz: float = cos(ep_time * yaw_speed_mult + 0.40) * (float_amplitude * horizontal_drift_scale * 0.80) if enable_horizontal_drift else 0.0
		var e_pos: Vector3 = _initial_env_pos + Vector3(env_dx, env_y, env_dz)

		var e_pitch: float = sin(ep_time * pitch_speed_mult + 0.90) * (tilt_angle * envelope_tilt_mult)
		var e_roll: float = cos(ep_time * roll_speed_mult + 2.40) * (tilt_angle * envelope_tilt_mult * 1.10)
		var e_yaw: float = sin(ep_time * yaw_speed_mult + 1.50) * (tilt_angle * envelope_tilt_mult * 0.50)
		var e_euler := _initial_env_rot + Vector3(e_pitch, e_yaw, e_roll)
		var e_quat := Quaternion.from_euler(Vector3(deg_to_rad(e_euler.x), deg_to_rad(e_euler.y), deg_to_rad(e_euler.z)))

		if env_pos_track >= 0:
			anim.position_track_insert_key(env_pos_track, t, e_pos)
		if env_rot_track >= 0:
			anim.rotation_track_insert_key(env_rot_track, t, e_quat)

	var lib: AnimationLibrary = null
	if anim_player.has_animation_library(""):
		lib = anim_player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)

	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)

	lib.add_animation(anim_name, anim)
	return anim

# ==============================================================================
# PROCEDURAL 3D PARTICLES BUILDER (GPUParticles3D Alternative)
# ==============================================================================

## Optional utility method: constructs a GPUParticles3D node in World3D space
## surrounding the 3D meshes with vertical speed lines and billboarded quads.
func build_wind_particles_3d(parent_node: Node3D = null) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "GPUParticles3D_Wind"
	particles.amount = int(streak_spawn_rate)
	particles.lifetime = 0.75
	particles.speed_scale = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.35

	# Process Material
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.65, 0.05, 0.65)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 2.5
	pmat.initial_velocity_min = streak_speed * 0.005
	pmat.initial_velocity_max = streak_speed * 0.008
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.8
	pmat.scale_max = 1.4

	# Color ramp fade in/out
	var grad := Gradient.new()
	grad.set_color(0, Color(streak_color.r, streak_color.g, streak_color.b, 0.0))
	grad.add_point(0.15, Color(streak_color.r, streak_color.g, streak_color.b, streak_color.a))
	grad.add_point(0.80, Color(streak_color.r, streak_color.g, streak_color.b, streak_color.a))
	grad.set_color(1, Color(streak_color.r, streak_color.g, streak_color.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pmat.color_ramp = grad_tex

	particles.process_material = pmat

	# Draw pass mesh (thin elongated vertical quad)
	var qmesh := QuadMesh.new()
	qmesh.size = Vector2(0.015, 0.75)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmesh.material = mat

	particles.draw_pass_1 = qmesh

	var target_parent: Node3D = parent_node
	if target_parent == null:
		if character_node != null and character_node.get_parent() is Node3D:
			target_parent = character_node.get_parent() as Node3D
		elif character_node != null:
			target_parent = character_node

	if target_parent != null:
		target_parent.add_child(particles)
		particles.position = Vector3(0, -1.0, -0.3)

	return particles

# ==============================================================================
# HELPERS
# ==============================================================================

func _matches_names(source: String, candidates: Array[String]) -> bool:
	var lower := source.to_lower()
	for candidate in candidates:
		if lower.contains(candidate.to_lower()):
			return true
	return false


func _get_hierarchy_root() -> Node:
	if owner != null:
		return owner
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	var curr: Node = self
	while curr.get_parent() != null and not (curr.get_parent() is Window):
		curr = curr.get_parent()
	return curr


func _find_target_node_recursive(root_node: Node, candidates: Array[String]) -> Node3D:
	if root_node == null:
		return null

	if root_node != self and root_node is Node3D:
		if _matches_names(root_node.name, candidates):
			return root_node as Node3D

	for child in root_node.get_children():
		if child == self:
			continue
		var found := _find_target_node_recursive(child, candidates)
		if found != null:
			return found

	return null


func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
		var sub := _find_skeleton_recursive(child)
		if sub != null:
			return sub
	return null


func _find_wind_streaks_recursive(node: Node) -> Control:
	if node == null:
		return null
	if node is Control and (node is WindStreaksClass or node.get_script() == WindStreaksClass):
		return node as Control
	for child in node.get_children():
		var found: Control = _find_wind_streaks_recursive(child)
		if found != null:
			return found
	return null


func _find_subviewport_container_recursive(node: Node) -> Control:
	if node == null:
		return null
	if node is SubViewportContainer:
		return node as Control
	for child in node.get_children():
		var found := _find_subviewport_container_recursive(child)
		if found != null:
			return found
	return null


func _find_divine_light_recursive(node: Node) -> Node3D:
	if node == null:
		return null
	if node is Node3D and (node is DivineLightClass or node.get_script() == DivineLightClass or _matches_names(node.name, ["divinelight", "cahayailahi", "divine_light"])):
		return node as Node3D
	for child in node.get_children():
		var found := _find_divine_light_recursive(child)
		if found != null:
			return found
	return null


func _find_dark_clouds_recursive(node: Node) -> Node3D:
	if node == null:
		return null
	if node is Node3D and (node is DarkCloudsClass or node.get_script() == DarkCloudsClass or _matches_names(node.name, ["darkclouds", "awangelap", "dark_clouds"])):
		return node as Node3D
	for child in node.get_children():
		var found := _find_dark_clouds_recursive(child)
		if found != null:
			return found
	return null
