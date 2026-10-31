extends SceneTree

## Actual engine renders for the reference-based keeper; never reads player saves.
const Appearance := preload("res://scripts/keeper_appearance.gd")

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await process_frame

func shot(file_name: String) -> void:
	await frames(6)
	RenderingServer.force_draw()
	var error := root.get_texture().get_image().save_png("res://docs/" + file_name + ".png")
	assert(error == OK, "Screenshot must be written")
	print("Keeper render: ", file_name)

func run() -> void:
	root.size = Vector2i(1440, 900)
	var studio := Node3D.new()
	root.add_child(studio)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#c8ced0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e9edf2")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.8
	environment.ssao_enabled = true
	environment.ssao_radius = 0.16
	environment.ssao_intensity = 1.4
	world.environment = environment
	studio.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_color = Color("#fff1d9")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.light_angular_distance = 8
	studio.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.3
	fill.light_color = Color("#deeaff")
	studio.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#c8ced0")
	floor_material.roughness = 0.95
	floor_mesh.material_override = floor_material
	studio.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	studio.add_child(camera)
	camera.make_current()
	var keepers: Array[Node3D] = []
	for index in range(3):
		var keeper := Node3D.new()
		keeper.position = Vector3((index - 1) * 1.9, 0.775, 0)
		studio.add_child(keeper)
		var appearance := Appearance.new()
		appearance.build(keeper)
		keeper.rotation.y = [0.0, PI * 0.5, PI][index]
		keepers.append(keeper)
	camera.position = Vector3(0, 2.3, 10)
	camera.look_at(Vector3(0, 1.24, 0))
	camera.size = 3.7
	await shot("主角-三视图")
	keepers[0].hide()
	keepers[2].hide()
	keepers[1].rotation.y = -0.38
	camera.size = 2.95
	camera.position = Vector3(2.2, 2.0, 7)
	camera.look_at(Vector3(0, 1.27, 0))
	await shot("主角-造型")
	studio.queue_free()
	await process_frame
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(30)
	game.set_player_palette(0, true)
	game.player.position = Vector3(0, 1.1, 11.5)
	game.player.rotation.y = 0.15
	game.camera_yaw = 0.35
	game.camera_pitch = 0.23
	game.camera_distance = 5.2
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	game.ui_layer.hide()
	await frames(50)
	await shot("主角-海岛实景")
	game.camera_distance = 12.5
	game.camera_pitch = 0.46
	game.ui_layer.show()
	game.toast_label.modulate.a = 0
	await frames(30)
	await shot("主角-游玩画面")
	# Hold a real dash after a single physics update for a deterministic closeup.
	game.ui_layer.hide()
	game.player.position = Vector3(0, 1.1, 10)
	game.camera_distance = 6
	game.camera_pitch = 0.28
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	await frames(30)
	game.dash_requested = true
	for frame in range(12):
		await physics_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.camera.position = game.player.position + Vector3(3.5, 2.1, 4.5)
	game.camera.look_at(game.player.position + Vector3(0, 0.4, 0))
	await shot("主角-踏浪")
	game.night = true
	game.island_life.apply_night()
	game._update_tide_visuals()
	await frames(100)
	await shot("主角-月夜")
	game.queue_free()
	await process_frame
	quit()
