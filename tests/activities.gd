extends SceneTree

const ActivityCatalog := preload("res://data/activity_catalog.gd")
const SaveState := preload("res://save_state.gd")
var failures: Array[String] = []
var game: Node3D
var path := "user://activity_test_%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle(count := 8) -> void:
	for i in range(count):
		await process_frame

func tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func open_spot(id: String) -> void:
	game.menus.close()
	var spot: Node3D = game.activities.spots[id]
	game.player.position = spot.global_position + Vector3(0, 0.6, 0.75)
	game.player.velocity = Vector3.ZERO
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	game.camera_distance = 17
	game._update_camera(1.0)
	game._update_interaction()
	check(game.interact_target == spot, "Spot is the nearest E interaction: " + id)
	game._interact()
	await settle()
	check(game.activities.active == id and game.menus.current_page == "activity", "E interaction opens " + id)

func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/闲趣-" + name + ".png")

func run() -> void:
	var defaults := {"stone_best": 0, "flowers": [0, 0, 0], "songs": [], "stars": []}
	check(ActivityCatalog.validated(null) == defaults, "Old saves get safe empty activities")
	check(ActivityCatalog.validated({"stone_best": 99, "flowers": [true, -1, "3"], "songs": ["bad", "home", "home"], "stars": 2}) == defaults.merged({"songs": ["home"]}, true), "Invalid, duplicate and out-of-range activity data is sanitized")
	game = load("res://Main.tscn").instantiate()
	game.progress_path = path
	game.set_meta("skip_title", true)
	root.add_child(game)
	game.toggle_audio()
	await settle()
	game.set_physics_process(false)
	game.set_process(false)
	var activities: Node3D = game.activities
	activities.open_activity("stars")
	check(not game.menu_is_open(), "Activity cannot be opened from across the island")
	await open_spot("stones")
	var before: Vector3 = game.player.position
	await tap(KEY_W)
	await tap(KEY_T)
	await tap(KEY_N)
	await tap(KEY_F)
	check(game.player.position == before and not game.night and game.tide_low, "Activity modal blocks world actions")
	await tap(KEY_E)
	check(activities.stone_cast, "E starts a throw")
	activities.stone_time = PI / (2.1 * 2.0)
	activities.stone_cursor = 0.5
	await tap(KEY_E)
	check(activities.progress.stone_best == 5, "Well timed throw records five skips")
	check(activities.stone_flight > 0, "Throw animates its skips")
	await settle()
	shot("打水漂")
	await tap(KEY_E)
	activities.stone_time = 0.0
	activities.stone_cursor = 0.0
	await tap(KEY_E)
	check(activities.progress.stone_best == 5, "A weaker throw keeps the best score")
	await tap(KEY_ESCAPE)
	check(activities.active.is_empty() and not activities.stone_cast, "Esc cancels activity session")

	await open_spot("flowers")
	await click(activities.choice_buttons[0])
	check(activities.progress.flowers == [1, 0, 0], "Mouse watering grows only the selected plant")
	check(activities.flower_models[0].visible, "Watering changes the 3D flower bed")
	for i in range(3):
		for j in range(3 - activities.progress.flowers[i]):
			await tap(KEY_1 + i)
	check(activities.progress.flowers == [3, 3, 3], "All three plants can bloom through keyboard input")
	await tap(KEY_1)
	check(activities.progress.flowers == [3, 3, 3], "Admiring a mature plant does not overgrow or erase it")
	await settle()
	shot("花圃")

	await open_spot("bells")
	await tap(KEY_3)
	check(activities.song_step == 0 and activities.progress.songs.is_empty(), "Wrong note never awards a tune")
	activities.play_demo()
	await settle()
	check(activities.choice_buttons[0].disabled, "Demo disables competing note input")
	game.menus.close()
	await settle()
	check(activities.demo == null and activities.active.is_empty(), "Closing a demo cancels its delayed callbacks")
	await open_spot("bells")
	activities.play_demo()
	await settle(220)
	check(not activities.choice_buttons[0].disabled and not activities.demo.is_running(), "Demo finishes and returns note controls")
	for song in ActivityCatalog.SONGS:
		for note in song.notes:
			await tap(KEY_1 + note)
		check(song.id in activities.progress.songs, "Correct tune is recorded: " + song.id)
		shot("风铃")
		activities.next_song()
		await settle()
	check(activities.progress.songs.size() == 3, "All three tunes recorded without duplication")

	await open_spot("stars")
	activities.connect_star(0)
	check(activities.star_step == 0, "Daytime cannot bypass the night requirement")
	var night_button: Button
	for button in game.menus.overlay.find_children("*", "Button", true, false):
		if button.text == "等到月夜":
			night_button = button
	check(night_button != null, "Daytime offers an explicit change to moonlight")
	if night_button:
		await click(night_button)
	await settle()
	check(game.night and activities.choice_buttons.size() == 5, "Waiting for night shows five selectable stars")
	await tap(KEY_3)
	check(activities.star_step == 0, "Out-of-order star does not award a constellation")
	await click(activities.choice_buttons[0])
	check(activities.star_step == 1, "Star can be selected with a real mouse event")
	for code in [KEY_2, KEY_3, KEY_4, KEY_5]:
		await tap(code)
	check(activities.progress.stars == ["sail"], "Connecting stars records the first constellation")
	shot("连星")
	activities.next_stars()
	await settle()
	for code in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		await tap(code)
	check(activities.progress.stars.size() == 2 and ActivityCatalog.count(activities.progress) == 9, "All nine leisure entries are achievable")
	check(game.archive_count == 0 and not game.repaired, "Leisure leaves main story progress independent")
	var expected: Dictionary = activities.progress.duplicate(true)
	check(SaveState.load_progress(path).activities == expected, "Activities autosave alongside the main progress")

	game.menus.open_archive()
	activities.open_journal()
	await settle()
	check(game.menus.current_page == "leisure", "Journal exposes leisure records")
	game.menus.back()
	check(game.menus.current_page == "archive", "Leisure returns to the main journal")
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 480)
	for id in ["stones", "flowers", "bells", "stars"]:
		await open_spot(id)
		var panel: Control = game.menus.overlay.find_child("MenuPanel", true, false)
		var close_button: Button = game.menus.overlay.find_child("CloseButton", true, false)
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel.get_global_rect()), "Activity panel fits a small window: " + id)
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(close_button.get_global_rect()), "Close remains reachable: " + id)
		var scroll: ScrollContainer = game.menus.overlay.find_child("MenuScroll", true, false)
		check(scroll.get_child(0).size.y <= scroll.size.y + 1, "Activity and actions are visible together without scrolling at 640: " + id)
		if id == "stars":
			for constellation in range(2):
				for button in activities.choice_buttons:
					check(activities.board.get_global_rect().encloses(button.get_global_rect()), "Stars stay inside the small sky card")
				activities.next_stars()
				await settle()
			close_button = game.menus.overlay.find_child("CloseButton", true, false)
		shot(id + "-640")
		await click(close_button)
		check(not game.menu_is_open(), "Mouse closes activity at 640: " + id)
	game.queue_free()
	await settle()
	game = load("res://Main.tscn").instantiate()
	game.progress_path = path
	game.set_meta("skip_title", true)
	root.add_child(game)
	await settle()
	check(game.activities.progress == expected, "Reload restores every leisure entry")
	check(game.activities.flower_models[2].visible and game.activities.flower_models[2].scale == Vector3.ONE, "Reload restores full grown flowers in the world")
	check(game.new_journey(), "New journey can back up and reset leisure")
	check(game.activities.progress == defaults, "New journey resets all leisure state")
	check(SaveState.load_progress(game.last_backup_path).activities == expected, "Restart backup preserves the old leisure entries")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.last_backup_path))
	game.queue_free()
	await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: all four activities, real mouse/keyboard input, world visuals, wrong inputs, nine rewards, modal cancellation, 640px layouts, autosave/reload and backup/reset")
	quit(0 if failures.is_empty() else 1)
