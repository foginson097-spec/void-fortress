extends Control
## Panel shown when a cell is selected — allows upgrading or removing.

@onready var info_label: Label = $InfoLabel
@onready var upgrade_btn: Button = $UpgradeBtn
@onready var remove_btn: Button = $RemoveBtn
@onready var cost_label: Label = $CostLabel

var _selected_pos: Vector2i = Vector2i(-1, -1)
var _visible: bool = false


func _ready() -> void:
	hide()
	upgrade_btn.pressed.connect(_on_upgrade)
	remove_btn.pressed.connect(_on_remove)


func show_for_cell(pos: Vector2i) -> void:
	_selected_pos = pos
	var cell: Dictionary = _find_cell(pos)
	
	if cell.is_empty():
		hide()
		return
	
	var type_name: String = cell["type"]
	var info: Dictionary = {
		"miner": "⛏️ Шахта",
		"gas_collector": "☁️ Сборщик газа",
		"crystal_harvester": "💎 Кристаллы",
		"greenhouse": "🌿 Теплица",
		"smelter": "🔥 Плавильня",
		"fab_plant": "🏭 Фабрика",
		"refinery": "🛢️ Очистка",
		"assembly": "🔧 Сборка",
		"biolab": "🧪 Биолаб",
		"reactor": "☢️ Реактор",
		"habitat": "🏠 Жильё",
		"drone_bay": "🛸 Док дронов",
		"turret": "🎯 Турель",
		"storage": "📦 Склад"
	}
	
	info_label.text = "%s (ур. %d)" % [info.get(type_name, type_name), cell["level"]]
	
	# Calculate upgrade cost
	var controller = get_node_or_null("/root/Main")
	var ship_grid_node = controller.get_node_or_null("ShipGrid") if controller else null
	if ship_grid_node and ship_grid_node.has_method("get_upgrade_cost_for"):
		var cost: Dictionary = ship_grid_node.get_upgrade_cost_for(pos)
		cost_label.text = _format_cost(cost)
	else:
		cost_label.text = ""
	
	show()
	_visible = true


func _on_upgrade() -> void:
	var controller = get_node_or_null("/root/Main")
	if controller and controller.has_method("upgrade_cell"):
		controller.upgrade_cell(_selected_pos)
	show_for_cell(_selected_pos)  # refresh


func _on_remove() -> void:
	var controller = get_node_or_null("/root/Main")
	if controller and controller.has_method("remove_cell"):
		controller.remove_cell(_selected_pos)
	hide()
	_visible = false


func _find_cell(pos: Vector2i) -> Dictionary:
	for cell in GameState.grid:
		if cell["grid_pos"] == pos:
			return cell
	return {}


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Бесплатно"
	var parts: Array = []
	for res in cost:
		parts.append("%s: %.1f" % [res, cost[res]])
	return "Стоимость: " + ", ".join(parts)
