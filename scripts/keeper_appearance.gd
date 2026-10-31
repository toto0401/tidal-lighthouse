extends RefCounted

## Sculpted, fully three-dimensional keeper based on docs/character-reference/.
## Visual geometry never participates in the CharacterBody3D's collision.
const COAT_COLORS := [Color("#efa15b"), Color("#8eb4c9"), Color("#d9a1b6"), Color("#91b594")]
var coat_material := _material(Color("#efa15b"))
var seam_material := _material(Color("#d58b4d"))
var hat_material := _material(Color("#ffe0a0"))
var hat_seam := _material(Color("#edc781"))
var ivory := _material(Color("#f5dfb3"))
var skin := _material(Color("#ecc09c"))
var hair := _material(Color("#8d6243"))
var hair_light := _material(Color("#9f7350"))
var navy := _material(Color("#3e5068"), 0.66)
var sage := _material(Color("#87a58e"))
var sage_edge := _material(Color("#718f7b"))
var brass := _material(Color("#ba8c54"), 0.6)
var coat: MeshInstance3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var shell_pivot: Node3D
var gait := 0.0
var dash_blend := 0.0
var walk_blend := 0.0

func build(player: Node3D) -> void:
	# A gently rounded, open hem; its inner return gives the raincoat thickness.
	coat = _mesh("Coat", _lathe([
		Vector3(0.485, -0.29, 0.299), Vector3(0.511, -0.305, 0.317),
		Vector3(0.523, -0.29, 0.325), Vector3(0.52, -0.265, 0.327),
		Vector3(0.475, -0.1, 0.31), Vector3(0.411, 0.12, 0.275),
		Vector3(0.352, 0.32, 0.236), Vector3(0.315, 0.424, 0.218),
		Vector3(0.263, 0.477, 0.18), Vector3(0.13, 0.49, 0.12)
	]), coat_material, player)
	_build_head()
	_build_coat_details()
	_build_backpack()
	for side in [-1.0, 1.0]:
		_build_arm(player, side)
		_build_leg(player, side)
	# Bake non-articulated details by material: buttons, stitches and hair locks
	# remain actual geometry without turning each one into a separate draw call.
	_merge_details(coat)
	for arm in arms:
		_merge_details(arm)
	for leg in legs:
		_merge_details(leg)
	_merge_details(shell_pivot)

