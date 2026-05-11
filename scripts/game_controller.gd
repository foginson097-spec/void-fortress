extends Node3D
## Game Controller 3D — оркестрирует все системы и tick-цикл.
## 3D-версия: управляет камерой, LOD, звёздами, атмосферой.

# Системы (логика — без изменений)
@onready var resource_manager: Node = $Systems/ResourceManager
@onready var crafter: Node = $Systems/Crafter
@onready var defense_system: Node = $Systems/DefenseSystem
@onready var population_system: Node = $Systems/Population
@onready var prestige_system: Node = $Systems/Prestige
@onready var ship_grid: Node = $Systems/ShipGrid
@onready var save_manager: Node = $Systems/SaveManager

# 3D-системы
@onready var orbit_camera: Camera3D = $Camera3D
@onready var floating_origin: Node3D = $FloatingOrigin
@onready var lod_manager: Node = $LODManager
@onready var ship_builder: Node = $ShipBuilder
@onready var atmosphere: MeshInstance3D = $World/Ship/Atmosphere

# UI (CanvasLayer поверх 3D)
@onready var dashboard_ui: Control = $CanvasLayer/UI/Dashboard
@onready var prestige_ui: Control = $CanvasLayer/UI/PrestigeScreen
@onready var build_bar: Control = $CanvasLayer/UI/BuildBar

# Autosave
var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL: float = 30.0

# Состояние
var _lod_label: Label


func _ready() -> void:
	# Загрузить сохранение
	if save_manager.has_save():
		save_manager.load_game()
	
	GameState.last_save_timestamp = Time.get_unix_time_from_system()
	
	# Построить LOD-заглушки
	ship_builder.ship_root = $World/Ship
	ship_builder.build_all_lods()
	
	# Настроить камеру
	orbit_camera.target = $World/Ship
	
	# Настроить Floating Origin
	floating_origin.origin_node = $World
	floating_origin.camera = orbit_camera
	
	# Настроить LOD Manager
	lod_manager.camera = orbit_camera
	lod_manager.lod_cosmos = $World/Ship/LOD_Cosmos
	lod_manager.lod_orbit = $World/Ship/LOD_Orbit
	lod_manager.lod_continent = $World/Ship/LOD_Continent
	lod_manager.lod_city = $World/Ship/LOD_City
	lod_manager.lod_street = $World/Ship/LOD_Street
	
	# Настроить атмосферу
	if atmosphere and atmosphere.has_method("_ready"):
		atmosphere.camera = orbit_camera
	
	# Сигналы
	GameState.game_ticked.connect(_on_game_ticked)
	lod_manager.lod_changed.connect(_on_lod_changed)
	
	# LOD label (в углу для дебага)
	_lod_label = Label.new()
	_lod_label.position = Vector2(10, 690)
	_lod_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	$CanvasLayer/UI.add_child(_lod_label)
	
	# Первый тик UI
	dashboard_ui.refresh()


func _process(delta: float) -> void:
	# Tick-цикл (игровая логика)
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
	resource_manager.tick()
	crafter.tick()
	defense_system.tick()
	population_system.tick()
	GameState.game_ticked.emit()


func _on_game_ticked() -> void:
	dashboard_ui.refresh()


func _on_lod_changed(from_lod: String, to_lod: String) -> void:
	_lod_label.text = "LOD: %s → %s | Cam: %.1fm" % [from_lod, to_lod, orbit_camera.get_distance()]
	
	# При входе в стрит-LOD — показать кнопки взаимодействия
	build_bar.visible = (to_lod == "street" or to_lod == "city")


# ---------- INPUT (3D clicks) ----------

func _input(event: InputEvent) -> void:
	# Левый клик по кораблю = выбор ячейки
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_3d_click(event.position)
	
	# P = prestige screen
	if event is InputEventKey and event.keycode == KEY_P and event.pressed:
		prestige_ui.show_screen()
		return
	
	# Escape = закрыть prestige
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if prestige_ui.visible:
			prestige_ui.hide_screen()
		return


func _handle_3d_click(screen_pos: Vector2) -> void:
	# Raycast из камеры в мир — проверяем попадание по ячейке
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = orbit_camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + orbit_camera.project_ray_normal(screen_pos) * 10000.0
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result.is_empty():
		return
	
	var collider: Node = result.get("collider")
	if collider:
		# Ищем родительскую ячейку
		var cell_node: Node = _find_cell_parent(collider)
		if cell_node and "_" in cell_node.name:
			var parts: PackedStringArray = cell_node.name.split("_")
			if parts.size() >= 3:
				var col: int = parts[1].to_int()
				var row: int = parts[2].to_int()
				var _pos: Vector2i = Vector2i(col, row)
				print("[3D Click] Cell: %d,%d" % [col, row])
				# TODO: показать панель апгрейда для этой ячейки


func _find_cell_parent(node: Node) -> Node:
	var current: Node = node
	while current:
		if current.name.begins_with("Cell_"):
			return current
		current = current.get_parent()
	return null


# ---------- PUBLIC API (кнопки UI) ----------

func build_cell(type_name: String, pos: Vector2i) -> void:
	if ship_grid.build_cell(type_name, pos):
		# Перестроить LOD-заглушки чтобы отразить изменения
		ship_builder.build_lod_continent()
		ship_builder.build_lod_city()
		ship_builder.build_lod_street()


func upgrade_cell(pos: Vector2i) -> void:
	ship_grid.upgrade_cell(pos)


func remove_cell(pos: Vector2i) -> void:
	ship_grid.remove_cell(pos)


func perform_prestige() -> void:
	if prestige_system.can_jump():
		prestige_system.perform_jump()
		save_manager.save_game()
		# Перестроить все LOD
		ship_builder.build_all_lods()


func buy_upgrade(upgrade_name: String) -> void:
	prestige_system.buy_permanent_upgrade(upgrade_name)


func save_game() -> void:
	save_manager.save_game()


func reset_game() -> void:
	save_manager.delete_save()
	GameState.reset_to_defaults()
	ship_builder.build_all_lods()
