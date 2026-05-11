extends Node3D
## Game Controller v3 — КУБ-КОРАБЛЬ.
## Оркестрирует все системы + регистрирует LOD граней.

# Системы
@onready var resource_manager: Node = $Systems/ResourceManager
@onready var crafter: Node = $Systems/Crafter
@onready var defense_system: Node = $Systems/DefenseSystem
@onready var population_system: Node = $Systems/Population
@onready var prestige_system: Node = $Systems/Prestige
@onready var ship_grid: Node = $Systems/ShipGrid
@onready var save_manager: Node = $Systems/SaveManager

# 3D
@onready var orbit_camera: Camera3D = $Camera3D
@onready var floating_origin: Node3D = $FloatingOrigin
@onready var lod_manager: Node = $LODManager
@onready var ship_builder: Node = $ShipBuilder
@onready var atmosphere: MeshInstance3D = $World/Ship/Atmosphere

# UI
@onready var dashboard_ui: Control = $CanvasLayer/UI/Dashboard
@onready var prestige_ui: Control = $CanvasLayer/UI/PrestigeScreen
@onready var build_bar: Control = $CanvasLayer/UI/BuildBar

# Face names
const FACE_NAMES = ["Front", "Back", "Right", "Left", "Top", "Bottom"]

var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL: float = 30.0
var _lod_label: Label


func _ready() -> void:
	if save_manager.has_save():
		save_manager.load_game()
	GameState.last_save_timestamp = Time.get_unix_time_from_system()
	
	# Build
	ship_builder.ship_root = $World/Ship
	ship_builder.build_all_lods()
	
	# Camera
	orbit_camera.target = $World/Ship
	
	# Floating origin
	floating_origin.origin_node = $World
	floating_origin.camera = orbit_camera
	
	# LOD Manager
	lod_manager.camera = orbit_camera
	lod_manager.lod_cosmos = $World/Ship/LOD_Cosmos
	lod_manager.lod_orbit = $World/Ship/LOD_Orbit
	
	# Register face LODs
	for i in range(6):
		var face_name: String = FACE_NAMES[i]
		var cont_node: Node3D = $World/Ship.get_node_or_null("LOD_Continent_%s" % face_name)
		if cont_node: lod_manager.register_face_lod(i, "continent", cont_node)
		var city_node: Node3D = $World/Ship.get_node_or_null("LOD_City_%s" % face_name)
		if city_node: lod_manager.register_face_lod(i, "city", city_node)
		var street_node: Node3D = $World/Ship.get_node_or_null("LOD_Street_%s" % face_name)
		if street_node: lod_manager.register_face_lod(i, "street", street_node)
	
	# Drone animator
	if has_node("DroneAnimator"):
		$DroneAnimator.lod_cosmos = $World/Ship/LOD_Cosmos
	
	# Atmosphere
	if atmosphere and atmosphere.has_method("_ready"):
		atmosphere.camera = orbit_camera
	
	# Signals
	GameState.game_ticked.connect(_on_game_ticked)
	lod_manager.lod_changed.connect(_on_lod_changed)
	lod_manager.face_changed.connect(_on_face_changed)
	
	# Debug label
	_lod_label = Label.new()
	_lod_label.position = Vector2(10, 690)
	_lod_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	$CanvasLayer/UI.add_child(_lod_label)
	
	dashboard_ui.refresh()


func _process(delta: float) -> void:
	GameState._accumulated_time += delta
	while GameState._accumulated_time >= GameState.TICK_INTERVAL:
		_tick()
		GameState._accumulated_time -= GameState.TICK_INTERVAL
	
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_manager.save_game()


func _tick() -> void:
	resource_manager.tick()
	crafter.tick()
	defense_system.tick()
	population_system.tick()
	GameState.game_ticked.emit()


func _on_game_ticked() -> void:
	dashboard_ui.refresh()


func _on_lod_changed(from_lod: String, to_lod: String) -> void:
	var face_str: String = FACE_NAMES[orbit_camera.get_active_face()] if orbit_camera.get_active_face() >= 0 else "none"
	_lod_label.text = "LOD: %s → %s | Face: %s | Dist: %.0f" % [from_lod, to_lod, face_str, orbit_camera.get_distance()]


func _on_face_changed(face_idx: int) -> void:
	print("[Controller] Face changed to: %s (%d)" % [FACE_NAMES[face_idx], face_idx])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_P and event.pressed:
		prestige_ui.show_screen()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if prestige_ui.visible:
			prestige_ui.hide_screen()


func build_cell(type_name: String, pos: Vector2i) -> void:
	if ship_grid.build_cell(type_name, pos):
		ship_builder.build_all_lods()

func upgrade_cell(pos: Vector2i) -> void:
	ship_grid.upgrade_cell(pos)

func remove_cell(pos: Vector2i) -> void:
	ship_grid.remove_cell(pos)

func perform_prestige() -> void:
	if prestige_system.can_jump():
		prestige_system.perform_jump()
		save_manager.save_game()
		ship_builder.build_all_lods()

func buy_upgrade(upgrade_name: String) -> void:
	prestige_system.buy_permanent_upgrade(upgrade_name)

func save_game() -> void:
	save_manager.save_game()

func reset_game() -> void:
	save_manager.delete_save()
	GameState.reset_to_defaults()
	ship_builder.build_all_lods()
