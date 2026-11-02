extends Area3D

var velocity: Vector3
var damage: float = 25.0
var lifetime: float = 0.5

func _ready() -> void:
	body_entered.connect(_on_hit)
	
	# Визуал осколка (маленький горящий кубик)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.1)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.4, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0)
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
	if body.has_method("take_damage"):
		body.take_damage(damage, &"torso", null)
		queue_free()
