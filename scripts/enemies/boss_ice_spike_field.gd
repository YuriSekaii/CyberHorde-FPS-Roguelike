extends Node3D

## Apex Overlord Stage 3 - Ice Spike Field
## Ice needles from the machine gun barrage pin into the ground as spikes.
## Players standing in a spike take that needle's damage every 0.5s (non-stacking per player).
## The post-exhaustion dive also erupts a spike field across its AoE.
## When the mega plasma orb lands, every spike detonates in an outward ripple (3m radius, 2x needle damage each).
## The blast is a column that also reaches 4.5m below the spike, so spikes on the platform hit players hiding underneath.
## All spikes share one MultiMesh so hundreds of them cost a single draw call.

const MAX_SPIKES: int = 480
const CONTACT_RADIUS: float = 0.75 # player capsule radius (0.45) + spike girth
const CONTACT_TICK: float = 0.5
const DETONATION_RADIUS: float = 3.0
const DETONATION_DOWN_REACH: float = 4.5 # blast reaches this far below a spike (covers the 3.9m platform underside)
const DETONATION_DMG_MULT: float = 2.0
const RIPPLE_SPEED: float = 45.0 # m/s outward from the orb impact
const SPIKE_HEIGHT: float = 1.0
const SPIKE_BURY: float = 0.3

const ZERO_XFORM := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

var _pos := PackedVector3Array()
var _dmg := PackedFloat32Array()
var _alive := PackedByteArray()
var _alive_count: int = 0
var _next_slot: int = 0

# Per-player contact cooldowns (instance_id -> seconds remaining)
var _contact_cd: Dictionary = {}

var _is_detonating: bool = false
var _det_order: Array = []
var _det_index: int = 0
var _ripple_center: Vector3 = Vector3.ZERO
var _ripple_radius: float = 0.0

var _mm: MultiMesh

func _ready() -> void:
	# Spike transforms are authored in world space
	top_level = true
	global_transform = Transform3D.IDENTITY
	
	_pos.resize(MAX_SPIKES)
	_dmg.resize(MAX_SPIKES)
	_alive.resize(MAX_SPIKES)
	_alive.fill(0)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = SPIKE_HEIGHT
	cone.radial_segments = 5
	cone.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.95, 1.0)
	mat.metallic = 0.2
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.2
	cone.material = mat

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = cone
	_mm.instance_count = MAX_SPIKES
	for i in range(MAX_SPIKES):
		_mm.set_instance_transform(i, ZERO_XFORM)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func add_spike(hit_pos: Vector3, dir: Vector3, normal: Vector3, dmg: float) -> void:
	if _is_detonating:
		return

	# Ring buffer: once full, the oldest spike melts away to make room
	var slot = _next_slot
	_next_slot = (_next_slot + 1) % MAX_SPIKES
	if _alive[slot] == 0:
		_alive_count += 1
	_alive[slot] = 1
	_pos[slot] = hit_pos
	_dmg[slot] = dmg

	# Spike juts out back along the incoming flight path, tilted toward the surface normal so it never lies flat
	var axis = (-dir).lerp(normal, 0.4).normalized()
	var side = axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd = side.cross(axis).normalized()
	var b = Basis(side, axis, fwd).rotated(axis, randf() * TAU)
	var s = randf_range(0.8, 1.2)
	b = b.scaled(Vector3(s, s, s))
	var center = hit_pos + axis * (SPIKE_HEIGHT * 0.5 - SPIKE_BURY) * s
	_mm.set_instance_transform(slot, Transform3D(b, center))

## Erupts spikes across a disc (Stage 3 dive impact). Each point raycasts down so spikes sit on the floor, platform or ramps.
func scatter_spikes(center: Vector3, radius: float, count: int, dmg: float) -> void:
	var space = get_world_3d().direct_space_state
	for i in range(count):
		var ang = randf() * TAU
		var r = sqrt(randf()) * radius # uniform over the disc area
		var outward = Vector3(cos(ang), 0.0, sin(ang))
		var col = center + outward * r
		var query = PhysicsRayQueryParameters3D.create(Vector3(col.x, center.y + 6.0, col.z), Vector3(col.x, -1.0, col.z), 1)
		var hit = space.intersect_ray(query)
		if hit.is_empty() or hit["normal"].y < 0.55:
			continue
		# Spikes lean outward from the impact like an eruption
		var dir = (Vector3.DOWN - outward * randf_range(0.3, 0.7)).normalized()
		add_spike(hit["position"], dir, hit["normal"], dmg)

