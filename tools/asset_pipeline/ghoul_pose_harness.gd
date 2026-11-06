extends SceneTree
# Run: Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --script tools/asset_pipeline/ghoul_pose_harness.gd
# (create the folder D:/AI/gen/_ghoul_poses first, or set HARNESS_OUT to a folder + file prefix)
# Visual test: spawns the Blood Ghoul in a lit test scene, forces each animation state through its own
# _animate_pose (AI paused) and saves a screenshot per state. Run windowed (needs a real renderer).
var OUT: String = OS.get_environment("HARNESS_OUT") if OS.get_environment("HARNESS_OUT") != "" else "D:/AI/gen/_ghoul_poses/game_"
var ghoul: Node3D
var cam: Camera3D
var victim: Node3D
var shots: Array = []  # [name, state, pin_time, cam_pos, cam_target]
var idx: int = -1
var frames: int = 0

func _initialize() -> void:
	var world := Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.025, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.4, 0.6); env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var moon := DirectionalLight3D.new(); moon.light_color = Color(0.7, 0.78, 1.0); moon.light_energy = 1.2
	moon.rotation_degrees = Vector3(-35, 150, 0); moon.shadow_enabled = true; world.add_child(moon)
	var rim := OmniLight3D.new(); rim.light_color = Color(1, 0.15, 0.1); rim.light_energy = 3.0; rim.omni_range = 8
	rim.position = Vector3(1.5, 3, 2.5); rim.light_energy = 1.5; world.add_child(rim)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); ground.mesh = pm
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color(0.05, 0.07, 0.05); ground.material_override = gmat
	world.add_child(ground)
	cam = Camera3D.new(); cam.fov = 55; world.add_child(cam); cam.current = true
	victim = Node3D.new(); world.add_child(victim); victim.position = Vector3(0, 0.1, -1.0)
	ghoul = load("res://scenes/enemies/blood_ghoul.tscn").instantiate()
	world.add_child(ghoul)
	ghoul.global_position = Vector3.ZERO
	ghoul.rotation.y = 0.0
	ghoul.set_physics_process(false); ghoul.set_process(false)
	var S = ghoul.GhoulState
	var q34 := Vector3(-3.2, 2.2, -4.2)
	shots = [
		["rest_front", S.FLEEING, 0.0, Vector3(0, 1.8, -5.5), Vector3(0, 1.4, 0)],
		["hiding", S.HIDING, 0.0, q34, Vector3(0, 1.0, 0)],
		["stalk", S.HUNTING, 0.0, q34, Vector3(0, 1.4, 0)],
		["leap", S.LEAPING, 0.0, Vector3(-4.5, 1.8, -1.5), Vector3(0, 1.4, 0)],
		["pin_a", S.PINNING, 0.12, Vector3(-3.0, 1.6, -3.4), Vector3(0, 1.1, -0.5)],
		["pin_b", S.PINNING, 0.42, Vector3(-3.0, 1.6, -3.4), Vector3(0, 1.1, -0.5)],
		["pin_pov", S.PINNING, 0.42, Vector3(0, 0.25, -1.6), Vector3(0, 2.0, -0.2)],
		["fallen", S.FALLEN, 0.0, q34, Vector3(0, 0.6, 0)],
		["knockdown", S.KNOCKDOWN, 0.0, q34, Vector3(0, 1.0, 0)],
	]

func _process(delta: float) -> bool:
	if idx >= shots.size():
		return true
	if idx < 0 or frames > 90:
		if idx >= 0:
			var shot: String = shots[idx][0]
			_print_arm_angles(shot)
			var img: Image = root.get_texture().get_image()
			img.save_png(OUT + shot + ".png")
			print("SHOT ", shot)
		idx += 1; frames = 0
		if idx >= shots.size():
			print("HARNESS DONE"); quit(); return true
		var s: Array = shots[idx]
		ghoul.state = s[1]
		ghoul.pinned_player = victim if s[1] == ghoul.GhoulState.PINNING else null
		cam.global_position = s[3]; cam.look_at(s[4])
	var s = shots[idx]
	ghoul.anim_time += 1.0 / 60.0
	ghoul.state_timer += 1.0 / 60.0
	ghoul.pin_time = s[2] + (0.0 if frames > 60 else 0.0)
	ghoul._animate_pose(1.0 / 60.0)
	if s[0] == "pin_pov": # victim's camera, aimed the way the game aims it
		cam.look_at(ghoul.get_pin_focus_point())
	frames += 1
	return false

