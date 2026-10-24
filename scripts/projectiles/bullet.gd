extends Area3D

@export var speed: float = 70.0
@export var base_damage: float = 25.0
@export var is_explosive: bool = false
@export var is_plasma: bool = false

var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 2.5
var timer: float = 0.0
var pierces_left: int = 0
var bounces_left: int = 0
var already_hit: Array[Node] = []

const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

func _ready() -> void:
	pierces_left = GameManager.pierce_count
	if GameManager.bouncing_bullets:
		bounces_left = 2

func setup(dir: Vector3, dmg: float, explosive: bool = false) -> void:
	direction = dir.normalized()
	base_damage = dmg
	is_explosive = explosive or GameManager.explosive_rounds
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	
	var move_step = direction * speed * delta
	# Check raycast sweep for precise collision at high speed
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + move_step,
		collision_mask,
		[self]
	)
	var result = space_state.intersect_ray(query)
	if result:
		_handle_hit(result.collider, result.position, result.normal)
	else:
		global_position += move_step

func _handle_hit(collider: Object, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if collider in already_hit:
		return
	
	if collider is Node and collider.is_in_group("enemies"):
		already_hit.append(collider)
		var is_crit = randf() < GameManager.crit_chance
		var final_dmg = base_damage * GameManager.damage_mult
		if is_crit:
			final_dmg *= GameManager.crit_damage
		
		if collider.has_method("take_damage"):
			collider.take_damage(final_dmg, is_crit, global_position)
		
		GameManager.record_damage(final_dmg, is_crit)
		
		# Chain Lightning effect
		if GameManager.chain_lightning:
			_trigger_chain_lightning(collider, final_dmg * 0.5)
		
		# Cryo slow
		if GameManager.cryo_slow and collider.has_method("apply_slow"):
			collider.apply_slow(0.4, 3.0)
		
		_trigger_impact_effects(hit_pos)
		
		if pierces_left > 0:
			pierces_left -= 1
			# Continue through
			return
		else:
			queue_free()
			return
	else:
		# Hit environment / wall
		if bounces_left > 0 and hit_normal != Vector3.ZERO:
			bounces_left -= 1
			direction = direction.bounce(hit_normal).normalized()
			global_position = hit_pos + hit_normal * 0.1
			look_at(global_position + direction, Vector3.UP)
			SoundManager.play("hitmarker", 0.2, -6.0)
			return
		
		_trigger_impact_effects(hit_pos)
		queue_free()

func _trigger_impact_effects(pos: Vector3) -> void:
	if is_explosive:
		var exp_inst = EXPLOSION_SCENE.instantiate()
		get_parent().add_child(exp_inst)
		exp_inst.global_position = pos
		exp_inst.setup(base_damage * 0.8 * GameManager.damage_mult, GameManager.explosion_radius)

func _trigger_chain_lightning(origin_enemy: Node, chain_dmg: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if enemy != origin_enemy and enemy is Node3D:
			var d = origin_enemy.global_position.distance_to(enemy.global_position)
			if d < 7.5:
				if enemy.has_method("take_damage"):
					enemy.take_damage(chain_dmg, false, origin_enemy.global_position)
				hit_count += 1
				if hit_count >= 2:
					break
