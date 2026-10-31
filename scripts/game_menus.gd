extends CanvasLayer

const IslandMap := preload("res://scripts/island_map.gd")

var game: Node3D
var overlay: Control
var title_open := false
var current_page := ""
var return_page := ""
var first_button: Button

func _ready() -> void:
	game = get_parent()
	layer = 20

func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if (code == KEY_ESCAPE and not title_open) or (code == KEY_H and current_page == "help"):
		back()
		get_viewport().set_input_as_handled()

func close() -> void:
	if is_instance_valid(game.activities):
		game.activities.cancel_session()
	if is_instance_valid(game.ui_layer):
		game.ui_layer.show()
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
		overlay = null
	title_open = false
	current_page = ""
	return_page = ""
	first_button = null
	game.jump_requested = false
	game.gliding.requested = false
	game.cancel_dash()
	if is_instance_valid(game.water_activities):
		game.water_activities.cancel_fishing()
	game.camera_dragging = false

func back() -> void:
	var destination := return_page
	match destination:
		"title": open_title()
		"pause": open_pause()
		"ending": open_ending()
		"archive": open_archive()
		_: close()

func _page(title: String, subtitle := "", width := 580.0) -> VBoxContainer:
	close()
	game.ui_layer.hide()
	overlay = Control.new()
	overlay.name = "MenuOverlay"
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.14, 0.2, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	overlay.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f4ead8")
	style.set_corner_radius_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	style.shadow_color = Color(0.04, 0.1, 0.15, 0.18)
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 20)
	panel.add_child(shell)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	shell.add_child(header)
	var heading := _label(header, title, 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if title != "潮汐灯塔":
		# Focus the fixed close action so opening a short window never scrolls past the guide.
		var close_button := _button(header, "关闭 ×", back)
		close_button.name = "CloseButton"
		close_button.tooltip_text = "关闭 / 返回（Esc）"
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	shell.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 20)
	scroll.add_child(box)
	if not subtitle.is_empty():
		_label(box, subtitle, 16)
	var fit := func(): _fit_page(panel, shell, box, width)
	box.minimum_size_changed.connect(func(): fit.call_deferred())
	overlay.resized.connect(func(): fit.call_deferred())
	fit.call_deferred()
	return box

func _fit_page(panel: PanelContainer, shell: VBoxContainer, box: VBoxContainer, width: float) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(overlay):
		return
	var available := overlay.size - Vector2(48, 48)
	var header_height := (shell.get_child(0) as Control).get_combined_minimum_size().y
	var content_height := box.get_combined_minimum_size().y + header_height + 72
	panel.size = Vector2(minf(width, available.x), minf(content_height, available.y))
	panel.position = (overlay.size - panel.size) * 0.5

