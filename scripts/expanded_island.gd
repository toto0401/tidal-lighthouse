extends Node3D

## Three authored garden islands, connected by wide, level wooden bridges.
## The flat physics deck is deliberate: visual details never become tiny stairs.
const Layout := preload("res://data/world_layout.gd")
const GROUND := Layout.GROUND_HEIGHT
## Keep the visual deck above overlapping grass (0.125 m) and sand (0.135 m).
## Sharing the main meadow's 0.12 m plane causes z-fighting as the camera moves.
const BRIDGE_SURFACE_HEIGHT := GROUND + 0.04
const COAST_MARGIN := 0.9
var game: Node3D
var materials: Dictionary = {}
var rng := RandomNumberGenerator.new()
var leaf_mesh: SphereMesh
var flower_mesh: SphereMesh
var rock_mesh: SphereMesh
var grass_mesh: ArrayMesh
var board_mesh: BoxMesh

func _ready() -> void:
	game = get_parent()
	rng.seed = 903176
	leaf_mesh = _sphere_mesh(1.0, 12, 6)
	flower_mesh = _sphere_mesh(1.0, 8, 4)
	rock_mesh = _sphere_mesh(1.0, 7, 3)
	grass_mesh = _grass_blade_mesh()
	board_mesh = BoxMesh.new()
	board_mesh.size = Vector3(1, 1, 1)
	for spec in Layout.REGIONS:
		_build_island(spec)
	for bridge in Layout.BRIDGES:
		_build_bridge(bridge)
	_build_shell_bay()
	_build_flower_picnic()
	_build_stargazer()
	_build_wayfinding()

func contains_walkable(point: Vector2) -> bool:
	if point.length() <= Layout.CORE_RADIUS:
		return true
	for region in Layout.REGIONS:
		if point.distance_to(region.center) <= float(region.radius) - COAST_MARGIN:
			return true
	for bridge in Layout.BRIDGES:
		var nearest := Geometry2D.get_closest_point_to_segment(point, bridge.from, bridge.to)
		if point.distance_to(nearest) <= float(bridge.width) * 0.5 - 0.55:
			return true
	return false

