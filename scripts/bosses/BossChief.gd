extends CharacterBody3D

var hp: float = 1500.0
var max_hp: float = 1500.0
var is_dead: bool = false
var dialog_50: bool = false
var dialog_25: bool = false
var dialog_10: bool = false
var speed: float = 4.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: Node3D = null
var attack_timer: float = 1.0
var time_since_attack: float = 0.0

var weapons = ["rifle", "shotgun", "sniper", "rocket", "flamer"]
var current_weapon: String = "rifle"
var weapon_switch_timer: float = 0.0

var bullet_scene = preload("res://scenes/weapons/PhysicalBullet.tscn")
var grenade_scene = preload("res://scenes/weapons/Grenade.tscn")
var rocket_scene = preload("res://scenes/weapons/Rocket.tscn")
var fire_scene = preload("res://scenes/weapons/FireVisual.tscn")
var body: Node3D

@onready var nav_agent: NavigationAgent3D = $NavAgent

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 10.0
	_build_model()
	if player and player.hud:
		player.hud.show_boss_bar("ГЛАВНЫЙ НАЧАЛЬНИК (ВСЕОРУЖИЕ)", max_hp)

func _build_model() -> void:
	body = Node3D.new(); add_child(body)
	
	var mat_metal = StandardMaterial3D.new(); mat_metal.albedo_color = Color(0.2, 0.2, 0.2); mat_metal.metallic = 0.8
	var mat_gold = StandardMaterial3D.new(); mat_gold.albedo_color = Color(0.8, 0.6, 0.1); mat_gold.metallic = 0.9
	var mat_cloak = StandardMaterial3D.new(); mat_cloak.albedo_color = Color(0.4, 0.05, 0.05) # Красный плащ
	var mat_visor = StandardMaterial3D.new(); mat_visor.albedo_color = Color(1, 0, 0); mat_visor.emission_enabled = true; mat_visor.emission = Color(1, 0, 0)
	
	var make_part = func(type: String, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
		var m = MeshInstance3D.new()
		if type == "capsule": var c = CapsuleMesh.new(); c.radius = sz.x; c.height = sz.y; m.mesh = c
		elif type == "sphere": var s = SphereMesh.new(); s.radius = sz.x; m.mesh = s
		elif type == "box": var b = BoxMesh.new(); b.size = sz; m.mesh = b
		elif type == "cyl": var c2 = CylinderMesh.new(); c2.top_radius = sz.x; c2.bottom_radius = sz.x; c2.height = sz.y; m.mesh = c2
		m.position = pos; m.material_override = mat; body.add_child(m); return m

	# Модель (Мощная, с наплечниками, шлемом и плащом)
	make_part.call("capsule", Vector3(0.5, 2.2, 0.5), Vector3(0, 1.1, 0), mat_metal) # Торс
	make_part.call("sphere", Vector3(0.3, 0, 0), Vector3(0, 2.1, 0), mat_metal) # Голова
	make_part.call("box", Vector3(0.5, 0.1, 0.1), Vector3(0, 2.1, -0.25), mat_visor) # Визор
	make_part.call("box", Vector3(0.6, 1.4, 0.1), Vector3(0, 1.0, 0.4), mat_cloak) # Плащ
	make_part.call("box", Vector3(0.4, 0.2, 0.4), Vector3(-0.6, 1.8, 0), mat_gold) # Наплечник Л
	make_part.call("box", Vector3(0.4, 0.2, 0.4), Vector3(0.6, 1.8, 0), mat_gold) # Наплечник П
	make_part.call("cyl", Vector3(0.05, 1.8, 0.05), Vector3(-0.8, 1.0, -0.2), mat_gold) # Посох

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead: return
	hp -= amount
	if player and player.hud: player.hud.update_boss_bar(hp)
	var t = create_tween()
	t.tween_property(body, "scale", Vector3(1.05, 1.05, 1.05), 0.05)
	t.tween_property(body, "scale", Vector3(1, 1, 1), 0.1)
	
	if hp <= 0: 
		die()
		return
	
	# Диалоги между стадиями
	var lc = get_parent()
	if lc and lc.has_method("_show_dialogue"):
		if hp <= 600 and not dialog_50:
			dialog_50 = true
			lc._show_dialogue(["Начальник: Ладно. Хватит. Теперь — серьёзно."])
		elif hp <= 300 and not dialog_25:
			dialog_25 = true
			lc._show_dialogue(["Начальник: Ты понимаешь, что это бессмысленно? Сюжет всё равно закончится."])
		elif hp <= 120 and not dialog_10:
			dialog_10 = true
			lc._show_dialogue(["Начальник: ...ладно. Ты победил. Прямолинейно. Как и всё в этой игре."])

func die() -> void:
	is_dead = true
	if player and player.hud: player.hud.hide_boss_bar()
	get_tree().call_group("wave_manager", "boss_defeated")
	var rag = preload("res://scenes/actors/Ragdoll.tscn").instantiate()
	get_tree().current_scene.add_child(rag); rag.global_position = global_position + Vector3(0, 1, 0)
	if player: rag.apply_central_impulse((global_position - player.global_position).normalized() * 20.0 + Vector3(0, 8, 0))
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead or not player: return
	if not is_on_floor(): velocity.y -= gravity * delta
	var dist = global_position.distance_to(player.global_position)
	
	# УМНЫЙ ВЫБОР ОРУЖИЯ (Дистанции увеличены, чтобы он успевал стрелять)
	if hp > max_hp * 0.66:
		if dist > 12.0: current_weapon = "sniper"
		else: current_weapon = "rifle"
	elif hp > max_hp * 0.33:
		if dist > 12.0: current_weapon = "minigun"
		elif dist > 6.0: current_weapon = "grenade"
		else: current_weapon = "flamer"
	else:
		if dist > 10.0: current_weapon = "rocket"
		elif dist > 5.0: current_weapon = "minigun"
		else: current_weapon = "flamer"
		
	if player and player.hud:
		player.hud.wave_label.text = "НАЧАЛЬНИК: " + current_weapon.to_upper()
	
	# ЛОГИКА ДВИЖЕНИЯ (Держит дистанцию)
	var move_dir = Vector3.ZERO
	if dist > 15.0:
		# Подходит, если слишком далеко
		nav_agent.target_position = player.global_position
		move_dir = (nav_agent.get_next_path_position() - global_position).normalized()
	elif dist < 6.0 and current_weapon in ["sniper", "rocket", "minigun"]:
		# Отходит назад, если игрок слишком близко (чтобы не сбить прицел)
		move_dir = (global_position - player.global_position).normalized()
	
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	
	# Поворот на игрока (всегда, чтобы целиться)
	if dist > 0.1:
		var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		look_at(look_target, Vector3.UP)
		
	time_since_attack += delta
	
	# Кулдаун стрельбы
	var cooldown = 1.2
	if current_weapon == "flamer": cooldown = 0.1
	elif current_weapon == "minigun": cooldown = 0.08
	elif current_weapon == "sniper": cooldown = 2.0
	elif current_weapon == "rocket": cooldown = 2.5
	elif current_weapon == "grenade": cooldown = 2.5
	
	if time_since_attack >= cooldown:
		time_since_attack = 0.0
		shoot_current()
		
	move_and_slide()

func shoot_current() -> void:
	var start = global_position + Vector3(0, 1.5, -0.5)
	var target = player.global_position + Vector3(0, 1, 0)
	
	match current_weapon:
		"rifle":
			for i in range(3):
				var b = bullet_scene.instantiate(); get_tree().current_scene.add_child(b); b.global_position = start
				b.velocity = ((target + Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1))) - start).normalized() * 40.0
				b.damage = 15.0; b.shooter = self
				await get_tree().create_timer(0.1).timeout
		"minigun":
			for i in range(2):
				var b = bullet_scene.instantiate(); get_tree().current_scene.add_child(b); b.global_position = start
				b.velocity = ((target + Vector3(randf_range(-2,2), randf_range(-2,2), randf_range(-2,2))) - start).normalized() * 50.0
				b.damage = 10.0; b.shooter = self
		"sniper":
			var b = bullet_scene.instantiate(); get_tree().current_scene.add_child(b); b.global_position = start
			b.velocity = (target - start).normalized() * 100.0; b.damage = 60.0; b.shooter = self
		"rocket":
			var r = rocket_scene.instantiate(); get_tree().current_scene.add_child(r); r.global_position = start
			r.velocity = (target - start).normalized() * 30.0; r.damage = 80.0; r.shooter = self
		"grenade":
			var g = grenade_scene.instantiate(); get_tree().current_scene.add_child(g); g.global_position = start
			# РАСЧЕТ БАЛЛИСТИКИ: Направление на игрока + компенсация падения (дуга)
			var dist = global_position.distance_to(player.global_position)
			var dir = (target - start).normalized()
			# Даем гранате точную скорость вместо импульса, чтобы она летела ровно в цель
			g.linear_velocity = dir * (dist * 0.8) + Vector3(0, 6.0, 0)
		"flamer":
			var f = fire_scene.instantiate(); get_tree().current_scene.add_child(f); f.global_position = start
			f.look_at(target, Vector3.UP)
			if global_position.distance_to(player.global_position) < 12.0 and player.has_method("take_damage"):
				player.take_damage(5.0, &"torso", null)
