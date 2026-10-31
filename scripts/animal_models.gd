extends RefCounted

## Small pastel wildlife, built entirely from reusable low-poly meshes.
## All models face +Z and rest on y=0. Animation pivots are direct children
## of Visual; their starting transforms are also saved as metadata.

static var _materials: Dictionary = {}
static var _round_mesh: SphereMesh
static var _rod_mesh: CylinderMesh

static func build(kind: String, parent: Node3D) -> Node3D:
	var visual := Node3D.new()
	visual.name = "Visual"
	parent.add_child(visual)
	match kind:
		"rabbit": _rabbit(visual)
		"crab": _crab(visual)
		"gull": _gull(visual)
	for child in visual.get_children():
		if child is Node3D:
			child.set_meta("rest_position", child.position)
			child.set_meta("rest_rotation", child.rotation)
	return visual

static func _rabbit(root: Node3D) -> void:
	var cream := Color("#f4e5ce")
	var ivory := Color("#fff2da")
	var blush := Color("#e6a7a2")
	var cocoa := Color("#514f55")
	_round("Body", Vector3(0.43, 0.44, 0.52), Vector3(0, 0.29, -0.03), cream, root)
	_round("Bib", Vector3(0.3, 0.3, 0.12), Vector3(0, 0.34, 0.205), ivory, root)
	for side in [-1.0, 1.0]:
		_round("HindPaw", Vector3(0.19, 0.13, 0.28), Vector3(side * 0.18, 0.065, -0.04), cream, root)
		_round("FrontPaw", Vector3(0.11, 0.17, 0.15), Vector3(side * 0.105, 0.09, 0.215), ivory, root)
	_round("CottonTail", Vector3.ONE * 0.19, Vector3(0, 0.29, -0.305), ivory, root)
	var head := _pivot("Head", Vector3(0, 0.52, 0.16), root)
	_round("Face", Vector3(0.37, 0.32, 0.32), Vector3.ZERO, cream, head)
	for side in [-1.0, 1.0]:
		_round("Cheek", Vector3(0.13, 0.095, 0.08), Vector3(side * 0.085, -0.046, 0.13), ivory, head)
		_round("Blush", Vector3(0.072, 0.035, 0.014), Vector3(side * 0.137, -0.004, 0.114), blush, head)
		_round("Eye", Vector3(0.035, 0.043, 0.025), Vector3(side * 0.089, 0.035, 0.14), cocoa, head)
		_round("EyeShine", Vector3.ONE * 0.011, Vector3(side * 0.089 - 0.005, 0.044, 0.152), ivory, head)
		for i in range(2):
			_rod("Whisker", Vector3(side * 0.104, -0.041, 0.158), Vector3(side * 0.226, -0.012 - i * 0.052, 0.144), 0.0035, Color("#b2a29c"), head)
	_round("Nose", Vector3(0.045, 0.031, 0.036), Vector3(0, -0.032, 0.178), blush, head)
	_rod("Mouth", Vector3(0, -0.044, 0.168), Vector3(0, -0.072, 0.163), 0.004, cocoa, head)
	for side in [-1.0, 1.0]:
		var ear := _pivot("LeftEar" if side < 0 else "RightEar", Vector3(side * 0.086, 0.622, 0.139), root)
		ear.rotation.z = side * -0.13
		ear.rotation.x = -0.1 if side < 0 else 0.09
		_round("Ear", Vector3(0.112, 0.34, 0.087), Vector3(0, 0.142, 0), cream, ear)
		_round("InnerEar", Vector3(0.061, 0.26, 0.023), Vector3(0, 0.155, 0.038), blush, ear)

static func _crab(root: Node3D) -> void:
	var shell := Color("#df816c")
	var light_shell := Color("#efa383")
	var claws := Color("#db735f")
	var ivory := Color("#ffebcd")
	var dark := Color("#46515b")
	_round("Shell", Vector3(0.61, 0.31, 0.46), Vector3(0, 0.22, -0.04), shell, root)
	_round("ShellHighlight", Vector3(0.43, 0.045, 0.3), Vector3(0, 0.363, -0.06), light_shell, root)
	_round("Belly", Vector3(0.49, 0.08, 0.33), Vector3(0, 0.116, -0.015), ivory, root)
	for side in [-1.0, 1.0]:
		for i in range(3):
			var z := -0.18 + float(i) * 0.125
			var knee := Vector3(side * (0.39 + float(i % 2) * 0.035), 0.135, z - 0.055)
			var foot := Vector3(side * (0.49 + float(i % 2) * 0.035), 0.019, z - 0.11)
			_rod("LegUpper", Vector3(side * 0.23, 0.2, z), knee, 0.035, shell, root)
			_rod("LegLower", knee, foot, 0.024, claws, root)
			_round("LegJoint", Vector3.ONE * 0.075, knee, light_shell, root)
	var head := _pivot("Head", Vector3(0, 0.245, 0.13), root)
	for side in [-1.0, 1.0]:
		_rod("EyeStalk", Vector3(side * 0.1, 0.0, 0), Vector3(side * 0.13, 0.16, 0.025), 0.025, shell, head)
		_round("EyeWhite", Vector3.ONE * 0.11, Vector3(side * 0.13, 0.175, 0.035), ivory, head)
		_round("Pupil", Vector3(0.045, 0.054, 0.024), Vector3(side * 0.13, 0.178, 0.083), dark, head)
		_round("EyeShine", Vector3.ONE * 0.014, Vector3(side * 0.13 - 0.009, 0.19, 0.095), ivory, head)
		_round("Cheek", Vector3(0.055, 0.025, 0.018), Vector3(side * 0.123, -0.025, 0.088), light_shell, head)
	_rod("SmileLeft", Vector3(-0.037, -0.029, 0.092), Vector3(0, -0.043, 0.095), 0.005, dark, head)
	_rod("SmileRight", Vector3(0, -0.043, 0.095), Vector3(0.037, -0.029, 0.092), 0.005, dark, head)
	for side in [-1.0, 1.0]:
		var claw := _pivot("LeftClaw" if side < 0 else "RightClaw", Vector3(side * 0.25, 0.21, 0.1), root)
		_rod("Arm", Vector3.ZERO, Vector3(side * 0.16, 0.075, 0.12), 0.04, shell, claw)
		_round("Palm", Vector3(0.19, 0.165, 0.2), Vector3(side * 0.19, 0.105, 0.18), claws, claw)
		var outer := _round("OuterPincer", Vector3(0.074, 0.12, 0.185), Vector3(side * 0.239, 0.14, 0.291), light_shell, claw)
		outer.rotation.y = side * -0.3
		var inner := _round("InnerPincer", Vector3(0.065, 0.115, 0.135), Vector3(side * 0.137, 0.13, 0.279), claws, claw)
		inner.rotation.y = side * 0.39