func _build_island(spec: Dictionary) -> void:
	var region := Node3D.new()
	region.name = "Region_" + str(spec.id)
	region.position = Vector3(spec.center.x, 0, spec.center.y)
	add_child(region)
	var radius: float = spec.radius
	var sandy := str(spec.id) == "moon_shell"
	var grass_color := Color("#98b695") if sandy else Color("#9ebdab") if str(spec.id) == "bloom_path" else Color("#94a9a4")
	# A single cylinder collider provides a continuous ground plane for every island.
	var body := StaticBody3D.new()
	body.name = "LevelIslandFloor"
	body.add_to_group("shore_floor")
	body.position.y = GROUND - 0.6
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 1.2
	collision.shape = cylinder
	body.add_child(collision)
	region.add_child(body)
	_coast_layer("Sandstone", region, radius, -0.7, 0.35, Color("#8eaaa8"), 0.06)
	_coast_layer("CreamCliff", region, radius * 1.005, -0.31, 0.18, Color("#c5c3aa"), 0.04)
	_coast_layer("PaleSand", region, radius, GROUND - 0.03, 0.0, Color("#e6d4b2"), 0.022)
	var meadow := _coast_layer("Meadow", region, radius * (0.65 if sandy else 0.88), GROUND + 0.005, 0.0, grass_color, 0.055)
	if ResourceLoader.exists("res://shaders/meadow.gdshader"):
		var meadow_material := ShaderMaterial.new()
		meadow_material.shader = load("res://shaders/meadow.gdshader")
		meadow_material.set_shader_parameter("base_color", grass_color)
		meadow.material_override = meadow_material
	if sandy:
		meadow.position = Vector3(1.8, 0, 1.8)
	var pebble_transforms: Array[Transform3D] = []
	var large_rocks: Array[Transform3D] = []
	var grass_transforms: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for i in range(120):
		var angle := rng.randf_range(0, TAU)
		var r := rng.randf_range(radius * 0.87, radius * 0.98)
		var p := Vector3(cos(angle) * r, GROUND + 0.04, sin(angle) * r)
		if _on_main_path(p + region.position, 2.8):
			continue
		var scale_value := rng.randf_range(0.06, 0.22)
		pebble_transforms.append(_transform(p, Vector3(scale_value * 1.5, scale_value * 0.55, scale_value), angle))
	for i in range(19):
		var angle := i * TAU / 19.0 + rng.randf_range(-0.08, 0.08)
		var p := Vector3(cos(angle) * (radius - 0.15), -0.04, sin(angle) * (radius - 0.15))
		if _on_main_path(p + region.position, 3.5):
			continue
		large_rocks.append(_transform(p, Vector3(rng.randf_range(0.5, 1.2), rng.randf_range(0.2, 0.52), rng.randf_range(0.5, 1.2)), angle))
	for i in range(430):
		var angle := rng.randf_range(0, TAU)
		var r := sqrt(rng.randf()) * radius * (0.59 if sandy else 0.83)
		var p := Vector3(cos(angle) * r, GROUND + 0.017, sin(angle) * r)
		if sandy:
			p += Vector3(1.8, 0, 1.8)
		if _on_main_path(p + region.position, 2.5) or _near_attraction(p + region.position, 5.0):
			continue
		var height := rng.randf_range(0.12, 0.33)
		grass_transforms.append(_transform(p, Vector3(height * 0.9, height, height), angle))
		if i % 3 == 0:
			flowers.append(_transform(p + Vector3(0, height * 0.85, 0), Vector3(0.11, 0.055, 0.11), angle))
	_batch("CoastalPebbles", rock_mesh, Color("#d4c7b5"), pebble_transforms, region)
	_batch("SeaSmoothRocks", rock_mesh, Color("#aac0bc"), large_rocks, region)
	_batch("MeadowGrasses", grass_mesh, Color("#80a58c"), grass_transforms, region)
	_batch("WildflowerCarpet", flower_mesh, Color("#f0d8cb") if sandy else Color("#e4cce5") if str(spec.id) == "bloom_path" else Color("#d1d9e9"), flowers, region)
	# Curated silhouettes sit along the perimeter, leaving the central promenade open.
	for i in range(9 if sandy else 15):
		var angle := i * TAU / (9.0 if sandy else 15.0) + 0.17
		var r := radius * rng.randf_range(0.59, 0.76)
		var world_p := region.position + Vector3(cos(angle) * r, GROUND, sin(angle) * r)
		if _on_main_path(world_p, 3.8) or _near_attraction(world_p, 5.0):
			continue
		_build_tree(world_p, rng.randf_range(0.78, 1.25), Color("#e7b9c9") if i % 4 == 0 else grass_color.lightened(0.05), i)

