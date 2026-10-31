extends RefCounted

## Scene-aware setup for regression tests; the full journey test walks these routes.
static func travel(game: Node3D, destination: String) -> void:
	for attempt in range(3):
		if game.current_location == destination:
			return
		var name := "TowerDoor" if game.current_location == "island" else "TopStairs" if game.current_location == "top" else "TowerStairs" if destination == "top" else "RoomExit"
		var portal: Node3D = game.world_node(name)
		game.player.position = portal.global_position + Vector3(0,0.9,-0.8 if name in ["TowerDoor", "RoomExit", "TopStairs"] else 0.8)
		game.player.velocity = Vector3.ZERO
		game._update_interaction()
		assert(game.interact_target == portal, "Expected portal: " + name)
		game._interact()
		for frame in range(90):
			await game.get_tree().process_frame
			if not game.locations.transitioning:
				break
	assert(game.current_location == destination, "Scene transition did not finish")
