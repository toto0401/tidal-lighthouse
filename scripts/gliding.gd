extends Node

## An unpowered sail: steering changes heading, never adds height.
const SPEED := 6.2
const SINK_SPEED := 1.25
const MIN_CLEARANCE := 2.0
const Layout := preload("res://data/world_layout.gd")
var game: Node3D
var active := false
var requested := false
var heading := Vector3.FORWARD
var visual: Node3D
var opening := 0.0
var bank := 0.0
var at_boundary := false

func _ready() -> void:
	game = get_parent()
	_build_sail()

func clearance() -> float:
	var origin: Vector3 = game.player.position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 200)
	query.exclude = [game.player.get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	var surface: float = game.WATER_LEVEL if hit.is_empty() else maxf(hit.position.y, game.WATER_LEVEL)
	return maxf(0.0, origin.y - 0.8 - surface)

func can_deploy() -> bool:
	return game.current_location == "island" and not game.swimming and not game.player.is_on_floor() and clearance() >= MIN_CLEARANCE

func deploy() -> bool:
	if not can_deploy():
		return false
	game.cancel_dash()
	game.dash_effects.clear_trail()
	game.water_activities.cancel_fishing()
	game.jump_requested = false
	heading = game.player.global_basis.z
	heading.y = 0
	heading = heading.normalized()
	active = true
	opening = 0.0
	bank = 0.0
	at_boundary = false
	visual.scale = Vector3.ONE * 0.04
	visual.show()
	# Reopening a sail may slow a fall, but can never act as another jump.
	game.player.velocity.y = minf(game.player.velocity.y, -0.7)
	game._play_chime(659.25, 0.2)
	return true

func cancel() -> void:
	requested = false
	if active:
		var motion := Vector2(game.player.velocity.x, game.player.velocity.z).limit_length(2.8)
		game.player.velocity.x = motion.x
		game.player.velocity.z = motion.y
	active = false
	at_boundary = false
	if visual:
		visual.hide()

func prepare(delta: float, direction: Vector3) -> void:
	if active and (game.current_location != "island" or game.swimming or game.player.is_on_floor()):
		cancel()
	if requested:
		requested = false
		if active:
			cancel()
		elif not deploy():
			game._show_toast("到高处迎风起跳\n离地至少 2 米时按 G，或到塔顶起飞点按 E。")
	if not active:
		return
	if game.jump_requested:
		game.jump_requested = false
		cancel()
		return
	game.dash_requested = false
	var turn := 0.0
	if direction.length_squared() > 0.01:
		turn = heading.signed_angle_to(direction.normalized(), Vector3.UP)
		heading = heading.rotated(Vector3.UP, clampf(turn, -2.2 * delta, 2.2 * delta))
	bank = lerpf(bank, clampf(turn * 0.28, -0.28, 0.28), 1.0 - exp(-6.0 * delta))
	opening = minf(1.0, opening + delta * 4.0)
	visual.scale = Vector3.ONE * lerpf(0.04, 1.0, smoothstep(0, 1, opening))
	visual.rotation.z = bank
	visual.rotation.x = sin(game.elapsed_time * 2.0) * 0.025

func apply_velocity(delta: float) -> void:
	game.player.velocity.x = heading.x * SPEED
	game.player.velocity.z = heading.z * SPEED
	game.player.velocity.y = move_toward(game.player.velocity.y, -SINK_SPEED, 18.0 * delta)

func after_move() -> void:
	if not active:
		return
	var at := Vector2(game.player.position.x, game.player.position.z)
	var limited := Layout.clamp_to_swimming_area(at)
	at_boundary = at.distance_squared_to(limited) > 0.0001
	if at_boundary:
		game.player.position.x = limited.x
		game.player.position.z = limited.y
		var inward := (limited - at).normalized()
		heading = Vector3(inward.x, 0, inward.y)
	if game.player.is_on_floor() or game.player.is_on_wall() or game.player.is_on_ceiling() or game.player.position.y <= game.SWIM_HEIGHT + 0.12:
		cancel()

func _build_sail() -> void:
	visual = Node3D.new()
	visual.name = "SeaGlider"
	game.player.add_child(visual)
	var colors := [Color("#f3dfb4"), Color("#79b9ae"), Color("#f3dfb4"), Color("#e3a18a"), Color("#f3dfb4"), Color("#79b9ae")]
	# Six curved cloth panels form a broad, lightly scalloped sea-colored wing.
	for panel in range(6):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in range(8):
			var a := -1.0 + (panel + step / 8.0) / 3.0
			var b := -1.0 + (panel + (step + 1) / 8.0) / 3.0
			for uv in [Vector2(a,0),Vector2(a,1),Vector2(b,0),Vector2(b,0),Vector2(a,1),Vector2(b,1)]:
				surface.add_vertex(_sail_point(uv.x, uv.y))
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = "SailPanel"
		mesh.mesh = surface.commit()
		mesh.material_override = game._material(colors[panel])
		mesh.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		visual.add_child(mesh)
	for side in [-1.0,1.0]:
		_rod(Vector3(side*0.64,0.78,0.28),_sail_point(side*0.65,0.0),0.015)
		_rod(Vector3(side*0.64,0.78,0.28),_sail_point(side*0.85,1.0),0.015)
	_rod(Vector3(-0.65,0.78,0.28),Vector3(0.65,0.78,0.28),0.025)
	for panel in range(7):
		var x := -1.0 + panel / 3.0
		_rod(_sail_point(x,0),_sail_point(x,1),0.022)
	visual.hide()

func _sail_point(x: float, rear: float) -> Vector3:
	return Vector3(x*2.25, 2.05 - x*x*0.5 - rear*0.13, 0.8 - absf(x)*0.22 - rear*(1.9 - absf(x)*0.5))

func _rod(a: Vector3, b: Vector3, radius: float) -> void:
	var rod: MeshInstance3D = game._add_cylinder("SailRigging",radius,a.distance_to(b),(a+b)*0.5,Color("#536f71"),false,visual)
	rod.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
