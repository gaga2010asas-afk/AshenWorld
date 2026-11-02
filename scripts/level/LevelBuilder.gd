extends Node

const BARREL_SCENE = preload("res://scenes/props/Barrel.tscn")

static func create_tex(noise_type: FastNoiseLite.NoiseType, freq: float, col1: Color, col2: Color) -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	noise.noise_type = noise_type
	noise.frequency = freq
	var grad = Gradient.new()
	grad.colors = [col1, col2]
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	return tex

static func generate_procedural_texture(tex_type: String) -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	var grad = Gradient.new()
	
	if tex_type == "concrete.png":
		noise.frequency = 0.05
		noise.fractal_octaves = 4
		grad.colors = [Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4)]
	elif tex_type == "metal.png":
		noise.frequency = 0.1
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		grad.colors = [Color(0.3, 0.3, 0.35), Color(0.6, 0.6, 0.65)]
	elif tex_type == "rust.png":
		noise.frequency = 0.08
		grad.colors = [Color(0.3, 0.1, 0.05), Color(0.6, 0.25, 0.1)]
	elif tex_type == "wood.png":
		noise.frequency = 0.15
		grad.colors = [Color(0.4, 0.25, 0.1), Color(0.6, 0.4, 0.2)]
	else:
		grad.colors = [Color(0.5, 0.5, 0.5), Color(0.8, 0.8, 0.8)]
		
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.width = 512
	tex.height = 512
	return tex

