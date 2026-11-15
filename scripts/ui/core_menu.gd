class_name CoreMenu
extends CanvasLayer

signal closed()

@onready var background: ColorRect = $Background
@onready var title_label: Label = $MainLayout/VBoxContainer/HeaderHBox/TitleVBox/TitleLabel
@onready var subtitle_label: Label = $MainLayout/VBoxContainer/HeaderHBox/TitleVBox/SubtitleLabel
@onready var back_btn: Button = $MainLayout/VBoxContainer/HeaderHBox/BackBtn

@onready var stats_list_vbox: VBoxContainer = $MainLayout/VBoxContainer/ContentHBox/LeftSidebar/MarginContainer/VBoxContainer/StatsScroll/StatsListVBox
@onready var grid_viewport: Control = $MainLayout/VBoxContainer/ContentHBox/CenterGridPanel/MarginContainer/VBoxContainer/GridScroll/GridCenterContainer/GridViewport
@onready var grid_info_label: Label = $MainLayout/VBoxContainer/ContentHBox/CenterGridPanel/MarginContainer/VBoxContainer/GridHeaderHBox/GridInfoLabel
@onready var clear_all_btn: Button = $MainLayout/VBoxContainer/ContentHBox/CenterGridPanel/MarginContainer/VBoxContainer/GridBottomHBox/ClearAllBtn
@onready var rotate_btn: Button = $MainLayout/VBoxContainer/ContentHBox/CenterGridPanel/MarginContainer/VBoxContainer/GridBottomHBox/RotateBtn
@onready var grid_tip_label: Label = $MainLayout/VBoxContainer/ContentHBox/CenterGridPanel/MarginContainer/VBoxContainer/GridBottomHBox/GridTipLabel

@onready var stash_count_label: Label = $MainLayout/VBoxContainer/ContentHBox/RightStashPanel/MarginContainer/VBoxContainer/StashHeaderHBox/StashCountLabel
@onready var stash_list_vbox: VBoxContainer = $MainLayout/VBoxContainer/ContentHBox/RightStashPanel/MarginContainer/VBoxContainer/StashScroll/StashListVBox

@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_name: Label = $TooltipPanel/MarginContainer/TooltipVBox/TooltipName
@onready var tooltip_rarity: Label = $TooltipPanel/MarginContainer/TooltipVBox/TooltipRarity
@onready var tooltip_shape: Label = $TooltipPanel/MarginContainer/TooltipVBox/TooltipShape
@onready var tooltip_stats_vbox: VBoxContainer = $TooltipPanel/MarginContainer/TooltipVBox/TooltipStatsVBox
@onready var tooltip_hint: Label = $TooltipPanel/MarginContainer/TooltipVBox/TooltipHint

const CELL_SIZE: float = 52.0
const CELL_PADDING: float = 3.0
const MAX_DISPLAY_ROWS: int = 8
const MAX_DISPLAY_COLS: int = 10

var core_grid: CoreGrid = null
var active_drag_comp: ComponentData = null
var drag_from_grid: bool = false
var drag_original_pos: Vector2i = Vector2i(-1, -1)

var hover_grid_cell: Vector2i = Vector2i(-1, -1)
var hovered_comp: ComponentData = null
var mouse_grid_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	
	core_grid = CoreGrid.get_instance()
	if core_grid:
		core_grid.grid_changed.connect(_on_grid_or_stash_changed)
		core_grid.stash_changed.connect(_on_grid_or_stash_changed)
		core_grid.dimensions_expanded.connect(_on_dimensions_expanded)
	
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if clear_all_btn:
		clear_all_btn.pressed.connect(_on_clear_all_pressed)
	if rotate_btn:
		rotate_btn.pressed.connect(_on_rotate_active_pressed)
	
	if grid_viewport:
		grid_viewport.draw.connect(_on_grid_viewport_draw)
		grid_viewport.gui_input.connect(_on_grid_viewport_gui_input)
		grid_viewport.mouse_exited.connect(_on_grid_viewport_mouse_exited)
	
	if tooltip_panel:
		tooltip_panel.visible = false
		tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	refresh_all()

func open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if core_grid:
		core_grid.load_from_disk()
	refresh_all()

