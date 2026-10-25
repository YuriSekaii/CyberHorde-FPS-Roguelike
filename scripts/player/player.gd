extends CharacterBody3D

signal health_changed(current: float, max_hp: float)
signal shield_changed(current: float, max_shield: float)
signal ammo_changed(current: int, max_mag: int, is_reloading: bool)
signal weapon_changed(weapon_index: int, weapon_name: String)
signal charge_changed(ratio: float)
signal downed_state_changed(is_downed: bool)

# Multiplayer & Identity
var peer_id: int = 1
var is_local_player: bool = true
var is_downed: bool = false
var bleedout_timer: float = 30.0
var revive_progress: float = 0.0
var target_net_pos: Vector3 = Vector3.ZERO
var target_net_rot_y: float = 0.0
var target_net_head_pitch: float = 0.0
var net_sync_timer: float = 0.0

# Movement Settings
const BASE_WALK_SPEED: float = 7.0
const SPRINT_MULTIPLIER: float = 1.4
const DOWNED_CRAWL_SPEED: float = 1.8
const JUMP_VELOCITY: float = 6.8
const GRAVITY: float = 20.0
var mouse_sensitivity: float = 0.0022

# Weapon Positioning (Hip vs Aim Down Sights)
const HIP_POSITION: Vector3 = Vector3(0.24, -0.22, -0.45)
const ADS_POSITION: Vector3 = Vector3(0.0, -0.16, -0.38)
var is_aiming: bool = false
var target_sway_pos: Vector3 = Vector3.ZERO
var target_sway_rot: Vector3 = Vector3.ZERO
var weapon_kick_z: float = 0.0
var weapon_kick_rot_x: float = 0.0

# State
var current_health: float = 100.0
var max_health: float = 100.0
var current_shield: float = 0.0
var shield_regen_timer: float = 0.0
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var null_barrier_timer: float = 0.0
var null_barrier_ready: bool = true
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Class & Skill Specializations (Medic, Rogue, Gunner)
var player_class: String = "medic":
	set(v):
		player_class = v
		if is_inside_tree() and not weapons.is_empty():
			_update_stats()
const MEDIC_COOLDOWN: float = 20.0
const ROGUE_COOLDOWN: float = 10.0
const GUNNER_COOLDOWN: float = 60.0
const GUNNER_ACTIVE_DURATION: float = 5.0

var skill_cooldown_timer: float = 0.0
var skill_ready: bool = true

# Rogue Active: Quantum Dash
const DASH_TOTAL_DISTANCE: float = 15.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 10.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_cooldown_timer: float:
	get: return skill_cooldown_timer
	set(v): skill_cooldown_timer = v
var dash_ready: bool:
	get: return skill_ready
	set(v): skill_ready = v

# Gunner Active: Berserk Overdrive
var is_gunner_active: bool = false
var gunner_timer: float = 0.0
var is_slayer_active: bool:
	get: return is_gunner_active
	set(v): is_gunner_active = v
var slayer_timer: float:
	get: return gunner_timer
	set(v): gunner_timer = v

# Head Bobbing & Shake
var bob_time: float = 0.0
var shake_intensity: float = 0.0

# Weapons Configuration
class Weapon:
	var name: String
	var fire_rate: float # Seconds per shot
	var damage: float
	var base_max_ammo: int
	var max_ammo: int
	var current_ammo: int
	var base_reload_time: float
	var reload_time: float
	var is_auto: bool
	var pellets: int
	var spread: float
	var is_explosive: bool
	var sound_name: String
	var base_crit_chance: float = 0.10
	var charge_time: float = 0.0

var weapons: Array[Weapon] = []
var active_weapon_idx: int = 0
var fire_cooldown: float = 0.0
var reload_timer: float = 0.0
var is_reloading: bool = false
var is_charging: bool = false
var charge_timer: float = 0.0
var charge_duration: float = 0.0

# Drone Companions
var active_drones: Array[Node3D] = []
const DRONE_SCENE = preload("res://scenes/player/drone.tscn")

# Node References
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_rig: Node3D = $Head/Camera3D/WeaponRig
@onready var gun_model_rifle: Node3D = $Head/Camera3D/WeaponRig/Rifle
@onready var gun_model_shotgun: Node3D = $Head/Camera3D/WeaponRig/Shotgun
@onready var gun_model_plasma: Node3D = $Head/Camera3D/WeaponRig/Plasma
@onready var plasma_core_mesh: MeshInstance3D = $Head/Camera3D/WeaponRig/Plasma/Core
const COLOR_PLASMA_READY: Color = Color(0.9, 0.1, 1.0, 1.0) # Purple when ready to fire
const COLOR_PLASMA_COOLDOWN: Color = Color(1.0, 0.12, 0.12, 1.0) # Red during cooldown / unable to shoot
var plasma_core_mat: StandardMaterial3D = null
var _plasma_was_ready: bool = true
@onready var muzzle_flash_light: OmniLight3D = $Head/Camera3D/WeaponRig/MuzzleFlashLight
@onready var muzzle_particles: CPUParticles3D = $Head/Camera3D/WeaponRig/MuzzleParticles
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var drone_companion: Node3D = $DroneCompanion

# Third Person Representation for Co-op Ally
@onready var third_person_model: Node3D = $ThirdPersonModel
@onready var tp_head: Node3D = $ThirdPersonModel/TPHead
@onready var tp_rifle: MeshInstance3D = $ThirdPersonModel/RightArm/HeldWeapon/RifleMesh
@onready var tp_shotgun: MeshInstance3D = $ThirdPersonModel/RightArm/HeldWeapon/ShotgunMesh
@onready var tp_plasma: MeshInstance3D = $ThirdPersonModel/RightArm/HeldWeapon/PlasmaMesh
@onready var tp_chest_light: MeshInstance3D = $ThirdPersonModel/ChestLight
@onready var tp_visor: MeshInstance3D = $ThirdPersonModel/TPHead/VisorMesh
@onready var tp_left_leg: MeshInstance3D = $ThirdPersonModel/LeftLeg
@onready var tp_right_leg: MeshInstance3D = $ThirdPersonModel/RightLeg

