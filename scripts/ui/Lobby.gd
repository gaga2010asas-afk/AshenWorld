extends Control

var list_vbox: VBoxContainer
var chat_log: RichTextLabel
var chat_input: LineEdit
var map_buttons = {}
var btn_start: Button
var btn_ready: Button

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_3d_background()
	_build_ui()
	
	if not NetworkManager.player_list_changed.is_connected(_update_player_list):
		NetworkManager.player_list_changed.connect(_update_player_list)
	if not NetworkManager.map_changed.is_connected(_update_map_ui):
		NetworkManager.map_changed.connect(_update_map_ui)
	
	_update_player_list()
	_update_map_ui(NetworkManager.chosen_map)

func _setup_3d_background() -> void:
	var container = SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
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
		viewport.add_child(box)

	var ash = CPUParticles3D.new()
	ash.amount = 150
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

func _build_ui() -> void:
	# Затемнение поверх 3D
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 50
	main_hbox.offset_top = 50
	main_hbox.offset_right = -50
	main_hbox.offset_bottom = -50
	main_hbox.add_theme_constant_override("separation", 30)
	add_child(main_hbox)

	# --- ЛЕВАЯ ПАНЕЛЬ (Игроки) ---
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(350, 0)
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.05, 0.05, 0.1, 0.8)
	left_style.border_color = Color(0, 1, 1, 0.5)
	left_style.set_border_width_all(2)
	left_panel.add_theme_stylebox_override("panel", left_style)
	main_hbox.add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 15)
	left_panel.add_child(left_vbox)
	
	var lbl_title = Label.new()
	lbl_title.text = "СПИСОК ИГРОКОВ"
	lbl_title.add_theme_font_size_override("font_size", 20)
	lbl_title.add_theme_color_override("font_color", Color(0, 1, 1))
	left_vbox.add_child(lbl_title)
	
	var lbl_ip = Label.new()
	lbl_ip.text = "Ваш IP: " + NetworkManager.get_local_ip() + ":" + str(NetworkManager.current_port) if NetworkManager.is_host else "Подключен к хосту"
	lbl_ip.add_theme_color_override("font_color", Color(1, 1, 0))
	left_vbox.add_child(lbl_ip)
	
	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(list_vbox)
	
	# --- ЦЕНТРАЛЬНАЯ ПАНЕЛЬ (Карты и Чат) ---
	var center_vbox = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 20)
	main_hbox.add_child(center_vbox)

	var lbl_maps = Label.new()
	lbl_maps.text = "ВЫБОР МИССИИ (Только хост):"
	lbl_maps.add_theme_font_size_override("font_size", 20)
	lbl_maps.add_theme_color_override("font_color", Color(0, 1, 1))
	center_vbox.add_child(lbl_maps)

	var map_hbox = HBoxContainer.new()
	map_hbox.add_theme_constant_override("separation", 10)
	map_hbox.visible = NetworkManager.is_host # Видят только хосты
	center_vbox.add_child(map_hbox)
	
	for map_name in ["Склад", "Пригород", "Завод", "Логово"]:
		var btn = Button.new()
		btn.text = map_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 50)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.05, 0.05, 0.1, 0.8)
		btn_style.border_color = Color(0, 1, 1, 0.5)
		btn_style.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style) # Упрощение
		
		btn.pressed.connect(func(): 
			if NetworkManager.is_host:
				NetworkManager.change_map(map_name.to_lower())
		)
		map_buttons[map_name.to_lower()] = btn
		map_hbox.add_child(btn)
		
	# Чат
	var chat_panel = PanelContainer.new()
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chat_style = StyleBoxFlat.new()
	chat_style.bg_color = Color(0.02, 0.02, 0.05, 0.9)
	chat_style.border_color = Color(0, 1, 1, 0.3)
	chat_style.set_border_width_all(1)
	chat_panel.add_theme_stylebox_override("panel", chat_style)
	center_vbox.add_child(chat_panel)
	
	var chat_vbox = VBoxContainer.new()
	chat_panel.add_child(chat_vbox)
	
	chat_log = RichTextLabel.new()
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.scroll_following = true
	chat_log.add_theme_font_size_override("normal_font_size", 16)
	chat_vbox.add_child(chat_log)
	
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Нажмите Enter, чтобы отправить сообщение..."
	chat_input.custom_minimum_size = Vector2(0, 40)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_vbox.add_child(chat_input)

	# --- ПРАВАЯ ПАНЕЛЬ (Кнопки) ---
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(250, 0)
	right_vbox.add_theme_constant_override("separation", 20)
	main_hbox.add_child(right_vbox)

	if not NetworkManager.is_host:
		btn_ready = Button.new()
		btn_ready.text = "Я ГОТОВ"
		btn_ready.custom_minimum_size = Vector2(0, 60)
		btn_ready.toggle_mode = true
		btn_ready.toggled.connect(func(val): NetworkManager.toggle_ready(val))
		right_vbox.add_child(btn_ready)

	btn_start = Button.new()
	btn_start.text = "НАЧАТЬ ИГРУ"
	btn_start.custom_minimum_size = Vector2(0, 60)
	btn_start.visible = NetworkManager.is_host # Скрываем для клиента
	btn_start.disabled = not NetworkManager.is_host
	btn_start.pressed.connect(func(): NetworkManager.start_game())
	right_vbox.add_child(btn_start)

	var btn_leave = Button.new()
	btn_leave.text = "ВЫЙТИ В МЕНЮ"
	btn_leave.custom_minimum_size = Vector2(0, 60)
	btn_leave.pressed.connect(func(): 
		if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	right_vbox.add_child(btn_leave)

func _update_player_list() -> void:
	for c in list_vbox.get_children(): c.queue_free()
	for id in NetworkManager.players:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = NetworkManager.players[id]["name"] + (" (Хост)" if id == 1 else "")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)
		
		var stat = Label.new()
		stat.text = "ГОТОВ" if NetworkManager.players[id].get("ready", false) else "ОЖИДАНИЕ"
		stat.add_theme_color_override("font_color", Color(0, 1, 0) if stat.text == "ГОТОВ" else Color(1, 0, 0))
		hbox.add_child(stat)
		
		list_vbox.add_child(hbox)

func _update_map_ui(map_id: String) -> void:
	for key in map_buttons:
		if key == map_id:
			map_buttons[key].modulate = Color(0, 1, 1, 1)
			map_buttons[key].get_theme_stylebox("normal").bg_color = Color(0, 0.4, 0.6, 0.8)
		else:
			map_buttons[key].modulate = Color(0.5, 0.5, 0.5, 1)
			map_buttons[key].get_theme_stylebox("normal").bg_color = Color(0.05, 0.05, 0.1, 0.8)

func _on_chat_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "": return
	var my_name = "Я"
	if NetworkManager.players.has(multiplayer.get_unique_id()):
		my_name = NetworkManager.players[multiplayer.get_unique_id()]["name"]
	
	var msg = my_name + ": " + new_text
	# Вызываем RPC на всех подключенных клиентах
	_receive_message.rpc(msg)
	
	chat_input.text = ""
	chat_input.release_focus()

@rpc("any_peer", "call_local", "reliable")
func _receive_message(text: String) -> void:
	if chat_log:
		chat_log.append_text(text + "\n")

func _exit_tree() -> void:
	if NetworkManager.player_list_changed.is_connected(_update_player_list):
		NetworkManager.player_list_changed.disconnect(_update_player_list)
	if NetworkManager.map_changed.is_connected(_update_map_ui):
		NetworkManager.map_changed.disconnect(_update_map_ui)
