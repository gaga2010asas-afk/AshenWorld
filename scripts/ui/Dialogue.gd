extends CanvasLayer

var text_label: Control # Используем базовый Control, чтобы избежать ошибок типов
var lines: Array = []
var current_line: int = 0
var player: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel = get_node_or_null("Panel")
	if not panel:
		panel = ColorRect.new()
		panel.name = "Panel"
		panel.color = Color(0.1, 0.1, 0.15, 0.95)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(900, 250)
		panel.size = Vector2(900, 250)
		add_child(panel)

		text_label = Label.new()
		text_label.name = "TextLabel"
		text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(text_label)
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		text_label = find_child("TextLabel", true, false)
		if not text_label:
			text_label = Label.new()
			add_child(text_label)

	if text_label:
		if text_label.has_method("add_theme_color_override"):
			text_label.add_theme_color_override("font_color", Color.WHITE)
			text_label.add_theme_font_size_override("font_size", 24)
			text_label.add_theme_font_size_override("normal_font_size", 24)

func start_dialogue(new_lines: Array, p: Node) -> void:
	lines = new_lines
	current_line = 0
	player = p
	if player: player.is_in_dialogue = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true 
	_show_line()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.is_action_pressed("interact"):
			_show_line()
			get_viewport().set_input_as_handled()

func _show_line() -> void:
	if current_line < lines.size():
		if text_label:
			text_label.text = str(lines[current_line])
		current_line += 1
	else:
		_end_dialogue()

func _end_dialogue() -> void:
	if player: player.is_in_dialogue = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false 
	queue_free()
