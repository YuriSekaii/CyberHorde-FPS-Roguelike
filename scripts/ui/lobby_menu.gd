extends CanvasLayer

signal mission_started()

@onready var main_buttons: VBoxContainer = $Panel/VBoxContainer/MainButtons
@onready var host_container: VBoxContainer = $Panel/VBoxContainer/HostContainer
@onready var join_container: VBoxContainer = $Panel/VBoxContainer/JoinContainer
@onready var update_container: VBoxContainer = $Panel/VBoxContainer/UpdateContainer

@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var host_ip_label: Label = $Panel/VBoxContainer/HostContainer/HostIPLabel
@onready var host_port_input: LineEdit = $Panel/VBoxContainer/HostContainer/PortContainer/HostPortInput
@onready var start_squad_btn: Button = $Panel/VBoxContainer/HostContainer/StartSquadBtn
@onready var peer_list_label: Label = $Panel/VBoxContainer/HostContainer/PeerListLabel

@onready var join_ip_input: LineEdit = $Panel/VBoxContainer/JoinContainer/IPContainer/JoinIPInput
@onready var join_port_input: LineEdit = $Panel/VBoxContainer/JoinContainer/PortContainer/JoinPortInput
@onready var connect_btn: Button = $Panel/VBoxContainer/JoinContainer/ConnectBtn

@onready var update_btn: Button = $Panel/VBoxContainer/MainButtons/UpdateBtn
@onready var window_mode_btn: Button = $Panel/VBoxContainer/MainButtons/WindowModeBtn
@onready var version_info_label: Label = $Panel/VBoxContainer/UpdateContainer/VersionInfoLabel
@onready var update_status_label: Label = $Panel/VBoxContainer/UpdateContainer/UpdateStatusLabel
@onready var changelog_box: PanelContainer = $Panel/VBoxContainer/UpdateContainer/ChangelogBox
@onready var changelog_label: Label = $Panel/VBoxContainer/UpdateContainer/ChangelogBox/Margin/ChangelogLabel
@onready var pull_update_btn: Button = $Panel/VBoxContainer/UpdateContainer/ActionButtons/PullUpdateBtn
@onready var restart_btn: Button = $Panel/VBoxContainer/UpdateContainer/ActionButtons/RestartBtn
@onready var check_again_btn: Button = $Panel/VBoxContainer/UpdateContainer/ActionButtons/CheckAgainBtn
@onready var version_footer: Label = $Panel/VBoxContainer/VersionFooter

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_show_main_view()
	
	NetworkManager.connection_status_changed.connect(_on_status_changed)
	NetworkManager.peer_connected_signal.connect(_on_peers_updated)
	NetworkManager.peer_disconnected_signal.connect(_on_peers_updated)
	
	UpdateManager.check_completed.connect(_on_update_check_completed)
	UpdateManager.update_completed.connect(_on_update_completed)
	
	GameManager.window_mode_changed.connect(_on_window_mode_changed)
	_update_window_mode_btn()
	
	_update_footer_version()
	
	# Run a quiet background update check at game launch
	UpdateManager.check_for_updates()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if not (focus_owner is LineEdit or focus_owner is TextEdit):
			if event.keycode == KEY_M or event.physical_keycode == KEY_M:
				_on_window_mode_pressed()
				get_viewport().set_input_as_handled()

func _update_footer_version() -> void:
	if version_footer:
		version_footer.text = "CyberHorde • Build %s • branch: %s" % [UpdateManager.current_commit_hash, UpdateManager.current_branch_name]

func _show_main_view() -> void:
	main_buttons.visible = true
	host_container.visible = false
	join_container.visible = false
	update_container.visible = false
	status_label.text = "Select deployment mode."
	_update_footer_version()

func _on_solo_pressed() -> void:
	NetworkManager.start_singleplayer()
	visible = false
	mission_started.emit()

func _on_host_menu_pressed() -> void:
	main_buttons.visible = false
	host_container.visible = true
	join_container.visible = false
	update_container.visible = false
	
	var local_ip = NetworkManager.get_local_ip()
	host_ip_label.text = "YOUR LOCAL IP: %s" % local_ip
	var port = int(host_port_input.text) if host_port_input.text.is_valid_int() else 7777
	NetworkManager.start_host(port)
	_update_peer_list()

func _on_join_menu_pressed() -> void:
	main_buttons.visible = false
	host_container.visible = false
	join_container.visible = true
	update_container.visible = false
	status_label.text = "Enter Host IP and Port, then click Connect."

func _on_connect_pressed() -> void:
	var ip = join_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port = int(join_port_input.text) if join_port_input.text.is_valid_int() else 7777
	NetworkManager.join_host(ip, port)

func _on_start_squad_pressed() -> void:
	if NetworkManager.is_server:
		mission_started.emit()

func _on_update_menu_pressed() -> void:
	main_buttons.visible = false
	host_container.visible = false
	join_container.visible = false
	update_container.visible = true
	
	pull_update_btn.visible = false
	restart_btn.visible = false
	check_again_btn.visible = false
	changelog_box.visible = false
	
	version_info_label.text = "LOCAL BUILD: %s (branch: %s)" % [UpdateManager.current_commit_hash, UpdateManager.current_branch_name]
	update_status_label.text = "Connecting to repository & checking for updates..."
	update_status_label.set("theme_override_colors/font_color", Color(0, 0.9, 1.0))
	status_label.text = "Checking GitHub repository for updates..."
	
	UpdateManager.check_for_updates()

