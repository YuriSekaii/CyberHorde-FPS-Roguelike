extends "res://scripts/enemies/enemy_base.gd"

var slam_cooldown: float = 0.0
var is_charging_slam: bool = false
var charge_timer: float = 0.0
const SLAM_COOLDOWN_TIME: float = 3.5
const SLAM_RANGE: float = 3.8
const SLAM_CHARGE_TIME: float = 0.7

@onready var slam_indicator: OmniLight3D = $MeshRoot/SlamLight
const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

func _ready() -> void:
	super._ready()
	slam_cooldown = 1.0
	if slam_indicator:
		slam_indicator.visible = false

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	slam_cooldown -= delta
	
	var to_player = target_player.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	var dir = to_player.normalized()
	
	if is_charging_slam:
		charge_timer += delta
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		if charge_timer >= SLAM_CHARGE_TIME:
			_execute_slam()
		return
	
	if dist > 0.1:
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 6.0 * delta)
		
		var effective_speed = speed * slow_multiplier
		velocity.x = dir.x * effective_speed + knockback_velocity.x * 0.3
		velocity.z = dir.z * effective_speed + knockback_velocity.z * 0.3
	
	move_and_slide()
	
	if dist <= SLAM_RANGE and slam_cooldown <= 0.0:
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
	
	# Check distance to player for slam damage
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= SLAM_RANGE + 1.0:
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
		if target_player.has_method("apply_impulse_jump"):
			target_player.apply_impulse_jump(10.0)
	
	# Spawn visual explosion dust
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position
	exp_inst.setup(0.0, 4.0) # Visual effect only
