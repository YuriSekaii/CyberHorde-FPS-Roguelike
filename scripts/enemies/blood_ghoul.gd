extends "res://scripts/enemies/enemy_base.gd"

## Blood Ghoul - Stage 2 Wave 50 Final Boss (under the Red Moon).
## A pitch-black abyss beast splattered with its victims' blood that hunts from the shadows under the trees.
## Loop:
##   HIDE      Crouches in a tree's moon shadow (almost invisible). Waits until an operative is within 25m.
##   LOCK      After that operative stays within 25m for 2s it silently locks their position (no sound, no indicator)
##   LEAP      and jumps at it extremely fast. Touching an operative mid-jump pins them down.
##   PIN       Knocks the operative flat on their back and straddles them, raking with alternating claws every 0.3s
##             (medium damage, heals the Ghoul 1% Max HP per landed strike) while their camera stays locked looking
##             up at it, until they mash A / D 10 times to escape. Then it's knocked down for 1s and flees REALLY
##             fast to a random tree to hide again.
##   MISS      If the jump misses, momentum drags it 5m past the locked spot and it falls: stunned for 3s, then flees.
##   ENGAGE    After 10s total hiding with nobody in its 25m reach (the count only restarts after a leap), its eyes
##             glow red and it takes 90% less damage while hiding. Whenever no operative has looked at it for 2s
##             (staring pauses the count, 2s of staring resets it) it hops to another tree closer to the nearest
##             operative, then waits for another 2s unwatched. No closer tree left: it leaps straight at them from
##             any range. Leaping at someone ends Engage mode.
## Every Ghoul attack inflicts Bleed (1% Max HP/s, 5% while moving, +1.5s per hit and stacking, bypasses shield).
## While hiding it only takes direct bullet hits (like a Spawnling) and drones ignore it; after losing 1% Max HP
## while hidden it relocates to another random tree and drops Engage mode, fully immune until it gets there.
## Phases (by HP, never revert even if lifesteal heals it back):
##   1  > 2/3    As above.
##   2  > 1/3    Engages after 5s, hops after 1s unwatched, hops 50% faster.
##   3  > 10%    Permanently engaged; hops the instant nobody is looking at it.
##   4  <= 10%   Stops hiding: hunts the nearest operative endlessly, with 90% damage reduction. Locks on in
##               1.5s; knockdown 1.5s, miss stun 4s.

enum GhoulState { HIDING, LEAPING, OVERSHOOT, FALLEN, PINNING, KNOCKDOWN, FLEEING, HOPPING, HUNTING }

