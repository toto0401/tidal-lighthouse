extends RefCounted

const ITEMS := [
	{"id": "glass", "name": "月光海玻璃", "color": Color("#b4f1df"), "pos": Vector3(-8, 0.9, -9.5), "hint": "像一小块被月光留下的海。", "tide": "low", "stage": 0},
	{"id": "shell", "name": "回声贝壳", "color": Color("#f4b6a9"), "pos": Vector3(7, 0.65, -10), "hint": "贴近耳边，能听见退潮。", "tide": "low", "stage": 0},
	{"id": "wood", "name": "漂流木星标", "color": Color("#d8a47e"), "pos": Vector3(2, 0.7, 8), "hint": "海把它送来，像一封没有地址的信。", "tide": "any", "stage": 0},
	{"id": "seed", "name": "风铃种子", "color": Color("#e6ca8c"), "pos": Vector3(32, 0.7, 3), "hint": "风经过的时候，种子轻轻碰了一下。", "tide": "any", "stage": 1},
	{"id": "feather", "name": "银白羽毛", "color": Color("#e6e2d9"), "pos": Vector3(-31, 0.75, -5), "hint": "涨潮带来一根羽毛，也带来鸟儿的消息。", "tide": "high", "stage": 1},
	{"id": "moss", "name": "苔绿圆石", "color": Color("#91b88f"), "pos": Vector3(5, 0.65, -3), "hint": "石头的背面，藏着一小片森林。", "tide": "low", "stage": 1},
	{"id": "ribbon", "name": "海蓝缎带", "color": Color("#a0bbd7"), "pos": Vector3(10.5, 0.8, -5.5), "hint": "涨潮把它系在礁石上，像给海湾的礼物。", "tide": "high", "stage": 2},
	{"id": "coral", "name": "珊瑚乐片", "color": Color("#e5a1a0"), "pos": Vector3(-4.5, 0.75, -10), "hint": "温柔的潮声，被它记成一支歌。", "tide": "low", "stage": 2},
	{"id": "stardust", "name": "星砂小瓶", "color": Color("#c5bae0"), "pos": Vector3(0, 0.9, -40), "hint": "夜色与退潮相遇时，星星落进了瓶底。", "tide": "low", "stage": 2, "night": true}
]

const LIGHTHOUSE_IDS := ["glass", "shell", "wood"]
const GARDEN_IDS := ["seed", "feather", "moss"]
const COVE_IDS := ["ribbon", "coral", "stardust"]

static func ids() -> Array[String]:
	var result: Array[String] = []
	for item in ITEMS:
		result.append(item.id)
	return result

static func has_all(discovered: Dictionary, required: Array) -> bool:
	for id in required:
		if not discovered.has(id):
			return false
	return true

static func available(spec: Dictionary, stage: int, low_tide: bool, night: bool) -> bool:
	if int(spec.stage) > stage:
		return false
	if spec.tide == "low" and not low_tide:
		return false
	if spec.tide == "high" and low_tide:
		return false
	return not spec.get("night", false) or night
