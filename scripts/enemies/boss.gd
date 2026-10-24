extends "res://scripts/enemies/enemy_base.gd"

## Apex Overlord - Wave 100 Final Boss
## Features 3 dynamic combat phases, dual plasma shoulder cannons,
## arena-wide tremor stomps, energy shielding, and escort summoning.

enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
var current_phase: BossPhase = BossPhase.PHASE_1

# Attack timers & intervals
var cannon_cooldown: float = 2.0
var base_cannon_interval: float = 2.2
var slam_cooldown: float = 6.0
var base_slam_interval: float = 7.5
var is_charging_slam: bool = false
var slam_charge_timer: float = 0.0
const SLAM_CHARGE_DURATION: float = 0.95
const SLAM_RADIUS: float = 10.0

# Minion summoning flags
var has_summoned_phase2: bool = false
var has_summoned_phase3: bool = false

# Left/Right alternating cannon firing
var fire_left_next: bool = true

# Node references
@onready var core_mesh: MeshInstance3D = $MeshRoot/ReactorCore
@onready var core_light: OmniLight3D = $MeshRoot/CoreLight
@onready var slam_light: OmniLight3D = $MeshRoot/SlamLight
@onready var visor_mesh: MeshInstance3D = $MeshRoot/Visor
@onready var left_muzzle: Node3D = $MeshRoot/LeftArm/LeftMuzzle
@onready var right_muzzle: Node3D = $MeshRoot/RightArm/RightMuzzle

const PROJECTILE_SCENE = preload("res://scenes/projectiles/enemy_projectile.tscn")
const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")
const SWARMER_SCENE = preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")

var core_material: StandardMaterial3D

func _ready() -> void:
	enemy_name = "Apex Overlord"
	
	# Create unique core material for phase transitions
	core_material = StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(1.0, 0.15, 0.15) # Phase 1: Crimson Red
	if core_mesh:
		core_mesh.material_override = core_material
	
	if slam_light:
		slam_light.visible = false
	
	super._ready()
	
	# Notify GameManager and HUD of Boss arrival
	GameManager.boss_spawned.emit(self)
	GameManager.boss_health_updated.emit(current_health, max_health)
	SoundManager.play("level_up", 0.3, -2.5)

func _apply_wave_scaling() -> void:
	var wave_num = GameManager.current_wave
	
	# Final Boss HP scaling:
	# Wave 1 base = 3500. Compounding up to Wave 100 (~500,000 HP)
	var hp_scale = pow(1.052, float(maxi(0, wave_num - 1)))
	max_health = 3500.0 * hp_scale
	current_health = max_health
	
	# Damage scaling (5% per wave, clamped to avoid instant-death spikes)
	var dmg_scale = pow(1.05, float(maxi(0, wave_num - 1)))
	attack_damage = clampf(40.0 * dmg_scale, 40.0, 180.0)
	
	# Movement & Attack Speed (every 10 waves: +5%)
	var speed_tier: int = int(wave_num / 10)
	var speed_factor: float = 1.0 + (float(speed_tier) * 0.05)
	speed = 4.2 * speed_factor
	attack_speed_mult = speed_factor
	
	# Damage reduction (every 10 waves: +10%, capped at 90%)
	var reduction_tier: int = int(wave_num / 10)
	damage_reduction = clampf(float(reduction_tier) * 0.10, 0.0, 0.90)

func take_damage(amount: float, is_crit: bool, from_pos: Vector3) -> void:
	super.take_damage(amount, is_crit, from_pos)
	
	if not is_dead:
		GameManager.boss_health_updated.emit(current_health, max_health)
		_check_phase_transitions()

func _check_phase_transitions() -> void:
	var hp_ratio = current_health / max_health
	
	# Phase 2 Transition (HP <= 60%)
	if hp_ratio <= 0.60 and current_phase == BossPhase.PHASE_1:
		current_phase = BossPhase.PHASE_2
		_enter_phase_2()
	
	# Phase 3 Transition (HP <= 30%)
	if hp_ratio <= 0.30 and current_phase == BossPhase.PHASE_2:
		current_phase = BossPhase.PHASE_3
		_enter_phase_3()

func _enter_phase_2() -> void:
	# Orange Overcharge state
	if core_material:
		core_material.albedo_color = Color(1.0, 0.55, 0.05)
	if core_light:
		core_light.light_color = Color(1.0, 0.55, 0.05)
		core_light.light_energy = 5.5
	
	base_cannon_interval = 1.8
	base_slam_interval = 6.0
	
	SoundManager.play("level_up", 0.3, 0.5)
	
	if not has_summoned_phase2:
		has_summoned_phase2 = true
		_summon_escort([0, 0, 1]) # 2 Swarmers, 1 Spitter

func _enter_phase_3() -> void:
	# Meltdown Berserk state: Blazing Violet
	if core_material:
		core_material.albedo_color = Color(0.95, 0.15, 0.95)
	if core_light:
		core_light.light_color = Color(0.95, 0.15, 0.95)
		core_light.light_energy = 8.0
	
	speed *= 1.25
	base_cannon_interval = 1.3
	base_slam_interval = 4.5
	
	SoundManager.play("explosion", 0.25, 1.0)
	
	if not has_summoned_phase3:
		has_summoned_phase3 = true
		_summon_escort([1, 1, 0, 0]) # 2 Spitters, 2 Swarmers

