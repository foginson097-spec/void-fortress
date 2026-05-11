extends Node
## Ship Builder v3 — КУБ-КОРАБЛЬ. 6 граней = 6 континентов.
## Каждая грань имеет свою ориентацию в пространстве и свой LOD-контент.

@export var ship_root: Node3D
@export var cube_size: float = 400.0           # сторона куба
@export var cell_cols: int = 8
@export var cell_rows: int = 6
@export var cell_size: float = 30.0            # размер ячейки на грани

# Half-size for convenience
var _half: float:
	get: return cube_size * 0.5

# Face definitions: name, normal (outward), continent color, continent name
const FACES = [
	{"name": "Front", "normal": Vector3(0, 0, 1),  "color": Color(0.15, 0.35, 0.15), "label": "Зелёный континент"},
	{"name": "Back",  "normal": Vector3(0, 0, -1), "color": Color(0.30, 0.25, 0.12), "label": "Коричневый континент"},
	{"name": "Right", "normal": Vector3(1, 0, 0),  "color": Color(0.12, 0.25, 0.40), "label": "Синий континент"},
	{"name": "Left",  "normal": Vector3(-1, 0, 0), "color": Color(0.35, 0.30, 0.20), "label": "Бронзовый континент"},
	{"name": "Top",   "normal": Vector3(0, 1, 0),  "color": Color(0.20, 0.45, 0.20), "label": "Лесной континент"},
	{"name": "Bottom","normal": Vector3(0, -1, 0), "color": Color(0.25, 0.15, 0.35), "label": "Фиолетовый континент"},
]

# Engine positions (corners of the cube for visual effect)
const ENGINE_CORNERS = [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1),
	Vector3(-1, -1, 1),  Vector3(1, -1, 1),  Vector3(-1, 1, 1),  Vector3(1, 1, 1),
]


func build_all_lods() -> void:
	build_lod_cosmos()
	build_lod_orbit()
	_build_all_face_lods()


func build_lod_cosmos() -> Node3D:
	## Far view: dark cube silhouette with engine lights + drone lights on surface.
	var parent: Node3D = _get_or_create_lod("LOD_Cosmos")
	
	# Dark cube mesh
	var cube_mesh: MeshInstance3D = MeshInstance3D.new()
	cube_mesh.name = "CubeSilhouette"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(cube_size, cube_size, cube_size)
	cube_mesh.mesh = box
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.10, 1.0)
	mat.metallic = 0.3
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.02, 0.04)
	mat.emission_energy_multiplier = 0.2
	cube_mesh.material_override = mat
	parent.add_child(cube_mesh)
	
	# Drone lights on cube surface
	var drone_lights: Node3D = Node3D.new()
	drone_lights.name = "DroneLights"
	parent.add_child(drone_lights)
	
	for i in range(50):
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "DroneLight_%d" % i
		light.light_color = Color(0.0, 0.6, 0.9)
		light.light_energy = 0.3 + randf() * 0.5
		light.omni_range = cube_size * 0.06
		
		# Random position on cube surface
		var face_idx: int = randi() % 6
		var normal: Vector3 = FACES[face_idx]["normal"]
		# U, V are perpendiculars to normal
		var u: Vector3
		var v: Vector3
		_perpendiculars(normal, u, v)
		light.position = normal * _half + u * randf_range(-_half, _half) + v * randf_range(-_half, _half)
		
		light.set_meta("speed_u", randf_range(-8, 8))
		light.set_meta("speed_v", randf_range(-8, 8))
		light.set_meta("face_normal", normal)
		light.set_meta("u_axis", u)
		light.set_meta("v_axis", v)
		drone_lights.add_child(light)
	
	# Engine lights at corners
	for i in range(8):
		var corner: Vector3 = ENGINE_CORNERS[i] * _half
		var engine: OmniLight3D = OmniLight3D.new()
		engine.name = "Engine_%d" % i
		engine.light_color = Color(0.9, 0.3, 0.1)
		engine.light_energy = 2.5
		engine.omni_range = cube_size * 0.12
		engine.position = corner
		parent.add_child(engine)
	
	print("[ShipBuilder] LOD_Cosmos: dark cube + 50 drone lights + 8 engines")
	_set_visibility_range(parent, 500.0, 10000.0)
	return parent


