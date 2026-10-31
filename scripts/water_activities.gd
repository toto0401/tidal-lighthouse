extends Node3D

## Shore fishing and pooled water effects. All gameplay advances on physics ticks.
const FishCatalog := preload("res://data/fish_catalog.gd")
const Layout := preload("res://data/world_layout.gd")
enum State { IDLE, CASTING, WAITING, BITE, CAUGHT }
const CAST_TIME := 0.55
const ROD_TIP := Vector3(0.32, 1.55, 1.85)
var game: Node3D
var state := State.IDLE
var fish_requested := false
var timer := 0.0
var clock := 0.0
var scan_timer := 0.0
var cast_point := Vector3.ZERO
var nearby_water := Vector3.ZERO
var can_cast := false
var near_sea_edge := false
var rod: Node3D
var bobber: Node3D
var float_ring: MeshInstance3D
var line: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var line_material: StandardMaterial3D
var caught_fish: Node3D
var fish_body: MeshInstance3D
var fish_tail: MeshInstance3D
var swim_rings: Array[MeshInstance3D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	game = get_parent()
	rng.randomize()
	rod = Node3D.new()
	rod.name = "FishingRod"
	game.player.add_child(rod)
	var bamboo := _material(Color("#b88a59"))
	_segment("BambooRod", Vector3(0.32, 0.15, 0.35), ROD_TIP, 0.025, bamboo, rod)
	_segment("RodGrip", Vector3(0.32, 0.05, 0.25), Vector3(0.32, 0.4, 0.63), 0.042, _material(Color("#4b645f")), rod)
	game._add_sphere("Reel", 0.10, Vector3(0.40, 0.28, 0.45), Color("#e8d6a4"), false, rod)
	bobber = Node3D.new()
	bobber.name = "FishingFloat"
	add_child(bobber)
	game._add_sphere("CoralFloat", 0.105, Vector3(0, 0.08, 0), Color("#ed947f"), false, bobber)
	game._add_sphere("IvoryFloat", 0.086, Vector3(0, 0.16, 0), Color("#fff1cd"), false, bobber)
	_segment("FloatAntenna", Vector3(0, 0.12, 0), Vector3(0, 0.4, 0), 0.015, _material(Color("#f4c685"), true), bobber)
	float_ring = _ring("FloatRipple", 0.30, self)
	line_material = _material(Color("#f8edce"), true)
	line = MeshInstance3D.new()
	line.name = "FishingLine"
	line.mesh = line_mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	caught_fish = Node3D.new()
	caught_fish.name = "CaughtFish"
	add_child(caught_fish)
	fish_body = game._add_sphere("Body", 0.23, Vector3.ZERO, Color.WHITE, false, caught_fish)
	fish_body.scale = Vector3(0.65, 0.9, 1.7)
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.01
	tail_mesh.bottom_radius = 0.20
	tail_mesh.height = 0.28
	tail_mesh.radial_segments = 3
	fish_tail = MeshInstance3D.new()
	fish_tail.mesh = tail_mesh
	fish_tail.position.z = -0.42
	fish_tail.rotation.x = PI * 0.5
	fish_tail.scale.x = 0.3
	caught_fish.add_child(fish_tail)
	game._add_sphere("Eye", 0.035, Vector3(0.14, 0.045, 0.21), Color("#304e59"), false, caught_fish)
	for index in range(4):
		var ripple := _ring("SwimRipple%d" % index, 0.5, self)
		ripple.hide()
		swim_rings.append(ripple)
	cancel_fishing()

func is_fishing() -> bool:
	return state != State.IDLE

func cancel_fishing() -> void:
	state = State.IDLE
	timer = 0.0
	fish_requested = false
	can_cast = false
	scan_timer = 0.0
	for node in [rod, bobber, float_ring, line, caught_fish]:
		if is_instance_valid(node):
			node.hide()

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _find_water() -> bool:
	if game.swimming or not game.player.is_on_floor() or game.dash_remaining > 0.0 or game.player.velocity.length() > 0.35:
		return false
	# Ordinary banks and bridge decks are fishable; rooftops are not banks.
	if game.player.position.y > 1.5:
		return false
	var origin: Vector3 = game.player.position
	for angle in [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2, PI * 0.75, -PI * 0.75, PI]:
		var direction: Vector3 = game.player.global_basis.z.rotated(Vector3.UP, angle)
		var target := origin + direction * 3.6
		target.y = game.WATER_LEVEL + 0.04
		# Test actual geometry, including bridges, not an approximate island radius.
		if not _ray(Vector3(target.x, 3, target.z), target - Vector3(0, 0.03, 0)).is_empty():
			continue
		if not _ray(origin + Vector3(0, 0.8, 0), target + Vector3(0, 0.2, 0)).is_empty():
			continue
		nearby_water = target
		return true
	return false

func update(delta: float) -> void:
	clock += delta
	_limit_swimming_area()
	_update_swimming()
	if is_fishing() and (game.swimming or not game.player.is_on_floor() or game.player.velocity.length() > 0.35):
		cancel_fishing()
	if state == State.IDLE:
		scan_timer -= delta
		if scan_timer <= 0.0:
			can_cast = _find_water()
			scan_timer = 0.18
	if fish_requested:
		fish_requested = false
		match state:
			State.IDLE:
				if _find_water():
					_begin_cast()
				else:
					game._show_toast("到岸边或木桥边站稳\n按 F 抛竿，等浮漂咬钩后再按 F。")
			State.BITE:
				_catch()
			State.CASTING, State.WAITING:
				cancel_fishing()
				game._show_toast("轻轻收起鱼竿\n想钓鱼时，随时再抛一竿。")
	if state == State.IDLE:
		return
	timer -= delta
	if state == State.CASTING and timer <= 0.0:
		state = State.WAITING
		timer = rng.randf_range(2.4, 4.5)
	elif state == State.WAITING and timer <= 0.0:
		state = State.BITE
		game._play_chime(1046.5, 0.45)
	elif state == State.CAUGHT and timer <= 0.0:
		cancel_fishing()
		return
	_update_fishing_visuals()

func _begin_cast() -> void:
	game.cancel_dash()
	game.player.velocity = Vector3.ZERO
	cast_point = nearby_water
	var direction: Vector3 = cast_point - game.player.position
	game.player.rotation.y = atan2(direction.x, direction.z)
	state = State.CASTING
	timer = CAST_TIME
	rod.show()
	bobber.show()
	line.show()
	float_ring.show()
	game._play_chime(440, 0.18)

func _catch() -> void:
	var available := FishCatalog.available(game.night, game.tide_low)
	var fish: Dictionary = available[rng.randi_range(0, available.size() - 1)]
	game.fish_caught[fish.id] = mini(int(game.fish_caught.get(fish.id, 0)) + 1, 999999)
	state = State.CAUGHT
	timer = 1.6
	game._save_progress()
	game._show_toast("钓到了「%s」！\n已记入手账 · J 查看钓鱼记录" % fish.name)
	game._play_chime(1318.5, 0.7)
	fish_body.material_override = _material(fish.color)
	fish_tail.material_override = fish_body.material_override
	caught_fish.rotation.y = game.player.rotation.y + PI * 0.5
	caught_fish.show()
	bobber.hide()
	float_ring.hide()

func prompt() -> String:
	match state:
		State.CASTING: return "抛竿入海…  F 收起 · 移动取消"
		State.WAITING: return "等浮漂轻轻下沉…  F 收起 · 移动取消"
		State.BITE: return "鱼儿咬钩了！  按 F 收竿"
		State.CAUGHT: return "来自海的小礼物 · 已记入手账"
	if game.swimming and near_sea_edge:
		return "前方是远海 · 请游回岛边（Tab 地图）"
	return "F 岸边钓鱼" if can_cast else ""

func _limit_swimming_area() -> void:
	if not game.swimming:
		near_sea_edge = false
		return
	var point := Vector2(game.player.position.x, game.player.position.z)
	var allowed := Layout.clamp_to_swimming_area(point)
	var outward := point - allowed
	if outward.length_squared() > 0.0000000001:
		# Correct only horizontal travel; keep water buoyancy and tangential motion.
		game.player.position.x = allowed.x
		game.player.position.z = allowed.y
		if game.dash_remaining > 0.0:
			game.cancel_dash()
			game._update_dash_hud()
		else:
			var normal := outward.normalized()
			var velocity := Vector2(game.player.velocity.x, game.player.velocity.z)
			velocity -= normal * maxf(0.0, velocity.dot(normal))
			game.player.velocity.x = velocity.x
			game.player.velocity.z = velocity.y
	var offshore := Layout.distance_to_shore(allowed)
	# A one-metre gap between entering/leaving the warning avoids hint flicker.
	near_sea_edge = offshore > Layout.SWIM_OFFSHORE_DISTANCE - 3.0 if near_sea_edge else offshore >= Layout.SWIM_OFFSHORE_DISTANCE - 2.0

func _update_fishing_visuals() -> void:
	var tip: Vector3 = rod.to_global(ROD_TIP)
	var end := cast_point
	if state == State.CASTING:
		var t := clampf(1.0 - timer / CAST_TIME, 0, 1)
		end = tip.lerp(cast_point, t) + Vector3.UP * sin(t * PI) * 1.2
	elif state == State.CAUGHT:
		var t := clampf(1.0 - timer / 1.6, 0, 1)
		end = cast_point.lerp(game.player.position + game.player.global_basis.z * 0.9, t) + Vector3.UP * sin(t * PI) * 1.8
		caught_fish.position = end
		caught_fish.rotation.z = sin(clock * 16) * 0.22
	else:
		end.y += sin(clock * (18.0 if state == State.BITE else 3.0)) * (0.09 if state == State.BITE else 0.025)
	bobber.position = end
	bobber.rotation.z = sin(clock * 18) * 0.3 if state == State.BITE else 0.0
	float_ring.position = cast_point
	float_ring.scale = Vector3(1, 0.18, 1) * (1.4 + sin(clock * 7) * 0.4 if state == State.BITE else 1.0)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_material)
	for index in range(21):
		var t := index / 20.0
		line_mesh.surface_add_vertex(tip.lerp(end + Vector3(0, 0.22, 0), t) - Vector3.UP * sin(t * PI) * 0.16)
	line_mesh.surface_end()

func _update_swimming() -> void:
	for index in range(swim_rings.size()):
		var ripple := swim_rings[index]
		ripple.visible = game.swimming
		if not game.swimming:
			continue
		var phase := fposmod(clock * 0.85 + index * 0.25, 1.0)
		ripple.position = Vector3(game.player.position.x, game.WATER_LEVEL + 0.04, game.player.position.z) - game.player.global_basis.z * phase * 0.6
		ripple.scale = Vector3(0.75 + phase * 1.8, 0.16, 0.75 + phase * 1.8)
		(ripple.material_override as StandardMaterial3D).albedo_color.a = (1.0 - phase) * 0.55

func _ring(node_name: String, radius: float, parent: Node3D) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.018
	ring.outer_radius = radius
	ring.rings = 32
	ring.ring_segments = 6
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = ring
	node.material_override = _material(Color("#d0f8e9"), true)
	node.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _segment(node_name: String, from: Vector3, to: Vector3, radius: float, material: Material, parent: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.7
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = (from + to) * 0.5
	var direction := (to - from).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, direction)

func _material(color: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
