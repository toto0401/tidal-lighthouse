extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(game: Node3D, file_name: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + file_name + ".png")

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	for i in range(30):
		await process_frame
	game.menus.open_title()
	await shot(game, "标题画面")
	game.menus.close()
	game.toast_label.modulate.a = 0.0
	await shot(game, "试玩画面")
	game._apply_progress(game.SaveState._validated({"discovered": game.Catalog.ids(), "repaired": true, "garden_repaired": true, "cove_repaired": true, "style": 1, "room_layout": 1, "player_palette": 2, "night": true}))
	game.island_life.apply_state()
	game._update_tide_visuals()
	game._update_objective()
	game.player.position = Vector3(5.5, 1.1, -6)
	game.camera_yaw = -0.5
	game.camera_distance = 26
	for i in range(120):
		await process_frame
	await shot(game, "月夜海湾")
	game.menus.open_ending()
	await shot(game, "海岛结局")
	game.menus.open_archive()
	await shot(game, "完整档案")
	game.menus.close()
	await Travel.travel(game,"room")
	game.camera_yaw = 0.3
	game.camera_distance = 12
	game.night = false
	game.island_life.apply_night(false)
	for i in range(100):
		await process_frame
	await shot(game, "灯塔小屋")
	game.menus.open_decor()
	await shot(game, "小屋布置")
	game.queue_free()
	await process_frame
	quit()