func _summon_escort(type_ids: Array) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
	
	for i in range(type_ids.size()):
		var t_id = int(type_ids[i])
		var angle = (TAU / float(type_ids.size())) * float(i)
		var offset = Vector3(cos(angle) * 5.0, 0.5, sin(angle) * 5.0)
		var spawn_pos = global_position + offset
		spawn_pos.x = clampf(spawn_pos.x, -26.0, 26.0)
		spawn_pos.z = clampf(spawn_pos.z, -26.0, 26.0)
		
		var scn = SWARMER_SCENE if t_id == 0 else SPITTER_SCENE
		var escort = scn.instantiate()
		escort.name = "BossEscort_%d_%d" % [Time.get_ticks_msec(), i]
		parent_node.call_deferred("add_child", escort)
		escort.global_position = spawn_pos

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	
	cannon_cooldown -= delta
	slam_cooldown -= delta
	
	var to_player = target_player.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	var dir = to_player.normalized()
	
	# Rotate towards player smoothly
	if dist > 0.1:
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 4.5 * delta)
	
	# Pulse reactor core in Phase 3
	if current_phase == BossPhase.PHASE_3 and core_light:
		core_light.light_energy = 6.0 + sin(Time.get_ticks_msec() * 0.01) * 3.0
	
	# Slam Charge state
	if is_charging_slam:
		slam_charge_timer += delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if slam_charge_timer >= SLAM_CHARGE_DURATION:
			_execute_tremor_stomp()
		return
	
	# Normal pursuit movement
	var effective_speed = speed * slow_multiplier
	if dist > 6.0:
		velocity.x = dir.x * effective_speed + knockback_velocity.x * 0.15
		velocity.z = dir.z * effective_speed + knockback_velocity.z * 0.15
	else:
		# Slow down when within stomping range
		velocity.x = dir.x * (effective_speed * 0.3)
		velocity.z = dir.z * (effective_speed * 0.3)
	
	move_and_slide()
	
	# Attack 1: Dual Plasma Cannons
	var eff_cannon_interval = base_cannon_interval / attack_speed_mult
	if cannon_cooldown <= 0.0 and dist <= 35.0:
		cannon_cooldown = eff_cannon_interval
		_fire_plasma_cannons(dir)
	
	# Attack 2: Tremor Stomp
	var eff_slam_interval = base_slam_interval / attack_speed_mult
	if slam_cooldown <= 0.0 and (dist <= 8.5 or (current_phase == BossPhase.PHASE_3 and dist <= 12.0)):
		_start_slam_charge()

func _fire_plasma_cannons(dir_to_player: Vector3) -> void:
	var muzzle = left_muzzle if fire_left_next else right_muzzle
	fire_left_next = not fire_left_next
	
	var muzzle_pos = muzzle.global_position if muzzle else (global_position + Vector3(0, 2.5, 0))
	var aim_target = target_player.global_position + Vector3(0, 1.0, 0)
	var base_aim_dir = (aim_target - muzzle_pos).normalized()
	
	SoundManager.play("shoot_plasma", 0.15, -3.0)
	
	match current_phase:
		BossPhase.PHASE_1:
			_spawn_plasma_bullet(muzzle_pos, base_aim_dir)
		BossPhase.PHASE_2:
			# 3-bullet spread
			for angle_deg in [-12.0, 0.0, 12.0]:
				var rad = deg_to_rad(angle_deg)
				var spread_dir = base_aim_dir.rotated(Vector3.UP, rad)
				_spawn_plasma_bullet(muzzle_pos, spread_dir)
		BossPhase.PHASE_3:
			# 5-bullet heavy barrage
			for angle_deg in [-20.0, -10.0, 0.0, 10.0, 20.0]:
				var rad = deg_to_rad(angle_deg)
				var spread_dir = base_aim_dir.rotated(Vector3.UP, rad)
				_spawn_plasma_bullet(muzzle_pos, spread_dir)

func _spawn_plasma_bullet(spawn_pos: Vector3, dir: Vector3) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = spawn_pos
	proj.scale = Vector3(1.4, 1.4, 1.4)
	proj.setup(dir, attack_damage)

func _start_slam_charge() -> void:
	is_charging_slam = true
	slam_charge_timer = 0.0
	if slam_light:
		slam_light.visible = true
	SoundManager.play("empty_ammo", 0.15, 2.0)

func _execute_tremor_stomp() -> void:
	is_charging_slam = false
	slam_cooldown = base_slam_interval / attack_speed_mult
	if slam_light:
		slam_light.visible = false
	
	SoundManager.play("explosion", 0.25, -2.0)
	
	# Deal massive AoE damage & vertical launch to all players in radius
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var d = global_position.distance_to(p.global_position)
			if d <= SLAM_RADIUS:
				var falloff = clampf(1.0 - (d / SLAM_RADIUS) * 0.5, 0.5, 1.0)
				if p.has_method("take_damage"):
					p.take_damage(attack_damage * 1.35 * falloff)
				if p.has_method("apply_impulse_jump"):
					p.apply_impulse_jump(14.0 * falloff)
	
	# Spawn visual explosion dust shockwave
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position + Vector3(0, 0.2, 0)
	exp_inst.setup(0.0, SLAM_RADIUS)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	GameManager.boss_defeated.emit()
	SoundManager.play("explosion", 0.3, -3.0)
	
	# Sequential death explosions
	var death_exp = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(death_exp)
	death_exp.global_position = global_position + Vector3(0, 2.0, 0)
	death_exp.setup(0.0, 8.0)
	
	# Boss bonus reward: 800 XP and 500 Scrap
	GameManager.add_xp(800)
	GameManager.add_scrap(500)
	
	GameManager.record_kill(enemy_name)
	
	# Drop multiple health stims and scrap clusters
	for i in range(3):
		var hp = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", hp)
		hp.global_position = global_position + Vector3(randf_range(-2.0, 2.0), 0.5, randf_range(-2.0, 2.0))
		hp.setup(1, 50)
	
	queue_free()
