extends Node3D

## Small neighbours with bounded, collision-free habitats and brief greetings.
const Models := preload("res://scripts/animal_models.gd")
const HABITATS := [
	{"id": "milk", "kind": "rabbit", "name": "奶糖", "home": Vector3(4.5, 0.12, 5.2), "radius": 1.4},
	{"id": "cloud", "kind": "rabbit", "name": "云朵", "home": Vector3(35, 0.12, -2.5), "radius": 2.2},
	{"id": "peach", "kind": "rabbit", "name": "桃酥", "home": Vector3(38.5, 0.12, 5.4), "radius": 0.55},
	{"id": "coral", "kind": "crab", "name": "桃桃", "home": Vector3(-35, 0.12, -3.5), "radius": 0.8},
	{"id": "claw", "kind": "crab", "name": "小夹子", "home": Vector3(-32, 0.12, -13), "radius": 1.5},
	{"id": "sail", "kind": "gull", "name": "小帆", "home": Vector3(-1, 0.12, 12), "radius": 1.3},
	{"id": "white", "kind": "gull", "name": "阿白", "home": Vector3(5, 0.12, -32), "radius": 1.8},
	{"id": "salt", "kind": "gull", "name": "海盐", "home": Vector3(-34, 0.12, 1.5), "radius": 1.6}
]
var game: Node3D
var critters: Array[Dictionary] = []
var animals: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var age := 0.0

func _ready() -> void:
	game = get_parent()
	rng.seed = 20261010
	for index in HABITATS.size():
		var spec: Dictionary = HABITATS[index]
		var animal := Node3D.new()
		animal.name = "Animal_" + str(spec.id)
		animal.position = spec.home
		animal.rotation.y = rng.randf_range(-PI, PI)
		animal.add_to_group("interactable")
		animal.add_to_group("island_animals")
		animal.set_meta("animal_kind", spec.kind)
		animal.set_meta("animal_name", spec.name)
		animal.set_meta("animal_index", index)
		add_child(animal)
		var model: Node3D = Models.build(str(spec.kind), animal)
		model.name = "Model"
		var label: Label3D = game._add_label_3d(str(spec.name), Vector3(0, 1.35, 0), Color("#fff0d6"), 0.53, animal)
		label.name = "NameLabel"
		label.hide()
		var heart: Label3D = game._add_label_3d("♥", Vector3(0, 1.35, 0), Color("#f5a9bc"), 0.95, animal)
		heart.name = "GreetingHeart"
		heart.hide()
		animals.append(animal)
		critters.append({"node": animal, "model": model, "home": spec.home, "radius": spec.radius,
			"kind": spec.kind, "mode": "idle", "timer": 0.5 + index * 0.35,
			"target": spec.home, "phase": index * 0.73, "heart_left": 0.0,
			"greet_cooldown": 0.0, "flight_start": spec.home, "flight_time": 0.0})

func can_interact(animal: Node3D) -> bool:
	if not is_instance_valid(animal) or not animal in animals or not animal.is_visible_in_tree():
		return false
	var entry: Dictionary = critters[int(animal.get_meta("animal_index"))]
	return game.current_location == "island" and entry.mode != "fly" and entry.greet_cooldown <= 0.0

func interact(animal: Node3D) -> void:
	if game.menu_is_open() or not can_interact(animal) or game.player.global_position.distance_to(animal.global_position) >= 2.6:
		return
	var entry: Dictionary = critters[int(animal.get_meta("animal_index"))]
	entry.heart_left = 2.1
	entry.greet_cooldown = 2.5
	entry.timer = 3.0
	entry.mode = "greet"
	animal.get_node("NameLabel").hide()
	var animal_name: String = animal.get_meta("animal_name")
	match str(entry.kind):
		"rabbit": game._show_toast("%s蹭了蹭你的手\n长耳朵轻轻晃了晃。" % animal_name)
		"crab": game._show_toast("%s举起小钳子\n它侧着身子，认真地和你打招呼。" % animal_name)
		"gull": game._show_toast("%s拍了拍翅膀\n像在邀请你一起听海。" % animal_name)
	game._play_chime(659.25 if entry.kind == "rabbit" else 523.25 if entry.kind == "crab" else 783.99, 0.28)
	_look_toward(animal, game.player.global_position - animal.global_position, 1.0)
	_animate(entry, 0.0, 0.0)

