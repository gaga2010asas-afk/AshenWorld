extends CharacterBody3D

@export var base_speed: float = 6.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 3.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.002
var hp: float = 100.0
var armor: float = 50.0
var is_dead: bool = false
var suit_mode: int = 0
var energy: float = 100.0
var energy_regen_rate: float = 25.0
var energy_drain_timer: float = 0.0
var ammo_type: int = 0
var trauma: float = 0.0
var is_in_dialogue: bool = false
var god_mode: bool = false
var noclip: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var walk_time: float = 0.0
var base_head_y: float = 1.6
var crouch_head_y: float = 1.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var hud: CanvasLayer = $HUD
@onready var leg_left: Node3D = $Body/Legs/LegLeft
@onready var leg_right: Node3D = $Body/Legs/LegRight
@onready var col_shape: CollisionShape3D = $CollisionShape3D

func _enter_tree() -> void:
	var id = name.to_int()
	if id <= 0: id = 1
	set_multiplayer_authority(id)

func generate_tex() -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	noise.frequency = 0.1
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	var grad = Gradient.new()
	grad.colors = [Color(0.3, 0.3, 0.35), Color(0.6, 0.6, 0.65)]
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	return tex

func apply_textures() -> void:
	if true:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = generate_tex()
		mat.roughness = 0.6
		mat.metallic = 0.8
		mat.uv1_triplanar = true
		for c in get_children():
			if c is MeshInstance3D and c.name != "Visor":
				c.material_override = mat

func _hide_local_meshes(node: Node) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			c.hide()
		elif c.name != "Camera3D" and c.name != "WeaponHolder":
			_hide_local_meshes(c)

func _ready() -> void:
	apply_textures()
	add_to_group("player")
	if is_multiplayer_authority():
		# Скрываем ВСЕ меши тела и головы для локального игрока
		_hide_local_meshes($Head)
		_hide_local_meshes($Body)
		
		# Скрываем визор, если он висит в корне
		var visor = get_node_or_null("Visor")
		if visor and visor is MeshInstance3D: visor.hide()
			
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
		
		await get_tree().process_frame
		if hud:
			hud.update_health(hp, 100.0)
			hud.update_armor(armor, 100.0)
			hud.update_energy(energy, 100.0)
			hud.update_suit_mode(suit_mode)
			if weapon_holder:
				weapon_holder.ammo_changed.connect(hud.update_ammo)
				weapon_holder.ammo_changed.connect(func(m, r, n): hud.update_weapon_ui(n))
				weapon_holder.fired.connect(hud.on_fire)
				
				# ПРИНУДИТЕЛЬНО НАДЕВАЕМ ПИСТОЛЕТ И ОБНОВЛЯЕМ HUD
				GameManager.equipped_weapon = "pistol"
				weapon_holder._equip_weapon("pistol")
				# Обновляем HUD правильными данными
				hud.update_ammo(weapon_holder.mag, weapon_holder.reserve, "pistol")
				hud.update_weapon_ui("pistol")
				weapon_holder.zoom_toggled.connect(_on_zoom)
				# ЗАЩИТА: Проверяем, существует ли прицел и не удален ли он
				if is_instance_valid(hud.crosshair) and hud.crosshair.has_method("show_hitmarker"):
					weapon_holder.hit_confirmed.connect(hud.crosshair.show_hitmarker)
	else:
		$Head/Camera3D.queue_free()
		$HUD.queue_free()

func _on_zoom(is_zoomed: bool) -> void:
	var target_fov = 75.0
	if is_zoomed:
		if weapon_holder and weapon_holder.current_weapon == "sniper":
			target_fov = 20.0
		else:
			target_fov = 50.0 # Для автомата зум поменьше
	create_tween().tween_property(camera, "fov", target_fov, 0.2)
	if hud and hud.crosshair: hud.crosshair.set_scoped(is_zoomed)

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func take_damage(amount: float, zone: StringName, armor_ref, attacker_pos: Vector3 = Vector3.ZERO) -> void:
	if god_mode: return
	if is_dead or not is_multiplayer_authority(): return
	
	# Трата энергии при получении урона в режиме Брони
	if suit_mode == 0 and energy > 0:
		var energy_absorb = min(energy, amount * 0.5)
		energy -= energy_absorb
		amount -= energy_absorb
		energy_drain_timer = 1.0

	if armor > 0:
		var absorbed = amount * 0.5
		armor -= absorbed
		amount -= absorbed
		if armor < 0: armor = 0
		if hud: hud.update_armor(armor, 100.0)
		
	hp -= amount
	if hp < 0: hp = 0
	if hud:
		hud.update_health(hp, 100.0)
		hud.flash_damage()
		add_trauma(0.5)
	
	if hp <= 0: die()

