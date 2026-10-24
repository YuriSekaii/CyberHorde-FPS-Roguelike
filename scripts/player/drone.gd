extends Node3D

@export var drone_index: int = 0
var fire_cooldown: float = 0.0
# Pulse Carbine base fire rate is 0.12s. 1/10 fire rate is 1.2s per shot.
var base_fire_interval: float = 1.2
var target_enemy: Node3D = null

@onready var light: OmniLight3D = $DroneLight
@onready var ring: MeshInstance3D = $DroneRing

const BULLET_SCENE = preload("res://scenes/projectiles/bullet.tscn")

func _ready() -> void:
	# Stagger initial shot timing based on drone index so multiple drones create rhythmic volley
	fire_cooldown = float(drone_index) * 0.35

func update_drone(delta: float, player_ref: Node3D, total_drones: int) -> void:
	if not is_instance_valid(player_ref):
		return
	
	# Smooth orbital flight formation around player
	var t = Time.get_ticks_msec() / 1000.0
	var angle_offset = (TAU / float(maxi(1, total_drones))) * float(drone_index)
	var orbit_angle = t * 1.5 + angle_offset
	var radius = 1.85
	var target_pos = player_ref.global_position + Vector3(
		cos(orbit_angle) * radius,
		1.75 + sin(t * 2.5 + float(drone_index)) * 0.15,
		sin(orbit_angle) * radius
	)
	
	global_position = global_position.lerp(target_pos, clampf(14.0 * delta, 0.0, 1.0))
	
	# Rotate cyan stabilizer ring
	if ring:
		ring.rotate_y(3.5 * delta)
	
	# Update fire cooldown
	fire_cooldown -= delta
	
	# Seek nearest alive enemy within 35 meters
	_find_target()
	
	if is_instance_valid(target_enemy):
		var enemy_aim_pos = target_enemy.global_position + Vector3(0, 0.7, 0)
		look_at(enemy_aim_pos, Vector3.UP)
		
		# Fires at 1/10 fire rate of Pulse Carbine, scaled by player's Overclock Trigger upgrades!
		var effective_cooldown = base_fire_interval / GameManager.fire_rate_mult
		if fire_cooldown <= 0.0:
			fire_cooldown = effective_cooldown
			_fire_pulse_carbine(enemy_aim_pos)
	else:
		# Idle aim forward along orbit tangential velocity
		var forward_dir = Vector3(-sin(orbit_angle), 0, cos(orbit_angle))
		if forward_dir.length_squared() > 0.01:
			look_at(global_position + forward_dir, Vector3.UP)

func _find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_dist: float = 35.0
	var best: Node3D = null
	for e in enemies:
		if e is Node3D and is_instance_valid(e) and not e.is_queued_for_deletion():
			var d = global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best = e
	target_enemy = best

func _fire_pulse_carbine(target_pos: Vector3) -> void:
	var aim_dir = (target_pos - global_position).normalized()
	
	# Inherits Multi-Barrel Splitter (+100% projectiles)
	var total_bullets = int(round(1.0 * (1.0 + GameManager.extra_projectile_mult)))
	
	SoundManager.play("shoot_rifle", 0.08, 2.4 + randf_range(-0.3, 0.3))
	
	# Flash drone light
	if light:
		light.light_energy = 4.0
		var tw = create_tween()
		tw.tween_property(light, "light_energy", 1.5, 0.08)
	
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_parent()
	
	for i in range(total_bullets):
		var bullet = BULLET_SCENE.instantiate()
		scene_root.add_child(bullet)
		bullet.global_position = global_position + aim_dir * 0.4
		
		# Direction with slight spread if multishot
		var spread_angle = 0.02
		if total_bullets > 1:
			spread_angle = 0.045
		
		var spread_x = randf_range(-spread_angle, spread_angle)
		var spread_y = randf_range(-spread_angle, spread_angle)
		var bullet_dir = (aim_dir + transform.basis.x * spread_x + transform.basis.y * spread_y).normalized()
		
		# Pulse Carbine base stats: 22.0 base damage, kinetic
		# Inherits ALL player weapon perks automatically:
		# - Heavy Caliber (+25% damage per stack, infinite stacks)
		# - Hyper-Penetrator (piercing)
		# - Explosive Payload (detonates on hit)
		# - Tesla Arc Emitter (chain lightning)
		# - Smart Bouncing Core (ricochets with on-bounce explosion and lightning)
		# - Cryo Rounds (slows enemies)
		# - Critical hits
		bullet.setup(bullet_dir, 22.0, false, false)
