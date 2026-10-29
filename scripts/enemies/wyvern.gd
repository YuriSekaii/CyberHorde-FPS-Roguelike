extends "res://scripts/enemies/enemy_base.gd"

## Venom Wyvern - Stage 2 ranged flyer (Wave 6+).
## A small jungle drake that circles above the canopy line and spits fast venom globs at a slow rate.
## The glob deals small damage and poisons: -25% move speed and 5 dmg/s for 3s (scaled by the wave damage factor,
## does not stack — a new hit only refreshes the duration).

const SHOOT_INTERVAL: float = 3.4
const PREFERRED_DIST: float = 14.0
const SHOOT_RANGE: float = 30.0
const VENOM_SPEED: float = 42.0
const POISON_BASE_DPS: float = 5.0
const VENOM_COLOR := Color(0.45, 1.0, 0.15)

const PROJECTILE_SCENE = preload("res://scenes/projectiles/enemy_projectile.tscn")

var shoot_timer: float = 0.0
var strafe_dir: float = 1.0
var flap_time: float = 0.0

@onready var left_wing: Node3D = $MeshRoot/LeftWing
@onready var right_wing: Node3D = $MeshRoot/RightWing
@onready var tail: Node3D = $MeshRoot/Tail

func _ready() -> void:
	super._ready()
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	shoot_timer = randf_range(1.5, 2.5) / attack_speed_mult
	flap_time = randf() * TAU

func _behave(delta: float) -> void:
	shoot_timer -= delta

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var forward_dir = to_player.normalized()
	var flat_forward = Vector3(forward_dir.x, 0.0, forward_dir.z).normalized()

	var target_rot = atan2(-forward_dir.x, -forward_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 6.0 * delta)

	# Glide a few metres above the operative, below the tree crowns
	var target_y = clampf(target_player.global_position.y + 3.2, 2.6, 8.0)
	velocity.y = (target_y - global_position.y) * 2.5

	var effective_speed = speed * slow_multiplier
	var right_dir = flat_forward.cross(Vector3.UP).normalized()
	var move_vec = Vector3.ZERO
	if dist > PREFERRED_DIST + 2.5:
		move_vec += flat_forward * effective_speed
	elif dist < PREFERRED_DIST - 2.5:
		move_vec -= flat_forward * effective_speed
	move_vec += right_dir * strafe_dir * (effective_speed * 0.75)
	velocity.x = move_vec.x
	velocity.z = move_vec.z

	move_and_slide()
	if is_on_wall():
		strafe_dir = -strafe_dir

	if absf(global_position.x) > 36.5:
		global_position.x = clampf(global_position.x, -36.5, 36.5)
		strafe_dir = -strafe_dir
	if absf(global_position.z) > 36.5:
		global_position.z = clampf(global_position.z, -36.5, 36.5)
		strafe_dir = -strafe_dir
	if randf() < 0.008:
		strafe_dir *= -1.0

	_animate(delta)

	if shoot_timer <= 0.0 and dist <= SHOOT_RANGE:
		shoot_timer = SHOOT_INTERVAL / attack_speed_mult
		_spit_venom()

func _spit_venom() -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	var mouth = global_position + (-global_transform.basis.z) * 0.9 + Vector3(0, 0.15, 0)
	proj.global_position = mouth
	var aim_target = target_player.global_position + Vector3(0, 1.0, 0)
	proj.setup((aim_target - mouth).normalized(), attack_damage, VENOM_SPEED)
	proj.set_projectile_visual(VENOM_COLOR, Vector3(0.55, 0.55, 0.55))
	proj.poison_dps = POISON_BASE_DPS * GameManager.get_wave_damage_factor()
	SoundManager.play_pitch("shoot_plasma", 1.6, -5.0)

func _animate(delta: float) -> void:
	flap_time += delta * 9.0
	var flap = sin(flap_time) * 0.7
	if left_wing:
		left_wing.rotation.z = flap
	if right_wing:
		right_wing.rotation.z = -flap
	if tail:
		tail.rotation.y = sin(flap_time * 0.4) * 0.35
	if mesh_root and not _is_flashing:
		mesh_root.position.y = sin(flap_time) * -0.08
