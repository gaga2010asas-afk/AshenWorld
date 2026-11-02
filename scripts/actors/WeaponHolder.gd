extends Node3D

signal ammo_changed(mag: int, res: int, w_name: String)
signal fired
signal zoom_toggled(is_zoomed: bool)
signal grenade_changed(count: int)
signal hit_confirmed
signal heat_changed(current: float, max_val: float, is_overheated: bool)
signal weapon_switched(w_name: String)

var current_weapon: String = ""
var weapons = {
	"pistol": {"dmg": 26, "mag_max": 12, "reserve_max": 200, "rof": 0.15, "reload": 1.2, "spread": 0.5, "pellets": 1, "auto": false},
	"rifle": {"dmg": 33, "mag_max": 30, "reserve_max": 300, "rof": 0.1, "reload": 2.4, "spread": 1.5, "pellets": 1, "auto": true},
	"shotgun": {"dmg": 8, "mag_max": 8, "reserve_max": 60, "rof": 0.8, "reload": 3.0, "spread": 6.0, "pellets": 12, "auto": false},
	"sniper": {"dmg": 115, "mag_max": 5, "reserve_max": 40, "rof": 1.0, "reload": 3.5, "spread": 0.1, "pellets": 1, "auto": false},
	"minigun": {"dmg": 15, "mag_max": 150, "reserve_max": 300, "rof": 0.05, "reload": 5.0, "spread": 3.0, "pellets": 1, "auto": true},
	"rocket": {"dmg": 200, "mag_max": 1, "reserve_max": 10, "rof": 1.5, "reload": 3.0, "spread": 0.0, "pellets": 1, "auto": false},
	"flamer": {"dmg": 5, "mag_max": 100, "reserve_max": 200, "rof": 0.05, "reload": 2.5, "spread": 4.0, "pellets": 3, "auto": true}
}

var ammo_state = {
	"pistol": {"mag": 12, "reserve": 200}, "rifle": {"mag": 30, "reserve": 300},
	"shotgun": {"mag": 8, "reserve": 60}, "sniper": {"mag": 5, "reserve": 40},
	"minigun": {"mag": 150, "reserve": 300}, "rocket": {"mag": 1, "reserve": 10}, "flamer": {"mag": 100, "reserve": 200}
}

var weapon_order = ["pistol", "rifle", "shotgun", "sniper", "minigun", "rocket", "flamer"]

var grenades: int = 3
var mag: int = 30
var reserve: int = 300
var is_reloading: bool = false
var heat: float = 0.0
var max_heat: float = 100.0
var is_overheated: bool = false
var overheat_timer: float = 0.0
var infinite_ammo: bool = false
var is_zoomed: bool = false
var can_shoot: bool = true
var time_since_last_shot: float = 0.0
var reload_tween: Tween = null

var current_ammo_type: int = 0
var attachment_mode: int = 0
var is_reload_cancelled: bool = false

var impact_scene = preload("res://scenes/weapons/BulletImpact.tscn")
var casing_scene = preload("res://scenes/weapons/Casing.tscn")
var dropped_mag_scene = preload("res://scenes/weapons/DroppedMag.tscn")
var grenade_scene = preload("res://scenes/weapons/Grenade.tscn")
var rocket_scene = preload("res://scenes/weapons/Rocket.tscn")
var flame_scene = preload("res://scenes/weapons/FlameJet.tscn")
var fire_visual_scene = preload("res://scenes/weapons/FireVisual.tscn")
var sound_gen = preload("res://scripts/utils/SoundGen.gd")

@onready var camera: Camera3D = get_parent()
@onready var muzzle_flash: OmniLight3D = $Model/MuzzleFlash
@onready var model: Node3D = $Model
var magazine_mesh: Node3D = null 
var audio_shoot: AudioStreamPlayer
var audio_reload: AudioStreamPlayer

var original_pos: Vector3
var original_rot: Vector3
var sway_offset: Vector3 = Vector3.ZERO
var recoil_offset: float = 0.0
var is_aiming: bool = false

