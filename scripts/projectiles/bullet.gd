extends Node3D

const BASE_BULLET_SPEED: float = 70.0
const PLASMA_SPEED: float = BASE_BULLET_SPEED / 3.0 # ~23.33 m/s (1/3 of standard bullet speed)
const PLASMA_HITBOX_RADIUS: float = 0.75 # Generous hitbox radius for plasma orb

@export var speed: float = BASE_BULLET_SPEED
@export var base_damage: float = 25.0
@export var is_explosive: bool = false
@export var is_plasma: bool = false
@export var collision_mask: int = 3 # Layer 1 world + Layer 2 enemies (bullets are plain Node3Ds swept by raycasts)

var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 2.5
var timer: float = 0.0
var pierces_left: int = 0
var bounces_left: int = 0
var already_hit: Array[Node] = []
var crit_chance: float = 0.10
var is_ricochet: bool = false
var shooter: Node = null
var sim_pos: Vector3 = Vector3.ZERO # Simulated position; the node itself only moves while the bullet is drawn
var _space: PhysicsDirectSpaceState3D = null
var _hit_rids: Array[RID] = [] # Pierced enemies, excluded from the sweep so the bullet travels on through them

# Dynamic bullet visual threshold tracking
static var active_bullets: Array[Node] = []
static var visible_bullets: Array[Node] = []
static var active_bullet_lights: int = 0
const MAX_BULLET_LIGHTS: int = 8
static var last_ricochet_sound_msec: int = 0
static var last_chain_sound_msec: int = 0

# Static bullet pool: spent bullets park hidden in the scene and are reused (no per-pellet instantiate/free)
static var bullet_pool: Array[Node] = []
const MAX_BULLET_POOL: int = 512
var _in_pool: bool = false

# One shared raycast query for every bullet sweep (no per-tick allocation)
static var _ray_query: PhysicsRayQueryParameters3D = null
static var _ray_query_has_exclude: bool = false

# Bullets leaving the 80x80 arena (or flying above its 48m ceiling) can't hit anything, so they're recycled early
const ARENA_CULL_EXTENT: float = 42.0
const ARENA_CULL_CEILING: float = 50.0

# Simulation budget: once this many bullets are alive, multi-pellet volleys merge into fewer, heavier pellets
const BULLET_SIM_BUDGET: int = 400

## How many pellets a volley of `count` should actually spawn: all of them under budget, otherwise 1/2, 1/3, ...
## as the live count passes 1x, 2x, ... the budget. Callers scale per-pellet damage by count / result.
static func budget_pellets(count: int) -> int:
	var merge = 1 + int(active_bullets.size() / BULLET_SIM_BUDGET)
	if count <= 1 or merge <= 1:
		return count
	return maxi(1, ceili(float(count) / float(merge)))

# Static pooled lightning beam instances (Zero heap allocation during combat)
static var beam_pool: Array[MeshInstance3D] = []
static var shared_beam_mesh: CylinderMesh = null
static var shared_beam_mat: StandardMaterial3D = null
const MAX_BEAM_POOL: int = 48

# Static shared resources for plasma projectiles (Zero heap allocations per shot)
static var plasma_outer_mesh: SphereMesh = null
static var plasma_outer_mat: StandardMaterial3D = null
static var plasma_core_mesh_res: SphereMesh = null
static var plasma_core_mat: StandardMaterial3D = null
static var plasma_ring_mesh: TorusMesh = null
static var plasma_ring_mat: StandardMaterial3D = null

var is_visual: bool = true
var has_light: bool = false
var _has_registered: bool = false

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")

const ExplosionScript = preload("res://scripts/projectiles/explosion.gd")

## Takes a parked bullet from the pool, or instantiates a new one under parent. Call setup() on the result.
static func acquire(parent: Node, scene: PackedScene) -> Node:
	while not bullet_pool.is_empty():
		var b = bullet_pool.pop_back()
		if is_instance_valid(b) and b.is_inside_tree():
			b._activate()
			return b
	var nb = scene.instantiate()
	parent.add_child(nb)
	return nb

func _ready() -> void:
	_activate()

func _exit_tree() -> void:
	_unregister_bullet()
	if _in_pool:
		_in_pool = false
		bullet_pool.erase(self)

