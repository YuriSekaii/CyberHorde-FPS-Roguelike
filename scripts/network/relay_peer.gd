extends MultiplayerPeerExtension

## Online co-op transport: tunnels Godot high-level multiplayer through the
## CyberHorde lobby relay (server/lobby_relay.py) over a single WebSocket.
## The lobby creator is peer 1 (authoritative host); joiners get ids 2..4.
## Binary frames carry an int32 LE header: target on send, source on receive.

signal lobby_ready(code: String, peer_id: int)
signal lobby_error(message: String)

const MAX_PACKET_SIZE: int = 1 << 20
const ICE_SERVERS: Array = [{"urls": ["stun:stun.l.google.com:19302"]}]

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

# Optional direct WebRTC links: pid -> {"pc": WebRTCPeerConnection,
# "rel": WebRTCDataChannel, "unrel": WebRTCDataChannel, "direct": bool}.
# A peer without both channels open still goes through the WebSocket relay.
# shortcut: while a link switches from relay to direct, reliable packets already in
# flight on the relay can arrive after newer direct ones; links normally open in the
# lobby before the match, upgrade to a per-peer sequence number if desync shows.
var _rtc := {}

# Incoming packet queue: each entry is [source_peer_id, payload, transfer_mode]
var _incoming: Array = []
var _current_packet: Array = [1, PackedByteArray(), TRANSFER_MODE_RELIABLE]

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
			_incoming.append([data.decode_s32(0), data.slice(4), TRANSFER_MODE_RELIABLE])
	_poll_rtc()
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
			# The joiner offers to everyone already here; they answer on peer_connected.
			var is_join := str(msg.get("op", "")) == "joined"
			for p in msg.get("peers", []):
				var pid := int(p)
				_add_peer(pid)
				if is_join:
					_rtc_create(pid, true)
			lobby_ready.emit(lobby_code, _unique_id)
		"peer_connected":
			var pid := int(msg.get("id", 0))
			_add_peer(pid)
			_rtc_create(pid, false)
		"peer_disconnected":
			var pid := int(msg.get("id", 0))
			_rtc_drop(pid)
			if _peers.has(pid):
				_peers.erase(pid)
				peer_disconnected.emit(pid)
		"signal":
			var from := int(msg.get("from", 0))
			if from > 0 and from != _unique_id:
				if not _rtc.has(from):
					_rtc_create(from, false)
				_rtc_handle_signal(from, msg.get("data", {}))
		"error":
			# The relay closes the socket right after; reported once the close lands.
			_last_error = str(msg.get("msg", "Lobby error."))

func _add_peer(pid: int) -> void:
	if pid > 0 and pid != _unique_id and not _peers.has(pid):
		_peers.append(pid)
		peer_connected.emit(pid)

func _shutdown() -> void:
	_status = CONNECTION_DISCONNECTED
	_rtc_clear()
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

func _rtc_create(pid: int, offer: bool) -> void:
	if pid <= 0 or pid == _unique_id or _rtc.has(pid):
		return
	var pc := WebRTCPeerConnection.new()
	if pc.initialize({"iceServers": ICE_SERVERS}) != OK:
		return
	var rel := pc.create_data_channel("rel", {"negotiated": true, "id": 1})
	var unrel := pc.create_data_channel("unrel", {"negotiated": true, "id": 2, "ordered": true, "maxRetransmits": 0})
	_rtc[pid] = {"pc": pc, "rel": rel, "unrel": unrel, "direct": false}
	pc.session_description_created.connect(_rtc_on_sdp.bind(pid))
	pc.ice_candidate_created.connect(_rtc_on_ice.bind(pid))
	if offer:
		pc.create_offer()

func _rtc_drop(pid: int) -> void:
	if not _rtc.has(pid):
		return
	var entry: Dictionary = _rtc[pid]
	var rel: WebRTCDataChannel = entry.get("rel")
	var unrel: WebRTCDataChannel = entry.get("unrel")
	var pc: WebRTCPeerConnection = entry.get("pc")
	if rel:
		rel.close()
	if unrel:
		unrel.close()
	if pc:
		pc.close()
	_rtc.erase(pid)

func _rtc_clear() -> void:
	for pid in _rtc.keys():
		_rtc_drop(int(pid))

func _rtc_on_sdp(type: String, sdp: String, pid: int) -> void:
	if not _rtc.has(pid):
		return
	var pc: WebRTCPeerConnection = _rtc[pid]["pc"]
	pc.set_local_description(type, sdp)
	_rtc_send_signal(pid, {"t": type, "sdp": sdp})