func build_lod_orbit() -> Node3D:
	## Mid view: cube with colored faces (continents visible).
	var parent: Node3D = _get_or_create_lod("LOD_Orbit")
	
	# Cube with per-face material (uses 6 materials via surface override)
	# Simple approach: create 6 quads, one per face
	for face in FACES:
		var face_quad: MeshInstance3D = MeshInstance3D.new()
		face_quad.name = "Face_%s" % face["name"]
		
		# Create a plane mesh and position it on the cube face
		var plane_mesh: PlaneMesh = PlaneMesh.new()
		plane_mesh.size = Vector2(cube_size, cube_size)
		plane_mesh.orientation = PlaneMesh.FACE_Y  # face-up by default
		face_quad.mesh = plane_mesh
		
		# Transform to position on cube face
		face_quad.position = face["normal"] * _half
		_align_to_normal(face_quad, face["normal"])
		
		var face_mat: StandardMaterial3D = StandardMaterial3D.new()
		face_mat.albedo_color = face["color"]
		face_mat.metallic = 0.1
		face_mat.roughness = 0.7
		face_quad.material_override = face_mat
		parent.add_child(face_quad)
		
		# Small label
		var label_3d: Label3D = Label3D.new()
		label_3d.text = face["label"]
		label_3d.font_size = 24
		label_3d.position = face["normal"] * (_half + 2.0)
		_align_to_normal(label_3d, face["normal"])
		parent.add_child(label_3d)
	
	print("[ShipBuilder] LOD_Orbit: 6 colored faces")
	_set_visibility_range(parent, 80.0, 500.0)
	return parent


func _build_all_face_lods() -> void:
	## Build continent/city/street for each face.
	for face_idx in range(FACES.size()):
		_build_face_continent(face_idx)
		_build_face_city(face_idx)
		_build_face_street(face_idx)


# ===============================
# FACE LOD: CONTINENT (grid cells)
# ===============================
func _build_face_continent(face_idx: int) -> Node3D:
	var face: Dictionary = FACES[face_idx]
	var lod_name: String = "LOD_Continent_%s" % face["name"]
	var parent: Node3D = _get_or_create_child_of_ship(lod_name)
	
	# Position face node
	parent.position = face["normal"] * _half
	_align_to_normal(parent, face["normal"])
	
	# Flat surface platform
	var platform: MeshInstance3D = MeshInstance3D.new()
	platform.name = "Platform"
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(cell_cols * cell_size, cell_rows * cell_size)
	plane_mesh.subdivide_width = cell_cols * 4
	plane_mesh.subdivide_depth = cell_rows * 4
	platform.mesh = plane_mesh
	platform.rotation_degrees = Vector3(-90, 0, 0)  # face up in local space
	
	var plat_mat: StandardMaterial3D = StandardMaterial3D.new()
	plat_mat.albedo_color = face["color"].darkened(0.3)
	plat_mat.metallic = 0.5
	plat_mat.roughness = 0.5
	platform.material_override = plat_mat
	parent.add_child(platform)
	
	# Grid cells
	var grid_offset: Vector3 = Vector3(
		-(cell_cols - 1) * cell_size * 0.5,
		0.5,
		-(cell_rows - 1) * cell_size * 0.5
	)
	
	var cell_types = ["miner", "smelter", "reactor", "habitat", "turret", "storage", "drone_bay", "assembly",
		"gas_collector", "fab_plant", "refinery", "biolab"]
	var cell_colors = {
		"miner": Color(0.6, 0.4, 0.2), "gas_collector": Color(0.4, 0.6, 0.9),
		"smelter": Color(0.8, 0.4, 0.1), "fab_plant": Color(0.4, 0.4, 0.6),
		"refinery": Color(0.6, 0.5, 0.2), "reactor": Color(1.0, 0.6, 0.0),
		"habitat": Color(0.3, 0.7, 0.7), "turret": Color(0.9, 0.2, 0.2),
		"storage": Color(0.5, 0.5, 0.5), "drone_bay": Color(0.5, 0.4, 0.7),
		"assembly": Color(0.5, 0.5, 0.8), "biolab": Color(0.3, 0.8, 0.4)
	}
	
	for row in range(cell_rows):
		for col in range(cell_cols):
			var cell: MeshInstance3D = MeshInstance3D.new()
			cell.name = "Cell_%d_%d" % [col, row]
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(cell_size * 0.7, cell_size * 0.2, cell_size * 0.7)
			cell.mesh = box
			cell.position = grid_offset + Vector3(col * cell_size, 0, row * cell_size)
			
			var cell_type: String = cell_types[(col + row * cell_cols + face_idx * 3) % cell_types.size()]
			var cell_mat: StandardMaterial3D = StandardMaterial3D.new()
			cell_mat.albedo_color = cell_colors.get(cell_type, Color.GRAY)
			cell_mat.metallic = 0.3
			cell_mat.roughness = 0.5
			cell.material_override = cell_mat
			
			var label: Label3D = Label3D.new()
			label.text = cell_type
			label.font_size = 10
			label.position = Vector3(0, cell_size * 0.15, 0)
			cell.add_child(label)
			
			parent.add_child(cell)
	
	print("[ShipBuilder] LOD_Continent_%s: %dx%d grid" % [face["name"], cell_cols, cell_rows])
	_set_visibility_range(parent, 8.0, 80.0)
	return parent


