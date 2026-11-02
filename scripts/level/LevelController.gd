extends Node3D

@export var mission_id: String = "sklad"
@export var level_index: int = 0
@onready var wave_manager: Node = $WaveManager
var dialogue_ui: CanvasLayer
var player: Node3D
var companion: Node3D

func _ready() -> void:
	MusicManager.play_track(mission_id)
	# 1. СОЗДАЕМ ЧЕРНЫЙ ЭКРАН ЗАГРУЗКИ
	var canvas = CanvasLayer.new()
	canvas.layer = 99
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	var lbl = Label.new()
	lbl.text = "EXO-SUIT ONLINE"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0, 1, 1))
	canvas.add_child(lbl)
	add_child(canvas)

	# 2. СТРОИМ МИР (пока экран черный)
	wave_manager.mission_id = mission_id
	var nav_region = preload("res://scripts/level/LevelBuilder.gd").build_level(self, mission_id)
	
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh(false)
	
	for child in get_children():
		if child is Marker3D and child.name.begins_with("Spawn_"):
			child.add_to_group("spawn_points")
			
	player = get_tree().get_first_node_in_group("player")
	if player and player.hud:
		wave_manager.wave_started.connect(player.hud.update_wave_info)
		wave_manager.wave_cleared.connect(player.hud.on_wave_cleared)
		wave_manager.wave_cleared.connect(_on_wave_cleared_story)
		GameManager.money_changed.connect(player.hud.update_money)
		player.hud.update_money(GameManager.money)
		
	wave_manager.all_waves_cleared.connect(_on_win)
	
	# 3. УБИРАЕМ ЭКРАН ЗАГРУЗКИ (плавное исчезновение)
	await get_tree().create_timer(1.5).timeout
	var t = create_tween()
	t.tween_property(bg, "color:a", 0.0, 1.0)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0)
	await t.finished
	canvas.queue_free()
	
	# 4. ПОКАЗЫВАЕМ ДИАЛОГ (только после загрузки)
	if level_index == 0:
		companion = preload("res://scenes/actors/Companion.tscn").instantiate()
		companion.position = player.position + Vector3(2, 0, 0)
		add_child(companion)
		_show_dialogue([
			"Напарник: О, живой. Я уж думал, начальник опять кого-то из кубов прислал.",
			"Напарник: Шучу. Ты же игрок. У тебя сюжетная броня. У меня — нет. Но это неважно.",
			"Напарник: Смотри: WASD — ходить. Мышь — смотреть. ЛКМ — стрелять. R — перезарядка. G — граната.",
			"Напарник: Патроны не бесконечны. Кроме пистолета. Пистолет — вечен, как сюжетная дыра.",
			"Напарник: Впереди волна болванчиков. Они тупые. Ты — умнее. Надеюсь."
		])
	elif level_index == 1:
		_show_dialogue([
			"Начальник: Склад зачищен. Напарник? А, да. Жаль. Он был... функциональным.",
			"Начальник: Пригород. Там гнездо болванчиков. И один... крупный. Мех-погрузчик. Ржавый, тупой, но бьёт больно.",
			"Начальник: Сюжет прямолинейный: иди туда, стреляй. Но хотя бы честно — я тебя не обманываю."
		])
	elif level_index == 2:
		_show_dialogue([
			"Начальник: Пригород зачищен. Мех-погрузчик? Хорошо. Он был... ржавым.",
			"Начальник: Завод. Вертикальный геймплей. Не смотри вниз — там текстуры кончились.",
			"Начальник: На заводе — дрон-турель. Летает, стреляет очередями. Слабое место — роторы. Да, я знаю, что это очевидно."
		])
	elif level_index == 3:
		_show_dialogue([
			"Начальник: Завод зачищен. Дрон-турель? Хорошо.",
			"Начальник: Слушай. Я должен тебе кое-что сказать. Помнишь, я говорил, что корпорация виновата в катастрофе? Так вот. Корпорация — это я.",
			"Начальник: Я и есть причина. Я запустил протокол. Я зачищал свидетелей. Ты — последний.",
			"Начальник: И да, это сюжетный твист на 5 минут. Но признай: лучше, чем ничего.",
			"Начальник: Логово — внизу. Я буду ждать. Возьми всё, что есть в магазине. Это последний бой."
		])
	
	# 5. ЗАПУСКАЕМ ВОЛНУ
	await get_tree().create_timer(1.0).timeout
	wave_manager.start_next_wave()

func _on_wave_cleared_story(wave_num: int) -> void:
	if level_index == 0 and wave_num == 2 and is_instance_valid(companion):
		var press = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(2, 0.5, 2)
		press.mesh = box
		press.position = companion.position + Vector3(0, 2.0, 0)
		add_child(press)
		
		var t = create_tween()
		t.tween_property(press, "position:y", 0.5, 0.5)
		
		companion.die()
		_show_dialogue([
			"Напарник: Ага. Вот и мой сюжетный момент. Не переживай — я NPC. У меня не было сюжетной брони. Буквально.",
			"Напарник: Иди дальше. И... не забудь про магазин. Броня реально помогает."
		])

func _show_dialogue(lines: Array) -> void:
	if dialogue_ui and is_instance_valid(dialogue_ui): return
	if not player: return
	dialogue_ui = preload("res://scenes/ui/Dialogue.tscn").instantiate()
	add_child(dialogue_ui)
	dialogue_ui.start_dialogue(lines, player)

func _on_win() -> void:
	GameManager.progress = max(GameManager.progress, level_index + 1)
	GameManager.add_money(400)
	GameManager.save_game()
	
	if player and player.hud:
		player.hud.wave_label.text = "МИССИЯ ВЫПОЛНЕНА!\n+$400\nВозврат на базу..."
		player.hud.wave_label.modulate = Color(0.3, 1, 0.3, 1)
	
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file("res://scenes/Hub.tscn")