const BOSS_MAX_HP: float = 1000000.0
const BOSS_DAMAGE: float = 200.0 # Fixed, no wave scaling
const ATTACK_RANGE: float = 25.0
const LOCK_TIME: float = 2.0
const LEAP_SPEED: float = 42.0
const LEAP_GRAVITY: float = 40.0
const LEAP_PIN_RANGE: float = 1.9
const LEAP_TIMEOUT: float = 1.6
const OVERSHOOT_DISTANCE: float = 5.0
const FALL_STUN_TIME: float = 5.0
const KNOCKDOWN_TIME: float = 2.0
const PIN_HIT_INTERVAL: float = 0.3
const PIN_ESCAPE_PRESSES: int = 10
const PIN_LIFESTEAL: float = 0.01
const PIN_HIT_DMG_MULT: float = 0.2
const POUNCE_DMG_MULT: float = 0.5
const PIN_STRADDLE_DIST: float = 1.0 # Crouches over the pinned operative, this far from their head
const PIN_LEAN: float = 0.5 # Forward lean over the pinned operative; each strike lunges deeper
const PIN_LUNGE_LEAN: float = 0.85
const PIN_TWIST: float = 0.3 # Torso yaw that wrenches the striking shoulder forward into each blow
const PIN_RAKE_HEIGHT: float = 0.85 # Claws rake through this height above the pinned operative (just over their face)
# One arm's claw cycle (2 strike intervals, the strike lands at 0): drag through -> raise overhead -> swing down
const CLAW_DRAG_END: float = 0.12
const CLAW_RAISE_END: float = 0.46
const EYE_GLOW: float = 4.0 # Red pupils ignite once it leaves the shadows
const DRIP_GRAVITY: float = 9.8 # Blood drops falling off the claws
const FLEE_SPEED: float = 24.0
const FLEE_TIMEOUT: float = 7.0
const HIDE_ARRIVE_DIST: float = 1.0
const HIDE_MIN_PLAYER_DIST: float = 14.0
const HIDE_RELOCATE_DAMAGE: float = 0.01 # Fraction of Max HP taken while hiding that makes it switch trees
const ENGAGE_IDLE_TIME: float = 10.0 # Nobody within reach this long: Engage mode
const ENGAGED_DAMAGE_REDUCTION: float = 0.9 # While hiding in Engage mode; multiplies with the wave reduction
const ENGAGED_EYE_GLOW: float = 1.6 # Visible from across the jungle, well short of the full hunting blaze
const HOP_UNWATCHED_TIME: float = 2.0 # Unwatched this long: hop to the next tree
const HOP_STARE_RESET_TIME: float = 2.0 # Stared at this long: the unwatched count resets
const HOP_SPEED: float = 30.0
const HOP_TIMEOUT: float = 2.0
const HOP_MAX_DIST: float = 22.0 # Prefers trees within one hop
const HOP_MIN_GAIN: float = 3.0 # Each hop must land at least this much closer to the operative
const PHASE_2_HP: float = 2.0 / 3.0 # HP fraction at or below which each phase starts
const PHASE_3_HP: float = 1.0 / 3.0
const PHASE_4_HP: float = 0.1
const PHASE_2_TIME_MULT: float = 0.5 # Engage trigger and hop wait from phase 2
const PHASE_2_HOP_SPEED_MULT: float = 1.5
const PHASE_4_DAMAGE_REDUCTION: float = 0.9 # While exposed; multiplies with the wave reduction
const PHASE_4_LOCK_TIME: float = 1.5
const PHASE_4_FALL_STUN_TIME: float = 4.0
const PHASE_4_KNOCKDOWN_TIME: float = 1.5
const HUNT_SPEED: float = 24.0
const HUNT_HOLD_DIST: float = 12.0 # Closes to this range, then crouches for the lock
const VIEW_CONE_DOT: float = 0.8 # ~37 degrees off the look direction (same as the Mantis Stalker)
const VIEW_MAX_DIST: float = 70.0
const WATCH_CHECK_INTERVAL: float = 0.1
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
var pin_dir: Vector3 = Vector3.FORWARD # Flat direction from the pinned operative to the Ghoul
var pin_time: float = 0.0 # Drives the claw swipes, in step with the strikes
var arm_pivots: Array[Node3D] = [] # [left, right] shoulder joints
var arm_elbows: Array[Node3D] = []
var arm_hands: Array[Node3D] = []
var arm_fingers: Array = [] # Per arm: finger + thumb joints (curl on X)
var body_base_y: float = 1.0 # Torso pivot height from the scene; pose drops are offsets from it
var anim_time: float = 0.0
var hide_damage_taken: float = 0.0
var retreat_immune: bool = false # Immune to everything while fleeing after the 1% hide-damage relocate
var engaged: bool = false
var idle_timer: float = 0.0 # Time hiding with nobody in reach, since its last leap
var unwatched_timer: float = 0.0
var stare_timer: float = 0.0
var hop_index: int = -1 # Tree it's hopping to, -1 = open ground toward the operative (no closer tree left)
var hop_target: Vector3 = Vector3.ZERO
var hop_dir: Vector3 = Vector3.ZERO
var hop_dist: float = 0.0
var hop_traveled: float = 0.0
var hop_vy: float = 0.0
var hop_speed: float = HOP_SPEED
var phase: int = 1
var is_watched: bool = false
var watch_check_timer: float = 0.0
var eye_engage: float = 0.0 # Engage-mode eye glow, 0..1 of ENGAGED_EYE_GLOW
var claw_drips: Array[Dictionary] = [] # Per drop: tip node, mesh, age, hang time, fall speed

