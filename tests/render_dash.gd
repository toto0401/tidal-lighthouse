extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = code == KEY_SHIFT and pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for frame in count:
		await physics_frame

func capture_dash(game: Node3D, is_night: bool, path: String, in_water := false) -> void:
	game.night = is_night
	game.island_life.apply_night()
	game._update_tide_visuals()
	game.swimming = false
	game.player.position = Vector3(39, 0, 18) if in_water else Vector3(29, 1.1, 6)
	game.player.velocity = Vector3.ZERO
	game.dash_cooldown = 0.0
	game.camera_yaw = 0.35
	game.camera_pitch = 0.46
	game.camera_distance = 12.5
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	game.dash_effects.clear_trail()
	await frames(40)
	game.toast_label.modulate.a = 0.0
	key(KEY_D, true)
	await frames(2)
	key(KEY_SHIFT, true)
	await frames(1)
	key(KEY_SHIFT, false)
	key(KEY_D, false)
	await frames(18)
	if game.dash_remaining <= 0.0:
		push_error("Dash ended before capture; keep the game window focused during rendering.")
		quit(1)
		return
	RenderingServer.force_draw()
	var error := root.get_texture().get_image().save_png(path)
	print("Dash screenshot: ", error, " active=", game.dash_remaining > 0.0)
	await frames(90)

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(40)
	if not is_instance_valid(game.menus):
		push_error("Game initialization failed; cannot capture dash screenshots.")
		quit(1)
		return
	# Let the native window and shaders settle before the short input sequence.
	DisplayServer.window_move_to_foreground()
	RenderingServer.force_draw()
	await frames(120)
	await capture_dash(game, false, "res://docs/踏浪冲刺.png")
	await capture_dash(game, true, "res://docs/踏浪月夜.png")
	await capture_dash(game, false, "res://docs/游泳冲刺.png", true)
	await capture_dash(game, true, "res://docs/月夜游泳冲刺.png", true)
	game.menus.open_help()
	await frames(6)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/踏浪操作说明.png")
	game.queue_free()
	await process_frame
	quit()