static func load_tex_mat(tex_name: String, tint: Color, uv_scale: float, metallic: float = 0.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = generate_procedural_texture(tex_name)
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.roughness = 0.8
	mat.metallic = metallic
	return mat

static func create_mat(tex_name: String, tint: Color, uv_scale: float, is_metal: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var path = "res://textures/" + tex_name
	if ResourceLoader.exists(path):
		mat.albedo_texture = create_tex(FastNoiseLite.TYPE_PERLIN, 0.1, tint.darkened(0.2), tint.lightened(0.2))
	else:
		var noise = FastNoiseLite.new()
		var noise_tex = NoiseTexture2D.new()
		noise_tex.noise = noise
		mat.albedo_texture = noise_tex
		
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.roughness = 0.8
	mat.metallic = 0.6 if is_metal else 0.0
	return mat

static func build_level(level_root: Node3D, level_id: String = "sklad") -> NavigationRegion3D:
	var nav_region = NavigationRegion3D.new()
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.6
	nav_mesh.agent_height = 1.8
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_region.navigation_mesh = nav_mesh
	level_root.add_child(nav_region)
	
	var create_box = func(sz: Vector3, pos: Vector3, mat: Material, is_static: bool = true, visible: bool = true) -> Node3D:
		var parent = StaticBody3D.new() if is_static else Node3D.new()
		if is_static: parent.collision_layer = 1
		var m = MeshInstance3D.new()
		var b = BoxMesh.new()
		b.size = sz
		m.mesh = b
		m.material_override = mat
		if visible: parent.add_child(m)
		if is_static:
			var col = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = sz
			col.shape = shape
			parent.add_child(col)
		parent.position = pos
		nav_region.add_child(parent)
		return parent
		
	var create_cyl = func(rad: float, h: float, pos: Vector3, mat: Material, is_static: bool = true) -> Node3D:
		var parent = StaticBody3D.new() if is_static else Node3D.new()
		if is_static: parent.collision_layer = 1
		var m = MeshInstance3D.new()
		var c = CylinderMesh.new()
		c.top_radius = rad
		c.bottom_radius = rad
		c.height = h
		m.mesh = c
		m.material_override = mat
		parent.add_child(m)
		if is_static:
			var col = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = rad
			shape.height = h
			col.shape = shape
			parent.add_child(col)
		parent.position = pos
		nav_region.add_child(parent)
		return parent

	# --- МАТЕРИАЛЫ ---
	var mat_floor
	var mat_wall
	var mat_metal = create_mat("metal.png", Color(0.6, 0.6, 0.6), 4.0, true)
	var mat_wood = create_mat("wood.png", Color(0.8, 0.6, 0.4), 2.0, false)
	var mat_dark = create_mat("metal.png", Color(0.1, 0.1, 0.1), 2.0, true)
	
	if level_id == "sklad":
		mat_floor = create_mat("concrete.png", Color(0.4, 0.4, 0.4), 8.0, false)
		mat_wall = create_mat("metal.png", Color(0.3, 0.3, 0.35), 6.0, true)
	elif level_id == "prigorod":
		mat_floor = create_mat("dirt.png", Color(0.5, 0.4, 0.3), 10.0, false)
		mat_wall = create_mat("concrete.png", Color(0.6, 0.5, 0.4), 4.0, false)
	elif level_id == "zavod":
		mat_floor = create_mat("concrete.png", Color(0.25, 0.25, 0.3), 8.0, false)
		mat_wall = create_mat("metal.png", Color(0.4, 0.45, 0.5), 5.0, true)
	else: # lair
		mat_floor = create_mat("metal.png", Color(0.15, 0.15, 0.2), 6.0, true)
		mat_wall = create_mat("concrete.png", Color(0.2, 0.15, 0.25), 5.0, false)

	var mat_glow = StandardMaterial3D.new()
	mat_glow.emission_enabled = true
	if level_id == "zavod":
		mat_glow.emission = Color(0, 1, 0.5)
	elif level_id == "lair":
		mat_glow.emission = Color(1, 0, 0)
	elif level_id == "prigorod":
		mat_glow.emission = Color(1, 0.8, 0.5)
	else:
		mat_glow.emission = Color(1, 0.7, 0.2)

	# --- ПОЛ И СТЕНЫ ---
	create_box.call(Vector3(60, 1, 60), Vector3(0, -0.5, 0), mat_floor)
	
	var walls = [
		{"pos": Vector3(0, 3, -30), "size": Vector3(60, 6, 1)}, 
		{"pos": Vector3(0, 3, 30), "size": Vector3(60, 6, 1)},  
		{"pos": Vector3(-30, 3, 0), "size": Vector3(1, 6, 60)}, 
		{"pos": Vector3(30, 3, 0), "size": Vector3(1, 6, 60)}
	]
	if level_id != "prigorod":
		walls.append({"pos": Vector3(0, 6, 0), "size": Vector3(60, 1, 60)})
		
	for w in walls:
		var is_visible = (level_id != "prigorod") # В Пригороде стены невидимые
		create_box.call(w["size"], w["pos"], mat_wall, true, is_visible)

	# --- ОКРУЖЕНИЕ ---
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.glow_enabled = true
	
	if level_id == "prigorod":
		env.background_color = Color(0.6, 0.3, 0.2)
		env.fog_enabled = true
		env.fog_light_color = Color(0.6, 0.4, 0.3)
		env.fog_density = 0.015
	elif level_id == "lair":
		env.background_color = Color(0.05, 0.02, 0.08)
		env.fog_enabled = true
		env.fog_light_color = Color(0.2, 0, 0)
		env.fog_density = 0.03
	else:
		env.background_color = Color(0.15, 0.15, 0.18)
		env.fog_enabled = true
		env.fog_light_color = Color(0.3, 0.3, 0.35)
		env.fog_density = 0.01
		
	env_node.environment = env
	level_root.add_child(env_node)

	var sun = DirectionalLight3D.new()
	sun.transform.basis = Basis.looking_at(Vector3(-1, -2, -1))
	sun.light_energy = 1.0 if level_id == "prigorod" else 0.2
	sun.shadow_enabled = true
	level_root.add_child(sun)

	# --- ДЕКОР ---
	# Город на заднем плане (только для Пригорода)
	if level_id == "prigorod":
		# 1. Огромный пол для фона (чтобы не было пустоты за краем арены)
		var bg_floor = MeshInstance3D.new()
		var bg_mesh = PlaneMesh.new()
		bg_mesh.size = Vector2(400, 400)
		bg_floor.mesh = bg_mesh
		bg_floor.material_override = create_mat("dirt.png", Color(0.3, 0.2, 0.15), 20.0, false)
		bg_floor.position = Vector3(0, -0.05, 0) # Чуть ниже основного пола
		nav_region.add_child(bg_floor)
		
		# 2. Дома на горизонте
		var mat_city = StandardMaterial3D.new()
		mat_city.albedo_color = Color(0.1, 0.05, 0.05) # Темный силуэт
		for i in range(60):
			var b = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			var w = randf_range(4, 12)
			var h = randf_range(15, 45)
			var d = randf_range(4, 12)
			mesh.size = Vector3(w, h, d)
			b.mesh = mesh
			b.material_override = mat_city
			
			# Расставляем по кругу на расстоянии 60-120 метров от центра
			var angle = randf() * TAU
			var dist = randf_range(60, 120)
			
			# Позиция: Y = h/2 (чтобы низ дома был ровно на земле Y=0)
			b.position = Vector3(cos(angle) * dist, h / 2.0, sin(angle) * dist)
			b.rotation.y = randf() * TAU
			nav_region.add_child(b)

	# Для мелкого мусора используем MultiMesh (оптимизация)
	var mm_mesh = BoxMesh.new()
	mm_mesh.size = Vector3(0.2, 0.2, 0.2)
	var mm_mat = StandardMaterial3D.new()
	mm_mat.albedo_color = Color(0.3, 0.3, 0.3)
	mm_mesh.material = mm_mat
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mm_mesh
	multimesh.instance_count = 100
	var mm_instance = MultiMeshInstance3D.new()
	mm_instance.multimesh = multimesh
	nav_region.add_child(mm_instance)
	
	# Используем массив [0], чтобы изменять счетчик внутри лямбды (GDScript захватывает числа по значению)
	var debris_count = [0] 
	var add_debris = func(pos: Vector3):
		if debris_count[0] < 100:
			var t = Transform3D(Basis(), pos + Vector3(randf_range(-10,10), randf_range(0,0.5), randf_range(-10,10)))
			multimesh.set_instance_transform(debris_count[0], t)
			debris_count[0] += 1

	# Вспомогательные материалы для декора
	var mat_glass = StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.1, 0.1, 0.2, 0.6)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.metallic = 0.8
	mat_glass.roughness = 0.2
	
	var mat_rust = create_mat("rust.png", Color(0.5, 0.2, 0.1), 2.0, true)
	
	# Функция для создания машины (4-5 примитивов)
	var make_car = func(pos: Vector3, flipped: bool = false, burnt: bool = false):
		var car_root = Node3D.new()
		car_root.position = pos
		if flipped: car_root.rotation_degrees.z = 180
		nav_region.add_child(car_root)
		
		var body_mat = mat_rust if burnt else create_mat("metal.png", Color(randf_range(0.2,0.5), 0.2, 0.2), 2.0, true)
		if burnt: body_mat.albedo_color = Color(0.1, 0.1, 0.1)
		
		var make_part = func(sz: Vector3, p: Vector3, mat: Material):
			var m = MeshInstance3D.new()
			var b = BoxMesh.new()
			b.size = sz
			m.mesh = b
			m.material_override = mat
			m.position = p
			car_root.add_child(m)
			
		make_part.call(Vector3(2.0, 0.8, 4.0), Vector3(0, 0.5, 0), body_mat) # Кузов
		make_part.call(Vector3(1.8, 0.6, 1.5), Vector3(0, 1.1, -0.2), body_mat) # Кабина
		make_part.call(Vector3(1.7, 0.5, 1.0), Vector3(0, 1.15, -0.5), mat_glass) # Лобовое стекло
		
		# Колеса
		for x in [-1.0, 1.0]:
			for z in [-1.2, 1.2]:
				var w = MeshInstance3D.new()
				var c = CylinderMesh.new()
				c.top_radius = 0.4
				c.bottom_radius = 0.4
				c.height = 0.3
				w.mesh = c
				w.rotation_degrees.z = 90
				w.position = Vector3(x, 0.4, z)
				w.material_override = create_mat("metal.png", Color(0.05, 0.05, 0.05), 1.0, false)
				car_root.add_child(w)

	# Функция для создания разрушенного дома
	var make_house = func(pos: Vector3, sz: Vector3, tint: Color):
		var house = StaticBody3D.new()
		house.position = pos
		house.collision_layer = 1
		nav_region.add_child(house)
		
		var h_mat = create_mat("concrete.png", tint, 3.0, false)
		
		var make_part = func(s: Vector3, p: Vector3, mat: Material):
			var m = MeshInstance3D.new()
			var b = BoxMesh.new()
			b.size = s
			m.mesh = b
			m.material_override = mat
			m.position = p
			house.add_child(m)
			
			var col = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = s
			col.shape = shape
			col.position = p
			house.add_child(col)
			return m
		
		# Основа дома
		make_part.call(sz, Vector3(0, sz.y/2, 0), h_mat)
		# Крыша (скаты)
		var roof = make_part.call(Vector3(sz.x + 1.0, 0.2, sz.z / 2), Vector3(0, sz.y, sz.z / 4), h_mat)
		roof.rotation_degrees.x = 30
		var roof2 = make_part.call(Vector3(sz.x + 1.0, 0.2, sz.z / 2), Vector3(0, sz.y, -sz.z / 4), h_mat)
		roof2.rotation_degrees.x = -30
		
		# Окна (вдавленные темные кубы)
		var win_mat = StandardMaterial3D.new()
		win_mat.albedo_color = Color(0.02, 0.02, 0.05)
		for i in range(-1, 2):
			for j in range(1, int(sz.y / 2)):
				make_part.call(Vector3(1.0, 1.2, 0.2), Vector3(i * 2.0, j * 2.0, sz.z/2 + 0.05), win_mat)
				make_part.call(Vector3(1.0, 1.2, 0.2), Vector3(i * 2.0, j * 2.0, -sz.z/2 - 0.05), win_mat)
		
		# Обломки вокруг
		for k in range(5):
			add_debris.call(pos + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))

	if level_id == "sklad":
		# Стеллажи
		for i in range(-2, 3):
			var p = Vector3(i * 8.0, 0, -10.0)
			# Вертикальные стойки
			create_box.call(Vector3(0.2, 5.0, 3.0), p + Vector3(-3, 2.5, 0), mat_metal)
			create_box.call(Vector3(0.2, 5.0, 3.0), p + Vector3(3, 2.5, 0), mat_metal)
			# Полки
			for y in [1.0, 2.5, 4.0]:
				create_box.call(Vector3(6, 0.1, 3.0), p + Vector3(0, y, 0), mat_metal)
				# Коробки на полках (разных цветов)
				create_box.call(Vector3(1.2, 1.2, 1.2), p + Vector3(-1.5, y + 0.65, 0), mat_wood)
				create_box.call(Vector3(1.0, 1.0, 1.0), p + Vector3(1.0, y + 0.55, 0), create_mat("rust.png", Color(0.6, 0.3, 0.1), 1.0, true))
		# Ящики и мусор
		for pos in [Vector3(10, 1, 10), Vector3(12, 1, 8), Vector3(-10, 1, -8)]:
			create_box.call(Vector3(1.5, 1.5, 1.5), pos, mat_wood)
			for k in range(3): add_debris.call(pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))

	elif level_id == "prigorod":
		sun.light_color = Color(1, 0.8, 0.6)
		# Дома
		for pos in [Vector3(-15, 0, -15), Vector3(15, 0, 10), Vector3(-10, 0, 20)]:
			make_house.call(pos, Vector3(8, 6, 8), Color(0.5, 0.4, 0.3))
		# Машины
		for pos in [Vector3(5, 0, -5), Vector3(-5, 0, 5), Vector3(10, 0, -15)]:
			make_car.call(pos, randf() < 0.3, randf() < 0.3)
		# Мертвые деревья
		for pos in [Vector3(-25, 0, -25), Vector3(25, 0, 25), Vector3(-20, 0, 15)]:
			var trunk = create_cyl.call(0.3, 4.0, pos + Vector3(0, 2.0, 0), mat_wood)
			for b in range(3):
				var branch = create_cyl.call(0.1, 2.0, pos + Vector3(randf_range(-1,1), 3.5, randf_range(-1,1)), mat_wood)
				branch.rotation_degrees = Vector3(randf_range(-45,45), randf_range(0,360), randf_range(-45,45))
		# Лужи и мусор
		for k in range(20):
			add_debris.call(Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)))

	elif level_id == "zavod":
		# Промышленные трубы и чаны
		for pos in [Vector3(-15, 4, -15), Vector3(15, 4, 0), Vector3(-15, 4, 15)]:
			create_cyl.call(4.0, 8.0, pos, mat_metal)
			create_cyl.call(4.1, 0.5, pos + Vector3(0, 4.0, 0), mat_glow)
		
		for x in [-20.0, 0.0, 20.0]:
			var pipe = create_cyl.call(0.5, 60, Vector3(x, 5.5, 0), mat_metal)
			pipe.rotation_degrees.x = 90
			# Вентили
			for z in range(-20, 21, 10):
				var valve = create_cyl.call(0.3, 0.3, Vector3(x, 5.5, z), create_mat("rust.png", Color(0.8, 0.1, 0.1), 1.0, true))
				valve.rotation_degrees.z = 90
				
		# Конвейерные ленты
		for i in range(-1, 2):
			create_box.call(Vector3(10, 0.5, 2), Vector3(i * 12, 1.0, 5), create_mat("metal.png", Color(0.1, 0.1, 0.1), 2.0, false))

	elif level_id == "lair":
		# Серверные стойки с мигающими огоньками
		for i in range(-3, 4):
			if i == 0: continue
			var pos = Vector3(i * 6.0, 2.0, -20.0)
			create_box.call(Vector3(2.5, 4.0, 1.5), pos, mat_dark)
			# Светодиоды
			for y in range(4):
				var led_mat = StandardMaterial3D.new()
				led_mat.albedo_color = Color(0, 1, 0) if randf() < 0.5 else Color(1, 0, 0)
				led_mat.emission_enabled = true
				led_mat.emission = led_mat.albedo_color
				create_box.call(Vector3(0.1, 0.1, 0.1), pos + Vector3(-0.8, -1.5 + y, -0.8), led_mat, false)
				create_box.call(Vector3(0.1, 0.1, 0.1), pos + Vector3(0.8, -1.5 + y, -0.8), led_mat, false)
				
		# Кабели под потолком
		for x in [-10.0, -5.0, 5.0, 10.0]:
			var cable = create_cyl.call(0.05, 40, Vector3(x, 5.8, 0), mat_dark, false)
			cable.rotation_degrees.x = 90
			
		for pos in [Vector3(-15, 4.0, -15), Vector3(15, 4.0, -15), Vector3(-15, 4.0, 15), Vector3(15, 4.0, 15)]:
			create_box.call(Vector3(1, 0.5, 1), pos, mat_glow, false)
			var light = OmniLight3D.new()
			light.position = pos
			light.omni_range = 20.0
			light.light_energy = 4.0
			light.light_color = mat_glow.emission
			nav_region.add_child(light)

	# --- СПАВН БОЧЕК ---
	for pos in [Vector3(-5, 1, -5), Vector3(5, 1, 5), Vector3(-15, 1, 0), Vector3(15, 1, 0)]:
		var b = BARREL_SCENE.instantiate()
		b.position = pos
		nav_region.add_child(b)

	# --- ТОЧКИ СПАВНА ---
	var spawn_points = [
		Vector3(-20, 0, -25), Vector3(20, 0, -25), Vector3(0, 0, -25),
		Vector3(-25, 0, 15), Vector3(25, 0, 15)
	]
	for i in range(spawn_points.size()):
		var marker = Marker3D.new()
		marker.name = "Spawn_" + str(i)
		marker.position = spawn_points[i]
		level_root.add_child(marker)
		
	create_weather_fx(level_root, level_id)
	return nav_region


