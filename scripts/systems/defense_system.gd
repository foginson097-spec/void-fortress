extends Node
## Defense system — manages pirate waves and passive DPS combat.
## No player micro-control. Pure DPS check.

# State
var _wave_timer: float = 0.0
var _wave_active: bool = false
var _current_pirate_hp: float = 0.0
var _wave_number: int = 0

# Ammo consumption (per DPS per tick)
const AMMO_PER_DPS: float = 0.1

# Repair cost (per destroyed turret)
const REPAIR_ALLOY_COST: float = 10.0
const REPAIR_CHIP_COST: float = 5.0

# Signals
signal wave_started(strength: float, wave_num: int)
signal wave_ended(won: bool, loot: Dictionary)
signal turret_destroyed(pos: Vector2i)


func tick() -> void:
	## Called every game tick.
	# Handle active wave
	if _wave_active:
		_fight_wave()
	
	# Countdown to next wave
	if not _wave_active:
		_wave_timer += GameState.TICK_INTERVAL
		var interval: float = GameState.sector_params.get("pirate_interval", 300.0)
		if _wave_timer >= interval:
			_start_wave()


func _start_wave() -> void:
	_wave_timer = 0.0
	_wave_active = true
	_wave_number += 1
	
	# Pirate strength scales with sector, wave number, and ship value
	var sector_mult: float = GameState.sector_params.get("pirate_strength", 1.0)
	var wave_mult: float = 1.0 + (_wave_number - 1) * 0.2
	_current_pirate_hp = 20.0 * sector_mult * wave_mult
	
	wave_started.emit(_current_pirate_hp, _wave_number)


func _fight_wave() -> void:
	# Consume ammo for DPS
	var ammo_needed: float = GameState.defense_dps * AMMO_PER_DPS
	var ammo_available: float = GameState.resources.get("ammo", 0.0)
	
	if ammo_available < ammo_needed:
		# Not enough ammo — defense fires at reduced rate
		_current_pirate_hp -= GameState.defense_dps * (ammo_available / max(ammo_needed, 0.001))
		GameState.resources["ammo"] = 0.0
	else:
		_current_pirate_hp -= GameState.defense_dps
		GameState.resources["ammo"] -= ammo_needed
	
	GameState.resources_changed.emit()
	
	# Check if pirates are dead
	if _current_pirate_hp <= 0:
		_wave_won()
		return
	
	# Pirates deal damage — check if they overwhelm defense
	# If pirate HP > defense DPS * 3, they deal damage
	var pirate_dmg: float = max(0, _current_pirate_hp - GameState.defense_dps * 3)
	if pirate_dmg > 0:
		_damage_turrets(pirate_dmg * 0.1)


func _wave_won() -> void:
	_wave_active = false
	
	# Loot: resources proportional to pirate strength
	var loot: Dictionary = {
		"alloy": _current_pirate_hp * 0.5,
		"microchips": _current_pirate_hp * 0.1
	}
	GameState.add_resources(loot)
	wave_ended.emit(true, loot)


func _damage_turrets(damage: float) -> void:
	## Pirates destroy turrets. Damage is spread across turrets.
	var turrets: Array = GameState.get_cells_of_type("turret")
	if turrets.is_empty():
		# No turrets — pirates raid storage
		_raid_storage(damage)
		return
	
	# Destroy weakest turrets first
	turrets.sort_custom(func(a, b): return a["level"] < b["level"])
	
	var dmg_left: float = damage
	for turret in turrets:
		if dmg_left <= 0:
			break
		dmg_left -= turret["level"] * 2.0  # each level absorbs 2 damage
		turret_destroyed.emit(turret["grid_pos"])
		GameState.remove_cell(turret["grid_pos"])
	
	# Auto-repair: try to rebuild destroyed turrets if resources available
	if GameState.resources.get("alloy", 0) >= REPAIR_ALLOY_COST and GameState.resources.get("microchips", 0) >= REPAIR_CHIP_COST:
		# Repair one turret per tick max
		_auto_repair()


func _auto_repair() -> void:
	## Rebuild a destroyed turret if resources allow.
	var repair_cost: Dictionary = {"alloy": REPAIR_ALLOY_COST, "microchips": REPAIR_CHIP_COST}
	if not GameState.has_resources(repair_cost):
		return
	
	# Find a free grid position for the new turret
	for y in range(GameState.GRID_ROWS):
		for x in range(GameState.GRID_COLS):
			var pos: Vector2i = Vector2i(x, y)
			if GameState.is_grid_pos_free(pos):
				GameState.spend_resources(repair_cost)
				GameState.add_cell("turret", pos)
				return


func _raid_storage(damage: float) -> void:
	## Pirates steal resources from storage.
	var loss_ratio: float = min(0.3, damage * 0.01)
	for res in GameState.resources:
		GameState.resources[res] *= (1.0 - loss_ratio)
	GameState.resources_changed.emit()


func get_next_wave_in() -> float:
	## Seconds until next wave (for UI).
	var interval: float = GameState.sector_params.get("pirate_interval", 300.0)
	return interval - _wave_timer


func is_wave_active() -> bool:
	return _wave_active


func get_pirate_hp_ratio() -> float:
	## 0 = dead, 1 = full HP (relative to max possible for display)
	if not _wave_active or _current_pirate_hp <= 0:
		return 0.0
	var max_hp: float = 20.0 * GameState.sector_params.get("pirate_strength", 1.0) * (1.0 + (_wave_number - 1) * 0.2)
	return _current_pirate_hp / max_hp