func _coast_layer(node_name: String, parent: Node3D, radius: float, height: float, thickness: float, color: Color, irregularity: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 100
	for i in range(count):
		var angle_a := TAU * i / count
		var angle_b := TAU * (i + 1) / count
		var radius_a := radius * (1.0 + sin(angle_a * 5.0 + 0.7) * irregularity + sin(angle_a * 9.0) * irregularity * 0.4)
		var radius_b := radius * (1.0 + sin(angle_b * 5.0 + 0.7) * irregularity + sin(angle_b * 9.0) * irregularity * 0.4)
		var a := Vector3(cos(angle_a) * radius_a, height, sin(angle_a) * radius_a)
		var b := Vector3(cos(angle_b) * radius_b, height, sin(angle_b) * radius_b)
		for vertex in [Vector3(0, height, 0), a, b]:
			surface.add_vertex(vertex)
		if thickness > 0:
			var low_a := a - Vector3(0, thickness, 0)
			var low_b := b - Vector3(0, thickness, 0)
			for vertex in [a, low_a, b, b, low_a, low_b]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = surface.commit()
	mesh.material_override = _mat(color)
	parent.add_child(mesh)
	return mesh

func _build_bridge(spec: Dictionary) -> void:
	var a: Vector2 = spec.from
	var b: Vector2 = spec.to
	var length := a.distance_to(b)
	var middle := (a + b) * 0.5
	var yaw := -atan2(b.y - a.y, b.x - a.x)
	var bridge := Node3D.new()
	bridge.name = str(spec.name)
	bridge.position = Vector3(middle.x, 0, middle.y)
	bridge.rotation.y = yaw
	add_child(bridge)
	var width: float = spec.width
	# One flat collision deck; separate boards and knots are purely visual.
	var body := StaticBody3D.new()
	body.name = "ContinuousBridgeDeck"
	body.add_to_group("shore_floor")
	body.position.y = GROUND - 0.16
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length + 0.4, 0.32, width)
	collision.shape = box
	body.add_child(collision)
	bridge.add_child(body)
	var boards_a: Array[Transform3D] = []
	var boards_b: Array[Transform3D] = []
	var nails: Array[Transform3D] = []
	var plank_count := ceili(length / 0.35)
	for i in range(plank_count + 1):
		var x := -length * 0.5 + i * length / plank_count
		var t := _transform(Vector3(x, BRIDGE_SURFACE_HEIGHT - 0.075, 0), Vector3(length / plank_count - 0.018, 0.15, width), 0)
		if i % 3 == 0:
			boards_b.append(t)
		else:
			boards_a.append(t)
		for side in [-1.0, 1.0]:
			nails.append(_transform(Vector3(x, BRIDGE_SURFACE_HEIGHT + 0.004, side * (width * 0.5 - 0.34)), Vector3(0.035, 0.009, 0.035), 0))
	_batch("HoneyWoodPlanks", board_mesh, Color("#c9ae8d"), boards_a, bridge)
	_batch("PaleWoodPlanks", board_mesh, Color("#dbc3a0"), boards_b, bridge)
	_batch("SmallBrassNails", flower_mesh, Color("#8c8b78"), nails, bridge)
	for side in [-1.0, 1.0]:
		for i in range(ceili(length / 2.1) + 1):
			var x := -length * 0.5 + i * length / ceili(length / 2.1)
			_cylinder("BridgePost", 0.075, 1.3, Vector3(x, 0.62, side * (width * 0.5 - 0.15)), Color("#a68f78"), bridge)
			_sphere("PostCap", Vector3(x, 1.3, side * (width * 0.5 - 0.15)), Vector3.ONE * 0.105, Color("#e1d0b0"), bridge)
			if i % 3 == 0:
				_lantern(Vector3(x, 1.61, side * (width * 0.5 - 0.15)), bridge, 0.7)
		for y in [0.62, 1.14]:
			_box("BridgeRailing", Vector3(length + 0.15, 0.075, 0.075), Vector3(0, y, side * (width * 0.5 - 0.15)), Color("#d9c5a7"), bridge)
		_box("Underbeam", Vector3(length, 0.18, 0.18), Vector3(0, -0.2, side * 1.55), Color("#9b9682"), bridge)

func _build_tree(position: Vector3, size: float, color: Color, seed_value: int) -> void:
	var tree := Node3D.new()
	tree.position = position
	tree.scale = Vector3.ONE * size
	add_child(tree)
	_cylinder("SoftBark", 0.17, 2.7, Vector3(0, 1.35, 0), Color("#a3917d"), tree)
	var branches: Array[Transform3D] = []
	for i in range(8):
		var angle := i * TAU / 8.0 + seed_value
		branches.append(_transform(Vector3(cos(angle) * 0.7, 2.7 + sin(i * 2.4) * 0.34, sin(angle) * 0.7), Vector3(0.93, 0.71, 0.93), angle))
	branches.append(_transform(Vector3(0, 3.25, 0), Vector3(1.1, 0.9, 1.1), 0))
	_batch("WatercolorCanopy", leaf_mesh, color, branches, tree)
	# One unobtrusive trunk collider, with a large open route around each tree.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.18
	cylinder.height = 2.5
	shape.shape = cylinder
	body.position.y = 1.25
	body.add_child(shape)
	tree.add_child(body)

