extends Node3D

## Stage 2 arena: moonlit night jungle.
## Same 80x80 footprint, perimeter walls and invisible sky barriers as Stage 1, but all flat ground:
## no center platform, no ramps, no jump pads. Trees are the only cover. The Moon is the only light source,
## so each tree canopy throws a near pitch-black shadow pool on the grass beneath it (where the Blood Ghoul hides).
## The layout uses a fixed seed so every co-op peer builds the identical jungle.

const ARENA_HALF: float = 40.0
const TREE_SEED: int = 51723
const TREE_COUNT: int = 26
const TREE_MIN_SPACING: float = 9.0
const TREE_PLACEMENT_RANGE: float = 33.0
const CENTER_CLEAR_RADIUS: float = 9.0 # squad spawn area stays open
const GRASS_TUFT_COUNT: int = 16000
const HIDE_SPOT_TRUNK_GAP: float = 1.4 # gap between a trunk's surface and the hide spot

# Moon: high enough that canopy shadows pool beside each trunk, low enough to be seen above the treeline
const MOON_PITCH_DEG: float = -52.0
const MOON_YAW_DEG: float = 32.0
const MOON_DISTANCE: float = 420.0

const NIGHT_MOON_COLOR := Color(0.62, 0.72, 1.0)
const NIGHT_MOON_ENERGY: float = 1.625
const NIGHT_DISC_COLOR := Color(0.92, 0.95, 1.0)
const NIGHT_SKY_TOP := Color(0.008, 0.012, 0.035)
const NIGHT_SKY_HORIZON := Color(0.035, 0.05, 0.09)
const NIGHT_FOG := Color(0.02, 0.03, 0.05)
const NIGHT_AMBIENT := Color(0.3, 0.38, 0.6)

const BLOOD_MOON_COLOR := Color(1.0, 0.22, 0.16)
const BLOOD_MOON_ENERGY: float = 1.625
const BLOOD_DISC_COLOR := Color(1.0, 0.12, 0.06)
const BLOOD_SKY_TOP := Color(0.04, 0.003, 0.004)
const BLOOD_SKY_HORIZON := Color(0.12, 0.015, 0.012)
const BLOOD_FOG := Color(0.07, 0.008, 0.008)
const BLOOD_AMBIENT := Color(0.6, 0.12, 0.1)

const GRASS_SHADER_CODE: String = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 root_color : source_color = vec3(0.02, 0.07, 0.025);
uniform vec3 tip_color : source_color = vec3(0.09, 0.3, 0.06);

void vertex() {
	float h = UV.y;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.4 + world_pos.x * 0.31 + world_pos.z * 0.23) * 0.09 * h * h;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, UV.y) * COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
