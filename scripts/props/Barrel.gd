extends RigidBody3D

var hp: float = 50.0
var is_exploded: bool = false
var player: Node3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	# Создаем визуал бочки
	var mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 1.0
	mesh.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.1, 0.1) # Красная бочка
	mat.roughness = 0.6
	mat.metallic = 0.4
	mesh.material_override = mat
	add_child(mesh)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.0
	col.shape = shape
	add_child(col)
	
	add_to_group("barrel")

func take_damage(amount: float, zone: StringName, armor_ref) -> void:
	if is_exploded: return
	hp -= amount
	if hp <= 0:
		explode()

func explode() -> void:
	is_exploded = true
	
	# Взрыв (используем логику гранаты)
	var explosion = preload("res://scenes/weapons/Grenade.tscn").instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	explosion.fuse_time = 0.05 # Мгновенный взрыв
	explosion.damage = 60.0 # Урон от бочки
	
	# Урон по игроку, если он близко
	if player and player.global_position.distance_to(global_position) < 4.0:
		if player.has_method("take_damage"):
			player.take_damage(40.0, &"torso", null)
			
	queue_free()