func _rtc_on_ice(mid: String, index: int, name: String, pid: int) -> void:
	_rtc_send_signal(pid, {"t": "ice", "mid": mid, "index": index, "name": name})

func _rtc_send_signal(pid: int, data: Dictionary) -> void:
	if _status == CONNECTION_CONNECTED:
		ws.send_text(JSON.stringify({"op": "signal", "to": pid, "data": data}))

func _rtc_handle_signal(pid: int, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not _rtc.has(pid):
		return
	var pc: WebRTCPeerConnection = _rtc[pid]["pc"]
	match str(data.get("t", "")):
		"offer":
			# Godot generates the answer itself (session_description_created fires)
			pc.set_remote_description("offer", str(data.get("sdp", "")))
		"answer":
			pc.set_remote_description("answer", str(data.get("sdp", "")))
		"ice":
			pc.add_ice_candidate(str(data.get("mid", "")), int(data.get("index", 0)), str(data.get("name", "")))

func _rtc_is_open(pid: int) -> bool:
	if not _rtc.has(pid):
		return false
	var entry: Dictionary = _rtc[pid]
	if not entry.get("direct", false):
		return false
	var rel: WebRTCDataChannel = entry.get("rel")
	var unrel: WebRTCDataChannel = entry.get("unrel")
	return (
		rel != null and unrel != null
		and rel.get_ready_state() == WebRTCDataChannel.STATE_OPEN
		and unrel.get_ready_state() == WebRTCDataChannel.STATE_OPEN
	)

func _rtc_send(pid: int, payload: PackedByteArray) -> void:
	var entry: Dictionary = _rtc.get(pid, {})
	var ch: WebRTCDataChannel
	if _transfer_mode == TRANSFER_MODE_RELIABLE:
		ch = entry.get("rel")
	else:
		ch = entry.get("unrel")
	if ch:
		ch.put_packet(payload)

func _poll_rtc() -> void:
	for pid in _rtc.keys():
		var entry: Dictionary = _rtc[pid]
		var pc: WebRTCPeerConnection = entry["pc"]
		pc.poll()
		var state := pc.get_connection_state()
		if state == WebRTCPeerConnection.STATE_FAILED or state == WebRTCPeerConnection.STATE_CLOSED:
			_rtc_drop(int(pid))
			continue
		var rel: WebRTCDataChannel = entry.get("rel")
		var unrel: WebRTCDataChannel = entry.get("unrel")
		if rel:
			rel.poll()
		if unrel:
			unrel.poll()
		var rel_open := rel != null and rel.get_ready_state() == WebRTCDataChannel.STATE_OPEN
		var unrel_open := unrel != null and unrel.get_ready_state() == WebRTCDataChannel.STATE_OPEN
		if rel_open:
			while rel.get_available_packet_count() > 0:
				_incoming.append([int(pid), rel.get_packet(), TRANSFER_MODE_RELIABLE])
		if unrel_open:
			while unrel.get_available_packet_count() > 0:
				_incoming.append([int(pid), unrel.get_packet(), TRANSFER_MODE_UNRELIABLE_ORDERED])
		if rel_open and unrel_open and not entry.get("direct", false):
			entry["direct"] = true
			print("[net] direct link to peer %d" % int(pid))

func _send_relay(target: int, payload: PackedByteArray) -> void:
	var frame := PackedByteArray()
	frame.resize(4)
	frame.encode_s32(0, target)
	frame.append_array(payload)
	ws.send(frame)

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
	var targets: Array[int] = []
	if _target_peer == 0:
		for pid in _peers:
			targets.append(pid)
	elif _target_peer > 0:
		if _target_peer != _unique_id:
			targets.append(_target_peer)
	else:
		var exclude := -_target_peer
		for pid in _peers:
			if pid != exclude:
				targets.append(pid)
	if targets.is_empty():
		return OK
	var relayed: Array[int] = []
	for pid in targets:
		if _rtc_is_open(pid):
			_rtc_send(pid, p_buffer)
		else:
			relayed.append(pid)
	if relayed.size() == targets.size():
		_send_relay(_target_peer, p_buffer)
	else:
		for pid in relayed:
			_send_relay(pid, p_buffer)
	return OK

func _get_packet_peer() -> int:
	# SceneMultiplayer queries the sender before popping the packet, so peek the head.
	return _incoming[0][0] if not _incoming.is_empty() else _current_packet[0]

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> TransferMode:
	# Relay frames are TCP; direct channels keep the mode they were sent with.
	return _current_packet[2]

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