"""

## Per tree: { "pos": Vector3 (trunk base), "trunk_radius": float, "canopy_center": Vector3, "canopy_radius": float, "hide_spot": Vector3 }
var trees: Array[Dictionary] = []
var is_blood_moon: bool = false

var environment: Environment
var sky_material: ProceduralSkyMaterial
var moon_light: DirectionalLight3D
var moon_disc_material: StandardMaterial3D
var geometry: Node3D
var navigation_region: NavigationRegion3D

func _ready() -> void:
	add_to_group("jungle_arena")
	_build_environment()
	_build_moon()
	geometry = Node3D.new()
	geometry.name = "Geometry"
	geometry.add_to_group("navigation_geometry")
	add_child(geometry)
	_build_ground_and_walls()
	_build_trees()
	_build_grass()
	_build_treeline()
	_build_navigation()
	GameManager.wave_started.connect(_on_wave_started)
	if GameManager.current_stage >= 2 and GameManager.current_wave >= 50:
		set_blood_moon(true, false)

func _on_wave_started(wave_num: int) -> void:
	if GameManager.current_stage >= 2 and wave_num >= 50 and not is_blood_moon:
		set_blood_moon(true)

# ----------------- PUBLIC API -----------------

## Ground points inside each tree's moon shadow (pitch black), used by the Blood Ghoul to hide
func get_hide_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for t in trees:
		spots.append(t["hide_spot"])
	return spots

## Final wave: the Moon turns blood red
func set_blood_moon(enabled: bool, animate: bool = true) -> void:
	is_blood_moon = enabled
	var light_col = BLOOD_MOON_COLOR if enabled else NIGHT_MOON_COLOR
	var light_energy = BLOOD_MOON_ENERGY if enabled else NIGHT_MOON_ENERGY
	var disc_col = BLOOD_DISC_COLOR if enabled else NIGHT_DISC_COLOR
	var sky_top = BLOOD_SKY_TOP if enabled else NIGHT_SKY_TOP
	var sky_hor = BLOOD_SKY_HORIZON if enabled else NIGHT_SKY_HORIZON
	var fog_col = BLOOD_FOG if enabled else NIGHT_FOG
	var amb_col = BLOOD_AMBIENT if enabled else NIGHT_AMBIENT
	if not animate:
		moon_light.light_color = light_col
		moon_light.light_energy = light_energy
		moon_disc_material.albedo_color = disc_col
		moon_disc_material.emission = disc_col
		sky_material.sky_top_color = sky_top
		sky_material.sky_horizon_color = sky_hor
		sky_material.ground_horizon_color = sky_hor
		environment.fog_light_color = fog_col
		environment.ambient_light_color = amb_col
		return
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(moon_light, "light_color", light_col, 4.0)
	tw.tween_property(moon_light, "light_energy", light_energy, 4.0)
	tw.tween_property(moon_disc_material, "albedo_color", disc_col, 4.0)
	tw.tween_property(moon_disc_material, "emission", disc_col, 4.0)
	tw.tween_property(sky_material, "sky_top_color", sky_top, 4.0)
	tw.tween_property(sky_material, "sky_horizon_color", sky_hor, 4.0)
	tw.tween_property(sky_material, "ground_horizon_color", sky_hor, 4.0)
	tw.tween_property(environment, "fog_light_color", fog_col, 4.0)
	tw.tween_property(environment, "ambient_light_color", amb_col, 4.0)

# ----------------- BUILDERS -----------------

func _build_environment() -> void:
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = NIGHT_SKY_TOP
	sky_material.sky_horizon_color = NIGHT_SKY_HORIZON
	sky_material.ground_bottom_color = Color(0.004, 0.006, 0.008)
	sky_material.ground_horizon_color = NIGHT_SKY_HORIZON
	sky_material.sun_angle_max = 7.0
	sky_material.sun_curve = 0.08
	var sky = Sky.new()
	sky.sky_material = sky_material

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Near-zero ambient so shaded ground under the canopy is almost pure black
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = NIGHT_AMBIENT
	environment.ambient_light_energy = 0.045
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.25
	environment.glow_enabled = true
	environment.set_glow_level(0, 0.0)
	environment.set_glow_level(1, 0.6)
	environment.set_glow_level(2, 0.5)
	environment.set_glow_level(3, 0.3)
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.05
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.fog_enabled = true
	environment.fog_light_color = NIGHT_FOG
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.011
	environment.fog_sky_affect = 0.25

	var we = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)

func _build_moon() -> void:
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.rotation_degrees = Vector3(MOON_PITCH_DEG, MOON_YAW_DEG, 0.0)
	moon_light.light_color = NIGHT_MOON_COLOR
	moon_light.light_energy = NIGHT_MOON_ENERGY
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.04
	moon_light.shadow_blur = 1.5
	moon_light.directional_shadow_max_distance = 110.0
	moon_light.light_angular_distance = 1.2
	add_child(moon_light)

	# Visible moon disc far out along the light's source direction (fog-exempt, unlit)
	moon_disc_material = StandardMaterial3D.new()
	moon_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_disc_material.albedo_color = NIGHT_DISC_COLOR
	moon_disc_material.emission_enabled = true
	moon_disc_material.emission = NIGHT_DISC_COLOR
	moon_disc_material.set("disable_fog", true)
	var disc_mesh = SphereMesh.new()
	disc_mesh.radius = 22.0
	disc_mesh.height = 44.0
	disc_mesh.material = moon_disc_material
	var disc = MeshInstance3D.new()
	disc.name = "MoonDisc"
	disc.mesh = disc_mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	disc.position = -_moon_ray() * MOON_DISTANCE

## Direction moonlight travels (from the Moon toward the ground)
func _moon_ray() -> Vector3:
	return -Basis.from_euler(Vector3(deg_to_rad(MOON_PITCH_DEG), deg_to_rad(MOON_YAW_DEG), 0.0)).z

func _make_material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _add_static_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material, layer: int = 1, visible_mesh: bool = true) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0 if layer != 1 else 1
	parent.add_child(body)
	body.position = pos
	var shape = BoxShape3D.new()
	shape.size = size
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	if visible_mesh:
		var mesh = BoxMesh.new()
		mesh.size = size
		mesh.material = mat
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)
	return body

func _build_ground_and_walls() -> void:
	var floor_mat = _make_material(Color(0.04, 0.075, 0.035), 1.0)
	var wall_mat = _make_material(Color(0.018, 0.035, 0.022), 1.0)
	_add_static_box(geometry, "Floor", Vector3(0, -0.5, 0), Vector3(80, 1, 80), floor_mat)
	# Perimeter walls (dense hedge) — same footprint as Stage 1
	_add_static_box(geometry, "WallNorth", Vector3(0, 4, -40), Vector3(82, 8, 2), wall_mat)
	_add_static_box(geometry, "WallSouth", Vector3(0, 4, 40), Vector3(82, 8, 2), wall_mat)
	_add_static_box(geometry, "WallEast", Vector3(40, 4, 0), Vector3(2, 8, 82), wall_mat)
	_add_static_box(geometry, "WallWest", Vector3(-40, 4, 0), Vector3(2, 8, 82), wall_mat)
	# Invisible upper barriers (Layer 5): stop bodies leaving the arena, let projectiles fly through
	_add_static_box(geometry, "BarrierNorth", Vector3(0, 28, -40), Vector3(82, 40, 2), null, 16, false)
	_add_static_box(geometry, "BarrierSouth", Vector3(0, 28, 40), Vector3(82, 40, 2), null, 16, false)
	_add_static_box(geometry, "BarrierEast", Vector3(40, 28, 0), Vector3(2, 40, 82), null, 16, false)
	_add_static_box(geometry, "BarrierWest", Vector3(-40, 28, 0), Vector3(2, 40, 82), null, 16, false)
	_add_static_box(geometry, "BarrierCeiling", Vector3(0, 48, 0), Vector3(82, 2, 82), null, 16, false)

func _build_trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var bark_mat = _make_material(Color(0.07, 0.05, 0.035), 1.0)
	var leaf_mats: Array[StandardMaterial3D] = [
		_make_material(Color(0.03, 0.075, 0.035), 0.95),
		_make_material(Color(0.025, 0.06, 0.04), 0.95),
		_make_material(Color(0.04, 0.08, 0.03), 0.95),
	]
	var moon_ray = _moon_ray()
	var placed: Array[Vector3] = []
	var attempts = 0
	while placed.size() < TREE_COUNT and attempts < 4000:
		attempts += 1
		var p = Vector3(rng.randf_range(-TREE_PLACEMENT_RANGE, TREE_PLACEMENT_RANGE), 0.0, rng.randf_range(-TREE_PLACEMENT_RANGE, TREE_PLACEMENT_RANGE))
		if Vector2(p.x, p.z).length() < CENTER_CLEAR_RADIUS:
			continue
		var ok = true
		for q in placed:
			if p.distance_to(q) < TREE_MIN_SPACING:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)

		var trunk_r = rng.randf_range(0.5, 0.85)
		var canopy_y = rng.randf_range(7.0, 9.5)
		var canopy_r = rng.randf_range(4.2, 5.6)
		var idx = placed.size() - 1

		var body = StaticBody3D.new()
		body.name = "Tree_%d" % idx
		body.collision_layer = 1
		body.collision_mask = 1
		geometry.add_child(body)
		body.position = p

		var trunk_shape = CylinderShape3D.new()
		trunk_shape.radius = trunk_r
		trunk_shape.height = canopy_y
		var col = CollisionShape3D.new()
		col.shape = trunk_shape
		col.position = Vector3(0, canopy_y * 0.5, 0)
		body.add_child(col)

		var trunk_mesh = CylinderMesh.new()
		trunk_mesh.top_radius = trunk_r * 0.65
		trunk_mesh.bottom_radius = trunk_r * 1.1
		trunk_mesh.height = canopy_y + 1.0
		trunk_mesh.radial_segments = 10
		trunk_mesh.material = bark_mat
		var trunk = MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.position = Vector3(0, (canopy_y + 1.0) * 0.5, 0)
		body.add_child(trunk)

		# Buttress roots
		for r in range(4):
			var root_mesh = BoxMesh.new()
			root_mesh.size = Vector3(0.28, 0.7, 1.5)
			root_mesh.material = bark_mat
			var root = MeshInstance3D.new()
			root.mesh = root_mesh
			var ang = TAU * float(r) / 4.0 + rng.randf_range(-0.4, 0.4)
			root.rotation = Vector3(0.45, ang, 0.0)
			root.position = Vector3(sin(ang) * (trunk_r + 0.35), 0.25, cos(ang) * (trunk_r + 0.35))
			body.add_child(root)

		# Canopy: a big crown plus offset lobes; these are what cast the pitch-black shadow pool
		var canopy_center = p + Vector3(0, canopy_y, 0)
		var lobes = [Vector3.ZERO, Vector3(1.6, -0.6, 0.9), Vector3(-1.4, -0.4, -1.2), Vector3(0.4, 0.9, -1.5)]
		for li in range(lobes.size()):
			var lr = canopy_r * (1.0 if li == 0 else rng.randf_range(0.55, 0.75))
			var leaf_mesh = SphereMesh.new()
			leaf_mesh.radius = lr
			leaf_mesh.height = lr * 1.4
			leaf_mesh.radial_segments = 14
			leaf_mesh.rings = 7
			leaf_mesh.material = leaf_mats[rng.randi_range(0, leaf_mats.size() - 1)]
			var leaf = MeshInstance3D.new()
			leaf.mesh = leaf_mesh
			leaf.position = Vector3(0, canopy_y, 0) + lobes[li].rotated(Vector3.UP, rng.randf() * TAU) * (canopy_r * 0.35)
			body.add_child(leaf)

		# Hide spot: where the canopy's moon shadow lands on the ground, kept clear of the trunk
		var shadow_center = canopy_center + moon_ray * (canopy_center.y / maxf(0.2, -moon_ray.y))
		var offset = Vector3(shadow_center.x - p.x, 0.0, shadow_center.z - p.z)
		var min_gap = trunk_r + HIDE_SPOT_TRUNK_GAP
		if offset.length() < min_gap:
			offset = (offset.normalized() if offset.length_squared() > 0.001 else Vector3(1, 0, 0)) * min_gap
		var hide = p + offset
		hide.x = clampf(hide.x, -36.0, 36.0)
		hide.z = clampf(hide.z, -36.0, 36.0)
		hide.y = 0.0

		trees.append({
			"pos": p,
			"trunk_radius": trunk_r,
			"canopy_center": canopy_center,
			"canopy_radius": canopy_r,
			"hide_spot": hide,
		})

func _build_grass() -> void:
	# One tuft = 3 crossed blades (single triangles); UV.y runs 0 at the root to 1 at the tip for shading & sway
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in range(3):
		var ang = TAU * float(b) / 3.0 + 0.3
		var side = Vector3(cos(ang), 0.0, sin(ang)) * 0.06
		var lean = Vector3(-sin(ang), 0.0, cos(ang)) * 0.12
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(-side)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(side)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(Vector3(0, 1.0, 0) + lean)
	var tuft_mesh = st.commit()

	var shader = Shader.new()
	shader.code = GRASS_SHADER_CODE
	var mat = ShaderMaterial.new()
	mat.shader = shader
	tuft_mesh.surface_set_material(0, mat)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft_mesh
	mm.instance_count = GRASS_TUFT_COUNT
	var rng = RandomNumberGenerator.new()
	rng.seed = TREE_SEED + 1
	for i in range(GRASS_TUFT_COUNT):
		var pos = Vector3(rng.randf_range(-38.8, 38.8), 0.0, rng.randf_range(-38.8, 38.8))
		var h = rng.randf_range(0.35, 0.75)
		var w = rng.randf_range(0.8, 1.5)
		var basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var tint = rng.randf_range(0.75, 1.25)
		mm.set_instance_color(i, Color(tint * rng.randf_range(0.85, 1.0), tint, tint * rng.randf_range(0.8, 1.0)))

	var grass = MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = mm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)

func _build_treeline() -> void:
	# Silhouette trees outside the walls so the horizon reads as endless jungle (visual only, no collision)
	var rng = RandomNumberGenerator.new()
	rng.seed = TREE_SEED + 2
	var dark_leaf = _make_material(Color(0.012, 0.025, 0.016), 1.0)
	var dark_bark = _make_material(Color(0.02, 0.015, 0.012), 1.0)
	var crown_mesh = SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 1.5
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 5
	crown_mesh.material = dark_leaf
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.6
	trunk_mesh.bottom_radius = 0.9
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = dark_bark

	var count = 72
	var crowns = MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = crown_mesh
	crowns.instance_count = count
	var trunks = MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = count
	for i in range(count):
		var side = i % 4
		var along = rng.randf_range(-48.0, 48.0)
		var depth = rng.randf_range(43.0, 52.0)
		var p: Vector3
		match side:
			0: p = Vector3(along, 0, -depth)
			1: p = Vector3(along, 0, depth)
			2: p = Vector3(depth, 0, along)
			_: p = Vector3(-depth, 0, along)
		var height = rng.randf_range(11.0, 17.0)
		var crown_r = rng.randf_range(4.5, 7.0)
		trunks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, height, 1)), p + Vector3(0, height * 0.5, 0)))
		crowns.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(crown_r, crown_r, crown_r)), p + Vector3(0, height, 0)))
	for mm in [crowns, trunks]:
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _build_navigation() -> void:
	# Same agent settings as Stage 1's navmesh; baked from the floor, walls and tree trunks
	var nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"navigation_geometry"
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_height = 2.25
	nav_mesh.agent_radius = 1.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.agent_max_slope = 40.0
	nav_mesh.region_min_size = 8.0
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "Navigation"
	navigation_region.navigation_mesh = nav_mesh
	add_child(navigation_region)
	navigation_region.bake_navigation_mesh(false)
