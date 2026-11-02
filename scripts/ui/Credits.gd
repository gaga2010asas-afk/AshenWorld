extends Control

var scroll_label: Label

func _ready() -> void:
	MusicManager.play_track("credits")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_3d_background()
	
	# Текст титров
	scroll_label = Label.new()
	scroll_label.text = "\n\n\nПЕПЕЛЬНЫЙ МИР\n\n" + \
		"ГЛАВНЫЙ ПО КУБАМ: ИИ\n" + \
		"ОТВЕТСТВЕННЫЙ ЗА ГРАНАТЫ: ИИ\n" + \
		"ЧЕЛОВЕК, СКАЗАВШИЙ 'ДОБАВИМ ЕЩЕ ОДИН КУБ': ИИ\n" + \
		"ТЕСТИРОВЩИК ВЫЛЕТОВ: ТЫ\n\n" + \
		"СПАСИБО ЗА ИГРУ!"
	
	scroll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll_label.add_theme_font_size_override("font_size", 32)
	scroll_label.add_theme_color_override("font_color", Color(0, 1, 1))
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll_label)
	
	scroll_label.position = Vector2(size.x / 2 - 300, size.y)
	
	var tween = create_tween()
	tween.tween_property(scroll_label, "position:y", -800.0, 15.0)
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	
	var btn_back = Button.new()
	btn_back.text = "НАЗАД"
	btn_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_back.position = Vector2(-150, -80)
	btn_back.custom_minimum_size = Vector2(120, 40)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	add_child(btn_back)

func _setup_3d_background() -> void:
	var container = SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	move_child(container, 0)
	
	var viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0, 5, 15)
	cam.look_at_from_position(cam.position, Vector3(0, 2, 0), Vector3.UP)
	viewport.add_child(cam)
	
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.02, 0.02)
	viewport.add_child(env)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	light.light_color = Color(1, 0.3, 0.1)
	light.light_energy = 1.0
	viewport.add_child(light)
	
	var city_mat = StandardMaterial3D.new()
	city_mat.albedo_color = Color(0.05, 0.05, 0.05)
	for i in range(20):
		var box = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(randf_range(1, 3), randf_range(2, 8), randf_range(1, 3))
		box.mesh = mesh
		box.material_override = city_mat
		box.position = Vector3(randf_range(-15, 15), mesh.size.y / 2 - 2, randf_range(-20, 5))
		viewport.add_child(box)
		
	var ash = CPUParticles3D.new()
	ash.amount = 200
	ash.lifetime = 5.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(20, 10, 20)
	ash.direction = Vector3(0, -1, 0)
	ash.gravity = Vector3(0, -1, 0)
	var ash_mesh = BoxMesh.new()
	ash_mesh.size = Vector3(1, 1, 1)
	var ash_mat = StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.6, 0.6, 0.6)
	ash_mesh.material = ash_mat
	ash.mesh = ash_mesh
	ash.position = Vector3(0, 10, 0)
	viewport.add_child(ash)