@onready var overhead_ui: Node3D = $OverheadUI
@onready var name_label: Label3D = $OverheadUI/NameLabel
@onready var status_label: Label3D = $OverheadUI/StatusLabel
@onready var revive_prompt: Label3D = $OverheadUI/RevivePrompt
@onready var downed_beacon: OmniLight3D = $DownedBeacon

const BULLET_SCENE = preload("res://scenes/projectiles/bullet.tscn")
const DAMAGE_NUMBER_SCENE = preload("res://scenes/ui/damage_number.tscn")

func _ready() -> void:
	add_to_group("player")
	_setup_weapons()
	_update_stats()
	
	if plasma_core_mesh:
		plasma_core_mat = StandardMaterial3D.new()
		plasma_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plasma_core_mat.albedo_color = COLOR_PLASMA_READY
		plasma_core_mesh.material_override = plasma_core_mat
	
	GameManager.stats_updated.connect(_update_stats)
	muzzle_flash_light.visible = false
	if drone_companion:
		drone_companion.visible = false
	
	target_net_pos = global_position
	target_net_rot_y = rotation.y

func setup_peer(id: int, p_class: String = "") -> void:
	if not is_node_ready():
		await ready
	peer_id = id
	set_multiplayer_authority(id)
	target_net_pos = global_position
	target_net_rot_y = rotation.y
	
	var is_me = false
	if not NetworkManager.is_multiplayer:
		is_me = true
	elif id == multiplayer.get_unique_id():
		is_me = true
	
	if not p_class.is_empty():
		player_class = p_class
	elif is_me:
		player_class = GameManager.player_class
	
	if is_me:
		is_local_player = true
		camera.current = true
		camera.make_current()
		weapon_rig.visible = true
		third_person_model.visible = false
		overhead_ui.visible = false
		downed_beacon.visible = false
	else:
		is_local_player = false
		camera.current = false
		weapon_rig.visible = false
		third_person_model.visible = true
		overhead_ui.visible = true
		
		# Set player armor colors based on operative class
		var p_color = Color(0.0, 1.0, 0.7) # Medic: mint green
		if player_class == "rogue":
			p_color = Color(1.0, 0.75, 0.1) # Rogue: gold/amber
		elif player_class == "gunner" or player_class == "slayer":
			p_color = Color(1.0, 0.2, 0.25) # Gunner: crimson
		
		var role_tag = "HOST" if id == 1 else "ALLY"
		name_label.text = "P%d [%s • %s]" % [id, role_tag, player_class.to_upper()]
		name_label.modulate = p_color
		
		var neon_mat = StandardMaterial3D.new()
		neon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		neon_mat.albedo_color = p_color
		tp_chest_light.material_override = neon_mat
		tp_visor.material_override = neon_mat
		_update_third_person_weapon(0)

func _exit_tree() -> void:
	for d in active_drones:
		if is_instance_valid(d):
			d.queue_free()
	active_drones.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if GameManager.state == GameManager.GameState.PLAYING and is_local_player:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_weapons() -> void:
	# Weapon 0: Pulse Rifle
	var rifle = Weapon.new()
	rifle.name = "Pulse Carbine"
	rifle.fire_rate = 0.12
	rifle.damage = 22.0
	rifle.base_max_ammo = 32
	rifle.max_ammo = 32
	rifle.current_ammo = 32
	rifle.base_reload_time = 1.2
	rifle.reload_time = 1.2
	rifle.is_auto = true
	rifle.pellets = 1
	rifle.spread = 0.02
	rifle.is_explosive = false
	rifle.sound_name = "shoot_rifle"
	rifle.base_crit_chance = 0.10
	weapons.append(rifle)
	
	# Weapon 1: Scatter Shotgun
	var shotgun = Weapon.new()
	shotgun.name = "Scatter Cannon"
	shotgun.fire_rate = 0.65
	shotgun.damage = 18.0
	shotgun.base_max_ammo = 8
	shotgun.max_ammo = 8
	shotgun.current_ammo = 8
	shotgun.base_reload_time = 1.6
	shotgun.reload_time = 1.6
	shotgun.is_auto = false
	shotgun.pellets = 10
	shotgun.spread = 0.103125
	shotgun.is_explosive = false
	shotgun.sound_name = "shoot_shotgun"
	shotgun.base_crit_chance = 0.05
	weapons.append(shotgun)
	
	# Weapon 2: Plasma Launcher
	var plasma = Weapon.new()
	plasma.name = "Plasma Core"
	plasma.fire_rate = 1.0 / 0.3 # 0.3 shot/s cooldown (3.333s), not including charge
	plasma.damage = 150.0
	plasma.base_max_ammo = 5
	plasma.max_ammo = 5
	plasma.current_ammo = 5
	plasma.base_reload_time = 2.0
	plasma.reload_time = 2.0
	plasma.is_auto = false
	plasma.pellets = 1
	plasma.spread = 0.015
	plasma.is_explosive = true
	plasma.sound_name = "shoot_plasma"
	plasma.base_crit_chance = 0.25
	plasma.charge_time = 0.18
	weapons.append(plasma)
	
	_switch_weapon(0)

