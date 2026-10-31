extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func send(event: InputEvent) -> void:
	Input.parse_input_event(event.duplicate())
	Input.flush_buffered_events()

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	send(button)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 50)
	send(motion)
	check(game.camera_yaw < -0.4, "Left-drag must orbit horizontally")
	check(game.camera_pitch > 0.8, "Left-drag must orbit vertically")
	button.pressed = false
	send(button)
	var yaw: float = game.camera_yaw
	send(motion)
	check(is_equal_approx(yaw, game.camera_yaw), "Releasing left mouse must stop dragging")
	button.button_index = MOUSE_BUTTON_WHEEL_UP
	button.pressed = true
	for i in range(50):
		send(button)
	check(is_equal_approx(game.camera_distance, 7.0), "Zoom must respect its near limit")
	button.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in range(50):
		send(button)
	check(is_equal_approx(game.camera_distance, 30.0), "Zoom must respect its far limit")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	send(key)
	check(is_equal_approx(game.camera_yaw, 0.0), "C must restore the heading")
	check(is_equal_approx(game.camera_pitch, 0.65), "C must restore the angle")
	check(is_equal_approx(game.camera_distance, 20.5), "C must restore the zoom")
	key.pressed = false
	send(key)
	key.physical_keycode = KEY_RIGHT
	key.keycode = KEY_RIGHT
	key.pressed = true
	send(key)
	game._update_camera(0.5)
	check(absf(game.camera_yaw) > 0.5, "Arrow keys must rotate the camera")
	key.pressed = false
	send(key)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(5, 4)
	yaw = game.camera_yaw
	send(pan)
	check(game.camera_yaw < yaw, "Trackpad pan must rotate the camera")
	check(game.chinese_font.has_char("潮".unicode_at(0)), "Bundled font must contain Chinese glyphs")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: mouse orbit, release, zoom limits, camera reset, arrow orbit, trackpad pan, and Chinese glyphs")
	quit(0 if failures.is_empty() else 1)
