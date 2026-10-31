extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(game: Node3D, at: Vector3, yaw: float, pitch: float, distance: float, output: String, hud := true) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.camera_yaw = yaw
	game.camera_pitch = pitch
	game.camera_distance = distance
	game.camera_focus = at + Vector3(0,0.6,0)
	for frame in range(25):
		await process_frame
	game.ui_layer.visible = hud
	game.toast_label.modulate.a = 0
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/" + output + ".png")

func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	for frame in range(30):
		await process_frame
	await capture(game,Vector3(0,1.1,4),0,0.65,20.5,"扩建后主岛")
	await capture(game,Vector3(0,1.1,-5),0.10,0.9,77,"四岛全景",false)
	await capture(game,Vector3(30,1.1,6),0.2,0.56,23,"绣球花岛",false)
	await capture(game,Vector3(-31,1.1,-1),-0.2,0.56,23,"月贝沙洲",false)
	await capture(game,Vector3(0,1.1,-34),0,0.52,24,"观星岬",false)
	game.menus.open_map()
	for frame in range(8):
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/海岛漫游图.png")
	game.menus.close()
	game.toggle_night()
	for frame in range(120):
		await process_frame
	await capture(game,Vector3(0,1.1,-34),0,0.42,24,"观星月夜",false)
	game.queue_free()
	await process_frame
	quit()
