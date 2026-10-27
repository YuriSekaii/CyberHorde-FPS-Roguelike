extends "res://scripts/enemies/enemy_base.gd"

var spawn_timer: float = 2.0
var wing_timer: float = 0.0
var strafe_dir: float = 1.0
var active_minions: Array[Node] = []
var minion_counter: int = 0

const SPAWN_INTERVAL: float = 4.5
const PREFERRED_HEIGHT: float = 8.5
const PREFERRED_DISTANCE: float = 17.0

const SPAWNLING_SCENE = preload("res://scenes/enemies/spawnling.tscn")
const CHEST_SCENE = preload("res://scenes/loot/chest.tscn")

@onready var wing_left: Node3D = $MeshRoot/WingLeft
@onready var wing_right: Node3D = $MeshRoot/WingRight
@onready var portal_disc: MeshInstance3D = $MeshRoot/GiantMouth/Portal/VortexDisc
@onready var portal_light: OmniLight3D = $MeshRoot/GiantMouth/PortalLight
@onready var portal_particles: CPUParticles3D = $MeshRoot/GiantMouth/PortalParticles
@onready var mouth_spawn_point: Node3D = $MeshRoot/GiantMouth/SpawnPoint

func _ready() -> void:
	super._ready()
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	var base_init_delay = randf_range(1.0, 1.75) if GameManager.current_wave >= 50 else randf_range(2.0, 3.5)
	spawn_timer = base_init_delay / attack_speed_mult
	# Spawner spawns directly in the sky at preferred aerial altitude
	if global_position.y < PREFERRED_HEIGHT * 0.7:
		global_position.y = PREFERRED_HEIGHT

func _behave(delta: float) -> void:
	wing_timer += delta
	
	# Flap large aerial wings
	var wing_angle = sin(wing_timer * 3.8) * 26.0
	if wing_left: wing_left.rotation_degrees.z = wing_angle
	if wing_right: wing_right.rotation_degrees.z = -wing_angle
	
	# Swirl mouth portal
	if portal_disc:
		portal_disc.rotation.z += 5.5 * delta
	if portal_light:
		portal_light.light_energy = 3.0 + sin(wing_timer * 5.0) * 1.2
	
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var forward_dir = to_player.normalized()
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized()
	
	# Smoothly rotate toward player
	if dist > 0.1:
		var target_rot = atan2(-forward_dir.x, -forward_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 4.0 * delta)
	
	# Height hover
	var target_y = target_player.global_position.y + PREFERRED_HEIGHT
	var dy = target_y - global_position.y
	velocity.y = dy * 2.2
	
	# Aerial navigation: maintain preferred distance while strafing
	var effective_speed = speed * slow_multiplier
	var right_dir = forward_dir.cross(Vector3.UP).normalized()
	var move_vec = Vector3.ZERO
	
	if dist > PREFERRED_DISTANCE + 2.5:
		move_vec += forward_dir * effective_speed
	elif dist < PREFERRED_DISTANCE - 2.5:
		move_vec -= forward_dir * effective_speed
	
	move_vec += right_dir * strafe_dir * (effective_speed * 0.75)
	
	velocity.x = move_vec.x
	velocity.z = move_vec.z
	
	move_and_slide()
	
	# Clamp inside arena
	global_position.x = clampf(global_position.x, -27.0, 27.0)
	global_position.z = clampf(global_position.z, -27.0, 27.0)
	
	if randf() < 0.008:
		strafe_dir *= -1.0
	
	# Minion spawning logic
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var eff_interval = (SPAWN_INTERVAL * 0.5) if GameManager.current_wave >= 50 else SPAWN_INTERVAL
		spawn_timer = eff_interval / attack_speed_mult
		_attempt_spawn_minion()

func _attempt_spawn_minion() -> void:
	# Only server initiates in multiplayer
	if NetworkManager.is_multiplayer and not NetworkManager.is_server:
		return
	
	minion_counter += 1
	var spawn_pos = mouth_spawn_point.global_position if mouth_spawn_point else global_position + Vector3(0, 0, -1.5)
	var launch_dir = -global_transform.basis.z.normalized()
	var m_name = "%s_minion_%d" % [name, minion_counter]
	
	if NetworkManager.is_multiplayer:
		rpc_spawn_minion.rpc(spawn_pos, launch_dir, m_name)
	else:
		_do_spawn_minion(spawn_pos, launch_dir, m_name)

@rpc("call_local", "reliable")
func rpc_spawn_minion(pos: Vector3, launch_dir: Vector3, minion_name: String) -> void:
	_do_spawn_minion(pos, launch_dir, minion_name)

func _do_spawn_minion(pos: Vector3, launch_dir: Vector3, minion_name: String) -> void:
	if portal_particles:
		portal_particles.restart()
	
	# Flash portal
	if portal_light:
		portal_light.light_energy = 7.0
		var tw = create_tween()
		tw.tween_property(portal_light, "light_energy", 3.0, 0.4)
	
	var minion = SPAWNLING_SCENE.instantiate()
	minion.name = minion_name
	get_parent().add_child(minion)
	minion.global_position = pos
	minion.velocity = launch_dir * 10.0 + Vector3.UP * 1.5
	active_minions.append(minion)

func _clean_minions() -> void:
	var valid: Array[Node] = []
	for m in active_minions:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			valid.append(m)
	active_minions = valid

func die() -> void:
	if is_dead:
		return
	
	# Drop the upgrade box (Loot Cache) when dies
	var chest_pos = Vector3(global_position.x, 0.5, global_position.z)
	chest_pos.x = clampf(chest_pos.x, -26.0, 26.0)
	chest_pos.z = clampf(chest_pos.z, -26.0, 26.0)
	
	if NetworkManager.is_multiplayer:
		if NetworkManager.is_server:
			rpc_drop_chest.rpc(chest_pos)
	else:
		_drop_chest(chest_pos)
	
	super.die()

@rpc("call_local", "reliable")
func rpc_drop_chest(pos: Vector3) -> void:
	_drop_chest(pos)

func _drop_chest(pos: Vector3) -> void:
	var chest = CHEST_SCENE.instantiate()
	get_parent().call_deferred("add_child", chest)
	chest.position = pos
