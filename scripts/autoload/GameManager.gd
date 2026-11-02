extends Node

signal money_changed(amount: int)
signal dialogue_requested(lines: Array, speaker: String)

var current_mission_id: StringName = ""
var money: int = 1500
var kills: int = 0
var deaths: int = 0
var owned_weapons: Array = ["pistol", "rifle"]
var equipped_weapon: String = "pistol"
var progress: int = 0
var extra_ammo = {"pistol": 0, "rifle": 0, "shotgun": 0, "sniper": 0}

# НАСТРОЙКИ
var difficulty: int = 1
var mouse_sens: float = 0.002
var invert_y: bool = false
var hud_shake: bool = true

var window_mode: int = 0
var resolution: int = 0
var vsync: int = 0
var shadows: bool = true
var fov: float = 75.0

var volume_master: float = 1.0
var volume_music: float = 1.0
var volume_sfx: float = 1.0

# НОВЫЕ НАСТРОЙКИ (HUD и Интерфейс)
var show_fps: bool = false
var colorblind: bool = false
var crosshair_color: int = 0

const SAVE_PATH = "user://savegame.json"
const SETTINGS_PATH = "user://settings.cfg"

func _ready() -> void:
	load_settings()
	load_game()
	apply_settings()

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func save_game() -> void:
	var save_dict = {
		"money": money, "owned_weapons": owned_weapons, "equipped_weapon": equipped_weapon,
		"progress": progress
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json:
			money = int(json.get("money", 1500))
			progress = int(json.get("progress", 0))
			equipped_weapon = str(json.get("equipped_weapon", "pistol"))
			var loaded_weapons = json.get("owned_weapons", ["pistol", "rifle"])
			if loaded_weapons is Array:
				owned_weapons.clear()
				for w in loaded_weapons: owned_weapons.append(str(w))
			money_changed.emit(money)
		file.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save(): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	money = 1500
	owned_weapons = ["pistol", "rifle"]
	equipped_weapon = "rifle"
	progress = 0

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "mouse_sens", mouse_sens)
	config.set_value("game", "invert_y", invert_y)
	config.set_value("game", "hud_shake", hud_shake)
	
	config.set_value("graphics", "window_mode", window_mode)
	config.set_value("graphics", "resolution", resolution)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "fov", fov)
	
	config.set_value("sound", "volume_master", volume_master)
	config.set_value("sound", "volume_music", volume_music)
	config.set_value("sound", "volume_sfx", volume_sfx)
	
	config.set_value("hud", "show_fps", show_fps)
	config.set_value("hud", "colorblind", colorblind)
	config.set_value("hud", "crosshair_color", crosshair_color)
	
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		difficulty = config.get_value("game", "difficulty", 1)
		mouse_sens = config.get_value("game", "mouse_sens", 0.002)
		invert_y = config.get_value("game", "invert_y", false)
		hud_shake = config.get_value("game", "hud_shake", true)
		
		window_mode = config.get_value("graphics", "window_mode", 0)
		resolution = config.get_value("graphics", "resolution", 0)
		vsync = config.get_value("graphics", "vsync", 0)
		shadows = config.get_value("graphics", "shadows", true)
		fov = config.get_value("graphics", "fov", 75.0)
		
		volume_master = config.get_value("sound", "volume_master", 1.0)
		volume_music = config.get_value("sound", "volume_music", 1.0)
		volume_sfx = config.get_value("sound", "volume_sfx", 1.0)
		
		show_fps = config.get_value("hud", "show_fps", false)
		colorblind = config.get_value("hud", "colorblind", false)
		crosshair_color = config.get_value("hud", "crosshair_color", 0)

func apply_settings() -> void:
	if window_mode == 1:
		# В Godot 4 EXCLUSIVE_FULLSCREEN работает надежнее
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		match resolution:
			0: DisplayServer.window_set_size(Vector2i(1280, 720))
			1: DisplayServer.window_set_size(Vector2i(1920, 1080))
			2: DisplayServer.window_set_size(Vector2i(1600, 900))
				
	if vsync == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
	AudioServer.set_bus_volume_db(0, linear_to_db(volume_master))


func add_kill() -> void:
	kills += 1

func add_death() -> void:
	deaths += 1

func reset_stats() -> void:
	kills = 0
	deaths = 0