func _build_head() -> void:
	_ellipsoid("Neck", Vector3(0, 0.51, 0), Vector3(0.13, 0.15, 0.13), skin, coat)
	_ellipsoid("HairCap", Vector3(0, 0.877, -0.038), Vector3(0.405, 0.373, 0.34), hair, coat)
	_ellipsoid("Head", Vector3(0, 0.84, 0.084), Vector3(0.327, 0.327, 0.279), skin, coat)
	# Short bob: shaped, tapered locks, clear of the deliberately featureless face.
	for index in range(13):
		var angle := lerpf(0.80, TAU - 0.80, float(index) / 12.0)
		var radius := 0.35
		var start := Vector3(sin(angle) * radius, 1.04, cos(angle) * 0.3 - 0.025)
		var mid := Vector3(sin(angle) * 0.405, 0.76, cos(angle) * 0.325 - 0.015)
		var tip := Vector3(sin(angle + 0.14) * 0.335, 0.545 + 0.035 * sin(index * 2.1), cos(angle + 0.14) * 0.29)
		_lock("BobLock", start, mid, tip, 0.083, hair if index % 3 else hair_light, coat)
	for side in [-1.0, 1.0]:
		for index in range(3):
			var inset := index * 0.043
			_lock("Fringe", Vector3(side * (0.18 + inset), 1.15, 0.2),
				Vector3(side * (0.27 + inset), 0.96 - index * 0.055, 0.303),
				Vector3(side * (0.225 + inset), 0.82 - index * 0.072, 0.30), 0.063, hair_light, coat)
	_mesh("RainHatCrown", _lathe([
		Vector3(0.49, 1.17, 0.453), Vector3(0.481, 1.29, 0.45),
		Vector3(0.439, 1.425, 0.412), Vector3(0.353, 1.552, 0.338),
		Vector3(0.221, 1.64, 0.214), Vector3(0.075, 1.679, 0.074), Vector3(0.001, 1.686, 0.001)
	], 64), hat_material, coat)
	# Bell brim, not a flat disk. Both sides are visible when the camera orbits.
	_mesh("RainHat", _lathe([
		Vector3(0.823, 0.91, 0.715), Vector3(0.835, 0.925, 0.724),
		Vector3(0.826, 0.943, 0.716), Vector3(0.774, 0.978, 0.678),
		Vector3(0.699, 1.025, 0.617), Vector3(0.621, 1.089, 0.552),
		Vector3(0.54, 1.151, 0.492), Vector3(0.49, 1.187, 0.453)
	], 80), hat_material, coat)
	_ellipse_seam("BrimPiping", Vector3(0, 0.935, 0), 0.829, 0.719, 0.009, hat_seam, coat)
	_ellipse_seam("CrownSeam", Vector3(0, 1.188, 0), 0.49, 0.455, 0.006, hat_seam, coat)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var points: Array[Vector3] = []
		for index in range(21):
			var t := float(index) / 20.0 * PI * 0.5
			points.append(Vector3(sin(angle) * 0.492 * sin(t), 1.186 + 0.502 * cos(t), cos(angle) * 0.457 * sin(t)))
		_tube("HatPanelSeam", points, 0.005, hat_seam, coat, 5)
	_ellipsoid("HatButton", Vector3(0, 1.69, 0), Vector3(0.067, 0.026, 0.06), hat_material, coat)

func _build_coat_details() -> void:
	for side in [-1.0, 1.0]:
		var collar := _ellipsoid("PeterPanCollar", Vector3(side * 0.139, 0.454, 0.219), Vector3(0.148, 0.022, 0.162), ivory, coat)
		collar.rotation = Vector3(0.58, side * -0.16, side * 0.17)
	_ellipsoid("BackCollar", Vector3(0, 0.478, -0.115), Vector3(0.29, 0.062, 0.125), ivory, coat)
	_tube("FrontPlacket", [Vector3(-0.054, -0.267, 0.327), Vector3(-0.05, -0.05, 0.313), Vector3(-0.046, 0.16, 0.27), Vector3(-0.039, 0.38, 0.224)], 0.0055, seam_material, coat)
	_ellipse_seam("HemStitch", Vector3(0, -0.256, 0), 0.519, 0.329, 0.0045, seam_material, coat)
	var thread := _material(Color("#a37d52"))
	for height in [0.337, 0.096, -0.145]:
		var front := 0.249 if height > 0.2 else (0.296 if height > 0 else 0.328)
		var button := Node3D.new()
		button.position = Vector3(0, height, front)
		coat.add_child(button)
		_ellipsoid("IvoryButton", Vector3.ZERO, Vector3(0.058, 0.058, 0.019), ivory, button)
		for x in [-0.013, 0.013]:
			for y in [-0.013, 0.013]:
				_ellipsoid("ButtonHole", Vector3(x, y, 0.019), Vector3(0.006, 0.006, 0.003), thread, button)
		_tube("ButtonThread", [Vector3(-0.013, -0.013, 0.022), Vector3(0.013, 0.013, 0.023)], 0.0025, thread, button, 5)
	for side in [-1.0, 1.0]:
		var pocket := _rounded_box("PatchPocket", Vector3(side * 0.354, -0.09, 0.246), Vector3(0.185, 0.22, 0.037), 0.018, coat_material, coat)
		pocket.rotation.z = side * 0.13
		pocket.rotation.y = side * 0.45
		_tube("PocketOpening", [Vector3(-0.075, 0.078, 0.021), Vector3(0, 0.071, 0.024), Vector3(0.075, 0.078, 0.021)], 0.005, seam_material, pocket)
	# Three-dimensional lighthouse applique, visible on the keeper's left chest.
	var pin := Node3D.new()
	pin.name = "LighthousePin"
	pin.position = Vector3(0.195, 0.231, 0.231)
	pin.rotation.y = 0.16
	coat.add_child(pin)
	_mesh("Tower", _lathe([Vector3(0.032, -0.065, 0.014), Vector3(0.023, 0.044, 0.012)], 12), ivory, pin)
	var red := _material(Color("#c97459"))
	_mesh("TowerStripe", _lathe([Vector3(0.029, -0.027, 0.015), Vector3(0.026, 0.003, 0.014)], 12), red, pin)
	_rounded_box("TowerFoot", Vector3(0, -0.07, 0), Vector3(0.087, 0.021, 0.039), 0.008, navy, pin)
	_rounded_box("LanternRoom", Vector3(0, 0.047, 0), Vector3(0.055, 0.029, 0.03), 0.007, navy, pin)
	_rounded_box("LanternWindow", Vector3(0, 0.047, 0.018), Vector3(0.021, 0.013, 0.008), 0.003, ivory, pin)
	_mesh("TowerRoof", _lathe([Vector3(0.039, 0.064, 0.025), Vector3(0.002, 0.09, 0.002)], 16), navy, pin)
	_ellipsoid("TowerWindow", Vector3(0, 0.011, 0.017), Vector3(0.009, 0.012, 0.006), navy, pin)

