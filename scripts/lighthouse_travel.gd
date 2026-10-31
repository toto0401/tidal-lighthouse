extends Node

## The player, music and progress stay alive while separate location scenes change.
const ROOM := preload("res://scenes/LighthouseRoom.tscn")
const TOP := preload("res://scenes/LighthouseTop.tscn")
const Layout := preload("res://data/lighthouse_layout.gd")
const DOOR_RETURN := Layout.DOOR_RETURN
const GALLERY_HEIGHT := Layout.GALLERY_HEIGHT
const TOP_CAMERA_DISTANCE := 23.0
const LINKS := {"island": ["room"], "room": ["island", "top"], "top": ["room"]}
var game: Node3D
var island_scene: Node3D
var active_scene: Node3D
var transitioning := false
var cover: ColorRect
var fade: Tween
var collision_objects: Array[CollisionObject3D] = []
var outside_camera := Vector3(0, 0.65, 20.5)
var request_serial := 0

func _ready() -> void:
	game = get_parent()
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	cover = ColorRect.new()
	cover.color = Color("#243d48")
	cover.modulate.a = 0.0
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.hide()

func capture_island() -> void:
	island_scene = Node3D.new()
	island_scene.name = "IslandScene"
	var nodes := game.get_children()
	game.add_child(island_scene)
	for node in nodes:
		if node is Node3D and node not in [game.player, game.camera, game.dash_effects, game.water_activities] and node.name != "WatercolorSun":
			node.reparent(island_scene)
	for node in island_scene.find_children("*", "CollisionObject3D", true, false):
		node.set_meta("island_layer", node.collision_layer)
		node.set_meta("island_mask", node.collision_mask)
		collision_objects.append(node)

func request(destination: String, glide_departure := false) -> void:
	if transitioning:
		return
	var launch_position := Vector3.ZERO
	if glide_departure:
		var launch: Node3D = game.world_node("GlideLaunch")
		if game.current_location != "top" or destination != "island" or not is_instance_valid(launch) or not game.player.is_on_floor() or game.player.global_position.distance_to(launch.global_position) >= 2.6:
			return
		# Clear the widened tower wall before opening the sail.
		launch_position = active_scene.to_global(Vector3(Layout.RADIUS + 0.9, launch.position.y + 0.8, launch.position.z))
	elif destination not in LINKS.get(game.current_location, []):
		return
	request_serial += 1
	var serial := request_serial
	transitioning = true
	_reset_motion()
	cover.show()
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	fade = create_tween()
	fade.tween_property(cover, "modulate:a", 1.0, 0.18)
	await fade.finished
	if serial != request_serial:
		return
	switch_now(destination)
	# Let new collision bodies enter the physics world before returning control.
	await get_tree().physics_frame
	if serial != request_serial:
		return
	if glide_departure:
		# Take off from the same world position seen while standing on the gallery.
		game.player.global_position = launch_position
		game.player.rotation.y = PI / 2.0
		game.player.velocity = Vector3(0,-0.7,0)
		game.player.move_and_slide()
		game.gliding.deploy()
		game.camera_yaw = -PI / 2.0
		game.camera_pitch = 0.42
		game.camera_distance = 13.5
		game._update_camera(0.0)
		game._show_toast("迎着海风出发\nWASD 转向 · G / 空格收翼 · 落地自动收起")
	fade = create_tween()
	fade.tween_property(cover, "modulate:a", 0.0, 0.2)
	await fade.finished
	if serial != request_serial:
		return
	transitioning = false
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.hide()
	game._update_interaction()

func _reset_motion() -> void:
	game.gliding.cancel()
	game.picnic_rest.leave(false)
	game.cancel_dash()
	game.dash_effects.clear_trail()
	game.water_activities.cancel_fishing()
	game.activities.cancel_session()
	game.swimming = false
	game.jump_requested = false
	game.camera_dragging = false
	game.player.velocity = Vector3.ZERO
	game.interact_target = null
	game.prompt_label.text = ""

func switch_now(destination: String) -> void:
	if destination not in LINKS:
		return
	var previous: String = game.current_location
	if previous == "island" and destination != "island":
		outside_camera = Vector3(game.camera_yaw, game.camera_pitch, game.camera_distance)
	_reset_motion()
	game.room_objects.clear()
	game.display_objects.clear()
	game.restoration_mesh = null
	if is_instance_valid(active_scene):
		game.remove_child(active_scene)
		active_scene.queue_free()
		active_scene = null
	game.current_location = destination
	var outside := destination == "island"
	var sees_island := destination != "room"
	island_scene.visible = sees_island
	island_scene.process_mode = Node.PROCESS_MODE_INHERIT if sees_island else Node.PROCESS_MODE_DISABLED
	for body in collision_objects:
		body.collision_layer = body.get_meta("island_layer") if sees_island else 0
		body.collision_mask = body.get_meta("island_mask") if sees_island else 0
	game.world_node("LighthouseLabel").visible = destination != "top"
	# Swap matching exterior and walkable roof visuals without overlaps.
	game.world_node("Lighthouse").get_node("ExteriorGallery").visible = destination != "top"
	if outside:
		game.player.position = DOOR_RETURN
		game.player.rotation.y = PI
		game.camera_yaw = outside_camera.x
		game.camera_pitch = outside_camera.y
		game.camera_distance = outside_camera.z
		game._show_toast("走出灯塔\n海风又回到身边。")
	else:
		active_scene = (ROOM if destination == "room" else TOP).instantiate()
		active_scene.game = game
		if destination == "top":
			active_scene.position = game.world_node("Lighthouse").position + Vector3(0, GALLERY_HEIGHT, 0)
		game.add_child(active_scene)
		var spawn := Vector3(3.4, 1.1, -0.8) if destination == "room" and previous == "top" else Vector3(0, 1.1, 2.3)
		game.player.global_position = active_scene.to_global(spawn)
		game.player.rotation.y = PI
		game.camera_yaw = 0
		game.camera_pitch = 0.88 if destination == "room" else 0.76
		game.camera_distance = 14.5 if destination == "room" else TOP_CAMERA_DISTANCE
		game._set_decoration(game.decoration_style, true)
		game.set_room_layout(game.room_layout, true)
		game._show_toast("灯塔一层 · 你的小屋\nB 布置小屋，右后方楼梯通往塔顶。" if destination == "room" else "灯塔顶层 · 海岛全景\n拖动镜头、滚轮拉远看海岛；E 灯芯 / 下楼 / 起飞。")
	game.last_ground_position = game.player.position
	game.camera_focus = game.player.position + Vector3(0, 0.6, 0)
	game._update_camera(0.0)
	game._apply_lighthouse()
	game.island_life.apply_night(false)
	game._update_region()
	game._update_objective()
	game._update_dash_hud()

func return_to_island() -> void:
	request_serial += 1
	if fade:
		fade.kill()
	transitioning = false
	cover.hide()
	cover.modulate.a = 0.0
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if game.current_location != "island":
		switch_now("island")

func reset_camera() -> void:
	game.camera_yaw = 0
	game.camera_pitch = 0.88 if game.current_location == "room" else 0.76 if game.current_location == "top" else 0.65
	game.camera_distance = 14.5 if game.current_location == "room" else TOP_CAMERA_DISTANCE if game.current_location == "top" else 20.5
