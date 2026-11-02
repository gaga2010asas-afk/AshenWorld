extends Node3D

var damage: float = 80.0
var radius: float = 5.0
var pos: Vector3

# Вызываем это ДО добавления в дерево (add_child)
func setup(p: Vector3, dmg: float) -> void:
	pos = p
	damage = dmg

func _ready() -> void:
	global_position = pos # Ставим на место
	
	# Вспышка света
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.2)
	light.light_energy = 12.0
	light.omni_range = radius * 1.5
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.5)
	
	# Огонь
	var fire = CPUParticles3D.new()
	fire.amount = 50
	fire.lifetime = 0.6
	fire.one_shot = true
	fire.explosiveness = 1.0
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 180.0
	fire.initial_velocity_min = 4.0
	fire.initial_velocity_max = 12.0
	fire.gravity = Vector3(0, -2, 0)
	fire.scale_amount_min = 1.0
	fire.scale_amount_max = 2.5
	fire.color = Color(1, 0.5, 0.1)
	var fire_mesh = SphereMesh.new()
	fire_mesh.radius = 0.4
	fire.mesh = fire_mesh
	add_child(fire)
	fire.emitting = true
	
	# Дым
	var smoke = CPUParticles3D.new()
	smoke.amount = 30
	smoke.lifetime = 1.5
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 180.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 5.0
	smoke.gravity = Vector3(0, 2, 0)
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.5
	smoke.color = Color(0.5, 0.5, 0.5, 0.8)
	var smoke_mesh = SphereMesh.new()
	smoke_mesh.radius = 0.6
	smoke.mesh = smoke_mesh
	add_child(smoke)
	smoke.emitting = true
	
	# Ударная волна
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2 # Уменьшили визуальную сферу, чтобы не заслоняла экран
	flash.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.8, 0.3, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat
	add_child(flash)
	var t_flash = create_tween()
	t_flash.set_parallel(true)
	t_flash.tween_property(flash, "scale", Vector3(radius*2, radius*2, radius*2), 0.3)
	t_flash.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	
	# Звук
	var audio = AudioStreamPlayer3D.new()
	audio.stream = preload("res://scripts/utils/SoundGen.gd").get_shoot_sound("shotgun")
	audio.pitch_scale = 0.4
	audio.volume_db = 8.0
	add_child(audio)
	audio.play()
	
	call_deferred("_do_damage")
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _do_damage() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_trauma"):
		var dist = player.global_position.distance_to(global_position)
		if dist < 15.0:
			player.add_trauma(1.0 - (dist / 15.0)) # Чем ближе, тем сильнее тряска
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 6 # 2 (Игрок) + 4 (Враги)
	
	var results = space_state.intersect_shape(query)
	for hit in results:
		var col = hit.collider
		if col.has_method("take_damage"):
			col.take_damage(damage, &"torso", null, global_position)
