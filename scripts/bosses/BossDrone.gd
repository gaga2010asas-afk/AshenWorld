extends CharacterBody3D

var hp: float = 500.0
var max_hp: float = 500.0
var is_dead: bool = false
var speed: float = 5.0
var player: Node3D = null
var attack_timer: float = 1.0
var time_since_attack: float = 0.0
var bullet_scene = preload("res://scenes/weapons/PhysicalBullet.tscn")
var body: Node3D

@onready var nav_agent: NavigationAgent3D = $NavAgent

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 10.0
	
	_build_model()
	
	if player and player.hud:
		player.hud.show_boss_bar("ДРОН-СНАЙПЕР", max_hp)

func _build_model() -> void:
	body = Node3D.new(); add_child(body)
	var mat_body = StandardMaterial3D.new(); mat_body.albedo_color = Color(0.2, 0.2, 0.25); mat_body.metallic = 0.8
	var mat_rotor = StandardMaterial3D.new(); mat_rotor.albedo_color = Color(0.5, 0.5, 0.5)
	var make_part = func(type: String, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
		var m = MeshInstance3D.new()
		if type == "sphere": var s = SphereMesh.new(); s.radius = sz.x; m.mesh = s
		elif type == "cyl": var c = CylinderMesh.new(); c.top_radius = sz.x; c.bottom_radius = sz.x; c.height = sz.y; m.mesh = c
		m.position = pos; m.material_override = mat; body.add_child(m); return m

	make_part.call("sphere", Vector3(0.8, 0, 0), Vector3.ZERO, mat_body)
	make_part.call("cyl", Vector3(0.1, 1.5, 0.1), Vector3(0, -0.2, -0.8), mat_body) # Пушка
	make_part.call("cyl", Vector3(0.1, 0.2, 0.1), Vector3(0, 0, -0.8), mat_rotor).rotation_degrees.x = 90
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			make_part.call("cyl", Vector3(0.8, 0.1, 0.8), Vector3(x, 0, z), mat_rotor)

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead: return
	if zone == &"head": amount *= 2.0
	hp -= amount
	if player and player.hud: player.hud.update_boss_bar(hp)
	if hp <= 0: die()

func die() -> void:
	is_dead = true
	if player and player.hud: player.hud.hide_boss_bar()
	get_tree().call_group("wave_manager", "boss_defeated")
	var exp = preload("res://scenes/weapons/Grenade.tscn").instantiate()
	get_tree().current_scene.add_child(exp); exp.global_position = global_position; exp.fuse_time = 0.1
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead or not player: return
	body.position.y = sin(Time.get_ticks_msec() / 300.0) * 0.2
	body.rotate_y(delta * 1.0)
	var dist = global_position.distance_to(player.global_position)
	
	# Держит дистанцию для снайперки, но подлетает если далеко
	if dist > 20.0:
		nav_agent.target_position = player.global_position + Vector3(0, 3, 0)
		var dir = (nav_agent.get_next_path_position() - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = Vector3.ZERO
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		time_since_attack += delta
		
		if dist > 12.0:
			# СНАЙПЕРСКИЙ РЕЖИМ (Медленно, но больно)
			if time_since_attack >= 2.5:
				time_since_attack = 0.0
				shoot(100.0, 0.01, 80.0) # скорость, разброс, урон
		else:
			# МИНИГАН (Быстро, слабо)
			if time_since_attack >= 0.1:
				time_since_attack = 0.0
				shoot(45.0, 2.0, 8.0)
	move_and_slide()

func shoot(speed_val: float, spread_val: float, dmg: float) -> void:
	var start = global_position + Vector3(0, -0.2, -0.8)
	var target = player.global_position + Vector3(0, 1, 0)
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = start
	var spread = Vector3(randf_range(-spread_val, spread_val), randf_range(-spread_val, spread_val), randf_range(-spread_val, spread_val))
	bullet.velocity = ((target + spread) - start).normalized() * speed_val
	bullet.damage = dmg
	bullet.shooter = self
