extends Node
## Ship grid management — handles placing, upgrading, and removing cells.
## This is the player-facing API for grid operations.

# Cost to build each cell type (level 1)
const BUILD_COSTS = {
	"miner": {"alloy": 10.0},
	"gas_collector": {"alloy": 15.0},
	"crystal_harvester": {"alloy": 25.0, "microchips": 5.0},
	"greenhouse": {"alloy": 10.0, "organics": 5.0},
	"smelter": {"alloy": 20.0},
	"fab_plant": {"alloy": 30.0, "microchips": 10.0},
	"refinery": {"alloy": 25.0, "fuel_cells": 5.0},
	"assembly": {"alloy": 50.0, "microchips": 20.0},
	"biolab": {"alloy": 20.0, "organics": 10.0},
	"reactor": {"alloy": 40.0, "microchips": 15.0},
	"habitat": {"alloy": 15.0},
	"drone_bay": {"alloy": 30.0, "microchips": 10.0},
	"turret": {"alloy": 20.0, "ammo": 5.0},
	"storage": {"alloy": 10.0}
}

# Cost multiplier per level for upgrades
const UPGRADE_COST_MULTIPLIER: float = 1.5


func build_cell(type_name: String, pos: Vector2i) -> bool:
	## Try to build a cell at the given position. Returns true on success.
	if not type_name in BUILD_COSTS:
		return false
	
	var cost: Dictionary = BUILD_COSTS[type_name].duplicate()
	
	if not GameState.spend_resources(cost):
		return false
	
	return GameState.add_cell(type_name, pos)


func upgrade_cell(pos: Vector2i) -> bool:
	## Try to upgrade an existing cell. Cost scales with current level.
	var cell: Dictionary = _find_cell(pos)
	if cell.is_empty():
		return false
	
	var type_name: String = cell["type"]
	if not type_name in BUILD_COSTS:
		return false
	
	# Cost = base_cost * multiplier^(current_level)
	var cost: Dictionary = {}
	var base_cost: Dictionary = BUILD_COSTS[type_name]
	var cost_mult: float = pow(UPGRADE_COST_MULTIPLIER, cell["level"])
	
	for res in base_cost:
		cost[res] = base_cost[res] * cost_mult
	
	if not GameState.spend_resources(cost):
		return false
	
	return GameState.upgrade_cell(pos)


func remove_cell(pos: Vector2i) -> bool:
	## Remove a cell. No refund (idle games usually don't refund).
	return GameState.remove_cell(pos)


func get_upgrade_cost_for(pos: Vector2i) -> Dictionary:
	## Preview upgrade cost for UI.
	var cell: Dictionary = _find_cell(pos)
	if cell.is_empty():
		return {}
	
	var type_name: String = cell["type"]
	if not type_name in BUILD_COSTS:
		return {}
	
	var cost: Dictionary = {}
	var base_cost: Dictionary = BUILD_COSTS[type_name]
	var cost_mult: float = pow(UPGRADE_COST_MULTIPLIER, cell["level"])
	
	for res in base_cost:
		cost[res] = base_cost[res] * cost_mult
	
	return cost


func get_build_cost_for(type_name: String) -> Dictionary:
	## Preview build cost for UI.
	return BUILD_COSTS.get(type_name, {}).duplicate()


func _find_cell(pos: Vector2i) -> Dictionary:
	for cell in GameState.grid:
		if cell["grid_pos"] == pos:
			return cell
	return {}


# ---------- JUMP REQUIREMENTS (for UI) ----------

func can_jump() -> bool:
	var cost: Dictionary = GameState.sector_params.get("jump_cost", {})
	return GameState.has_resources(cost)


func get_jump_cost() -> Dictionary:
	return GameState.sector_params.get("jump_cost", {}).duplicate()
