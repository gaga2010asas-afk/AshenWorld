extends CanvasLayer

var hp_bar: ProgressBar
var energy_bar: ProgressBar
var armor_bar: ProgressBar
var ammo_label: Label
var reserve_label: Label
var weapon_label: Label
var suit_label: Label
var money_label: Label
var wave_label: Label
var crosshair: Control
var heat_bar: ProgressBar
var hitmarker: Control
var weapon_popup: Label
var grenade_label: Label
var vignette_top: ColorRect
var vignette_bottom: ColorRect

# Оставляем заглушки для методов, которые вызывает Player.gd и WeaponHolder.gd
var tactical_map: Control = null
var damage_flash: ColorRect = null
var suit_flash: ColorRect = null
var hit_indicator: Control = null
var boot_screen: Control = null

var flash_tween: Tween
var fps_label: Label
var in_game_chat: LineEdit
var chat_display: RichTextLabel
var scoreboard: Panel
var kills_label: Label
var death_screen: Control
var loading_screen: Control
var loading_bar: ProgressBar
var tip_label: Label

func _ready() -> void:
	add_to_group("hud")
	
	# Очищаем старый сломанный UI (если он был)
	for child in get_children():
		child.queue_free()
		
	# 1. СОЗДАЕМ ПРИЦЕЛ (Всегда с нуля, чтобы не было вылетов)
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	# Подключаем скрипт прицела (крестик)
	var crosshair_script = load("res://scripts/ui/Crosshair.gd")
	if crosshair_script:
		crosshair.set_script(crosshair_script)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# 2. ЛЕВЫЙ НИЖНИЙ УГОЛ: Экзокостюм, HP, Броня (Стиль Crysis)
	var left_ui = VBoxContainer.new()
	left_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left_ui.position = Vector2(40, -150)
	left_ui.add_theme_constant_override("separation", 10)
	add_child(left_ui)
	
	suit_label = Label.new()
	suit_label.text = "СИСТЕМА: БРОНЯ"
	suit_label.add_theme_font_size_override("font_size", 22)
	suit_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0)) # Crysis Cyan
	suit_label.add_theme_constant_override("outline_size", 4)
	suit_label.add_theme_color_override("font_outline_color", Color.BLACK)
	left_ui.add_child(suit_label)
	
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(300, 15)
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	_style_bar(hp_bar, Color(0.8, 0.1, 0.1)) # Красный HP
	left_ui.add_child(hp_bar)
	
	armor_bar = ProgressBar.new()
	armor_bar.custom_minimum_size = Vector2(300, 15)
	armor_bar.max_value = 100
	armor_bar.value = 50
	armor_bar.show_percentage = false
	_style_bar(armor_bar, Color(0.0, 0.6, 1.0)) # Голубая броня
	left_ui.add_child(armor_bar)
	
	# Полоска энергии (белая)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(300, 8)
	energy_bar.max_value = 100
	energy_bar.value = 100
	energy_bar.show_percentage = false
	_style_bar(energy_bar, Color(1.0, 1.0, 1.0))
	left_ui.add_child(energy_bar)

	# 3. ПРАВЫЙ НИЖНИЙ УГОЛ: Патроны (Стиль Crysis)
	var right_ui = VBoxContainer.new()
	right_ui.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right_ui.position = Vector2(-250, -120)
	right_ui.alignment = BoxContainer.ALIGNMENT_END
	add_child(right_ui)
	
	weapon_label = Label.new()
	weapon_label.text = "ПИСТОЛЕТ"
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_font_size_override("font_size", 24)
	weapon_label.add_theme_color_override("font_color", Color.WHITE)
	right_ui.add_child(weapon_label)
	
	ammo_label = Label.new()
	ammo_label.text = "12 / 200"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 56)
	ammo_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	ammo_label.add_theme_constant_override("outline_size", 8)
	ammo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	right_ui.add_child(ammo_label)

	# 4. ВЕРХНИЙ ПРАВЫЙ УГОЛ: Деньги
	money_label = Label.new()
	money_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	money_label.position = Vector2(-150, 30)
	money_label.text = "$1500"
	money_label.add_theme_font_size_override("font_size", 28)
	money_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	money_label.add_theme_constant_override("outline_size", 4)
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(money_label)

	# 5. ВЕРХНИЙ ЦЕНТР: Волна / Статус
	wave_label = Label.new()
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_label.position = Vector2(-200, 30)
	wave_label.custom_minimum_size = Vector2(400, 0)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.text = "БАЗА (ХАБ)"
	wave_label.add_theme_font_size_override("font_size", 32)
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	wave_label.add_theme_constant_override("outline_size", 6)
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(wave_label)

	# ВНУТРИИГРОВОЙ ЧАТ
	chat_display = RichTextLabel.new()
	chat_display.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chat_display.position = Vector2(20, -300)
	chat_display.custom_minimum_size = Vector2(400, 200)
	chat_display.bbcode_enabled = true
	chat_display.scroll_following = true
	chat_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chat_display)
	
	in_game_chat = LineEdit.new()
	in_game_chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	in_game_chat.position = Vector2(20, -100)
	in_game_chat.custom_minimum_size = Vector2(400, 30)
	in_game_chat.visible = false
	in_game_chat.text_submitted.connect(_on_chat_entered)
	add_child(in_game_chat)

	# ТАБЛИЦА ЛИДЕРОВ
	scoreboard = Panel.new()
	scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scoreboard.custom_minimum_size = Vector2(600, 400)
	scoreboard.position = Vector2(-300, -200)
	scoreboard.visible = false
	add_child(scoreboard)
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.8)
	sb_bg.border_color = Color(0, 1, 1)
	sb_bg.set_border_width_all(2)
	scoreboard.add_theme_stylebox_override("panel", sb_bg)
	
	kills_label = Label.new()
	kills_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kills_label.add_theme_font_size_override("font_size", 24)
	kills_label.text = "ТАБЛИЦА ЛИДЕРОВ (В РАЗРАБОТКЕ)"
	scoreboard.add_child(kills_label)

	# СЧЕТЧИК FPS
	fps_label = Label.new()
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-150, 60)
	fps_label.add_theme_color_override("font_color", Color(0, 1, 0))
	fps_label.visible = false
	add_child(fps_label)

	# Создаем защитные узлы для методов
	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color(1, 0, 0, 0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)

	# 6. ПЕРЕГРЕВ (Справа от прицела)
	heat_bar = ProgressBar.new()
	heat_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	heat_bar.position = Vector2(40, -30)
	heat_bar.custom_minimum_size = Vector2(10, 60)
	heat_bar.max_value = 100
	heat_bar.show_percentage = false
	heat_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_style_bar(heat_bar, Color(1.0, 0.5, 0.0)) # Оранжевый
	heat_bar.visible = false
	add_child(heat_bar)

	# 7. ХИТМАРКЕР
	hitmarker = Control.new()
	hitmarker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hitmarker)

	# 8. ВСПЛЫВАЮЩИЙ ТЕКСТ СМЕНЫ ОРУЖИЯ
	weapon_popup = Label.new()
	weapon_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	weapon_popup.position = Vector2(-150, 80)
	weapon_popup.custom_minimum_size = Vector2(300, 0)
	weapon_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_popup.add_theme_font_size_override("font_size", 28)
	weapon_popup.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	weapon_popup.add_theme_constant_override("outline_size", 4)
	weapon_popup.add_theme_color_override("font_outline_color", Color.BLACK)
	weapon_popup.modulate.a = 0.0
	add_child(weapon_popup)

	# 9. ИНДИКАТОР ГРАНАТ
	grenade_label = Label.new()
	grenade_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grenade_label.position = Vector2(-150, -180)
	grenade_label.text = "[G] 3"
	grenade_label.add_theme_font_size_override("font_size", 20)
	grenade_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	add_child(grenade_label)

	# 10. ВИНЬЕТКА УРОНА (Рамка)
	vignette_top = ColorRect.new()
	vignette_top.color = Color(1, 0, 0, 0)
	vignette_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	vignette_top.custom_minimum_size = Vector2(0, 50)
	vignette_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette_top)
	
	vignette_bottom = ColorRect.new()
	vignette_bottom.color = Color(1, 0, 0, 0)
	vignette_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	vignette_bottom.custom_minimum_size = Vector2(0, 50)
	vignette_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette_bottom)

	# Подключаем сигналы от WeaponHolder
	var wh = get_parent().get_node_or_null("Head/Camera3D/WeaponHolder")
	if wh:
		wh.heat_changed.connect(update_heat)
		wh.weapon_switched.connect(show_weapon_popup)
		wh.hit_confirmed.connect(func(): show_hitmarker(false))

	# --- DEATH SCREEN (ЭКРАН СМЕРТИ) ---
	death_screen = Control.new()
	death_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_screen.visible = false
	death_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(death_screen)
	
	var dark_bg = ColorRect.new()
	dark_bg.color = Color(0.1, 0, 0, 0.85)
	dark_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_screen.add_child(dark_bg)
	
	var death_lbl = Label.new()
	death_lbl.text = "ВЫ ПОГИБЛИ"
	death_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_lbl.position = Vector2(-200, -100)
	death_lbl.custom_minimum_size = Vector2(400, 0)
	death_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_lbl.add_theme_font_size_override("font_size", 72)
	death_lbl.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	death_lbl.add_theme_constant_override("outline_size", 10)
	death_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	death_screen.add_child(death_lbl)
	
	var respawn_btn = Button.new()
	respawn_btn.text = "ВОЗРОДИТЬСЯ"
	respawn_btn.custom_minimum_size = Vector2(250, 60)
	respawn_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	respawn_btn.position = Vector2(-125, 50)
	respawn_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub.tscn"))
	death_screen.add_child(respawn_btn)

	# --- LOADING SCREEN (ЭКРАН ЗАГРУЗКИ) ---
	loading_screen = Control.new()
	loading_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_screen.visible = false
	loading_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(loading_screen)
	
	var load_bg = ColorRect.new()
	load_bg.color = Color(0, 0, 0, 1)
	load_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_screen.add_child(load_bg)
	
	var load_lbl = Label.new()
	load_lbl.text = "EXO-SUIT ONLINE"
	load_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	load_lbl.position = Vector2(-200, -50)
	load_lbl.custom_minimum_size = Vector2(400, 0)
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.add_theme_font_size_override("font_size", 32)
	load_lbl.add_theme_color_override("font_color", Color(0, 1, 1))
	loading_screen.add_child(load_lbl)
	
	loading_bar = ProgressBar.new()
	loading_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_bar.position = Vector2(-200, 10)
	loading_bar.custom_minimum_size = Vector2(400, 20)
	loading_bar.max_value = 100
	loading_bar.show_percentage = false
	_style_bar(loading_bar, Color(0, 1, 1))
	loading_screen.add_child(loading_bar)
	
	tip_label = Label.new()
	tip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tip_label.position = Vector2(-300, -100)
	tip_label.custom_minimum_size = Vector2(600, 0)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 18)
	tip_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	loading_screen.add_child(tip_label)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("background", sb_bg)
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = color
	bar.add_theme_stylebox_override("fill", sb_fill)

