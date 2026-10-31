extends Node3D

## 潮汐灯塔：探索、记录与海岛恢复。

const WATER_COLOR := Color("#75b7bb")
const NIGHT_WATER := Color("#54e6d5")
const PAPER := Color("#f5ead1")
const INK := Color("#263d4b")
const CORAL := Color("#e59683")
const SEAFOAM := Color("#bde8d6")
const SaveState := preload("res://save_state.gd")
const Catalog := preload("res://data/island_catalog.gd")
const IslandLife := preload("res://scripts/island_life.gd")
const IslandAnimals := preload("res://scripts/island_animals.gd")
const IslandMusic := preload("res://scripts/island_music.gd")
const DayNightCycle := preload("res://scripts/day_night_cycle.gd")
const GameMenus := preload("res://scripts/game_menus.gd")
const ExpandedIsland := preload("res://scripts/expanded_island.gd")
const ArchitectureArt := preload("res://scripts/architecture_art.gd")
const WaveDashEffects := preload("res://scripts/wave_dash_effects.gd")
const KeeperAppearance := preload("res://scripts/keeper_appearance.gd")
const IslandActivities := preload("res://scripts/island_activities.gd")
const WaterActivities := preload("res://scripts/water_activities.gd")
const PicnicRest := preload("res://scripts/picnic_rest.gd")
const LighthouseTravel := preload("res://scripts/lighthouse_travel.gd")
const LighthouseLayout := preload("res://data/lighthouse_layout.gd")
const Gliding := preload("res://scripts/gliding.gd")
const FishCatalog := preload("res://data/fish_catalog.gd")
const WATER_LEVEL := -0.4
const SWIM_HEIGHT := WATER_LEVEL + 0.22
const DASH_SPEED := 12.0
const DASH_DURATION := 0.65
const DASH_COOLDOWN := 1.5

var current_location := "island"
var locations: Node
var gliding: Node
var player: CharacterBody3D
var swimming := false
var water_activities: Node3D
var picnic_rest: Node
var fish_caught := {}
var keeper_appearance: RefCounted
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := 0.65
var camera_distance := 20.5
var camera_focus := Vector3.ZERO
var camera_dragging := false
var chinese_font: Font
var jump_requested := false
var dash_requested := false
var dash_remaining := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.ZERO
var dash_effects: Node3D
var dash_label: Label
var dash_meter: ProgressBar
var objective_label: Label
var save_label: Label
var ui_layer: CanvasLayer
var elapsed_time := 0.0
var chime: AudioStreamPlayer
var water_shader: ShaderMaterial
var display_objects: Array[Node3D] = []
var tide_low := true
var tide_blend := 1.0
var discovered := {}
var progress_path := "user://progress.cfg"
var last_backup_path := ""
var archive_count := 0
var repaired := false
var garden_repaired := false
var cove_repaired := false
var room_layout := 0
var player_palette := 0
var night := false
var day_night_cycle: Node
var audio_enabled := true
var music: Node
var island_life: Node3D
var animals: Node3D
var activities: Node3D
var menus: CanvasLayer
var expanded_island: Node3D
var last_ground_position := Vector3(0, 1.1, 4)
var controls_label: Label
var region_label: Label
var decoration_style := 0
var interact_target: Node3D
var interact_text := ""
var tide_label: Label
var archive_label: Label
var prompt_label: Label
var toast_label: Label
var archive_panel: PanelContainer
var archive_panel_label: Label
var shallow_water: MeshInstance3D
var shallow_material: StandardMaterial3D
var beacon_light: OmniLight3D
var beacon_mesh: MeshInstance3D
var beacon_sweep: Node3D
var beacon_beam_material: ShaderMaterial
var reply_mesh: MeshInstance3D
var reply_light: OmniLight3D
var restoration_mesh: MeshInstance3D
var room_objects: Array[Node3D] = []
var tide_tween: Tween
var toast_tween: Tween

var item_specs: Array = Catalog.ITEMS

func _ready() -> void:
	chinese_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf") as Font
	RenderingServer.set_default_clear_color(Color("#8ca9b7"))
	_setup_environment()
	_build_world()
	expanded_island = ExpandedIsland.new()
	expanded_island.name = "ExpandedIsland"
	add_child(expanded_island)
	var architecture := ArchitectureArt.new()
	architecture.name = "ArchitectureArt"
	add_child(architecture)
	_build_player()
	dash_effects = WaveDashEffects.new()
	dash_effects.name = "WaveDashEffects"
	add_child(dash_effects)
	_build_camera()
	_build_ui()
	water_activities = WaterActivities.new()
	water_activities.name = "WaterActivities"
	add_child(water_activities)
	gliding = Gliding.new()
	gliding.name = "Gliding"
	add_child(gliding)
	island_life = IslandLife.new()
	island_life.name = "IslandLife"
	add_child(island_life)
	animals = IslandAnimals.new()
	animals.name = "IslandAnimals"
	add_child(animals)
	activities = IslandActivities.new()
	activities.name = "IslandActivities"
	add_child(activities)
	picnic_rest = PicnicRest.new()
	picnic_rest.name = "PicnicRest"
	add_child(picnic_rest)
	locations = LighthouseTravel.new()
	locations.name = "LighthouseTravel"
	add_child(locations)
	locations.capture_island()
	day_night_cycle = DayNightCycle.new()
	day_night_cycle.name = "DayNightCycle"
	add_child(day_night_cycle)
	_restore_progress()
	music = IslandMusic.new()
	music.name = "IslandMusic"
	music.set_night(night, false)
	music.set_enabled(audio_enabled)
	add_child(music)
	_update_tide_visuals()
	_update_objective()
	island_life.apply_state()
	menus = GameMenus.new()
	menus.name = "GameMenus"
	add_child(menus)
	if not get_meta("test_mode", false) and not get_meta("skip_title", false):
		menus.open_title()
	_show_toast("欢迎回到潮汐灯塔\n你的档案和房间配色已保存" if archive_count > 0 else "潮汐档案馆 · 第一页\n先找灯塔东南边的漂流木，靠近后按 E")

func _physics_process(delta: float) -> void:
	day_night_cycle.update(delta)
	if menu_is_open():
		jump_requested = false
		gliding.requested = false
		cancel_dash()
		water_activities.cancel_fishing()
		picnic_rest.cancel_sip()
		return
	if picnic_rest.update(delta):
		return
	_update_player(delta)
	if current_location == "island":
		water_activities.update(delta)

func _process(delta: float) -> void:
	elapsed_time += delta
	if menu_is_open():
		prompt_label.text = ""
		_update_beacon(delta)
		return
	_update_camera(delta)
	_update_interaction()
	_update_beacon(delta)
	_update_region()
	if Input.is_action_just_pressed("toggle_tide"):
		_toggle_tide()
	if Input.is_action_just_pressed("decorate_one") and _near_lighthouse():
		_set_decoration(0)
	if Input.is_action_just_pressed("decorate_two") and _near_lighthouse():
		_set_decoration(1)
	if Input.is_action_just_pressed("decorate_three") and _near_lighthouse():
		_set_decoration(2)

