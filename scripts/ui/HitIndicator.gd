extends Control
func _draw() -> void:
	var center = size / 2
	var radius = 200.0
	var points = PackedVector2Array()
	for i in range(20):
		var angle = deg_to_rad(-30 + i * 3)
		points.append(center + Vector2(sin(angle), cos(angle)) * radius)
	draw_polyline(points, Color(1, 0, 0, 1), 5.0)
