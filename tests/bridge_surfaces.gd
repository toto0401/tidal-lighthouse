extends SceneTree

## Run with the real renderer: the headless dummy backend cannot read MultiMesh
## transforms. Covers the overlapping bridge/terrain surfaces shown in the bug.
const Layout := preload("res://data/world_layout.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func mesh_top(mesh: MeshInstance3D) -> float:
	var bounds := mesh.mesh.get_aabb()
	return (mesh.global_transform * (bounds.position + bounds.size)).y

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Bridge surface test needs a real renderer; omit --headless.")
		quit(1)
		return
	var game = load("res://Main.tscn").instantiate()
	game.set_meta("test_mode", true)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.ui_layer.hide()
	var terrain_top := maxf(mesh_top(game.world_node("Meadow")), mesh_top(game.world_node("SandyShore")))
	for region in Layout.REGIONS:
		terrain_top = maxf(terrain_top, mesh_top(game.expanded_island.get_node("Region_" + str(region.id) + "/Meadow")))
	var snapshots := OS.get_cmdline_user_args()
	var index := 0
	for spec in Layout.BRIDGES:
		var bridge: Node3D = game.expanded_island.get_node(str(spec.name))
		var deck: StaticBody3D = bridge.get_node("ContinuousBridgeDeck")
		var shape := deck.get_child(0) as CollisionShape3D
		var floor_top := (shape.global_transform * Vector3(0, shape.shape.size.y * 0.5, 0)).y
		check(is_equal_approx(floor_top, Layout.GROUND_HEIGHT), str(spec.name) + ": collision deck stays level with island floors")
		var board_top := 0.0
		for batch_name in ["HoneyWoodPlanks", "PaleWoodPlanks"]:
			var batch: MultiMeshInstance3D = bridge.get_node(batch_name)
			var bounds := batch.multimesh.mesh.get_aabb()
			var lowest_top := INF
			var highest_top := -INF
			for i in batch.multimesh.instance_count:
				var transform := batch.global_transform * batch.multimesh.get_instance_transform(i)
				var top := (transform * (bounds.position + bounds.size)).y
				lowest_top = minf(lowest_top, top)
				highest_top = maxf(highest_top, top)
			check(lowest_top - terrain_top >= 0.015, "%s/%s: planks must clear grass AND sand, actual clearance %.6f m" % [spec.name, batch_name, lowest_top - terrain_top])
			check(highest_top - floor_top <= 0.05, str(spec.name) + ": visual deck stays within 5 cm of the walking floor")
			board_top = highest_top
		var nails: MultiMeshInstance3D = bridge.get_node("SmallBrassNails")
		var nails_clear := true
		for i in nails.multimesh.instance_count:
			var transform := nails.global_transform * nails.multimesh.get_instance_transform(i)
			var above_deck := transform.origin.y - board_top
			nails_clear = nails_clear and above_deck > 0.0 and above_deck < 0.01
		check(nails_clear, str(spec.name) + ": nail heads follow the raised planks without sinking or floating")
		if not snapshots.is_empty():
			for endpoint in [spec.from, spec.to]:
				var center := Vector3(endpoint.x, Layout.GROUND_HEIGHT, endpoint.y)
				game.player.position = center + Vector3(3.5, 0.8, 0)
				game.camera.position = center + Vector3(2, 8, 9)
				game.camera.look_at(center)
				for frame in range(5):
					await process_frame
				RenderingServer.force_draw()
				var error := root.get_texture().get_image().save_png(snapshots[0] + "-%d.png" % index)
				check(error == OK, "Bridge screenshot is written")
				index += 1
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: all three bridges clear grass and sand, every plank and nail aligns, continuous walking decks remain level")
	quit(0 if failures.is_empty() else 1)
