extends "res://scripts/enemies/enemy_base.gd"

# Flying gunship drone: orbits the target operative at altitude and fires thin, fast laser bolts.
var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 1.2 # Double the Spitter's fire rate (2.4s)
const LASER_SPEED: float = 48.0 # Double the Spitter orb speed (24 m/s)
const ORBIT_RADIUS: float = 11.0
const HOVER_HEIGHT: float = 3.5
var orbit_dir: float = 1.0
var bob_phase: float = 0.0

const LASER_SCENE = preload("res://scenes/projectiles/enemy_laser.tscn")

@onready var wing_left: Node3D = $MeshRoot/WingLeft
@onready var wing_right: Node3D = $MeshRoot/WingRight

func _ready() -> void:
	super._ready()
	orbit_dir = 1.0 if randf() > 0.5 else -1.0
	bob_phase = randf() * TAU
	shoot_timer = randf_range(0.6, 1.4) / attack_speed_mult

func _behave(delta: float) -> void:
	shoot_timer -= delta
	bob_phase += delta * 2.2

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var forward_dir = to_player.normalized()

	# Face player
	var target_rot = atan2(-forward_dir.x, -forward_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)

	# Altitude: hover above the operative with a gentle bob
	var target_y = clampf(target_player.global_position.y + HOVER_HEIGHT + sin(bob_phase) * 0.8, 2.5, 10.0)
	velocity.y = (target_y - global_position.y) * 3.0

	# Orbit around the target, pulling in/out toward the orbit ring
	var effective_speed = speed * slow_multiplier
	var horiz = Vector3(to_player.x, 0.0, to_player.z)
	var horiz_dist = horiz.length()
	var horiz_dir = horiz.normalized() if horiz_dist > 0.01 else Vector3.FORWARD
	var tangent = horiz_dir.cross(Vector3.UP).normalized()
	var radial = clampf((horiz_dist - ORBIT_RADIUS) / 4.0, -1.0, 1.0)
	var move_vec = (tangent * orbit_dir + horiz_dir * radial).normalized() * effective_speed

	velocity.x = move_vec.x
	velocity.z = move_vec.z

	move_and_slide()

	# Keep within arena perimeter bounds
	if absf(global_position.x) > 28.5:
		global_position.x = clampf(global_position.x, -28.5, 28.5)
		orbit_dir = -orbit_dir
	if absf(global_position.z) > 28.5:
		global_position.z = clampf(global_position.z, -28.5, 28.5)
		orbit_dir = -orbit_dir

	# Occasionally reverse orbit to stay unpredictable
	if randf() < 0.004:
		orbit_dir *= -1.0

	# Wing buzz
	var flap = sin(Time.get_ticks_msec() * 0.06) * 0.35
	if wing_left:
		wing_left.rotation.z = flap
	if wing_right:
		wing_right.rotation.z = -flap

	if shoot_timer <= 0.0 and dist <= 28.0:
		shoot_timer = SHOOT_INTERVAL / attack_speed_mult
		_shoot()

func _shoot() -> void:
	var laser = LASER_SCENE.instantiate()
	get_parent().add_child(laser)
	laser.global_position = global_position + Vector3(0, -0.1, 0)
	var aim_target = target_player.global_position + Vector3(0, 1.0, 0)
	var dir = (aim_target - laser.global_position).normalized()
	laser.setup(dir, attack_damage, LASER_SPEED)
	SoundManager.play_pitch("shoot_plasma", 1.7, -5.0)
