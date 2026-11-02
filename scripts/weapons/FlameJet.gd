extends Area3D

var velocity: Vector3
var damage: float = 5.0
var lifetime: float = 0.5
var shooter: Node3D

func _ready() -> void:
	body_entered.connect(_on_hit)
	
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.5
	col.shape = shape
	add_child(col)

	var particles = CPUParticles3D.new()
	particles.amount = 25
	particles.lifetime = 0.5
	
	# ГЛОБАЛЬНЫЕ КООРДИНАТЫ (не зависят от поворота узла)
	particles.local_coords = false 
	# Задаем направление строго по вектору полета
	particles.direction = velocity.normalized() 
	particles.spread = 20.0
	particles.gravity = Vector3(0, 3, 0)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 10.0
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.3)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.4, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0)
	mesh.material = mat
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_hit(body: Node) -> void:
	if body == shooter: return
	if body.has_method("take_damage"):
		body.take_damage(damage, &"torso", null, shooter.global_position)
