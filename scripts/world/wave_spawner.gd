extends Node3D

signal wave_progress(enemies_remaining: int, total_enemies: int)
signal intermission_tick(seconds_left: int)

const SWARMER_SCENE = preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")
const BRUTE_SCENE = preload("res://scenes/enemies/brute.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const CHARGER_SCENE = preload("res://scenes/enemies/charger.tscn")
const SPAWNER_ENEMY_SCENE = preload("res://scenes/enemies/spawner.tscn")
const BOMBER_SCENE = preload("res://scenes/enemies/bomber.tscn")
const HORNET_SCENE = preload("res://scenes/enemies/hornet.tscn")
# Stage 2 (Night Jungle) roster
const SPIDER_SCENE = preload("res://scenes/enemies/spider.tscn")
const WYVERN_SCENE = preload("res://scenes/enemies/wyvern.tscn")
const SLIME_SCENE = preload("res://scenes/enemies/slime.tscn")
const STALKER_SCENE = preload("res://scenes/enemies/stalker.tscn")
const SPORE_PIT_SCENE = preload("res://scenes/enemies/spore_pit.tscn")
const BLOOD_GHOUL_SCENE = preload("res://scenes/enemies/blood_ghoul.tscn")
const CHEST_SCENE = preload("res://scenes/loot/chest.tscn")
const SPAWN_INDICATOR_SCENE = preload("res://scenes/world/spawn_indicator.tscn")

const FINAL_WAVE: int = 50
const SPAWN_DELAY: float = 3.0
const MAX_CONCURRENT_ENEMIES: int = 40
# Upgraded basic units fully replace their predecessors after these waves
const BOMBER_AFTER_WAVE: int = 30
const HORNET_AFTER_WAVE: int = 40
# Stage 2 unlocks (unit appears from the wave after this one)
const WYVERN_AFTER_WAVE: int = 5
const SLIME_AFTER_WAVE: int = 10
const STALKER_AFTER_WAVE: int = 20
const SPORE_PIT_AFTER_WAVE: int = 30
const STAGE_TRANSITION_DELAY: float = 10.0

# Enemy type ids: 0=Swarmer, 1=Spitter, 2=Brute, 3=Apex Overlord, 4=Charger, 5=Void Spawner, 6=Bomber, 7=Hornet,
# 8=Shadow Spider, 9=Venom Wyvern, 10=Bog Slime, 11=Mantis Stalker, 12=Spore Pit, 13=Blood Ghoul
const TYPE_SPORE_PIT: int = 12
const TYPE_BLOOD_GHOUL: int = 13

var is_spawner_active: bool = false
var current_wave: int = 1
var is_wave_active: bool = false
var is_intermission: bool = false
var intermission_timer: float = 0.0

var total_enemies_in_wave: int = 0
var enemies_left_to_spawn: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var enemy_counter: int = 0
var last_sent_tick: int = -1

var active_enemies: Array[Node] = []
var pending_spawns: Array[Dictionary] = []
var boss_spawned_for_wave: bool = false
var active_boss: Node = null

func _ready() -> void:
	GameManager.enemy_killed.connect(_on_enemy_killed)
	GameManager.boss_defeated.connect(_on_boss_defeated)

func start_spawner() -> void:
	is_spawner_active = true
	last_sent_tick = -1
	pending_spawns.clear()
	boss_spawned_for_wave = false
	_clean_all_indicators()
	if GameManager.is_boss_battle_mode:
		current_wave = GameManager.current_wave
	else:
		current_wave = 1
	# In multiplayer, only server controls wave timers
	if not NetworkManager.is_multiplayer or NetworkManager.is_server:
		start_intermission(3.0 / GameManager.get_fever_spawn_rate_mult())

func get_effective_enemy_cap() -> int:
	return int(round(float(MAX_CONCURRENT_ENEMIES) * GameManager.get_fever_spawn_rate_mult()))

func get_effective_spawn_interval() -> float:
	return spawn_interval / GameManager.get_fever_spawn_rate_mult()

func _process(delta: float) -> void:
	if not is_spawner_active:
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	
	# Only server (or singleplayer) calculates wave logic
	if NetworkManager.is_multiplayer and not NetworkManager.is_server:
		return
	
	if is_intermission:
		intermission_timer -= delta
		var tick_sec = int(ceil(intermission_timer))
		if tick_sec != last_sent_tick:
			last_sent_tick = tick_sec
			if NetworkManager.is_multiplayer:
				rpc_intermission_tick.rpc(tick_sec)
			else:
				intermission_tick.emit(tick_sec)
			
		if intermission_timer <= 0.0:
			is_intermission = false
			_start_wave(current_wave)
		return
	
	if is_wave_active:
		# Queue up new enemy telegraphs only if active count is within concurrent capacity.
		# In Final Boss battle (current_wave >= FINAL_WAVE), enemies spawn infinitely until the Boss is defeated!
		_clean_dead_enemies()
		var current_active = active_enemies.size() + pending_spawns.size()
		var can_spawn: bool = (current_wave >= FINAL_WAVE or enemies_left_to_spawn > 0)
		if can_spawn and current_active < get_effective_enemy_cap():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = get_effective_spawn_interval()
				_spawn_one_enemy()
		
		# Process pending spawn delays (3.0s countdown)
		var i = pending_spawns.size() - 1
		while i >= 0:
			var p = pending_spawns[i]
			p.timer -= delta
			if p.timer <= 0.0:
				pending_spawns.remove_at(i)
				if NetworkManager.is_multiplayer:
					rpc_spawn_enemy.rpc(p.type_id, p.pos, p.name)
				else:
					_instantiate_enemy(p.type_id, p.pos, p.name)
			i -= 1
		
		# Check wave completion
		_clean_dead_enemies()
		var alive_count = active_enemies.size() + pending_spawns.size()
		if current_wave < FINAL_WAVE:
			alive_count += enemies_left_to_spawn
		if NetworkManager.is_multiplayer:
			rpc_wave_progress.rpc(alive_count, total_enemies_in_wave)
		else:
			wave_progress.emit(alive_count, total_enemies_in_wave)
		
		# Regular waves complete when all enemies are slain.
		# Final Boss battle ONLY completes when the Boss is defeated (_on_boss_defeated)!
		if current_wave < FINAL_WAVE:
			if alive_count <= 0 and enemies_left_to_spawn <= 0 and pending_spawns.is_empty():
				_complete_wave()

func start_intermission(duration: float = 4.0) -> void:
	is_intermission = true
	is_wave_active = false
	intermission_timer = duration

func _start_wave(wave_num: int) -> void:
	current_wave = wave_num
	GameManager.current_wave = wave_num
	is_wave_active = true
	boss_spawned_for_wave = false
	
	if current_wave >= FINAL_WAVE:
		total_enemies_in_wave = -1
		enemies_left_to_spawn = -1
		# Final Boss Fight: all enemies have double spawn rate (half spawn interval: 0.4s -> 0.2s)
		spawn_interval = 0.2
		spawn_timer = get_effective_spawn_interval()
	else:
		total_enemies_in_wave = 10 + wave_num * 6
		enemies_left_to_spawn = total_enemies_in_wave
		spawn_interval = clampf(2.0 - (wave_num * 0.1), 0.4, 2.0)
		spawn_timer = minf(0.5, get_effective_spawn_interval())
	
	pending_spawns.clear()
	_clean_all_indicators()
	
	if NetworkManager.is_multiplayer:
		rpc_wave_started.rpc(current_wave, total_enemies_in_wave)
	else:
		GameManager.wave_started.emit(current_wave)
	
	# Spawn a Loot Chest every 2 waves (and on final wave)
	if wave_num % 2 == 0 or wave_num >= FINAL_WAVE:
		_spawn_loot_chest()

func _spawn_one_enemy() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	
	var ref_player = players.pick_random()
	if not is_instance_valid(ref_player):
		return
	
	if current_wave < FINAL_WAVE:
		enemies_left_to_spawn -= 1
	enemy_counter += 1
	var enemy_name = "Enemy_%d_%d" % [current_wave, enemy_counter]
	
	# Determine enemy type
	# 0=Swarmer, 1=Spitter, 2=Brute, 3=Boss, 4=Charger, 5=Spawner, 6=Bomber, 7=Hornet
	var type_id = 0
	var spawn_pos: Vector3
	var delay: float = SPAWN_DELAY
	
	if current_wave >= FINAL_WAVE and not boss_spawned_for_wave:
		boss_spawned_for_wave = true
		delay = 4.0
		if GameManager.current_stage >= 2:
			# Blood Ghoul starts lurking in the moon shadow under a tree far from the squad
			type_id = TYPE_BLOOD_GHOUL
			spawn_pos = _pick_ghoul_spawn(players)
		else:
			type_id = 3
			# Spawn at center of the elevated stage platform (top surface at y = 3.9)
			spawn_pos = Vector3(0.0, 3.9, 0.0)
	else:
		type_id = _select_enemy_type(current_wave)
		spawn_pos = _find_valid_spawn_pos(ref_player, players)
		if type_id == 5:
			# Void Spawner spawns directly in the sky at high altitude
			spawn_pos.y = 8.5
		elif type_id == TYPE_SPORE_PIT:
			# The pit is huge: find a spot with room around it
			for attempt in range(8):
				if not _is_spot_blocked(spawn_pos, 3.0):
					break
				spawn_pos = _find_valid_spawn_pos(ref_player, players)
	
	# Enqueue pending spawn
	pending_spawns.append({
		"type_id": type_id,
		"pos": spawn_pos,
		"name": enemy_name,
		"timer": delay
	})
	
	# Start visual telegraph (the Blood Ghoul arrives unseen)
	if type_id == TYPE_BLOOD_GHOUL:
		return
	if NetworkManager.is_multiplayer:
		rpc_start_spawn_telegraph.rpc(type_id, spawn_pos, enemy_name, delay)
	else:
		_create_spawn_indicator(type_id, spawn_pos, enemy_name, delay)

func _select_enemy_type(wave_num: int) -> int:
	if GameManager.current_stage >= 2:
		return _select_stage2_enemy_type(wave_num)
	# Multiplicative reduction for basic enemies (Swarmer & Spitter):
	# Each 5 waves, reduce the weight of the first and second basic enemy by 5% multiplicatively (* 0.95^(wave/5)).
	var wave_factor: int = int(wave_num / 5)
	var basic_multiplier: float = pow(0.95, float(wave_factor))
	
	var w_swarmer: float = 0.0
	var w_spitter: float = 0.0
	var w_brute: float = 0.0
	var w_charger: float = 0.0
	var w_spawner: float = 0.0
	
	# Base weights:
	# Brute: 0.144 -> 0.072 (halved)
	# Charger: 0.080/0.085 -> 0.040/0.0425 (halved)
	# Spawner: 0.020 -> 0.010 -> 0.0025 (halved, then reduced to another 1/4)
	if wave_num >= 20:
		w_swarmer = 0.456 * basic_multiplier
		w_spitter = 0.300 * basic_multiplier
		w_brute = 0.072
		w_charger = 0.040
		w_spawner = 0.0025
	elif wave_num > 10:
		w_swarmer = 0.471 * basic_multiplier
		w_spitter = 0.300 * basic_multiplier
		w_brute = 0.072
		w_charger = 0.0425
		w_spawner = 0.0
	elif wave_num >= 6:
		w_swarmer = 0.556 * basic_multiplier
		w_spitter = 0.300 * basic_multiplier
		w_brute = 0.072
		w_charger = 0.0
		w_spawner = 0.0
	elif wave_num >= 3:
		w_swarmer = 0.650 * basic_multiplier
		w_spitter = 0.350 * basic_multiplier
		w_brute = 0.0
		w_charger = 0.0
		w_spawner = 0.0
	else:
		w_swarmer = 1.0 * basic_multiplier
		w_spitter = 0.0
		w_brute = 0.0
		w_charger = 0.0
		w_spawner = 0.0
	
	var total_weight: float = w_swarmer + w_spitter + w_brute + w_charger + w_spawner
	if total_weight <= 0.0:
		return 0
	
	var roll: float = randf() * total_weight
	if roll < w_spawner:
		return 5 # Void Spawner
	roll -= w_spawner
	if roll < w_charger:
		return 4 # Cyber Charger
	roll -= w_charger
	if roll < w_brute:
		return 2 # Armored Goliath (Brute)
	roll -= w_brute
	if roll < w_spitter:
		return 7 if wave_num > HORNET_AFTER_WAVE else 1 # Photon Hornet / Plasma Spitter
	return 6 if wave_num > BOMBER_AFTER_WAVE else 0 # Volt Bomber / Cyber Swarmer

## Stage 2 (Night Jungle) roster. Spider & Wyvern weights decay 5% every 5 waves like Stage 1's basic units;
## the Spider also loses another 10% every 10 waves.
func _select_stage2_enemy_type(wave_num: int) -> int:
	var basic_multiplier: float = pow(0.95, float(int(wave_num / 5)))
	var spider_multiplier: float = basic_multiplier * pow(0.9, float(int(wave_num / 10)))
	var w_spider: float = 1.0 * spider_multiplier
	var w_wyvern: float = 0.0
	var w_slime: float = 0.0
	var w_stalker: float = 0.0
	var w_pit: float = 0.0
	if wave_num > WYVERN_AFTER_WAVE:
		w_spider = 0.65 * spider_multiplier
		w_wyvern = 0.175 * basic_multiplier
	if wave_num > SLIME_AFTER_WAVE:
		w_spider = 0.5 * spider_multiplier
		w_wyvern = 0.15 * basic_multiplier
		w_slime = 0.05
	if wave_num > STALKER_AFTER_WAVE:
		w_spider = 0.456 * spider_multiplier
		w_stalker = 0.01
	if wave_num > SPORE_PIT_AFTER_WAVE:
		w_pit = 0.001

	var roll: float = randf() * (w_spider + w_wyvern + w_slime + w_stalker + w_pit)
	if roll < w_pit:
		return TYPE_SPORE_PIT
	roll -= w_pit
	if roll < w_stalker:
		return 11 # Mantis Stalker
	roll -= w_stalker
	if roll < w_slime:
		return 10 # Bog Slime
	roll -= w_slime
	if roll < w_wyvern:
		return 9 # Venom Wyvern
	return 8 # Shadow Spider

## Blood Ghoul spawn: the jungle hide spot farthest from the squad
func _pick_ghoul_spawn(players: Array) -> Vector3:
	var arena = get_tree().get_first_node_in_group("jungle_arena")
	if arena == null:
		return Vector3(0.0, 0.5, -30.0)
	var best = Vector3(0.0, 0.5, -30.0)
	var best_d = -1.0
	for spot in arena.get_hide_spots():
		var min_d = INF
		for p in players:
			if is_instance_valid(p):
				min_d = minf(min_d, spot.distance_to(p.global_position))
		if min_d > best_d:
			best_d = min_d
			best = spot
	best.y = 0.5
	return best

func _find_valid_spawn_pos(ref_player: CharacterBody3D, players: Array) -> Vector3:
	var best_pos = Vector3.ZERO
	var best_dist_to_player = -1.0
	
	# Attempt up to 12 times to find an arena position at least 10m away from all players
	for attempt in range(12):
		var angle = randf() * TAU
		var dist = randf_range(16.0, 30.0)
		var candidate = ref_player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
		candidate.x = clampf(candidate.x, -35.0, 35.0)
		candidate.z = clampf(candidate.z, -35.0, 35.0)
		candidate.y = 0.5

		var min_p_dist = INF
		for p in players:
			if is_instance_valid(p) and p is CharacterBody3D:
				var d = candidate.distance_to(p.global_position)
				if d < min_p_dist:
					min_p_dist = d

		# Avoid spawning inside or overlapping pillars, ramps and cover
		if _is_spot_blocked(candidate):
			continue
		
		if min_p_dist >= 10.0:
			return candidate
		
		if min_p_dist > best_dist_to_player:
			best_dist_to_player = min_p_dist
			best_pos = candidate
	
	if best_pos != Vector3.ZERO and best_dist_to_player >= 5.0:
		return best_pos
	
	# Fallback: spawn on opposite side of arena relative to player
	var away_dir = -ref_player.global_position.normalized()
	if away_dir.length_squared() < 0.05:
		away_dir = Vector3(1, 0, 0)
	var fallback = away_dir * randf_range(18.0, 30.0)
	fallback.x = clampf(fallback.x, -35.0, 35.0)
	fallback.z = clampf(fallback.z, -35.0, 35.0)
	fallback.y = 0.5
	# If fallback is inside solid geometry, nudge it to the first clear spot around it
	if _is_spot_blocked(fallback):
		for i in range(8):
			var a = TAU * float(i) / 8.0
			var nudged = fallback + Vector3(cos(a) * 3.5, 0.0, sin(a) * 3.5)
			nudged.x = clampf(nudged.x, -35.0, 35.0)
			nudged.z = clampf(nudged.z, -35.0, 35.0)
			if not _is_spot_blocked(nudged):
				return nudged
	return fallback

# True when a ground-level body at pos would overlap static level geometry (layer 1: pillars, ramps, cover)
func _is_spot_blocked(pos: Vector3, radius: float = 1.0) -> bool:
	var shape = SphereShape3D.new()
	shape.radius = radius
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), Vector3(pos.x, 0.3 + radius, pos.z))
	params.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()

