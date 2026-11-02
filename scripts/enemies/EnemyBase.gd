extends CharacterBody3D

@export var weapon_type: String = "rifle"

var hp: float = 100.0
var is_dead: bool = false
var ragdoll_scene = preload("res://scenes/actors/Ragdoll.tscn")
var bullet_scene = preload("res://scenes/weapons/PhysicalBullet.tscn")
var grenade_scene = preload("res://scenes/weapons/Grenade.tscn")
var casing_scene = preload("res://scenes/weapons/Casing.tscn")
var money_scene = preload("res://scenes/pickups/MoneyPickup.tscn")
var health_scene = preload("res://scenes/pickups/HealthPickup.tscn")
var armor_scene = preload("res://scenes/pickups/ArmorPickup.tscn")
var ammo_scene = preload("res://scenes/pickups/AmmoPickup.tscn")
var dmg_num_scene = preload("res://scenes/ui/DamageNumber.tscn")

var player: Node3D = null
var speed: float = 3.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var audio_shoot: AudioStreamPlayer3D
var walk_time: float = 0.0

var damage: float = 10.0
var attack_range: float = 15.0
var retreat_dist: float = 5.0
var shoot_timer: float = 1.5
var time_since_shoot: float = 0.0
var burst_count: int = 0
var is_shooting_burst: bool = false

var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var kill_reward: int = 100

var arm_r: Node3D
var muzzle: Marker3D
var gun_barrel: MeshInstance3D
var flash_mat: StandardMaterial3D
var leg_l: Node3D
var leg_r: Node3D

func generate_tex() -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	noise.frequency = 0.1
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	var grad = Gradient.new()
	grad.colors = [Color(0.3, 0.3, 0.35), Color(0.6, 0.6, 0.65)]
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	return tex

func apply_textures() -> void:
	if true:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = generate_tex()
		mat.roughness = 0.7
		mat.metallic = 0.5
		mat.uv1_triplanar = true
		for c in find_children("*", "MeshInstance3D", true, false):
			if c.name != "Visor": c.material_override = mat

func _ready() -> void:
	apply_textures()
	player = get_tree().get_first_node_in_group("player")
	$NavAgent.path_desired_distance = 0.5
	$NavAgent.target_desired_distance = 1.0
	strafe_timer = randf_range(0.5, 1.5)
	
	flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 0, 0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 0, 0)
	
	_build_model()
	
	audio_shoot = AudioStreamPlayer3D.new()
	audio_shoot.stream = preload("res://scripts/utils/SoundGen.gd").get_shoot_sound(weapon_type)
	audio_shoot.unit_size = 20.0
	audio_shoot.volume_db = -5.0
	add_child(audio_shoot)

	if weapon_type == "pistol":
		damage = 15.0
		attack_range = 15.0
		retreat_dist = 5.0
		shoot_timer = 1.0
		kill_reward = 100
	elif weapon_type == "shotgun":
		damage = 25.0
		attack_range = 8.0
		retreat_dist = 8.0
		shoot_timer = 1.8
		gun_barrel.scale = Vector3(2.0, 0.5, 2.0)
		audio_shoot.pitch_scale = 0.6
		kill_reward = 150
	elif weapon_type == "sniper":
		damage = 35.0
		attack_range = 25.0
		retreat_dist = 12.0
		shoot_timer = 2.5
		gun_barrel.scale = Vector3(0.5, 2.5, 0.5)
		audio_shoot.pitch_scale = 1.2
		kill_reward = 50
	elif weapon_type == "minigun":
		damage = 8.0
		attack_range = 20.0
		retreat_dist = 8.0
		shoot_timer = 0.08
		gun_barrel.scale = Vector3(3.0, 1.0, 3.0)
		audio_shoot.pitch_scale = 1.5
		kill_reward = 300
	elif weapon_type == "rocket":
		damage = 50.0
		attack_range = 25.0
		retreat_dist = 12.0
		shoot_timer = 3.0
		gun_barrel.scale = Vector3(2.0, 2.0, 2.0)
		audio_shoot.pitch_scale = 0.5
		kill_reward = 500
	elif weapon_type == "flamer":
		damage = 2.0
		attack_range = 10.0
		retreat_dist = 3.0
		shoot_timer = 0.1
		gun_barrel.scale = Vector3(1.5, 1.5, 1.5)
		audio_shoot.pitch_scale = 0.8
		kill_reward = 400
	elif weapon_type == "grenade":
		damage = 60.0
		attack_range = 15.0
		retreat_dist = 8.0
		shoot_timer = 3.0
		gun_barrel.scale = Vector3(1.0, 1.0, 1.0)
		audio_shoot.pitch_scale = 1.0
		kill_reward = 200
	elif weapon_type == "grenade":
		damage = 60.0
		attack_range = 15.0
		retreat_dist = 8.0
		shoot_timer = 3.0
		gun_barrel.scale = Vector3(1.0, 1.0, 1.0)
		audio_shoot.pitch_scale = 1.0
		kill_reward = 200
	else:
		damage = 10.0
		attack_range = 15.0
		retreat_dist = 6.0
		shoot_timer = 1.5
		kill_reward = 100