# --- МЕТОДЫ ОБНОВЛЕНИЯ (Вызываются из Player.gd и WeaponHolder.gd) ---

func update_health(current: float, max_val: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = current

func update_armor(current: float, max_val: float) -> void:
	if armor_bar:
		armor_bar.max_value = max_val
		armor_bar.value = current

func update_energy(current: float, max_val: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_val
		energy_bar.value = current
		# Если энергия < 20%, она краснеет
		if current < 20:
			_style_bar(energy_bar, Color(1.0, 0.2, 0.2))
		else:
			_style_bar(energy_bar, Color(1.0, 1.0, 1.0))

func update_ammo(mag: int, res: int, w_name: String) -> void:
	var ru_name = w_name
	match w_name:
		"pistol": ru_name = "ПИСТОЛЕТ"
		"rifle": ru_name = "АВТОМАТ"
		"shotgun": ru_name = "ДРОБОВИК"
		"sniper": ru_name = "СНАЙПЕРКА"
		"minigun": ru_name = "МИНИГАН"
		"rocket": ru_name = "РПГ"
		"flamer": ru_name = "ОГНЕМЕТ"
		
	if weapon_label: weapon_label.text = ru_name
	if ammo_label: 
		ammo_label.text = str(mag) + " / " + str(res)
		if mag <= 5:
			ammo_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2)) # Красный если мало
		else:
			ammo_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0)) # Синий Crysis

