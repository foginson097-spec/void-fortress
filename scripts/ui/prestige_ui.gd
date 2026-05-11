extends Control
## Prestige screen — shown when player wants to jump to next sector.

@onready var sector_info: Label = $SectorInfo
@onready var cost_label: Label = $CostLabel
@onready var tech_preview: Label = $TechPreview
@onready var jump_btn: Button = $JumpBtn
@onready var upgrade_list: VBoxContainer = $UpgradeList
@onready var tech_points_label: Label = $TechPointsLabel


func _ready() -> void:
	hide()
	jump_btn.pressed.connect(_on_jump)


func show_screen() -> void:
	_refresh()
	show()


func hide_screen() -> void:
	hide()


func _refresh() -> void:
	var next_sector: int = GameState.current_sector + 1
	
	sector_info.text = "Текущий сектор: %s → Следующий: Сектор %d" % [
		GameState.sector_params.get("name", "???"),
		next_sector + 1
	]
	
	# Jump cost
	var cost: Dictionary = GameState.sector_params.get("jump_cost", {})
	var cost_text: String = "Стоимость прыжка:\n"
	for res in cost:
		var available: float = GameState.resources.get(res, 0.0)
		var color: String = "green" if available >= cost[res] else "red"
		cost_text += "  [color=%s]%s: %.1f / %.1f[/color]\n" % [color, res, available, cost[res]]
	cost_label.text = cost_text
	
	# Tech preview
	var prestige_node = get_node_or_null("/root/Main/Prestige")
	if prestige_node and prestige_node.has_method("_calculate_tech_points"):
		# We can't call private methods, but we can approximate
		var est_points: float = GameState.grid.size() * 2.0 + GameState.population * 0.5 + GameState.defense_dps * 0.1
		est_points *= (1.0 + GameState.current_sector * 0.5)
		tech_preview.text = "Ожидаемые тех-очки: %.1f" % max(1.0, est_points)
	
	# Jump button state
	jump_btn.disabled = not GameState.has_resources(cost)
	
	# Tech points
	tech_points_label.text = "Тех-очки: %.1f" % GameState.tech_points
	
	# Upgrade list
	_refresh_upgrades()


func _refresh_upgrades() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	
	var upgrades = {
		"mining_bonus": "⛏️ Бонус добычи +0.1",
		"crafting_speed": "⚙️ Скорость крафта +0.1",
		"defense_bonus": "🛡️ Бонус обороны +0.15",
		"pop_growth_bonus": "👥 Рост населения +0.1",
		"auto_craft": "🤖 Авто-крафт (разово)",
		"start_turrets": "🎯 +1 турель на старте"
	}
	
	for upgrade in upgrades:
		var btn: Button = Button.new()
		var current_level: float = GameState.permanent_upgrades.get(upgrade, 0.0)
		
		if upgrade == "auto_craft":
			btn.text = "%s [%s]" % [upgrades[upgrade], "✓" if current_level else "—"]
			btn.disabled = bool(current_level)
		else:
			btn.text = "%s (%.1f)" % [upgrades[upgrade], current_level]
		
		btn.pressed.connect(_on_buy_upgrade.bind(upgrade))
		upgrade_list.add_child(btn)


func _on_jump() -> void:
	var controller = get_node_or_null("/root/Main")
	if controller and controller.has_method("perform_prestige"):
		controller.perform_prestige()
		hide_screen()


func _on_buy_upgrade(upgrade_name: String) -> void:
	var controller = get_node_or_null("/root/Main")
	if controller and controller.has_method("buy_upgrade"):
		controller.buy_upgrade(upgrade_name)
		_refresh()
