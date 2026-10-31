extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func space(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

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
	var ground: float = game.player.position.y
	check(game.player.is_on_floor(), "Player must start on the ground")
	space(true)
	await frames(6)
	check(game.player.position.y > ground + 0.3, "Space must launch the player")
	check(game.player.velocity.y > 0, "Jump must initially move upward")
	check(game.tide_low, "Space must not change the tide")
	space(false)
	await frames(6)
	var speed_before: float = game.player.velocity.y
	space(true)
	await frames(3)
	check(game.player.velocity.y < speed_before, "Space in midair must not trigger a second jump")
	space(false)
	await frames(70)
	check(game.player.is_on_floor(), "Jump must return to the ground")
	check(absf(game.player.position.y - ground) < 0.04, "Landing must return to the original ground height")
	space(true)
	await frames(6)
	check(game.player.position.y > ground + 0.3, "Player must be able to jump again after landing")
	await frames(90)
	check(game.player.is_on_floor(), "Holding Space must not cause automatic repeated jumps")
	space(false)
	await Travel.travel(game,"room")
	game.player.position = Vector3(0,1.1,2.3)
	game.player.velocity = Vector3.ZERO
	await frames(40)
	var room_floor: float = game.player.position.y
	space(true)
	await frames(6)
	check(game.player.position.y > room_floor + 0.3, "Jump must also work on the raised room floor")
	space(false)
	await frames(80)
	check(game.player.is_on_floor() and absf(game.player.position.y - room_floor) < 0.04, "Jump must land safely in the room")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: Space jump, gravity and landing, no midair double jump, no auto-repeat, no tide conflict")
	quit(0 if failures.is_empty() else 1)
