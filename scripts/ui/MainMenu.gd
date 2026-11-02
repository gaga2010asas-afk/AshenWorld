extends Control

@onready var btn_continue = get_node_or_null("MenuButtons/BtnContinue")
@onready var btn_new = get_node_or_null("MenuButtons/BtnNew")
@onready var btn_credits = get_node_or_null("MenuButtons/BtnCredits")
@onready var btn_settings = get_node_or_null("MenuButtons/BtnSettings")
@onready var btn_host = get_node_or_null("MenuButtons/BtnHost")
@onready var btn_join = get_node_or_null("MenuButtons/BtnJoin")
@onready var btn_quit = get_node_or_null("MenuButtons/BtnQuit")
@onready var settings_panel = get_node_or_null("SettingsPanel")
@onready var btn_close_settings = get_node_or_null("SettingsPanel/VBox/HBox/BtnClose")
@onready var tc = get_node_or_null("SettingsPanel/VBox/TabContainer")

var bg_city_root: Node3D
var bg_camera_tween: Tween

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_hide_overlapping_texts(self)
	
	var old_bg = get_node_or_null("Background")
	if old_bg: old_bg.hide()

	MusicManager.play_track("menu")
	MusicManager.play_track("menu")
	_setup_3d_background()
	_setup_trailer_btn()

	if settings_panel: settings_panel.visible = false
	
	if btn_continue:
		if GameManager.has_save():
			btn_continue.disabled = false
			btn_continue.modulate = Color(1, 1, 1)
		else:
			btn_continue.disabled = true
			btn_continue.modulate = Color(0.4, 0.4, 0.4)
		btn_continue.pressed.connect(func(): GameManager.load_game(); get_tree().change_scene_to_file("res://scenes/Hub.tscn"))
		
	if btn_new: 
		btn_new.pressed.connect(func(): GameManager.delete_save(); GameManager.save_game(); get_tree().change_scene_to_file("res://scenes/Hub.tscn"))
	if btn_credits: 
		btn_credits.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn"))
	
	if btn_settings: 
		btn_settings.pressed.connect(func(): 
			if settings_panel: 
				settings_panel.visible = not settings_panel.visible
				if settings_panel.visible: _populate_settings_ui()
		)
	
	if btn_quit: 
		btn_quit.pressed.connect(func(): 
			var dialog = ConfirmationDialog.new()
			dialog.title = "Выход"
			dialog.dialog_text = "ВЫ УВЕРЕНЫ?\nНесохраненный прогресс будет потерян."
			dialog.ok_button_text = "ВЫЙТИ"
			dialog.cancel_button_text = "ОТМЕНА"
			dialog.confirmed.connect(func(): get_tree().quit())
			add_child(dialog)
			dialog.popup_centered()
		)
		
	if btn_host: 
		btn_host.pressed.connect(func(): NetworkManager.host())
	if btn_join: 
		btn_join.pressed.connect(func(): 
			var dialog = ConfirmationDialog.new()
			dialog.title = "Подключиться"
			dialog.ok_button_text = "ПОДКЛЮЧИТЬСЯ"
			dialog.cancel_button_text = "ОТМЕНА"
			dialog.min_size = Vector2(400, 100)
			var vbox = VBoxContainer.new()
			dialog.add_child(vbox)
			var label = Label.new()
			label.text = "Введите IP и порт хоста (например, 192.168.1.5:7777):"
			vbox.add_child(label)
			var input = LineEdit.new()
			input.placeholder_text = "127.0.0.1:7777"
			input.custom_minimum_size = Vector2(350, 40)
			vbox.add_child(input)
			dialog.confirmed.connect(func(): 
				if input.text != "": NetworkManager.join(input.text)
			)
			add_child(dialog)
			dialog.popup_centered()
			input.grab_focus()
		)
	
	if btn_close_settings: 
		btn_close_settings.pressed.connect(func(): 
			GameManager.save_settings()
			if settings_panel: settings_panel.visible = false
		)

