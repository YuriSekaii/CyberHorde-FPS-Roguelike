extends "res://scripts/enemies/enemy_base.gd"

## Blood Ghoul - Stage 2 Wave 50 Final Boss (under the Red Moon).
## A pitch-dark ghoul caked in old, dried blood that hunts from the shadows under the trees.
## Loop:
##   HIDE      Crouches in a tree's moon shadow (almost invisible). Waits until an operative is within 25m.
##   LOCK      After that operative stays within 25m for 2s it silently locks their position (no sound, no indicator)
##   LEAP      and jumps at it extremely fast. Touching an operative mid-jump pins them down.
##   PIN       Claws the pinned operative every 0.3s (medium damage, heals the Ghoul 1% Max HP per landed strike)
##             until they mash A / D 10 times to escape. Then it's knocked down for 1s and flees REALLY fast to a
##             random tree to hide again.
##   MISS      If the jump misses, momentum drags it 5m past the locked spot and it falls: stunned for 3s, then flees.
## Every Ghoul attack inflicts Bleed (1% Max HP/s, 5% while moving, +1s per hit and stacking, bypasses shield).
## While hiding it only takes direct bullet hits (like a Spawnling) and drones ignore it; after losing 1% Max HP
## while hidden it relocates to another random tree.

enum GhoulState { HIDING, LEAPING, OVERSHOOT, FALLEN, PINNING, KNOCKDOWN, FLEEING }

const BOSS_MAX_HP: float = 2000000.0
const ATTACK_RANGE: float = 25.0
const LOCK_TIME: float = 2.0
const LEAP_SPEED: float = 42.0
const LEAP_GRAVITY: float = 40.0
const LEAP_PIN_RANGE: float = 1.9
const LEAP_TIMEOUT: float = 1.6
const OVERSHOOT_DISTANCE: float = 5.0
const FALL_STUN_TIME: float = 3.0
const KNOCKDOWN_TIME: float = 1.0
const PIN_HIT_INTERVAL: float = 0.3
const PIN_ESCAPE_PRESSES: int = 10
const PIN_LIFESTEAL: float = 0.01
const PIN_HIT_DMG_MULT: float = 0.2
const POUNCE_DMG_MULT: float = 0.5
const FLEE_SPEED: float = 24.0
const FLEE_TIMEOUT: float = 7.0
const HIDE_ARRIVE_DIST: float = 1.0
const HIDE_MIN_PLAYER_DIST: float = 14.0
const HIDE_RELOCATE_DAMAGE: float = 0.01 # Fraction of Max HP taken while hiding that makes it switch trees
const GRAVITY: float = 20.0

const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

var state: GhoulState = GhoulState.HIDING
var state_timer: float = 0.0
var hide_spot: Vector3 = Vector3.ZERO
var hide_index: int = -1
var range_timer: float = 0.0
var leap_dir: Vector3 = Vector3.ZERO
var leap_dist: float = 0.0
var leap_traveled: float = 0.0
var leap_vy: float = 0.0
var overshoot_speed: float = 0.0
var pinned_player: Node = null
var pin_hit_timer: float = 0.0
var anim_time: float = 0.0
var hide_damage_taken: float = 0.0

@onready var body_root: Node3D = $MeshRoot/Body

func _ready() -> void:
	enemy_name = "Blood Ghoul"
	super._ready()
	hide_spot = global_position
	hide_spot.y = 0.0
	hide_index = _nearest_hide_index(global_position)
	_set_state(GhoulState.HIDING)
	rotation.y = atan2(global_position.x, global_position.z) # face the arena center
	GameManager.boss_spawned.emit(self)
	GameManager.boss_health_updated.emit(current_health, max_health)

func _apply_wave_scaling() -> void:
	# Fixed HP and cadence like the Apex Overlord; damage scales with the wave curve (capped)
	max_health = BOSS_MAX_HP
	current_health = max_health
	attack_damage = clampf(120.0 * GameManager.get_wave_damage_factor(), 120.0, 600.0)
	wave_speed_mult = 1.0
	attack_speed_mult = 1.0
	damage_reduction = clampf(floorf(GameManager.get_scaling_wave() / 10.0) * 0.10, 0.0, 0.50)

