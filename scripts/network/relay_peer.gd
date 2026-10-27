extends MultiplayerPeerExtension

## Online co-op transport: tunnels Godot high-level multiplayer through the
## CyberHorde lobby relay (server/lobby_relay.py) over a single WebSocket.
## The lobby creator is peer 1 (authoritative host); joiners get ids 2..4.
## Binary frames carry an int32 LE header: target on send, source on receive.

signal lobby_ready(code: String, peer_id: int)
signal lobby_error(message: String)

const MAX_PACKET_SIZE: int = 1 << 20

var ws := WebSocketPeer.new()
var lobby_code: String = ""
var _want_create: bool = false
var _join_code: String = ""
var _sent_hello: bool = false
var _last_error: String = ""

var _unique_id: int = 0
var _status: ConnectionStatus = CONNECTION_DISCONNECTED
var _target_peer: int = 0
var _transfer_mode: TransferMode = TRANSFER_MODE_RELIABLE
var _transfer_channel: int = 0
var _refusing: bool = false
var _peers: Array[int] = []

# Incoming packet queue: each entry is [source_peer_id, payload]
var _incoming: Array = []
var _current_packet: Array = [1, PackedByteArray()]

func create_lobby(url: String) -> Error:
	_want_create = true
	return _open(url)

func join_lobby(url: String, code: String) -> Error:
	_join_code = code.strip_edges().to_upper()
	return _open(url)

func _open(url: String) -> Error:
	ws.inbound_buffer_size = MAX_PACKET_SIZE
	ws.outbound_buffer_size = MAX_PACKET_SIZE
	ws.max_queued_packets = 8192
	var err = ws.connect_to_url(url)
	if err == OK:
		_status = CONNECTION_CONNECTING
	return err

func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	ws.poll()
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _sent_hello:
		_sent_hello = true
		if _want_create:
			ws.send_text(JSON.stringify({"op": "create"}))
		else:
			ws.send_text(JSON.stringify({"op": "join", "code": _join_code}))
	# Drain even when closing: a "lobby full" error and the close can land in the same poll.
	while ws.get_available_packet_count() > 0:
		var data: PackedByteArray = ws.get_packet()
		if ws.was_string_packet():
			_handle_control(data.get_string_from_utf8())
		elif data.size() >= 4 and _status == CONNECTION_CONNECTED:
			_incoming.append([data.decode_s32(0), data.slice(4)])
	if state == WebSocketPeer.STATE_CLOSED:
		if _status == CONNECTION_CONNECTING:
			if _last_error.is_empty():
				_last_error = ws.get_close_reason()
			lobby_error.emit(_last_error if not _last_error.is_empty() else "Could not reach the online lobby server.")
		_shutdown()

func _handle_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match msg.get("op", ""):
		"created", "joined":
			lobby_code = msg.get("code", "")
			_unique_id = int(msg.get("id", 0))
			_status = CONNECTION_CONNECTED
			for p in msg.get("peers", []):
				_add_peer(int(p))
			lobby_ready.emit(lobby_code, _unique_id)
		"peer_connected":
			_add_peer(int(msg.get("id", 0)))
		"peer_disconnected":
			var pid = int(msg.get("id", 0))
			if _peers.has(pid):
				_peers.erase(pid)
				peer_disconnected.emit(pid)
		"error":
			# The relay closes the socket right after; reported once the close lands.
			_last_error = str(msg.get("msg", "Lobby error."))

func _add_peer(pid: int) -> void:
	if pid > 0 and pid != _unique_id and not _peers.has(pid):
		_peers.append(pid)
		peer_connected.emit(pid)

func _shutdown() -> void:
	_status = CONNECTION_DISCONNECTED
	for pid in _peers.duplicate():
		peer_disconnected.emit(pid)
	_peers.clear()
	_incoming.clear()

func _close() -> void:
	ws.close(1000, "bye")
	_shutdown()

func _disconnect_peer(p_peer: int, _p_force: bool) -> void:
	if _unique_id == 1 and _status == CONNECTION_CONNECTED:
		ws.send_text(JSON.stringify({"op": "kick", "id": p_peer}))

func _get_available_packet_count() -> int:
	return _incoming.size()

func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	_current_packet = _incoming.pop_front()
	return _current_packet[1]

func _put_packet_script(p_buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var frame := PackedByteArray()
	frame.resize(4)
	frame.encode_s32(0, _target_peer)
	frame.append_array(p_buffer)
	return ws.send(frame)

func _get_packet_peer() -> int:
	# SceneMultiplayer queries the sender before popping the packet, so peek the head.
	return _incoming[0][0] if not _incoming.is_empty() else _current_packet[0]

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> TransferMode:
	# WebSocket is TCP: everything arrives reliable and ordered.
	return TRANSFER_MODE_RELIABLE

func _get_max_packet_size() -> int:
	return MAX_PACKET_SIZE - 4

func _set_transfer_channel(p_channel: int) -> void:
	_transfer_channel = p_channel

func _get_transfer_channel() -> int:
	return _transfer_channel

func _set_transfer_mode(p_mode: TransferMode) -> void:
	_transfer_mode = p_mode

func _get_transfer_mode() -> TransferMode:
	return _transfer_mode

func _set_target_peer(p_peer: int) -> void:
	_target_peer = p_peer

func _get_unique_id() -> int:
	return _unique_id

func _is_server() -> bool:
	return _unique_id == 1

func _is_server_relay_supported() -> bool:
	# The lobby relay already routes packets directly between any two members.
	return false

func _set_refuse_new_connections(p_enable: bool) -> void:
	_refusing = p_enable
	if _unique_id == 1 and _status == CONNECTION_CONNECTED:
		ws.send_text(JSON.stringify({"op": "lock", "locked": p_enable}))

func _is_refusing_new_connections() -> bool:
	return _refusing

func _get_connection_status() -> ConnectionStatus:
	return _status
