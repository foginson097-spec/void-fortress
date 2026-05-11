extends Node3D
## Drone Light Animator v2 — куб-версия.
## Дроны скользят по поверхности куба, оставаясь на своих гранях.

@export var lod_cosmos: Node3D
@export var cube_size: float = 400.0

var _time: float = 0.0
var _half: float:
	get: return cube_size * 0.5


func _ready() -> void:
	if not lod_cosmos:
		lod_cosmos = get_node_or_null("../LOD_Cosmos")


func _process(delta: float) -> void:
	if not lod_cosmos or not lod_cosmos.visible:
		return
	
	_time += delta
	var drone_lights: Node = lod_cosmos.get_node_or_null("DroneLights")
	if not drone_lights:
		return
	
	for child in drone_lights.get_children():
		if child.name.begins_with("DroneLight"):
			_animate_drone(child, delta)
		elif child.name.begins_with("Flare"):
			# Flares not in v3 yet, but keep if they exist
			pass


func _animate_drone(light: OmniLight3D, delta: float) -> void:
	var speed_u: float = light.get_meta("speed_u", 0.0)
	var speed_v: float = light.get_meta("speed_v", 0.0)
	var face_normal: Vector3 = light.get_meta("face_normal", Vector3.UP)
	var u: Vector3 = light.get_meta("u_axis", Vector3.RIGHT)
	var v: Vector3 = light.get_meta("v_axis", Vector3.FORWARD)
	
	# Current position relative to face center
	var face_center: Vector3 = face_normal * _half
	var rel: Vector3 = light.position - face_center
	var u_pos: float = rel.dot(u)
	var v_pos: float = rel.dot(v)
	
	# Move
	u_pos += speed_u * delta
	v_pos += speed_v * delta
	
	# Bounce at face edges
	if abs(u_pos) > _half:
		u_pos = sign(u_pos) * _half
		light.set_meta("speed_u", -speed_u)
	if abs(v_pos) > _half:
		v_pos = sign(v_pos) * _half
		light.set_meta("speed_v", -speed_v)
	
	light.position = face_center + u * u_pos + v * v_pos + face_normal * 0.2
	
	# Flicker
	light.light_energy = 0.2 + sin(_time * 2.5 + u_pos * 0.1 + v_pos * 0.1) * 0.25