func _build_backpack() -> void:
	var bag := _rounded_box("Backpack", Vector3(0, 0.195, -0.335), Vector3(0.51, 0.575, 0.232), 0.07, sage, coat)
	_rounded_box("BagFrontPanel", Vector3(0, -0.025, -0.122), Vector3(0.439, 0.454, 0.043), 0.02, sage_edge, bag)
	_rounded_box("BagFrontInset", Vector3(0, -0.024, -0.148), Vector3(0.411, 0.423, 0.026), 0.012, sage, bag)
	_rounded_box("BagFlap", Vector3(0, 0.171, -0.139), Vector3(0.46, 0.24, 0.06), 0.029, sage, bag)
	_rounded_box("BagClasp", Vector3(0, 0.021, -0.181), Vector3(0.081, 0.153, 0.039), 0.016, sage_edge, bag)
	_rounded_box("BagBuckle", Vector3(0, -0.011, -0.205), Vector3(0.069, 0.051, 0.01), 0.004, sage, bag)
	_tube("BagHandle", [Vector3(-0.092, 0.468, -0.324), Vector3(-0.07, 0.529, -0.33), Vector3(0, 0.543, -0.33), Vector3(0.07, 0.529, -0.33), Vector3(0.092, 0.468, -0.324)], 0.014, sage_edge, coat)
	for side in [-1.0, 1.0]:
		# Flattened straps follow the shoulders and remain visible from the front.
		var strap_points: Array[Vector3] = [Vector3(side * 0.222, -0.038, 0.245), Vector3(side * 0.264, 0.17, 0.229), Vector3(side * 0.257, 0.377, 0.192), Vector3(side * 0.246, 0.479, 0.07), Vector3(side * 0.232, 0.457, -0.132), Vector3(side * 0.223, 0.34, -0.25)]
		_tube("ShoulderStrap", strap_points, 0.044, sage_edge, coat, 10, 0.32)
		_rounded_box("StrapAdjuster", Vector3(side * 0.25, 0.125, 0.267), Vector3(0.081, 0.036, 0.022), 0.008, sage, coat)
	shell_pivot = Node3D.new()
	shell_pivot.name = "ShellCharm"
	shell_pivot.position = Vector3(-0.269, 0.411, -0.419)
	shell_pivot.set_meta("articulated", true)
	coat.add_child(shell_pivot)
	_tube("CharmCord", [Vector3.ZERO, Vector3(-0.02, 0.015, -0.014), Vector3(-0.029, -0.055, -0.027), Vector3(-0.026, -0.109, -0.03)], 0.0065, brass, shell_pivot)
	_ellipsoid("CharmBead", Vector3(-0.026, -0.109, -0.03), Vector3(0.019, 0.02, 0.019), ivory, shell_pivot)
	# Scallop fan with raised radial ribs and a scalloped edge.
	for index in range(7):
		var angle := lerpf(-0.85, 0.85, index / 6.0)
		var rib := _ellipsoid("ShellRib", Vector3(-0.026 + sin(angle) * 0.041, -0.165 - cos(angle) * 0.018, -0.032), Vector3(0.018, 0.069, 0.023), ivory, shell_pivot)
		rib.rotation.z = angle

