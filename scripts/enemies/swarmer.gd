extends "res://scripts/enemies/enemy_base.gd"

var attack_cooldown: float = 0.5
const ATTACK_RATE: float = 0.8
const ATTACK_RANGE: float = 1.6

func _ready() -> void:
	super._ready()
	attack_cooldown = 0.5 / attack_speed_mult

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	
	attack_cooldown -= delta
	
	var full_to_player = target_player.global_position - global_position
	var dist_3d = full_to_player.length()
	var dir = nav_direction_to(target_player.global_position, delta)

	if dir != Vector3.ZERO:
		# Face movement direction smoothly
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 12.0 * delta)
		
		var effective_speed = speed * slow_multiplier
		var move_dir = steer_around_cover(dir, delta)
		velocity.x = move_dir.x * effective_speed
		velocity.z = move_dir.z * effective_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	move_and_slide()
	
	# Attack if in 3D range (must be within ATTACK_RANGE in full 3D and vertical offset <= 1.8m)
	if dist_3d <= ATTACK_RANGE and absf(full_to_player.y) <= 1.8 and attack_cooldown <= 0.0:
		attack_cooldown = ATTACK_RATE / attack_speed_mult
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
			SoundManager.play("player_hurt", 0.1, 0.0)