func close() -> void:
	if active_drag_comp:
		_cancel_active_drag()
	if core_grid:
		core_grid.save_to_disk()
	hide_tooltip()
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			if active_drag_comp != null:
				_cancel_active_drag()
				get_viewport().set_input_as_handled()
			else:
				close()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R or event.physical_keycode == KEY_R:
			if active_drag_comp != null:
				_rotate_active_drag()
				get_viewport().set_input_as_handled()

func refresh_all() -> void:
	_update_header_info()
	_update_grid_size()
	_update_stat_sidebar()
	_update_stash_list()
	if grid_viewport:
		grid_viewport.queue_redraw()

func _update_header_info() -> void:
	if not core_grid:
		return
	var rows = core_grid.get_rows()
	var cols = core_grid.get_cols()
	if subtitle_label:
		var wave_milestone = int(core_grid.highest_wave_reached / 10) * 10
		var bosses_down = (1 if core_grid.stage1_boss_defeated else 0) + (1 if core_grid.stage2_boss_defeated else 0)
		subtitle_label.text = "Matrix Capacity: %d Rows × %d Cols (%d Slots) • Waves Survived: %d • Boss Cores Defeated: %d/2" % [
			rows, cols, rows * cols, core_grid.highest_wave_reached, bosses_down
		]
	if grid_info_label:
		grid_info_label.text = "Active Capacity: %dx%d" % [cols, rows]

func _update_grid_size() -> void:
	if not grid_viewport or not core_grid:
		return
	var display_cols = maxi(core_grid.get_cols() + 1, core_grid.get_cols())
	var display_rows = maxi(core_grid.get_rows() + 1, core_grid.get_rows())
	display_cols = mini(MAX_DISPLAY_COLS, display_cols)
	display_rows = mini(MAX_DISPLAY_ROWS, display_rows)
	
	var total_w = display_cols * CELL_SIZE
	var total_h = display_rows * CELL_SIZE
	grid_viewport.custom_minimum_size = Vector2(total_w, total_h)

func _update_stat_sidebar() -> void:
	if not stats_list_vbox or not core_grid:
		return
	
	for child in stats_list_vbox.get_children():
		child.queue_free()
	
	var bonuses = core_grid.calculate_aggregate_bonuses()
	
	_add_stat_row("Projectile Damage", "+%d%%" % int(round((bonuses.get("damage_mult", 1.0) - 1.0) * 100.0)), Color(0.2, 0.9, 1.0))
	_add_stat_row("Fire Rate", "+%d%%" % int(round((bonuses.get("fire_rate_mult", 1.0) - 1.0) * 100.0)), Color(1.0, 0.85, 0.2))
	_add_stat_row("Max Health", "+%d HP" % int(round(bonuses.get("max_health_bonus", 0.0))), Color(0.2, 1.0, 0.5))
	_add_stat_row("Shield Capacity", "+%d" % int(round(bonuses.get("shield_max", 0.0))), Color(0.3, 0.9, 1.0))
	_add_stat_row("Movement Speed", "+%d%%" % int(round((bonuses.get("speed_mult", 1.0) - 1.0) * 100.0)), Color(0.5, 0.8, 1.0))
	_add_stat_row("Reload Speed", "+%d%%" % int(round((bonuses.get("reload_speed_mult", 1.0) - 1.0) * 100.0)), Color(0.8, 0.9, 1.0))
	_add_stat_row("Critical Chance", "%d%%" % int(round(bonuses.get("crit_chance", 0.10) * 100.0)), Color(1.0, 0.5, 0.2))
	_add_stat_row("Critical Damage", "%.2fx" % float(bonuses.get("crit_damage", 2.0)), Color(1.0, 0.4, 0.3))
	
	var extra_proj = int(bonuses.get("extra_projectiles", 0))
	if extra_proj > 0:
		_add_stat_row("Extra Pellets", "+%d" % extra_proj, Color(0.9, 0.6, 1.0))
	
	var pierce = int(bonuses.get("pierce_count", 0))
	if pierce > 0:
		_add_stat_row("Pierce Count", "+%d" % pierce, Color(0.6, 0.9, 1.0))
	
	var drones = int(bonuses.get("drone_count", 0))
	if drones > 0:
		_add_stat_row("Assault Drones", "%d Active" % drones, Color(0.3, 1.0, 0.8))
	
	var v_heal = float(bonuses.get("vampiric_heal", 0.0))
	if v_heal > 0.0:
		_add_stat_row("Nanite Leech", "+%d HP / Kill" % int(round(v_heal)), Color(0.2, 1.0, 0.5))
		
	var dmg_red = float(bonuses.get("player_damage_reduction", 0.0))
	if dmg_red > 0.0:
		_add_stat_row("Armor Plating", "-%d%% Damage Taken" % int(round(dmg_red * 100.0)), Color(0.4, 0.8, 1.0))
	
	var magnet = float(bonuses.get("magnet_radius", 6.0))
	if magnet > 6.0:
		_add_stat_row("Nanite Magnet", "%.1fm" % magnet, Color(0.8, 0.8, 1.0))
	
	# Special Core Modifiers
	if bool(bonuses.get("explosive_rounds", false)):
		_add_perk_badge("Explosive Payload (2.5m AoE)", Color(1.0, 0.4, 0.2))
	if bool(bonuses.get("chain_lightning", false)):
		_add_perk_badge("Tesla Arc Emitter (Chain Shock)", Color(0.4, 0.8, 1.0))
	if bool(bonuses.get("bouncing_bullets", false)):
		_add_perk_badge("Smart Bouncing Core (+Ricochet)", Color(0.8, 0.4, 1.0))
	if bool(bonuses.get("cryo_slow", false)):
		_add_perk_badge("Cryo Modulator (25% Enemy Slow)", Color(0.5, 0.9, 1.0))
	if bool(bonuses.get("null_barrier_unlocked", false)):
		_add_perk_badge("Null Barrier (Block damage/10s)", Color(0.3, 1.0, 0.6))
	if bool(bonuses.get("second_wind_unlocked", false)):
		_add_perk_badge("Emergency Defibrillator (Revive)", Color(1.0, 0.8, 0.2))
	if bool(bonuses.get("cooldown_reduction", false)):
		_add_perk_badge("Overclocked Actuator (-50% CD)", Color(0.3, 0.9, 1.0))
	if bool(bonuses.get("dual_capacitor", false)):
		_add_perk_badge("Dual Capacitor (+1 Skill Charge)", Color(1.0, 0.6, 0.2))

