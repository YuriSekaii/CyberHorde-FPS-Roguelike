extends "res://scripts/enemies/enemy_base.gd"

## Blood Ghoul - Stage 2 Wave 50 Final Boss (under the Red Moon).
## A pitch-black abyss beast splattered with its victims' blood that hunts from the shadows under the trees.
## Loop:
##   HIDE      Crouches in a tree's moon shadow (almost invisible). Waits until an operative is within 25m.
##   LOCK      After that operative stays within 25m for 2s it silently locks their position (no sound, no indicator), then leaps 0.1s later
##   LEAP      and jumps at it extremely fast. Touching an operative mid-jump pins them down.
##   PIN       Knocks the operative flat on their back and straddles them, raking with alternating claws every 0.3s
##             (medium damage, heals the Ghoul 1% Max HP per landed strike) while their camera stays locked looking
##             up at it, until they press alternating A / D 10 times to escape (holding or repeating one key doesn't count). Takes 90% less damage while pinning (stacks with the wave reduction). Then it's knocked down for 1s and flees REALLY
##             fast to a random tree to hide again.
##   MISS      If the jump misses, momentum drags it 5m past the locked spot and it falls: stunned for 5s (3s in phase 4), then flees.
##   BLOOD RAIN After a missed leap's stun ends it roars and pours blood from the sky over the whole arena: 5s in phase 1,
##              7s in phase 2, 10s in phase 3, ticking Corrupted Blood every second on every operative not standing in a
##              tree's moon shadow (canopies block it). From phase 4 the rain is permanent (infinite duration).
##   ENGAGE    After 10s total hiding with nobody in its 25m reach (the count only restarts after a leap), its eyes
##             glow red and it takes 90% less damage while hiding. Whenever no operative has looked at it for 2s
##             (staring pauses the count, 2s of staring resets it) it hops to another tree closer to the nearest
##             operative, then waits for another 2s unwatched. No closer tree left: it leaps straight at them from
##             any range. Leaping at someone ends Engage mode.
## Every Ghoul attack inflicts Bleed (1% Max HP/s, 5% while moving, +1.5s per hit and stacking, bypasses shield) and Corrupted Blood (2% Max HP/s drain, -75% healing, +2s per hit and stacking).
## While hiding it only takes direct bullet hits (like a Spawnling) and drones ignore it; after losing 1% Max HP
## while hidden it relocates to another random tree and drops Engage mode.
## Fleeing to a tree it's immune to all damage; knocked down or fallen after a miss it's fully vulnerable.
## Phases (by HP, never revert even if lifesteal heals it back). Each new phase it drops whatever it's doing
## (releasing a pin) and flees, immune, to a tree; in phase 4 it starts hunting from there.
##   1  > 2/3    As above.
##   2  > 1/3    Engages after 5s, hops after 1s unwatched, hops 50% faster.
##   3  > 10%    Permanently engaged; hops the instant nobody is looking at it.
##   4  <= 10%   Stops hiding: hunts the nearest operative endlessly, with 90% damage reduction while exposed. Locks on
##               the instant an operative is within 25m (then leaps 0.1s later); knockdown 1.5s, miss stun 3s. Immune to all damage while pinning.

enum GhoulState { HIDING, LEAPING, OVERSHOOT, FALLEN, PINNING, KNOCKDOWN, FLEEING, HOPPING, HUNTING }

const BOSS_MAX_HP: float = 1000000.0
const BOSS_DAMAGE: float = 200.0 # Fixed, no wave scaling
const ATTACK_RANGE: float = 25.0
const LOCK_TIME: float = 2.0
const LOCK_LEAP_DELAY: float = 0.1
const LEAP_SPEED: float = 42.0
const LEAP_GRAVITY: float = 40.0
const LEAP_PIN_RANGE: float = 2.375 # 1.9 * 1.25 (boss is 1.25x scale)
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
const PIN_DAMAGE_REDUCTION: float = 0.9 # While pinning (phases 1-3); multiplies with the wave reduction
const ENGAGED_EYE_GLOW: float = 4.0 # Visible from across the jungle, as bright as the full hunting blaze
const LURK_EYE_GLOW: float = 6.0 # Red eyes always burn in the shadows so players can spot and shoot it
const EYE_FLARE_SIZE: float = 0.36 # World size (m) of each eye's glow flare
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
const PHASE_4_FALL_STUN_TIME: float = 3.0
const PHASE_4_KNOCKDOWN_TIME: float = 1.5
const BLOOD_RAIN_DURATION_PHASE_1: float = 5.0
const BLOOD_RAIN_DURATION_PHASE_2: float = 7.0
const BLOOD_RAIN_DURATION_PHASE_3: float = 10.0
const BLOOD_RAIN_TICK: float = 0.5
const HUNT_SPEED: float = 24.0
const HUNT_HOLD_DIST: float = 12.0 # Closes to this range, then crouches for the lock
const VIEW_CONE_DOT: float = 0.8 # ~37 degrees off the look direction (same as the Mantis Stalker)
const VIEW_MAX_DIST: float = 70.0
const WATCH_CHECK_INTERVAL: float = 0.1
const GRAVITY: float = 20.0

