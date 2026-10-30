extends "res://scripts/enemies/enemy_base.gd"

## Mantis Stalker - Stage 2 ambush predator (Wave 21+). Brown void-mantis with scythe arms.
## While any operative is looking at it (it's inside their view cone with a clear line of sight) it creeps slowly
## and strikes sluggishly. The moment nobody watches, it sprints extremely fast and slashes in rapid bursts.
## High damage, low HP, but heavily armored while nobody watches it.

const WATCHED_SPEED_RATIO: float = 0.1 # 10% of its sprint speed while watched
const UNWATCHED_DAMAGE_REDUCTION: float = 0.75 # Multiplies with the wave damage reduction
const WATCHED_ATTACK_RATE: float = 1.5
const UNWATCHED_ATTACK_RATE: float = 0.3
const ATTACK_RANGE: float = 2.3
const VIEW_CONE_DOT: float = 0.8 # ~37 degrees off the look direction
const VIEW_MAX_DIST: float = 70.0
const WATCH_CHECK_INTERVAL: float = 0.1
const GRAVITY: float = 18.0

var is_watched: bool = false
var watch_check_timer: float = 0.0
var attack_cooldown: float = 0.6
var anim_time: float = 0.0
var slash_timer: float = 0.0

@onready var left_scythe: Node3D = $MeshRoot/LeftScythe
@onready var right_scythe: Node3D = $MeshRoot/RightScythe

func _ready() -> void:
	super._ready()
	anim_time = randf() * TAU

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	attack_cooldown -= delta

	watch_check_timer -= delta
	if watch_check_timer <= 0.0:
		watch_check_timer = WATCH_CHECK_INTERVAL
		is_watched = _is_being_watched()

	var to_player = target_player.global_position - global_position
	var dir = nav_direction_to(target_player.global_position, delta)
	var move_speed = speed * slow_multiplier * (WATCHED_SPEED_RATIO if is_watched else 1.0)
	if to_player.length() <= ATTACK_RANGE * 0.8:
		move_speed = 0.0
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), (4.0 if is_watched else 16.0) * delta)
		var move_dir = steer_around_cover(dir, delta)
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	_animate(delta)

	if to_player.length() <= ATTACK_RANGE and absf(to_player.y) <= 2.0 and attack_cooldown <= 0.0:
		attack_cooldown = (WATCHED_ATTACK_RATE if is_watched else UNWATCHED_ATTACK_RATE) / attack_speed_mult
		if target_player.has_method("take_damage"):
			target_player.take_damage(attack_damage)
			SoundManager.play("player_hurt", 0.1, 0.5)
		_slash_anim()

func take_damage(amount: float, is_crit: bool, from_pos: Vector3, damage_type: int = DAMAGE_TYPE_DIRECT, killer_source: Variant = null) -> void:
	if not is_watched:
		amount *= (1.0 - UNWATCHED_DAMAGE_REDUCTION)
	super.take_damage(amount, is_crit, from_pos, damage_type, killer_source)

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
		if space.intersect_ray(query).is_empty():
			return true
	return false

func _animate(delta: float) -> void:
	# Frozen, twitching pose while watched; scythes raised and swaying while hunting
	anim_time += delta * (1.5 if is_watched else 9.0)
	if slash_timer > 0.0:
		slash_timer -= delta
		return
	var sway = sin(anim_time) * (0.05 if is_watched else 0.3)
	if left_scythe:
		left_scythe.rotation.x = lerpf(left_scythe.rotation.x, -0.6 + sway, 10.0 * delta)
	if right_scythe:
		right_scythe.rotation.x = lerpf(right_scythe.rotation.x, -0.6 - sway, 10.0 * delta)

func _slash_anim() -> void:
	slash_timer = 0.12
	for s in [left_scythe, right_scythe]:
		if s:
			s.rotation.x = -1.6
			var tw = create_tween()
			tw.tween_property(s, "rotation:x", 0.5, 0.08)
