extends CanvasLayer

@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolContainer/MasterSlider
@onready var master_val_label: Label = $Panel/VBoxContainer/MasterVolContainer/MasterValLabel
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SfxVolContainer/SfxSlider
@onready var sfx_val_label: Label = $Panel/VBoxContainer/SfxVolContainer/SfxValLabel
@onready var sensitivity_slider: HSlider = $Panel/VBoxContainer/SensContainer/HSlider
@onready var sens_label: Label = $Panel/VBoxContainer/SensContainer/SensValueLabel
@onready var window_mode_btn: Button = $Panel/VBoxContainer/DisplayContainer/WindowModeBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if master_slider:
		master_slider.value = SoundManager.master_volume * 100.0
		master_val_label.text = "%d%%" % int(master_slider.value)
		master_slider.value_changed.connect(_on_master_volume_changed)
	
	if sfx_slider:
		sfx_slider.value = SoundManager.sfx_volume * 100.0
		sfx_val_label.text = "%d%%" % int(sfx_slider.value)
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if sensitivity_slider:
		sensitivity_slider.value = 2.2
		sens_label.text = "%.1f" % sensitivity_slider.value
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	_update_window_mode_ui()
	GameManager.window_mode_changed.connect(_on_window_mode_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.state == GameManager.GameState.PLAYING:
			open_pause()
		elif GameManager.state == GameManager.GameState.PAUSED:
			resume()
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.physical_keycode == KEY_M:
			_on_window_mode_pressed()
			get_viewport().set_input_as_handled()

func open_pause() -> void:
	visible = true
	_update_window_mode_ui()
	GameManager.state = GameManager.GameState.PAUSED
	if not NetworkManager.is_multiplayer:
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

func _on_master_volume_changed(value: float) -> void:
	if master_val_label:
		master_val_label.text = "%d%%" % int(value)
	SoundManager.set_master_volume(value / 100.0)

func _on_sfx_volume_changed(value: float) -> void:
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(value)
	SoundManager.set_sfx_volume(value / 100.0)
	SoundManager.play("hitmarker", 0.0, 0.0)

func _on_sensitivity_changed(value: float) -> void:
	sens_label.text = "%.1f" % value
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].set("mouse_sensitivity", value * 0.001)

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	restart_run()

func _on_quit_pressed() -> void:
	quit_game()

func _update_window_mode_ui() -> void:
	if window_mode_btn:
		if GameManager.is_fullscreen():
			window_mode_btn.text = "🔲 FULLSCREEN"
		else:
			window_mode_btn.text = "🗗 WINDOWED"

func _on_window_mode_pressed() -> void:
	SoundManager.play("upgrade_select", 0.05, 0.0)
	GameManager.toggle_fullscreen()

func _on_window_mode_changed(_is_fullscreen: bool) -> void:
	_update_window_mode_ui()