func _print_arm_angles(shot: String) -> void:
	var skel: Skeleton3D = ghoul.skeleton
	if skel == null or ghoul.arm_pivots.size() < 2 or ghoul.arm_elbows.size() < 2:
		return
	var pivots: Array[Node3D] = ghoul.arm_pivots as Array[Node3D]
	var elbows: Array[Node3D] = ghoul.arm_elbows as Array[Node3D]
	for i in range(2):
		var side: String = "L" if i == 0 else "R"
		var u_bone: String = "UpperArm." + side
		var f_bone: String = "Forearm." + side
		var h_bone: String = "Hand." + side
		var u_i: int = skel.find_bone(u_bone)
		var f_i: int = skel.find_bone(f_bone)
		var h_i: int = skel.find_bone(h_bone)
		var upper_deg: float = 0.0
		var fore_deg: float = 0.0
		var roll_deg: float = 0.0
		var back: float = 0.0
		var across: float = 0.0
		var elbow_angles: Vector3 = Vector3.ZERO
		var wrist_angles: Vector3 = Vector3.ZERO
		if u_i >= 0 and f_i >= 0 and h_i >= 0:
			var body_root_node: Node3D = ghoul.body_root
			var br_inv: Basis = body_root_node.global_transform.basis.inverse()
			var d: Vector3 = (br_inv * -pivots[i].global_transform.basis.y).normalized()
			back = rad_to_deg(asin(clampf(d.z, -1.0, 1.0)))
			across = rad_to_deg(asin(clampf(-d.x * signf(pivots[i].position.x), -1.0, 1.0)))
			var sg: Transform3D = skel.global_transform # bone poses are skeleton-local; pivots are world
			var pose_u: Transform3D = sg * skel.get_bone_global_pose(u_i)
			var pose_f: Transform3D = sg * skel.get_bone_global_pose(f_i)
			var pose_h: Transform3D = sg * skel.get_bone_global_pose(h_i)
			var upper_dir: Vector3 = (pose_f.origin - pose_u.origin).normalized()
			var fore_dir: Vector3 = (pose_h.origin - pose_f.origin).normalized()
			var pivot_down: Vector3 = -pivots[i].global_transform.basis.y
			var elbow_down: Vector3 = -elbows[i].global_transform.basis.y
			upper_deg = rad_to_deg(upper_dir.angle_to(pivot_down))
			fore_deg = rad_to_deg(fore_dir.angle_to(elbow_down))
			# Roll of the elbow hinge around the arm, from the body's left-right axis (natural: near 0)
			var right: Vector3 = ghoul.global_transform.basis.x
			var ref: Vector3 = (right - pivot_down * right.dot(pivot_down)).normalized()
			roll_deg = rad_to_deg(ref.signed_angle_to(pivots[i].global_transform.basis.x, pivot_down))
			elbow_angles = _bone_swing_twist_deg(skel, f_i)
			wrist_angles = _bone_swing_twist_deg(skel, h_i)
		print("ARM %s %s upper=%.2f fore=%.2f roll=%.1f back=%.1f across=%.1f elbow=(%.1f,%.1f,%.1f) wrist=(%.1f,%.1f,%.1f)" % [shot, side, upper_deg, fore_deg, roll_deg, back, across, elbow_angles.x, elbow_angles.y, elbow_angles.z, wrist_angles.x, wrist_angles.y, wrist_angles.z])

## Swing-twist of a bone's pose rotation vs its rest rotation, twist about local Y.
## Returns (flex_deg, side_deg, twist_deg), rounded to 1 decimal.
func _bone_swing_twist_deg(skel: Skeleton3D, idx: int) -> Vector3:
	var rest_rot: Quaternion = skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	var pose_rot: Quaternion = skel.get_bone_pose_rotation(idx)
	var rel: Quaternion = rest_rot.inverse() * pose_rot
	var twist: Quaternion = Quaternion(0.0, rel.y, 0.0, rel.w).normalized()
	var swing: Quaternion = rel * twist.inverse()
	var swing_vec: Vector3 = swing.get_axis() * swing.get_angle()
	var twist_angle: float = 2.0 * atan2(twist.y, twist.w)
	if twist_angle > PI:
		twist_angle -= 2.0 * PI
	elif twist_angle < -PI:
		twist_angle += 2.0 * PI
	return Vector3(
		roundf(rad_to_deg(swing_vec.x) * 10.0) / 10.0,
		roundf(rad_to_deg(swing_vec.z) * 10.0) / 10.0,
		roundf(rad_to_deg(twist_angle) * 10.0) / 10.0)
