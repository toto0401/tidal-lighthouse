extends Node3D

const Catalog := preload("res://data/activity_catalog.gd")
const Board := preload("res://scripts/activity_board.gd")
const FREQUENCIES := [523.25, 659.25, 783.99]
var game: Node3D
var progress := Catalog.validated({})
var spots := {}
var flower_models: Array[Node3D] = []
var bell_models: Array[Node3D] = []
var active := ""
var status: Label
var tally: Label
var board: Control
var action_button: Button
var choice_buttons: Array[Button] = []
var stone_cast := false
var stone_time := 0.0
var stone_cursor := 0.0
var stone_flight := 0.0
var stone_skips := 0
var song_choice := 0
var song_step := 0
var last_note := -1
var star_choice := 0
var star_step := 0
var demo: Tween
var watering_effect: Tween
var watering_can: Node3D
var compact := false

func _ready() -> void:
	game = get_parent()
	for spec in Catalog.SPOTS:
		var spot := Node3D.new()
		spot.name = "Activity_" + spec.id
		spot.position = spec.pos
		spot.set_meta("activity_id", spec.id)
		spot.set_meta("activity_verb", spec.verb)
		spot.add_to_group("interactable")
		add_child(spot)
		spots[spec.id] = spot
		game._add_label_3d(spec.name + " · E", Vector3(0, 2.65, 0), Color("#fff0cc"), 0.72, spot)
	_build_stone_spot()
	_build_flowers()
	_build_bells()
	apply_progress(progress)

func _build_stone_spot() -> void:
	var spot: Node3D = spots.stones
	game._add_cylinder("StoneBasket", 0.35, 0.3, Vector3(-0.5, 0.15, 0.3), Color("#b79577"), false, spot)
	for i in range(5):
		var stone: MeshInstance3D = game._add_sphere("SkippingStone", 0.13, Vector3(-0.64 + i * 0.07, 0.34 + i * 0.025, 0.3), Color("#96a9ab"), false, spot)
		stone.scale.y = 0.3

func _build_flowers() -> void:
	var spot: Node3D = spots.flowers
	for i in range(3):
		var plot := Node3D.new()
		plot.position.x = (i - 1) * 1.15
		spot.add_child(plot)
		game._add_box("PocketPlanter", Vector3(0.95, 0.3, 1.1), Vector3(0, 0.15, 0), Color("#b4967f"), false, plot)
		game._add_box("PocketSoil", Vector3(0.82, 0.035, 0.96), Vector3(0, 0.31, 0), Color("#766d60"), false, plot)
		var plant := Node3D.new()
		plant.position.y = 0.32
		plot.add_child(plant)
		flower_models.append(plant)
		game._add_cylinder("Stem", 0.045, 0.7, Vector3(0, 0.35, 0), Color("#77a48b"), false, plant)
		for side in [-1, 1]:
			var leaf: MeshInstance3D = game._add_sphere("Leaf", 0.16, Vector3(side * 0.12, 0.32, 0), Color("#9abfa0"), false, plant)
			leaf.scale = Vector3(1.2, 0.3, 0.65)
		var bloom := Node3D.new()
		bloom.name = "Bloom"
		bloom.position.y = 0.74
		plant.add_child(bloom)
		for petal in range(5):
			var angle := petal * TAU / 5.0
			game._add_sphere("Petal", 0.18, Vector3(cos(angle) * 0.17, 0, sin(angle) * 0.17), Catalog.COLORS[i], false, bloom)
		game._add_sphere("Pollen", 0.12, Vector3(0, 0.08, 0), Color("#f7d991"), false, bloom)
	watering_can = Node3D.new()
	watering_can.position = Vector3(2.0, 0, 0)
	spot.add_child(watering_can)
	game._add_cylinder("WateringCan", 0.2, 0.32, Vector3(0, 0.2, 0), Color("#92b6bc"), false, watering_can)
	var spout: MeshInstance3D = game._add_cylinder("Spout", 0.05, 0.45, Vector3(-0.22, 0.26, 0), Color("#92b6bc"), false, watering_can)
	spout.rotation.z = -0.9