@onready var body_root: Node3D = $MeshRoot/Body
@onready var head_mesh: Node3D = $MeshRoot/Body/Head
@onready var jaw: Node3D = $MeshRoot/Body/Head/Jaw
@onready var pupil_mat: StandardMaterial3D = ($MeshRoot/Body/Head/PupilL as MeshInstance3D).mesh.material
@onready var skin_mat: ShaderMaterial = ($MeshRoot/Body/Ribcage as MeshInstance3D).mesh.material
var body_glow: float = 0.0 # 0 dormant in the shadows .. 1 fully awake

func _ready() -> void:
	enemy_name = "Blood Ghoul"
	super._ready()
	if body_root:
		body_base_y = body_root.position.y
	_collect_arm_joints()
	_setup_claw_drips()
	hide_spot = global_position
	hide_spot.y = 0.0
	hide_index = _nearest_hide_index(global_position)
	_set_state(GhoulState.HIDING)
	rotation.y = atan2(global_position.x, global_position.z) # face the arena center
	GameManager.boss_spawned.emit(self)
	GameManager.boss_health_updated.emit(current_health, max_health)

func _apply_wave_scaling() -> void:
	# Fixed HP, damage and cadence
	max_health = BOSS_MAX_HP
	current_health = max_health
	attack_damage = BOSS_DAMAGE
	wave_speed_mult = 1.0
	attack_speed_mult = 1.0
	damage_reduction = clampf(floorf(GameManager.get_scaling_wave() / 10.0) * 0.10, 0.0, 0.50)

func take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = EnemyBase.DAMAGE_TYPE_DIRECT, killer_source: Variant = null) -> void:
	if engaged and state == GhoulState.HIDING:
		amount *= (1.0 - ENGAGED_DAMAGE_REDUCTION)
	elif phase >= 4:
		amount *= (1.0 - PHASE_4_DAMAGE_REDUCTION)
	var hp_before = current_health
	super.take_damage(amount, is_crit, from_pos, damage_type, killer_source)
	if is_dead:
		return
	GameManager.boss_health_updated.emit(current_health, max_health)
	_update_phase()
	# Hurt enough while hidden (or hopping between trees): slip away to another tree and calm down
	if _is_lurking() and phase < 4:
		hide_damage_taken += maxf(0.0, hp_before - current_health)
		if hide_damage_taken >= max_health * HIDE_RELOCATE_DAMAGE:
			_set_engaged(false)
			_start_flee()
			retreat_immune = state == GhoulState.FLEEING

## Hidden in the shadows it can only be hurt by direct bullet hits (no AoE, ricochet or chain lightning).
## Retreating to a new tree after the 1% relocate it can't be hurt at all.
func is_immune_to(damage_type: int) -> bool:
	if retreat_immune:
		return true
	return state == GhoulState.HIDING and damage_type != DAMAGE_TYPE_DIRECT and damage_type != DAMAGE_TYPE_WEAKPOINT

## In the shadows: hiding under a tree or hopping between trees
func _is_lurking() -> bool:
	return state == GhoulState.HIDING or state == GhoulState.HOPPING

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
			if state_timer >= (PHASE_4_FALL_STUN_TIME if phase >= 4 else FALL_STUN_TIME):
				_start_flee()
		GhoulState.PINNING:
			_process_pinning(delta)
		GhoulState.KNOCKDOWN:
			_hold_still(delta)
			if state_timer >= (PHASE_4_KNOCKDOWN_TIME if phase >= 4 else KNOCKDOWN_TIME):
				_start_flee()
		GhoulState.FLEEING:
			_process_fleeing(delta)
		GhoulState.HOPPING:
			_process_hopping(delta)
		GhoulState.HUNTING:
			_process_hunting(delta)
	_animate_pose(delta)

# ----------------- PHASES -----------------

## Phases only escalate: healing back over a threshold (pin lifesteal) doesn't calm it down
func _update_phase() -> void:
	var frac = current_health / max_health
	var new_phase = 4 if frac <= PHASE_4_HP else (3 if frac <= PHASE_3_HP else (2 if frac <= PHASE_2_HP else 1))
	if new_phase <= phase:
		return
	phase = new_phase
	SoundManager.play_pitch("charger_windup", 0.45, 0.0) # Guttural growl
	if phase >= 3:
		engaged = true
	# Done hiding: hunt right away (mid-leap, pin, stun or hop it switches over when that ends)
	if phase >= 4 and (state == GhoulState.HIDING or state == GhoulState.FLEEING):
		_start_hunt()

