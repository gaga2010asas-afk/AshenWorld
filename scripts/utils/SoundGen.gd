extends Node

static func get_shoot_sound(w_type: String) -> AudioStream:
	var path = "res://audio/sfx/shoot_rifle.wav"
	if w_type == "shotgun": path = "res://audio/sfx/shoot_shotgun.wav"
	elif w_type == "sniper": path = "res://audio/sfx/shoot_sniper.wav"
	
	if ResourceLoader.exists(path): return load(path)
	return _create_wav(0.5, "shoot")

static func get_reload_sound() -> AudioStream:
	var path = "res://audio/sfx/reload.wav"
	if ResourceLoader.exists(path): return load(path)
	return _create_wav(1.0, "reload")

static func get_clink_sound() -> AudioStream:
	return _create_wav(0.3, "clink")

static func get_mag_fall_sound() -> AudioStream:
	return _create_wav(0.6, "mag_fall")

static func get_concrete_hit_sound() -> AudioStream:
	return _create_wav(0.2, "concrete_hit")

# Синтезатор звуков в памяти
static func _create_wav(duration: float, type: String) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	var samples = int(duration * 44100)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / 44100.0
		var val = 0.0
		
		if type == "shoot":
			val = (sin(t * 150.0 * TAU) * exp(-10.0 * t)) + (randf_range(-1.0, 1.0) * exp(-30.0 * t) * 0.8)
			
		elif type == "reload":
			if t > 0.1 and t < 0.15: val = randf_range(-1.0, 1.0) * exp(-50.0 * (t - 0.1))
			elif t > 0.4 and t < 0.45: val = randf_range(-1.0, 1.0) * exp(-50.0 * (t - 0.4))
			elif t > 0.8 and t < 0.85: val = randf_range(-1.0, 1.0) * exp(-50.0 * (t - 0.8))
			
		elif type == "clink":
			var ping = sin(t * 2500.0 * TAU) + sin(t * 3200.0 * TAU)
			val = ping * 0.3 * exp(-20.0 * t)
			
		elif type == "mag_fall":
			# Тяжелый удар + металлический лязг + дребезг
			var thud = sin(t * 90.0 * TAU) * exp(-12.0 * t) * 0.9 # Глухой бас
			var clang = sin(t * 600.0 * TAU) * exp(-18.0 * t) * 0.5 # Металл
			var rattle = randf_range(-1.0, 1.0) * exp(-15.0 * t) * 0.6 # Дребезг
			val = thud + clang + rattle
			
		elif type == "concrete_hit":
			val = randf_range(-1.0, 1.0) * exp(-60.0 * t) + (sin(t * 100.0 * TAU) * exp(-30.0 * t) * 0.5)
			
		val = clamp(val, -1.0, 1.0)
		data.encode_s16(i * 2, int(val * 32767))
		
	wav.data = data
	return wav


static func get_flame_sound() -> AudioStreamWAV:
	return _create_wav(0.2, "concrete_hit") # Используем звук шипения как заглушку


static func get_ui_click() -> AudioStreamWAV:
	return _create_wav(0.05, "clink") # Используем звонкий звук для UI

static func get_ambient_drone() -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	var duration = 5.0 # 5 секунд, зациклим
	var samples = int(duration * 44100)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / 44100.0
		# Смешиваем низкие частоты для мрачного гула
		var hum1 = sin(t * 50.0 * TAU) * 0.3
		var hum2 = sin(t * 55.5 * TAU) * 0.3 # Диссонанс
		var noise = randf_range(-0.02, 0.02) # Легкий шум
		var val = (hum1 + hum2 + noise) * 0.5
		
		data.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 32767))
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples
	return wav


static func get_mech_step() -> AudioStreamWAV:
	return _create_wav(0.3, "mech_step")

static func get_mech_scrape() -> AudioStreamWAV:
	return _create_wav(0.5, "mech_scrape")

static func get_drone_hum() -> AudioStreamWAV:
	return _create_wav(1.0, "drone_hum")

static func get_drone_shoot() -> AudioStreamWAV:
	return _create_wav(0.2, "drone_shoot")

static func get_boss_step() -> AudioStreamWAV:
	return _create_wav(0.4, "boss_step")

static func get_boss_roar() -> AudioStreamWAV:
	return _create_wav(1.5, "boss_roar")
