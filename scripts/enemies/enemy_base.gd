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
var knockback_velocity: Vector3 = Vector3.ZERO

@onready var mesh_root: Node3D = $MeshRoot
const DAMAGE_NUMBER_SCENE = preload("res://scenes/ui/damage_number.tscn")
const LOOT_SCENE = preload("res://scenes/loot/loot_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	# Wave scaling
	var wave_factor = 1.0 + (GameManager.current_wave - 1) * 0.15
	current_health = max_health * wave_factor
	max_health = current_health
	
	_find_player()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		return
	
	# Handle slow debuff
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	
	# Handle knockback decay
	if knockback_velocity.length_squared() > 0.01:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 30.0 * delta)
	
	_behave(delta)

func _behave(_delta: float) -> void:
	# Overridden in child classes
	pass

func take_damage(amount: float, is_crit: bool, from_pos: Vector3) -> void:
	if is_dead:
		return
	
	current_health -= amount
	SoundManager.play( "crit_hit" if is_crit else "enemy_hit", 0.15)
	
	# Spawn floating damage number
	var dnum = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(dnum)
	dnum.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
	dnum.setup(amount, is_crit)
	
	# Flash mesh white/red
	_flash_hit()
	
	# Apply knockback
	var knock_dir = (global_position - from_pos).normalized()
	knock_dir.y = 0.2
	knockback_velocity += knock_dir.normalized() * (6.0 if is_crit else 3.5)
	
	if current_health <= 0:
		die()

func apply_slow(factor: float, duration: float) -> void:
	slow_multiplier = clampf(1.0 - factor, 0.2, 1.0)
	slow_timer = duration

func _flash_hit() -> void:
	if not mesh_root:
		return
	var tw = create_tween()
	mesh_root.scale = Vector3(1.15, 0.85, 1.15)
	tw.tween_property(mesh_root, "scale", Vector3.ONE, 0.15)

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
