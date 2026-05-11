extends Node
## Ship Builder v2 — ПЛОСКИЙ КОРАБЛЬ-КВАДРАТ.
## Космос: квадрат + огни дронов. Атмосфера: смена камеры.
## Континенты: геометрические секторы. Город: ульи + панели + реки проводов.

@export var ship_root: Node3D
@export var ship_size: float = 500.0          # сторона квадрата (корабль огромный)
@export var cell_cols: int = 8
@export var cell_rows: int = 6
@export var cell_size: float = 40.0           # размер одной ячейки


func build_all_lods() -> void:
	build_lod_cosmos()
	build_lod_orbit()
	build_lod_continent()
	build_lod_city()
	build_lod_street()


# ===============================
# LOD 1: КОСМОС — огромный квадрат с движущимися огнями дронов
# ===============================
func build_lod_cosmos() -> Node3D:
	var parent: Node3D = _get_or_create_lod("LOD_Cosmos")
	
	# Тёмная платформа — силуэт корабля
	var plane: MeshInstance3D = MeshInstance3D.new()
	plane.name = "ShipSilhouette"
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(ship_size, ship_size)
	plane_mesh.orientation = PlaneMesh.FACE_Z  # горизонтально
	plane.mesh = plane_mesh
	plane.rotation_degrees = Vector3(-90, 0, 0)
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.08, 0.9)  # почти чёрный
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.02, 0.05)
	mat.emission_energy_multiplier = 0.3
	plane.material_override = mat
	parent.add_child(plane)
	
	# Огни дронов — яркие точки, движущиеся по поверхности
	var drone_lights: Node3D = Node3D.new()
	drone_lights.name = "DroneLights"
	parent.add_child(drone_lights)
	
	for i in range(30):
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "DroneLight_%d" % i
		light.light_color = Color(0.0, 0.7, 1.0)  # голубой
		light.light_energy = 0.6 + randf() * 0.8
		light.omni_range = ship_size * 0.08
		light.position = Vector3(
			randf_range(-ship_size * 0.45, ship_size * 0.45),
			0.5,
			randf_range(-ship_size * 0.45, ship_size * 0.45)
		)
		# Анимация движения
		light.set_meta("speed_x", randf_range(-15, 15))
		light.set_meta("speed_z", randf_range(-15, 15))
		light.set_meta("bound", ship_size * 0.45)
		drone_lights.add_child(light)
	
	# Редкие яркие вспышки (фары дронов)
	for i in range(8):
		var flare: OmniLight3D = OmniLight3D.new()
		flare.name = "Flare_%d" % i
		flare.light_color = Color(1.0, 1.0, 0.8)
		flare.light_energy = 2.0
		flare.omni_range = ship_size * 0.12
		flare.position = Vector3(randf_range(-ship_size * 0.4, ship_size * 0.4), 0.5, 
			randf_range(-ship_size * 0.4, ship_size * 0.4))
		flare.set_meta("phase", randf() * TAU)
		drone_lights.add_child(flare)
	
	# Двигатели по краям квадрата
	for i in range(4):
		var engine: OmniLight3D = OmniLight3D.new()
		engine.name = "Engine_%d" % i
		engine.light_color = Color(0.8, 0.3, 0.1)  # оранжевый
		engine.light_energy = 3.0
		engine.omni_range = ship_size * 0.15
		var angle: float = i * TAU / 4.0 + TAU / 8.0
		engine.position = Vector3(cos(angle) * ship_size * 0.48, -2.0, sin(angle) * ship_size * 0.48)
		parent.add_child(engine)
	
	print("[ShipBuilder] LOD_Cosmos: square silhouette + 30 drone lights + 8 flares + 4 engines")
	_set_visibility_range(parent, 500.0, 10000.0)
	return parent


