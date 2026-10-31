extends SceneTree

## Real keyboard input and Jolt collision tests, using only a private save file.
const FishCatalog := preload("res://data/fish_catalog.gd")
const SaveState := preload("res://save_state.gd")
var failures: Array[String] = []
var game: Node3D
var held := {}
var test_path := "user://water_activities_%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func key(code: Key, pressed: bool, echo_event := false) -> void:
	held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo_event
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func place(at: Vector3, heading := 0.0, camera_heading := 0.0) -> void:
	for code in held:
		if held[code]:
			key(code, false)
	game.menus.close()
	game.cancel_dash()
	game.swimming = false
	game.dash_cooldown = 0.0
	game.player.position = at
	game.player.rotation.y = heading
	game.player.velocity = Vector3.ZERO
	game.camera_yaw = camera_heading
	game.camera_focus = at + Vector3(0, 0.6, 0)
	await frames(50)

func move(code: Key, count: int) -> void:
	key(code, true)
	await frames(count)
	key(code, false)
	await frames(20)

func catch_count() -> int:
	var count := 0
	for value in game.fish_caught.values():
		count += int(value)
	return count

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.progress_path = test_path
	game.set_meta("skip_title", true)
	root.add_child(game)
	await frames(40)
	check(InputMap.has_action("fish"), "F fishing action exists")
	# Walk past the former 15.25 m clamp and into real water, without teleporting.
	await place(Vector3(0, 1.1, 14))
	await move(KEY_S, 190)
	check(game.player.position.z > 21, "South coast no longer has an air wall: %s" % game.player.position)
	check(game.swimming and not game.player.is_on_floor(), "Walking off the shore starts swimming")
	check(absf(game.player.position.y - game.SWIM_HEIGHT) < 0.1, "Buoyancy holds the player on the sea surface")
	check(game.water_activities.swim_rings[0].visible, "Swimming produces visible ripples")
	var at: Vector3 = game.player.position
	await frames(180)
	check(Vector2(at.x, at.z).distance_to(Vector2(game.player.position.x, game.player.position.z)) < 0.05, "Releasing movement floats in place without a respawn")
	await tap(KEY_F)
	check(not game.water_activities.is_fishing(), "Fishing cannot start while swimming")
	await tap(KEY_SPACE)
	await tap(KEY_SHIFT)
	check(game.swimming and game.dash_remaining > 0 and game.player.position.y < 0, "Shift starts a water dash while buoyancy keeps the player afloat")
	await tap(KEY_SPACE)
	check(game.swimming and game.dash_remaining <= 0 and game.player.position.y < 0, "Space stops a water dash without jumping into the air")
	await tap(KEY_T)
	await tap(KEY_N)
	await frames(90)
	check(game.swimming and absf(game.player.position.y - game.SWIM_HEIGHT) < 0.1, "Tide/night changes keep swimmers afloat")
	await move(KEY_W, 210)
	check(not game.swimming and game.player.is_on_floor() and game.player.position.z < 16, "Swimming toward the main island automatically climbs the bank: %s" % game.player.position)
	# Expanded islands and bridge decks use the same safe exit, including oblique approaches.
	for shore in [
		{"start": Vector3(-31, 1.1, 7), "out": KEY_S, "back": KEY_W},
		{"start": Vector3(46, 1.1, 2), "out": KEY_D, "back": KEY_A},
		{"start": Vector3(0, 1.1, -47), "out": KEY_W, "back": KEY_S},
		{"start": Vector3(0, 1.1, -20), "out": KEY_D, "back": KEY_A}
	]:
		await place(shore.start)
		await move(shore.out, 135)
		check(game.swimming, "Can leave island/bridge at %s; ended %s" % [shore.start, game.player.position])
		await move(shore.back, 170)
		check(not game.swimming and game.player.is_on_floor(), "Can climb back onto island/bridge at %s; ended %s" % [shore.start, game.player.position])
	# Diagonal corner of the old square island collider is now open sea.
	await place(Vector3(16, 1.1, 16))
	check(game.swimming, "Round island no longer has an invisible square floor in the sea")
	key(KEY_A, true)
	key(KEY_W, true)
	await frames(150)
	key(KEY_A, false)
	key(KEY_W, false)
	await frames(20)
	check(not game.swimming and game.player.is_on_floor(), "An oblique approach also climbs the round shore")
	await place(Vector3(-4.9, 1.1, 9.5), PI)
	await move(KEY_W, 12)
	check(game.player.position.z < 9.2, "Round lighthouse no longer has a square corner blocking the path")
	# Camera-relative swimming remains free within the nearby sea boundary.
	await place(Vector3(24, 0, 24), 0, PI / 2)
	at = game.player.position
	await move(KEY_W, 60)
	check(game.player.position.x < at.x - 2.0 and absf(game.player.position.z - at.z) < 0.1, "Swimming follows a rotated camera in nearby open water")
	await tap(KEY_TAB)
	at = game.player.position
	await move(KEY_W, 20)
	check(game.player.position.is_equal_approx(at), "Map freezes swimming")
	game.menus.close()
	game.return_home()
	await frames(40)
	check(not game.swimming and game.player.is_on_floor(), "Map return home restores normal walking")
	# Fishing anywhere by open water, without special unlocks or designated spots.
	await place(Vector3(5, 1.1, 0))
	await tap(KEY_F)
	check(not game.water_activities.is_fishing(), "Cannot cast inland")
	await place(Vector3(0, 1.1, 16), 0)
	check(game.water_activities.can_cast, "A normal bank offers the fishing prompt")
	await tap(KEY_F)
	check(game.water_activities.state == game.water_activities.State.CASTING, "F starts a visible cast from the bank")
	check(game.water_activities.rod.visible and game.water_activities.bobber.visible, "Cast shows a rod, float, and line")
	await frames(40)
	check(game.water_activities.state == game.water_activities.State.WAITING, "Float settles before waiting for a bite")
	await tap(KEY_F)
	check(not game.water_activities.is_fishing() and catch_count() == 0, "Early reel cancels without awarding a fish")
	key(KEY_F, true)
	await frames(360)
	check(game.water_activities.state == game.water_activities.State.BITE, "Holding F does not automatically catch a fish")
	key(KEY_F, true, true)
	await frames(4)
	check(catch_count() == 0, "Keyboard echo cannot reel in a fish")
	await frames(300)
	check(game.water_activities.state == game.water_activities.State.BITE, "The bite waits without a reaction-time penalty")
	key(KEY_F, false)
	await tap(KEY_F)
	check(catch_count() == 1 and game.water_activities.caught_fish.visible, "A fresh F press catches exactly one visible fish")
	await tap(KEY_F)
	check(catch_count() == 1, "Repeated reel input cannot duplicate the catch")
	check(SaveState.load_progress(test_path).fish_caught == game.fish_caught, "Caught fish are automatically saved")
	await frames(110)
	check(not game.water_activities.is_fishing(), "Catch animation returns to idle")
	# Movement, jumping, dash, menus, focus loss and return home release all fishing state.
	for action in [KEY_W, KEY_SPACE, KEY_SHIFT, KEY_TAB]:
		await place(Vector3(0, 1.1, 16))
		await tap(KEY_F)
		await tap(action)
		check(not game.water_activities.is_fishing() and not game.water_activities.rod.visible, "Action %d cancels fishing cleanly" % action)
	await place(Vector3(0, 1.1, 16))
	await tap(KEY_F)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not game.water_activities.is_fishing(), "Focus loss cancels fishing")
	await tap(KEY_F)
	game.return_home()
	check(not game.water_activities.is_fishing(), "Return home clears fishing state")
	await place(Vector3(1.8, 1.1, -20), PI / 2)
	await tap(KEY_F)
	check(game.water_activities.is_fishing(), "Bridge edges also support fishing")
	game.menus.open_archive()
	check(not game.water_activities.is_fishing(), "Opening the archive stows the rod")
	var fish_labels: Array = game.menus.overlay.find_children("*", "Label", true, false).filter(func(label): return label.text.contains("海边钓鱼"))
	check(fish_labels.size() == 1, "The journal exposes the fishing records")
	for night in [false, true]:
		for low in [false, true]:
			var available := FishCatalog.available(night, low)
			check(available.any(func(fish): return fish.id == "moonfish") == night, "Moonfish require night")
			check(available.any(func(fish): return fish.id == "mackerel") == not night, "Mackerel require daytime")
			check(available.any(func(fish): return fish.id == "bream") == not low, "Bream require high tide")
	var saved_fish: Dictionary = game.fish_caught.duplicate()
	game.queue_free()
	await process_frame
	game = load("res://Main.tscn").instantiate()
	game.progress_path = test_path
	game.set_meta("skip_title", true)
	root.add_child(game)
	await frames(5)
	check(game.fish_caught == saved_fish, "Reopening the game restores the caught fish")
	check(game.new_journey() and game.fish_caught.is_empty(), "New journey resets fishing records")
	check(SaveState.load_progress(game.last_backup_path).fish_caught == saved_fish, "New journey backs up the previous fishing records")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.last_backup_path))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures.is_empty():
		print("PASS: coast/bridge water entry and exit, real round colliders, buoyancy, camera-relative sea exploration, map/home, F cast/wait/reel, cancellation, fish conditions, journal, save/reload and backed-up restart")
	quit(0 if failures.is_empty() else 1)
