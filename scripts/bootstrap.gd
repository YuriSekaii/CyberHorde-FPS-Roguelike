extends Control

func _ready() -> void:
	var needs_import: bool = false
	
	# Check if class cache exists
	if not FileAccess.file_exists("res://.godot/global_script_class_cache.cfg"):
		needs_import = true
	# Check if imported folder and critical textures exist
	elif not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://.godot/imported")):
		needs_import = true
	elif not FileAccess.file_exists("res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"):
		needs_import = true
	elif not FileAccess.file_exists("res://.godot/imported/medic_restore.svg-53aa694cd1713db7c7194bf49f75a81a.ctex"):
		needs_import = true
	elif not FileAccess.file_exists("res://.godot/imported/rogue_dash.svg-d7731bc005b556918d30660279fad2f9.ctex"):
		needs_import = true
	elif not FileAccess.file_exists("res://.godot/imported/gunner_berserk.svg-d0b99a14b3d74619aa1bba348156f138.ctex"):
		needs_import = true

	if needs_import:
		# Give a frame for UI to show
		await get_tree().process_frame
		
		var proj_path: String = ProjectSettings.globalize_path("res://")
		var out: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--editor", "--quit", "--path", proj_path], out, true)
		
		# Restart the engine process so Godot re-indexes global class names and loads newly imported assets
		var args: PackedStringArray = OS.get_cmdline_args()
		OS.create_process(OS.get_executable_path(), args)
		get_tree().quit()
		return
	
	# Assets are already imported and verified - transition immediately to main scene
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
