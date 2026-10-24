extends Area3D

var damage: float = 40.0
var radius: float = 4.0
var lifetime: float = 0.25
var timer: float = 0.0

static var active_explosion_lights: int = 0
const MAX_EXPLOSION_LIGHTS: int = 4
static var last_sound_msec: int = 0
var has_light: bool = false

@onready var particles: CPUParticles3D = $CPUParticles3D
@onready var light: OmniLight3D = $OmniLight3D

func setup(dmg: float, rad: float) -> void:
	damage = dmg
	radius = rad
	if not is_node_ready():
		await ready
	
	# Audio throttling: prevent audio exhaustion when dozens of explosions occur in the same frame
	var now = Time.get_ticks_msec()
	if now - last_sound_msec >= 50:
		last_sound_msec = now
		SoundManager.play("explosion", 0.1, 2.0)
	
	# Light capping: limit concurrent OmniLights to preserve clustered Forward+ performance
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
		particles.emitting = true
	
	_deal_damage()

func _exit_tree() -> void:
	if has_light:
		has_light = false
		active_explosion_lights = maxi(0, active_explosion_lights - 1)

func _deal_damage() -> void:
	if damage <= 0.0:
		return
	
	# Instant single-pass synchronous AoE damage
	# Uses rapid AABB pre-filtering to eliminate 95% of enemies before distance_squared_to (no sqrt)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var rad_sq = radius * radius
	var my_pos = global_position
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		var epos = enemy.global_position
		if absf(epos.x - my_pos.x) > radius or absf(epos.z - my_pos.z) > radius:
			continue
		if my_pos.distance_squared_to(epos) <= rad_sq:
			_damage_enemy(enemy)

func _damage_enemy(enemy: Node) -> void:
	# Explosive damage is purely based on initial hit damage; no double-dip crit roll
	var final_dmg = damage
	if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
		enemy.rpc_take_damage.rpc(final_dmg, false, global_position)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(final_dmg, false, global_position)
	GameManager.record_damage(final_dmg, false)

func _process(delta: float) -> void:
	timer += delta
	if has_light and light:
		light.light_energy = maxf(0.0, 4.5 * (1.0 - (timer / lifetime)))
	if timer >= lifetime:
		queue_free()
