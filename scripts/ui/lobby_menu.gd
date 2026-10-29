extends CanvasLayer

signal mission_started()

@onready var panel: Panel = $Panel
@onready var main_buttons: VBoxContainer = $Panel/VBoxContainer/MainButtons
@onready var host_container: VBoxContainer = $Panel/VBoxContainer/HostContainer
@onready var join_container: VBoxContainer = $Panel/VBoxContainer/JoinContainer
@onready var update_container: VBoxContainer = $Panel/VBoxContainer/UpdateContainer
@onready var boss_container: VBoxContainer = $Panel/VBoxContainer/BossContainer
@onready var class_select_container: VBoxContainer = $Panel/VBoxContainer/ClassSelectContainer

@onready var host_class_medic: Button = get_node_or_null("Panel/VBoxContainer/HostContainer/ClassContainer/HostMedicBtn")
@onready var host_class_rogue: Button = get_node_or_null("Panel/VBoxContainer/HostContainer/ClassContainer/HostRogueBtn")
@onready var host_class_gunner: Button = get_node_or_null("Panel/VBoxContainer/HostContainer/ClassContainer/HostGunnerBtn")

@onready var join_class_medic: Button = get_node_or_null("Panel/VBoxContainer/JoinContainer/ClassContainer/JoinMedicBtn")
@onready var join_class_rogue: Button = get_node_or_null("Panel/VBoxContainer/JoinContainer/ClassContainer/JoinRogueBtn")
@onready var join_class_gunner: Button = get_node_or_null("Panel/VBoxContainer/JoinContainer/ClassContainer/JoinGunnerBtn")

enum ClassSelectTarget { SOLO, BOSS_SOLO }
var pending_class_target: ClassSelectTarget = ClassSelectTarget.SOLO

@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var host_ip_label: Label = $Panel/VBoxContainer/HostContainer/HostIPLabel
@onready var host_port_input: LineEdit = $Panel/VBoxContainer/HostContainer/PortContainer/HostPortInput
@onready var start_squad_btn: Button = $Panel/VBoxContainer/HostContainer/StartSquadBtn
@onready var peer_list_label: Label = $Panel/VBoxContainer/HostContainer/PeerListLabel

@onready var host_port_container: HBoxContainer = $Panel/VBoxContainer/HostContainer/PortContainer
@onready var join_ip_label: Label = $Panel/VBoxContainer/JoinContainer/IPContainer/Label
@onready var join_ip_input: LineEdit = $Panel/VBoxContainer/JoinContainer/IPContainer/JoinIPInput
@onready var join_port_container: HBoxContainer = $Panel/VBoxContainer/JoinContainer/PortContainer
@onready var join_port_input: LineEdit = $Panel/VBoxContainer/JoinContainer/PortContainer/JoinPortInput
@onready var connect_btn: Button = $Panel/VBoxContainer/JoinContainer/ConnectBtn

@onready var boss_key_input: LineEdit = $Panel/VBoxContainer/BossContainer/KeyContainer/BossKeyInput
@onready var boss_status_label: Label = $Panel/VBoxContainer/BossContainer/KeyStatusLabel

const BOSS_BATTLE_KEY: String = "HereComeTheChallenger"
# Boss Battle test targets (GameManager.boss_battle_target)
const BOSS_TARGET_LABELS: Array[String] = [
	"Stage 1 · Wave 50 — Apex Overlord",
	"Stage 2 · Wave 50 — Blood Ghoul (Blood Moon)",
	"Stage 2 · Wave 1 — Nightfall Jungle",
]
var boss_target_select: OptionButton = null

