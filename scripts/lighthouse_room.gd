extends Node3D

var game: Node3D
const WOOD := Color("#cbb393")
const CREAM := Color("#eee0c8")
const TEAL := Color("#567e7d")
const LAYOUTS := [
	[Vector3(-1,0.025,0.2), Vector3(-4.4,0.3,-1.2), Vector3(-4.4,1.0,-1.2), Vector3(-2.7,0.57,-0.5), Vector3(-1.1,0.46,-0.6)],
	[Vector3(-1,0.025,0.2), Vector3(-4.6,0.3,1.0), Vector3(-4.6,1.0,1.0), Vector3(-2.3,0.57,1.2), Vector3(-1,0.46,0.1)],
	[Vector3(-3,0.025,0.6), Vector3(-2.6,0.3,-3.8), Vector3(-2.6,1.0,-3.8), Vector3(-4.5,0.57,-0.2), Vector3(-4.4,0.46,1.2)],
]

func _ready() -> void:
	_build_shell()
	_build_furniture()
	_build_stairs()
	_portal("RoomExit", Vector3(0,0.3,4.5), "island", "走出灯塔")
	_portal("TowerStairs", Vector3(3.8,1.1,-3.1), "top", "沿楼梯登上塔顶")
	var work := Node3D.new()
	work.name = "RoomTrigger"
	work.position = Vector3(-3.6,0.5,2.6)
	work.add_to_group("interactable")
	add_child(work)
	game._add_label_3d("档案台 · 布置 E / B", Vector3(-3.6,1.9,2.6), CREAM, 0.65, self)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-2,3.8,0)
	lamp.light_color = Color("#ffe2aa")
	lamp.light_energy = 1.1
	lamp.omni_range = 11
	add_child(lamp)
	apply_layout(game.room_layout)

func _box(label: String, size: Vector3, pos: Vector3, color: Color, solid := false, parent: Node = null) -> MeshInstance3D:
	return game._add_box(label, size, pos, color, solid, self if parent == null else parent)

func _cylinder(label: String, radius: float, height: float, pos: Vector3, color: Color, solid := false, parent: Node = null) -> MeshInstance3D:
	return game._add_cylinder(label, radius, height, pos, color, solid, self if parent == null else parent)

func _build_shell() -> void:
	_box("RoomFloor", Vector3(12,0.3,10), Vector3(0,-0.15,0), WOOD, true)
	for i in range(25):
		_box("FloorSeam", Vector3(0.015,0.004,9.8), Vector3(-5.75 + i * 0.48,0.006,0), Color("#ac947b"))
	for x in range(-5,6,2):
		_box("BoardJoint", Vector3(0.45,0.005,0.015), Vector3(x,0.008,0.8 if x % 3 == 0 else -1.8), Color("#ac947b"))
	_box("BackWall", Vector3(12,3.4,0.25), Vector3(0,1.7,-5), CREAM, true)
	_box("LeftWall", Vector3(0.25,3.4,10), Vector3(-6,1.7,0), CREAM, true)
	# The near walls are cut away visually; full height collision keeps the room enclosed.
	for spec in [["FrontWall",Vector3(12,0.2,0.25),Vector3(0,0.1,5),Vector3(12,4,0.25)], ["RightWall",Vector3(0.25,0.2,10),Vector3(6,0.1,0),Vector3(0.25,4,10)]]:
		_box(spec[0], spec[1], spec[2], TEAL)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[3]
		shape.shape = box
		body.position = spec[2] + Vector3(0,1.9,0)
		body.add_child(shape)
		add_child(body)
	for x in [-5.8,-0.8,5.8]:
		_box("TimberPost",Vector3(0.16,3.6,0.28),Vector3(x,1.8,-4.85),TEAL)
	_box("CeilingBeam",Vector3(12.2,0.22,0.4),Vector3(0,3.45,-4.9),TEAL)
	_box("WallSkirting",Vector3(11.8,0.18,0.09),Vector3(0,0.14,-4.81),WOOD)
	# Sea-blue glass, gathered curtains and a wide window ledge.
	_box("WindowFrame",Vector3(3.1,1.85,0.2),Vector3(-3.2,2.1,-4.81),TEAL)
	var glass := _box("WindowGlass",Vector3(2.85,1.6,0.03),Vector3(-3.2,2.1,-4.68),Color("#9ac8cc"))
	glass.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x in [-4.65,-3.2,-1.75]:
		_box("WindowMullion",Vector3(0.075,1.65,0.07),Vector3(x,2.1,-4.62),CREAM)
	_box("WindowCrossbar",Vector3(2.9,0.065,0.07),Vector3(-3.2,2.1,-4.62),CREAM)
	_box("WindowLedge",Vector3(3.35,0.12,0.65),Vector3(-3.2,1.17,-4.62),WOOD)
	for x in [-4.85,-1.55]:
		for fold in range(3):
			_cylinder("CurtainFold",0.09,1.9,Vector3(x+fold*0.1,2.13,-4.5),Color("#dca99b"))
	_box("DoorMat",Vector3(1.9,0.025,1.0),Vector3(0,0.02,3.9),Color("#8daaa0"))
	game._add_label_3d("海岛出口 · E",Vector3(0,1.2,4.7),CREAM,0.7,self)

