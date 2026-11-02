extends Node3D

var debris_scene = preload("res://scenes/weapons/Debris.tscn")

func setup(normal: Vector3, is_enemy: bool, target_node: Node = null) -> void:
	if normal != Vector3.ZERO:
		look_at(global_position + normal, Vector3.UP)

	var decal = Decal.new()
	decal.size = Vector3(0.1, 0.1, 0.1)
	var grad = Gradient.new()
	grad.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.width = 32
	tex.height = 32
	decal.texture_albedo = tex
	decal.modulate = Color(0.1, 0.1, 0.1) if is_enemy else Color(0.2, 0.2, 0.2)
	decal.global_position = global_position + normal * 0.01
	get_parent().add_child(decal)
	get_tree().create_timer(10.0).timeout.connect(decal.queue_free)

	if not is_enemy:
		var audio = AudioStreamPlayer3D.new()
		audio.stream = preload("res://scripts/utils/SoundGen.gd").get_concrete_hit_sound()
		audio.unit_size = 5.0
		audio.volume_db = -2.0
		add_child(audio)
		audio.play()
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)

	var debris_mat = StandardMaterial3D.new()
	debris_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	
	if is_enemy:
		var sparks = CPUParticles3D.new()
		sparks.amount = 12
		sparks.lifetime = 0.4
		sparks.one_shot = true
		sparks.direction = normal
		sparks.spread = 45.0
		sparks.initial_velocity_min = 3.0
		sparks.initial_velocity_max = 8.0
		var spark_mesh = BoxMesh.new()
		spark_mesh.size = Vector3(0.02, 0.02, 0.02)
		var spark_mat = StandardMaterial3D.new()
		spark_mat.albedo_color = Color(1.0, 0.8, 0.1)
		spark_mat.emission_enabled = true
		spark_mat.emission = Color(1.0, 0.6, 0.0)
		spark_mesh.material = spark_mat
		sparks.mesh = spark_mesh
		sparks.global_position = global_position
		get_parent().add_child(sparks)
		sparks.emitting = true
		get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)
	else:
		var base_color = Color(0.4, 0.4, 0.4) 
		
		# УЛЬТИМАТИВНЫЙ ПОИСК: Ищем ближайший меш во всей сцене
		var closest_mesh = null
		var min_dist = 9999.0
		var root = get_tree().current_scene
		
		if root:
			var all_meshes = root.find_children("*", "MeshInstance3D", true, false)
			for m in all_meshes:
				# Пропускаем сами осколки, чтобы они не влияли на поиск
				if m.get_parent() and m.get_parent().name == "Debris": continue
				if m.get_parent() and m.get_parent().name == "BulletImpact": continue
				
				var dist = m.global_position.distance_to(global_position)
				# Ищем только в радиусе 3 метров
				if dist < min_dist and dist < 3.0:
					min_dist = dist
					closest_mesh = m
					
		if closest_mesh:
			if closest_mesh.material_override is StandardMaterial3D:
				base_color = closest_mesh.material_override.albedo_color
			elif closest_mesh.mesh and closest_mesh.mesh.surface_get_material(0) is StandardMaterial3D:
				base_color = closest_mesh.mesh.surface_get_material(0).albedo_color
				
		# Делаем цвет чуть ярче, чтобы он выделялся
		debris_mat.albedo_color = base_color.lightened(0.15)
		
		for i in range(4):
			var debris = debris_scene.instantiate()
			get_parent().add_child(debris)
			debris.global_position = global_position
			debris.get_node("MeshInstance3D").material_override = debris_mat
			var impulse = (normal * 3.0 + Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1))).normalized() * 3.0
			debris.apply_central_impulse(impulse)

	var flash = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.03
	flash.mesh = sphere_mesh
	var s_mat = StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.albedo_color = Color(1.0, 0.8, 0.5, 1) 
	flash.material_override = s_mat
	flash.global_position = global_position
	get_parent().add_child(flash)
	var t = create_tween()
	t.tween_property(flash, "scale", Vector3(0, 0, 0), 0.1)
	t.tween_callback(queue_free)