func _build_shell_bay() -> void:
	var scene := Node3D.new()
	scene.name = "MoonShellBay"
	scene.position = Vector3(-35, GROUND, -7)
	add_child(scene)
	# Scallop sculpture: folded ribs catch the soft sun, with a pearl in the opening.
	var shell_surface := SurfaceTool.new()
	shell_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var angle_a := lerpf(-PI * 0.82, -PI * 0.18, i / 24.0)
		var angle_b := lerpf(-PI * 0.82, -PI * 0.18, (i + 1) / 24.0)
		var radius_a := 2.8 + (0.12 if i % 2 == 0 else 0.0)
		var radius_b := 2.8 + (0.12 if i % 2 != 0 else 0.0)
		for vertex in [Vector3(0, 0.05, 0), Vector3(cos(angle_b) * radius_b, -sin(angle_b) * radius_b * 0.76, -0.7), Vector3(cos(angle_a) * radius_a, -sin(angle_a) * radius_a * 0.76, -0.7)]:
			shell_surface.add_vertex(vertex)
	shell_surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.mesh = shell_surface.commit()
	var shell_mat := _mat(Color("#e8baba")).duplicate() as StandardMaterial3D
	shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = shell_mat
	shell.position = Vector3(-1.3, 0.13, -2.5)
	scene.add_child(shell)
	_sphere("Pearl", Vector3(-1.3, 0.52, -2.2), Vector3.ONE * 0.48, Color("#fff1d8"), scene)
	for i in range(16):
		var angle := i * TAU / 16.0
		var shell_piece := _sphere("BeachShell", Vector3(cos(angle) * 4.2, 0.06, sin(angle) * 3.4), Vector3(0.15, 0.075, 0.24), Color("#ebd6c8") if i % 2 == 0 else Color("#e9c2b3"), scene)
		shell_piece.rotation.y = angle
	# The seat's local +Z faces the open sea west of Moon Shell Bay.
	_bench(Vector3(-3.7, 0, 1.8), -PI / 2.0, scene)
	_lantern(Vector3(2.6, 0.5, 1.0), scene, 1.0)
	_build_scenic_marker(Layout.REGIONS[0], "浪把月光留在贝壳里。坐一会儿，听海替你翻页。")
	_path_between(Vector2(-23, -4), Vector2(-35, -7), Color("#eddbc0"), 1.15)

func _build_flower_picnic() -> void:
	var picnic := Node3D.new()
	picnic.name = "HydrangeaPicnic"
	picnic.position = Vector3(35, GROUND, 5)
	add_child(picnic)
	# A woven checked blanket and a proper low tea table sit in a blossom clearing.
	_box("PicnicBlanket", Vector3(5.0, 0.025, 4.0), Vector3(0, 0.016, 0), Color("#e5c1b3"), picnic)
	for i in range(9):
		_box("BlanketWeave", Vector3(0.07, 0.009, 3.95), Vector3(-2.2 + i * 0.55, 0.034, 0), Color("#f6e8d5"), picnic)
	for i in range(7):
		_box("BlanketWeave", Vector3(4.95, 0.009, 0.065), Vector3(0, 0.035, -1.65 + i * 0.55), Color("#f6e8d5"), picnic)
	var table := _cylinder("TeaTray", 0.9, 0.12, Vector3(0, 0.42, -0.6), Color("#c9ac8a"), picnic)
	table.set_meta("picnic_table", true)
	table.add_to_group("interactable")
	var table_body := StaticBody3D.new()
	table_body.name = "TeaTableBody"
	table_body.position = Vector3(0, 0.24, -0.6)
	var table_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.9
	cylinder.height = 0.48
	table_shape.shape = cylinder
	table_body.add_child(table_shape)
	picnic.add_child(table_body)
	for x in [-0.55, 0.55]:
		_box("TableLeg", Vector3(0.12, 0.36, 0.8), Vector3(x, 0.18, -0.6), Color("#bca385"), picnic)
	_cylinder("TeaPot", 0.16, 0.23, Vector3(-0.2, 0.59, -0.6), Color("#b8cdd4"), picnic)
	_sphere("TeapotLid", Vector3(-0.2, 0.73, -0.6), Vector3(0.12, 0.045, 0.12), Color("#d2e2dc"), picnic)
	for p in [Vector3(0.35, 0.54, -0.65), Vector3(-0.2, 0.54, -0.1)]:
		var cup := _cylinder("PorcelainCup", 0.085, 0.11, p, Color("#f4e6cf"), picnic)
		cup.set_meta("picnic_cup", true)
	for p in [Vector3(-1.4, 0.14, 0.7), Vector3(1.4, 0.14, 0.4)]:
		var cushion := _sphere("FloorCushion", p, Vector3(0.7, 0.18, 0.62), Color("#a4b9cf") if p.x > 0 else Color("#d7b2c5"), picnic)
		cushion.set_meta("picnic_seat", true)
		cushion.add_to_group("interactable")
	_box("PicnicBasket", Vector3(0.55, 0.42, 0.48), Vector3(1.4, 0.22, -1.1), Color("#cdb291"), picnic)
	for i in range(18):
		var angle := i * TAU / 18.0
		var pos := picnic.position + Vector3(cos(angle) * 6.0, 0, sin(angle) * 5.4)
		if _on_main_path(pos, 2.7):
			continue
		_hydrangea(pos, 0.7 + (i % 3) * 0.13, Color("#afb8df") if i % 3 == 0 else Color("#d7b4cf") if i % 3 == 1 else Color("#b4c8df"))
	# Two airy blossom arches mark the walk without narrowing the route.
	for x in [27.0, 30.8]:
		for z in [0.3, 5.7]:
			_cylinder("GardenArchPost", 0.085, 3.0, Vector3(x, 1.62, z), Color("#ddcdb4"), self)
		_box("FlowerArchLintel", Vector3(0.18, 0.16, 5.65), Vector3(x, 3.12, 3), Color("#ddd0bc"), self)
		for j in range(7):
			_sphere("ArchBloom", Vector3(x, 3.2 + sin(j) * 0.14, 0.35 + j * 0.9), Vector3(0.43, 0.3, 0.43), Color("#e1bfd0") if j % 2 == 0 else Color("#abbca4"), self)
	_build_scenic_marker(Layout.REGIONS[1], "一杯海盐茶，两朵绣球花。今天的空白，也可以慢慢过。")
	_path_between(Vector2(24, 3), Vector2(32, 3), Color("#dcd2b6"), 1.1)