func _engage_idle_time() -> float:
	return ENGAGE_IDLE_TIME * (PHASE_2_TIME_MULT if phase >= 2 else 1.0)

func _hop_unwatched_time() -> float:
	if phase >= 3:
		return 0.0
	return HOP_UNWATCHED_TIME * (PHASE_2_TIME_MULT if phase >= 2 else 1.0)

func _set_state(new_state: GhoulState) -> void:
	var was_lurking = _is_lurking()
	state = new_state
	state_timer = 0.0
	# Retreat immunity only lasts the flee itself (re-picking a tree when stuck keeps it)
	if state != GhoulState.FLEEING:
		retreat_immune = false
	# The relocate counter covers one stay in the shadows, across tree hops
	if _is_lurking() and not was_lurking:
		hide_damage_taken = 0.0
	# Companion drones can't spot it while it hides
	if state == GhoulState.HIDING:
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
	if phase >= 4:
		_start_hunt()
		return
	_hold_still(delta)
	var p = _nearest_player_in_range(ATTACK_RANGE)
	if p == null:
		range_timer = 0.0
		# Nobody comes close: grow restless (the count only restarts after a leap), then hunt them tree by tree
		if engaged:
			_process_engaged(delta)
		else:
			idle_timer += delta
			if idle_timer >= _engage_idle_time():
				_set_engaged(true)
		return
	# Slowly turn to watch the prey
	var to_p = p.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), 3.0 * delta)
	range_timer += delta
	if range_timer >= (PHASE_4_LOCK_TIME if phase >= 4 else LOCK_TIME):
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

# ----------------- ENGAGE MODE & TREE HOPS -----------------

func _set_engaged(on: bool) -> void:
	engaged = on or phase >= 3 # Permanent from phase 3
	idle_timer = 0.0
	unwatched_timer = 0.0
	stare_timer = 0.0

## Engaged and nobody in reach: hop toward the nearest operative once nobody has watched it for 2s
func _process_engaged(delta: float) -> void:
	var prey = _nearest_player_in_range(INF)
	if prey == null:
		return
	# Glares at its prey, so the red eyes face them
	var to_p = prey.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), 3.0 * delta)
	watch_check_timer -= delta
	if watch_check_timer <= 0.0:
		watch_check_timer = WATCH_CHECK_INTERVAL
		is_watched = _is_being_watched()
	if is_watched:
		# Staring pauses the count; a long enough stare resets it
		stare_timer += delta
		if stare_timer >= HOP_STARE_RESET_TIME:
			unwatched_timer = 0.0
		return
	stare_timer = 0.0
	unwatched_timer += delta
	if unwatched_timer >= _hop_unwatched_time():
		_start_hop(prey.global_position)

func _start_hop(prey_pos: Vector3) -> void:
	unwatched_timer = 0.0
	stare_timer = 0.0
	if not _pick_hop_target(prey_pos):
		# No tree left that gets it closer: leap straight at them, however far
		_start_leap(prey_pos)
		return
	var flat = Vector3(hop_target.x - global_position.x, 0.0, hop_target.z - global_position.z)
	hop_dist = flat.length()
	hop_dir = flat / hop_dist
	hop_traveled = 0.0
	hop_speed = HOP_SPEED * (PHASE_2_HOP_SPEED_MULT if phase >= 2 else 1.0)
	# Arc that lands exactly on the target spot
	var flight_time = hop_dist / hop_speed
	hop_vy = LEAP_GRAVITY * flight_time * 0.5 + (hop_target.y - global_position.y) / maxf(flight_time, 0.05)
	rotation.y = atan2(-hop_dir.x, -hop_dir.z)
	_set_state(GhoulState.HOPPING)