func _setup_trailer_btn() -> void:
	var menu_btns = get_node_or_null("MenuButtons")
	if menu_btns and not menu_btns.has_node("BtnTrailer"):
		var btn = Button.new()
		btn.name = "BtnTrailer"
		btn.text = "  > ТРЕЙЛЕР"
		btn.custom_minimum_size = Vector2(0, 45)
		btn.add_theme_font_size_override("font_size", 18)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if btn_new:
			btn.add_theme_stylebox_override("normal", btn_new.get_theme_stylebox("normal"))
			btn.add_theme_stylebox_override("hover", btn_new.get_theme_stylebox("hover"))
			btn.add_theme_color_override("font_color", btn_new.get_theme_color("font_color"))
			btn.add_theme_color_override("font_hover_color", btn_new.get_theme_color("font_hover_color"))
		btn.pressed.connect(_play_trailer)
		menu_btns.add_child(btn)
		menu_btns.move_child(btn, 1)

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
	env.environment.background_color = Color(0.15, 0.05, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.4, 0.1, 0.1)
	viewport.add_child(env)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	light.light_color = Color(1, 0.4, 0.2)
	light.light_energy = 1.5
	viewport.add_child(light)
	
	bg_city_root = Node3D.new()
	viewport.add_child(bg_city_root)
	
	var city_mat = StandardMaterial3D.new()
	city_mat.albedo_color = Color(0.1, 0.1, 0.12)
	for i in range(30):
		var box = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(randf_range(1, 3), randf_range(2, 8), randf_range(1, 3))
		box.mesh = mesh
		box.material_override = city_mat
		box.position = Vector3(randf_range(-15, 15), mesh.size.y / 2 - 2, randf_range(-20, 5))
		box.rotation_degrees.y = randf_range(0, 360)
		bg_city_root.add_child(box)
		
	var ash = CPUParticles3D.new()
	ash.amount = 150
	ash.lifetime = 5.0
	ash.preprocess = 5.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(20, 10, 20)
	ash.direction = Vector3(0, -1, 0)
	ash.gravity = Vector3(0, -1, 0)
	ash.initial_velocity_min = 1.0
	ash.initial_velocity_max = 2.0
	ash.scale_amount_min = 0.05
	ash.scale_amount_max = 0.1
	var ash_mesh = BoxMesh.new()
	ash_mesh.size = Vector3(1, 1, 1)
	var ash_mat = StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.6, 0.6, 0.6)
	ash_mesh.material = ash_mat
	ash.mesh = ash_mesh
	ash.position = Vector3(0, 10, 0)
	bg_city_root.add_child(ash)
	
	bg_camera_tween = create_tween().set_loops()
	bg_camera_tween.tween_property(cam, "position", Vector3(10, 6, -5), 10.0)
	bg_camera_tween.tween_property(cam, "position", Vector3(-10, 4, 15), 10.0)

