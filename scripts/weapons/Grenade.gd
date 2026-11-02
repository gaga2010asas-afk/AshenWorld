extends RigidBody3D

var damage: float = 25.0 # Урон от одного осколка
var radius: float = 3.0
var fuse_time: float = 3.0
var shrapnel_scene = preload("res://scenes/weapons/Shrapnel.tscn")

func _ready() -> void:
	_build_model()
	
	# Таймер взрыва
	await get_tree().create_timer(fuse_time).timeout
	explode()

func _build_model() -> void:
	# Основа (сфера)
	var sphere = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 0.12
	s_mesh.height = 0.24
	sphere.mesh = s_mesh
	
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.2, 0.3, 0.2) # Военный зеленый
	sphere.material_override = mat_body
	add_child(sphere)
	
	# Ребристость (цилиндр вокруг)
	var cyl = MeshInstance3D.new()
	var c_mesh = CylinderMesh.new()
	c_mesh.top_radius = 0.12
	c_mesh.bottom_radius = 0.12
	c_mesh.height = 0.1
	cyl.mesh = c_mesh
	cyl.material_override = mat_body
	add_child(cyl)
	
	# Рычаг
	var lever = MeshInstance3D.new()
	var l_mesh = CylinderMesh.new()
	l_mesh.top_radius = 0.02
	l_mesh.bottom_radius = 0.02
	l_mesh.height = 0.15
	lever.mesh = l_mesh
	lever.position = Vector3(0, 0.15, 0)
	lever.material_override = load("res://materials/metal.tres")
	add_child(lever)
	
	# Светящееся кольцо
	var ring = MeshInstance3D.new()
	var r_mesh = CylinderMesh.new()
	r_mesh.top_radius = 0.13
	r_mesh.bottom_radius = 0.13
	r_mesh.height = 0.02
	ring.mesh = r_mesh
	var mat_ring = StandardMaterial3D.new()
	mat_ring.albedo_color = Color(1, 0, 0)
	mat_ring.emission_enabled = true
	mat_ring.emission = Color(1, 0, 0)
	ring.material_override = mat_ring
	add_child(ring)

func explode() -> void:
	# Звук взрыва
	var audio_explode = AudioStreamPlayer3D.new()
	audio_explode.stream = preload("res://scripts/utils/SoundGen.gd").get_shoot_sound("shotgun")
	audio_explode.pitch_scale = 0.4
	audio_explode.volume_db = 5.0
	get_tree().current_scene.add_child(audio_explode)
	audio_explode.global_position = global_position
	audio_explode.play()
	
	# Спавн 30 осколков
	for i in range(30):
		var shrapnel = shrapnel_scene.instantiate()
		shrapnel.damage = damage
		get_tree().current_scene.add_child(shrapnel)
		shrapnel.global_position = global_position
		
		# Случайное направление (сфера)
		var dir = Vector3(randf_range(-1,1), randf_range(-0.5, 1), randf_range(-1,1)).normalized()
		# Скорость осколка
		shrapnel.velocity = dir * randf_range(15.0, 25.0)
	
	# Создаем чистый взрыв
	var exp = preload("res://scenes/weapons/Explosion.tscn").instantiate()
	exp.setup(global_position, damage)
	get_tree().current_scene.add_child(exp)
	queue_free()
