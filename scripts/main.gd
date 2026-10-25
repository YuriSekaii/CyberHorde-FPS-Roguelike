extends Node3D

@onready var arena: Node3D = $Arena
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var lobby_menu: CanvasLayer = $LobbyMenu
@onready var players_container: Node3D = $Players

const PLAYER_SCENE = preload("res://scenes/player/player.tscn")

var is_mission_active: bool = false

func _ready() -> void:
	if lobby_menu:
		lobby_menu.mission_started.connect(_on_lobby_mission_started)
	
	NetworkManager.peer_connected_signal.connect(_on_peer_connected)
	NetworkManager.peer_disconnected_signal.connect(_on_peer_disconnected)

func _on_lobby_mission_started() -> void:
	if NetworkManager.is_multiplayer:
		if NetworkManager.is_server:
			# Server tells all peers to start the mission together
			rpc_start_mission.rpc(NetworkManager.connected_peers, GameManager.is_boss_battle_mode, NetworkManager.get_all_classes())
	else:
		_start_mission_local([1], {1: GameManager.player_class})

@rpc("call_local", "reliable")
func rpc_start_mission(peer_ids: Array, is_boss_mode: bool = false, classes_dict: Dictionary = {}) -> void:
	if is_boss_mode:
		GameManager.setup_boss_battle_mode()
	_start_mission_local(peer_ids, classes_dict)

func _start_mission_local(peer_ids: Array, classes_dict: Dictionary = {}) -> void:
	is_mission_active = true
	
	if lobby_menu:
		lobby_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Cleanly remove any old nodes immediately from the tree
	for child in players_container.get_children():
		players_container.remove_child(child)
		child.queue_free()
	
	# Spawn all squad members
	for i in range(peer_ids.size()):
		var p_id = int(peer_ids[i])
		var p_cls = String(classes_dict.get(p_id, GameManager.player_class))
		var spawn_pos = Vector3(-2.5 if i == 0 else 2.5, 4.5, 0.0)
		_instantiate_player(p_id, spawn_pos, p_cls)
	
	if hud and spawner:
		hud.connect_spawner(spawner)
	if spawner:
		spawner.start_spawner()

func _instantiate_player(id: int, spawn_pos: Vector3, p_class: String = "") -> CharacterBody3D:
	var node_name = "Player_%d" % id
	if players_container.has_node(node_name):
		return players_container.get_node(node_name) as CharacterBody3D
	
	var p = PLAYER_SCENE.instantiate()
	p.name = node_name
	players_container.add_child(p)
	p.global_position = spawn_pos
	p.setup_peer(id, p_class)
	
	if p.is_local_player and hud:
		hud.connect_player(p)
	
	return p

func _on_peer_connected(peer_id: int) -> void:
	# Only spawn late-joining players if the mission has already started
	if is_mission_active and NetworkManager.is_server:
		rpc_spawn_late_peer.rpc(peer_id, Vector3(2.5, 4.5, 0.0))

@rpc("call_local", "reliable")
func rpc_spawn_late_peer(peer_id: int, spawn_pos: Vector3) -> void:
	if is_mission_active:
		_instantiate_player(peer_id, spawn_pos)

func _on_peer_disconnected(peer_id: int) -> void:
	var node_name = "Player_%d" % peer_id
	if players_container.has_node(node_name):
		var p = players_container.get_node(node_name)
		players_container.remove_child(p)
		p.queue_free()
