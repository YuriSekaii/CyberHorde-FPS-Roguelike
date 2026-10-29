extends Node3D

## Spore Pit artillery glob: shot straight up into the sky, then falls onto a locked ground position.
## The landing zone is marked by a pulsing ring for the whole flight so operatives can dodge out of it.
## On impact every operative within the radius takes the full hit, and a poison puddle stays there for 3s.

const LOCK_INDICATOR_SCENE = preload("res://scenes/enemies/boss_lock_indicator.tscn")
const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")
const POISON_ZONE_SCRIPT = preload("res://scripts/projectiles/spore_poison_zone.gd")
const PEAK_HEIGHT: float = 34.0
const SPORE_COLOR := Color(0.75, 1.0, 0.2)

var start_pos: Vector3
var target_pos: Vector3
var flight_time: float = 2.2
var radius: float = 5.0
var damage: float = 60.0
var elapsed: float = 0.0
var indicator: Node3D = null

func setup(p_start: Vector3, p_target: Vector3, p_flight_time: float, p_radius: float, p_damage: float) -> void:
	start_pos = p_start
	target_pos = p_target
	flight_time = p_flight_time
	radius = p_radius
	damage = p_damage
	global_position = start_pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = SPORE_COLOR
	mat.emission_enabled = true
	mat.emission = SPORE_COLOR
	mat.emission_energy_multiplier = 3.0
	var mesh = SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.1
	mesh.material = mat
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	indicator = LOCK_INDICATOR_SCENE.instantiate()
	get_parent().add_child(indicator)
	indicator.global_position = target_pos
	indicator.setup(radius, flight_time)
	var label = indicator.get_node_or_null("Label3D")
	if label:
		label.text = "⚠ SPORE IMPACT ⚠"

func _physics_process(delta: float) -> void:
	elapsed += delta
	var s = clampf(elapsed / flight_time, 0.0, 1.0)
	# Mostly vertical launch first, then a steep drop onto the target
	var h = s * s * (3.0 - 2.0 * s)
	var pos = start_pos.lerp(target_pos, h)
	pos.y = lerpf(start_pos.y, target_pos.y, s) + PEAK_HEIGHT * 4.0 * s * (1.0 - s)
	global_position = pos
	if s >= 1.0:
		_impact()

func _impact() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.has_method("take_damage"):
			continue
		var d = p.global_position - target_pos
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) <= 3.0:
			p.take_damage(damage)
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = target_pos + Vector3(0, 0.3, 0)
	exp_inst.setup(0.0, radius)
	var zone = Node3D.new()
	zone.set_script(POISON_ZONE_SCRIPT)
	get_parent().add_child(zone)
	zone.global_position = target_pos
	zone.setup(radius)
	SoundManager.play("explosion", 0.15, -2.0)
	if is_instance_valid(indicator):
		indicator.queue_free()
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(indicator) and not indicator.is_queued_for_deletion():
		indicator.queue_free()
