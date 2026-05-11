extends Camera3D
## Orbital camera v3 — КУБ-КОРАБЛЬ.
## Космос: свободная орбита вокруг куба.
## При приближении к грани: RTS-режим (top-down на грань + pan + zoom).

@export var target: Node3D
@export var min_distance: float = 0.3
@export var max_distance: float = 12000.0
@export var start_distance: float = 600.0

@export var rotation_speed_h: float = 0.3
@export var rotation_speed_v: float = 0.3
@export var zoom_speed: float = 0.12

@export var min_angle_v: float = -89.0
@export var max_angle_v: float = -1.0

@export var cube_size: float = 400.0

# Порог перехода в RTS-режим (расстояние до грани)
const FACE_LOCK_DISTANCE: float = 80.0

# Face normals (match ship_builder)
const FACE_NORMALS = [
	Vector3(0, 0, 1),   # Front
	Vector3(0, 0, -1),  # Back
	Vector3(1, 0, 0),   # Right
	Vector3(-1, 0, 0),  # Left
	Vector3(0, 1, 0),   # Top
	Vector3(0, -1, 0),  # Bottom
]

enum CameraMode { COSMOS, RTS }
var _mode: CameraMode = CameraMode.COSMOS
var _active_face: int = -1

# Cosmos state
var _distance: float
var _angle_h: float = 0.0
var _angle_v: float = -20.0
var _target_distance: float

# RTS state
var _rts_pan: Vector2 = Vector2.ZERO  # pan offset on face plane
var _rts_zoom: float = 30.0           # distance from face surface

# Smoothing
@export var zoom_smoothing: float = 8.0
@export var mode_transition_speed: float = 3.0

# Transition
var _transition_t: float = 0.0  # 0=cosmos, 1=RTS


func _ready() -> void:
	_distance = start_distance
	_target_distance = start_distance
	if not target:
		target = get_node_or_null("../World/Ship")


func _input(event: InputEvent) -> void:
	match _mode:
		CameraMode.COSMOS:
			_input_cosmos(event)
		CameraMode.RTS:
			_input_rts(event)


