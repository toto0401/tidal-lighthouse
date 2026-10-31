extends SceneTree

## Exercise the real Shift input and physics without opening or modifying saves.
var failures: Array[String] = []
var game: Node3D
var held: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func key(code: Key, down: bool, echo_event := false) -> void:
	held[code] = down
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
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

func place(at: Vector3, heading := 0.0, camera_heading := 0.0, in_water := false) -> void:
	for code in held.keys():
		if held[code]:
			key(code, false)
	if game.menu_is_open():
		game.menus.close()
	game.cancel_dash()
	game.dash_effects.clear_trail()
	game.dash_cooldown = 0.0
	game.swimming = false
	game.player.position = at
	game.player.rotation.y = heading
	game.player.velocity = Vector3.ZERO
	game.camera_yaw = camera_heading
	game.camera_focus = at + Vector3(0, 0.6, 0)
	await frames(40)
	check(game.swimming if in_water else game.player.is_on_floor(), "Fixture starts %s at %s" % ["afloat" if in_water else "grounded", at])

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func visible_ripples() -> int:
	var count := 0
	for ripple in game.dash_effects.trail:
		if ripple.visible:
			count += 1
	return count

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	check(InputMap.has_action("wave_dash"), "Wave dash has an input action")

	# The straight northern bridge offers an unobstructed measured route.
	await place(Vector3(0, 1.1, -24))
	var start: Vector3 = game.player.position
	key(KEY_SHIFT, true)
	await frames(8)
	check(game.dash_remaining > 0.0, "Pressing physical Shift starts the dash")
	check(game.dash_effects.wave.visible and visible_ripples() > 0, "Dashing shows a crest and trailing water ripples")
	check(game.dash_label.text.contains("踏浪中"), "HUD announces the active dash")
	check(game.player.is_on_floor(), "Dash keeps the character grounded")
	await frames(38)
	var end: Vector3 = game.player.position
	var travel := flat_distance(start, end)
	check(travel > 7.5 and travel < 8.1, "A free dash travels about 7.8 m; measured %.3f m" % travel)
	check(absf(end.y - start.y) < 0.05, "Dash does not launch the character into the air")
	check(game.dash_remaining <= 0.0 and game.dash_cooldown > 1.2, "Dash stops and enters cooldown")
	check(not game.dash_effects.wave.visible, "The crest disappears when the dash finishes")
	check(game.player.velocity.length() < 0.1, "A completed stationary dash leaves no fast momentum")
	key(KEY_SHIFT, false)
	await tap(KEY_SHIFT)
	check(flat_distance(end, game.player.position) < 0.02, "A second press during cooldown cannot move the player")
	key(KEY_SHIFT, true)
	await frames(150)
	check(flat_distance(end, game.player.position) < 0.02, "Holding Shift never repeats or queues a dash after cooldown")
	check(visible_ripples() == 0, "Water ripples completely fade after the dash")
	check(game.dash_label.text.contains("就绪"), "HUD returns to ready after cooldown")
	key(KEY_SHIFT, true, true)
	await frames(4)
	check(flat_distance(end, game.player.position) < 0.02, "Keyboard echo cannot trigger another dash")
	key(KEY_SHIFT, false)
	await tap(KEY_SHIFT)
	check(game.dash_remaining > 0.0, "A new press after cooldown activates the ability again")

	await place(Vector3(0, 1.1, -24))
	key(KEY_S, true)
	await frames(25)
	start = game.player.position
	await frames(60)
	travel = flat_distance(start, game.player.position)
	check(absf(travel - 2.8) < 0.12, "Ordinary walking stays at 2.8 m/s; measured %.3f m" % travel)
	key(KEY_S, false)

	# Direction follows the rotated camera when moving, and facing when idle.
	await place(Vector3(5, 1.1, 0), 0.0, PI / 2)
	start = game.player.position
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(8)
	var offset: Vector3 = game.player.position - start
	check(offset.x < -1.1 and absf(offset.z) < 0.12, "W + Shift follows camera-relative forward after orbiting")
	await place(Vector3(5, 1.1, 0), PI / 2)
	start = game.player.position
	key(KEY_SHIFT, true)
	await frames(8)
	offset = game.player.position - start
	check(offset.x > 1.1 and absf(offset.z) < 0.12, "Shift while idle follows the character's facing direction")

	await place(Vector3(0, 1.1, -24))
	await tap(KEY_SPACE)
	check(not game.player.is_on_floor(), "Jump fixture is airborne")
	start = game.player.position
	await tap(KEY_SHIFT)
	await frames(70)
	check(flat_distance(start, game.player.position) < 0.02, "Shift while airborne neither dashes nor queues a landing dash")
	check(game.player.is_on_floor(), "Airborne Shift still permits a normal landing")
	await tap(KEY_SHIFT)
	check(game.dash_remaining > 0.0, "Dash can activate after landing")
	start = game.player.position
	await tap(KEY_SPACE)
	check(game.dash_remaining <= 0.0 and not game.dash_effects.wave.visible, "Jump cancels an active dash and its crest")
	await frames(8)
	check(game.player.position.y > start.y + 0.35, "Jump during a dash still launches a normal jump")
	check(flat_distance(start, game.player.position) < 0.25, "Jump cancellation removes dash momentum")

	# Solid objects still stop dashes; open coasts and bridge edges allow swimming.
	await place(game.locations.DOOR_RETURN + Vector3(0, 0, -2), 0.0)
	start = game.player.position
	await tap(KEY_SHIFT)
	await frames(45)
	check(game.player.position.z < game.LighthouseLayout.DOOR_POSITION.z - 0.2 and game.player.position.z > start.z + 1.0, "Dashing toward the lighthouse stops before its solid wall")
	check(game.dash_remaining <= 0.0 and game.player.is_on_floor(), "Wall impact ends the dash safely")
	await place(Vector3(0, 1.1, 13), 0.0)
	await tap(KEY_SHIFT)
	await frames(55)
	check(game.player.position.z > 17.8, "Dashing at the south shore can enter open water")
	check(game.swimming and game.dash_remaining <= 0.0, "A dash from land finishes afloat")
	await place(Vector3(0, 1.1, -21), PI / 2)
	await tap(KEY_SHIFT)
	await frames(55)
	check(game.player.position.x > 3.0 and game.player.position.y > -0.3, "Sideways dash can leave the bridge and float in the sea")
	check(game.dash_remaining <= 0.0 and game.swimming, "Leaving a bridge transitions safely to swimming")
	await place(Vector3(0, 1.1, -12), PI)
	await tap(KEY_SHIFT)
	await frames(45)
	check(game.player.position.z < -19.5 and game.player.is_on_floor(), "Forward dash crosses from the main island onto the bridge")
	await place(Vector3(0, 1.1, -25), PI)
	await tap(KEY_SHIFT)
	await frames(45)
	check(game.player.position.z < -32.5 and game.player.is_on_floor(), "Forward dash crosses from the bridge onto the northern island")

	await place(Vector3(0, 1.1, -24))
	await tap(KEY_SHIFT)
	await tap(KEY_TAB)
	check(game.menu_is_open(), "Map opens during a dash")
	start = game.player.position
	check(game.dash_remaining <= 0.0 and not game.dash_effects.wave.visible, "Opening a menu cancels the dash")
	await tap(KEY_SHIFT)
	await frames(20)
	check(game.player.position.is_equal_approx(start), "Shift is blocked while the map is open")
	await tap(KEY_ESCAPE)
	await frames(120)
	check(flat_distance(start, game.player.position) < 0.02, "Closing a menu never releases a queued dash")
	await tap(KEY_SHIFT)
	check(game.dash_remaining > 0.0, "The ability works after resuming from the map")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	start = game.player.position
	await frames(10)
	check(game.dash_remaining <= 0.0 and flat_distance(start, game.player.position) < 0.02, "Losing window focus cancels dash momentum")

	await place(Vector3(0, 1.1, -24))
	await tap(KEY_SHIFT)
	check(visible_ripples() > 0, "Return-home fixture has an active trail")
	game.return_home()
	check(game.dash_remaining <= 0.0 and not game.dash_effects.wave.visible and visible_ripples() == 0, "Return home clears the ability and all trails")
	await frames(50)
	check(game.player.is_on_floor() and flat_distance(game.player.position, Vector3(0.6, 0, 5.5)) < 0.02, "Returning home during a dash lands at home without drifting")
	check(game.archive_count == 0 and not game.repaired, "Using wave dash does not change game progression")

	# Swimming shares the same one-shot Shift ability, timing and direction rules.
	# Leave a full dash of open water inside the nearby-sea boundary.
	await place(Vector3(32, 0, 20), 0, 0, true)
	check(game.dash_label.text.contains("水上冲刺") and game.dash_label.text.contains("就绪"), "Swimming HUD advertises Shift when ready")
	start = game.player.position
	key(KEY_SHIFT, true)
	await frames(8)
	check(game.swimming and game.dash_remaining > 0.0, "Physical Shift starts a dash while swimming")
	check(game.dash_label.text.contains("水上冲刺") and game.dash_label.text.contains("踏浪中"), "Swimming HUD shows active dash progress")
	check(game.dash_effects.wave.visible and visible_ripples() > 0, "Water dash shows its crest and trail")
	check(absf(game.dash_effects.wave.position.y - game.WATER_LEVEL - 0.04) < 0.001, "Crest stays on top of the sea instead of underwater")
	for ripple in game.dash_effects.trail:
		if ripple.visible:
			check(ripple.position.y > game.WATER_LEVEL, "Every water dash ripple remains above the sea")
	await frames(38)
	end = game.player.position
	travel = flat_distance(start, end)
	check(travel > 7.5 and travel < 8.1, "A free swimming dash travels about 7.8 m; measured %.3f m" % travel)
	check(absf(end.y - game.SWIM_HEIGHT) < 0.1 and game.swimming, "Water dash preserves buoyancy")
	check(game.dash_cooldown > 1.2 and game.dash_label.text.contains("蓄能"), "Water dash shows the shared cooldown")
	check(not game.dash_effects.wave.visible, "Water dash crest stops with the ability")
	key(KEY_SHIFT, false)
	await tap(KEY_SHIFT)
	check(flat_distance(end, game.player.position) < 0.02, "Water cooldown prevents early reactivation")
	key(KEY_SHIFT, true)
	await frames(150)
	check(flat_distance(end, game.player.position) < 0.02, "Holding Shift cannot repeat a swimming dash")
	key(KEY_SHIFT, true, true)
	await frames(4)
	check(game.dash_remaining <= 0.0, "Keyboard echo cannot restart a swimming dash")
	key(KEY_SHIFT, false)
	await tap(KEY_SHIFT)
	check(game.dash_remaining > 0.0, "A fresh press reactivates water dash after cooldown")
	await tap(KEY_SPACE)
	check(game.swimming and game.dash_remaining <= 0 and game.player.position.y < 0, "Space safely cancels water dash without an airborne jump")

	await place(Vector3(32, 0, 20), 0, PI / 2, true)
	start = game.player.position
	key(KEY_W, true)
	await tap(KEY_SHIFT)
	await frames(4)
	offset = game.player.position - start
	check(offset.x < -1.1 and absf(offset.z) < 0.12, "Swimming dash follows the rotated camera with WASD")
	await place(Vector3(32, 0, 20), PI / 2, 0, true)
	start = game.player.position
	await tap(KEY_SHIFT)
	await frames(4)
	check(game.player.position.x > start.x + 1.1 and absf(game.player.position.z - start.z) < 0.12, "Idle swimming dash follows facing")

	await place(Vector3(0, 1.1, 16.5))
	await tap(KEY_SHIFT)
	await frames(25)
	check(game.swimming and game.dash_remaining > 0, "An active land dash continues after entering the sea")
	await place(Vector3(0, 0, 18.5), PI, 0, true)
	await tap(KEY_SHIFT)
	await frames(10)
	check(not game.swimming and game.player.is_on_floor() and game.dash_remaining > 0, "Water dash climbs onto a low bank and continues on land")
	await place(Vector3(4, 0, -20), -PI / 2, 0, true)
	await tap(KEY_SHIFT)
	await frames(10)
	check(game.player.is_on_floor() and game.dash_remaining > 0, "Water dash can climb back onto a bridge")
	# An actual wall in the sea must still stop the dash rather than be climbed.
	game._add_box("SwimDashTestWall", Vector3(0.4, 4, 4), Vector3(35, 0, 20), Color.WHITE, true)
	await place(Vector3(32, 0, 20), PI / 2, 0, true)
	await tap(KEY_SHIFT)
	await frames(25)
	check(game.player.position.x < 34.5 and game.dash_remaining <= 0 and game.swimming, "Water dash cannot tunnel through or climb a solid wall")
	game.world_node("SwimDashTestWallBody").queue_free()
	game.world_node("SwimDashTestWall").queue_free()

	await place(Vector3(32, 0, 20), 0, 0, true)
	await tap(KEY_SHIFT)
	await tap(KEY_TAB)
	start = game.player.position
	check(game.dash_remaining <= 0 and not game.dash_effects.wave.visible, "Map cancels water dash")
	await tap(KEY_SHIFT)
	await frames(10)
	check(game.player.position.is_equal_approx(start), "Menu blocks swimming dash input")
	await tap(KEY_ESCAPE)
	await frames(110)
	check(flat_distance(start, game.player.position) < 0.02, "Resuming swimming has no queued dash or momentum")
	await tap(KEY_SHIFT)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.dash_remaining <= 0 and not game.dash_effects.wave.visible, "Focus loss cancels water dash")
	await frames(110)
	await tap(KEY_SHIFT)
	game.return_home()
	await frames(40)
	check(not game.swimming and game.player.is_on_floor() and game.dash_remaining <= 0 and visible_ripples() == 0, "Return home clears water dash and lands safely")
	for code in held.keys():
		if held[code]:
			key(code, false)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: land/swim Shift dash, 7.8 m distance, cooldown, no hold/echo repeats, camera/facing direction, buoyancy, water-surface VFX and HUD, land/water/bridge transitions, solid walls, Space cancellation, menus, focus and return home")
	quit(0 if failures.is_empty() else 1)
