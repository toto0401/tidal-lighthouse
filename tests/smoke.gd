extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")

## Run with: godot --headless --path . --script res://tests/smoke.gd
## A private user directory prevents this test from changing player saves.

var failures: Array[String] = []

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "TideArchiveSmokeTest")
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _physics_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn")
	var game = packed.instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(game.player != null, "Player must exist")
	for child in game.player.get_children():
		_check(not child is StaticBody3D, "Player visuals must not create static collision bodies")

	# Freeze the camera orbit while testing movement relative to a known camera heading.
	game.set_process(false)
	game.camera.rotation = Vector3.ZERO
	# Use physical keyboard events, including the same default device as a real keyboard.
	game.player.position = Vector3(5.0, 1.1, 2.0)
	game.player.velocity = Vector3.ZERO
	var start: Vector3 = game.player.position
	_key(KEY_D, true)
	_check(Input.is_action_pressed("move_right"), "D key must match move_right")
	await _physics_frames(30)
	_key(KEY_D, false)
	_check(game.player.position.x > start.x + 0.25, "D input must move the player right")
	_check(game.player.velocity.length() <= 2.81, "Walking speed must stay at or below 2.8 m/s")
	await _physics_frames(30)
	_check(Vector2(game.player.velocity.x, game.player.velocity.z).length() < 0.01, "Releasing movement must stop the player")
	_check(game.player.is_on_floor(), "Gravity must settle the player on the island")
	_check(game.player.position.y < 1.0 and game.player.position.y > 0.6, "Player must stay at ground height")

	game.camera.rotation.y = PI / 2.0
	start = game.player.position
	_key(KEY_W, true)
	await _physics_frames(30)
	_key(KEY_W, false)
	_check(game.player.position.x < start.x - 0.25, "Forward movement must follow the rotated camera heading")
	await _physics_frames(30)

	# Walk directly into the lighthouse wall for four seconds. It must block us without launching us.
	game.camera.rotation = Vector3.ZERO
	game.player.position = Vector3(-2.0, 1.1, 7.0)
	game.player.velocity = Vector3.ZERO
	var highest_y: float = game.player.position.y
	_key(KEY_A, true)
	for frame in range(240):
		await physics_frame
		highest_y = maxf(highest_y, game.player.position.y)
	_key(KEY_A, false)
	await _physics_frames(30)
	_check(game.player.position.x > -5.0 and game.player.position.x < -4.0, "The lighthouse must block walking through its wall")
	_check(highest_y <= 1.11, "Movement and wall contact must never launch the player into the air")
	_check(game.player.is_on_floor() and absf(game.player.velocity.y) < 0.01, "Player must stay grounded after wall contact")
	game.set_process(true)

	_key(KEY_T, true)
	await process_frame
	_key(KEY_T, false)
	await process_frame
	_check(not game.tide_low, "T key must switch to high tide")
	_key(KEY_T, true)
	await process_frame
	_key(KEY_T, false)
	await process_frame
	_check(game.tide_low, "T key must switch back to low tide")

	game.interact_target = null
	game._interact()
	await Travel.travel(game,"top")
	var restoration: Node3D = game.world_node("RestorationPoint")
	game.player.position = restoration.position + Vector3(1.0, 0.86, 0)
	game._update_interaction()
	_check(game.interact_target == restoration, "Restoration point must be reachable")
	game._interact()
	_check(not game.repaired, "Lighthouse must require the complete archive")

	await Travel.travel(game,"island")
	# Only the first three objects are available before the lighthouse is repaired.
	for spec in game.item_specs:
		if int(spec.stage) != 0:
			continue
		var collectible: Node3D = game.world_node("Collectible_" + str(spec.id))
		game.player.position = collectible.position + Vector3(0.8, 0, 0)
		game._update_interaction()
		_check(game.interact_target == collectible, "Collectible must become the nearest interaction: " + str(spec.id))
		_key(KEY_E, true)
		await process_frame
		_key(KEY_E, false)
		await process_frame
		_check(game.discovered.has(spec.id), "E key must record collectible: " + str(spec.id))
		_check(not collectible.visible, "Recorded collectible must be hidden: " + str(spec.id))
	_check(game.archive_count == 3, "The first three archive entries must be counted exactly once")

	await Travel.travel(game,"top")
	restoration = game.restoration_mesh
	game.player.position = restoration.position + Vector3(1.0, 0.86, 0)
	game._update_interaction()
	game._interact()
	_check(game.repaired, "Complete archive must allow lighthouse restoration")
	game._update_interaction()
	_check("修复灯芯" not in game.prompt_label.text, "Restored lighthouse must no longer offer repair")
	game._interact()
	_check("档案还不完整" not in game.toast_label.text, "Repeated restoration must acknowledge the completed lighthouse")

	await Travel.travel(game,"room")
	game.player.position = Vector3(0,1.1,2.3)
	var keys := [KEY_1, KEY_2, KEY_3]
	var previous_colors: Array[Color] = []
	for i in range(game.room_objects.size()):
		previous_colors.append(Color.TRANSPARENT)
	for style in range(3):
		_key(keys[style], true)
		await process_frame
		_key(keys[style], false)
		await process_frame
		_check(game.decoration_style == style, "Decoration key must apply style " + str(style + 1))
		for i in range(game.room_objects.size()):
			var mesh: MeshInstance3D = game.room_objects[i]
			var material: StandardMaterial3D = mesh.material_override
			_check(material != null, "Every decoration needs a material")
			_check(material.albedo_color != previous_colors[i], "Every decoration must change color for style " + str(style + 1))
			previous_colors[i] = material.albedo_color

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: keyboard mapping, gentle camera-relative movement, gravity, wall collision, tides, collection, restoration, repeat interaction, and all decoration palettes")
		quit(0)
	else:
		print("FAIL: %d checks" % failures.size())
		quit(1)