func _input_cosmos(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_angle_h -= event.relative.x * rotation_speed_h * 0.01 * _distance
		_angle_v -= event.relative.y * rotation_speed_v * 0.01 * _distance
		_angle_v = clamp(_angle_v, min_angle_v, max_angle_v)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_distance *= (1.0 - zoom_speed)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_distance *= (1.0 + zoom_speed)
		_target_distance = clamp(_target_distance, min_distance, max_distance)


func _input_rts(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Pan on face plane
		var speed: float = _rts_zoom * 0.01
		var face_normal: Vector3 = FACE_NORMALS[_active_face]
		var perp: Array = _perpendiculars(face_normal)
		var u: Vector3 = perp[0]
		var v: Vector3 = perp[1]
		_rts_pan.x -= event.relative.x * speed * 0.5
		_rts_pan.y -= event.relative.y * speed * 0.5
		
		# Clamp pan to face bounds
		var half: float = cube_size * 0.45
		_rts_pan.x = clamp(_rts_pan.x, -half, half)
		_rts_pan.y = clamp(_rts_pan.y, -half, half)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_rts_zoom = max(1.0, _rts_zoom * 0.88)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_rts_zoom = min(200.0, _rts_zoom * 1.12)


func _process(delta: float) -> void:
	if not target:
		return
	
	# Smooth zoom
	_distance = lerp(_distance, _target_distance, zoom_smoothing * delta)
	
	# Detect nearest face
	var cam_world_pos: Vector3 = global_position
	var nearest_face: int = _find_nearest_face(cam_world_pos)
	var dist_to_face: float = _distance_to_face(cam_world_pos, nearest_face)
	
	# Mode decision
	var target_mode: CameraMode = CameraMode.RTS if dist_to_face < FACE_LOCK_DISTANCE else CameraMode.COSMOS
	
	if target_mode != _mode:
		_mode = target_mode
		if _mode == CameraMode.RTS:
			_active_face = nearest_face
			# Initialize RTS state from current camera position
			_init_rts_from_camera()
		else:
			_active_face = -1
			_rts_pan = Vector2.ZERO
	
	# Smooth transition
	if _mode == CameraMode.RTS:
		_transition_t = move_toward(_transition_t, 1.0, mode_transition_speed * delta)
		_process_rts(delta)
	else:
		_transition_t = move_toward(_transition_t, 0.0, mode_transition_speed * delta)
		_process_cosmos(delta)


func _process_cosmos(_delta: float) -> void:
	var rad_v: float = deg_to_rad(_angle_v)
	var rad_h: float = deg_to_rad(_angle_h)
	var offset: Vector3 = Vector3(
		_distance * cos(rad_v) * sin(rad_h),
		_distance * sin(rad_v),
		_distance * cos(rad_v) * cos(rad_h)
	)
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)


func _process_rts(_delta: float) -> void:
	if _active_face < 0:
		return
	
	var face_normal: Vector3 = FACE_NORMALS[_active_face]
	var perp: Array = _perpendiculars(face_normal)
	var u: Vector3 = perp[0]
	var v: Vector3 = perp[1]
	
	# Target: camera looks perpendicular to face from above
	var face_center: Vector3 = target.global_position + face_normal * cube_size * 0.5
	var cam_target: Vector3 = face_center + u * _rts_pan.x + v * _rts_pan.y
	var cam_pos: Vector3 = cam_target + face_normal * _rts_zoom
	
	# Blend between cosmos (free) position and RTS (locked) position
	# _transition_t: 0=cosmos, 1=RTS
	global_position = global_position.lerp(cam_pos, _transition_t * 5.0 * _delta)
	var look_target: Vector3 = face_center.lerp(cam_target, _transition_t * 5.0 * _delta)
	look_at(look_target, Vector3.UP)


func _init_rts_from_camera() -> void:
	## Initialize RTS pan/zoom from current camera position relative to face.
	if _active_face < 0:
		return
	var face_normal: Vector3 = FACE_NORMALS[_active_face]
	var face_center: Vector3 = target.global_position + face_normal * cube_size * 0.5
	
	# Distance from camera to face plane
	var to_cam: Vector3 = global_position - face_center
	_rts_zoom = abs(to_cam.dot(face_normal))
	_rts_zoom = clamp(_rts_zoom, 1.0, 200.0)
	
	# Pan: project camera position onto face plane
	var perp: Array = _perpendiculars(face_normal)
	var u: Vector3 = perp[0]
	var v: Vector3 = perp[1]
	var on_plane: Vector3 = global_position - face_normal * to_cam.dot(face_normal)
	var from_center: Vector3 = on_plane - face_center
	_rts_pan.x = from_center.dot(u)
	_rts_pan.y = from_center.dot(v)


# ===============================
# FACE DETECTION
# ===============================

func _find_nearest_face(pos: Vector3) -> int:
	var local_pos: Vector3 = pos - target.global_position
	var best_face: int = 0
	var best_dist: float = INF
	
	for i in range(FACE_NORMALS.size()):
		var dist: float = _distance_to_face_at(local_pos, i)
		if abs(dist) < abs(best_dist):
			best_dist = dist
			best_face = i
	
	return best_face


func _distance_to_face(pos: Vector3, face_idx: int) -> float:
	var local_pos: Vector3 = pos - target.global_position
	return _distance_to_face_at(local_pos, face_idx)


func _distance_to_face_at(local_pos: Vector3, face_idx: int) -> float:
	var normal: Vector3 = FACE_NORMALS[face_idx]
	var half: float = cube_size * 0.5
	# Distance from point to the face plane (positive = outside)
	return local_pos.dot(normal) - half


func _perpendiculars(normal: Vector3) -> Array:
	var n: Vector3 = normal.normalized()
	var u: Vector3
	if abs(n.x) < 0.99:
		u = Vector3(1, 0, 0).cross(n).normalized()
	else:
		u = Vector3(0, 1, 0).cross(n).normalized()
	var v: Vector3 = n.cross(u)
	return [u, v]


func get_current_lod() -> String:
	var dist: float = _distance
	if _mode == CameraMode.RTS:
		dist = _rts_zoom
	if dist >= 500.0: return "cosmos"
	elif dist >= 80.0: return "orbit"
	elif dist >= 8.0: return "continent"
	elif dist >= 1.0: return "city"
	else: return "street"


func get_distance() -> float:
	return _distance


func get_active_face() -> int:
	return _active_face


func get_mode() -> CameraMode:
	return _mode
