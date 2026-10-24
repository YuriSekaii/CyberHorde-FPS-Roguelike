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
var crit_chance: float = 0.10

const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

func _ready() -> void:
	pierces_left = GameManager.pierce_count
	if GameManager.bouncing_bullets:
		bounces_left = GameManager.bounce_count

func setup(dir: Vector3, dmg: float, explosive: bool = false, from_plasma: bool = false, base_crit: float = 0.10) -> void:
	direction = dir.normalized()
	base_damage = dmg
	is_explosive = explosive or GameManager.explosive_rounds
	is_plasma = from_plasma
	crit_chance = base_crit + (GameManager.crit_chance - 0.10)
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
		var is_crit = randf() < crit_chance
		var final_dmg = base_damage * GameManager.damage_mult
		if is_crit:
			final_dmg *= GameManager.crit_damage
		
		# Slot 3 (Plasma Core) exclusive chain lightning behavior
		if is_plasma and GameManager.chain_lightning:
			_trigger_plasma_chain_lightning(hit_pos, final_dmg, collider, is_crit)
		else:
			if collider.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
				collider.rpc_take_damage.rpc(final_dmg, is_crit, global_position)
			elif collider.has_method("take_damage"):
				collider.take_damage(final_dmg, is_crit, global_position)
			
			GameManager.record_damage(final_dmg, is_crit)
			
			# Standard Chain Lightning effect on enemy hit
			if GameManager.chain_lightning:
				_trigger_chain_lightning_at_pos(hit_pos, final_dmg * 0.5, collider)
			
			# Cryo slow
			if GameManager.cryo_slow and collider.has_method("apply_slow"):
				collider.apply_slow(0.4, 3.0)
			
			# Explosion on hit (purely based on initial hit damage)
			_trigger_impact_effects(hit_pos, final_dmg)
		
		if pierces_left > 0:
			pierces_left -= 1
			# Continue piercing through
			return
		elif bounces_left > 0:
			# Ricochet off enemy toward next enemy
			bounces_left -= 1
			_ricochet_from(hit_pos, -direction, collider)
			return
		else:
			queue_free()
			return
	else:
		# Hit environment / wall / floor
		var wall_hit_dmg = base_damage * GameManager.damage_mult
		if bounces_left > 0 and hit_normal != Vector3.ZERO:
			bounces_left -= 1
			
			# Trigger all on-hit effects for each bounce!
			if is_plasma and GameManager.chain_lightning:
				_trigger_plasma_chain_lightning(hit_pos, wall_hit_dmg, null, false)
			else:
				_trigger_impact_effects(hit_pos, wall_hit_dmg)
				if GameManager.chain_lightning:
					_trigger_chain_lightning_at_pos(hit_pos, wall_hit_dmg * 0.5, null)
			
			_ricochet_from(hit_pos, hit_normal, null)
			return
		
		if is_plasma and GameManager.chain_lightning:
			_trigger_plasma_chain_lightning(hit_pos, wall_hit_dmg, null, false)
		else:
			_trigger_impact_effects(hit_pos, wall_hit_dmg)
		queue_free()

func _ricochet_from(pos: Vector3, surface_normal: Vector3, ignore_target: Node) -> void:
	var bounce_dir = direction.bounce(surface_normal).normalized()
	if bounce_dir == Vector3.ZERO:
		bounce_dir = surface_normal
	
	# Smart homing: seek nearest enemy within range and field of view
	var best_enemy = _find_smart_ricochet_target(pos, bounce_dir, ignore_target)
	if best_enemy:
		var to_enemy = (best_enemy.global_position + Vector3(0, 0.7, 0) - pos).normalized()
		# Blend physical bounce with target direction for natural smart ricochet
		direction = bounce_dir.lerp(to_enemy, 0.75).normalized()
	else:
		direction = bounce_dir
	
	global_position = pos + surface_normal * 0.15
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)
	SoundManager.play("hitmarker", 0.25, 4.0)

func _find_smart_ricochet_target(from_pos: Vector3, forward_dir: Vector3, ignore_target: Node) -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_dist: float = 28.0
	for enemy in enemies:
		if enemy is Node3D and is_instance_valid(enemy) and enemy != ignore_target and not enemy in already_hit:
			var d = from_pos.distance_to(enemy.global_position)
			if d < best_dist:
				var dir_to = (enemy.global_position - from_pos).normalized()
				if forward_dir.dot(dir_to) > -0.25:
					best_dist = d
					best_target = enemy
	return best_target

func _trigger_impact_effects(pos: Vector3, initial_hit_dmg: float) -> void:
	if is_explosive:
		var exp_inst = EXPLOSION_SCENE.instantiate()
		get_parent().add_child(exp_inst)
		exp_inst.global_position = pos
		var rad = GameManager.explosion_radius
		if is_plasma:
			# Base Plasma AoE is 5.0m. If Explosive Payload perk is picked, get +100% more radius (10.0m)!
			rad = 5.0 * (2.0 if GameManager.explosive_rounds else 1.0)
		# Explosive damage: Plasma deals 100% AoE (150 base direct, 150 base AoE), others deal 80% AoE
		var aoe_dmg = initial_hit_dmg if is_plasma else (initial_hit_dmg * 0.8)
		exp_inst.setup(aoe_dmg, rad)

