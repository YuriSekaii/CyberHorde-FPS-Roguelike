extends "res://scripts/enemies/enemy_base.gd"

var attack_timer: float = 0.0
var wing_timer: float = 0.0
var drill_rotation_speed: float = 25.0

const ATTACK_INTERVAL: float = 0.15
const CONNECT_RANGE: float = 1.45

@onready var drill_body: Node3D = $MeshRoot/DrillBody
@onready var wing_left: Node3D = $MeshRoot/WingLeft
@onready var wing_right: Node3D = $MeshRoot/WingRight
@onready var contact_sparks: CPUParticles3D = $MeshRoot/DrillBody/ContactSparks
@onready var booster_particles: CPUParticles3D = $MeshRoot/Booster/Particles

func _ready() -> void:
	super._ready()
	attack_timer = 0.05
	if contact_sparks:
		contact_sparks.emitting = false

func _behave(delta: float) -> void:
	var aim_target = target_player.global_position + Vector3(0, 1.1, 0)
	var to_player = aim_target - global_position
	var dist = to_player.length()
	var dir = to_player.normalized()
	
	# Rotate towards player in 3D (flying tracking)
	if dist > 0.1:
		var target_rot_y = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 9.0 * delta)
		var target_rot_x = asin(clampf(dir.y, -0.9, 0.9))
		rotation.x = lerp_angle(rotation.x, target_rot_x, 9.0 * delta)
	
	# Fast aerial homing flight
	var effective_speed = speed * slow_multiplier
	velocity = dir * effective_speed
	
	move_and_slide()
	
	# Wing flutter animation
	wing_timer += delta
	var wing_angle = sin(wing_timer * 36.0) * 35.0
	if wing_left: wing_left.rotation_degrees.z = wing_angle
	if wing_right: wing_right.rotation_degrees.z = -wing_angle
	
	# Drill spinning
	if drill_body:
		drill_body.rotation.z += drill_rotation_speed * delta
	
	# Continuous rapid attack when connected to player
	if dist <= CONNECT_RANGE:
		drill_rotation_speed = 65.0
		if contact_sparks:
			contact_sparks.emitting = true
		
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = ATTACK_INTERVAL / attack_speed_mult
			if target_player.has_method("take_damage"):
				target_player.take_damage(attack_damage)
			SoundManager.play("spawnling_drill", 0.15, -1.0)
	else:
		drill_rotation_speed = 25.0
		if contact_sparks:
			contact_sparks.emitting = false

func is_immune_to(damage_type: int) -> bool:
	# Spawnlings require a direct hit from a bullet to take damage.
	# Immune to ricochet, AoE (explosive), and chain lightning.
	return damage_type != DAMAGE_TYPE_DIRECT

func take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = DAMAGE_TYPE_DIRECT) -> void:
	if damage_type != DAMAGE_TYPE_DIRECT:
		_on_immune_hit(from_pos)
		return
	super.take_damage(amount, is_crit, from_pos, damage_type)
