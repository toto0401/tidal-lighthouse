extends Node

## A short, repeatable rest at the hydrangea tea table; never changes progress.
const SIP_DURATION := 2.4
var game: Node3D
var table: Node3D
var seats: Array[Node3D] = []
var cups: Array[Node3D] = []
var seat: Node3D
var table_cup: Node3D
var held_cup: Node3D
var standing_transform := Transform3D.IDENTITY
var sip_remaining := 0.0

func _ready() -> void:
	game = get_parent()
	var picnic: Node3D = game.expanded_island.get_node("HydrangeaPicnic")
	table = picnic.get_node("TeaTray")
	for node in picnic.get_children():
		if node.has_meta("picnic_seat"):
			seats.append(node)
		elif node.has_meta("picnic_cup"):
			cups.append(node)

func is_seated() -> bool:
	return is_instance_valid(seat)

func sit(target: Node3D) -> void:
	if is_seated() or game.menu_is_open() or game.current_location != "island" or game.swimming or not game.player.is_on_floor():
		return
	if not is_instance_valid(target) or not target.is_visible_in_tree() or game.player.global_position.distance_to(target.global_position) >= 2.6:
		return
	if target != table and target not in seats:
		return
	var nearest: Node3D = target if target in seats else seats[0]
	if target == table:
		for candidate in seats:
			if game.player.global_position.distance_squared_to(candidate.global_position) < game.player.global_position.distance_squared_to(nearest.global_position):
				nearest = candidate
	standing_transform = game.player.global_transform
	seat = nearest
	game.cancel_dash()
	game.dash_effects.clear_trail()
	game.jump_requested = false
	game.water_activities.cancel_fishing()
	game.player.velocity = Vector3.ZERO
	# Cushion top is 0.18 above its origin; the coat hem rests on its surface.
	game.player.global_position = seat.global_position + Vector3(0, 0.49, 0)
	var facing: Vector3 = table.global_position - seat.global_position
	game.player.rotation.y = atan2(facing.x, facing.z)
	table_cup = cups[0]
	for cup in cups:
		if cup.global_position.distance_squared_to(seat.global_position) < table_cup.global_position.distance_squared_to(seat.global_position):
			table_cup = cup
	held_cup = table_cup.duplicate() as Node3D
	held_cup.name = "PicnicHeldCup"
	game.player.add_child(held_cup)
	held_cup.hide()
	game._add_cylinder("Tea", 0.07, 0.008, Vector3(0, 0.058, 0), Color("#a8784b"), false, held_cup)
	game.keeper_appearance.animate_seated(0.0)
	game._show_toast("在绣球花旁坐一会儿\nF 喝茶 · E / WASD 起身")
	game._update_interaction()

func handle_input(event: InputEvent) -> bool:
	if not is_seated():
		return false
	for action in ["interact", "fish", "jump", "wave_dash", "glide", "move_left", "move_right", "move_forward", "move_back"]:
		if event.is_action_pressed(action, true):
			if not event.is_echo():
				if action == "fish":
					sip()
				else:
					leave()
			return true
	return false

func sip() -> void:
	if not is_seated() or game.menu_is_open() or sip_remaining > 0.0:
		return
	sip_remaining = SIP_DURATION
	table_cup.hide()
	held_cup.show()
	game._play_chime(523.25, 0.18)
	game._show_toast("一口温热的海盐茶\n海风和花香，正好。")

func update(delta: float) -> bool:
	if not is_seated():
		return false
	if game.current_location != "island" or not seat.is_visible_in_tree():
		leave(false)
		return false
	game.player.velocity = Vector3.ZERO
	game.jump_requested = false
	game.dash_requested = false
	game.dash_cooldown = maxf(0.0, game.dash_cooldown - delta)
	game._update_dash_hud()
	sip_remaining = maxf(0.0, sip_remaining - delta)
	var phase := 1.0 - sip_remaining / SIP_DURATION
	var lift := smoothstep(0.0, 0.3, phase) * (1.0 - smoothstep(0.65, 1.0, phase)) if sip_remaining > 0.0 else 0.0
	game.keeper_appearance.animate_seated(lift)
	if sip_remaining > 0.0:
		var hand: Node3D = game.keeper_appearance.arms[1]
		held_cup.global_position = hand.to_global(Vector3(0, -0.45, 0.008)) + game.player.global_basis * Vector3(-0.02, 0.06, 0.08)
		held_cup.rotation = Vector3(-0.3 * lift, 0, 0)
	else:
		cancel_sip()
	return true

func cancel_sip() -> void:
	sip_remaining = 0.0
	if is_instance_valid(table_cup):
		table_cup.show()
	if is_instance_valid(held_cup):
		held_cup.hide()
	if is_seated():
		game.keeper_appearance.animate_seated(0.0)

func leave(restore_position := true) -> void:
	if not is_seated():
		return
	cancel_sip()
	seat = null
	table_cup = null
	if is_instance_valid(held_cup):
		held_cup.queue_free()
	held_cup = null
	if restore_position:
		game.player.global_transform = standing_transform
	game.player.velocity = Vector3.ZERO
	game.jump_requested = false
	game.cancel_dash()
	game.water_activities.cancel_fishing()
	game.keeper_appearance.animate(1.0, 0.0, true, false)
	game._update_interaction()

func prompt() -> String:
	return ("慢慢喝茶中…" if sip_remaining > 0.0 else "F 喝一口茶") + "  ·  E / WASD 起身"
