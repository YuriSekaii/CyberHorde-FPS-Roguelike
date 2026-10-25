extends "res://scripts/enemies/enemy_base.gd"

## Apex Overlord - Wave 50 Final Boss
## Multi-Stage Climactic Battle:
## Stage 1: Slow-moving armored juggernaut with ground Slam AoE (high dmg, 14.25m radius) & occasional long-range cannon fire (low dmg).
## Stage 2: Transforms armor into wings, ascends to sky. Standing still shooting slow explosive projectiles (medium dmg, 6.75m AoE), then charges energy, flashes red aura, locks player position (0.7s), and dives at extreme speed (60 m/s) causing massive shockwave (massive dmg, 15.75m AoE).
## Stage 3: Detonates outer armor, revealing a Solid Metal Fallen Angel with massive spread wings. Flies at high speed (32 m/s), unleashing a massive bullet-hell barrage from both hands and both wings simultaneously with tighter focused spread (65 m/s, 6 projectiles/volley). Ends with a giant slow mega orb (18.0m AoE), enters 8s exhaustion cooldown (increased by 5s), then flashes red aura, locks position (0.7s - same as Stage 2), and charges in a supersonic dive (105 m/s, 17.25m AoE). Loops until death.

enum BossStage {
	STAGE_1,
	STAGE_2_TRANSITION,
	STAGE_2,
	STAGE_3_TRANSITION,
	STAGE_3
}

enum Stage2SubState {
	BOMBARD,
	CHARGE_ENERGY,
	LOCK_ON,
	DIVE,
	IMPACT_RECOVERY,
	ASCEND
}

enum Stage3SubState {
	FLIGHT_BARRAGE,
	MEGA_PROJECTILE_CHARGE,
	EXHAUSTION,
	POST_EXHAUST_LOCK_ON,
	POST_EXHAUST_DIVE,
	IMPACT_RECOVERY,
	ASCEND
}

var current_stage: BossStage = BossStage.STAGE_1
var s2_state: Stage2SubState = Stage2SubState.BOMBARD
var s3_state: Stage3SubState = Stage3SubState.FLIGHT_BARRAGE

# Timers & Counters
var state_timer: float = 0.0
var attack_timer: float = 0.0
var slam_cooldown: float = 3.5
var cannon_cooldown: float = 2.0
var is_charging_slam: bool = false
var slam_charge_timer: float = 0.0
const SLAM_CHARGE_DURATION: float = 0.85
const SLAM_RADIUS: float = 14.25

var s2_shots_fired: int = 0
var s3_machine_shots: int = 0
var flight_orbit_angle: float = 0.0
const FLIGHT_ALTITUDE: float = 14.0

var locked_impact_pos: Vector3 = Vector3.ZERO
var active_indicator: Node = null
var fire_left_next: bool = true

# Escort summon flags
var has_summoned_phase2: bool = false
var has_summoned_phase3: bool = false

# Node references - Stage 1 & 2
@onready var core_mesh: MeshInstance3D = $MeshRoot/ArmorRoot/ReactorCore
@onready var core_light: OmniLight3D = $MeshRoot/CoreLight
@onready var visor_mesh: MeshInstance3D = $MeshRoot/ArmorRoot/Visor
@onready var slam_light: OmniLight3D = $MeshRoot/SlamLight
@onready var aura_light: OmniLight3D = $MeshRoot/AuraLight
@onready var aura_shell: MeshInstance3D = $MeshRoot/AuraShell
@onready var armor_root: Node3D = $MeshRoot/ArmorRoot
@onready var true_form_root: Node3D = $MeshRoot/TrueFormRoot
@onready var left_wing_root: Node3D = $MeshRoot/ArmorRoot/LeftWingRoot
@onready var right_wing_root: Node3D = $MeshRoot/ArmorRoot/RightWingRoot
@onready var left_muzzle: Node3D = $MeshRoot/ArmorRoot/LeftArm/LeftMuzzle
@onready var right_muzzle: Node3D = $MeshRoot/ArmorRoot/RightArm/RightMuzzle

