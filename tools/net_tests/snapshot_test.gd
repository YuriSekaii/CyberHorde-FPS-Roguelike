extends SceneTree

const RelayPeer = preload("res://scripts/network/relay_peer.gd")
const SnapshotNode = preload("res://tools/net_tests/snapshot_node.gd")
const EnemySnapshot = preload("res://scripts/network/enemy_snapshot.gd")

var role: String = OS.get_environment("ROLE")
var peer
var snap
var t: float = 0.0
var send_at: float = float(OS.get_environment("SEND_AT")) if OS.has_environment("SEND_AT") else 8.0
var secs: float = float(OS.get_environment("SECS")) if OS.has_environment("SECS") else (14.0 if OS.get_environment("ROLE") == "host" else 12.0)
var codefile: String = OS.get_environment("CODEFILE")
var next_send: float = 0.0
var tick: int = 0
var host_chunks_per_tick: int = 0
var host_max_chunk_bytes: int = 0
var host_printed: bool = false

func _initialize() -> void:
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
	snap = SnapshotNode.new()
	snap.name = "Snap"
	root.add_child(snap)

func _process(delta: float) -> bool:
	t += delta
	if role == "host":
		var mp = get_multiplayer()
		if mp.get_unique_id() == 1 and t >= send_at and t < send_at + 5.0:
			if t >= next_send:
				next_send = t + 0.1
				tick += 1
				_send_tick(tick)
		if t >= send_at + 5.0 and not host_printed and tick > 0:
			host_printed = true
			print("host chunks_per_tick=%d max_chunk_bytes=%d" % [host_chunks_per_tick, host_max_chunk_bytes])
	if t > secs:
		if role != "host":
			_print_result()
		return true
	return false

func _send_tick(tick: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var enemies: Array = []
	for i in range(1, 501):
		var pos = Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(0.0, 10.0), rng.randf_range(-40.0, 40.0))
		var yaw = rng.randf_range(0.0, TAU)
		enemies.append([i, pos, yaw])
	var chunks := EnemySnapshot.encode(enemies)
	var max_bytes := 0
	for chunk in chunks:
		max_bytes = max(max_bytes, chunk.size())
		snap.rpc_snap.rpc(tick, chunk)
	host_chunks_per_tick = chunks.size()
	host_max_chunk_bytes = max_bytes
	if not host_printed:
		host_printed = true
		print("host chunks_per_tick=%d max_chunk_bytes=%d" % [chunks.size(), max_bytes])

func _print_result() -> void:
	var ticks = snap.tick_count()
	var avg = snap.avg_enemies()
	var ok = ticks >= 40 and avg >= 450
	print("snapshot ticks=%d avg_enemies=%.1f/500 rx=%s" % [ticks, avg, str(peer.rx_stats)])
	quit(0 if ok else 1)