## Next tree toward the operative: the closest to them within one hop, else the nearest tree that's still closer.
## False if no tree gets it closer.
func _pick_hop_target(prey_pos: Vector3) -> bool:
	var my_d = Vector2(prey_pos.x - global_position.x, prey_pos.z - global_position.z).length()
	var arena = _get_arena()
	var spots: Array[Vector3] = arena.get_hide_spots() if arena else ([] as Array[Vector3])
	var best_near = -1
	var best_near_d = INF # Distance to the operative, among trees within one hop
	var best_far = -1
	var best_far_d = INF # Distance from the Ghoul, among the rest
	for i in range(spots.size()):
		if i == hide_index:
			continue
		var d_prey = Vector2(prey_pos.x - spots[i].x, prey_pos.z - spots[i].z).length()
		if d_prey > my_d - HOP_MIN_GAIN:
			continue
		var d_me = global_position.distance_to(spots[i])
		if d_me <= HOP_MAX_DIST:
			if d_prey < best_near_d:
				best_near_d = d_prey
				best_near = i
		elif d_me < best_far_d:
			best_far_d = d_me
			best_far = i
	hop_index = best_near if best_near >= 0 else best_far
	if hop_index < 0:
		return false
	hop_target = spots[hop_index]
	return true

func _process_hopping(delta: float) -> void:
	hop_vy -= LEAP_GRAVITY * delta
	velocity = hop_dir * hop_speed + Vector3(0.0, hop_vy, 0.0)
	var before = global_position
	move_and_slide()
	var moved = global_position - before
	hop_traveled += Vector2(moved.x, moved.z).length()
	if hop_traveled >= hop_dist or (is_on_wall() and state_timer > 0.05) or state_timer >= HOP_TIMEOUT:
		velocity = Vector3.ZERO
		var landed_on_tree = Vector2(hop_target.x - global_position.x, hop_target.z - global_position.z).length() <= HIDE_ARRIVE_DIST * 2.0
		hide_index = hop_index if landed_on_tree else -1
		hide_spot = global_position
		range_timer = 0.0
		unwatched_timer = 0.0
		stare_timer = 0.0
		_set_state(GhoulState.HIDING)

# ----------------- PHASE 4: ENDLESS HUNT -----------------

func _start_hunt() -> void:
	range_timer = 0.0
	_set_state(GhoulState.HUNTING)

## Sprints at the nearest operative, crouches once close and leaps after the usual 2s lock
func _process_hunting(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var prey = _nearest_player_in_range(INF)
	if prey == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to_p = prey.global_position - global_position
	var flat_d = Vector2(to_p.x, to_p.z).length()
	rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), 10.0 * delta)
	if flat_d > ATTACK_RANGE:
		range_timer = 0.0
	else:
		range_timer += delta
		if range_timer >= (PHASE_4_LOCK_TIME if phase >= 4 else LOCK_TIME):
			_start_leap(prey.global_position)
			return
	var move_speed = 0.0 if flat_d <= HUNT_HOLD_DIST else HUNT_SPEED * slow_multiplier
	var dir = nav_direction_to(prey.global_position, delta)
	if dir != Vector3.ZERO and move_speed > 0.0:
		var move_dir = steer_around_cover(dir, delta)
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

## True if any standing operative has it inside their view cone with nothing blocking the sight line
func _is_being_watched() -> bool:
	var center = global_position + Vector3(0, 1.2, 0)
	var space = get_world_3d().direct_space_state
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.get("is_downed") == true or not p.has_method("get_look_direction"):
			continue
		var eye: Vector3 = p.get_eye_position()
		var to_me = center - eye
		var d = to_me.length()
		if d > VIEW_MAX_DIST or d < 0.01:
			continue
		if p.get_look_direction().dot(to_me / d) < VIEW_CONE_DOT:
			continue
		var query = PhysicsRayQueryParameters3D.create(eye, center, 1)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return true
	return false

# ----------------- LEAP / MISS -----------------

func _start_leap(locked_pos: Vector3) -> void:
	range_timer = 0.0
	_set_engaged(false) # The hunt paid off
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
	# Long Engage-mode leaps get the flight time they need
	if leap_traveled >= leap_dist or state_timer >= maxf(LEAP_TIMEOUT, leap_dist / LEAP_SPEED + 0.3):
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
			var flat = Vector3(global_position.x - p.global_position.x, 0.0, global_position.z - p.global_position.z)
			pin_dir = flat.normalized() if flat.length_squared() > 0.01 else -leap_dir
			pin_time = 0.0
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
	# Straddle the operative lying on their back, facing down at them
	var p_pos: Vector3 = pinned_player.global_position
	global_position = global_position.lerp(p_pos + pin_dir * PIN_STRADDLE_DIST, 20.0 * delta)
	rotation.y = atan2(pin_dir.x, pin_dir.z)
	velocity = Vector3.ZERO

	pin_time += delta
	pin_hit_timer -= delta
	if pin_hit_timer <= 0.0:
		pin_hit_timer += PIN_HIT_INTERVAL # Accumulate so the claw swipes stay in step with the hits
		_strike(PIN_HIT_DMG_MULT, true)

