extends "res://scripts/enemies/enemy_base.gd"

## Bog Slime - Stage 2 tank (Wave 11+). Very high HP, slow.
## Touching an operative engulfs them for 3s: they can't move and take 10 dmg/s (scaled by the wave damage factor)
## while other enemies and projectiles keep hitting them. Mashing A / D shaves 0.5s off the trap per press.
## After escaping, the operative can't be trapped again for 3s.

const TOUCH_RANGE: float = 1.6
const TRAP_DURATION: float = 3.0
const TRAP_BASE_DPS: float = 10.0
const RECOIL_TIME: float = 1.2 # pauses after losing its prey so the operative can walk away
const GRAVITY: float = 18.0

var engulfed_player: Node = null
var recoil_timer: float = 0.0
var wobble_time: float = 0.0

func _ready() -> void:
	super._ready()
	wobble_time = randf() * TAU

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	wobble_time += delta

	if engulfed_player != null:
		if is_instance_valid(engulfed_player) and engulfed_player.get("trap_source") == self:
			# Sit on the trapped operative
			var hold = engulfed_player.global_position
			global_position.x = lerpf(global_position.x, hold.x, 14.0 * delta)
			global_position.z = lerpf(global_position.z, hold.z, 14.0 * delta)
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			_animate(delta, 1.75, 7.0)
			return
		_release_hold()

	if recoil_timer > 0.0:
		recoil_timer -= delta
		velocity.x = lerpf(velocity.x, 0.0, 4.0 * delta)
		velocity.z = lerpf(velocity.z, 0.0, 4.0 * delta)
		move_and_slide()
		_animate(delta, 1.0, 2.0)
		return

	var to_player = target_player.global_position - global_position
	var dir = nav_direction_to(target_player.global_position, delta)
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
		var move_dir = steer_around_cover(dir, delta)
		var effective_speed = speed * slow_multiplier
		velocity.x = move_dir.x * effective_speed
		velocity.z = move_dir.z * effective_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	_animate(delta, 1.0, 3.5)

	if to_player.length() <= TOUCH_RANGE and absf(to_player.y) <= 1.8 and target_player.has_method("apply_trap"):
		if target_player.apply_trap(self, TRAP_DURATION, TRAP_BASE_DPS * GameManager.get_wave_damage_factor()):
			engulfed_player = target_player
			add_collision_exception_with(engulfed_player)
			engulfed_player.add_collision_exception_with(self)
			SoundManager.play_pitch("spawnling_drill", 0.45, -4.0)

## Called by the player when the trap ends (escaped by mashing / timer, or cancelled)
func on_trap_released(player: Node, _escaped: bool) -> void:
	if player == engulfed_player:
		_release_hold()
		recoil_timer = RECOIL_TIME
		# Spit the operative out: hop back
		var away = global_position - player.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		velocity = away.normalized() * 6.0 + Vector3(0, 4.0, 0)

func _release_hold() -> void:
	if is_instance_valid(engulfed_player):
		remove_collision_exception_with(engulfed_player)
		engulfed_player.remove_collision_exception_with(self)
	engulfed_player = null

func _animate(_delta: float, size: float, wobble_speed: float) -> void:
	if not mesh_root or _is_flashing:
		return
	var w = sin(wobble_time * wobble_speed) * 0.08
	var target = Vector3(size * (1.0 + w), size * (1.0 - w), size * (1.0 + w))
	mesh_root.scale = mesh_root.scale.lerp(target, 0.2)

func die() -> void:
	if is_dead:
		return
	if is_instance_valid(engulfed_player) and engulfed_player.get("trap_source") == self:
		engulfed_player.release_trap(false)
	_release_hold()
	super.die()
