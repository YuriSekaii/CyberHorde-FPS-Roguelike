extends RefCounted

## Learns this PC's public IPv4 and NAT kind from one UDP socket (STUN, RFC 5389).
## "fixed" = both servers saw the same outside port, "random" = they differ.

const SERVERS: Array = [["stun.l.google.com", 19302], ["stun.cloudflare.com", 3478]]
const COOKIE: int = 0x2112A442

var done: bool = false
var public_ip: String = ""
var mapped_ports: Array[int] = []
var local_port: int = 0
var kind: String = "unknown"

var _sock := PacketPeerUDP.new()
var _dests: Array = []  # [ip, port, txid, answered]
var _t0: int = 0
var _last_send: int = 0

func start(p_local_port: int = 0) -> Error:
	var err := _sock.bind(p_local_port, "*")
	if err != OK:
		done = true
		return err
	local_port = _sock.get_local_port()
	for s in SERVERS:
		var ip := IP.resolve_hostname(s[0], IP.TYPE_IPV4)
		if ip.is_empty():
			continue
		var tx := PackedByteArray()
		for i in 12:
			tx.append(randi() & 0xFF)
		_dests.append([ip, s[1], tx, false])
	_t0 = Time.get_ticks_msec()
	if _dests.is_empty():
		done = true
		return ERR_CANT_RESOLVE
	_send_all()
	return OK

func _send_all() -> void:
	_last_send = Time.get_ticks_msec()
	for d in _dests:
		if d[3]:
			continue
		var req := PackedByteArray([0, 1, 0, 0, 0x21, 0x12, 0xA4, 0x42])
		req.append_array(d[2])
		_sock.set_dest_address(d[0], d[1])
		_sock.put_packet(req)

func poll() -> void:
	if done:
		return
	while _sock.get_available_packet_count() > 0:
		var pkt := _sock.get_packet()
		if _sock.get_packet_error() == OK:
			_parse(pkt)
	var now := Time.get_ticks_msec()
	var answered := 0
	for d in _dests:
		if d[3]:
			answered += 1
	if answered == _dests.size() or now - _t0 > 3000:
		_finish()
	elif now - _last_send >= 500:
		_send_all()

func _parse(pkt: PackedByteArray) -> void:
	if pkt.size() < 20 or pkt[0] != 0x01 or pkt[1] != 0x01:
		return
	var tx := pkt.slice(8, 20)
	for d in _dests:
		if d[3] or d[2] != tx:
			continue
		var i := 20
		while i + 4 <= pkt.size():
			var t := (pkt[i] << 8) | pkt[i + 1]
			var l := (pkt[i + 2] << 8) | pkt[i + 3]
			if (t == 0x0020 or t == 0x0001) and l >= 8 and pkt[i + 5] == 1 and i + 4 + l <= pkt.size():
				var xor := 0x2112A442 if t == 0x0020 else 0
				var port := ((pkt[i + 6] << 8) | pkt[i + 7]) ^ (xor >> 16)
				var a: Array[int] = []
				for k in 4:
					a.append(pkt[i + 8 + k] ^ ((xor >> (24 - 8 * k)) & 0xFF))
				public_ip = "%d.%d.%d.%d" % [a[0], a[1], a[2], a[3]]
				d[3] = true
				mapped_ports.append(port)
				if t == 0x0020:
					return
			i += 4 + ((l + 3) & ~3)
		return

func _finish() -> void:
	done = true
	if mapped_ports.size() >= 2:
		kind = "fixed" if mapped_ports[0] == mapped_ports[1] else "random"

## Hands the still-bound socket to the caller (this object forgets it).
func take_socket() -> PacketPeerUDP:
	var s := _sock
	_sock = PacketPeerUDP.new()
	return s

func close() -> void:
	_sock.close()