func take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = EnemyBase.DAMAGE_TYPE_DIRECT, killer_source: Variant = null) -> void:
	var hp_before = current_health
	super.take_damage(amount, is_crit, from_pos, damage_type, killer_source)
	if is_dead:
		return
	GameManager.boss_health_updated.emit(current_health, max_health)
	# Hurt enough while hidden: slip away to another tree
	if state == GhoulState.HIDING:
		hide_damage_taken += maxf(0.0, hp_before - current_health)
		if hide_damage_taken >= max_health * HIDE_RELOCATE_DAMAGE:
			_start_flee()

## Hidden in the shadows it can only be hurt by direct bullet hits (no AoE, ricochet or chain lightning)
func is_immune_to(damage_type: int) -> bool:
	return state == GhoulState.HIDING and damage_type != DAMAGE_TYPE_DIRECT and damage_type != DAMAGE_TYPE_WEAKPOINT

func _behave(delta: float) -> void:
	state_timer += delta
	anim_time += delta
	match state:
		GhoulState.HIDING:
			_process_hiding(delta)
		GhoulState.LEAPING:
			_process_leaping(delta)
		GhoulState.OVERSHOOT:
			_process_overshoot(delta)
		GhoulState.FALLEN:
			_hold_still(delta)
			if state_timer >= FALL_STUN_TIME:
				_start_flee()
		GhoulState.PINNING:
			_process_pinning(delta)
		GhoulState.KNOCKDOWN:
			_hold_still(delta)
			if state_timer >= KNOCKDOWN_TIME:
				_start_flee()
		GhoulState.FLEEING:
			_process_fleeing(delta)
	_animate_pose(delta)

func _set_state(new_state: GhoulState) -> void:
	state = new_state
	state_timer = 0.0
	# Companion drones can't spot it while it hides
	if state == GhoulState.HIDING:
		hide_damage_taken = 0.0
		add_to_group("drone_ignore")
	else:
		remove_from_group("drone_ignore")

func _hold_still(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

# ----------------- HIDE & LOCK -----------------

func _process_hiding(delta: float) -> void:
	_hold_still(delta)
	var p = _nearest_player_in_range(ATTACK_RANGE)
	if p == null:
		range_timer = 0.0
		return
	# Slowly turn to watch the prey
	var to_p = p.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), 3.0 * delta)
	range_timer += delta
	if range_timer >= LOCK_TIME:
		# Silent lock-in: no sound, no flash, no indicator
		_start_leap(p.global_position)

func _nearest_player_in_range(max_range: float) -> Node:
	var best: Node = null
	var best_d = max_range
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.get("is_downed") == true:
			continue
		var d = global_position.distance_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best

# ----------------- LEAP / MISS -----------------

func _start_leap(locked_pos: Vector3) -> void:
	range_timer = 0.0
	var flat = Vector3(locked_pos.x - global_position.x, 0.0, locked_pos.z - global_position.z)
	leap_dist = maxf(flat.length(), 0.5)
	leap_dir = flat.normalized() if flat.length_squared() > 0.001 else -global_transform.basis.z
	leap_traveled = 0.0
	# Low, flat arc that lands exactly on the locked spot
	var flight_time = leap_dist / LEAP_SPEED
	leap_vy = LEAP_GRAVITY * flight_time * 0.5 + (locked_pos.y - global_position.y) / maxf(flight_time, 0.05)
	rotation.y = atan2(-leap_dir.x, -leap_dir.z)
	_set_state(GhoulState.LEAPING)

func _process_leaping(delta: float) -> void:
	leap_vy -= LEAP_GRAVITY * delta
	velocity = leap_dir * LEAP_SPEED + Vector3(0.0, leap_vy, 0.0)
	var before = global_position
	move_and_slide()
	var moved = global_position - before
	leap_traveled += Vector2(moved.x, moved.z).length()

	if _try_pin_nearby():
		return
	# Slammed into a trunk / wall: crash straight down
	if is_on_wall() and state_timer > 0.05:
		_fall_down()
		return
	if leap_traveled >= leap_dist or state_timer >= LEAP_TIMEOUT:
		overshoot_speed = LEAP_SPEED
		_set_state(GhoulState.OVERSHOOT)

