extends Area3D

enum PickupType { XP, HEALTH, SCRAP }

@export var type: PickupType = PickupType.XP
@export var value: int = 15

var player: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var is_magnetized: bool = false
var magnet_speed: float = 12.0
var bob_timer: float = 0.0
var initial_y: float = 0.0

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	initial_y = global_position.y
	bob_timer = randf() * TAU
	# Small initial pop
	velocity = Vector3(
		randf_range(-2.0, 2.0),
		randf_range(3.0, 5.0),
		randf_range(-2.0, 2.0)
	)
	_apply_visuals()

func setup(p_type: PickupType, p_val: int) -> void:
	type = p_type
	value = p_val
	if is_node_ready():
		_apply_visuals()

func _apply_visuals() -> void:
	if not mesh_inst:
		return
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	match type:
		PickupType.XP:
			mat.albedo_color = Color(0.1, 1.0, 0.6, 1.0)
			if light: light.light_color = Color(0.1, 1.0, 0.6, 1.0)
		PickupType.HEALTH:
			mat.albedo_color = Color(1.0, 0.15, 0.2, 1.0)
			if light: light.light_color = Color(1.0, 0.15, 0.2, 1.0)
		PickupType.SCRAP:
			mat.albedo_color = Color(1.0, 0.85, 0.1, 1.0)
			if light: light.light_color = Color(1.0, 0.85, 0.1, 1.0)
	
	mesh_inst.material_override = mat

func _physics_process(delta: float) -> void:
	bob_timer += delta
	
	# Initial toss physics
	if velocity.length_squared() > 0.01:
		global_position += velocity * delta
		velocity.y -= 9.8 * delta
		if global_position.y <= initial_y:
			global_position.y = initial_y
			velocity = Vector3.ZERO
	
	# Find player if not cached
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if player != null and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= GameManager.magnet_radius:
			is_magnetized = true
		
		if is_magnetized:
			var dir = (player.global_position + Vector3(0, 0.8, 0) - global_position).normalized()
			magnet_speed += 25.0 * delta # Accelerates rapidly
			global_position += dir * magnet_speed * delta
			
			if dist < 1.3:
				_collect()
				return
	
	# Spin idle
	rotate_y(2.5 * delta)

func _collect() -> void:
	match type:
		PickupType.XP:
			GameManager.add_xp(value)
			SoundManager.play("pickup_xp", 0.15, -2.0)
		PickupType.HEALTH:
			if player and player.has_method("heal"):
				player.heal(25.0)
			SoundManager.play("pickup_health", 0.05, 1.0)
		PickupType.SCRAP:
			GameManager.add_scrap(value)
			SoundManager.play("pickup_xp", 0.2, -4.0)
	
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_collect()
