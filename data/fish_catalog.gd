extends RefCounted

const FISH := [
	{"id": "silver", "name": "银鳞小鱼", "hint": "每一片岸边，都有银色的小小惊喜。", "color": Color("#c4e7df")},
	{"id": "mackerel", "name": "晴海青鲭", "hint": "白昼时追逐海面上的阳光。", "color": Color("#7bbbc6")},
	{"id": "bream", "name": "珊瑚海鲷", "hint": "涨潮时，随暖流来到岸边。", "color": Color("#edac95")},
	{"id": "moonfish", "name": "月光灯鱼", "hint": "月夜里，像一颗落进海里的星。", "color": Color("#c6b7eb")}
]

static func available(night: bool, tide_low: bool) -> Array[Dictionary]:
	var fish: Array[Dictionary] = [FISH[0], FISH[3] if night else FISH[1]]
	if not tide_low:
		fish.append(FISH[2])
	return fish

static func validated(raw: Variant) -> Dictionary:
	var result := {}
	if raw is Dictionary:
		for fish in FISH:
			var count: Variant = raw.get(fish.id, 0)
			if typeof(count) == TYPE_INT and count > 0:
				result[fish.id] = mini(count, 999999)
	return result
