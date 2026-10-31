extends SceneTree

const Travel := preload("res://tests/lighthouse_helpers.gd")

## Full play progression uses a process-specific save and removes only those test files.
const SaveState := preload("res://save_state.gd")
const Catalog := preload("res://data/island_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func interact_with(game: Node3D, target: Node3D) -> void:
	game.player.position = target.global_position + Vector3(0.45, 0.3, 0)
	game.player.velocity = Vector3.ZERO
	game._update_interaction()
	check(game.interact_target == target, "Nearby visible target must be selectable: " + str(target.name))
	game._interact()

func collect(game: Node3D, id: String) -> void:
	var target: Node3D = game.world_node("Collectible_" + id)
	check(target.visible, "Required discovery must be available: " + id)
	var count: int = game.archive_count
	interact_with(game, target)
	check(game.discovered.has(id), "Interaction must record: " + id)
	check(game.archive_count == count + 1, "Discovery must increment the archive once: " + id)
	check(not target.visible, "Recorded item must disappear from the beach: " + id)
	# A stale interaction cannot duplicate an archive entry.
	game.interact_target = target
	game._interact()
	check(game.archive_count == count + 1, "Repeated collection must not duplicate: " + id)

func hidden_items(game: Node3D, ids: Array) -> void:
	for id in ids:
		check(not game.world_node("Collectible_" + str(id)).visible, "Item must stay gated: " + str(id))

func _run() -> void:
	var path := "user://tide_integration_%s.cfg" % OS.get_process_id()
	var scene: PackedScene = load("res://Main.tscn")
	var game = scene.instantiate()
	game.progress_path = path
	game.set_meta("skip_title", true)
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	check(game.archive_count == 0 and game.restoration_stage() == 0, "A fresh save starts before lighthouse restoration")
	hidden_items(game, Catalog.GARDEN_IDS + Catalog.COVE_IDS)
	interact_with(game, game.world_node("GardenRestore"))
	check(not game.garden_repaired, "Garden cannot be restored before the lighthouse")
	interact_with(game, game.world_node("CoveRestore"))
	check(not game.cove_repaired, "Cove cannot be restored before the garden")
	game._toggle_tide()
	hidden_items(game, ["glass", "shell"])
	check(game.world_node("Collectible_wood").visible, "Driftwood is available at either tide")
	# Even a cached/direct target cannot bypass visibility and tide requirements.
	game.interact_target = game.world_node("Collectible_glass")
	game._interact()
	check(not game.discovered.has("glass"), "High tide cannot be bypassed with a stale interaction")
	collect(game, "wood")
	await Travel.travel(game,"top")
	interact_with(game, game.restoration_mesh)
	await Travel.travel(game,"island")
	check(not game.repaired, "One object is insufficient to restore the lighthouse")
	game._toggle_tide()
	collect(game, "glass")
	collect(game, "shell")
	await Travel.travel(game,"top")
	interact_with(game, game.restoration_mesh)
	await Travel.travel(game,"island")
	check(game.repaired and game.restoration_stage() == 1, "The first three entries unlock the lighthouse")
	check(game.beacon_light.light_energy > 5.0, "Restoring the lighthouse illuminates its beacon")
	check(not game.menu_is_open(), "Lighthouse completion must continue into the garden chapter")
	check(game.world_node("Collectible_seed").visible, "Lighthouse restoration unlocks the seed")
	hidden_items(game, Catalog.COVE_IDS + ["feather"])
	interact_with(game, game.world_node("GardenRestore"))
	check(not game.garden_repaired, "Garden restoration requires all three garden objects")
	collect(game, "seed")
	collect(game, "moss")
	game._toggle_tide()
	collect(game, "feather")
	interact_with(game, game.world_node("GardenRestore"))
	check(game.garden_repaired and game.restoration_stage() == 2, "Garden entries unlock the second restoration")
	check(game.island_life.garden.visible, "Restored garden flowers must be visible")
	check(not game.island_life.seal.visible, "The seal waits for the cove to be restored")
	check(game.world_node("Collectible_ribbon").visible, "High tide reveals the unlocked cove ribbon")
	hidden_items(game, ["coral", "stardust"])
	collect(game, "ribbon")
	game._toggle_tide()
	collect(game, "coral")
	hidden_items(game, ["stardust"])
	interact_with(game, game.world_node("CoveRestore"))
	check(not game.cove_repaired, "The last restoration requires night-only stardust")
	game.toggle_night()
	check(game.night and game.world_node("Collectible_stardust").visible, "Night plus low tide reveals stardust")
	game._toggle_tide()
	hidden_items(game, ["stardust"])
	game._toggle_tide()
	collect(game, "stardust")
	interact_with(game, game.world_node("CoveRestore"))
	check(game.cove_repaired and game.restoration_stage() == 3, "All nine discoveries allow island completion")
	check(game.island_life.seal.visible, "Restoring the cove returns the seal")
	check(game.menu_is_open() and game.menus.current_page == "ending", "Only the full restoration opens the ending")
	game.menus.close()
	interact_with(game, game.island_life.seal)
	check(not game.toast_label.text.is_empty(), "The returning seal offers an interaction")
	check(game.archive_count == 9, "Nine archive entries are counted exactly once")
	for exhibit in game.display_objects:
		check(exhibit.visible, "Every collected item has a visible archive exhibit")

	# Decor choices must affect world geometry and persist, including furniture collision.
	await Travel.travel(game,"room")
	game.player.position = game.world_node("RoomTrigger").position
	game._set_decoration(2)
	var chair: Node3D = game.world_node("Chair")
	var chair_start: Vector3 = chair.position
	game.set_room_layout(1)
	check(game.room_layout == 1 and not chair.position.is_equal_approx(chair_start), "A new room layout actually moves the chair")
	check(chair.position.is_equal_approx(game.world_node("ChairBody").position), "Furniture collision must follow its visual position")
	game.set_player_palette(3)
	var saved_coat_color: Color = game.player.get_node("Coat").material_override.albedo_color
	var saved_chair_position: Vector3 = chair.position
	game.toggle_audio()
	game._toggle_tide()
	check(FileAccess.file_exists(path), "Actions automatically create the selected save file")
	game.queue_free()
	await process_frame

	var resumed = scene.instantiate()
	resumed.progress_path = path
	resumed.set_meta("skip_title", true)
	root.add_child(resumed)
	await process_frame
	resumed.set_physics_process(false)
	resumed.set_process(false)
	check(resumed.archive_count == 9 and resumed.restoration_stage() == 3, "Reload restores all nine entries and all three zones")
	check(resumed.decoration_style == 2 and resumed.room_layout == 1, "Reload restores room colors and arrangement")
	check(resumed.player_palette == 3, "Reload restores raincoat color")
	check(resumed.player.get_node("Coat").material_override.albedo_color == saved_coat_color, "Reload applies the selected raincoat material")
	await Travel.travel(resumed,"room")
	check(resumed.world_node("Chair").position.is_equal_approx(saved_chair_position), "Reload applies the selected furniture positions")
	check(resumed.night and not resumed.tide_low and not resumed.audio_enabled, "Reload restores night, tide, and sound settings")
	check(resumed.island_life.garden.visible and resumed.island_life.seal.visible, "Reload restores garden and returning seal visuals")
	check(resumed.world_node("Chair").position.is_equal_approx(resumed.world_node("ChairBody").position), "Reloaded chair collision matches the layout")
	hidden_items(resumed, Catalog.ids())
	for exhibit in resumed.display_objects:
		check(exhibit.visible, "Reloaded archive exhibits stay visible")
	check(resumed.beacon_light.light_energy > 5.0, "Saved lighthouse stays illuminated")

	# Restart must back up the complete original before replacing the current save.
	check(resumed.new_journey(), "A writable test save permits a new journey")
	check(not resumed.last_backup_path.is_empty(), "Restart records where it preserved the old journey")
	check(resumed.archive_count == 0 and resumed.restoration_stage() == 0, "New journey resets all discoveries and restorations")
	check(resumed.tide_low and not resumed.night, "New journey begins with daytime low tide")
	check(not resumed.island_life.garden.visible and not resumed.island_life.seal.visible, "New journey resets restored world visuals")
	check(SaveState.load_progress(path).discovered.is_empty(), "Restart writes a fresh current save")
	var backup_found := false
	var absolute := ProjectSettings.globalize_path(path)
	for filename in DirAccess.get_files_at(absolute.get_base_dir()):
		if filename.begins_with(absolute.get_file()) and filename != absolute.get_file():
			var candidate := absolute.get_base_dir().path_join(filename)
			var backup := SaveState.load_progress(candidate)
			if backup.discovered.size() == 9 and backup.cove_repaired:
				backup_found = true
			DirAccess.remove_absolute(candidate)
	check(backup_found, "New journey preserves the previous completed save in a backup")
	resumed.queue_free()
	await process_frame
	DirAccess.remove_absolute(absolute)
	if failures.is_empty():
		print("PASS: nine tide/night/stage-gated discoveries, three restorations, ending, exhibits, seal, furniture collision, complete reload, and backed-up restart")
	quit(0 if failures.is_empty() else 1)