func _add_stat_row(label_text: String, value_text: String, value_color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.set("theme_override_colors/font_color", Color(0.75, 0.85, 0.95, 0.85))
	lbl.set("theme_override_font_sizes/font_size", 12)
	hbox.add_child(lbl)
	
	var val = Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.set("theme_override_colors/font_color", value_color)
	val.set("theme_override_font_sizes/font_size", 12)
	hbox.add_child(val)
	
	stats_list_vbox.add_child(hbox)

func _add_perk_badge(text: String, color: Color) -> void:
	var pnl = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.8)
	style.border_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	pnl.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	
	var lbl = Label.new()
	lbl.text = "⚡ " + text
	lbl.set("theme_override_colors/font_color", color)
	lbl.set("theme_override_font_sizes/font_size", 11)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(lbl)
	
	pnl.add_child(margin)
	stats_list_vbox.add_child(pnl)

func _update_stash_list() -> void:
	if not stash_list_vbox or not core_grid:
		return
	
	for child in stash_list_vbox.get_children():
		child.queue_free()
	
	var count = core_grid.stash.size()
	if stash_count_label:
		stash_count_label.text = "(%d)" % count
	
	if count == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "Stash is empty.\nDefeat enemies or open Loot Boxes during runs to harvest Cyberware Components!"
		empty_lbl.set("theme_override_colors/font_color", Color(0.5, 0.6, 0.7, 0.7))
		empty_lbl.set("theme_override_font_sizes/font_size", 12)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stash_list_vbox.add_child(empty_lbl)
		return
	
	for comp in core_grid.stash:
		var item_card = _create_stash_card(comp)
		stash_list_vbox.add_child(item_card)

