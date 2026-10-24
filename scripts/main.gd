extends Node3D

@onready var arena: Node3D = $Arena
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var lobby_menu: CanvasLayer = $LobbyMenu
@onready var players_container: Node3D = $Players

const PLAYER_SCENE = preload("res://scenes/player/player.tscn")

func _ready() -> void:
	if lobby_menu:
		lobby_menu.mission_started.connect(_on_mission_started)
	
	NetworkManager.peer_connected_signal.connect(_on_peer_connected)
	NetworkManager.peer_disconnected_signal.connect(_on_peer_disconnected)

func _on_mission_started() -> void:
	_spawn_all_players()
	if hud and spawner:
		hud.connect_spawner(spawner)
	if spawner:
		spawner.start_spawner()

func _spawn_all_players() -> void:
	for child in players_container.get_children():
		child.queue_free()
	
	if not NetworkManager.is_multiplayer:
		_spawn_player(1, Vector3(0, 4.5, 0))
	else:
		for p_id in NetworkManager.connected_peers:
			var pos = Vector3(-2.5, 4.5, 0) if p_id == 1 else Vector3(2.5, 4.5, 0)
			_spawn_player(p_id, pos)

func _spawn_player(id: int, spawn_pos: Vector3) -> CharacterBody3D:
	if players_container.has_node(str(id)):
		return players_container.get_node(str(id)) as CharacterBody3D
	
	var p = PLAYER_SCENE.instantiate()
	p.name = str(id)
	players_container.add_child(p)
	p.global_position = spawn_pos
	p.setup_peer(id)
	
	if p.is_local_player and hud:
		hud.connect_player(p)
	
	return p

func _on_peer_connected(peer_id: int) -> void:
	if NetworkManager.is_server:
		var pos = Vector3(2.5, 4.5, 0)
		_spawn_player(peer_id, pos)
		rpc_client_sync_players.rpc(NetworkManager.connected_peers)

@rpc("reliable")
func rpc_client_sync_players(peers_list: Array) -> void:
	for p_id in peers_list:
		var pos = Vector3(-2.5, 4.5, 0) if p_id == 1 else Vector3(2.5, 4.5, 0)
		_spawn_player(p_id, pos)

func _on_peer_disconnected(peer_id: int) -> void:
	if players_container.has_node(str(peer_id)):
		players_container.get_node(str(peer_id)).queue_free()
