extends Node3D

var player: Node3D
var interact_label: Label3D
var current_interactable: String = ""
var dialogue_ui: CanvasLayer

var missions = [
	{"id": "sklad", "name": "СКЛАД", "pos": Vector3(-10, 0, -9.5), "req": 0},
	{"id": "prigorod", "name": "ПРИГОРОД", "pos": Vector3(-3, 0, -9.5), "req": 1},
	{"id": "zavod", "name": "ЗАВОД", "pos": Vector3(4, 0, -9.5), "req": 2},
	{"id": "lair", "name": "ЛОГОВО", "pos": Vector3(11, 0, -9.5), "req": 3}
]

func _ready() -> void:
	MusicManager.play_track("hub")
	_build_base()
	
	player = preload("res://scenes/actors/Player.tscn").instantiate()
	player.name = "1"
	add_child(player)
	player.global_position = Vector3(0, 1, 5)
	
	await get_tree().process_frame
	# БЕЗОПАСНЫЙ ДОСТУП К HUD (Защита от вылетов)
	if is_instance_valid(player):
		var hud = player.get_node_or_null("HUD")
		if is_instance_valid(hud):
			var wl = hud.get_node_or_null("WaveLabel")
			if wl:
				wl.text = "БАЗА (ХАБ)"
				wl.modulate = Color(1, 1, 1, 1)
			
			GameManager.money_changed.connect(hud.update_money)
			hud.update_money(GameManager.money)