func _update_stats() -> void:
	var old_max = max_health
	max_health = 100.0 + GameManager.max_health_bonus
	if max_health > old_max:
		current_health += (max_health - old_max)
	current_health = minf(current_health, max_health)
	if current_shield < GameManager.current_shield:
		current_shield = GameManager.current_shield
	current_shield = minf(current_shield, GameManager.shield_max)
	
	var rogue_reload_mult: float = 1.25 if player_class == "rogue" else 1.0
	for w in weapons:
		var new_max = int(round(w.base_max_ammo * GameManager.magazine_mult))
		if new_max > w.max_ammo:
			var diff = new_max - w.max_ammo
			w.max_ammo = new_max
			w.current_ammo = mini(w.current_ammo + diff, w.max_ammo)
		else:
			w.max_ammo = new_max
			w.current_ammo = mini(w.current_ammo, w.max_ammo)
		w.reload_time = w.base_reload_time / (GameManager.reload_speed_mult * rogue_reload_mult)
	
	if drone_companion:
		drone_companion.visible = false
	if is_local_player:
		_sync_drones()
	
	if GameManager.null_barrier_unlocked and null_barrier_timer <= 0.0:
		null_barrier_ready = true
	
	if skill_cooldown_timer <= 0.0:
		skill_ready = true
	
	health_changed.emit(current_health, max_health)
	shield_changed.emit(current_shield, GameManager.shield_max)
	if active_weapon_idx < weapons.size():
		var cur_w = weapons[active_weapon_idx]
		ammo_changed.emit(cur_w.current_ammo, cur_w.max_ammo, is_reloading)

