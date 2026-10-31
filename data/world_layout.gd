extends RefCounted

## Shared positions for rendering, map hints and safe shoreline movement.
const GROUND_HEIGHT := 0.12
const CORE_RADIUS := 15.25
const CORE_SHORE_RADIUS := 17.0
const SWIM_OFFSHORE_DISTANCE := 12.0
const REGIONS := [
	{"id": "moon_shell", "name": "月贝沙洲", "center": Vector2(-31, -5), "radius": 14.0, "scenic": Vector3(-35, 0.2, -7)},
	{"id": "bloom_path", "name": "绣球花岛", "center": Vector2(32, 2), "radius": 16.0, "scenic": Vector3(35, 0.2, 5)},
	{"id": "star_cape", "name": "观星岬", "center": Vector2(0, -36), "radius": 13.0, "scenic": Vector3(0, 0.2, -36)}
]
const BRIDGES := [
	{"name": "月贝木桥", "from": Vector2(-12, -2), "to": Vector2(-23, -4), "width": 4.6},
	{"name": "花径木桥", "from": Vector2(12, 3), "to": Vector2(24, 3), "width": 4.6},
	{"name": "星光长桥", "from": Vector2(0, -11), "to": Vector2(0, -28), "width": 4.6}
]

static func distance_to_shore(point: Vector2) -> float:
	var distance := point.length() - CORE_SHORE_RADIUS
	for region in REGIONS:
		distance = minf(distance, point.distance_to(region.center) - float(region.radius))
	return maxf(distance, 0.0)

static func clamp_to_swimming_area(point: Vector2) -> Vector2:
	# The union of the four coastal areas keeps every inter-island channel open.
	# Project onto the nearest area only when outside, so overlapping areas never
	# snap the swimmer back to a particular island.
	var nearest := point.limit_length(CORE_SHORE_RADIUS + SWIM_OFFSHORE_DISTANCE)
	var distance := point.distance_squared_to(nearest)
	for region in REGIONS:
		var center: Vector2 = region.center
		var candidate := center + (point - center).limit_length(float(region.radius) + SWIM_OFFSHORE_DISTANCE)
		var candidate_distance := point.distance_squared_to(candidate)
		if candidate_distance < distance:
			nearest = candidate
			distance = candidate_distance
	return nearest