func _build_base() -> void:
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.ambient_light_energy = 2.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.fog_enabled = false 
	env_node.environment = env
	add_child(env_node)

	var sun = DirectionalLight3D.new()
	sun.transform.basis = Basis.looking_at(Vector3(-1, -1.5, -1))
	sun.light_color = Color(0.9, 0.9, 1.0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	add_child(sun)

	var mat_floor = StandardMaterial3D.new()
	mat_floor.albedo_color = Color(0.2, 0.2, 0.25)
	mat_floor.metallic = 0.6
	mat_floor.roughness = 0.4

	var mat_wall = StandardMaterial3D.new()
	mat_wall.albedo_color = Color(0.4, 0.4, 0.45)
	mat_wall.metallic = 0.2
	mat_wall.roughness = 0.8

	var mat_panel = StandardMaterial3D.new()
	mat_panel.albedo_color = Color(0.25, 0.25, 0.3)
	mat_panel.metallic = 0.8
	mat_panel.roughness = 0.3
	
	var mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.05, 0.05, 0.05)
	
	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.8, 0.6, 0.1)
	mat_gold.metallic = 0.8
	mat_gold.roughness = 0.2
	
	var mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.8, 0.6, 0.5)
	
	var mat_cloth = StandardMaterial3D.new()
	mat_cloth.albedo_color = Color(0.1, 0.2, 0.1)
	
	var mat_carpet = StandardMaterial3D.new()
	mat_carpet.albedo_color = Color(0.6, 0.05, 0.05)
	mat_carpet.roughness = 1.0

	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var f_col = CollisionShape3D.new()
	var f_shape = BoxShape3D.new()
	f_shape.size = Vector3(30, 1, 20)
	f_col.shape = f_shape
	floor_body.add_child(f_col)
	
	var f_mesh = MeshInstance3D.new()
	var f_box = BoxMesh.new()
	f_box.size = Vector3(30, 1, 20)
	f_mesh.mesh = f_box
	f_mesh.material_override = mat_floor
	floor_body.add_child(f_mesh)
	floor_body.position.y = -0.5
	add_child(floor_body)
	
	var carpet = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(2.0, 0.05, 10.0)
	carpet.mesh = c_box
	carpet.material_override = mat_carpet
	carpet.position = Vector3(0, 0.02, -1.0)
	add_child(carpet)

	var walls = [
		{"pos": Vector3(0, 3, -10), "size": Vector3(30, 6, 1)},
		{"pos": Vector3(-15, 3, 0), "size": Vector3(1, 6, 20)},
		{"pos": Vector3(15, 3, 0), "size": Vector3(1, 6, 20)},
		{"pos": Vector3(0, 3, 10), "size": Vector3(30, 6, 1)},
		{"pos": Vector3(0, 6, 0), "size": Vector3(30, 1, 20)}
	]
	for w in walls:
		var wall = StaticBody3D.new()
		wall.collision_layer = 1
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = w["size"]
		col.shape = shape
		wall.add_child(col)
		
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = w["size"]
		mesh.mesh = box
		mesh.material_override = mat_wall
		wall.add_child(mesh)
		wall.position = w["pos"]
		add_child(wall)

	for i in range(4):
		var p_l = MeshInstance3D.new()
		var p_box = BoxMesh.new()
		p_box.size = Vector3(0.2, 4.0, 2.0)
		p_l.mesh = p_box
		p_l.material_override = mat_panel
		p_l.position = Vector3(-14.8, 3.0, -6 + i*4)
		add_child(p_l)
		
		var p_r = MeshInstance3D.new()
		p_r.mesh = p_box
		p_r.material_override = mat_panel
		p_r.position = Vector3(14.8, 3.0, -6 + i*4)
		add_child(p_r)

	for z in [5.0, 0.0, -5.0]:
		var ceil_light = OmniLight3D.new()
		ceil_light.position = Vector3(0, 5.5, z)
		ceil_light.light_color = Color(0.8, 0.9, 1.0)
		ceil_light.light_energy = 3.0
		ceil_light.omni_range = 15.0
		add_child(ceil_light)
		
		var l_mesh = MeshInstance3D.new()
		var l_box = BoxMesh.new()
		l_box.size = Vector3(1.5, 0.1, 1.5)
		l_mesh.mesh = l_box
		var mat_light = StandardMaterial3D.new()
		mat_light.albedo_color = Color(1, 1, 1)
		mat_light.emission_enabled = true
		mat_light.emission = Color(1, 1, 1)
		mat_light.emission_energy_multiplier = 3.0
		l_mesh.material_override = mat_light
		l_mesh.position = Vector3(0, 5.9, z)
		add_child(l_mesh)

	var throne = Node3D.new()
	throne.position = Vector3(0, 0, -5)
	throne.rotation_degrees.y = 180
	add_child(throne)
	
	var make_part = func(sz: Vector3, pos: Vector3, mat: Material, p_node: Node3D) -> MeshInstance3D:
		var m = MeshInstance3D.new()
		var b = BoxMesh.new()
		b.size = sz
		m.mesh = b
		m.position = pos
		m.material_override = mat
		p_node.add_child(m)
		return m

	make_part.call(Vector3(2.4, 0.4, 2.0), Vector3(0, 0.2, 0), mat_dark, throne)
	make_part.call(Vector3(1.8, 0.6, 1.6), Vector3(0, 0.7, 0), mat_gold, throne)
	make_part.call(Vector3(1.4, 0.2, 1.4), Vector3(0, 1.1, 0), mat_carpet, throne)
	make_part.call(Vector3(2.4, 3.5, 0.4), Vector3(0, 1.75, 0.8), mat_dark, throne)
	make_part.call(Vector3(1.8, 3.0, 0.1), Vector3(0, 1.75, 0.55), mat_gold, throne)
	make_part.call(Vector3(0.5, 1.0, 1.8), Vector3(-1.0, 1.2, 0), mat_gold, throne)
	make_part.call(Vector3(0.5, 1.0, 1.8), Vector3(1.0, 1.2, 0), mat_gold, throne)

	var chief = Node3D.new()
	chief.position = Vector3(0, 0.6, 0)
	throne.add_child(chief)
	
	make_part.call(Vector3(0.7, 0.8, 0.4), Vector3(0, 1.0, 0), mat_cloth, chief)
	make_part.call(Vector3(0.25, 0.6, 0.25), Vector3(-0.18, 0.3, -0.2), mat_dark, chief)
	make_part.call(Vector3(0.25, 0.6, 0.25), Vector3(0.18, 0.3, -0.2), mat_dark, chief)
	make_part.call(Vector3(0.2, 0.7, 0.2), Vector3(-0.45, 1.0, 0), mat_cloth, chief)
	make_part.call(Vector3(0.2, 0.7, 0.2), Vector3(0.45, 1.0, 0), mat_cloth, chief)
	make_part.call(Vector3(0.4, 0.4, 0.4), Vector3(0, 1.6, 0), mat_skin, chief)
	make_part.call(Vector3(0.06, 0.06, 0.06), Vector3(-0.1, 1.65, -0.2), mat_dark, chief)
	make_part.call(Vector3(0.06, 0.06, 0.06), Vector3(0.1, 1.65, -0.2), mat_dark, chief)
	make_part.call(Vector3(0.25, 0.06, 0.06), Vector3(0, 1.55, -0.2), mat_dark, chief)
	make_part.call(Vector3(0.5, 0.12, 0.5), Vector3(0, 1.85, 0), mat_dark, chief)
	make_part.call(Vector3(0.35, 0.06, 0.2), Vector3(0, 1.8, -0.3), mat_dark, chief)
	
	var chief_light = SpotLight3D.new()
	chief_light.position = Vector3(0, 5, -5)
	chief_light.rotation_degrees.x = -90
	chief_light.light_color = Color(1.0, 0.9, 0.8)
	chief_light.light_energy = 8.0
	chief_light.spot_range = 10.0
	chief_light.spot_angle = 40.0
	add_child(chief_light)
	
	var chief_area = Area3D.new()
	chief_area.collision_mask = 2
	var ca_col = CollisionShape3D.new()
	var ca_shape = SphereShape3D.new()
	ca_shape.radius = 2.5
	ca_col.shape = ca_shape
	chief_area.add_child(ca_col)
	chief_area.position = Vector3(0, 1.5, -5)
	chief_area.body_entered.connect(func(b): if b.is_in_group("player"): current_interactable = "chief")
	chief_area.body_exited.connect(func(b): if b.is_in_group("player") and current_interactable == "chief": current_interactable = "")
	add_child(chief_area)
	
	var shop = Node3D.new()
	shop.position = Vector3(-10, 0, -3)
	add_child(shop) # Сначала добавляем в дерево!
	shop.look_at(Vector3(0, 0, -3), Vector3.UP) # Теперь можно поворачивать
	
	var shop_body = StaticBody3D.new()
	shop_body.collision_layer = 1
	var s_col = CollisionShape3D.new()
	var s_shape = BoxShape3D.new()
	s_shape.size = Vector3(1.6, 1.8, 0.8)
	s_col.shape = s_shape
	s_col.position = Vector3(0, 0.9, 0)
	shop_body.add_child(s_col)
	shop.add_child(shop_body)
	
	make_part.call(Vector3(1.6, 1.8, 0.8), Vector3(0, 0.9, 0), mat_dark, shop)
	
	var screen_light = StandardMaterial3D.new()
	screen_light.albedo_color = Color(0, 0.3, 0.6)
	screen_light.emission_enabled = true
	screen_light.emission = Color(0, 0.4, 0.8)
	screen_light.emission_energy_multiplier = 2.0
	make_part.call(Vector3(1.2, 0.8, 0.1), Vector3(0, 1.3, -0.45), screen_light, shop)
	
	make_part.call(Vector3(0.9, 0.3, 0.2), Vector3(0, 0.8, -0.45), mat_panel, shop)
	
	var mat_red = StandardMaterial3D.new()
	mat_red.albedo_color = Color(1, 0.1, 0.1)
	mat_red.emission_enabled = true
	mat_red.emission = Color(1, 0.1, 0.1)
	mat_red.emission_energy_multiplier = 3.0
	
	var eye_l = make_part.call(Vector3(0.15, 0.04, 0.02), Vector3(-0.2, 1.45, -0.51), mat_red, shop)
	eye_l.rotation_degrees.z = -20
	var eye_r = make_part.call(Vector3(0.15, 0.04, 0.02), Vector3(0.2, 1.45, -0.51), mat_red, shop)
	eye_r.rotation_degrees.z = 20
	var mouth = make_part.call(Vector3(0.3, 0.04, 0.02), Vector3(0, 1.15, -0.51), mat_red, shop)
	mouth.rotation_degrees.z = 180
	
	var shop_area = Area3D.new()
	shop_area.collision_mask = 2
	var sa_col = CollisionShape3D.new()
	var sa_shape = SphereShape3D.new()
	sa_shape.radius = 2.5
	sa_col.shape = sa_shape
	shop_area.add_child(sa_col)
	shop_area.position = shop.position + Vector3(0, 1, 0)
	shop_area.body_entered.connect(func(b): if b.is_in_group("player"): current_interactable = "shop")
	shop_area.body_exited.connect(func(b): if b.is_in_group("player") and current_interactable == "shop": current_interactable = "")
	add_child(shop_area)

	for m in missions:
		var door = Node3D.new()
		door.position = m["pos"]
		add_child(door)
		
		var door_body = StaticBody3D.new()
		door_body.collision_layer = 1
		var d_col = CollisionShape3D.new()
		var d_shape = BoxShape3D.new()
		d_shape.size = Vector3(2.5, 4.0, 0.4)
		d_col.shape = d_shape
		d_col.position = Vector3(0, 2.0, 0.1)
		door_body.add_child(d_col)
		door.add_child(door_body)
		
		make_part.call(Vector3(3.0, 0.4, 0.6), Vector3(0, 4.2, 0), mat_panel, door)
		make_part.call(Vector3(3.0, 0.4, 0.6), Vector3(0, -0.2, 0), mat_panel, door)
		make_part.call(Vector3(0.4, 4.8, 0.6), Vector3(-1.3, 2.0, 0), mat_panel, door)
		make_part.call(Vector3(0.4, 4.8, 0.6), Vector3(1.3, 2.0, 0), mat_panel, door)
		
		var door_cyl = CylinderMesh.new()
		door_cyl.top_radius = 1.2
		door_cyl.bottom_radius = 1.2
		door_cyl.height = 0.4
		var cyl_mesh = MeshInstance3D.new()
		cyl_mesh.mesh = door_cyl
		cyl_mesh.rotation_degrees.x = 90
		cyl_mesh.position = Vector3(0, 2.0, 0)
		cyl_mesh.material_override = mat_wall
		door.add_child(cyl_mesh)
		
		for i in range(8):
			var angle = i * (PI / 4.0)
			var bolt = MeshInstance3D.new()
			var b_m = CylinderMesh.new()
			b_m.top_radius = 0.1
			b_m.bottom_radius = 0.1
			b_m.height = 0.15
			bolt.mesh = b_m
			bolt.rotation_degrees.x = 90
			bolt.position = Vector3(cos(angle) * 1.0, 2.0 + sin(angle) * 1.0, 0.25)
			bolt.material_override = mat_gold
			door.add_child(bolt)
		
		var wheel = CylinderMesh.new()
		wheel.top_radius = 0.5
		wheel.bottom_radius = 0.5
		wheel.height = 0.15
		var wheel_mesh = MeshInstance3D.new()
		wheel_mesh.mesh = wheel
		wheel_mesh.rotation_degrees.x = 90
		wheel_mesh.position = Vector3(0, 2.0, 0.35)
		wheel_mesh.material_override = mat_gold
		door.add_child(wheel_mesh)
		
		for i in range(4):
			var spoke = MeshInstance3D.new()
			var s_box = BoxMesh.new()
			s_box.size = Vector3(1.0, 0.1, 0.1)
			spoke.mesh = s_box
			spoke.position = Vector3(0, 2.0, 0.35)
			spoke.rotation_degrees.z = i * 45
			spoke.material_override = mat_gold
			door.add_child(spoke)
		
		var door_area = Area3D.new()
		door_area.collision_mask = 2
		var da_col = CollisionShape3D.new()
		var da_shape = SphereShape3D.new()
		da_shape.radius = 2.5
		da_col.shape = da_shape
		door_area.add_child(da_col)
		door_area.position = door.position + Vector3(0, 1, 0.5)
		
		var mission_id = m["id"]
		door_area.body_entered.connect(func(b): 
			if b.is_in_group("player"): 
				current_interactable = "door_" + mission_id
		)
		door_area.body_exited.connect(func(b): 
			if b.is_in_group("player") and current_interactable == "door_" + mission_id: 
				current_interactable = ""
		)
		add_child(door_area)
		
		var label = Label3D.new()
		label.text = m["name"]
		label.font_size = 48
		label.position = m["pos"] + Vector3(0, 4.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

	interact_label = Label3D.new()
	interact_label.font_size = 24
	interact_label.pixel_size = 0.005
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1, 1, 0)
	interact_label.no_depth_test = true
	interact_label.render_priority = 2
	interact_label.visible = false
	add_child(interact_label)

