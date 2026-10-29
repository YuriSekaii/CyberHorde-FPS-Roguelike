extends CharacterBody3D
class_name EnemyBase

@export var enemy_name: String = "Enemy"
@export var max_health: float = 50.0
@export var speed: float = 5.0
@export var attack_damage: float = 12.0
@export var xp_reward: int = 20
@export var scrap_reward: int = 15

var current_health: float = 50.0
var target_player: CharacterBody3D = null
var is_dead: bool = false
var slow_timer: float = 0.0
var slow_multiplier: float = 1.0
var retarget_timer: float = 0.0
var attack_speed_mult: float = 1.0
var wave_speed_mult: float = 1.0
var damage_reduction: float = 0.0
var last_hit_by_rogue: bool = false
var _is_flashing: bool = false
static var _last_hit_sound_msec: int = 0
static var all_enemies: Array[Node] = []

@onready var mesh_root: Node3D = $MeshRoot
const DAMAGE_NUMBER_SCENE = preload("res://scenes/ui/damage_number.tscn")
const LOOT_SCENE = preload("res://scenes/loot/loot_pickup.tscn")

const DAMAGE_TYPE_DIRECT: int = 0
const DAMAGE_TYPE_RICOCHET: int = 1
const DAMAGE_TYPE_EXPLOSIVE: int = 2
const DAMAGE_TYPE_CHAIN_LIGHTNING: int = 3
const DAMAGE_TYPE_WEAKPOINT: int = 4 # Direct (non-ricochet) shot whose path passes through an enemy's weakpoint

const CRYO_SLOW_FACTOR: float = 0.25
const CRYO_SLOW_DURATION: float = 3.0

var _last_immune_feedback_msec: int = 0
var _detour_dir: Vector3 = Vector3.ZERO
var _detour_side: float = 1.0
var _detour_timer: float = 0.0
var _nav_path: PackedVector3Array = PackedVector3Array()
var _nav_index: int = 0
var _nav_repath_timer: float = 0.0
const NAV_REPATH_INTERVAL: float = 0.3

func _ready() -> void:
	collision_mask |= 16 # Collide with invisible boundary barrier (Layer 5)
	all_enemies.append(self)
	add_to_group("enemies")
	_apply_wave_scaling()
	_find_player()

func _exit_tree() -> void:
	all_enemies.erase(self)

func _apply_wave_scaling() -> void:
	# Every stage restarts the curve at Wave 1
	var wave_num = GameManager.get_scaling_wave()
	# 1. Every wave: 10% more HP and 5% more DMG compounding
	var hp_factor = pow(1.10, float(maxi(0, wave_num - 1)))
	var dmg_factor = pow(1.05, float(maxi(0, wave_num - 1)))
	current_health = max_health * hp_factor
	max_health = current_health
	attack_damage = attack_damage * dmg_factor
	
	# 2. Every 10 waves: 5% more Attack SPD and Movement SPD (compounding per 10-wave tier)
	var speed_tier: int = int(wave_num / 10)
	var speed_mult: float = pow(1.05, float(speed_tier))
	speed *= speed_mult
	wave_speed_mult = speed_mult
	attack_speed_mult = speed_mult
	
	# 3. Every 10 waves: 10% dmg reduction (capped at 50% in Wave 50)
	var reduction_tier: int = int(wave_num / 10)
	damage_reduction = clampf(float(reduction_tier) * 0.10, 0.0, 0.50)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var closest_dist: float = INF
	target_player = null
	
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			if p.get("is_downed") == true:
				continue
			var d = global_position.distance_squared_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				target_player = p
	
	if target_player == null:
		closest_dist = INF
		for p in players:
			if is_instance_valid(p) and p is CharacterBody3D:
				var d = global_position.distance_squared_to(p.global_position)
				if d < closest_dist:
					closest_dist = d
					target_player = p

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Out-of-bounds instant elimination: any enemy outside arena boundaries is eliminated immediately
	if is_out_of_arena():
		die()
		return
	
	retarget_timer += delta
	if retarget_timer >= 0.5 or target_player == null or not is_instance_valid(target_player):
		retarget_timer = 0.0
		_find_player()
		if target_player == null:
			return
	
	# Handle slow debuff
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	
	_behave(delta)
	
	# Re-check out-of-bounds after movement: eliminate immediately if pushed or moved out of the arena
	if is_out_of_arena():
		die()
		return

