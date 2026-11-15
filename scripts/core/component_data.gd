class_name ComponentData
extends RefCounted

## Core Component Data Model
## Defines shapes, rarities, stat generation, and rotation for the RPG progression system.

const RARITY_COLORS: Dictionary = {
	"Common": Color(0.4, 0.8, 1.0, 1.0),     # Neon Cyan
	"Rare": Color(0.8, 0.3, 1.0, 1.0),       # Purple
	"Epic": Color(1.0, 0.6, 0.1, 1.0),       # Neon Orange
	"Legendary": Color(1.0, 0.9, 0.2, 1.0)   # Radiant Gold
}

const SHAPES: Dictionary = {
	"1x1": [Vector2i(0, 0)],
	"1x2": [Vector2i(0, 0), Vector2i(0, 1)],
	"2x1": [Vector2i(0, 0), Vector2i(1, 0)],
	"1x3": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	"3x1": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"2x2": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"L_shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"T_shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]
}

# Instance properties
var id: String = ""
var type_id: String = ""
var name: String = "Component"
var rarity: String = "Common"
var shape_type: String = "1x1"
var rotation_deg: int = 0 # 0, 90, 180, 270
var base_cells: Array[Vector2i] = [Vector2i(0, 0)]
var stats: Dictionary = {}
var grid_pos: Vector2i = Vector2i(-1, -1) # (-1, -1) = in stash/inventory

func _init() -> void:
	if id.is_empty():
		id = "comp_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

static func get_color_for_rarity(p_rarity: String) -> Color:
	return RARITY_COLORS.get(p_rarity, Color.WHITE)

## Rotates the component 90 degrees clockwise
func rotate_90() -> void:
	rotation_deg = (rotation_deg + 90) % 360

## Returns the cell offsets rotated by rotation_deg and normalized to (0, 0) top-left
func get_transformed_cells() -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	var min_x: int = 9999
	var min_y: int = 9999
	
	for cell in base_cells:
		var rx = cell.x
		var ry = cell.y
		match rotation_deg:
			90:
				rx = -cell.y
				ry = cell.x
			180:
				rx = -cell.x
				ry = -cell.y
			270:
				rx = cell.y
				ry = -cell.x
		rotated.append(Vector2i(rx, ry))
		if rx < min_x: min_x = rx
		if ry < min_y: min_y = ry
		
	var final_cells: Array[Vector2i] = []
	for c in rotated:
		final_cells.append(Vector2i(c.x - min_x, c.y - min_y))
	return final_cells

func get_width() -> int:
	var cells = get_transformed_cells()
	var max_x: int = 0
	for c in cells:
		if c.x > max_x: max_x = c.x
	return max_x + 1

func get_height() -> int:
	var cells = get_transformed_cells()
	var max_y: int = 0
	for c in cells:
		if c.y > max_y: max_y = c.y
	return max_y + 1

## Human-readable stat descriptions for hover tooltips
func get_stat_descriptions() -> Array[String]:
	var desc: Array[String] = []
	for k in stats:
		var v = stats[k]
		match k:
			"damage_mult":
				desc.append("+%d%% Projectile Damage" % int(round(v * 100.0)))
			"fire_rate_mult":
				desc.append("+%d%% Fire Rate" % int(round(v * 100.0)))
			"max_health_bonus":
				desc.append("+%d Maximum Health" % int(round(v)))
			"shield_max":
				desc.append("+%d Regenerating Shield" % int(round(v)))
			"speed_mult":
				desc.append("+%d%% Movement Speed" % int(round(v * 100.0)))
			"reload_speed_mult":
				desc.append("+%d%% Reload Speed" % int(round(v * 100.0)))
			"magazine_mult":
				desc.append("+%d%% Magazine Capacity" % int(round(v * 100.0)))
			"magnet_radius":
				desc.append("+%.1fm Collection Radius" % float(v))
			"crit_chance":
				desc.append("+%d%% Critical Chance" % int(round(v * 100.0)))
			"crit_damage":
				desc.append("+%.2fx Critical Damage" % float(v))
			"player_damage_reduction":
				desc.append("+%d%% Damage Reduction" % int(round(v * 100.0)))
			"vampiric_heal":
				desc.append("+%d HP on Enemy Kill" % int(round(v)))
			"pierce_count":
				desc.append("+%d Enemy Piercing" % int(v))
			"extra_projectiles":
				desc.append("+%d Extra Projectiles" % int(v))
			"greed_mult":
				desc.append("+%d%% Nanite & Scrap Drops" % int(round(v * 100.0)))
			"hit_invulnerability_duration":
				desc.append("+%.2fs Hit Invulnerability" % float(v))
			"explosive_rounds":
				if bool(v): desc.append("Explosive Payload (2.5m AoE)")
			"chain_lightning":
				if bool(v): desc.append("Tesla Arc Emitter (Chain Lightning)")
			"bouncing_bullets":
				if bool(v): desc.append("Smart Bouncing Core (+Ricochet)")
			"drone_count":
				desc.append("+%d Assault Companion Drone" % int(v))
			"cryo_slow":
				if bool(v): desc.append("Cryo Rounds (Slows enemies 25%)")
			"null_barrier_unlocked":
				if bool(v): desc.append("Null Barrier (Blocks damage every 10s)")
			"second_wind":
				if bool(v): desc.append("Emergency Defibrillator (Revive on fatal)")
			"cooldown_reduction":
				if bool(v): desc.append("-50% Class Skill Cooldown")
			"dual_capacitor":
				if bool(v): desc.append("+1 Class Skill Charge (Dual Capacitor)")
	return desc

