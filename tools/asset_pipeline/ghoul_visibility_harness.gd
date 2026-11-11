extends SceneTree
# Run: Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --script tools/asset_pipeline/ghoul_visibility_harness.gd
# Stage 2 boss fight check: real jungle arena under the blood moon, Blood Ghoul hiding (AI paused) under
# random trees, screenshots from a player's eye height at several distances. Output: HARNESS_OUT prefix.
var OUT: String = OS.get_environment("HARNESS_OUT") if OS.get_environment("HARNESS_OUT") != "" else "D:/AI/gen/_ghoul_vis/vis_"
var arena: Node3D
var ghoul: Node3D
var cam: Camera3D
var shots: Array = [] # [name, hide_spot, distance]
var idx: int = -1
var frames: int = 0

func _initialize() -> void:
	arena = load("res://scenes/world/jungle_arena.tscn").instantiate()
	root.add_child(arena)
	cam = Camera3D.new(); cam.fov = 75; root.add_child(cam); cam.current = true
	ghoul = load("res://scenes/enemies/blood_ghoul.tscn").instantiate()
	root.add_child(ghoul)
	ghoul.set_physics_process(false)

func _setup_shots() -> void:
	arena.set_blood_moon(true, false)
	var spots: Array = arena.get_hide_spots()
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 3:
		var s: Vector3 = spots[rng.randi() % spots.size()]
		for d in [12.0, 20.0]:
			shots.append(["tree%d_%dm" % [i, int(d)], s, d, rng.randf() * TAU])

func _process(_delta: float) -> bool:
	if idx == -1 and frames == 2:
		_setup_shots()
	if idx >= shots.size():
		return true
	frames += 1
	if idx >= 0:
		ghoul.anim_time += 1.0 / 60.0
		ghoul._animate_pose(1.0 / 60.0)
	if idx < 0 and frames < 5:
		return false
	if idx < 0 or frames > 60:
		if idx >= 0:
			root.get_texture().get_image().save_png(OUT + shots[idx][0] + ".png")
			print("SHOT ", shots[idx][0], " ghoul=", ghoul.global_position, " pupil=", ghoul.pupil_mat, " emis=", ghoul.pupil_mat.emission_energy_multiplier if ghoul.pupil_mat else -1, " onscreen=", cam.is_position_in_frustum(ghoul.global_position + Vector3(0,1,0)), " state=", ghoul.state, " emisOn=", ghoul.pupil_mat.emission_enabled, " ecol=", ghoul.pupil_mat.emission, " lurk=", ghoul._is_lurking(), " vis=", ghoul.is_visible_in_tree())
		idx += 1; frames = 0
		if idx < shots.size():
			var spot: Vector3 = shots[idx][1]
			var a: float = shots[idx][3]
			var eye: Vector3 = spot + Vector3(cos(a), 0, sin(a)) * shots[idx][2] + Vector3(0, 1.7, 0)
			ghoul.global_position = spot
			if OS.get_environment("MARK") != "": ghoul.add_child(_marker())
			ghoul.state = ghoul.GhoulState.HIDING
			ghoul.look_at(Vector3(eye.x, spot.y, eye.z), Vector3.UP, true)
			cam.global_position = eye
			cam.look_at(spot + Vector3(0, 0.8, 0))
	return false

func _marker() -> MeshInstance3D:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.15; s.height = 0.3; m.mesh = s
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color.GREEN
	m.material_override = mat; m.position.y = 1.5
	return m