func _build_arm(player: Node3D, side: float) -> void:
	var arm := Node3D.new()
	arm.name = "LeftSleeve" if side < 0 else "RightSleeve"
	arm.position = Vector3(side * 0.283, 0.376, 0)
	arm.rotation.z = side * 0.4
	arm.scale.y = 1.2
	player.add_child(arm)
	arms.append(arm)
	_mesh("BellSleeve", _lathe([
		Vector3(0.16, -0.348, 0.146), Vector3(0.18, -0.351, 0.164),
		Vector3(0.19, -0.34, 0.174), Vector3(0.186, -0.317, 0.171),
		Vector3(0.153, -0.15, 0.151), Vector3(0.118, 0.015, 0.121),
		Vector3(0.074, 0.069, 0.08), Vector3(0.001, 0.075, 0.001)
	], 32), coat_material, arm)
	_ellipse_seam("SleeveStitch", Vector3(0, -0.32, 0), 0.187, 0.173, 0.004, seam_material, arm)
	_ellipsoid("Wrist", Vector3(0, -0.343, 0), Vector3(0.072, 0.093, 0.065), skin, arm)
	_ellipsoid("Hand", Vector3(0, -0.405, 0.008), Vector3(0.084, 0.084, 0.055), skin, arm)
	for finger in range(4):
		_ellipsoid("Finger", Vector3(-0.051 + finger * 0.032, -0.46 + absf(finger - 1.5) * 0.012, 0.013), Vector3(0.019, 0.052, 0.023), skin, arm)
	var thumb := _ellipsoid("Thumb", Vector3(-side * 0.078, -0.402, 0.046), Vector3(0.027, 0.051, 0.029), skin, arm)
	thumb.rotation.z = side * 0.6

func _build_leg(player: Node3D, side: float) -> void:
	var leg := Node3D.new()
	leg.name = "Boots" if side < 0 else "Boots2"
	leg.position = Vector3(side * 0.229, -0.247, 0)
	player.add_child(leg)
	legs.append(leg)
	_ellipsoid("BareLeg", Vector3(0, -0.08, 0), Vector3(0.092, 0.184, 0.089), skin, leg)
	_mesh("BootShaft", _lathe([Vector3(0.128, -0.446, 0.142), Vector3(0.12, -0.35, 0.129), Vector3(0.126, -0.23, 0.124), Vector3(0.136, -0.171, 0.132)], 32), navy, leg)
	_ellipse_seam("RolledBootCuff", Vector3(0, -0.183, 0), 0.135, 0.131, 0.017, navy, leg)
	_ellipsoid("BootToe", Vector3(0, -0.427, 0.066), Vector3(0.14, 0.092, 0.209), navy, leg)
	var sole := _mesh("CreamSole", _lathe([Vector3(0.001, -0.031, 0.001), Vector3(0.125, -0.031, 0.19), Vector3(0.144, -0.023, 0.212), Vector3(0.145, 0.016, 0.212), Vector3(0.128, 0.031, 0.191), Vector3(0.001, 0.031, 0.001)], 40), ivory, leg)
	sole.position = Vector3(0, -0.495, 0.061)
	_tube("BootBackSeam", [Vector3(0, -0.205, -0.129), Vector3(0, -0.33, -0.131), Vector3(0, -0.447, -0.139)], 0.003, _material(Color("#485b74")), leg)

