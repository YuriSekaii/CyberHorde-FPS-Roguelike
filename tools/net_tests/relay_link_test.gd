extends SceneTree

const RelayPeer = preload("res://scripts/network/relay_peer.gd")

var role: String = OS.get_environment("ROLE")
var peer
var t: float = 0.0
var sent: bool = false
var send_at: float = float(OS.get_environment("SEND_AT")) if OS.has_environment("SEND_AT") else 8.0
var secs: float = float(OS.get_environment("SECS")) if OS.has_environment("SECS") else (14.0 if OS.get_environment("ROLE") == "host" else 12.0)
var codefile: String = OS.get_environment("CODEFILE")

func _init() -> void:
	peer = RelayPeer.new()
	var url := OS.get_environment("URL")
	if role == "host":
		peer.lobby_ready.connect(func(code, _id):
			var f := FileAccess.open(codefile, FileAccess.WRITE)
			f.store_string(code)
			f.close()
			print("host lobby ", code))
		peer.create_lobby(url)
	else:
		var code := FileAccess.get_file_as_string(codefile).strip_edges()
		peer.join_lobby(url, code)
	var mp = get_multiplayer()
	mp.multiplayer_peer = peer
	mp.peer_packet.connect(func(id, data): print("%s GOT from %d: %s" % [role, id, data.get_string_from_utf8()]))

func _process(delta: float) -> bool:
	t += delta
	var mp = get_multiplayer()
	if t > send_at and not sent:
		sent = true
		var target := 2 if role == "host" else 1
		mp.send_bytes((role + "-rel").to_utf8_buffer(), target, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		mp.send_bytes((role + "-unrel").to_utf8_buffer(), target, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	return t > secs