func _label(parent: Node, text: String, size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", game.chinese_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#304a52"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", game.chinese_font)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#f9f2df"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#597e7c")
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#72958d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("#dfae70")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	button.pressed.connect(callback)
	if not is_instance_valid(first_button):
		first_button = button
		button.grab_focus.call_deferred()
	return button

func open_title() -> void:
	var box := _page("潮汐灯塔", "T I D A L   A R C H I V E\n\n海把遗失的小东西送回岸边。\n你把它们记进手账，也让小岛一点点醒来。", 600)
	title_open = true
	current_page = "title"
	var has_progress: bool = game.archive_count > 0 or not game.fish_caught.is_empty() or game.activities.progress != game.activities.Catalog.validated({})
	_button(box, "继续旅程" if has_progress else "开始旅程", close)
	_button(box, "散步指南", open_help)
	if has_progress:
		_button(box, "重新开始", confirm_new_journey)
	_label(box, "四片相连的岛屿 · 九页潮汐档案 · 属于你的小屋", 14)

func open_pause() -> void:
	var box := _page("歇一会儿", "进度会在发现、修复和布置后自动保存。")
	current_page = "pause"
	_button(box, "继续散步", close)
	_button(box, "海岛漫游图  Tab", open_map)
	_button(box, "打开潮汐档案馆  J", open_archive)
	_button(box, "岛上闲趣 · 水漂、花圃、风铃与星图", game.activities.open_journal)
	_button(box, "操作说明  H", open_help)
	_button(box, "配乐与音效：" + ("开启" if game.audio_enabled else "关闭"), _toggle_sound)
	_button(box, "重新开始旅程", confirm_new_journey)
	_button(box, "保存并退出", func():
		if game._save_progress() == OK:
			get_tree().quit()
		else:
			_label(box, "暂时无法保存，请检查存档目录后重试。", 16)
	)

func _toggle_sound() -> void:
	game.toggle_audio()
	open_pause()

func open_help() -> void:
	if current_page == "help":
		back()
		return
	var origin := current_page
	var box := _page("散步指南", "不必赶时间。昼夜自然交替，也可按 N 随时切换。", 650)
	current_page = "help"
	return_page = origin if origin in ["title", "pause"] else ""
	_label(box, "小岛时间：白昼约 4 分钟，月夜约 3 分钟，循环交替。\n天空、海水、灯光与配乐会慢慢过渡；N 从另一时段重新计时。\n喝茶、钓鱼和待在灯塔里也会走时；打开菜单时暂停。", 17)
	_label(box, "WASD 走路      空格 跳跃      E 互动\nShift 踏浪冲刺：随行走方向滑行，站定时朝面向\n陆地 / 游泳都可用，一次约 8 米，冷却 1.5 秒\n左键拖动 / 方向键 转视角      滚轮 缩放\nC 镜头回正      T 潮汐      N 昼夜\nTab 海岛地图      J 档案      V 换衣      M 声音\n进入灯塔小屋后按 B 布置，1 / 2 / 3 快速换色\nEsc 暂停 / 返回", 18)
	_label(box, "随时可在塔门按 E 进入小屋，无需先收集遗物。\n靠近右后方楼梯按 E 切换到塔顶。\n记录三件海岸遗物后，在塔顶灯芯前按 E 修复。\n再恢复花园与海湾，让小海豹回家。\n沿木桥探索新岛屿，Tab 地图可帮你找到方向。", 17)
	_label(box, "乘风滑翔：塔顶右侧的起飞点按 E，展开滑翔翼飞回海岛。\n室外从高处起跳或落下，离地至少 2 米时也可按 G 展翼。\nWASD 转向；松开方向键继续向前，缓慢下降。\nG / 空格收翼，落地或入水自动收起。无需解锁，不消耗道具。\n菜单会暂停空中移动，关闭后继续；Tab 可快速回家。", 17)
	_label(box, "岛上的小邻居：\n主岛和绣球花岛有小兔子，月贝沙洲有小螃蟹。\n海鸥会在主岛、月贝沙洲和观星岬散步、飞翔。\n走近看见提示后按 E 摸摸或打招呼；飞行时等它落地。\n夜晚兔子和海鸥会休息，小螃蟹仍会散步。", 17)
	_label(box, "闲趣地点靠近按 E：\n主岛码头打水漂：E 准备，指针进深绿区时再按 E 投石。\n东岛花圃浇水、西岛风铃演奏：点击按钮或按 1 / 2 / 3。\n绣球花岛茶席：靠近桌子或软垫按 E 坐下，F 喝茶，E / WASD 起身。\n北岬望远镜：月夜按 1 → 5 连星。\nJ 手账中的「岛上闲趣」记录收获，进度自动保存。", 17)
	_label(box, "自由游泳：走入海水自动浮起，WASD 游动，Shift 冲刺，靠岸自动上岸。\n空格结束冲刺；可游到岛岸外约 12 米，近海边缘会提示转向。\n没有溺水惩罚，Tab 可回到灯塔。\n岸边 / 木桥边按 F 抛竿，听到提示、看见咬钩后再按 F 收竿。\n提前按 F、走动或打开菜单会收起鱼竿；咬钩后不必抢时间。\n白昼、月夜和涨潮会遇到不同的鱼，钓鱼记录按 J 查看。", 17)
	_button(box, "返回标题" if return_page == "title" else "返回暂停菜单" if return_page == "pause" else "回到岛上  ·  H / Esc", back)

func open_archive() -> void:
	var origin := current_page
	var box := _page("潮汐档案馆", "九件来自海的礼物，每一件都值得记住。", 1040)
	current_page = "archive"
	return_page = origin if origin in ["pause", "ending"] else ""
	_button(box, "岛上闲趣  ·  %d / 9  ·  查看水漂、花圃、旋律与星图" % game.activities.Catalog.count(game.activities.progress), game.activities.open_journal)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	for stage in range(3):
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 310
		column.add_theme_constant_override("separation", 14)
		columns.add_child(column)
		_label(column, ["01 · 第一束光", "02 · 风铃花园", "03 · 星砂海湾"][stage], 20)
		for spec in game.item_specs:
			if int(spec.stage) != stage:
				continue
			var found: bool = game.discovered.has(spec.id)
			_label(column, ("◆ " if found else "◇ ") + str(spec.name), 18)
			var detail := _label(column, str(spec.hint) if found else "尚未记录 · " + game.discovery_condition(spec), 14)
			detail.custom_minimum_size.x = 280
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "04 · 海边钓鱼", 20)
	for fish in game.FishCatalog.FISH:
		var count: int = game.fish_caught.get(fish.id, 0)
		_label(box, ("◆ %s × %d" % [fish.name, count] if count > 0 else "◇ " + str(fish.name) + " · 尚未钓到") + "  —  " + str(fish.hint), 16)
	_button(box, "合上手账", back)