func _create_stash_card(comp: ComponentData) -> PanelContainer:
	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(0, 58)
	
	var rarity_col = comp.get_rarity_color()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.95)
	style.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.65)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	pnl.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	# Mini Shape Thumbnail Control
	var thumb = Control.new()
	thumb.custom_minimum_size = Vector2(36, 36)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.draw.connect(func(): _draw_comp_thumbnail(thumb, comp))
	hbox.add_child(thumb)
	
	# Info VBox
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	
	var name_lbl = Label.new()
	name_lbl.text = comp.name
	name_lbl.set("theme_override_colors/font_color", rarity_col)
	name_lbl.set("theme_override_font_sizes/font_size", 12)
	info_vbox.add_child(name_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "[%s] • Shape: %s" % [comp.rarity.to_upper(), comp.shape_type]
	sub_lbl.set("theme_override_colors/font_color", Color(0.65, 0.75, 0.85, 0.7))
	sub_lbl.set("theme_override_font_sizes/font_size", 10)
	info_vbox.add_child(sub_lbl)
	
	hbox.add_child(info_vbox)
	
	# Action buttons VBox
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 2)
	
	var pick_btn = Button.new()
	pick_btn.text = "EQUIP"
	pick_btn.custom_minimum_size = Vector2(58, 22)
	pick_btn.set("theme_override_font_sizes/font_size", 10)
	pick_btn.pressed.connect(func(): _on_stash_item_picked(comp))
	btn_vbox.add_child(pick_btn)
	
	var rot_btn = Button.new()
	rot_btn.text = "ROTATE"
	rot_btn.custom_minimum_size = Vector2(58, 20)
	rot_btn.set("theme_override_font_sizes/font_size", 9)
	rot_btn.pressed.connect(func():
		comp.rotate_90()
		thumb.queue_redraw()
		_update_stash_list()
	)
	btn_vbox.add_child(rot_btn)
	
	hbox.add_child(btn_vbox)
	margin.add_child(hbox)
	pnl.add_child(margin)
	
	# Connect hover to tooltip
	pnl.mouse_entered.connect(func(): _show_tooltip_for_comp(comp, pnl.get_global_position() + Vector2(-220, 0)))
	pnl.mouse_exited.connect(hide_tooltip)
	
	return pnl

func _draw_comp_thumbnail(ctrl: Control, comp: ComponentData) -> void:
	var cells = comp.get_transformed_cells()
	if cells.is_empty():
		return
	var w = comp.get_width()
	var h = comp.get_height()
	var max_dim = maxi(w, h)
	var t_size = minf(32.0 / float(max_dim), 14.0)
	var offset_x = (36.0 - (float(w) * t_size)) * 0.5
	var offset_y = (36.0 - (float(h) * t_size)) * 0.5
	var color = comp.get_rarity_color()
	
	for c in cells:
		var rect = Rect2(offset_x + float(c.x) * t_size, offset_y + float(c.y) * t_size, t_size - 1.0, t_size - 1.0)
		ctrl.draw_rect(rect, Color(color.r, color.g, color.b, 0.45), true)
		ctrl.draw_rect(rect, color, false, 1.0)