## Where a pinned operative's camera looks: the Ghoul's face looming over them
func get_pin_focus_point() -> Vector3:
	return head_mesh.global_position if head_mesh else global_position + Vector3(0.0, 1.4, 0.0)

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
	SoundManager.play("flesh_tear", 0.12, 0.0)
	# Strikes alternate left / right claw (matching _animate_arms); jolt the victim's view with the swing
	if victim.has_method("pin_strike_jolt"):
		victim.pin_strike_jolt(-1.0 if roundi(pin_time / PIN_HIT_INTERVAL) % 2 == 0 else 1.0)
	if lifesteal:
		current_health = minf(max_health, current_health + max_health * PIN_LIFESTEAL)
		GameManager.boss_health_updated.emit(current_health, max_health)
	if body_root:
		body_root.rotation.x = -PIN_LUNGE_LEAN
		var tw = create_tween()
		tw.tween_property(body_root, "rotation:x", -PIN_LEAN, 0.15)

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
	if phase >= 4:
		_start_hunt()
		return
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

func _collect_arm_joints() -> void:
	for side in ["L", "R"]:
		var pivot = body_root.get_node("ArmPivot" + side) as Node3D
		var elbow = pivot.get_node("Elbow" + side) as Node3D
		var hand = elbow.get_node("Hand" + side) as Node3D
		arm_pivots.append(pivot)
		arm_elbows.append(elbow)
		arm_hands.append(hand)
		var fingers: Array[Node3D] = []
		for child in hand.get_children():
			if child.name.begins_with("Finger") or child.name.begins_with("Thumb"):
				fingers.append(child)
		arm_fingers.append(fingers)

## Shoulder rotation that points the arm (rest axis -Y) along a world direction
func _arm_aim(pivot: Node3D, world_dir: Vector3) -> Quaternion:
	var local_dir = (pivot.get_parent().global_transform.basis.inverse() * world_dir).normalized()
	return Quaternion(Vector3.DOWN, local_dir)

func _animate_arms(delta: float) -> void:
	var pinning = state == GhoulState.PINNING and is_instance_valid(pinned_player)
	for i in range(arm_pivots.size()):
		var side = -1.0 if i == 0 else 1.0
		if pinning:
			_animate_claw_attack(i, side)
			continue
		# Free-roaming arm poses: x > 0 swings the arm forward
		var reach = 0.1
		var elbow_bend = 0.25
		var wrist = 0.1
		var curl = 0.2
		match state:
			GhoulState.HIDING:
				reach = 0.85 # Crouched, claws curled ready just above the ground
				elbow_bend = 1.3
				wrist = 0.6
				curl = 0.7
			GhoulState.LEAPING, GhoulState.OVERSHOOT:
				reach = 1.6 # Both claws thrust out ahead of the pounce
				elbow_bend = 0.1
				wrist = -0.4
				curl = -0.3
			GhoulState.FLEEING, GhoulState.HUNTING:
				reach = -0.3 + sin(anim_time * 18.0 + i * PI) * 0.7
				elbow_bend = 0.6
			GhoulState.HOPPING:
				reach = 1.1 # Claws reaching for the next tree
				elbow_bend = 0.5
				wrist = 0.2
				curl = 0.5
			GhoulState.FALLEN:
				reach = 0.3
				elbow_bend = 0.9
				curl = 0.8
			GhoulState.KNOCKDOWN:
				reach = -0.6
				elbow_bend = 1.0
				curl = 0.9
		var target = Quaternion.from_euler(Vector3(reach, 0.0, side * 0.2))
		arm_pivots[i].quaternion = arm_pivots[i].quaternion.slerp(target, 12.0 * delta)
		arm_elbows[i].rotation.x = lerpf(arm_elbows[i].rotation.x, elbow_bend, 12.0 * delta)
		arm_hands[i].rotation.x = lerpf(arm_hands[i].rotation.x, wrist, 12.0 * delta)
		for f in arm_fingers[i]:
			f.rotation.x = lerpf(f.rotation.x, curl, 12.0 * delta)

