extends SceneTree

## Run without --headless to also check the light through the actual rendered glass.
var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames() -> void:
	for i in range(8):
		await process_frame

func sample_brightness(picture: Image, point: Vector2) -> float:
	var total := 0.0
	for y in range(int(point.y) - 4, int(point.y) + 5):
		for x in range(int(point.x) - 4, int(point.x) + 5):
			var color := picture.get_pixel(x, y)
			total += (color.r + color.g) * 0.5
	return total / 81.0

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.set_physics_process(false)
	game.ui_layer.hide()
	game._apply_progress(game.SaveState._validated({"discovered": ["wood", "glass", "shell"], "repaired": true}))
	var tower: Node3D = game.world_node("Lighthouse")
	var glass: MeshInstance3D = tower.get_node("ExteriorGallery/LanternRoom")
	check(glass.material_override.albedo_color.a < 0.3, "Lantern glass must transmit the light instead of enclosing it in an opaque shell")
	var sweep := tower.get_node_or_null("BeaconSweep") as Node3D
	check(sweep != null, "A restored lighthouse must cast a visible outward beam")
	if sweep:
		check(sweep.is_visible_in_tree(), "Loading restored progress turns on the exterior beam")
		var initial := sweep.rotation.y
		game._update_beacon(1.0)
		check(absf(angle_difference(initial, sweep.rotation.y)) > 0.1, "The beam sweeps across the sea while playing")
		game.menus.open_pause()
		initial = sweep.rotation.y
		game._update_beacon(1.0)
		check(is_equal_approx(initial, sweep.rotation.y), "Opening a menu pauses the sweep")
		game.menus.close()
		# Keep the beam out of the lens sample: glass must reveal the core itself.
		sweep.hide()
	if DisplayServer.get_name() != "headless":
		for is_night in [false, true]:
			game.night = is_night
			game._update_beacon(0.0)
			if sweep:
				sweep.hide()
			game.island_life.apply_night(false)
			game.island_life.night_tween.custom_step(1.0)
			for side in range(4):
				var angle := side * PI * 0.5
				game.camera.position = game.beacon_mesh.global_position + Vector3(sin(angle) * 13, -2.1, cos(angle) * 13)
				game.camera.look_at(game.beacon_mesh.global_position)
				game.camera.fov = 43
				await frames()
				await RenderingServer.frame_post_draw
				var picture := root.get_texture().get_image()
				var center: Vector2 = game.camera.unproject_position(game.beacon_mesh.global_position)
				var bright_pixels := 0
				for y in range(int(center.y) - 18, int(center.y) + 19):
					for x in range(int(center.x) - 18, int(center.x) + 19):
						var color := picture.get_pixel(x, y)
						if color.r > 0.8 and color.g > 0.7 and color.r > color.b + 0.015:
							bright_pixels += 1
				print("Lens pixels, night=%s side=%d: %d" % [is_night, side, bright_pixels])
				check(bright_pixels > 100, "The lit core is visible from side %d at %s, including the low camera angle from the bug" % [side, "night" if is_night else "day"])
			if sweep:
				game.camera.position = game.beacon_mesh.global_position + Vector3(0, 2.1, 32)
				game.camera.look_at(game.beacon_mesh.global_position)
				var point: Vector2 = game.camera.unproject_position(game.beacon_mesh.global_position + Vector3(8, 0, 0))
				await frames()
				await RenderingServer.frame_post_draw
				var unlit := sample_brightness(root.get_texture().get_image(), point)
				sweep.show()
				sweep.rotation.y = 0
				await frames()
				await RenderingServer.frame_post_draw
				var lit := sample_brightness(root.get_texture().get_image(), point)
				sweep.rotation.y = PI
				await frames()
				await RenderingServer.frame_post_draw
				var swept_away := sample_brightness(root.get_texture().get_image(), point)
				print("Beam brightness, night=%s: off=%.3f on=%.3f rotated=%.3f" % [is_night, unlit, lit, swept_away])
				check(lit > unlit + 0.04, "The outward beam is visibly brighter than the sky, by day and night")
				check(swept_away < lit - 0.04, "Rotating the beacon moves the actual visible beam")
	if sweep:
		sweep.show()
	game.locations.switch_now("room")
	if sweep:
		check(not sweep.is_visible_in_tree(), "Exterior light effects are hidden indoors")
	game.locations.switch_now("top")
	check(game.locations.active_scene.lens_light.light_energy > 4, "The upstairs lens stays in sync with repaired progress")
	game.locations.switch_now("island")
	if sweep:
		check(sweep.is_visible_in_tree(), "Returning outside restores the sweeping light")
	game._apply_progress(game.SaveState._validated({}))
	if sweep:
		check(not sweep.visible, "Starting a fresh journey extinguishes the beam until repair")
	check(not game.beacon_mesh.material_override.emission_enabled, "An unrepaired lamp stays unlit")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: beacon visibility, sweep, pause, interior travel and progress reset")
	quit(0 if failures.is_empty() else 1)