static func _gull(root: Node3D) -> void:
	var white := Color("#fff1db")
	var silver := Color("#adbfc6")
	var slate := Color("#526675")
	var yellow := Color("#e8b668")
	var ink := Color("#394952")
	_round("Body", Vector3(0.37, 0.4, 0.54), Vector3(0, 0.33, -0.035), white, root)
	_round("Back", Vector3(0.31, 0.2, 0.39), Vector3(0, 0.415, -0.102), silver, root)
	for side in [-1.0, 1.0]:
		_rod("Leg", Vector3(side * 0.095, 0.18, 0.004), Vector3(side * 0.095, 0.035, 0.025), 0.019, yellow, root)
		_round("WebbedFoot", Vector3(0.14, 0.044, 0.17), Vector3(side * 0.095, 0.022, 0.075), yellow, root)
		for toe in [-1.0, 0.0, 1.0]:
			_rod("Toe", Vector3(side * 0.095, 0.025, 0.06), Vector3(side * 0.095 + toe * 0.051, 0.016, 0.151), 0.009, yellow, root)
		var wing := _pivot("LeftWing" if side < 0 else "RightWing", Vector3(side * 0.153, 0.43, -0.027), root)
		wing.rotation.z = side * 0.13
		var wing_mesh := _round("Wing", Vector3(0.12, 0.24, 0.45), Vector3(side * 0.052, -0.07, -0.075), silver, wing)
		wing_mesh.rotation.x = -0.18
		for feather in range(3):
			var tip := _round("WingTip", Vector3(0.067, 0.078, 0.19), Vector3(side * (0.037 + float(feather) * 0.022), -0.075 - float(feather) * 0.037, -0.25 + float(feather) * 0.017), slate, wing)
			tip.rotation.x = -0.18
	for x in [-0.065, 0.0, 0.065]:
		var tail := _round("TailFeather", Vector3(0.1, 0.048, 0.22), Vector3(x, 0.345, -0.32), white, root)
		tail.rotation.x = 0.16
	var head := _pivot("Head", Vector3(0, 0.569, 0.145), root)
	_round("Face", Vector3(0.285, 0.285, 0.29), Vector3.ZERO, white, head)
	for side in [-1.0, 1.0]:
		_round("Eye", Vector3(0.03, 0.04, 0.027), Vector3(side * 0.084, 0.034, 0.116), ink, head)
		_round("EyeShine", Vector3.ONE * 0.01, Vector3(side * 0.084 - 0.005, 0.043, 0.129), white, head)
		_round("Cheek", Vector3(0.054, 0.03, 0.014), Vector3(side * 0.115, -0.025, 0.086), Color("#e6b8a4"), head)
	var beak := CylinderMesh.new()
	beak.top_radius = 0.013
	beak.bottom_radius = 0.061
	beak.height = 0.16
	beak.radial_segments = 6
	var bill := _mesh("Beak", beak, Vector3(0, -0.018, 0.171), yellow, head)
	bill.rotation.x = PI / 2.0
	bill.scale.z = 0.65
	_rod("BeakSeam", Vector3(-0.04, -0.018, 0.156), Vector3(0.04, -0.018, 0.156), 0.004, Color("#b38250"), head)

static func _pivot(label: String, pos: Vector3, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = pos
	parent.add_child(node)
	return node

static func _round(label: String, size: Vector3, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	if _round_mesh == null:
		_round_mesh = SphereMesh.new()
		_round_mesh.radius = 0.5
		_round_mesh.height = 1.0
		_round_mesh.radial_segments = 12
		_round_mesh.rings = 6
	var node := _mesh(label, _round_mesh, pos, color, parent)
	node.scale = size
	return node

static func _rod(label: String, a: Vector3, b: Vector3, radius: float, color: Color, parent: Node3D) -> MeshInstance3D:
	if _rod_mesh == null:
		_rod_mesh = CylinderMesh.new()
		_rod_mesh.top_radius = 1.0
		_rod_mesh.bottom_radius = 1.0
		_rod_mesh.height = 1.0
		_rod_mesh.radial_segments = 6
	var node := _mesh(label, _rod_mesh, (a + b) * 0.5, color, parent)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	node.scale = Vector3(radius, a.distance_to(b), radius)
	return node

static func _mesh(label: String, mesh: Mesh, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node, true)
	return node

static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.88
		_materials[key] = material
	return _materials[key]