## Pinned victim: each hand cocks high and out to its own side (45 deg), then slashes diagonally in across the
## victim's face and rakes on through. Arms alternate, so one is scratching while the other winds up.
func _animate_claw_attack(i: int, side: float) -> void:
	var pivot = arm_pivots[i]
	var u = fmod(pin_time + i * PIN_HIT_INTERVAL, PIN_HIT_INTERVAL * 2.0)
	var rake_point = pinned_player.global_position + Vector3(0.0, PIN_RAKE_HEIGHT, 0.0)
	var outward = global_transform.basis.x * side
	var rake = _arm_aim(pivot, rake_point - pivot.global_position)
	# After connecting the claws keep raking across the face toward the other side
	var drag = _arm_aim(pivot, rake_point - outward * 0.45 + Vector3.DOWN * 0.25 - pivot.global_position)
	var raised = _arm_aim(pivot, Vector3.UP + outward + pin_dir * 0.15)
	var shoulder: Quaternion
	var elbow_bend: float
	var wrist: float
	var curl: float
	if u < CLAW_DRAG_END:
		var k = smoothstep(0.0, CLAW_DRAG_END, u)
		shoulder = rake.slerp(drag, k)
		elbow_bend = lerpf(0.15, 0.7, k)
		wrist = lerpf(0.4, 0.8, k)
		curl = lerpf(0.6, 1.1, k)
	elif u < CLAW_RAISE_END:
		var k = smoothstep(CLAW_DRAG_END, CLAW_RAISE_END, u)
		shoulder = drag.slerp(raised, k)
		elbow_bend = lerpf(0.7, 0.4, k)
		wrist = lerpf(0.8, -0.5, k)
		curl = lerpf(1.1, -0.35, k) # Fingers splay wide at the top
	else:
		var k = (u - CLAW_RAISE_END) / (PIN_HIT_INTERVAL * 2.0 - CLAW_RAISE_END)
		k *= k # Accelerates into the strike
		shoulder = raised.slerp(rake, k)
		elbow_bend = lerpf(0.4, 0.15, k)
		wrist = lerpf(-0.5, 0.4, k)
		curl = lerpf(-0.35, 0.6, k)
	pivot.quaternion = shoulder
	arm_elbows[i].rotation.x = elbow_bend
	arm_hands[i].rotation.x = wrist
	for f in arm_fingers[i]:
		f.rotation.x = curl

## Head aim, snarling jaw, and the eyes / fresh blood that wake once it leaves the shadows
func _animate_head(delta: float) -> void:
	var look_up = 0.35 # Counters the hunch so it glares ahead
	var jaw_open = 0.3
	match state:
		GhoulState.HIDING, GhoulState.HOPPING:
			look_up = 0.55
			jaw_open = 0.05
		GhoulState.LEAPING, GhoulState.OVERSHOOT:
			look_up = 0.9
			jaw_open = 0.65
		GhoulState.FLEEING:
			look_up = 0.6
			jaw_open = 0.3
		GhoulState.HUNTING:
			look_up = 0.7
			jaw_open = 0.55
		GhoulState.FALLEN:
			look_up = 0.0
			jaw_open = 0.4
		GhoulState.KNOCKDOWN:
			look_up = 0.3
			jaw_open = 0.5
		GhoulState.PINNING:
			look_up = -0.35 # Glares straight down into the victim's face
			# Snarls wider with every strike
			jaw_open = 0.35 + 0.35 * (1.0 - smoothstep(0.0, 0.15, fmod(pin_time, PIN_HIT_INTERVAL)))
	if head_mesh:
		head_mesh.rotation.x = lerpf(head_mesh.rotation.x, look_up, 10.0 * delta)
	if jaw:
		jaw.rotation.x = lerpf(jaw.rotation.x, -jaw_open, 18.0 * delta)
	var glow_target = 0.6
	if _is_lurking():
		glow_target = 0.0
	elif state == GhoulState.LEAPING or state == GhoulState.PINNING:
		glow_target = 1.0
	body_glow = lerpf(body_glow, glow_target, 6.0 * delta)
	# Engage mode: the eyes alone smoulder red in the dark, a tell you can spot from afar
	eye_engage = lerpf(eye_engage, 1.0 if engaged and _is_lurking() else 0.0, 4.0 * delta)
	if pupil_mat:
		pupil_mat.emission_energy_multiplier = maxf(EYE_GLOW * minf(body_glow * 2.0, 1.0), ENGAGED_EYE_GLOW * eye_engage)
	if skin_mat:
		skin_mat.set_shader_parameter("glow", body_glow)