func _input(event: InputEvent) -> void:
	if locations and locations.transitioning:
		return
	if menu_is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			if not menus.title_open:
				menus.back()
		return
	if picnic_rest.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		_update_interaction()
		if not water_activities.is_fishing():
			_interact()
		return
	if event.is_action_pressed("jump") and not event.is_echo():
		jump_requested = true
	if event.is_action_pressed("wave_dash") and not event.is_echo():
		dash_requested = true
	if event.is_action_pressed("glide") and not event.is_echo():
		gliding.requested = true
	if event.is_action_pressed("fish") and not event.is_echo() and current_location == "island":
		water_activities.fish_requested = true
	var max_camera_distance := 60.0 if current_location == "top" else 30.0
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			camera_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clampf(camera_distance - 1.3, 7.0, max_camera_distance)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clampf(camera_distance + 1.3, 7.0, max_camera_distance)
	elif event is InputEventMouseMotion and camera_dragging:
		camera_yaw -= event.relative.x * 0.005
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.004, 0.3, 1.22)
	elif event is InputEventPanGesture:
		camera_yaw -= event.delta.x * 0.04
		camera_pitch = clampf(camera_pitch + event.delta.y * 0.025, 0.3, 1.22)
	elif event is InputEventMagnifyGesture:
		camera_distance = clampf(camera_distance / maxf(event.factor, 0.01), 7.0, max_camera_distance)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			locations.reset_camera()
		elif event.physical_keycode == KEY_ESCAPE:
			camera_dragging = false
			menus.open_pause()
		elif event.physical_keycode == KEY_H:
			menus.open_help()
		elif event.physical_keycode == KEY_J:
			menus.open_archive()
		elif event.physical_keycode == KEY_TAB:
			menus.open_map()
		elif event.physical_keycode == KEY_B:
			menus.open_decor()
		elif event.physical_keycode == KEY_N:
			toggle_night()
		elif event.physical_keycode == KEY_V:
			set_player_palette((player_palette + 1) % 4)
		elif event.physical_keycode == KEY_M:
			toggle_audio()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_save_progress()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		camera_dragging = false
		jump_requested = false
		cancel_dash()
		if is_instance_valid(gliding):
			gliding.requested = false
			if gliding.active and is_instance_valid(menus) and not menu_is_open():
				menus.open_pause()
		if is_instance_valid(water_activities):
			water_activities.cancel_fishing()
		if is_instance_valid(picnic_rest):
			picnic_rest.cancel_sip()

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "IslandEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/island_sky.gdshader")
	sky_material.set_shader_parameter("night_amount", 0.0)
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.sky = sky
	environment.background_color = Color("#8ca9b7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#bfd8d5")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.72
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 0.9
	environment.ssao_light_affect = 0.12
	environment.glow_enabled = true
	environment.glow_intensity = 1.15
	environment.glow_bloom = 0.22
	environment.fog_enabled = true
	environment.fog_light_color = Color("#abc7c8")
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.15
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "WatercolorSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#ffe4bf")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	sun.light_angular_distance = 1.5
	add_child(sun)

func _build_world() -> void:
	# 岛屿底色，边缘用几块柔和的岩石压住平面感。
	_add_cylinder("Island", 17.0, 0.8, Vector3(0, -0.4, 0), Color("#d7c6a3"), true)
	var meadow_material := ShaderMaterial.new()
	meadow_material.shader = load("res://shaders/meadow.gdshader")
	_add_cylinder("Meadow", 15.6, 0.16, Vector3(0, 0.04, 0), meadow_material, true)
	_build_sandy_shore()
	# 发光浅海，低潮时显现。
	shallow_material = _material(NIGHT_WATER, 0.15, 0.12, true)
	shallow_material.emission_enabled = true
	shallow_material.emission = NIGHT_WATER
	shallow_material.emission_energy_multiplier = 1.8
	shallow_water = _add_cylinder("GlowingShallows", 11.0, 0.12, Vector3(0, 0.18, -13.0), shallow_material, false)
	shallow_water.hide()
	# 远海色带和潮汐线。
	# Cover the horizon even when looking out from the elevated gallery.
	var ocean := _add_box("Ocean", Vector3(2000.0, 0.2, 2000.0), Vector3(0, -0.5, 0), WATER_COLOR, false)
	water_shader = ShaderMaterial.new()
	water_shader.shader = load("res://shaders/tidal_water.gdshader")
	water_shader.set_shader_parameter("low_tide", 1.0)
	water_shader.set_shader_parameter("night_amount", 0.0)
	ocean.material_override = water_shader
	_build_lighthouse()
	for spec in item_specs:
		_build_collectible(spec)
	_build_scattered_details()
	_build_garden()

func _build_lighthouse() -> void:
	var tower := Node3D.new()
	tower.name = "Lighthouse"
	tower.position = LighthouseLayout.POSITION
	add_child(tower)
	var radius := LighthouseLayout.RADIUS
	_lighthouse_section("TowerFoundation", radius, radius, 0.0, LighthouseLayout.FOUNDATION_HEIGHT, Color("#cbbd9f"), tower, true)
	_lighthouse_section("Tower", LighthouseLayout.SHAFT_BOTTOM_RADIUS, LighthouseLayout.SHAFT_TOP_RADIUS, LighthouseLayout.FOUNDATION_HEIGHT, LighthouseLayout.SHAFT_TOP, _material(Color("#f3e4cc"), 0.92), tower, true)
	_lighthouse_section("TowerStripe", LighthouseLayout.shaft_radius(9.0) + 0.025, LighthouseLayout.shaft_radius(10.35) + 0.025, 9.0, 10.35, Color("#cf9a89"), tower)
	_lighthouse_section("GalleryCorbel", LighthouseLayout.SHAFT_TOP_RADIUS, radius, LighthouseLayout.SHAFT_TOP, LighthouseLayout.GALLERY_HEIGHT - LighthouseLayout.DECK_THICKNESS, Color("#e1d2b6"), tower, true)
	# Both views use the same lantern and railing geometry. The outside copy has
	# no interactions; upstairs loads the walkable scene at this exact position.
	var exterior = LighthouseTravel.TOP.instantiate()
	exterior.name = "ExteriorGallery"
	exterior.game = self
	exterior.exterior_only = true
	exterior.position.y = LighthouseLayout.GALLERY_HEIGHT
	tower.add_child(exterior)
	beacon_light = exterior.lens_light
	beacon_mesh = exterior.lens
	_build_beacon_sweep(tower)
	_add_box("Door", Vector3(1.2, 2.2, 0.28), LighthouseLayout.DOOR_POSITION, Color("#3b5660"), false)
	var entrance := Node3D.new()
	entrance.name = "TowerDoor"
	entrance.position = LighthouseLayout.ENTRANCE
	entrance.set_meta("destination", "room")
	entrance.set_meta("travel_verb", "进入灯塔小屋")
	entrance.add_to_group("interactable")
	add_child(entrance)
	_add_label_3d("进入灯塔 · E", entrance.position + Vector3(0, 2.0, -0.3), PAPER, 0.8)
	_add_label_3d("潮汐灯塔", LighthouseLayout.POSITION + Vector3(0, LighthouseLayout.GALLERY_HEIGHT + 4.4, 0), Color("#fff0cd"), 1.0).name = "LighthouseLabel"
	_add_cylinder("DistantBuoy", 0.45, 1.2, Vector3(13.0, 0.4, -19.0), Color("#749598"), false)
	var glow := _material(Color("#ffe8aa"))
	glow.emission_enabled = true
	glow.emission = Color("#ffe2a4")
	glow.emission_energy_multiplier = 2.5
	reply_mesh = _add_sphere("ReplyLight", 0.3, Vector3(13.0, 1.3, -19.0), glow, false)
	reply_mesh.hide()
	reply_light = OmniLight3D.new()
	reply_light.position = reply_mesh.position
	reply_light.light_color = Color("#ffe2a4")
	reply_light.omni_range = 8.0
	reply_light.light_energy = 0.0
	add_child(reply_light)

func _lighthouse_section(node_name: String, bottom_radius: float, top_radius: float, bottom: float, top: float, material: Variant, parent: Node3D, collision := false) -> MeshInstance3D:
	var section := _add_cylinder(node_name, top_radius, top - bottom, Vector3(0, (top + bottom) * 0.5, 0), material, collision, parent)
	section.mesh.bottom_radius = bottom_radius
	section.mesh.radial_segments = 48
	if collision and not is_equal_approx(bottom_radius, top_radius):
		# Fit the taper instead of leaving an invisible cylindrical wall around it.
		parent.get_node(node_name + "Body").get_child(0).shape = section.mesh.create_convex_shape()
	return section

