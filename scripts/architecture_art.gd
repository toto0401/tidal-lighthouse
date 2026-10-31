extends Node3D

## Visual dressing for the original harbour. All geometry is decorative: the
## existing collision shapes, interaction anchors and furniture roots stay put.

const IVORY := Color("#f4e5c9")
const TEAL := Color("#416f76")
const DARK_TEAL := Color("#31565e")
const BRASS := Color("#d8ba79")
const WOOD := Color("#977968")
const PALE_WOOD := Color("#ceb397")
const CORAL := Color("#d99a89")
const LighthouseLayout := preload("res://data/lighthouse_layout.gd")

var game: Node3D
var _materials := {}
var _meshes := {}

func _ready() -> void:
	game = get_parent() as Node3D
	_dress_lighthouse()
	_dress_home()
	_dress_furniture()
	_dress_archive()
	_dress_trees_and_flowers()

func _dress_lighthouse() -> void:
	var tower := game.get_node_or_null("Lighthouse") as Node3D
	if not tower:
		return
	var plaster := ShaderMaterial.new()
	plaster.shader = load("res://shaders/harbour_plaster.gdshader")
	plaster.set_shader_parameter("base_color", IVORY)
	(tower.get_node("Tower") as MeshInstance3D).material_override = plaster
	var radius := LighthouseLayout.RADIUS
	_torus("FoundationLip", radius, 0.055, Vector3(0, 0.5, 0), IVORY, tower)
	_cylinder("StoneFooting", radius - 0.25, 0.12, Vector3(0, 0.56, 0), PALE_WOOD, tower)
	_torus("ShaftFootTrim", LighthouseLayout.SHAFT_BOTTOM_RADIUS, 0.07, Vector3(0, 0.7, 0), IVORY, tower)
	_torus("CorbelLowerLip", LighthouseLayout.SHAFT_TOP_RADIUS + 0.1, 0.075, Vector3(0, 16.03, 0), IVORY, tower)
	_torus("CorbelCrown", radius - 0.04, 0.06, Vector3(0, 17.6, 0), DARK_TEAL, tower)
	# Warm glass is emissive rather than an additional shadow-casting light.
	for spec in [[PI, 4.8], [PI * 0.5, 4.8], [-PI * 0.5, 4.8], [0.0, 4.8], [PI * 0.5, 12.8], [0.0, 12.8], [PI, 12.8], [-PI * 0.5, 12.8]]:
		var angle: float = spec[0]
		var mount := Node3D.new()
		mount.name = "TowerWindow"
		mount.position = Vector3(sin(angle) * (LighthouseLayout.shaft_radius(spec[1]) + 0.05), spec[1], cos(angle) * (LighthouseLayout.shaft_radius(spec[1]) + 0.05))
		mount.rotation.y = angle
		tower.add_child(mount)
		_box("WindowSurround", Vector3(0.74, 1.04, 0.09), Vector3.ZERO, IVORY, mount)
		var pane := _box("WarmGlass", Vector3(0.52, 0.79, 0.02), Vector3(0, 0.02, 0.061), Color("#e6c28e"), mount)
		pane.material_override = _glow(Color("#dfc18d"), 0.34)
		_box("VerticalMullion", Vector3(0.045, 0.82, 0.04), Vector3(0, 0.02, 0.085), TEAL, mount)
		_box("HorizontalMullion", Vector3(0.54, 0.045, 0.04), Vector3(0, 0.08, 0.085), TEAL, mount)
		_box("WindowSill", Vector3(0.84, 0.09, 0.25), Vector3(0, -0.53, 0.04), PALE_WOOD, mount)
	var door := Node3D.new()
	door.name = "EntryDetails"
	door.position = Vector3(0, 0.5, -5.1)
	tower.add_child(door)
	for x in [-0.7, 0.7]:
		_box("DoorJamb", Vector3(0.13, 2.13, 0.22), Vector3(x, 1.08, 0), IVORY, door)
	_box("DoorLintel", Vector3(1.54, 0.17, 0.24), Vector3(0, 2.1, 0), IVORY, door)
	_box("DoorUpperPanel", Vector3(0.83, 0.55, 0.025), Vector3(0, 1.53, -0.07), TEAL, door)
	_box("DoorLowerPanel", Vector3(0.83, 0.56, 0.025), Vector3(0, 0.63, -0.07), TEAL, door)
	_sphere("DoorHandle", 0.055, Vector3(0.39, 1.06, -0.14), BRASS, door)
	_box("Threshold", Vector3(1.65, 0.09, 0.55), Vector3(0, 0.19, -0.2), PALE_WOOD, door)
	for node in game.get_children():
		if node is Label3D and node.text == "潮汐灯塔":
			node.position.y = LighthouseLayout.GALLERY_HEIGHT + 4.4