# Grid Canvas Rendering & Input
func _on_grid_viewport_draw() -> void:
	if not grid_viewport or not core_grid:
		return
	
	var rows = core_grid.get_rows()
	var cols = core_grid.get_cols()
	var display_cols = maxi(cols + 1, cols)
	var display_rows = maxi(rows + 1, rows)
	display_cols = mini(MAX_DISPLAY_COLS, display_cols)
	display_rows = mini(MAX_DISPLAY_ROWS, display_rows)
	
	# 1. Draw Cells (Unlocked and Locked perimeter)
	for r in range(display_rows):
		for c in range(display_cols):
			var cell_rect = Rect2(float(c) * CELL_SIZE + CELL_PADDING, float(r) * CELL_SIZE + CELL_PADDING, CELL_SIZE - CELL_PADDING * 2.0, CELL_SIZE - CELL_PADDING * 2.0)
			if c < cols and r < rows:
				# Unlocked cell
				grid_viewport.draw_rect(cell_rect, Color(0.04, 0.08, 0.14, 0.75), true)
				grid_viewport.draw_rect(cell_rect, Color(0.0, 0.7, 0.9, 0.35), false, 1.0)
				
				# Corner cyber dots
				var dot_r = 1.5
				grid_viewport.draw_circle(cell_rect.position + Vector2(3, 3), dot_r, Color(0.0, 0.9, 1.0, 0.5))
				grid_viewport.draw_circle(cell_rect.position + Vector2(cell_rect.size.x - 3, 3), dot_r, Color(0.0, 0.9, 1.0, 0.5))
				grid_viewport.draw_circle(cell_rect.position + Vector2(3, cell_rect.size.y - 3), dot_r, Color(0.0, 0.9, 1.0, 0.5))
				grid_viewport.draw_circle(cell_rect.position + cell_rect.size - Vector2(3, 3), dot_r, Color(0.0, 0.9, 1.0, 0.5))
			else:
				# Locked indicator cell
				grid_viewport.draw_rect(cell_rect, Color(0.10, 0.04, 0.06, 0.65), true)
				grid_viewport.draw_rect(cell_rect, Color(0.7, 0.2, 0.3, 0.45), false, 1.0)
				# Lock text
				var font = ThemeDB.fallback_font
				var font_size = 12
				grid_viewport.draw_string(font, cell_rect.position + Vector2(10, 28), "🔒", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.8, 0.4, 0.4, 0.8))
	
	# 2. Draw Placed Components
	var rendered_comps: Dictionary = {}
	for comp in core_grid.placed_components:
		if comp == active_drag_comp:
			continue
		var col = comp.grid_pos.x
		var row = comp.grid_pos.y
		if col < 0 or row < 0:
			continue
		
		var rarity_col = comp.get_rarity_color()
		var cells = comp.get_transformed_cells()
		
		for offset in cells:
			var target_c = col + offset.x
			var target_r = row + offset.y
			var cell_rect = Rect2(float(target_c) * CELL_SIZE + CELL_PADDING + 1.0, float(target_r) * CELL_SIZE + CELL_PADDING + 1.0, CELL_SIZE - CELL_PADDING * 2.0 - 2.0, CELL_SIZE - CELL_PADDING * 2.0 - 2.0)
			
			grid_viewport.draw_rect(cell_rect, Color(rarity_col.r * 0.35, rarity_col.g * 0.35, rarity_col.b * 0.35, 0.85), true)
			grid_viewport.draw_rect(cell_rect, rarity_col, false, 2.0)
		
		# Draw name on top-left occupied cell
		var top_rect = Rect2(float(col) * CELL_SIZE + 6.0, float(row) * CELL_SIZE + 18.0, CELL_SIZE * float(comp.get_width()), 20.0)
		var font = ThemeDB.fallback_font
		grid_viewport.draw_string(font, top_rect.position, comp.name, HORIZONTAL_ALIGNMENT_LEFT, int(top_rect.size.x), 10, Color.WHITE)
	
	# 3. Draw Active Placement Ghost / Drag Preview
	if active_drag_comp != null:
		if hover_grid_cell.x >= 0 and hover_grid_cell.y >= 0:
			var can_place = core_grid.can_place(active_drag_comp, hover_grid_cell.x, hover_grid_cell.y)
			var preview_color = Color(0.2, 1.0, 0.4, 0.6) if can_place else Color(1.0, 0.2, 0.2, 0.6)
			var outline_color = Color(0.3, 1.0, 0.5, 1.0) if can_place else Color(1.0, 0.3, 0.3, 1.0)
			
			for offset in active_drag_comp.get_transformed_cells():
				var target_c = hover_grid_cell.x + offset.x
				var target_r = hover_grid_cell.y + offset.y
				var cell_rect = Rect2(float(target_c) * CELL_SIZE + CELL_PADDING, float(target_r) * CELL_SIZE + CELL_PADDING, CELL_SIZE - CELL_PADDING * 2.0, CELL_SIZE - CELL_PADDING * 2.0)
				grid_viewport.draw_rect(cell_rect, preview_color, true)
				grid_viewport.draw_rect(cell_rect, outline_color, false, 2.0)
		else:
			# Free floating mouse preview
			var rarity_col = active_drag_comp.get_rarity_color()
			for offset in active_drag_comp.get_transformed_cells():
				var ghost_rect = Rect2(mouse_grid_pos.x + float(offset.x) * (CELL_SIZE * 0.7), mouse_grid_pos.y + float(offset.y) * (CELL_SIZE * 0.7), CELL_SIZE * 0.65, CELL_SIZE * 0.65)
				grid_viewport.draw_rect(ghost_rect, Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.6), true)
				grid_viewport.draw_rect(ghost_rect, rarity_col, false, 1.5)

