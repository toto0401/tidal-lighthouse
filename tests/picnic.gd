extends SceneTree

## Real E/F/movement input, physical seating, interruption and scene travel.
var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count := 8) -> void:
	for i in range(count):
		await physics_frame

func key(code: Key, pressed: bool, echo_event := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo_event
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func approach(seat: Node3D) -> void:
	game.picnic_rest.leave()
	game.player.position = seat.global_position + Vector3(signf(seat.position.x) * 0.6, 1.1, 0.45)
	game.player.velocity = Vector3.ZERO
	await frames(35)
	game._update_interaction()
	check(game.player.is_on_floor(), "Approach starts on dry ground")
	check(game.interact_target == seat, "Each cushion can be selected without another interaction stealing E")
	check(game.prompt_label.text.contains("坐下喝茶"), "Cushion advertises its use")

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.camera_yaw = game.player.rotation.y + 0.5
	game.camera_pitch = 0.34
	game.camera_distance = 6.5
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	game._update_camera(0.0)
	game.toast_label.modulate.a = 0
	await frames(4)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/茶席-" + label + ".png")

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	game.toggle_audio()
	await frames(35)
	var rest: Node = game.picnic_rest
	check(rest.seats.size() == 2 and rest.cups.size() == 2, "Both cushions and both cups are available")
	rest.sit(rest.seats[0])
	check(not rest.is_seated(), "Cannot sit from across the island")
	for index in range(2):
		var seat: Node3D = rest.seats[index]
		await approach(seat)
		var standing: Vector3 = game.player.position
		await tap(KEY_E)
		check(rest.seat == seat, "E sits on the selected cushion")
		check(game.player.position.distance_to(seat.global_position + Vector3(0, 0.49, 0)) < 0.01, "Keeper sits on top of the cushion")
		var facing: Vector3 = (rest.table.global_position - seat.global_position)
		facing.y = 0
		check(game.player.global_basis.z.dot(facing.normalized()) > 0.99, "Keeper faces the tea table")
		var seated: Vector3 = game.player.position
		key(KEY_E, true, true)
		await frames(12)
		key(KEY_E, false)
		check(rest.is_seated() and game.player.position.is_equal_approx(seated), "Holding E does not bounce between sitting and standing")
		check(game.keeper_appearance.legs[0].rotation.x < -1, "Sitting has an actual leg pose")
		check(game.controls_label.text.contains("喝茶") and not game.controls_label.text.contains("钓鱼"), "Seated controls describe tea instead of fishing")
		await shot("坐下-%d" % (index + 1))
		await tap(KEY_F)
		check(rest.sip_remaining > 0 and rest.held_cup.visible and not rest.table_cup.visible, "F picks up a cup instead of fishing")
		check(not game.water_activities.fish_requested and not game.water_activities.is_fishing(), "Drinking cannot queue a fishing action")
		var remaining: float = rest.sip_remaining
		await tap(KEY_F)
		check(rest.sip_remaining < remaining, "Repeated F cannot restart the sip")
		await frames(48)
		await shot("喝茶-%d" % (index + 1))
		await frames(120)
		check(rest.is_seated() and rest.sip_remaining == 0 and not rest.held_cup.visible and rest.table_cup.visible, "Cup returns to the table after drinking")
		check(game.player.position.is_equal_approx(seated), "Rest never drifts or falls through the cushion")
		await tap(KEY_E)
		check(not rest.is_seated() and game.player.position.distance_to(standing) < 0.05, "E returns to the safe approach position")
		check(absf(game.keeper_appearance.legs[0].rotation.y) < 0.001 and absf(game.keeper_appearance.legs[0].rotation.z) < 0.001, "Standing restores the normal leg pose")

	# The table itself offers the same action and chooses the nearer cushion.
	game.player.position = rest.table.global_position + Vector3(0, 1.0, -1.55)
	game.player.velocity = Vector3.ZERO
	await frames(35)
	game._update_interaction()
	check(game.interact_target == rest.table, "Tea table is reachable as an interaction")
	await tap(KEY_E)
	check(rest.is_seated(), "E at the table finds a seat")
	await tap(KEY_F)
	await tap(KEY_J)
	check(game.menu_is_open() and rest.is_seated() and rest.sip_remaining == 0, "Journal keeps the seat and safely puts the cup down")
	await tap(KEY_F)
	check(rest.sip_remaining == 0 and not game.water_activities.fish_requested, "Menu blocks drinking and fishing")
	await tap(KEY_ESCAPE)
	await tap(KEY_N)
	check(rest.is_seated() and game.night, "Can enjoy the tea seat at night")
	await tap(KEY_F)
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(rest.sip_remaining == 0 and rest.table_cup.visible, "Focus loss puts away the held cup")
	await tap(KEY_W)
	check(not rest.is_seated(), "WASD stands up and resumes walking")
	await frames(25)
	check(game.player.is_on_floor(), "Walking after sitting stays grounded")

	for code in [KEY_SPACE, KEY_SHIFT, KEY_G]:
		await approach(rest.seats[0])
		await tap(KEY_E)
		await tap(code)
		check(not rest.is_seated() and game.dash_remaining == 0 and game.player.velocity.y <= 0 and not game.gliding.requested and not game.gliding.active, "Space, Shift or G leaves without queued movement abilities")

	await approach(rest.seats[0])
	await tap(KEY_SPACE)
	await frames(5)
	rest.sit(rest.seats[0])
	check(not rest.is_seated(), "Cannot snap into the tea seat while airborne")
	await frames(75)
	await approach(rest.seats[0])
	await tap(KEY_E)
	await tap(KEY_F)
	game.return_home()
	await frames(35)
	check(not rest.is_seated() and game.player.position.distance_to(Vector3(0.6, 0.9, 5.5)) < 0.3, "Map return cancels resting without snapping back to the tea table")
	await approach(rest.seats[1])
	await tap(KEY_E)
	game.locations.switch_now("room")
	await frames(35)
	check(not rest.is_seated() and game.current_location == "room" and game.player.is_on_floor(), "Location changes clean up the seat and held cup")
	rest.sit(rest.seats[0])
	check(not rest.is_seated(), "Hidden island seats cannot be used from indoors")
	game.locations.switch_now("island")
	await frames(35)
	await approach(rest.seats[0])
	await tap(KEY_E)
	check(game.new_journey() and not rest.is_seated(), "New journey clears sitting state")
	await frames(35)
	check(game.player.position.distance_to(Vector3(0, 0.9, 4)) < 0.3, "New journey stays at its intended spawn")
	check(game.archive_count == 0 and game.fish_caught.is_empty(), "Resting leaves story and fishing progress untouched")
	for cup in rest.cups:
		check(cup.visible, "All table cups are restored after exits")
	game.queue_free()
	await frames(10)
	if failures.is_empty():
		print("PASS: both picnic seats, table interaction, seated pose, tea animation, key repeat, menus, focus, walking, jump/dash, travel and restart")
	quit(0 if failures.is_empty() else 1)
