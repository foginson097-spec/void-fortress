extends Node
## Population system — passive growth when housing + food available.
## Each pop consumes food and provides crafting bonus.

# Growth parameters
const BASE_GROWTH_RATE: float = 0.01  # pops per second per available housing slot
const FOOD_PER_POP: float = 0.5  # food consumed per pop per tick
const MEDKIT_PER_POP: float = 0.01  # medkit consumption per pop per tick


func tick() -> void:
	## Called each tick. Grows population and consumes food.
	_consume_supplies()
	_grow_population()


func _consume_supplies() -> void:
	# Food consumption
	var food_needed: float = GameState.population * FOOD_PER_POP
	var food_available: float = GameState.resources.get("organics", 0.0)
	
	if food_available < food_needed:
		# Starvation: population declines
		var deficit: float = food_needed - food_available
		var pop_loss: int = max(1, int(deficit / FOOD_PER_POP))
		GameState.population = max(0, GameState.population - pop_loss)
		GameState.resources["organics"] = 0.0
	else:
		GameState.resources["organics"] -= food_needed
	
	# Medkit consumption
	var medkits_needed: float = GameState.population * MEDKIT_PER_POP
	var medkits_available: float = GameState.resources.get("medkits", 0.0)
	
	if medkits_available < medkits_needed:
		# Health decline — slight pop loss
		var deficit: float = medkits_needed - medkits_available
		if deficit > medkits_needed * 0.5:  # only if severe shortage
			GameState.population = max(0, GameState.population - 1)
		GameState.resources["medkits"] = 0.0
	else:
		GameState.resources["medkits"] -= medkits_needed
	
	GameState.resources_changed.emit()
	GameState.population_changed.emit()


func _grow_population() -> void:
	if GameState.population >= GameState.max_population:
		return
	
	# Growth depends on available housing, food security, and comfort
	var available_slots: int = GameState.max_population - GameState.population
	var growth: float = BASE_GROWTH_RATE * available_slots
	
	# Food security bonus: if we have >2x needed food, grow faster
	var food_needed: float = GameState.population * FOOD_PER_POP
	if GameState.resources.get("organics", 0.0) > food_needed * 2.0:
		growth *= 1.5
	
	# Permanent upgrade bonus
	growth *= (1.0 + GameState.permanent_upgrades.get("pop_growth_bonus", 0.0))
	
	# Accumulate fractional population
	var new_pop_float: float = float(GameState.population) + growth
	var pop_gain: int = int(new_pop_float) - GameState.population
	
	if pop_gain > 0:
		GameState.population = min(GameState.max_population, GameState.population + pop_gain)
		GameState.population_changed.emit()
