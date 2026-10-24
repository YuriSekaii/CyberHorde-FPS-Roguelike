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

# Dynamic bullet visual threshold tracking
static var active_bullets: Array[Node] = []
static var visible_bullets: Array[Node] = []
static var active_bullet_lights: int = 0
const MAX_BULLET_LIGHTS: int = 8
static var last_ricochet_sound_msec: int = 0

# Static pooled lightning beam instances (Zero heap allocation during combat)
static var beam_pool: Array[MeshInstance3D] = []
static var shared_beam_mesh: CylinderMesh = null
static var shared_beam_mat: StandardMaterial3D = null
const MAX_BEAM_POOL: int = 24

var is_visual: bool = true
var has_light: bool = false
var _has_registered: bool = false

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")

const ExplosionScript = preload("res://scripts/projectiles/explosion.gd")

func _ready() -> void:
	pierces_left = GameManager.pierce_count
	if GameManager.bouncing_bullets:
		bounces_left = GameManager.bounce_count
	_register_bullet()

func _exit_tree() -> void:
	_unregister_bullet()

func _register_bullet() -> void:
	if _has_registered:
		return
	_has_registered = true
	active_bullets.append(self)
	
	var max_visual = GameManager.max_visible_bullets
	if visible_bullets.size() < max_visual:
		set_visual(true)
		visible_bullets.append(self)
	else:
		# If number of bullets on screen > threshold, random bullets are set nonvisual to fit threshold.
		# Give freshly spawned shots a fair chance to be visible while demoting an existing visible bullet.
		var swap_chance: float = float(max_visual) / float(maxi(1, active_bullets.size()))
		if randf() < swap_chance and not visible_bullets.is_empty():
			var victim_idx = randi() % visible_bullets.size()
			var victim = visible_bullets[victim_idx]
			if is_instance_valid(victim) and victim.has_method("set_visual"):
				victim.set_visual(false)
			visible_bullets.remove_at(victim_idx)
			
			set_visual(true)
			visible_bullets.append(self)
		else:
			set_visual(false)

func _unregister_bullet() -> void:
	if _has_registered:
		_has_registered = false
		if has_light:
			has_light = false
			active_bullet_lights = maxi(0, active_bullet_lights - 1)
		active_bullets.erase(self)
		visible_bullets.erase(self)
		
		# If visible count fell below threshold, promote an existing non-visual bullet
		var max_visual = GameManager.max_visible_bullets
		if visible_bullets.size() < max_visual and active_bullets.size() > visible_bullets.size():
			for b in active_bullets:
				if is_instance_valid(b) and not b.is_visual:
					b.set_visual(true)
					visible_bullets.append(b)
					if visible_bullets.size() >= max_visual:
						break

func set_visual(state: bool) -> void:
	is_visual = state
	if mesh_instance:
		mesh_instance.visible = is_visual
	else:
		var m = get_node_or_null("MeshInstance3D")
		if m:
			m.visible = is_visual
	
	var light_target: OmniLight3D = omni_light if omni_light else get_node_or_null("OmniLight3D")
	if light_target:
		if is_visual and not has_light and active_bullet_lights < MAX_BULLET_LIGHTS:
			active_bullet_lights += 1
			has_light = true
			light_target.visible = true
		elif not is_visual and has_light:
			has_light = false
			active_bullet_lights = maxi(0, active_bullet_lights - 1)
			light_target.visible = false
		elif not is_visual:
			light_target.visible = false

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
			
			# Trigger on-hit effects for bounce
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
	
	# Audio throttling on ricochet
	var now = Time.get_ticks_msec()
	if now - last_ricochet_sound_msec >= 35:
		last_ricochet_sound_msec = now
		SoundManager.play("hitmarker", 0.25, 4.0)

func _find_smart_ricochet_target(from_pos: Vector3, forward_dir: Vector3, ignore_target: Node) -> Node3D:
	# Direct access to static cache: 0 heap allocations, 0 SceneTree queries
	var enemies = EnemyBase.all_enemies
	var best_target: Node3D = null
	var best_dist_sq: float = 28.0 * 28.0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy != ignore_target and not enemy in already_hit:
			var epos = enemy.global_position
			if absf(epos.x - from_pos.x) > 28.0 or absf(epos.z - from_pos.z) > 28.0:
				continue
			var d_sq = from_pos.distance_squared_to(epos)
			if d_sq < best_dist_sq:
				var dir_to = (epos - from_pos).normalized()
				if forward_dir.dot(dir_to) > -0.25:
					best_dist_sq = d_sq
					best_target = enemy
	return best_target

func _trigger_impact_effects(pos: Vector3, initial_hit_dmg: float) -> void:
	if is_explosive:
		var rad = GameManager.explosion_radius
		if is_plasma:
			rad = 5.0 * (2.0 if GameManager.explosive_rounds else 1.0)
		var aoe_dmg = initial_hit_dmg if is_plasma else (initial_hit_dmg * 0.8)
		var parent = get_parent()
		if parent:
			ExplosionScript.spawn_explosion(parent, pos, aoe_dmg, rad)

