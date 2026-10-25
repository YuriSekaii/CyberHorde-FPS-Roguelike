extends "res://scripts/enemies/enemy_base.gd"

var attack_cooldown: float = 0.5
const ATTACK_RATE: float = 0.8
const ATTACK_RANGE: float = 1.6

func _ready() -> void:
	super._ready()
	attack_cooldown = 0.5

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	
	attack_cooldown -= delta
	
	var to_player = target_player.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	
	if dist > 0.1:
		var dir = to_player.normalized()
		# Face player smoothly
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 12.0 * delta)
		
		var effective_speed = speed * slow_multiplier
		velocity.x = dir.x * effective_speed
		velocity.z = dir.z * effective_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	move_and_slide()
	
	# Attack if in range
	if dist <= ATTACK_RANGE and attack_cooldown <= 0.0:
		attack_cooldown = ATTACK_RATE / attack_speed_mult
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
			SoundManager.play("player_hurt", 0.1, 0.0)