func _animate_pose(delta: float) -> void:
	if not body_root:
		return
	var target_tilt = 0.3 # stooped
	var target_roll = 0.0
	var target_drop = 0.0
	var target_twist = 0.0
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
			# Left claw lands at 0, right half a cycle later: the torso swings into whichever arm is striking
			var c = -cos(pin_time * PI / PIN_HIT_INTERVAL)
			target_twist = PIN_TWIST * signf(c) * sqrt(absf(c))
		GhoulState.FLEEING, GhoulState.HUNTING:
			target_tilt = 0.95 + sin(anim_time * 18.0) * 0.08
		GhoulState.HOPPING:
			target_tilt = 1.0
			target_drop = -0.2
	body_root.rotation.z = lerpf(body_root.rotation.z, target_roll, 10.0 * delta)
	body_root.rotation.y = lerpf(body_root.rotation.y, target_twist, 18.0 * delta)
	body_root.position.y = lerpf(body_root.position.y, body_base_y + target_drop, 10.0 * delta)
	# Tilt > 0 leans toward the face (-Z), which is a negative X rotation
	if state != GhoulState.PINNING:
		body_root.rotation.x = lerpf(body_root.rotation.x, -target_tilt, 10.0 * delta)
	_animate_arms(delta)
	_animate_head(delta)
	_animate_claw_drips(delta)

## One blood drop per claw: it swells on the tip, then falls (onto a pinned victim's face). Hidden while it lurks.
func _setup_claw_drips() -> void:
	var claw = arm_hands[0].get_node_or_null("FingerL0/ClawL00") as MeshInstance3D
	if not claw:
		return
	var drop_mesh = SphereMesh.new()
	drop_mesh.radius = 0.011
	drop_mesh.height = 0.03
	drop_mesh.radial_segments = 6
	drop_mesh.rings = 3
	drop_mesh.material = claw.mesh.material # Wet blood
	for hand in arm_hands:
		for finger in hand.get_children():
			if not finger.name.begins_with("Finger"):
				continue
			var tip = finger.get_node_or_null("DripTip" + finger.name.trim_prefix("Finger")) as Node3D
			if not tip:
				continue
			var drop = MeshInstance3D.new()
			drop.mesh = drop_mesh
			drop.top_level = true
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			drop.visible = false
			add_child(drop)
			claw_drips.append({"tip": tip, "mesh": drop, "t": randf(), "hang": randf_range(0.25, 0.9), "vel": 0.0})

func _animate_claw_drips(delta: float) -> void:
	var dripping = not _is_lurking()
	for d in claw_drips:
		var drop: MeshInstance3D = d["mesh"]
		drop.visible = dripping
		if not dripping:
			continue
		d["t"] += delta
		if d["t"] < d["hang"]:
			var k: float = d["t"] / d["hang"]
			drop.global_position = (d["tip"] as Node3D).global_position + Vector3.DOWN * 0.012 * k
			drop.scale = Vector3.ONE * (0.3 + 0.7 * k)
			d["vel"] = 0.0
		else:
			d["vel"] += DRIP_GRAVITY * delta
			drop.global_position += Vector3.DOWN * float(d["vel"]) * delta
			drop.scale = Vector3(0.8, 1.5, 0.8)
			if drop.global_position.y < global_position.y + 0.02 or d["t"] > d["hang"] + 0.8:
				d["t"] = 0.0
				d["hang"] = randf_range(0.25, 0.9)

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
