extends Node3D

## Toxic puddle left by a Spore Pit mortar impact. Lasts 3s; any operative standing inside keeps getting
## Poison (same dose as Wyvern venom: 5 dmg/s x wave damage factor, 25% slow, 3s after leaving).

const DURATION: float = 3.0
const POISON_BASE_DPS: float = 5.0
const FADE_TIME: float = 0.5
const ZONE_COLOR := Color(0.45, 0.95, 0.15)

var radius: float = 5.0
var elapsed: float = 0.0
var poison_dps: float = POISON_BASE_DPS
var mat: StandardMaterial3D

func setup(p_radius: float) -> void:
	radius = p_radius
	poison_dps = POISON_BASE_DPS * GameManager.get_wave_damage_factor()
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(ZONE_COLOR, 0.35)
	mat.disable_receive_shadows = true
	var disc = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.06
	disc.radial_segments = 48
	disc.material = mat
	var mi = MeshInstance3D.new()
	mi.mesh = disc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.08
	add_child(mi)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	# Toxic shimmer, fading out over the last half second
	var fade = clampf((DURATION - elapsed) / FADE_TIME, 0.0, 1.0)
	mat.albedo_color.a = (0.3 + 0.08 * sin(elapsed * 9.0)) * fade
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p.has_method("apply_poison"):
			continue
		var d = p.global_position - global_position
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) <= 3.0:
			p.apply_poison(poison_dps)
