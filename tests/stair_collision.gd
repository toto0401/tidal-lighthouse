extends SceneTree

var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func place(at: Vector3) -> void:
	game.cancel_dash()
	game.dash_cooldown = 0.0
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.camera_yaw = 0
	await frames(35)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.toast_label.modulate.a = 0
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/楼梯碰撞-" + label + ".png")

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(30)
	game.locations.switch_now("room")
	await frames(30)
	# Cast down onto several visible tread edges, never accepting the room floor.
	for step in [0, 2, 4, 7]:
		var z: float = -1.91 - step * 0.34
		var expected_top: float = 0.195 + step * 0.23
		var query := PhysicsRayQueryParameters3D.create(Vector3(3.8, 5, z), Vector3(3.8, -0.2, z))
		query.exclude = [game.player.get_rid()]
		var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.position.y >= expected_top - 0.02, "Tread %d supports the player above its visible surface; ray hit %s" % [step, hit.get("position", Vector3.ZERO)])
	await place(Vector3(3.8, 1.1, -0.8))
	key(KEY_W, true)
	await frames(90)
	key(KEY_W, false)
	await frames(12)
	check(game.player.position.z < -3.8 and game.player.position.y > 2.1 and game.player.is_on_floor(), "Walking up stairs raises the player onto the treads: %s" % game.player.position)
	check(game.player.position.z > -4.65, "The back wall remains solid at the top of the stairs")
	await shot("正常上楼")
	game._update_interaction()
	check(game.interact_target != null and game.interact_target.name == "TowerStairs", "E to climb the tower remains reachable from the upper stairs")
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(40)
	check(game.current_location == "top", "E from the upper stairs reaches the tower top")
	game.locations.switch_now("room")
	await frames(40)
	check(game.player.is_on_floor() and game.player.position.z > -1.5, "Returning downstairs spawns clear of the stairs")
	# An approach from either side must not enter the filled stair volume.
	for side in [-1.0, 1.0]:
		await place(Vector3(3.8 + side * 2.0, 1.1, -3.5))
		var move_key := KEY_D if side < 0 else KEY_A
		key(move_key, true)
		await frames(75)
		key(move_key, false)
		await frames(8)
		check(side * (game.player.position.x - 3.8) > 1.25, "Side %s cannot walk through the stair body: %s" % [side, game.player.position])
	# At stair height, the visible rails must also block horizontal movement.
	for move_key in [KEY_A, KEY_D]:
		await place(Vector3(3.8, 3, -3.3))
		key(move_key, true)
		key(KEY_SHIFT, true)
		await frames(45)
		key(KEY_SHIFT, false)
		key(move_key, false)
		check(absf(game.player.position.x - 3.8) < 0.75 and game.player.position.y > 1.3, "A sideways dash cannot pass through either staircase railing: %s" % game.player.position)
	await shot("栏杆阻挡")
	await place(Vector3(3.8, 3, -4.1))
	key(KEY_S, true)
	await frames(100)
	key(KEY_S, false)
	await frames(20)
	check(game.player.position.z > -1.3 and game.player.position.y < 1.0 and game.player.is_on_floor(), "Walking downstairs returns to the room floor without getting stuck")
	await place(Vector3(3.8, 1.1, -0.8))
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(45)
	key(KEY_SHIFT, false)
	key(KEY_W, false)
	await frames(20)
	check(game.player.position.z < -3.5 and game.player.position.y > 2.1, "A forward dash travels over the stairs, never through them")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: solid staircase, uphill/downhill walking, side approach, railing dash collision, stair dash, upper E portal and safe return spawn")
	quit(0 if failures.is_empty() else 1)
