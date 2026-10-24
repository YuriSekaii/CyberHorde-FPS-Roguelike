extends Node

signal check_started()
signal check_completed(up_to_date: bool, behind_count: int, changelog: Array, error_msg: String)
signal update_started()
signal update_completed(success: bool, message: String)

var is_checking: bool = false
var is_updating: bool = false
var is_up_to_date: bool = true
var commits_behind: int = 0
var changelog_list: Array = []
var current_commit_hash: String = "unknown"
var current_branch_name: String = "main"
var last_check_error: String = ""

var _thread: Thread = null

func _init() -> void:
	_detect_local_git_info()

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_local_git_info()

func _ready() -> void:
	_detect_local_git_info()

func _exit_tree() -> void:
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()

func _get_project_dir() -> String:
	return ProjectSettings.globalize_path("res://")

func _detect_local_git_info() -> void:
	var proj_dir = _get_project_dir()
	var out: Array = []
	
	# Check git branch
	var err = OS.execute("git", ["-C", proj_dir, "rev-parse", "--abbrev-ref", "HEAD"], out, true)
	if err == 0 and out.size() > 0:
		var branch = out[0].strip_edges()
		if not branch.is_empty():
			current_branch_name = branch
	
	# Check git commit
	out.clear()
	err = OS.execute("git", ["-C", proj_dir, "rev-parse", "--short", "HEAD"], out, true)
	if err == 0 and out.size() > 0:
		var commit = out[0].strip_edges()
		if not commit.is_empty():
			current_commit_hash = commit

func check_for_updates() -> void:
	if is_checking or is_updating:
		return
	
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	
	is_checking = true
	check_started.emit()
	
	_thread = Thread.new()
	_thread.start(_worker_check_updates)

func _worker_check_updates() -> void:
	var proj_dir = _get_project_dir()
	var out: Array = []
	
	# 1. Verify git is present
	var err = OS.execute("git", ["--version"], out, true)
	if err != 0:
		_finish_check.call_deferred(false, 0, [], "Git executable not found in system PATH.")
		return
	
	# 2. Refresh local branch and commit
	out.clear()
	err = OS.execute("git", ["-C", proj_dir, "rev-parse", "--abbrev-ref", "HEAD"], out, true)
	var branch = out[0].strip_edges() if (err == 0 and out.size() > 0) else "main"
	if branch == "HEAD" or branch.is_empty():
		branch = "main"
	
	out.clear()
	err = OS.execute("git", ["-C", proj_dir, "rev-parse", "--short", "HEAD"], out, true)
	var commit = out[0].strip_edges() if (err == 0 and out.size() > 0) else "unknown"
	
	# 3. Fetch remote
	out.clear()
	err = OS.execute("git", ["-C", proj_dir, "fetch", "origin", branch], out, true)
	if err != 0:
		out.clear()
		err = OS.execute("git", ["-C", proj_dir, "fetch", "origin"], out, true)
		if err != 0:
			var fetch_err = out[0].strip_edges() if out.size() > 0 else "Unknown network error."
			_finish_check.call_deferred(false, 0, [], "Could not reach update server: %s" % fetch_err, branch, commit)
			return
	
	# 4. Check commits behind
	out.clear()
	var target_ref = "origin/" + branch
	err = OS.execute("git", ["-C", proj_dir, "rev-list", "HEAD.." + target_ref, "--count"], out, true)
	if err != 0:
		out.clear()
		err = OS.execute("git", ["-C", proj_dir, "rev-list", "HEAD..@{u}", "--count"], out, true)
	
	var behind = 0
	if err == 0 and out.size() > 0:
		behind = int(out[0].strip_edges())
	
	var changelog: Array = []
	if behind > 0:
		out.clear()
		var log_err = OS.execute("git", ["-C", proj_dir, "log", "HEAD.." + target_ref, "--oneline", "-n", "10"], out, true)
		if log_err == 0 and out.size() > 0:
			var lines = out[0].split("\n", false)
			for line in lines:
				var trimmed = line.strip_edges()
				if not trimmed.is_empty():
					changelog.append(trimmed)
	
	_finish_check.call_deferred(behind == 0, behind, changelog, "", branch, commit)

func _finish_check(up_to_date: bool, behind: int, cl: Array, err_msg: String, branch: String = "", commit: String = "") -> void:
	if _thread:
		_thread.wait_to_finish()
	
	is_checking = false
	is_up_to_date = up_to_date
	commits_behind = behind
	changelog_list = cl
	last_check_error = err_msg
	if not branch.is_empty():
		current_branch_name = branch
	if not commit.is_empty():
		current_commit_hash = commit
	
	check_completed.emit(up_to_date, behind, cl, err_msg)

func pull_updates() -> void:
	if is_updating or is_checking:
		return
	
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	
	is_updating = true
	update_started.emit()
	
	_thread = Thread.new()
	_thread.start(_worker_pull_updates)

func _worker_pull_updates() -> void:
	var proj_dir = _get_project_dir()
	var branch = current_branch_name if not current_branch_name.is_empty() else "main"
	var out: Array = []
	
	# Execute git pull origin <branch>
	var err = OS.execute("git", ["-C", proj_dir, "pull", "origin", branch], out, true)
	if err != 0:
		out.clear()
		err = OS.execute("git", ["-C", proj_dir, "pull"], out, true)
	
	var pull_msg = out[0].strip_edges() if out.size() > 0 else ""
	var success = (err == 0)
	
	var new_commit = ""
	if success:
		out.clear()
		var c_err = OS.execute("git", ["-C", proj_dir, "rev-parse", "--short", "HEAD"], out, true)
		if c_err == 0 and out.size() > 0:
			new_commit = out[0].strip_edges()
	
	_finish_pull.call_deferred(success, pull_msg, new_commit)

func _finish_pull(success: bool, pull_msg: String, new_commit: String) -> void:
	if _thread:
		_thread.wait_to_finish()
	
	is_updating = false
	if success:
		is_up_to_date = true
		commits_behind = 0
		changelog_list.clear()
		if not new_commit.is_empty():
			current_commit_hash = new_commit
		update_completed.emit(true, "Successfully updated! Current commit is now %s." % current_commit_hash)
	else:
		update_completed.emit(false, "Update failed: %s" % pull_msg)

func restart_game() -> void:
	if OS.has_method("set_restart_on_exit"):
		OS.set_restart_on_exit(true)
		get_tree().quit()
	else:
		OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
		get_tree().quit()
