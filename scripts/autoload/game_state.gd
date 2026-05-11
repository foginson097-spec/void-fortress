extends Node
## Central game state — all systems read/write through this autoload singleton.
## Never instantiated manually. Access globally as `GameState.xxx`.

# ---------- RESOURCES ----------
# { "ore": float, "gas": float, "crystals": float, "alloy": float, ... }
var resources: Dictionary = {}

# ---------- SHIP GRID ----------
# Array of cell dicts: { "type": "miner", "level": int, "grid_pos": Vector2i }
# grid_pos is 0-based: (col, row)
var grid: Array = []

# Grid dimensions (server-authoritative; UI renders this size)
const GRID_COLS: int = 8
const GRID_ROWS: int = 6

# ---------- POPULATION ----------
var population: int = 0
var max_population: int = 0

# ---------- DRONES ----------
var drones: int = 0
var max_drones: int = 0

# ---------- DEFENSE ----------
var defense_dps: float = 0.0

# ---------- SECTOR ----------
# 0 = Sector 1 (Asteroid Belt), 1 = Sector 2 (Nebula), etc.
var current_sector: int = 0
var sector_params: Dictionary = {}  # loaded from sectors.tres

# ---------- PRESTIGE ----------
var tech_points: float = 0.0
var permanent_upgrades: Dictionary = {}  # { "mining_bonus": 0.0, "auto_craft": false, ... }

# ---------- TIME ----------
# Unix timestamp of last save (used for offline progress calculation)
var last_save_timestamp: float = 0.0

# How many seconds have passed in this session since last tick
@warning_ignore("unused_private_class_variable")
var _accumulated_time: float = 0.0

# ---------- SIGNALS ----------
signal resources_changed
signal grid_changed
signal population_changed
signal defense_changed
signal sector_changed
signal prestige_changed
signal game_ticked  # emitted every tick (1 sec)

# ---------- CONSTANTS ----------
const TICK_INTERVAL: float = 1.0  # one tick per second
const SAVE_PATH: String = "user://save.json"

# ---------- INITIALIZATION ----------

func _ready() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	## Full reset (new game or prestige)
	resources = {
		"ore": 0.0,
		"gas": 0.0,
		"crystals": 0.0,
		"organics": 0.0,
		"alloy": 0.0,
		"microchips": 0.0,
		"fuel_cells": 0.0,
		"modules": 0.0,
		"ammo": 0.0,
		"medkits": 0.0,
		"energy": 10.0
	}
	grid = []
	population = 5  # start with a handful of crew
	max_population = 10
	drones = 1
	max_drones = 3
	defense_dps = 0.0
	current_sector = 0
	tech_points = 0.0
	permanent_upgrades = {
		"mining_bonus": 0.0,
		"crafting_speed": 0.0,
		"defense_bonus": 0.0,
		"pop_growth_bonus": 0.0,
		"auto_craft": false,
		"start_turrets": 0
	}
	_load_sector_params()


func _load_sector_params() -> void:
	## Loads sector-specific modifiers based on current_sector index.
	# Sector 0: Asteroid Belt — basic
	# Sector 1: Nebula — gas boost, crystals appear
	# Sector 2: Factory Cluster — intermediate boost, pirates x2
	# Sector 3: Deep Void — all resources, rare artifacts
	# Sector 4+: infinite scaling
	var base = {
		"name": "Asteroid Belt",
		"resource_mult": {"ore": 1.0, "gas": 1.0, "crystals": 0.0, "organics": 1.0},
		"pirate_strength": 1.0,
		"pirate_interval": 300.0,  # seconds between waves
		"crystal_threshold": 0  # dmg needed to start getting crystals
	}
	
	match current_sector:
		0:
			base = {
				"name": "Asteroid Belt",
				"resource_mult": {"ore": 1.0, "gas": 1.0, "crystals": 0.0, "organics": 1.0},
				"pirate_strength": 1.0,
				"pirate_interval": 300.0,
				"jump_cost": {"alloy": 50.0, "fuel_cells": 25.0}
			}
		1:
			base = {
				"name": "Nebula",
				"resource_mult": {"ore": 0.8, "gas": 2.0, "crystals": 1.0, "organics": 0.5},
				"pirate_strength": 2.0,
				"pirate_interval": 240.0,
				"jump_cost": {"alloy": 200.0, "fuel_cells": 100.0, "microchips": 50.0}
			}
		2:
			base = {
				"name": "Factory Cluster",
				"resource_mult": {"ore": 1.5, "gas": 1.0, "crystals": 1.5, "organics": 1.0},
				"pirate_strength": 5.0,
				"pirate_interval": 180.0,
				"jump_cost": {"alloy": 500.0, "fuel_cells": 250.0, "modules": 100.0}
			}
		3:
			base = {
				"name": "Deep Void",
				"resource_mult": {"ore": 2.0, "gas": 2.0, "crystals": 2.0, "organics": 2.0},
				"pirate_strength": 12.0,
				"pirate_interval": 150.0,
				"jump_cost": {"alloy": 2000.0, "fuel_cells": 1000.0, "modules": 400.0, "microchips": 300.0}
			}
		_:
			# Infinite sectors: scale exponentially
			var scale = pow(1.5, current_sector - 3)
			base = {
				"name": "Sector %d" % (current_sector + 1),
				"resource_mult": {"ore": 2.0 * scale, "gas": 2.0 * scale, "crystals": 2.0 * scale, "organics": 2.0 * scale},
				"pirate_strength": 12.0 * scale,
				"pirate_interval": max(60.0, 150.0 / scale),
				"jump_cost": {
					"alloy": 2000.0 * pow(2.0, current_sector - 3),
					"fuel_cells": 1000.0 * pow(2.0, current_sector - 3)
				}
			}
	
	sector_params = base


