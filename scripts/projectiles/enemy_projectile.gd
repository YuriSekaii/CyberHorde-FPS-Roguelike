extends Area3D

@export var speed: float = 24.0
@export var damage: float = 15.0

var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 6.0
var timer: float = 0.0

func setup(dir: Vector3, dmg: float) -> void:
	direction = dir.normalized()
	damage = dmg
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif not body.is_in_group("enemies"):
		# Hit wall / floor
		queue_free()
