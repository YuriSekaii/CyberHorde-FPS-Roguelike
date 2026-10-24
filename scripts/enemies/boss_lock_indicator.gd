extends Node3D

@export var radius: float = 10.0
@export var duration: float = 1.0

var elapsed: float = 0.0
var ring_mat: StandardMaterial3D
var pillar_mat: StandardMaterial3D

@onready var ring_mesh: MeshInstance3D = $Ring
@onready var pillar_mesh: MeshInstance3D = $Pillar
@onready var light: OmniLight3D = $WarningLight
@onready var label: Label3D = $Label3D

func _ready() -> void:
	add_to_group("boss_indicators")
	_setup_visuals()

func setup(p_radius: float, p_duration: float = 1.0) -> void:
	radius = p_radius
	duration = p_duration
	_setup_visuals()

func _setup_visuals() -> void:
	if not ring_mat:
		ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.65)
	
	if not pillar_mat:
		pillar_mat = StandardMaterial3D.new()
		pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		pillar_mat.albedo_color = Color(1.0, 0.05, 0.05, 0.25)
	
	if ring_mesh:
		ring_mesh.material_override = ring_mat
		ring_mesh.scale = Vector3(radius, 1.0, radius)
	
	if pillar_mesh:
		pillar_mesh.material_override = pillar_mat
		pillar_mesh.scale = Vector3(radius * 0.2, 1.0, radius * 0.2)
	
	if light:
		light.light_color = Color(1.0, 0.1, 0.1)
		light.omni_range = radius * 1.4

func _process(delta: float) -> void:
	elapsed += delta
	var pulse = 0.5 + sin(elapsed * 18.0) * 0.5
	
	if ring_mat:
		ring_mat.albedo_color.a = 0.45 + pulse * 0.4
	if pillar_mat:
		pillar_mat.albedo_color.a = 0.15 + pulse * 0.2
	if light:
		light.light_energy = 4.0 + pulse * 6.0
	if label:
		label.scale = Vector3.ONE * (1.0 + pulse * 0.15)
	
	if elapsed >= duration + 2.5:
		queue_free()

func burst_and_free() -> void:
	queue_free()
