extends Node3D
## Floating Origin — решает проблему 32-битных координат при огромном мире.
## При удалении камеры от центра > threshold — двигаем ВЕСЬ мир обратно.
## Игрок не замечает, точность сохраняется.

@export var origin_node: Node3D          # корень мира (World)
@export var camera: Camera3D             # ссылка на камеру
@export var threshold: float = 5000.0    # метров, когда сдвигать
@export var recenter_at: float = 100.0   # сдвигаем мир чтобы камера была здесь

var _accumulated_offset: Vector3 = Vector3.ZERO  # общий сдвиг для UI/логики


func _ready() -> void:
	if not camera:
		camera = get_node_or_null("../Camera3D")
	if not origin_node:
		origin_node = get_node_or_null("../World")


func _process(_delta: float) -> void:
	if not camera or not origin_node:
		return
	
	var cam_pos: Vector3 = camera.global_position
	
	if cam_pos.length() > threshold:
		# Сдвигаем мир чтобы камера стала ближе к (0,0,0)
		var shift: Vector3 = -cam_pos + Vector3(recenter_at, 0, recanter_at)
		origin_node.global_position += shift
		_accumulated_offset += shift
		# Камера автоматически пересчитает позицию в следующем кадре


func get_world_offset() -> Vector3:
	## Для UI/логики: абсолютная позиция = local_pos + world_offset.
	return _accumulated_offset