# ===============================
# LOD 2: ОРБИТА — плоская поверхность с геометрическими континентами
# ===============================
func build_lod_orbit() -> Node3D:
	var parent: Node3D = _get_or_create_lod("LOD_Orbit")
	
	# Основная плоскость
	var plane: MeshInstance3D = MeshInstance3D.new()
	plane.name = "ShipSurface"
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(ship_size, ship_size)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32
	plane.mesh = plane_mesh
	plane.rotation_degrees = Vector3(-90, 0, 0)
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.12, 0.18)
	mat.metallic = 0.8
	mat.roughness = 0.5
	plane.material_override = mat
	parent.add_child(plane)
	
	# Геометрические континенты — прямоугольные секторы
	var continent_colors = [
		Color(0.15, 0.35, 0.15),  # тёмно-зелёный
		Color(0.30, 0.25, 0.12),  # коричневый
		Color(0.12, 0.25, 0.40),  # тёмно-синий
		Color(0.35, 0.30, 0.20),  # бронзовый
		Color(0.20, 0.20, 0.20),  # тёмно-серый
		Color(0.25, 0.35, 0.25),  # зелёный
	]
	
	var continent_rects = [
		Rect2(-ship_size * 0.45, -ship_size * 0.45, ship_size * 0.30, ship_size * 0.35),
		Rect2(-ship_size * 0.10, -ship_size * 0.30, ship_size * 0.40, ship_size * 0.25),
		Rect2(ship_size * 0.10, -ship_size * 0.45, ship_size * 0.35, ship_size * 0.30),
		Rect2(-ship_size * 0.40, ship_size * 0.00, ship_size * 0.35, ship_size * 0.40),
		Rect2(ship_size * 0.00, ship_size * 0.05, ship_size * 0.30, ship_size * 0.30),
		Rect2(-ship_size * 0.20, ship_size * 0.25, ship_size * 0.50, ship_size * 0.20),
	]
	
	for i in range(continent_rects.size()):
		var rect: Rect2 = continent_rects[i]
		var continent: MeshInstance3D = MeshInstance3D.new()
		continent.name = "Continent_%d" % i
		
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(rect.size.x, 0.5, rect.size.y)
		continent.mesh = box
		continent.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.3, rect.position.y + rect.size.y * 0.5)
		
		var cont_mat: StandardMaterial3D = StandardMaterial3D.new()
		cont_mat.albedo_color = continent_colors[i]
		cont_mat.metallic = 0.2
		cont_mat.roughness = 0.7
		continent.material_override = cont_mat
		parent.add_child(continent)
	
	# Разделительные линии (каналы) между континентами
	for i in range(3):
		var line_h: MeshInstance3D = MeshInstance3D.new()
		var box_h: BoxMesh = BoxMesh.new()
		box_h.size = Vector3(ship_size * 0.9, 0.1, 1.5)
		line_h.mesh = box_h
		line_h.position = Vector3(0, 0.55, -ship_size * 0.2 + i * ship_size * 0.2)
		
		var line_mat: StandardMaterial3D = StandardMaterial3D.new()
		line_mat.albedo_color = Color(0.1, 0.5, 0.8)  # голубые каналы
		line_mat.emission_enabled = true
		line_mat.emission = Color(0.1, 0.3, 0.6)
		line_mat.emission_energy_multiplier = 0.5
		line.material_override = line_mat
		parent.add_child(line)
	
	print("[ShipBuilder] LOD_Orbit: flat plane + 6 geometric continents + 3 channels")
	_set_visibility_range(parent, 40.0, 500.0)
	return parent