## Serialization to Dictionary for JSON saving
func to_dict() -> Dictionary:
	var cells_arr: Array = []
	for c in base_cells:
		cells_arr.append([c.x, c.y])
	return {
		"id": id,
		"type_id": type_id,
		"name": name,
		"rarity": rarity,
		"shape_type": shape_type,
		"rotation_deg": rotation_deg,
		"base_cells": cells_arr,
		"stats": stats.duplicate(true),
		"grid_pos": [grid_pos.x, grid_pos.y]
	}

## Deserialization from Dictionary
static func from_dict(data: Dictionary) -> ComponentData:
	var comp = ComponentData.new()
	comp.id = data.get("id", "comp_%d_%d" % [Time.get_ticks_msec(), randi() % 10000])
	comp.type_id = data.get("type_id", "generic")
	comp.name = data.get("name", "Unknown Component")
	comp.rarity = data.get("rarity", "Common")
	comp.shape_type = data.get("shape_type", "1x1")
	comp.rotation_deg = int(data.get("rotation_deg", 0))
	comp.stats = data.get("stats", {}).duplicate(true)
	
	var raw_cells = data.get("base_cells", [])
	comp.base_cells.clear()
	for c in raw_cells:
		comp.base_cells.append(Vector2i(int(c[0]), int(c[1])))
	if comp.base_cells.is_empty():
		var template: Array = SHAPES.get(comp.shape_type, [Vector2i(0, 0)])
		for c in template:
			comp.base_cells.append(Vector2i(c.x, c.y))
	
	var gp = data.get("grid_pos", [-1, -1])
	comp.grid_pos = Vector2i(int(gp[0]), int(gp[1]))
	return comp