func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	
	# Clicking in window recaptures mouse if lost
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Mouse look & Weapon sway
	if event is InputEventMouseMotion:
		var sens = mouse_sensitivity * (0.65 if is_aiming else 1.0)
		rotate_y(-event.relative.x * sens)
		head.rotate_x(-event.relative.y * sens)
		head.rotation.x = clampf(head.rotation.x, -deg_to_rad(88.0), deg_to_rad(88.0))
		
		var sway_mult = 0.35 if is_aiming else 1.0
		var sway_x = clampf(-event.relative.x * 0.0006 * sway_mult, -0.035, 0.035)
		var sway_y = clampf(event.relative.y * 0.0006 * sway_mult, -0.03, 0.03)
		var sway_rot_z = clampf(-event.relative.x * 0.001 * sway_mult, -0.06, 0.06)
		var sway_rot_x = clampf(event.relative.y * 0.001 * sway_mult, -0.05, 0.05)
		
		target_sway_pos = Vector3(sway_x, sway_y, 0.0)
		target_sway_rot = Vector3(sway_rot_x, 0.0, sway_rot_z)
	
	if is_downed:
		return
	
	# Weapon switching
	if event.is_action_pressed("weapon_1"):
		_switch_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		_switch_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		_switch_weapon(2)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_switch_weapon((active_weapon_idx - 1 + weapons.size()) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_switch_weapon((active_weapon_idx + 1) % weapons.size())

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	
	# Invulnerability timer
	if is_invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0:
			is_invulnerable = false
	
	# Null Barrier cooldown timer (Every 10s, nullifies next instance of damage)
	if GameManager.null_barrier_unlocked and not null_barrier_ready:
		null_barrier_timer -= delta
		if null_barrier_timer <= 0.0:
			null_barrier_timer = 0.0
			null_barrier_ready = true
			if is_local_player:
				SoundManager.play("upgrade_select", 0.05, 1.8)
	
	# Class Skill cooldown timer
	if skill_cooldown_timer > 0.0:
		skill_cooldown_timer -= delta
		if skill_cooldown_timer <= 0.0:
			skill_cooldown_timer = 0.0
			skill_ready = true
			if is_local_player:
				SoundManager.play("upgrade_select", 0.05, 1.8)
	
	# Slayer active duration timer (5s)
	if is_slayer_active:
		slayer_timer -= delta
		if slayer_timer <= 0.0:
			_end_slayer_skill()
	
	# Medic Passive: 5 HP/s regeneration across all players per active Medic (Stackable)
	if not is_downed and current_health < max_health:
		var total_medic_regen = _get_total_medic_regen()
		if total_medic_regen > 0.0:
			heal(total_medic_regen * delta)
	
	# Remote player interpolation
	if not is_local_player:
		global_position = global_position.lerp(target_net_pos, 18.0 * delta)
		rotation.y = lerp_angle(rotation.y, target_net_rot_y, 18.0 * delta)
		if tp_head:
			tp_head.rotation.x = target_net_head_pitch
		_animate_third_person_legs(delta)
		return
	
	# Broadcast transform to squad peers
	if NetworkManager.is_multiplayer:
		net_sync_timer += delta
		if net_sync_timer >= 0.033:
			net_sync_timer = 0.0
			rpc_sync_state.rpc(global_position, rotation.y, head.rotation.x, velocity, active_weapon_idx)
	
	# Downed handling
	if is_downed:
		_handle_downed_state(delta)
		return
	
	_handle_movement(delta)
	_handle_weapons(delta)
	_handle_shield_regen(delta)
	_handle_drone(delta)
	_handle_head_bob_and_shake(delta)
	_handle_teammate_revive(delta)

func _handle_downed_state(delta: float) -> void:
	bleedout_timer -= delta
	if bleedout_timer <= 0.0:
		die()
		return
	
	# Crawling movement
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_basis = transform.basis
	var forward = -move_basis.z
	var right = move_basis.x
	var wish_dir = (right * input_dir.x + forward * -input_dir.y).normalized()
	
	velocity.x = wish_dir.x * DOWNED_CRAWL_SPEED
	velocity.z = wish_dir.z * DOWNED_CRAWL_SPEED
	move_and_slide()

func _handle_movement(delta: float) -> void:
	# Active dash state execution (Rogue)
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * (DASH_TOTAL_DISTANCE / DASH_DURATION)
		move_and_slide()
		if dash_timer <= 0.0:
			_end_dash()
		return
	
	# Check Class Active Skill activation (Skill: Q)
	if not is_downed:
		if Input.is_action_just_pressed("skill_dash") or Input.is_action_just_pressed("skill_active"):
			if skill_ready and skill_cooldown_timer <= 0.0 and not is_dashing and not is_slayer_active:
				_activate_class_skill()
				return
			elif not is_dashing and not is_slayer_active:
				SoundManager.play("empty_ammo", 0.1, -6.0)
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = 0.15
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.15
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
	
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		var jump_spd = JUMP_VELOCITY * (1.0 + (GameManager.speed_mult - 1.0) * 0.5)
		if player_class == "rogue":
			jump_spd *= 1.25 # Rogue Passive: +25% MORE jump speed
		velocity.y = jump_spd
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_basis = transform.basis
	var forward = -move_basis.z
	var right = move_basis.x
	var wish_dir = (right * input_dir.x + forward * -input_dir.y).normalized()
	
	var is_sprinting = Input.is_action_pressed("sprint")
	var target_speed = BASE_WALK_SPEED * GameManager.speed_mult
	if player_class == "rogue":
		target_speed *= 1.25 # Rogue Passive: +25% MORE movement speed
	if is_sprinting:
		target_speed *= SPRINT_MULTIPLIER
	
	if wish_dir.length_squared() > 0.01:
		velocity.x = lerpf(velocity.x, wish_dir.x * target_speed, 14.0 * delta)
		velocity.z = lerpf(velocity.z, wish_dir.z * target_speed, 14.0 * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, 16.0 * delta)
		velocity.z = lerpf(velocity.z, 0.0, 16.0 * delta)
	
	move_and_slide()

func _handle_weapons(delta: float) -> void:
	var w = weapons[active_weapon_idx]
	fire_cooldown -= delta
	_update_plasma_core_visual()
	
	if is_reloading:
		if is_charging:
			_cancel_charge()
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			w.current_ammo = w.max_ammo
			ammo_changed.emit(w.current_ammo, w.max_ammo, false)
		return
	
	if Input.is_action_just_pressed("reload") and w.current_ammo < w.max_ammo:
		if is_charging:
			_cancel_charge()
		_start_reload()
		return
	
	# Process active charge delay (Slot 3: Plasma Core)
	# Requires player to hold LMB for at least the charge delay time.
	# If held longer without release, the weapon will not shoot until released.
	# If released before charge delay is reached, the shot is cancelled (must fully charge again).
	if is_charging:
		if Input.is_action_pressed("shoot"):
			charge_timer = maxf(-0.01, charge_timer - delta)
			var p = clampf(1.0 - (charge_timer / maxf(0.001, charge_duration)), 0.0, 1.0)
			
			# Charging visual feedback: core pulses and weapon vibrates
			if plasma_core_mesh and active_weapon_idx == 2:
				plasma_core_mesh.scale = Vector3.ONE * (1.0 + p * 0.35)
			
			muzzle_flash_light.visible = true
			muzzle_flash_light.light_color = Color(0.85, 0.2, 1.0)
			muzzle_flash_light.light_energy = p * 2.2
			
			# Slight pre-fire coil vibration and draw-back
			weapon_kick_z = lerpf(weapon_kick_z, -0.015 * p, 18.0 * delta)
			target_sway_pos += Vector3(randf_range(-0.002, 0.002), randf_range(-0.002, 0.002), 0.0) * p
			charge_changed.emit(p)
			# Do not fire while button is still held down!
			return
		else:
			# Player released LMB (or stopped holding shoot action)
			var can_fire = (charge_timer <= 0.0)
			_cancel_charge()
			if can_fire:
				_fire_active_weapon()
			return
	
	var wants_fire = Input.is_action_pressed("shoot") if (is_slayer_active or w.is_auto or w.charge_time > 0.0) else Input.is_action_just_pressed("shoot")
	if wants_fire:
		if w.current_ammo > 0 or is_slayer_active:
			if fire_cooldown <= 0.0:
				if w.charge_time > 0.0 and not is_slayer_active:
					_start_charge(w)
				else:
					_fire_active_weapon()
		else:
			SoundManager.play("empty_ammo")
			_start_reload()

func _start_charge(w: Weapon) -> void:
	is_charging = true
	charge_duration = w.charge_time / GameManager.fire_rate_mult
	charge_timer = charge_duration
	SoundManager.play("plasma_charge", 0.06, 1.0)
	charge_changed.emit(0.0)

func _cancel_charge() -> void:
	is_charging = false
	charge_timer = 0.0
	charge_duration = 0.0
	if muzzle_flash_light:
		muzzle_flash_light.visible = false
	if plasma_core_mesh:
		plasma_core_mesh.scale = Vector3.ONE
	charge_changed.emit(0.0)

func _fire_active_weapon() -> void:
	var w = weapons[active_weapon_idx]
	var slayer_fr_mult = 4.0 if is_slayer_active else 1.0
	var effective_cooldown = maxf(0.02, w.fire_rate / (GameManager.fire_rate_mult * slayer_fr_mult))
	fire_cooldown = effective_cooldown
	_update_plasma_core_visual()
	if not is_slayer_active:
		w.current_ammo -= 1
	ammo_changed.emit(w.current_ammo, w.max_ammo, false)
	
	SoundManager.play(w.sound_name, 0.08)
	_flash_muzzle()
	
	if active_weapon_idx == 2:
		# Slot 3 (Plasma Core): Massive heavy cannon recoil!
		weapon_kick_z = 0.16 if not is_aiming else 0.11
		weapon_kick_rot_x = deg_to_rad(13.0 if not is_aiming else 7.5)
		shake_intensity = 0.38
		# Visceral upward camera kick
		head.rotation.x = clampf(head.rotation.x + deg_to_rad(2.6 if not is_aiming else 1.4), -deg_to_rad(88.0), deg_to_rad(88.0))
		# Heavy backward concussive impulse
		velocity += camera.global_transform.basis.z * (4.2 if not is_on_floor() else 2.5)
		if plasma_core_mesh:
			var tw = create_tween()
			plasma_core_mesh.scale = Vector3.ONE * 0.65
			tw.tween_property(plasma_core_mesh, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif active_weapon_idx == 1:
		# Slot 2 (Scatter Cannon): Punchy shotgun recoil
		weapon_kick_z = 0.085 if not is_aiming else 0.05
		weapon_kick_rot_x = deg_to_rad(5.5 if not is_aiming else 3.0)
		shake_intensity = 0.18
	else:
		# Slot 1 (Pulse Carbine): Crisp automatic rifle recoil
		weapon_kick_z = 0.045 if not is_aiming else 0.025
		weapon_kick_rot_x = deg_to_rad(2.8 if not is_aiming else 1.4)
		shake_intensity = 0.06
	
	var total_projectiles = int(round(w.pellets * (1.0 + GameManager.extra_projectile_mult)))
	var shoot_origin = camera.global_position + (-camera.global_transform.basis.z * 0.5)
	var base_dir = -camera.global_transform.basis.z
	
	for i in range(total_projectiles):
		var bullet = BULLET_SCENE.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = shoot_origin
		
		var spread_angle = w.spread * (0.5 if is_aiming else 1.0)
		if total_projectiles > 1:
			spread_angle = maxf(spread_angle, 0.045)
		if total_projectiles > 7:
			spread_angle *= 1.2
		
		var spread_x = randf_range(-spread_angle, spread_angle)
		var spread_y = randf_range(-spread_angle, spread_angle)
		var bullet_dir = (base_dir + camera.global_transform.basis.x * spread_x + camera.global_transform.basis.y * spread_y).normalized()
		
		var crit_bonus = 0.25 if (player_class == "gunner" or player_class == "slayer") else 0.0
		bullet.setup(bullet_dir, w.damage, w.is_explosive, active_weapon_idx == 2, w.base_crit_chance + crit_bonus, self)
	
	# Notify squad of gunfire visual & sound
	if NetworkManager.is_multiplayer:
		rpc_fire_weapon.rpc(active_weapon_idx, shoot_origin, base_dir)

func _flash_muzzle() -> void:
	muzzle_flash_light.visible = true
	if active_weapon_idx == 2:
		muzzle_flash_light.light_color = Color(0.95, 0.3, 1.0)
		muzzle_flash_light.light_energy = 3.5
	elif active_weapon_idx == 1:
		muzzle_flash_light.light_color = Color(1.0, 0.65, 0.2)
		muzzle_flash_light.light_energy = 2.5
	else:
		muzzle_flash_light.light_color = Color(0.3, 0.9, 1.0)
		muzzle_flash_light.light_energy = 2.0
	if muzzle_particles:
		muzzle_particles.restart()
		muzzle_particles.emitting = true
	get_tree().create_timer(0.04).timeout.connect(func(): muzzle_flash_light.visible = false)

func _start_reload() -> void:
	var w = weapons[active_weapon_idx]
	if is_reloading:
		return
	if is_charging:
		_cancel_charge()
	is_reloading = true
	var rogue_reload_mult: float = 1.25 if player_class == "rogue" else 1.0
	reload_timer = w.base_reload_time / (GameManager.reload_speed_mult * rogue_reload_mult)
	SoundManager.play("reload", 0.05)
	ammo_changed.emit(w.current_ammo, w.max_ammo, true)

func _switch_weapon(new_idx: int) -> void:
	if is_charging:
		_cancel_charge()
	if new_idx == active_weapon_idx and not is_reloading:
		return
	active_weapon_idx = new_idx
	is_reloading = false
	fire_cooldown = 0.1
	
	var w = weapons[active_weapon_idx]
	gun_model_rifle.visible = (active_weapon_idx == 0)
	gun_model_shotgun.visible = (active_weapon_idx == 1)
	gun_model_plasma.visible = (active_weapon_idx == 2)
	
	SoundManager.play("reload", 0.1, -4.0)
	weapon_changed.emit(active_weapon_idx, w.name)
	ammo_changed.emit(w.current_ammo, w.max_ammo, false)
	_update_plasma_core_visual()

func _update_plasma_core_visual() -> void:
	if active_weapon_idx != 2 or plasma_core_mat == null or not is_instance_valid(plasma_core_mesh):
		return
	
	var w = weapons[2]
	var can_shoot = (fire_cooldown <= 0.0 and not is_reloading and w.current_ammo > 0)
	
	if is_charging:
		var p = clampf(1.0 - (charge_timer / maxf(0.001, charge_duration)), 0.0, 1.0)
		plasma_core_mat.albedo_color = COLOR_PLASMA_READY.lerp(Color(1.0, 0.7, 1.0), p * 0.7)
	elif can_shoot:
		if not _plasma_was_ready:
			_plasma_was_ready = true
			var tw = create_tween()
			plasma_core_mesh.scale = Vector3.ONE * 1.25
			tw.tween_property(plasma_core_mesh, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		plasma_core_mat.albedo_color = COLOR_PLASMA_READY
	else:
		_plasma_was_ready = false
		plasma_core_mat.albedo_color = COLOR_PLASMA_COOLDOWN

func _handle_shield_regen(delta: float) -> void:
	if GameManager.shield_max <= 0.0:
		return
	
	shield_regen_timer += delta
	if shield_regen_timer >= 4.0 and current_shield < GameManager.shield_max:
		current_shield = minf(GameManager.shield_max, current_shield + 20.0 * delta)
		GameManager.current_shield = current_shield
		shield_changed.emit(current_shield, GameManager.shield_max)

func _sync_drones() -> void:
	var target_count = GameManager.drone_count
	var parent_node = get_parent()
	if not parent_node:
		return
	while active_drones.size() < target_count:
		var d = DRONE_SCENE.instantiate()
		d.drone_index = active_drones.size()
		d.assigned_weapon_idx = randi() % (weapons.size() if weapons.size() > 0 else 3)
		parent_node.add_child(d)
		d.global_position = global_position + Vector3(0, 1.8, 0)
		active_drones.append(d)
	while active_drones.size() > target_count:
		var d = active_drones.pop_back()
		if is_instance_valid(d):
			d.queue_free()
	for i in range(active_drones.size()):
		if is_instance_valid(active_drones[i]):
			active_drones[i].drone_index = i

func _handle_drone(delta: float) -> void:
	if active_drones.is_empty():
		return
	for d in active_drones:
		if is_instance_valid(d):
			d.update_drone(delta, self, active_drones.size())

func _handle_head_bob_and_shake(delta: float) -> void:
	is_aiming = Input.is_action_pressed("aim")
	var target_fov = 65.0 if is_aiming else (98.0 if is_dashing else 85.0)
	camera.fov = lerpf(camera.fov, target_fov, 14.0 * delta)
	
	var base_pos = ADS_POSITION if is_aiming else HIP_POSITION
	var is_moving = is_on_floor() and velocity.length_squared() > 1.0
	var is_sprinting = Input.is_action_pressed("sprint") and is_moving
	
	var gun_bob = Vector3.ZERO
	if is_moving:
		var speed_factor = 14.0 if is_sprinting else 10.0
		bob_time += delta * speed_factor
		camera.position.y = lerpf(camera.position.y, sin(bob_time) * 0.04, 10.0 * delta)
		camera.position.x = lerpf(camera.position.x, cos(bob_time * 0.5) * 0.025, 10.0 * delta)
		
		var bob_scale = 0.3 if is_aiming else (1.4 if is_sprinting else 1.0)
		gun_bob.x = cos(bob_time * 0.5) * 0.014 * bob_scale
		gun_bob.y = sin(bob_time) * 0.012 * bob_scale
	else:
		bob_time = 0.0
		camera.position = camera.position.lerp(Vector3.ZERO, 8.0 * delta)
	
	if shake_intensity > 0.001:
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = lerpf(shake_intensity, 0.0, 12.0 * delta)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	
	weapon_kick_z = lerpf(weapon_kick_z, 0.0, 12.0 * delta)
	weapon_kick_rot_x = lerpf(weapon_kick_rot_x, 0.0, 12.0 * delta)
	target_sway_pos = target_sway_pos.lerp(Vector3.ZERO, 8.0 * delta)
	target_sway_rot = target_sway_rot.lerp(Vector3.ZERO, 8.0 * delta)
	
	if weapon_rig:
		var final_target_pos = base_pos + gun_bob + target_sway_pos + Vector3(0, 0, weapon_kick_z)
		var final_target_rot = target_sway_rot + Vector3(weapon_kick_rot_x, 0, 0)
		weapon_rig.position = weapon_rig.position.lerp(final_target_pos, 16.0 * delta)
		weapon_rig.rotation = weapon_rig.rotation.lerp(final_target_rot, 16.0 * delta)

# Revive mechanic when standing near a downed teammate
func _handle_teammate_revive(delta: float) -> void:
	if not NetworkManager.is_multiplayer:
		return
	
	var players = get_tree().get_nodes_in_group("player")
	var downed_teammate: CharacterBody3D = null
	
	for p in players:
		if p != self and is_instance_valid(p) and p.get("is_downed") == true:
			if global_position.distance_to(p.global_position) <= 3.0:
				downed_teammate = p
				break
	
	if downed_teammate != null:
		if downed_teammate.revive_prompt:
			downed_teammate.revive_prompt.visible = true
		
		if Input.is_action_pressed("interact"):
			revive_progress += delta
			downed_teammate.revive_prompt.text = "REVIVING SQUADMATE... %d%%" % int((revive_progress / 2.0) * 100.0)
			if revive_progress >= 2.0:
				revive_progress = 0.0
				downed_teammate.rpc_revive.rpc()
				SoundManager.play("level_up", 0.2, 1.5)
		else:
			revive_progress = maxf(0.0, revive_progress - delta * 2.0)
			downed_teammate.revive_prompt.text = "[HOLD E TO REVIVE]"
	else:
		revive_progress = 0.0

func _animate_third_person_legs(delta: float) -> void:
	if tp_left_leg and tp_right_leg:
		if velocity.length_squared() > 0.5:
			var leg_swing = sin(Time.get_ticks_msec() * 0.012) * 0.4
			tp_left_leg.rotation.x = leg_swing
			tp_right_leg.rotation.x = -leg_swing
		else:
			tp_left_leg.rotation.x = lerpf(tp_left_leg.rotation.x, 0.0, 10.0 * delta)
			tp_right_leg.rotation.x = lerpf(tp_right_leg.rotation.x, 0.0, 10.0 * delta)

func _update_third_person_weapon(idx: int) -> void:
	if tp_rifle: tp_rifle.visible = (idx == 0)
	if tp_shotgun: tp_shotgun.visible = (idx == 1)
	if tp_plasma: tp_plasma.visible = (idx == 2)

func trigger_invulnerability(duration: float) -> void:
	is_invulnerable = true
	invulnerable_timer = maxf(invulnerable_timer, duration)

func take_damage(amount: float) -> void:
	if is_invulnerable or is_dashing:
		return
	
	# Gunner Passive: take 10% more damage from all sources
	if player_class == "gunner" or player_class == "slayer":
		amount *= 1.10
	
	# Epic perk: Null Barrier (Every 10s, nullifies next instance of damage)
	if GameManager.null_barrier_unlocked and null_barrier_ready:
		null_barrier_ready = false
		null_barrier_timer = 10.0
		SoundManager.play("shield_hit", 0.15, 1.8)
		shake_intensity = 0.08
		
		# Visual floating popup
		var scene_root = get_tree().current_scene if get_tree() else get_parent()
		if scene_root:
			var dnum = DAMAGE_NUMBER_SCENE.instantiate()
			scene_root.add_child(dnum)
			dnum.global_position = global_position + Vector3(0, 1.8, 0)
			dnum.setup_text("NULLIFIED!", Color(0.2, 0.9, 1.0))
		
		# (This still triggers invulnerability duration perk)
		if GameManager.hit_invulnerability_duration > 0.0:
			trigger_invulnerability(GameManager.hit_invulnerability_duration)
		return
	
	# Rare perk: Hardened Alloy (10% Dmg Reduction per stack, max 50%)
	if GameManager.player_damage_reduction > 0.0:
		amount *= (1.0 - GameManager.player_damage_reduction)
	
	shield_regen_timer = 0.0
	shake_intensity = 0.25
	
	if current_shield > 0.0:
		var absorbed = minf(current_shield, amount)
		current_shield -= absorbed
		amount -= absorbed
		SoundManager.play("shield_hit", 0.1)
		shield_changed.emit(current_shield, GameManager.shield_max)
	
	if amount > 0.0:
		current_health -= amount
		SoundManager.play("player_hurt", 0.1)
		health_changed.emit(current_health, max_health)
	
	# Update overhead tag
	if status_label:
		status_label.text = "HP: %d/%d" % [int(current_health), int(max_health)]
	
	if current_health <= 0:
		if GameManager.second_wind_available:
			_trigger_second_wind()
		elif NetworkManager.is_multiplayer and not is_downed:
			rpc_set_downed.rpc(true)
		else:
			die()
	else:
		# Survived hit: check Epic perk Reactive Phase-Shield (0.5s invulnerability per stack, max 1s)
		if GameManager.hit_invulnerability_duration > 0.0:
			trigger_invulnerability(GameManager.hit_invulnerability_duration)

func _trigger_second_wind() -> void:
	GameManager.trigger_second_wind()
	current_health = 45.0
	trigger_invulnerability(5.0)
	SoundManager.play("level_up", 0.2, 2.0)
	health_changed.emit(current_health, max_health)

func heal(amount: float) -> void:
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	if status_label:
		status_label.text = "HP: %d/%d" % [int(current_health), int(max_health)]

func apply_impulse_jump(force: float) -> void:
	velocity.y = force
	SoundManager.play("jump_pad", 0.05)

func die() -> void:
	if is_charging:
		_cancel_charge()
	if NetworkManager.is_multiplayer:
		# Check if any teammate is still alive
		var any_alive = false
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.get("is_downed") == false and p.get("current_health") > 0:
				any_alive = true
				break
		if not any_alive:
			GameManager.trigger_game_over()
	else:
		GameManager.trigger_game_over()

# ==============================================================================
# NETWORK RPCS
# ==============================================================================

@rpc("any_peer", "unreliable_ordered")
func rpc_sync_state(pos: Vector3, rot_y: float, head_pitch: float, vel: Vector3, wep_idx: int) -> void:
	if is_local_player:
		return
	target_net_pos = pos
	target_net_rot_y = rot_y
	target_net_head_pitch = head_pitch
	velocity = vel
	if active_weapon_idx != wep_idx:
		active_weapon_idx = wep_idx
		_update_third_person_weapon(wep_idx)

@rpc("any_peer", "call_local", "reliable")
func rpc_fire_weapon(wep_idx: int, origin: Vector3, dir: Vector3) -> void:
	if is_local_player:
		return
	var w = weapons[wep_idx] if wep_idx < weapons.size() else null
	if w:
		SoundManager.play(w.sound_name, 0.1, -2.0)
		var bullet = BULLET_SCENE.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = origin
		bullet.setup(dir, w.damage, w.is_explosive, wep_idx == 2, w.base_crit_chance)

@rpc("any_peer", "call_local", "reliable")
func rpc_set_downed(downed: bool) -> void:
	if downed and is_charging:
		_cancel_charge()
	is_downed = downed
	bleedout_timer = 30.0
	downed_state_changed.emit(downed)
	
	if downed_beacon:
		downed_beacon.visible = downed
	
	if downed:
		SoundManager.play("player_hurt", 0.2, -4.0)
		if is_local_player:
			head.position.y = 0.7 # Lower camera to ground crawl
		if status_label:
			status_label.text = "DOWNED!"
			status_label.modulate = Color(1, 0.2, 0.2)
		if revive_prompt:
			revive_prompt.visible = not is_local_player
	else:
		current_health = max_health * 0.5
		health_changed.emit(current_health, max_health)
		if is_local_player:
			head.position.y = 1.6
		if status_label:
			status_label.text = "HP: %d/%d" % [int(current_health), int(max_health)]
			status_label.modulate = Color(0.1, 1, 0.6)
		if revive_prompt:
			revive_prompt.visible = false

@rpc("any_peer", "call_local", "reliable")
func rpc_revive() -> void:
	rpc_set_downed(false)
	trigger_invulnerability(3.0)
	SoundManager.play("level_up", 0.2, 1.5)

# ==============================================================================
# CLASS ACTIVE SKILLS & SPECIALIZATIONS
# ==============================================================================

func _get_total_medic_regen() -> float:
	var medic_count: int = 0
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.get("is_downed") == false and p.get("player_class") == "medic":
			medic_count += 1
	return float(medic_count) * 5.0

func _spawn_floating_text(text_msg: String, color: Color) -> void:
	var scene_root = get_tree().current_scene if get_tree() else get_parent()
	if scene_root:
		var dnum = DAMAGE_NUMBER_SCENE.instantiate()
		scene_root.add_child(dnum)
		dnum.global_position = global_position + Vector3(0, 1.8, 0)
		dnum.setup_text(text_msg, color)

func _activate_class_skill() -> void:
	match player_class:
		"medic":
			_activate_medic_skill()
		"rogue":
			_start_dash()
		"gunner", "slayer":
			_activate_gunner_skill()

# --- MEDIC ACTIVE: CELLULAR RESTORE (20s cd) ---
func _activate_medic_skill() -> void:
	var cd = MEDIC_COOLDOWN * GameManager.get_skill_cooldown_mult()
	skill_cooldown_timer = cd
	skill_ready = false
	if NetworkManager.is_multiplayer:
		rpc_medic_active.rpc()
	else:
		_apply_medic_heal_all()
	SoundManager.play("pickup_health", 0.2, 0.5)
	SoundManager.play("shield_hit", 0.15, 2.0)

@rpc("any_peer", "call_local", "reliable")
func rpc_medic_active() -> void:
	_apply_medic_heal_all()

func _apply_medic_heal_all() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			# Active skill no longer revives downed squadmates (manual revive with E remains)
			if p.get("is_downed") == true:
				continue
			var max_hp = float(p.get("max_health")) if "max_health" in p else 100.0
			p.heal(max_hp * 0.20)
			if GameManager.shield_max > 0.0:
				var s_add = GameManager.shield_max * 0.20
				p.current_shield = minf(GameManager.shield_max, p.current_shield + s_add)
				GameManager.current_shield = p.current_shield
				p.shield_changed.emit(p.current_shield, GameManager.shield_max)
	_spawn_floating_text("+20% HP & SHIELD", Color(0.2, 1.0, 0.6))

# --- ROGUE ACTIVE: QUANTUM DASH (10s cd) ---
func _start_dash() -> void:
	is_dashing = true
	skill_ready = false
	dash_timer = DASH_DURATION
	var cd = DASH_COOLDOWN * GameManager.get_skill_cooldown_mult()
	skill_cooldown_timer = cd
	
	# Rogue Active: Instantly reload all weapons (and companion drones)
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
	if is_charging:
		_cancel_charge()
	for w in weapons:
		w.current_ammo = w.max_ammo
	for d in active_drones:
		if is_instance_valid(d):
			if d.assigned_weapon_idx >= 0 and d.assigned_weapon_idx < weapons.size():
				d.current_ammo = weapons[d.assigned_weapon_idx].max_ammo
			d.is_reloading = false
			d.reload_timer = 0.0
	if active_weapon_idx < weapons.size():
		var cur_w = weapons[active_weapon_idx]
		ammo_changed.emit(cur_w.current_ammo, cur_w.max_ammo, false)
		_update_plasma_core_visual()
	
	# Look direction: aim vector in 3D (allows dashing into sky, ground, or air)
	var dir = -camera.global_transform.basis.z.normalized()
	if dir.length_squared() < 0.001:
		dir = -transform.basis.z.normalized()
	dash_direction = dir
	
	if dash_direction.y > 0.05:
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	# While Dash, invulnerable (and remains invulnerable through dash + 0.5s after)
	trigger_invulnerability(DASH_DURATION + 0.5)
	
	# High-speed FOV warp kick
	camera.fov = minf(camera.fov + 15.0, 105.0)
	
	SoundManager.play("dash", 0.08, 0.0)
	_create_dash_effect(global_position, dash_direction)
	
	if NetworkManager.is_multiplayer:
		rpc_trigger_dash.rpc(global_position, dash_direction)
	
	velocity = dash_direction * (DASH_TOTAL_DISTANCE / DASH_DURATION)
	move_and_slide()

func _end_dash() -> void:
	is_dashing = false
	# After Dash, gain 0.5s invulnerable
	trigger_invulnerability(0.5)
	var exit_speed = BASE_WALK_SPEED * GameManager.speed_mult
	velocity = dash_direction * exit_speed

# --- GUNNER ACTIVE: BERSERK OVERDRIVE (60s cd, 5s duration) ---
func _activate_gunner_skill() -> void:
	is_gunner_active = true
	gunner_timer = GUNNER_ACTIVE_DURATION
	var cd = GUNNER_COOLDOWN * GameManager.get_skill_cooldown_mult()
	skill_cooldown_timer = cd
	skill_ready = false
	
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
	if is_charging:
		_cancel_charge()
	for d in active_drones:
		if is_instance_valid(d):
			d.is_reloading = false
			d.reload_timer = 0.0
	
	SoundManager.play("level_up", 0.25, 0.6)
	shake_intensity = 0.22
	_spawn_floating_text("BERSERK OVERDRIVE!", Color(1.0, 0.2, 0.2))
	
	var cur_w = weapons[active_weapon_idx]
	ammo_changed.emit(cur_w.current_ammo, cur_w.max_ammo, false)

func _end_gunner_skill() -> void:
	is_gunner_active = false
	gunner_timer = 0.0
	# Reload all weapons after skill ends
	for w in weapons:
		w.current_ammo = w.max_ammo
	is_reloading = false
	reload_timer = 0.0
	# Reload all companion drones after skill ends
	for d in active_drones:
		if is_instance_valid(d):
			if d.assigned_weapon_idx >= 0 and d.assigned_weapon_idx < weapons.size():
				d.current_ammo = weapons[d.assigned_weapon_idx].max_ammo
			d.is_reloading = false
			d.reload_timer = 0.0
	SoundManager.play("reload", 0.15, 0.0)
	var cur_w = weapons[active_weapon_idx]
	ammo_changed.emit(cur_w.current_ammo, cur_w.max_ammo, false)

func _activate_slayer_skill() -> void:
	_activate_gunner_skill()

func _end_slayer_skill() -> void:
	_end_gunner_skill()

func _create_dash_effect(pos: Vector3, dir: Vector3) -> void:
	var scene_root = get_tree().current_scene if get_tree() else get_parent()
	if not scene_root:
		return
	
	var p = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.35
	p.amount = 24
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.35)
	mesh.material = mat
	p.mesh = mesh
	
	p.direction = -dir
	p.spread = 45.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	
	scene_root.add_child(p)
	p.global_position = pos + Vector3(0, 0.9, 0)
	p.emitting = true
	
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.2)
	light.light_energy = 3.5
	light.omni_range = 6.0
	scene_root.add_child(light)
	light.global_position = pos + Vector3(0, 0.9, 0)
	var tw = get_tree().create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.25)
	tw.tween_callback(light.queue_free)
	
	get_tree().create_timer(0.45).timeout.connect(p.queue_free)

@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_dash(pos: Vector3, dir: Vector3) -> void:
	if not is_local_player:
		_create_dash_effect(pos, dir)
		SoundManager.play("dash", 0.08, -3.0)