static func create_weather_fx(parent: Node3D, level_id: String) -> void:
	if level_id == "prigorod":
		var ash = CPUParticles3D.new()
		ash.amount = 300
		ash.lifetime = 10.0
		ash.preprocess = 10.0
		ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		ash.emission_box_extents = Vector3(40, 20, 40)
		ash.direction = Vector3(1, -1, 0)
		ash.gravity = Vector3(0, -2, 0)
		ash.scale_amount_min = 0.05
		ash.scale_amount_max = 0.15
		var mesh = BoxMesh.new()
		mesh.size = Vector3(1, 1, 1)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.4, 0.4)
		mesh.material = mat
		ash.mesh = mesh
		ash.position = Vector3(0, 15, 0)
		parent.add_child(ash)
		
	elif level_id == "zavod":
		for pos in [Vector3(-10, 2, -10), Vector3(15, 4, 10)]:
			var sparks = CPUParticles3D.new()
			sparks.amount = 50
			sparks.lifetime = 0.5
			sparks.direction = Vector3(0, 1, 0)
			sparks.spread = 45.0
			sparks.gravity = Vector3(0, -9.8, 0)
			sparks.scale_amount_min = 0.02
			sparks.scale_amount_max = 0.05
			var mesh = BoxMesh.new()
			mesh.size = Vector3(1, 1, 1)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1, 0.5, 0)
			mat.emission_enabled = true
			mat.emission = Color(1, 0.5, 0)
			mesh.material = mat
			sparks.mesh = mesh
			sparks.position = pos
			parent.add_child(sparks)