func update_weapon_ui(current_w_name: String) -> void:
	pass # Слоты оружия мы убрали для чистоты



func update_money(amount: int) -> void:
	if money_label: money_label.text = "$" + str(amount)

func update_wave_info(wave_num: int, enemies: int) -> void:
	if wave_label:
		wave_label.text = "ВОЛНА " + str(wave_num) + " / Врагов: " + str(enemies)

func on_wave_cleared(wave_num: int) -> void:
	if wave_label:
		wave_label.text = "ВОЛНА " + str(wave_num) + " ЗАЧИЩЕНА!"



func on_fire() -> void:
	pass

func update_suit_mode(mode: int) -> void:
	if not suit_label: return
	match mode:
		0: 
			suit_label.text = "КОСТЮМ: БРОНЯ"
			suit_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
		1: 
			suit_label.text = "КОСТЮМ: СКОРОСТЬ"
			suit_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
		2: 
			suit_label.text = "КОСТЮМ: СИЛА"
			suit_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_: suit_label.text = "ЭНЕРГИЯ ИСЧЕРПАНА"

func show_suit_message(mode_text: String, color: Color) -> void:
	if suit_label:
		suit_label.text = mode_text
		suit_label.add_theme_color_override("font_color", color)

func show_attachment(mode: int) -> void: pass
func show_ammo_type(type: int) -> void: pass
func toggle_scoreboard() -> void:
	if scoreboard:
		scoreboard.visible = not scoreboard.visible
		if scoreboard.visible:
			kills_label.text = "ТАБЛИЦА ЛИДЕРОВ\n\nУБИЙСТВА: " + str(GameManager.kills) + "\nСМЕРТИ: " + str(GameManager.deaths)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