func is_out_of_arena() -> bool:
	# Arena floor is 80x80 (X: [-40, 40], Z: [-40, 40]), enclosed by 4 perimeter walls (inner faces at |X, Z| = 39.0).
	# Floor surface is at Y = 0.0, ceiling boundary is at Y = 48.0m.
	if absf(global_position.x) > 39.5 or absf(global_position.z) > 39.5:
		return true
	if global_position.y < -1.0 or global_position.y > 45.0:
		return true
	return false

func _behave(_delta: float) -> void:
	# Overridden in child classes
	pass

# Horizontal direction to walk toward target_pos along the arena navmesh, so ground units take the ramps up to
# the center platform (and back down) instead of pushing into its sides. Falls back to a straight line when no path exists.
func nav_direction_to(target_pos: Vector3, delta: float) -> Vector3:
	_nav_repath_timer -= delta
	if _nav_repath_timer <= 0.0:
		_nav_repath_timer = NAV_REPATH_INTERVAL
		_nav_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, target_pos, true)
		_nav_index = 0
	while _nav_index < _nav_path.size():
		var to_wp = _nav_path[_nav_index] - global_position
		var horiz = Vector3(to_wp.x, 0.0, to_wp.z)
		if horiz.length() > 0.6 or absf(to_wp.y) > 1.5:
			if horiz.length_squared() > 0.0001:
				return horiz.normalized()
		_nav_index += 1
	var direct = Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
	return direct.normalized() if direct.length_squared() > 0.01 else Vector3.ZERO

# Bends a direct chase direction around cover/pillars: when pressed head-on into a wall, commit to sliding along
# its face (toward the side nearer the target) for a short time so the enemy rounds the obstacle instead of grinding on it.
func steer_around_cover(dir: Vector3, delta: float) -> Vector3:
	_detour_timer = maxf(_detour_timer - delta, 0.0)
	if is_on_wall():
		var n = get_wall_normal()
		n.y = 0.0
		if n.length_squared() > 0.01:
			n = n.normalized()
			if dir.dot(n) < -0.35:
				var tangent = Vector3(-n.z, 0.0, n.x)
				if _detour_timer <= 0.0:
					_detour_side = 1.0 if tangent.dot(dir) >= 0.0 else -1.0
				_detour_dir = tangent * _detour_side
				_detour_timer = 0.6
	if _detour_timer > 0.0:
		return (_detour_dir + dir * 0.25).normalized()
	return dir

func is_immune_to(_damage_type: int) -> bool:
	return false

func _on_immune_hit(_from_pos: Vector3) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_immune_feedback_msec >= 100:
		_last_immune_feedback_msec = now
		SoundManager.play("shield_hit", 0.15, -4.0)
	if GameManager.show_damage_numbers:
		var dnum = DAMAGE_NUMBER_SCENE.instantiate()
		get_parent().add_child(dnum)
		dnum.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.8, randf_range(-0.2, 0.2))
		dnum.setup_text("IMMUNE", Color(0.3, 0.85, 1.0))

@rpc("any_peer", "call_local", "reliable")
func rpc_take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = DAMAGE_TYPE_DIRECT, is_rogue_src: bool = false) -> void:
	take_damage(amount, is_crit, from_pos, damage_type, is_rogue_src)