func _trigger_plasma_chain_lightning(hit_pos: Vector3, impact_dmg: float, direct_enemy: Node, is_direct_crit: bool) -> void:
	# Slot 3 (Plasma Core) exclusive sequence:
	# 1. Explode radius is 5.0m base (10.0m if Explosive Payload perk is picked)
	var explode_rad = 5.0 * (2.0 if GameManager.explosive_rounds else 1.0)
	var chain_base_dmg = impact_dmg * 0.5
	
	# Step 1: Shoot 1 lightning bolt to EVERY alive enemy in the explosive range BEFORE AoE damage
	var enemies = get_tree().get_nodes_in_group("enemies")
	var primary_targets: Array[Dictionary] = []
	var hit_count: int = 0
	
	for enemy in enemies:
		if enemy is Node3D and is_instance_valid(enemy) and not enemy.get("is_dead"):
			var d = hit_pos.distance_to(enemy.global_position)
			if d <= explode_rad:
				var target_pos = enemy.global_position + Vector3(0, 0.6, 0)
				primary_targets.append({ "node": enemy, "pos": target_pos })
				
				_create_lightning_beam(hit_pos, target_pos)
				
				var is_crit = randf() < crit_chance
				var bolt_dmg = chain_base_dmg * (GameManager.crit_damage if is_crit else 1.0)
				if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
					enemy.rpc_take_damage.rpc(bolt_dmg, is_crit, hit_pos)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(bolt_dmg, is_crit, hit_pos)
				GameManager.record_damage(bolt_dmg, is_crit)
				
				if GameManager.cryo_slow and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.3, 2.0)
				
				hit_count += 1
	
	if hit_count > 0:
		SoundManager.play("hitmarker", 0.15, 6.0)
	
	# Step 2: Deal direct hit damage on collider (if direct enemy hit) AND AoE Plasma Explosion damage
	if direct_enemy != null and is_instance_valid(direct_enemy) and not direct_enemy.get("is_dead"):
		if direct_enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
			direct_enemy.rpc_take_damage.rpc(impact_dmg, is_direct_crit, global_position)
		elif direct_enemy.has_method("take_damage"):
			direct_enemy.take_damage(impact_dmg, is_direct_crit, global_position)
		GameManager.record_damage(impact_dmg, is_direct_crit)
		
		if GameManager.cryo_slow and direct_enemy.has_method("apply_slow"):
			direct_enemy.apply_slow(0.4, 3.0)
	
	# Detonate plasma explosion AoE damage
	_trigger_impact_effects(hit_pos, impact_dmg)
	
	# Step 3: Lightning chains to alive enemy within 8.5m of each primary struck target
	var secondary_hit_counts: Dictionary = {}
	var secondary_hits: int = 0
	
	for entry in primary_targets:
		var from_pos: Vector3 = entry["pos"]
		var src_enemy: Node = entry["node"]
		
		var best_cand: Node3D = null
		var best_score: float = INF
		
		for enemy in enemies:
			if enemy is Node3D and is_instance_valid(enemy) and not enemy.get("is_dead") and enemy.get("current_health") != null and enemy.get("current_health") > 0.0:
				if enemy == src_enemy:
					continue
				var dist = from_pos.distance_to(enemy.global_position)
				if dist <= 8.5:
					var times_hit = secondary_hit_counts.get(enemy, 0)
					var score = float(times_hit) * 1000.0 + dist
					if score < best_score:
						best_score = score
						best_cand = enemy
		
		if best_cand != null:
			secondary_hit_counts[best_cand] = secondary_hit_counts.get(best_cand, 0) + 1
			var cand_pos = best_cand.global_position + Vector3(0, 0.6, 0)
			_create_lightning_beam(from_pos, cand_pos)
			
			var chain_is_crit = randf() < crit_chance
			var chain_dmg = chain_base_dmg * (GameManager.crit_damage if chain_is_crit else 1.0)
			if best_cand.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
				best_cand.rpc_take_damage.rpc(chain_dmg, chain_is_crit, from_pos)
			elif best_cand.has_method("take_damage"):
				best_cand.take_damage(chain_dmg, chain_is_crit, from_pos)
			GameManager.record_damage(chain_dmg, chain_is_crit)
			
			if GameManager.cryo_slow and best_cand.has_method("apply_slow"):
				best_cand.apply_slow(0.3, 2.0)
			
			secondary_hits += 1
	
	if secondary_hits > 0 and hit_count == 0:
		SoundManager.play("hitmarker", 0.15, 6.0)

func _trigger_chain_lightning_at_pos(origin_pos: Vector3, chain_dmg: float, ignore_enemy: Node) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if enemy is Node3D and is_instance_valid(enemy) and enemy != ignore_enemy:
			var d = origin_pos.distance_to(enemy.global_position)
			if d < 8.5:
				var is_crit = randf() < crit_chance
				var final_dmg = chain_dmg * (GameManager.crit_damage if is_crit else 1.0)
				if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
					enemy.rpc_take_damage.rpc(final_dmg, is_crit, origin_pos)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(final_dmg, is_crit, origin_pos)
				GameManager.record_damage(final_dmg, is_crit)
				if GameManager.cryo_slow and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.3, 2.0)
				_create_lightning_beam(origin_pos, enemy.global_position + Vector3(0, 0.6, 0))
				hit_count += 1
				if hit_count >= 2:
					break
	if hit_count > 0:
		SoundManager.play("hitmarker", 0.15, 6.0)

func _create_lightning_beam(start_pos: Vector3, end_pos: Vector3) -> void:
	var dist = start_pos.distance_to(end_pos)
	if dist < 0.2:
		return
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = dist
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.88, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyl.material = mat
	beam.mesh = cyl
	get_parent().add_child(beam)
	beam.global_position = (start_pos + end_pos) * 0.5
	var up_vec = Vector3.UP
	var dir = (end_pos - start_pos).normalized()
	if absf(dir.dot(up_vec)) > 0.98:
		up_vec = Vector3.RIGHT
	beam.look_at(end_pos, up_vec)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	var tw = beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(beam.queue_free)