# ===============================
# LOD 3: КОНТИНЕНТ — секторы с сеткой ячеек
# ===============================
func build_lod_continent() -> Node3D:
	var parent: Node3D = _get_or_create_lod("LOD_Continent")
	
	# Платформа поверхности
	var platform: MeshInstance3D = MeshInstance3D.new()
	platform.name = "SurfacePlatform"
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(cell_cols * cell_size, cell_rows * cell_size)
	plane_mesh.subdivide_width = cell_cols * 4
	plane_mesh.subdivide_depth = cell_rows * 4
	platform.mesh = plane_mesh
	platform.rotation_degrees = Vector3(-90, 0, 0)
	
	var plat_mat: StandardMaterial3D = StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.12, 0.14, 0.20)
	plat_mat.metallic = 0.7
	plat_mat.roughness = 0.4
	platform.material_override = plat_mat
	parent.add_child(platform)
	
	# Сетка ячеек (отсеки)
	var grid_offset: Vector3 = Vector3(
		-(cell_cols - 1) * cell_size * 0.5,
		0.5,
		-(cell_rows - 1) * cell_size * 0.5
	)
	
	var cell_types = ["miner", "smelter", "reactor", "habitat", "turret", "storage", "drone_bay", "assembly",
		"gas_collector", "fab_plant", "refinery", "biolab"]
	var cell_colors = {
		"miner": Color(0.6, 0.4, 0.2),
		"gas_collector": Color(0.4, 0.6, 0.9),
		"smelter": Color(0.8, 0.4, 0.1),
		"fab_plant": Color(0.4, 0.4, 0.6),
		"refinery": Color(0.6, 0.5, 0.2),
		"reactor": Color(1.0, 0.6, 0.0),
		"habitat": Color(0.3, 0.7, 0.7),
		"turret": Color(0.9, 0.2, 0.2),
		"storage": Color(0.5, 0.5, 0.5),
		"drone_bay": Color(0.5, 0.4, 0.7),
		"assembly": Color(0.5, 0.5, 0.8),
		"biolab": Color(0.3, 0.8, 0.4)
	}
	
	for row in range(cell_rows):
		for col in range(cell_cols):
			var cell: MeshInstance3D = MeshInstance3D.new()
			cell.name = "Cell_%d_%d" % [col, row]
			
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(cell_size * 0.75, cell_size * 0.25, cell_size * 0.75)
			cell.mesh = box
			cell.position = grid_offset + Vector3(col * cell_size, 0, row * cell_size)
			
			var cell_type: String = cell_types[(col + row * cell_cols) % cell_types.size()]
			var cell_mat: StandardMaterial3D = StandardMaterial3D.new()
			cell_mat.albedo_color = cell_colors.get(cell_type, Color.GRAY)
			cell_mat.metallic = 0.3
			cell_mat.roughness = 0.5
			cell.material_override = cell_mat
			
			var label: Label3D = Label3D.new()
			label.name = "Label"
			label.text = cell_type
			label.font_size = 12
			label.position = Vector3(0, cell_size * 0.2, 0)
			cell.add_child(label)
			
			parent.add_child(cell)
	
	# Периметр — башни-столбы
	for i in range(16):
		var tower: MeshInstance3D = MeshInstance3D.new()
		tower.name = "Tower_%d" % i
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = cell_size * 0.6
		cyl.top_radius = cell_size * 0.06
		cyl.bottom_radius = cell_size * 0.12
		tower.mesh = cyl
		var angle: float = i * TAU / 16.0
		var edge_dist: float = max(cell_cols, cell_rows) * cell_size * 0.45
		tower.position = Vector3(cos(angle) * edge_dist, cell_size * 0.3, sin(angle) * edge_dist)
		parent.add_child(tower)
	
	print("[ShipBuilder] LOD_Continent: grid %dx%d + 16 towers" % [cell_cols, cell_rows])
	_set_visibility_range(parent, 4.0, 40.0)
	return parent


