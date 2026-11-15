class_name CoreGrid
extends RefCounted

## Backpack Battles-style Core Grid & Inventory System
## Manages cell occupancy, placement, rotation, boundary checks, progression milestones,
## persistence (user://save_core.json), and aggregate player bonus calculations.

signal grid_changed()
signal stash_changed()
signal dimensions_expanded(new_rows: int, new_cols: int)
signal component_placed(comp: ComponentData, at_col: int, at_row: int)
signal component_removed(comp: ComponentData)

const SAVE_PATH: String = "user://save_core.json"
const DEFAULT_ROWS: int = 4
const DEFAULT_COLS: int = 5

const ComponentDataScript = preload("res://scripts/core/component_data.gd")

static var instance: CoreGrid = null

var unlocked_rows: int = DEFAULT_ROWS
var unlocked_cols: int = DEFAULT_COLS
var highest_wave_reached: int = 1
var stage1_boss_defeated: bool = false
var stage2_boss_defeated: bool = false

var placed_components: Array[ComponentData] = []
var stash: Array[ComponentData] = []
var grid_cells: Dictionary = {} # Vector2i(col, row) -> ComponentData

func _init() -> void:
	instance = self
	load_from_disk()

static func get_instance() -> CoreGrid:
	if instance == null:
		instance = CoreGrid.new()
	return instance

# Static convenience wrappers for external systems
static func add_to_stash_static(comp: ComponentData) -> void:
	get_instance().add_to_stash(comp)

static func unlock_wave_milestone(wave: int) -> void:
	get_instance()._unlock_wave_milestone_internal(wave)

static func unlock_boss_defeat(stage: int) -> void:
	get_instance()._unlock_boss_defeat_internal(stage)

static func get_aggregate_bonuses() -> Dictionary:
	return get_instance().calculate_aggregate_bonuses()

# Grid Dimensions & Queries
func get_rows() -> int:
	return unlocked_rows

func get_cols() -> int:
	return unlocked_cols

func is_within_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < unlocked_cols and row >= 0 and row < unlocked_rows

func get_component_at(col: int, row: int) -> ComponentData:
	return grid_cells.get(Vector2i(col, row), null)

func is_cell_occupied(col: int, row: int, ignore_comp: ComponentData = null) -> bool:
	var occupant = grid_cells.get(Vector2i(col, row), null)
	if occupant == null:
		return false
	if ignore_comp != null and occupant == ignore_comp:
		return false
	return true

## Checks if a component can be placed at (at_col, at_row) with its current rotation
func can_place(comp: ComponentData, at_col: int, at_row: int) -> bool:
	var transformed = comp.get_transformed_cells()
	for offset in transformed:
		var target_pos = Vector2i(at_col + offset.x, at_row + offset.y)
		if not is_within_bounds(target_pos.x, target_pos.y):
			return false
		if is_cell_occupied(target_pos.x, target_pos.y, comp):
			return false
	return true

## Places component on grid at (at_col, at_row). Removes from stash or former grid pos.
func place_component(comp: ComponentData, at_col: int, at_row: int) -> bool:
	if not can_place(comp, at_col, at_row):
		return false
	
	# If already placed elsewhere on grid, clear previous cells
	if placed_components.has(comp):
		for offset in comp.get_transformed_cells():
			var old_pos = Vector2i(comp.grid_pos.x + offset.x, comp.grid_pos.y + offset.y)
			if grid_cells.get(old_pos) == comp:
				grid_cells.erase(old_pos)
	else:
		stash.erase(comp)
		placed_components.append(comp)
	
	comp.grid_pos = Vector2i(at_col, at_row)
	for offset in comp.get_transformed_cells():
		var cell_pos = Vector2i(at_col + offset.x, at_row + offset.y)
		grid_cells[cell_pos] = comp
	
	save_to_disk()
	grid_changed.emit()
	stash_changed.emit()
	component_placed.emit(comp, at_col, at_row)
	return true

## Removes component from grid and returns it to stash
func remove_component(comp: ComponentData) -> void:
	if placed_components.has(comp):
		for offset in comp.get_transformed_cells():
			var cell_pos = Vector2i(comp.grid_pos.x + offset.x, comp.grid_pos.y + offset.y)
			if grid_cells.get(cell_pos) == comp:
				grid_cells.erase(cell_pos)
		placed_components.erase(comp)
	
	comp.grid_pos = Vector2i(-1, -1)
	if not stash.has(comp):
		stash.append(comp)
	
	save_to_disk()
	grid_changed.emit()
	stash_changed.emit()
	component_removed.emit(comp)