func open_map() -> void:
	var origin := current_page
	var box := _page("海岛漫游图", "沿木桥散步，或在岛屿周围近海游泳；海域边缘会提醒你返回。", 880)
	current_page = "map"
	return_page = origin if origin == "pause" else ""
	if game.current_location != "island":
		_label(box, "你正在" + ("灯塔小屋内" if game.current_location == "room" else "灯塔顶层") + "；地图标记灯塔所在位置。", 16)
	var map := IslandMap.new()
	map.game = game
	box.add_child(map)
	_label(box, "◆ 闲趣地点：主岛码头打水漂 · 东岛花圃浇水\n西岛贝壳风铃 · 北岬望远镜连星（月夜）\n走近按 E 开始，收获记录在 J 手账的「岛上闲趣」。", 15)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	_button(actions, "合上地图，继续散步", back).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(actions, "回到灯塔", func():
		close()
		game.return_home()
	).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func open_decor() -> void:
	if not game._near_lighthouse():
		game._show_toast("布置小屋\n从塔门进入灯塔小屋，再按 B。")
		return
	var box := _page("属于你的灯塔小屋", "换一套颜色，把今天的海摆在喜欢的位置。", 680)
	current_page = "decor"
	_label(box, "房间配色", 17)
	_choices(box, ["珊瑚晨光", "雾蓝海盐", "岛屿苔痕"], game.decoration_style, func(i: int): game._set_decoration(i); open_decor())
	_label(box, "家具陈列", 17)
	_choices(box, ["窗边读书", "围坐喝茶", "留白散步"], game.room_layout, func(i: int): game.set_room_layout(i); open_decor())
	_label(box, "雨衣颜色", 17)
	_choices(box, ["麦芽黄", "雾海蓝", "蔷薇粉", "苔叶绿"], game.player_palette, func(i: int): game.set_player_palette(i); open_decor())
	_button(box, "布置好了", close)

func _choices(parent: Node, labels: Array, selected: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for i in labels.size():
		var button := _button(row, ("✓ " if i == selected else "") + str(labels[i]), callback.bind(i))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func confirm_new_journey() -> void:
	var origin := current_page
	var box := _page("再听一次海的故事", "将从第一件发现重新开始，旧进度会保留备份。")
	current_page = "confirm_new"
	return_page = origin if origin in ["title", "pause"] else ""
	_button(box, "开始新的旅程", func():
		if game.new_journey():
			close()
		else:
			_label(box, "未能备份或保存新旅程，当前进度已保留。", 16)
	)
	_button(box, "保留这次旅程", back).grab_focus.call_deferred()

func open_ending() -> void:
	var box := _page("小岛，终于醒来了", "灯塔亮起，花园开花，雾团回到了海湾。\n九页潮汐档案，记下了这座岛重新发光的过程。", 680)
	current_page = "ending"
	_label(box, "谢谢你把温柔留在这里。\n岛上的每一个明天，都可以慢慢度过。", 20)
	_button(box, "留在岛上，继续生活", close)
	_button(box, "翻看完整的潮汐档案", open_archive)
