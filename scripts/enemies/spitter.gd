extends "res://scripts/enemies/enemy_base.gd"

var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 2.4
const PREFERRED_DIST: float = 12.0
var strafe_dir: float = 1.0

const PROJECTILE_SCENE = preload("res://scenes/projectiles/enemy_projectile.tscn")

func _ready() -> void:
	super._ready()
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	shoot_timer = randf_range(1.0, 2.0)

func _behave(delta: float) -> void:
	shoot_timer -= delta
	
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var forward_dir = to_player.normalized()
	
	# Face player
	var target_rot = atan2(-forward_dir.x, -forward_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)
	
	# Hover height (keep around 2.5m above floor)
	var target_y = target_player.global_position.y + 2.2
	var dy = target_y - global_position.y
	velocity.y = dy * 3.0
	
	# Movement: maintain preferred distance while strafing sideways
	var effective_speed = speed * slow_multiplier
	var right_dir = forward_dir.cross(Vector3.UP).normalized()
	var move_vec = Vector3.ZERO
	
	if dist > PREFERRED_DIST + 2.0:
		move_vec += forward_dir * effective_speed
	elif dist < PREFERRED_DIST - 2.0:
		move_vec -= forward_dir * effective_speed
	
	# Strafe sideways
	move_vec += right_dir * strafe_dir * (effective_speed * 0.7)
	
	velocity.x = move_vec.x
	velocity.z = move_vec.z
	
	move_and_slide()
	
	# Randomly change strafe direction
	if randf() < 0.01:
		strafe_dir *= -1.0
	
	# Shoot plasma
	if shoot_timer <= 0.0 and dist <= 25.0:
		shoot_timer = SHOOT_INTERVAL / attack_speed_mult
		_shoot()

func _shoot() -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.2, 0)
	var aim_target = target_player.global_position + Vector3(0, 1.0, 0)
	var dir = (aim_target - proj.global_position).normalized()
	proj.setup(dir, attack_damage)
	SoundManager.play("shoot_plasma", 0.1, -2.0)
