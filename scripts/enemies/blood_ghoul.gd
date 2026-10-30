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
## Every Ghoul attack inflicts Bleed (1% Max HP/s, 5% while moving, +1.5s per hit and stacking, bypasses shield).
## While hiding it only takes direct bullet hits (like a Spawnling) and drones ignore it; after losing 1% Max HP
## while hidden it relocates to another random tree.

enum GhoulState { HIDING, LEAPING, OVERSHOOT, FALLEN, PINNING, KNOCKDOWN, FLEEING }

const BOSS_MAX_HP: float = 2000000.0
const BASE_DAMAGE: float = 50.0
const MAX_DAMAGE: float = 250.0
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
	# Fixed HP and cadence like the Apex Overlord; damage scales with the wave curve (capped)
	max_health = BOSS_MAX_HP
	current_health = max_health
	attack_damage = clampf(BASE_DAMAGE * GameManager.get_wave_damage_factor(), BASE_DAMAGE, MAX_DAMAGE)
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
			GhoulState.FLEEING:
				reach = -0.3 + sin(anim_time * 18.0 + i * PI) * 0.7
				elbow_bend = 0.6
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
		GhoulState.HIDING:
			look_up = 0.55
			jaw_open = 0.05
		GhoulState.LEAPING, GhoulState.OVERSHOOT:
			look_up = 0.9
			jaw_open = 0.65
		GhoulState.FLEEING:
			look_up = 0.6
			jaw_open = 0.3
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
	if state == GhoulState.HIDING:
		glow_target = 0.0
	elif state == GhoulState.LEAPING or state == GhoulState.PINNING:
		glow_target = 1.0
	body_glow = lerpf(body_glow, glow_target, 6.0 * delta)
	if pupil_mat:
		pupil_mat.emission_energy_multiplier = EYE_GLOW * minf(body_glow * 2.0, 1.0)
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
		GhoulState.FLEEING:
			target_tilt = 0.95 + sin(anim_time * 18.0) * 0.08
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
	var dripping = state != GhoulState.HIDING
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
