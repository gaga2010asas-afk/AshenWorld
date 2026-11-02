extends RigidBody3D
var amount: float = 50.0
var can_collect: bool = false

func _ready() -> void:
	var area = $Area3D
	area.body_entered.connect(_on_hit)
	
	# Визуал аптечки (Белый куб с зеленым крестом)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.4, 0.2, 0.4)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9)
	mesh.material_override = mat
	add_child(mesh)
	
	var cross1 = MeshInstance3D.new()
	var c1 = BoxMesh.new()
	c1.size = Vector3(0.25, 0.22, 0.08)
	cross1.mesh = c1
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color(0, 1, 0)
	cm.emission_enabled = true
	cm.emission = Color(0, 1, 0)
	cross1.material_override = cm
	add_child(cross1)
	
	var cross2 = MeshInstance3D.new()
	var c2 = BoxMesh.new()
	c2.size = Vector3(0.08, 0.22, 0.25)
	cross2.mesh = c2
	cross2.material_override = cm
	add_child(cross2)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.5, 0.3, 0.5)
	col.shape = shape
	add_child(col)
	
	apply_central_impulse(Vector3(randf_range(-2, 2), 3, randf_range(-2, 2)))
	await get_tree().create_timer(0.5).timeout
	can_collect = true

func _process(delta: float) -> void:
	rotate_y(delta * 2.0)

func _on_hit(body: Node) -> void:
	if can_collect and body.name == "Player":
		body.hp = min(100.0, body.hp + amount)
		body.hud.update_health(body.hp, 100.0)
		queue_free()
