extends Node3D

@export var drone_index: int = 0
@export var assigned_weapon_idx: int = -1

var fire_cooldown: float = 0.0
var target_enemy: Node3D = null

# Assigned weapon state
var current_ammo: int = -1
var is_reloading: bool = false
var reload_timer: float = 0.0
var idle_timer: float = 0.0
var _visuals_applied: bool = false
var _was_berserk: bool = false

@onready var light: OmniLight3D = $DroneLight
@onready var ring: MeshInstance3D = $DroneRing

const BULLET_SCENE = preload("res://scenes/projectiles/bullet.tscn")

func _ready() -> void:
	if assigned_weapon_idx < 0:
		assigned_weapon_idx = randi() % 3
	_apply_weapon_visuals()
	# Stagger initial shot timing based on drone index so multiple drones create rhythmic volley
	fire_cooldown = float(drone_index) * 0.25

func _apply_weapon_visuals() -> void:
	if _visuals_applied or not is_inside_tree():
		return
	_visuals_applied = true
	var col: Color = Color(0.0, 0.95, 1.0)
	match assigned_weapon_idx:
		0: col = Color(0.0, 0.95, 1.0)   # Cyan: Pulse Carbine
		1: col = Color(1.0, 0.55, 0.08)  # Orange: Scatter Cannon
		2: col = Color(0.9, 0.2, 1.0)    # Magenta: Plasma Core
	if light:
		light.light_color = col
	if ring:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		ring.material_override = mat

func update_drone(delta: float, player_ref: Node3D, total_drones: int) -> void:
	if not is_instance_valid(player_ref) or player_ref.weapons.is_empty():
		return
	
	if not _visuals_applied:
		_apply_weapon_visuals()
	
	if assigned_weapon_idx < 0 or assigned_weapon_idx >= player_ref.weapons.size():
		assigned_weapon_idx = randi() % player_ref.weapons.size()
	var cur_weapon = player_ref.weapons[assigned_weapon_idx]
	
	# Initialize or clamp ammo to weapon's current max_ammo (which scales with Extended Mag)
	if current_ammo < 0:
		current_ammo = cur_weapon.max_ammo
	else:
		current_ammo = mini(current_ammo, cur_weapon.max_ammo)
	
	var is_berserk: bool = false
	if is_instance_valid(player_ref):
		is_berserk = (player_ref.get("is_gunner_active") == true or player_ref.get("is_slayer_active") == true)
	
	# Berserk skill transition: if active ends, reload drone to max_ammo
	if _was_berserk and not is_berserk:
		current_ammo = cur_weapon.max_ammo
		is_reloading = false
		reload_timer = 0.0
		if light:
			light.light_energy = 1.5
	# If berserk just activated while reloading, interrupt reload immediately so drone can shoot
	if is_berserk and is_reloading:
		is_reloading = false
		reload_timer = 0.0
	_was_berserk = is_berserk
	
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
	
	# Stabilizer ring rotation (spins fastest in Berserk, fast while reloading, normal otherwise)
	if ring:
		ring.rotate_y((14.0 if is_berserk else (7.0 if is_reloading else 3.5)) * delta)
	
	# Handle reload countdown
	if is_reloading:
		reload_timer -= delta
		if light:
			light.light_energy = 1.0 + sin(Time.get_ticks_msec() * 0.015) * 0.8
		if reload_timer <= 0.0:
			is_reloading = false
			reload_timer = 0.0
			current_ammo = cur_weapon.max_ammo
			if light:
				light.light_energy = 1.5
	elif is_berserk and light:
		# Pulsate with intense berserk energy during active
		light.light_energy = 2.2 + sin(Time.get_ticks_msec() * 0.025) * 1.2
	
	# Trigger reload if empty or if player reloads their weapon (disabled during Berserk Overdrive)
	if not is_reloading and not is_berserk:
		if current_ammo <= 0:
			_start_reload(cur_weapon)
		elif player_ref.is_reloading and current_ammo < cur_weapon.max_ammo:
			_start_reload(cur_weapon)
	
	# Update fire cooldown
	fire_cooldown -= delta
	
	# Seek nearest alive enemy within 35 meters
	_find_target()
	
	if is_instance_valid(target_enemy):
		idle_timer = 0.0
		var enemy_aim_pos = target_enemy.global_position + Vector3(0, 0.7, 0)
		look_at(enemy_aim_pos, Vector3.UP)
		
		# Fires at assigned weapon fire rate (1/4 rate for rapid weapons, full 0.2 shot/s for heavy plasma), scaled by Overclock Trigger and Gunner Active (+500% MORE fire rate)
		var gunner_fr_mult: float = 6.0 if is_berserk else 1.0
		var effective_cooldown = maxf(0.02, (((cur_weapon.fire_rate) if assigned_weapon_idx == 2 else (cur_weapon.fire_rate * 4.0)) / (GameManager.fire_rate_mult * gunner_fr_mult)))
		if fire_cooldown <= 0.0 and not is_reloading:
			if current_ammo > 0 or is_berserk:
				fire_cooldown = effective_cooldown
				_fire_weapon(enemy_aim_pos, cur_weapon, assigned_weapon_idx == 2, player_ref, is_berserk)
			else:
				_start_reload(cur_weapon)
	else:
		# Idle reload after 3s out of combat if magazine is not full (only outside Berserk)
		if not is_reloading and not is_berserk and current_ammo < cur_weapon.max_ammo:
			idle_timer += delta
			if idle_timer >= 3.0:
				idle_timer = 0.0
				_start_reload(cur_weapon)
		else:
			idle_timer = 0.0
		
		# Idle aim forward along orbit tangential velocity
		var forward_dir = Vector3(-sin(orbit_angle), 0, cos(orbit_angle))
		if forward_dir.length_squared() > 0.01:
			look_at(global_position + forward_dir, Vector3.UP)

