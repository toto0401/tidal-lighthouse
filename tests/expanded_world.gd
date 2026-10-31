extends SceneTree

var failures: Array[String] = []
var held := {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func key(code: Key, down: bool) -> void:
	if held.get(code,false) == down:
		return
	held[code] = down
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func walk(game: Node3D, destination: Vector2) -> void:
	var reached := false
	for step in range(1800):
		var offset := destination - Vector2(game.player.position.x,game.player.position.z)
		if offset.length() < 0.6:
			reached = true
			break
		key(KEY_A,offset.x < -0.18)
		key(KEY_D,offset.x > 0.18)
		key(KEY_W,offset.y < -0.18)
		key(KEY_S,offset.y > 0.18)
		await physics_frame
		if game.player.position.y < 0.6 or game.player.position.y > 1.6:
			check(false,"Walking must stay grounded at " + str(game.player.position))
			break
	for code in [KEY_A,KEY_D,KEY_W,KEY_S]:
		key(code,false)
	for step in range(10):
		await physics_frame
	check(reached,"Route reaches %s; ended at %s" % [destination,game.player.position])

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	for frame in range(40):
		await physics_frame
	check(game.expanded_island != null,"Expanded world is installed")
	await walk(game,Vector2(2,0))
	await walk(game,Vector2(-12,-2))
	await walk(game,Vector2(-23,-4))
	await walk(game,Vector2(-31,-5))
	check(game.region_label.text.contains("月贝"),"West island has its own region name")
	await walk(game,Vector2(-23,-4))
	await walk(game,Vector2(-12,-2))
	await walk(game,Vector2(2,0))
	await walk(game,Vector2(12,3))
	await walk(game,Vector2(24,3))
	await walk(game,Vector2(32,2))
	check(game.region_label.text.contains("绣球"),"East island has its own region name")
	await walk(game,Vector2(24,3))
	await walk(game,Vector2(12,3))
	await walk(game,Vector2(1,-4))
	await walk(game,Vector2(0,-11))
	await walk(game,Vector2(0,-28))
	await walk(game,Vector2(0,-36))
	check(game.region_label.text.contains("观星"),"North island has its own region name")
	var previous: Vector3 = game.player.position
	key(KEY_TAB,true)
	await process_frame
	key(KEY_TAB,false)
	await process_frame
	check(game.menus.current_page == "map","Tab opens the navigation map")
	key(KEY_W,true)
	for frame in range(12):
		await physics_frame
	key(KEY_W,false)
	check(game.player.position.is_equal_approx(previous),"The map pauses walking")
	var map: Control = game.menus.overlay.find_children("*","Control",true,false).filter(func(node): return node.get_script() == load("res://scripts/island_map.gd"))[0]
	check(map.size.x >= 800 and map.size.y >= 392,"The map has room for all four islands")
	game.menus.close()
	game.return_home()
	for frame in range(40):
		await physics_frame
	check(game.player.position.distance_to(Vector3(0.6,0.9,5.5)) < 0.4 and game.player.is_on_floor(),"Return home lands safely without resetting progression")
	check(game.archive_count == 0,"Navigation does not modify archive progress")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: all three new islands reached on foot via bridges and back, grounded movement, region signs, map modal, safe return home")
	quit(0 if failures.is_empty() else 1)
