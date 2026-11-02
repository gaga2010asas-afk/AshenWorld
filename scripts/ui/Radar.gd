extends Control

var radar_range: float = 40.0
var radar_radius: float = 75.0

func _ready() -> void:
	# Принудительно задаем размер для отрисовки
	custom_minimum_size = Vector2(160, 160)
	size = Vector2(160, 160)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center = size / 2
	var player = get_tree().get_first_node_in_group("player")
	
	# Фон радара
	draw_circle(center, radar_radius, Color(0, 0, 0, 0.6))
	# Обводка (зеленая)
	draw_arc(center, radar_radius, 0, TAU, 64, Color(0, 1, 0, 0.5), 2.0)
	# Сетка
	draw_line(center - Vector2(radar_radius, 0), center + Vector2(radar_radius, 0), Color(0, 1, 0, 0.2), 1.0)
	draw_line(center - Vector2(0, radar_radius), center + Vector2(0, radar_radius), Color(0, 1, 0, 0.2), 1.0)
	
	if not player: return
	
	# Враги (красные точки)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e): continue
		var rel = e.global_position - player.global_position
		var dir = Vector2(rel.x, rel.z)
		
		# Вращаем радар вместе с игроком (чтобы верх всегда был "вперед")
		dir = dir.rotated(-player.global_rotation.y)
		
		if dir.length() < radar_range:
			var dot_pos = center + (dir / radar_range) * radar_radius
			var enemy_color = Color(1, 0.5, 0, 1) if GameManager.colorblind else Color(1, 0, 0, 1)
			draw_circle(dot_pos, 4.0, enemy_color)
			
	# Игрок (зеленая точка в центре)
	draw_circle(center, 3.0, Color(0, 1, 0, 1))
