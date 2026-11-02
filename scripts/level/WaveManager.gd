extends Node

signal wave_started(wave_num: int, enemies_count: int)
signal wave_cleared(wave_num: int)
signal all_waves_cleared()

var current_wave: int = 0
var max_waves: int = 3
var wave_enemies_alive: int = 0
var is_wave_active: bool = false
var mission_id: String = "sklad"
var is_boss_alive: bool = false
var spawning_active: bool = true

var enemy_scene = preload("res://scenes/enemies/Enemy_Rifle.tscn")
var kamikaze_scene = preload("res://scenes/enemies/Enemy_Kamikaze.tscn")
var drone_scene = preload("res://scenes/enemies/Enemy_Drone.tscn")

var boss_mech_scene = preload("res://scenes/bosses/BossMech.tscn")
var boss_drone_scene = preload("res://scenes/bosses/BossDrone.tscn")
var boss_chief_scene = preload("res://scenes/bosses/BossChief.tscn")

var bot_timer: Timer
var watchdog_timer: float = 0.0

func _ready() -> void:
	add_to_group("wave_manager")
	
	# Таймер фоновых болванчиков (каждые 5 сек)
	bot_timer = Timer.new()
	bot_timer.wait_time = 5.0
	bot_timer.autostart = true
	bot_timer.timeout.connect(_on_bot_spawn)
	add_child(bot_timer)

func _process(delta: float) -> void:
	if is_wave_active and not is_boss_alive:
		watchdog_timer += delta
		if watchdog_timer > 15.0:
			watchdog_timer = 0.0
			var active_wave_enemies = 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.has_meta("is_wave") and e.get_meta("is_wave") == true:
					active_wave_enemies += 1
			if active_wave_enemies == 0 and wave_enemies_alive > 0:
				print("WATCHDOG: Волновые враги исчезли. Завершаем волну.")
				wave_enemies_alive = 1
				_on_wave_cleared()

# --- ФОНОВЫЙ СПАВН БОЛВАНЧИКОВ ---
func _on_bot_spawn() -> void:
	if not spawning_active: return
	var markers = get_tree().get_nodes_in_group("spawn_points")
	if markers.is_empty(): return
	
	var enemy = enemy_scene.instantiate()
	enemy.weapon_type = "pistol" # Фоновые всегда с пистолетом
	enemy.set_meta("is_wave", false) # Не считаются в волну
	
	var marker = markers.pick_random()
	enemy.position = marker.position + Vector3(randf_range(-5, 5), 0.5, randf_range(-5, 5))
	get_parent().add_child(enemy)

# --- СПАВН ВОЛН ---
func _get_wave_enemy() -> Node:
	var node = null
	if mission_id == "prigorod":
		node = kamikaze_scene.instantiate()
	elif mission_id == "zavod":
		node = drone_scene.instantiate()
	elif mission_id == "lair":
		# На Логове смесь дронов и камикадзе
		if randf() < 0.5: node = kamikaze_scene.instantiate()
		else: node = drone_scene.instantiate()
	else:
		# На Складе волновые болванчики со случайным оружием
		node = enemy_scene.instantiate()
		var weapons = ["rifle", "shotgun", "sniper", "minigun", "rocket", "flamer", "grenade"]
		node.weapon_type = weapons.pick_random()
		
	node.set_meta("is_wave", true)
	return node

func start_next_wave() -> void:
	if current_wave >= max_waves:
		all_waves_cleared.emit()
		return
		
	current_wave += 1
	is_wave_active = true
	watchdog_timer = 0.0
	
	# На 3-й волне спавним Босса
	if current_wave == max_waves:
		if mission_id == "prigorod":
			_start_boss(boss_mech_scene)
			return
		elif mission_id == "zavod":
			_start_boss(boss_drone_scene)
			return
		elif mission_id == "lair":
			_start_boss(boss_chief_scene)
			return
		elif mission_id == "sklad":
			pass # На Складе просто 3-я волна болванчиков
			
	# ОПРЕДЕЛЯЕМ КОЛИЧЕСТВО ВРАГОВ В ЗАВИСИМОСТИ ОТ СЛОЖНОСТИ
	var wave_count = 8
	if GameManager.difficulty == 0:
		wave_count = 5 # Легкая (5 врагов)
	elif GameManager.difficulty == 1:
		wave_count = 8 # Средняя (8 врагов)
	elif GameManager.difficulty == 2:
		wave_count = 12 # Сложная (12 врагов)
		
	wave_enemies_alive = wave_count
	wave_started.emit(current_wave, wave_count)
	
	var markers = get_tree().get_nodes_in_group("spawn_points")
	if markers.is_empty(): 
		print("ERROR: Нет точек спавна (spawn_points)!")
		return
		
	for i in range(wave_count):
		var marker = markers[i % markers.size()]
		var enemy_node = _get_wave_enemy()
		
		var spawn_y = 3.0 if mission_id == "zavod" else 0.5
		var spawn_offset = Vector3(randf_range(-3.0, 3.0), spawn_y, randf_range(-3.0, 3.0))
		
		enemy_node.position = marker.position + spawn_offset
		get_parent().add_child(enemy_node)

func _start_boss(boss_scene: PackedScene) -> void:
	is_boss_alive = true
	wave_started.emit(current_wave, 1)
	var boss = boss_scene.instantiate()
	boss.position = Vector3(0, 1, -15)
	boss.set_meta("is_wave", true)
	get_parent().add_child(boss)
	wave_enemies_alive = 1

func boss_defeated() -> void:
	is_boss_alive = false
	spawning_active = false
	if bot_timer: bot_timer.stop()
	all_waves_cleared.emit()

func on_enemy_died(node: Node) -> void:
	if not is_instance_valid(node): return
	
	if node.get_meta("is_wave", false):
		wave_enemies_alive -= 1
		if wave_enemies_alive <= 0:
			if is_boss_alive:
				boss_defeated()
			else:
				_on_wave_cleared()

func _on_wave_cleared() -> void:
	is_wave_active = false
	var bonus = 400 if current_wave == 1 else (600 if current_wave == 2 else 900)
	GameManager.add_money(bonus)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var wh = player.get_node_or_null("Head/Camera3D/WeaponHolder")
		if wh: wh.add_ammo_to_all(60)
	
	wave_cleared.emit(current_wave)
	
	if current_wave < max_waves:
		await get_tree().create_timer(5.0).timeout
		start_next_wave()
	else:
		if mission_id == "sklad":
			spawning_active = false
			if bot_timer: bot_timer.stop()
			all_waves_cleared.emit()
