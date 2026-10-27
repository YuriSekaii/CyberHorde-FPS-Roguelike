extends "res://scripts/enemies/enemy_base.gd"

var slam_cooldown: float = 0.0
var is_charging_slam: bool = false
var charge_timer: float = 0.0
const SLAM_COOLDOWN_TIME: float = 3.5
const SLAM_RANGE: float = 5.7 # Base 3.8 * 1.5 (+50% attack range)
const SLAM_AOE_RANGE: float = 7.2 # Base 4.8 * 1.5 (+50% AoE range)
const SLAM_CHARGE_TIME: float = 0.56 # Base 0.7 / 1.25 (+25% windup speed)

@onready var slam_indicator: OmniLight3D = $MeshRoot/SlamLight
const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

func _ready() -> void:
	super._ready()
	slam_cooldown = 1.0 / attack_speed_mult
	if slam_indicator:
		slam_indicator.visible = false

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	slam_cooldown -= delta
	
	var full_to_player = target_player.global_position - global_position
	var dist_3d = full_to_player.length()
	var to_player_horiz = Vector3(full_to_player.x, 0.0, full_to_player.z)
	var horiz_dist = to_player_horiz.length()
	var dir = to_player_horiz.normalized()
	
	if is_charging_slam:
		charge_timer += delta
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		var eff_slam_charge_time = SLAM_CHARGE_TIME / attack_speed_mult
		if charge_timer >= eff_slam_charge_time:
			_execute_slam()
		return
	
	if horiz_dist > 0.1:
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 6.0 * delta)
		
		var effective_speed = speed * slow_multiplier
		var move_dir = steer_around_cover(dir, delta)
		velocity.x = move_dir.x * effective_speed
		velocity.z = move_dir.z * effective_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	move_and_slide()
	
	if dist_3d <= SLAM_RANGE and absf(full_to_player.y) <= 3.75 and slam_cooldown <= 0.0:
		_start_slam_charge()

func _start_slam_charge() -> void:
	is_charging_slam = true
	charge_timer = 0.0
	if slam_indicator:
		slam_indicator.visible = true
	SoundManager.play("empty_ammo", 0.1, 3.0)

func _execute_slam() -> void:
	is_charging_slam = false
	slam_cooldown = SLAM_COOLDOWN_TIME / attack_speed_mult
	if slam_indicator:
		slam_indicator.visible = false
	
	SoundManager.play("explosion", 0.1, 2.0)
	
	# Check distance to squad players for slam damage AoE
	var players = get_tree().get_nodes_in_group("player")
	var hit_players: Array = []
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var dist = global_position.distance_to(p.global_position)
			if dist <= SLAM_AOE_RANGE:
				hit_players.append(p)
				if p.has_method("take_damage"):
					p.take_damage(attack_damage)
				if p.has_method("apply_impulse_jump"):
					p.apply_impulse_jump(10.0)
	
	# Fallback to target_player if not covered in player group
	if is_instance_valid(target_player) and not target_player in hit_players:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= SLAM_AOE_RANGE:
			if target_player.has_method("take_damage"):
				target_player.take_damage(attack_damage)
			if target_player.has_method("apply_impulse_jump"):
				target_player.apply_impulse_jump(10.0)
	
	# Spawn visual explosion dust scaled to AoE range
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position
	exp_inst.setup(0.0, SLAM_AOE_RANGE) # Visual effect only
