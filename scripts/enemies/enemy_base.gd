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
var damage_reduction: float = 0.0
var _is_flashing: bool = false
static var _last_hit_sound_msec: int = 0
static var all_enemies: Array[Node] = []

@onready var mesh_root: Node3D = $MeshRoot
const DAMAGE_NUMBER_SCENE = preload("res://scenes/ui/damage_number.tscn")
const LOOT_SCENE = preload("res://scenes/loot/loot_pickup.tscn")

func _ready() -> void:
	all_enemies.append(self)
	add_to_group("enemies")
	_apply_wave_scaling()
	_find_player()

func _exit_tree() -> void:
	all_enemies.erase(self)

func _apply_wave_scaling() -> void:
	var wave_num = GameManager.current_wave
	# 1. Every wave: 10% more HP and 5% more DMG compounding
	var hp_factor = pow(1.10, float(maxi(0, wave_num - 1)))
	var dmg_factor = pow(1.05, float(maxi(0, wave_num - 1)))
	current_health = max_health * hp_factor
	max_health = current_health
	attack_damage = attack_damage * dmg_factor
	
	# 2. Every 10 waves: 5% more Attack SPD and Movement SPD
	var speed_tier: int = int(wave_num / 10)
	var speed_mult: float = 1.0 + (float(speed_tier) * 0.05)
	speed *= speed_mult
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

func _behave(_delta: float) -> void:
	# Overridden in child classes
	pass

@rpc("any_peer", "call_local", "reliable")
func rpc_take_damage(amount: float, is_crit: bool, from_pos: Vector3) -> void:
	take_damage(amount, is_crit, from_pos)

func take_damage(amount: float, is_crit: bool, from_pos: Vector3) -> void:
	if is_dead:
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
	# 1. Drop XP Gem
	var xp = LOOT_SCENE.instantiate()
	get_parent().call_deferred("add_child", xp)
	xp.global_position = global_position + Vector3(0, 0.5, 0)
	xp.setup(0, xp_reward)
	
	# 2. Chance of Scrap
	if randf() < 0.45:
		var scrap = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", scrap)
		scrap.global_position = global_position + Vector3(0, 0.5, 0)
		scrap.setup(2, scrap_reward)
	
	# 3. Chance of Health Stim
	var health_chance = 0.12
	if target_player and target_player.current_health < target_player.max_health * 0.4:
		health_chance = 0.28
	if randf() < health_chance:
		var hp = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", hp)
		hp.global_position = global_position + Vector3(0, 0.5, 0)
		hp.setup(1, 25)
