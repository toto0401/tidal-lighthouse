extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")
var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count := 30) -> void:
	for i in range(count):
		await physics_frame

func tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func shot(label: String, yaw: float, distance := 23.0, pitch := 0.76) -> void:
	game.camera_yaw = yaw
	game.camera_distance = distance
	game.camera_pitch = pitch
	await frames(12)
	if DisplayServer.get_name() == "headless":
		return
	game.toast_label.modulate.a = 0
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/塔顶实景-" + label + ".png")

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	game.toggle_audio()
	await frames()
	var island: Node3D = game.locations.island_scene
	var island_id := island.get_instance_id()
	var picnic: Node3D = game.expanded_island.get_node("HydrangeaPicnic")
	var picnic_position := picnic.global_position
	var ocean: MeshInstance3D = game.world_node("Ocean")
	var ocean_id := ocean.get_instance_id()
	# Restore real progress before climbing; it must remain the same visible scene.
	game._apply_progress(game.SaveState._validated({"discovered": game.Catalog.ids(), "repaired": true, "garden_repaired": true, "cove_repaired": true}))
	game.island_life.apply_state()
	await Travel.travel(game, "top")
	await frames()
	check(island.get_instance_id() == island_id and island.is_visible_in_tree(), "Roof displays the existing playable island instance")
	check(picnic.is_visible_in_tree() and picnic.global_position == picnic_position, "Actual tea table remains visible at its original world location")
	check(game.world_node("Ocean").get_instance_id() == ocean_id and ocean.material_override == game.water_shader, "Roof uses the original ocean and its live material")
	check(game.island_life.garden.is_visible_in_tree() and game.island_life.seal.is_visible_in_tree(), "Restored garden and returned seal are visible from the roof")
	for region in game.expanded_island.Layout.REGIONS:
		check(game.expanded_island.get_node("Region_" + str(region.id)).is_visible_in_tree(), "Real island terrain is visible: " + str(region.id))
	for bridge in game.expanded_island.Layout.BRIDGES:
		check(game.expanded_island.get_node(str(bridge.name)).is_visible_in_tree(), "Detailed bridge is visible: " + str(bridge.name))
	var roof: Node3D = game.locations.active_scene
	var tower: Node3D = game.world_node("Lighthouse")
	check(Vector2(roof.global_position.x, roof.global_position.z) == Vector2(tower.global_position.x, tower.global_position.z), "Gallery stands over the actual lighthouse")
	check(game.player.is_on_floor() and game.player.global_position.y > 10.0, "Player stands safely at the real tower height")
	check(roof.get_node_or_null("RoofOcean") == null and roof.find_children("Panorama*", "", true, false).is_empty(), "No substitute islands or duplicate ocean remain")
	var animal_age: float = game.animals.age
	var seal_age: float = game.island_life.age
	await frames(45)
	check(game.animals.age > animal_age and game.island_life.age > seal_age, "Wildlife continues moving while viewed from the gallery")
	# Even a cached target or a mistaken proximity cannot activate the ground.
	var outside_item: Node3D = game.world_node("Collectible_wood")
	game.discovered.erase("wood")
	game.archive_count = game.discovered.size()
	game._update_tide_visuals()
	var standing: Transform3D = game.player.global_transform
	game.player.global_position = outside_item.global_position + Vector3(0.4, 0.3, 0)
	game._update_interaction()
	check(game.interact_target != outside_item, "Roof interaction selection excludes the visible ground")
	game.interact_target = outside_item
	game._interact()
	check(not game.discovered.has("wood"), "Cached ground interactions cannot collect from upstairs")
	game.player.global_transform = standing
	game.discovered.wood = true
	game.archive_count = game.discovered.size()
	game._update_tide_visuals()
	await shot("白昼", 0.0)
	await shot("东侧花岛", -0.7, 30.0, 0.65)
	await shot("西侧沙洲", 0.7, 30.0, 0.65)
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom.pressed = true
	for i in range(70):
		Input.parse_input_event(zoom.duplicate())
		Input.flush_buffered_events()
	check(game.camera_distance == 60.0, "Roof can zoom out far enough to see the full archipelago")
	await shot("四岛全景", 0.0, game.camera_distance, 0.95)
	await tap(KEY_C)
	check(game.camera_distance == game.locations.TOP_CAMERA_DISTANCE and game.camera_yaw == 0.0, "C restores the rooftop view")
	await tap(KEY_T)
	await frames(100)
	check(not game.tide_low and is_zero_approx(float(game.water_shader.get_shader_parameter("low_tide"))), "T changes the actual sea below the gallery")
	await tap(KEY_T)
	await tap(KEY_N)
	await frames(125)
	check(game.night and is_equal_approx(float(game.water_shader.get_shader_parameter("night_amount")), 1.0), "Night changes the shared ocean")
	await shot("月夜", -0.3, 28.0)
	await Travel.travel(game, "room")
	check(not island.visible, "Island hides inside the cottage")
	await Travel.travel(game, "top")
	check(island.is_visible_in_tree() and game.night, "Reclimbing restores the same live night view")
	await Travel.travel(game, "island")
	check(island.get_instance_id() == island_id and picnic.global_position == picnic_position, "Returning never shifts or duplicates the map")
	check(game.world_node("LighthouseLabel").is_visible_in_tree(), "Lighthouse sign returns at ground level")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: real rooftop world, existing terrain/bridges/props, progress and wildlife, shared tide/night, zoom/reset, interaction isolation, return/reclimb")
	quit(0 if failures.is_empty() else 1)
