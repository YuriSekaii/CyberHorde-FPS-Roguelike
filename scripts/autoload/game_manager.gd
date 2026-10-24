extends Node

## Central Game Manager & Roguelike Protocol
## Handles player stats, roguelike upgrades, loot economy, wave director, and input bindings.

signal xp_changed(current_xp: int, xp_needed: int)
signal level_up(new_level: int)
signal scrap_changed(new_scrap: int)
signal stats_updated()
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal game_over_triggered()
signal hitmarker_triggered(is_crit: bool)
signal enemy_killed(enemy_type: String)

enum GameState { PLAYING, PAUSED, UPGRADING, GAME_OVER }
var state: GameState = GameState.PLAYING

# Run Statistics
var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int = 100
var scrap: int = 0
var current_wave: int = 1
var enemies_killed: int = 0
var total_damage_dealt: float = 0.0
var run_time: float = 0.0

# Roguelike Stats
var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var speed_mult: float = 1.0
var magnet_radius: float = 6.0
var extra_projectiles: int = 0
var pierce_count: int = 0
var explosive_rounds: bool = false
var explosion_radius: float = 3.5
var bouncing_bullets: bool = false
var chain_lightning: bool = false
var vampiric_heal: float = 0.0
var shield_max: float = 0.0
var current_shield: float = 0.0
var drone_count: int = 0
var cryo_slow: bool = false
var crit_chance: float = 0.15
var crit_damage: float = 2.0
var max_health_bonus: float = 0.0
var second_wind_available: bool = false
var greed_mult: float = 1.0

# Active Upgrades tracker: id -> count
var active_upgrades: Dictionary = {}

# Upgrade Catalog
var upgrade_database: Dictionary = {
	"heavy_rounds": {
		"id": "heavy_rounds",
		"name": "Heavy Caliber",
		"desc": "+25% Projectile Damage to all weapons.",
		"rarity": "Common",
		"color": Color(0.4, 0.8, 1.0),
		"max_stacks": 8
	},
	"overclock": {
		"id": "overclock",
		"name": "Overclock Trigger",
		"desc": "+25% Fire Rate for continuous suppression.",
		"rarity": "Common",
		"color": Color(0.4, 0.8, 1.0),
		"max_stacks": 6
	},
	"kinetic_thrusters": {
		"id": "kinetic_thrusters",
		"name": "Kinetic Thrusters",
		"desc": "+18% Movement Speed and +15% Jump Power.",
		"rarity": "Common",
		"color": Color(0.4, 0.8, 1.0),
		"max_stacks": 5
	},
	"nanite_magnet": {
		"id": "nanite_magnet",
		"name": "Nanite Magnet",
		"desc": "+60% Pickup & Magnet Collection Radius.",
		"rarity": "Common",
		"color": Color(0.4, 0.8, 1.0),
		"max_stacks": 4
	},
	"multishot": {
		"id": "multishot",
		"name": "Multi-Barrel Splitter",
		"desc": "+1 Additional projectile per shot with spread.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 3
	},
	"piercing_core": {
		"id": "piercing_core",
		"name": "Hyper-Penetrator",
		"desc": "Shots pierce through +1 additional enemy.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 3
	},
	"explosive_payload": {
		"id": "explosive_payload",
		"name": "Explosive Payload",
		"desc": "Bullets detonate on impact for AoE blast damage.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 1
	},
	"energy_shield": {
		"id": "energy_shield",
		"name": "Aegis Energy Shield",
		"desc": "Grants +50 Regenerating Shield capacity.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 3
	},
	"vampiric_core": {
		"id": "vampiric_core",
		"name": "Vampiric Siphon",
		"desc": "Instantly heals +4 HP whenever an enemy is slain.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 4
	},
	"cryo_rounds": {
		"id": "cryo_rounds",
		"name": "Cryo Rounds",
		"desc": "Bullets chill targets, slowing them by 40% for 3s.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 1
	},
	"chain_lightning": {
		"id": "chain_lightning",
		"name": "Tesla Arc Emitter",
		"desc": "Bullet hits arc chain lightning to nearby targets.",
		"rarity": "Epic",
		"color": Color(1.0, 0.6, 0.1),
		"max_stacks": 2
	},
	"ricochet": {
		"id": "ricochet",
		"name": "Smart Bouncing Core",
		"desc": "Projectiles ricochet off surfaces toward enemies.",
		"rarity": "Epic",
		"color": Color(1.0, 0.6, 0.1),
		"max_stacks": 2
	},
	"combat_drone": {
		"id": "combat_drone",
		"name": "Assault Drone Unit",
		"desc": "Deploys an autonomous companion drone to fire lasers.",
		"rarity": "Epic",
		"color": Color(1.0, 0.6, 0.1),
		"max_stacks": 3
	},
	"second_wind": {
		"id": "second_wind",
		"name": "Emergency Defibrillator",
		"desc": "Survive fatal damage once, gaining 3s of invulnerability.",
		"rarity": "Legendary",
		"color": Color(1.0, 0.9, 0.2),
		"max_stacks": 1
	},
	"loot_greed": {
		"id": "loot_greed",
		"name": "Nanite Scavenger",
		"desc": "+40% XP and Scrap drops from all defeated enemies.",
		"rarity": "Rare",
		"color": Color(0.8, 0.3, 1.0),
		"max_stacks": 3
	}
}