func _dress_home() -> void:
	var home := game.get_node_or_null("LighthouseRoom") as Node3D
	if not home:
		return
	# The open front and right wall retain the dollhouse view and walk-in access.
	for p in [Vector3(-2.02, 1.24, -1.4), Vector3(2.02, 1.24, -1.4), Vector3(-2.02, 1.24, 1.42)]:
		_box("HomeTimber", Vector3(0.13, 2.5, 0.15), p, PALE_WOOD, home)
	_box("BackFascia", Vector3(4.4, 0.16, 0.23), Vector3(0, 2.43, -1.45), TEAL, home)
	_box("SideFascia", Vector3(0.23, 0.16, 3.05), Vector3(-2.05, 2.43, 0), TEAL, home)
	_box("BackSkirting", Vector3(4.05, 0.14, 0.055), Vector3(0, 0.24, -1.36), PALE_WOOD, home)
	_box("SideSkirting", Vector3(0.055, 0.14, 2.9), Vector3(-1.96, 0.24, 0), PALE_WOOD, home)
	_box("FrontFloorEdge", Vector3(4.22, 0.15, 0.085), Vector3(0, 0.05, 1.51), WOOD, home)
	for i in range(11):
		_box("FloorboardSeam", Vector3(0.015, 0.005, 2.92), Vector3(-1.88 + i * 0.375, 0.124, 0), Color("#b69a82"), home)
	for i in range(5):
		_box("BoardJoint", Vector3(0.37, 0.006, 0.014), Vector3(-1.7 + i * 0.75, 0.125, -0.4 if i % 2 == 0 else 0.65), Color("#b69a82"), home)
	var window := Node3D.new()
	window.name = "CottageWindow"
	window.position = Vector3(0.74, 1.47, -1.36)
	home.add_child(window)
	_box("WindowFrame", Vector3(1.19, 1.13, 0.1), Vector3.ZERO, PALE_WOOD, window)
	var pane := _box("OceanGlass", Vector3(0.99, 0.93, 0.03), Vector3(0, 0, 0.065), Color("#a4cac4"), window)
	pane.material_override = _glow(Color("#a4cac4"), 0.14)
	_box("WindowCrossX", Vector3(1.0, 0.07, 0.045), Vector3(0, 0, 0.09), IVORY, window)
	_box("WindowCrossY", Vector3(0.06, 0.97, 0.045), Vector3(0, 0, 0.095), IVORY, window)
	_box("WindowSill", Vector3(1.28, 0.07, 0.24), Vector3(0, -0.56, 0.05), IVORY, window)
	for x in [-0.63, 0.63]:
		_box("Curtain", Vector3(0.18, 1.01, 0.035), Vector3(x, 0.02, 0.14), Color("#e9bdad"), window)
	_box("WallShelf", Vector3(1.2, 0.065, 0.3), Vector3(-0.82, 1.36, -1.15), WOOD, home)
	for x in [-1.23, -0.47]:
		_box("ShelfBracket", Vector3(0.045, 0.2, 0.2), Vector3(x, 1.25, -1.21), TEAL, home)
	var book_colors := [CORAL, TEAL, Color("#d8c48f"), Color("#9baea3"), Color("#7d94a4")]
	for i in range(5):
		var book := _box("ShelfBook", Vector3(0.13, 0.35 + (i % 2) * 0.06, 0.2), Vector3(-1.26 + i * 0.15, 1.57, -1.14), book_colors[i], home)
		_box("BookSpineBand", Vector3(0.14, 0.035, 0.018), Vector3(0, -0.09, 0.109), IVORY, book)
	_cylinder("ShelfVase", 0.12, 0.21, Vector3(-0.35, 1.5, -1.15), CORAL, home)
	for i in range(3):
		var angle := float(i) * 2.1
		var tip := Vector3(-0.35 + sin(angle) * 0.07, 1.84 + float(i % 2) * 0.08, -1.15 + cos(angle) * 0.065)
		_rod("DriedStem", Vector3(-0.35, 1.57, -1.15), tip, 0.012, Color("#a0a075"), home)
		_sphere("DriedFlower", 0.055, tip, Color("#e3cca2"), home)
	# A small tide-chart print and a cloth pennant garland replace bare walls.
	_box("ChartFrame", Vector3(0.75, 0.64, 0.06), Vector3(-1.0, 0.81, -1.35), TEAL, home)
	_box("ChartPaper", Vector3(0.65, 0.54, 0.015), Vector3(-1.0, 0.81, -1.31), IVORY, home)
	for i in range(3):
		var wave := _torus("PrintedTides", 0.12 + i * 0.025, 0.009, Vector3(-1.16 + i * 0.16, 0.82, -1.29), Color("#7faaa7"), home)
		wave.rotation.x = PI / 2.0
	for i in range(9):
		var x := -1.82 + float(i) * 0.45
		var y := 2.3 - sin(float(i) / 8.0 * PI) * 0.16
		if i < 8:
			var next_x := x + 0.45
			var next_y := 2.3 - sin(float(i + 1) / 8.0 * PI) * 0.16
			_rod("GarlandString", Vector3(x, y, -1.27), Vector3(next_x, next_y, -1.27), 0.009, WOOD, home)
		_triangle("ClothPennant", Vector3(x, y - 0.025, -1.26), Vector2(0.19, 0.24), [CORAL, Color("#8bafa4"), Color("#dfcc99")][i % 3], home)

