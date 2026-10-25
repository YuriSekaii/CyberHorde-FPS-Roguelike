extends Area3D
class_name Explosion

var damage: float = 40.0
var radius: float = 4.0
var lifetime: float = 0.25
var timer: float = 0.0
var is_active: bool = false

static var active_explosion_lights: int = 0
const MAX_EXPLOSION_LIGHTS: int = 4
static var last_sound_msec: int = 0
var has_light: bool = false

# Static explosion pool for zero-allocation recycling
static var explosion_pool: Array[Node] = []
const MAX_EXPLOSION_POOL: int = 24
const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

@onready var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
@onready var light: OmniLight3D = get_node_or_null("OmniLight3D")

static func spawn_explosion(parent: Node, pos: Vector3, dmg: float, rad: float, attacker: Node = null) -> void:
	# Deal instant synchronous damage via static cache
	_deal_static_damage(pos, dmg, rad, attacker)
	
	# Find available pooled explosion visual
	var exp_inst: Node = null
	for e in explosion_pool:
		if is_instance_valid(e) and not e.is_active:
			exp_inst = e
			break
	
	if exp_inst == null and explosion_pool.size() < MAX_EXPLOSION_POOL and parent != null:
		exp_inst = EXPLOSION_SCENE.instantiate()
		parent.add_child(exp_inst)
		explosion_pool.append(exp_inst)
	
	if exp_inst != null and is_instance_valid(exp_inst):
		exp_inst.global_position = pos
		exp_inst.setup(dmg, rad)

func setup(dmg: float, rad: float) -> void:
	damage = dmg
	radius = rad
	timer = 0.0
	is_active = true
	visible = true
	
	if not is_node_ready():
		await ready
	
	# Audio throttling
	var now = Time.get_ticks_msec()
	if now - last_sound_msec >= 45:
		last_sound_msec = now
		SoundManager.play("explosion", 0.1, 2.0)
	
	# Light capping
	if light:
		if active_explosion_lights < MAX_EXPLOSION_LIGHTS:
			active_explosion_lights += 1
			has_light = true
			light.visible = true
			light.light_energy = 4.5
		else:
			has_light = false
			light.visible = false
	
	if particles:
		particles.restart()
		particles.emitting = true

func _exit_tree() -> void:
	if has_light:
		has_light = false
		active_explosion_lights = maxi(0, active_explosion_lights - 1)
	explosion_pool.erase(self)

static func _deal_static_damage(pos: Vector3, dmg: float, rad: float, attacker: Node = null) -> void:
	if dmg <= 0.0:
		return
	var rad_sq = rad * rad
	# Uses centralized static enemy list - 0 heap allocations, 0 SceneTree queries
	var enemies = EnemyBase.all_enemies
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var epos = enemy.global_position
		if absf(epos.x - pos.x) > rad or absf(epos.z - pos.z) > rad:
			continue
		if pos.distance_squared_to(epos) <= rad_sq:
			var is_immune = enemy.has_method("is_immune_to") and enemy.is_immune_to(EnemyBase.DAMAGE_TYPE_EXPLOSIVE)
			var is_from_rogue = (attacker != null and attacker.get("player_class") == "rogue")
			if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
				enemy.rpc_take_damage.rpc(dmg, false, pos, EnemyBase.DAMAGE_TYPE_EXPLOSIVE, is_from_rogue)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(dmg, false, pos, EnemyBase.DAMAGE_TYPE_EXPLOSIVE, attacker)
			if not is_immune:
				GameManager.record_damage(dmg, false)

func _process(delta: float) -> void:
	if not is_active:
		return
	timer += delta
	if has_light and light:
		light.light_energy = maxf(0.0, 4.5 * (1.0 - (timer / lifetime)))
	if timer >= lifetime:
		_deactivate()

func _deactivate() -> void:
	is_active = false
	visible = false
	if has_light:
		has_light = false
		active_explosion_lights = maxi(0, active_explosion_lights - 1)
	if light:
		light.visible = false
	if particles:
		particles.emitting = false