func _build_stargazer() -> void:
	var gazebo := Node3D.new()
	gazebo.name = "StargazerPavilion"
	gazebo.position = Vector3(0, GROUND, -38)
	add_child(gazebo)
	# Flush octagonal deck and a light, open pergola keep the camera clear.
	_cylinder("ObservatoryDeck", 4.4, 0.035, Vector3(0, 0.014, 0), Color("#c6c5b4"), gazebo, 8)
	for i in range(8):
		var angle := TAU * i / 8.0 + PI / 8.0
		var p := Vector3(cos(angle) * 4.0, 1.55, sin(angle) * 4.0)
		_cylinder("GazeboColumn", 0.12, 3.1, p, Color("#dbe0d0"), gazebo)
		_lantern(Vector3(p.x, 2.55, p.z), gazebo, 0.85)
		var next_angle := angle + TAU / 8.0
		var next := Vector3(cos(next_angle) * 4.0, 3.16, sin(next_angle) * 4.0)
		_rod("PergolaEave", Vector3(p.x, 3.16, p.z), next, 0.09, Color("#cbd8cc"), gazebo)
		_rod("OpenRoofRib", Vector3(p.x, 3.16, p.z), Vector3(0, 4.6, 0), 0.065, Color("#c3d2cb"), gazebo)
	_sphere("PavilionStar", Vector3(0, 4.65, 0), Vector3(0.2, 0.32, 0.2), Color("#f0d9a3"), gazebo)
	for i in range(12):
		var angle := i * TAU / 12.0
		_sphere("StarMosaic", Vector3(cos(angle) * 2.9, 0.041, sin(angle) * 2.9), Vector3(0.09, 0.017, 0.09), Color("#e7ddb1"), gazebo)
	# A brass telescope with a sturdy three-legged base faces the far ocean.
	for i in range(3):
		var angle := i * TAU / 3.0
		_rod("TelescopeTripod", Vector3(1.2 + cos(angle) * 0.63, 0.08, -1.2 + sin(angle) * 0.63), Vector3(1.2, 1.25, -1.2), 0.052, Color("#a6957e"), gazebo)
	_rod("TelescopeBarrel", Vector3(1.2, 1.3, -0.8), Vector3(1.2, 1.85, -2.2), 0.17, Color("#cfbd8e"), gazebo)
	_sphere("TelescopeLens", Vector3(1.2, 1.87, -2.22), Vector3(0.15, 0.15, 0.05), Color("#8daab3"), gazebo)
	_bench(Vector3(-2.2, 0, -1.9), PI * 0.35, gazebo)
	for i in range(16):
		var angle := i * TAU / 16.0
		var p := Vector3(cos(angle) * 8.2, GROUND, -36 + sin(angle) * 8.2)
		if _on_main_path(p, 3.1):
			continue
		_hydrangea(p, 0.63, Color("#b4bdd9") if i % 2 == 0 else Color("#c4c5df"))
	_build_scenic_marker(Layout.REGIONS[2], "把烦恼交给晚风。按 N 等夜色降临，海与星光会一起亮起。")
	_path_between(Vector2(0, -28), Vector2(0, -34), Color("#d8d5c3"), 1.2)

