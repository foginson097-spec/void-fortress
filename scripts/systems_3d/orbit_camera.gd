extends Camera3D
## Orbital camera v2 — космос: свободная орбита. Атмосфера: top-down constrained.
## Seamless переход при пересечении границы атмосферы (distance < 100m).

@export var target: Node3D
@export var min_distance: float = 0.3       # улица
@export var max_distance: float = 10000.0   # далёкий космос
@export var start_distance: float = 400.0   # старт — орбита (видно весь квадрат)

@export var rotation_speed_h: float = 0.3
@export var rotation_speed_v: float = 0.3
@export var zoom_speed: float = 0.12

@export var min_angle_v: float = -89.0
@export var max_angle_v: float = -1.0

# Граница атмосферы (переход между режимами)
const ATMOSPHERE_BOUNDARY: float = 100.0  # метров

# Режим камеры
enum CameraMode { COSMOS, ATMOSPHERE }
var _mode: CameraMode = CameraMode.COSMOS

# State
var _distance: float
var _angle_h: float = 0.0
var _angle_v: float = -30.0
var _target_distance: float

# Pan в режиме атмосферы (смещение точки взгляда)
var _pan_offset: Vector2 = Vector2.ZERO

# Smoothing
@export var zoom_smoothing: float = 8.0
@export var mode_transition_speed: float = 2.0  # скорость перехода между режимами

# Целевые углы для атмосферного режима
const ATMOSPHERE_ANGLE_V: float = -80.0  # почти отвесно вниз


func _ready() -> void:
	_distance = start_distance
	_target_distance = start_distance
	if not target:
		target = get_node_or_null("../World/Ship")


func _input(event: InputEvent) -> void:
	match _mode:
		CameraMode.COSMOS:
			_input_cosmos(event)
		CameraMode.ATMOSPHERE:
			_input_atmosphere(event)


func _input_cosmos(event: InputEvent) -> void:
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


func _input_atmosphere(event: InputEvent) -> void:
	# В атмосфере: правый клик = pan, колёсико = зум
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_pan_offset.x -= event.relative.x * 0.5 * (_distance / ATMOSPHERE_BOUNDARY)
		_pan_offset.y += event.relative.y * 0.5 * (_distance / ATMOSPHERE_BOUNDARY)  # инвертировано
	
	# Middle mouse = tilt (лёгкое отклонение от отвеса)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_angle_h -= event.relative.x * 0.2
	
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
	
	# Определяем режим
	var target_mode: CameraMode = CameraMode.ATMOSPHERE if _distance < ATMOSPHERE_BOUNDARY else CameraMode.COSMOS
	
	# Переход между режимами
	if target_mode != _mode:
		_mode = target_mode
		if _mode == CameraMode.ATMOSPHERE:
			# При входе в атмосферу — сбрасываем pan
			_pan_offset = Vector2.ZERO
		else:
			# При выходе — сбрасываем pan
			_pan_offset = Vector2.ZERO
	
	# Движение камеры в зависимости от режима
	if _mode == CameraMode.COSMOS:
		_process_cosmos(delta)
	else:
		_process_atmosphere(delta)


func _process_cosmos(_delta: float) -> void:
	# Сферическая орбита
	var rad_v: float = deg_to_rad(_angle_v)
	var rad_h: float = deg_to_rad(_angle_h)
	
	var offset: Vector3 = Vector3(
		_distance * cos(rad_v) * sin(rad_h),
		_distance * sin(rad_v),
		_distance * cos(rad_v) * cos(rad_h)
	)
	
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)


func _process_atmosphere(delta: float) -> void:
	# Плавный переход к top-down углу
	var target_angle_v: float = ATMOSPHERE_ANGLE_V
	_angle_v = lerp(_angle_v, target_angle_v, mode_transition_speed * delta)
	
	# Top-down позиция с pan
	var rad_v: float = deg_to_rad(_angle_v)
	var rad_h: float = deg_to_rad(_angle_h)
	
	var offset: Vector3 = Vector3(
		_distance * cos(rad_v) * sin(rad_h) + _pan_offset.x,
		_distance * sin(rad_v),
		_distance * cos(rad_v) * cos(rad_h) + _pan_offset.y
	)
	
	var look_target: Vector3 = target.global_position + Vector3(_pan_offset.x, 0, _pan_offset.y)
	global_position = target.global_position + offset
	look_at(look_target, Vector3.UP)


func get_current_lod() -> String:
	if _distance >= 500.0:
		return "cosmos"
	elif _distance >= 40.0:
		return "orbit"
	elif _distance >= 4.0:
		return "continent"
	elif _distance >= 0.5:
		return "city"
	else:
		return "street"


func get_distance() -> float:
	return _distance


func get_mode() -> CameraMode:
	return _mode
