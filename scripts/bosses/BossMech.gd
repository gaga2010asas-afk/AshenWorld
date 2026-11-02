extends CharacterBody3D

var hp: float = 800.0
var max_hp: float = 800.0
var is_dead: bool = false
var speed: float = 3.0
var damage: float = 15.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: Node3D = null
var attack_timer: float = 0.1
var time_since_attack: float = 0.0
var eye_light: OmniLight3D
var fire_scene = preload("res://scenes/weapons/FireVisual.tscn")

@onready var nav_agent: NavigationAgent3D = $NavAgent

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 4.0
	
	_build_model()
	
	if player and player.hud:
		player.hud.show_boss_bar("МЕХ-ОГНЕМЕТЧИК", max_hp)

func _build_model() -> void:
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.545, 0.271, 0.075) # Rust
	
	var make_part = func(mesh_type: String, sz: Vector3, pos: Vector3, mat: Material, p_node: Node3D = self) -> MeshInstance3D:
		var m = MeshInstance3D.new()
		if mesh_type == "box":
			var b = BoxMesh.new(); b.size = sz; m.mesh = b
		elif mesh_type == "cyl":
			var c = CylinderMesh.new(); c.top_radius = sz.x; c.bottom_radius = sz.x; c.height = sz.y; m.mesh = c
		m.position = pos; m.material_override = mat; p_node.add_child(m)
		return m

	make_part.call("box", Vector3(2.0, 1.5, 2.5), Vector3(0, 0.75, 0), mat_body) # Тело
	make_part.call("box", Vector3(0.6, 1.8, 0.6), Vector3(-1.2, 0.75, -0.8), mat_body) # Ковш 1
	make_part.call("box", Vector3(0.6, 1.8, 0.6), Vector3(1.2, 0.75, -0.8), mat_body) # Ковш 2
	for x in [-1.0, 1.0]:
		for z in [-0.8, 0.8]:
			var w = make_part.call("cyl", Vector3(0.4, 0.3, 0.4), Vector3(x, 0.15, z), mat_body)
			w.rotation_degrees.z = 90
			
	make_part.call("box", Vector3(0.4, 0.2, 0.2), Vector3(0, 1.2, -1.3), mat_body) # Глаз
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(1, 0.6, 0); eye_light.light_energy = 2.0; eye_light.omni_range = 3.0
	eye_light.position = Vector3(0, 1.2, -1.4); add_child(eye_light)
	
	# Дуло огнемета
	make_part.call("cyl", Vector3(0.1, 0.8, 0.1), Vector3(0, 1.0, -1.4), mat_body).rotation_degrees.x = 90

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead: return
	if zone == &"head":
		amount *= 2.0
		if eye_light: eye_light.light_color = Color(1, 0, 0)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(eye_light): eye_light.light_color = Color(1, 0.6, 0)
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
	if not is_on_floor(): velocity.y -= gravity * delta
	var dist = global_position.distance_to(player.global_position)
	
	if dist > 8.0:
		nav_agent.target_position = player.global_position
		var next_pos = nav_agent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		velocity.x = dir.x * speed; velocity.z = dir.z * speed
		var look_target = global_position + dir; look_target.y = global_position.y
		look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0; velocity.z = 0
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		
		time_since_attack += delta
		if time_since_attack >= attack_timer:
			time_since_attack = 0.0
			attack_player()
	move_and_slide()

func attack_player() -> void:
	# Визуал струи огня
	var fire = fire_scene.instantiate()
	get_tree().current_scene.add_child(fire)
	fire.global_position = global_position + Vector3(0, 1.0, -1.0)
	fire.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)
	
	# Урон по площади если игрок близко
	if player.global_position.distance_to(global_position) < 9.0:
		if player.has_method("take_damage"):
			player.take_damage(damage, &"torso", null)