# ===============================
# FACE LOD: CITY (hives + solar panels + wire rivers)
# ===============================
func _build_face_city(face_idx: int) -> Node3D:
	var face: Dictionary = FACES[face_idx]
	var lod_name: String = "LOD_City_%s" % face["name"]
	var parent: Node3D = _get_or_create_child_of_ship(lod_name)
	
	parent.position = face["normal"] * _half
	_align_to_normal(parent, face["normal"])
	
	var half_w: float = cell_cols * cell_size * 0.5
	var half_h: float = cell_rows * cell_size * 0.5
	
	# Hive clusters (3-4 per face)
	for i in range(3 + randi() % 2):
		var center: Vector3 = Vector3(
			randf_range(-half_w * 0.6, half_w * 0.6),
			0,
			randf_range(-half_h * 0.6, half_h * 0.6)
		)
		_build_hive_cluster(parent, center, 3 + randi() % 4)
	
	# Solar panels (1-2 areas per face)
	var panel_count: int = 1 + randi() % 2
	for _pn in range(panel_count):
		var area: Rect2 = Rect2(
			randf_range(-half_w * 0.7, half_w * 0.3),
			randf_range(-half_h * 0.7, half_h * 0.3),
			half_w * 0.3,
			half_h * 0.2
		)
		_build_solar_panels(parent, area, 8 + randi() % 8)
	
	# Wire rivers (2 per face)
	var wire_count: int = 2
	for _wi in range(wire_count):
		var path: Array = [
			Vector3(randf_range(-half_w * 0.7, half_w * 0.7), 0.02, randf_range(-half_h * 0.7, half_h * 0.7)),
			Vector3(randf_range(-half_w * 0.5, half_w * 0.5), 0.02, randf_range(-half_h * 0.5, half_h * 0.5)),
			Vector3(randf_range(-half_w * 0.6, half_w * 0.6), 0.02, randf_range(-half_h * 0.6, half_h * 0.6)),
		]
		_build_wire_river(parent, path)
	
	# Roads
	for row in range(cell_rows):
		var road: MeshInstance3D = MeshInstance3D.new()
		road.name = "Road_H_%d" % row
		var road_box: BoxMesh = BoxMesh.new()
		road_box.size = Vector3(half_w * 2.0, 0.03, 0.5)
		road.mesh = road_box
		road.position = Vector3(0, 0.015, -half_h + row * cell_size)
		var road_mat: StandardMaterial3D = StandardMaterial3D.new()
		road_mat.albedo_color = Color(0.12, 0.12, 0.14)
		road.material_override = road_mat
		parent.add_child(road)
	
	print("[ShipBuilder] LOD_City_%s" % face["name"])
	_set_visibility_range(parent, 1.0, 8.0)
	return parent


