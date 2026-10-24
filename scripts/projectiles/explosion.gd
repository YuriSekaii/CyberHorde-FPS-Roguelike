extends Area3D

var damage: float = 40.0
var radius: float = 4.0
var lifetime: float = 0.4
var timer: float = 0.0
var hit_targets: Array[Node] = []

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var particles: CPUParticles3D = $CPUParticles3D
@onready var light: OmniLight3D = $OmniLight3D

func setup(dmg: float, rad: float) -> void:
	damage = dmg
	radius = rad
	if not is_node_ready():
		await ready
	
	if collision_shape and collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = radius
	
	SoundManager.play("explosion", 0.1, 2.0)
	particles.emitting = true
	_deal_damage()

func _deal_damage() -> void:
	# Direct distance check on existing enemies ensures instant synchronous AoE damage
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is Node3D and is_instance_valid(enemy) and not enemy in hit_targets:
			if global_position.distance_to(enemy.global_position) <= radius:
				hit_targets.append(enemy)
				_damage_enemy(enemy)
	
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("enemies") and not b in hit_targets:
			hit_targets.append(b)
			_damage_enemy(b)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and not body in hit_targets:
		hit_targets.append(body)
		_damage_enemy(body)

func _damage_enemy(enemy: Node) -> void:
	if damage <= 0.0:
		return
	# Explosive damage is purely based on initial hit damage; no double-dip crit roll
	var final_dmg = damage
	if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
		enemy.rpc_take_damage.rpc(final_dmg, false, global_position)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(final_dmg, false, global_position)
	GameManager.record_damage(final_dmg, false)

func _process(delta: float) -> void:
	timer += delta
	if light:
		light.light_energy = maxf(0.0, 5.0 * (1.0 - (timer / lifetime)))
	if timer >= lifetime:
		queue_free()