func take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = DAMAGE_TYPE_DIRECT, killer_source: Variant = null) -> void:
	if is_dead:
		return
	
	if killer_source != null:
		if killer_source is Node:
			last_hit_by_rogue = (killer_source.get("player_class") == "rogue")
		elif killer_source is bool:
			last_hit_by_rogue = killer_source
	
	if is_immune_to(damage_type):
		_on_immune_hit(from_pos)
		return
	
	# Apply enemy damage reduction (10% per 10 waves)
	if damage_reduction > 0.0:
		amount *= (1.0 - damage_reduction)
	
	current_health -= amount
	
	var now = Time.get_ticks_msec()
	if now - _last_hit_sound_msec >= 45:
		_last_hit_sound_msec = now
		SoundManager.play("crit_hit" if is_crit else "enemy_hit", 0.15)
	
	# Spawn floating damage number (can be toggled in pause menu / F8)
	if GameManager.show_damage_numbers:
		var dnum = DAMAGE_NUMBER_SCENE.instantiate()
		get_parent().add_child(dnum)
		dnum.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
		dnum.setup(amount, is_crit)
	
	# Flash mesh white/red
	_flash_hit()
	
	if current_health <= 0:
		die()

func apply_slow(factor: float, duration: float) -> void:
	slow_multiplier = clampf(1.0 - factor, 0.2, 1.0)
	slow_timer = duration

## Cryo Rounds: every damage instance the player deals (direct, ricochet, explosive, chain lightning, drone) chills the target
func apply_cryo_chill() -> void:
	if GameManager.cryo_slow:
		apply_slow(CRYO_SLOW_FACTOR, CRYO_SLOW_DURATION)

func _flash_hit() -> void:
	if not mesh_root or _is_flashing:
		return
	_is_flashing = true
	var tw = create_tween()
	mesh_root.scale = Vector3(1.15, 0.85, 1.15)
	tw.tween_property(mesh_root, "scale", Vector3.ONE, 0.12)
	tw.tween_callback(func(): _is_flashing = false)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	SoundManager.play("enemy_die", 0.1, -1.0)
	GameManager.record_kill(enemy_name)
	
	# Vampiric heal check
	if GameManager.vampiric_heal > 0 and target_player and target_player.has_method("heal"):
		target_player.heal(GameManager.vampiric_heal)
	
	# Drop loot
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	var is_rogue_kill = last_hit_by_rogue or (GameManager.player_class == "rogue" and not NetworkManager.is_multiplayer)
	var loot_mult: float = 3.0 if is_rogue_kill else 1.0 # 200% more = 3x value
	var fever_mult: float = GameManager.get_fever_loot_mult()
	
	# Clamp loot spawn to safe arena ground level so pickups are never lost outside the arena or in the abyss
	var drop_pos = global_position
	if drop_pos.y < 0.2 or drop_pos.y > 15.0 or absf(drop_pos.x) > 36.0 or absf(drop_pos.z) > 36.0:
		drop_pos.x = clampf(drop_pos.x, -36.0, 36.0)
		drop_pos.z = clampf(drop_pos.z, -36.0, 36.0)
		drop_pos.y = 0.5
	
	if is_rogue_kill and GameManager.show_damage_numbers:
		var dnum = DAMAGE_NUMBER_SCENE.instantiate()
		get_parent().call_deferred("add_child", dnum)
		dnum.position = drop_pos + Vector3(0, 1.8, 0)
		dnum.setup_text("+200% BOUNTY", Color(1.0, 0.85, 0.1))
	
	# Pickups are added deferred (die() can run mid-physics), so set local `position`:
	# the parent is the scene root at the origin, and global_position errors before entering the tree.
	# 1. Drop XP Gem
	var xp = LOOT_SCENE.instantiate()
	get_parent().call_deferred("add_child", xp)
	xp.position = drop_pos + Vector3(0, 0.5, 0)
	xp.setup(0, int(xp_reward * loot_mult * fever_mult))
	
	# 2. Chance of Scrap
	if randf() < 0.45:
		var scrap = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", scrap)
		scrap.position = drop_pos + Vector3(0, 0.5, 0)
		scrap.setup(2, int(scrap_reward * loot_mult * fever_mult))
	
	# 3. Chance of Health Stim
	var health_chance = 0.12
	if target_player and target_player.current_health < target_player.max_health * 0.4:
		health_chance = 0.28
	if randf() < health_chance:
		var hp = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", hp)
		hp.position = drop_pos + Vector3(0, 0.5, 0)
		hp.setup(1, 25)
