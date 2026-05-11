extends Node
## Crafting system — converts raw resources into intermediate and finished products.
## Runs every tick. Reads from GameState.resources, writes back.

# Recipe definitions: { output: { input_resource: amount }, output_resource: amount_produced }
# Format: recipe_name = { "inputs": {...}, "output": resource_name, "amount": N, "time_per_unit": seconds }
const RECIPES = {
	"smelt_alloy": {
		"inputs": {"ore": 3.0},
		"output": "alloy",
		"amount": 1.0,
		"time_per_unit": 2.0  # base seconds for 1 factory level to produce 1 unit
	},
	"fabricate_chips": {
		"inputs": {"crystals": 2.0, "alloy": 1.0},
		"output": "microchips",
		"amount": 1.0,
		"time_per_unit": 3.0
	},
	"refine_fuel": {
		"inputs": {"gas": 2.0},
		"output": "fuel_cells",
		"amount": 1.0,
		"time_per_unit": 1.5
	},
	"assemble_module": {
		"inputs": {"alloy": 3.0, "microchips": 2.0},
		"output": "modules",
		"amount": 1.0,
		"time_per_unit": 5.0
	},
	"produce_ammo": {
		"inputs": {"alloy": 1.0},
		"output": "ammo",
		"amount": 2.0,
		"time_per_unit": 1.0
	},
	"grow_medkits": {
		"inputs": {"organics": 2.0},
		"output": "medkits",
		"amount": 1.0,
		"time_per_unit": 2.0
	}
}

# Which recipes each factory type can run
const FACTORY_RECIPES = {
	"smelter": ["smelt_alloy"],
	"fab_plant": ["fabricate_chips"],
	"refinery": ["refine_fuel"],
	"assembly": ["assemble_module", "produce_ammo"],
	"biolab": ["grow_medkits"]
}


func tick() -> Dictionary:
	## Run one crafting tick. Returns {resource: amount_crafted}.
	var crafted: Dictionary = {}
	
	# Calculate crafting speed multiplier
	var speed_mult: float = _get_crafting_speed_multiplier()
	
	for cell in GameState.grid:
		if cell["type"] in FACTORY_RECIPES:
			for recipe_name in FACTORY_RECIPES[cell["type"]]:
				var recipe = RECIPES[recipe_name]
				var amount_crafted: float = _craft_recipe(recipe, cell["level"], speed_mult)
				if amount_crafted > 0:
					crafted[recipe["output"]] = crafted.get(recipe["output"], 0.0) + amount_crafted
	
	# Apply to GameState
	if not crafted.is_empty():
		GameState.add_resources(crafted)
	
	return crafted


func _craft_recipe(recipe: Dictionary, factory_level: int, speed_mult: float) -> float:
	## Attempt to craft. Consumes inputs, returns amount produced.
	# How many units can we produce this tick?
	var max_units: float = (factory_level * speed_mult) / recipe["time_per_unit"]
	if max_units <= 0:
		return 0.0
	
	# How many units can we afford based on resources?
	var affordable: float = max_units
	for res in recipe["inputs"]:
		var needed_per_unit: float = recipe["inputs"][res]
		var available: float = GameState.resources.get(res, 0.0)
		var can_afford_units: float = available / needed_per_unit
		affordable = min(affordable, can_afford_units)
	
	if affordable <= 0:
		return 0.0
	
	# Consume inputs
	var cost: Dictionary = {}
	for res in recipe["inputs"]:
		cost[res] = recipe["inputs"][res] * affordable
	GameState.spend_resources(cost)
	
	return recipe["amount"] * affordable


func _get_crafting_speed_multiplier() -> float:
	var mult: float = 1.0
	
	# Population bonus: each pop gives +2% crafting speed
	mult += GameState.population * 0.02
	
	# Drone bonus: each drone gives +3% crafting speed
	mult += GameState.drones * 0.03
	
	# Permanent upgrade bonus
	mult *= (1.0 + GameState.permanent_upgrades.get("crafting_speed", 0.0))
	
	return mult
