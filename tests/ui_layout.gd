extends SceneTree

var failures: Array[String] = []
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for i in range(10):
		await process_frame

func tap(code: Key, logical := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		if logical:
			event.keycode = code
		else:
			event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await settle()

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func shot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/" + file_name + ".png")

func close_button() -> Button:
	return game.menus.overlay.find_child("CloseButton", true, false) as Button

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	game.audio_enabled = false
	root.add_child(game)
	await settle()
	await tap(KEY_H)
	check(game.menus.current_page == "help", "H opens help")
	await tap(KEY_H)
	check(not game.menu_is_open(), "Pressing H again closes help")
	game.menus.close()
	game.menus.open_help()
	await settle()
	await tap(KEY_ESCAPE, true)
	check(not game.menu_is_open(), "Logical Escape closes help too")
	game.menus.close()
	game.menus.open_help()
	await settle()
	var button := close_button()
	check(button != null, "Help has an obvious close button")
	if button:
		await click(button)
		check(not game.menu_is_open(), "Mouse click on the close button closes help without reopening pause")
	game.menus.close()
	game.menus.open_title()
	game.menus.open_help()
	await settle()
	await tap(KEY_H)
	check(game.menus.current_page == "title", "Closing title help returns to the title")
	game.menus.close()
	game.menus.open_pause()
	game.menus.open_help()
	await settle()
	await tap(KEY_ESCAPE)
	check(game.menus.current_page == "pause", "Closing pause help returns to pause")
	game.menus.close()
	check(not game.archive_panel.visible, "Full journal is not permanently covering the island")
	for stage in range(4):
		game.repaired = stage >= 1
		game.garden_repaired = stage >= 2
		game.cove_repaired = stage >= 3
		game._update_objective()
		await settle()
		check(game.objective_label.get_global_rect().end.y <= 216, "Stage %d objective fits its card" % stage)
	game.repaired = false
	game.garden_repaired = false
	game.cove_repaired = false
	game._update_objective()
	game.toast_label.modulate.a = 0.0
	await settle()
	shot("界面精简-1280")
	game.menus.open_help()
	await settle()
	shot("帮助窗口-1280")
	# Disable stretch to test an actually constrained logical viewport as well.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(960, 540), Vector2i(640, 480)]:
		root.size = dimensions
		await settle()
		for page in ["help", "pause", "archive", "map"]:
			game.menus.close()
			game.menus.call("open_" + page)
			await settle()
			var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
			var panel: Control = game.menus.overlay.find_child("MenuPanel", true, false)
			button = close_button()
			check(panel != null and bounds.encloses(panel.get_global_rect()), "%s panel fits %s" % [page, dimensions])
			check(button != null and bounds.encloses(button.get_global_rect()), "%s close button stays onscreen at %s" % [page, dimensions])
			if page == "help":
				var scroll: ScrollContainer = game.menus.overlay.find_child("MenuScroll", true, false)
				check(scroll.scroll_vertical == 0, "Help opens at the beginning at %s" % dimensions)
				shot("帮助窗口-%d" % dimensions.x)
			if button:
				await click(button)
				check(not game.menu_is_open(), "%s remains closable at %s" % [page, dimensions])
	game.queue_free()
	await process_frame
	# Let the audio mixer release stopped streams before this fast test exits.
	OS.delay_msec(100)
	await process_frame
	if failures.is_empty():
		print("PASS: help H/Esc/mouse close, return destinations, uncluttered HUD, constrained menus at 960x540 and 640x480")
	quit(0 if failures.is_empty() else 1)