## Anatomical joint limits (degrees), keyed by bone name prefix (.L/.R stripped;
## Finger1_1..Finger4_1 -> Finger_1, Finger1_2..Finger4_2 -> Finger_2).
## Each entry: [x_min, x_max, z_min, z_max, twist_min, twist_max] about local X/Z/Y.
const JOINT_LIMITS: Dictionary = {
	"Forearm": [-150.0, 5.0, -10.0, 10.0, -70.0, 70.0],
	"Hand": [-80.0, 70.0, -30.0, 30.0, -15.0, 15.0],
	"Finger_1": [-90.0, 20.0, -15.0, 15.0, -5.0, 5.0],
	"Finger_2": [-100.0, 5.0, -5.0, 5.0, -5.0, 5.0],
	"Thumb_1": [-60.0, 25.0, -30.0, 30.0, -20.0, 20.0],
	"Thumb_2": [-80.0, 10.0, -5.0, 5.0, -5.0, 5.0],
}

const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

var state: GhoulState = GhoulState.HIDING
var state_timer: float = 0.0
var hide_spot: Vector3 = Vector3.ZERO
var hide_index: int = -1
var range_timer: float = 0.0
var lock_delay: float = 0.0
var lock_pos: Vector3 = Vector3.ZERO
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
var blood_rain_timer: float = 0.0
var blood_rain_tick_timer: float = 0.0

@onready var body_root: Node3D = $MeshRoot/Body
@onready var head_mesh: Node3D = $MeshRoot/Body/Head
@onready var jaw: Node3D = $MeshRoot/Body/Head/Jaw
@onready var model: Node3D = $MeshRoot/Model # mesh_root comes from EnemyBase
@onready var pupil_mat: StandardMaterial3D = null # EyeL's active material (shared by both eyes)
@onready var skin_mat: ShaderMaterial = ($MeshRoot/Body/Ribcage as MeshInstance3D).mesh.material
var eye_flare_mat: StandardMaterial3D = null
var body_glow: float = 0.0 # 0 dormant in the shadows .. 1 fully awake

# ----------------- RIGGED MODEL RETARGET -----------------
var skeleton: Skeleton3D = null
var rest_d: Dictionary = {} # Driver Node3D -> MeshRoot-space basis at rest
var rest_local: Dictionary = {} # Driver Node3D -> local basis at rest
var rest_b: Dictionary = {} # Bone name -> skeleton-space global rest basis
var rest_align: Dictionary = {} # Bone name -> one-off arm rest alignment (UpperArm/Forearm only)
var bone_index: Dictionary = {} # Bone name -> skeleton index
var drivers: Dictionary = {} # Bone name -> driver Node3D
var second_drivers: Dictionary = {} # Second-joint bone name -> its first-joint driver Node3D
var model_body_mats: Array = [] # Per model body material: {"mat": StandardMaterial3D, "base": Color}
var leg_rest: Dictionary = {} # Side -> thigh/shin/foot rest data for the planted-feet IK

func _ready() -> void:
	enemy_name = "Blood Ghoul"
	super._ready()
	if body_root:
		body_base_y = body_root.position.y
	_collect_arm_joints()
	_setup_model()
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
	if state == GhoulState.PINNING:
		amount *= (1.0 - PIN_DAMAGE_REDUCTION)
	elif engaged and state == GhoulState.HIDING:
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