## Procedural Generator
static func generate_random_component(p_rarity: String = "Common", forced_shape: String = "") -> ComponentData:
	var comp = ComponentData.new()
	comp.rarity = p_rarity
	
	# Determine shape based on rarity if not forced
	var shape_candidates: Array[String] = []
	match p_rarity:
		"Common":
			shape_candidates = ["1x1", "1x1", "1x2", "2x1", "1x3", "3x1"]
		"Rare":
			shape_candidates = ["1x1", "1x2", "2x1", "1x3", "3x1", "L_shape", "2x2"]
		"Epic":
			shape_candidates = ["1x2", "2x1", "1x3", "3x1", "L_shape", "2x2", "T_shape"]
		"Legendary":
			shape_candidates = ["1x3", "3x1", "L_shape", "2x2", "T_shape"]
		_:
			shape_candidates = ["1x1", "1x2", "2x1"]
	
	if not forced_shape.is_empty() and SHAPES.has(forced_shape):
		comp.shape_type = forced_shape
	else:
		comp.shape_type = shape_candidates[randi() % shape_candidates.size()]
	
	comp.base_cells.clear()
	var template: Array = SHAPES.get(comp.shape_type, [Vector2i(0, 0)])
	for c in template:
		comp.base_cells.append(Vector2i(c.x, c.y))
	var cell_count: int = comp.base_cells.size()
	
	# Scaling: Bigger shapes roll stronger & multiple stats
	var size_scale: float = 1.0
	var num_stats: int = 1
	match cell_count:
		1:
			size_scale = 1.0
			num_stats = 1
		2:
			size_scale = 1.2
			num_stats = 1 if randf() < 0.35 else 2
		3:
			size_scale = 1.45
			num_stats = 2 if randf() < 0.50 else 3
		4:
			size_scale = 1.75
			num_stats = 2 + (randi() % 3) # 2 to 4 stats
	
	var rarity_scale: float = 1.0
	match p_rarity:
		"Common": rarity_scale = 1.0
		"Rare": rarity_scale = 1.25
		"Epic": rarity_scale = 1.5
		"Legendary": rarity_scale = 1.8
	
	var total_scale: float = size_scale * rarity_scale * randf_range(0.92, 1.08)
	
	# Stat Pools
	var common_stat_keys: Array[String] = [
		"damage_mult", "fire_rate_mult", "max_health_bonus", "speed_mult",
		"reload_speed_mult", "magazine_mult", "magnet_radius", "crit_chance"
	]
	var rare_stat_keys: Array[String] = [
		"shield_max", "player_damage_reduction", "crit_damage", "vampiric_heal",
		"pierce_count", "greed_mult", "cryo_slow"
	]
	var epic_stat_keys: Array[String] = [
		"explosive_rounds", "chain_lightning", "bouncing_bullets", "drone_count",
		"hit_invulnerability_duration", "null_barrier_unlocked", "extra_projectiles"
	]
	var legendary_stat_keys: Array[String] = [
		"second_wind", "cooldown_reduction", "dual_capacitor"
	]
	
	# Combined available pool based on rarity
	var available_pool: Array[String] = []
	var signature_keys: Array[String] = []
	match p_rarity:
		"Common":
			available_pool = common_stat_keys.duplicate()
		"Rare":
			available_pool = common_stat_keys + rare_stat_keys
			signature_keys = rare_stat_keys.duplicate()
		"Epic":
			available_pool = common_stat_keys + rare_stat_keys + epic_stat_keys
			signature_keys = epic_stat_keys.duplicate()
		"Legendary":
			available_pool = common_stat_keys + rare_stat_keys + epic_stat_keys + legendary_stat_keys
			signature_keys = legendary_stat_keys.duplicate()
	
	# Ensure at least 1 signature stat from the rarity tier (if applicable)
	var chosen_keys: Array[String] = []
	if not signature_keys.is_empty():
		var sig = signature_keys[randi() % signature_keys.size()]
		chosen_keys.append(sig)
		available_pool.erase(sig)
	
	while chosen_keys.size() < num_stats and not available_pool.is_empty():
		var idx = randi() % available_pool.size()
		var picked = available_pool[idx]
		chosen_keys.append(picked)
		available_pool.remove_at(idx)
	
	# Roll the values for the chosen stats
	var rolled_stats: Dictionary = {}
	var primary_stat: String = chosen_keys[0] if not chosen_keys.is_empty() else "damage_mult"
	
	for key in chosen_keys:
		match key:
			"damage_mult":
				rolled_stats["damage_mult"] = snappedf(randf_range(0.15, 0.35) * (total_scale / rarity_scale), 0.01)
			"fire_rate_mult":
				rolled_stats["fire_rate_mult"] = snappedf(randf_range(0.10, 0.40) * (total_scale / rarity_scale), 0.01)
			"max_health_bonus":
				rolled_stats["max_health_bonus"] = snappedf(randf_range(20.0, 50.0) * (total_scale / rarity_scale), 1.0)
			"shield_max":
				rolled_stats["shield_max"] = snappedf(randf_range(20.0, 50.0) * (total_scale / rarity_scale), 1.0)
			"crit_chance":
				rolled_stats["crit_chance"] = clampf(snappedf(randf_range(0.05, 0.20) * (total_scale / rarity_scale), 0.01), 0.05, 0.35)
			"crit_damage":
				rolled_stats["crit_damage"] = snappedf(randf_range(0.25, 0.75) * (total_scale / rarity_scale), 0.05)
			"speed_mult":
				rolled_stats["speed_mult"] = snappedf(randf_range(0.10, 0.25) * (total_scale / rarity_scale), 0.01)
			"reload_speed_mult":
				rolled_stats["reload_speed_mult"] = snappedf(randf_range(0.15, 0.35) * (total_scale / rarity_scale), 0.01)
			"magazine_mult":
				rolled_stats["magazine_mult"] = snappedf(randf_range(0.15, 0.40) * (total_scale / rarity_scale), 0.01)
			"magnet_radius":
				rolled_stats["magnet_radius"] = snappedf(randf_range(2.0, 5.0) * (total_scale / rarity_scale), 0.1)
			"greed_mult":
				rolled_stats["greed_mult"] = snappedf(randf_range(0.20, 0.50) * (total_scale / rarity_scale), 0.05)
			"player_damage_reduction":
				rolled_stats["player_damage_reduction"] = snappedf(randf_range(0.05, 0.15) * (total_scale / rarity_scale), 0.01)
			"hit_invulnerability_duration":
				rolled_stats["hit_invulnerability_duration"] = snappedf(randf_range(0.15, 0.30) * (total_scale / rarity_scale), 0.05)
			"vampiric_heal":
				rolled_stats["vampiric_heal"] = snappedf(randf_range(2.0, 6.0) * (total_scale / rarity_scale), 1.0)
			"pierce_count":
				rolled_stats["pierce_count"] = 2 if total_scale > 1.8 else 1
			"extra_projectiles":
				rolled_stats["extra_projectiles"] = 1
			"bouncing_bullets":
				rolled_stats["bouncing_bullets"] = true
				rolled_stats["bounce_count"] = 2 if total_scale > 1.8 else 1
			"explosive_rounds":
				rolled_stats["explosive_rounds"] = true
			"cryo_slow":
				rolled_stats["cryo_slow"] = true
			"chain_lightning":
				rolled_stats["chain_lightning"] = true
				rolled_stats["chain_lightning_targets"] = 3 if total_scale > 1.8 else 2
			"drone_count":
				rolled_stats["drone_count"] = 1
			"null_barrier_unlocked":
				rolled_stats["null_barrier_unlocked"] = true
			"second_wind":
				rolled_stats["second_wind"] = true
			"cooldown_reduction":
				rolled_stats["cooldown_reduction"] = true
			"dual_capacitor":
				rolled_stats["dual_capacitor"] = true
	
	comp.stats = rolled_stats
	
	# Generate Cyberpunk Procedural Name based on Primary Stat and Rarity
	comp.name = _generate_name(primary_stat, p_rarity, comp.shape_type)
	comp.type_id = primary_stat
	return comp