# true while the host/join panels are driving an online (lobby code) session instead of LAN
var online_mode: bool = false
var lan_join_ip: String = "127.0.0.1"

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
	NetworkManager.peer_class_updated.connect(_on_peer_class_updated)
	NetworkManager.online_lobby_ready.connect(_on_online_lobby_ready)
	
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
			if class_select_container and class_select_container.visible:
				if event.keycode == KEY_1 or event.physical_keycode == KEY_1:
					_on_medic_selected()
					get_viewport().set_input_as_handled()
					return
				elif event.keycode == KEY_2 or event.physical_keycode == KEY_2:
					_on_rogue_selected()
					get_viewport().set_input_as_handled()
					return
				elif event.keycode == KEY_3 or event.physical_keycode == KEY_3:
					_on_gunner_selected()
					get_viewport().set_input_as_handled()
					return
				elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
					_on_back_pressed()
					get_viewport().set_input_as_handled()
					return
			
			if event.keycode == KEY_M or event.physical_keycode == KEY_M:
				_on_window_mode_pressed()
				get_viewport().set_input_as_handled()

func _update_footer_version() -> void:
	if version_footer:
		version_footer.text = "CyberHorde • Build %s • branch: %s" % [UpdateManager.current_commit_hash, UpdateManager.current_branch_name]

func _set_panel_width(w: float) -> void:
	if panel:
		panel.custom_minimum_size.x = w
		panel.offset_left = -w * 0.5
		panel.offset_right = w * 0.5

func _show_main_view() -> void:
	_set_panel_width(520.0)
	main_buttons.visible = true
	host_container.visible = false
	join_container.visible = false
	update_container.visible = false
	if boss_container:
		boss_container.visible = false
	if class_select_container:
		class_select_container.visible = false
	status_label.text = "Select deployment mode."
	_update_footer_version()

func _show_class_select(target: ClassSelectTarget) -> void:
	pending_class_target = target
	main_buttons.visible = false
	host_container.visible = false
	join_container.visible = false
	update_container.visible = false
	if boss_container:
		boss_container.visible = false
	if class_select_container:
		class_select_container.visible = true
	_set_panel_width(840.0)
	status_label.text = "Select your operative combat specialty before deploying into the CyberHorde."

func _on_solo_pressed() -> void:
	_show_class_select(ClassSelectTarget.SOLO)

func _on_host_menu_pressed() -> void:
	GameManager.reset_game()
	main_buttons.visible = false
	host_container.visible = true
	join_container.visible = false
	update_container.visible = false
	if boss_container:
		boss_container.visible = false
	if class_select_container:
		class_select_container.visible = false
	_set_panel_width(520.0)
	_set_online_mode(false)
	
	var local_ip = NetworkManager.get_local_ip()
	host_ip_label.text = "YOUR LOCAL IP: %s" % local_ip
	var port = int(host_port_input.text) if host_port_input.text.is_valid_int() else 7777
	NetworkManager.start_host(port)
	_update_class_button_highlights()
	_update_peer_list()

func _on_online_host_pressed() -> void:
	_on_host_menu_pressed()
	_set_online_mode(true)
	host_ip_label.text = "ONLINE LOBBY CODE: connecting..."
	NetworkManager.host_online_lobby()
	_update_peer_list()

func _on_online_join_pressed() -> void:
	_on_join_menu_pressed()
	_set_online_mode(true)
	status_label.text = "Enter the 5-character lobby code from your host, then click Connect."
	join_ip_input.grab_focus()

func _on_online_lobby_ready(code: String) -> void:
	if NetworkManager.is_server:
		host_ip_label.text = "ONLINE LOBBY CODE: %s   (share with up to %d friends)" % [code, NetworkManager.max_clients - 1]
	_update_peer_list()

func _set_online_mode(enabled: bool) -> void:
	if enabled == online_mode:
		return
	online_mode = enabled
	host_port_container.visible = not enabled
	join_port_container.visible = not enabled
	if enabled:
		lan_join_ip = join_ip_input.text
		join_ip_label.text = "Lobby Code: "
		join_ip_input.text = ""
		join_ip_input.placeholder_text = "e.g. K7QXM"
		join_ip_input.max_length = 5
	else:
		join_ip_label.text = "Host IP: "
		join_ip_input.max_length = 0
		join_ip_input.text = lan_join_ip
		join_ip_input.placeholder_text = "192.168.x.x or IP"