func _build_furniture() -> void:
	_box("BedFrame",Vector3(2.6,0.45,1.9),Vector3(-3.8,0.3,-3.1),TEAL,true)
	_box("Mattress",Vector3(2.5,0.22,1.8),Vector3(-3.8,0.63,-3.1),CREAM)
	_box("Quilt",Vector3(1.8,0.12,1.77),Vector3(-3.47,0.8,-3.1),Color("#cfaaa1"))
	_box("Pillow",Vector3(0.45,0.16,1.35),Vector3(-4.72,0.81,-3.1),Color("#fff0d8"))
	_box("Bookshelf",Vector3(1.5,2.1,0.45),Vector3(0.45,1.1,-4.6),WOOD,true)
	for y in [0.4,1.0,1.6,2.1]:
		_box("Shelf",Vector3(1.48,0.07,0.5),Vector3(0.45,y,-4.52),TEAL)
		if y < 2:
			for i in range(6):
				_box("Book",Vector3(0.14,0.36+i%2*0.08,0.26),Vector3(-0.08+i*0.18,y+0.23,-4.43),[Color("#c88676"),TEAL,Color("#d6c290")][i%3])
	game._build_archivist_desk(self)
	var desk := get_node("ArchiveDesk") as Node3D
	desk.position = Vector3(-3.7,0.12,2.7)
	for i in game.item_specs.size():
		var source: Node3D = game.world_node("Collectible_" + str(game.item_specs[i].id))
		var exhibit := source.get_children().filter(func(node): return node is MeshInstance3D)[0].duplicate() as Node3D
		exhibit.name = "ArchiveExhibit_" + str(game.item_specs[i].id)
		exhibit.position = Vector3(-1.0 + (i % 5) * 0.5,1.5,-0.35 + (i / 5) * 0.5)
		exhibit.scale *= 0.3
		exhibit.visible = game.discovered.has(game.item_specs[i].id)
		desk.add_child(exhibit)
		game.display_objects.append(exhibit)
	game.room_objects.append(_box("Rug",Vector3(3.8,0.035,2.5),Vector3.ZERO,Color("#e7a6a1")))
	game.room_objects.append(_cylinder("PlantPot",0.32,0.5,Vector3.ZERO,Color("#d37f70")))
	game.room_objects.append(game._add_sphere("Plant",0.52,Vector3.ZERO,Color("#7eb397"),false,self))
	var chair := _box("Chair",Vector3(0.85,0.2,0.85),Vector3.ZERO,Color("#8eb8b0"),true)
	game.room_objects.append(chair)
	_box("ChairBack",Vector3(0.85,0.62,0.12),Vector3(0,0.4,-0.36),WOOD,false,chair)
	for x in [-0.32,0.32]:
		for z in [-0.32,0.32]:
			_box("ChairLeg",Vector3(0.075,0.48,0.075),Vector3(x,-0.3,z),TEAL,false,chair)
	_box("Cushion",Vector3(0.72,0.09,0.72),Vector3(0,0.14,0),CREAM,false,chair)
	var table := _cylinder("TeaTable",0.55,0.8,Vector3.ZERO,CREAM,true)
	game.room_objects.append(table)
	_cylinder("TableTop",0.64,0.1,Vector3(0,0.36,0),WOOD,false,table)
	_cylinder("TeaCup",0.11,0.16,Vector3.ZERO,Color("#bbd7c9"))