func _dress_furniture() -> void:
	var chair := game.get_node_or_null("Chair") as MeshInstance3D
	if chair:
		# Chair remains the material/palette root and keeps its existing collision.
		var seat := BoxMesh.new()
		seat.size = Vector3(0.75, 0.16, 0.75)
		chair.mesh = seat
		_box("ChairBack", Vector3(0.75, 0.55, 0.12), Vector3(0, 0.35, -0.31), PALE_WOOD, chair)
		for x in [-0.28, 0.28]:
			for z in [-0.28, 0.28]:
				_box("ChairLeg", Vector3(0.065, 0.46, 0.065), Vector3(x, -0.29, z), WOOD, chair)
		for x in [-0.2, 0.0, 0.2]:
			_box("ChairBackSlat", Vector3(0.035, 0.47, 0.025), Vector3(x, 0.36, -0.238), PALE_WOOD, chair)
		_box("SeatCushion", Vector3(0.6, 0.08, 0.59), Vector3(0, 0.11, 0.03), IVORY, chair)
	var table := game.get_node_or_null("TeaTable") as MeshInstance3D
	if table:
		var pedestal := CylinderMesh.new()
		pedestal.top_radius = 0.16
		pedestal.bottom_radius = 0.27
		pedestal.height = 0.6
		pedestal.radial_segments = 24
		table.mesh = pedestal
		_cylinder("TeaTableTop", 0.49, 0.09, Vector3(0, 0.25, 0), IVORY, table)
		_torus("TableRim", 0.495, 0.012, Vector3(0, 0.3, 0), BRASS, table)
		_box("FoldedLetter", Vector3(0.3, 0.015, 0.23), Vector3(-0.14, 0.303, 0.16), Color("#ede1c7"), table)
		_box("LetterRibbon", Vector3(0.31, 0.012, 0.03), Vector3(-0.14, 0.315, 0.16), CORAL, table)
		var cup := game.get_node_or_null("TeaCup") as MeshInstance3D
		if cup:
			var tea := _cylinder("Tea", 0.083, 0.01, Vector3(0, 0.071, 0), Color("#a5754e"), cup)
			tea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var handle := _torus("CupHandle", 0.065, 0.02, Vector3(0.11, 0.01, 0), IVORY, cup)
			handle.rotation.x = PI / 2.0

func _dress_archive() -> void:
	var desk := game.get_node_or_null("LighthouseRoom/ArchiveDesk") as Node3D
	if not desk:
		return
	for x in [-1.2, 1.2]:
		_box("DeskFoot", Vector3(0.5, 0.11, 0.92), Vector3(x, 0.2, 0), WOOD, desk)
	_box("DeskApron", Vector3(3.15, 0.25, 0.08), Vector3(0, 0.91, 0.58), WOOD, desk)
	_box("BookBinding", Vector3(0.045, 0.013, 0.94), Vector3(0, 1.287, 0), PALE_WOOD, desk)
	for i in range(5):
		for side in [-1.0, 1.0]:
			_box("JournalInk", Vector3(0.58 - (i % 2) * 0.12, 0.008, 0.015), Vector3(side * 0.46, 1.291, -0.29 + i * 0.12), Color("#879992"), desk)
	_cylinder("InkBottle", 0.09, 0.18, Vector3(1.4, 1.28, -0.44), TEAL, desk)
	_rod("Quill", Vector3(1.4, 1.34, -0.44), Vector3(1.53, 1.71, -0.48), 0.014, IVORY, desk)
	var feather := _sphere("QuillFeather", 0.13, Vector3(1.53, 1.7, -0.48), IVORY, desk)
	feather.scale = Vector3(0.45, 1.5, 0.19)
	feather.rotation.z = -0.4
	_cylinder("ChartRoll", 0.075, 0.74, Vector3(-1.4, 1.28, -0.03), IVORY, desk).rotation.x = PI / 2.0
	_box("ChartRollTie", Vector3(0.16, 0.15, 0.035), Vector3(-1.4, 1.28, -0.03), CORAL, desk)

