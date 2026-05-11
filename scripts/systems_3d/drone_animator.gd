extends Node3D
## Drone Light Animator — двигает огни дронов по поверхности корабля.
## Прицепляется к LOD_Cosmos и анимирует DroneLights каждый кадр.
## Также управляет вспышками фар (flares).

@export var lod_cosmos: Node3D

var _time: float = 0.0


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
			_animate_flare(child)


func _animate_drone(light: OmniLight3D, delta: float) -> void:
	var speed_x: float = light.get_meta("speed_x", 0.0)
	var speed_z: float = light.get_meta("speed_z", 0.0)
	var bound: float = light.get_meta("bound", 200.0)
	
	light.position.x += speed_x * delta
	light.position.z += speed_z * delta
	
	# Отскок от границ
	if abs(light.position.x) > bound:
		light.position.x = sign(light.position.x) * bound
		light.set_meta("speed_x", -speed_x)
	if abs(light.position.z) > bound:
		light.position.z = sign(light.position.z) * bound
		light.set_meta("speed_z", -speed_z)
	
	# Мерцание
	light.light_energy = 0.4 + sin(_time * 3.0 + light.position.x * 0.1) * 0.3


func _animate_flare(light: OmniLight3D, _delta: float) -> void:
	var phase: float = light.get_meta("phase", 0.0)
	# Вспышка раз в 2-5 секунд
	var cycle: float = sin(_time * 1.5 + phase)
	var flash: float = 0.0
	if cycle > 0.85:
		flash = (cycle - 0.85) / 0.15  # 0→1 за 0.15 цикла
	light.light_energy = flash * 3.0
