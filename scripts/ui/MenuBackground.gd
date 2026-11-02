extends Control
var t: float = 0.0

func _ready() -> void:
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c = size / 2
	var w = size.x
	var h = size.y
	
	draw_rect(Rect2(0, 0, w, h), Color(0.01, 0.02, 0.05, 1))
	
	# Сетка
	var grid_col = Color(0, 0.5, 0.8, 0.15 + sin(t * 2.0) * 0.05)
	for i in range(1, 20):
		var y = (i * i) * (h / 400.0)
		draw_line(Vector2(0, y), Vector2(w, y), grid_col, 1.0)
	for i in range(-10, 11):
		var x = c.x + i * (w / 10.0)
		draw_line(Vector2(c.x, h * 0.4), Vector2(x, h), grid_col, 1.0)

	# Шлем (Сдвинут далеко вправо, чтобы не перекрывать меню)
	var helmet_center = Vector2(c.x + 400, c.y + 50)
	var wire_col = Color(0, 1, 1, 0.3 + sin(t * 3.0) * 0.1)
	
	draw_arc(helmet_center, 120, 0, TAU, 32, wire_col, 2.0)
	draw_line(helmet_center + Vector2(-100, 0), helmet_center + Vector2(100, 0), Color(0, 1, 1, 0.6), 4.0)
	draw_line(helmet_center + Vector2(-100, 20), helmet_center + Vector2(100, 20), Color(0, 1, 1, 0.3), 1.0)
	draw_rect(Rect2(helmet_center + Vector2(-130, -30), Vector2(30, 60)), wire_col, false, 2.0)
	draw_rect(Rect2(helmet_center + Vector2(100, -30), Vector2(30, 60)), wire_col, false, 2.0)
	
	# Уголки
	var deco_col = Color(0, 1, 1, 0.4)
	draw_line(Vector2(20, 20), Vector2(80, 20), deco_col, 4.0)
	draw_line(Vector2(20, 20), Vector2(20, 80), deco_col, 4.0)
	draw_line(Vector2(w-20, h-20), Vector2(w-80, h-20), deco_col, 4.0)
	draw_line(Vector2(w-20, h-20), Vector2(w-20, h-80), deco_col, 4.0)
