extends Node
## Ship Builder — создаёт 5 LOD-уровней корабля из геометрических заглушек.
## Когда пользователь добавит свои 3D-модели — просто заменит эти Node3D.

@export var ship_root: Node3D
@export var grid_cols: int = 8
@export var grid_rows: int = 6
@export var cell_size: float = 20.0      # метров (корабль огромный)
@export var ship_total_size: float = 200.0  # диаметр корабля


func build_all_lods() -> void:
	build_lod_cosmos()
	build_lod_orbit()
	build_lod_continent()
	build_lod_city()
	build_lod_street()


# ============================
# LOD 1: COSMOS — силуэт
# ============================
func build_lod_cosmos() -> Node3D:
	var parent: Node3D = _get_or_create_child(ship_root, "LOD_Cosmos")
	
	# Билборд-спрайт: квадрат, всегда лицом к камере
	var billboard: Sprite3D = Sprite3D.new()
	billboard.name = "ShipBillboard"
	billboard.pixel_size = 0.05
	billboard.modulate = Color(0.1, 0.15, 0.3, 0.8)  # тёмный силуэт
	billboard.scale = Vector3(ship_total_size * 0.6, ship_total_size * 0.6, 1)
	parent.add_child(billboard)
	
	# Огни двигателей
	for i in range(3):
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "EngineLight_%d" % i
		light.light_color = Color(0.3, 0.6, 1.0)
		light.light_energy = 2.0
		light.omni_range = ship_total_size * 0.5
		light.position = Vector3(
			(i - 1) * ship_total_size * 0.2,
			0,
			-ship_total_size * 0.5
		)
		parent.add_child(light)
	
	print("[ShipBuilder] LOD_Cosmos: billboard + engine lights")
	
	# Visibility
	_set_visibility_range(parent, 1000.0, 10000.0)
	
	return parent


# ============================
# LOD 2: ORBIT — low-poly
# ============================
func build_lod_orbit() -> Node3D:
	var parent: Node3D = _get_or_create_child(ship_root, "LOD_Orbit")
	
	# Низкополигональная сфера — форма корабля
	var sphere: MeshInstance3D = MeshInstance3D.new()
	sphere.name = "Ship_LowPoly"
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = ship_total_size * 0.5
	sphere_mesh.height = ship_total_size * 0.7
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 12
	sphere.mesh = sphere_mesh
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.35)
	mat.metallic = 0.9
	mat.roughness = 0.6
	sphere.material_override = mat
	parent.add_child(sphere)
	
	# Континенты = цветные пятна
	for i in range(4):
		var continent: MeshInstance3D = MeshInstance3D.new()
		continent.name = "Continent_%d" % i
		var cap_mesh: SphereMesh = SphereMesh.new()
		cap_mesh.radius = ship_total_size * 0.48
		cap_mesh.height = ship_total_size * 0.1
		cap_mesh.radial_segments = 24
		cap_mesh.rings = 4
		cap_mesh.is_hemisphere = true
		continent.mesh = cap_mesh
		continent.position = Vector3(
			randf_range(-ship_total_size * 0.3, ship_total_size * 0.3),
			ship_total_size * 0.33,
			randf_range(-ship_total_size * 0.3, ship_total_size * 0.3)
		)
		continent.rotation_degrees = Vector3(
			randf_range(-20, 20),
			0,
			randf_range(0, 360)
		)
		
		var cont_mat: StandardMaterial3D = StandardMaterial3D.new()
		var colors = [Color(0.1, 0.5, 0.1), Color(0.4, 0.3, 0.1), Color(0.1, 0.3, 0.5), Color(0.5, 0.5, 0.4)]
		cont_mat.albedo_color = colors[i]
		cont_mat.metallic = 0.1
		cont_mat.roughness = 0.8
		continent.material_override = cont_mat
		parent.add_child(continent)
	
	print("[ShipBuilder] LOD_Orbit: low-poly sphere + 4 continents")
	
	_set_visibility_range(parent, 100.0, 1000.0)
	
	return parent


