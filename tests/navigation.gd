extends SceneTree

## Walk a complete journey through the physical world without teleporting the player.
## Run with --fixed-fps 60 for deterministic accelerated simulation.
var failures: Array[String] = []
var keys_held: Dictionary = {}
var highest_y := 0.0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: Key, pressed: bool) -> void:
	if keys_held.get(code, false) == pressed:
		return
	keys_held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func stop() -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		key(code, false)

func tap(code: Key) -> void:
	key(code, true)
	await process_frame
	key(code, false)
	await process_frame

func walk(game: Node3D, point: Vector2, radius := 0.6) -> bool:
	var reached := false
	for step in range(1200):
		var delta := point - Vector2(game.player.position.x, game.player.position.z)
		if delta.length() < radius:
			reached = true
			break
		key(KEY_D, delta.x > 0.2)
		key(KEY_A, delta.x < -0.2)
		key(KEY_S, delta.y > 0.2)
		key(KEY_W, delta.y < -0.2)
		await physics_frame
		var floor_height: float = game.locations.active_scene.global_position.y if game.current_location == "top" else 0.0
		highest_y = maxf(highest_y, game.player.position.y - floor_height)
	stop()
	for i in range(10):
		await physics_frame
	check(reached, "Walking must reach %s; stopped at %s" % [point, game.player.position])
	return reached

func record(game: Node3D, id: String) -> void:
	var target: Node3D = game.world_node("Collectible_" + id)
	check(target.visible, "Walking route must find visible object " + id)
	await walk(game, Vector2(target.position.x, target.position.z), 1.1)
	game._update_interaction()
	check(game.interact_target == target, "Walking route must reach interaction range for " + id)
	await tap(KEY_E)
	check(game.discovered.has(id), "Physical E input records " + id)

func restore(game: Node3D, node_name: String) -> void:
	var target: Node3D = game.world_node(node_name)
	await walk(game, Vector2(target.global_position.x, target.global_position.z), 1.0)
	game._update_interaction()
	check(game.interact_target == target, "Restoration marker is reachable on foot: " + node_name)
	await tap(KEY_E)

func travel_on_foot(game: Node3D, portal_name: String, destination: String) -> void:
	var target: Node3D = game.world_node(portal_name)
	await walk(game, Vector2(target.global_position.x, target.global_position.z), 1.15)
	game._update_interaction()
	check(game.interact_target == target, "Walking reaches doorway: " + portal_name)
	await tap(KEY_E)
	for frame in range(90):
		await physics_frame
		if not game.locations.transitioning:
			break
	check(game.current_location == destination, "Doorway leads to " + destination)

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	# Keep the heading fixed so WASD uses the same cardinal directions throughout.
	game.camera.rotation = Vector3.ZERO
	game.camera_yaw = 0.0
	for i in range(30):
		await physics_frame
		highest_y = maxf(highest_y, game.player.position.y)
	check(game.player.is_on_floor(), "Default spawn must settle safely on the island")
	await record(game, "wood")
	await walk(game, Vector2(2, 0))
	await record(game, "glass")
	await record(game, "shell")
	await walk(game, Vector2(1, 1))
	await walk(game, Vector2(-4, -0.5))
	await travel_on_foot(game, "TowerDoor", "room")
	await walk(game, Vector2(2.8, 0))
	await travel_on_foot(game, "TowerStairs", "top")
	await restore(game, "RestorationPoint")
	check(game.repaired, "Walking route completes the lighthouse")
	await travel_on_foot(game, "TopStairs", "room")
	await walk(game, Vector2(1.5, 1.5))
	await travel_on_foot(game, "RoomExit", "island")
	await walk(game, Vector2(-3, 0))
	await walk(game, Vector2(2, 7))
	await walk(game, Vector2(12, 3))
	await walk(game, Vector2(24, 3))
	await record(game, "seed")
	await walk(game, Vector2(24, 3))
	await walk(game, Vector2(12, 3))
	await record(game, "moss")
	await tap(KEY_T)
	await walk(game, Vector2(-12, -2))
	await walk(game, Vector2(-23, -4))
	await record(game, "feather")
	await walk(game, Vector2(-23, -4))
	await walk(game, Vector2(-12, -2))
	await walk(game, Vector2(0, 0))
	await restore(game, "GardenRestore")
	check(game.garden_repaired, "Walking route completes the flower garden")
	await record(game, "ribbon")
	await tap(KEY_T)
	await record(game, "coral")
	await tap(KEY_N)
	await walk(game, Vector2(0, -11))
	await walk(game, Vector2(0, -28))
	await record(game, "stardust")
	await walk(game, Vector2(0, -28))
	await walk(game, Vector2(0, -11))
	await restore(game, "CoveRestore")
	check(game.cove_repaired and game.archive_count == 9, "Walking route restores the entire island with all nine records")
	check(game.menus.current_page == "ending", "The on-foot journey reaches the ending")
	check(highest_y < 1.6, "Ordinary walking along the full route never launches the player")
	stop()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: full nine-object journey on foot with WASD/E/T/N, reachable repair points, safe spawn, no walking launches, final ending")
	quit(0 if failures.is_empty() else 1)
