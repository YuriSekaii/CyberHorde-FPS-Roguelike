extends Node3D

signal wave_progress(enemies_remaining: int, total_enemies: int)
signal intermission_tick(seconds_left: int)

const SWARMER_SCENE = preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")
const BRUTE_SCENE = preload("res://scenes/enemies/brute.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const CHARGER_SCENE = preload("res://scenes/enemies/charger.tscn")
const SPAWNER_ENEMY_SCENE = preload("res://scenes/enemies/spawner.tscn")
const CHEST_SCENE = preload("res://scenes/loot/chest.tscn")
const SPAWN_INDICATOR_SCENE = preload("res://scenes/world/spawn_indicator.tscn")

const FINAL_WAVE: int = 100
const SPAWN_DELAY: float = 3.0
const MAX_CONCURRENT_ENEMIES: int = 40

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
		current_wave = 100
		GameManager.current_wave = 100
	else:
		current_wave = 1
	# In multiplayer, only server controls wave timers
	if not NetworkManager.is_multiplayer or NetworkManager.is_server:
		start_intermission(3.0)

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
		# Queue up new enemy telegraphs only if active count is within concurrent capacity
		_clean_dead_enemies()
		var current_active = active_enemies.size() + pending_spawns.size()
		if enemies_left_to_spawn > 0 and current_active < MAX_CONCURRENT_ENEMIES:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = spawn_interval
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
		var alive_count = active_enemies.size() + pending_spawns.size() + enemies_left_to_spawn
		if NetworkManager.is_multiplayer:
			rpc_wave_progress.rpc(alive_count, total_enemies_in_wave)
		else:
			wave_progress.emit(alive_count, total_enemies_in_wave)
		
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
	
	total_enemies_in_wave = 10 + wave_num * 6
	enemies_left_to_spawn = total_enemies_in_wave
	spawn_interval = clampf(2.0 - (wave_num * 0.1), 0.4, 2.0)
	spawn_timer = 0.5
	
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
	
	enemies_left_to_spawn -= 1
	enemy_counter += 1
	var enemy_name = "Enemy_%d_%d" % [current_wave, enemy_counter]
	
	# Determine enemy type
	# 0=Swarmer, 1=Spitter, 2=Brute, 3=Boss, 4=Charger, 5=Spawner
	var type_id = 0
	var spawn_pos: Vector3
	var delay: float = SPAWN_DELAY
	
	if current_wave >= FINAL_WAVE and not boss_spawned_for_wave:
		boss_spawned_for_wave = true
		type_id = 3
		spawn_pos = Vector3(0.0, 0.5, -12.0)
		delay = 4.0
	else:
		var r = randf()
		if current_wave >= 20:
			# Void Spawner: extremely rare (~2.5%), max 1 concurrent spawner
			var active_spawner_count = 0
			for e in active_enemies:
				if is_instance_valid(e) and e.get("enemy_name") == "Void Spawner":
					active_spawner_count += 1
			for p in pending_spawns:
				if p.get("type_id") == 5:
					active_spawner_count += 1
			
			if r < 0.025 and active_spawner_count == 0:
				type_id = 5
			elif r < 0.105: # Charger (~8.0%, rarer than Brute's 14.4%)
				type_id = 4
			elif r < 0.249: # Brute (14.4%)
				type_id = 2
			elif r < 0.549: # Spitter (30.0%)
				type_id = 1
			else:
				type_id = 0 # Swarmer (45.1%)
		elif current_wave > 10:
			# Charger introduced after Wave 10, rarer than Brute
			if r < 0.085: # Charger (8.5%, rarer than Brute's 14.4%)
				type_id = 4
			elif r < 0.229: # Brute (14.4%)
				type_id = 2
			elif r < 0.529: # Spitter (30.0%)
				type_id = 1
			else:
				type_id = 0 # Swarmer (47.1%)
		elif current_wave >= 6:
			# Brute spawn chance 14.4%, Spitter 30%
			if r < 0.144:
				type_id = 2
			elif r < 0.444:
				type_id = 1
			else:
				type_id = 0
		elif current_wave >= 3:
			if r < 0.35:
				type_id = 1
			else:
				type_id = 0
		else:
			type_id = 0
		
		spawn_pos = _find_valid_spawn_pos(ref_player, players)
	
	# Enqueue pending spawn
	pending_spawns.append({
		"type_id": type_id,
		"pos": spawn_pos,
		"name": enemy_name,
		"timer": delay
	})
	
	# Start visual telegraph
	if NetworkManager.is_multiplayer:
		rpc_start_spawn_telegraph.rpc(type_id, spawn_pos, enemy_name, delay)
	else:
		_create_spawn_indicator(type_id, spawn_pos, enemy_name, delay)

func _find_valid_spawn_pos(ref_player: CharacterBody3D, players: Array) -> Vector3:
	var best_pos = Vector3.ZERO
	var best_dist_to_player = -1.0
	
	# Attempt up to 12 times to find an arena position at least 10m away from all players
	for attempt in range(12):
		var angle = randf() * TAU
		var dist = randf_range(16.0, 28.0)
		var candidate = ref_player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
		candidate.x = clampf(candidate.x, -27.0, 27.0)
		candidate.z = clampf(candidate.z, -27.0, 27.0)
		candidate.y = 0.5
		
		var min_p_dist = INF
		for p in players:
			if is_instance_valid(p) and p is CharacterBody3D:
				var d = candidate.distance_to(p.global_position)
				if d < min_p_dist:
					min_p_dist = d
		
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
	var fallback = away_dir * randf_range(15.0, 25.0)
	fallback.x = clampf(fallback.x, -27.0, 27.0)
	fallback.z = clampf(fallback.z, -27.0, 27.0)
	fallback.y = 0.5
	return fallback

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
	
	var enemy = enemy_scene.instantiate()
	enemy.name = net_name
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
	var pos_x = randf_range(-14.0, 14.0)
	var pos_z = randf_range(-14.0, 14.0)
	var spawn_pos = Vector3(pos_x, 0.5, pos_z)
	
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
			valid_list.append(e)
	active_enemies = valid_list

func _on_enemy_killed(_type: String) -> void:
	_clean_dead_enemies()
	var alive_count = active_enemies.size() + pending_spawns.size() + enemies_left_to_spawn
	if NetworkManager.is_multiplayer and NetworkManager.is_server:
		rpc_wave_progress.rpc(alive_count, total_enemies_in_wave)
	else:
		wave_progress.emit(alive_count, total_enemies_in_wave)

func _on_boss_defeated() -> void:
	if NetworkManager.is_multiplayer and not NetworkManager.is_server:
		return
	if current_wave >= FINAL_WAVE and is_wave_active:
		# Overlord reactor meltdown clears remaining horde units & completes final wave
		enemies_left_to_spawn = 0
		pending_spawns.clear()
		_clean_all_indicators()
		for e in active_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if e.has_method("die"):
					e.die()
				else:
					e.queue_free()
		active_enemies.clear()
		_complete_wave()

func _complete_wave() -> void:
	is_wave_active = false
	pending_spawns.clear()
	_clean_all_indicators()
	
	if NetworkManager.is_multiplayer:
		rpc_wave_cleared.rpc(current_wave)
	else:
		GameManager.wave_cleared.emit(current_wave)
	
	GameManager.add_scrap(30 + current_wave * 10)
	GameManager.add_xp(40 + current_wave * 15)
	
	# Wave 100 Final Wave Victory
	if current_wave >= FINAL_WAVE:
		if NetworkManager.is_multiplayer:
			rpc_trigger_victory.rpc()
		else:
			GameManager.trigger_victory()
		return
	
	current_wave += 1
	start_intermission(4.5)

# ==============================================================================
# SPAWNER MULTIPLAYER RPCS
# ==============================================================================

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
