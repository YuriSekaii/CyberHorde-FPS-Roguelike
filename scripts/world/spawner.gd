extends Node3D

signal wave_progress(enemies_remaining: int, total_enemies: int)
signal intermission_tick(seconds_left: int)

const SWARMER_SCENE = preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")
const BRUTE_SCENE = preload("res://scenes/enemies/brute.tscn")
const CHEST_SCENE = preload("res://scenes/loot/chest.tscn")

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

func _ready() -> void:
	GameManager.enemy_killed.connect(_on_enemy_killed)

func start_spawner() -> void:
	is_spawner_active = true
	last_sent_tick = -1
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
		if enemies_left_to_spawn > 0:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = spawn_interval
				_spawn_one_enemy()
		
		# Check wave completion
		_clean_dead_enemies()
		var alive_count = active_enemies.size() + enemies_left_to_spawn
		if NetworkManager.is_multiplayer:
			rpc_wave_progress.rpc(alive_count, total_enemies_in_wave)
		else:
			wave_progress.emit(alive_count, total_enemies_in_wave)
		
		if alive_count <= 0 and enemies_left_to_spawn <= 0:
			_complete_wave()

func start_intermission(duration: float = 4.0) -> void:
	is_intermission = true
	is_wave_active = false
	intermission_timer = duration

func _start_wave(wave_num: int) -> void:
	current_wave = wave_num
	GameManager.current_wave = wave_num
	is_wave_active = true
	
	total_enemies_in_wave = 10 + wave_num * 4
	enemies_left_to_spawn = total_enemies_in_wave
	spawn_interval = clampf(2.0 - (wave_num * 0.1), 0.4, 2.0)
	spawn_timer = 0.5
	
	if NetworkManager.is_multiplayer:
		rpc_wave_started.rpc(current_wave, total_enemies_in_wave)
	else:
		GameManager.wave_started.emit(current_wave)
	
	# Spawn a Loot Chest every 2 waves
	if wave_num % 2 == 0:
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
	var type_id = 0 # 0=Swarmer, 1=Spitter, 2=Brute
	var r = randf()
	if current_wave >= 6:
		if r < 0.18:
			type_id = 2
		elif r < 0.48:
			type_id = 1
	elif current_wave >= 3:
		if r < 0.35:
			type_id = 1
	
	# Pick spawn location around random player at radius 22 to 32 meters
	var angle = randf() * TAU
	var dist = randf_range(22.0, 32.0)
	var spawn_pos = ref_player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
	spawn_pos.x = clampf(spawn_pos.x, -28.0, 28.0)
	spawn_pos.z = clampf(spawn_pos.z, -28.0, 28.0)
	spawn_pos.y = 0.5
	
	if NetworkManager.is_multiplayer:
		rpc_spawn_enemy.rpc(type_id, spawn_pos, enemy_name)
	else:
		_instantiate_enemy(type_id, spawn_pos, enemy_name)

func _instantiate_enemy(type_id: int, spawn_pos: Vector3, net_name: String) -> void:
	var enemy_scene = SWARMER_SCENE
	if type_id == 1:
		enemy_scene = SPITTER_SCENE
	elif type_id == 2:
		enemy_scene = BRUTE_SCENE
	
	var enemy = enemy_scene.instantiate()
	enemy.name = net_name
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos
	active_enemies.append(enemy)

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
	var alive_count = active_enemies.size() + enemies_left_to_spawn
	if NetworkManager.is_multiplayer and NetworkManager.is_server:
		rpc_wave_progress.rpc(alive_count, total_enemies_in_wave)
	else:
		wave_progress.emit(alive_count, total_enemies_in_wave)

func _complete_wave() -> void:
	is_wave_active = false
	if NetworkManager.is_multiplayer:
		rpc_wave_cleared.rpc(current_wave)
	else:
		GameManager.wave_cleared.emit(current_wave)
	
	GameManager.add_scrap(30 + current_wave * 10)
	GameManager.add_xp(40 + current_wave * 15)
	
	current_wave += 1
	start_intermission(4.5)

# ==============================================================================
# SPANWER MULTIPLAYER RPCS
# ==============================================================================

@rpc("call_local", "reliable")
func rpc_spawn_enemy(type_id: int, spawn_pos: Vector3, net_name: String) -> void:
	if not NetworkManager.is_server:
		_instantiate_enemy(type_id, spawn_pos, net_name)
	else:
		_instantiate_enemy(type_id, spawn_pos, net_name)

@rpc("call_local", "reliable")
func rpc_spawn_chest(spawn_pos: Vector3) -> void:
	if not NetworkManager.is_server:
		_instantiate_chest(spawn_pos)
	else:
		_instantiate_chest(spawn_pos)

@rpc("call_local", "reliable")
func rpc_wave_started(wave_num: int, total_enemies: int) -> void:
	current_wave = wave_num
	GameManager.current_wave = wave_num
	total_enemies_in_wave = total_enemies
	is_wave_active = true
	is_intermission = false
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
	GameManager.wave_cleared.emit(wave_num)
