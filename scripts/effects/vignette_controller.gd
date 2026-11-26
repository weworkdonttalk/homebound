extends ColorRect

# ============================================================================
# Vignette Screen Tracker — Limbo / Little Nightmares Style
# Menyinkronkan parameter 'center_offset' pada ShaderMaterial vignette
# dengan proyeksi posisi layar karakter (unproject_position) secara real-time.
# Dilengkapi slider @export di Inspector untuk mengatur radius lingkaran.
# ============================================================================

## Referensi ke karakter pemain (CharacterBody3D)
@export var player: Node3D = null

## Referensi ke kamera permainan (Camera3D)
@export var camera: Camera3D = null

## Ketinggian offset titik pusat (pusat tubuh karakter) dalam meter
@export var player_height_offset: float = 1.4

## Kecepatan interpolasi pelacakan layar (0 = instan / tanpa lag)
@export var track_smooth_speed: float = 30.0

@export_group("Vignette Radius & Intensity")
## Radius lingkaran dalam yang jernih/transparan (lebih kecil = lingkaran lebih sempit/fokus)
@export_range(0.05, 1.0, 0.01) var inner_radius: float = 0.32:
	set(v):
		inner_radius = v
		if _mat:
			_mat.set_shader_parameter("inner_radius", v)

## Radius lingkaran luar tempat kegelapan pekat mulai penuh
@export_range(0.1, 2.0, 0.01) var outer_radius: float = 0.75:
	set(v):
		outer_radius = v
		if _mat:
			_mat.set_shader_parameter("outer_radius", v)

## Opasitas maksimal vignette hitam di pinggiran layar
@export_range(0.0, 1.0, 0.01) var vignette_opacity: float = 0.92:
	set(v):
		vignette_opacity = v
		if _mat:
			_mat.set_shader_parameter("vignette_opacity", v)

## Faktor koreksi aspek (1.0 = lingkaran sempurna di pixel, 0.0 = elips layar penuh)
@export_range(0.0, 1.0, 0.01) var aspect_correction: float = 1.0:
	set(v):
		aspect_correction = v
		if _mat:
			_mat.set_shader_parameter("aspect_correction", v)

var _mat: ShaderMaterial = null
var _current_center: Vector2 = Vector2(0.5, 0.5)

func _ready() -> void:
	_mat = material as ShaderMaterial
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _mat:
		_mat.set_shader_parameter("inner_radius", inner_radius)
		_mat.set_shader_parameter("outer_radius", outer_radius)
		_mat.set_shader_parameter("vignette_opacity", vignette_opacity)
		_mat.set_shader_parameter("aspect_correction", aspect_correction)

	if player == null:
		player = get_node_or_null("../../Player")
	if camera == null:
		camera = get_viewport().get_camera_3d()

	if player and camera:
		var world_target := player.global_position + Vector3.UP * player_height_offset
		if not camera.is_position_behind(world_target):
			var screen_pixel_pos := camera.unproject_position(world_target)
			var vp_rect := get_viewport().get_visible_rect()
			if vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0:
				_current_center = Vector2(
					screen_pixel_pos.x / vp_rect.size.x,
					screen_pixel_pos.y / vp_rect.size.y
				)
				if _mat:
					_mat.set_shader_parameter("center_offset", _current_center)

func _process(delta: float) -> void:
	if _mat == null:
		_mat = material as ShaderMaterial
		if _mat == null:
			return

	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return

	if player == null or not is_instance_valid(player):
		player = get_node_or_null("../../Player")
		if player == null:
			return

	var world_target := player.global_position + Vector3.UP * player_height_offset

	# Abaikan jika berada di belakang frustum kamera
	if camera.is_position_behind(world_target):
		return

	# Proyeksikan koordinat dunia 3D ke koordinat piksel layar 2D (unproject_position)
	var screen_pixel_pos := camera.unproject_position(world_target)
	var vp_rect := get_viewport().get_visible_rect()

	if vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0:
		var target_norm_center := Vector2(
			screen_pixel_pos.x / vp_rect.size.x,
			screen_pixel_pos.y / vp_rect.size.y
		)

		if track_smooth_speed > 0.0:
			_current_center = _current_center.lerp(target_norm_center, clampf(track_smooth_speed * delta, 0.0, 1.0))
		else:
			_current_center = target_norm_center

		_mat.set_shader_parameter("center_offset", _current_center)
