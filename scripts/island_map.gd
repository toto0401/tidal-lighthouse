extends Control

const Layout := preload("res://data/world_layout.gd")
var game: Node3D
const SCALE := 5.0
const ORIGIN := Vector2(400, 282)
const INK := Color("#36575d")

func _ready() -> void:
	custom_minimum_size = Vector2(800, 392)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func point(p: Vector2) -> Vector2:
	return ORIGIN + p * SCALE

func caption(text: String, at: Vector2, color := INK, font_size := 17) -> void:
	var width: float = game.chinese_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(game.chinese_font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	draw_style_box(_paper(), Rect2(Vector2.ZERO, size))
	for p in [Vector2(100,90), Vector2(694,200), Vector2(92,330), Vector2(650,52)]:
		for row in range(3):
			draw_arc(p + Vector2(row * 6, row * 8), 20, 0.1, PI - 0.1, 18, Color("#a4cac3"), 1.5, true)
	var islands := [
		[Vector2.ZERO, 17.0, Color("#b3c69a"), "灯塔主岛"],
		[Vector2(-31,-5),14.0,Color("#e4d1a9"),"月贝沙洲"],
		[Vector2(32,2),16.0,Color("#afcaa1"),"绣球花岛"],
		[Vector2(0,-36),13.0,Color("#b0b6c8"),"观星岬"]
	]
	for spec in islands:
		var center := point(spec[0])
		draw_circle(center, spec[1]*SCALE+5, Color("#84b5b0"), false, 2, true)
		draw_circle(center, spec[1]*SCALE, Color("#f0dfb8"), true, -1, true)
		draw_circle(center, (spec[1]-1.3)*SCALE, spec[2], true, -1, true)
	for bridge in Layout.BRIDGES:
		draw_line(point(bridge.from), point(bridge.to), Color("#987d64"), 13, true)
		draw_line(point(bridge.from), point(bridge.to), Color("#ead0a2"), 8, true)
	for spec in islands:
		caption(spec[3], point(spec[0]) + Vector2(0, -28))
	for spec in game.item_specs:
		if game.Catalog.available(spec, game.restoration_stage(), game.tide_low, game.night) and not game.discovered.has(spec.id):
			var pos := point(Vector2(spec.pos.x,spec.pos.z))
			draw_circle(pos, 5, Color("#f4f0d4"), true, -1, true)
			draw_circle(pos, 3, Color("#b9746d"), true, -1, true)
	for spot in game.activities.Catalog.SPOTS:
		var pos := point(Vector2(spot.pos.x, spot.pos.z))
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0,-6), pos + Vector2(6,0), pos + Vector2(0,6), pos + Vector2(-6,0)]), Color("#3f817e"))
	var lighthouse := point(Vector2(-7.5,7))
	draw_rect(Rect2(lighthouse - Vector2(5,12), Vector2(10,17)), Color("#f7efda"))
	draw_colored_polygon(PackedVector2Array([lighthouse+Vector2(-8,-12),lighthouse+Vector2(0,-20),lighthouse+Vector2(8,-12)]), Color("#577c80"))
	var here := point(Vector2(game.player.position.x, game.player.position.z) if game.current_location == "island" else Vector2(-7.5,7))
	var outside := not Rect2(16, 24, 768, 336).has_point(here)
	here = here.clamp(Vector2(16, 24), Vector2(784, 360))
	draw_circle(here, 8, Color("#f9f0cf"), true, -1, true)
	draw_circle(here, 4, Color("#df816d"), true, -1, true)
	caption("你（图外海域）" if outside else "你", Vector2(clampf(here.x, 65, 735), here.y - 13), Color("#733f42"), 15)
	caption("N  北", Vector2(747,48), INK, 14)
	draw_line(Vector2(747,80), Vector2(747,58), INK, 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(743,65),Vector2(747,55),Vector2(751,65)]), INK)
	caption("暖红点 · 你的位置     小圆点 · 遗物     绿菱形 · 闲趣", Vector2(400,385), INK, 14)

func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#d6e5d9")
	style.set_corner_radius_all(10)
	return style
