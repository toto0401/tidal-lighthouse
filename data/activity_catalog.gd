extends RefCounted

const SPOTS := [
	{"id": "stones", "name": "水漂码头", "verb": "试试打水漂", "where": "主岛北岸 · 木码头尽头", "pos": Vector3(4.5, 0.3, -11.5)},
	{"id": "flowers", "name": "口袋花圃", "verb": "给花圃浇水", "where": "东侧绣球花岛 · 茶席西南", "pos": Vector3(30.5, 0.2, 7.5)},
	{"id": "bells", "name": "贝壳风铃", "verb": "奏一段风铃", "where": "西侧月贝沙洲 · 贝壳雕塑东南", "pos": Vector3(-30, 0.2, -1)},
	{"id": "stars", "name": "连星望远镜", "verb": "用望远镜连星", "where": "北方观星岬 · 亭子里的望远镜", "pos": Vector3(1.2, 0.2, -39.2)},
]
const FLOWERS := ["珊瑚小菊", "海盐绣球", "月白铃兰"]
const COLORS := [Color("#e5a499"), Color("#a5bce0"), Color("#f3e3b1")]
const SONGS := [
	{"id": "breeze", "name": "海风来信", "notes": [0, 1, 2, 1, 0]},
	{"id": "tide", "name": "潮汐摇篮", "notes": [2, 0, 1, 0, 2]},
	{"id": "home", "name": "回家的船", "notes": [0, 2, 1, 2, 0]},
]
const STARS := [
	{"id": "sail", "name": "小帆船座", "points": [Vector2(0.2, 0.6), Vector2(0.49, 0.25), Vector2(0.49, 0.6), Vector2(0.8, 0.6), Vector2(0.64, 0.8)]},
	{"id": "whale", "name": "鲸尾座", "points": [Vector2(0.18, 0.25), Vector2(0.37, 0.47), Vector2(0.51, 0.78), Vector2(0.65, 0.47), Vector2(0.83, 0.25)]},
]

static func validated(raw: Variant) -> Dictionary:
	var data: Dictionary = raw if raw is Dictionary else {}
	var flowers := [0, 0, 0]
	var values: Variant = data.get("flowers", [])
	if values is Array:
		for i in mini(values.size(), 3):
			if typeof(values[i]) == TYPE_INT and values[i] >= 0 and values[i] <= 3:
				flowers[i] = values[i]
	var best: Variant = data.get("stone_best", 0)
	return {"stone_best": best if typeof(best) == TYPE_INT and best >= 0 and best <= 5 else 0, "flowers": flowers,
		"songs": _ids(data.get("songs", []), SONGS), "stars": _ids(data.get("stars", []), STARS)}

static func _ids(raw: Variant, catalog: Array) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for entry in catalog:
			if entry.id in raw:
				result.append(entry.id)
	return result

static func count(data: Dictionary) -> int:
	return (1 if data.stone_best == 5 else 0) + data.songs.size() + data.stars.size() + data.flowers.count(3)
