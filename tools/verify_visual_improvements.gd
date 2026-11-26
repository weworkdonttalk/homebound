extends SceneTree

var frames := 0

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		var scene: PackedScene = load("res://scenes/levels/chapter_1.tscn")
		var m = scene.instantiate()
		get_root().add_child(m)
		return false

	if frames == 4:
		var root = get_root().get_child(get_root().get_child_count() - 1)
		print("=== 1. VERIFY DUST PARTICLES ===")
		var dust: GPUParticles3D = root.get_node_or_null("DustParticles")
		if dust:
			print("amount: ", dust.amount)
			var quad: QuadMesh = dust.draw_pass_1 as QuadMesh
			if quad:
				print("quad size: ", quad.size)
				var sm: StandardMaterial3D = quad.material as StandardMaterial3D
				if sm:
					var tex = sm.albedo_texture
					print("texture type: ", tex.get_class() if tex else "None")
					if tex is GradientTexture2D:
						print("fill mode: ", "RADIAL" if tex.fill == GradientTexture2D.FILL_RADIAL else str(tex.fill))
						print("albedo color: ", sm.albedo_color)

		print("\n=== 2. VERIFY LIGHTS & SHADOWS ===")
		for n in root.find_children("*", "Light3D", true):
			var l: Light3D = n as Light3D
			var spot_attn = l.get("spot_angle_attenuation")
			print(l.name, " (", l.get_class(), "): energy=", l.light_energy, 
				" shadow=", l.shadow_enabled, " bias=", l.shadow_bias, 
				" norm_bias=", l.shadow_normal_bias, " blur=", l.shadow_blur, 
				(" spot_attn=" + str(spot_attn)) if spot_attn != null else "")

		print("\n=== 3. VERIFY WORLD ENVIRONMENT ===")
		var we: WorldEnvironment = root.get_node_or_null("WorldEnvironment")
		if we and we.environment:
			var env = we.environment
			print("ambient_source: ", env.ambient_light_source)
			print("ambient_color: ", env.ambient_light_color, " energy=", env.ambient_light_energy)
			print("glow_strength: ", env.glow_strength, " glow_bloom=", env.glow_bloom)
			print("fog_enabled: ", env.fog_enabled, " fog_color=", env.fog_light_color, " fog_density=", env.fog_density)

		print("\n=== 4. VERIFY ITEM MATERIALS (TOY CAR, TEDDY, ABC BLOCKS, DUCK) ===")
		var targets = ["sketchfab_scene8", "sketchfab_scene22", "sketchfab_scene7", "sketchfab_scene2", "pushabletoyblock", "sketchfab_scene19", "sketchfab_scene13"]
		for n in root.find_children("*", "MeshInstance3D", true):
			var mi: MeshInstance3D = n as MeshInstance3D
			var path_lower = str(mi.get_path()).to_lower()
			var match_target = false
			for t in targets:
				if t in path_lower:
					match_target = true
					break
			if match_target and mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var mat = mi.get_surface_override_material(s)
					if mat == null:
						mat = mi.mesh.surface_get_material(s)
					if mat is StandardMaterial3D:
						var sm: StandardMaterial3D = mat
						print(mi.name, " [surf ", s, "] in ", mi.get_parent().name, 
							": unshaded=", sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, 
							" emission=", sm.emission_enabled, 
							" roughness=", sm.roughness, 
							" metallic=", sm.metallic, 
							" albedo=", sm.albedo_color)

		quit()
		return true

	return false
