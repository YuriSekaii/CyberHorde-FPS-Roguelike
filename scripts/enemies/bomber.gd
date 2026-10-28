extends "res://scripts/enemies/enemy_base.gd"

# Suicide unit: rushes the nearest operative and detonates within TRIGGER_RANGE.
# Also detonates on death (killing it next to you still hurts).
const TRIGGER_RANGE: float = 2.0
const EXPLOSION_RADIUS: float = 3.0

var detonate_on_death: bool = true
var pulse_time: float = 0.0

@onready var core_light: OmniLight3D = $MeshRoot/CoreLight
@onready var beacon: MeshInstance3D = $MeshRoot/Beacon
@onready var leg_nodes: Array[Node3D] = [$MeshRoot/LegFL, $MeshRoot/LegFR, $MeshRoot/LegBL, $MeshRoot/LegBR]

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	var full_to_player = target_player.global_position - global_position
	var dist_3d = full_to_player.length()
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
	_animate(delta, dist_3d)

	# Proximity fuse: any operative within TRIGGER_RANGE sets it off
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p is CharacterBody3D and p.get("is_downed") != true:
			if global_position.distance_to(p.global_position) <= TRIGGER_RANGE:
				die()
				return

func _animate(delta: float, dist: float) -> void:
	# Beacon blinks faster the closer it gets to its target
	var blink_rate = lerpf(18.0, 4.0, clampf(dist / 20.0, 0.0, 1.0))
	pulse_time += delta * blink_rate
	var pulse = (sin(pulse_time) + 1.0) * 0.5
	if core_light:
		core_light.light_energy = lerpf(0.6, 3.0, pulse)
	if beacon:
		beacon.visible = pulse > 0.35

	# Scuttling legs
	var stride = sin(Time.get_ticks_msec() * 0.022) * 0.45
	for i in range(leg_nodes.size()):
		if is_instance_valid(leg_nodes[i]):
			leg_nodes[i].rotation.x = stride if i % 3 == 0 else -stride

func die() -> void:
	if is_dead:
		return
	if detonate_on_death:
		_detonate()
	super.die()

func _detonate() -> void:
	var blast_pos = global_position + Vector3(0, 0.4, 0)
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p is CharacterBody3D:
			if blast_pos.distance_to(p.global_position) <= EXPLOSION_RADIUS and p.has_method("take_damage"):
				p.take_damage(attack_damage)
	# Visual only (0 damage): enemy blasts never hurt other enemies
	Explosion.spawn_explosion(get_parent(), blast_pos, 0.0, EXPLOSION_RADIUS)
