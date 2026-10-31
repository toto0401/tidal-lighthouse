extends RefCounted

const Catalog := preload("res://data/island_catalog.gd")
const ActivityCatalog := preload("res://data/activity_catalog.gd")
const FishCatalog := preload("res://data/fish_catalog.gd")
const DayNightCycle := preload("res://scripts/day_night_cycle.gd")
const SECTION := "progress"

static func load_progress(path: String = "user://progress.cfg") -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return _validated({})
	var data := {}
	for key in ["discovered", "repaired", "style", "tide_low", "garden_repaired", "cove_repaired", "room_layout", "player_palette", "night", "day_night_elapsed", "audio_enabled", "fish_caught", "activities"]:
		if config.has_section_key(SECTION, key):
			data[key] = config.get_value(SECTION, key)
	return _validated(data)

static func save_progress(data: Dictionary, path: String = "user://progress.cfg") -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	var validated := _validated(data)
	for key in validated:
		config.set_value(SECTION, key, validated[key])
	# Keep the temporary file beside its destination so the rename is on the same volume.
	var temporary := "%s.tmp.%s.%s" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return error

static func _validated(data: Dictionary) -> Dictionary:
	var ids: Array[String] = []
	var raw_ids: Variant = data.get("discovered", [])
	if raw_ids is Array:
		for id in raw_ids:
			if typeof(id) == TYPE_STRING and id in Catalog.ids() and id not in ids:
				ids.append(id)
	var raw_style: Variant = data.get("style", 0)
	var style: int = raw_style if typeof(raw_style) == TYPE_INT and raw_style >= 0 and raw_style <= 2 else 0
	var raw_repaired: Variant = data.get("repaired", false)
	var raw_tide: Variant = data.get("tide_low", true)
	var known := {}
	for id in ids:
		known[id] = true
	var repaired: bool = typeof(raw_repaired) == TYPE_BOOL and raw_repaired and Catalog.has_all(known, Catalog.LIGHTHOUSE_IDS)
	var garden: bool = _flag(data, "garden_repaired") and repaired and Catalog.has_all(known, Catalog.GARDEN_IDS)
	var cove: bool = _flag(data, "cove_repaired") and garden and Catalog.has_all(known, Catalog.COVE_IDS)
	return {
		"discovered": ids,
		"repaired": repaired,
		"style": style,
		"tide_low": raw_tide if typeof(raw_tide) == TYPE_BOOL else true,
		"garden_repaired": garden,
		"cove_repaired": cove,
		"room_layout": _choice(data, "room_layout", 2),
		"player_palette": _choice(data, "player_palette", 3),
		"night": _flag(data, "night"),
		"day_night_elapsed": DayNightCycle.validated_elapsed(data.get("day_night_elapsed", 0.0), _flag(data, "night")),
		"audio_enabled": _flag(data, "audio_enabled", true),
		"activities": ActivityCatalog.validated(data.get("activities", {})),
		"fish_caught": FishCatalog.validated(data.get("fish_caught", {})),
	}

static func _flag(data: Dictionary, key: String, fallback := false) -> bool:
	var value: Variant = data.get(key, fallback)
	return value if typeof(value) == TYPE_BOOL else fallback

static func _choice(data: Dictionary, key: String, maximum: int) -> int:
	var value: Variant = data.get(key, 0)
	return value if typeof(value) == TYPE_INT and value >= 0 and value <= maximum else 0