func _build_bells() -> void:
	var spot: Node3D = spots.bells
	for x in [-1.25, 1.25]:
		game._add_cylinder("ChimePost", 0.065, 2.1, Vector3(x, 1.05, 0), Color("#bca688"), false, spot)
	game._add_box("ChimeBeam", Vector3(2.7, 0.1, 0.15), Vector3(0, 2.1, 0), Color("#c9b494"), false, spot)
	for i in range(3):
		var bell := Node3D.new()
		bell.position = Vector3((i - 1) * 0.7, 2.05, 0)
		spot.add_child(bell)
		bell_models.append(bell)
		game._add_cylinder("Thread", 0.012, 0.35, Vector3(0, -0.18, 0), Color("#a8967b"), false, bell)
		game._add_capsule("ShellChime", 0.16, 0.6, Vector3(0, -0.65, 0), Catalog.COLORS[i], false, bell)
		game._add_sphere("ChimeBead", 0.06, Vector3(0, -1.1, 0), Color("#e7d6b2"), false, bell)

func apply_progress(raw: Variant) -> void:
	progress = Catalog.validated(raw)
	for i in flower_models.size():
		var growth: int = progress.flowers[i]
		var plant := flower_models[i]
		plant.visible = growth > 0
		plant.scale = Vector3.ONE * [0.15, 0.4, 0.72, 1.0][growth]
		plant.get_node("Bloom").visible = growth >= 2
		plant.get_node("Bloom").scale = Vector3.ONE * (0.5 if growth == 2 else 1.0)

func cancel_session() -> void:
	active = ""
	stone_cast = false
	stone_flight = 0.0
	if demo:
		demo.kill()
		demo = null
	last_note = -1
	choice_buttons.clear()
	for bell in bell_models:
		bell.rotation.z = 0

func _process(delta: float) -> void:
	if active.is_empty():
		return
	if not game.menu_is_open() or game.menus.current_page != "activity":
		cancel_session()
		return
	stone_flight = maxf(0.0, stone_flight - delta)
	if active == "stones" and stone_cast:
		stone_time += delta
		stone_cursor = (1.0 - cos(stone_time * 2.1)) * 0.5
	if last_note >= 0:
		bell_models[last_note].rotation.z = sin(Time.get_ticks_msec() * 0.008) * 0.23

func _unhandled_key_input(event: InputEvent) -> void:
	if active.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if active == "stones" and code == KEY_E:
		stone_action()
	elif code >= KEY_1 and code <= KEY_5:
		var index := int(code - KEY_1)
		if index >= choice_buttons.size() or choice_buttons[index].disabled:
			return
		choice_buttons[index].pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()

func open_activity(id: String) -> void:
	if not spots.has(id) or game.player.global_position.distance_to(spots[id].global_position) >= 2.6:
		return
	var spec: Dictionary = Catalog.SPOTS.filter(func(entry: Dictionary): return entry.id == id)[0]
	var box: VBoxContainer = game.menus._page(spec.name, spec.where + "  ·  随时按 Esc 离开", 700)
	game.menus.current_page = "activity"
	active = id
	status = game.menus._label(box, "", 18)
	status.custom_minimum_size.y = 52
	board = Board.new()
	board.activity = self
	box.add_child(board)
	tally = game.menus._label(box, "", 15)
	match id:
		"stones":
			stone_cursor = 0.0
			status.text = "拿一块扁石，等指针进入深绿区中心再投出。\n投得越准，石头在海面上跳得越远。"
			action_button = game.menus._button(box, "准备投石  ·  E", stone_action)
			game.menus._label(box, "瞄准深绿区正中，挑战连续五跳。没有次数限制。", 14).set_meta("activity_hint", true)
		"flowers":
			status.text = "点击花盆浇水，让种子、嫩芽、花苞慢慢盛开。\n每盆浇三次；也可以按 1 / 2 / 3。"
			var row := _row(box)
			for i in range(3):
				choice_buttons.append(game.menus._button(row, "", water_flower.bind(i)))
			_refresh_flower_buttons()
		"bells":
			song_step = 0
			var row := _row(box)
			for i in range(3):
				choice_buttons.append(game.menus._button(row, ["1 · 哆", "2 · 咪", "3 · 嗦"][i], play_note.bind(i)))
			var actions := _row(box)
			game.menus._button(actions, "听一遍旋律", play_demo)
			game.menus._button(actions, "换一首", next_song)
			_song_status()
		"stars":
			star_step = 0
			if not game.night:
				status.text = "白天的天空太亮了，星星还没有出现。\n让夜色降临，再把星光连成图案。"
				game.menus._button(box, "等到月夜", func():
					game.toggle_night()
					open_activity("stars")
				)
			else:
				_build_star_buttons()
				_star_status()
				game.menus._button(box, "寻找另一片星空", next_stars)
	_fit_activity(box)
	game.menus.overlay.resized.connect(_fit_activity.bind(box))