func _activate() -> void:
	_in_pool = false
	timer = 0.0
	speed = BASE_BULLET_SPEED
	lifetime = 2.5
	is_explosive = false
	is_plasma = false
	is_ricochet = false
	shooter = null
	already_hit.clear()
	_hit_rids.clear()
	pierces_left = GameManager.pierce_count
	bounces_left = GameManager.bounce_count if GameManager.bouncing_bullets else 0
	visible = true
	_space = get_world_3d().direct_space_state
	set_physics_process(true)
	_register_bullet()

## Spent bullet: park it hidden in the pool for reuse (plasma orbs carry custom visuals, so they're freed)
func _release() -> void:
	if _in_pool:
		return
	_unregister_bullet()
	if is_plasma or bullet_pool.size() >= MAX_BULLET_POOL or not is_inside_tree():
		queue_free()
		return
	_in_pool = true
	visible = false
	set_physics_process(false)
	shooter = null
	already_hit.clear()
	_hit_rids.clear()
	bullet_pool.append(self)

static func _get_ray_query(from: Vector3, to: Vector3, mask: int, exclude: Array[RID]) -> PhysicsRayQueryParameters3D:
	if _ray_query == null:
		_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.from = from
	_ray_query.to = to
	_ray_query.collision_mask = mask
	# Assigning exclude copies the array, so skip it for the common case (nothing pierced yet)
	if not exclude.is_empty() or _ray_query_has_exclude:
		_ray_query.exclude = exclude
		_ray_query_has_exclude = not exclude.is_empty()
	return _ray_query

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
	if is_plasma:
		is_visual = true
		if mesh_instance:
			mesh_instance.visible = true
		var light_target: OmniLight3D = omni_light if omni_light else get_node_or_null("OmniLight3D")
		if light_target:
			if not has_light and active_bullet_lights < MAX_BULLET_LIGHTS:
				active_bullet_lights += 1
				has_light = true
			light_target.visible = true
		return

	is_visual = state
	if is_visual:
		_sync_node()
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

static func _init_plasma_resources() -> void:
	plasma_outer_mesh = SphereMesh.new()
	plasma_outer_mesh.radius = 0.45
	plasma_outer_mesh.height = 0.90
	
	plasma_outer_mat = StandardMaterial3D.new()
	plasma_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plasma_outer_mat.albedo_color = Color(0.92, 0.22, 1.0, 0.75)
	plasma_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plasma_outer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	plasma_outer_mesh.material = plasma_outer_mat
	
	plasma_core_mesh_res = SphereMesh.new()
	plasma_core_mesh_res.radius = 0.24
	plasma_core_mesh_res.height = 0.48
	
	plasma_core_mat = StandardMaterial3D.new()
	plasma_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plasma_core_mat.albedo_color = Color(1.0, 0.9, 1.0, 1.0)
	plasma_core_mesh_res.material = plasma_core_mat
	
	plasma_ring_mesh = TorusMesh.new()
	plasma_ring_mesh.inner_radius = 0.44
	plasma_ring_mesh.outer_radius = 0.52
	
	plasma_ring_mat = StandardMaterial3D.new()
	plasma_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plasma_ring_mat.albedo_color = Color(0.35, 0.92, 1.0, 0.85)
	plasma_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plasma_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	plasma_ring_mesh.material = plasma_ring_mat

func _setup_plasma_visuals() -> void:
	if plasma_outer_mesh == null:
		_init_plasma_resources()
	
	var m = mesh_instance if mesh_instance else get_node_or_null("MeshInstance3D")
	if m:
		m.mesh = plasma_outer_mesh
		m.material_override = null
		m.transform = Transform3D.IDENTITY
		m.visible = true
		
		# Inner white-hot glowing core
		var core = m.get_node_or_null("PlasmaCore")
		if core == null:
			core = MeshInstance3D.new()
			core.name = "PlasmaCore"
			core.mesh = plasma_core_mesh_res
			m.add_child(core)
		
		# Equatorial electric containment ring
		var ring = m.get_node_or_null("PlasmaRing")
		if ring == null:
			ring = MeshInstance3D.new()
			ring.name = "PlasmaRing"
			ring.mesh = plasma_ring_mesh
			ring.rotation_degrees = Vector3(90, 0, 0)
			m.add_child(ring)
	
	var light_target: OmniLight3D = omni_light if omni_light else get_node_or_null("OmniLight3D")
	if light_target:
		light_target.light_color = Color(0.95, 0.25, 1.0)
		light_target.light_energy = 3.5
		light_target.omni_range = 6.5
		light_target.visible = true
		if not has_light and active_bullet_lights < MAX_BULLET_LIGHTS:
			active_bullet_lights += 1
			has_light = true

