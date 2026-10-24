extends Node3D

signal wave_progress(enemies_remaining: int, total_enemies: int)
signal intermission_tick(seconds_left: int)

const SWARMER_SCENE = preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")
const BRUTE_SCENE = preload("res://scenes/enemies/brute.tscn")
const CHEST_SCENE = preload("res://scenes/loot/chest.tscn")

var current_wave: int = 1
var is_wave_active: bool = false
var is_intermission: bool = false
var intermission_timer: float = 0.0

var total_enemies_in_wave: int = 0
var enemies_left_to_spawn: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2

var active_enemies: Array[Node] = []
var player: CharacterBody3D = null

func _ready() -> void:
	GameManager.enemy_killed.connect(_on_enemy_killed)
	_find_player()
	# Start initial wave after 3s warm-up
	start_intermission(3.0)

func _find_player() -> void:
	var p = get_tree().get_nodes_in_group("player")
	if p.size() > 0:
		player = p[0]

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	
	if is_intermission:
		intermission_timer -= delta
		intermission_tick.emit(int(ceil(intermission_timer)))
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
	
	GameManager.wave_started.emit(current_wave)
	
	# Spawn a Loot Chest every 2 waves
	if wave_num % 2 == 0:
		_spawn_loot_chest()

func _spawn_one_enemy() -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			return
	
	enemies_left_to_spawn -= 1
	
	# Determine enemy type based on wave
	var enemy_scene = SWARMER_SCENE
	var r = randf()
	
	if current_wave >= 6:
		if r < 0.18:
			enemy_scene = BRUTE_SCENE
		elif r < 0.48:
			enemy_scene = SPITTER_SCENE
		else:
			enemy_scene = SWARMER_SCENE
	elif current_wave >= 3:
		if r < 0.35:
			enemy_scene = SPITTER_SCENE
		else:
			enemy_scene = SWARMER_SCENE
	else:
		enemy_scene = SWARMER_SCENE
	
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	
	# Pick spawn location around player at radius 22 to 32 meters
	var angle = randf() * TAU
	var dist = randf_range(22.0, 32.0)
	var spawn_pos = player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
	
	# Clamp to arena boundary (arena is 65x65m, bounds -30 to +30)
	spawn_pos.x = clampf(spawn_pos.x, -28.0, 28.0)
	spawn_pos.z = clampf(spawn_pos.z, -28.0, 28.0)
	spawn_pos.y = 0.5 # Floor level
	
	enemy.global_position = spawn_pos
	active_enemies.append(enemy)

func _spawn_loot_chest() -> void:
	var chest = CHEST_SCENE.instantiate()
	get_parent().add_child(chest)
	# Place on arena elevated platform or random location
	var pos_x = randf_range(-14.0, 14.0)
	var pos_z = randf_range(-14.0, 14.0)
	chest.global_position = Vector3(pos_x, 0.5, pos_z)

func _clean_dead_enemies() -> void:
	var valid_list: Array[Node] = []
	for e in active_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			valid_list.append(e)
	active_enemies = valid_list

func _on_enemy_killed(_type: String) -> void:
	_clean_dead_enemies()
	var alive_count = active_enemies.size() + enemies_left_to_spawn
	wave_progress.emit(alive_count, total_enemies_in_wave)

func _complete_wave() -> void:
	is_wave_active = false
	GameManager.wave_cleared.emit(current_wave)
	
	# Wave completion bonuses
	GameManager.add_scrap(30 + current_wave * 10)
	GameManager.add_xp(40 + current_wave * 15)
	
	current_wave += 1
	start_intermission(4.5)
