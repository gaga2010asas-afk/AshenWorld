extends Node

var current_track: String = ""
var player_a: AudioStreamPlayer
var player_b: AudioStreamPlayer
var active_player: AudioStreamPlayer

func _ready() -> void:
	# Создаем два плеера для кроссфейда
	player_a = AudioStreamPlayer.new()
	player_a.bus = "Master"
	add_child(player_a)
	
	player_b = AudioStreamPlayer.new()
	player_b.bus = "Master"
	add_child(player_b)
	
	active_player = player_a

func play_track(track_name: String, fade_time: float = 1.5) -> void:
	if current_track == track_name: return
	
	var path = "res://audio/music/" + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		print("MUSIC: Файл не найден: ", path)
		return
		
	print("MUSIC: Переключение на ", track_name)
	var new_stream = load(path)
	
	# ПРИНУДИТЕЛЬНО ВКЛЮЧАЕМ ЗАЦИКЛИВАНИЕ
	if new_stream:
		if new_stream is AudioStreamOggVorbis:
			new_stream.loop = true
		elif new_stream is AudioStreamMP3:
			new_stream.loop = true
		elif "loop" in new_stream:
			new_stream.loop = true
			
	current_track = track_name
	
	# Меняем плееры местами
	var old_player = active_player
	if active_player == player_a:
		active_player = player_b
	else:
		active_player = player_a
		
	# Настраиваем новый
	active_player.stream = new_stream
	active_player.volume_db = -80.0 # Начинаем с тишины
	active_player.play()
	
	# Кроссфейд
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(active_player, "volume_db", -5.0, fade_time)
	t.tween_property(old_player, "volume_db", -80.0, fade_time)
	
	# Останавливаем старый после затухания
	t.chain().tween_callback(func():
		if old_player != active_player:
			old_player.stop()
	)

func stop_music(fade_time: float = 1.5) -> void:
	current_track = ""
	var t = create_tween()
	t.tween_property(active_player, "volume_db", -80.0, fade_time)
	t.tween_callback(active_player.stop)
