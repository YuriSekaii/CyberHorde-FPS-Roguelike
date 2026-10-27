extends "res://scripts/enemies/enemy_base.gd"

enum State { STALKING, WINDUP, CHARGING, STUNNED }

var current_state: State = State.STALKING
var state_timer: float = 0.0
var charge_cooldown: float = 1.0
var charge_direction: Vector3 = Vector3.ZERO
var is_locked: bool = false
var has_damaged_player: bool = false
var walk_anim_timer: float = 0.0

const ATTACK_RANGE: float = 14.0
const WINDUP_TIME: float = 0.85
const LOCK_TIME: float = 0.28
const CHARGE_SPEED: float = 30.0
const STUN_DURATION: float = 3.5
const CHARGE_COOLDOWN_TIME: float = 2.5
const HIT_RADIUS: float = 2.2

const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

@onready var charge_light: OmniLight3D = $MeshRoot/ChargeLight
@onready var head_node: Node3D = $MeshRoot/Head
@onready var horns_left: MeshInstance3D = $MeshRoot/Head/HornLeft
@onready var horns_right: MeshInstance3D = $MeshRoot/Head/HornRight
@onready var leg_fl: Node3D = $MeshRoot/LegFrontLeft
@onready var leg_fr: Node3D = $MeshRoot/LegFrontRight
@onready var leg_bl: Node3D = $MeshRoot/LegBackLeft
@onready var leg_br: Node3D = $MeshRoot/LegBackRight
@onready var stun_particles: CPUParticles3D = $MeshRoot/StunParticles

var normal_horn_mat: StandardMaterial3D
var red_horn_mat: StandardMaterial3D

func _ready() -> void:
	super._ready()
	charge_cooldown = randf_range(1.0, 2.0) / attack_speed_mult
	if charge_light:
		charge_light.visible = false
	if stun_particles:
		stun_particles.emitting = false
	
	_setup_horn_materials()

func _setup_horn_materials() -> void:
	normal_horn_mat = StandardMaterial3D.new()
	normal_horn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	normal_horn_mat.albedo_color = Color(0.2, 0.22, 0.26, 1.0)
	normal_horn_mat.metallic = 0.85
	normal_horn_mat.roughness = 0.25
	
	red_horn_mat = StandardMaterial3D.new()
	red_horn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_horn_mat.albedo_color = Color(1.0, 0.1, 0.05, 1.0)

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	
	if charge_cooldown > 0.0:
		charge_cooldown -= delta
	
	match current_state:
		State.STALKING:
			_process_stalking(delta)
		State.WINDUP:
			_process_windup(delta)
		State.CHARGING:
			_process_charging(delta)
		State.STUNNED:
			_process_stunned(delta)

func _process_stalking(delta: float) -> void:
	var full_to_player = target_player.global_position - global_position
	var dist_3d = full_to_player.length()
	var to_player_horiz = Vector3(full_to_player.x, 0.0, full_to_player.z)
	var horiz_dist = to_player_horiz.length()
	var dir = to_player_horiz.normalized()
	
	if horiz_dist > 0.1:
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 7.0 * delta)
		
		var effective_speed = speed * slow_multiplier
		var move_dir = steer_around_cover(dir, delta)
		velocity.x = move_dir.x * effective_speed
		velocity.z = move_dir.z * effective_speed
		
		# Animate 4 legs
		walk_anim_timer += delta * effective_speed * 2.2
		var leg_swing = sin(walk_anim_timer) * 25.0
		if leg_fl: leg_fl.rotation_degrees.x = leg_swing
		if leg_fr: leg_fr.rotation_degrees.x = -leg_swing
		if leg_bl: leg_bl.rotation_degrees.x = -leg_swing
		if leg_br: leg_br.rotation_degrees.x = leg_swing
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
	
	# Check if inside attack range to wind up
	if dist_3d <= ATTACK_RANGE and absf(full_to_player.y) <= 3.0 and charge_cooldown <= 0.0:
		_start_windup()

func _start_windup() -> void:
	current_state = State.WINDUP
	state_timer = 0.0
	is_locked = false
	velocity.x = 0
	velocity.z = 0
	
	SoundManager.play("charger_windup", 0.08, 1.0)
	
	if charge_light:
		charge_light.visible = true
		charge_light.light_color = Color(1.0, 0.4, 0.1)
		charge_light.light_energy = 2.0

func _process_windup(delta: float) -> void:
	state_timer += delta
	velocity.x = 0
	velocity.z = 0
	move_and_slide()
	
	# Vibrate in place
	if mesh_root:
		mesh_root.position.x = randf_range(-0.06, 0.06)
		mesh_root.position.z = randf_range(-0.06, 0.06)
	
	var eff_windup = WINDUP_TIME / attack_speed_mult
	var eff_lock = LOCK_TIME / attack_speed_mult
	
	# Face player until lock moment
	if not is_locked:
		var to_player = target_player.global_position - global_position
		to_player.y = 0.0
		var dir = to_player.normalized()
		var target_rot = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 12.0 * delta)
		
		# Lock location & flash bright red near the end of windup
		if state_timer >= (eff_windup - eff_lock):
			_lock_charge(dir)
	
	if state_timer >= eff_windup:
		_start_charge()

