extends SceneTree

const SaveState := preload("res://save_state.gd")
const Catalog := preload("res://data/island_catalog.gd")
var failures: Array[String] = []
var test_path := "user://test_tide_archive_save_state_%s.cfg" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _raw_file(data: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in data:
		config.set_value("progress", key, data[key])
	_check(config.save(test_path) == OK, "Test fixture must be writable")

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var defaults := {"discovered": [], "repaired": false, "style": 0, "tide_low": true, "garden_repaired": false, "cove_repaired": false, "room_layout": 0, "player_palette": 0, "night": false, "audio_enabled": true, "fish_caught": {}}
	defaults["activities"] = {"stone_best": 0, "flowers": [0, 0, 0], "songs": [], "stars": []}
	defaults["day_night_elapsed"] = 0.0
	_check(SaveState.load_progress(test_path) == defaults, "Missing file must return defaults")
	var complete := defaults.merged({"discovered": ["glass", "shell", "wood"], "repaired": true, "style": 2, "tide_low": false}, true)
	_check(SaveState.save_progress(complete, test_path) == OK, "Complete progress must save")
	_check(SaveState.load_progress(test_path) == complete, "Complete progress must round-trip")
	_check(SaveState.load_progress(test_path).discovered.is_typed(), "Loaded archive IDs must be typed strings")
	var partial := defaults.merged({"discovered": ["glass"], "repaired": false, "style": 1, "tide_low": true}, true)
	_check(SaveState.save_progress(partial, test_path) == OK, "Saving must replace an existing file")
	_check(SaveState.load_progress(test_path) == partial, "Replacement must contain the latest state")

	# A v1 file has only the first three discoveries and the original four fields.
	var legacy := {"discovered": ["glass", "shell", "wood"], "repaired": true, "style": 2, "tide_low": false}
	_raw_file(legacy)
	var migrated := defaults.merged(legacy, true)
	_check(SaveState.load_progress(test_path) == migrated, "Legacy three-item progress must retain its lighthouse, palette, and tide with new defaults")
	_check(SaveState.save_progress(SaveState.load_progress(test_path), test_path) == OK, "Migrated progress must be writable as v2")
	_check(SaveState.load_progress(test_path) == migrated, "Migrated progress must survive the next reload")
	_raw_file({"discovered": ["glass", "shell", "wood"], "repaired": false})
	_check(not SaveState.load_progress(test_path).repaired, "Migration must not auto-repair a lighthouse the player has not repaired")

	var all_ids := Catalog.ids()
	_check(all_ids.size() == 9, "The island archive must contain all nine discoveries")
	var whole_island := defaults.merged({
		"discovered": all_ids, "repaired": true, "garden_repaired": true, "cove_repaired": true,
		"style": 2, "tide_low": false, "room_layout": 2, "player_palette": 3, "night": true, "audio_enabled": false,
	}, true)
	_check(SaveState.save_progress(whole_island, test_path) == OK, "Complete nine-item island progress must save")
	_check(SaveState.load_progress(test_path) == whole_island, "All discoveries, restorations, appearance, layout, night, and mute settings must round-trip")

	_check(SaveState.save_progress({"fish_caught": {"silver": 3, "moonfish": 2}}, test_path) == OK, "Fish records save")
	_check(SaveState.load_progress(test_path).fish_caught == {"silver": 3, "moonfish": 2}, "Fish species and counts round-trip")
	_raw_file({"fish_caught": {"silver": -2, "moonfish": "2", "unknown": 3, "bream": true, "mackerel": 999999999}})
	_check(SaveState.load_progress(test_path).fish_caught == {"mackerel": 999999}, "Fish records reject unknown IDs and invalid counts, and cap large values")
	for invalid in [null, 3, "silver", []]:
		_raw_file({"fish_caught": invalid})
		_check(SaveState.load_progress(test_path).fish_caught.is_empty(), "Malformed fish records default to empty")

	# Later stages need their own discoveries and every earlier completed restoration.
	var repair_cases := [
		{"ids": all_ids, "flags": [false, true, true], "expected": [false, false, false], "name": "garden and cove need a repaired lighthouse"},
		{"ids": all_ids, "flags": [true, false, true], "expected": [true, false, false], "name": "cove needs a repaired garden"},
		{"ids": ["glass", "shell", "wood"], "flags": [true, true, true], "expected": [true, false, false], "name": "later stages need their own archive entries"},
		{"ids": ["glass", "shell", "wood", "seed", "feather"], "flags": [true, true, true], "expected": [true, false, false], "name": "garden needs all three garden entries"},
		{"ids": ["glass", "shell", "wood", "seed", "feather", "moss"], "flags": [true, true, true], "expected": [true, true, false], "name": "complete garden may stay restored while cove is incomplete"},
		{"ids": ["glass", "shell", "wood", "seed", "feather", "moss", "ribbon", "coral"], "flags": [true, true, true], "expected": [true, true, false], "name": "cove also needs the night-only star bottle"},
		{"ids": all_ids, "flags": [true, "true", true], "expected": [true, false, false], "name": "string garden flag must not unlock the cove"},
		{"ids": all_ids, "flags": [true, true, 1], "expected": [true, true, false], "name": "numeric cove flag must not count as restored"},
	]
	for repair_case in repair_cases:
		var candidate := {"discovered": repair_case.ids, "repaired": repair_case.flags[0], "garden_repaired": repair_case.flags[1], "cove_repaired": repair_case.flags[2]}
		_raw_file(candidate)
		var loaded := SaveState.load_progress(test_path)
		_check([loaded.repaired, loaded.garden_repaired, loaded.cove_repaired] == repair_case.expected, "Loaded repair order: " + repair_case.name)
		_check(SaveState.save_progress(candidate, test_path) == OK, "Repair validation fixture must save")
		_check(SaveState.load_progress(test_path) == loaded, "Writer must enforce the same repair order: " + repair_case.name)

	for field in {"style": 2, "room_layout": 2, "player_palette": 3}:
		var maximum: int = {"style": 2, "room_layout": 2, "player_palette": 3}[field]
		for choice in range(maximum + 1):
			var candidate := {field: choice}
			_check(SaveState.save_progress(candidate, test_path) == OK, "Valid choice must save: " + field)
			_check(SaveState.load_progress(test_path)[field] == choice, "Every supported choice must round-trip: " + field + "=" + str(choice))
		for invalid in [-1, maximum + 1, 1.5, "1", true, null]:
			_raw_file({field: invalid})
			_check(SaveState.load_progress(test_path)[field] == 0, "Invalid choice must use the default: " + field + "=" + str(invalid))

	for field in ["night", "audio_enabled"]:
		for flag in [true, false]:
			_check(SaveState.save_progress({field: flag}, test_path) == OK, "Boolean option must save: " + field)
			_check(SaveState.load_progress(test_path)[field] == flag, "Both boolean states must round-trip: " + field)
		for invalid in [0, 1, "false", [], null]:
			_raw_file({field: invalid})
			_check(SaveState.load_progress(test_path)[field] == defaults[field], "Malformed boolean must use the default: " + field + "=" + str(invalid))

	for is_night in [true, false]:
		for seconds in [0, 42.25, 179.9]:
			_check(SaveState.save_progress({"night": is_night, "day_night_elapsed": seconds}, test_path) == OK, "Clock progress saves")
			_check(is_equal_approx(SaveState.load_progress(test_path).day_night_elapsed, float(seconds)), "Clock progress round-trips in both phases")
		for invalid in [-1, 240, 1e20, INF, NAN, "30", true, [], null]:
			_raw_file({"night": is_night, "day_night_elapsed": invalid})
			_check(SaveState.load_progress(test_path).day_night_elapsed == 0.0, "Malformed clock progress resets safely")
	_raw_file({"night": true, "day_night_elapsed": 180.0})
	_check(SaveState.load_progress(test_path).day_night_elapsed == 0.0, "Night phase validates its own shorter duration")
	_raw_file({"night": true})
	_check(SaveState.load_progress(test_path).night and SaveState.load_progress(test_path).day_night_elapsed == 0.0, "Legacy night preference starts a full night")

	# Validate both untrusted input to the writer and hand-edited configuration files.
	var malformed := {"discovered": ["glass", "glass", "unknown", 12, "shell"], "repaired": true, "style": 7, "tide_low": "false"}
	var sanitized := defaults.merged({"discovered": ["glass", "shell"], "repaired": false, "style": 0, "tide_low": true}, true)
	_check(SaveState.save_progress(malformed, test_path) == OK, "Malformed input must be normalized before saving")
	_check(SaveState.load_progress(test_path) == sanitized, "IDs, duplicates, range, types, and premature repair must be validated")
	_raw_file(malformed)
	_check(SaveState.load_progress(test_path) == sanitized, "Loaded malformed values must receive the same validation")
	_raw_file({"discovered": "glass", "repaired": 1, "style": 1.5, "tide_low": 0})
	_check(SaveState.load_progress(test_path) == defaults, "Wrong value types must return safe defaults")
	_raw_file({"discovered": ["glass", "shell", "wood"], "repaired": "true", "style": -1})
	_check(not SaveState.load_progress(test_path).repaired, "A string must not count as a repair flag")

	var file := FileAccess.open(test_path, FileAccess.WRITE)
	_check(file != null, "Corrupt-file fixture must open")
	if file:
		file.store_string("[progress\ndiscovered = [\n")
		file.close()
	var previous_error_messages := Engine.print_error_messages
	Engine.print_error_messages = false # The deliberately corrupt fixture produces an expected parser diagnostic.
	var corrupted := SaveState.load_progress(test_path)
	Engine.print_error_messages = previous_error_messages
	_check(corrupted == defaults, "Corrupt file must return defaults")
	_check(SaveState.save_progress(complete, "") == ERR_INVALID_PARAMETER, "Empty save path must be rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures.is_empty():
		print("PASS: v1 migration, nine-item v2 round-trip, ordered restoration, appearance and layout ranges, night and audio types, replacement, and corrupt-file recovery")
		quit(0)
	else:
		print("FAIL: %d save-state checks" % failures.size())
		quit(1)