func _build_model() -> void:
	var is_wave_enemy = get_meta("is_wave", false)
	
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.6, 0.1, 0.1) if is_wave_enemy else Color(0.2, 0.2, 0.25)
	mat_body.metallic = 0.5
	
	var mat_visor = StandardMaterial3D.new()
	mat_visor.albedo_color = Color(1, 0.2, 0)
	mat_visor.emission_enabled = true
	mat_visor.emission = Color(1, 0.2, 0)
	
	var mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.1, 0.1, 0.1)

	var make_part = func(mesh_type: String, sz: Vector3, pos: Vector3, mat: Material, p_node: Node3D = self) -> MeshInstance3D:
		var m = MeshInstance3D.new()
		if mesh_type == "box":
			var b = BoxMesh.new()
			b.size = sz
			m.mesh = b
		elif mesh_type == "cyl":
			var c = CylinderMesh.new()
			c.top_radius = sz.x
			c.bottom_radius = sz.x
			c.height = sz.y
			m.mesh = c
		m.position = pos
		m.material_override = mat
		p_node.add_child(m)
		return m

	# Торс и Плечи (Разные для разных классов)
	if weapon_type == "shotgun":
		make_part.call("box", Vector3(0.8, 0.8, 0.5), Vector3(0, 0.9, 0), mat_body) # Широкий торс
		make_part.call("box", Vector3(0.2, 0.2, 0.2), Vector3(-0.5, 1.2, 0), mat_dark) # Огромные плечи
		make_part.call("box", Vector3(0.2, 0.2, 0.2), Vector3(0.5, 1.2, 0), mat_dark)
	else:
		make_part.call("box", Vector3(0.6, 0.7, 0.4), Vector3(0, 0.9, 0), mat_body)
		make_part.call("cyl", Vector3(0.1, 0.2, 0.1), Vector3(-0.4, 1.15, 0), mat_dark).rotation_degrees.z = 90
		make_part.call("cyl", Vector3(0.1, 0.2, 0.1), Vector3(0.4, 1.15, 0), mat_dark).rotation_degrees.z = 90

	# Голова и Снайперский капюшон
	make_part.call("box", Vector3(0.3, 0.3, 0.3), Vector3(0, 1.45, 0), mat_body)
	if weapon_type == "sniper":
		var hood = make_part.call("cyl", Vector3(0.2, 0.4, 0.2), Vector3(0, 1.5, 0.1), mat_dark)
		hood.rotation_degrees.x = 90
		
	# Визор (Светящийся)
	make_part.call("box", Vector3(0.25, 0.05, 0.05), Vector3(0, 1.45, -0.16), mat_visor)
	
	# Ноги (Пивоты для анимации)
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.15, 0.55, 0)
	add_child(leg_l)
	make_part.call("box", Vector3(0.2, 0.6, 0.2), Vector3(0, -0.3, 0), mat_body, leg_l)
	
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.15, 0.55, 0)
	add_child(leg_r)
	make_part.call("box", Vector3(0.2, 0.6, 0.2), Vector3(0, -0.3, 0), mat_body, leg_r)
	
	# Левая рука (Просто висит)
	make_part.call("box", Vector3(0.15, 0.5, 0.15), Vector3(-0.4, 0.9, 0), mat_body)
	
	# Правая рука с оружием
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.4, 1.1, 0)
	add_child(arm_r)
	make_part.call("box", Vector3(0.15, 0.5, 0.15), Vector3(0, -0.25, 0), mat_body, arm_r)
	
	var gun = Node3D.new()
	gun.position = Vector3(0, -0.5, -0.1)
	arm_r.add_child(gun)
	make_part.call("box", Vector3(0.08, 0.1, 0.4), Vector3.ZERO, mat_dark, gun)
	gun_barrel = make_part.call("cyl", Vector3(0.02, 0.3, 0.02), Vector3(0, 0.02, -0.3), mat_dark, gun)
	gun_barrel.rotation_degrees.x = 90
	make_part.call("box", Vector3(0.05, 0.15, 0.1), Vector3(0, -0.1, 0.05), mat_dark, gun)
	
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -0.45)
	gun.add_child(muzzle)

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead: return
	hp -= amount
	var is_head = (zone == &"head")
	var dmg_ui = dmg_num_scene.instantiate()
	get_tree().current_scene.add_child(dmg_ui)
	dmg_ui.global_position = global_position + Vector3(0, 1.5, 0)
	dmg_ui.setup(amount, is_head)
	
	strafe_dir *= -1.0
	strafe_timer = randf_range(0.8, 1.5)
	
	for child in find_children("*", "MeshInstance3D", true, false):
		if child.name != "Visor":
			child.material_overlay = flash_mat
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(child) and not is_dead:
				child.material_overlay = null
	
	if hp <= 0:
		die()

