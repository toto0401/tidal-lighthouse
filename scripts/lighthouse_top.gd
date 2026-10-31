extends Node3D

const Layout := preload("res://data/lighthouse_layout.gd")

var exterior_only := false
var game: Node3D
var lens: MeshInstance3D
var lens_light: OmniLight3D
var lens_label: Label3D
const TEAL := Color("#507b7e")
const BRASS := Color("#d5b278")

func _ready() -> void:
	var floor_mesh: MeshInstance3D = game._add_cylinder("GalleryFloor",Layout.RADIUS,Layout.DECK_THICKNESS,Vector3(0,-Layout.DECK_THICKNESS * 0.5,0),Color("#dfd0b4"),not exterior_only,self)
	floor_mesh.mesh.bottom_radius = Layout.RADIUS
	game._add_torus("DeckRim",6.3,0.12,Vector3(0,0.03,0),TEAL,self)
	game._add_torus("GalleryRail",6.0,0.07,Vector3(0,1.3,0),TEAL,self)
	game._add_torus("GalleryLowerRail",6.0,0.045,Vector3(0,0.6,0),TEAL,self)
	for i in range(32):
		var angle := TAU * i / 32.0
		game._add_cylinder("RailPost",0.055,1.3,Vector3(cos(angle)*6,0.65,sin(angle)*6),TEAL,false,self)
		if exterior_only:
			continue
		var barrier := StaticBody3D.new()
		barrier.name = "BalconyBarrier"
		barrier.position = Vector3(cos(angle)*6.0,2.1,sin(angle)*6.0)
		barrier.rotation.y = -angle
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.18,4.2,1.3)
		shape.shape = box
		barrier.add_child(shape)
		add_child(barrier)
	# The gallery sits above the real lighthouse; the island supplies its view.
	game._add_cylinder("LensPedestal",0.85,0.9,Vector3(0,0.45,-1.2),TEAL,not exterior_only,self)
	game._add_cylinder("LensBase",1.05,0.14,Vector3(0,0.96,-1.2),BRASS,false,self)
	for y in [1.05,1.3,1.55,1.8,2.05,2.3]:
		game._add_torus("FresnelRing",0.85,0.045,Vector3(0,y,-1.2),Color("#a9d2cb"),self)
	for x in [-0.93,0.93]:
		game._add_cylinder("LensStrut",0.04,1.55,Vector3(x,1.66,-1.2),BRASS,false,self)
	game._add_cylinder("LensCap",1.05,0.13,Vector3(0,2.47,-1.2),TEAL,false,self)
	var glass_material: StandardMaterial3D = game._material(Color(0.49, 0.7, 0.7, 0.08), 0.25, 0.1, true)
	glass_material.cull_mode = BaseMaterial3D.CULL_BACK
	glass_material.render_priority = -1
	var glass: MeshInstance3D = game._add_cylinder("LanternRoom",1.12,1.5,Vector3(0,1.7,-1.2),glass_material,false,self)
	glass.mesh.bottom_radius = 1.12
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(8):
		var angle := TAU * (i + 0.5) / 8.0
		game._add_cylinder("LanternFrame",0.035,1.5,Vector3(sin(angle)*1.15,1.7,-1.2+cos(angle)*1.15),TEAL,false,self)
	var cap: MeshInstance3D = game._add_cylinder("PointedRoof",1.5,1.05,Vector3(0,3.0,-1.2),TEAL,false,self)
	cap.mesh.top_radius = 0.06
	cap.mesh.bottom_radius = 1.5
	game._add_torus("LanternEave",1.5,0.045,Vector3(0,2.48,-1.2),TEAL,self)
	game._add_cylinder("LanternFinial",0.035,0.42,Vector3(0,3.69,-1.2),BRASS,false,self)
	game._add_sphere("FinialPearl",0.07,Vector3(0,3.93,-1.2),BRASS,false,self)
	lens = game._add_sphere("LampCore",0.44,Vector3(0,1.72,-1.2),Color("#f7d395"),false,self)
	lens_light = OmniLight3D.new()
	lens_light.position = lens.position
	lens_light.light_color = Color("#ffe1a0")
	lens_light.omni_range = 13
	add_child(lens_light)
	if exterior_only:
		apply_beacon()
		return
	game.restoration_mesh = game._add_cylinder("RestorationPoint",0.6,0.08,Vector3(0,0.07,0.1),BRASS,false,self)
	game.restoration_mesh.add_to_group("interactable")
	game._add_torus("RestorationRing",0.85,0.05,Vector3(0,0.13,0.1),BRASS,self)
	lens_label = game._add_label_3d("修复灯芯 · E",Vector3(0,4.3,-1.2),Color("#fff0c2"),0.9,self)
	game._add_box("StairHatch",Vector3(1.8,0.08,1.35),Vector3(0,0.07,4.1),TEAL,false,self)
	for i in range(4):
		game._add_box("HatchSlat",Vector3(1.65,0.025,0.06),Vector3(0,0.13,3.64+i*0.29),BRASS,false,self)
	var stairs := Node3D.new()
	stairs.name = "TopStairs"
	stairs.position = Vector3(0,0.3,4.1)
	stairs.set_meta("destination","room")
	stairs.set_meta("travel_verb","下楼回到小屋")
	stairs.add_to_group("interactable")
	add_child(stairs)
	game._add_label_3d("下楼回小屋 · E",Vector3(0,1.5,4.1),Color("#fff0c2"),0.72,self)
	var launch := Node3D.new()
	launch.name = "GlideLaunch"
	launch.position = Vector3(4.3,0.3,0)
	launch.set_meta("glide_launch",true)
	launch.add_to_group("interactable")
	add_child(launch)
	game._add_box("LaunchMat",Vector3(1.7,0.035,2.1),Vector3(4.3,0.04,0),Color("#7caea3"),false,self)
	for z in [-0.35,0.35]:
		var arrow: MeshInstance3D = game._add_box("WindArrow",Vector3(0.75,0.015,0.09),Vector3(4.4,0.065,z),BRASS,false,self)
		arrow.rotation.y = PI/4.0 if z < 0 else -PI/4.0
	game._add_cylinder("WindsockPole",0.035,2.3,Vector3(5.1,1.15,-1.6),TEAL,false,self)
	var sock: MeshInstance3D = game._add_cylinder("Windsock",0.17,0.85,Vector3(5.4,2.3,-1.6),Color("#e3a18a"),false,self)
	sock.rotation.z = PI/2.0
	game._add_label_3d("乘风滑翔 · E",Vector3(4.3,2.7,-0.6),Color("#fff0c2"),0.72,self)
	apply_beacon()

func apply_beacon() -> void:
	var mat: StandardMaterial3D = lens.material_override
	mat.emission_enabled = game.repaired
	mat.emission = Color("#ffe0a0")
	mat.emission_energy_multiplier = 3.5
	lens_light.light_energy = 5.0 if game.repaired else 0.25
	if is_instance_valid(lens_label):
		lens_label.text = "灯芯已点亮 · E" if game.repaired else "修复灯芯 · E"