func apply_weapon_textures() -> void:
	if ResourceLoader.exists("res://textures/rust.png"):
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_texture = load("res://textures/rust.png")
		r_mat.roughness = 0.9
		# Это применится к новым моделям через material_override в _add_part
	# Пока просто заглушка, так как оружие создается динамически

func _ready() -> void:
	apply_weapon_textures()
	original_pos = model.position
	original_rot = model.rotation
	
	audio_shoot = AudioStreamPlayer.new()
	audio_shoot.stream = sound_gen.get_shoot_sound("rifle")
	audio_shoot.volume_db = 0.0
	add_child(audio_shoot)
	
	audio_reload = AudioStreamPlayer.new()
	audio_reload.stream = sound_gen.get_reload_sound()
	add_child(audio_reload)
	
	for w in ammo_state.keys():
		if GameManager.extra_ammo.has(w):
			ammo_state[w]["reserve"] += GameManager.extra_ammo[w]
			GameManager.extra_ammo[w] = 0
	
	original_pos = Vector3(0.3, -0.3, -0.6)
	original_rot = Vector3.ZERO
	model.position = original_pos
	model.rotation = original_rot
	
	# Принудительно выдаем пистолет для теста
	_equip_weapon("pistol")
	GameManager.equipped_weapon = "pistol"
		
	grenade_changed.emit(grenades)

func _process(delta: float) -> void:
	if current_weapon in ["sniper", "rifle"] and is_zoomed: model.hide()
	else: model.show()

	sway_offset = sway_offset.lerp(Vector3.ZERO, delta * 5.0)
	var target_pos = original_pos
	if is_aiming: target_pos = Vector3(0.0, -0.1, -0.3)
	model.position = model.position.lerp(target_pos + sway_offset, delta * 15.0)

	recoil_offset = move_toward(recoil_offset, 0.0, delta * 150.0)
	model.rotation.x = original_rot.x + deg_to_rad(recoil_offset)

	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0:
			is_overheated = false
			heat = 0.0
			heat_changed.emit(heat, max_heat, false)
	elif heat > 0:
		heat = max(0.0, heat - 25.0 * delta)
		heat_changed.emit(heat, max_heat, false)

	if is_reloading: return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE or get_tree().paused: return
	
	time_since_last_shot += delta
	if Input.is_action_pressed("fire") and time_since_last_shot >= weapons[current_weapon]["rof"] and can_shoot:
		shoot()
		time_since_last_shot = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE or get_tree().paused: return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		infinite_ammo = !infinite_ammo
		print("CHEAT: INFINITE AMMO ", infinite_ammo)
		return

	
	if event is InputEventMouseMotion:
		sway_offset.x = clamp(-event.relative.x * 0.005, -0.05, 0.05)
		sway_offset.y = clamp(-event.relative.y * 0.005, -0.05, 0.05)
		
	if event.is_action_pressed("reload"): reload()
	if event.is_action_pressed("grenade") and grenades > 0: throw_grenade()
	if event.is_action_pressed("melee"): melee_attack()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		attachment_mode = (attachment_mode + 1) % 3
		_create_viewmodel(current_weapon)
		if get_parent() and get_parent().get_parent():
			var hud = get_parent().get_parent().get_node_or_null("HUD")
			if hud and hud.has_method("show_attachment"):
				hud.show_attachment(attachment_mode)
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _cycle_weapon(1)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 and GameManager.owned_weapons.has("pistol"): _equip_weapon("pistol")
		elif event.keycode == KEY_2 and GameManager.owned_weapons.has("rifle"): _equip_weapon("rifle")
		elif event.keycode == KEY_3 and GameManager.owned_weapons.has("shotgun"): _equip_weapon("shotgun")
		elif event.keycode == KEY_4 and GameManager.owned_weapons.has("sniper"): _equip_weapon("sniper")
		elif event.keycode == KEY_5 and GameManager.owned_weapons.has("minigun"): _equip_weapon("minigun")
		elif event.keycode == KEY_6 and GameManager.owned_weapons.has("rocket"): _equip_weapon("rocket")
		elif event.keycode == KEY_7 and GameManager.owned_weapons.has("flamer"): _equip_weapon("flamer")
		
	if event.is_action_pressed("aim"):
		is_aiming = true
		if current_weapon in ["sniper", "rifle"]:
			is_zoomed = true
			zoom_toggled.emit(true)
		else:
			create_tween().tween_property(camera, "fov", 60.0, 0.2)
	elif event.is_action_released("aim"):
		is_aiming = false
		if current_weapon in ["sniper", "rifle"]:
			is_zoomed = false
			zoom_toggled.emit(false)
		else:
			create_tween().tween_property(camera, "fov", 75.0, 0.2)

