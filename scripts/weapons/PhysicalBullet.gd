extends Area3D

var velocity: Vector3
var damage: float
var shooter: Node3D
var lifetime: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_hit)
	
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.2)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.8, 0)
	mesh.material_override = mat
	add_child(mesh)
	
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.1
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_hit(body: Node) -> void:
	if body == shooter: return
	
	if body.has_method("take_damage"):
		var attacker_pos = Vector3.ZERO
		if is_instance_valid(shooter):
			attacker_pos = shooter.global_position
		body.take_damage(damage, &"torso", null, attacker_pos)
		
	queue_free()