func _enter_tree() -> void:
	_setup_inputs()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		run_time += delta

func _setup_inputs() -> void:
	# Primary bindings
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	
	# Secondary arrow key bindings
	_bind_key("move_forward", KEY_UP)
	_bind_key("move_back", KEY_DOWN)
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_right", KEY_RIGHT)
	
	_bind_key("jump", KEY_SPACE)
	_bind_key("sprint", KEY_SHIFT)
	_bind_mouse("shoot", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)
	_bind_key("reload", KEY_R)
	_bind_key("interact", KEY_E)
	_bind_key("interact", KEY_F)
	_bind_key("weapon_1", KEY_1)
	_bind_key("weapon_2", KEY_2)
	_bind_key("weapon_3", KEY_3)
	_bind_key("pause", KEY_ESCAPE)

func _bind_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func reset_game() -> void:
	state = GameState.PLAYING
	player_level = 1
	player_xp = 0
	xp_to_next_level = 100
	scrap = 0
	current_wave = 1
	enemies_killed = 0
	total_damage_dealt = 0.0
	run_time = 0.0
	
	damage_mult = 1.0
	fire_rate_mult = 1.0
	speed_mult = 1.0
	magnet_radius = 6.0
	extra_projectiles = 0
	pierce_count = 0
	explosive_rounds = false
	explosion_radius = 3.5
	bouncing_bullets = false
	chain_lightning = false
	vampiric_heal = 0.0
	shield_max = 0.0
	current_shield = 0.0
	drone_count = 0
	cryo_slow = false
	crit_chance = 0.15
	crit_damage = 2.0
	max_health_bonus = 0.0
	second_wind_available = false
	greed_mult = 1.0
	
	active_upgrades.clear()
	get_tree().paused = false

func add_xp(amount: int) -> void:
	var final_xp = int(amount * greed_mult)
	player_xp += final_xp
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = int(xp_to_next_level * 1.35 + 40)
		SoundManager.play("level_up")
		level_up.emit(player_level)
		prompt_upgrade_menu()
	xp_changed.emit(player_xp, xp_to_next_level)

func add_scrap(amount: int) -> void:
	scrap += int(amount * greed_mult)
	scrap_changed.emit(scrap)

func record_damage(dmg: float, is_crit: bool) -> void:
	total_damage_dealt += dmg
	hitmarker_triggered.emit(is_crit)

func record_kill(enemy_type: String) -> void:
	enemies_killed += 1
	enemy_killed.emit(enemy_type)

func prompt_upgrade_menu() -> void:
	state = GameState.UPGRADING
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func get_upgrade_options(count: int = 3) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for id in upgrade_database:
		var item = upgrade_database[id]
		var cur = active_upgrades.get(id, 0)
		if cur < item["max_stacks"]:
			available.append(item)
	
	available.shuffle()
	var result: Array[Dictionary] = []
	for i in range(mini(count, available.size())):
		result.append(available[i])
	return result

func apply_upgrade(upgrade_id: String) -> void:
	if not upgrade_database.has(upgrade_id):
		return
	var cur_count = active_upgrades.get(upgrade_id, 0) + 1
	active_upgrades[upgrade_id] = cur_count
	
	match upgrade_id:
		"heavy_rounds":
			damage_mult += 0.25
		"overclock":
			fire_rate_mult += 0.25
		"kinetic_thrusters":
			speed_mult += 0.18
		"nanite_magnet":
			magnet_radius += 4.5
		"multishot":
			extra_projectiles += 1
		"piercing_core":
			pierce_count += 1
		"explosive_payload":
			explosive_rounds = true
		"energy_shield":
			shield_max += 50.0
			current_shield = shield_max
		"vampiric_core":
			vampiric_heal += 4.0
		"cryo_rounds":
			cryo_slow = true
		"chain_lightning":
			chain_lightning = true
		"ricochet":
			bouncing_bullets = true
		"combat_drone":
			drone_count += 1
		"second_wind":
			second_wind_available = true
		"loot_greed":
			greed_mult += 0.40
	
	stats_updated.emit()
	SoundManager.play("upgrade_select")
	resume_game()

func resume_game() -> void:
	state = GameState.PLAYING
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func trigger_game_over() -> void:
	state = GameState.GAME_OVER
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_over_triggered.emit()