func _physics_process(delta: float) -> void:
	if game.menu_is_open() or game.current_location == "room" or not is_visible_in_tree():
		return
	age += delta
	for entry in critters:
		_step(entry, delta)

func _step(entry: Dictionary, delta: float) -> void:
	var animal: Node3D = entry.node
	var kind: String = entry.kind
	var distance := animal.global_position.distance_to(game.player.global_position)
	entry.greet_cooldown = maxf(0.0, float(entry.greet_cooldown) - delta)
	entry.heart_left = maxf(0.0, float(entry.heart_left) - delta)
	var label := animal.get_node("NameLabel") as Label3D
	label.visible = distance < 4.5 and entry.mode != "fly" and entry.heart_left <= 0.0
	entry.timer = float(entry.timer) - delta
	var moving := 0.0
	if entry.mode == "fly":
		_update_flight(entry, delta)
	elif entry.mode == "greet":
		_look_toward(animal, game.player.global_position - animal.global_position, delta * 3.0)
		if entry.timer <= 0.0:
			entry.mode = "idle"
			entry.timer = rng.randf_range(1.5, 3.0)
	elif game.night and kind != "crab":
		entry.mode = "sleep"
		entry.timer = 1.0
	elif game.dash_remaining > 0.0 and distance < 3.2 and entry.mode != "scamper":
		if kind == "gull":
			_begin_flight(entry)
		else:
			var away: Vector3 = animal.global_position - game.player.global_position
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.RIGHT
			entry.target = _bounded(entry, animal.position + away.normalized() * 1.6)
			entry.mode = "scamper"
			entry.timer = 1.0
	elif entry.mode == "roam" or entry.mode == "scamper":
		var direction: Vector3 = entry.target - animal.position
		direction.y = 0.0
		var speed := (1.7 if entry.mode == "scamper" else 0.55) if kind == "rabbit" else 0.7 if kind == "crab" else 0.4
		var next := animal.position.move_toward(entry.target, speed * delta)
		if direction.length() < 0.07 or entry.timer <= 0.0 or not _clear_path(animal.position, next):
			entry.mode = "idle"
			entry.timer = rng.randf_range(1.2, 3.5)
		else:
			animal.position = next
			moving = 1.0
			_look_toward(animal, direction.rotated(Vector3.UP, PI * 0.5) if kind == "crab" else direction, delta * 5.0)
	else:
		if entry.mode == "sleep":
			entry.mode = "idle"
			entry.timer = 0.5
		if distance < 3.0 and not game.swimming:
			# A nearby observer gets a glance, not an indefinite pause. Only E
			# enters the timed greeting state; ordinary routines keep advancing.
			_look_toward(animal, game.player.global_position - animal.global_position, delta * 2.5)
		if entry.timer <= 0.0:
			if kind == "gull" and rng.randf() < 0.35 and not game.night:
				_begin_flight(entry)
			else:
				var angle := rng.randf_range(-PI, PI)
				var home: Vector3 = entry.home
				entry.target = _bounded(entry, home + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.35, float(entry.radius)))
				entry.mode = "roam"
				entry.timer = 5.0
	_animate(entry, delta, moving)

func _bounded(entry: Dictionary, point: Vector3) -> Vector3:
	var home: Vector3 = entry.home
	var offset := Vector2(point.x - home.x, point.z - home.z).limit_length(float(entry.radius))
	return Vector3(home.x + offset.x, home.y, home.z + offset.y)