func _on_join_menu_pressed() -> void:
	GameManager.reset_game()
	main_buttons.visible = false
	host_container.visible = false
	join_container.visible = true
	update_container.visible = false
	if boss_container:
		boss_container.visible = false
	if class_select_container:
		class_select_container.visible = false
	_set_panel_width(520.0)
	_set_online_mode(false)
	_update_class_button_highlights()
	status_label.text = "Enter Host IP and Port, then click Connect."

func _on_connect_pressed() -> void:
	if online_mode:
		NetworkManager.join_online_lobby(join_ip_input.text)
		return
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
	GameManager.reset_game()
	_show_main_view()

## Target selector added above the deploy buttons
func _ensure_boss_target_select() -> void:
	if boss_target_select:
		return
	boss_target_select = OptionButton.new()
	boss_target_select.name = "BossTargetSelect"
	boss_target_select.custom_minimum_size = Vector2(0, 36)
	for i in range(BOSS_TARGET_LABELS.size()):
		boss_target_select.add_item(BOSS_TARGET_LABELS[i], i + 1)
	boss_target_select.select(clampi(GameManager.boss_battle_target - 1, 0, BOSS_TARGET_LABELS.size() - 1))
	boss_target_select.item_selected.connect(func(idx: int): GameManager.boss_battle_target = boss_target_select.get_item_id(idx))
	boss_container.add_child(boss_target_select)
	var deploy_btn = boss_container.get_node_or_null("DeployBossSoloBtn")
	if deploy_btn:
		boss_container.move_child(boss_target_select, deploy_btn.get_index())

func _on_boss_menu_pressed() -> void:
	_ensure_boss_target_select()
	main_buttons.visible = false
	host_container.visible = false
	join_container.visible = false
	update_container.visible = false
	boss_container.visible = true
	boss_key_input.text = ""
	boss_status_label.text = ""
	status_label.text = "Enter Authorization Key to access Boss Battle mode."
	boss_key_input.grab_focus()

func _validate_boss_key() -> bool:
	var entered = boss_key_input.text.strip_edges()
	return entered == BOSS_BATTLE_KEY or entered.nocasecmp_to(BOSS_BATTLE_KEY) == 0

func _on_boss_key_submitted(_new_text: String) -> void:
	_on_deploy_boss_solo_pressed()

func _on_deploy_boss_solo_pressed() -> void:
	if _validate_boss_key():
		boss_status_label.set("theme_override_colors/font_color", Color(0.2, 1.0, 0.5))
		boss_status_label.text = "✓ ACCESS GRANTED! DEPLOYING: %s" % BOSS_TARGET_LABELS[clampi(GameManager.boss_battle_target - 1, 0, BOSS_TARGET_LABELS.size() - 1)].to_upper()
		SoundManager.play("level_up", 0.2, 0.0)
		_show_class_select(ClassSelectTarget.BOSS_SOLO)
	else:
		boss_status_label.set("theme_override_colors/font_color", Color(1.0, 0.3, 0.3))
		boss_status_label.text = "❌ ACCESS DENIED: INVALID AUTHORIZATION KEY"
		SoundManager.play("hitmarker", 0.3, -3.0)
		boss_key_input.grab_focus()