func _on_grid_viewport_gui_input(event: InputEvent) -> void:
	if not core_grid:
		return
	
	if event is InputEventMouseMotion:
		mouse_grid_pos = event.position
		var c = int(event.position.x / CELL_SIZE)
		var r = int(event.position.y / CELL_SIZE)
		
		if c >= 0 and c < core_grid.get_cols() and r >= 0 and r < core_grid.get_rows():
			hover_grid_cell = Vector2i(c, r)
			var occupant = core_grid.get_component_at(c, r)
			if occupant != null and active_drag_comp == null:
				_show_tooltip_for_comp(occupant, grid_viewport.get_global_position() + Vector2(float(c + 1) * CELL_SIZE + 10.0, float(r) * CELL_SIZE))
			elif active_drag_comp == null:
				hide_tooltip()
		else:
			hover_grid_cell = Vector2i(-1, -1)
			if active_drag_comp == null:
				# Check if hovering locked cell
				if c < MAX_DISPLAY_COLS and r < MAX_DISPLAY_ROWS:
					_show_locked_tooltip(c, r, grid_viewport.get_global_position() + event.position + Vector2(15, 15))
				else:
					hide_tooltip()
		
		grid_viewport.queue_redraw()
	
	elif event is InputEventMouseButton and event.pressed:
		var c = int(event.position.x / CELL_SIZE)
		var r = int(event.position.y / CELL_SIZE)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if active_drag_comp != null:
				# Place component on grid
				if core_grid.can_place(active_drag_comp, c, r):
					core_grid.place_component(active_drag_comp, c, r)
					active_drag_comp = null
					drag_from_grid = false
					SoundManager.play("upgrade_select", 0.1, 0.0)
					if grid_tip_label:
						grid_tip_label.text = "Component installed successfully."
					refresh_all()
				else:
					SoundManager.play("hitmarker", 0.2, -2.0)
					if grid_tip_label:
						grid_tip_label.text = "Cannot install: Cells occupied or out of bounds."
			else:
				# Pick up placed component
				var occupant = core_grid.get_component_at(c, r)
				if occupant != null:
					active_drag_comp = occupant
					drag_from_grid = true
					drag_original_pos = occupant.grid_pos
					core_grid.remove_component(occupant)
					SoundManager.play("upgrade_select", 0.05, 1.0)
					hide_tooltip()
					if grid_tip_label:
						grid_tip_label.text = "Relocating %s. Left-click to place, Right-click to rotate." % active_drag_comp.name
					refresh_all()
					
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if active_drag_comp != null:
				_rotate_active_drag()
			else:
				# Rotate placed component directly on grid
				var occupant = core_grid.get_component_at(c, r)
				if occupant != null:
					var success = core_grid.rotate_placed_component(occupant)
					if success:
						SoundManager.play("upgrade_select", 0.05, 2.0)
						refresh_all()
					else:
						SoundManager.play("hitmarker", 0.2, -3.0)
						if grid_tip_label:
							grid_tip_label.text = "Cannot rotate: space blocked by adjacent components or boundary."

func _on_grid_viewport_mouse_exited() -> void:
	hover_grid_cell = Vector2i(-1, -1)
	if active_drag_comp == null:
		hide_tooltip()
	if grid_viewport:
		grid_viewport.queue_redraw()

func _on_stash_item_picked(comp: ComponentData) -> void:
	if active_drag_comp != null:
		_cancel_active_drag()
	
	active_drag_comp = comp
	drag_from_grid = false
	drag_original_pos = Vector2i(-1, -1)
	core_grid.remove_from_stash(comp)
	SoundManager.play("upgrade_select", 0.05, 1.0)
	hide_tooltip()
	if grid_tip_label:
		grid_tip_label.text = "Installing %s: Hover over 'Your Body' grid and Left-Click. Right-Click rotates." % comp.name
	refresh_all()

func _rotate_active_drag() -> void:
	if active_drag_comp == null:
		return
	active_drag_comp.rotate_90()
	SoundManager.play("upgrade_select", 0.05, 2.0)
	if grid_viewport:
		grid_viewport.queue_redraw()

