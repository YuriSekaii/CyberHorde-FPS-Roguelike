extends CanvasLayer

signal mission_started()

@onready var main_buttons: VBoxContainer = $Panel/VBoxContainer/MainButtons
@onready var host_container: VBoxContainer = $Panel/VBoxContainer/HostContainer
@onready var join_container: VBoxContainer = $Panel/VBoxContainer/JoinContainer
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var host_ip_label: Label = $Panel/VBoxContainer/HostContainer/HostIPLabel
@onready var host_port_input: LineEdit = $Panel/VBoxContainer/HostContainer/PortContainer/HostPortInput
@onready var start_squad_btn: Button = $Panel/VBoxContainer/HostContainer/StartSquadBtn
@onready var peer_list_label: Label = $Panel/VBoxContainer/HostContainer/PeerListLabel

@onready var join_ip_input: LineEdit = $Panel/VBoxContainer/JoinContainer/IPContainer/JoinIPInput
@onready var join_port_input: LineEdit = $Panel/VBoxContainer/JoinContainer/PortContainer/JoinPortInput
@onready var connect_btn: Button = $Panel/VBoxContainer/JoinContainer/ConnectBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_show_main_view()
	
	NetworkManager.connection_status_changed.connect(_on_status_changed)
	NetworkManager.peer_connected_signal.connect(_on_peers_updated)
	NetworkManager.peer_disconnected_signal.connect(_on_peers_updated)

func _show_main_view() -> void:
	main_buttons.visible = true
	host_container.visible = false
	join_container.visible = false
	status_label.text = "Select deployment mode."

func _on_solo_pressed() -> void:
	NetworkManager.start_singleplayer()
	visible = false
	mission_started.emit()

func _on_host_menu_pressed() -> void:
	main_buttons.visible = false
	host_container.visible = true
	join_container.visible = false
	
	var local_ip = NetworkManager.get_local_ip()
	host_ip_label.text = "YOUR LOCAL IP: %s" % local_ip
	var port = int(host_port_input.text) if host_port_input.text.is_valid_int() else 7777
	NetworkManager.start_host(port)
	_update_peer_list()

func _on_join_menu_pressed() -> void:
	main_buttons.visible = false
	host_container.visible = false
	join_container.visible = true
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
