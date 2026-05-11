extends MeshInstance3D
## Atmosphere sphere — скрывает переключение LOD туманом.
## Когда камера входит в сферу → туман усиливается → LOD меняется → выходит.
## Выглядит как «вход в атмосферу корабля».

@export var camera: Camera3D
@export var atmosphere_radius: float = 100.0    # радиус сферы
@export var transition_zone: float = 20.0       # зона перехода (край сферы)

# Текущая прозрачность (0 = прозрачно, 1 = непрозрачно)
var _current_alpha: float = 0.0

# Сигнал: камера вошла/вышла из атмосферы
signal atmosphere_entered
signal atmosphere_exited

var _was_inside: bool = false


func _ready() -> void:
	if not camera:
		camera = get_node_or_null("../Camera3D")
	
	# Create our own sphere mesh (was removed from .tscn due to SubResource error)
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = atmosphere_radius
	sphere_mesh.height = atmosphere_radius * 2.0
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32
	mesh = sphere_mesh
	
	# Настройка материала
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _create_atmosphere_shader()
	mesh.surface_set_material(0, mat)
	
	mat.set_shader_parameter("alpha", 0.0)
	mat.set_shader_parameter("color", Color(0.3, 0.4, 0.8, 1.0))  # голубоватый туман


func _process(_delta: float) -> void:
	if not camera:
		return
	
	# Расстояние от камеры до центра сферы
	var dist_to_center: float = camera.global_position.distance_to(global_position)
	var dist_to_surface: float = atmosphere_radius - dist_to_center
	
	# Нормализуем: 0 = снаружи, 1 = глубоко внутри
	var target_alpha: float = 0.0
	
	if dist_to_surface > 0:
		# Камера внутри сферы
		target_alpha = clamp(dist_to_surface / transition_zone, 0.0, 1.0)
	else:
		# Камера снаружи — туман только на самом краю
		target_alpha = clamp(1.0 + dist_to_surface / transition_zone, 0.0, 0.3)
	
	# Плавный переход
	_current_alpha = lerp(_current_alpha, target_alpha, 3.0 * _delta)
	
	# Применяем
	var mat: Material = mesh.surface_get_material(0)
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("alpha", _current_alpha)
	
	# Сигналы входа/выхода
	var is_inside: bool = dist_to_surface > 0
	if is_inside and not _was_inside:
		atmosphere_entered.emit()
	elif not is_inside and _was_inside:
		atmosphere_exited.emit()
	_was_inside = is_inside


func _create_atmosphere_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform float alpha: hint_range(0.0, 1.0) = 0.0;
uniform vec4 color: source_color = vec4(0.3, 0.4, 0.8, 1.0);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = alpha;
}
"""
	return shader