func _process_overshoot(delta: float) -> void:
	# Missed: momentum drags it ~5m past the locked spot before it tumbles over
	var decel = (LEAP_SPEED * LEAP_SPEED) / (2.0 * OVERSHOOT_DISTANCE)
	overshoot_speed = maxf(0.0, overshoot_speed - decel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = leap_dir.x * overshoot_speed
	velocity.z = leap_dir.z * overshoot_speed
	move_and_slide()
	if overshoot_speed <= 0.0 or is_on_wall() or state_timer > 1.0:
		_fall_down()

func _fall_down() -> void:
	velocity = Vector3.ZERO
	SoundManager.play_pitch("charger_crash", 0.7, -4.0)
	_set_state(GhoulState.FALLEN)

# ----------------- PIN -----------------

func _try_pin_nearby() -> bool:
	var chest = global_position + Vector3(0, 0.9, 0)
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.get("is_downed") == true or not p.has_method("apply_trap"):
			continue
		if chest.distance_to(p.global_position + Vector3(0, 0.9, 0)) > LEAP_PIN_RANGE:
			continue
		if p.apply_trap(self, INF, 0.0, PIN_ESCAPE_PRESSES):
			pinned_player = p
			add_collision_exception_with(p)
			p.add_collision_exception_with(self)
			velocity = Vector3.ZERO
			_set_state(GhoulState.PINNING)
			SoundManager.play_pitch("charger_crash", 1.3, -2.0)
			_strike(POUNCE_DMG_MULT, false)
			pin_hit_timer = PIN_HIT_INTERVAL
			return true
	return false

func _process_pinning(delta: float) -> void:
	if not is_instance_valid(pinned_player) or pinned_player.get("trap_source") != self:
		_release_pin()
		_start_flee()
		return
	# Crouch over the operative, facing them
	var p_pos: Vector3 = pinned_player.global_position
	var fwd = Vector3.FORWARD
	if pinned_player.has_method("get_look_direction"):
		fwd = pinned_player.get_look_direction()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	global_position = global_position.lerp(p_pos + fwd * 0.9, 20.0 * delta)
	rotation.y = atan2(fwd.x, fwd.z)
	velocity = Vector3.ZERO

	pin_hit_timer -= delta
	if pin_hit_timer <= 0.0:
		pin_hit_timer = PIN_HIT_INTERVAL
		_strike(PIN_HIT_DMG_MULT, true)

## A Ghoul attack: damage + Bleed; pin strikes also heal it 1% Max HP when they land
func _strike(dmg_mult: float, lifesteal: bool) -> void:
	var victim = pinned_player
	if not is_instance_valid(victim):
		return
	# A lethal strike releases the pin (and clears pinned_player) from inside take_damage
	var landed = victim.take_damage(attack_damage * dmg_mult)
	if not landed:
		return
	if victim.get("is_downed") != true and victim.has_method("apply_bleed"):
		victim.apply_bleed()
	SoundManager.play_pitch("enemy_hit", 0.6, -3.0)
	if lifesteal:
		current_health = minf(max_health, current_health + max_health * PIN_LIFESTEAL)
		GameManager.boss_health_updated.emit(current_health, max_health)
	if body_root:
		body_root.rotation.x = 0.9
		var tw = create_tween()
		tw.tween_property(body_root, "rotation:x", 0.45, 0.15)

## Called by the player when the pin ends
func on_trap_released(player: Node, escaped: bool) -> void:
	if player != pinned_player:
		return
	_release_pin()
	if is_dead:
		return
	if escaped:
		# Thrown off: knocked down for 1s, then bolts for the trees
		var away = global_position - player.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			global_position += away.normalized() * 1.2
		_set_state(GhoulState.KNOCKDOWN)
	else:
		_start_flee()

func _release_pin() -> void:
	if is_instance_valid(pinned_player):
		remove_collision_exception_with(pinned_player)
		pinned_player.remove_collision_exception_with(self)
	pinned_player = null

# ----------------- FLEE & HIDE -----------------

func _start_flee() -> void:
	hide_index = _pick_hide_index()
	var arena = _get_arena()
	if arena and hide_index >= 0:
		hide_spot = arena.get_hide_spots()[hide_index]
	_set_state(GhoulState.FLEEING)

func _process_fleeing(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var to_spot = Vector3(hide_spot.x - global_position.x, 0.0, hide_spot.z - global_position.z)
	if to_spot.length() <= HIDE_ARRIVE_DIST:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		range_timer = 0.0
		_set_state(GhoulState.HIDING)
		return
	if state_timer >= FLEE_TIMEOUT:
		# Stuck somewhere: pick another tree
		_start_flee()
		return
	var dir = nav_direction_to(hide_spot, delta)
	if dir != Vector3.ZERO:
		var move_dir = steer_around_cover(dir, delta)
		var flee_speed = FLEE_SPEED * slow_multiplier
		velocity.x = move_dir.x * flee_speed
		velocity.z = move_dir.z * flee_speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 14.0 * delta)
	move_and_slide()

func _get_arena() -> Node:
	return get_tree().get_first_node_in_group("jungle_arena")

func _nearest_hide_index(pos: Vector3) -> int:
	var arena = _get_arena()
	if arena == null:
		return -1
	var spots: Array[Vector3] = arena.get_hide_spots()
	var best = -1
	var best_d = INF
	for i in range(spots.size()):
		var d = pos.distance_squared_to(spots[i])
		if d < best_d:
			best_d = d
			best = i
	return best

## A random tree other than the current one, preferring trees away from every operative
func _pick_hide_index() -> int:
	var arena = _get_arena()
	if arena == null:
		return -1
	var spots: Array[Vector3] = arena.get_hide_spots()
	if spots.is_empty():
		return -1
	var far: Array[int] = []
	var any: Array[int] = []
	var players = get_tree().get_nodes_in_group("player")
	for i in range(spots.size()):
		if i == hide_index:
			continue
		any.append(i)
		var min_d = INF
		for p in players:
			if is_instance_valid(p):
				min_d = minf(min_d, spots[i].distance_to(p.global_position))
		if min_d >= HIDE_MIN_PLAYER_DIST:
			far.append(i)
	if not far.is_empty():
		return far.pick_random()
	if not any.is_empty():
		return any.pick_random()
	return hide_index

# ----------------- VISUALS -----------------

func _animate_pose(delta: float) -> void:
	if not body_root:
		return
	var target_tilt = 0.45 # hunched
	var target_roll = 0.0
	var target_drop = 0.0
	match state:
		GhoulState.HIDING:
			target_tilt = 0.75
			target_drop = -0.45
		GhoulState.LEAPING:
			target_tilt = 1.2
		GhoulState.OVERSHOOT:
			target_tilt = 1.2 + clampf(state_timer * 2.5, 0.0, 0.4)
		GhoulState.FALLEN:
			target_tilt = 0.2
			target_roll = 1.45
			target_drop = -0.8
		GhoulState.KNOCKDOWN:
			target_tilt = -0.9
			target_drop = -0.6
		GhoulState.PINNING:
			target_tilt = 0.8
			target_drop = -0.35
		GhoulState.FLEEING:
			target_tilt = 0.95 + sin(anim_time * 18.0) * 0.08
	body_root.rotation.z = lerpf(body_root.rotation.z, target_roll, 10.0 * delta)
	body_root.position.y = lerpf(body_root.position.y, target_drop, 10.0 * delta)
	if state != GhoulState.PINNING:
		body_root.rotation.x = lerpf(body_root.rotation.x, target_tilt, 10.0 * delta)

func die() -> void:
	if is_dead:
		return
	if is_instance_valid(pinned_player) and pinned_player.get("trap_source") == self:
		pinned_player.release_trap(false)
	_release_pin()
	is_dead = true
	GameManager.boss_defeated.emit()
	SoundManager.play("explosion", 0.3, -3.0)

	var death_exp = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(death_exp)
	death_exp.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	death_exp.setup(0.0, 8.0)

	var is_rogue_kill = last_hit_by_rogue or (GameManager.player_class == "rogue" and not NetworkManager.is_multiplayer)
	var loot_mult: float = 3.0 if is_rogue_kill else 1.0
	var fever_mult: float = GameManager.get_fever_loot_mult()
	GameManager.add_xp(int(1200 * loot_mult * fever_mult))
	GameManager.add_scrap(int(800 * loot_mult * fever_mult))
	GameManager.record_kill(enemy_name)

	for i in range(4):
		var hp = LOOT_SCENE.instantiate()
		get_parent().call_deferred("add_child", hp)
		hp.position = global_position + Vector3(randf_range(-2.5, 2.5), 0.5, randf_range(-2.5, 2.5))
		hp.setup(1, 50)
	queue_free()