func _build_sandy_shore() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		var a := PI + float(i) / 48.0 * PI
		var b := PI + float(i + 1) / 48.0 * PI
		var inner_a := 13.5 + sin(a * 5.0) * 0.4
		var inner_b := 13.5 + sin(b * 5.0) * 0.4
		var points := [Vector3(cos(a) * inner_a, 0.135, sin(a) * inner_a), Vector3(cos(a) * 16.9, 0.135, sin(a) * 16.9), Vector3(cos(b) * 16.9, 0.135, sin(b) * 16.9), Vector3(cos(b) * inner_b, 0.135, sin(b) * inner_b)]
		for j in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(points[j])
	var material := _material(Color("#ead9b7"))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_node(surface.commit(), "SandyShore", Vector3.ZERO, material)

func _build_archivist_desk(room: Node3D) -> void:
	var desk := Node3D.new()
	desk.name = "ArchiveDesk"
	# A compact desk against the back wall leaves the open front clear.
	desk.position = Vector3(-0.55, 0.12, -0.75)
	desk.scale = Vector3.ONE * 0.7
	room.add_child(desk)
	_add_box("DeskTop", Vector3(3.4, 0.18, 1.4), Vector3(0, 1.1, 0), Color("#9f7566"), true, desk)
	for x in [-1.2, 1.2]:
		_add_box("DeskLeg", Vector3(0.18, 1.1, 0.18), Vector3(x, 0.55, 0), Color("#76554f"), true, desk)
	_add_box("OpenBook", Vector3(1.9, 0.08, 0.95), Vector3(0, 1.24, 0), PAPER, false, desk)

