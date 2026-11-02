extends RigidBody3D

var damage: float = 15.0
var has_hit: bool = false

func _ready() -> void:
	# Удаляем кубик через 1.5 секунды, если он не попал ни во что
	get_tree().create_timer(1.5).timeout.connect(queue_free)
	
	body_entered.connect(_on_hit)
	
	# Случайное вращение для реалистичности
	angular_velocity = Vector3(randf_range(-20,20), randf_range(-20,20), randf_range(-20,20))

func _on_hit(body: Node) -> void:
	if has_hit: return
	
	if body.has_method("take_damage"):
		has_hit = true
		body.take_damage(damage, &"torso", null, global_position)
		queue_free() # Исчезает при попадании
	else:
		# Если попал в стену, просто останавливается и исчезает через секунду
		has_hit = true
		get_tree().create_timer(0.5).timeout.connect(queue_free)
