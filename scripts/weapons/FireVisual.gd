extends Node3D

func _ready() -> void:
	# Пламя (частицы, летящие вперед)
	var particles = CPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.3
	particles.local_coords = false
	particles.direction = Vector3(0, 0, -1) # Вперед
	particles.spread = 25.0
	particles.gravity = Vector3(0, 3, 0)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 15.0
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.4, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0)
	mesh.material = mat
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(0.3).timeout
	queue_free()