func _build_collectible(spec: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Collectible_" + str(spec.id)
	area.position = spec.pos
	area.add_to_group("interactable")
	area.set_meta("collectible_id", spec.id)
	area.set_meta("collectible_name", spec.name)
	area.set_meta("collectible_hint", spec.hint)
	add_child(area)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.2
	shape.shape = sphere_shape
	area.add_child(shape)
	var mesh: Node3D
	if spec.id == "glass":
		mesh = _add_box("GlassShard", Vector3(0.42, 0.8, 0.2), Vector3.ZERO, spec.color, false, area)
		mesh.rotation_degrees = Vector3(0, 24, 12)
	elif spec.id == "shell":
		mesh = _add_torus("Shell", 0.42, 0.16, Vector3.ZERO, spec.color, area)
	elif spec.id in ["seed", "moss"]:
		mesh = _add_sphere("NaturalTreasure", 0.3, Vector3.ZERO, spec.color, false, area)
		mesh.scale = Vector3(0.8, 1.1, 0.9)
	elif spec.id in ["feather", "ribbon"]:
		mesh = _add_capsule("SoftTreasure", 0.13, 0.8, Vector3.ZERO, spec.color, false, area)
		mesh.rotation.z = -0.65
	elif spec.id == "stardust":
		var sparkle := _material(spec.color)
		sparkle.emission_enabled = true
		sparkle.emission = spec.color
		sparkle.emission_energy_multiplier = 1.3
		mesh = _add_cylinder("StardustBottle", 0.2, 0.65, Vector3.ZERO, sparkle, false, area)
	elif spec.id == "coral":
		mesh = _add_torus("CoralTreasure", 0.38, 0.15, Vector3.ZERO, spec.color, area)
		mesh.rotation.x = 0.8
	else:
		mesh = _add_box("Driftwood", Vector3(1.0, 0.2, 0.3), Vector3.ZERO, spec.color, false, area)
		mesh.rotation_degrees = Vector3(0, -28, 12)
	_add_label_3d(spec.name, Vector3(0, 1.15, 0), spec.color, 0.9, area)
	var halo := _add_torus("DiscoveryRing", 0.8, 0.055, Vector3(0, -0.42, 0), spec.color, area)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_scattered_details() -> void:
	for p in [Vector3(-11, 0.3, 8), Vector3(10, 0.25, 8), Vector3(9, 0.2, -9), Vector3(-9, 0.18, -9)]:
		_add_sphere("SoftRock", 0.7, p, _material(Color("#79979a"), 0.95), true)
	for p in [Vector3(10, 0.15, 1), Vector3(6, 0.15, 10), Vector3(-2, 0.15, -3)]:
		_add_cylinder("SeaGrass", 0.09, 0.9, p, _material(SEAFOAM, 0.9), false)
		_add_cylinder("SeaGrass2", 0.07, 0.65, p + Vector3(0.18, 0.06, 0.08), _material(Color("#87bba0"), 0.9), false)

func _build_garden() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 92417
	# 海边的小路从家门口蜿蜒到退潮的沙滩。
	for i in range(17):
		var z := 8.0 - i * 1.08
		var x := sin(i * 0.32) * 1.4 - 1.8
		var stone := _add_cylinder("PathStone", rng.randf_range(0.35, 0.62), 0.08, Vector3(x, 0.2, z), Color("#d8ccb0"), false)
		stone.scale.z = 0.65
		stone.rotation.y = rng.randf_range(-0.4, 0.4)
	for p in [Vector3(10.0, 0, 4.0), Vector3(7.8, 0, 9.0), Vector3(-11.0, 0, -3.0), Vector3(9.0, 0, -4.5)]:
		var trunk := _add_cylinder("WindTreeTrunk", 0.18, 2.3, p + Vector3(0, 1.25, 0), Color("#8a7669"), false)
		trunk.rotation.z = 0.12
		for j in range(3):
			var canopy := _add_sphere("WindTreeCrown", 1.0, p + Vector3((j - 1) * 0.7, 2.7 + j * 0.23, 0), Color("#769b8c") if j % 2 == 0 else Color("#a0b89a"), false)
			canopy.scale = Vector3(1.2, 0.7, 0.85)
	for i in range(72):
		var p := Vector3(rng.randf_range(-13.5, 13.5), 0.17, rng.randf_range(-9.5, 12.0))
		if Vector2(p.x, p.z).length() > 13.8 or p.distance_to(Vector3(-7.5, 0, 7)) < 4.7 or absf(p.x) < 2.5:
			continue
		var stem := _add_cylinder("FlowerStem", 0.035, 0.4, p + Vector3(0, 0.15, 0), Color("#5d866e"), false)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var colors := [Color("#e5b0ad"), Color("#e8d9b2"), Color("#b1bdcf")]
		var flower := _add_sphere("Wildflower", 0.12, p + Vector3(0, 0.4, 0), colors[i % 3], false)
		flower.scale.y = 0.6
		flower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 岸边的岩石打散轮廓，木码头与暖灯引导归途。
	for i in range(18):
		var angle := float(i) / 18.0 * TAU
		var p := Vector3(cos(angle) * 16.3, -0.15, sin(angle) * 16.3)
		var rock := _add_sphere("CoastalRock", rng.randf_range(0.55, 0.95), p, Color("#799799"), false)
		rock.scale = Vector3(1.25, 0.6, 0.8)
	for i in range(8):
		_add_box("JettyPlank", Vector3(2.2, 0.12, 0.45), Vector3(4.5, 0.26, -8.6 - i * 0.55), Color("#b49480"), false)
	for p in [Vector3(3.4, 0.8, -8.6), Vector3(5.6, 0.8, -8.6), Vector3(3.4, 0.8, -11.9), Vector3(5.6, 0.8, -11.9)]:
		_add_cylinder("JettyPost", 0.11, 1.4, p, Color("#8e7466"), false)
	for p in [Vector3(-3, 0, 3), Vector3(0.4, 0, -2.5), Vector3(3.3, 0, -8.6)]:
		_add_cylinder("LanternPole", 0.055, 1.65, p + Vector3(0, 0.9, 0), Color("#55757b"), false)
		var lantern_material := _material(Color("#ffe6ac"))
		lantern_material.emission_enabled = true
		lantern_material.emission = Color("#ffd5a0")
		lantern_material.emission_energy_multiplier = 0.8
		_add_sphere("WarmLantern", 0.2, p + Vector3(0, 1.8, 0), lantern_material, false)
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, 1.8, 0)
		light.light_color = Color("#ffd6a3")
		light.light_energy = 0.65
		light.omni_range = 3.5
		add_child(light)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.1, 4.0)
	player.floor_snap_length = 0.3
	player.floor_stop_on_slope = true
	player.safe_margin = 0.025
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.55
	collision.shape = capsule
	player.add_child(collision)
	keeper_appearance = KeeperAppearance.new()
	keeper_appearance.build(player)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "WatercolorCamera"
	add_child(camera)
	camera_focus = player.position + Vector3(0, 0.6, 0)
	camera.position = camera_focus + Vector3(0, sin(camera_pitch), cos(camera_pitch)) * camera_distance
	camera.look_at(camera_focus, Vector3.UP)
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	ui_layer = layer
	add_child(layer)
	for rect in [Rect2(28, 122, 342, 94), Rect2(28, 646, 420, 46)]:
		var paper := ColorRect.new()
		paper.color = Color(0.96, 0.92, 0.84, 0.86)
		paper.position = rect.position
		paper.size = rect.size
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(paper)
		if rect.position.y > 600:
			_pin_ui(paper, Control.PRESET_BOTTOM_LEFT, Rect2(28, -74, 420, 46))
	var top := ColorRect.new()
	top.color = Color(0.08, 0.15, 0.19, 0.72)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(28, 26)
	top.size = Vector2(342, 84)
	layer.add_child(top)
	tide_label = _ui_label(layer, "退潮 · 白昼", Vector2(46, 36), Vector2(306, 30), 21, Color("#d5fff1"))
	archive_label = _ui_label(layer, "档案 0 / 9", Vector2(46, 74), Vector2(306, 24), 15, Color("#f5ead1"))
	prompt_label = _ui_label(layer, "", Vector2.ZERO, Vector2(500, 38), 20, PAPER)
	_pin_ui(prompt_label, Control.PRESET_CENTER_BOTTOM, Rect2(-250, -130, 500, 38))
	prompt_label.add_theme_color_override("font_shadow_color", Color("#263d4b"))
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _ui_label(layer, "", Vector2(440, 70), Vector2(400, 74), 20, Color("#fff0d1"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pin_ui(toast_label, Control.PRESET_CENTER_TOP, Rect2(-220, 72, 440, 90))
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.08, 0.22, 0.26, 0.90)
	toast_style.set_corner_radius_all(10)
	toast_style.content_margin_left = 12
	toast_style.content_margin_right = 12
	toast_style.content_margin_top = 8
	toast_style.content_margin_bottom = 8
	toast_label.add_theme_stylebox_override("normal", toast_style)
	region_label = _ui_label(layer, "灯塔主岛  ·  Tab 海岛地图", Vector2(440, 30), Vector2(430, 32), 18, PAPER)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.16, 0.2, 0.8))
	region_label.add_theme_constant_override("shadow_offset_y", 2)
	_pin_ui(region_label, Control.PRESET_TOP_RIGHT, Rect2(-358, 28, 330, 32))
	archive_panel = PanelContainer.new()
	archive_panel.position = Vector2(962, 28)
	archive_panel.size = Vector2(290, 204)
	archive_panel.visible = false
	layer.add_child(archive_panel)
	archive_panel_label = Label.new()
	archive_panel_label.add_theme_font_override("font", chinese_font)
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color("#f5ead1eF")
	paper_style.content_margin_left = 22
	paper_style.content_margin_right = 22
	paper_style.content_margin_top = 18
	paper_style.content_margin_bottom = 18
	paper_style.set_corner_radius_all(10)
	archive_panel.add_theme_stylebox_override("panel", paper_style)
	archive_panel_label.add_theme_font_size_override("font_size", 16)
	archive_panel_label.add_theme_color_override("font_color", INK)
	archive_panel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	archive_panel.add_child(archive_panel_label)
	_update_archive_panel()
	objective_label = _ui_label(layer, "", Vector2(46, 136), Vector2(306, 68), 17, INK)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label = _ui_label(layer, "进度自动保存", Vector2(1020, 618), Vector2(230, 30), 14, INK)
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pin_ui(save_label, Control.PRESET_TOP_RIGHT, Rect2(-288, 68, 260, 26))
	save_label.add_theme_color_override("font_color", PAPER)
	save_label.add_theme_color_override("font_shadow_color", INK)
	save_label.add_theme_constant_override("shadow_offset_y", 2)
	var controls := _ui_label(layer, "WASD 移动 · 空格 跳 · E 互动 · F 钓鱼", Vector2.ZERO, Vector2(388, 30), 16, INK)
	controls_label = controls
	_pin_ui(controls, Control.PRESET_BOTTOM_LEFT, Rect2(44, -66, 388, 30))
	controls.modulate = Color(1, 1, 1, 0.82)
	var dash_panel := ColorRect.new()
	dash_panel.color = Color(0.08, 0.22, 0.26, 0.86)
	dash_panel.position = Vector2(28, 530)
	dash_panel.size = Vector2(250, 62)
	dash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dash_panel)
	_pin_ui(dash_panel, Control.PRESET_BOTTOM_LEFT, Rect2(28, -148, 250, 62))
	dash_label = _ui_label(layer, "Shift  踏浪冲刺 · 就绪", Vector2(42, 537), Vector2(224, 28), 17, Color("#dbfff5"))
	_pin_ui(dash_label, Control.PRESET_BOTTOM_LEFT, Rect2(42, -141, 224, 28))
	dash_meter = ProgressBar.new()
	dash_meter.position = Vector2(42, 574)
	dash_meter.max_value = 1.0
	dash_meter.value = 1.0
	dash_meter.show_percentage = false
	dash_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var meter_background := StyleBoxFlat.new()
	meter_background.bg_color = Color("#426365")
	meter_background.set_corner_radius_all(3)
	dash_meter.add_theme_stylebox_override("background", meter_background)
	var meter_fill := StyleBoxFlat.new()
	meter_fill.bg_color = Color("#8af5e0")
	meter_fill.set_corner_radius_all(3)
	dash_meter.add_theme_stylebox_override("fill", meter_fill)
	layer.add_child(dash_meter)
	dash_meter.size = Vector2(222, 5)
	_pin_ui(dash_meter, Control.PRESET_BOTTOM_LEFT, Rect2(42, -104, 222, 5))
	var help_button := Button.new()
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.text = "操作说明 H"
	help_button.position = Vector2(1110, 665)
	help_button.size = Vector2(142, 36)
	help_button.add_theme_font_override("font", chinese_font)
	help_button.pressed.connect(func(): menus.open_help())
	layer.add_child(help_button)
	_pin_ui(help_button, Control.PRESET_BOTTOM_RIGHT, Rect2(-170, -74, 142, 46))
	var journal_button := Button.new()
	journal_button.text = "潮汐手账 J"
	journal_button.focus_mode = Control.FOCUS_NONE
	journal_button.add_theme_font_override("font", chinese_font)
	journal_button.pressed.connect(func(): menus.open_archive())
	layer.add_child(journal_button)
	_pin_ui(journal_button, Control.PRESET_BOTTOM_RIGHT, Rect2(-328, -74, 142, 46))
	chime = AudioStreamPlayer.new()
	chime.volume_db = -15.0
	add_child(chime)

