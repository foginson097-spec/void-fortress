extends Node
## LOD Manager — включает/выключает 5 слоёв детализации корабля
## в зависимости от расстояния камеры. Без загрузки — все слои в сцене.

@export var camera: Camera3D
@export var lod_cosmos: Node3D     # импостор (спрайт/силуэт)
@export var lod_orbit: Node3D      # low-poly модель
@export var lod_continent: Node3D  # средняя детализация
@export var lod_city: Node3D       # здания
@export var lod_street: Node3D     # NPC, детали

# Переходные зоны — чтобы не было резкого переключения
@export var hysteresis: float = 0.05  # 5% гистерезис

# Текущее состояние
var _current_lod: String = "orbit"
var _previous_lod: String = "orbit"

# Сигналы
signal lod_changed(from_lod: String, to_lod: String)


func _ready() -> void:
	if not camera:
		camera = get_node_or_null("../Camera3D")
	
	# Начальное состояние: показываем орбитальный LOD
	_set_lod("orbit")


func _process(_delta: float) -> void:
	if not camera:
		return
	
	var dist: float = 0.0
	if camera.has_method("get_distance"):
		dist = camera.get_distance()
	else:
		dist = camera.global_position.distance_to(Vector3.ZERO)
	
	var new_lod: String = _lod_from_distance(dist)
	
	if new_lod != _current_lod:
		_previous_lod = _current_lod
		_set_lod(new_lod)


func _lod_from_distance(dist: float) -> String:
	# С гистерезисом — переключение вверх (приближение) требует ближе,
	# переключение вниз (отдаление) требует дальше.
	var h: float = 1.0 - hysteresis
	
	match _current_lod:
		"cosmos":
			if dist < 1000.0 * h: return "orbit"
		"orbit":
			if dist < 100.0 * h: return "continent"
			elif dist > 1000.0 / h: return "cosmos"
		"continent":
			if dist < 10.0 * h: return "city"
			elif dist > 100.0 / h: return "orbit"
		"city":
			if dist < 1.0 * h: return "street"
			elif dist > 10.0 / h: return "continent"
		"street":
			if dist > 1.0 / h: return "city"
	
	return _current_lod


func _set_lod(new_lod: String) -> void:
	_current_lod = new_lod
	
	# Включаем только нужный слой
	if lod_cosmos:
		lod_cosmos.visible = (new_lod == "cosmos")
	if lod_orbit:
		lod_orbit.visible = (new_lod == "orbit")
	if lod_continent:
		lod_continent.visible = (new_lod == "continent")
	if lod_city:
		lod_city.visible = (new_lod == "city")
	if lod_street:
		lod_street.visible = (new_lod == "street")
	
	lod_changed.emit(_previous_lod, new_lod)


func get_current_lod() -> String:
	return _current_lod
