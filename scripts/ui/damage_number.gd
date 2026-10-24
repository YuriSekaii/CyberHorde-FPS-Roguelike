extends Node3D

@onready var label: Label3D = $Label3D

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.8
var timer: float = 0.0

func setup(amount: float, is_crit: bool) -> void:
	if not is_node_ready():
		await ready
	
	var text_val = str(int(round(amount)))
	if is_crit:
		label.text = text_val + "!"
		label.modulate = Color(1.0, 0.25, 0.1, 1.0)
		label.outline_modulate = Color(0.8, 0.8, 0.0, 1.0)
		label.font_size = 46
		scale = Vector3.ONE * 1.4
	else:
		label.text = text_val
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label.outline_modulate = Color(0.1, 0.1, 0.2, 1.0)
		label.font_size = 32
		scale = Vector3.ONE * 1.0
	
	# Random float direction
	velocity = Vector3(
		randf_range(-1.2, 1.2),
		randf_range(2.0, 3.5),
		randf_range(-1.2, 1.2)
	)

func _process(delta: float) -> void:
	timer += delta
	global_position += velocity * delta
	velocity.y -= 4.0 * delta # Slight gravity
	
	# Fade out
	var alpha = clampf(1.0 - (timer / lifetime), 0.0, 1.0)
	label.modulate.a = alpha
	label.outline_modulate.a = alpha
	
	if timer >= lifetime:
		queue_free()
