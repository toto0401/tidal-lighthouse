extends SceneTree

## Observe the actual physics loop without E or movement input.
var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames(15)
	game.set_physics_process(false)
	game.set_process(false)
	game.night = false
	game.swimming = false
	# Each animal must resume its own routine while watched at greeting range.
	for entry in game.animals.critters:
		var animal: Node3D = entry.node
		animal.position = entry.home
		entry.mode = "idle"
		entry.timer = 0.05
		entry.heart_left = 0.0
		entry.greet_cooldown = 0.0
		game.player.position = animal.global_position + Vector3(1, 0.8, 0)
		var start := animal.position
		var furthest := 0.0
		var stayed_safe := true
		for frame in range(720):
			await physics_frame
			furthest = maxf(furthest, start.distance_to(animal.position))
			if entry.mode != "fly":
				var home: Vector3 = entry.home
				stayed_safe = stayed_safe and Vector2(animal.position.x - home.x, animal.position.z - home.z).length() <= float(entry.radius) + 0.01
		check(furthest > 0.2, "Nearby observer does not freeze " + str(animal.name) + ": displacement %.3f m" % furthest)
		check(stayed_safe, "Ground wandering stays inside the habitat: " + str(animal.name))
		check(not animal.get_node("GreetingHeart").visible, "Watching alone does not trigger an interaction")
	# The restored seal also explores when the player is nowhere near it.
	game.cove_repaired = true
	game.island_life.apply_state()
	game.player.position = Vector3(-5, 1, 3)
	var seal: Node3D = game.island_life.seal
	var seal_start := seal.position
	var seal_furthest := 0.0
	for frame in range(900):
		await physics_frame
		seal_furthest = maxf(seal_furthest, seal_start.distance_to(seal.position))
		check(seal.position.x >= 2.0 and seal.position.x <= 8.0 and seal.position.z >= -9.0 and seal.position.z <= -4.0, "Seal stays near its cove")
	check(seal_furthest > 0.3, "Seal wanders without being approached or petted")
	game.player.position = seal.global_position + Vector3(0.6, 0.7, 0)
	game._update_interaction()
	check(game.interact_target == seal, "Wandering seal remains reachable for E")
	game._interact()
	var seal_greeted_at := seal.position
	await frames(90)
	check(seal.position.distance_to(seal_greeted_at) < 0.01, "Petting briefly stops the seal")
	seal_furthest = 0.0
	for frame in range(720):
		await physics_frame
		seal_furthest = maxf(seal_furthest, seal_greeted_at.distance_to(seal.position))
	check(seal_furthest > 0.3, "Seal resumes its own routine after being petted")
	# Greeting remains reliable, then the critter returns to its own activities.
	var rabbit: Dictionary = game.animals.critters[0]
	rabbit.node.position = rabbit.home
	rabbit.mode = "idle"
	rabbit.greet_cooldown = 0.0
	game.player.position = rabbit.node.global_position + Vector3(0.8, 0.8, 0)
	game._update_interaction()
	check(game.interact_target == rabbit.node and game.prompt_label.text.contains("E"), "Nearby autonomous animal keeps the E interaction hint")
	game._interact()
	check(rabbit.mode == "greet" and rabbit.node.get_node("GreetingHeart").visible, "E starts the actual greeting")
	var greeted_at: Vector3 = rabbit.node.position
	await frames(90)
	check(rabbit.node.position.distance_to(greeted_at) < 0.01, "Animal stays still during the brief greeting")
	var resumed_distance := 0.0
	for frame in range(900):
		await physics_frame
		resumed_distance = maxf(resumed_distance, greeted_at.distance_to(rabbit.node.position))
	check(resumed_distance > 0.2, "Animal resumes wandering after greeting even when the player stays nearby")
	game.menus.open_pause()
	var frozen_positions: Array[Vector3] = []
	for animal in game.animals.animals:
		frozen_positions.append(animal.position)
	var seal_paused := seal.transform
	var seal_head_paused: Transform3D = seal.get_node("SealHead").transform
	var age_paused: float = game.animals.age
	await frames(90)
	for index in frozen_positions.size():
		check(game.animals.animals[index].position.is_equal_approx(frozen_positions[index]), "Pause stops animal movement")
	check(is_equal_approx(game.animals.age, age_paused), "Pause stops idle animation time")
	check(seal.transform.is_equal_approx(seal_paused), "Pause stops the seal")
	check(seal.get_node("SealHead").transform.is_equal_approx(seal_head_paused), "Pause also freezes the seal's idle animation")
	game.menus.close()
	game.locations.switch_now("room")
	var indoor_animal_age: float = game.animals.age
	var indoor_seal_age: float = game.island_life.age
	await frames(90)
	check(is_equal_approx(game.animals.age, indoor_animal_age) and is_equal_approx(game.island_life.age, indoor_seal_age), "Indoor scenes suspend outside wildlife")
	game.locations.switch_now("island")
	# Night has breathing/resting for rabbits and birds, while crabs still roam.
	game.night = true
	rabbit.mode = "idle"
	await frames(10)
	check(rabbit.mode == "sleep", "Rabbit settles down at night")
	var resting_scale: Vector3 = rabbit.model.scale
	await frames(50)
	check(not rabbit.model.scale.is_equal_approx(resting_scale), "Sleeping animals still breathe")
	game.night = false
	await frames(20)
	check(rabbit.mode != "sleep", "Daylight wakes sleeping animals")
	game.cove_repaired = false
	game.island_life.apply_state()
	seal_start = seal.position
	await frames(60)
	check(not seal.visible and seal.position.is_equal_approx(seal_start), "Locked seal stays hidden and still")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: all eight animals wander without input near an observer, safe habitats, autonomous seal, E greeting/resume, pause, night breathing/wake, seal unlock")
	quit(0 if failures.is_empty() else 1)
