extends Control

func _ready() -> void:
	# Скрываем системный курсор
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Принудительно растягиваем на весь экран
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	# Курсор всегда следует за мышкой
	global_position = get_viewport().get_mouse_position()
	queue_redraw()

func _draw() -> void:
	# Рисуем прицел (крестик)
	var col = Color(0, 1, 1, 0.9) # Голубой Crysis
	draw_line(Vector2(0, -15), Vector2(0, -5), col, 2.0)
	draw_line(Vector2(0, 5), Vector2(0, 15), col, 2.0)
	draw_line(Vector2(-15, 0), Vector2(-5, 0), col, 2.0)
	draw_line(Vector2(5, 0), Vector2(15, 0), col, 2.0)
	draw_circle(Vector2(0, 0), 2.0, col)