func _cycle_weapon(dir: int) -> void:
	var idx = weapon_order.find(current_weapon)
	for i in range(1, weapon_order.size() + 1):
		var next_idx = (idx + dir * i) % weapon_order.size()
		if next_idx < 0: next_idx = weapon_order.size() + next_idx
		var w_name = weapon_order[next_idx]
		if GameManager.owned_weapons.has(w_name):
			_equip_weapon(w_name)
			return

func throw_grenade() -> void:
	grenades -= 1
	grenade_changed.emit(grenades)
	var grenade = grenade_scene.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = camera.global_position + (-camera.global_transform.basis.z * 0.5)
	grenade.apply_central_impulse(-camera.global_transform.basis.z * 8.0 + Vector3(0, 3.0, 0))
	grenade.angular_velocity = Vector3(randf_range(-10,10), randf_range(-10,10), randf_range(-10,10))

func _equip_weapon(w_type: String) -> void:
	if current_weapon == w_type: return
	if reload_tween and reload_tween.is_valid(): reload_tween.kill()
	is_reloading = false
	is_reload_cancelled = true
	can_shoot = true
	is_zoomed = false
	
	if ammo_state.has(current_weapon):
		ammo_state[current_weapon]["mag"] = mag
		ammo_state[current_weapon]["reserve"] = reserve
	
	current_weapon = w_type
	GameManager.equipped_weapon = w_type
	weapon_switched.emit(w_type)
	heat = 0.0
	is_overheated = false
	heat_changed.emit(heat, max_heat, false)
	var w = weapons[w_type]
	
	mag = ammo_state[w_type]["mag"]
	reserve = ammo_state[w_type]["reserve"]
	ammo_changed.emit(mag, reserve, w_type)
	
	var shoot_stream = sound_gen.get_shoot_sound(w_type)
	if shoot_stream: audio_shoot.stream = shoot_stream
	
	model.position = original_pos
	model.rotation = original_rot
	_create_viewmodel(w_type)

func add_ammo_to_all(amount: int) -> void:
	for w in ammo_state.keys():
		ammo_state[w]["reserve"] += amount
		if w == current_weapon:
			reserve += amount
			ammo_changed.emit(mag, reserve, current_weapon)

func melee_attack() -> void:
	if is_reloading: return
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z * 2.5)
	query.collision_mask = 5
	var result = space_state.intersect_ray(query)
	var t = create_tween()
	t.tween_property(model, "position:z", original_pos.z - 0.2, 0.05)
	t.tween_property(model, "position:z", original_pos.z, 0.15)
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(100.0, &"torso", null)
		hit_confirmed.emit()

