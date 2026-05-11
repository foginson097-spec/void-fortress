extends Control
## Build bar — нижняя панель с кнопками типов отсеков для постройки.
## Появляется при приближении к LOD city/street.

@onready var button_container: HBoxContainer = $ButtonContainer

const CELL_TYPES = [
	{"type": "miner", "name": "⛏️ Шахта", "cost": "10 сплавов"},
	{"type": "gas_collector", "name": "☁️ Сборщик", "cost": "15 сплавов"},
	{"type": "smelter", "name": "🔥 Плавильня", "cost": "20 сплавов"},
	{"type": "reactor", "name": "☢️ Реактор", "cost": "40 сплавов"},
	{"type": "habitat", "name": "🏠 Жильё", "cost": "15 сплавов"},
	{"type": "turret", "name": "🎯 Турель", "cost": "20 сплавов"},
	{"type": "drone_bay", "name": "🛸 Док", "cost": "30 сплавов"},
	{"type": "assembly", "name": "🔧 Сборка", "cost": "50 сплавов"},
	{"type": "storage", "name": "📦 Склад", "cost": "10 сплавов"},
]

var _selected_type: String = ""


func _ready() -> void:
	visible = false
	_create_buttons()


func _create_buttons() -> void:
	for cell in CELL_TYPES:
		var btn: Button = Button.new()
		btn.text = "%s %s\n[%s]" % [cell["name"].split(" ")[0], cell["name"].split(" ")[1] if " " in cell["name"] else "", cell["cost"]]
		btn.pressed.connect(_on_type_selected.bind(cell["type"]))
		btn.custom_minimum_size = Vector2(100, 60)
		button_container.add_child(btn)


func _on_type_selected(type_name: String) -> void:
	_selected_type = type_name
	# Подсветить выбранную кнопку
	for btn in button_container.get_children():
		if btn is Button:
			btn.modulate = Color.WHITE
	
	# Найти кнопку и подсветить
	for i in range(CELL_TYPES.size()):
		if CELL_TYPES[i]["type"] == type_name:
			var btn: Button = button_container.get_child(i)
			btn.modulate = Color.GREEN
			break


func get_selected_type() -> String:
	return _selected_type


func clear_selection() -> void:
	_selected_type = ""
	for btn in button_container.get_children():
		if btn is Button:
			btn.modulate = Color.WHITE
