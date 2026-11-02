extends Node3D

var velocity: Vector3
var damage: float = 200.0
var shooter: Node3D
var prev_pos: Vector3

func _ready() -> void:
	prev_pos = global_position
	if velocity != Vector3.ZERO:
		look_at(global_position + velocity.normalized(), Vector3.UP)
	
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.15
	cyl.height = 0.8
	mesh.mesh = cyl
	mesh.rotation_degrees.x = 90
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0)
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	prev_pos = global_position
	global_position += velocity * delta
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(prev_pos, global_position)
	query.collision_mask = 5 
	
	# ФИКС: Проверяем, жив ли еще стрелок перед тем как исключать его из рейкаста
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
		
	var result = space_state.intersect_ray(query)
	
	if result:
		var explosion_node = preload("res://scenes/weapons/Explosion.tscn").instantiate()
		explosion_node.setup(result.position, damage)
		get_tree().current_scene.add_child(explosion_node)
		queue_free()
