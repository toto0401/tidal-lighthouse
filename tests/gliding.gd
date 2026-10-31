extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")
var game: Node3D
var failures: Array[String] = []
var held: Array[Key] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func key(code: Key, down: bool, echo_event := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo_event
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if down and not held.has(code):
		held.append(code)
	elif not down:
		held.erase(code)

func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func place(at: Vector3, facing := PI) -> void:
	for code in held.duplicate():
		key(code,false)
	game.gliding.cancel()
	game.cancel_dash()
	game.player.position = at
	game.player.rotation.y = facing
	game.player.velocity = Vector3.ZERO
	game.swimming = false
	await frames(2)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.toast_label.modulate.a = 0
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/滑翔-" + label + ".png")

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await frames(30)
	await tap(KEY_G)
	check(not game.gliding.active, "G cannot launch from level ground")
	await tap(KEY_SPACE)
	await frames(8)
	await tap(KEY_G)
	check(not game.gliding.active, "An ordinary low jump cannot become a powered takeoff")
	await frames(70)
	await Travel.travel(game,"room")
	await tap(KEY_G)
	check(not game.gliding.active, "Interior disables gliding")
	await Travel.travel(game,"top")
	game.player.global_position = game.locations.active_scene.to_global(Vector3(2.6,1.0,0))
	game.player.velocity = Vector3.ZERO
	await frames(30)
	game.camera_yaw = 0
	game._update_camera(0)
	key(KEY_D,true)
	await frames(28)
	key(KEY_D,false)
	await frames(10)
	game._update_interaction()
	check(game.interact_target == game.world_node("GlideLaunch"), "Walk onto the marked roof launch point")
	await shot("塔顶起飞点")
	await tap(KEY_E)
	check(game.locations.transitioning, "E starts the roof departure")
	await tap(KEY_E)
	await frames(45)
	check(game.current_location == "island" and game.gliding.active, "Roof launch loads the actual island and opens the sail")
	check(game.locations.active_scene == null and game.locations.island_scene.visible, "Flight leaves the gallery while keeping the same island visible")
	check(game.player.position.y > 7 and game.gliding.visual.is_visible_in_tree(), "Sail carries the player at tower height")
	check(game.dash_remaining == 0 and not game.water_activities.is_fishing(), "Launch clears competing abilities")
	await frames(65)
	await shot("飞越海岛")
	var before: Vector3 = game.player.position
	await frames(60)
	check(game.player.position.distance_to(before) > 5, "No input keeps gliding forward")
	check(before.y - game.player.position.y > 1.0 and before.y - game.player.position.y < 1.5, "The sail descends steadily instead of flying upward")
	await tap(KEY_SHIFT)
	check(game.gliding.active and game.dash_remaining == 0, "Shift cannot add an aerial dash")
	await tap(KEY_TAB)
	before = game.player.position
	await tap(KEY_G)
	await frames(30)
	check(game.player.position.is_equal_approx(before) and game.gliding.active, "Map pauses flight and blocks G")
	await tap(KEY_ESCAPE)
	await frames(5)
	check(game.gliding.active and game.player.position.y < before.y, "Closing map resumes the same glide")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.menu_is_open() and game.gliding.active, "Focus loss safely pauses flight")
	game.menus.close()
	game.return_home()
	await frames(30)
	check(not game.gliding.active and not game.gliding.visual.visible and game.player.is_on_floor(), "Return home clears sail and flight")
	# A real elevated ledge: jump off, then deploy with G.
	game._add_box("GlideTestLedge",Vector3(2,0.3,2),Vector3(4,5,3),Color.WHITE,true)
	await place(Vector3(4,6.1,3),PI/2)
	await frames(30)
	check(game.player.is_on_floor(), "Elevated ledge has a physical floor")
	game.set_process(false)
	game.camera.rotation = Vector3.ZERO
	key(KEY_D,true)
	await tap(KEY_SPACE)
	await frames(40)
	key(KEY_D,false)
	await tap(KEY_G)
	check(game.gliding.active, "G deploys after jumping from a high ledge")
	var height: float = game.player.position.y
	key(KEY_G,true,true)
	await frames(5)
	key(KEY_G,false)
	check(game.gliding.active and game.player.position.y < height, "Key echo cannot toggle or gain height")
	key(KEY_W,true)
	await frames(80)
	key(KEY_W,false)
	check(game.gliding.heading.z < -0.9, "WASD turns toward camera-relative input")
	check(game.gliding.active and game.player.velocity.y > -1.5, "Opening during a fast fall settles into a slow descent")
	await tap(KEY_G)
	check(not game.gliding.active and not game.gliding.visual.visible, "G stows the sail in midair")
	height = game.player.position.y
	await tap(KEY_G)
	check(game.gliding.active and game.player.position.y < height and game.player.velocity.y < 0, "Reopening slows the fall without gaining altitude")
	await tap(KEY_SPACE)
	check(not game.gliding.active and game.player.velocity.y < 0, "Space stows without a second jump")
	game.world_node("GlideTestLedge").queue_free()
	game.world_node("GlideTestLedgeBody").queue_free()
	# Straight flight along the central clear path lands and resets movement.
	await place(Vector3(0,5,4))
	await tap(KEY_G)
	for frame in range(300):
		await physics_frame
		if game.player.is_on_floor():
			break
	check(game.player.is_on_floor() and not game.gliding.active and not game.swimming, "Touching land automatically folds the sail")
	await tap(KEY_SPACE)
	check(game.player.velocity.y > 0, "Normal jump still works after landing")
	# Sea landing changes into the existing swimming mode.
	await place(Vector3(0,4,22),0)
	await tap(KEY_G)
	for frame in range(260):
		await physics_frame
		if game.swimming:
			break
	check(game.swimming and not game.gliding.active and not game.gliding.visual.visible, "Water landing folds the wing and starts swimming")
	await tap(KEY_G)
	check(not game.gliding.active, "Swimming cannot reopen the wing")
	await place(Vector3(0,8,28.8),0)
	await tap(KEY_G)
	await frames(10)
	check(game.player.position.z <= 29.01 and game.gliding.heading.z < 0, "The sea boundary redirects flight inward")
	# A solid wall must stop a glide with the regular character collision.
	game._add_box("GlideTestWall",Vector3(0.3,16,4),Vector3(5,8,2),Color.WHITE,true)
	await place(Vector3(2,8,2),PI/2)
	await tap(KEY_G)
	await frames(40)
	check(not game.gliding.active and game.player.position.x < 4.6, "Solid walls stop flight without tunnelling")
	game.world_node("GlideTestWall").queue_free()
	game.world_node("GlideTestWallBody").queue_free()
	await place(Vector3(0,9,4))
	await tap(KEY_G)
	game.locations.switch_now("room")
	await frames(30)
	check(not game.gliding.active and not game.gliding.visual.visible, "Scene transitions always clear the wing")
	game.return_home()
	await place(Vector3(0,9,4))
	await tap(KEY_G)
	check(game.new_journey(), "Restart remains available during flight")
	await frames(30)
	check(not game.gliding.active and game.player.is_on_floor(), "Restart clears airborne state")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: rooftop launch, high-ledge jump/deploy, steering, descent/no height gain, G/Space/echo, land/water/wall/boundary, dash separation, menus/focus, scene travel/home/restart")
	quit(0 if failures.is_empty() else 1)