## Fleeing to a tree it can't be hurt at all; hidden in the shadows it can only be hurt by direct bullet hits
## (no AoE, ricochet or chain lightning); pinning in phase 4 makes it fully immune
func is_immune_to(damage_type: int) -> bool:
	if state == GhoulState.FLEEING:
		return true
	if state == GhoulState.PINNING and phase >= 4:
		return true
	return state == GhoulState.HIDING and damage_type != DAMAGE_TYPE_DIRECT and damage_type != DAMAGE_TYPE_WEAKPOINT

## In the shadows: hiding under a tree or hopping between trees
func _is_lurking() -> bool:
	return state == GhoulState.HIDING or state == GhoulState.HOPPING

func _behave(delta: float) -> void:
	state_timer += delta
	anim_time += delta
	_process_blood_rain(delta)
	if lock_delay > 0.0:
		lock_delay -= delta
		_hold_still(delta)
		if lock_delay <= 0.0:
			lock_delay = 0.0
			_launch_leap()
		_animate_pose(delta)
		return
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
				_start_blood_rain(_blood_rain_duration())
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

## Blood Rain: while the timer runs, every second every standing, non-downed player not under a tree canopy
## gets Corrupted Blood. INF timer = permanent (phase 4) and never turns the rain off.
func _process_blood_rain(delta: float) -> void:
	if blood_rain_timer <= 0.0:
		return
	var arena = _get_arena()
	if not is_inf(blood_rain_timer):
		blood_rain_timer = maxf(0.0, blood_rain_timer - delta)
		if blood_rain_timer <= 0.0:
			if arena:
				arena.set_blood_rain(false)
			return
	blood_rain_tick_timer -= delta
	if blood_rain_tick_timer > 0.0:
		return
	blood_rain_tick_timer = BLOOD_RAIN_TICK
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.get("is_downed") == true:
			continue
		if arena and arena.is_in_tree_shadow(p.global_position):
			continue
		if p.has_method("apply_corrupted_blood"):
			p.apply_corrupted_blood()

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
	if phase == 4:
		_start_blood_rain(INF) # Blood Rain is permanent from phase 4 on
	# Breaks off whatever it's doing (pin, knockdown, leap...) and retreats, immune, to a tree.
	# In phase 4 it starts hunting once it gets there.
	if is_instance_valid(pinned_player) and pinned_player.get("trap_source") == self:
		pinned_player.release_trap(false)
	_release_pin()
	_start_flee(true)

func _engage_idle_time() -> float:
	return ENGAGE_IDLE_TIME * (PHASE_2_TIME_MULT if phase >= 2 else 1.0)

func _hop_unwatched_time() -> float:
	if phase >= 3:
		return 0.0
	return HOP_UNWATCHED_TIME * (PHASE_2_TIME_MULT if phase >= 2 else 1.0)

func _set_state(new_state: GhoulState) -> void:
	var was_lurking = _is_lurking()
	lock_delay = 0.0
	state = new_state
	state_timer = 0.0
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

## Sprints at the nearest operative, crouches once close, then locks on instantly and leaps 0.1s later
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
	lock_pos = locked_pos
	lock_delay = LOCK_LEAP_DELAY

func _launch_leap() -> void:
	var flat = Vector3(lock_pos.x - global_position.x, 0.0, lock_pos.z - global_position.z)
	leap_dist = maxf(flat.length(), 0.5)
	leap_dir = flat.normalized() if flat.length_squared() > 0.001 else -global_transform.basis.z
	leap_traveled = 0.0
	# Low, flat arc that lands exactly on the locked spot
	var flight_time = leap_dist / LEAP_SPEED
	leap_vy = LEAP_GRAVITY * flight_time * 0.5 + (lock_pos.y - global_position.y) / maxf(flight_time, 0.05)
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

## Roar and start (or extend) Blood Rain: ticks immediately, runs for duration (INF = permanent, phase 4)
func _start_blood_rain(duration: float) -> void:
	SoundManager.play_pitch("charger_windup", 0.45, 0.0) # guttural roar
	blood_rain_timer = maxf(blood_rain_timer, duration)
	blood_rain_tick_timer = 0.0 # tick immediately
	var arena = _get_arena()
	if arena:
		arena.set_blood_rain(true)

## Blood Rain duration for the current phase; INF from phase 4
func _blood_rain_duration() -> float:
	match phase:
		1: return BLOOD_RAIN_DURATION_PHASE_1
		2: return BLOOD_RAIN_DURATION_PHASE_2
		3: return BLOOD_RAIN_DURATION_PHASE_3
		_: return INF

