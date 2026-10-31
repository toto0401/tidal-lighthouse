extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func tap(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func capture(path: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Screenshot failed: " + path)
		quit(1)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(40)
	DisplayServer.window_move_to_foreground()
	game.player.position = Vector3(39, 0, 18)
	game.player.rotation.y = PI * 0.7
	game.player.velocity = Vector3.ZERO
	game.camera_yaw = 0.4
	game.camera_pitch = 0.6
	game.camera_distance = 11
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	await frames(100)
	game.toast_label.modulate.a = 0.0
	await capture("res://docs/自由游泳.png")
	game.player.position = Vector3(38, 1.1, 16)
	game.player.rotation.y = 0.5
	game.player.velocity = Vector3.ZERO
	game.swimming = false
	game.camera_yaw = 2.5
	game.camera_pitch = 0.55
	game.camera_distance = 10
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	await frames(60)
	await tap(KEY_F)
	await frames(45)
	await capture("res://docs/岸边钓鱼.png")
	await frames(300)
	await capture("res://docs/鱼儿咬钩.png")
	await tap(KEY_F)
	await frames(18)
	await capture("res://docs/钓鱼收获.png")
	await frames(110)
	game.menus.open_archive()
	await frames(12)
	await capture("res://docs/钓鱼手账.png")
	game.menus.open_help()
	await frames(12)
	await capture("res://docs/游泳钓鱼说明.png")
	game.queue_free()
	await process_frame
	quit()
