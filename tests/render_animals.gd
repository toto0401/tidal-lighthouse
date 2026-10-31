extends SceneTree

## Real Metal renders of the animals in their actual habitats; saves are disabled.
func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await process_frame

func shot(label: String) -> void:
	await frames(8)
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://docs/小动物-" + label + ".png") == OK)
	print("Animal render: ", label)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(12)
	game.set_process(false)
	game.set_physics_process(false)
	game.animals.set_physics_process(false)
	game.ui_layer.hide()
	game.player.hide()
	for id in ["milk", "coral", "peach", "white"]:
		var animal: Node3D = game.animals.get_node("Animal_" + id)
		var entry: Dictionary = game.animals.critters[int(animal.get_meta("animal_index"))]
		animal.position = entry.home
		animal.rotation.y = 0.3
		entry.mode = "idle"
		entry.timer = 3.0
		game.player.position = animal.position + Vector3(0.6, 0.8, 1.0)
		game.camera.position = animal.position + Vector3(1.7, 1.3, 3.0)
		game.camera.look_at(animal.position + Vector3(0, 0.4, 0))
		game.animals._step(entry, 0.01)
		await shot({"milk": "兔子", "coral": "螃蟹", "peach": "花岛兔子", "white": "海鸥"}[id])
	var rabbit: Node3D = game.animals.get_node("Animal_milk")
	game.player.show()
	game.player.position = rabbit.position + Vector3(0.95, 0.66, 0)
	game.player.rotation.y = -PI * 0.5
	game.camera.position = rabbit.position + Vector3(-1.5, 2.4, 4.3)
	game.camera.look_at(rabbit.position + Vector3(0.4, 0.9, 0))
	game.ui_layer.show()
	game._update_interaction()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game._update_interaction()
	await shot("打招呼")
	key = InputEventKey.new()
	key.physical_keycode = KEY_E
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game.ui_layer.hide()
	game.player.hide()
	var gull_entry: Dictionary = game.animals.critters[5]
	game.animals._begin_flight(gull_entry)
	game.animals.age = 1.2
	game.animals._update_flight(gull_entry, 2.0)
	game.animals._animate(gull_entry, 0.01, 0.0)
	var gull: Node3D = gull_entry.node
	game.camera.position = gull.position + Vector3(2.6, 1.3, 3.0)
	game.camera.look_at(gull.position + Vector3(0, 0.4, 0))
	await shot("飞翔")
	game.night = true
	game.island_life.apply_night()
	game._update_tide_visuals()
	var rabbit_entry: Dictionary = game.animals.critters[0]
	rabbit_entry.mode = "idle"
	rabbit_entry.heart_left = 0
	game.animals._step(rabbit_entry, 0.01)
	game.camera.position = rabbit.position + Vector3(1.7, 1.3, 3.0)
	game.camera.look_at(rabbit.position + Vector3(0, 0.4, 0))
	await frames(100)
	await shot("月夜休息")
	game.queue_free()
	await process_frame
	quit()