func _pin_ui(control: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _ui_label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", chinese_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _update_player(delta: float) -> void:
	if not player:
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_right := camera.global_basis.x if camera else Vector3.RIGHT
	var camera_back := camera.global_basis.z if camera else Vector3.BACK
	camera_right.y = 0.0
	camera_back.y = 0.0
	var direction := camera_right.normalized() * input_vec.x + camera_back.normalized() * input_vec.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	if not direction.is_zero_approx() or jump_requested or dash_requested:
		water_activities.cancel_fishing()
	if current_location != "island" or player.is_on_floor():
		swimming = false
	elif player.position.y <= SWIM_HEIGHT + 0.12 and player.velocity.y <= 0.0:
		if not swimming:
			water_activities.cancel_fishing()
		swimming = true
	gliding.prepare(delta, direction)
	player.floor_snap_length = 0.0 if swimming or gliding.active else 0.3
	if dash_remaining <= 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
	# Space stops a dash; a new dash can start on land or while afloat.
	if jump_requested:
		cancel_dash()
	if dash_requested and dash_cooldown <= 0.0 and (player.is_on_floor() or swimming) and not jump_requested:
		dash_direction = direction.normalized() if direction.length_squared() > 0.01 else player.global_basis.z
		dash_direction.y = 0.0
		dash_direction = dash_direction.normalized()
		dash_remaining = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		dash_effects.begin_wave(_dash_surface_position(), dash_direction)
		_play_chime(880.0, 0.35)
	dash_requested = false
	var speed := 2.5 if swimming else 2.8
	var acceleration := 10.0 if not input_vec.is_zero_approx() else 14.0
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(Vector2(direction.x, direction.z) * speed, acceleration * delta)
	if dash_remaining > 0.0:
		direction = dash_direction
		horizontal_velocity = Vector2(direction.x, direction.z) * DASH_SPEED
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.y
	if gliding.active:
		gliding.apply_velocity(delta)
	elif swimming:
		var surface := SWIM_HEIGHT + sin(elapsed_time * 2.8) * 0.035
		player.velocity.y = clampf((surface - player.position.y) * 8.0, -2.0, 3.0)
	elif player.is_on_floor():
		player.velocity.y = minf(player.velocity.y, 0.0)
	else:
		player.velocity.y = maxf(player.velocity.y - 18.0 * delta, -30.0)
	if jump_requested and player.is_on_floor():
		player.velocity.y = 6.2
	jump_requested = false
	if gliding.active:
		direction = gliding.heading
		horizontal_velocity = Vector2(player.velocity.x, player.velocity.z)
	player.move_and_slide()
	gliding.after_move()
	var climbed_shore := false
	if swimming and player.is_on_wall() and direction.length_squared() > 0.01:
		climbed_shore = _try_leave_water(direction.normalized())
	if dash_remaining > 0.0:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		if (player.is_on_wall() and not climbed_shore) or dash_remaining <= 0.0:
			# Also remove dash momentum, so releasing Shift never leaves a fast glide.
			cancel_dash()
			player.velocity.x = 0.0
			player.velocity.z = 0.0
	if player.is_on_floor():
		swimming = false
		last_ground_position = player.position
	elif player.position.y < -3.0:
		cancel_dash()
		gliding.cancel()
		player.position = last_ground_position + Vector3(0, 0.2, 0)
		player.velocity = Vector3.ZERO
	if direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(direction.x, direction.z), delta * 10.0)
	keeper_appearance.animate(delta, horizontal_velocity.length(), player.is_on_floor(), dash_remaining > 0.0, swimming, water_activities.is_fishing())
	if gliding.active:
		keeper_appearance.animate_gliding(gliding.bank)
	dash_effects.update_wave(delta, _dash_surface_position(), dash_direction, dash_remaining > 0.0)
	# Keep the sea under the camera even when exploring far beyond the islands.
	if current_location == "island":
		world_node("Ocean").position.x = player.position.x
		world_node("Ocean").position.z = player.position.z
	_update_dash_hud()

func _dash_surface_position() -> Vector3:
	return Vector3(player.position.x, maxf(player.position.y - 0.7, WATER_LEVEL + 0.04), player.position.z)

func _try_leave_water(direction: Vector3) -> bool:
	# Climb only the low island/bridge rim, with a clear capsule sweep above it.
	# Buildings and scenery remain solid and can never be used as shore steps.
	var ahead := player.position + direction * 0.8
	var query := PhysicsRayQueryParameters3D.create(Vector3(ahead.x, 1.0, ahead.z), Vector3(ahead.x, WATER_LEVEL, ahead.z))
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.is_in_group("shore_floor") or hit.normal.y < 0.9:
		return false
	var raised := player.global_transform
	raised.origin.y = hit.position.y + 0.81
	if player.test_move(raised, direction * 0.8):
		return false
	player.global_transform = raised
	player.move_and_collide(direction * 0.8)
	player.velocity.y = 0.0
	swimming = false
	player.floor_snap_length = 0.3
	player.apply_floor_snap()
	return true

func cancel_dash() -> void:
	dash_requested = false
	if dash_remaining > 0.0 and is_instance_valid(player):
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	dash_remaining = 0.0
	if is_instance_valid(dash_effects):
		dash_effects.stop_wave()

func _update_dash_hud() -> void:
	if not dash_label:
		return
	if gliding and gliding.active:
		dash_label.text = "G 收翼 · 滑翔中"
		dash_meter.value = 1.0
		return
	if picnic_rest and picnic_rest.is_seated():
		dash_label.text = "茶席小憩 · 海风正好"
		dash_meter.value = 1.0
		return
	if dash_remaining > 0.0:
		dash_label.text = "水上冲刺 · 踏浪中" if swimming else "踏浪中 · 海风正好"
		dash_meter.value = dash_remaining / DASH_DURATION
	elif dash_cooldown > 0.0:
		dash_label.text = "踏浪蓄能 · %.1f 秒" % dash_cooldown
		dash_meter.value = 1.0 - dash_cooldown / DASH_COOLDOWN
	else:
		dash_label.text = "Shift  水上冲刺 · 就绪" if swimming else "Shift  踏浪冲刺 · 就绪"
		dash_meter.value = 1.0

func _update_camera(delta: float) -> void:
	if not camera or not player:
		return
	var orbit_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	camera_yaw -= orbit_input.x * delta * 1.35
	camera_pitch = clampf(camera_pitch + orbit_input.y * delta * 0.8, 0.3, 1.22)
	var target := player.position + Vector3(0, 0.6, 0)
	if current_location == "room":
		camera_yaw = clampf(camera_yaw, -0.45, 0.45)
		camera_pitch = clampf(camera_pitch, 0.7, 1.1)
		camera_distance = clampf(camera_distance, 12, 23)
		target = Vector3(0, 0.7, 0).lerp(target, 0.12)
	camera_focus = target if delta == 0.0 else camera_focus.lerp(target, 1.0 - exp(-8.0 * delta))
	var offset := Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch)) * camera_distance
	var desired := camera_focus + offset
	if current_location != "island":
		camera.position = desired
		camera.look_at(camera_focus, Vector3.UP)
		return
	var query := PhysicsRayQueryParameters3D.create(camera_focus, desired)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	camera.position = hit.position + hit.normal * 0.25 if not hit.is_empty() else desired
	camera.look_at(camera_focus, Vector3.UP)

func _update_interaction() -> void:
	interact_target = null
	interact_text = ""
	if gliding.active:
		prompt_label.text = "前方是远海 · 已转向海岛" if gliding.at_boundary else "WASD 转向 · G / 空格 收翼"
		return
	if picnic_rest and picnic_rest.is_seated():
		prompt_label.text = picnic_rest.prompt()
		return
	var best_distance := 2.6
	var best_priority := 2
	for node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		if current_location == "top" and not locations.active_scene.is_ancestor_of(node):
			continue
		var is_animal := node.has_meta("animal_kind")
		if is_animal and not animals.can_interact(node):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		# Story objects, doors and activities remain easy to select near wildlife.
		var priority := 1 if is_animal else 0
		if distance < 2.6 and (priority < best_priority or (priority == best_priority and distance < best_distance)):
			best_distance = distance
			best_priority = priority
			interact_target = node
			if node.has_meta("collectible_id"):
				interact_text = "E 记录「%s」" % node.get_meta("collectible_name")
			elif node.has_meta("destination"):
				interact_text = "E " + str(node.get_meta("travel_verb"))
			elif node.has_meta("glide_launch"):
				interact_text = "E 乘风滑翔 · 飞回海岛"
			elif node.has_meta("activity_id"):
				interact_text = "E " + str(node.get_meta("activity_verb"))
			elif node.has_meta("picnic_seat") or node.has_meta("picnic_table"):
				interact_text = "E 坐下喝茶" if player.is_on_floor() and not swimming else "落地后按 E 坐下喝茶"
			elif node.has_meta("zone"):
				interact_text = "E 看看风铃花园" if node.get_meta("zone") == "garden" else "E 看看星砂海湾"
			elif node.has_meta("seal"):
				interact_text = "E 摸摸雾团"
			elif is_animal:
				interact_text = "E " + ("摸摸" if node.get_meta("animal_kind") == "rabbit" else "和它打招呼 · ") + str(node.get_meta("animal_name"))
			elif node.has_meta("scenic_name"):
				interact_text = "E 看看「%s」" % node.get_meta("scenic_name")
			elif node.name == "RestorationPoint":
				interact_text = "E 看看点亮的灯芯" if repaired else "E 修复灯芯" if Catalog.has_all(discovered, Catalog.LIGHTHOUSE_IDS) else "E 查看灯芯需要的档案"
			elif node.name == "RoomTrigger":
				interact_text = "E 布置灯塔小屋"
	var fishing_prompt: String = water_activities.prompt()
	if water_activities.is_fishing():
		prompt_label.text = fishing_prompt
	else:
		prompt_label.text = interact_text + ("  ·  " if not interact_text.is_empty() and not fishing_prompt.is_empty() else "") + fishing_prompt