# ===============================
# FACE LOD: STREET (NPC + lamps)
# ===============================
func _build_face_street(face_idx: int) -> Node3D:
	var face: Dictionary = FACES[face_idx]
	var lod_name: String = "LOD_Street_%s" % face["name"]
	var parent: Node3D = _get_or_create_child_of_ship(lod_name)
	
	parent.position = face["normal"] * _half
	_align_to_normal(parent, face["normal"])
	
	var half_w: float = cell_cols * cell_size * 0.5
	var half_h: float = cell_rows * cell_size * 0.5
	
	# NPCs
	for i in range(8):
		var npc: Node3D = Node3D.new()
		npc.name = "NPC_%d" % i
		var body: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.1
		cap.height = 0.8
		body.mesh = cap
		var body_mat: StandardMaterial3D = StandardMaterial3D.new()
		var npc_colors = [Color(0.8, 0.2, 0.2), Color(0.2, 0.6, 0.2), Color(0.2, 0.2, 0.8), Color(0.8, 0.8, 0.2)]
		body_mat.albedo_color = npc_colors[randi() % npc_colors.size()]
		body.material_override = body_mat
		npc.add_child(body)
		var head: MeshInstance3D = MeshInstance3D.new()
		var head_sphere: SphereMesh = SphereMesh.new()
		head_sphere.radius = 0.12
		head_sphere.height = 0.25
		head.mesh = head_sphere
		head.position = Vector3(0, 0.55, 0)
		npc.add_child(head)
		npc.position = Vector3(randf_range(-half_w * 0.7, half_w * 0.7), 0.4, randf_range(-half_h * 0.7, half_h * 0.7))
		parent.add_child(npc)
	
	# Lamps
	for i in range(5):
		var lamp: Node3D = Node3D.new()
		lamp.name = "Lamp_%d" % i
		var pole: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = 1.0
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		pole.mesh = cyl
		lamp.add_child(pole)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 0.3
		light.omni_range = 2.0
		light.position = Vector3(0, 1.0, 0)
		lamp.add_child(light)
		lamp.position = Vector3(randf_range(-half_w * 0.7, half_w * 0.7), 0, randf_range(-half_h * 0.7, half_h * 0.7))
		parent.add_child(lamp)
	
	print("[ShipBuilder] LOD_Street_%s: 8 NPCs + 5 lamps" % face["name"])
	_set_visibility_range(parent, 0.0, 1.0)
	return parent


# ===============================
# SUB-BUILDERS
# ===============================

func _build_hive_cluster(parent: Node3D, center: Vector3, count: int) -> void:
	for i in range(count):
		var angle: float = i * TAU / count
		var dist: float = 1.0 + randf() * 2.0
		var pos: Vector3 = center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var cell: MeshInstance3D = MeshInstance3D.new()
		cell.name = "HiveCell"
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = 0.25 + randf() * 0.3
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.5
		cyl.radial_segments = 6
		cell.mesh = cyl
		cell.position = pos + Vector3(0, cyl.height * 0.5, 0)
		var hive_mat: StandardMaterial3D = StandardMaterial3D.new()
		hive_mat.albedo_color = Color(0.7, 0.55, 0.2)
		hive_mat.metallic = 0.3
		hive_mat.roughness = 0.6
		cell.material_override = hive_mat
		parent.add_child(cell)


