extends RigidBody3D

var ammo_type: String = "rifle"
var amount: int = 30
var can_collect: bool = false
var lifetime: float = 30.0

@onready var label: Label3D = $Label
@onready var area: Area3D = $Area3D

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	
	apply_central_impulse(Vector3(randf_range(-2, 2), randf_range(3, 5), randf_range(-2, 2)))
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	
	label.text = "+" + str(amount)
	_build_model()
	
	await get_tree().create_timer(0.5).timeout
	can_collect = true

func _build_model() -> void:
	# Цвета зависят от типа патронов
	var glow_color = Color(1, 0.8, 0.1) # Желтый для автомата
	if ammo_type == "shotgun": glow_color = Color(1, 0.2, 0.2) # Красный для дробовика
	elif ammo_type == "sniper": glow_color = Color(0.2, 0.5, 1.0) # Синий для снайперки
	
	var mat_box = StandardMaterial3D.new()
	mat_box.albedo_color = Color(0.2, 0.25, 0.2) # Темно-зеленый армейский
	mat_box.metallic = 0.5
	mat_box.roughness = 0.6
	
	var mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.15, 0.15, 0.15) # Темный металл
	mat_metal.metallic = 0.8
	
	var mat_glow = StandardMaterial3D.new()
	mat_glow.albedo_color = glow_color
	mat_glow.emission_enabled = true
	mat_glow.emission = glow_color
	mat_glow.emission_energy_multiplier = 3.0
	
	var make_part = func(mesh_type: String, sz: Vector3, pos: Vector3, rot: Vector3, mat: Material):
		var m = MeshInstance3D.new()
		if mesh_type == "box":
			var b = BoxMesh.new()
			b.size = sz
			m.mesh = b
		elif mesh_type == "cyl":
			var c = CylinderMesh.new()
			c.top_radius = sz.x
			c.bottom_radius = sz.x
			c.height = sz.y
			m.mesh = c
		m.position = pos
		m.rotation_degrees = rot
		m.material_override = mat
		add_child(m)
		return m

	# 1. Основной корпус
	make_part.call("box", Vector3(0.5, 0.25, 0.7), Vector3(0, 0, 0), Vector3.ZERO, mat_box)
	# 2. Крышка (чуть шире)
	make_part.call("box", Vector3(0.54, 0.08, 0.74), Vector3(0, 0.16, 0), Vector3.ZERO, mat_metal)
	# 3. Защелки (спереди)
	make_part.call("box", Vector3(0.1, 0.15, 0.05), Vector3(-0.15, 0.05, 0.36), Vector3.ZERO, mat_metal)
	make_part.call("box", Vector3(0.1, 0.15, 0.05), Vector3(0.15, 0.05, 0.36), Vector3.ZERO, mat_metal)
	# 4. Светящаяся полоса (маркер)
	make_part.call("box", Vector3(0.3, 0.02, 0.02), Vector3(0, 0.2, 0.3), Vector3.ZERO, mat_glow)
	
	# 5. Декоративные патроны сверху
	for i in range(3):
		var b = make_part.call("cyl", Vector3(0.03, 0.15, 0.03), Vector3(-0.1 + i*0.1, 0.25, -0.2), Vector3(90, 0, 0), mat_glow)
		# Носик пули (конус заменяем маленьким кубом для простоты)
		make_part.call("box", Vector3(0.06, 0.06, 0.06), Vector3(-0.1 + i*0.1, 0.25, -0.35), Vector3(45, 45, 0), mat_metal)

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	elif lifetime < 5.0:
		visible = int(lifetime * 10) % 2 == 0

func _on_body_entered(body: Node) -> void:
	if can_collect and body.name == "Player" and body.has_method("take_damage"):
		var wh = body.get_node_or_null("Head/Camera3D/WeaponHolder")
		if wh:
			wh.ammo_state[ammo_type]["reserve"] += amount
			if wh.current_weapon == ammo_type:
				wh.reserve += amount
				wh.ammo_changed.emit(wh.mag, wh.reserve, wh.current_weapon)
		
		var audio = AudioStreamPlayer3D.new()
		audio.stream = preload("res://scripts/utils/SoundGen.gd").get_clink_sound()
		audio.pitch_scale = 2.0
		body.add_child(audio)
		audio.play()
		get_tree().create_timer(0.3).timeout.connect(audio.queue_free)
		queue_free()