func _add_part(mesh_type: String, sz: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
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
	model.add_child(m)
	return m

func _get_crysis_material(base_color: Color, noise_scale: float, is_metal: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var noise = FastNoiseLite.new()
	noise.frequency = noise_scale
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	var grad = Gradient.new()
	grad.colors = [base_color.darkened(0.3), base_color.lightened(0.2)]
	tex.color_ramp = grad
	mat.albedo_texture = tex
	mat.roughness = 0.4 if is_metal else 0.8
	mat.metallic = 0.8 if is_metal else 0.1
	return mat

func _create_viewmodel(w_type: String) -> void:
	for c in model.get_children():
		if c.name != "MuzzleFlash": c.queue_free()
		
	var metal = _get_crysis_material(Color(0.4, 0.42, 0.45), 0.05, true)
	var rust = _get_crysis_material(Color(0.5, 0.3, 0.1), 0.08, false)
	var accent = _get_crysis_material(Color(1.0, 0.4, 0.1), 0.02, false)
	accent.emission_enabled = true
	accent.emission = Color(1.0, 0.4, 0.1)
	
	var glass_mat = StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.0, 1.0, 1.0, 0.05)
	glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		
	if w_type == "pistol":
		_add_part("box", Vector3(0.06, 0.08, 0.3), Vector3(0, 0.02, -0.05), Vector3.ZERO, metal) # Slide
		_add_part("box", Vector3(0.05, 0.06, 0.2), Vector3(0, -0.02, 0), Vector3.ZERO, rust) # Frame
		_add_part("box", Vector3(0.04, 0.15, 0.08), Vector3(0, -0.1, 0.05), Vector3(-15, 0, 0), metal) # Grip
		_add_part("cyl", Vector3(0.015, 0.05, 0.015), Vector3(0, 0.02, -0.22), Vector3(90, 0, 0), metal) # Barrel
		_add_part("box", Vector3(0.01, 0.02, 0.04), Vector3(0, 0.06, -0.1), Vector3.ZERO, accent) # Front Sight
		_add_part("box", Vector3(0.03, 0.02, 0.02), Vector3(0, 0.06, 0.1), Vector3.ZERO, metal) # Rear Sight
		magazine_mesh = _add_part("box", Vector3(0.03, 0.12, 0.05), Vector3(0, -0.12, 0.05), Vector3(-15, 0, 0), metal)
		
	elif w_type == "rifle":
		_add_part("box", Vector3(0.06, 0.08, 0.4), Vector3(0, 0, 0), Vector3.ZERO, metal) # Upper Receiver
		_add_part("box", Vector3(0.06, 0.06, 0.3), Vector3(0, -0.07, 0.05), Vector3.ZERO, rust) # Lower Receiver
		_add_part("cyl", Vector3(0.015, 0.35, 0.015), Vector3(0, 0.02, -0.35), Vector3(90, 0, 0), metal) # Barrel
		_add_part("box", Vector3(0.07, 0.06, 0.25), Vector3(0, 0, -0.25), Vector3.ZERO, metal) # Handguard
		_add_part("box", Vector3(0.05, 0.1, 0.25), Vector3(0, -0.02, 0.35), Vector3(10, 0, 0), metal) # Stock
		_add_part("box", Vector3(0.04, 0.15, 0.08), Vector3(0, -0.12, 0.15), Vector3(-25, 0, 0), rust) # Pistol Grip
		_add_part("cyl", Vector3(0.025, 0.15, 0.025), Vector3(0, 0.08, -0.05), Vector3(90, 0, 0), metal) # Scope Body
		_add_part("cyl", Vector3(0.035, 0.04, 0.035), Vector3(0, 0.08, -0.13), Vector3(90, 0, 0), glass_mat) # Scope Lens
		magazine_mesh = _add_part("box", Vector3(0.05, 0.18, 0.08), Vector3(0, -0.15, 0.05), Vector3(-15, 0, 0), rust)

	elif w_type == "shotgun":
		_add_part("cyl", Vector3(0.03, 0.6, 0.03), Vector3(0, 0.04, -0.3), Vector3(90, 0, 0), metal) # Barrel
		_add_part("cyl", Vector3(0.025, 0.5, 0.025), Vector3(0, -0.03, -0.25), Vector3(90, 0, 0), metal) # Tube Mag
		_add_part("box", Vector3(0.07, 0.08, 0.2), Vector3(0, 0.04, -0.15), Vector3.ZERO, rust) # Pump
		_add_part("box", Vector3(0.08, 0.1, 0.3), Vector3(0, 0, 0.1), Vector3.ZERO, metal) # Receiver
		_add_part("box", Vector3(0.06, 0.12, 0.25), Vector3(0, -0.04, 0.35), Vector3(5, 0, 0), rust) # Stock
		_add_part("box", Vector3(0.04, 0.08, 0.1), Vector3(0, -0.08, 0.15), Vector3(-10, 0, 0), metal) # Grip
		magazine_mesh = null 

	elif w_type == "sniper":
		_add_part("box", Vector3(0.06, 0.1, 0.5), Vector3(0, 0, 0), Vector3.ZERO, metal) # Receiver
		_add_part("cyl", Vector3(0.015, 0.9, 0.015), Vector3(0, 0.02, -0.6), Vector3(90, 0, 0), metal) # Long Barrel
		_add_part("cyl", Vector3(0.03, 0.2, 0.03), Vector3(0, 0.02, -1.1), Vector3(90, 0, 0), rust) # Muzzle Brake
		_add_part("box", Vector3(0.06, 0.12, 0.35), Vector3(0, -0.02, 0.4), Vector3(-5, 0, 0), rust) # Stock
		_add_part("box", Vector3(0.04, 0.1, 0.08), Vector3(0, -0.1, 0.15), Vector3(-20, 0, 0), metal) # Grip
		_add_part("cyl", Vector3(0.025, 0.3, 0.025), Vector3(0, 0.12, -0.1), Vector3(90, 0, 0), metal) # Scope
		_add_part("cyl", Vector3(0.035, 0.05, 0.035), Vector3(0, 0.12, -0.26), Vector3(90, 0, 0), accent) # Scope Lens
		magazine_mesh = _add_part("box", Vector3(0.05, 0.12, 0.1), Vector3(0, -0.12, 0.1), Vector3(-10, 0, 0), metal)

	elif w_type == "minigun":
		_add_part("box", Vector3(0.18, 0.18, 0.4), Vector3(0, 0, 0.1), Vector3.ZERO, metal) # Motor Housing
		_add_part("cyl", Vector3(0.06, 0.2, 0.06), Vector3(0, 0, -0.1), Vector3(90, 0, 0), rust) # Rotor Core
		for i in range(6):
			var angle = i * (PI / 3.0)
			_add_part("cyl", Vector3(0.015, 0.7, 0.015), Vector3(cos(angle)*0.06, sin(angle)*0.06, -0.4), Vector3(90, 0, 0), metal)
		_add_part("box", Vector3(0.08, 0.15, 0.1), Vector3(0, -0.15, 0.2), Vector3(-15, 0, 0), metal) # Handle
		magazine_mesh = _add_part("box", Vector3(0.25, 0.25, 0.3), Vector3(0, -0.15, 0.4), Vector3.ZERO, rust)

	elif w_type == "rocket":
		_add_part("cyl", Vector3(0.08, 0.8, 0.08), Vector3(0, 0, -0.1), Vector3(90, 0, 0), rust) # Tube
		_add_part("cyl", Vector3(0.1, 0.15, 0.1), Vector3(0, 0, 0.35), Vector3(90, 0, 0), metal) # Backblast
		_add_part("box", Vector3(0.05, 0.15, 0.1), Vector3(0, -0.1, 0.1), Vector3(-10, 0, 0), metal) # Grip
		_add_part("box", Vector3(0.04, 0.1, 0.2), Vector3(0, 0.1, 0), Vector3.ZERO, metal) # Sight
		magazine_mesh = _add_part("cyl", Vector3(0.04, 0.4, 0.04), Vector3(0, 0, -0.4), Vector3(90, 0, 0), accent) # Rocket

	elif w_type == "flamer":
		_add_part("cyl", Vector3(0.03, 0.5, 0.03), Vector3(0, 0, -0.3), Vector3(90, 0, 0), metal) # Nozzle
		_add_part("cyl", Vector3(0.06, 0.2, 0.06), Vector3(0, 0, -0.6), Vector3(90, 0, 0), rust) # Flame Tip
		_add_part("box", Vector3(0.12, 0.12, 0.3), Vector3(0, 0, 0.1), Vector3.ZERO, metal) # Body
		_add_part("box", Vector3(0.04, 0.1, 0.1), Vector3(0, -0.1, 0.1), Vector3(-10, 0, 0), rust) # Grip
		magazine_mesh = _add_part("cyl", Vector3(0.08, 0.35, 0.08), Vector3(0, -0.2, 0.2), Vector3(0, 0, 0), rust) # Fuel Tank

func shoot() -> void:
	# Бесконечные патроны для минигана и огнемета
	if current_weapon in ["minigun", "flamer"]:
		mag = weapons[current_weapon]["mag_max"]
		ammo_state[current_weapon]["mag"] = mag
		
	if mag <= 0 or not can_shoot:
		if not current_weapon in ["minigun", "flamer"]:
			reload()
		return
		
	can_shoot = false
	if not infinite_ammo:
		mag -= 1
		ammo_state[current_weapon]["mag"] = mag
	ammo_changed.emit(mag, reserve, current_weapon)
	
	# СИНХРОНИЗАЦИЯ ВЫСТРЕЛА ПО СЕТИ
	var player_node = get_parent().get_parent().get_parent()
	if player_node and player_node.is_multiplayer_authority():
		var dir = -camera.global_transform.basis.z
		_sync_shoot.rpc(dir, current_weapon)

	
	# Логика перегрева
	if current_weapon in ["minigun", "flamer"]:
		heat += 4.0
		heat_changed.emit(heat, max_heat, false)
		if heat >= max_heat:
			is_overheated = true
			overheat_timer = 3.0
			can_shoot = false
			heat_changed.emit(heat, max_heat, true)
			return
	fired.emit()
	
	player_node = get_parent().get_parent().get_parent()
	if player_node and player_node.has_method("add_trauma"):
		if current_weapon == "sniper" or current_weapon == "rocket": player_node.add_trauma(0.4)
		elif current_weapon == "shotgun" or current_weapon == "minigun": player_node.add_trauma(0.2)
		else: player_node.add_trauma(0.05)
	
	if audio_shoot and audio_shoot.stream:
		if attachment_mode == 1: audio_shoot.volume_db = -15.0
		else: audio_shoot.volume_db = 0.0
		audio_shoot.play()
	
	var w = weapons[current_weapon]
	
	var t_rec = create_tween()
	t_rec.tween_property(model, "position:z", original_pos.z + 0.05, 0.05)
	t_rec.tween_property(model, "position:z", original_pos.z, 0.1)
	
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = true
		var t = create_tween()
		t.tween_property(muzzle_flash, "light_energy", 0.0, 0.05)
		t.tween_callback(func(): 
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false
				muzzle_flash.light_energy = 2.0
		)

	# Гильзы (только для пулевого оружия)
	var spawn_casing = current_weapon not in ["rocket", "flamer"]
	if spawn_casing:
		var casing = casing_scene.instantiate()
		get_tree().current_scene.add_child(casing)
		casing.global_position = model.global_position + model.global_transform.basis.x * 0.1 + Vector3(0, 0.05, 0)
		casing.apply_central_impulse(model.global_transform.basis.x * randf_range(2, 4) + Vector3(0, randf_range(1.5, 2.5), 0))
		casing.angular_velocity = Vector3(randf_range(-15,15), randf_range(-15,15), randf_range(-15,15))

	if current_weapon == "flamer":
		var fire_vis = fire_visual_scene.instantiate()
		get_tree().current_scene.add_child(fire_vis)
		fire_vis.global_position = camera.global_position + (-camera.global_transform.basis.z * 1.0)
		fire_vis.rotation = camera.global_rotation
		
		var space_state_fl = get_world_3d().direct_space_state
		for i in range(5):
			var start_fl = camera.global_position
			var spread_fl = Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), 0)
			var dir_fl = (-camera.global_transform.basis.z + spread_fl).normalized()
			var end_fl = start_fl + dir_fl * 18.0
			
			var query_fl = PhysicsRayQueryParameters3D.create(start_fl, end_fl)
			query_fl.collision_mask = 5
			var result_fl = space_state_fl.intersect_ray(query_fl)
			
			if result_fl:
				var col = result_fl.collider
				if col.has_method("take_damage"):
					col.take_damage(w["dmg"], &"torso", null, global_position)
					hit_confirmed.emit()
					
		await get_tree().create_timer(w["rof"]).timeout
		can_shoot = true
		return
		
	if current_weapon == "rocket":
		var rocket = rocket_scene.instantiate()
		get_tree().current_scene.add_child(rocket)
		rocket.global_position = camera.global_position + (-camera.global_transform.basis.z * 0.5)
		rocket.velocity = -camera.global_transform.basis.z * 60.0
		rocket.damage = w["dmg"]
		rocket.shooter = get_parent().get_parent().get_parent()
		rocket.look_at(rocket.global_position + rocket.velocity.normalized(), Vector3.UP)
		hit_confirmed.emit()
		await get_tree().create_timer(w["rof"]).timeout
		can_shoot = true
		return

	var space_state = get_world_3d().direct_space_state
	
	for i in range(w["pellets"]):
		var start = camera.global_position
		var current_spread = w["spread"]
		if is_aiming: current_spread *= 0.3
		if attachment_mode == 2: current_spread *= 0.5
		
		var spread_vec = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * (current_spread * 0.01)
		var end = start + (-camera.global_transform.basis.z + spread_vec) * 100.0
		var query = PhysicsRayQueryParameters3D.create(start, end)
		query.collision_mask = 5 
		var result = space_state.intersect_ray(query)
		
		if result:
			var impact = impact_scene.instantiate()
			get_tree().current_scene.add_child(impact)
			impact.global_position = result.position
			var collider = result.collider
			var is_enemy = (collider is CharacterBody3D and collider.is_in_group("enemy"))
			var is_barrel = (collider.is_in_group("barrel"))
			
			impact.setup(result.normal, is_enemy, collider)
			
			if collider.has_method("take_damage"):
				var actual_dmg = w["dmg"]
				var is_headshot = false
				if is_enemy and result.position.y > collider.global_position.y + 1.2:
					is_headshot = true
					actual_dmg *= 4.0
				
				if current_ammo_type == 1:
					actual_dmg *= 1.3
				elif current_ammo_type == 2:
					actual_dmg *= 0.8
					if is_enemy and collider.has_method("take_damage"):
						var burn_timer = Timer.new()
						burn_timer.wait_time = 0.5
						burn_timer.autostart = true
						collider.add_child(burn_timer)
						var burn_state = {"count": 0}
						burn_timer.timeout.connect(func():
							if not is_instance_valid(collider) or collider.is_dead:
								burn_timer.queue_free()
								return
							collider.take_damage(5.0, &"torso", null, global_position)
							burn_state["count"] += 1
							if burn_state["count"] >= 6: burn_timer.queue_free()
						)
						
				collider.take_damage(actual_dmg, &"torso", null, global_position)
				
				recoil_offset = min(recoil_offset + (2.0 if current_weapon != "sniper" else 8.0), 15.0)
				
				if is_headshot:
					GameManager.add_money(50)
					
			if is_enemy or is_barrel:
				hit_confirmed.emit()

	await get_tree().create_timer(w["rof"]).timeout
	can_shoot = true