# ============================
# LOD 3: CONTINENT — сетка отсеков
# ============================
func build_lod_continent() -> Node3D:
	var parent: Node3D = _get_or_create_child(ship_root, "LOD_Continent")
	
	# Платформа — плоская поверхность корабля
	var platform: MeshInstance3D = MeshInstance3D.new()
	platform.name = "Platform"
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(grid_cols * cell_size, grid_rows * cell_size)
	plane_mesh.subdivide_width = grid_cols * 2
	plane_mesh.subdivide_depth = grid_rows * 2
	platform.mesh = plane_mesh
	platform.rotation_degrees = Vector3(-90, 0, 0)
	
	var plat_mat: StandardMaterial3D = StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.15, 0.18, 0.25)
	plat_mat.metallic = 0.8
	plat_mat.roughness = 0.5
	platform.material_override = plat_mat
	parent.add_child(platform)
	
	# Сетка отсеков
	var grid_offset: Vector3 = Vector3(
		-(grid_cols - 1) * cell_size * 0.5,
		0.5,
		-(grid_rows - 1) * cell_size * 0.5
	)
	
	var cell_types = ["miner", "smelter", "reactor", "habitat", "turret", "storage", "drone_bay", "assembly"]
	var cell_colors = {
		"miner": Color(0.6, 0.4, 0.2),
		"smelter": Color(0.8, 0.4, 0.1),
		"reactor": Color(1.0, 0.6, 0.0),
		"habitat": Color(0.3, 0.6, 0.6),
		"turret": Color(0.9, 0.2, 0.2),
		"storage": Color(0.5, 0.5, 0.5),
		"drone_bay": Color(0.4, 0.4, 0.6),
		"assembly": Color(0.5, 0.5, 0.7)
	}
	
	for row in range(grid_rows):
		for col in range(grid_cols):
			var cell: MeshInstance3D = MeshInstance3D.new()
			cell.name = "Cell_%d_%d" % [col, row]
			
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(cell_size * 0.8, cell_size * 0.3, cell_size * 0.8)
			cell.mesh = box
			
			cell.position = grid_offset + Vector3(col * cell_size, 0, row * cell_size)
			
			# Случайный тип для демонстрации
			var cell_type: String = cell_types[(col + row * grid_cols) % cell_types.size()]
			var cell_mat: StandardMaterial3D = StandardMaterial3D.new()
			cell_mat.albedo_color = cell_colors.get(cell_type, Color.GRAY)
			cell_mat.metallic = 0.3 + randf() * 0.5
			cell_mat.roughness = 0.5 + randf() * 0.3
			cell.material_override = cell_mat
			
			# Метка типа (UI) — потом заменится на модель
			var label: Label3D = Label3D.new()
			label.name = "Label"
			label.text = cell_type
			label.font_size = 14
			label.modulate = Color.WHITE
			label.position = Vector3(0, cell_size * 0.2, 0)
			cell.add_child(label)
			
			parent.add_child(cell)
	
	# Башни по краям
	for i in range(8):
		var tower: MeshInstance3D = MeshInstance3D.new()
		tower.name = "Tower_%d" % i
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = cell_size * 0.5
		cyl.top_radius = cell_size * 0.1
		cyl.bottom_radius = cell_size * 0.15
		tower.mesh = cyl
		var angle: float = i * TAU / 8.0
		var edge_dist: float = max(grid_cols, grid_rows) * cell_size * 0.45
		tower.position = Vector3(cos(angle) * edge_dist, cell_size * 0.25, sin(angle) * edge_dist)
		parent.add_child(tower)
	
	print("[ShipBuilder] LOD_Continent: grid cells + towers")
	
	_set_visibility_range(parent, 10.0, 100.0)
	
	return parent


# ============================
# LOD 4: CITY — здания
# ============================
func build_lod_city() -> Node3D:
	var parent: Node3D = _get_or_create_child(ship_root, "LOD_City")
	
	# Платформа (та же, но с деталями)
	var grid_offset: Vector3 = Vector3(
		-(grid_cols - 1) * cell_size * 0.5,
		0,
		-(grid_rows - 1) * cell_size * 0.5
	)
	
	# Здания внутри ячеек
	for row in range(grid_rows):
		for col in range(grid_cols):
			var building_count: int = randi() % 3 + 1
			for b in range(building_count):
				var building: MeshInstance3D = MeshInstance3D.new()
				building.name = "Building_%d_%d_%d" % [col, row, b]
				
				var box: BoxMesh = BoxMesh.new()
				var w: float = cell_size * 0.1 + randf() * cell_size * 0.15
				var d: float = cell_size * 0.1 + randf() * cell_size * 0.15
				var h: float = cell_size * 0.05 + randf() * cell_size * 0.3
				box.size = Vector3(w, h, d)
				building.mesh = box
				
				building.position = grid_offset + Vector3(
					col * cell_size + randf_range(-cell_size * 0.3, cell_size * 0.3),
					h * 0.5,
					row * cell_size + randf_range(-cell_size * 0.3, cell_size * 0.3)
				)
				
				var bld_mat: StandardMaterial3D = StandardMaterial3D.new()
				var city_colors = [Color(0.6, 0.6, 0.7), Color(0.5, 0.5, 0.6), Color(0.7, 0.7, 0.8), Color(0.4, 0.5, 0.6)]
				bld_mat.albedo_color = city_colors[randi() % city_colors.size()]
				bld_mat.metallic = 0.4
				bld_mat.roughness = 0.5
				building.material_override = bld_mat
				
				parent.add_child(building)
	
	# Дороги между ячейками
	for row in range(grid_rows):
		var road: MeshInstance3D = MeshInstance3D.new()
		road.name = "Road_H_%d" % row
		var road_box: BoxMesh = BoxMesh.new()
		road_box.size = Vector3(grid_cols * cell_size, 0.05, cell_size * 0.15)
		road.mesh = road_box
		road.position = grid_offset + Vector3(0, 0.03, row * cell_size)
		
		var road_mat: StandardMaterial3D = StandardMaterial3D.new()
		road_mat.albedo_color = Color(0.2, 0.2, 0.22)
		road_mat.metallic = 0.2
		road_mat.roughness = 0.9
		road.material_override = road_mat
		parent.add_child(road)
	
	print("[ShipBuilder] LOD_City: buildings + roads")
	
	_set_visibility_range(parent, 1.0, 10.0)
	
	return parent