# ----------------- PIN -----------------

func _try_pin_nearby() -> bool:
	var chest = global_position + Vector3(0, 1.125, 0) # 0.9 * 1.25 (boss is 1.25x scale)
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
	if skeleton and bone_index.has("Head"): # The visible skull, not the hidden procedural head
		return skeleton.global_transform * skeleton.get_bone_global_pose(bone_index["Head"]).origin
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
	if victim.get("is_downed") != true and victim.has_method("apply_corrupted_blood"):
		victim.apply_corrupted_blood()
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

## to_tree: flee to a tree even in phase 4 (the phase change retreat), where it otherwise hunts straight away
func _start_flee(to_tree: bool = false) -> void:
	if phase >= 4 and not to_tree:
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
		_start_flee(true)
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

## Shortcut: the old procedural meshes stay in the scene as invisible drivers instead of being
## deleted, so every existing animation and gameplay path keeps working unchanged.
func _hide_procedural_meshes(node: Node) -> void:
	for child in node.get_children():
		if child == model:
			continue
		if child is MeshInstance3D:
			child.visible = false
		_hide_procedural_meshes(child)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _setup_model() -> void:
	if not model or not mesh_root:
		return
	_hide_procedural_meshes(mesh_root)
	skeleton = _find_skeleton(model)
	if skeleton == null:
		return
	# The old pupils were the glowing eyes; the rig's EyeL/EyeR now share this material.
	var eye = model.find_child("EyeL", true, false) as MeshInstance3D
	# The eyeballs sit deep in the skull and read as 1px from range: a billboard flare over each one
	eye_flare_mat = StandardMaterial3D.new()
	eye_flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eye_flare_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	eye_flare_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	eye_flare_mat.billboard_keep_scale = true
	eye_flare_mat.no_depth_test = false
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(0.5, 0.0)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(1, 0.6, 0.45, 1))
	grad.gradient.set_color(1, Color(1, 0, 0, 0))
	eye_flare_mat.albedo_texture = grad
	for eye_name in ["EyeL", "EyeR"]:
		var e = model.find_child(eye_name, true, false) as MeshInstance3D
		if e == null or e.mesh == null:
			continue
		var flare := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * EYE_FLARE_SIZE
		flare.mesh = quad
		flare.material_override = eye_flare_mat
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.add_child(flare)
		flare.position = e.mesh.get_aabb().get_center()
		flare.global_basis = Basis.IDENTITY # Size in world meters regardless of the rig's scale
	if eye and eye.mesh:
		pupil_mat = eye.get_active_material(0) as StandardMaterial3D
		if pupil_mat == null:
			pupil_mat = eye.mesh.surface_get_material(0) as StandardMaterial3D
	for body_name in ["BloodGhoul", "BloodGhoul_head"]:
		var mi = model.find_child(body_name, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat = mi.get_active_material(s)
			if not (mat is StandardMaterial3D):
				continue
			var known := false
			for entry in model_body_mats:
				if entry["mat"] == mat:
					known = true
					break
			if not known:
				model_body_mats.append({"mat": mat, "base": mat.albedo_color})
	_build_retarget()

func _model_basis(n: Node3D) -> Basis:
	return (mesh_root.global_transform.affine_inverse() * n.global_transform).basis.orthonormalized()

func _bone_rest_basis(bone: String) -> Basis:
	return rest_b[bone]

func _add_driver(bone: String, path: String) -> Node3D:
	if not bone_index.has(bone):
		return null
	var node = body_root.get_node_or_null(path) as Node3D
	if node == null:
		return null
	drivers[bone] = node
	if not rest_d.has(node):
		rest_d[node] = _model_basis(node)
		rest_local[node] = node.transform.basis
	return node

func _build_retarget() -> void:
	if skeleton == null or body_root == null or mesh_root == null:
		return
	rest_d.clear()
	rest_local.clear()
	rest_b.clear()
	rest_align.clear()
	bone_index.clear()
	drivers.clear()
	second_drivers.clear()
	leg_rest.clear()
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		bone_index[bone_name] = i
		rest_b[bone_name] = skeleton.get_bone_global_rest(i).basis
	# Record the driver rest poses from the upright skeleton, not the scene's hunched body pose.
	var saved := body_root.transform
	body_root.transform = Transform3D(Basis(), saved.origin)
	for side in ["L", "R"]:
		var arm = "ArmPivot" + side
		var hand = arm + "/Elbow" + side + "/Hand" + side
		_add_driver("UpperArm." + side, arm)
		_add_driver("Forearm." + side, arm + "/Elbow" + side)
		_add_driver("Hand." + side, hand)
		for n in range(1, 5):
			var finger_node = _add_driver("Finger%d_1.%s" % [n, side], hand + "/Finger" + side + str(n - 1))
			if finger_node:
				second_drivers["Finger%d_2.%s" % [n, side]] = finger_node
		var thumb_node = _add_driver("Thumb_1." + side, hand + "/Thumb" + side)
		if thumb_node:
			second_drivers["Thumb_2." + side] = thumb_node
	_add_driver("Head", "Head")
	_add_driver("Jaw", "Head/Jaw")
	body_root.transform = saved
	for side in ["L", "R"]:
		var u_bone: String = "UpperArm." + side
		var f_bone: String = "Forearm." + side
		var h_bone: String = "Hand." + side
		var u_driver: Node3D = drivers.get(u_bone, null)
		if u_driver != null and bone_index.has(u_bone) and bone_index.has(f_bone):
			var u_i: int = bone_index[u_bone]
			var f_i: int = bone_index[f_bone]
			var bone_dir: Vector3 = (skeleton.get_bone_global_rest(f_i).origin - skeleton.get_bone_global_rest(u_i).origin).normalized()
			var driver_down: Vector3 = -(rest_d.get(u_driver) as Basis).y
			rest_align[u_bone] = Basis(Quaternion(bone_dir, driver_down))
		var f_driver: Node3D = drivers.get(f_bone, null)
		if f_driver != null and bone_index.has(f_bone) and bone_index.has(h_bone):
			var f_i: int = bone_index[f_bone]
			var h_i: int = bone_index[h_bone]
			var bone_dir: Vector3 = (skeleton.get_bone_global_rest(h_i).origin - skeleton.get_bone_global_rest(f_i).origin).normalized()
			var driver_down: Vector3 = -(rest_d.get(f_driver) as Basis).y
			rest_align[f_bone] = Basis(Quaternion(bone_dir, driver_down))
		var align: Basis = rest_align.get(f_bone, Basis.IDENTITY)
		for hand_bone in [h_bone, "Finger1_1." + side, "Finger2_1." + side, "Finger3_1." + side, "Finger4_1." + side, "Finger1_2." + side, "Finger2_2." + side, "Finger3_2." + side, "Finger4_2." + side, "Thumb_1." + side, "Thumb_2." + side]:
			if bone_index.has(hand_bone):
				rest_align[hand_bone] = align
	for side in ["L", "R"]:
		var ti := int(bone_index.get("Thigh." + side, -1))
		var si := int(bone_index.get("Shin." + side, -1))
		var fi := int(bone_index.get("Foot." + side, -1))
		if ti < 0 or si < 0 or fi < 0:
			continue
		var thigh_rest := skeleton.get_bone_global_rest(ti)
		var shin_rest := skeleton.get_bone_global_rest(si)
		var foot_rest := skeleton.get_bone_global_rest(fi)
		leg_rest[side] = {
			"upper": (shin_rest.origin - thigh_rest.origin).length(),
			"lower": (foot_rest.origin - shin_rest.origin).length(),
			# Joint-to-joint directions: imported bone axes aren't guaranteed to run along the bone
			"thigh_dir": (shin_rest.origin - thigh_rest.origin).normalized(),
			"shin_dir": (foot_rest.origin - shin_rest.origin).normalized(),
			"foot_origin": foot_rest.origin,
			"foot_basis": rest_b["Foot." + side],
		}

## Strips the .L/.R suffix and maps FingerN_1/FingerN_2 to Finger_1/Finger_2.
func _limit_key(bone_name: String) -> String:
	var name: String = bone_name
	if name.ends_with(".L") or name.ends_with(".R"):
		name = name.substr(0, name.length() - 2)
	if name.begins_with("Finger") and name.ends_with("_1"):
		return "Finger_1"
	if name.begins_with("Finger") and name.ends_with("_2"):
		return "Finger_2"
	return name

## Clamps the pose-space rotation of bone_index to anatomical limits (swing about
## local X/Z, twist about local Y), relative to the bone's rest pose. Bones without
## a JOINT_LIMITS entry are returned unchanged.
func _limit_joint(bone_index: int, local_basis: Basis) -> Basis:
	var key: String = _limit_key(skeleton.get_bone_name(bone_index))
	if not JOINT_LIMITS.has(key):
		return local_basis
	var limits: Array = JOINT_LIMITS[key]
	var rest_rot: Quaternion = skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
	var rel: Quaternion = rest_rot.inverse() * local_basis.get_rotation_quaternion()
	if rel.w < 0.0: # Same rotation, shortest-path sign, so the swing angle stays under 180°
		rel = -rel
	var twist: Quaternion = Quaternion(0.0, rel.y, 0.0, rel.w).normalized()
	var swing: Quaternion = rel * twist.inverse()
	var swing_vec: Vector3 = swing.get_axis() * swing.get_angle()
	swing_vec.x = clampf(swing_vec.x, deg_to_rad(limits[0]), deg_to_rad(limits[1]))
	swing_vec.z = clampf(swing_vec.z, deg_to_rad(limits[2]), deg_to_rad(limits[3]))
	var swing_mag: float = swing_vec.length()
	var swing_clamped: Quaternion = Quaternion.IDENTITY
	if swing_mag > 0.0:
		swing_clamped = Quaternion(swing_vec / swing_mag, swing_mag)
	var twist_angle: float = 2.0 * atan2(twist.y, twist.w)
	if twist_angle > PI:
		twist_angle -= 2.0 * PI
	elif twist_angle < -PI:
		twist_angle += 2.0 * PI
	twist_angle = clampf(twist_angle, deg_to_rad(limits[4]), deg_to_rad(limits[5]))
	var twist_clamped: Quaternion = Quaternion(Vector3.UP, twist_angle)
	var scale: Vector3 = Vector3(local_basis.x.length(), local_basis.y.length(), local_basis.z.length())
	var result: Basis = Basis(rest_rot * swing_clamped * twist_clamped)
	if scale != Vector3.ONE:
		result = result.scaled(scale)
	return result

## Copies the invisible procedural joint poses onto the imported skeleton every frame.
func _retarget_skeleton() -> void:
	if skeleton == null or body_root == null or mesh_root == null:
		return
	var count := skeleton.get_bone_count()
	var global_pose: Array[Transform3D] = []
	global_pose.resize(count)
	var roll: float = body_root.rotation.z
	var roll_basis := Basis(Vector3(0.0, 0.0, 1.0), roll)
	var tilt := Basis.from_euler(Vector3(body_root.rotation.x, body_root.rotation.y, 0.0))
	var half := Basis(Quaternion.IDENTITY.slerp(tilt.get_rotation_quaternion(), 0.5))
	var drop: float = body_root.position.y - body_base_y
	var leg_w: float = 1.0 - clampf(absf(roll) / 1.2, 0.0, 1.0)
	var hips_i := int(bone_index.get("Hips", -1))
	var spine_i := int(bone_index.get("Spine", -1))
	var chest_i := int(bone_index.get("Chest", -1))
	var ik_shin_dir: Dictionary = {}
	for i in range(count):
		var bone := skeleton.get_bone_name(i)
		var local := skeleton.get_bone_rest(i)
		var parent_i := skeleton.get_bone_parent(i)
		var parent_global := Transform3D.IDENTITY if parent_i < 0 else global_pose[parent_i]
		var target_basis := Basis.IDENTITY
		var has_target := false
		if i == hips_i:
			# Body roll turns the hips; the torso gets the tilt/twist half on Spine and half on Chest.
			target_basis = roll_basis * _bone_rest_basis(bone)
			has_target = true
			local.origin += Vector3(0.0, drop, 0.0)
		elif i == spine_i:
			target_basis = roll_basis * half * _bone_rest_basis(bone)
			has_target = true
		elif i == chest_i:
			target_basis = roll_basis * half * half * _bone_rest_basis(bone)
			has_target = true
		elif drivers.has(bone):
			var node: Node3D = drivers[bone]
			var node_rest: Basis = rest_d[node]
			var delta := _model_basis(node) * node_rest.inverse()
			if bone == "Jaw": # The model's mouth already gapes at rest: open half as far as the old jaw
				var head_node := node.get_parent() as Node3D
				var half_open := Quaternion.IDENTITY.slerp((node.basis * (rest_local[node] as Basis).inverse()).get_rotation_quaternion(), 0.5)
				delta = _model_basis(head_node) * Basis(half_open) * (rest_d[head_node] as Basis).inverse()
			var align: Basis = rest_align.get(bone, Basis.IDENTITY)
			target_basis = delta * align * _bone_rest_basis(bone)
			has_target = true
		elif second_drivers.has(bone):
			var node: Node3D = second_drivers[bone]
			var node_rest: Basis = rest_d[node]
			var delta := _model_basis(node) * node_rest.inverse()
			var local_rest: Basis = rest_local[node]
			var local_delta := node.basis * local_rest.inverse()
			# Curl the second finger/thumb joint as much again as the first.
			var parent_now := _model_basis(node.get_parent() as Node3D)
			var extra := parent_now * local_delta * parent_now.inverse()
			var align: Basis = rest_align.get(bone, Basis.IDENTITY)
			target_basis = extra * delta * align * _bone_rest_basis(bone)
			has_target = true
		elif bone.begins_with("Thigh.") and leg_rest.has(bone.trim_prefix("Thigh.")):
			var side := bone.trim_prefix("Thigh.")
			var info: Dictionary = leg_rest[side]
			var thigh_origin := (parent_global * local).origin
			var foot_target: Vector3 = info["foot_origin"]
			var to_target := foot_target - thigh_origin
			var dist := to_target.length()
			if dist > 0.001:
				var upper: float = info["upper"]
				var lower: float = info["lower"]
				var dir := to_target / dist
				var pole := Vector3(0.0, 0.0, -1.0) # Knees bend forward (-Z), like the model's rest pose
				var pole_proj := pole - dir * pole.dot(dir)
				if pole_proj.length_squared() < 0.0001:
					pole_proj = Vector3.RIGHT - dir * dir.dot(Vector3.RIGHT)
				pole_proj = pole_proj.normalized()
				var reach := clampf(dist, absf(upper - lower) + 0.001, upper + lower - 0.001)
				var cos_a := clampf((upper * upper + reach * reach - lower * lower) / (2.0 * upper * reach), -1.0, 1.0)
				var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
				var knee := thigh_origin + dir * (upper * cos_a) + pole_proj * (upper * sin_a)
				var thigh_dir := (knee - thigh_origin).normalized()
				ik_shin_dir[side] = (foot_target - knee).normalized()
				var ik_basis := Basis(Quaternion(info["thigh_dir"], thigh_dir)) * _bone_rest_basis(bone)
				var default_basis := (parent_global * local).basis
				target_basis = Basis(default_basis.get_rotation_quaternion().slerp(ik_basis.get_rotation_quaternion(), leg_w))
				has_target = true
		elif bone.begins_with("Shin.") and ik_shin_dir.has(bone.trim_prefix("Shin.")):
			var side := bone.trim_prefix("Shin.")
			var info: Dictionary = leg_rest[side]
			var ik_basis := Basis(Quaternion(info["shin_dir"], ik_shin_dir[side])) * _bone_rest_basis(bone)
			var default_basis := (parent_global * local).basis
			target_basis = Basis(default_basis.get_rotation_quaternion().slerp(ik_basis.get_rotation_quaternion(), leg_w))
			has_target = true
		elif bone.begins_with("Foot.") and leg_rest.has(bone.trim_prefix("Foot.")):
			var side := bone.trim_prefix("Foot.")
			var info: Dictionary = leg_rest[side]
			var default_basis := (parent_global * local).basis
			var ik_basis: Basis = info["foot_basis"]
			target_basis = Basis(default_basis.get_rotation_quaternion().slerp(ik_basis.get_rotation_quaternion(), leg_w))
			has_target = true
		if has_target:
			local.basis = (parent_global.basis.inverse() * target_basis).orthonormalized()
			local.basis = _limit_joint(i, local.basis)
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		global_pose[i] = parent_global * skeleton.get_bone_pose(i)

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

## Shoulder rotation that points the arm (rest axis -Y) along a world direction, with the roll pinned
## so the elbow/wrist hinge (local X) stays near the body's left-right axis (shortest arc twisted it up to 120°)
## Unit dir with its component along unit axis capped at max_dot, keeping its direction around that axis
func _clamp_dir_component(dir: Vector3, axis: Vector3, max_dot: float) -> Vector3:
	var d: float = dir.dot(axis)
	if d <= max_dot:
		return dir
	var perp: Vector3 = dir - axis * d
	if perp.length_squared() < 0.000001:
		perp = Vector3.UP - axis * axis.dot(Vector3.UP)
	return axis * max_dot + perp.normalized() * sqrt(1.0 - max_dot * max_dot)

func _arm_aim(pivot: Node3D, world_dir: Vector3) -> Quaternion:
	var local_dir: Vector3 = (pivot.get_parent().global_transform.basis.inverse() * world_dir).normalized()
	# Shoulder range: at most ~25° behind the shoulder, ~45° across the chest past the other shoulder
	local_dir = _clamp_dir_component(local_dir, Vector3(0.0, 0.0, 1.0), 0.42)
	local_dir = _clamp_dir_component(local_dir, Vector3(-signf(pivot.position.x), 0.0, 0.0), 0.71)
	var y: Vector3 = -local_dir
	# Skewed off pure left-right so an arm reaching straight across the body doesn't hit the reference's flip point
	var ref := Vector3(1.0, 0.0, -0.6 * signf(pivot.position.x))
	var x: Vector3 = (ref - y * ref.dot(y)).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized().get_rotation_quaternion()

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
	var tb := body_root.global_transform.basis
	var raised = _arm_aim(pivot, tb.y + tb.x * side * 0.8 - tb.z * 0.25)
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
		pupil_mat.emission_energy_multiplier = maxf(maxf(EYE_GLOW * minf(body_glow * 2.0, 1.0), ENGAGED_EYE_GLOW * eye_engage), LURK_EYE_GLOW if _is_lurking() else 0.0)
		if eye_flare_mat:
			eye_flare_mat.albedo_color.a = clampf(pupil_mat.emission_energy_multiplier / EYE_GLOW, 0.0, 1.0)
	if skin_mat:
		skin_mat.set_shader_parameter("glow", body_glow)
	# Keep the rigged body nearly invisible in the shadows and fully lit once it wakes.
	var glow_scale := lerpf(0.3, 1.0, body_glow)
	for entry in model_body_mats:
		var mat: StandardMaterial3D = entry["mat"]
		var base: Color = entry["base"]
		mat.albedo_color = Color(base.r * glow_scale, base.g * glow_scale, base.b * glow_scale, base.a)

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
	_retarget_skeleton()

## One blood drop per claw: it swells on the tip, then falls (onto a pinned victim's face). Hidden while it lurks.
func _setup_claw_drips() -> void:
	var claw = arm_hands[0].get_node_or_null("FingerL0/ClawL00") as MeshInstance3D
	if not claw or skeleton == null:
		return
	var drop_mesh = SphereMesh.new()
	drop_mesh.radius = 0.011
	drop_mesh.height = 0.03
	drop_mesh.radial_segments = 6
	drop_mesh.rings = 3
	drop_mesh.material = claw.mesh.material # Wet blood
	# Drips hang off the rig's claw-tip bones now (arm_hands[0] is the .L hand).
	for i in range(2):
		var side := "L" if i == 0 else "R"
		for n in range(1, 5):
			var attach := BoneAttachment3D.new()
			attach.name = "DripTip%s%d" % [side, n - 1]
			skeleton.add_child(attach)
			attach.bone_name = "ClawTip%d.%s" % [n, side]
			var drop = MeshInstance3D.new()
			drop.mesh = drop_mesh
			drop.top_level = true
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			drop.visible = false
			add_child(drop)
			claw_drips.append({"tip": attach, "mesh": drop, "t": randf(), "hang": randf_range(0.25, 0.9), "vel": 0.0})

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
	var arena = _get_arena()
	if is_instance_valid(arena) and arena.has_method("set_blood_rain"):
		arena.set_blood_rain(false)
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

func _exit_tree() -> void:
	super._exit_tree()
	# Make sure the rain stops if the Ghoul leaves the tree for any reason
	var arena = _get_arena()
	if is_instance_valid(arena) and arena.has_method("set_blood_rain"):
		arena.set_blood_rain(false)
