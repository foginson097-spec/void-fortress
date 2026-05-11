extends Node
## Save/Load system — persists game state to JSON and calculates offline progress.

const SAVE_PATH: String = "user://void_fortress_save.json"
const SAVE_VERSION: int = 1


func save_game() -> void:
	## Serialize all game state to JSON and write to disk.
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"resources": GameState.resources,
		"grid": _serialize_grid(),
		"population": GameState.population,
		"max_population": GameState.max_population,
		"drones": GameState.drones,
		"max_drones": GameState.max_drones,
		"defense_dps": GameState.defense_dps,
		"current_sector": GameState.current_sector,
		"tech_points": GameState.tech_points,
		"permanent_upgrades": GameState.permanent_upgrades,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		GameState.last_save_timestamp = data["timestamp"]


func load_game() -> bool:
	## Deserialize game state from JSON. Returns true if save existed.
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("Save file corrupted: ", json.get_error_message())
		return false
	
	var data: Dictionary = json.data
	
	# Version check
	if data.get("version", 0) != SAVE_VERSION:
		push_warning("Save version mismatch, attempting load anyway")
	
	# Restore state
	GameState.resources = data.get("resources", {})
	_deserialize_grid(data.get("grid", []))
	GameState.population = data.get("population", 5)
	GameState.max_population = data.get("max_population", 10)
	GameState.drones = data.get("drones", 0)
	GameState.max_drones = data.get("max_drones", 3)
	GameState.defense_dps = data.get("defense_dps", 0.0)
	GameState.current_sector = data.get("current_sector", 0)
	GameState.tech_points = data.get("tech_points", 0.0)
	GameState.permanent_upgrades = data.get("permanent_upgrades", {})
	GameState.last_save_timestamp = data.get("timestamp", 0.0)
	
	# Reload sector params for current sector
	GameState._load_sector_params()
	GameState._recalc_derived_stats()
	
	# Calculate offline progress
	var current_time: float = Time.get_unix_time_from_system()
	var offline_seconds: float = current_time - GameState.last_save_timestamp
	
	if offline_seconds > 1.0:
		_calculate_offline_progress(min(offline_seconds, 86400.0))  # cap at 24 hours
	
	# Save immediately to update timestamp
	save_game()
	
	return true


func _serialize_grid() -> Array:
	var result: Array = []
	for cell in GameState.grid:
		result.append({
			"type": cell["type"],
			"level": cell["level"],
			"grid_pos": [cell["grid_pos"].x, cell["grid_pos"].y]
		})
	return result


func _deserialize_grid(data: Array) -> void:
	GameState.grid = []
	for cell_data in data:
		var pos_arr: Array = cell_data.get("grid_pos", [0, 0])
		GameState.grid.append({
			"type": cell_data.get("type", "miner"),
			"level": cell_data.get("level", 1),
			"grid_pos": Vector2i(pos_arr[0], pos_arr[1])
		})


func _calculate_offline_progress(seconds: float) -> void:
	## Simulate ticks for offline time at reduced efficiency (50%).
	var ticks: int = int(seconds / GameState.TICK_INTERVAL)
	
	for i in range(ticks):
		# Simpler offline simulation: just do resource generation and crafting
		# at 50% efficiency, no defense events during offline time
		_offline_tick()
	
	# Give bonus resources as compensation for missed defense loot
	var offline_bonus: float = seconds * 0.1
	GameState.resources["alloy"] = GameState.resources.get("alloy", 0.0) + offline_bonus


func _offline_tick() -> void:
	## Simplified tick for offline calculation.
	# Mining at 50%
	for cell in GameState.grid:
		var resource_map = {
			"miner": "ore",
			"gas_collector": "gas",
			"crystal_harvester": "crystals",
			"greenhouse": "organics"
		}
		if cell["type"] in resource_map:
			var res: String = resource_map[cell["type"]]
			var base_rates = {"ore": 1.0, "gas": 0.8, "crystals": 0.3, "organics": 0.5}
			var gain: float = base_rates.get(res, 1.0) * cell["level"] * 0.5
			var sector_mult = GameState.sector_params.get("resource_mult", {}).get(res, 1.0)
			gain *= sector_mult
			GameState.resources[res] = GameState.resources.get(res, 0.0) + gain
	
	# Simple crafting at 50%
	if GameState.resources.get("ore", 0.0) >= 3.0:
		var crafts: float = min(GameState.resources["ore"] / 3.0, 0.25)  # reduced rate
		GameState.resources["ore"] -= crafts * 3.0
		GameState.resources["alloy"] = GameState.resources.get("alloy", 0.0) + crafts * 0.5


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
