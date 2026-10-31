extends Control

## A lightweight animated postcard behind the real, keyboard-focusable controls.
var activity: Node3D
var age := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(activity):
		return
	var mode: String = activity.active
	var card := StyleBoxFlat.new()
	card.bg_color = Color("#243e59") if mode == "stars" else Color("#d5e4d9")
	card.set_corner_radius_all(14)
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	if mode != "stars":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / 240.0))
	match mode:
		"stones": _stones()
		"flowers": _flowers()
		"bells": _bells()
		"stars": _stars()

func _text(value: String, at: Vector2, color: Color, font_size := 16) -> void:
	var font: Font = activity.game.chinese_font
	var factor := size.y / 240.0
	var label_size := mini(font_size, 13) if factor < 1.0 else font_size
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
	draw_set_transform(Vector2.ZERO)
	draw_string(font, Vector2(at.x - width * 0.5, at.y * factor), value, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, factor))

func _stones() -> void:
	for row in range(4):
		for col in range(7):
			var p := Vector2(size.x * (col + 0.5) / 7.0, 45 + row * 26 + sin(age * 1.2 + col) * 3)
			draw_arc(p, 17, 0.15, PI - 0.15, 18, Color("#abcfc5"), 2, true)
	if activity.stone_flight > 0:
		var t: float = 1.0 - activity.stone_flight / 2.4
		for hop in range(activity.stone_skips):
			var start: float = float(hop) / activity.stone_skips
			if t >= start:
				var ripple := Vector2(40 + (size.x - 80) * start, 130)
				draw_arc(ripple, 10 + (t - start) * 24, 0, TAU, 30, Color("#faf0d2"), 2, true)
		var p := Vector2(40 + t * (size.x - 80), 125 - absf(sin(t * PI * activity.stone_skips)) * 52)
		draw_circle(p, 7, Color("#647f85"), true, -1, true)
	else:
		draw_circle(Vector2(40, 122), 9, Color("#647f85"), true, -1, true)
	var bar := Rect2(28, 175, size.x - 56, 22)
	draw_style_box(_style(Color("#a0bbb3")), bar)
	draw_style_box(_style(Color("#557f72")), Rect2(bar.position + Vector2(bar.size.x * 0.38, 0), Vector2(bar.size.x * 0.24, 22)))
	var x: float = bar.position.x + bar.size.x * activity.stone_cursor
	draw_line(Vector2(x, 170), Vector2(x, 202), Color("#fff4d7"), 5, true)
	_text("指针越靠近深绿区中心，水漂越远", Vector2(size.x * 0.5, 225), Color("#42605e"), 15)

func _style(color: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(6)
	return result

func _flowers() -> void:
	for i in range(3):
		var p := Vector2(size.x * (i + 0.5) / 3.0, 170)
		var growth: int = activity.progress.flowers[i]
		draw_style_box(_style(Color("#b39178")), Rect2(p - Vector2(32, 6), Vector2(64, 38)))
		draw_ellipse_soil(p)
		if growth > 0:
			var tip := p - Vector2(0, 25 + growth * 22)
			draw_line(p, tip, Color("#618e73"), 5, true)
			draw_colored_polygon(PackedVector2Array([p-Vector2(0,25), p-Vector2(25,45), p-Vector2(14,18)]), Color("#78a489"))
			draw_colored_polygon(PackedVector2Array([p-Vector2(0,38), p+Vector2(23,-56), p+Vector2(12,-29)]), Color("#90b594"))
			if growth >= 2:
				for petal in range(5):
					var angle := petal * TAU / 5.0 + sin(age) * 0.04
					draw_circle(tip + Vector2(cos(angle),sin(angle)) * (16 if growth == 3 else 5), 13 if growth == 3 else 8, activity.Catalog.COLORS[i], true, -1, true)
				draw_circle(tip, 7, Color("#f8df9e"), true, -1, true)
		_text(["种子", "嫩芽", "花苞", "盛开"][growth], p + Vector2(0, 58), Color("#48635e"))

func draw_ellipse_soil(p: Vector2) -> void:
	draw_style_box(_style(Color("#766d60")), Rect2(p - Vector2(28, 10), Vector2(56, 12)))

func _bells() -> void:
	draw_line(Vector2(size.x * 0.1, 35), Vector2(size.x * 0.9, 35), Color("#a08b70"), 7, true)
	for i in range(3):
		var swing := sin(age * 2.6 + i) * (10 if activity.last_note == i else 2)
		var p := Vector2(size.x * (i + 0.5) / 3.0 + swing, 105 + i * 17)
		draw_line(Vector2(size.x * (i + 0.5) / 3.0, 35), p, Color("#a28e74"), 2, true)
		if activity.last_note == i:
			draw_circle(p + Vector2(0, 25), 37, Color("#f9edbb"), true, -1, true)
		draw_style_box(_style(activity.Catalog.COLORS[i]), Rect2(p - Vector2(20, 0), Vector2(40, 53)))
		draw_line(p + Vector2(0, 53), p + Vector2(0, 72), Color("#7b9688"), 2, true)
		draw_circle(p + Vector2(0, 72), 4, Color("#a78a71"), true, -1, true)
		_text(["1 · 哆", "2 · 咪", "3 · 嗦"][i], Vector2(size.x * (i + 0.5) / 3.0, 225), Color("#48635e"))

func _stars() -> void:
	for i in range(44):
		var p := Vector2(fposmod(i * 79.7 + 19, size.x), fposmod(i * 57.3 + 11, size.y))
		draw_circle(p, 1 + sin(age + i) * 0.3, Color("#8aa5bc"), true, -1, true)
	var points: Array = activity.Catalog.STARS[activity.star_choice].points
	for i in range(1, activity.star_step):
		draw_line(points[i - 1] * size, points[i] * size, Color("#f6db9c"), 3, true)
