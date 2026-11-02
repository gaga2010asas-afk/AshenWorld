extends CharacterBody3D

var hp: float = 30.0
var speed: float = 6.5
var damage: float = 60.0
var is_dead: bool = false
var player: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var stuck_timer: float = 0.0

@onready var nav_agent: NavigationAgent3D = $NavAgent

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.5
	
	# КОЛЛИЗИЯ
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 0.5, 1.2)
	col.shape = shape
	add_child(col)
	
	# МОДЕЛЬ МАШИНКИ
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.7, 0.1, 0.1)
	var mat_wheel = StandardMaterial3D.new()
	mat_wheel.albedo_color = Color(0.1, 0.1, 0.1)
	var mat_glow = StandardMaterial3D.new()
	mat_glow.albedo_color = Color(1, 0, 0)
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(1, 0, 0)
	
	# Шасси
	var chassis = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.3, 1.2)
	chassis.mesh = box
	chassis.position.y = 0.25
	chassis.material_override = mat_body
	add_child(chassis)
	
	# Колеса
	for x in [-0.4, 0.4]:
		for z in [-0.4, 0.4]:
			var wheel = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.2
			cyl.height = 0.1
			wheel.mesh = cyl
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.1, z)
			wheel.material_override = mat_wheel
			add_child(wheel)
			
	# Мигалка
	var light = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.1
	light.mesh = sphere
	light.position.y = 0.45
	light.material_override = mat_glow
	add_child(light)

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead: return
	hp -= amount
	if hp <= 0: 
		die_silent()

func die_silent() -> void:
	if is_dead: return
	is_dead = true
	GameManager.add_kill()
	var fire = preload("res://scenes/weapons/FireVisual.tscn").instantiate()
	get_tree().current_scene.add_child(fire)
	fire.global_position = global_position
	get_tree().call_group("wave_manager", "on_enemy_died", self)
	queue_free()

func explode() -> void:
	if is_dead: return
	is_dead = true
	GameManager.add_kill()
	var exp = preload("res://scenes/weapons/Explosion.tscn").instantiate()
	exp.setup(global_position, damage)
	get_tree().current_scene.add_child(exp)
	get_tree().call_group("wave_manager", "on_enemy_died", self)
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead or not player: return
	
	# Защита от падения в бездну
	if global_position.y < -5.0:
		die_silent()
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var dist = global_position.distance_to(player.global_position)
	
	# 1. Если игрок близко, взрываемся (наносим урон)
	if dist < 3.0:
		explode()
		return
		
	# 2. Проверка на застревание (если не может доехать)
	if velocity.length() < 1.0 and is_on_floor():
		stuck_timer += delta
		if stuck_timer > 2.0:
			explode()
			return
	else:
		stuck_timer = 0.0
		
	# 3. Движение по навигации
	nav_agent.target_position = player.global_position
	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0
	
	if dir.length() < 0.1:
		dir = (player.global_position - global_position).normalized()
		dir.y = 0
		
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	
	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)
		
	move_and_slide()
