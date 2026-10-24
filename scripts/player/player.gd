extends CharacterBody3D

signal health_changed(current: float, max_hp: float)
signal shield_changed(current: float, max_shield: float)
signal ammo_changed(current: int, max_mag: int, is_reloading: bool)
signal weapon_changed(weapon_index: int, weapon_name: String)

# Movement Settings
const BASE_WALK_SPEED: float = 7.0
const SPRINT_MULTIPLIER: float = 1.4
const JUMP_VELOCITY: float = 6.8
const GRAVITY: float = 20.0
const MOUSE_SENSITIVITY: float = 0.0022

# State
var current_health: float = 100.0
var max_health: float = 100.0
var current_shield: float = 0.0
var shield_regen_timer: float = 0.0
var is_invulnerable: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Head Bobbing & Shake
var bob_time: float = 0.0
var shake_intensity: float = 0.0

# Weapons Configuration
class Weapon:
	var name: String
	var fire_rate: float # Seconds per shot
	var damage: float
	var max_ammo: int
	var current_ammo: int
	var reload_time: float
	var is_auto: bool
	var pellets: int
	var spread: float
	var is_explosive: bool
	var sound_name: String

var weapons: Array[Weapon] = []
var active_weapon_idx: int = 0
var fire_cooldown: float = 0.0
var reload_timer: float = 0.0
var is_reloading: bool = false

# Drone Companion
var drone_timer: float = 0.0

# Node References
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_rig: Node3D = $Head/Camera3D/WeaponRig
@onready var gun_model_rifle: Node3D = $Head/Camera3D/WeaponRig/Rifle
@onready var gun_model_shotgun: Node3D = $Head/Camera3D/WeaponRig/Shotgun
@onready var gun_model_plasma: Node3D = $Head/Camera3D/WeaponRig/Plasma
@onready var muzzle_flash_light: OmniLight3D = $Head/Camera3D/WeaponRig/MuzzleFlashLight
@onready var muzzle_particles: CPUParticles3D = $Head/Camera3D/WeaponRig/MuzzleParticles
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var drone_companion: Node3D = $DroneCompanion

const BULLET_SCENE = preload("res://scenes/projectiles/bullet.tscn")

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_weapons()
	_update_stats()
	
	GameManager.stats_updated.connect(_update_stats)
	muzzle_flash_light.visible = false

func _setup_weapons() -> void:
	# Weapon 0: Pulse Rifle
	var rifle = Weapon.new()
	rifle.name = "Pulse Carbine"
	rifle.fire_rate = 0.12
	rifle.damage = 22.0
	rifle.max_ammo = 32
	rifle.current_ammo = 32
	rifle.reload_time = 1.2
	rifle.is_auto = true
	rifle.pellets = 1
	rifle.spread = 0.02
	rifle.is_explosive = false
	rifle.sound_name = "shoot_rifle"
	weapons.append(rifle)
	
	# Weapon 1: Scatter Shotgun
	var shotgun = Weapon.new()
	shotgun.name = "Scatter Cannon"
	shotgun.fire_rate = 0.65
	shotgun.damage = 14.0
	shotgun.max_ammo = 8
	shotgun.current_ammo = 8
	shotgun.reload_time = 1.6
	shotgun.is_auto = false
	shotgun.pellets = 7
	shotgun.spread = 0.075
	shotgun.is_explosive = false
	shotgun.sound_name = "shoot_shotgun"
	weapons.append(shotgun)
	
	# Weapon 2: Plasma Launcher
	var plasma = Weapon.new()
	plasma.name = "Plasma Core"
	plasma.fire_rate = 0.85
	plasma.damage = 65.0
	plasma.max_ammo = 5
	plasma.current_ammo = 5
	plasma.reload_time = 1.8
	plasma.is_auto = false
	plasma.pellets = 1
	plasma.spread = 0.015
	plasma.is_explosive = true
	plasma.sound_name = "shoot_plasma"
	weapons.append(plasma)
	
	_switch_weapon(0)

