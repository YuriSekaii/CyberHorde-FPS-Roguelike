extends SceneTree

const UdpPunch = preload("res://scripts/network/udp_punch.gd")

func _attempt(tok: int) -> bool:
	var sock := PacketPeerUDP.new()
	if sock.bind(47990, "*") != OK:
		print("cannot bind 47990")
		return false
	var r = UdpPunch.new()
	r.start_random("127.0.0.1", 47990, tok)
	var f = UdpPunch.new()
	f.start_fixed(sock, "127.0.0.1", tok)
	var t0 := Time.get_ticks_msec()
	while (r.state == "running" or f.state == "running") and Time.get_ticks_msec() - t0 < 15000:
		OS.delay_msec(10)
		r.poll()
		f.poll()
	print("random=%s fixed=%s hole=%d->%d probes=%d ms=%d" % [r.state, f.state, f.local_port, f.remote_port, f.probes_sent, Time.get_ticks_msec() - t0])
	var ok: bool = r.state == "done" and f.state == "done" and r.local_port == f.remote_port and f.local_port == r.remote_port
	r.close()
	f.close()
	return ok

func _init() -> void:
	var tok := randi()
	var ok := _attempt(tok)
	if not ok:
		OS.delay_msec(300)
		ok = _attempt(tok)
	quit(0 if ok else 1)
