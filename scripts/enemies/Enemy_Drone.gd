extends CharacterBody3D

var hp: float = 50.0
var speed: float = 4.0
var damage: float = 8.0
var is_dead: bool = false
var player: Node3D = null
var shoot_timer: float = 0.1 # Скорострельность как у минигана
var time_since_shoot: float = 0.0
var bullet_scene = preload("res://scenes/weapons/PhysicalBullet.tscn")
var rotors = []

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	
	# КОЛЛИЗИЯ
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	add_child(col)
	
	# МОДЕЛЬ ДРОНА
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.3, 0.3, 0.35)
	mat_body.metallic = 0.8
	var mat_rotor = StandardMaterial3D.new()
	mat_rotor.albedo_color = Color(0.7, 0.7, 0.7)
	var mat_gun = StandardMaterial3D.new()
	mat_gun.albedo_color = Color(0.1, 0.1, 0.1)
	
	# Корпус (Более сложная форма)
	var body = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.3
	body.mesh = sphere
	body.material_override = mat_body
	add_child(body)
	
	# Светящийся глаз
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 0, 0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0, 0)
	var eye = MeshInstance3D.new()
	var e_mesh = SphereMesh.new()
	e_mesh.radius = 0.1
	eye.mesh = e_mesh
	eye.position = Vector3(0, 0, -0.35)
	eye.material_override = eye_mat
	add_child(eye)
	
	# Пушка
	var gun = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 0.6
	gun.mesh = cyl
	gun.rotation_degrees.x = 90
	gun.position = Vector3(0, -0.2, -0.4)
	gun.material_override = mat_gun
	add_child(gun)
	
	# Пропеллеры (4 штуки)
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			# Стойка
			var arm = MeshInstance3D.new()
			var a_box = BoxMesh.new()
			a_box.size = Vector3(0.4, 0.05, 0.05)
			arm.mesh = a_box
			arm.position = Vector3(x/2, 0, z/2)
			arm.rotation_degrees.y = atan2(z, x) * 180 / PI
			arm.material_override = mat_body
			add_child(arm)
			
			# Сам пропеллер
			var rotor = MeshInstance3D.new()
			var r_cyl = CylinderMesh.new()
			r_cyl.top_radius = 0.3
			r_cyl.bottom_radius = 0.3
			r_cyl.height = 0.02
			rotor.mesh = r_cyl
			rotor.position = Vector3(x, 0.1, z)
			rotor.material_override = mat_rotor
			add_child(rotor)
			rotors.append(rotor)

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead: return
	hp -= amount
	if hp <= 0: die()

func die() -> void:
	if is_dead: return
	is_dead = true
	GameManager.add_kill()
	# Дрон просто ломается и падает (без взрыва)
	var fire = preload("res://scenes/weapons/FireVisual.tscn").instantiate()
	get_tree().current_scene.add_child(fire)
	fire.global_position = global_position
	
	# Дропаем патроны, чтобы игрок не остался без БК
	if randf() < 0.7:
		var ammo_scene = preload("res://scenes/pickups/AmmoPickup.tscn").instantiate()
		get_tree().current_scene.add_child(ammo_scene)
		ammo_scene.global_position = global_position
		ammo_scene.ammo_type = "rifle"
		ammo_scene.amount = 30
		ammo_scene.apply_central_impulse(Vector3(randf_range(-2,2), 3, randf_range(-2,2)))
		
	get_tree().call_group("wave_manager", "on_enemy_died", self)
	queue_free() # Просто исчезает

func _physics_process(delta: float) -> void:
	# ЗАЩИТА ОТ ПРОВАЛИВАНИЯ В БЕЗДНУ
	if global_position.y < -5.0:
		die()
		return

	if is_dead or not player: return
	
	# Вращение пропеллеров
	for r in rotors:
		r.rotate_y(delta * 30.0)
		
	var target_pos = player.global_position + Vector3(0, 4, 0)
	var dist = global_position.distance_to(target_pos)
	
	if dist > 6.0:
		var dir = (target_pos - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = Vector3(0, sin(Time.get_ticks_msec() / 300.0) * 1.0, 0)
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		
		time_since_shoot += delta
		if time_since_shoot > shoot_timer:
			time_since_shoot = 0.0
			shoot()
			
	move_and_slide()

func shoot() -> void:
	var start = global_position + Vector3(0, -0.2, -0.6)
	var target = player.global_position + Vector3(0, 1, 0)
	
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = start
	
	# Разброс как у минигана
	var spread = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	bullet.velocity = ((target + spread) - start).normalized() * 40.0
	bullet.damage = damage
	bullet.shooter = self