## Moves the node to the simulated position and faces it along its flight (only needed while drawn)
func _sync_node() -> void:
	global_position = sim_pos
	if direction != Vector3.ZERO and absf(direction.dot(Vector3.UP)) < 0.999:
		look_at(sim_pos + direction, Vector3.UP)

func setup(dir: Vector3, dmg: float, explosive: bool = false, from_plasma: bool = false, base_crit: float = 0.10, p_shooter: Node = null) -> void:
	sim_pos = global_position # Callers place the bullet before setup
	direction = dir.normalized()
	base_damage = dmg
	is_explosive = explosive or GameManager.explosive_rounds
	is_plasma = from_plasma
	shooter = p_shooter
	crit_chance = base_crit + (GameManager.crit_chance - 0.10)
	if is_plasma:
		speed = PLASMA_SPEED
		lifetime = 4.5
		is_visual = true # Plasma orbs are always drawn (and always move their node)
		if not self in visible_bullets:
			visible_bullets.append(self)
		_setup_plasma_visuals()
	if is_visual:
		_sync_node()

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		_release()
		return
	
	var p = sim_pos
	if absf(p.x) > ARENA_CULL_EXTENT or absf(p.z) > ARENA_CULL_EXTENT or p.y > ARENA_CULL_CEILING or p.y < -2.0:
		_release()
		return
	
	var move_step = direction * speed * delta
	var next_pos = sim_pos + move_step
	var space_state = _space
	
	if is_plasma:
		# Rotating & pulsing plasma orb visual animation
		var m = mesh_instance if mesh_instance else get_node_or_null("MeshInstance3D")
		if m:
			m.rotate_z(6.0 * delta)
			var ring = m.get_node_or_null("PlasmaRing")
			if ring:
				ring.rotate_x(8.0 * delta)
				ring.rotate_y(10.0 * delta)
			var pulse = 1.0 + sin(timer * 18.0) * 0.06
			m.scale = Vector3(pulse, pulse, pulse)
		
		# --- PLASMA COLLISION DETECTION WITH LARGE HITBOX ---
		# 1. Environment collision (walls, floor) with raycast so it doesn't snag on corners/doorways
		var wall_result = space_state.intersect_ray(_get_ray_query(sim_pos, next_pos, 1, _hit_rids)) # Layer 1: World / Environment
		var wall_dist = sim_pos.distance_to(wall_result.position) if wall_result else INF
		
		# 2. Check enemies with generous hitbox
		var best_enemy: Node = null
		var best_enemy_dist = INF
		var best_hit_pos = Vector3.ZERO
		
		var seg = next_pos - sim_pos
		var seg_len_sq = seg.length_squared()
		
		for enemy in EnemyBase.all_enemies:
			if not is_instance_valid(enemy) or enemy.is_dead or enemy in already_hit:
				continue
			
			var col_shape = enemy.get_node_or_null("CollisionShape3D")
			var enemy_rad = 0.55
			var shape_offset = Vector3(0, 0.5, 0)
			if col_shape:
				shape_offset = col_shape.position
				if col_shape.shape is SphereShape3D:
					enemy_rad = col_shape.shape.radius
				elif col_shape.shape is BoxShape3D:
					var s = col_shape.shape.size
					enemy_rad = maxf(s.x, s.z) * 0.5
			
			var epos = enemy.global_position + shape_offset
			
			# Broadphase distance cull
			if absf(epos.x - sim_pos.x) > 4.0 or absf(epos.z - sim_pos.z) > 4.0 or absf(epos.y - sim_pos.y) > 4.0:
				continue
			
			var t = 0.0
			if seg_len_sq > 0.0001:
				t = clampf((epos - sim_pos).dot(seg) / seg_len_sq, 0.0, 1.0)
			var closest_pt = sim_pos + seg * t
			var dist = closest_pt.distance_to(epos)
			
			# Generous contact threshold: projectile radius (0.75m) + enemy collision radius
			if dist <= (PLASMA_HITBOX_RADIUS + enemy_rad):
				var travel_d = sim_pos.distance_to(closest_pt)
				if travel_d < wall_dist and travel_d < best_enemy_dist:
					best_enemy = enemy
					best_enemy_dist = travel_d
					best_hit_pos = closest_pt
		
		# 3. Resolve collision
		if best_enemy != null:
			_move_to(next_pos)
			_handle_hit(best_enemy, best_hit_pos, -direction)
			return
		elif wall_result:
			_handle_hit(wall_result.collider, wall_result.position, wall_result.normal)
			return
		else:
			_move_to(next_pos)
			return
	
	# Standard bullet raycast sweep (pierced enemies are excluded so the bullet passes through them)
	var result = space_state.intersect_ray(_get_ray_query(sim_pos, next_pos, collision_mask, _hit_rids))
	if result:
		_handle_hit(result.collider, result.position, result.normal)
	else:
		_move_to(next_pos)

