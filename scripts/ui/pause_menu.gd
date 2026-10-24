extends CanvasLayer

@onready var sensitivity_slider: HSlider = $Panel/VBoxContainer/SensContainer/HSlider
@onready var sens_label: Label = $Panel/VBoxContainer/SensContainer/SensValueLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if sensitivity_slider:
		sensitivity_slider.value = 2.2
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.state == GameManager.GameState.PLAYING:
			open_pause()
		elif GameManager.state == GameManager.GameState.PAUSED:
			resume()

func open_pause() -> void:
	visible = true
	GameManager.state = GameManager.GameState.PAUSED
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume() -> void:
	visible = false
	GameManager.resume_game()

func restart_run() -> void:
	visible = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func quit_game() -> void:
	get_tree().quit()

func _on_sensitivity_changed(value: float) -> void:
	sens_label.text = "%.1f" % value
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].set("MOUSE_SENSITIVITY", value * 0.001)

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	restart_run()

func _on_quit_pressed() -> void:
	quit_game()