func _process(_delta: float) -> void:
	if not player or player.is_in_dialogue or get_tree().paused:
		interact_label.visible = false
		return
		
	if current_interactable != "":
		interact_label.visible = true
		var target_pos = Vector3.ZERO
		var text = ""
		
		if current_interactable == "chief":
			target_pos = Vector3(0, 3.0, -4.0)
			text = "[E] Поговорить"
		elif current_interactable == "shop":
			target_pos = Vector3(-10, 2.5, -3.0)
			text = "[E] Терминал"
		elif current_interactable.begins_with("door_"):
			var m_id = current_interactable.replace("door_", "")
			var req = 0
			var pos = Vector3.ZERO
			
			for m in missions:
				if m["id"] == m_id:
					req = m["req"]
					pos = m["pos"] + Vector3(0, 2.5, 1.5)
					
			target_pos = pos
			if GameManager.progress >= req:
				text = "[E] Начать миссию"
			else:
				text = "[X] Требуется пройти прошлые миссии"
				interact_label.modulate = Color(1, 0.3, 0.3)
				
		if interact_label.modulate != Color(1, 0.3, 0.3) and not text.begins_with("[X]"):
			interact_label.modulate = Color(1, 1, 0)
			
		interact_label.global_position = target_pos
		interact_label.text = text
	else:
		interact_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable != "" and not player.is_in_dialogue and not get_tree().paused:
		if current_interactable == "chief":
			if GameManager.progress == 0:
				_start_dialogue(["Начальник: Начни со Склада. Там наш напарник застрял.", "Начальник: И да, не забудь купить патроны."])
			elif GameManager.progress == 1:
				_start_dialogue(["Начальник: Склад чист. Отлично.", "Начальник: Теперь Пригород. Сюжет прямолинейный: иди туда, стреляй."])
			elif GameManager.progress == 2:
				_start_dialogue(["Начальник: В Пригороде тоже порядок.", "Начальник: Завод ждет. Там вертикальный геймплей. Не смотри вниз."])
			elif GameManager.progress == 3:
				_start_dialogue(["Начальник: Ты почти у цели.", "Начальник: Логово. Я буду ждать тебя там. Пора заканчивать этот цирк."])
			else:
				_start_dialogue(["Начальник: Ты победил. Иди наслаждайся титрами.", "Начальник: Ах да, титров нет. Бюджет кончился."])
		elif current_interactable == "shop":
			var shop_ui = preload("res://scenes/ui/Shop.tscn").instantiate()
			add_child(shop_ui)
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif current_interactable.begins_with("door_"):
			var m_id = current_interactable.replace("door_", "")
			var req = 0
			for m in missions:
				if m["id"] == m_id: req = m["req"]
			
			if GameManager.progress >= req:
				# ОТЛОЖЕННЫЙ ПЕРЕХОД (фиксит зависание Environment)
				get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/Level_" + m_id.capitalize() + ".tscn")
			else:
				_start_dialogue(["Начальник: Эй, не так быстро. Сначала зачисти предыдущие точки."])

func _start_dialogue(lines: Array) -> void:
	if player.is_in_dialogue: return
	dialogue_ui = preload("res://scenes/ui/Dialogue.tscn").instantiate()
	add_child(dialogue_ui)
	dialogue_ui.start_dialogue(lines, player)
