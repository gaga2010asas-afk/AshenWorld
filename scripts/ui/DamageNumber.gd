extends Label3D

var velocity: Vector3 = Vector3(0, 2.0, 0)
var lifetime: float = 1.0

func setup(amount: float, is_headshot: bool) -> void:
	text = str(int(amount))
	font_size = 64
	outline_size = 12
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 3
	
	if is_headshot:
		modulate = Color(1, 0.2, 0.2)
		font_size = 96
	else:
		modulate = Color(1, 0.8, 0.2)
		
	# Случайный разброс, чтобы цифры не слипались
	position.x += randf_range(-0.5, 0.5)
	position.z += randf_range(-0.5, 0.5)

func _process(delta: float) -> void:
	global_position += velocity * delta
	velocity.y -= 2.0 * delta # Замедление
	lifetime -= delta
	
	if lifetime < 0.5:
		modulate.a = lifetime * 2.0 # Прозрачность
		
	if lifetime <= 0:
		queue_free()
