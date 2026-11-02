extends Node

const BASE_PORT := 7777
const MAX_PEERS := 8

signal connection_failed()
signal connection_succeeded()
signal server_disconnected()
signal player_list_changed()
signal map_changed(map_id: String)
signal ready_changed(id: int, is_ready: bool)

var players = {}
var is_host = false
var chosen_map = "sklad"
var current_port = 7777

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host() -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = -1
	for p in range(BASE_PORT, BASE_PORT + 10):
		err = peer.create_server(p, MAX_PEERS)
		if err == OK:
			current_port = p
			break
	if err != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	players.clear()
	players[1] = {"name": "Хост", "ready": true}
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func join(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	var parts = ip.split(":")
	var addr = parts[0]
	var port = int(parts[1]) if parts.size() > 1 else BASE_PORT
	var err = peer.create_client(addr, port)
	if err != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_peer_connected(id: int) -> void:
	if is_host:
		players[id] = {"name": "Игрок_" + str(id), "ready": false}
		_sync_players.rpc(players)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_list_changed.emit()
	if is_host:
		_sync_players.rpc(players)

func _on_connected_to_server() -> void:
	connection_succeeded.emit()
	_register_player.rpc_id(1, "Игрок_" + str(multiplayer.get_unique_id()))

@rpc("any_peer", "reliable")
func _register_player(p_name: String) -> void:
	if not is_host: return
	var id = multiplayer.get_remote_sender_id()
	players[id] = {"name": p_name, "ready": false}
	_sync_players.rpc(players)

@rpc("authority", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	players = new_players
	player_list_changed.emit()

func change_map(map_id: String) -> void:
	if not is_host: return
	chosen_map = map_id
	_sync_map.rpc(chosen_map)

@rpc("authority", "reliable")
func _sync_map(map_id: String) -> void:
	chosen_map = map_id
	map_changed.emit(map_id)

func start_game() -> void:
	if not is_host: return
	_start_level.rpc()

@rpc("authority", "reliable")
func _start_level() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/Level_" + chosen_map.capitalize() + ".tscn")

func toggle_ready(is_ready: bool) -> void:
	if not is_host:
		_set_ready.rpc_id(1, multiplayer.get_unique_id(), is_ready)

@rpc("any_peer", "reliable")
func _set_ready(id: int, is_ready: bool) -> void:
	if not is_host: return
	if players.has(id):
		players[id]["ready"] = is_ready
		_sync_players.rpc(players)
		ready_changed.emit(id, is_ready)

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"