func _dress_trees_and_flowers() -> void:
	# The original flat ellipsoids become lobed, wind-shaped foliage. Tiny leaves
	# are batched into a single draw call; none add collision to walking routes.
	var leaf_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 61924
	for node in game.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("WindTreeCrown"):
			node.material_override = _mat(Color("#719a88") if leaf_transforms.size() % 2 == 0 else Color("#99b39b"))
			for i in range(12):
				var angle := TAU * float(i) / 12.0
				var location: Vector3 = node.position + Vector3(cos(angle) * 0.8, rng.randf_range(-0.22, 0.42), sin(angle) * 0.57)
				var basis := Basis.from_euler(Vector3(0.12, angle, -0.1)).scaled(Vector3(0.42, 0.29, 0.37))
				leaf_transforms.append(Transform3D(basis, location))
	var foliage := _sphere_mesh(1.0)
	_multimesh("CanopyLobes", foliage, leaf_transforms, _mat(Color("#8cac91")), self)
	var blossoms: Array[Transform3D] = []
	var leaf_sprays: Array[Transform3D] = []
	var centres: Array[Transform3D] = []
	for base in [Vector3(-10.8, 0.22, 11.0), Vector3(-11.6, 0.22, 5.2), Vector3(7.3, 0.22, 10.5), Vector3(11.4, 0.22, 4.8), Vector3(-8.6, 0.22, -4.9)]:
		for i in range(16):
			var p: Vector3 = base + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(0.14, 0.34), rng.randf_range(-0.55, 0.55))
			for j in range(5):
				var angle := float(j) / 5.0 * TAU
				var basis := Basis.from_euler(Vector3(0, angle, 0)).scaled(Vector3(0.066, 0.025, 0.11))
				blossoms.append(Transform3D(basis, p + Vector3(sin(angle) * 0.08, 0, cos(angle) * 0.08)))
			centres.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.035, 0.026, 0.035)), p + Vector3(0, 0.025, 0)))
			var spray := Basis.from_euler(Vector3(0.4, rng.randf() * TAU, 0.3)).scaled(Vector3(0.055, 0.16, 0.19))
			leaf_sprays.append(Transform3D(spray, p - Vector3(0, 0.1, 0)))
	_multimesh("CoastalDaisyPetals", foliage, blossoms, _mat(Color("#e8c2b7")), self)
	_multimesh("DaisyHearts", foliage, centres, _mat(Color("#d9bc78")), self)
	_multimesh("DaisyLeaves", foliage, leaf_sprays, _mat(Color("#70977d")), self)

func _mat(color: Color, roughness := 0.88, metallic := 0.0) -> StandardMaterial3D:
	var key := str(color) + ":" + str(roughness) + ":" + str(metallic)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color).duplicate() as StandardMaterial3D
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _box(node_name: String, size: Vector3, location: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var key := "box:" + str(size)
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _instance(_meshes[key], node_name, location, _mat(color), parent)

func _cylinder_mesh(radius: float, height: float) -> CylinderMesh:
	var key := "cylinder:" + str(radius) + ":" + str(height)
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 24
		_meshes[key] = mesh
	return _meshes[key]

func _cylinder(node_name: String, radius: float, height: float, location: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	return _instance(_cylinder_mesh(radius, height), node_name, location, _mat(color), parent)

func _sphere_mesh(radius: float) -> SphereMesh:
	var key := "sphere:" + str(radius)
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		_meshes[key] = mesh
	return _meshes[key]

func _sphere(node_name: String, radius: float, location: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	return _instance(_sphere_mesh(radius), node_name, location, _mat(color), parent)

func _torus(node_name: String, radius: float, width: float, location: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 48
	mesh.ring_segments = 6
	return _instance(mesh, node_name, location, _mat(color), parent)

func _instance(mesh: Mesh, node_name: String, location: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = location
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _rod(node_name: String, a: Vector3, b: Vector3, radius: float, color: Color, parent: Node3D) -> MeshInstance3D:
	var rod := _cylinder(node_name, radius, a.distance_to(b), (a + b) * 0.5, color, parent)
	var direction := (b - a).normalized()
	if not direction.is_equal_approx(Vector3.UP):
		rod.quaternion = Quaternion(Vector3.UP, direction)
	return rod

func _triangle(node_name: String, location: Vector3, size: Vector2, color: Color, parent: Node3D) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-size.x * 0.5, 0, 0), Vector3(0, -size.y, 0), Vector3(size.x * 0.5, 0, 0)]:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(point)
	var material := _mat(color).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _instance(surface.commit(), node_name, location, material, parent)

func _multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material, parent: Node3D) -> void:
	if transforms.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = batch
	instance.material_override = material
	parent.add_child(instance)
