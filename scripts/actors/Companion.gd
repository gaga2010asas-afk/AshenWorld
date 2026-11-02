extends CharacterBody3D

var speed: float = 5.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: Node3D = null
var is_dead: bool = false

@onready var nav_agent: NavigationAgent3D = $NavAgent

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 2.5

func die() -> void:
	if is_dead: return
	is_dead = true
	# Взрыв напарника
	var explosion = preload("res://scenes/weapons/Grenade.tscn").instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	explosion.fuse_time = 0.1
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead or not player: return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Следуем за игроком, если он далеко
	if global_position.distance_to(player.global_position) > 4.0:
		nav_agent.target_position = player.global_position
		var next_pos = nav_agent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		
		var look_target = global_position + dir
		look_target.y = global_position.y
		look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0
		# Смотрим на игрока
		var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		look_at(target_pos, Vector3.UP)

	move_and_slide()
