extends RefCounted

## Shared dimensions keep the exterior, walkable roof and entrances aligned.
const POSITION := Vector3(-7.5, 0, 7.0)
const RADIUS := 6.2
const GALLERY_HEIGHT := 18.0
const DECK_THICKNESS := 0.4
const FOUNDATION_HEIGHT := 0.5
const SHAFT_TOP := 16.0
const SHAFT_BOTTOM_RADIUS := 5.1
const SHAFT_TOP_RADIUS := 3.7
const LAMP_OFFSET := Vector3(0, 1.72, -1.2)
const BEACON_HEIGHT := GALLERY_HEIGHT + LAMP_OFFSET.y
const DOOR_POSITION := POSITION + Vector3(0, 1.55, -5.04)
const ENTRANCE := POSITION + Vector3(0, 0.7, -RADIUS - 0.65)
const DOOR_RETURN := POSITION + Vector3(0, 1.1, -RADIUS - 1.65)

static func shaft_radius(height: float) -> float:
	return lerpf(SHAFT_BOTTOM_RADIUS, SHAFT_TOP_RADIUS, clampf((height - FOUNDATION_HEIGHT) / (SHAFT_TOP - FOUNDATION_HEIGHT), 0.0, 1.0))