func _build_wayfinding() -> void:
	for spec in Layout.REGIONS:
		var p: Vector3 = spec.scenic
		var label := Label3D.new()
		label.name = "RegionTitle"
		label.text = str(spec.name)
		label.font = game.chinese_font
		label.font_size = 40
		label.pixel_size = 0.016
		label.position = p + Vector3(0, 4.6, 0)
		label.modulate = Color("#fff3dd")
		label.outline_modulate = Color(0.18, 0.28, 0.31, 0.7)
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	for spec in Layout.BRIDGES:
		var point: Vector2 = spec.from
		var direction: Vector2 = (spec.to - spec.from).normalized()
		var side := Vector2(-direction.y, direction.x)
		var p := Vector3(point.x + side.x * 2.8, GROUND, point.y + side.y * 2.8)
		_cylinder("SignPost", 0.075, 1.6, p + Vector3(0, 0.8, 0), Color("#ad977c"), self)
		var sign := _box("PaintedSign", Vector3(1.6, 0.48, 0.12), p + Vector3(0, 1.4, 0), Color("#e3d7b9"), self)
		sign.rotation.y = -atan2(direction.y, direction.x)
		var label := Label3D.new()
		label.text = str(spec.name).replace("木桥", "").replace("长桥", "") + "  →"
		label.font = game.chinese_font
		label.font_size = 28
		label.pixel_size = 0.009
		label.modulate = Color("#566b70")
		label.outline_size = 0
		label.position = p + Vector3(0, 2.02, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

func _build_scenic_marker(spec: Dictionary, hint: String) -> void:
	var marker := Node3D.new()
	marker.name = "Scenic_" + str(spec.id)
	marker.position = spec.scenic
	marker.set_meta("scenic_id", str(spec.id))
	marker.set_meta("scenic_name", str(spec.name))
	marker.set_meta("scenic_hint", hint)
	marker.add_to_group("interactable")
	add_child(marker)
	_cylinder("DiscoveryStone", 0.34, 0.1, Vector3(0, -0.015, 0), Color("#ded4b5"), marker)
	_sphere("LittleKeepsake", Vector3(0, 0.22, 0), Vector3(0.14, 0.2, 0.14), Color("#ffe6ad"), marker)

func _path_between(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var steps := ceili(from.distance_to(to) / 0.7)
	var tiles: Array[Transform3D] = []
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / steps)
		tiles.append(_transform(Vector3(p.x, GROUND + 0.006, p.y), Vector3(width, 0.027, 0.6), rng.randf_range(-0.2, 0.2)))
	_batch("SoftGardenPath", rock_mesh, color, tiles, self)

func _hydrangea(position: Vector3, size: float, color: Color) -> void:
	var leaves: Array[Transform3D] = []
	var blooms: Array[Transform3D] = []
	for i in range(9):
		var angle := i * TAU / 9.0
		leaves.append(_transform(position + Vector3(cos(angle) * size * 0.6, size * 0.33, sin(angle) * size * 0.6), Vector3(size * 0.48, size * 0.3, size * 0.48), angle))
	for i in range(21):
		var angle := i * 2.399963
		var r := sqrt(float(i) / 21.0) * size * 0.8
		blooms.append(_transform(position + Vector3(cos(angle) * r, size * (0.66 + sin(i * 2.3) * 0.2), sin(angle) * r), Vector3.ONE * size * 0.23, angle))
	_batch("HydrangeaLeaves", leaf_mesh, Color("#83aa98"), leaves, self)
	_batch("HydrangeaPetals", flower_mesh, color, blooms, self)

func _bench(position: Vector3, angle: float, parent: Node3D) -> void:
	var bench := Node3D.new()
	bench.position = position
	bench.rotation.y = angle
	parent.add_child(bench)
	for z in [-0.23, 0.0, 0.23]:
		_box("BenchSeatSlat", Vector3(2.2, 0.11, 0.19), Vector3(0, 0.54, z), Color("#ceb697"), bench)
	for y in [0.95, 1.22]:
		_box("BenchBackSlat", Vector3(2.2, 0.2, 0.09), Vector3(0, y, -0.34), Color("#d9c3a7"), bench)
	for x in [-0.85, 0.85]:
		_box("BenchLeg", Vector3(0.13, 1.22, 0.13), Vector3(x, 0.65, -0.34), Color("#9caa9e"), bench)
		_box("BenchLeg", Vector3(0.13, 0.55, 0.13), Vector3(x, 0.28, 0.25), Color("#9caa9e"), bench)

func _lantern(position: Vector3, parent: Node3D, size: float) -> void:
	var frame := Node3D.new()
	frame.position = position
	frame.scale = Vector3.ONE * size
	parent.add_child(frame)
	_cylinder("LanternBase", 0.16, 0.055, Vector3(0, -0.18, 0), Color("#83968f"), frame, 6)
	_cylinder("LanternTop", 0.2, 0.07, Vector3(0, 0.21, 0), Color("#9cad9c"), frame, 6)
	var light_core := _sphere("WarmLantern", Vector3.ZERO, Vector3(0.13, 0.18, 0.13), Color("#ffdaa2"), frame)
	var glow := _mat(Color("#ffdaa2")).duplicate() as StandardMaterial3D
	glow.emission_enabled = true
	glow.emission = Color("#ffe1ad")
	glow.emission_energy_multiplier = 1.3
	light_core.material_override = glow
	for x in [-0.13, 0.13]:
		_box("LanternEdge", Vector3(0.025, 0.4, 0.025), Vector3(x, 0, 0), Color("#91a395"), frame)

func _on_main_path(position: Vector3, width: float) -> bool:
	var point := Vector2(position.x, position.z)
	for bridge in Layout.BRIDGES:
		var near := Geometry2D.get_closest_point_to_segment(point, bridge.from, bridge.to)
		if point.distance_to(near) < width:
			return true
	for segment in [[Vector2(-23, -4), Vector2(-35, -7)], [Vector2(24, 3), Vector2(35, 5)], [Vector2(0, -28), Vector2(0, -38)]]:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1])) < width:
			return true
	return false