func _trigger_plasma_chain_lightning(hit_pos: Vector3, impact_dmg: float, direct_enemy: Node, is_direct_crit: bool) -> void:
	var explode_rad = 5.0 * (2.0 if GameManager.explosive_rounds else 1.0)
	var explode_rad_sq = explode_rad * explode_rad
	var chain_base_dmg = impact_dmg * 0.5
	
	var enemies = EnemyBase.all_enemies
	var primary_targets: Array[Dictionary] = []
	var hit_count: int = 0
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var epos = enemy.global_position
			if absf(epos.x - hit_pos.x) > explode_rad or absf(epos.z - hit_pos.z) > explode_rad:
				continue
			var d_sq = hit_pos.distance_squared_to(epos)
			if d_sq <= explode_rad_sq:
				var target_pos = epos + Vector3(0, 0.6, 0)
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
				if hit_count >= 10:
					break
	
	if hit_count > 0:
		SoundManager.play("hitmarker", 0.15, 6.0)
	
	# Direct hit damage
	if direct_enemy != null and is_instance_valid(direct_enemy) and not direct_enemy.is_dead:
		if direct_enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
			direct_enemy.rpc_take_damage.rpc(impact_dmg, is_direct_crit, global_position)
		elif direct_enemy.has_method("take_damage"):
			direct_enemy.take_damage(impact_dmg, is_direct_crit, global_position)
		GameManager.record_damage(impact_dmg, is_direct_crit)
		
		if GameManager.cryo_slow and direct_enemy.has_method("apply_slow"):
			direct_enemy.apply_slow(0.4, 3.0)
	
	# Detonate plasma explosion AoE damage
	_trigger_impact_effects(hit_pos, impact_dmg)
	
	# Outward secondary chain
	var secondary_hit_counts: Dictionary = {}
	var secondary_hits: int = 0
	var chain_rad_sq = 8.5 * 8.5
	
	for entry in primary_targets:
		if secondary_hits >= 6:
			break
		var from_pos: Vector3 = entry["pos"]
		var src_enemy: Node = entry["node"]
		
		var best_cand: Node3D = null
		var best_score: float = INF
		
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.is_dead and enemy.get("current_health") != null and enemy.get("current_health") > 0.0:
				if enemy == src_enemy:
					continue
				var epos = enemy.global_position
				if absf(epos.x - from_pos.x) > 8.5 or absf(epos.z - from_pos.z) > 8.5:
					continue
				var dist_sq = from_pos.distance_squared_to(epos)
				if dist_sq <= chain_rad_sq:
					var times_hit = secondary_hit_counts.get(enemy, 0)
					var score = float(times_hit) * 1000.0 + dist_sq
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
	var enemies = EnemyBase.all_enemies
	var hit_count = 0
	var range_sq = 8.5 * 8.5
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy != ignore_enemy:
			var epos = enemy.global_position
			if absf(epos.x - origin_pos.x) > 8.5 or absf(epos.z - origin_pos.z) > 8.5:
				continue
			var d_sq = origin_pos.distance_squared_to(epos)
			if d_sq < range_sq:
				var is_crit = randf() < crit_chance
				var final_dmg = chain_dmg * (GameManager.crit_damage if is_crit else 1.0)
				if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
					enemy.rpc_take_damage.rpc(final_dmg, is_crit, origin_pos)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(final_dmg, is_crit, origin_pos)
				GameManager.record_damage(final_dmg, is_crit)
				if GameManager.cryo_slow and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.3, 2.0)
				_create_lightning_beam(origin_pos, epos + Vector3(0, 0.6, 0))
				hit_count += 1
				if hit_count >= 2:
					break
	if hit_count > 0:
		SoundManager.play("hitmarker", 0.15, 6.0)

func _create_lightning_beam(start_pos: Vector3, end_pos: Vector3) -> void:
	var dist = start_pos.distance_to(end_pos)
	if dist < 0.2:
		return
	
	# Initialize shared static mesh & material once
	if shared_beam_mesh == null:
		shared_beam_mesh = CylinderMesh.new()
		shared_beam_mesh.top_radius = 0.04
		shared_beam_mesh.bottom_radius = 0.04
		shared_beam_mesh.height = 1.0 # unit height, scaled dynamically
		
		shared_beam_mat = StandardMaterial3D.new()
		shared_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_beam_mat.albedo_color = Color(0.3, 0.88, 1.0, 0.9)
		shared_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shared_beam_mesh.material = shared_beam_mat
	
	# Find available pooled beam instance
	var beam: MeshInstance3D = null
	for b in beam_pool:
		if is_instance_valid(b) and not b.visible:
			beam = b
			break
	
	if beam == null and beam_pool.size() < MAX_BEAM_POOL:
		beam = MeshInstance3D.new()
		beam.mesh = shared_beam_mesh
		beam.visible = false
		var root = get_tree().current_scene if get_tree() else get_parent()
		if root:
			root.add_child(beam)
			beam_pool.append(beam)
	
	if beam == null or not is_instance_valid(beam):
		return
	
	beam.global_position = (start_pos + end_pos) * 0.5
	var up_vec = Vector3.UP
	var dir = (end_pos - start_pos).normalized()
	if absf(dir.dot(up_vec)) > 0.98:
		up_vec = Vector3.RIGHT
	beam.look_at(end_pos, up_vec)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	beam.scale = Vector3(1.0, dist, 1.0)
	beam.visible = true
	
	# Auto-hide after 0.09s (recycled for next bolt)
	get_tree().create_timer(0.09).timeout.connect(func():
		if is_instance_valid(beam):
			beam.visible = false
	)