func _interact() -> void:
	if menu_is_open() or gliding.active or not is_instance_valid(interact_target) or not interact_target.is_visible_in_tree():
		return
	if current_location == "top" and not locations.active_scene.is_ancestor_of(interact_target):
		return
	if player.global_position.distance_to(interact_target.global_position) >= 2.6:
		return
	if interact_target.has_meta("glide_launch"):
		locations.request("island", true)
		return
	if interact_target.has_meta("picnic_seat") or interact_target.has_meta("picnic_table"):
		picnic_rest.sit(interact_target)
		return
	if interact_target.has_meta("animal_kind"):
		animals.interact(interact_target)
		return
	if interact_target.has_meta("destination"):
		locations.request(str(interact_target.get_meta("destination")))
		return
	if interact_target.has_meta("activity_id"):
		activities.open_activity(str(interact_target.get_meta("activity_id")))
		return
	if interact_target.has_meta("collectible_id"):
		var item_id: String = interact_target.get_meta("collectible_id")
		var spec: Dictionary = {}
		for candidate in item_specs:
			if candidate.id == item_id:
				spec = candidate
		if spec.is_empty() or not Catalog.available(spec, restoration_stage(), tide_low, night) or discovered.has(item_id):
			return
		discovered[item_id] = true
		archive_count = discovered.size()
		interact_target.hide()
		_show_toast("已记录：%s\n%s" % [spec.name, spec.hint])
		_play_chime(660.0 + (archive_count % 4) * 110.0)
	elif interact_target.name == "RestorationPoint":
		if current_location != "top":
			return
		if repaired:
			_show_toast("灯芯已经点亮\n这束光会一直陪着这座岛")
		elif Catalog.has_all(discovered, Catalog.LIGHTHOUSE_IDS):
			repaired = true
			_apply_lighthouse()
			_show_toast("第一束光 · 灯塔亮了\n新的遗物来到岸边，去恢复风铃花园吧")
			_play_chime(523.25, 1.8)
		else:
			_show_toast("灯芯需要三页档案\n漂流木、月光海玻璃与回声贝壳。按 J 查看。")
	elif interact_target.has_meta("zone"):
		var zone: String = interact_target.get_meta("zone")
		if zone == "garden":
			if garden_repaired:
				_show_toast("花园在风里轻轻摇晃\n每一朵花，都记得你。")
			elif repaired and Catalog.has_all(discovered, Catalog.GARDEN_IDS):
				garden_repaired = true
				island_life.apply_state(true)
				_show_toast("风铃花园 · 重新开花\n去寻找海湾的三件遗物，等待雾团回家。")
				_play_chime(783.99, 1.8)
			else:
				_show_toast("先点亮灯塔，再恢复花园\n记录风铃种子、银白羽毛和苔绿圆石。")
		elif zone == "cove":
			if cove_repaired:
				_show_toast("星砂海湾 · 欢迎回家\n雾团喜欢在码头附近陪你散步。")
			elif garden_repaired and Catalog.has_all(discovered, Catalog.COVE_IDS):
				cove_repaired = true
				island_life.apply_state(true)
				_play_chime(1046.5, 2.0)
				_show_ending()
			else:
				_show_toast("先恢复花园，再唤醒海湾\n记录海蓝缎带、珊瑚乐片和夜里的星砂小瓶。")
	elif interact_target.has_meta("seal"):
		island_life.greet_seal()
		_show_toast("雾团蹭了蹭你的手\n它已经把这里当作家了。")
		_play_chime(392.0)
	elif interact_target.has_meta("scenic_name"):
		_show_toast(str(interact_target.get_meta("scenic_name")) + "\n" + str(interact_target.get_meta("scenic_hint")))
		_play_chime(587.33)
	elif interact_target.name == "RoomTrigger":
		menus.open_decor()
	_update_archive_panel()
	_update_tide_visuals()
	_update_objective()
	_save_progress()

func _toggle_tide() -> void:
	tide_low = not tide_low
	_update_tide_visuals()
	_update_objective()
	_save_progress()
	_show_toast("退潮：浅海发光，海岸遗物显露" if tide_low else "涨潮：海面收拢，灯塔倒映在水里")

func _update_tide_visuals() -> void:
	if not shallow_water:
		return
	if tide_tween:
		tide_tween.kill()
	tide_tween = create_tween().set_parallel(true)
	var target_alpha := 0.82 if tide_low else 0.38
	var target_emission := 1.8 if tide_low else 0.22
	tide_tween.tween_property(shallow_material, "albedo_color", Color(NIGHT_WATER, target_alpha), 0.8)
	tide_tween.tween_property(shallow_material, "emission_energy_multiplier", target_emission, 0.8)
	tide_label.text = ("退潮" if tide_low else "涨潮") + " · " + ("月夜" if night else "白昼") + " · 自动昼夜"
	if water_shader:
		tide_tween.tween_property(water_shader, "shader_parameter/low_tide", 1.0 if tide_low else 0.0, 1.2)
	for spec in item_specs:
		var item := world_node("Collectible_" + str(spec.id)) as Node3D
		if item:
			item.visible = not discovered.has(spec.id) and Catalog.available(spec, restoration_stage(), tide_low, night)

func _build_beacon_sweep(tower: Node3D) -> void:
	beacon_sweep = Node3D.new()
	beacon_sweep.name = "BeaconSweep"
	beacon_sweep.position = Vector3(0, LighthouseLayout.GALLERY_HEIGHT, 0) + LighthouseLayout.LAMP_OFFSET
	beacon_sweep.visible = false
	tower.add_child(beacon_sweep)
	beacon_beam_material = ShaderMaterial.new()
	beacon_beam_material.shader = preload("res://shaders/beacon_beam.gdshader")
	# A soft, depth-tested cone makes the light visible in clear air, without
	# requiring volumetric fog across the entire island.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 2.2
	cone.height = 24.0
	cone.radial_segments = 48
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := _mesh_node(cone, "LightBeam", Vector3(12, 0, 0), beacon_beam_material, false, beacon_sweep)
	beam.rotation.z = PI / 2.0
	beam.scale.x = 0.65
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spot := SpotLight3D.new()
	spot.name = "SweepingLight"
	spot.rotation.y = -PI / 2.0
	spot.light_color = Color("#ffe2a4")
	spot.light_energy = 3.0
	spot.spot_range = 26.0
	spot.spot_angle = 7.0
	spot.shadow_enabled = true
	beacon_sweep.add_child(spot)