func _update_stats() -> void:
	max_health = 100.0 + GameManager.max_health_bonus
	current_health = minf(current_health, max_health)
	current_shield = minf(current_shield, GameManager.shield_max)
	
	if drone_companion:
		drone_companion.visible = (GameManager.drone_count > 0)
	
	health_changed.emit(current_health, max_health)
	shield_changed.emit(current_shield, GameManager.shield_max)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -deg_to_rad(88.0), deg_to_rad(88.0))
		
		# Weapon sway
		if weapon_rig:
			weapon_rig.position.x = lerpf(weapon_rig.position.x, -event.relative.x * 0.0004, 0.2)
			weapon_rig.position.y = lerpf(weapon_rig.position.y, event.relative.y * 0.0004, 0.2)
	
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
	
	_handle_movement(delta)
	_handle_weapons(delta)
	_handle_shield_regen(delta)
	_handle_drone(delta)
	_handle_head_bob_and_shake(delta)

func _handle_movement(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = 0.15 # 150ms coyote time
	
	# Jump buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.15
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
	
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY * (1.0 + (GameManager.speed_mult - 1.0) * 0.5)
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	# Movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_basis = transform.basis
	var forward = -move_basis.z
	var right = move_basis.x
	var wish_dir = (right * input_dir.x + forward * -input_dir.y).normalized()
	
	var is_sprinting = Input.is_action_pressed("sprint")
	var target_speed = BASE_WALK_SPEED * GameManager.speed_mult
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
	
	# Reloading
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			w.current_ammo = w.max_ammo
			ammo_changed.emit(w.current_ammo, w.max_ammo, false)
		return
	
	# Manual reload
	if Input.is_action_just_pressed("reload") and w.current_ammo < w.max_ammo:
		_start_reload()
		return
	
	# Shooting
	var wants_fire = Input.is_action_pressed("shoot") if w.is_auto else Input.is_action_just_pressed("shoot")
	if wants_fire:
		if w.current_ammo > 0:
			if fire_cooldown <= 0.0:
				_fire_active_weapon()
		else:
			SoundManager.play("empty_ammo")
			_start_reload()

func _fire_active_weapon() -> void:
	var w = weapons[active_weapon_idx]
	var effective_cooldown = w.fire_rate / GameManager.fire_rate_mult
	fire_cooldown = effective_cooldown
	w.current_ammo -= 1
	ammo_changed.emit(w.current_ammo, w.max_ammo, false)
	
	# Sound & Muzzle flash
	SoundManager.play(w.sound_name, 0.08)
	_flash_muzzle()
	
	# Weapon kick recoil
	if weapon_rig:
		weapon_rig.position.z = 0.08
		weapon_rig.rotation.x = deg_to_rad(4.0)
	shake_intensity = 0.08 if active_weapon_idx != 1 else 0.18
	
	# Spawn bullets (pellets + multishot)
	var total_projectiles = w.pellets + GameManager.extra_projectiles
	var shoot_origin = camera.global_position + (-camera.global_transform.basis.z * 0.5)
	
	for i in range(total_projectiles):
		var bullet = BULLET_SCENE.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = shoot_origin
		
		# Direction with spread
		var base_dir = -camera.global_transform.basis.z
		var spread_angle = w.spread
		if total_projectiles > 1:
			spread_angle = maxf(spread_angle, 0.05)
		
		var spread_x = randf_range(-spread_angle, spread_angle)
		var spread_y = randf_range(-spread_angle, spread_angle)
		var bullet_dir = (base_dir + camera.global_transform.basis.x * spread_x + camera.global_transform.basis.y * spread_y).normalized()
		
		bullet.setup(bullet_dir, w.damage, w.is_explosive)

func _flash_muzzle() -> void:
	muzzle_flash_light.visible = true
	if muzzle_particles:
		muzzle_particles.restart()
		muzzle_particles.emitting = true
	get_tree().create_timer(0.04).timeout.connect(func(): muzzle_flash_light.visible = false)

func _start_reload() -> void:
	var w = weapons[active_weapon_idx]
	if is_reloading:
		return
	is_reloading = true
	reload_timer = w.reload_time
	SoundManager.play("reload", 0.05)
	ammo_changed.emit(w.current_ammo, w.max_ammo, true)

func _switch_weapon(new_idx: int) -> void:
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

func _handle_shield_regen(delta: float) -> void:
	if GameManager.shield_max <= 0.0:
		return
	
	shield_regen_timer += delta
	if shield_regen_timer >= 4.0 and current_shield < GameManager.shield_max:
		current_shield = minf(GameManager.shield_max, current_shield + 20.0 * delta)
		GameManager.current_shield = current_shield
		shield_changed.emit(current_shield, GameManager.shield_max)

func _handle_drone(delta: float) -> void:
	if GameManager.drone_count <= 0 or not drone_companion:
		return
	
	# Orbit drone
	var t = Time.get_ticks_msec() / 1000.0 * 2.0
	drone_companion.position = Vector3(cos(t) * 1.5, 1.8 + sin(t * 2.0) * 0.15, sin(t) * 1.5)
	
	drone_timer += delta
	if drone_timer >= 1.2:
		drone_timer = 0.0
		# Search for nearest enemy
		var enemies = get_tree().get_nodes_in_group("enemies")
		var closest: Node3D = null
		var min_dist: float = 16.0
		for e in enemies:
			if e is Node3D:
				var d = drone_companion.global_position.distance_to(e.global_position)
				if d < min_dist:
					min_dist = d
					closest = e
		
		if closest:
			# Fire drone laser
			var bullet = BULLET_SCENE.instantiate()
			get_parent().add_child(bullet)
			bullet.global_position = drone_companion.global_position
			var dir = (closest.global_position + Vector3(0, 0.8, 0) - bullet.global_position).normalized()
			bullet.setup(dir, 18.0 * GameManager.damage_mult, false)
			SoundManager.play("shoot_rifle", 0.3, -4.0)

func _handle_head_bob_and_shake(delta: float) -> void:
	# Recover weapon rig position
	if weapon_rig:
		weapon_rig.position = weapon_rig.position.lerp(Vector3(0.24, -0.22, -0.45), 10.0 * delta)
		weapon_rig.rotation = weapon_rig.rotation.lerp(Vector3.ZERO, 10.0 * delta)
	
	# Head bob
	var is_moving = is_on_floor() and velocity.length_squared() > 1.0
	if is_moving:
		bob_time += delta * (14.0 if Input.is_action_pressed("sprint") else 10.0)
		camera.position.y = lerpf(camera.position.y, sin(bob_time) * 0.05, 10.0 * delta)
		camera.position.x = lerpf(camera.position.x, cos(bob_time * 0.5) * 0.03, 10.0 * delta)
	else:
		bob_time = 0.0
		camera.position = camera.position.lerp(Vector3.ZERO, 8.0 * delta)
	
	# Camera shake
	if shake_intensity > 0.001:
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = lerpf(shake_intensity, 0.0, 12.0 * delta)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func take_damage(amount: float) -> void:
	if is_invulnerable:
		return
	
	shield_regen_timer = 0.0
	shake_intensity = 0.25
	
	# Shield absorbs first
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
	
	if current_health <= 0:
		if GameManager.second_wind_available:
			_trigger_second_wind()
		else:
			die()

func _trigger_second_wind() -> void:
	GameManager.second_wind_available = false
	current_health = 45.0
	is_invulnerable = true
	SoundManager.play("level_up", 0.2, 2.0)
	health_changed.emit(current_health, max_health)
	
	# 3s Invulnerability
	await get_tree().create_timer(3.0).timeout
	is_invulnerable = false

func heal(amount: float) -> void:
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func apply_impulse_jump(force: float) -> void:
	velocity.y = force
	SoundManager.play("jump_pad", 0.05)

func die() -> void:
	GameManager.trigger_game_over()
