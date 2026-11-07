extends Node

const EnemySnapshot = preload("res://scripts/network/enemy_snapshot.gd")

# tick -> {enemy_hash: true} of unique hashes decoded for that tick.
var per_tick: Dictionary = {}

@rpc("authority", "unreliable_ordered")
func rpc_snap(tick: int, data: PackedByteArray) -> void:
	var entries := EnemySnapshot.decode(data)
	if not per_tick.has(tick):
		per_tick[tick] = {}
	var set: Dictionary = per_tick.get(tick, {})
	for entry in entries:
		set[int(entry[0])] = true

func tick_count() -> int:
	return per_tick.size()

func avg_enemies() -> float:
	var total := 0
	for set in per_tick.values():
		total += set.size()
	var ticks := per_tick.size()
	if ticks == 0:
		return 0.0
	return float(total) / float(ticks)
