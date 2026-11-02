extends Control

var spread: float = 10.0
var hit_alpha: float = 0.0
var is_scoped: bool = false

func set_scoped(val: bool) -> void:
	is_scoped = val
	queue_redraw()

func _draw() -> void:
	var c = size / 2
	var cx = int(c.x)
	var cy = int(c.y)
	
	if is_scoped:
		var radius = size.y * 0.4 # Радиус прицела
		var col = Color(0, 0, 0, 1) # Черный
		
		# Рисуем черные прямоугольники (закрываем края экрана)
		draw_rect(Rect2(0, 0, size.x, cy - radius), col)
		draw_rect(Rect2(0, cy + radius, size.x, size.y - (cy + radius)), col)
		draw_rect(Rect2(0, cy - radius, cx - radius, radius * 2), col)
		draw_rect(Rect2(cx + radius, cy - radius, size.x - (cx + radius), radius * 2), col)
		
		# Рисуем черную обводку круга
		draw_arc(c, radius, 0, TAU, 64, col, 10.0)
		
		# Тонкие линии прицела
		draw_line(Vector2(cx, cy - radius), Vector2(cx, cy - 10), col, 2.0)
		draw_line(Vector2(cx, cy + 10), Vector2(cx, cy + radius), col, 2.0)
		draw_line(Vector2(cx - radius, cy), Vector2(cx - 10, cy), col, 2.0)
		draw_line(Vector2(cx + 10, cy), Vector2(cx + radius, cy), col, 2.0)
		
		# Красная точка
		draw_circle(c, 2.0, Color(1, 0, 0, 1))
	else:
		# Обычный прицел
		var s = int(spread)
		var col = Color(1, 1, 1, 0.8)
		draw_line(Vector2(cx, cy - s - 10), Vector2(cx, cy - s), col, 2.0)
		draw_line(Vector2(cx, cy + s), Vector2(cx, cy + s + 10), col, 2.0)
		draw_line(Vector2(cx - s - 10, cy), Vector2(cx - s, cy), col, 2.0)
		draw_line(Vector2(cx + s, cy), Vector2(cx + s + 10, cy), col, 2.0)
		draw_circle(c, 2.0, col)

	if hit_alpha > 0:
		var hc = Color(1, 1, 1, hit_alpha)
		draw_line(Vector2(cx-10, cy-10), Vector2(cx-5, cy-5), hc, 2.0)
		draw_line(Vector2(cx+10, cy-10), Vector2(cx+5, cy-5), hc, 2.0)
		draw_line(Vector2(cx-10, cy+10), Vector2(cx-5, cy+5), hc, 2.0)
		draw_line(Vector2(cx+10, cy+10), Vector2(cx+5, cy+5), hc, 2.0)

func on_fire() -> void:
	spread = 25.0
	queue_redraw()
	var tween = create_tween()
	tween.tween_property(self, "spread", 10.0, 0.1)
	tween.finished.connect(func(): queue_redraw())

func show_hitmarker() -> void:
	hit_alpha = 1.0
	queue_redraw()
	var t = create_tween()
	t.tween_property(self, "hit_alpha", 0.0, 0.2)
	t.finished.connect(func(): queue_redraw())
