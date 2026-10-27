extends Node3D

@export var type_id: int = 0
@export var duration: float = 3.0

var net_name: String = ""
var time_left: float = 3.0
var is_bursting: bool = false
var type_name: String = "Enemy"
var theme_color: Color = Color(1.0, 0.4, 0.1)
var base_radius: float = 1.3

@onready var outer_ring: MeshInstance3D = $MeshRoot/OuterRing
@onready var inner_disc: MeshInstance3D = $MeshRoot/InnerDisc
@onready var pillar: MeshInstance3D = $MeshRoot/Pillar
@onready var warning_light: OmniLight3D = $WarningLight
@onready var label: Label3D = $Label3D
@onready var sparks: CPUParticles3D = $Sparks
@onready var burst_particles: CPUParticles3D = $BurstParticles

var ring_mat: StandardMaterial3D
var disc_mat: StandardMaterial3D
var pillar_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("spawn_indicators")
	time_left = duration
	_setup_materials()
	_apply_theme()
	SoundManager.play("spawn_telegraph", 0.08, -6.0)

func setup(p_type_id: int, p_net_name: String, p_duration: float = 3.0) -> void:
	type_id = p_type_id
	net_name = p_net_name
	duration = p_duration
	time_left = p_duration
	_setup_materials()
	_apply_theme()

func _setup_materials() -> void:
	if ring_mat == null:
		ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if outer_ring:
			outer_ring.material_override = ring_mat
	
	if disc_mat == null:
		disc_mat = StandardMaterial3D.new()
		disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if inner_disc:
			inner_disc.material_override = disc_mat
	
	if pillar_mat == null:
		pillar_mat = StandardMaterial3D.new()
		pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if pillar:
			pillar.material_override = pillar_mat

func _apply_theme() -> void:
	match type_id:
		0: # Swarmer
			type_name = "Swarmer"
			theme_color = Color(1.0, 0.42, 0.08, 1.0)
			base_radius = 1.3
		1: # Spitter
			type_name = "Spitter"
			theme_color = Color(0.85, 0.25, 1.0, 1.0)
			base_radius = 1.5
		2: # Brute
			type_name = "Brute"
			theme_color = Color(1.0, 0.12, 0.12, 1.0)
			base_radius = 2.4
		3: # Boss: Apex Overlord
			type_name = "FINAL BOSS: APEX OVERLORD"
			theme_color = Color(1.0, 0.1, 0.25, 1.0)
			base_radius = 4.5
		4: # Charger
			type_name = "Charger"
			theme_color = Color(1.0, 0.55, 0.0, 1.0)
			base_radius = 2.0
		5: # Void Spawner
			type_name = "Void Spawner"
			theme_color = Color(0.75, 0.15, 1.0, 1.0)
			base_radius = 2.8
		6: # Volt Bomber
			type_name = "Bomber"
			theme_color = Color(1.0, 0.3, 0.05, 1.0)
			base_radius = 1.3
		7: # Photon Hornet
			type_name = "Hornet"
			theme_color = Color(0.45, 1.0, 0.15, 1.0)
			base_radius = 1.5
		_:
			type_name = "Enemy"
			theme_color = Color(1.0, 0.4, 0.1, 1.0)
			base_radius = 1.3
	
	if outer_ring and outer_ring.mesh is TorusMesh:
		var torus = outer_ring.mesh.duplicate() as TorusMesh
		torus.inner_radius = base_radius - 0.15
		torus.outer_radius = base_radius
		outer_ring.mesh = torus
	
	if inner_disc and inner_disc.mesh is CylinderMesh:
		var cyl = inner_disc.mesh.duplicate() as CylinderMesh
		cyl.top_radius = base_radius - 0.15
		cyl.bottom_radius = base_radius - 0.15
		inner_disc.mesh = cyl
	
	if pillar and pillar.mesh is CylinderMesh:
		var cyl = pillar.mesh.duplicate() as CylinderMesh
		cyl.top_radius = base_radius
		cyl.bottom_radius = base_radius
		if type_id == 5:
			# Void Spawner spawns in the sky: extend holographic beacon from ground to sky portal
			cyl.height = 9.0
			pillar.position.y = -4.25
		else:
			cyl.height = 3.5
			pillar.position.y = 1.75
		pillar.mesh = cyl
	
	if ring_mat:
		ring_mat.albedo_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.9)
	if disc_mat:
		disc_mat.albedo_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.35)
	if pillar_mat:
		pillar_mat.albedo_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.15)
	
	if warning_light:
		warning_light.light_color = theme_color
		warning_light.omni_range = base_radius * 2.8
	
	if label:
		label.modulate = theme_color
		label.outline_modulate = Color(0, 0, 0, 0.95)
	
	if sparks:
		sparks.color = theme_color
		sparks.emission_ring_radius = base_radius * 0.8
	
	if burst_particles:
		burst_particles.color = theme_color

func _process(delta: float) -> void:
	if is_bursting:
		return
	
	time_left -= delta
	
	# Continuous rotation
	if outer_ring:
		outer_ring.rotation.y += 2.2 * delta
	if inner_disc:
		inner_disc.rotation.y -= 1.4 * delta
	
	# Progress: 0.0 -> 1.0
	var progress = clampf(1.0 - (time_left / maxf(duration, 0.001)), 0.0, 1.0)
	
	# Disc scales from 0 to full radius as countdown progresses
	if inner_disc:
		var s = maxf(0.01, progress)
		inner_disc.scale = Vector3(s, 1.0, s)
	
	# Pulse faster as emergence approaches
	var pulse_speed = lerpf(16.0, 4.0, clampf(time_left / duration, 0.0, 1.0))
	var pulse = (sin(Time.get_ticks_msec() * 0.001 * pulse_speed) + 1.0) * 0.5
	
	if warning_light:
		warning_light.light_energy = lerpf(1.0, 3.2, pulse)
	
	if pillar_mat:
		pillar_mat.albedo_color.a = lerpf(0.08, 0.28, pulse)
	
	# Update 3D billboard text
	if label:
		if time_left > 0.4:
			label.text = "⚠ %s (%.1fs)" % [type_name.to_upper(), maxf(0.0, time_left)]
		else:
			label.text = "⚠ %s SPAWNING!" % type_name.to_upper()

func burst_and_free() -> void:
	if is_bursting:
		return
	is_bursting = true
	
	if label:
		label.visible = false
	if inner_disc:
		inner_disc.visible = false
	if pillar:
		pillar.visible = false
	
	if burst_particles:
		burst_particles.restart()
		burst_particles.emitting = true
	
	if warning_light:
		warning_light.light_energy = 4.5
	
	# Flash and expand outer ring
	if outer_ring:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(outer_ring, "scale", Vector3(1.6, 1.0, 1.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if ring_mat:
			tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.25)
		if warning_light:
			tw.tween_property(warning_light, "light_energy", 0.0, 0.25)
	
	get_tree().create_timer(0.3).timeout.connect(queue_free)
