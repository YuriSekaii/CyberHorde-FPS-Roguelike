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

static var active_pickups: Array[Node] = []
const MAX_ACTIVE_PICKUPS: int = 40
var retarget_timer: float = 0.0

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Auto-merge excess XP drops if active pickup pool is full
	if active_pickups.size() >= MAX_ACTIVE_PICKUPS and type == PickupType.XP:
		for p in active_pickups:
			if is_instance_valid(p) and p.get("type") == PickupType.XP:
				p.set("value", p.get("value") + value)
				queue_free()
				return
	
	active_pickups.append(self)
	# If dropped from high in the sky (e.g. flying Void Spawner), tumble down to arena ground
	initial_y = 0.5 if global_position.y > 4.5 else global_position.y
	bob_timer = randf() * TAU
	velocity = Vector3(
		randf_range(-2.0, 2.0),
		randf_range(3.0, 5.0),
		randf_range(-2.0, 2.0)
	)
	_apply_visuals()

func _exit_tree() -> void:
	active_pickups.erase(self)

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
		PickupType.HEALTH:
			mat.albedo_color = Color(1.0, 0.15, 0.2, 1.0)
		PickupType.SCRAP:
			mat.albedo_color = Color(1.0, 0.85, 0.1, 1.0)
	
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
	
	# Retarget player periodically (not every single frame)
	retarget_timer -= delta
	if retarget_timer <= 0.0 or player == null or not is_instance_valid(player):
		retarget_timer = 0.25
		var players = get_tree().get_nodes_in_group("player")
		var closest_p: Node3D = null
		var min_d_sq: float = INF
		for p in players:
			if is_instance_valid(p):
				var d_sq = global_position.distance_squared_to(p.global_position)
				if d_sq < min_d_sq:
					min_d_sq = d_sq
					closest_p = p
		player = closest_p
	
	if player != null and is_instance_valid(player):
		var magnet_r_sq = GameManager.magnet_radius * GameManager.magnet_radius
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq <= magnet_r_sq:
			is_magnetized = true
		
		if is_magnetized:
			var dir = (player.global_position + Vector3(0, 0.8, 0) - global_position).normalized()
			magnet_speed += 25.0 * delta # Accelerates rapidly
			global_position += dir * magnet_speed * delta
			
			if dist_sq < 1.69: # 1.3^2
				_collect()
				return
	
	# Spin idle
	rotate_y(2.5 * delta)

func _collect() -> void:
	match type:
		PickupType.XP:
			if NetworkManager.is_multiplayer:
				GameManager.rpc_add_xp.rpc(value)
			else:
				GameManager.add_xp(value)
			SoundManager.play("pickup_xp", 0.15, -2.0)
		PickupType.HEALTH:
			if player and player.has_method("heal"):
				player.heal(25.0)
			SoundManager.play("pickup_health", 0.05, 1.0)
		PickupType.SCRAP:
			if NetworkManager.is_multiplayer:
				GameManager.rpc_add_scrap.rpc(value)
			else:
				GameManager.add_scrap(value)
			SoundManager.play("pickup_xp", 0.2, -4.0)
	
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body
		_collect()
