extends Node

## Network Manager for CyberHorde Co-op
## Manages ENet multiplayer peer, hosting, joining, peer discovery, and co-op game states.

signal connection_status_changed(status_text: String)
signal peer_connected_signal(peer_id: int)
signal peer_disconnected_signal(peer_id: int)
signal peer_class_updated(peer_id: int, new_class: String)
signal game_started()
signal game_reset_signal()
signal mission_toast(message: String)

enum NetworkRole { NONE, SINGLEPLAYER, HOST, CLIENT }
var current_role: NetworkRole = NetworkRole.NONE

var is_multiplayer: bool = false
var is_server: bool = false
var server_port: int = 7777
var max_clients: int = 4

var local_peer_id: int = 1
var connected_peers: Array[int] = []

# Player profiles (peer_id -> info dict)
var players_info: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			return ip
	return "127.0.0.1"

func start_singleplayer() -> void:
	cleanup_network()
	current_role = NetworkRole.SINGLEPLAYER
	is_multiplayer = false
	is_server = true
	local_peer_id = 1
	connected_peers = [1]
	players_info[1] = {"name": "Player 1", "color": Color(0, 0.95, 1.0), "class": GameManager.player_class}

func start_host(port: int = 7777) -> Error:
	cleanup_network()
	server_port = port
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(server_port, max_clients)
	if error != OK:
		connection_status_changed.emit("Failed to create server on port %d (Error: %s)" % [server_port, error])
		return error
	
	multiplayer.multiplayer_peer = peer
	current_role = NetworkRole.HOST
	is_multiplayer = true
	is_server = true
	local_peer_id = 1
	connected_peers = [1]
	players_info[1] = {"name": "Host (P1)", "color": Color(0, 0.95, 1.0), "class": GameManager.player_class}
	
	var local_ip = get_local_ip()
	connection_status_changed.emit("Hosting co-op on %s:%d. Waiting for teammates..." % [local_ip, server_port])
	return OK

func join_host(ip: String = "127.0.0.1", port: int = 7777) -> Error:
	cleanup_network()
	if ip.strip_edges().is_empty():
		ip = "127.0.0.1"
	server_port = port
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, server_port)
	if error != OK:
		connection_status_changed.emit("Failed to initialize connection to %s:%d" % [ip, server_port])
		return error
	
	multiplayer.multiplayer_peer = peer
	current_role = NetworkRole.CLIENT
	is_multiplayer = true
	is_server = false
	
	connection_status_changed.emit("Connecting to %s:%d..." % [ip, server_port])
	return OK

func cleanup_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	connected_peers.clear()
	players_info.clear()
	current_role = NetworkRole.NONE
	is_multiplayer = false
	is_server = false

func _on_peer_connected(peer_id: int) -> void:
	if not connected_peers.has(peer_id):
		connected_peers.append(peer_id)
	
	var p_name = "Player %d" % peer_id if peer_id != 1 else "Host"
	players_info[peer_id] = {
		"name": p_name,
		"color": Color(1.0, 0.5, 0.08) if peer_id != 1 else Color(0, 0.95, 1.0),
		"class": "medic"
	}
	
	# Broadcast own class to new peer
	if is_multiplayer:
		rpc_set_player_class.rpc(local_peer_id, GameManager.player_class)
	
	connection_status_changed.emit("Player %d joined the squad!" % peer_id)
	peer_connected_signal.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	players_info.erase(peer_id)
	connection_status_changed.emit("Player %d disconnected." % peer_id)
	peer_disconnected_signal.emit(peer_id)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	if not connected_peers.has(1):
		connected_peers.append(1)
	if not connected_peers.has(local_peer_id):
		connected_peers.append(local_peer_id)
	
	connection_status_changed.emit("Connected to Host! Waiting for Host to launch mission...")

func _on_connection_failed() -> void:
	cleanup_network()
	connection_status_changed.emit("Connection failed! Verify Host IP and port.")

func _on_server_disconnected() -> void:
	cleanup_network()
	connection_status_changed.emit("Host closed the server.")

# RPC to start the game synchronously for all connected peers
@rpc("call_local", "reliable")
func rpc_start_game() -> void:
	game_started.emit()

# RPC for toast notifications across the squad
@rpc("call_local", "reliable")
func rpc_toast(message: String) -> void:
	mission_toast.emit(message)

func set_local_class(p_class: String) -> void:
	GameManager.player_class = p_class
	if not players_info.has(local_peer_id):
		players_info[local_peer_id] = {}
	players_info[local_peer_id]["class"] = p_class
	peer_class_updated.emit(local_peer_id, p_class)
	if is_multiplayer:
		rpc_set_player_class.rpc(local_peer_id, p_class)

@rpc("any_peer", "call_local", "reliable")
func rpc_set_player_class(peer_id: int, p_class: String) -> void:
	if not players_info.has(peer_id):
		players_info[peer_id] = {}
	players_info[peer_id]["class"] = p_class
	peer_class_updated.emit(peer_id, p_class)

func get_player_class(peer_id: int) -> String:
	return players_info.get(peer_id, {}).get("class", GameManager.player_class)

func get_all_classes() -> Dictionary:
	var res: Dictionary = {}
	for p_id in connected_peers:
		res[p_id] = get_player_class(p_id)
	return res
