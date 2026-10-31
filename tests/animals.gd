extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	await frames(5)
	var wildlife: Node3D = game.animals
	check(wildlife.animals.size() == 8, "Eight island animals must spawn")
	var counts := {"rabbit": 0, "crab": 0, "gull": 0}
	for animal in wildlife.animals:
		var kind: String = animal.get_meta("animal_kind")
		counts[kind] += 1
		check(animal.get_node("Model").find_children("*", "MeshInstance3D", true, false).size() > 5, "Animal must have visible model parts: " + animal.name)
		check(animal.find_children("*", "CollisionObject3D", true, false).is_empty(), "Wildlife must not block movement: " + animal.name)
		check(animal.is_in_group("interactable"), "Animal must support interaction: " + animal.name)
		var query := PhysicsRayQueryParameters3D.create(animal.position + Vector3.UP, animal.position - Vector3.UP)
		query.exclude = [game.player.get_rid()]
		var hit := wildlife.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - animal.position.y) < 0.06, "Animal must stand on its island surface: " + animal.name)
	check(counts == {"rabbit": 3, "crab": 2, "gull": 3}, "Rabbit, crab and gull populations must be present")

	# Real keyboard greetings exercise main-scene selection and animation together.
	wildlife.set_physics_process(false)
	for id in ["milk", "coral", "sail"]:
		var animal: Node3D = wildlife.get_node("Animal_" + id)
		var entry: Dictionary = wildlife.critters[int(animal.get_meta("animal_index"))]
		game.player.position = animal.position + Vector3(0.7, 0.8, 0)
		game.player.velocity = Vector3.ZERO
		game._update_interaction()
		check(game.interact_target == animal, "Approaching selects the animal: " + id)
		await tap(KEY_E)
		check(entry.mode == "greet" and entry.heart_left > 0, "E must greet each animal species: " + id)
		check(animal.get_node("GreetingHeart").visible, "Greeting must display its heart: " + id)
		check(str(animal.get_meta("animal_name")) in game.toast_label.text, "Greeting must name the animal: " + id)
		check(not wildlife.can_interact(animal), "Greeting cooldown prevents repeated triggering: " + id)
		await tap(KEY_E)
		check(is_equal_approx(entry.heart_left, 2.1), "Repeated E must not restart a greeting: " + id)

	var rabbit: Node3D = wildlife.get_node("Animal_milk")
	var rabbit_entry: Dictionary = wildlife.critters[0]
	# Put wildlife nearer than a story object to test selection priority, not distance.
	var collectible: Node3D = game.world_node("Collectible_wood")
	game.player.position = collectible.position + Vector3(1.2, 0.8, 0)
	rabbit.position = game.player.position - Vector3(0.2, 0.8, 0)
	rabbit_entry.greet_cooldown = 0.0
	game._update_interaction()
	check(game.interact_target == collectible, "Nearby animal must not replace a collectible interaction")
	var activity: Node3D = null
	for node in get_nodes_in_group("interactable"):
		if node.has_meta("activity_id"):
			activity = node
			break
	check(activity != null, "An island activity must exist")
	if activity:
		game.player.position = activity.position + Vector3(1.2, 0.8, 0)
		rabbit.position = game.player.position - Vector3(0.2, 0.8, 0)
		game._update_interaction()
		check(game.interact_target == activity, "Nearby animal must not replace an island activity")
	var door: Node3D = null
	for node in get_nodes_in_group("interactable"):
		if node.has_meta("destination") and node.is_visible_in_tree():
			door = node
			break
	check(door != null, "The island lighthouse entrance must exist")
	if door:
		game.player.position = door.global_position + Vector3(1.0, 0.8, 0)
		rabbit.global_position = game.player.global_position - Vector3(0.2, 0.8, 0)
		game._update_interaction()
		check(game.interact_target == door, "Nearby animal must not replace the lighthouse door interaction")
	rabbit.position = rabbit_entry.home
	for entry in wildlife.critters:
		entry.mode = "idle"
		entry.timer = 0.1
		entry.heart_left = 0.0
		entry.greet_cooldown = 0.0
	game.player.position = Vector3(-8, 0.9, 0)
	game.player.velocity = Vector3.ZERO
	wildlife.set_physics_process(true)
	var moved := {"rabbit": false, "crab": false, "gull": false}
	var flew := false
	var left_habitat := false
	for frame in range(3600):
		await physics_frame
		for entry in wildlife.critters:
			var offset: Vector3 = entry.node.position - entry.home
			if offset.length() > 0.25:
				moved[entry.kind] = true
			if entry.mode == "fly":
				flew = flew or offset.y > 1.0
			elif Vector2(offset.x, offset.z).length() > float(entry.radius) + 0.02 or absf(offset.y) > 0.01:
				left_habitat = true
	check(moved.rabbit and moved.crab and moved.gull, "All species must move during normal island play")
	check(flew, "Seagulls must rise above the island during flight")
	check(not left_habitat, "Ground animals and landed birds must stay in their habitats")
	# A stationary observer should still see nearby animals going about their day.
	game.player.position = rabbit.position + Vector3(1.2, 0.8, 0)
	game.player.velocity = Vector3.ZERO
	var observed_start: Vector3 = rabbit.position
	var observer_motion := 0.0
	for frame in range(900):
		await physics_frame
		observer_motion = maxf(observer_motion, rabbit.position.distance_to(observed_start))
	check(observer_motion > 0.25, "Nearby observation must not freeze a rabbit indefinitely")
	game.player.position = Vector3(-8, 0.9, 0)

	var gull: Node3D = wildlife.get_node("Animal_sail")
	var gull_entry: Dictionary = wildlife.critters[5]
	wildlife._begin_flight(gull_entry)
	check(not wildlife.can_interact(gull), "Flying birds must not offer unreachable interaction prompts")
	await frames(361)
	check(gull_entry.mode != "fly" and gull.position.distance_to(gull_entry.home) < 0.03, "Seagull flight must land at its home")
	wildlife._begin_flight(gull_entry)
	await tap(KEY_N)
	await frames(365)
	check(gull_entry.mode == "sleep" and gull.position.distance_to(gull_entry.home) < 0.03, "Nightfall during flight must let the gull land and rest")
	for entry in wildlife.critters:
		if entry.kind != "crab" and entry.mode != "fly":
			check(entry.mode == "sleep", "Rabbits and landed gulls must rest at night")
		elif entry.kind == "crab":
			check(entry.mode != "sleep", "Crabs remain awake at night")
	await tap(KEY_N)
	await frames(3)
	check(rabbit_entry.mode != "sleep", "Daylight must wake sleeping rabbits")

	# Approaching in a dash provokes a bounded reaction without physical obstacles.
	rabbit_entry.mode = "idle"
	game.set_physics_process(false)
	game.player.position = rabbit.position + Vector3(0.6, 0.8, 0)
	game.dash_remaining = 0.3
	await frames(2)
	check(rabbit_entry.mode == "scamper", "Rabbits must move aside when approached in a dash")
	game.player.position = gull.position + Vector3(0.6, 0.8, 0)
	gull_entry.mode = "idle"
	await frames(2)
	check(gull_entry.mode == "fly", "Seagulls must take flight when approached in a dash")
	game.cancel_dash()
	game.set_physics_process(true)

	await tap(KEY_J)
	var age: float = wildlife.age
	var position: Vector3 = rabbit.position
	await frames(30)
	check(is_equal_approx(wildlife.age, age) and rabbit.position == position, "Menus pause animal movement")
	await tap(KEY_ESCAPE)
	await Travel.travel(game, "room")
	age = wildlife.age
	await frames(30)
	check(not wildlife.is_visible_in_tree() and is_equal_approx(wildlife.age, age), "Indoor scenes hide and pause island wildlife")
	check(not wildlife.can_interact(rabbit), "Indoor scenes must not allow island animal interaction")
	await Travel.travel(game, "island")
	check(wildlife.is_visible_in_tree(), "Returning outdoors restores the animals")
	await frames(5)
	check(wildlife.age > age, "Returning outdoors resumes animal movement")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: animal populations, ground placement, collision-free models, E greetings, cooldown, story priority, bounded roaming, flight, night rest, dash response, menus and scene travel")
	quit(0 if failures.is_empty() else 1)
