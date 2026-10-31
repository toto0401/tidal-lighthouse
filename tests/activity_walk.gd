extends SceneTree

var game: Node3D
var failures: Array[String] = []
var held := {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func key(code: Key, down: bool) -> void:
	if held.get(code, false) == down:
		return
	held[code] = down
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func walk(destination: Vector2) -> void:
	var reached := false
	for step in range(1500):
		var offset := destination - Vector2(game.player.position.x, game.player.position.z)
		if offset.length() < 0.45:
			reached = true
			break
		key(KEY_A, offset.x < -0.14)
		key(KEY_D, offset.x > 0.14)
		key(KEY_W, offset.y < -0.14)
		key(KEY_S, offset.y > 0.14)
		await physics_frame
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		key(code, false)
	for frame in range(12):
		await physics_frame
	check(reached, "Walk to %s, actual %s" % [destination, game.player.position])

func visit(id: String) -> void:
	game._update_interaction()
	check(game.interact_target == game.activities.spots[id], "Walking reaches the E prompt for " + id)
	game.set_process(true)
	key(KEY_E, true)
	await process_frame
	key(KEY_E, false)
	await process_frame
	game.set_process(false)
	check(game.activities.active == id, "Actual E key opens " + id)
	var before: Vector3 = game.player.position
	key(KEY_W, true)
	key(KEY_SPACE, true)
	key(KEY_SHIFT, true)
	for frame in range(25):
		await physics_frame
	key(KEY_W, false)
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	check(game.player.position.is_equal_approx(before), "Activity blocks movement, jump and dash: " + id)
	key(KEY_ESCAPE, true)
	await process_frame
	key(KEY_ESCAPE, false)
	await process_frame
	check(not game.menu_is_open(), "Esc returns to the world: " + id)
	for frame in range(8):
		await physics_frame
	check(game.player.position.is_equal_approx(before), "Closing does not release queued movement: " + id)
	game.camera.rotation.y = 0

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	for frame in range(40):
		await physics_frame
	game.set_process(false)
	game.camera.rotation.y = 0
	for point in [Vector2(4,0), Vector2(4.5,-9.6)]:
		await walk(point)
	await visit("stones")
	for point in [Vector2(5,0), Vector2(12,3), Vector2(24,3), Vector2(30.5,5.8)]:
		await walk(point)
	await visit("flowers")
	for point in [Vector2(24,3), Vector2(12,3), Vector2(1,0), Vector2(-12,-2), Vector2(-23,-4), Vector2(-30,0)]:
		await walk(point)
	await visit("bells")
	for point in [Vector2(-23,-4), Vector2(-12,-2), Vector2(1,-4), Vector2(0,-11), Vector2(0,-28), Vector2(0,-36), Vector2(1.2,-38.3)]:
		await walk(point)
	await visit("stars")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: all four activities reached on foot from spawn, opened with E, modal physics and safe resume")
	quit(0 if failures.is_empty() else 1)