# ===============================
# LOD 4: ГОРОД — ульи, солнечные панели, реки проводов
# ===============================
func build_lod_city() -> Node3D:
	var parent: Node3D = _get_or_create_lod("LOD_City")
	
	var half_w: float = cell_cols * cell_size * 0.5
	var half_h: float = cell_rows * cell_size * 0.5
	
	# === УЛЬИ — гексагональные кластеры ===
	var hive_positions = [
		Vector3(-half_w * 0.6, 0, -half_h * 0.5),
		Vector3(0, 0, -half_h * 0.6),
		Vector3(half_w * 0.5, 0, -half_h * 0.3),
		Vector3(-half_w * 0.3, 0, half_h * 0.4),
		Vector3(half_w * 0.4, 0, half_h * 0.5),
		Vector3(-half_w * 0.7, 0, half_h * 0.1),
	]
	
	for i in range(hive_positions.size()):
		var center: Vector3 = hive_positions[i]
		_build_hive_cluster(parent, center, 3 + randi() % 5)
	
	# === ПОЛЯ СОЛНЕЧНЫХ ПАНЕЛЕЙ (синие прямоугольники) ===
	var panel_areas = [
		Rect2(-half_w * 0.2, -half_h * 0.1, half_w * 0.4, half_h * 0.15),
		Rect2(-half_w * 0.5, half_h * 0.2, half_w * 0.3, half_h * 0.2),
		Rect2(half_w * 0.1, -half_h * 0.4, half_w * 0.2, half_h * 0.2),
	]
	
	for area in panel_areas:
		_build_solar_panels(parent, area, 12 + randi() % 10)
	
	# === РЕКИ ПРОВОДОВ (светящиеся линии) ===
	var wire_paths = [
		[Vector3(-half_w * 0.8, 0.03, -half_h * 0.7), Vector3(-half_w * 0.4, 0.03, 0), Vector3(-half_w * 0.1, 0.03, half_h * 0.5)],
		[Vector3(half_w * 0.7, 0.03, -half_h * 0.6), Vector3(half_w * 0.3, 0.03, -half_h * 0.2), Vector3(0, 0.03, half_h * 0.3)],
		[Vector3(0, 0.03, -half_h * 0.8), Vector3(half_w * 0.2, 0.03, -half_h * 0.1), Vector3(half_w * 0.6, 0.03, half_h * 0.6)],
		[Vector3(-half_w * 0.5, 0.03, half_h * 0.0), Vector3(-half_w * 0.1, 0.03, half_h * 0.4), Vector3(half_w * 0.5, 0.03, half_h * 0.7)],
	]
	
	for path in wire_paths:
		_build_wire_river(parent, path)
	
	# === ДОРОГИ (тёмные линии) ===
	for row in range(cell_rows):
		var road: MeshInstance3D = MeshInstance3D.new()
		road.name = "Road_H_%d" % row
		var road_box: BoxMesh = BoxMesh.new()
		road_box.size = Vector3(half_w * 2.0, 0.04, 0.8)
		road.mesh = road_box
		road.position = Vector3(0, 0.02, -half_h + row * cell_size)
		var road_mat: StandardMaterial3D = StandardMaterial3D.new()
		road_mat.albedo_color = Color(0.15, 0.15, 0.17)
		road_mat.metallic = 0.1
		road_mat.roughness = 0.9
		road.material_override = road_mat
		parent.add_child(road)
	
	for col in range(cell_cols):
		var road: MeshInstance3D = MeshInstance3D.new()
		road.name = "Road_V_%d" % col
		var road_box: BoxMesh = BoxMesh.new()
		road_box.size = Vector3(0.8, 0.04, half_h * 2.0)
		road.mesh = road_box
		road.position = Vector3(-half_w + col * cell_size, 0.02, 0)
		var road_mat: StandardMaterial3D = StandardMaterial3D.new()
		road_mat.albedo_color = Color(0.15, 0.15, 0.17)
		road_mat.metallic = 0.1
		road_mat.roughness = 0.9
		road.material_override = road_mat
		parent.add_child(road)
	
	print("[ShipBuilder] LOD_City: %d hives + %d solar panel areas + %d wire rivers + roads" % [
		hive_positions.size(), panel_areas.size(), wire_paths.size()])
	_set_visibility_range(parent, 0.5, 4.0)
	return parent


