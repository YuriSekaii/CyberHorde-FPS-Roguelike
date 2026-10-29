extends "res://scripts/enemies/enemy_base.gd"

## Shadow Spider - Stage 2 basic melee unit.
## Pitch-black body that vanishes in the dark; only its red eyes stand out. Chases at medium speed and bites
## like a Cyber Swarmer (small damage). Within 5m it pounces at the operative (3x bite damage, 5s cooldown).

const ATTACK_RATE: float = 0.8
const ATTACK_RANGE: float = 1.6
const GRAVITY: float = 18.0
const LEAP_TRIGGER_RANGE: float = 5.0
const LEAP_COOLDOWN: float = 5.0
const LEAP_UP_SPEED: float = 5.5
const LEAP_MAX_HORIZONTAL_SPEED: float = 14.0
const LEAP_HIT_RANGE: float = 1.8
const LEAP_DAMAGE_MULT: float = 3.0

var attack_cooldown: float = 0.5
var leap_cooldown: float = 1.0
var is_leaping: bool = false
var leap_hit_done: bool = false
var leap_air_time: float = 0.0
var gait_time: float = 0.0
var leg_base_rotations: Array[Vector3] = []

@onready var legs_root: Node3D = $MeshRoot/Legs

func _ready() -> void:
	super._ready()
	if legs_root:
		for leg in legs_root.get_children():
			leg_base_rotations.append(leg.rotation)
	attack_cooldown = 0.5 / attack_speed_mult
	leap_cooldown = randf_range(0.5, 1.5)

func _behave(delta: float) -> void:
	attack_cooldown -= delta
	leap_cooldown -= delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var to_player = target_player.global_position - global_position
	var dist_3d = to_player.length()

	if is_leaping:
		leap_air_time += delta
		if not leap_hit_done and dist_3d <= LEAP_HIT_RANGE:
			leap_hit_done = true
			attack_cooldown = ATTACK_RATE / attack_speed_mult
			if target_player.has_method("take_damage"):
				target_player.take_damage(attack_damage * LEAP_DAMAGE_MULT)
				SoundManager.play("player_hurt", 0.1, 1.0)
			velocity.x *= 0.2
			velocity.z *= 0.2
		move_and_slide()
		if leap_air_time > 0.15 and is_on_floor():
			is_leaping = false
		_animate_legs(delta, 0.0)
		return

	var flat = Vector3(to_player.x, 0.0, to_player.z)
	var flat_dist = flat.length()
	if leap_cooldown <= 0.0 and is_on_floor() and flat_dist <= LEAP_TRIGGER_RANGE and flat_dist > 1.2 and absf(to_player.y) <= 2.5:
		_start_leap(flat)
		move_and_slide()
		return

	var dir = nav_direction_to(target_player.global_position, delta)
	if dir != Vector3.ZERO:
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
	_animate_legs(delta, Vector2(velocity.x, velocity.z).length())

	if dist_3d <= ATTACK_RANGE and absf(to_player.y) <= 1.8 and attack_cooldown <= 0.0:
		attack_cooldown = ATTACK_RATE / attack_speed_mult
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
			SoundManager.play("player_hurt", 0.1, 0.0)

func _start_leap(flat_to_player: Vector3) -> void:
	is_leaping = true
	leap_hit_done = false
	leap_air_time = 0.0
	leap_cooldown = LEAP_COOLDOWN / attack_speed_mult
	var flight_time = 2.0 * LEAP_UP_SPEED / GRAVITY
	var dir = flat_to_player.normalized()
	var h_speed = minf(flat_to_player.length() / flight_time, LEAP_MAX_HORIZONTAL_SPEED) * slow_multiplier
	velocity = dir * h_speed + Vector3(0.0, LEAP_UP_SPEED, 0.0)
	rotation.y = atan2(-dir.x, -dir.z)
	SoundManager.play_pitch("dash", 1.8, -10.0)

## Legs sweep forward/back (yaw) and lift (roll) around their base pose; alternating gait per side
func _animate_legs(delta: float, move_speed: float) -> void:
	if not legs_root:
		return
	var legs = legs_root.get_children()
	gait_time += delta * (6.0 + move_speed * 2.2)
	for i in range(mini(legs.size(), leg_base_rotations.size())):
		var leg: Node3D = legs[i]
		var base = leg_base_rotations[i]
		var side = signf(leg.position.x)
		var target = base
		if is_leaping:
			# Legs raised and splayed mid-pounce
			target = base + Vector3(0.0, 0.0, side * 0.55)
		elif move_speed > 0.5:
			var phase = gait_time + (PI if (i % 2) == 0 else 0.0)
			target = base + Vector3(0.0, sin(phase) * 0.3, side * maxf(0.0, cos(phase)) * 0.3)
		leg.rotation = leg.rotation.lerp(target, minf(1.0, 18.0 * delta))