func _update_beacon(delta: float) -> void:
	if beacon_mesh:
		beacon_mesh.rotation.y += delta * (1.0 if repaired else 0.45)
		var glow := beacon_mesh.material_override as StandardMaterial3D
		glow.emission_enabled = repaired
		glow.emission = Color("#ffdf93")
		glow.emission_energy_multiplier = 2.0
	if beacon_sweep:
		beacon_sweep.visible = repaired
		if repaired and current_location == "island" and not menu_is_open():
			beacon_sweep.rotation.y = fposmod(beacon_sweep.rotation.y + delta * 0.24, TAU)
		beacon_beam_material.set_shader_parameter("strength", 0.32 if night else 0.2)
	if reply_mesh:
		reply_mesh.visible = repaired
		reply_light.light_energy = 2.0 if repaired else 0.0

func _near_lighthouse() -> bool:
	return current_location == "room" and not locations.transitioning

func menu_is_open() -> bool:
	return (is_instance_valid(locations) and locations.transitioning) or (is_instance_valid(menus) and menus.is_open())

func _update_region() -> void:
	if not region_label:
		return
	controls_label.text = "WASD 移动 · 空格 跳 · E 互动 · F 钓鱼" if current_location == "island" else "WASD 移动 · E 门 / 楼梯 · B 布置" if current_location == "room" else "WASD 移动 · E 灯芯 / 下楼 / 起飞"
	if gliding.active:
		controls_label.text = "WASD 转向 · G 收翼 · Tab 地图"
	elif current_location == "island" and not player.is_on_floor() and not swimming:
		controls_label.text = "WASD 移动 · G 高处滑翔"
	if picnic_rest and picnic_rest.is_seated():
		controls_label.text = "F 喝茶 · E / WASD 起身 · J 手账"
	if current_location != "island":
		region_label.text = ("灯塔一层 · 你的小屋" if current_location == "room" else "灯塔顶层 · 灯室") + "  ·  E 门 / 楼梯"
		return
	var location := Vector2(player.position.x, player.position.z)
	var region := "灯塔主岛"
	if location.distance_to(Vector2(-31,-5)) < 14.5:
		region = "月贝沙洲"
	elif location.distance_to(Vector2(32,2)) < 16.5:
		region = "绣球花岛"
	elif location.distance_to(Vector2(0,-36)) < 13.5:
		region = "观星岬"
	elif location.length() > 17:
		region = "海风木桥"
	if swimming:
		region = "自由海域"
	elif gliding.active:
		region += "上空"
	region_label.text = region + "  ·  Tab 海岛地图"

func return_home() -> void:
	gliding.cancel()
	picnic_rest.leave(false)
	locations.return_to_island()
	cancel_dash()
	water_activities.cancel_fishing()
	swimming = false
	dash_effects.clear_trail()
	player.position = Vector3(0.6, 1.1, 5.5)
	player.velocity = Vector3.ZERO
	jump_requested = false
	last_ground_position = player.position
	camera_focus = player.position + Vector3(0, 0.6, 0)
	_show_toast("回到灯塔\n海风把你送回熟悉的地方。")

func world_node(node_name: String) -> Node:
	var found := get_node_or_null(NodePath(node_name))
	if found:
		return found
	if is_instance_valid(locations):
		if is_instance_valid(locations.active_scene):
			found = locations.active_scene.get_node_or_null(NodePath(node_name))
			if found:
				return found
		if is_instance_valid(locations.island_scene):
			return locations.island_scene.get_node_or_null(NodePath(node_name))
	return null

func restoration_stage() -> int:
	return 3 if cove_repaired else 2 if garden_repaired else 1 if repaired else 0

func discovery_condition(spec: Dictionary) -> String:
	var locations := {"glass": "西北海岸", "shell": "东北海岸", "wood": "灯塔东南", "seed": "东侧绣球花岛", "feather": "西侧月贝沙洲", "moss": "小路东侧", "ribbon": "东北礁石旁", "coral": "北岸西侧", "stardust": "北方观星岬"}
	var condition: String = locations.get(spec.id, "海岸")
	condition += " · 退潮" if spec.tide == "low" else " · 涨潮" if spec.tide == "high" else " · 任意潮汐"
	if spec.get("night", false):
		condition += " · 月夜"
	if int(spec.stage) > restoration_stage():
		condition = ("点亮灯塔后" if int(spec.stage) == 1 else "恢复花园后") + " · " + condition
	return condition

func toggle_night() -> void:
	day_night_cycle.toggle()

func _set_night(value: bool, automatic := false) -> void:
	night = value
	island_life.apply_night(true, DayNightCycle.TRANSITION_SECONDS if automatic else 1.8)
	music.set_night(night, true, DayNightCycle.TRANSITION_SECONDS if automatic else IslandMusic.TRANSITION_SECONDS)
	_update_tide_visuals()
	_update_objective()
	_save_progress()
	_show_toast("夜色降临\n星砂在退潮的观星岬悄悄发光。" if night else "清晨的海风\n小岛又迎来了明亮的一天。")

func toggle_audio() -> void:
	audio_enabled = not audio_enabled
	if not audio_enabled:
		chime.stop()
	if island_life.soundscape:
		island_life.soundscape.stream_paused = not audio_enabled
	music.set_enabled(audio_enabled)
	_save_progress()
	_show_toast("配乐、海风与提示音已开启" if audio_enabled else "声音已关闭")

func set_player_palette(choice: int, restoring := false) -> void:
	if choice < 0 or choice > 3:
		return
	player_palette = choice
	keeper_appearance.set_palette(choice)
	if not restoring:
		_save_progress()
		_show_toast("雨衣换好了\n" + ["麦芽黄", "雾海蓝", "蔷薇粉", "苔叶绿"][choice])

func set_room_layout(choice: int, restoring := false) -> void:
	if choice < 0 or choice > 2 or (not restoring and not _near_lighthouse()):
		return
	room_layout = choice
	# Keep every layout clear of the archive desk along the back wall.
	if current_location == "room" and is_instance_valid(locations.active_scene):
		locations.active_scene.apply_layout(choice)
	if not restoring:
		cancel_dash()
		dash_effects.clear_trail()
		player.position = Vector3(0, 1.1, 2.3)
		player.velocity = Vector3.ZERO
		last_ground_position = player.position
		_save_progress()
		_show_toast("家具已经摆好\n" + ["窗边读书", "围坐喝茶", "留白散步"][choice])

func new_journey() -> bool:
	last_backup_path = ""
	if not get_meta("test_mode", false):
		if FileAccess.file_exists(progress_path):
			var backup := "%s.backup.%s.%s" % [progress_path, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(progress_path), ProjectSettings.globalize_path(backup)) != OK:
				_show_toast("旧进度暂时无法备份\n请检查存档目录是否可以写入。")
				return false
			last_backup_path = backup
		if SaveState.save_progress({}, progress_path) != OK:
			_show_toast("新旅程暂时无法保存\n原来的旅程仍然保留。")
			return false
	locations.return_to_island()
	picnic_rest.leave(false)
	gliding.cancel()
	_apply_progress(SaveState._validated({}))
	activities.cancel_session()
	cancel_dash()
	water_activities.cancel_fishing()
	swimming = false
	dash_cooldown = 0.0
	dash_effects.clear_trail()
	player.position = Vector3(0, 1.1, 4.0)
	player.velocity = Vector3.ZERO
	jump_requested = false
	camera_yaw = 0.0
	camera_pitch = 0.65
	camera_distance = 20.5
	camera_focus = player.position + Vector3(0, 0.6, 0)
	island_life.apply_state()
	_update_tide_visuals()
	_update_objective()
	_show_toast("新的一页\n先去灯塔东南边找漂流木星标。")
	return true

func _set_decoration(style: int, restoring := false) -> void:
	if (not restoring and not _near_lighthouse()) or style < 0 or style > 2:
		return
	decoration_style = style
	var palettes := [
		[Color("#e7a6a1"), Color("#d37f70"), Color("#7eb397"), Color("#8eb8b0")],
		[Color("#9db9d4"), Color("#d7a46d"), Color("#7dafaa"), Color("#8a9cc2")],
		[Color("#e2c58e"), Color("#bb8c7e"), Color("#86a984"), Color("#a0aa82")]
	]
	var palette: Array = palettes[style]
	for i in room_objects.size():
		var mesh := room_objects[i] as MeshInstance3D
		if mesh:
			mesh.material_override = _material(palette[i % palette.size()], 0.86)
	if not restoring:
		_show_toast("小屋布置已更换\n%s" % ["珊瑚晨光" if style == 0 else "雾蓝海盐" if style == 1 else "岛屿苔痕"])
		_save_progress()