# ===============================
# LOD 5: УЛИЦА — NPC + детали
# ===============================
func build_lod_street() -> Node3D:
	var parent: Node3D = _get_or_create_lod("LOD_Street")
	
	var half_w: float = cell_cols * cell_size * 0.5
	var half_h: float = cell_rows * cell_size * 0.5
	
	# Человечки-NPC (капсулы)
	for i in range(25):
		var npc: Node3D = Node3D.new()
		npc.name = "NPC_%d" % i
		
		# Тело
		var body: MeshInstance3D = MeshInstance3D.new()
		body.name = "Body"
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.12
		cap.height = 1.0
		body.mesh = cap
		var body_mat: StandardMaterial3D = StandardMaterial3D.new()
		var npc_colors = [Color(0.8, 0.2, 0.2), Color(0.2, 0.6, 0.2), Color(0.2, 0.2, 0.8), Color(0.8, 0.8, 0.2), Color(0.6, 0.6, 0.6)]
		body_mat.albedo_color = npc_colors[randi() % npc_colors.size()]
		body.material_override = body_mat
		npc.add_child(body)
		
		# Голова
		var head: MeshInstance3D = MeshInstance3D.new()
		head.name = "Head"
		var head_sphere: SphereMesh = SphereMesh.new()
		head_sphere.radius = 0.15
		head_sphere.height = 0.3
		head.mesh = head_sphere
		head.position = Vector3(0, 0.65, 0)
		npc.add_child(head)
		
		npc.position = Vector3(randf_range(-half_w * 0.8, half_w * 0.8), 0.5, randf_range(-half_h * 0.8, half_h * 0.8))
		parent.add_child(npc)
	
	# Фонари
	for i in range(15):
		var lamp: Node3D = Node3D.new()
		lamp.name = "Lamp_%d" % i
		var pole: MeshInstance3D = MeshInstance3D.new()
		pole.name = "Pole"
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = 1.2
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		pole.mesh = cyl
		lamp.add_child(pole)
		
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 0.4
		light.omni_range = 2.5
		light.position = Vector3(0, 1.2, 0)
		lamp.add_child(light)
		
		lamp.position = Vector3(randf_range(-half_w * 0.8, half_w * 0.8), 0, randf_range(-half_h * 0.8, half_h * 0.8))
		parent.add_child(lamp)
	
	print("[ShipBuilder] LOD_Street: 25 NPCs + 15 lamps")
	_set_visibility_range(parent, 0.0, 0.5)
	return parent


# ===============================
# СУБ-СТРОИТЕЛИ: УЛЬИ, ПАНЕЛИ, ПРОВОДА
# ===============================

func _build_hive_cluster(parent: Node3D, center: Vector3, count: int) -> void:
	# Гексагональная сетка ячеек
	for i in range(count):
		var angle: float = i * TAU / count
		var dist: float = 1.5 + randf() * 3.0
		var pos: Vector3 = center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		
		var cell: MeshInstance3D = MeshInstance3D.new()
		cell.name = "HiveCell"
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = 0.3 + randf() * 0.5
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.65
		cyl.radial_segments = 6  # гексагон
		cell.mesh = cyl
		cell.position = pos + Vector3(0, cyl.height * 0.5, 0)
		
		var hive_mat: StandardMaterial3D = StandardMaterial3D.new()
		hive_mat.albedo_color = Color(0.7, 0.55, 0.2, 1.0)  # золотисто-медовый
		hive_mat.metallic = 0.3
		hive_mat.roughness = 0.6
		cell.material_override = hive_mat
		parent.add_child(cell)
	
	# Центральная башня улья
	var tower: MeshInstance3D = MeshInstance3D.new()
	tower.name = "HiveTower"
	var tower_cyl: CylinderMesh = CylinderMesh.new()
	tower_cyl.height = 2.0
	tower_cyl.top_radius = 0.3
	tower_cyl.bottom_radius = 0.8
	tower.mesh = tower_cyl
	tower.position = center + Vector3(0, 1.0, 0)
	var tower_mat: StandardMaterial3D = StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.8, 0.6, 0.15)
	tower_mat.metallic = 0.4
	tower_mat.roughness = 0.5
	tower.material_override = tower_mat
	parent.add_child(tower)


