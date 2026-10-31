extends SceneTree

const SaveState := preload("res://save_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for index in count:
		await process_frame

func _run() -> void:
	# A real saved night/mute preference must be applied before audio starts.
	var path := "user://music_test_%s.cfg" % OS.get_process_id()
	check(SaveState.save_progress({"night": true, "audio_enabled": false}, path) == OK, "Create isolated audio preferences")
	var game = load("res://Main.tscn").instantiate()
	game.progress_path = path
	root.add_child(game)
	await process_frame
	var music = game.music
	check(game.menus.title_open, "Music is available on the title screen")
	check(is_equal_approx(music.night_mix, 1.0), "Saved night selects the night arrangement before playback")
	check(music.day_player.stream_paused and music.night_player.stream_paused, "Saved mute pauses both arrangements on startup")
	for player in [music.day_player, music.night_player]:
		print("Audio resource: %s, %.3f seconds" % [player.name, player.stream.get_length()])
		check(player.stream.loop, "Each music stream loops")
		check(player.stream.get_length() > 100.0, "Full-length soundtrack is imported")
		var playback: AudioStreamPlayback = player.stream.instantiate_playback()
		playback.start(player.stream.get_length() - 0.02)
		var samples := playback.mix_audio(1.0, 4096)
		var peak := 0.0
		var step := 0.0
		for index in samples.size():
			peak = maxf(peak, maxf(absf(samples[index].x), absf(samples[index].y)))
			if index > 0:
				step = maxf(step, samples[index].distance_to(samples[index - 1]))
		check(peak > 0.001 and peak < 0.9, "Decoded loop contains music without clipping")
		check(step < 0.1, "Decoded loop boundary has no large discontinuity")
		check(playback.get_loop_count() > 0, "Playback crosses the loop boundary successfully")
		playback.stop()
	game.toggle_audio()
	check(not music.day_player.stream_paused and not music.night_player.stream_paused, "Unmute resumes both arrangements")
	# Advance tweens explicitly: background load can make a frame-count wait
	# overshoot the entire crossfade, especially while validating an export.
	music.startup_tween.pause()
	music.startup_tween.custom_step(2.0)
	check(music.night_player.volume_linear > 0.3 and music.day_player.volume_linear < 0.001, "Startup fade settles on night music")
	game.menus.close()
	game.toggle_night()
	music.mix_tween.pause()
	music.mix_tween.custom_step(1.5)
	check(music.day_player.volume_linear > 0.02 and music.night_player.volume_linear > 0.02, "Day/night transition blends both arrangements")
	var before: float = music.night_mix
	game.toggle_night()
	check(is_equal_approx(before, music.night_mix), "Rapid reversal continues from the current blend")
	music.mix_tween.pause()
	music.mix_tween.custom_step(3.1)
	check(is_equal_approx(music.night_mix, 1.0), "Rapid reversal settles on the latest night selection")
	game.menus.open_pause()
	check(music.night_player.playing and not music.night_player.stream_paused, "Music continues while resting in the pause menu")
	game.menus._toggle_sound()
	check(not game.audio_enabled and music.day_player.stream_paused and music.night_player.stream_paused, "Pause menu controls both music streams")
	var saved := SaveState.load_progress(path)
	check(not saved.audio_enabled and saved.night, "Mute and night preferences persist to disk")
	# Exercise the new-journey reset without touching any player save or backup.
	game.set_meta("test_mode", true)
	check(game.new_journey(), "New journey resets the soundtrack state")
	check(is_zero_approx(music.night_mix) and not music.day_player.stream_paused, "New journey restores daytime audio")
	game.queue_free()
	# Let the audio thread release stopped Ogg playbacks before engine shutdown.
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: decoded seamless loops, saved muted/night startup, fade-in, reversible crossfade, pause playback, mute persistence, new journey")
	quit(0 if failures.is_empty() else 1)