func _play_trailer() -> void:
	var menu_btns = get_node_or_null("MenuButtons")
	var title_container = get_node_or_null("TitleContainer")
	if menu_btns: menu_btns.hide()
	if title_container: title_container.hide()
	
	if bg_camera_tween and bg_camera_tween.is_valid(): bg_camera_tween.kill()
	if bg_city_root: bg_city_root.hide()
	
	var trailer_text = Label.new()
	trailer_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	trailer_text.position = Vector2(-300, 150)
	trailer_text.custom_minimum_size = Vector2(600, 0)
	trailer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trailer_text.add_theme_font_size_override("font_size", 40)
	trailer_text.add_theme_color_override("font_color", Color(0, 1, 1))
	trailer_text.modulate.a = 0.0
	add_child(trailer_text)
	
	var viewport_container = null
	for child in get_children():
		if child is SubViewportContainer:
			viewport_container = child
			break
			
	if not viewport_container:
		_end_trailer(menu_btns, title_container, trailer_text)
		return
		
	var viewport = viewport_container.get_child(0)
	var cam = null
	for c in viewport.get_children():
		if c is Camera3D:
			cam = c
			break
			
	if not cam:
		_end_trailer(menu_btns, title_container, trailer_text)
		return
	
	var stage = Node3D.new()
	viewport.add_child(stage)
	
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.02, 0.02)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.2, 0.1, 0.1)
	env.environment.glow_enabled = true
	stage.add_child(env)
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-20, -45, 0)
	sun.light_color = Color(1, 0.4, 0.2)
	sun.light_energy = 3.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	
	var floor = MeshInstance3D.new()
	var p_mesh = PlaneMesh.new()
	p_mesh.size = Vector2(200, 200)
	floor.mesh = p_mesh
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.1, 0.1, 0.1)
	floor.material_override = f_mat
	floor.position.y = -0.01
	stage.add_child(floor)
	
	var hero = Node3D.new()
	hero.position = Vector3(0, 0, 5)
	stage.add_child(hero)
	
	var h_body = MeshInstance3D.new()
	var h_mesh = CapsuleMesh.new()
	h_mesh.radius = 0.4
	h_mesh.height = 1.8
	h_body.mesh = h_mesh
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0, 0.8, 1)
	h_mat.emission_enabled = true
	h_mat.emission = Color(0, 0.4, 0.5)
	h_body.material_override = h_mat
	h_body.position.y = 0.9
	hero.add_child(h_body)
	
	var h_gun = MeshInstance3D.new()
	var g_mesh = CylinderMesh.new()
	g_mesh.top_radius = 0.1
	g_mesh.bottom_radius = 0.1
	g_mesh.height = 1.5
	h_gun.mesh = g_mesh
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.2, 0.2, 0.2)
	h_gun.material_override = g_mat
	h_gun.rotation_degrees.x = 90
	h_gun.position = Vector3(0.5, 1.2, -0.5)
	hero.add_child(h_gun)
	
	var enemies = []
	var rifle_scene = load("res://scenes/enemies/Enemy_Rifle.tscn")
	var drone_scene = load("res://scenes/enemies/Enemy_Drone.tscn")
	var kam_scene = load("res://scenes/enemies/Enemy_Kamikaze.tscn")
	
	for i in range(40):
		var e = null
		if i % 3 == 0 and drone_scene: e = drone_scene.instantiate()
		elif i % 3 == 1 and kam_scene: e = kam_scene.instantiate()
		elif rifle_scene: e = rifle_scene.instantiate()
		else: e = Node3D.new()
		
		if e.has_method("set_physics_process"): e.set_physics_process(false)
		if e.has_method("set_process"): e.set_process(false)
		
		var x = randf_range(-20, 20)
		var z = randf_range(-35, -15)
		var y = randf_range(3, 6) if i % 3 == 0 else 0.5
		e.position = Vector3(x, y, z)
		stage.add_child(e)
		enemies.append(e)
		
	var t = create_tween()
	
	cam.position = stage.position + Vector3(15, 8, 20)
	cam.look_at_from_position(cam.position, stage.position + Vector3(0, 2, -15), Vector3.UP)
	trailer_text.text = "В МИРЕ, ГДЕ ТЕКСТУРЫ ЗАКОНЧИЛИСЬ..."
	t.tween_property(trailer_text, "modulate:a", 1.0, 1.0)
	t.tween_interval(1.5)
	t.tween_property(trailer_text, "modulate:a", 0.0, 0.5)
	
	t.tween_callback(func():
		trailer_text.text = "ОДИН ПРОТИВ АРМИИ..."
		trailer_text.modulate.a = 1.0
	)
	
	var rocket = MeshInstance3D.new()
	var r_mesh = CylinderMesh.new()
	r_mesh.top_radius = 0.1
	r_mesh.bottom_radius = 0.15
	r_mesh.height = 1.0
	rocket.mesh = r_mesh
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.8, 0.2, 0)
	r_mat.emission_enabled = true
	r_mat.emission = Color(0.8, 0.2, 0)
	rocket.material_override = r_mat
	rocket.rotation_degrees.x = 90
	rocket.position = Vector3(0, 1.5, 4)
	stage.add_child(rocket)
	
	t.tween_property(rocket, "position", Vector3(0, 1.5, -20), 0.8).set_trans(Tween.TRANS_LINEAR)
	
	t.tween_callback(func():
		if is_instance_valid(rocket): rocket.queue_free()
		
		var exp_light = OmniLight3D.new()
		exp_light.light_color = Color(1, 0.5, 0)
		exp_light.light_energy = 20.0
		exp_light.omni_range = 50.0
		exp_light.position = Vector3(0, 2, -20)
		stage.add_child(exp_light)
		
		var exp_mesh = MeshInstance3D.new()
		var s_mesh = SphereMesh.new()
		s_mesh.radius = 1.0
		exp_mesh.mesh = s_mesh
		
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(1, 0.5, 0, 1)
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.emission_enabled = true
		s_mat.emission = Color(1, 0.5, 0)
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		exp_mesh.material_override = s_mat
		exp_mesh.position = Vector3(0, 2, -20)
		stage.add_child(exp_mesh)
		
		var t_exp = create_tween()
		t_exp.set_parallel(true)
		t_exp.tween_property(exp_mesh, "scale", Vector3(6, 6, 6), 0.4)
		t_exp.tween_property(s_mat, "albedo_color:a", 0.0, 0.4)
		t_exp.tween_property(exp_light, "light_energy", 0.0, 0.4)
		
		for e in enemies:
			if is_instance_valid(e):
				var fly_dir = (e.position - Vector3(0, 2, -20)).normalized()
				var target_pos = e.position + fly_dir * 20.0 + Vector3(0, 15, 0)
				t_exp.tween_property(e, "position", target_pos, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t_exp.tween_property(e, "rotation", Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15)), 1.0)
	)
	
	# ФИНАЛ С ГРАНАТОЙ
	t.tween_interval(1.5)
	t.tween_property(trailer_text, "modulate:a", 0.0, 0.5)
	
	t.tween_callback(func():
		# Прячем героя и врагов, чтобы они не мешали
		hero.hide()
		for e in enemies:
			if is_instance_valid(e): e.hide()
		
		# Создаем гранату прямо в 3D-сцене
		var grenade = Node3D.new()
		stage.add_child(grenade)
		
		var g_body = MeshInstance3D.new()
		var b_mesh = SphereMesh.new()
		b_mesh.radius = 0.15
		b_mesh.height = 0.25
		g_body.mesh = b_mesh
		var mat_body = StandardMaterial3D.new()
		mat_body.albedo_color = Color(0.2, 0.35, 0.15)
		mat_body.roughness = 0.8
		g_body.material_override = mat_body
		grenade.add_child(g_body)

		var g_cap = MeshInstance3D.new()
		var c_mesh = CylinderMesh.new()
		c_mesh.top_radius = 0.05
		c_mesh.bottom_radius = 0.07
		c_mesh.height = 0.08
		g_cap.mesh = c_mesh
		g_cap.position.y = 0.14
		var mat_metal = StandardMaterial3D.new()
		mat_metal.albedo_color = Color(0.25, 0.25, 0.25)
		mat_metal.metallic = 0.8
		g_cap.material_override = mat_metal
		grenade.add_child(g_cap)

		var g_lever = MeshInstance3D.new()
		var l_mesh = BoxMesh.new()
		l_mesh.size = Vector3(0.03, 0.12, 0.01)
		g_lever.mesh = l_mesh
		g_lever.position = Vector3(0.07, 0.1, 0)
		g_lever.rotation_degrees.z = -15
		g_lever.material_override = mat_metal
		grenade.add_child(g_lever)

		var g_glow = MeshInstance3D.new()
		var gl_mesh = SphereMesh.new()
		gl_mesh.radius = 0.02
		g_glow.mesh = gl_mesh
		g_glow.position = Vector3(0, -0.05, -0.12)
		var mat_glow = StandardMaterial3D.new()
		mat_glow.albedo_color = Color(1, 0, 0)
		mat_glow.emission_enabled = true
		mat_glow.emission = Color(1, 0, 0)
		g_glow.material_override = mat_glow
		grenade.add_child(g_glow)
		
		# Ставим гранату прямо перед камерой (на расстоянии 1.5 метра)
		var cam_fwd = -cam.global_transform.basis.z
		grenade.global_position = cam.global_position + cam_fwd * 1.5
		
		# Вращаем гранату
		var t_spin = create_tween().set_loops()
		t_spin.tween_property(grenade, "rotation:y", TAU, 1.0)
	)
	
	t.tween_interval(1.5)
	
	t.tween_callback(func():
		var flash = ColorRect.new()
		flash.color = Color(1, 1, 1, 0)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(flash)
		
		var t_flash = create_tween()
		t_flash.tween_property(flash, "color:a", 1.0, 0.05)
		t_flash.tween_property(flash, "color:a", 0.0, 0.5)
		t_flash.tween_callback(flash.queue_free)
		
		trailer_text.text = "НА ЭТУ ГРАНАТУ\nУШЕЛ ВЕСЬ БЮДЖЕТ!"
		trailer_text.add_theme_color_override("font_color", Color(1, 0.5, 0))
		trailer_text.add_theme_font_size_override("font_size", 60)
		trailer_text.modulate.a = 1.0
		
		for child in get_children():
			if child is Node3D and child != stage:
				child.queue_free()
	)
	
	t.tween_interval(2.5)
	t.tween_property(trailer_text, "modulate:a", 0.0, 1.0)
	
	t.tween_callback(func():
		stage.queue_free()
		_end_trailer(menu_btns, title_container, trailer_text)
	)