func _lock_charge(dir: Vector3) -> void:
	is_locked = true
	charge_direction = dir
	
	# Flash red
	if charge_light:
		charge_light.light_color = Color(1.0, 0.05, 0.05)
		charge_light.light_energy = 5.0
	if horns_left:
		horns_left.material_override = red_horn_mat
	if horns_right:
		horns_right.material_override = red_horn_mat
	
	# Flash mesh scale punch
	if mesh_root:
		var tw = create_tween()
		tw.tween_property(mesh_root, "scale", Vector3(1.15, 0.9, 1.15), 0.1)
		tw.tween_property(mesh_root, "scale", Vector3.ONE, 0.1)

func _start_charge() -> void:
	current_state = State.CHARGING
	state_timer = 0.0
	has_damaged_player = false
	if mesh_root:
		mesh_root.position = Vector3.ZERO
	SoundManager.play("shoot_plasma", 0.15, -4.0)

func _process_charging(delta: float) -> void:
	state_timer += delta
	
	var effective_charge_speed = CHARGE_SPEED * wave_speed_mult * slow_multiplier
	velocity.x = charge_direction.x * effective_charge_speed
	velocity.z = charge_direction.z * effective_charge_speed
	
	# Fast leg scramble
	walk_anim_timer += delta * effective_charge_speed
	var leg_swing = sin(walk_anim_timer) * 35.0
	if leg_fl: leg_fl.rotation_degrees.x = leg_swing
	if leg_fr: leg_fr.rotation_degrees.x = -leg_swing
	if leg_bl: leg_bl.rotation_degrees.x = -leg_swing
	if leg_br: leg_br.rotation_degrees.x = leg_swing
	
	# Deal damage to player on contact
	if not has_damaged_player and is_instance_valid(target_player):
		var p_dist = global_position.distance_to(target_player.global_position)
		if p_dist <= HIT_RADIUS:
			has_damaged_player = true
			if target_player.has_method("take_damage"):
				target_player.take_damage(attack_damage)
			if target_player.has_method("apply_impulse_jump"):
				target_player.apply_impulse_jump(8.0)
			target_player.velocity += charge_direction * 14.0
			SoundManager.play("player_hurt", 0.1, 2.0)
	
	move_and_slide()
	
	# Wall detection: check is_on_wall or arena border
	var hit_wall = false
	if is_on_wall():
		hit_wall = true
	elif absf(global_position.x) >= 36.5 or absf(global_position.z) >= 36.5:
		hit_wall = true
	else:
		# Check slide collision normals
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var n = col.get_normal()
			if n.y < 0.6: # Vertical wall/pillar
				hit_wall = true
				break
	
	if hit_wall:
		_impact_wall()
	elif state_timer >= 3.0:
		# Fallback if somehow didn't hit a wall after full charge across arena
		_start_stun(2.0)

func _impact_wall() -> void:
	SoundManager.play("charger_crash", 0.1, 2.0)
	
	# Spawn impact explosion dust/sparks
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position + charge_direction * 0.8
	exp_inst.setup(0.0, 3.2)
	
	_start_stun(STUN_DURATION)

func _start_stun(duration: float) -> void:
	current_state = State.STUNNED
	state_timer = 0.0
	velocity.x = 0
	velocity.z = 0
	
	if charge_light:
		charge_light.visible = false
	if horns_left:
		horns_left.material_override = normal_horn_mat
	if horns_right:
		horns_right.material_override = normal_horn_mat
	
	# Stun visual: droop head, emit stars/sparks
	if head_node:
		var tw = create_tween()
		tw.tween_property(head_node, "rotation_degrees:x", 32.0, 0.2)
	
	if stun_particles:
		stun_particles.emitting = true

func _process_stunned(delta: float) -> void:
	state_timer += delta
	velocity.x = 0
	velocity.z = 0
	move_and_slide()
	
	# Dizzy wobble
	if head_node:
		head_node.rotation_degrees.z = sin(state_timer * 7.0) * 8.0
	
	if state_timer >= STUN_DURATION:
		_recover_from_stun()

func _recover_from_stun() -> void:
	current_state = State.STALKING
	charge_cooldown = CHARGE_COOLDOWN_TIME / attack_speed_mult
	
	if stun_particles:
		stun_particles.emitting = false
	
	if head_node:
		var tw = create_tween()
		tw.tween_property(head_node, "rotation_degrees", Vector3.ZERO, 0.25)
	
	# Reset leg rotations
	if leg_fl: leg_fl.rotation_degrees.x = 0
	if leg_fr: leg_fr.rotation_degrees.x = 0
	if leg_bl: leg_bl.rotation_degrees.x = 0
	if leg_br: leg_br.rotation_degrees.x = 0
