extends "res://scripts/enemies/enemy_base.gd"

## Spore Pit - Stage 2 mini-boss (Wave 31+). A huge rooted carnivorous pit-plant with enormous HP.
## Never moves. Every few seconds it fires a spore glob high into the sky that falls on an operative anywhere
## in the arena (global range): the 5m landing zone is marked for the whole flight, and the impact hits hard.
## Drops a Loot Cache when destroyed.

const FIRE_INTERVAL: float = 2.8
const FLIGHT_TIME: float = 2.2
const IMPACT_RADIUS: float = 5.0
const GRAVITY: float = 18.0

const SPORE_MORTAR_SCRIPT = preload("res://scripts/projectiles/spore_mortar.gd")
const CHEST_SCENE = preload("res://scenes/loot/chest.tscn")

var fire_timer: float = 2.0
var pulse_time: float = 0.0
var maw_punch: float = 0.0

@onready var maw_glow: MeshInstance3D = $MeshRoot/MawGlow
@onready var tendrils: Node3D = $MeshRoot/Tendrils

func _ready() -> void:
	super._ready()
	add_to_group("spore_pits")
	fire_timer = randf_range(1.5, 2.5)

func _behave(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = FIRE_INTERVAL / attack_speed_mult
		_launch_spore()
	_animate(delta)

func _launch_spore() -> void:
	var candidates: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("is_downed") != true:
			candidates.append(p)
	if candidates.is_empty():
		return
	var victim = candidates.pick_random()
	var target = victim.global_position
	target.y = 0.0
	var mortar = Node3D.new()
	mortar.set_script(SPORE_MORTAR_SCRIPT)
	get_parent().add_child(mortar)
	mortar.setup(global_position + Vector3(0, 4.2, 0), target, FLIGHT_TIME, IMPACT_RADIUS, attack_damage)
	maw_punch = 1.0
	SoundManager.play_pitch("explosion", 0.55, -6.0)

func _animate(delta: float) -> void:
	pulse_time += delta
	maw_punch = maxf(0.0, maw_punch - delta * 3.0)
	if maw_glow:
		var s = 1.0 + sin(pulse_time * 3.0) * 0.06 + maw_punch * 0.35
		maw_glow.scale = Vector3(s, 1.0, s)
	if tendrils:
		tendrils.rotation.y += delta * 0.25

func die() -> void:
	if is_dead:
		return
	var chest_pos = Vector3(clampf(global_position.x, -34.0, 34.0), 0.5, clampf(global_position.z, -34.0, 34.0))
	if NetworkManager.is_multiplayer:
		if NetworkManager.is_server:
			rpc_drop_chest.rpc(chest_pos)
	else:
		_drop_chest(chest_pos)
	super.die()

@rpc("call_local", "reliable")
func rpc_drop_chest(pos: Vector3) -> void:
	_drop_chest(pos)

func _drop_chest(pos: Vector3) -> void:
	var chest = CHEST_SCENE.instantiate()
	get_parent().call_deferred("add_child", chest)
	chest.position = pos