## Advances the simulated position; hidden bullets skip the node transform update entirely
func _move_to(p: Vector3) -> void:
	sim_pos = p
	if is_visual:
		global_position = p

func _handle_hit(collider: Object, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if collider in already_hit:
		return
	
	if collider is Node and collider.is_in_group("enemies"):
		already_hit.append(collider)
		if collider is CollisionObject3D:
			_hit_rids.append(collider.get_rid())
		var is_crit = randf() < crit_chance
		var final_dmg = base_damage * GameManager.damage_mult
		if is_crit:
			final_dmg *= GameManager.crit_damage
		
		# Slot 3 (Plasma Core) exclusive chain lightning behavior
		if is_plasma and GameManager.chain_lightning:
			_trigger_plasma_chain_lightning(hit_pos, final_dmg, collider, is_crit)
		else:
			var hit_dmg_type = _get_direct_hit_type(collider, hit_pos)
			var is_immune = collider.has_method("is_immune_to") and collider.is_immune_to(hit_dmg_type)
			var is_from_rogue = (shooter != null and shooter.get("player_class") == "rogue")
			
			if collider.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
				collider.rpc_take_damage.rpc(final_dmg, is_crit, sim_pos, hit_dmg_type, is_from_rogue)
			elif collider.has_method("take_damage"):
				collider.take_damage(final_dmg, is_crit, sim_pos, hit_dmg_type, shooter)
			
			if not is_immune:
				GameManager.record_damage(final_dmg, is_crit)
				if collider.has_method("apply_cryo_chill"):
					collider.apply_cryo_chill()
			
			# Standard Chain Lightning effect on enemy hit (does not trigger on ricochets)
			if GameManager.chain_lightning and not is_ricochet:
				_trigger_chain_lightning_at_pos(hit_pos, final_dmg * 0.75, collider)
			
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
			_release()
			return
	else:
		# Hit environment / wall / floor
		var wall_hit_dmg = base_damage * GameManager.damage_mult
		if bounces_left > 0 and hit_normal != Vector3.ZERO:
			bounces_left -= 1
			
			# Trigger on-hit effects for bounce (Plasma Core retains ricochet lightning synergy)
			if is_plasma and GameManager.chain_lightning:
				_trigger_plasma_chain_lightning(hit_pos, wall_hit_dmg, null, false)
			else:
				_trigger_impact_effects(hit_pos, wall_hit_dmg)
			
			_ricochet_from(hit_pos, hit_normal, null)
			return
		
		if is_plasma and GameManager.chain_lightning:
			_trigger_plasma_chain_lightning(hit_pos, wall_hit_dmg, null, false)
		else:
			_trigger_impact_effects(hit_pos, wall_hit_dmg)
		_release()

func _ricochet_from(pos: Vector3, surface_normal: Vector3, ignore_target: Node) -> void:
	is_ricochet = true
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
	
	sim_pos = pos + surface_normal * 0.15
	if is_visual:
		_sync_node()
	
	# Audio throttling on ricochet (attenuated to 1/4 volume: 4.0 dB - 12.0 dB = -8.0 dB)
	var now = Time.get_ticks_msec()
	if now - last_ricochet_sound_msec >= 35:
		last_ricochet_sound_msec = now
		SoundManager.play("hitmarker", 0.25, -8.0)

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
			# Prioritize targets that are vulnerable to ricochet damage
			var is_immune = enemy.has_method("is_immune_to") and enemy.is_immune_to(EnemyBase.DAMAGE_TYPE_RICOCHET)
			var score = d_sq + (100000.0 if is_immune else 0.0)
			if score < best_dist_sq:
				var dir_to = (epos - from_pos).normalized()
				if forward_dir.dot(dir_to) > -0.25:
					best_dist_sq = score
					best_target = enemy
	return best_target

## Direct hit type: ricochets never count as weakpoint shots; otherwise ask the enemy whether this shot's path crosses its weakpoint
func _get_direct_hit_type(enemy: Object, hit_pos: Vector3) -> int:
	if is_ricochet:
		return EnemyBase.DAMAGE_TYPE_RICOCHET
	if enemy.has_method("is_weakpoint_hit"):
		# Hitboxes enclose the weakpoint, so trace the flight line from well before the surface hit
		var pad = 0.3 if is_plasma else 0.0
		if enemy.is_weakpoint_hit(hit_pos - direction * 3.0, direction, pad):
			return EnemyBase.DAMAGE_TYPE_WEAKPOINT
	return EnemyBase.DAMAGE_TYPE_DIRECT

func _trigger_impact_effects(pos: Vector3, initial_hit_dmg: float) -> void:
	if is_explosive:
		var rad = GameManager.explosion_radius
		if is_plasma:
			rad = 5.0 * (1.25 if GameManager.explosive_rounds else 1.0)
		var aoe_dmg = initial_hit_dmg if is_plasma else (initial_hit_dmg * 0.8)
		var parent = get_parent()
		if parent:
			ExplosionScript.spawn_explosion(parent, pos, aoe_dmg, rad, shooter)

func _trigger_plasma_chain_lightning(hit_pos: Vector3, impact_dmg: float, direct_enemy: Node, is_direct_crit: bool) -> void:
	var explode_rad = 5.0 * (1.25 if GameManager.explosive_rounds else 1.0)
	var explode_rad_sq = explode_rad * explode_rad
	var chain_base_dmg = impact_dmg * 0.75
	
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
				var is_immune = enemy.has_method("is_immune_to") and enemy.is_immune_to(EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING)
				var is_from_rogue = (shooter != null and shooter.get("player_class") == "rogue")
				if enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
					enemy.rpc_take_damage.rpc(bolt_dmg, is_crit, hit_pos, EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING, is_from_rogue)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(bolt_dmg, is_crit, hit_pos, EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING, shooter)
				
				if not is_immune:
					GameManager.record_damage(bolt_dmg, is_crit)
					if enemy.has_method("apply_cryo_chill"):
						enemy.apply_cryo_chill()
				
				hit_count += 1
				if hit_count >= 10:
					break
	
	if hit_count > 0:
		_play_chain_sound()
	
	# Direct hit damage
	if direct_enemy != null and is_instance_valid(direct_enemy) and not direct_enemy.is_dead:
		var direct_dmg_type = _get_direct_hit_type(direct_enemy, hit_pos)
		var direct_immune = direct_enemy.has_method("is_immune_to") and direct_enemy.is_immune_to(direct_dmg_type)
		if direct_enemy.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
			direct_enemy.rpc_take_damage.rpc(impact_dmg, is_direct_crit, sim_pos, direct_dmg_type)
		elif direct_enemy.has_method("take_damage"):
			direct_enemy.take_damage(impact_dmg, is_direct_crit, sim_pos, direct_dmg_type)
		
		if not direct_immune:
			GameManager.record_damage(impact_dmg, is_direct_crit)
			if direct_enemy.has_method("apply_cryo_chill"):
				direct_enemy.apply_cryo_chill()
	
	# Detonate plasma explosion AoE damage
	_trigger_impact_effects(hit_pos, impact_dmg)
	
	# Outward secondary chain
	var secondary_hit_counts: Dictionary = {}
	var secondary_hits: int = 0
	var chain_rad_sq = 8.5 * 8.5
	
	var max_secondary = maxi(6, GameManager.chain_lightning_targets * 2)
	for entry in primary_targets:
		if secondary_hits >= max_secondary:
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
					var is_cand_immune = enemy.has_method("is_immune_to") and enemy.is_immune_to(EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING)
					var score = float(times_hit) * 1000.0 + dist_sq + (50000.0 if is_cand_immune else 0.0)
					if score < best_score:
						best_score = score
						best_cand = enemy
		
		if best_cand != null:
			secondary_hit_counts[best_cand] = secondary_hit_counts.get(best_cand, 0) + 1
			var cand_pos = best_cand.global_position + Vector3(0, 0.6, 0)
			_create_lightning_beam(from_pos, cand_pos)
			
			var chain_is_crit = randf() < crit_chance
			var chain_dmg = chain_base_dmg * (GameManager.crit_damage if chain_is_crit else 1.0)
			var is_target_immune = best_cand.has_method("is_immune_to") and best_cand.is_immune_to(EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING)
			var is_from_rogue = (shooter != null and shooter.get("player_class") == "rogue")
			if best_cand.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
				best_cand.rpc_take_damage.rpc(chain_dmg, chain_is_crit, from_pos, EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING, is_from_rogue)
			elif best_cand.has_method("take_damage"):
				best_cand.take_damage(chain_dmg, chain_is_crit, from_pos, EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING, shooter)
			
			if not is_target_immune:
				GameManager.record_damage(chain_dmg, chain_is_crit)
				if best_cand.has_method("apply_cryo_chill"):
					best_cand.apply_cryo_chill()
			
			secondary_hits += 1
	
	if secondary_hits > 0 and hit_count == 0:
		_play_chain_sound()

func _trigger_chain_lightning_at_pos(origin_pos: Vector3, chain_dmg: float, initial_enemy: Node) -> void:
	var total_chains = GameManager.chain_lightning_targets
	if total_chains <= 0:
		total_chains = 2
	
	var enemies = EnemyBase.all_enemies
	var current_node: Node = initial_enemy
	var current_pos: Vector3 = origin_pos
	if is_instance_valid(current_node) and current_node is Node3D:
		current_pos = current_node.global_position + Vector3(0, 0.6, 0)
	
	var chain_hit_counts: Dictionary = {}
	if current_node != null:
		# Initial enemy already took direct bullet impact damage; mark 1 so unhit enemies are prioritized
		chain_hit_counts[current_node] = 1
	
	var hit_count: int = 0
	var range_sq: float = 8.5 * 8.5
	
	for _step in range(total_chains):
		var best_cand: Node = null
		var best_score: float = INF
		var best_cand_pos: Vector3 = Vector3.ZERO
		
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.is_dead:
				continue
			if enemy.get("current_health") != null and enemy.get("current_health") <= 0.0:
				continue
			# It MUST chain to another enemy (cannot chain to the current node)
			if enemy == current_node:
				continue
			
			var epos: Vector3 = enemy.global_position
			if absf(epos.x - current_pos.x) > 8.5 or absf(epos.z - current_pos.z) > 8.5:
				continue
			var d_sq = current_pos.distance_squared_to(epos)
			if d_sq <= range_sq:
				var times_hit = chain_hit_counts.get(enemy, 0)
				# Prioritize enemies with fewer chain hits and those vulnerable to chain lightning
				var is_immune = enemy.has_method("is_immune_to") and enemy.is_immune_to(EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING)
				var score = float(times_hit) * 1000.0 + d_sq + (50000.0 if is_immune else 0.0)
				if score < best_score:
					best_score = score
					best_cand = enemy
					best_cand_pos = epos + Vector3(0, 0.6, 0)
		
		# If no other valid enemy in range, chain terminates
		if best_cand == null:
			break
		
		# Apply chain hit
		chain_hit_counts[best_cand] = chain_hit_counts.get(best_cand, 0) + 1
		_create_lightning_beam(current_pos, best_cand_pos)
		
		var is_crit = randf() < crit_chance
		var final_dmg = chain_dmg * (GameManager.crit_damage if is_crit else 1.0)
		var is_target_immune = best_cand.has_method("is_immune_to") and best_cand.is_immune_to(EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING)
		var is_from_rogue = (shooter != null and shooter.get("player_class") == "rogue")
		if best_cand.has_method("rpc_take_damage") and NetworkManager.is_multiplayer:
			best_cand.rpc_take_damage.rpc(final_dmg, is_crit, current_pos, EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING, is_from_rogue)
		elif best_cand.has_method("take_damage"):
			best_cand.take_damage(final_dmg, is_crit, current_pos, EnemyBase.DAMAGE_TYPE_CHAIN_LIGHTNING, shooter)
		
		if not is_target_immune:
			GameManager.record_damage(final_dmg, is_crit)
			if best_cand.has_method("apply_cryo_chill"):
				best_cand.apply_cryo_chill()
		
		hit_count += 1
		# Advance chain
		current_node = best_cand
		current_pos = best_cand_pos
	
	if hit_count > 0:
		_play_chain_sound()

## Chain lightning zap sound, throttled like ricochets so pellet storms don't spam the SFX pool
func _play_chain_sound() -> void:
	var now = Time.get_ticks_msec()
	if now - last_chain_sound_msec >= 35:
		last_chain_sound_msec = now
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