# ============================
# LOD 5: STREET — NPC + детали
# ============================
func build_lod_street() -> Node3D:
	var parent: Node3D = _get_or_create_child(ship_root, "LOD_Street")
	
	# Маленькие человечки-заглушки (капсулы)
	for i in range(20):
		var npc: CharacterBody3D = CharacterBody3D.new()
		npc.name = "NPC_%d" % i
		
		# Тело
		var body: MeshInstance3D = MeshInstance3D.new()
		body.name = "Body"
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.15
		cap.height = 1.2
		body.mesh = cap
		
		var body_mat: StandardMaterial3D = StandardMaterial3D.new()
		var npc_colors = [Color(0.8, 0.2, 0.2), Color(0.2, 0.6, 0.2), Color(0.2, 0.2, 0.8), Color(0.8, 0.8, 0.2)]
		body_mat.albedo_color = npc_colors[randi() % npc_colors.size()]
		body.material_override = body_mat
		npc.add_child(body)
		
		# Голова
		var head: MeshInstance3D = MeshInstance3D.new()
		head.name = "Head"
		var head_sphere: SphereMesh = SphereMesh.new()
		head_sphere.radius = 0.2
		head_sphere.height = 0.35
		head.mesh = head_sphere
		head.position = Vector3(0, 0.8, 0)
		npc.add_child(head)
		
		# Случайная позиция на платформе
		var grid_offset: Vector3 = Vector3(
			-(grid_cols - 1) * cell_size * 0.5,
			0,
			-(grid_rows - 1) * cell_size * 0.5
		)
		var rand_col: int = randi() % grid_cols
		var rand_row: int = randi() % grid_rows
		npc.position = grid_offset + Vector3(
			rand_col * cell_size + randf_range(-cell_size * 0.4, cell_size * 0.4),
			0.6,
			rand_row * cell_size + randf_range(-cell_size * 0.4, cell_size * 0.4)
		)
		
		parent.add_child(npc)
	
	# Фонари
	for i in range(12):
		var lamp: Node3D = Node3D.new()
		lamp.name = "Lamp_%d" % i
		
		var pole: MeshInstance3D = MeshInstance3D.new()
		pole.name = "Pole"
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = 1.5
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		pole.mesh = cyl
		lamp.add_child(pole)
		
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.9, 0.7)
		light.light_energy = 0.5
		light.omni_range = 3.0
		light.position = Vector3(0, 1.5, 0)
		lamp.add_child(light)
		
		var grid_offset: Vector3 = Vector3(
			-(grid_cols - 1) * cell_size * 0.5,
			0,
			-(grid_rows - 1) * cell_size * 0.5
		)
		lamp.position = grid_offset + Vector3(
			randf_range(-grid_cols * cell_size * 0.5, grid_cols * cell_size * 0.5),
			0,
			randf_range(-grid_rows * cell_size * 0.5, grid_rows * cell_size * 0.5)
		)
		
		parent.add_child(lamp)
	
	print("[ShipBuilder] LOD_Street: NPCs + lamps")
	
	_set_visibility_range(parent, 0.0, 1.0)
	
	return parent


# ============================
# HELPERS
# ============================
func _get_or_create_child(parent_node: Node3D, node_name: String) -> Node3D:
	if not parent_node:
		push_error("[ShipBuilder] parent_node is null — ship_root not set. Call ship_builder.ship_root = $World/Ship first.")
		return Node3D.new()
	for child in parent_node.get_children():
		if child.name == node_name:
			# Очистить перед пересборкой
			for gc in child.get_children():
				gc.queue_free()
			return child
	
	var node: Node3D = Node3D.new()
	node.name = node_name
	parent_node.add_child(node)
	return node


func _set_visibility_range(node: Node3D, begin: float, end: float) -> void:
	# Применяем VisibilityRange ко всем GeometryInstance3D внутри
	for child in _get_all_geometry(node):
		child.visibility_range_begin = begin
		child.visibility_range_end = end
		child.visibility_range_begin_margin = begin * 0.1
		child.visibility_range_end_margin = end * 0.1


func _get_all_geometry(node: Node) -> Array:
	var result: Array = []
	if node is GeometryInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_geometry(child))
	return result
