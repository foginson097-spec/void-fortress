extends Node
## Prestige system — handles sector jumps (prestige mechanic).
## Resets resources and grid, gives permanent tech points.

signal prestige_completed(sector: int, tech_gained: float)


func can_jump() -> bool:
	var cost: Dictionary = GameState.sector_params.get("jump_cost", {})
	return GameState.has_resources(cost)


func get_jump_cost() -> Dictionary:
	return GameState.sector_params.get("jump_cost", {}).duplicate()


func perform_jump() -> bool:
	## Execute a prestige jump. Returns true if successful.
	if not can_jump():
		return false
	
	# Pay the jump cost
	var cost: Dictionary = GameState.sector_params.get("jump_cost", {})
	GameState.spend_resources(cost)
	
	# Calculate tech points gained from this run
	var tech_gained: float = _calculate_tech_points()
	GameState.tech_points += tech_gained
	
	# Advance sector
	GameState.current_sector += 1
	
	# Reset everything except tech points and permanent upgrades
	_reset_for_new_sector()
	
	prestige_completed.emit(GameState.current_sector, tech_gained)
	return true


func _calculate_tech_points() -> float:
	## Calculate tech points based on achievements this run.
	var points: float = 0.0
	
	# Points from max DPS achieved (defense)
	points += GameState.defense_dps * 0.1
	
	# Points from max population
	points += GameState.population * 0.5
	
	# Points from grid size (number of cells)
	points += GameState.grid.size() * 2.0
	
	# Points from sector number (higher sector = more points)
	points *= (1.0 + GameState.current_sector * 0.5)
	
	return max(1.0, points)


func _reset_for_new_sector() -> void:
	## Reset game state for new sector, keeping tech_points and permanent_upgrades.
	var saved_tech: float = GameState.tech_points
	var saved_upgrades: Dictionary = GameState.permanent_upgrades.duplicate()
	
	GameState.reset_to_defaults()
	
	GameState.tech_points = saved_tech
	GameState.permanent_upgrades = saved_upgrades
	
	# Apply starting bonuses from permanent upgrades
	_apply_permanent_bonuses()


func _apply_permanent_bonuses() -> void:
	## Apply permanent upgrade effects to the fresh sector.
	# Start with extra population from upgrades
	if GameState.permanent_upgrades.get("pop_growth_bonus", 0.0) > 0:
		GameState.population += int(GameState.permanent_upgrades["pop_growth_bonus"] * 10)
		GameState.population = min(GameState.population, GameState.max_population)
	
	# Start with pre-built turrets
	var start_turrets: int = int(GameState.permanent_upgrades.get("start_turrets", 0))
	for i in range(start_turrets):
		# Place turrets in first available slots
		for y in range(GameState.GRID_ROWS):
			for x in range(GameState.GRID_COLS):
				var pos: Vector2i = Vector2i(x, y)
				if GameState.is_grid_pos_free(pos):
					GameState.add_cell("turret", pos)
					break
	
	# Start with extra resources
	var mining_bonus: float = GameState.permanent_upgrades.get("mining_bonus", 0.0)
	if mining_bonus > 0:
		for res in ["ore", "alloy"]:
			GameState.resources[res] = mining_bonus * 100


func buy_permanent_upgrade(upgrade_name: String) -> bool:
	## Purchase a permanent upgrade with tech points.
	var costs = {
		"mining_bonus": 10.0,    # +0.1 per level
		"crafting_speed": 15.0,  # +0.1 per level
		"defense_bonus": 10.0,   # +0.15 per level
		"pop_growth_bonus": 20.0, # +0.1 per level
		"auto_craft": 50.0,      # one-time: auto-crafting in new sectors (needs logic in crafter)
		"start_turrets": 30.0    # +1 turret at start per level
	}
	
	if not upgrade_name in costs:
		return false
	
	var cost: float = costs[upgrade_name]
	
	# Auto-craft is one-time purchase
	if upgrade_name == "auto_craft":
		if GameState.permanent_upgrades.get("auto_craft", false):
			return false  # already bought
		if GameState.tech_points < cost:
			return false
		GameState.tech_points -= cost
		GameState.permanent_upgrades["auto_craft"] = true
		return true
	
	# Other upgrades scale each level
	if GameState.tech_points < cost:
		return false
	
	GameState.tech_points -= cost
	GameState.permanent_upgrades[upgrade_name] = GameState.permanent_upgrades.get(upgrade_name, 0.0)
	
	match upgrade_name:
		"mining_bonus":
			GameState.permanent_upgrades["mining_bonus"] += 0.1
		"crafting_speed":
			GameState.permanent_upgrades["crafting_speed"] += 0.1
		"defense_bonus":
			GameState.permanent_upgrades["defense_bonus"] += 0.15
		"pop_growth_bonus":
			GameState.permanent_upgrades["pop_growth_bonus"] += 0.1
		"start_turrets":
			GameState.permanent_upgrades["start_turrets"] += 1.0
	
	return true


func get_upgrade_cost(upgrade_name: String) -> float:
	var base_costs = {
		"mining_bonus": 10.0,
		"crafting_speed": 15.0,
		"defense_bonus": 10.0,
		"pop_growth_bonus": 20.0,
		"auto_craft": 50.0,
		"start_turrets": 30.0
	}
	return base_costs.get(upgrade_name, 0.0)
