extends CanvasLayer

@onready var waves_label: Label = $Panel/VBoxContainer/StatsGrid/WavesVal
@onready var kills_label: Label = $Panel/VBoxContainer/StatsGrid/KillsVal
@onready var damage_label: Label = $Panel/VBoxContainer/StatsGrid/DmgVal
@onready var scrap_label: Label = $Panel/VBoxContainer/StatsGrid/ScrapVal
@onready var level_label: Label = $Panel/VBoxContainer/StatsGrid/LevelVal
@onready var time_label: Label = $Panel/VBoxContainer/StatsGrid/TimeVal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.game_over_triggered.connect(_on_game_over)

func _on_game_over() -> void:
	visible = true
	waves_label.text = str(GameManager.current_wave)
	kills_label.text = str(GameManager.enemies_killed)
	damage_label.text = str(int(GameManager.total_damage_dealt))
	scrap_label.text = str(GameManager.scrap)
	level_label.text = str(GameManager.player_level)
	
	var mins = int(GameManager.run_time) / 60
	var secs = int(GameManager.run_time) % 60
	time_label.text = "%02d:%02d" % [mins, secs]

func _on_restart_pressed() -> void:
	visible = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