func die() -> void:
	is_dead = true
	GameManager.add_death()
	if is_multiplayer_authority():
		if hud: hud.show_death_screen()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead: return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			god_mode = !god_mode
			print("CHEAT: GOD MODE ", god_mode)
			return
		elif event.keycode == KEY_F2:
			GameManager.add_money(10000)
			print("CHEAT: +$10,000 MONEY")
			return
		elif event.keycode == KEY_F3:
			get_tree().call_group("enemy", "take_damage", 99999.0, &"torso", null)
			print("CHEAT: ALL ENEMIES KILLED")
			return
		elif event.keycode == KEY_F4:
			noclip = !noclip
			col_shape.disabled = noclip
			print("CHEAT: NOCLIP ", noclip)
			return

	
	if event.is_action_pressed("ui_cancel"):
		var pm = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
		get_tree().current_scene.add_child(pm)
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()
		return
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE: return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -1.5, 1.5)
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		suit_mode = (suit_mode + 1) % 4
		if hud: 
			hud.update_suit_mode(suit_mode)
			match suit_mode:
				0: hud.show_suit_message("MAX ARMOR", Color(0.2, 0.5, 1))
				1: hud.show_suit_message("MAX SPEED", Color(1, 1, 0))
				2: hud.show_suit_message("MAX STRENGTH", Color(1, 0.2, 0.2))
		
	if event.is_action_pressed("flashlight"):
		var fl = get_node_or_null("Head/Camera3D/Flashlight")
		if fl: fl.visible = not fl.visible
		
	if event.is_action_pressed("ui_cancel"): # Кнопка ESC
		var pm = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
		get_tree().current_scene.add_child(pm)
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tactical_map"):
		if hud and hud.has_method("toggle_scoreboard"): hud.toggle_scoreboard()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead: return
	if noclip:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if Input.is_action_pressed("jump"): dir.y += 1
		if Input.is_action_pressed("crouch"): dir.y -= 1
		position += dir * 20.0 * delta
		velocity = Vector3.ZERO
		return

	# --- ЭНЕРГИЯ: Восстановление ---
	if energy_drain_timer > 0:
		energy_drain_timer -= delta
	else:
		energy = min(100.0, energy + energy_regen_rate * delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- ЭНЕРГИЯ: Трата в режиме Скорости ---
	if suit_mode == 1 and direction != Vector3.ZERO:
		energy -= 15.0 * delta
		energy_drain_timer = 1.0
		if energy <= 0:
			energy = 0
			suit_mode = 0 # Автоматический сброс на Броню
			if hud: hud.update_suit_mode(suit_mode)

	# --- ЭНЕРГИЯ: Трата в режиме Силы (прыжок) ---
	if Input.is_action_just_pressed("jump") and is_on_floor() and not Input.is_action_pressed("crouch"):
		var jump_mult = 1.0
		if suit_mode == 2 and energy >= 20.0:
			jump_mult = 1.6
			energy -= 20.0
			energy_drain_timer = 1.0
		velocity.y = jump_velocity * jump_mult

	if not is_on_floor(): velocity.y -= gravity * delta
	
	var target_speed = base_speed
	if suit_mode == 1: target_speed *= 1.6
	if Input.is_action_pressed("sprint"): target_speed = sprint_speed
	if Input.is_action_pressed("crouch"): target_speed = crouch_speed
	
	if direction:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
		walk_time += delta * target_speed * 2.0
		leg_left.rotation.x = sin(walk_time) * 0.5
		leg_right.rotation.x = -sin(walk_time) * 0.5
	else:
		velocity.x = move_toward(velocity.x, 0, target_speed)
		velocity.z = move_toward(velocity.z, 0, target_speed)
		leg_left.rotation.x = move_toward(leg_left.rotation.x, 0, delta * 10.0)
		leg_right.rotation.x = move_toward(leg_right.rotation.x, 0, delta * 10.0)

	# Обновляем HUD каждый кадр
	if hud:
		hud.update_energy(energy, 100.0)
		
	move_and_slide()


func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer and is_multiplayer_authority():
		# Отправляем позицию и поворот всем игрокам 20 раз в секунду
		_sync_transform.rpc(global_position, rotation.y, head.rotation.x)

@rpc("any_peer", "unreliable")
func _sync_transform(pos: Vector3, body_y: float, head_x: float) -> void:
	if not is_multiplayer_authority():
		# Плавная интерполяция для других игроков
		global_position = global_position.lerp(pos, 0.3)
		rotation.y = lerp_angle(rotation.y, body_y, 0.3)
		head.rotation.x = lerp(head.rotation.x, head_x, 0.3)