func _cancel_active_drag() -> void:
	if active_drag_comp == null:
		return
	if drag_from_grid and drag_original_pos.x >= 0 and drag_original_pos.y >= 0:
		if core_grid.can_place(active_drag_comp, drag_original_pos.x, drag_original_pos.y):
			core_grid.place_component(active_drag_comp, drag_original_pos.x, drag_original_pos.y)
		else:
			core_grid.add_to_stash(active_drag_comp)
	else:
		core_grid.add_to_stash(active_drag_comp)
	active_drag_comp = null
	drag_from_grid = false
	if grid_tip_label:
		grid_tip_label.text = "Component returned to stash."
	refresh_all()

func _on_clear_all_pressed() -> void:
	if not core_grid:
		return
	var to_remove = core_grid.placed_components.duplicate()
	for comp in to_remove:
		core_grid.remove_component(comp)
	SoundManager.play("upgrade_select", 0.1, 0.0)
	if grid_tip_label:
		grid_tip_label.text = "All components recalled to stash."
	refresh_all()

func _on_rotate_active_pressed() -> void:
	_rotate_active_drag()

func _on_back_pressed() -> void:
	close()

func _on_grid_or_stash_changed() -> void:
	refresh_all()

func _on_dimensions_expanded(_new_rows: int, _new_cols: int) -> void:
	SoundManager.play("level_up", 0.2, 0.0)
	refresh_all()

# Tooltip Display
func _show_tooltip_for_comp(comp: ComponentData, global_pos: Vector2) -> void:
	if not tooltip_panel:
		return
	
	var r_col = comp.get_rarity_color()
	tooltip_name.text = comp.name
	tooltip_name.set("theme_override_colors/font_color", r_col)
	
	tooltip_rarity.text = "[ %s CYBERWARE ]" % comp.rarity.to_upper()
	tooltip_rarity.set("theme_override_colors/font_color", r_col)
	
	tooltip_shape.text = "Shape: %s (%d cells)" % [comp.shape_type, comp.base_cells.size()]
	
	for child in tooltip_stats_vbox.get_children():
		child.queue_free()
	
	var descs = comp.get_stat_descriptions()
	for d in descs:
		var lbl = Label.new()
		lbl.text = "• " + d
		lbl.set("theme_override_colors/font_color", Color(0.85, 0.95, 1.0, 0.95))
		lbl.set("theme_override_font_sizes/font_size", 11)
		tooltip_stats_vbox.add_child(lbl)
	
	if tooltip_hint:
		tooltip_hint.text = "Left-Click: Pick / Place • Right-Click: Rotate 90°"
	
	tooltip_panel.visible = true
	_position_tooltip(global_pos)

func _show_locked_tooltip(col: int, row: int, global_pos: Vector2) -> void:
	if not tooltip_panel or not core_grid:
		return
	
	tooltip_name.text = "🔒 LOCKED NEURAL SLOT"
	tooltip_name.set("theme_override_colors/font_color", Color(1.0, 0.4, 0.4))
	tooltip_rarity.text = "[ UNLOCK CRITERIA ]"
	tooltip_rarity.set("theme_override_colors/font_color", Color(1.0, 0.6, 0.6))
	
	tooltip_shape.text = "Coordinates: [%d, %d]" % [col, row]
	
	for child in tooltip_stats_vbox.get_children():
		child.queue_free()
	
	var req_lbl = Label.new()
	if col >= core_grid.get_cols():
		var wave_needed = (col - CoreGrid.DEFAULT_COLS + 1) * 10
		req_lbl.text = "• Requires reaching Wave %d to unlock this column." % wave_needed
	else:
		req_lbl.text = "• Defeat Stage 1 or Stage 2 Boss to expand neural rows."
	req_lbl.set("theme_override_colors/font_color", Color(0.9, 0.8, 0.8))
	req_lbl.set("theme_override_font_sizes/font_size", 11)
	req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_stats_vbox.add_child(req_lbl)
	
	if tooltip_hint:
		tooltip_hint.text = "Keep progressing through waves to expand 'Your Body'!"
	
	tooltip_panel.visible = true
	_position_tooltip(global_pos)

func _position_tooltip(pos: Vector2) -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var panel_size = tooltip_panel.size
	var target_x = clampf(pos.x, 10.0, vp_size.x - panel_size.x - 10.0)
	var target_y = clampf(pos.y, 10.0, vp_size.y - panel_size.y - 10.0)
	tooltip_panel.global_position = Vector2(target_x, target_y)

func hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false
