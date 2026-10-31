extends SceneTree

## Exercise real movement, water dashes, and the player-facing boundary hint.
var game: Node3D
var failures: Array[String] = []
var held: Array[Key] = []

func _initialize() -> void:
	call_deferred("run")

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
	if pressed and not held.has(code):
		held.append(code)
	elif not pressed:
		held.erase(code)

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func release_keys() -> void:
	for code in held.duplicate():
		key(code, false)

func place(at: Vector2) -> void:
	release_keys()
	game.cancel_dash()
	game.dash_cooldown = 0.0
	game.player.position = Vector3(at.x, game.SWIM_HEIGHT, at.y)
	game.player.velocity = Vector3.ZERO
	game.swimming = false
	await frames(15)

func position_2d() -> Vector2:
	return Vector2(game.player.position.x, game.player.position.z)

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(20)
	game.set_process(false)
	game.camera.rotation = Vector3.ZERO
	# Four outer shores plus 12 m of nearby sea. Do not derive expectations from
	# the clamp helper: these assert the actual playable world limits.
	for edge in [
		{"at": Vector2(0, 28.75), "normal": Vector2.DOWN, "limit": 29.0, "out": KEY_S, "back": KEY_W},
		{"at": Vector2(59.75, 2), "normal": Vector2.RIGHT, "limit": 60.0, "out": KEY_D, "back": KEY_A},
		{"at": Vector2(-56.75, -5), "normal": Vector2.LEFT, "limit": 57.0, "out": KEY_A, "back": KEY_D},
		{"at": Vector2(0, -60.75), "normal": Vector2.UP, "limit": 61.0, "out": KEY_W, "back": KEY_S}
	]:
		await place(edge.at)
		key(edge.out, true)
		var furthest := 0.0
		for frame in range(90):
			await physics_frame
			furthest = maxf(furthest, position_2d().dot(edge.normal))
		check(furthest <= edge.limit + 0.01, "Held swim cannot leave the sea boundary: " + str(edge.at))
		check(game.swimming and absf(game.player.position.y - game.SWIM_HEIGHT) < 0.1, "Boundary preserves buoyancy")
		game._update_interaction()
		check(game.prompt_label.text.contains("远海"), "Near the boundary, show a readable turn-back hint")
		release_keys()
		key(edge.back, true)
		await frames(90)
		release_keys()
		check(position_2d().dot(edge.normal) < edge.limit - 2.5, "Swimmer can immediately turn back")
		game._update_interaction()
		check(not game.prompt_label.text.contains("远海"), "Returning to the islands clears the warning")
		await place(edge.at)
		key(edge.out, true)
		key(KEY_SHIFT, true)
		furthest = 0.0
		for frame in range(30):
			await physics_frame
			furthest = maxf(furthest, position_2d().dot(edge.normal))
		check(furthest <= edge.limit + 0.01, "Water dash cannot cross the boundary: " + str(edge.at))
		check(game.dash_remaining <= 0.0 and not game.dash_effects.wave.visible, "Hitting the sea edge ends the dash and wave")
		check(game.dash_cooldown > 0.0, "Boundary collision preserves the dash cooldown")
	# Tangential and diagonal input slide along the curved boundary, without
	# freezing the swimmer or escaping between the four cardinal test cases.
	await place(Vector2(0, 28.9))
	key(KEY_S, true)
	key(KEY_D, true)
	await frames(100)
	check(position_2d().length() <= 29.01 and game.player.position.x > 2.0, "Diagonal swimming slides along the curved edge")
	# Recover old/debug far-sea positions to the nearest allowed water, without
	# teleporting home or changing tide, time, or progress.
	await place(Vector2(90, 90))
	check(position_2d().distance_to(Vector2(32, 2)) <= 28.01 and game.swimming, "Far-sea positions recover to the nearest island's swimming area")
	check(game.player.position.y < 0.0, "Recovery leaves the swimmer in the water")
	# Channel overlap stays open between all islands.
	for at in [Vector2(17, 11), Vector2(-17, -9), Vector2(5, -20)]:
		await place(at)
		check(position_2d().distance_to(at) < 0.01 and game.swimming, "Inter-island swimming remains open: " + str(at))
	# Small position changes around the warning threshold must not flash it.
	await place(Vector2(0, 27.1))
	for z in [26.9, 27.1, 26.8]:
		await place(Vector2(0, z))
		game._update_interaction()
		check(game.prompt_label.text.contains("远海"), "Boundary hint stays stable around the warning threshold")
	await place(Vector2(0, 25.8))
	game._update_interaction()
	check(not game.prompt_label.text.contains("远海"), "Retreating far enough dismisses the stable hint")
	await place(Vector2(0, 28.8))
	key(KEY_TAB, true)
	await frames(2)
	release_keys()
	var stopped: Vector3 = game.player.position
	key(KEY_S, true)
	await frames(20)
	release_keys()
	check(game.player.position.is_equal_approx(stopped), "Map still pauses swimming at the boundary")
	game.menus.close()
	game.return_home()
	await frames(30)
	game._update_interaction()
	check(not game.swimming and game.player.is_on_floor(), "Return home restores walking")
	check(not game.prompt_label.text.contains("远海"), "Return home clears the boundary hint")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: four sea limits, continuous swim, dash/cooldown, buoyancy, edge sliding, warning/return, far-sea recovery, island channels, map/home")
	quit(0 if failures.is_empty() else 1)
