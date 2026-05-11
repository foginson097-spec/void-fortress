extends Control
## 3D Dashboard — минимальный оверлей поверх 3D-вида.
## Показывает ресурсы, население, оборону — без перекрытия вида.

@onready var resource_panel: VBoxContainer = $ResourcePanel
@onready var pop_label: Label = $Header/PopLabel
@onready var defense_label: Label = $Header/DefenseLabel
@onready var sector_label: Label = $Header/SectorLabel
@onready var energy_label: Label = $Header/EnergyLabel

const RESOURCE_INFO = {
	"ore": {"name": "Руда", "icon": "🪨", "color": Color(0.7, 0.5, 0.3)},
	"gas": {"name": "Газ", "icon": "☁️", "color": Color(0.5, 0.7, 1.0)},
	"crystals": {"name": "Кристаллы", "icon": "💎", "color": Color(0.8, 0.4, 1.0)},
	"organics": {"name": "Органика", "icon": "🌱", "color": Color(0.3, 0.8, 0.3)},
	"alloy": {"name": "Сплавы", "icon": "🔩", "color": Color(0.6, 0.6, 0.7)},
	"microchips": {"name": "Микросхемы", "icon": "🖥️", "color": Color(0.2, 0.8, 0.2)},
	"fuel_cells": {"name": "Топливо", "icon": "⚡", "color": Color(1.0, 0.6, 0.0)},
	"modules": {"name": "Модули", "icon": "📦", "color": Color(0.5, 0.5, 0.8)},
	"ammo": {"name": "Патроны", "icon": "🔫", "color": Color(0.8, 0.3, 0.3)},
	"medkits": {"name": "Медикаменты", "icon": "💊", "color": Color(1.0, 0.2, 0.2)},
	"energy": {"name": "Энергия", "icon": "🔋", "color": Color(1.0, 0.9, 0.2)}
}

# Только ключевые ресурсы для отображения (чтобы не засорять экран)
const SHOWN_RESOURCES = ["ore", "gas", "crystals", "alloy", "microchips", "energy"]


func refresh() -> void:
	_update_resources()
	_update_header()


func _update_resources() -> void:
	for child in resource_panel.get_children():
		child.queue_free()
	
	for res in SHOWN_RESOURCES:
		var amount: float = GameState.resources.get(res, 0.0)
		var info: Dictionary = RESOURCE_INFO.get(res, {})
		
		var label: Label = Label.new()
		label.text = "%s %s: %.1f" % [info.get("icon", "?"), info.get("name", res), amount]
		label.add_theme_color_override("font_color", info.get("color", Color.WHITE))
		label.add_theme_font_size_override("font_size", 14)
		resource_panel.add_child(label)


func _update_header() -> void:
	sector_label.text = "Сектор %d: %s" % [
		GameState.current_sector + 1,
		GameState.sector_params.get("name", "Unknown")
	]
	pop_label.text = "👥 Население: %d/%d" % [GameState.population, GameState.max_population]
	defense_label.text = "🛡️ Оборона: %.1f DPS" % GameState.defense_dps
	
	var produced: float = GameState.get_energy_production()
	var consumed: float = GameState.get_total_energy_consumption()
	var color: String = "#00ff00" if produced >= consumed else "#ff4444"
	energy_label.text = "[color=%s]🔋 %.1f/%.1f[/color]" % [color, produced, consumed]
