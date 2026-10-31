extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	await process_frame
	key(code, false)
	await process_frame

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	game.player.position = Vector3(5, 1.1, 2)
	game.player.velocity = Vector3.ZERO
	await frames(40)
	check(game.player.is_on_floor(), "Menu regression test starts grounded")
	await tap(KEY_J)
	check(game.menu_is_open() and game.menus.current_page == "archive", "J opens the nine-page archive")
	var position_before: Vector3 = game.player.position
	var yaw: float = game.camera_yaw
	key(KEY_D, true)
	key(KEY_SPACE, true)
	key(KEY_RIGHT, true)
	await frames(20)
	key(KEY_D, false)
	key(KEY_SPACE, false)
	key(KEY_RIGHT, false)
	await tap(KEY_T)
	await tap(KEY_N)
	await tap(KEY_V)
	await tap(KEY_M)
	check(game.player.position.is_equal_approx(position_before), "Reading the archive stops walking and jumping")
	check(is_equal_approx(yaw, game.camera_yaw), "Reading the archive stops camera rotation")
	check(game.tide_low and not game.night, "Menu keys must not change tide or night behind the page")
	check(game.player_palette == 0 and game.audio_enabled, "Menu keys must not change outfit or sound behind the page")
	await tap(KEY_ESCAPE)
	check(not game.menu_is_open(), "Esc closes an archive page")
	await frames(8)
	check(game.player.is_on_floor() and game.player.position.is_equal_approx(position_before), "Closing the archive must not release a queued jump or movement")
	await tap(KEY_SPACE)
	await frames(5)
	check(game.player.position.y > position_before.y + 0.3, "Jump still works after closing a menu")
	await frames(80)

	await tap(KEY_N)
	check(game.night, "N switches the world to night")
	await tap(KEY_M)
	check(not game.audio_enabled, "M toggles sound")
	var coat_before: Color = game.player.get_node("Coat").material_override.albedo_color
	await tap(KEY_V)
	check(game.player_palette == 1, "V cycles the character color")
	check(game.player.get_node("Coat").material_override.albedo_color != coat_before, "Cycling the outfit visibly changes the raincoat material")
	await tap(KEY_ESCAPE)
	check(game.menu_is_open() and game.menus.current_page == "pause", "Esc opens pause while exploring")
	await tap(KEY_ESCAPE)
	check(not game.menu_is_open(), "Esc resumes from pause")
	await tap(KEY_H)
	check(game.menus.current_page == "help", "H opens the controls guide")
	await tap(KEY_ESCAPE)
	await tap(KEY_B)
	check(not game.menu_is_open(), "B away from home gives a hint without opening decoration")
	await Travel.travel(game,"room")
	game.player.position = Vector3(0,1.1,2.3)
	game.player.velocity = Vector3.ZERO
	await tap(KEY_B)
	check(game.menus.current_page == "decor", "B at home opens the decoration choices")
	await tap(KEY_ESCAPE)

	# The title is a modal too, and its primary button allows play to begin.
	game.menus.open_title()
	check(game.menus.title_open and game.menu_is_open(), "Title screen opens as a modal")
	position_before = game.player.position
	key(KEY_W, true)
	await frames(10)
	key(KEY_W, false)
	check(game.player.position.is_equal_approx(position_before), "Title screen blocks gameplay movement")
	var start_button: Button = null
	for node in game.menus.overlay.find_children("*", "Button", true, false):
		if node.text == "开始旅程":
			start_button = node
	check(start_button != null, "A new player's title offers Start Journey")
	if start_button:
		start_button.pressed.emit()
	check(not game.menu_is_open(), "Start Journey closes the title")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: title, pause, guide, archive, home decoration, modal movement/jump/camera blocking, resume, night/outfit/sound shortcuts")
	quit(0 if failures.is_empty() else 1)