func _start_reload(w) -> void:
	if is_reloading:
		return
	is_reloading = true
	# Matches assigned weapon's reload speed, scaled by Rapid Loader upgrades
	reload_timer = w.reload_time
	SoundManager.play("reload", 0.08, -4.0)

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

func _fire_weapon(target_pos: Vector3, w, is_plasma: bool, p_owner: Node = null, is_berserk: bool = false) -> void:
	var aim_dir = (target_pos - global_position).normalized()
	
	# Consume magazine ammo only when not in Berserk Overdrive
	if not is_berserk:
		current_ammo -= 1
	
	# Inherits weapon base pellets and Multi-Barrel Splitter (+100% projectiles per stack)
	var total_bullets = int(round(float(w.pellets) * (1.0 + GameManager.extra_projectile_mult)))
	
	SoundManager.play(w.sound_name, 0.08, -2.0)
	
	# Flash drone light
	if light:
		light.light_energy = 4.0
		var tw = create_tween()
		tw.tween_property(light, "light_energy", 1.5, 0.08)
	
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_parent()
	
	# Inherits Gunner Passive (+25% critical strike chance)
	var is_gunner = (p_owner != null and (p_owner.get("player_class") == "gunner" or p_owner.get("player_class") == "slayer"))
	var crit_bonus: float = 0.25 if is_gunner else 0.0
	
	for i in range(total_bullets):
		var bullet = BULLET_SCENE.instantiate()
		scene_root.add_child(bullet)
		bullet.global_position = global_position + aim_dir * 0.4
		
		# Direction with spread matching assigned weapon spread
		var spread_angle = w.spread
		if total_bullets > 1:
			spread_angle = maxf(spread_angle, 0.045)
		if total_bullets > 7:
			spread_angle *= 1.2
		
		var spread_x = randf_range(-spread_angle, spread_angle)
		var spread_y = randf_range(-spread_angle, spread_angle)
		var bullet_dir = (aim_dir + transform.basis.x * spread_x + transform.basis.y * spread_y).normalized()
		
		# Matches assigned weapon base stats (damage, explosive, plasma),
		# and inherits ALL player weapon perks automatically:
		# - Heavy Caliber (+25% damage per stack, infinite stacks)
		# - Hyper-Penetrator (piercing)
		# - Explosive Payload (detonates on hit)
		# - Tesla Arc Emitter (chain lightning)
		# - Smart Bouncing Core (ricochets with on-bounce explosion and lightning)
		# - Cryo Rounds (slows enemies)
		# - Precision Optics & Hollow-Point Rounds (critical hits)
		# - Gunner Passive (+25% critical strike chance)
		# - Multi-Barrel Splitter (extra projectiles)
		# - Extended Mag (same magazine capacity)
		# - Rapid Loader (same reload speed)
		bullet.setup(bullet_dir, w.damage, w.is_explosive, is_plasma, w.base_crit_chance + crit_bonus, p_owner)
	
	if not is_berserk and current_ammo <= 0:
		_start_reload(w)
