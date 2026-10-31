extends SceneTree

const SaveState := preload("res://save_state.gd")
const Cycle := preload("res://scripts/day_night_cycle.gd")
var failures: Array[String] = []
var game: Node3D
var path := "user://test_day_night_%s.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func tap_n() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_N
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/自动昼夜-" + label + ".png")

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	game.audio_enabled = false
	game.progress_path = path
	root.add_child(game)
	await frames(35)
	shot("白昼")
	var cycle: Node = game.day_night_cycle
	check(not game.night and cycle.elapsed > 0.0, "Actual gameplay advances the day clock without input")
	game.repaired = true
	game.garden_repaired = true
	game._update_tide_visuals()
	var stardust: Node3D = game.world_node("Collectible_stardust")
	check(not stardust.visible, "Night-only star bottle is hidden in daytime")
	cycle.elapsed = Cycle.DAY_SECONDS - 0.3
	await frames(30)
	check(game.night and cycle.elapsed < 1.0, "Normal physics loop automatically changes day into night")
	check(stardust.visible and game.tide_label.text.contains("月夜"), "Automatic night updates discoveries and HUD")
	check(game.toast_label.text.contains("夜色"), "Automatic night announces itself")
	var sky: ShaderMaterial = game.get_node("IslandEnvironment").environment.sky.sky_material
	game.island_life.night_tween.custom_step(10.0)
	game.music.mix_tween.custom_step(10.0)
	var sky_mix: float = sky.get_shader_parameter("night_amount")
	check(sky_mix > 0.3 and sky_mix < 0.7, "Sky is midway through the gentle 20-second dusk")
	check(game.music.night_mix > 0.3 and game.music.night_mix < 0.7, "Music follows the same gentle dusk")
	shot("日落渐变")
	game.menus.open_pause()
	await frames(2)
	var before: float = cycle.elapsed
	var before_sky: float = sky.get_shader_parameter("night_amount")
	var before_music: float = game.music.night_mix
	await frames(60)
	check(cycle.elapsed == before, "Pause menu freezes the clock")
	check(is_equal_approx(sky.get_shader_parameter("night_amount"), before_sky) and is_equal_approx(game.music.night_mix, before_music), "Pause freezes an automatic sky and music crossfade")
	game.menus.close()
	await frames(15)
	check(cycle.elapsed > before and game.music.night_mix > before_music, "Resuming continues clock and crossfade")
	await tap_n()
	check(not game.night and cycle.elapsed < 0.1, "N immediately selects day and starts a full phase")
	game.island_life.night_tween.custom_step(2.0)
	game.music.mix_tween.custom_step(3.1)
	check(is_zero_approx(sky.get_shader_parameter("night_amount")) and is_zero_approx(game.music.night_mix), "Manual override finishes on matching day sky and music")
	await tap_n()
	game.island_life.night_tween.custom_step(2.0)
	game.music.mix_tween.custom_step(3.1)
	shot("月夜")
	cycle.elapsed = Cycle.NIGHT_SECONDS - 0.3
	await frames(30)
	check(not game.night and not stardust.visible, "Night automatically returns to day and hides night discoveries")
	game.island_life.night_tween.custom_step(20.1)
	game.music.mix_tween.custom_step(20.1)
	check(is_zero_approx(sky.get_shader_parameter("night_amount")) and is_zero_approx(game.music.night_mix), "Dawn finishes on day visuals and music")
	shot("天亮")

	# Whole cycles and overshoot retain the remaining seconds without timer drift.
	cycle.restore(0.0)
	cycle.update(Cycle.DAY_SECONDS + 4.5)
	check(game.night and is_equal_approx(cycle.elapsed, 4.5), "A crossing preserves leftover seconds")
	cycle.update((Cycle.DAY_SECONDS + Cycle.NIGHT_SECONDS) * 3.0)
	check(game.night and is_equal_approx(cycle.elapsed, 4.5), "Large steps preserve phase over complete cycles")
	game.menus.open_title()
	await frames(12)
	check(is_equal_approx(cycle.elapsed, 4.5), "Title screen freezes time")
	game.menus.close()
	game.menus.open_archive()
	await frames(12)
	check(is_equal_approx(cycle.elapsed, 4.5), "Reading the journal freezes time")
	game.menus.close()
	game.locations.transitioning = true
	await frames(12)
	check(is_equal_approx(cycle.elapsed, 4.5), "Scene loading freezes time")
	game.locations.transitioning = false
	game.locations.switch_now("room")
	cycle.elapsed = Cycle.NIGHT_SECONDS - 0.3
	await frames(30)
	check(not game.night, "Time continues inside the lighthouse")
	game.island_life.night_tween.custom_step(20.1)
	check(is_equal_approx(game.get_node("WatercolorSun").light_energy, 0.45), "Automatic changes keep indoor lighting comfortable")
	game.locations.switch_now("top")
	cycle.elapsed = Cycle.DAY_SECONDS - 0.3
	await frames(30)
	game.island_life.night_tween.custom_step(20.1)
	check(game.night and is_equal_approx(game.water_shader.get_shader_parameter("night_amount"), 1.0), "Tower sea follows automatic nighttime")
	game.locations.switch_now("island")
	await frames(3)
	check(is_equal_approx(sky.get_shader_parameter("night_amount"), 1.0), "Returning outdoors retains current night")
	var seat: Node3D = game.picnic_rest.seats[0]
	game.player.position = seat.global_position + Vector3(-0.6, 1.1, 0.45)
	game.player.velocity = Vector3.ZERO
	await frames(35)
	game.picnic_rest.sit(seat)
	check(game.picnic_rest.is_seated(), "Clock test reaches an actual picnic seat")
	before = cycle.elapsed
	await frames(30)
	check(cycle.elapsed > before, "Resting at the picnic table does not stop time")
	game.picnic_rest.leave()

	# Use only an isolated test save, then reopen a real scene from that file.
	game.set_physics_process(false)
	game.set_process(false)
	game.set_meta("test_mode", false)
	cycle.elapsed = 37.25
	cycle.since_save = Cycle.SAVE_INTERVAL
	cycle.update(0.0)
	var saved := SaveState.load_progress(path)
	check(saved.night and is_equal_approx(saved.day_night_elapsed, 37.25), "Periodic checkpoint writes clock progress during idle exploration")
	game.queue_free()
	await frames(3)
	game = load("res://Main.tscn").instantiate()
	game.progress_path = path
	root.add_child(game)
	await frames(3)
	check(game.night and is_equal_approx(game.day_night_cycle.elapsed, 37.25), "Reload resumes saved phase and title does not advance it")
	game.set_meta("test_mode", true)
	check(game.new_journey(), "New journey can reset the clock")
	check(not game.night and is_zero_approx(game.day_night_cycle.elapsed), "New journey starts with a full daytime phase")
	game.queue_free()
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: automatic dusk/dawn, smooth sky/music, N override, menu pauses, indoors, tower sea, picnic, overshoot, checkpoint, reload and new journey")
	quit(0 if failures.is_empty() else 1)
