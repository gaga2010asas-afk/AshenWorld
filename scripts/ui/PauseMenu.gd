extends CanvasLayer

var vbox: VBoxContainer
var settings_panel: Panel
var tc: TabContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	# ОЧИЩАЕМ СТАРЫЕ ЭЛЕМЕНТЫ ИЗ СЦЕНЫ (чтобы не было дубликатов)
	for child in get_children():
		child.queue_free()
	
	# Затемнение
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Главные кнопки
	vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-150, -150)
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	var title = Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	vbox.add_child(title)
	
	var btn_resume = Button.new()
	btn_resume.text = "ПРОДОЛЖИТЬ"
	btn_resume.custom_minimum_size = Vector2(0, 50)
	btn_resume.pressed.connect(func(): 
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		queue_free()
	)
	vbox.add_child(btn_resume)
	
	var btn_settings = Button.new()
	btn_settings.text = "НАСТРОЙКИ"
	btn_settings.custom_minimum_size = Vector2(0, 50)
	btn_settings.pressed.connect(func():
		vbox.visible = false
		settings_panel.visible = true
		_populate_settings()
	)
	vbox.add_child(btn_settings)
	
	var btn_menu = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ"
	btn_menu.custom_minimum_size = Vector2(0, 50)
	btn_menu.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	vbox.add_child(btn_menu)
	
	var btn_quit = Button.new()
	btn_quit.text = "ВЫХОД"
	btn_quit.custom_minimum_size = Vector2(0, 50)
	btn_quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_quit)
	
	# Панель настроек
	settings_panel = Panel.new()
	settings_panel.visible = false
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.custom_minimum_size = Vector2(700, 500)
	settings_panel.size = Vector2(700, 500)
	settings_panel.position = Vector2(-350, -250)
	add_child(settings_panel)
	
	var settings_vbox = VBoxContainer.new()
	settings_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_vbox.offset_left = 20
	settings_vbox.offset_top = 20
	settings_vbox.offset_right = -20
	settings_vbox.offset_bottom = -20
	settings_panel.add_child(settings_vbox)
	
	var st_title = Label.new()
	st_title.text = "СИСТЕМНЫЕ НАСТРОЙКИ"
	st_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st_title.add_theme_font_size_override("font_size", 32)
	settings_vbox.add_child(st_title)
	
	tc = TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_vbox.add_child(tc)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	settings_vbox.add_child(hbox)
	
	var btn_close = Button.new()
	btn_close.text = "НАЗАД"
	btn_close.custom_minimum_size = Vector2(150, 45)
	btn_close.pressed.connect(func():
		GameManager.save_settings()
		GameManager.apply_settings()
		settings_panel.visible = false
		vbox.visible = true
	)
	hbox.add_child(btn_close)

func _populate_settings() -> void:
	if tc.get_child_count() > 0: return
	
	# ИГРА
	var game_tab = VBoxContainer.new(); tc.add_child(game_tab); tc.set_tab_title(0, "Игра")
	var lbl_diff = Label.new(); lbl_diff.text = "Сложность:"; game_tab.add_child(lbl_diff)
	var opt_diff = OptionButton.new(); opt_diff.add_item("Легкая"); opt_diff.add_item("Средняя"); opt_diff.add_item("Сложная")
	opt_diff.selected = GameManager.difficulty
	opt_diff.item_selected.connect(func(idx): GameManager.difficulty = idx)
	game_tab.add_child(opt_diff)
	
	# ГРАФИКА
	var graph_tab = VBoxContainer.new(); tc.add_child(graph_tab); tc.set_tab_title(1, "Графика")
	var chk_vsync = CheckBox.new(); chk_vsync.text = "Вертикальная синхронизация"
	chk_vsync.button_pressed = GameManager.vsync == 1
	chk_vsync.toggled.connect(func(val): GameManager.vsync = 1 if val else 0; GameManager.apply_settings())
	graph_tab.add_child(chk_vsync)
	
	# ЗВУК
	var sound_tab = VBoxContainer.new(); tc.add_child(sound_tab); tc.set_tab_title(2, "Звук")
	var slider_vol = HSlider.new(); slider_vol.value = GameManager.volume_master * 100
	slider_vol.value_changed.connect(func(v): GameManager.volume_master = v / 100.0; GameManager.apply_settings())
	sound_tab.add_child(slider_vol)
	
	# УПРАВЛЕНИЕ
	var ctrl_tab = VBoxContainer.new(); tc.add_child(ctrl_tab); tc.set_tab_title(3, "Управление")
	var lbl_ctrl = Label.new(); lbl_ctrl.text = "WASD - Движение
Q - Экзокостюм
F - Фонарик
G - Граната
R - Перезарядка"
	ctrl_tab.add_child(lbl_ctrl)
	
	# ИНТЕРФЕЙС
	var hud_tab = VBoxContainer.new(); tc.add_child(hud_tab); tc.set_tab_title(4, "Интерфейс")
	var chk_fps = CheckBox.new(); chk_fps.text = "Показывать FPS"
	chk_fps.button_pressed = GameManager.show_fps
	chk_fps.toggled.connect(func(val): GameManager.show_fps = val)
	hud_tab.add_child(chk_fps)