## Rotates a placed component 90 degrees if space allows, or in stash freely
func rotate_placed_component(comp: ComponentData) -> bool:
	if not placed_components.has(comp):
		comp.rotate_90()
		stash_changed.emit()
		return true
	
	var orig_pos = comp.grid_pos
	var orig_rot = comp.rotation_deg
	
	# Temporarily clear occupancy
	for offset in comp.get_transformed_cells():
		grid_cells.erase(Vector2i(orig_pos.x + offset.x, orig_pos.y + offset.y))
	
	comp.rotate_90()
	if can_place(comp, orig_pos.x, orig_pos.y):
		for offset in comp.get_transformed_cells():
			grid_cells[Vector2i(orig_pos.x + offset.x, orig_pos.y + offset.y)] = comp
		save_to_disk()
		grid_changed.emit()
		return true
	else:
		# Restore previous rotation
		comp.rotation_deg = orig_rot
		for offset in comp.get_transformed_cells():
			grid_cells[Vector2i(orig_pos.x + offset.x, orig_pos.y + offset.y)] = comp
		return false

## Returns all global grid cell coordinates occupied by this component
func get_component_occupied_cells(comp: ComponentData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if comp.grid_pos.x < 0 or comp.grid_pos.y < 0:
		return result
	for offset in comp.get_transformed_cells():
		result.append(Vector2i(comp.grid_pos.x + offset.x, comp.grid_pos.y + offset.y))
	return result

## Stash Management
func add_to_stash(comp: ComponentData) -> void:
	comp.grid_pos = Vector2i(-1, -1)
	if not stash.has(comp):
		stash.append(comp)
	save_to_disk()
	stash_changed.emit()

func remove_from_stash(comp: ComponentData) -> void:
	stash.erase(comp)
	save_to_disk()
	stash_changed.emit()

func delete_component(comp: ComponentData) -> void:
	if placed_components.has(comp):
		for offset in comp.get_transformed_cells():
			var cell_pos = Vector2i(comp.grid_pos.x + offset.x, comp.grid_pos.y + offset.y)
			if grid_cells.get(cell_pos) == comp:
				grid_cells.erase(cell_pos)
		placed_components.erase(comp)
	stash.erase(comp)
	save_to_disk()
	grid_changed.emit()
	stash_changed.emit()

# Progression Triggers
func _unlock_wave_milestone_internal(wave: int) -> void:
	if wave > highest_wave_reached:
		highest_wave_reached = wave
		var earned_cols: int = int(highest_wave_reached / 10)
		var target_cols: int = DEFAULT_COLS + earned_cols
		if target_cols > unlocked_cols:
			unlocked_cols = target_cols
			dimensions_expanded.emit(unlocked_rows, unlocked_cols)
			save_to_disk()

func _unlock_boss_defeat_internal(stage: int) -> void:
	var changed: bool = false
	if stage == 1 and not stage1_boss_defeated:
		stage1_boss_defeated = true
		unlocked_rows += 2
		changed = true
	elif stage == 2 and not stage2_boss_defeated:
		stage2_boss_defeated = true
		unlocked_rows += 2
		changed = true
	
	if changed:
		dimensions_expanded.emit(unlocked_rows, unlocked_cols)
		save_to_disk()

# Aggregate Bonuses Calculation for Player & Weapons
func calculate_aggregate_bonuses() -> Dictionary:
	var bonuses: Dictionary = {
		"damage_mult": 1.0,
		"fire_rate_mult": 1.0,
		"speed_mult": 1.0,
		"reload_speed_mult": 1.0,
		"magazine_mult": 1.0,
		"magnet_radius": 6.0,
		"extra_projectiles": 0,
		"extra_projectile_mult": 0.0,
		"pierce_count": 0,
		"explosive_rounds": false,
		"explosion_radius": 2.5,
		"bouncing_bullets": false,
		"bounce_count": 0,
		"chain_lightning": false,
		"chain_lightning_targets": 0,
		"vampiric_heal": 0.0,
		"shield_max": 0.0,
		"drone_count": 0,
		"cryo_slow": false,
		"crit_chance": 0.10,
		"crit_damage": 2.0,
		"max_health_bonus": 0.0,
		"player_damage_reduction": 0.0,
		"hit_invulnerability_duration": 0.0,
		"null_barrier_unlocked": false,
		"second_wind_unlocked": false,
		"cooldown_reduction": false,
		"dual_capacitor": false,
		"greed_mult": 1.0
	}
	
	for comp in placed_components:
		for k in comp.stats:
			var v = comp.stats[k]
			match k:
				"damage_mult":
					bonuses["damage_mult"] += float(v)
				"fire_rate_mult":
					bonuses["fire_rate_mult"] += float(v)
				"speed_mult":
					bonuses["speed_mult"] += float(v)
				"reload_speed_mult":
					bonuses["reload_speed_mult"] += float(v)
				"magazine_mult":
					bonuses["magazine_mult"] += float(v)
				"magnet_radius":
					bonuses["magnet_radius"] += float(v)
				"extra_projectiles":
					bonuses["extra_projectiles"] += int(v)
					bonuses["extra_projectile_mult"] += float(v)
				"pierce_count":
					bonuses["pierce_count"] += int(v)
				"explosive_rounds":
					if bool(v): bonuses["explosive_rounds"] = true
				"bouncing_bullets":
					if bool(v):
						bonuses["bouncing_bullets"] = true
						bonuses["bounce_count"] += int(comp.stats.get("bounce_count", 2))
				"bounce_count":
					bonuses["bouncing_bullets"] = true
					bonuses["bounce_count"] += int(v)
				"chain_lightning":
					if bool(v):
						bonuses["chain_lightning"] = true
						bonuses["chain_lightning_targets"] += int(comp.stats.get("chain_lightning_targets", 2))
				"chain_lightning_targets":
					bonuses["chain_lightning"] = true
					bonuses["chain_lightning_targets"] += int(v)
				"shield_max":
					bonuses["shield_max"] += float(v)
				"vampiric_heal":
					bonuses["vampiric_heal"] += float(v)
				"drone_count":
					bonuses["drone_count"] += int(v)
				"cryo_slow":
					if bool(v): bonuses["cryo_slow"] = true
				"crit_chance":
					bonuses["crit_chance"] += float(v)
				"crit_damage":
					bonuses["crit_damage"] += float(v)
				"max_health_bonus":
					bonuses["max_health_bonus"] += float(v)
				"player_damage_reduction":
					bonuses["player_damage_reduction"] = minf(0.60, bonuses["player_damage_reduction"] + float(v))
				"hit_invulnerability_duration":
					bonuses["hit_invulnerability_duration"] = minf(0.50, bonuses["hit_invulnerability_duration"] + float(v))
				"null_barrier_unlocked":
					if bool(v): bonuses["null_barrier_unlocked"] = true
				"second_wind":
					if bool(v): bonuses["second_wind_unlocked"] = true
				"cooldown_reduction":
					if bool(v): bonuses["cooldown_reduction"] = true
				"dual_capacitor":
					if bool(v): bonuses["dual_capacitor"] = true
				"greed_mult":
					bonuses["greed_mult"] += float(v)
					
	return bonuses

# Progression Persistence (user://save_core.json)
func save_to_disk() -> void:
	var placed_data: Array = []
	for comp in placed_components:
		placed_data.append(comp.to_dict())
	
	var stash_data: Array = []
	for comp in stash:
		stash_data.append(comp.to_dict())
	
	var save_dict: Dictionary = {
		"unlocked_rows": unlocked_rows,
		"unlocked_cols": unlocked_cols,
		"highest_wave_reached": highest_wave_reached,
		"stage1_boss_defeated": stage1_boss_defeated,
		"stage2_boss_defeated": stage2_boss_defeated,
		"placed_components": placed_data,
		"stash": stash_data
	}
	
	var json_str = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_default_save()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_init_default_save()
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK or not (json.data is Dictionary):
		_init_default_save()
		return
	
	var data: Dictionary = json.data
	unlocked_rows = maxi(DEFAULT_ROWS, int(data.get("unlocked_rows", DEFAULT_ROWS)))
	unlocked_cols = maxi(DEFAULT_COLS, int(data.get("unlocked_cols", DEFAULT_COLS)))
	highest_wave_reached = maxi(1, int(data.get("highest_wave_reached", 1)))
	stage1_boss_defeated = bool(data.get("stage1_boss_defeated", false))
	stage2_boss_defeated = bool(data.get("stage2_boss_defeated", false))
	
	placed_components.clear()
	stash.clear()
	grid_cells.clear()
	
	var placed_raw = data.get("placed_components", [])
	for p_dict in placed_raw:
		if p_dict is Dictionary:
			var comp = ComponentDataScript.from_dict(p_dict)
			placed_components.append(comp)
			for offset in comp.get_transformed_cells():
				var pos = Vector2i(comp.grid_pos.x + offset.x, comp.grid_pos.y + offset.y)
				grid_cells[pos] = comp
	
	var stash_raw = data.get("stash", [])
	for s_dict in stash_raw:
		if s_dict is Dictionary:
			var comp = ComponentDataScript.from_dict(s_dict)
			comp.grid_pos = Vector2i(-1, -1)
			stash.append(comp)

func _init_default_save() -> void:
	unlocked_rows = DEFAULT_ROWS
	unlocked_cols = DEFAULT_COLS
	highest_wave_reached = 1
	stage1_boss_defeated = false
	stage2_boss_defeated = false
	placed_components.clear()
	stash.clear()
	grid_cells.clear()
	
	# Give starter components in stash so the player immediately has items to equip
	var starter1 = ComponentDataScript.generate_random_component("Common", "1x1")
	starter1.name = "Kinetic Servo [1x1]"
	starter1.stats = {"damage_mult": 0.20}
	stash.append(starter1)
	
	var starter2 = ComponentDataScript.generate_random_component("Common", "1x2")
	starter2.name = "Pulse Capacitor [1x2]"
	starter2.stats = {"fire_rate_mult": 0.25, "max_health_bonus": 25.0}
	stash.append(starter2)
	
	save_to_disk()
