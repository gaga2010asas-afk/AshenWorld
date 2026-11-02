extends RigidBody3D
var amount: float = 50.0
var can_collect: bool = false

func _ready() -> void:
	var area = $Area3D
	area.body_entered.connect(_on_hit)
	
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.4, 0.3, 0.3)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	add_child(mesh)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.5, 0.4, 0.4)
	col.shape = shape
	add_child(col)
	
	apply_central_impulse(Vector3(randf_range(-2, 2), 3, randf_range(-2, 2)))
	await get_tree().create_timer(0.5).timeout
	can_collect = true

func _process(delta: float) -> void:
	rotate_y(delta * 2.0)

func _on_hit(body: Node) -> void:
	if can_collect and body.name == "Player":
		body.armor = min(100.0, body.armor + amount)
		body.hud.update_armor(body.armor, 100.0)
		queue_free()
