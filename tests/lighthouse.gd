extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")
var game: Node3D
var failures: Array[String] = []
var path := "user://lighthouse_test_%d.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count := 30) -> void:
	for i in range(count):
		await physics_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code,true)
	await process_frame
	key(code,false)
	await process_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.toast_label.modulate.a = 0
	await frames(4)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/灯塔场景-" + label + ".png")

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.progress_path = path
	game.set_meta("skip_title",true)
	root.add_child(game)
	await frames()
	check(game.current_location == "island", "A journey starts outside")
	check(game.world_node("LighthouseRoom") == null and game.world_node("RoomTrigger") == null, "No detached outdoor cottage or decoration trigger remains")
	check(game.restoration_mesh == null and game.world_node("RestorationPoint") == null, "Repair is absent from ground level")
	await tap(KEY_B)
	check(not game.menu_is_open(), "Decoration requires entering the tower")
	var camera_before := Vector3(game.camera_yaw,game.camera_pitch,game.camera_distance)
	# Transition is modal, rejects duplicate requests, and discards queued abilities.
	game.player.position = game.locations.DOOR_RETURN
	game._update_interaction()
	await tap(KEY_E)
	check(game.locations.transitioning, "E starts a visible scene transition")
	game.locations.request("top")
	key(KEY_SHIFT,true)
	key(KEY_SPACE,true)
	key(KEY_F,true)
	await frames(35)
	key(KEY_SHIFT,false)
	key(KEY_SPACE,false)
	key(KEY_F,false)
	check(game.current_location == "room" and not game.locations.transitioning, "Entry finishes inside, never skips directly to the roof")
	check(game.locations.active_scene.scene_file_path == "res://scenes/LighthouseRoom.tscn", "Room is its own instantiated scene")
	check(not game.locations.island_scene.visible, "Exterior is hidden inside")
	for body in game.locations.collision_objects:
		check(body.collision_layer == 0 and body.collision_mask == 0, "Hidden island collisions are disabled")
	check(not game.jump_requested and game.dash_remaining == 0 and not game.water_activities.is_fishing(), "Transition clears jump, dash and fishing")
	await frames()
	check(game.player.is_on_floor() and not game.swimming, "Room spawn is grounded, never swimming")
	check(game.room_objects.size() == 5, "Furniture has moved into the interior")
	var outside_item: Node3D = game.world_node("Collectible_wood")
	game.interact_target = outside_item
	game._interact()
	check(game.archive_count == 0, "A stale exterior interaction cannot fire inside")
	await shot("小屋")
	await tap(KEY_B)
	check(game.menus.current_page == "decor", "B decorates the interior")
	game._set_decoration(2)
	for layout in range(3):
		game.set_room_layout(layout)
		check(game.world_node("Chair").position == game.world_node("ChairBody").position, "Furniture collision follows layout")
	await shot("布置")
	await tap(KEY_ESCAPE)
	await frames()
	var room_floor: float = game.player.position.y
	await tap(KEY_SPACE)
	await frames(6)
	check(game.player.position.y > room_floor + 0.3, "Player can jump inside")
	await frames(70)
	check(game.player.is_on_floor(), "Indoor jump lands safely")
	await Travel.travel(game,"top")
	await frames()
	check(game.locations.active_scene.scene_file_path == "res://scenes/LighthouseTop.tscn", "Roof is a separate scene")
	check(game.world_node("RoomTrigger") == null and game.room_objects.is_empty(), "Room scene is unloaded upstairs")
	check(game.restoration_mesh != null, "Repair point exists only upstairs")
	game.player.global_position = game.locations.active_scene.to_global(Vector3(0,1.1,1.15))
	await frames()
	await tap(KEY_E)
	check(not game.repaired, "Roof repair still requires all three archive entries")
	game.discovered = {"wood":true,"glass":true,"shell":true}
	game.archive_count = 3
	game._update_interaction()
	await tap(KEY_E)
	check(game.repaired and game.locations.active_scene.lens_light.light_energy > 4, "Repair lights the actual upstairs lens")
	check(game.beacon_light.light_energy > 5, "Exterior beacon also receives the repair")
	await tap(KEY_E)
	check(game.archive_count == 3, "Repeat repair leaves inventory unchanged")
	await shot("塔顶")
	# Railings stop a dash and a jump from escaping the separate roof scene.
	game.player.global_position = game.locations.active_scene.to_global(Vector3(4.5,1.1,0))
	await frames()
	key(KEY_D,true)
	await tap(KEY_SHIFT)
	await tap(KEY_SPACE)
	await frames(90)
	key(KEY_D,false)
	var roof_position: Vector3 = game.locations.active_scene.to_local(game.player.global_position)
	check(roof_position.x < 5.75 and roof_position.y > 0.6, "Balcony railing contains jumping and dashing")
	await Travel.travel(game,"room")
	await frames()
	check(game.decoration_style == 2 and game.room_layout == 2, "Re-entering room restores its colors and layout")
	var chair_position: Vector3 = game.world_node("Chair").position
	game.menus.open_map()
	await frames(5)
	check(game.menus.current_page == "map", "Map can be opened inside")
	game.menus.close()
	game.return_home()
	await frames()
	check(game.current_location == "island" and game.locations.active_scene == null, "Map return home exits and unloads the interior")
	check(game.locations.island_scene.visible, "Returning restores the island")
	for body in game.locations.collision_objects:
		check(body.collision_layer == body.get_meta("island_layer"), "Exterior collision layers restore")
	check(Vector3(game.camera_yaw,game.camera_pitch,game.camera_distance).is_equal_approx(camera_before), "Island camera settings restore")
	check(game.world_node("Collectible_seed").visible, "Roof repair unlocks outdoor discoveries")
	# Stress unload/reload and real return doors, without increasing the active scene count.
	for round in range(3):
		await Travel.travel(game,"top")
		await Travel.travel(game,"room")
		await Travel.travel(game,"island")
	check(game.player.position.distance_to(game.locations.DOOR_RETURN) < 0.4, "Room exit lands outside the actual tower door")
	check(game.get_children().filter(func(n): return n.scene_file_path in ["res://scenes/LighthouseRoom.tscn","res://scenes/LighthouseTop.tscn"]).is_empty(), "Repeated trips do not accumulate scenes")
	game.queue_free()
	await process_frame
	game = load("res://Main.tscn").instantiate()
	game.progress_path = path
	game.set_meta("skip_title",true)
	root.add_child(game)
	await frames()
	check(game.repaired and game.room_layout == 2 and game.decoration_style == 2, "Saved repair and decoration load in a new session")
	await Travel.travel(game,"room")
	check(game.world_node("Chair").position == chair_position, "Loaded room renders saved furniture layout")
	check(game.new_journey(), "Restart from indoors succeeds")
	await frames()
	check(game.current_location == "island" and game.room_objects.is_empty() and not game.repaired, "Restart unloads interior and clears repair")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.last_backup_path))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: door/stairs transitions, separate packed scenes, collision isolation, indoor decor and jump, rooftop repair and guardrails, return routes, repeated unload/reload, save compatibility and indoor reset")
	quit(0 if failures.is_empty() else 1)