static func _generate_name(primary_stat: String, p_rarity: String, p_shape: String) -> String:
	var prefix_map: Dictionary = {
		"Common": ["Overclocked", "Reinforced", "Precision", "Kinetic", "Supercharged", "Hardened", "Nano-Tuned", "Hyper"],
		"Rare": ["Apex", "Plasma", "Cybernetic", "Voltaic", "Vampiric", "Cryogenic", "Titanium", "Quantum"],
		"Epic": ["Apex", "Plasma", "Cybernetic", "Voltaic", "Vampiric", "Cryogenic", "Titanium", "Quantum"],
		"Legendary": ["Omega", "God-Core", "Singularity", "Chronos", "Void-Forged", "Eclipse", "Aegis Prime"]
	}
	var root_map: Dictionary = {
		"damage_mult": "Caliber Core",
		"fire_rate_mult": "Trigger Actuator",
		"max_health_bonus": "Vital Plating",
		"shield_max": "Energy Shield Matrix",
		"crit_chance": "Optic Lens",
		"crit_damage": "Hollow-Point Module",
		"speed_mult": "Kinetic Thruster",
		"reload_speed_mult": "Rapid Loader",
		"magazine_mult": "Expanded Magazine",
		"magnet_radius": "Nanite Collector",
		"greed_mult": "Scavenger Sensor",
		"player_damage_reduction": "Hardened Alloy",
		"hit_invulnerability_duration": "Phase-Shield Emitter",
		"vampiric_heal": "Siphon Conduit",
		"pierce_count": "Penetrator Spike",
		"extra_projectiles": "Barrel Splitter",
		"bouncing_bullets": "Ricochet Mod",
		"explosive_rounds": "Explosive Warhead",
		"cryo_slow": "Cryo Capacitor",
		"chain_lightning": "Tesla Arc Emitter",
		"drone_count": "Assault Drone Bay",
		"null_barrier_unlocked": "Null Barrier Aegis",
		"second_wind": "Defibrillator Protocol",
		"cooldown_reduction": "Chrono Accelerator",
		"dual_capacitor": "Dual Capacitor"
	}
	
	var prefixes: Array = prefix_map.get(p_rarity, ["Cyber"])
	var pfx = prefixes[randi() % prefixes.size()]
	var root = root_map.get(primary_stat, "Component")
	return "%s %s [%s]" % [pfx, root, p_shape]
