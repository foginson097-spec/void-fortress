extends Node3D
## Star field — создаёт иллюзию полёта корабля сквозь космос.
## Звёзды-партиклы движутся навстречу (или вращаются) относительно корабля.

@export var particle_count: int = 2000
@export var field_radius: float = 3000.0     # сфера звёзд
@export var rotation_speed: float = 0.005    # рад/сек (медленное вращение)
@export var drift_speed: float = 5.0         # скорость «полёта» звёзд к кораблю

var _stars: Array[Vector3] = []
var _star_mesh: ImmediateMesh
var _material: StandardMaterial3D
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_generate_stars()
	_create_mesh()


func _generate_stars() -> void:
	_stars.clear()
	for i in range(particle_count):
		# Равномерное распределение в сфере
		var dir: Vector3 = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()
		var dist: float = randf_range(field_radius * 0.3, field_radius)
		_stars.append(dir * dist)


func _create_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	
	_star_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _star_mesh
	
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.disable_receive_shadows = true
	_mesh_instance.material_override = _material


func _process(delta: float) -> void:
	# Вращение звёздного поля
	rotate_y(rotation_speed * delta)
	rotate_x(rotation_speed * 0.3 * delta)
	
	# Движение звёзд «навстречу» (эффект полёта)
	for i in range(_stars.size()):
		_stars[i] -= Vector3(0, 0, drift_speed * delta)
		
		# Если звезда улетела далеко — переспавнить впереди
		if _stars[i].z < -field_radius:
			_stars[i] = Vector3(
				randf_range(-field_radius, field_radius),
				randf_range(-field_radius, field_radius),
				field_radius * randf_range(0.5, 1.0)
			)
	
	_render()


func _render() -> void:
	_star_mesh.clear_surfaces()
	_star_mesh.surface_begin(Mesh.PRIMITIVE_POINTS)
	
	for star in _stars:
		# Яркость зависит от дальности
		var dist_ratio: float = clamp(abs(star.z) / field_radius, 0.0, 1.0)
		var brightness: float = lerp(1.0, 0.3, dist_ratio)
		var color: Color = Color(brightness, brightness, brightness * 0.9 + 0.1)
		_star_mesh.surface_set_color(color)
		_star_mesh.surface_add_vertex(star)
	
	_star_mesh.surface_end()
