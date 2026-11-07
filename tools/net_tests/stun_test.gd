extends SceneTree

const StunProbe = preload("res://scripts/network/stun_probe.gd")

func _init() -> void:
	var p = StunProbe.new()
	var err = p.start()
	if err != OK:
		print("start failed: ", err)
		quit(1)
		return
	while not p.done:
		OS.delay_msec(20)
		p.poll()
	print("kind=%s ip=%s ports=%s local=%d" % [p.kind, p.public_ip, p.mapped_ports, p.local_port])
	p.close()
	quit(0 if not p.public_ip.is_empty() else 1)
