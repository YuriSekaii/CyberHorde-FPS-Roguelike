extends RefCounted

## Birthday UDP hole punch to one peer (design: Parsec Copy REPORT.md section 4).
## random side: 800 sockets each announce to the fixed side's exact ip:port.
## fixed side: 300 probes from one port to random ports on the random side's IP.
## Packet = 0xFF 'C' 'H' + type (1 announce, 2 probe, 3 ack) + u32 token (LE).

const SOCKETS: int = 800
const PROBES: int = 300
const PROBE_RATE: int = 30  # probes per second
const TIMEOUT_MSEC: int = 12000
const LINGER_MSEC: int = 1000

var state: String = "running"
var local_port: int = 0
var remote_ip: String = ""
var remote_port: int = 0

var _socks: Array[PacketPeerUDP] = []
var _peer_ip: String = ""
var _token: int = 0
var _mode: String = ""
var _t0: int = 0
var _sent: int = 0
var _last_direct: int = 0
var _direct_port: int = 0
var _hit_at: int = 0
var _hit_sock: PacketPeerUDP = null
var probes_sent: int = 0

func _packet(type: int) -> PackedByteArray:
	var p := PackedByteArray([0xFF, 0x43, 0x48, type, 0, 0, 0, 0])
	p.encode_u32(4, _token)
	return p

func _send(sock: PacketPeerUDP, ip: String, port: int, type: int) -> void:
	sock.set_dest_address(ip, port)
	sock.put_packet(_packet(type))

func start_random(peer_ip: String, peer_port: int, token: int) -> void:
	_begin("random", peer_ip, token)
	for i in SOCKETS:
		var s := PacketPeerUDP.new()
		if s.bind(0, "*") != OK:
			continue
		_socks.append(s)
		_send(s, peer_ip, peer_port, 1)

func start_fixed(sock: PacketPeerUDP, peer_ip: String, token: int) -> void:
	_begin("fixed", peer_ip, token)
	_socks.append(sock)

func start_direct(sock: PacketPeerUDP, peer_ip: String, peer_port: int, token: int) -> void:
	_begin("direct", peer_ip, token)
	_direct_port = peer_port
	_socks.append(sock)

func _begin(mode: String, peer_ip: String, token: int) -> void:
	_mode = mode
	_peer_ip = peer_ip
	_token = token
	_t0 = Time.get_ticks_msec()

func poll() -> void:
	if state != "running":
		return
	var now := Time.get_ticks_msec()
	if _hit_at == 0:
		if now - _t0 > TIMEOUT_MSEC:
			state = "failed"
			return
		if _mode == "fixed":
			var due := mini(PROBES, (now - _t0) * PROBE_RATE / 1000 + 1)
			while _sent < due:
				_sent += 1
				_send(_socks[0], _peer_ip, randi_range(1024, 65535), 2)
			probes_sent = _sent
		elif _mode == "direct" and now - _last_direct >= 100:
			_last_direct = now
			_send(_socks[0], _peer_ip, _direct_port, 2)
	for s in _socks:
		while s.get_available_packet_count() > 0:
			var pkt := s.get_packet()
			if s.get_packet_error() != OK or pkt.size() < 8:
				continue
			if pkt[0] != 0xFF or pkt[1] != 0x43 or pkt[2] != 0x48 or pkt.decode_u32(4) != _token:
				continue
			if s.get_packet_ip() != _peer_ip:
				continue
			var type := pkt[3]
			if type == 2:
				for i in 3:
					_send(s, s.get_packet_ip(), s.get_packet_port(), 3)
			if (type == 2 or type == 3) and _hit_at == 0:
				_hit_at = now
				_hit_sock = s
				local_port = s.get_local_port()
				remote_ip = s.get_packet_ip()
				remote_port = s.get_packet_port()
				if _mode != "random":
					state = "done"
	# The random side lingers so the fixed side surely gets an ack.
	if _mode == "random" and _hit_at > 0 and now - _hit_at >= LINGER_MSEC:
		state = "done"

## Closes every socket so the caller can rebind local_port.
func close() -> void:
	for s in _socks:
		s.close()
	_socks.clear()

## After state "done": closes every other socket, returns the one that got the hit
## (destination already set to the remote), or null.
func take_hit_socket() -> PacketPeerUDP:
	var hit := _hit_sock
	for s in _socks:
		if s != hit:
			s.close()
	_socks.clear()
	_hit_sock = null
	if hit != null:
		hit.set_dest_address(remote_ip, remote_port)
	return hit
