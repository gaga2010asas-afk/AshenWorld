extends RigidBody3D
var has_played_sound = false
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
	var lifetime = randf_range(10.0, 20.0)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = 0.5
	phys_mat.friction = 0.4
	physics_material_override = phys_mat
	
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_hit)
	
	audio_player = AudioStreamPlayer3D.new()
	
	# Проверяем группу, а не имя узла
	if is_in_group("dropped_mags"):
		audio_player.stream = preload("res://scripts/utils/SoundGen.gd").get_mag_fall_sound()
		audio_player.volume_db = 0.0 # Громко
	else:
		audio_player.stream = preload("res://scripts/utils/SoundGen.gd").get_clink_sound()
		audio_player.volume_db = -5.0 # Потише
		
	if audio_player.stream:
		audio_player.unit_size = 5.0
		add_child(audio_player)
	
	var casings = get_tree().get_nodes_in_group("casings")
	if casings.size() > 50: 
		casings[0].queue_free()
	add_to_group("casings")

func _on_hit(_body: Node) -> void:
	if not has_played_sound and is_instance_valid(audio_player) and audio_player.stream:
		has_played_sound = true
		# Для магазина не меняем питч, для гильзы рандомизируем
		if not is_in_group("dropped_mags"):
			audio_player.pitch_scale = randf_range(0.8, 1.2)
		audio_player.play()