func _on_deploy_boss_host_pressed() -> void:
	if _validate_boss_key():
		boss_status_label.set("theme_override_colors/font_color", Color(0.2, 1.0, 0.5))
		boss_status_label.text = "✓ ACCESS GRANTED! SETTING UP CO-OP BOSS BATTLE..."
		SoundManager.play("level_up", 0.2, 0.0)
		GameManager.setup_boss_battle_mode()
		
		main_buttons.visible = false
		boss_container.visible = false
		host_container.visible = true
		_set_online_mode(false)
		
		var local_ip = NetworkManager.get_local_ip()
		host_ip_label.text = "YOUR LOCAL IP: %s (BOSS BATTLE HOST)" % local_ip
		var port = int(host_port_input.text) if host_port_input.text.is_valid_int() else 7777
		NetworkManager.start_host(port)
		_update_peer_list()
	else:
		boss_status_label.set("theme_override_colors/font_color", Color(1.0, 0.3, 0.3))
		boss_status_label.text = "❌ ACCESS DENIED: INVALID AUTHORIZATION KEY"
		SoundManager.play("hitmarker", 0.3, -3.0)
		boss_key_input.grab_focus()

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_peers_updated(_peer_id: int) -> void:
	_update_peer_list()

func _update_peer_list() -> void:
	var peers = NetworkManager.connected_peers
	var text = "SQUAD MEMBERS (%d):\n" % peers.size()
	for p in peers:
		var c = NetworkManager.get_player_class(p).to_upper()
		if p == 1:
			text += " • Player 1 (Host) [%s] - READY\n" % c
		else:
			text += " • Player %d (Ally) [%s] - CONNECTED\n" % [p, c]
	peer_list_label.text = text
	
	if NetworkManager.is_server:
		start_squad_btn.disabled = false
		start_squad_btn.text = "LAUNCH SQUAD MISSION (%d PLAYERS)" % peers.size()

func _on_medic_selected() -> void:
	_select_and_launch("medic")

func _on_rogue_selected() -> void:
	_select_and_launch("rogue")

func _on_gunner_selected() -> void:
	_select_and_launch("gunner")

func _select_and_launch(chosen_class: String) -> void:
	NetworkManager.set_local_class(chosen_class)
	SoundManager.play("upgrade_select", 0.1, 0.0)
	visible = false
	if pending_class_target == ClassSelectTarget.BOSS_SOLO:
		GameManager.setup_boss_battle_mode()
	else:
		GameManager.reset_game()
	NetworkManager.start_singleplayer()
	mission_started.emit()

func _on_host_medic_pressed() -> void:
	NetworkManager.set_local_class("medic")
	_update_class_button_highlights()
	_update_peer_list()

func _on_host_rogue_pressed() -> void:
	NetworkManager.set_local_class("rogue")
	_update_class_button_highlights()
	_update_peer_list()

func _on_host_gunner_pressed() -> void:
	NetworkManager.set_local_class("gunner")
	_update_class_button_highlights()
	_update_peer_list()

func _on_join_medic_pressed() -> void:
	NetworkManager.set_local_class("medic")
	_update_class_button_highlights()

func _on_join_rogue_pressed() -> void:
	NetworkManager.set_local_class("rogue")
	_update_class_button_highlights()

func _on_join_gunner_pressed() -> void:
	NetworkManager.set_local_class("gunner")
	_update_class_button_highlights()

func _on_peer_class_updated(_peer_id: int, _new_class: String) -> void:
	_update_peer_list()
	_update_class_button_highlights()

func _update_class_button_highlights() -> void:
	var cur_class = GameManager.player_class
	var dim = Color(0.65, 0.65, 0.65, 0.8)
	if host_class_medic: host_class_medic.modulate = Color(0.2, 1.0, 0.7) if cur_class == "medic" else dim
	if host_class_rogue: host_class_rogue.modulate = Color(1.0, 0.85, 0.2) if cur_class == "rogue" else dim
	if host_class_gunner: host_class_gunner.modulate = Color(1.0, 0.35, 0.4) if (cur_class == "gunner" or cur_class == "slayer") else dim
	if join_class_medic: join_class_medic.modulate = Color(0.2, 1.0, 0.7) if cur_class == "medic" else dim
	if join_class_rogue: join_class_rogue.modulate = Color(1.0, 0.85, 0.2) if cur_class == "rogue" else dim
	if join_class_gunner: join_class_gunner.modulate = Color(1.0, 0.35, 0.4) if (cur_class == "gunner" or cur_class == "slayer") else dim

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
