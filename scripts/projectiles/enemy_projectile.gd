extends Area3D

## Emitted when an explosive projectile detonates (used by the final boss to chain-detonate ice spikes)
signal exploded(pos: Vector3)
## Emitted when a pin_on_ground projectile embeds into a floor-like surface
signal pinned(pos: Vector3, dir: Vector3, normal: Vector3, dmg: float)

@export var speed: float = 24.0
@export var damage: float = 15.0

var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 4.5
var timer: float = 0.0

var is_explosive: bool = false
var explosion_radius: float = 4.5
var explosion_damage: float = -1.0
var has_exploded: bool = false
var pin_on_ground: bool = false

const EXPLOSION_SCENE = preload("res://scenes/projectiles/explosion.tscn")

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var light: OmniLight3D = get_node_or_null("OmniLight3D")

func setup(dir: Vector3, dmg: float, p_speed: float = 24.0, explosive: bool = false, exp_rad: float = 4.5, exp_dmg: float = -1.0) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = p_speed
	is_explosive = explosive
	explosion_radius = exp_rad
	explosion_damage = exp_dmg if exp_dmg >= 0.0 else dmg
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func set_projectile_visual(color: Color, p_scale: Vector3 = Vector3.ONE) -> void:
	scale = p_scale
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mesh_instance.material_override = mat
	if light:
		light.light_color = color
		if p_scale.x > 1.5:
			light.omni_range = 10.0
			light.light_energy = 5.0

## Ice needle look: stretches only the mesh along the flight axis (-Z) so the collision shape stays uniformly scaled
func set_needle_visual(color: Color, p_scale: float = 0.42) -> void:
	set_projectile_visual(color, Vector3(p_scale, p_scale, p_scale))
	if mesh_instance:
		mesh_instance.scale = Vector3(0.45, 0.45, 3.2)
		var mat: StandardMaterial3D = mesh_instance.material_override
		if mat:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 1.5

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		if is_explosive:
			_explode()
		else:
			queue_free()
		return
	
	global_position += direction * speed * delta

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	
	var actual_dmg = explosion_damage if explosion_damage >= 0.0 else damage
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var d = global_position.distance_to(p.global_position)
			if d <= explosion_radius:
				var falloff = clampf(1.0 - (d / explosion_radius) * 0.5, 0.4, 1.0)
				if p.has_method("take_damage"):
					p.take_damage(actual_dmg * falloff)
				if p.has_method("apply_impulse_jump") and explosion_radius >= 6.0:
					p.apply_impulse_jump(12.0 * falloff)
	
	var exp_inst = EXPLOSION_SCENE.instantiate()
	get_parent().add_child(exp_inst)
	exp_inst.global_position = global_position
	exp_inst.setup(0.0, explosion_radius)
	SoundManager.play("explosion", 0.15, -1.0)
	exploded.emit(global_position)
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		return
	
	if is_explosive:
		_explode()
		return
	
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	else:
		# Hit wall / floor
		if pin_on_ground:
			_try_pin()
		queue_free()

func _try_pin() -> void:
	# Area3D overlaps carry no contact normal, so raycast along the flight path to find the surface hit
	var space = get_world_3d().direct_space_state
	var from = global_position - direction * maxf(speed * 0.05, 1.0)
	var to = global_position + direction * 1.5
	var query = PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return
	var n: Vector3 = hit["normal"]
	# Only floor-like surfaces (ground, platform top, ramps) hold a spike; walls just shatter the needle
	if n.y >= 0.55:
		pinned.emit(hit["position"], direction, n, damage)
