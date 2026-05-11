extends Camera3D
## Orbital camera — вращается вокруг цели, зум колёсиком/тачем.
## Поддерживает seamless переход от «космос» (5km) до «улица» (1m).

@export var target: Node3D
@export var min_distance: float = 0.3       # улица — носом в NPC
@export var max_distance: float = 8000.0     # космос — весь корабль
@export var start_distance: float = 25.0     # стартовый зум (орбита)

@export var rotation_speed_h: float = 0.3    # горизонталь (мышь)
@export var rotation_speed_v: float = 0.3    # вертикаль
@export var zoom_speed: float = 0.12         # скролл

@export var min_angle_v: float = -89.0       # почти снизу
@export var max_angle_v: float = -1.0        # почти сверху (но не переворот)

# LOD thresholds (match lod_manager.gd)
const LOD_COSMOS: float = 1000.0    # >1km = силуэт
const LOD_ORBIT: float = 100.0      # 100-1000m = low-poly
const LOD_CONTINENT: float = 10.0   # 10-100m = детали
const LOD_CITY: float = 1.0         # 1-10m = здания
# <1m = street

# State
var _distance: float
var _angle_h: float = 0.0
var _angle_v: float = -30.0
var _target_distance: float

# Smoothing
@export var zoom_smoothing: float = 8.0


func _ready() -> void:
	_distance = start_distance
	_target_distance = start_distance
	if not target:
		target = get_node_or_null("../Ship")


func _input(event: InputEvent) -> void:
	# Right mouse drag = orbit
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_angle_h -= event.relative.x * rotation_speed_h * 0.01 * _distance
		_angle_v -= event.relative.y * rotation_speed_v * 0.01 * _distance
		_angle_v = clamp(_angle_v, min_angle_v, max_angle_v)
	
	# Scroll = zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_distance *= (1.0 - zoom_speed)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_distance *= (1.0 + zoom_speed)
		_target_distance = clamp(_target_distance, min_distance, max_distance)


func _process(delta: float) -> void:
	if not target:
		return
	
	# Smooth zoom
	_distance = lerp(_distance, _target_distance, zoom_smoothing * delta)
	
	# Calculate position on sphere around target
	var rad_v: float = deg_to_rad(_angle_v)
	var rad_h: float = deg_to_rad(_angle_h)
	
	var offset: Vector3 = Vector3(
		_distance * cos(rad_v) * sin(rad_h),
		_distance * sin(rad_v),
		_distance * cos(rad_v) * cos(rad_h)
	)
	
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)


func get_current_lod() -> String:
	## Returns the current LOD layer name based on camera distance.
	if _distance >= LOD_COSMOS:
		return "cosmos"
	elif _distance >= LOD_ORBIT:
		return "orbit"
	elif _distance >= LOD_CONTINENT:
		return "continent"
	elif _distance >= LOD_CITY:
		return "city"
	else:
		return "street"


func get_distance() -> float:
	return _distance
