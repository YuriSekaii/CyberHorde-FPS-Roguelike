extends Area3D

@export var launch_force: float = 16.0
@onready var particles: CPUParticles3D = $CPUParticles3D

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("apply_impulse_jump"):
		body.apply_impulse_jump(launch_force)
		if particles:
			particles.restart()
			particles.emitting = true