func _build_solar_panels(parent: Node3D, area: Rect2, count: int) -> void:
	for _i in range(count):
		var panel: MeshInstance3D = MeshInstance3D.new()
		panel.name = "SolarPanel"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(1.0, 0.03, 2.0)
		panel.mesh = box
		panel.position = Vector3(area.position.x + randf() * area.size.x, 0.03, area.position.y + randf() * area.size.y)
		var panel_mat: StandardMaterial3D = StandardMaterial3D.new()
		panel_mat.albedo_color = Color(0.0, 0.1, 0.35)
		panel_mat.metallic = 0.9
		panel_mat.roughness = 0.1
		panel_mat.emission_enabled = true
		panel_mat.emission = Color(0.0, 0.04, 0.12)
		panel_mat.emission_energy_multiplier = 0.3
		panel.material_override = panel_mat
		parent.add_child(panel)


func _build_wire_river(parent: Node3D, points: Array) -> void:
	for i in range(points.size() - 1):
		var start: Vector3 = points[i]
		var end: Vector3 = points[i + 1]
		var mid: Vector3 = (start + end) * 0.5
		var length: float = (end - start).length()
		
		var segment: MeshInstance3D = MeshInstance3D.new()
		segment.name = "WireSeg"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.3, 0.015, length)
		segment.mesh = box
		segment.position = mid
		parent.add_child(segment)
		segment.look_at(end, Vector3.UP)
		segment.rotate_object_local(Vector3.UP, TAU / 4.0)
		
		var wire_mat: StandardMaterial3D = StandardMaterial3D.new()
		wire_mat.albedo_color = Color(0.0, 0.35, 0.7)
		wire_mat.emission_enabled = true
		wire_mat.emission = Color(0.0, 0.25, 0.6)
		wire_mat.emission_energy_multiplier = 0.8
		segment.material_override = wire_mat


# ===============================
# TRANSFORM HELPERS
# ===============================

func _align_to_normal(node: Node3D, normal: Vector3) -> void:
	## Rotate node so its local Y axis aligns with the given normal.
	## Local XY plane faces outward from cube.
	var up: Vector3 = normal.normalized()
	var right: Vector3
	if abs(up.x) < 0.99:
		right = Vector3(1, 0, 0).cross(up).normalized()
	else:
		right = Vector3(0, 1, 0).cross(up).normalized()
	var forward: Vector3 = up.cross(right)
	node.transform.basis = Basis(right, up, forward)


func _perpendiculars(normal: Vector3, out_u: Vector3, out_v: Vector3) -> void:
	## Compute two perpendicular vectors to the given normal.
	var n: Vector3 = normal.normalized()
	if abs(n.x) < 0.99:
		out_u = Vector3(1, 0, 0).cross(n).normalized()
	else:
		out_u = Vector3(0, 1, 0).cross(n).normalized()
	out_v = n.cross(out_u)


func _perpendiculars2(normal: Vector3) -> Array:
	## Same as above but returns array [u, v].
	var n: Vector3 = normal.normalized()
	var u: Vector3
	if abs(n.x) < 0.99:
		u = Vector3(1, 0, 0).cross(n).normalized()
	else:
		u = Vector3(0, 1, 0).cross(n).normalized()
	var v: Vector3 = n.cross(u)
	return [u, v]


# ===============================
# NODE HELPERS
# ===============================

func _get_or_create_lod(lod_name: String) -> Node3D:
	if not ship_root:
		push_error("[ShipBuilder] ship_root is null")
		return Node3D.new()
	for child in ship_root.get_children():
		if child.name == lod_name:
			for gc in child.get_children():
				gc.queue_free()
			return child
	var node: Node3D = Node3D.new()
	node.name = lod_name
	ship_root.add_child(node)
	return node


func _get_or_create_child_of_ship(child_name: String) -> Node3D:
	## Create/reuse a node under ship_root (not under a LOD parent).
	if not ship_root:
		push_error("[ShipBuilder] ship_root is null")
		return Node3D.new()
	for child in ship_root.get_children():
		if child.name == child_name:
			for gc in child.get_children():
				gc.queue_free()
			return child
	var node: Node3D = Node3D.new()
	node.name = child_name
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
