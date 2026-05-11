extends Node
## LOD Manager v3 — per-face LOD for cube ship.
## Detects which face the camera is on and shows that face's details.

@export var camera: Camera3D
@export var lod_cosmos: Node3D
@export var lod_orbit: Node3D
@export var star_field: Node3D           # звёзды — скрываются на континенте

# Face LOD nodes (set in game_controller)
var _face_continents: Dictionary = {}  # {0: Node3D, 1: Node3D, ...}
var _face_cities: Dictionary = {}
var _face_streets: Dictionary = {}

# Face names matching ship_builder
const FACE_NAMES = ["Front", "Back", "Right", "Left", "Top", "Bottom"]

@export var hysteresis: float = 0.05

var _current_lod: String = "cosmos"
var _active_face: int = -1

signal lod_changed(from_lod: String, to_lod: String)
signal face_changed(face_idx: int)


func register_face_lod(face_idx: int, lod_type: String, node: Node3D) -> void:
	match lod_type:
		"continent":
			_face_continents[face_idx] = node
		"city":
			_face_cities[face_idx] = node
		"street":
			_face_streets[face_idx] = node


func _process(_delta: float) -> void:
	if not camera:
		return
	
	var dist: float = 0.0
	if camera.has_method("get_distance"):
		dist = camera.get_distance()
	
	var new_lod: String = _lod_from_distance(dist)
	var new_face: int = -1
	if camera.has_method("get_active_face"):
		new_face = camera.get_active_face()
	
	# Update global LODs
	if new_lod != _current_lod:
		_set_lod(new_lod)
	
	# Update face-specific LODs
	if new_face != _active_face or new_lod != _current_lod:
		_set_face_lod(new_face, new_lod)
		_active_face = new_face


func _lod_from_distance(dist: float) -> String:
	var h: float = 1.0 - hysteresis
	match _current_lod:
		"cosmos":
			if dist < 500.0 * h: return "orbit"
		"orbit":
			if dist < 80.0 * h: return "continent"
			elif dist > 500.0 / h: return "cosmos"
		"continent":
			if dist < 8.0 * h: return "city"
			elif dist > 80.0 / h: return "orbit"
		"city":
			if dist < 1.0 * h: return "street"
			elif dist > 8.0 / h: return "continent"
		"street":
			if dist > 1.0 / h: return "city"
	return _current_lod


func _set_lod(new_lod: String) -> void:
	var prev: String = _current_lod
	_current_lod = new_lod
	
	if lod_cosmos: lod_cosmos.visible = (new_lod == "cosmos")
	if lod_orbit: lod_orbit.visible = (new_lod == "orbit")
	
	lod_changed.emit(prev, new_lod)


func _set_face_lod(face_idx: int, lod: String) -> void:
	# Hide all face LODs, then show only the active face's LOD
	var on_continent: bool = (lod in ["continent", "city", "street"])
	
	# Hide cosmos, orbit, and stars when on a continent (RTS mode)
	if lod_cosmos: lod_cosmos.visible = not on_continent
	if lod_orbit: lod_orbit.visible = not on_continent
	if star_field: star_field.visible = not on_continent
	
	for i in range(6):
		if i in _face_continents:
			_face_continents[i].visible = (i == face_idx and on_continent)
		if i in _face_cities:
			_face_cities[i].visible = (i == face_idx and lod in ["city", "street"])
		if i in _face_streets:
			_face_streets[i].visible = (i == face_idx and lod == "street")
	
	if face_idx != _active_face:
		face_changed.emit(face_idx)


func get_current_lod() -> String:
	return _current_lod