# Node references - Stage 3 Solid Metal Fallen Angel
@onready var angel_core: MeshInstance3D = $MeshRoot/TrueFormRoot/AngelCore
@onready var angel_visor: MeshInstance3D = $MeshRoot/TrueFormRoot/AngelHead/AngelVisor
@onready var dark_halo: MeshInstance3D = $MeshRoot/TrueFormRoot/AngelHead/DarkHalo
@onready var left_hand_muzzle: Node3D = $MeshRoot/TrueFormRoot/LeftArm/LeftHandMuzzle
@onready var right_hand_muzzle: Node3D = $MeshRoot/TrueFormRoot/RightArm/RightHandMuzzle
@onready var left_wing_muzzle1: Node3D = $MeshRoot/TrueFormRoot/LeftAngelWing/WingMuzzle1
@onready var left_wing_muzzle2: Node3D = $MeshRoot/TrueFormRoot/LeftAngelWing/WingMuzzle2
@onready var right_wing_muzzle1: Node3D = $MeshRoot/TrueFormRoot/RightAngelWing/WingMuzzle1
@onready var right_wing_muzzle2: Node3D = $MeshRoot/TrueFormRoot/RightAngelWing/WingMuzzle2

const PROJECTILE_SCENE = preload("res://scenes/projectiles/enemy_projectile.tscn")
const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")
const LOCK_INDICATOR_SCENE = preload("res://scenes/enemies/boss_lock_indicator.tscn")
const SWARMER_SCENE = preload("res://scenes/enemies/swarmer.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")

var core_material: StandardMaterial3D
var visor_material: StandardMaterial3D

func _ready() -> void:
	enemy_name = "Apex Overlord"
	
	# Setup materials
	core_material = StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(1.0, 0.15, 0.15) # Stage 1: Crimson Red
	if core_mesh:
		core_mesh.material_override = core_material
	
	visor_material = StandardMaterial3D.new()
	visor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visor_material.albedo_color = Color(1.0, 0.15, 0.15)
	if visor_mesh:
		visor_mesh.material_override = visor_material
	
	if slam_light:
		slam_light.visible = false
	if aura_light:
		aura_light.visible = false
	if aura_shell:
		aura_shell.visible = false
	if true_form_root:
		true_form_root.visible = false
	if armor_root:
		armor_root.visible = true
	
	super._ready()
	
	GameManager.boss_spawned.emit(self)
	GameManager.boss_health_updated.emit(current_health, max_health)
	SoundManager.play("level_up", 0.3, -2.5)

func _apply_wave_scaling() -> void:
	var wave_num = GameManager.current_wave
	
	# Final Boss Fixed HP: exactly 4,444,444 HP (no wave scaling)
	max_health = 4444444.0
	current_health = max_health
	
	# Attack damage scaling (+50% attack across all attacks: base 80.0 -> 120.0, cap: 360.0 -> 540.0)
	var dmg_scale = pow(1.05, float(maxi(0, wave_num - 1)))
	attack_damage = clampf(120.0 * dmg_scale, 120.0, 540.0)
	
	# Final Boss Fixed Speed & Attack Cadence:
	# Keep movement speed and attack speed fixed for calibrated telegraph windows and easier balancing
	speed = 3.2
	wave_speed_mult = 1.0
	attack_speed_mult = 1.0
	
	var reduction_tier: int = int(wave_num / 10)
	damage_reduction = clampf(float(reduction_tier) * 0.10, 0.0, 0.50)

func take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = EnemyBase.DAMAGE_TYPE_DIRECT) -> void:
	# Damage mitigation during cinematic transitions
	if current_stage == BossStage.STAGE_2_TRANSITION or current_stage == BossStage.STAGE_3_TRANSITION:
		amount *= 0.25
	
	super.take_damage(amount, is_crit, from_pos, damage_type)
	
	if not is_dead:
		GameManager.boss_health_updated.emit(current_health, max_health)
		_check_phase_transitions()

