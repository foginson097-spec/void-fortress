extends Node
## Main game controller — orchestrates all systems and the tick loop.

@onready var resource_manager: Node = $ResourceManager
@onready var crafter: Node = $Crafter
@onready var defense_system: Node = $DefenseSystem
@onready var population_system: Node = $Population
@onready var prestige_system: Node = $Prestige
@onready var ship_grid: Node = $ShipGrid
@onready var save_manager: Node = $SaveManager

# UI references
@onready var dashboard_ui: Control = $UI/Dashboard
@onready var ship_view_ui: Control = $UI/ShipView
@onready var upgrade_panel_ui: Control = $UI/UpgradePanel
@onready var prestige_ui: Control = $UI/PrestigeScreen

# Autosave timer (every 30 seconds)
var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL: float = 30.0


func _ready() -> void:
	# Try to load existing save
	if save_manager.has_save():
		save_manager.load_game()
	
	# Initial save timestamp
	GameState.last_save_timestamp = Time.get_unix_time_from_system()
	
	# Connect signals
	GameState.game_ticked.connect(_on_game_ticked)


func _process(delta: float) -> void:
	# Accumulate time and tick at fixed interval
	GameState._accumulated_time += delta
	
	while GameState._accumulated_time >= GameState.TICK_INTERVAL:
		_tick()
		GameState._accumulated_time -= GameState.TICK_INTERVAL
	
	# Autosave
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_manager.save_game()


func _tick() -> void:
	## One game tick — run all systems in order.
	# 1. Resource generation (mining)
	resource_manager.tick()
	
	# 2. Crafting
	crafter.tick()
	
	# 3. Defense (pirate waves)
	defense_system.tick()
	
	# 4. Population growth/consumption
	population_system.tick()
	
	# 5. Notify UI
	GameState.game_ticked.emit()


func _on_game_ticked() -> void:
	## Update UI elements after each tick.
	dashboard_ui.refresh()
	ship_view_ui.refresh()


# ---------- PUBLIC API (called by UI buttons) ----------

func build_cell(type_name: String, pos: Vector2i) -> void:
	ship_grid.build_cell(type_name, pos)


func upgrade_cell(pos: Vector2i) -> void:
	ship_grid.upgrade_cell(pos)


func remove_cell(pos: Vector2i) -> void:
	ship_grid.remove_cell(pos)


func perform_prestige() -> void:
	if prestige_system.can_jump():
		prestige_system.perform_jump()
		save_manager.save_game()


func buy_upgrade(upgrade_name: String) -> void:
	prestige_system.buy_permanent_upgrade(upgrade_name)


func save_game() -> void:
	save_manager.save_game()


func reset_game() -> void:
	save_manager.delete_save()
	GameState.reset_to_defaults()
