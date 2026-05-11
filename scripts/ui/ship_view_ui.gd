extends Control
## Grid-based ship view — shows all cells and allows interaction.

@onready var grid_container: GridContainer = $GridContainer
@onready var build_panel: Control = $BuildPanel

# State
var _selected_pos: Vector2i = Vector2i(-1, -1)  # -1 means no selection
var _cell_buttons: Array = []  # 2D array of buttons [row][col]

# Cell display data
const CELL_INFO = {
	"miner": {"name": "Шахта", "icon": "⛏️", "color": Color(0.6, 0.4, 0.2)},
	"gas_collector": {"name": "Сборщик газа", "icon": "☁️", "color": Color(0.3, 0.6, 0.9)},
	"crystal_harvester": {"name": "Кристаллы", "icon": "💎", "color": Color(0.7, 0.3, 0.9)},
	"greenhouse": {"name": "Теплица", "icon": "🌿", "color": Color(0.2, 0.7, 0.3)},
	"smelter": {"name": "Плавильня", "icon": "🔥", "color": Color(0.8, 0.4, 0.1)},
	"fab_plant": {"name": "Фабрика", "icon": "🏭", "color": Color(0.4, 0.4, 0.6)},
	"refinery": {"name": "Очистка", "icon": "🛢️", "color": Color(0.6, 0.5, 0.2)},
	"assembly": {"name": "Сборка", "icon": "🔧", "color": Color(0.5, 0.5, 0.7)},
	"biolab": {"name": "Биолаб", "icon": "🧪", "color": Color(0.3, 0.7, 0.5)},
	"reactor": {"name": "Реактор", "icon": "☢️", "color": Color(1.0, 0.6, 0.0)},
	"habitat": {"name": "Жильё", "icon": "🏠", "color": Color(0.3, 0.8, 0.8)},
	"drone_bay": {"name": "Док дронов", "icon": "🛸", "color": Color(0.5, 0.5, 0.5)},
	"turret": {"name": "Турель", "icon": "🎯", "color": Color(0.9, 0.2, 0.2)},
	"storage": {"name": "Склад", "icon": "📦", "color": Color(0.7, 0.7, 0.5)}
}

# Which cells can be built (for the build panel)
const BUILDABLE_TYPES = [
	"miner", "gas_collector", "crystal_harvester", "greenhouse",
	"smelter", "fab_plant", "refinery", "assembly", "biolab",
	"reactor", "habitat", "drone_bay", "turret", "storage"
]


func _ready() -> void:
	_create_grid()
	_create_build_panel()


func _create_grid() -> void:
	grid_container.columns = GameState.GRID_COLS
	
	for row in range(GameState.GRID_ROWS):
		var row_buttons: Array = []
		for col in range(GameState.GRID_COLS):
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(64, 64)
			btn.text = ""
			btn.pressed.connect(_on_cell_pressed.bind(Vector2i(col, row)))
			grid_container.add_child(btn)
			row_buttons.append(btn)
		_cell_buttons.append(row_buttons)


func _create_build_panel() -> void:
	for type_name in BUILDABLE_TYPES:
		var info: Dictionary = CELL_INFO.get(type_name, {})
		var btn: Button = Button.new()
		btn.text = "%s %s" % [info.get("icon", "❓"), info.get("name", type_name)]
		btn.pressed.connect(_on_build_pressed.bind(type_name))
		build_panel.add_child(btn)


func refresh() -> void:
	## Called each tick to update grid display.
	for row in range(GameState.GRID_ROWS):
		for col in range(GameState.GRID_COLS):
			var btn: Button = _cell_buttons[row][col]
			var pos: Vector2i = Vector2i(col, row)
			var cell: Dictionary = _find_cell_at(pos)
			
			if cell.is_empty():
				btn.text = ""
				btn.modulate = Color(0.15, 0.15, 0.2, 1.0)  # empty slot
			else:
				var info: Dictionary = CELL_INFO.get(cell["type"], {})
				btn.text = "%s\nLv.%d" % [info.get("icon", "?"), cell["level"]]
				btn.modulate = info.get("color", Color.WHITE)
			
			# Highlight selected cell
			if pos == _selected_pos:
				btn.modulate = btn.modulate.lightened(0.3)


func _find_cell_at(pos: Vector2i) -> Dictionary:
	for cell in GameState.grid:
		if cell["grid_pos"] == pos:
			return cell
	return {}


func _on_cell_pressed(pos: Vector2i) -> void:
	_selected_pos = pos
	refresh()
	
	# Show upgrade option in a separate panel
	var upgrade_panel: Control = get_node_or_null("/root/Main/UI/UpgradePanel")
	if upgrade_panel:
		upgrade_panel.show_for_cell(pos)


func _on_build_pressed(type_name: String) -> void:
	if _selected_pos.x < 0:
		return  # no position selected
	
	# Try to build
	var controller = get_node_or_null("/root/Main")
	if controller and controller.has_method("build_cell"):
		controller.build_cell(type_name, _selected_pos)
	refresh()