func die() -> void:
	if is_dead: return
	is_dead = true
	GameManager.add_kill()
	
	get_tree().call_group("wave_manager", "on_enemy_died", self)
	get_tree().call_group("hud", "add_killfeed", weapon_type)
	
	var money = money_scene.instantiate()
	money.amount = kill_reward
	get_tree().current_scene.add_child(money)
	money.global_position = global_position + Vector3(0, 1, 0)
	
	if randf() < 0.15:
		var hp_pickup = health_scene.instantiate()
		get_tree().current_scene.add_child(hp_pickup)
		hp_pickup.global_position = global_position + Vector3(0, 1, 0)
		hp_pickup.apply_central_impulse(Vector3(randf_range(-3,3), 5, randf_range(-3,3)))
		
	if randf() < 0.20:
		var ap_pickup = armor_scene.instantiate()
		get_tree().current_scene.add_child(ap_pickup)
		ap_pickup.global_position = global_position + Vector3(0, 1, 0)
		ap_pickup.apply_central_impulse(Vector3(randf_range(-3,3), 5, randf_range(-3,3)))
		
	if randf() < 0.4:
		var ammo = ammo_scene.instantiate()
		if weapon_type == "shotgun": ammo.ammo_type = "shotgun"; ammo.amount = 8
		elif weapon_type == "sniper": ammo.ammo_type = "sniper"; ammo.amount = 5
		else: ammo.ammo_type = "rifle"; ammo.amount = 30
		get_tree().current_scene.add_child(ammo)
		ammo.global_position = global_position + Vector3(0, 1, 0)
		ammo.apply_central_impulse(Vector3(randf_range(-3,3), 5, randf_range(-3,3)))
		
	var rag = ragdoll_scene.instantiate()
	get_tree().current_scene.add_child(rag)
	if is_instance_valid(rag):
		rag.global_position = global_position + Vector3(0, 0.8, 0)
		rag.rotation = rotation
		if player and is_instance_valid(player):
			var dir = (global_position - player.global_position).normalized()
			rag.apply_central_impulse(dir * 15.0 + Vector3(0, 5, 0))
			rag.angular_velocity = Vector3(randf_range(-10,10), randf_range(-10,10), randf_range(-10,10))
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead: return
	if global_position.y < -5.0:
		die()
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if not player: return
	
	var dist = global_position.distance_to(player.global_position)
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + Vector3(0, 1.2, 0)
	var ray_end = player.global_position + Vector3(0, 1.2, 0)
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 3
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	var can_see_player = (result and result.collider == player)

	var target_arm_rot: float = 0.0
	
	if dist > attack_range or not can_see_player:
		$NavAgent.target_position = player.global_position
		var next_pos = $NavAgent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		
		if dir.length() < 0.1:
			dir = (player.global_position - global_position).normalized()
			
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		
		if dir.length() > 0.1:
			var look_target = global_position + dir
			look_target.y = global_position.y
			look_at(look_target, Vector3.UP)
	else:
		var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		look_at(target_pos, Vector3.UP)
		target_arm_rot = -90.0
		strafe_timer -= delta
		if strafe_timer <= 0:
			strafe_dir *= -1.0
			strafe_timer = randf_range(1.0, 2.5)
		if is_on_wall():
			strafe_dir *= -1.0
			strafe_timer = randf_range(1.0, 2.0)
		var right_vec = transform.basis.x.normalized()
		var retreat = Vector3.ZERO
		if dist < retreat_dist:
			var dir_away = (global_position - player.global_position).normalized()
			if weapon_type == "shotgun":
				velocity.x = dir_away.x * speed * 2.5
				velocity.z = dir_away.z * speed * 2.5
			else:
				retreat = dir_away * speed * 1.5
		if weapon_type != "shotgun" or dist >= retreat_dist:
			velocity.x = (right_vec.x * strafe_dir * speed * 0.5) + retreat.x
			velocity.z = (right_vec.z * strafe_dir * speed * 0.5) + retreat.z
		time_since_shoot += delta
		if time_since_shoot >= shoot_timer:
			if weapon_type == "rifle":
				if not is_shooting_burst:
					is_shooting_burst = true
					burst_count = 3
				if burst_count > 0:
					shoot_at_player()
					burst_count -= 1
					time_since_shoot = 0.15
				else:
					is_shooting_burst = false
					time_since_shoot = 0.0
					shoot_timer = 1.5
			else:
				shoot_at_player()
				time_since_shoot = 0.0

	arm_r.rotation_degrees.x = move_toward(arm_r.rotation_degrees.x, target_arm_rot, delta * 200.0)

	if velocity.length() > 0.5 and is_on_floor():
		walk_time += delta * 10.0
		leg_l.rotation.x = sin(walk_time) * 0.5
		leg_r.rotation.x = -sin(walk_time) * 0.5
	else:
		leg_l.rotation.x = move_toward(leg_l.rotation.x, 0, delta * 10)
		leg_r.rotation.x = move_toward(leg_r.rotation.x, 0, delta * 10)
				
	move_and_slide()