# ---------- RESOURCE HELPERS ----------

func has_resources(cost: Dictionary) -> bool:
	for res in cost:
		if resources.get(res, 0.0) < cost[res]:
			return false
	return true


func spend_resources(cost: Dictionary) -> bool:
	if not has_resources(cost):
		return false
	for res in cost:
		resources[res] -= cost[res]
	resources_changed.emit()
	return true


func add_resources(gains: Dictionary) -> void:
	for res in gains:
		resources[res] = resources.get(res, 0.0) + gains[res]
	resources_changed.emit()


# ---------- GRID HELPERS ----------

func get_cells_of_type(type_name: String) -> Array:
	var result: Array = []
	for cell in grid:
		if cell["type"] == type_name:
			result.append(cell)
	return result


func count_cells_of_type(type_name: String) -> int:
	return get_cells_of_type(type_name).size()


func get_total_level_of_type(type_name: String) -> int:
	var total: int = 0
	for cell in get_cells_of_type(type_name):
		total += cell["level"]
	return total


func is_grid_pos_free(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= GRID_COLS or pos.y < 0 or pos.y >= GRID_ROWS:
		return false
	for cell in grid:
		if cell["grid_pos"] == pos:
			return false
	return true


func add_cell(type_name: String, pos: Vector2i) -> bool:
	if not is_grid_pos_free(pos):
		return false
	grid.append({
		"type": type_name,
		"level": 1,
		"grid_pos": pos
	})
	_recalc_derived_stats()
	grid_changed.emit()
	return true


func upgrade_cell(grid_pos: Vector2i) -> bool:
	for cell in grid:
		if cell["grid_pos"] == grid_pos:
			cell["level"] += 1
			_recalc_derived_stats()
			grid_changed.emit()
			return true
	return false


func remove_cell(grid_pos: Vector2i) -> bool:
	for i in range(grid.size()):
		if grid[i]["grid_pos"] == grid_pos:
			grid.remove_at(i)
			_recalc_derived_stats()
			grid_changed.emit()
			return true
	return false


func _recalc_derived_stats() -> void:
	## Recalculate max_population, max_drones, defense_dps from grid cells.
	max_population = 10  # base
	max_drones = 3  # base
	var total_defense: float = 0.0
	
	for cell in grid:
		match cell["type"]:
			"habitat":
				max_population += cell["level"] * 5
			"drone_bay":
				max_drones += cell["level"] * 2
			"turret":
				total_defense += cell["level"] * 5.0
	
	defense_dps = total_defense * (1.0 + drones * 0.1)  # drones boost defense
	defense_dps *= (1.0 + permanent_upgrades.get("defense_bonus", 0.0))
	
	population = min(population, max_population)
	drones = min(drones, max_drones)
	
	population_changed.emit()
	defense_changed.emit()


# ---------- ENERGY ----------

func get_total_energy_consumption() -> float:
	var consumption: float = 0.0
	for cell in grid:
		consumption += cell["level"] * 0.5
	return consumption


func get_energy_production() -> float:
	var total: float = 0.0
	for cell in get_cells_of_type("reactor"):
		total += cell["level"] * 3.0
	return total
