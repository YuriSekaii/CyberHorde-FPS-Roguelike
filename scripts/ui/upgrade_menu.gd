extends CanvasLayer

@onready var container: HBoxContainer = $Panel/CardContainer
@onready var title_label: Label = $Panel/TitleLabel
@onready var scrap_label: Label = $Panel/BottomBar/ScrapLabel
@onready var reroll_btn: Button = $Panel/BottomBar/RerollBtn

var current_options: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.level_up.connect(_on_level_up)
	GameManager.upgrade_requested.connect(open_menu)
	GameManager.scrap_changed.connect(_on_scrap_changed)
	if reroll_btn:
		reroll_btn.pressed.connect(_on_reroll_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1 and current_options.size() >= 1:
			_select_card(0)
		elif event.physical_keycode == KEY_2 and current_options.size() >= 2:
			_select_card(1)
		elif event.physical_keycode == KEY_3 and current_options.size() >= 3:
			_select_card(2)

func _on_level_up(_lvl: int) -> void:
	open_menu()

func open_menu() -> void:
	if visible:
		return
	current_options = GameManager.get_upgrade_options(3)
	if current_options.is_empty():
		GameManager.resume_game()
		return
	
	visible = true
	title_label.text = "LEVEL UP! CHOOSE AN UPGRADE"
	_populate_cards()
	_update_reroll_ui()

func _on_scrap_changed(_new_scrap: int) -> void:
	if visible:
		_update_reroll_ui()

func _update_reroll_ui() -> void:
	if not scrap_label or not reroll_btn:
		return
	
	var cur_scrap = GameManager.scrap
	var cost = GameManager.reroll_cost
	scrap_label.text = "SCRAP: %d" % cur_scrap
	
	if not GameManager.has_available_upgrades():
		reroll_btn.disabled = true
		reroll_btn.text = "MAX UPGRADES REACHED"
		reroll_btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
	elif cur_scrap >= cost:
		reroll_btn.disabled = false
		reroll_btn.text = "⟳ REROLL  (%d Scrap)" % cost
		reroll_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		reroll_btn.disabled = true
		reroll_btn.text = "⟳ REROLL  (Need %d Scrap)" % cost
		reroll_btn.modulate = Color(0.8, 0.5, 0.5, 0.8)

func _on_reroll_pressed() -> void:
	if not visible:
		return
	
	if not GameManager.can_afford_reroll() or not GameManager.has_available_upgrades():
		SoundManager.play("empty_ammo")
		return
	
	var current_ids: Array[String] = []
	for opt in current_options:
		current_ids.append(opt["id"])
	
	if GameManager.use_reroll():
		SoundManager.play("reroll")
		current_options = GameManager.get_upgrade_options(3, current_ids)
		_populate_cards()
		_update_reroll_ui()

func _populate_cards() -> void:
	for child in container.get_children():
		child.queue_free()
	
	for i in range(current_options.size()):
		var opt = current_options[i]
		var card = _create_card_button(i, opt)
		container.add_child(card)

func _create_card_button(index: int, opt: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(260, 340)
	
	var cur_stacks = GameManager.active_upgrades.get(opt["id"], 0)
	var max_stacks = opt["max_stacks"]
	var rarity_color = opt["color"]
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	
	# Key indicator
	var key_lbl = Label.new()
	key_lbl.text = "[KEY %d]" % [index + 1]
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(key_lbl)
	
	# Rarity badge
	var rarity_lbl = Label.new()
	rarity_lbl.text = opt["rarity"].to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 13)
	rarity_lbl.modulate = rarity_color
	vbox.add_child(rarity_lbl)
	
	# Upgrade Name
	var name_lbl = Label.new()
	name_lbl.text = opt["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)
	
	# Stacks
	var stack_lbl = Label.new()
	if max_stacks >= 999:
		stack_lbl.text = "Rank: %d / ∞" % [cur_stacks + 1]
	else:
		stack_lbl.text = "Rank: %d / %d" % [cur_stacks + 1, max_stacks]
	stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_lbl.add_theme_font_size_override("font_size", 13)
	stack_lbl.modulate = Color(0.8, 0.8, 0.8, 0.8)
	vbox.add_child(stack_lbl)
	
	# Divider
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = opt["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_lbl)
	
	btn.add_child(vbox)
	btn.pressed.connect(func(): _select_card(index))
	return btn

func _select_card(index: int) -> void:
	if index < 0 or index >= current_options.size():
		return
	
	var chosen = current_options[index]
	visible = false
	GameManager.apply_upgrade(chosen["id"])