func set_palette(choice: int) -> void:
	coat_material.albedo_color = COAT_COLORS[choice]
	seam_material.albedo_color = COAT_COLORS[choice].darkened(0.1)
	hat_material.albedo_color = Color("#ffe0a0") if choice == 0 else COAT_COLORS[choice].lightened(0.3)
	hat_seam.albedo_color = hat_material.albedo_color.darkened(0.065)

func animate(delta: float, speed: float, grounded: bool, dashing: bool, swimming := false, fishing := false) -> void:
	var blend := 1.0 - exp(-delta * 12.0)
	walk_blend = lerpf(walk_blend, minf(speed / 2.8, 1.0) if grounded and not dashing else 0.0, blend)
	dash_blend = lerpf(dash_blend, 1.0 if dashing else 0.0, blend)
	gait += delta * 9.0 * minf(speed / 2.8, 1.0)
	coat.rotation.x = dash_blend * 0.1
	coat.rotation.z = sin(gait) * 0.018 * walk_blend
	coat.position.y = absf(sin(gait)) * 0.017 * walk_blend
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var step := sin(gait + index * PI) * walk_blend
		arms[index].rotation = Vector3(step * 0.34 - dash_blend * 0.15, 0, side * (0.4 + dash_blend * 0.82 + (0.18 if not grounded else 0.0)))
		legs[index].rotation = Vector3(-step * 0.30 + dash_blend * (0.19 if index == 0 else -0.23), 0, 0)
		legs[index].position.y = -0.247 + maxf(0, step) * 0.048
		legs[index].position.z = dash_blend * (0.10 if index == 0 else -0.11)
		if not grounded:
			legs[index].rotation.x = 0.16 if index == 0 else -0.26
	shell_pivot.rotation.x = sin(gait + 0.4) * 0.12 * walk_blend + dash_blend * 0.26
	if swimming:
		gait += delta * 3.5
		coat.rotation.x = 0.18
		for index in range(2):
			var side := -1.0 if index == 0 else 1.0
			arms[index].rotation = Vector3(-0.8 + sin(gait) * 0.55, side * cos(gait) * 0.5, side * 0.95)
			legs[index].rotation.x = sin(gait * 1.8 + index * PI) * 0.3
	elif fishing:
		arms[1].rotation = Vector3(-0.9, 0, 0.12)
		arms[0].rotation = Vector3(-0.6, -0.4, -0.15)

func animate_gliding(bank: float) -> void:
	coat.rotation = Vector3(0.08,0,bank*0.3)
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		arms[index].rotation = Vector3(-0.5,0,side*2.0)
		legs[index].rotation = Vector3(0.16 if index == 0 else -0.12,0,side*0.08)
	shell_pivot.rotation.x = 0.22

func animate_seated(sip_lift: float) -> void:
	walk_blend = 0.0
	dash_blend = 0.0
	coat.position.y = 0.0
	coat.rotation = Vector3(-0.035 * sip_lift, 0, 0)
	shell_pivot.rotation.x = 0.0
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		legs[index].rotation = Vector3(-1.28, -side * 0.16, side * 0.1)
		legs[index].position.y = -0.247
		legs[index].position.z = 0.06
		arms[index].rotation = Vector3(-0.7, 0, side * 0.24)
	arms[1].rotation = Vector3(-0.7, 0, 0.24).lerp(Vector3(-2.5, 0, 0.45), sip_lift)