func detonate(impact_pos: Vector3) -> void:
	if _is_detonating or _alive_count == 0:
		return
	_is_detonating = true
	_ripple_center = impact_pos
	_ripple_radius = 0.0
	_det_index = 0
	_det_order.clear()
	for i in range(MAX_SPIKES):
		if _alive[i] == 1:
			_det_order.append(i)
	_det_order.sort_custom(func(a, b): return _pos[a].distance_squared_to(impact_pos) < _pos[b].distance_squared_to(impact_pos))
	SoundManager.play("explosion", 0.2, -2.0)

func clear_all() -> void:
	for i in range(MAX_SPIKES):
		_alive[i] = 0
		_mm.set_instance_transform(i, ZERO_XFORM)
	_alive_count = 0
	_next_slot = 0
	_is_detonating = false
	_det_order.clear()

func _physics_process(delta: float) -> void:
	if _alive_count == 0:
		return

	if _is_detonating:
		_process_detonation(delta)

	_process_contact(delta)

func _process_contact(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p) or not (p is CharacterBody3D):
			continue
		var pid = p.get_instance_id()
		var cd: float = _contact_cd.get(pid, 0.0) - delta
		if cd > 0.0:
			_contact_cd[pid] = cd
			continue
		_contact_cd[pid] = 0.0

		var feet: Vector3 = p.global_position
		for i in range(MAX_SPIKES):
			if _alive[i] == 0:
				continue
			var sp = _pos[i]
			# Jumping over a spike clears it; only feet-level contact counts
			var dy = feet.y - sp.y
			if dy < -0.4 or dy > 0.9:
				continue
			var dx = feet.x - sp.x
			var dz = feet.z - sp.z
			if dx * dx + dz * dz <= CONTACT_RADIUS * CONTACT_RADIUS:
				if p.has_method("take_damage"):
					p.take_damage(_dmg[i])
				_contact_cd[pid] = CONTACT_TICK
				break

func _process_detonation(delta: float) -> void:
	_ripple_radius += RIPPLE_SPEED * delta
	var players = get_tree().get_nodes_in_group("player")
	while _det_index < _det_order.size():
		var slot: int = _det_order[_det_index]
		if _pos[slot].distance_to(_ripple_center) > _ripple_radius:
			break
		_det_index += 1
		_explode_spike(slot, players)

	if _det_index >= _det_order.size():
		_is_detonating = false
		_det_order.clear()

func _explode_spike(slot: int, players: Array) -> void:
	var sp = _pos[slot]
	var blast_dmg = _dmg[slot] * DETONATION_DMG_MULT
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			# Column blast: 3m around the spike, but punches straight down through the platform slab
			# so hiding under the stage doesn't dodge spikes pinned on top of it
			var chest: Vector3 = p.global_position + Vector3(0.0, 0.9, 0.0)
			var dy = chest.y - sp.y
			if dy > DETONATION_RADIUS or dy < -DETONATION_DOWN_REACH:
				continue
			var dx = chest.x - sp.x
			var dz = chest.z - sp.z
			if dx * dx + dz * dz <= DETONATION_RADIUS * DETONATION_RADIUS:
				if p.has_method("take_damage"):
					p.take_damage(blast_dmg)

	_alive[slot] = 0
	_alive_count -= 1
	_mm.set_instance_transform(slot, ZERO_XFORM)
	# Pooled visual (0 dmg: player damage is handled above, enemies are unaffected)
	Explosion.spawn_explosion(get_parent(), sp + Vector3(0.0, 0.3, 0.0), 0.0, DETONATION_RADIUS)
