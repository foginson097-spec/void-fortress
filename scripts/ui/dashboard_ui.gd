extends Control
## Main dashboard — displays all resources, population, defense, sector info.

@onready var resource_list: VBoxContainer = $ResourceList
@onready var sector_label: Label = $Header/SectorLabel
@onready var pop_label: Label = $Header/PopLabel
@onready var defense_label: Label = $Header/DefenseLabel
@onready var energy_label: Label = $Header/EnergyLabel
@onready var wave_label: Label = $Header/WaveLabel

# Resource display names and icons (emoji placeholders until user adds art)
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


func refresh() -> void:
	_update_resource_list()
	_update_header()


func _update_resource_list() -> void:
	# Clear and rebuild resource labels (simple approach for MVP)
	for child in resource_list.get_children():
		child.queue_free()
	
	for res in RESOURCE_INFO:
		var amount: float = GameState.resources.get(res, 0.0)
		var info: Dictionary = RESOURCE_INFO[res]
		
		var label: Label = Label.new()
		label.text = "%s %s: %.1f" % [info["icon"], info["name"], amount]
		label.add_theme_color_override("font_color", info["color"])
		resource_list.add_child(label)


func _update_header() -> void:
	sector_label.text = "Сектор %d: %s" % [
		GameState.current_sector + 1,
		GameState.sector_params.get("name", "Unknown")
	]
	pop_label.text = "👥 %d/%d" % [GameState.population, GameState.max_population]
	defense_label.text = "🛡️ DPS: %.1f" % GameState.defense_dps
	
	# Energy balance
	var produced: float = GameState.get_energy_production()
	var consumed: float = GameState.get_total_energy_consumption()
	var balance: float = produced - consumed
	var energy_color: String = "green" if balance >= 0 else "red"
	energy_label.text = "[color=%s]🔋 %.1f/%.1f[/color]" % [energy_color, produced, consumed]
	
	# Wave timer
	# (We need a reference to DefenseSystem — we'll use a signal instead)
	wave_label.text = "⚔️ Волна: ожидание..."