func shoot_at_player() -> void:
	if not player or is_dead: return
	if audio_shoot: audio_shoot.play()
	
	var start = muzzle.global_position
	var target = player.global_position + Vector3(0, 1.2, 0)
	
	var casing = casing_scene.instantiate()
	get_tree().current_scene.add_child(casing)
	casing.global_position = start + transform.basis.x * 0.1 + Vector3(0, 0.1, 0)
	
	var casing_mesh = casing.get_node("MeshInstance3D")
	var mat = StandardMaterial3D.new()
	if weapon_type == "shotgun": casing.scale = Vector3(1.5, 0.6, 1.5); mat.albedo_color = Color(0.8, 0.1, 0.1)
	elif weapon_type == "sniper": casing.scale = Vector3(1.0, 1.5, 1.0); mat.albedo_color = Color(0.8, 0.6, 0.1)
	else: casing.scale = Vector3(0.8, 0.8, 0.8); mat.albedo_color = Color(0.8, 0.6, 0.1)
	casing_mesh.material_override = mat
	
	casing.apply_central_impulse(transform.basis.x * randf_range(2, 4) + Vector3(0, randf_range(1.5, 2.5), 0))
	casing.angular_velocity = Vector3(randf_range(-15,15), randf_range(-15,15), randf_range(-15,15))

	if weapon_type == "rocket":
		var rocket = preload("res://scenes/weapons/Rocket.tscn").instantiate()
		get_tree().current_scene.add_child(rocket)
		rocket.global_position = start
		rocket.velocity = (target - start).normalized() * 30.0
		rocket.damage = damage
		rocket.shooter = self
	elif weapon_type == "flamer":
		var fire = preload("res://scenes/weapons/FireVisual.tscn").instantiate()
		get_tree().current_scene.add_child(fire)
		fire.global_position = start
		fire.look_at(target, Vector3.UP)
		var dist = global_position.distance_to(player.global_position)
		if dist < attack_range and player.has_method("take_damage"):
			player.take_damage(damage, &"torso", null, global_position)
	elif weapon_type == "grenade":
		var grenade = grenade_scene.instantiate()
		get_tree().current_scene.add_child(grenade)
		grenade.global_position = start
		var force = (target - start).normalized() * 12.0 + Vector3(0, 5, 0)
		grenade.apply_central_impulse(force)
	elif weapon_type == "grenade":
		var grenade = grenade_scene.instantiate()
		get_tree().current_scene.add_child(grenade)
		grenade.global_position = start
		var force = (target - start).normalized() * 12.0 + Vector3(0, 5, 0)
		grenade.apply_central_impulse(force)
	else:
		var bullets = 3 if weapon_type == "shotgun" else 1
		for i in range(bullets):
			var bullet = bullet_scene.instantiate()
			get_tree().current_scene.add_child(bullet)
			bullet.global_position = start
			var spread = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1))
			if weapon_type == "sniper": spread *= 0.1
			elif weapon_type == "shotgun": spread *= 3.0
			else: spread *= 1.5
			bullet.velocity = ((target + spread) - start).normalized() * 40.0
			bullet.damage = damage
			bullet.shooter = self
