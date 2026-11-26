extends Node3D

# ============================================================================
# Glowing Platforms — Stepping-stone bercahaya
# Awalnya tidak terlihat & CollisionShape3D nonaktif.
# Muncul secara bertahap (staggered) saat Pressure Plate terpicu.
# ============================================================================

## Durasi fade-in emission per platform (detik)
@export var fade_in_duration := 0.5

## Jeda antara setiap platform (stagger delay, detik)
@export var stagger_delay := 0.2

## Nilai emisi saat aktif
@export var emission_active := 6.0

## Nilai emisi saat mati
@export var emission_inactive := 0.0

## Sinyal saat semua platform telah aktif
signal all_platforms_activated

var _active_count := 0
var _total_platforms := 0

func _ready() -> void:
	# Pastikan semua platform awalnya mati & tidak berkolisi
	_deactivate_all()

func activate_platforms() -> void:
	var children = get_children()
	_total_platforms = children.size()
	_active_count = 0

	for i in range(children.size()):
		var child = children[i]
		if child is MeshInstance3D:
			_show_platform_staggered(child, i)
		elif child is Node3D:
			# Cari MeshInstance3D di dalam anak (misal dalam StaticBody3D)
			var mesh = child.get_node_or_null("MeshInstance3D")
			if mesh:
				_show_platform_staggered(mesh, i)

func _show_platform_staggered(mesh: MeshInstance3D, index: int) -> void:
	var tw = create_tween()

	# 1. Tampilkan mesh & parent
	mesh.visible = true
	if mesh.get_parent() is Node3D:
		(mesh.get_parent() as Node3D).visible = true

	# 2. Aktifkan CollisionShape3D secara dinamis (bukan hanya visible)
	var col = mesh.get_node_or_null("CollisionShape3D")
	if col:
		col.set_deferred("disabled", false)
	# Jika collision ada di anak lain (StaticBody3D > CollisionShape3D)
	if not col and mesh.get_parent() and mesh.get_parent() is Node3D:
		var col2 = mesh.get_parent().get_node_or_null("CollisionShape3D")
		if col2:
			col2.set_deferred("disabled", false)

	# 3. Staggered emission glow via Tween
	var mat = mesh.get_surface_override_material(0)
	if mat == null or not (mat is StandardMaterial3D):
		var base_mat = mesh.material_override
		if base_mat is StandardMaterial3D:
			mat = base_mat.duplicate()
		else:
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.4, 0.6)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.85, 1.0)
		mesh.set_surface_override_material(0, mat)
	else:
		mat.emission_enabled = true
		if mat.emission == Color.BLACK:
			mat.emission = Color(0.3, 0.85, 1.0)

	mat.emission_energy_multiplier = emission_inactive

	if (stagger_delay * index) > 0.0:
		tw.tween_interval(stagger_delay * index)
	tw.tween_property(mat, "emission_energy_multiplier", emission_active, fade_in_duration)

	tw.tween_callback(func() -> void:
		_active_count += 1
		if _active_count >= _total_platforms:
			all_platforms_activated.emit()
	)
	tw.play()

func _deactivate_all() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
			var col = child.get_node_or_null("CollisionShape3D")
			if col:
				col.disabled = true
			var mat = child.get_surface_override_material(0)
			if mat:
				mat.emission_energy_multiplier = emission_inactive
		elif child is Node3D:
			var mesh = child.get_node_or_null("MeshInstance3D")
			if mesh:
				mesh.visible = false
				var col = child.get_node_or_null("CollisionShape3D")
				if col:
					col.disabled = true