func _near_attraction(position: Vector3, radius: float) -> bool:
	for region in Layout.REGIONS:
		var point: Vector3 = region.scenic
		if Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z)) < radius:
			return true
	return false

func _transform(position: Vector3, size: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(size), position)

func _batch(node_name: String, mesh: Mesh, color: Color, transforms: Array[Transform3D], parent: Node3D) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = _mat(color)
	parent.add_child(instance)

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	materials[key] = material
	return material

func _sphere_mesh(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh

func _sphere(node_name: String, position: Vector3, size: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = leaf_mesh
	instance.position = position
	instance.scale = size
	instance.material_override = _mat(color)
	parent.add_child(instance)
	return instance

func _box(node_name: String, size: Vector3, position: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = board_mesh
	instance.scale = size
	instance.position = position
	instance.material_override = _mat(color)
	parent.add_child(instance)
	return instance

func _cylinder(node_name: String, radius: float, height: float, position: Vector3, color: Color, parent: Node3D, segments := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _mat(color)
	parent.add_child(instance)
	return instance

func _rod(node_name: String, from: Vector3, to: Vector3, radius: float, color: Color, parent: Node3D) -> void:
	var mesh := _cylinder(node_name, radius, from.distance_to(to), (from + to) * 0.5, color, parent)
	mesh.quaternion = Quaternion(Vector3.UP, (to - from).normalized())

func _grass_blade_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI * 0.5, PI * 0.25]:
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.13
		var tip := Vector3(cos(angle) * 0.14, 1.0, sin(angle) * 0.14)
		for vertex in [-side, side, tip, side, -side, tip]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