func _fit_activity(box: VBoxContainer) -> void:
	if not is_instance_valid(box):
		return
	compact = get_viewport().get_visible_rect().size.y < 600
	box.add_theme_constant_override("separation", 8 if compact else 20)
	box.get_child(0).visible = not compact
	status.custom_minimum_size.y = 44 if compact else 52
	status.add_theme_font_size_override("font_size", 15 if compact else 18)
	board.custom_minimum_size.y = 130 if compact else 240
	tally.add_theme_font_size_override("font_size", 13 if compact else 15)
	for child in box.get_children():
		if child.has_meta("activity_hint"):
			child.visible = not compact
	_refresh_tally()

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row

func _refresh_tally() -> void:
	if is_instance_valid(tally):
		tally.text = "水漂最佳 %d 跳   ·   花开 %d/3   ·   旋律 %d/3   ·   星图 %d/2\n收获记在 J 手账的「岛上闲趣」里。" % [progress.stone_best, progress.flowers.count(3), progress.songs.size(), progress.stars.size()]
		if compact:
			tally.text = "水漂 %d 跳 · 花开 %d/3 · 旋律 %d/3 · 星图 %d/2" % [progress.stone_best, progress.flowers.count(3), progress.songs.size(), progress.stars.size()]

func _record() -> void:
	var result: Error = game._save_progress()
	_refresh_tally()
	if result != OK:
		tally.text += "\n暂时未能保存，返回暂停菜单可重试。"

func stone_action() -> void:
	if active != "stones":
		return
	if not stone_cast:
		stone_cast = true
		stone_time = 0.0
		stone_cursor = 0.0
		stone_flight = 0.0
		status.text = "手腕放轻，等指针靠近深绿区正中。\n按 E 或点「投出石子」，看它在水面上跳几次。"
		action_button.text = "投出石子  ·  E"
		return
	stone_cast = false
	stone_skips = 5 if absf(stone_cursor - 0.5) <= 0.12 else 3 if absf(stone_cursor - 0.5) <= 0.28 else 1
	stone_flight = 2.4
	var previous: int = progress.stone_best
	progress.stone_best = maxi(previous, stone_skips)
	status.text = "石子在海面上跳了 %d 次！%s\n%s" % [stone_skips, " 新纪录。" if stone_skips > previous else "", "五跳达成，已记入闲趣手账。" if stone_skips == 5 else "再靠近深绿区正中一些，试试连续五跳。"]
	action_button.text = "再试一颗  ·  E"
	game._play_chime(520 + stone_skips * 70, 0.6)
	_record()

func water_flower(index: int) -> void:
	if active != "flowers" or index < 0 or index >= 3:
		return
	if progress.flowers[index] >= 3:
		status.text = Catalog.FLOWERS[index] + "正在盛开。\n浇过的水都变成了花瓣，随时回来看看吧。"
		return
	progress.flowers[index] += 1
	apply_progress(progress)
	var growth: int = progress.flowers[index]
	status.text = Catalog.FLOWERS[index] + " · " + ["", "种子冒出了嫩芽", "枝头鼓起了花苞", "开花了，已收入手账"][growth] + "\n回到岛上，也能看到花圃的新模样。"
	if watering_effect:
		watering_effect.kill()
	watering_can.rotation.z = -0.45
	watering_effect = create_tween()
	watering_effect.tween_property(watering_can, "rotation:z", 0.0, 0.8)
	game._play_chime(520 + growth * 130, 0.5)
	_refresh_flower_buttons()
	_record()

func _refresh_flower_buttons() -> void:
	for i in choice_buttons.size():
		choice_buttons[i].text = "%d · %s\n%s" % [i + 1, Catalog.FLOWERS[i], "赏花" if progress.flowers[i] == 3 else "浇水 %d/3" % progress.flowers[i]]

func _song_status() -> void:
	var song: Dictionary = Catalog.SONGS[song_choice]
	var notes: Array[String] = []
	for i in song.notes.size():
		notes.append(("✓" if i < song_step else "") + str(song.notes[i] + 1))
	status.text = song.name + "   " + " → ".join(notes) + "\n" + ("旋律已收入手账。可以继续演奏，或换一首。" if song_step == song.notes.size() else "按谱点风铃，或按 1 / 2 / 3；可先听一遍。")