func reload() -> void:
	# Миниган и Огнемет не требуют перезарядки (бесконечный БК)
	if current_weapon in ["minigun", "flamer"]:
		return
		
	var w = weapons[current_weapon]
	if is_reloading or mag == w["mag_max"] or reserve <= 0: return
	
	is_reloading = true
	is_reload_cancelled = false
	can_shoot = false
	if audio_reload and audio_reload.stream: audio_reload.play()
	
	if is_instance_valid(magazine_mesh) and current_weapon != "shotgun":
		magazine_mesh.visible = false
		var dropped_mag = dropped_mag_scene.instantiate()
		get_tree().current_scene.add_child(dropped_mag)
		dropped_mag.global_position = magazine_mesh.global_position
		
		if current_weapon == "pistol": dropped_mag.scale = Vector3(0.6, 0.8, 0.8)
		elif current_weapon == "sniper": dropped_mag.scale = Vector3(1.2, 1.0, 1.0)
		elif current_weapon == "rocket": dropped_mag.scale = Vector3(3.0, 3.0, 3.0)
			
		dropped_mag.apply_central_impulse(Vector3(0, -2, 0))

	reload_tween = create_tween()
	
	if current_weapon == "shotgun":
		reload_tween.tween_property(model, "position:z", original_pos.z - 0.15, 0.2)
		reload_tween.tween_property(model, "position:z", original_pos.z + 0.1, 0.2)
		reload_tween.tween_property(model, "position:z", original_pos.z, 0.2)
		reload_tween.tween_interval(w["reload"] - 0.6)
		
	elif current_weapon == "sniper":
		reload_tween.tween_property(model, "rotation:z", deg_to_rad(-45), 0.3)
		reload_tween.tween_property(model, "position:x", original_pos.x - 0.1, 0.3)
		reload_tween.tween_interval(w["reload"] - 0.6)
		reload_tween.tween_property(model, "rotation:z", original_rot.z, 0.3)
		reload_tween.tween_property(model, "position:x", original_pos.x, 0.3)
		
	elif current_weapon in ["minigun", "rocket", "flamer"]:
		reload_tween.tween_property(model, "position:y", original_pos.y - 0.2, 0.3)
		reload_tween.tween_property(model, "rotation:z", deg_to_rad(15), 0.2)
		for i in range(4):
			reload_tween.tween_property(model, "position:x", original_pos.x + 0.02, 0.05)
			reload_tween.tween_property(model, "position:x", original_pos.x - 0.02, 0.05)
		reload_tween.tween_interval(w["reload"] - 0.8)
		reload_tween.tween_property(model, "position:y", original_pos.y, 0.3)
		reload_tween.tween_property(model, "rotation:z", original_rot.z, 0.3)
		
	else:
		reload_tween.tween_property(model, "position", original_pos + Vector3(0, -0.15, -0.1), 0.3)
		reload_tween.tween_property(model, "rotation:z", deg_to_rad(-45), 0.3)
		reload_tween.tween_interval(w["reload"] - 0.6)
		reload_tween.tween_property(model, "position", original_pos, 0.3)
		reload_tween.tween_property(model, "rotation:z", original_rot.z, 0.3)
	
	reload_tween.tween_callback(func():
		if is_reload_cancelled: return
		
		var needed = w["mag_max"] - mag
		var to_reload = min(needed, reserve)
		mag += to_reload
		reserve -= to_reload
		
		ammo_state[current_weapon]["mag"] = mag
		ammo_state[current_weapon]["reserve"] = reserve
		
		ammo_changed.emit(mag, reserve, current_weapon)
		if is_instance_valid(magazine_mesh): magazine_mesh.visible = true
		
		is_reloading = false
		can_shoot = true
		
		var click = AudioStreamPlayer.new()
		click.stream = sound_gen.get_clink_sound()
		click.volume_db = -5.0
		add_child(click)
		click.play()
		get_tree().create_timer(0.5).timeout.connect(click.queue_free)
	)


@rpc("any_peer", "unreliable")
func _sync_shoot(dir: Vector3, w_type: String) -> void:
	var player_node = get_parent().get_parent().get_parent()
	if player_node and not player_node.is_multiplayer_authority():
		# Воспроизводим визуал выстрела у других игроков
		if audio_shoot and audio_shoot.stream: audio_shoot.play()
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = true
			await get_tree().create_timer(0.05).timeout
			if is_instance_valid(muzzle_flash): muzzle_flash.visible = false