func _update_archive_panel() -> void:
	if not archive_panel_label:
		return
	var stage := mini(restoration_stage(), 2)
	var lines := ["潮汐档案馆  ·  J 翻开", "", ["01  第一束光", "02  风铃花园", "03  星砂海湾"][stage]]
	for spec in item_specs:
		if int(spec.stage) == stage:
			lines.append(("◆ " if discovered.has(spec.id) else "◇ ") + str(spec.name))
			if not discovered.has(spec.id):
				lines.append("    " + discovery_condition(spec))
	lines.append("")
	lines.append("全岛已恢复 · 去看看雾团吧" if cove_repaired else "靠近遗物按 E 记录")
	archive_panel_label.text = "\n".join(lines)
	archive_label.text = "档案 %d / 9   ·   岛屿恢复 %d / 3" % [archive_count, restoration_stage()]
	for i in display_objects.size():
		display_objects[i].visible = discovered.has(item_specs[i].id)

func _restore_progress() -> void:
	if get_meta("test_mode", false):
		return
	_apply_progress(SaveState.load_progress(progress_path))

func _apply_progress(progress: Dictionary) -> void:
	fish_caught = progress.get("fish_caught", {}).duplicate()
	discovered.clear()
	for item_id in progress.discovered:
		discovered[item_id] = true
	archive_count = discovered.size()
	repaired = progress.repaired
	garden_repaired = progress.garden_repaired
	cove_repaired = progress.cove_repaired
	tide_low = progress.tide_low
	night = progress.night
	day_night_cycle.restore(progress.get("day_night_elapsed", 0.0))
	audio_enabled = progress.audio_enabled
	activities.apply_progress(progress.get("activities", {}))
	if is_instance_valid(music):
		music.set_night(night, false)
		music.set_enabled(audio_enabled)
	_set_decoration(progress.style, true)
	set_room_layout(progress.room_layout, true)
	set_player_palette(progress.player_palette, true)
	_apply_lighthouse()
	_update_archive_panel()

func _apply_lighthouse() -> void:
	beacon_light.light_energy = 8.0 if repaired else 0.1
	# Keep the lit core inside the gallery opening, below the roof eave.
	beacon_mesh.scale = Vector3.ONE * (1.1 if repaired else 1.0)
	if is_instance_valid(restoration_mesh):
		restoration_mesh.material_override = _material(Color("#8ee7c4") if repaired else Color("#e2a87c"))
	if current_location == "top" and is_instance_valid(locations.active_scene):
		locations.active_scene.apply_beacon()
	_update_beacon(0.0)

func _save_progress() -> Error:
	if get_meta("test_mode", false):
		return OK
	var error := SaveState.save_progress({
		"discovered": discovered.keys(), "repaired": repaired,
		"garden_repaired": garden_repaired, "cove_repaired": cove_repaired,
		"style": decoration_style, "room_layout": room_layout, "player_palette": player_palette,
		"tide_low": tide_low, "night": night, "audio_enabled": audio_enabled,
		"day_night_elapsed": day_night_cycle.elapsed,
		"fish_caught": fish_caught,
		"activities": activities.progress
	}, progress_path)
	if save_label:
		save_label.text = "已自动保存" if error == OK else "本次进度尚未写入存档"
	return error

func _update_objective() -> void:
	if not objective_label:
		return
	if cove_repaired:
		objective_label.text = "小岛醒来了 · 三处恢复完成\n去码头找雾团，或进灯塔布置小屋。"
		return
	var stage := restoration_stage()
	var required: Array = [Catalog.LIGHTHOUSE_IDS, Catalog.GARDEN_IDS, Catalog.COVE_IDS][stage]
	if Catalog.has_all(discovered, required):
		objective_label.text = ["下一步 · 点亮灯塔\n进灯塔，沿小屋楼梯登顶修复灯芯。", "下一步 · 唤醒花园\n去东边风铃花园的圆环，按 E。", "下一步 · 恢复海湾\n去北边码头旁的圆环，按 E。"][stage]
	else:
		for spec in item_specs:
			if int(spec.stage) == stage and not discovered.has(spec.id):
				if stage == 0 and not discovered.has("wood"):
					objective_label.text = "第一件发现 · 漂流木星标\n在灯塔东南边。靠近后按 E。"
				else:
					objective_label.text = "寻找 · " + str(spec.name) + "\n" + discovery_condition(spec) + "。"
				break

func _show_ending() -> void:
	if menus:
		menus.open_ending()

func _play_chime(frequency: float, duration := 0.7) -> void:
	if not chime or not audio_enabled or get_meta("test_mode", false):
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / stream.mix_rate
		var envelope := minf(t * 50.0, 1.0) * exp(-t * 4.5) * minf((duration - t) * 20.0, 1.0)
		var tone := sin(TAU * frequency * t) * 0.65 + sin(TAU * frequency * 1.5 * t) * 0.25
		data.encode_s16(i * 2, int(tone * envelope * 18000.0))
	stream.data = data
	chime.stop()
	chime.stream = stream
	chime.play()

func _exit_tree() -> void:
	if is_instance_valid(chime):
		chime.stop()
		chime.stream = null

func _show_toast(message: String) -> void:
	if not toast_label:
		return
	toast_label.text = message
	toast_label.modulate = Color.WHITE
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(3.2)
	toast_tween.tween_property(toast_label, "modulate", Color(1, 1, 1, 0), 0.8)

func _material(color: Color, roughness := 0.85, metallic := 0.0, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _mesh_node(mesh: Mesh, node_name: String, position: Vector3, material: Variant, collision := false, parent: Node = null) -> MeshInstance3D:
	if parent == null:
		parent = self
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	if material is Color:
		instance.material_override = _material(material)
	else:
		instance.material_override = material
	parent.add_child(instance, true)
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		body.position = position
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		if mesh is CylinderMesh:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = mesh.top_radius
			cylinder.height = mesh.height
			shape.shape = cylinder
		elif mesh is SphereMesh:
			var sphere := SphereShape3D.new()
			sphere.radius = mesh.radius
			shape.shape = sphere
		else:
			var box := BoxShape3D.new()
			box.size = mesh.get_aabb().size
			shape.shape = box
		body.add_child(shape)
		if node_name in ["Island", "Meadow"]:
			body.add_to_group("shore_floor")
	return instance

func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, collision := false, parent: Node = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_node(mesh, node_name, position, color, collision, parent)

func _add_cylinder(node_name: String, radius: float, height: float, position: Vector3, material: Variant, collision := false, parent: Node = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = 32
	return _mesh_node(mesh, node_name, position, material, collision, parent)

func _add_capsule(node_name: String, radius: float, height: float, position: Vector3, color: Color, collision := false, parent: Node = null) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	return _mesh_node(mesh, node_name, position, color, collision, parent)

func _add_sphere(node_name: String, radius: float, position: Vector3, material: Variant, collision := false, parent: Node = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return _mesh_node(mesh, node_name, position, material, collision, parent)

func _add_torus(node_name: String, outer: float, inner: float, position: Vector3, color: Color, parent: Node = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = outer - inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 12
	return _mesh_node(mesh, node_name, position, color, false, parent)

func _add_ring(node_name: String, inner: float, outer: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 6
	return _mesh_node(mesh, node_name, position, color, false)

func _add_label_3d(text: String, position: Vector3, color: Color, font_size: float, parent: Node = null) -> Label3D:
	if parent == null:
		parent = self
	var label := Label3D.new()
	label.font = chinese_font
	label.pixel_size = 0.015
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = int(font_size * 32.0)
	label.outline_size = 8
	label.outline_modulate = Color(0.08, 0.15, 0.18, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