func _check_phase_transitions() -> void:
	var hp_ratio = current_health / max_health
	
	# Stage 2 Transition (HP <= 66%)
	if hp_ratio <= 0.66 and current_stage == BossStage.STAGE_1:
		_start_stage_2_transition()
	
	# Stage 3 Transition (HP <= 33%)
	if hp_ratio <= 0.33 and (current_stage == BossStage.STAGE_2 or current_stage == BossStage.STAGE_2_TRANSITION):
		_start_stage_3_transition()

# ----------------- STAGE 2 TRANSITION -----------------

func _start_stage_2_transition() -> void:
	current_stage = BossStage.STAGE_2_TRANSITION
	state_timer = 0.0
	is_charging_slam = false
	if slam_light:
		slam_light.visible = false
	
	# Transform colors to radiant orange/amber
	if core_material:
		core_material.albedo_color = Color(1.0, 0.55, 0.05)
	if visor_material:
		visor_material.albedo_color = Color(1.0, 0.55, 0.05)
	if core_light:
		core_light.light_color = Color(1.0, 0.55, 0.05)
		core_light.light_energy = 6.5
	
	SoundManager.play("level_up", 0.2, 0.5)
	SoundManager.play("plasma_charge", 0.1, -1.0)
	
	# Armor plates move and form wings (smooth procedural unfold)
	if left_wing_root and right_wing_root:
		var wing_tw = create_tween().set_parallel(true)
		wing_tw.tween_property(left_wing_root, "rotation_degrees", Vector3(-15, -25, 25), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		wing_tw.tween_property(right_wing_root, "rotation_degrees", Vector3(-15, 25, -25), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Boss ascends smoothly to the sky
	var ascend_tw = create_tween()
	ascend_tw.tween_property(self, "global_position:y", FLIGHT_ALTITUDE, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	ascend_tw.finished.connect(func():
		current_stage = BossStage.STAGE_2
		s2_state = Stage2SubState.BOMBARD
		s2_shots_fired = 0
		state_timer = 0.0
		attack_timer = 0.0
	)
	
	if not has_summoned_phase2:
		has_summoned_phase2 = true
		_summon_escort([0, 0, 1])

# ----------------- STAGE 3 TRANSITION -----------------

func _start_stage_3_transition() -> void:
	current_stage = BossStage.STAGE_3_TRANSITION
	state_timer = 0.0
	
	if active_indicator:
		active_indicator.queue_free()
		active_indicator = null
	if aura_light:
		aura_light.visible = false
	if aura_shell:
		aura_shell.visible = false
	
	# Stage 3: Detonation jettisons all outer armor, exposing Solid Metal Fallen Angel!
	SoundManager.play("explosion", 0.35, 0.2)
	
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position
	exp_inst.setup(0.0, 9.0)
	
	if armor_root:
		armor_root.visible = false
	if true_form_root:
		true_form_root.visible = true
	
	# Solid Metal Fallen Angel glowing core and visor
	var angel_glow_mat = StandardMaterial3D.new()
	angel_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	angel_glow_mat.albedo_color = Color(1.0, 0.12, 0.3)
	if angel_core:
		angel_core.material_override = angel_glow_mat
	if angel_visor:
		angel_visor.material_override = angel_glow_mat
	if dark_halo:
		dark_halo.material_override = angel_glow_mat
	
	if core_light:
		core_light.light_color = Color(1.0, 0.12, 0.3)
		core_light.light_energy = 10.0
		core_light.omni_range = 18.0
	
	var lift_tw = create_tween()
	lift_tw.tween_property(self, "global_position:y", FLIGHT_ALTITUDE, 0.8)
	lift_tw.finished.connect(func():
		current_stage = BossStage.STAGE_3
		s3_state = Stage3SubState.FLIGHT_BARRAGE
		state_timer = 0.0
		attack_timer = 0.0
		s3_machine_shots = 0
	)
	
	if not has_summoned_phase3:
		has_summoned_phase3 = true
		_summon_escort([1, 1, 0, 0])

func _summon_escort(type_ids: Array) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
	
	for i in range(type_ids.size()):
		var t_id = int(type_ids[i])
		var angle = (TAU / float(type_ids.size())) * float(i)
		var offset = Vector3(cos(angle) * 6.0, 0.5, sin(angle) * 6.0)
		var spawn_pos = global_position + offset
		spawn_pos.x = clampf(spawn_pos.x, -26.0, 26.0)
		spawn_pos.z = clampf(spawn_pos.z, -26.0, 26.0)
		spawn_pos.y = 3.9 if (absf(spawn_pos.x) <= 9.0 and absf(spawn_pos.z) <= 9.0) else 0.5
		
		var scn = SWARMER_SCENE if t_id == 0 else SPITTER_SCENE
		var escort = scn.instantiate()
		escort.name = "BossEscort_%d_%d" % [Time.get_ticks_msec(), i]
		parent_node.call_deferred("add_child", escort)
		escort.global_position = spawn_pos

# ----------------- MAIN BEHAVIOR LOOP -----------------

func _behave(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		return
	
	match current_stage:
		BossStage.STAGE_1:
			_process_stage_1(delta)
		BossStage.STAGE_2_TRANSITION:
			velocity = Vector3.ZERO
		BossStage.STAGE_2:
			_process_stage_2(delta)
		BossStage.STAGE_3_TRANSITION:
			velocity = Vector3.ZERO
		BossStage.STAGE_3:
			_process_stage_3(delta)

# ----------------- STAGE 1: GROUND JUGGERNAUT -----------------

func _process_stage_1(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	
	slam_cooldown -= delta
	cannon_cooldown -= delta
	
	var to_player = target_player.global_position - global_position
	to_player.y = 0.0
	var dist = to_player.length()
	var dir = to_player.normalized()
	
	# Smoothly look at player
	if dist > 0.1:
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 4.0 * delta)
	
	# Slam charge wind-up
	if is_charging_slam:
		slam_charge_timer += delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if slam_charge_timer >= SLAM_CHARGE_DURATION:
			_execute_tremor_stomp()
		return
	
	# Movement logic: Close range triggers slam, far range moves & shoots
	var eff_speed = speed * slow_multiplier
	if dist <= 8.5 and slam_cooldown <= 0.0:
		_start_slam_charge()
		return
	
	# Normal pursuit
	velocity.x = dir.x * eff_speed
	velocity.z = dir.z * eff_speed
	move_and_slide()
	
	# Occasional projectile if player is too far (low dmg)
	var eff_cannon_interval = 2.4
	if dist > 8.5 and cannon_cooldown <= 0.0:
		cannon_cooldown = eff_cannon_interval
		_fire_stage1_cannon()

func _start_slam_charge() -> void:
	is_charging_slam = true
	slam_charge_timer = 0.0
	if slam_light:
		slam_light.visible = true
	SoundManager.play("empty_ammo", 0.1, 2.0)

func _execute_tremor_stomp() -> void:
	is_charging_slam = false
	slam_cooldown = 4.2
	if slam_light:
		slam_light.visible = false
	
	SoundManager.play("explosion", 0.25, -2.0)
	
	# High damage slam AoE
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var d = global_position.distance_to(p.global_position)
			if d <= SLAM_RADIUS:
				var falloff = clampf(1.0 - (d / SLAM_RADIUS) * 0.5, 0.5, 1.0)
				if p.has_method("take_damage"):
					p.take_damage(attack_damage * 1.6 * falloff)
				if p.has_method("apply_impulse_jump"):
					p.apply_impulse_jump(14.0 * falloff)
	
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position + Vector3(0, 0.2, 0)
	exp_inst.setup(0.0, SLAM_RADIUS)

func _fire_stage1_cannon() -> void:
	var muzzle = left_muzzle if fire_left_next else right_muzzle
	fire_left_next = not fire_left_next
	var muzzle_pos = muzzle.global_position if muzzle else (global_position + Vector3(0, 2.5, 0))
	var aim_target = target_player.global_position + Vector3(0, 1.0, 0)
	var dir = (aim_target - muzzle_pos).normalized()
	
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = muzzle_pos
	proj.setup(dir, attack_damage * 0.45, 26.0, false)
	SoundManager.play("shoot_plasma", 0.15, -2.5)

# ----------------- STAGE 2: SKY BOMBARDIER & HYPER DIVE -----------------

func _process_stage_2(delta: float) -> void:
	state_timer += delta
	attack_timer -= delta
	
	# Smoothly orient towards player
	var to_player = target_player.global_position - global_position
	var flat_to_player = Vector3(to_player.x, 0.0, to_player.z)
	if flat_to_player.length() > 0.1:
		var target_rot = atan2(-flat_to_player.x, -flat_to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 4.5 * delta)
	
	match s2_state:
		Stage2SubState.BOMBARD:
			# Stand still in the air with gentle vertical hover
			var hover_y = FLIGHT_ALTITUDE + sin(Time.get_ticks_msec() * 0.003) * 0.35
			global_position.y = lerpf(global_position.y, hover_y, 4.0 * delta)
			velocity = Vector3.ZERO
			
			if attack_timer <= 0.0:
				attack_timer = 0.85
				_fire_stage2_bomb()
				s2_shots_fired += 1
				if s2_shots_fired >= 4:
					s2_state = Stage2SubState.CHARGE_ENERGY
					state_timer = 0.0
		
		Stage2SubState.CHARGE_ENERGY:
			velocity = Vector3.ZERO
			# Pulsing energy buildup
			if core_light:
				core_light.light_energy = 5.0 + (state_timer / 1.8) * 8.0
			
			if state_timer >= 1.8:
				s2_state = Stage2SubState.LOCK_ON
				state_timer = 0.0
				_trigger_stage2_lock_on()
		
		Stage2SubState.LOCK_ON:
			velocity = Vector3.ZERO
			# Red aura flashing telegraph: 0.70s window for player to run away!
			if aura_light:
				aura_light.light_energy = 8.0 + sin(Time.get_ticks_msec() * 0.03) * 6.0
			
			if state_timer >= 0.70:
				s2_state = Stage2SubState.DIVE
				state_timer = 0.0
				SoundManager.play("jump_pad", 0.1, -1.0)
		
		Stage2SubState.DIVE:
			# Extreme speed charge straight at locked impact position (60.0 m/s)
			var dive_vec = locked_impact_pos - global_position
			var dive_dist = dive_vec.length()
			var dive_dir = dive_vec.normalized()
			
			velocity = dive_dir * 60.0
			move_and_slide()
			
			# Check impact with ground or target point
			if global_position.y <= locked_impact_pos.y + 1.2 or dive_dist <= 2.5 or is_on_floor():
				_execute_dive_impact(15.75, 2.2)
				s2_state = Stage2SubState.IMPACT_RECOVERY
				state_timer = 0.0
		
		Stage2SubState.IMPACT_RECOVERY:
			velocity = Vector3.ZERO
			if state_timer >= 1.1:
				s2_state = Stage2SubState.ASCEND
				state_timer = 0.0
		
		Stage2SubState.ASCEND:
			velocity = Vector3(0.0, 18.0, 0.0)
			move_and_slide()
			if global_position.y >= FLIGHT_ALTITUDE:
				global_position.y = FLIGHT_ALTITUDE
				velocity = Vector3.ZERO
				s2_state = Stage2SubState.BOMBARD
				s2_shots_fired = 0
				state_timer = 0.0
				attack_timer = 0.5

func _fire_stage2_bomb() -> void:
	var muzzle = left_muzzle if fire_left_next else right_muzzle
	fire_left_next = not fire_left_next
	var muzzle_pos = muzzle.global_position if muzzle else (global_position + Vector3(0, 1.5, 0))
	var aim_target = target_player.global_position + Vector3(0, 0.5, 0)
	var dir = (aim_target - muzzle_pos).normalized()
	
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = muzzle_pos
	proj.setup(dir, attack_damage * 0.85, 13.0, true, 6.75, attack_damage * 0.85)
	proj.set_projectile_visual(Color(1.0, 0.45, 0.05), Vector3(1.35, 1.35, 1.35))
	SoundManager.play("shoot_plasma", 0.15, -2.0)

func _trigger_stage2_lock_on() -> void:
	if aura_light:
		aura_light.visible = true
		aura_light.light_color = Color(1.0, 0.08, 0.08)
		aura_light.light_energy = 14.0
	if aura_shell:
		aura_shell.visible = true
	
	SoundManager.play("empty_ammo", 0.05, 3.0)
	SoundManager.play("spawn_telegraph", 0.05, 4.0)
	
	locked_impact_pos = target_player.global_position
	# Align to stage surface (3.9) if player is on the elevated platform, otherwise ground floor (0.0)
	locked_impact_pos.y = 3.9 if target_player.global_position.y >= 2.0 else 0.0
	
	if active_indicator:
		active_indicator.queue_free()
	active_indicator = LOCK_INDICATOR_SCENE.instantiate()
	get_parent().add_child(active_indicator)
	active_indicator.global_position = locked_impact_pos
	active_indicator.setup(15.75, 1.2)

func _execute_dive_impact(blast_radius: float, dmg_multiplier: float) -> void:
	if active_indicator:
		active_indicator.burst_and_free()
		active_indicator = null
	if aura_light:
		aura_light.visible = false
	if aura_shell:
		aura_shell.visible = false
	
	SoundManager.play("explosion", 0.3, -3.0)
	
	# Massive damage AoE shockwave
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var d = global_position.distance_to(p.global_position)
			if d <= blast_radius:
				var falloff = clampf(1.0 - (d / blast_radius) * 0.5, 0.5, 1.0)
				if p.has_method("take_damage"):
					p.take_damage(attack_damage * dmg_multiplier * falloff)
				if p.has_method("apply_impulse_jump"):
					p.apply_impulse_jump(16.0 * falloff)
	
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position + Vector3(0, 0.2, 0)
	exp_inst.setup(0.0, blast_radius)

# ----------------- STAGE 3: SOLID METAL FALLEN ANGEL (MASSIVE WINGS & BULLET HELL) -----------------

func _process_stage_3(delta: float) -> void:
	state_timer += delta
	attack_timer -= delta
	
	var to_player = target_player.global_position - global_position
	var flat_to_player = Vector3(to_player.x, 0.0, to_player.z)
	if flat_to_player.length() > 0.1:
		var target_rot = atan2(-flat_to_player.x, -flat_to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 7.5 * delta)
	
	match s3_state:
		Stage3SubState.FLIGHT_BARRAGE:
			# Fast aerial flight weaving around the sky (32.0 m/s)
			flight_orbit_angle += delta * 2.8
			var target_flight_pos = Vector3(cos(flight_orbit_angle) * 20.0, FLIGHT_ALTITUDE + sin(flight_orbit_angle * 1.5) * 2.5, sin(flight_orbit_angle) * 20.0)
			var flight_dir = (target_flight_pos - global_position).normalized()
			velocity = flight_dir * 32.0
			move_and_slide()
			
			# Bullet hell barrage from both hands and both wings simultaneously
			if attack_timer <= 0.0:
				attack_timer = 0.065
				_fire_stage3_machine_gun()
				s3_machine_shots += 1
			
			# Sustained machine gun barrage: 6.0 seconds
			if state_timer >= 6.0:
				velocity = Vector3.ZERO
				s3_state = Stage3SubState.MEGA_PROJECTILE_CHARGE
				state_timer = 0.0
				SoundManager.play("plasma_charge", 0.1, -2.0)
		
		Stage3SubState.MEGA_PROJECTILE_CHARGE:
			velocity = Vector3.ZERO
			if core_light:
				core_light.light_energy = 8.0 + (state_timer / 1.1) * 8.0
			
			if state_timer >= 1.1:
				_fire_stage3_mega_projectile()
				s3_state = Stage3SubState.EXHAUSTION
				state_timer = 0.0
		
		Stage3SubState.EXHAUSTION:
			# Boss is visibly exhausted in the sky waiting for cooldown
			velocity = Vector3.ZERO
			var exhaust_y = FLIGHT_ALTITUDE - 2.5 + sin(Time.get_ticks_msec() * 0.002) * 0.25
			global_position.y = lerpf(global_position.y, exhaust_y, 2.5 * delta)
			
			# Core light dims and flickers weakly
			if core_light:
				core_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.015) * 1.5
			
			# Exhaustion cooldown increased by 5s (3.0s -> 8.0s)
			if state_timer >= 8.0:
				s3_state = Stage3SubState.POST_EXHAUST_LOCK_ON
				state_timer = 0.0
				_trigger_stage3_lock_on()
		
		Stage3SubState.POST_EXHAUST_LOCK_ON:
			velocity = Vector3.ZERO
			# Red aura flashing telegraph: 0.70s window (exact same lock-on time as Stage 2)
			if aura_light:
				aura_light.light_energy = 14.0 + sin(Time.get_ticks_msec() * 0.04) * 8.0
			
			if state_timer >= 0.70:
				s3_state = Stage3SubState.POST_EXHAUST_DIVE
				state_timer = 0.0
				SoundManager.play("jump_pad", 0.1, 0.5)
		
		Stage3SubState.POST_EXHAUST_DIVE:
			# Supersonic hyper dive: 105.0 m/s (significantly faster than Stage 2's 60.0 m/s)
			var dive_vec = locked_impact_pos - global_position
			var dive_dist = dive_vec.length()
			var dive_dir = dive_vec.normalized()
			
			velocity = dive_dir * 105.0
			move_and_slide()
			
			if global_position.y <= locked_impact_pos.y + 1.2 or dive_dist <= 3.0 or is_on_floor():
				_execute_dive_impact(17.25, 2.5)
				s3_state = Stage3SubState.IMPACT_RECOVERY
				state_timer = 0.0
		
		Stage3SubState.IMPACT_RECOVERY:
			velocity = Vector3.ZERO
			if state_timer >= 0.8:
				s3_state = Stage3SubState.ASCEND
				state_timer = 0.0
		
		Stage3SubState.ASCEND:
			velocity = Vector3(0.0, 26.0, 0.0)
			move_and_slide()
			if global_position.y >= FLIGHT_ALTITUDE:
				global_position.y = FLIGHT_ALTITUDE
				velocity = Vector3.ZERO
				s3_state = Stage3SubState.FLIGHT_BARRAGE
				s3_machine_shots = 0
				state_timer = 0.0
				attack_timer = 0.4

func _fire_stage3_machine_gun() -> void:
	var target_center = target_player.global_position + Vector3(0.0, 0.85, 0.0)
	
	# Fires from both hands and both massive wings simultaneously with 50% tighter spread
	var muzzles = [
		{"node": left_hand_muzzle, "h_spread": randf_range(-0.07, 0.02), "v_spread": randf_range(-0.03, 0.03)},
		{"node": right_hand_muzzle, "h_spread": randf_range(-0.02, 0.07), "v_spread": randf_range(-0.03, 0.03)},
		{"node": left_wing_muzzle1, "h_spread": randf_range(-0.23, -0.08), "v_spread": randf_range(-0.05, 0.05)},
		{"node": left_wing_muzzle2, "h_spread": randf_range(-0.14, -0.03), "v_spread": randf_range(-0.04, 0.04)},
		{"node": right_wing_muzzle1, "h_spread": randf_range(0.08, 0.23), "v_spread": randf_range(-0.05, 0.05)},
		{"node": right_wing_muzzle2, "h_spread": randf_range(0.03, 0.14), "v_spread": randf_range(-0.04, 0.04)}
	]
	
	for m_data in muzzles:
		var m_node: Node3D = m_data["node"]
		var spawn_pos = m_node.global_position if m_node else (global_position + Vector3(0.0, 1.2, 0.0))
		var base_dir = (target_center - spawn_pos).normalized()
		
		var right_axis = base_dir.cross(Vector3.UP).normalized()
		if right_axis.length_squared() < 0.01:
			right_axis = Vector3.RIGHT
		
		var spread_dir = base_dir.rotated(Vector3.UP, m_data["h_spread"]).rotated(right_axis, m_data["v_spread"]).normalized()
		
		var proj = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(proj)
		proj.global_position = spawn_pos
		proj.setup(spread_dir, attack_damage * 0.09, 65.0, false)
		proj.set_projectile_visual(Color(1.0, 0.15, 0.35), Vector3(0.42, 0.42, 0.42))
	
	SoundManager.play("shoot_rifle", 0.18, 0.2)

func _fire_stage3_mega_projectile() -> void:
	var muzzle_pos = global_position + Vector3(0.0, 0.4, -1.2).rotated(Vector3.UP, rotation.y)
	var aim_target = target_player.global_position + Vector3(0.0, 0.5, 0.0)
	var dir = (aim_target - muzzle_pos).normalized()
	
	var proj = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = muzzle_pos
	proj.setup(dir, attack_damage * 2.8, 7.5, true, 18.0, attack_damage * 2.8)
	proj.set_projectile_visual(Color(0.9, 0.05, 0.45), Vector3(3.6, 3.6, 3.6))
	SoundManager.play("shoot_plasma", 0.2, -3.5)

func _trigger_stage3_lock_on() -> void:
	if aura_light:
		aura_light.visible = true
		aura_light.light_color = Color(1.0, 0.02, 0.02)
		aura_light.light_energy = 16.0
	if aura_shell:
		aura_shell.visible = true
	
	SoundManager.play("empty_ammo", 0.05, 3.5)
	SoundManager.play("spawn_telegraph", 0.05, 5.0)
	
	locked_impact_pos = target_player.global_position
	# Align to stage surface (3.9) if player is on the elevated platform, otherwise ground floor (0.0)
	locked_impact_pos.y = 3.9 if target_player.global_position.y >= 2.0 else 0.0
	
	if active_indicator:
		active_indicator.queue_free()
	active_indicator = LOCK_INDICATOR_SCENE.instantiate()
	get_parent().add_child(active_indicator)
	active_indicator.global_position = locked_impact_pos
	active_indicator.setup(17.25, 1.2)

# ----------------- DEATH SEQUENCE -----------------

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	if active_indicator:
		active_indicator.queue_free()
		active_indicator = null
	if aura_light:
		aura_light.visible = false
	if aura_shell:
		aura_shell.visible = false
	
	GameManager.boss_defeated.emit()
	SoundManager.play("explosion", 0.3, -3.0)
	
	# Cascading catastrophic death explosions
	var death_exp = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(death_exp)
	death_exp.global_position = global_position + Vector3(0.0, 1.5, 0.0)
	death_exp.setup(0.0, 10.0)
	
	# Generous rewards
	GameManager.add_xp(800)
	GameManager.add_scrap(500)
	GameManager.record_kill(enemy_name)
	
	for i in range(4):
		var hp = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", hp)
		hp.global_position = global_position + Vector3(randf_range(-2.5, 2.5), 0.5, randf_range(-2.5, 2.5))
		hp.setup(1, 50)
	
	queue_free()