func play_note(index: int) -> void:
	if active != "bells" or index < 0 or index >= 3 or (demo and demo.is_running()):
		return
	_sound_note(index)
	var song: Dictionary = Catalog.SONGS[song_choice]
	if song_step == song.notes.size():
		song_step = 0
	if index != song.notes[song_step]:
		song_step = 0
		_song_status()
		status.text = status.text.get_slice("\n", 0) + "\n轻轻再来，下一音从 %d 开始。" % (song.notes[0] + 1)
		return
	song_step += 1
	_song_status()
	if song_step == song.notes.size():
		if song.id not in progress.songs:
			progress.songs.append(song.id)
		_record()

func _sound_note(index: int) -> void:
	for bell in bell_models:
		bell.rotation.z = 0
	last_note = index
	game._play_chime(FREQUENCIES[index], 0.6)

func play_demo() -> void:
	if active != "bells":
		return
	if demo:
		demo.kill()
	song_step = 0
	status.text = "听听「%s」……\n风铃会依次亮起，静音时也可以看着学。" % Catalog.SONGS[song_choice].name
	for button in choice_buttons:
		button.disabled = true
	demo = create_tween()
	for note in Catalog.SONGS[song_choice].notes:
		demo.tween_callback(_sound_note.bind(note))
		demo.tween_interval(0.65)
	demo.tween_callback(func():
		for button in choice_buttons:
			button.disabled = false
		_song_status()
	)

func next_song() -> void:
	song_choice = (song_choice + 1) % Catalog.SONGS.size()
	open_activity("bells")

func _build_star_buttons() -> void:
	var points: Array = Catalog.STARS[star_choice].points
	for i in points.size():
		var button: Button = game.menus._button(board, str(i + 1), connect_star.bind(i))
		button.custom_minimum_size = Vector2(44, 44)
		button.size = Vector2(44, 44)
		button.tooltip_text = "连接第 %d 颗星（按 %d）" % [i + 1, i + 1]
		button.set_anchor(SIDE_LEFT, points[i].x)
		button.set_anchor(SIDE_RIGHT, points[i].x)
		button.set_anchor(SIDE_TOP, points[i].y)
		button.set_anchor(SIDE_BOTTOM, points[i].y)
		button.offset_left = -22
		button.offset_right = 22
		button.offset_top = -22
		button.offset_bottom = 22
		choice_buttons.append(button)

func _star_status() -> void:
	status.text = "正在寻找「%s」\n按 1 → 5 的顺序点亮星星，也可以用数字键。" % Catalog.STARS[star_choice].name

func connect_star(index: int) -> void:
	if active != "stars" or not game.night or star_step >= 5:
		return
	if index != star_step:
		status.text = "星光还连不到这里。\n接着点第 %d 颗星，之前的连线会保留。" % (star_step + 1)
		return
	choice_buttons[index].text = "✦"
	choice_buttons[index].modulate = Color("#ffe2a0")
	star_step += 1
	game._play_chime(587.33 + index * 90, 0.5)
	if star_step == 5:
		var star: Dictionary = Catalog.STARS[star_choice]
		if star.id not in progress.stars:
			progress.stars.append(star.id)
		status.text = "认出了「%s」！\n这片星空已经画进手账。" % star.name
		_record()
	else:
		_star_status()

func next_stars() -> void:
	star_choice = (star_choice + 1) % Catalog.STARS.size()
	open_activity("stars")

func open_journal() -> void:
	var origin: String = game.menus.current_page
	var box: VBoxContainer = game.menus._page("岛上闲趣", "把散步途中喜欢的小事，一件件留在这里。  %d / 9" % Catalog.count(progress), 720)
	game.menus.current_page = "leisure"
	game.menus.return_page = origin if origin in ["archive", "pause"] else ""
	for spec in Catalog.SPOTS:
		game.menus._label(box, spec.name + "  ·  " + spec.where, 19)
		var lines: Array[String] = []
		match spec.id:
			"stones":
				lines.append(("◆ " if progress.stone_best == 5 else "◇ ") + "五跳挑战  ·  最佳 %d 跳" % progress.stone_best)
			"flowers":
				for i in range(3):
					lines.append(("◆ " if progress.flowers[i] == 3 else "◇ ") + Catalog.FLOWERS[i] + "  ·  " + ["等待浇水", "嫩芽 1/3", "花苞 2/3", "已经盛开"][progress.flowers[i]])
			"bells":
				for song in Catalog.SONGS:
					lines.append(("◆ " if song.id in progress.songs else "◇ ") + song.name)
			"stars":
				for star in Catalog.STARS:
					lines.append(("◆ " if star.id in progress.stars else "◇ ") + star.name + "  ·  月夜")
		game.menus._label(box, "\n".join(lines), 16)
	game.menus._button(box, "返回手账" if origin == "archive" else "返回", game.menus.back)