func show_hit_indicator(angle: float) -> void: pass
func add_killfeed(enemy_name: String) -> void: pass
func show_boss_bar(n: String, max_hp: float) -> void: pass
func update_boss_bar(hp: float) -> void: pass
func hide_boss_bar() -> void: pass


func update_heat(current: float, max_val: float, is_overheated: bool) -> void:
	if not heat_bar: return
	var wh = get_parent().get_node_or_null("Head/Camera3D/WeaponHolder")
	if wh and wh.current_weapon in ["minigun", "flamer"]:
		heat_bar.visible = true
		heat_bar.max_value = max_val
		heat_bar.value = current
		if is_overheated:
			_style_bar(heat_bar, Color(1.0, 0.0, 0.0)) # Красный при перегреве
		else:
			_style_bar(heat_bar, Color(1.0, 0.5, 0.0))
	else:
		heat_bar.visible = false

func show_hitmarker(is_kill: bool) -> void:
	if not hitmarker: return
	hitmarker.draw.connect(func():
		var c = hitmarker.size / 2
		var col = Color(1, 0, 0, 1) if is_kill else Color(1, 1, 1, 1)
		hitmarker.draw_line(c + Vector2(-10, -10), c + Vector2(-5, -5), col, 2.0)
		hitmarker.draw_line(c + Vector2(10, -10), c + Vector2(5, -5), col, 2.0)
		hitmarker.draw_line(c + Vector2(-10, 10), c + Vector2(-5, 5), col, 2.0)
		hitmarker.draw_line(c + Vector2(10, 10), c + Vector2(5, 5), col, 2.0)
	)
	hitmarker.queue_redraw()
	await get_tree().create_timer(0.1).timeout
	hitmarker.draw.disconnect(hitmarker.draw.get_connections()[0]["callable"])
	hitmarker.queue_redraw()

func show_weapon_popup(w_name: String) -> void:
	if not weapon_popup: return
	var ru_name = w_name
	match w_name:
		"pistol": ru_name = "ПИСТОЛЕТ"
		"rifle": ru_name = "АВТОМАТ"
		"shotgun": ru_name = "ДРОБОВИК"
		"sniper": ru_name = "СНАЙПЕРКА"
		"minigun": ru_name = "МИНИГАН"
		"rocket": ru_name = "РПГ"
		"flamer": ru_name = "ОГНЕМЕТ"
	weapon_popup.text = ru_name
	weapon_popup.modulate.a = 1.0
	var t = create_tween()
	t.tween_interval(1.0)
	t.tween_property(weapon_popup, "modulate:a", 0.0, 0.5)

func update_grenades(count: int) -> void:
	if grenade_label:
		grenade_label.text = "[G] " + str(count)
		if count <= 0:
			grenade_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			grenade_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))

func flash_damage() -> void:
	if not damage_flash or not vignette_top or not vignette_bottom: return
	damage_flash.color.a = 0.2
	vignette_top.color.a = 0.6
	vignette_bottom.color.a = 0.6
	if flash_tween and flash_tween.is_valid(): flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.3)
	flash_tween.tween_property(vignette_top, "color:a", 0.0, 0.3)
	flash_tween.tween_property(vignette_bottom, "color:a", 0.0, 0.3)


func _process(_delta: float) -> void:
	if fps_label:
		fps_label.visible = GameManager.show_fps
		if GameManager.show_fps:
			fps_label.text = "FPS: " + str(Engine.get_frames_per_second())


func _on_chat_submitted(text: String):
	pass


func _on_chat_entered(new_text: String) -> void:
	if new_text.strip_edges() == "":
		in_game_chat.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	var my_name = "Игрок_" + str(multiplayer.get_unique_id())
	_receive_msg.rpc(my_name + ": " + new_text)
	in_game_chat.text = ""
	in_game_chat.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

@rpc("any_peer", "reliable")
func _receive_msg(txt: String) -> void:
	if chat_display:
		chat_display.append_text(txt + "\n")


func show_death_screen() -> void:
	if death_screen:
		death_screen.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func show_loading_screen() -> void:
	if loading_screen:
		loading_screen.visible = true
		loading_bar.value = 0
		var tips = [
			"Совет: Если у вас кончились патроны, стреляйте гранатами. Бюджет ушел на них.",
			"Совет: Напарник не бессмертен. В отличие от вас.",
			"Совет: Стреляйте в голову. Это не только эффективно, но и приятно.",
			"Совет: Нажмите F, чтобы включить фонарик. Там темно.",
			"Совет: Начальник не так прост, как кажется."
		]
		tip_label.text = tips.pick_random()
		
		# Анимация загрузки
		var t = create_tween()
		t.tween_property(loading_bar, "value", 100.0, 2.0)
		await t.finished
		await get_tree().create_timer(0.5).timeout
		loading_screen.visible = false
