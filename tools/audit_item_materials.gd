extends SceneTree

var frames := 0

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		var scene: PackedScene = load("res://scenes/levels/chapter_1.tscn")
		var m = scene.instantiate()
		get_root().add_child(m)
		return false
	if frames == 3:
		var root = get_root().get_child(get_root().get_child_count() - 1)
		print("=== AUDITING ALL MESH MATERIALS IN MAP ===")
		for n in root.find_children("*", "MeshInstance3D", true):
			var mi: MeshInstance3D = n as MeshInstance3D
			var path = str(mi.get_path())
			# check all surfaces
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var mat = mi.get_surface_override_material(s)
					if mat == null:
						mat = mi.mesh.surface_get_material(s)
					if mat is StandardMaterial3D:
						var sm: StandardMaterial3D = mat
						var is_unshaded = sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
						var has_emission = sm.emission_enabled
						var rough = sm.roughness
						var metal = sm.metallic
						if is_unshaded or has_emission or rough < 0.65 or "toy" in path.to_lower() or "car" in path.to_lower() or "cube" in path.to_lower() or "duck" in path.to_lower():
							print(path, " [surf ", s, "] unshaded=", is_unshaded, " emission=", has_emission, " rough=", rough, " metal=", metal, " albedo=", sm.albedo_color)
					elif mat is ORMMaterial3D:
						var om: ORMMaterial3D = mat
						print("ORM: ", path, " unshaded=", om.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, " rough=", om.roughness)
					elif mat != null:
						print(path, " Other material: ", mat.get_class())
		quit()
		return true
	return false