static func _material(color: Color, roughness := 0.86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _mesh(node_name: String, mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance, true)
	return instance

func _ellipsoid(node_name: String, at: Vector3, radius: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 16
	var node := _mesh(node_name, sphere, material, parent)
	node.position = at
	node.scale = radius
	return node

func _lathe(profile: Array[Vector3], segments := 48) -> ArrayMesh:
	var points := PackedVector3Array()
	for ring in profile:
		for index in range(segments + 1):
			var angle := TAU * index / segments
			points.append(Vector3(sin(angle) * ring.x, ring.y, cos(angle) * ring.z))
	return _grid(points, profile.size(), segments + 1)

func _grid(points: PackedVector3Array, rows: int, columns: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in points:
		surface.add_vertex(point)
	for row in range(rows - 1):
		for col in range(columns - 1):
			var a := row * columns + col
			for index in [a, a + columns, a + 1, a + 1, a + columns, a + columns + 1]:
				surface.add_index(index)
	surface.generate_normals()
	return surface.commit()

func _tube(node_name: String, points: Array[Vector3], radius: float, material: Material, parent: Node3D, sides := 8, flatten := 1.0, taper := false) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	for index in range(points.size()):
		var tangent := (points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]).normalized()
		var reference := Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var u := tangent.cross(reference).normalized()
		var v := tangent.cross(u).normalized()
		var r := radius
		if taper:
			var t := float(index) / (points.size() - 1)
			r *= maxf(0.025, pow(sin(PI * (0.13 + t * 0.87)), 0.65))
		for segment in range(sides + 1):
			var angle := TAU * segment / sides
			vertices.append(points[index] + r * (u * cos(angle) + v * sin(angle) * flatten))
	return _mesh(node_name, _grid(vertices, points.size(), sides + 1), material, parent)

func _lock(node_name: String, start: Vector3, middle: Vector3, end: Vector3, radius: float, material: Material, parent: Node3D) -> void:
	var points: Array[Vector3] = []
	for index in range(17):
		var t := float(index) / 16.0
		points.append(start * (1.0 - t) * (1.0 - t) + middle * 2.0 * t * (1.0 - t) + end * t * t)
	_tube(node_name, points, radius, material, parent, 12, 0.7, true)

func _ellipse_seam(node_name: String, at: Vector3, rx: float, rz: float, radius: float, material: Material, parent: Node3D) -> void:
	var points: Array[Vector3] = []
	for index in range(65):
		var angle := index * TAU / 64.0
		points.append(at + Vector3(sin(angle) * rx, 0, cos(angle) * rz))
	_tube(node_name, points, radius, material, parent, 6)

func _rounded_box(node_name: String, at: Vector3, size: Vector3, radius: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core := size * 0.5 - Vector3.ONE * radius
	var divisions := 8
	for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u: Vector3 = normal.cross(Vector3.UP if absf(normal.y) < 0.5 else Vector3.BACK)
		var v: Vector3 = normal.cross(u)
		for row in range(divisions):
			for col in range(divisions):
				for corner in [Vector2(col, row), Vector2(col, row + 1), Vector2(col + 1, row), Vector2(col + 1, row), Vector2(col, row + 1), Vector2(col + 1, row + 1)]:
					var point: Vector3 = (normal + u * (corner.x * 2.0 / divisions - 1.0) + v * (corner.y * 2.0 / divisions - 1.0)) * size * 0.5
					var inner := point.clamp(-core, core)
					var outward := (point - inner).normalized()
					surface.set_normal(outward)
					surface.add_vertex(inner + outward * radius)
	var node := _mesh(node_name, surface.commit(), material, parent)
	node.position = at
	return node

func _merge_details(root: Node3D) -> void:
	var batches := {}
	var instances: Array[MeshInstance3D] = []
	_collect_static(root, instances)
	for instance in instances:
		var material: Material = instance.material_override
		if not batches.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[material] = surface
		var local := root.global_transform.affine_inverse() * instance.global_transform
		batches[material].append_from(instance.mesh, 0, local)
	# Collect first, remove children deepest-first so no freed pointer is revisited.
	for index in range(instances.size() - 1, -1, -1):
		instances[index].free()
	for material in batches:
		_mesh("SculptedDetail", batches[material].commit(), material, root)

func _collect_static(node: Node3D, instances: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if not child is Node3D or child.get_meta("articulated", false):
			continue
		if child is MeshInstance3D:
			instances.append(child)
		_collect_static(child, instances)
