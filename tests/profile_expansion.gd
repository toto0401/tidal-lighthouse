extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	var readings: Array[String] = []
	for spot in [Vector3(0,1.1,4),Vector3(32,1.1,4),Vector3(-31,1.1,-5),Vector3(0,1.1,-34)]:
		game.player.position=spot
		game.camera_focus=spot+Vector3(0,0.6,0)
		for frame in range(15):
			await process_frame
		var start := Time.get_ticks_usec()
		var drawn := Engine.get_frames_drawn()
		for frame in range(90):
			await process_frame
		var seconds := float(Time.get_ticks_usec()-start)/1000000.0
		var rendered_frames := Engine.get_frames_drawn()-drawn
		var line := "Region %s: %.1f rendered FPS (%d frames), draw calls %d" % [spot,float(rendered_frames)/seconds,rendered_frames,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
		print(line)
		readings.append(line)
	var report := FileAccess.open("res://docs/扩建性能抽样.txt",FileAccess.WRITE)
	report.store_string("Godot 4.7.2 / Metal / Apple M2 / 1280x720 / normal simulation, 60 FPS limit\n"+"\n".join(readings)+"\n")
	game.queue_free()
	await process_frame
	quit()