func _clear_path(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.35, 0), to + Vector3(0, 0.35, 0))
	query.exclude = [game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _look_toward(animal: Node3D, direction: Vector3, weight: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		animal.rotation.y = lerp_angle(animal.rotation.y, atan2(direction.x, direction.z), clampf(weight, 0, 1))

func _begin_flight(entry: Dictionary) -> void:
	entry.mode = "fly"
	entry.flight_start = entry.node.position
	entry.flight_time = 0.0

func _update_flight(entry: Dictionary, delta: float) -> void:
	entry.flight_time = minf(float(entry.flight_time) + delta, 6.0)
	var t := float(entry.flight_time) / 6.0
	var start: Vector3 = entry.flight_start
	var home: Vector3 = entry.home
	var previous: Vector3 = entry.node.position
	# A closed coastal arc always lands back inside the bird's habitat.
	entry.node.position = start.lerp(home, t) + Vector3(sin(t * TAU) * 2.5, sin(t * PI) * 3.4, (1.0 - cos(t * TAU)) * 1.5)
	_look_toward(entry.node, entry.node.position - previous, delta * 7.0)
	if t >= 1.0:
		entry.node.position = home
		entry.mode = "idle"
		entry.timer = rng.randf_range(4.0, 7.0)

func _animate(entry: Dictionary, delta: float, moving: float) -> void:
	entry.phase = float(entry.phase) + delta * (12.0 if moving > 0 else 3.0)
	var model: Node3D = entry.model
	var phase: float = entry.phase
	var greeting: bool = entry.mode == "greet"
	var sleeping: bool = entry.mode == "sleep"
	model.position.y = absf(sin(phase)) * 0.18 * moving if entry.kind == "rabbit" else sin(phase) * 0.02 * moving
	model.scale.y = (0.82 if sleeping else 1.0) + sin(age * 1.6 + phase) * (0.015 if moving == 0.0 else 0.0)
	model.rotation.x = -0.1 * moving if entry.kind == "rabbit" else 0.0
	var head := model.get_node_or_null("Head") as Node3D
	if head:
		var idle_weight := 1.0 - moving if not greeting and not sleeping and entry.mode != "fly" else 0.0
		head.rotation.y = sin(phase * 0.45) * 0.2 * idle_weight
		# Rabbits sniff, gulls occasionally peck, and crabs look around.
		head.rotation.x = (0.08 + sin(phase) * 0.07) * idle_weight if entry.kind == "rabbit" else pow(maxf(0.0, sin(phase * 0.5)), 8.0) * 0.3 * idle_weight if entry.kind == "gull" else 0.0
	for part in ["LeftEar", "RightEar"]:
		var ear := model.get_node_or_null(part) as Node3D
		if ear:
			ear.rotation.x = 0.55 if sleeping else ear.get_meta("rest_rotation").x + sin(phase + (0.7 if part == "LeftEar" else 0.0)) * (0.25 if greeting else 0.055)
	for part in ["LeftWing", "RightWing"]:
		var wing := model.get_node_or_null(part) as Node3D
		if wing:
			var side := -1.0 if part == "LeftWing" else 1.0
			wing.rotation.z = wing.get_meta("rest_rotation").z + (side * (sin(age * 13.0) * 0.65 + 0.3) if entry.mode == "fly" else side * (sin(phase * 2.5) * 0.45 + 0.25) if greeting else side * sin(phase * 0.7) * 0.045 if not sleeping else 0.0)
	for part in ["LeftClaw", "RightClaw"]:
		var claw := model.get_node_or_null(part) as Node3D
		if claw:
			claw.rotation.x = -0.55 + sin(phase * 2.0) * 0.3 if greeting else sin(phase * (1.0 if moving > 0.0 else 0.45) + (0.9 if part == "LeftClaw" else 0.0)) * (0.12 if moving > 0.0 else 0.09)
	var heart := entry.node.get_node("GreetingHeart") as Label3D
	heart.visible = entry.heart_left > 0.0
	heart.position.y = 1.3 + (2.1 - float(entry.heart_left)) * 0.3
	heart.modulate.a = minf(1.0, float(entry.heart_left) * 2.0)