func _on_update_check_completed(up_to_date: bool, behind_count: int, changelog: Array, error_msg: String) -> void:
	version_info_label.text = "LOCAL BUILD: %s (branch: %s)" % [UpdateManager.current_commit_hash, UpdateManager.current_branch_name]
	_update_footer_version()
	check_again_btn.visible = true
	
	if not error_msg.is_empty():
		update_status_label.text = "⚠ %s" % error_msg
		update_status_label.set("theme_override_colors/font_color", Color(1.0, 0.4, 0.4))
		pull_update_btn.visible = false
		changelog_box.visible = false
		status_label.text = "Update check failed."
		return
	
	if up_to_date:
		update_status_label.text = "✓ GAME IS UP TO DATE!\nYou are running the latest version (%s)." % UpdateManager.current_commit_hash
		update_status_label.set("theme_override_colors/font_color", Color(0.3, 1.0, 0.5))
		pull_update_btn.visible = false
		changelog_box.visible = false
		status_label.text = "System is up to date."
		update_btn.text = "🔄  CHECK FOR UPDATES"
	else:
		update_status_label.text = "⚡ UPDATE AVAILABLE!\n%d new commit(s) found on GitHub." % behind_count
		update_status_label.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.2))
		pull_update_btn.visible = true
		pull_update_btn.disabled = false
		pull_update_btn.text = "⬇  UPDATE GAME NOW (GIT PULL)"
		update_btn.text = "⚡  UPDATE AVAILABLE (%d NEW)" % behind_count
		status_label.text = "New update available! Click 'Update Game Now'."
		
		if changelog.size() > 0:
			changelog_box.visible = true
			var log_str = ""
			for commit_entry in changelog:
				log_str += "• " + commit_entry + "\n"
			changelog_label.text = log_str.strip_edges()
		else:
			changelog_box.visible = false

func _on_pull_update_pressed() -> void:
	pull_update_btn.disabled = true
	pull_update_btn.text = "UPDATING... (GIT PULL)"
	check_again_btn.visible = false
	update_status_label.text = "Downloading & applying update via git pull... Please wait."
	update_status_label.set("theme_override_colors/font_color", Color(0, 0.9, 1.0))
	status_label.text = "Executing git pull in progress..."
	
	UpdateManager.pull_updates()

func _on_update_completed(success: bool, message: String) -> void:
	_update_footer_version()
	if success:
		update_status_label.text = "✓ UPDATE COMPLETED SUCCESSFULLY!\nGame files updated to commit %s.\nRestart the game to apply changes." % UpdateManager.current_commit_hash
		update_status_label.set("theme_override_colors/font_color", Color(0.3, 1.0, 0.5))
		pull_update_btn.visible = false
		restart_btn.visible = true
		check_again_btn.visible = false
		changelog_box.visible = false
		status_label.text = "Update installed! Restart to apply changes."
		update_btn.text = "🔄  CHECK FOR UPDATES"
	else:
		update_status_label.text = "❌ UPDATE FAILED:\n%s" % message
		update_status_label.set("theme_override_colors/font_color", Color(1.0, 0.35, 0.35))
		pull_update_btn.visible = true
		pull_update_btn.disabled = false
		pull_update_btn.text = "🔄  RETRY UPDATE (GIT PULL)"
		restart_btn.visible = false
		check_again_btn.visible = true
		status_label.text = "Update encountered an error."

func _on_restart_game_pressed() -> void:
	status_label.text = "Restarting CyberHorde..."
	UpdateManager.restart_game()

func _on_check_again_pressed() -> void:
	_on_update_menu_pressed()

func _on_back_pressed() -> void:
	NetworkManager.cleanup_network()
	_show_main_view()

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_peers_updated(_peer_id: int) -> void:
	_update_peer_list()

func _update_peer_list() -> void:
	var peers = NetworkManager.connected_peers
	var text = "SQUAD MEMBERS (%d):\n" % peers.size()
	for p in peers:
		if p == 1:
			text += " • Player 1 (Host) - READY\n"
		else:
			text += " • Player %d (Ally) - CONNECTED\n" % p
	peer_list_label.text = text
	
	if NetworkManager.is_server:
		start_squad_btn.disabled = false
		start_squad_btn.text = "LAUNCH SQUAD MISSION (%d PLAYERS)" % peers.size()

func _update_window_mode_btn() -> void:
	if window_mode_btn:
		if GameManager.is_fullscreen():
			window_mode_btn.text = "🖥️  WINDOW MODE: FULLSCREEN (CLICK TO TOGGLE)"
		else:
			window_mode_btn.text = "🗗  WINDOW MODE: WINDOWED (CLICK TO TOGGLE)"

func _on_window_mode_pressed() -> void:
	SoundManager.play("upgrade_select", 0.05, 0.0)
	GameManager.toggle_fullscreen()

func _on_window_mode_changed(_is_fullscreen: bool) -> void:
	_update_window_mode_btn()