func _end_trailer(menu_btns: Node, title_container: Node, trailer_text: Node) -> void:
	if is_instance_valid(menu_btns): menu_btns.show()
	if is_instance_valid(title_container): title_container.show()
	if is_instance_valid(trailer_text): trailer_text.queue_free()
	
	if bg_city_root: bg_city_root.show()
	var vp_container = null
	for child in get_children():
		if child is SubViewportContainer:
			vp_container = child
			break
	if vp_container:
		var vp = vp_container.get_child(0)
		for c in vp.get_children():
			if c is Camera3D:
				c.position = Vector3(0, 5, 15)
				c.look_at_from_position(c.position, Vector3(0, 2, 0), Vector3.UP)
				bg_camera_tween = create_tween().set_loops()
				bg_camera_tween.tween_property(c, "position", Vector3(10, 6, -5), 10.0)
				bg_camera_tween.tween_property(c, "position", Vector3(-10, 4, 15), 10.0)
				break

func _populate_settings_ui() -> void:
	if not tc: return
	for child in tc.get_children():
		child.queue_free()
		
	var game_tab = VBoxContainer.new()
	tc.add_child(game_tab)
	tc.set_tab_title(tc.get_tab_count() - 1, "Игра")
	
	var lbl_diff = Label.new(); lbl_diff.text = "Сложность:"; game_tab.add_child(lbl_diff)
	var opt_diff = OptionButton.new()
	opt_diff.add_item("Легкая"); opt_diff.add_item("Средняя"); opt_diff.add_item("Сложная")
	opt_diff.selected = GameManager.difficulty
	opt_diff.item_selected.connect(func(idx): GameManager.difficulty = idx)
	game_tab.add_child(opt_diff)
	
	var lbl_sens = Label.new(); lbl_sens.text = "Чувствительность мыши:"; game_tab.add_child(lbl_sens)
	var slider_sens = HSlider.new()
	slider_sens.min_value = 0.1; slider_sens.max_value = 2.0; slider_sens.step = 0.05
	slider_sens.value = GameManager.mouse_sens * 1000
	slider_sens.value_changed.connect(func(v): GameManager.mouse_sens = v / 1000.0)
	game_tab.add_child(slider_sens)

	var graph_tab = VBoxContainer.new()
	tc.add_child(graph_tab)
	tc.set_tab_title(tc.get_tab_count() - 1, "Графика")
	
	var lbl_win = Label.new(); lbl_win.text = "Режим окна:"; graph_tab.add_child(lbl_win)
	var opt_win = OptionButton.new()
	opt_win.add_item("Оконный"); opt_win.add_item("Полноэкранный")
	opt_win.selected = GameManager.window_mode
	opt_win.item_selected.connect(func(idx): GameManager.window_mode = idx; GameManager.apply_settings())
	graph_tab.add_child(opt_win)
	
	var chk_vsync = CheckBox.new()
	chk_vsync.text = "Вертикальная синхронизация"
	chk_vsync.button_pressed = GameManager.vsync == 1
	chk_vsync.toggled.connect(func(val): GameManager.vsync = 1 if val else 0; GameManager.apply_settings())
	graph_tab.add_child(chk_vsync)

	var sound_tab = VBoxContainer.new()
	tc.add_child(sound_tab)
	tc.set_tab_title(tc.get_tab_count() - 1, "Звук")
	
	var lbl_vol = Label.new(); lbl_vol.text = "Общая громкость:"; sound_tab.add_child(lbl_vol)
	var slider_vol = HSlider.new()
	slider_vol.value = GameManager.volume_master * 100
	slider_vol.value_changed.connect(func(v): GameManager.volume_master = v / 100.0; GameManager.apply_settings())
	sound_tab.add_child(slider_vol)
	
	var ctrl_tab = VBoxContainer.new()
	tc.add_child(ctrl_tab)
	tc.set_tab_title(tc.get_tab_count() - 1, "Управление")
	var lbl_ctrl = Label.new(); lbl_ctrl.text = "WASD - Движение\nQ - Экзокостюм\nF - Фонарик\nG - Граната\nR - Перезарядка\nTab - Таблица"
	ctrl_tab.add_child(lbl_ctrl)
	
	var hud_tab = VBoxContainer.new()
	tc.add_child(hud_tab)
	tc.set_tab_title(tc.get_tab_count() - 1, "Интерфейс")
	
	var chk_fps = CheckBox.new()
	chk_fps.text = "Показывать FPS"
	chk_fps.button_pressed = GameManager.show_fps
	chk_fps.toggled.connect(func(val): GameManager.show_fps = val)
	hud_tab.add_child(chk_fps)
	
	var chk_cb = CheckBox.new()
	chk_cb.text = "Режим для дальтоников"
	chk_cb.button_pressed = GameManager.colorblind
	chk_cb.toggled.connect(func(val): GameManager.colorblind = val)
	hud_tab.add_child(chk_cb)

	var hbox = get_node_or_null("SettingsPanel/VBox/HBox")
	if hbox and not hbox.has_node("BtnApply"):
		var close_btn = hbox.get_node_or_null("BtnClose")
		
		var btn_reset = Button.new()
		btn_reset.text = "СБРОС"
		btn_reset.custom_minimum_size = Vector2(150, 45)
		if close_btn: btn_reset.add_theme_stylebox_override("normal", close_btn.get_theme_stylebox("normal"))
		btn_reset.pressed.connect(func():
			GameManager.difficulty = 1; GameManager.mouse_sens = 0.002; GameManager.window_mode = 0; GameManager.volume_master = 1.0
			GameManager.save_settings(); GameManager.apply_settings(); get_tree().reload_current_scene()
		)
		hbox.add_child(btn_reset)
		hbox.move_child(btn_reset, 0)

		var btn_apply = Button.new()
		btn_apply.name = "BtnApply"
		btn_apply.text = "ПРИМЕНИТЬ"
		btn_apply.custom_minimum_size = Vector2(150, 45)
		if close_btn: btn_apply.add_theme_stylebox_override("normal", close_btn.get_theme_stylebox("normal"))
		btn_apply.pressed.connect(func():
			GameManager.save_settings(); GameManager.apply_settings()
			btn_apply.text = "СОХРАНЕНО!"
			await get_tree().create_timer(1.5).timeout
			if is_instance_valid(btn_apply): btn_apply.text = "ПРИМЕНИТЬ"
		)
		hbox.add_child(btn_apply)
		hbox.move_child(btn_apply, hbox.get_child_count() - 2)

func _hide_overlapping_texts(node: Node) -> void:
	for child in node.get_children():
		if child is Label or child is RichTextLabel:
			if "СИСТЕМА" in child.text or "БЮДЖЕТ" in child.text:
				child.hide()
		if child.get_child_count() > 0:
			_hide_overlapping_texts(child)