func _create_spawn_indicator(type_id: int, spawn_pos: Vector3, net_name: String, delay: float) -> void:
	var ind = SPAWN_INDICATOR_SCENE.instantiate()
	get_parent().add_child(ind)
	ind.global_position = spawn_pos
	ind.setup(type_id, net_name, delay)

func _instantiate_enemy(type_id: int, spawn_pos: Vector3, net_name: String) -> void:
	# Trigger burst and cleanup on any active indicator for this spawn
	var indicators = get_tree().get_nodes_in_group("spawn_indicators")
	for ind in indicators:
		if is_instance_valid(ind):
			if ind.get("net_name") == net_name or ind.global_position.distance_to(spawn_pos) < 0.8:
				if ind.has_method("burst_and_free"):
					ind.burst_and_free()
	
	var enemy_scene = SWARMER_SCENE
	if type_id == 1:
		enemy_scene = SPITTER_SCENE
	elif type_id == 2:
		enemy_scene = BRUTE_SCENE
	elif type_id == 3:
		enemy_scene = BOSS_SCENE
	elif type_id == 4:
		enemy_scene = CHARGER_SCENE
	elif type_id == 5:
		enemy_scene = SPAWNER_ENEMY_SCENE
	elif type_id == 6:
		enemy_scene = BOMBER_SCENE
	elif type_id == 7:
		enemy_scene = HORNET_SCENE
	elif type_id == 8:
		enemy_scene = SPIDER_SCENE
	elif type_id == 9:
		enemy_scene = WYVERN_SCENE
	elif type_id == 10:
		enemy_scene = SLIME_SCENE
	elif type_id == 11:
		enemy_scene = STALKER_SCENE
	elif type_id == TYPE_SPORE_PIT:
		enemy_scene = SPORE_PIT_SCENE
	elif type_id == TYPE_BLOOD_GHOUL:
		enemy_scene = BLOOD_GHOUL_SCENE
		
	var enemy = enemy_scene.instantiate()
	if type_id == 3 or type_id == TYPE_BLOOD_GHOUL:
		active_boss = enemy
	enemy.name = net_name
	enemy.position = spawn_pos
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos
	active_enemies.append(enemy)
	
	# Smooth emergence scale pop animation
	if enemy.mesh_root:
		enemy.mesh_root.scale = Vector3(0.2, 0.2, 0.2)
		var tw = enemy.create_tween()
		tw.tween_property(enemy.mesh_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clean_all_indicators() -> void:
	var indicators = get_tree().get_nodes_in_group("spawn_indicators")
	for ind in indicators:
		if is_instance_valid(ind):
			ind.queue_free()

func _spawn_loot_chest() -> void:
	var spawn_pos = Vector3(randf_range(-18.0, 18.0), 0.5, randf_range(-18.0, 18.0))
	for attempt in range(10):
		if not _is_spot_blocked(spawn_pos):
			break
		spawn_pos = Vector3(randf_range(-18.0, 18.0), 0.5, randf_range(-18.0, 18.0))

	if NetworkManager.is_multiplayer:
		rpc_spawn_chest.rpc(spawn_pos)
	else:
		_instantiate_chest(spawn_pos)

func _instantiate_chest(spawn_pos: Vector3) -> void:
	var chest = CHEST_SCENE.instantiate()
	get_parent().add_child(chest)
	chest.global_position = spawn_pos

func _clean_dead_enemies() -> void:
	var valid_list: Array[Node] = []
	for e in active_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			# Instant failsafe elimination if any enemy somehow got out of the arena
			if e.has_method("is_out_of_arena") and e.is_out_of_arena():
				if e.has_method("die"):
					e.die()
				else:
					e.queue_free()
				continue
			valid_list.append(e)
	active_enemies = valid_list

func _on_enemy_killed(_type: String) -> void:
	_clean_dead_enemies()
	var alive_count = active_enemies.size() + pending_spawns.size()
	if current_wave < FINAL_WAVE:
		alive_count += enemies_left_to_spawn
	if NetworkManager.is_multiplayer and NetworkManager.is_server:
		rpc_wave_progress.rpc(alive_count, total_enemies_in_wave)
	else:
		wave_progress.emit(alive_count, total_enemies_in_wave)

func _on_boss_defeated() -> void:
	if NetworkManager.is_multiplayer and not NetworkManager.is_server:
		return
	# GameManager.reset_game() also emits boss_defeated (to hide the boss bar): ignore it while the boss still lives
	if is_instance_valid(active_boss) and active_boss.get("is_dead") != true:
		return
	if current_wave >= FINAL_WAVE and is_wave_active:
		# Overlord reactor meltdown clears remaining horde units & completes final wave
		enemies_left_to_spawn = 0
		pending_spawns.clear()
		_clean_all_indicators()
		for e in active_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if "detonate_on_death" in e:
					e.detonate_on_death = false
				if e.has_method("die"):
					e.die()
				else:
					e.queue_free()
		active_enemies.clear()
		# Also kill any escort or minion enemies in the scene
		var remaining_enemies = get_tree().get_nodes_in_group("enemies")
		for e in remaining_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if "detonate_on_death" in e:
					e.detonate_on_death = false
				if e.has_method("die"):
					e.die()
				else:
					e.queue_free()
		_complete_wave()

func _complete_wave() -> void:
	is_wave_active = false
	pending_spawns.clear()
	_clean_all_indicators()
	
	if NetworkManager.is_multiplayer:
		rpc_wave_cleared.rpc(current_wave)
	else:
		GameManager.wave_cleared.emit(current_wave)
	
	var fever_mult = GameManager.get_fever_loot_mult()
	GameManager.add_scrap(int((30 + current_wave * 10) * fever_mult))
	GameManager.add_xp(int((40 + current_wave * 15) * fever_mult))
	
	# Wave 50 boss slain: advance to the next stage at Wave 1, or win after the final stage
	if current_wave >= FINAL_WAVE:
		if GameManager.current_stage < GameManager.FINAL_STAGE:
			var next_stage = GameManager.current_stage + 1
			if NetworkManager.is_multiplayer:
				rpc_advance_stage.rpc(next_stage)
			else:
				_apply_stage(next_stage)
			start_intermission(STAGE_TRANSITION_DELAY)
			return
		if NetworkManager.is_multiplayer:
			rpc_trigger_victory.rpc()
		else:
			GameManager.trigger_victory()
		return
	
	current_wave += 1
	var next_round_delay = 4.5 / GameManager.get_fever_spawn_rate_mult()
	start_intermission(next_round_delay)

# ==============================================================================
# SPAWNER MULTIPLAYER RPCS
# ==============================================================================

## Switches every peer to the next stage: Wave 1 of a new arena with a fresh build (main.gd swaps the arena on stage_changed)
func _apply_stage(stage: int) -> void:
	current_wave = 1
	GameManager.current_wave = 1
	boss_spawned_for_wave = false
	pending_spawns.clear()
	_clean_all_indicators()
	GameManager.reset_stage_progression()
	GameManager.set_stage(stage)

@rpc("call_local", "reliable")
func rpc_advance_stage(stage: int) -> void:
	_apply_stage(stage)

@rpc("call_local", "reliable")
func rpc_trigger_victory() -> void:
	GameManager.trigger_victory()

@rpc("call_local", "reliable")
func rpc_start_spawn_telegraph(type_id: int, spawn_pos: Vector3, net_name: String, delay: float) -> void:
	_create_spawn_indicator(type_id, spawn_pos, net_name, delay)

@rpc("call_local", "reliable")
func rpc_spawn_enemy(type_id: int, spawn_pos: Vector3, net_name: String) -> void:
	_instantiate_enemy(type_id, spawn_pos, net_name)

@rpc("call_local", "reliable")
func rpc_spawn_chest(spawn_pos: Vector3) -> void:
	_instantiate_chest(spawn_pos)

@rpc("call_local", "reliable")
func rpc_wave_started(wave_num: int, total_enemies: int) -> void:
	current_wave = wave_num
	GameManager.current_wave = wave_num
	total_enemies_in_wave = total_enemies
	is_wave_active = true
	is_intermission = false
	pending_spawns.clear()
	_clean_all_indicators()
	GameManager.wave_started.emit(current_wave)

@rpc("call_local", "reliable")
func rpc_wave_progress(alive_count: int, total_enemies: int) -> void:
	wave_progress.emit(alive_count, total_enemies)

@rpc("call_local", "reliable")
func rpc_intermission_tick(secs_left: int) -> void:
	is_intermission = true
	intermission_tick.emit(secs_left)

@rpc("call_local", "reliable")
func rpc_wave_cleared(wave_num: int) -> void:
	is_wave_active = false
	pending_spawns.clear()
	_clean_all_indicators()
	GameManager.wave_cleared.emit(wave_num)
