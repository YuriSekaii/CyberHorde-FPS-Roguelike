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
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("enemies") and not b in hit_targets:
			hit_targets.append(b)
			if b.has_method("take_damage"):
				b.take_damage(damage, false, global_position)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and not body in hit_targets:
		hit_targets.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage, false, global_position)

func _process(delta: float) -> void:
	timer += delta
	if light:
		light.light_energy = maxf(0.0, 5.0 * (1.0 - (timer / lifetime)))
	if timer >= lifetime:
		queue_free()