func _build_solar_panels(parent: Node3D, area: Rect2, count: int) -> void:
	for _i in range(count):
		var panel: MeshInstance3D = MeshInstance3D.new()
		panel.name = "SolarPanel"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(1.2, 0.04, 2.5)
		panel.mesh = box
		panel.position = Vector3(area.position.x + randf() * area.size.x, 0.05, area.position.y + randf() * area.size.y)
		panel.rotation_degrees = Vector3(-5 + randf() * 10, randf() * 10, 0)
		
		var panel_mat: StandardMaterial3D = StandardMaterial3D.new()
		panel_mat.albedo_color = Color(0.0, 0.15, 0.4)  # тёмно-синий
		panel_mat.metallic = 0.9
		panel_mat.roughness = 0.1
		panel_mat.emission_enabled = true
		panel_mat.emission = Color(0.0, 0.05, 0.15)
		panel_mat.emission_energy_multiplier = 0.3
		panel.material_override = panel_mat
		parent.add_child(panel)


func _build_wire_river(parent: Node3D, points: Array) -> void:
	# Строим ломаную линию из segment-боксов (приближение кривой)
	for i in range(points.size() - 1):
		var start: Vector3 = points[i]
		var end: Vector3 = points[i + 1]
		var mid: Vector3 = (start + end) * 0.5
		var dir: Vector3 = (end - start)
		var length: float = dir.length()
		
		var segment: MeshInstance3D = MeshInstance3D.new()
		segment.name = "WireSeg"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.4, 0.02, length)
		segment.mesh = box
		segment.position = mid
		segment.look_at(end, Vector3.UP)
		segment.rotate_object_local(Vector3.UP, TAU / 4.0)  # box alignment
		
		var wire_mat: StandardMaterial3D = StandardMaterial3D.new()
		wire_mat.albedo_color = Color(0.0, 0.4, 0.8)
		wire_mat.emission_enabled = true
		wire_mat.emission = Color(0.0, 0.3, 0.7)
		wire_mat.emission_energy_multiplier = 0.8
		segment.material_override = wire_mat
		parent.add_child(segment)
	
	# Узлы на точках (круглые распределители)
	for point in points:
		var node_mesh: MeshInstance3D = MeshInstance3D.new()
		node_mesh.name = "WireNode"
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		node_mesh.mesh = sphere
		node_mesh.position = point + Vector3(0, 0.03, 0)
		
		var node_mat: StandardMaterial3D = StandardMaterial3D.new()
		node_mat.albedo_color = Color(0.1, 0.6, 1.0)
		node_mat.emission_enabled = true
		node_mat.emission = Color(0.1, 0.5, 0.9)
		node_mat.emission_energy_multiplier = 1.0
		node_mesh.material_override = node_mat
		parent.add_child(node_mesh)


# ===============================
# HELPERS
# ===============================
func _get_or_create_lod(lod_name: String) -> Node3D:
	if not ship_root:
		push_error("[ShipBuilder] ship_root is null — cannot build LOD.")
		return Node3D.new()
	
	# Ищем или создаём LOD-узел
	for child in ship_root.get_children():
		if child.name == lod_name:
			for gc in child.get_children():
				gc.queue_free()
			return child
	
	var node: Node3D = Node3D.new()
	node.name = lod_name
	ship_root.add_child(node)
	return node


func _set_visibility_range(node: Node3D, begin: float, end: float) -> void:
	for child in _get_all_geometry(node):
		child.visibility_range_begin = begin
		child.visibility_range_end = end
		child.visibility_range_begin_margin = begin * 0.15
		child.visibility_range_end_margin = end * 0.15


func _get_all_geometry(node: Node) -> Array:
	var result: Array = []
	if node is GeometryInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_geometry(child))
	return result