func _build_stairs() -> void:
	const FIRST_TOP := 0.195
	const RISE := 0.23
	const RUN := 0.34
	const FRONT := -1.9
	var top := FIRST_TOP + 7 * RISE
	var last_nose := FRONT - 7 * RUN
	var back := last_nose - 0.4
	# Fill the risers visually; a continuous solid wedge supports the capsule
	# along the tread nosings so neither walking nor dashing catches on a riser.
	for i in range(8):
		var height := FIRST_TOP + i * RISE
		_box("StairTread",Vector3(1.9,height,0.4),Vector3(3.8,height * 0.5,-2.1-i*RUN),WOOD)
	var body := StaticBody3D.new()
	body.name = "StairBody"
	var collision := CollisionShape3D.new()
	var ramp := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for x in [2.85, 4.75]:
		points.append(Vector3(x, 0, FRONT + FIRST_TOP * RUN / RISE))
		points.append(Vector3(x, 0, back))
		points.append(Vector3(x, top, back))
		points.append(Vector3(x, top, last_nose))
	ramp.points = points
	collision.shape = ramp
	body.add_child(collision)
	add_child(body)
	for x in [2.75,4.85]:
		for i in [0, 2, 4, 6, 7]:
			var height: float = FIRST_TOP + i * RISE
			_cylinder("StairPost",0.055,1.0,Vector3(x,height+0.46,FRONT-i*RUN),TEAL,true)
		# Both rails have matching visible meshes and solid collision shapes.
		for rail_height in [0.42, 0.92]:
			_stair_rail(Vector3(x,FIRST_TOP+rail_height,FRONT), Vector3(x,top+rail_height,last_nose))
			_stair_rail(Vector3(x,top+rail_height,last_nose), Vector3(x,top+rail_height,back))
	game._add_label_3d("登上塔顶 · E",Vector3(3.7,2.8,-3.3),Color("#f7ddb0"),0.78,self)

func _stair_rail(from: Vector3, to: Vector3) -> void:
	# Rotate the parent so the rail's mesh and sibling collider stay aligned.
	var rail := Node3D.new()
	rail.name = "StairRail"
	add_child(rail)
	rail.position = (from + to) * 0.5
	rail.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	_box("Handrail", Vector3(0.10,from.distance_to(to),0.10), Vector3.ZERO, TEAL, true, rail)

func _portal(label: String, at: Vector3, destination: String, verb: String) -> void:
	var trigger := Node3D.new()
	trigger.name = label
	trigger.position = at
	trigger.set_meta("destination",destination)
	trigger.set_meta("travel_verb",verb)
	trigger.add_to_group("interactable")
	add_child(trigger)

func apply_layout(choice: int) -> void:
	for i in game.room_objects.size():
		var object: Node3D = game.room_objects[i]
		object.position = LAYOUTS[choice][i]
		var body := get_node_or_null(str(object.name) + "Body") as Node3D
		if body:
			body.position = object.position
	get_node("TeaCup").position = get_node("TeaTable").position + Vector3(0.25,0.5,0.1)
