extends Node
## Passive resource generation system. Runs every tick (1 second).
## Reads grid state, writes to GameState.resources.

# Base production per level for each resource type
const BASE_PRODUCTION = {
	"ore": 1.0,
	"gas": 0.8,
	"crystals": 0.3,
	"organics": 0.5
}

# Which resource each miner type produces
const MINER_TYPES = {
	"miner": "ore",
	"gas_collector": "gas",
	"crystal_harvester": "crystals",
	"greenhouse": "organics"
}


func tick() -> Dictionary:
	## Run one tick of resource generation. Returns {resource: amount_gained}.
	var gains: Dictionary = {}
	
	# 1. Energy production and consumption
	var energy_produced: float = GameState.get_energy_production()
	var energy_consumed: float = GameState.get_total_energy_consumption()
	var energy_balance: float = energy_produced - energy_consumed
	gains["energy"] = energy_balance
	
	# 2. If energy is negative (deficit), cut all production proportionally
	var efficiency: float = 1.0
	if energy_balance < 0 and energy_consumed > 0:
		efficiency = max(0.2, energy_produced / energy_consumed)
	
	# 3. Mining from grid cells
	for cell in GameState.grid:
		if cell["type"] in MINER_TYPES:
			var resource: String = MINER_TYPES[cell["type"]]
			var base: float = BASE_PRODUCTION.get(resource, 1.0)
			var produced: float = _calculate_mining_output(cell, base)
			gains[resource] = gains.get(resource, 0.0) + produced
	
	# 4. Apply efficiency penalty
	if efficiency < 1.0:
		for res in gains:
			gains[res] *= efficiency
	
	# 5. Apply to GameState
	GameState.add_resources(gains)
	
	return gains


func _calculate_mining_output(cell: Dictionary, base_rate: float) -> float:
	var resource: String = MINER_TYPES.get(cell["type"], "ore")
	
	# Base output
	var output: float = base_rate * cell["level"]
	
	# Sector multiplier
	var sector_mult: float = GameState.sector_params.get("resource_mult", {}).get(resource, 1.0)
	output *= sector_mult
	
	# Permanent upgrade bonus
	output *= (1.0 + GameState.permanent_upgrades.get("mining_bonus", 0.0))
	
	# Drone bonus: each drone gives +5% to all production
	output *= (1.0 + GameState.drones * 0.05)
	
	return output


func get_production_summary() -> Dictionary:
	## Returns estimated per-second production for UI display.
	# Run a dry tick without modifying state
	var summary: Dictionary = {}
	
	for cell in GameState.grid:
		if cell["type"] in MINER_TYPES:
			var resource: String = MINER_TYPES[cell["type"]]
			var base: float = BASE_PRODUCTION.get(resource, 1.0)
			summary[resource] = summary.get(resource, 0.0) + _calculate_mining_output(cell, base)
	
	return summary
