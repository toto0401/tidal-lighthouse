extends Node3D

const SEAL_HOME := Vector3(6.4, 0.25, -7.6)
var game: Node3D
var garden: Node3D
var seal: Node3D
var garden_marker: MeshInstance3D
var cove_marker: MeshInstance3D
var soundscape: AudioStreamPlayer
var night_tween: Tween
var age := 0.0
var seal_target := SEAL_HOME
var seal_wandering := false
var seal_rest_left := 1.4
var seal_greeting_left := 0.0
var seal_rng := RandomNumberGenerator.new()
var seal_flippers: Array[Node3D] = []

func _ready() -> void:
	game = get_parent()
	seal_rng.seed = 85133
	_build_restorations()
	_build_seal()
	_build_soundscape()
	apply_state()

func _build_restorations() -> void:
	garden_marker = game._add_cylinder("GardenRestore", 0.8, 0.1, Vector3(8.0, 0.25, 2.0), Color("#c7b991"), false)
	garden_marker.add_to_group("interactable")
	garden_marker.set_meta("zone", "garden")
	game._add_torus("GardenRing", 1.1, 0.07, Vector3(8, 0.34, 2), Color("#e4d4a8"))
	game._add_label_3d("风铃花园", Vector3(8, 1.8, 2), Color("#ede3bf"), 0.9)
	cove_marker = game._add_cylinder("CoveRestore", 0.8, 0.1, Vector3(2.5, 0.25, -8.0), Color("#8caeaf"), false)
	cove_marker.add_to_group("interactable")
	cove_marker.set_meta("zone", "cove")
	game._add_torus("CoveRing", 1.1, 0.07, Vector3(2.5, 0.34, -8), Color("#badbcf"))
	game._add_label_3d("星砂海湾", Vector3(2.5, 1.8, -8), Color("#d5eeee"), 0.9)
	garden = Node3D.new()
	garden.name = "RestoredGarden"
	add_child(garden)
	for x in [8.9, 11.4]:
		game._add_box("Planter", Vector3(1.5, 0.3, 2.2), Vector3(x, 0.3, 1.1), Color("#b7957c"), false, self)
		game._add_box("Soil", Vector3(1.35, 0.06, 2.0), Vector3(x, 0.47, 1.1), Color("#716d61"), false, self)
	for i in range(22):
		var x := 8.55 + (i % 4) * 0.32 + (2.5 if i > 10 else 0.0)
		var z := 0.35 + (i % 6) * 0.31
		game._add_cylinder("GardenStem", 0.028, 0.65, Vector3(x, 0.75, z), Color("#6b9e88"), false, garden)
		var color := Color("#deb2c5") if i % 3 == 0 else Color("#e5cf9a") if i % 3 == 1 else Color("#b3b8da")
		var bloom: MeshInstance3D = game._add_sphere("Bellflower", 0.16, Vector3(x, 1.1, z), color, false, garden)
		bloom.scale.y = 1.3
	for x in [8.5, 11.8]:
		game._add_cylinder("GardenArch", 0.09, 3.2, Vector3(x, 1.7, -0.3), Color("#ddcdb2"), false, self)
	game._add_box("ArchLintel", Vector3(3.6, 0.15, 0.18), Vector3(10.15, 3.25, -0.3), Color("#ddcdb2"), false, self)
	for i in range(5):
		var bell: MeshInstance3D = game._add_sphere("WindBell", 0.12, Vector3(8.9 + i * 0.6, 2.9 - sin(i) * 0.18, -0.3), Color("#c7e1ce"), false, garden)
		bell.scale.y = 1.45

func _build_seal() -> void:
	seal = Node3D.new()
	seal.name = "ReturningSeal"
	seal.position = SEAL_HOME
	seal.add_to_group("interactable")
	seal.set_meta("seal", true)
	add_child(seal)
	var body: MeshInstance3D = game._add_sphere("SealBody", 0.65, Vector3(0, 0.35, 0), Color("#bdccd0"), false, seal)
	body.scale = Vector3(0.8, 0.65, 1.35)
	game._add_sphere("SealHead", 0.39, Vector3(0, 0.65, 0.61), Color("#d9e3df"), false, seal)
	for side in [-1.0, 1.0]:
		var fin: MeshInstance3D = game._add_sphere("Flipper", 0.2, Vector3(side * 0.47, 0.16, 0.1), Color("#a2b8c2"), false, seal)
		fin.scale = Vector3(1.7, 0.28, 0.6)
		seal_flippers.append(fin)
		game._add_sphere("SealEye", 0.043, Vector3(side * 0.15, 0.74, 0.944), Color("#354b59"), false, seal)
	game._add_sphere("SealNose", 0.058, Vector3(0, 0.64, 1.0), Color("#687e88"), false, seal)
	game._add_label_3d("小海豹 · 雾团", Vector3(0, 1.48, 0), Color("#f6ead9"), 0.75, seal)

func apply_state(animate := false) -> void:
	if not garden:
		return
	garden.visible = game.garden_repaired
	seal.visible = game.cove_repaired
	if not seal.visible:
		seal.position = SEAL_HOME
		seal_target = SEAL_HOME
		seal_wandering = false
		seal_rest_left = 1.4
		seal_greeting_left = 0.0
	garden_marker.material_override = game._material(Color("#98c8a1") if game.garden_repaired else Color("#c7b991"))
	cove_marker.material_override = game._material(Color("#94daca") if game.cove_repaired else Color("#8caeaf"))
	if animate and garden.visible:
		garden.scale.y = 0.05
		create_tween().tween_property(garden, "scale:y", 1.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for node in (game.locations.island_scene.get_children() if is_instance_valid(game.locations) else game.get_children()):
		if node is MeshInstance3D and str(node.name).begins_with("JettyPlank"):
			node.material_override = game._material(Color("#c9b197") if game.cove_repaired else Color("#8a8b80"))
	apply_night(animate)
	if soundscape:
		soundscape.stream_paused = not game.audio_enabled

func apply_night(animate := true, transition_seconds := 1.8) -> void:
	var env: Environment = game.get_node("IslandEnvironment").environment
	var sun: DirectionalLight3D = game.get_node("WatercolorSun")
	if night_tween:
		night_tween.kill()
	night_tween = game.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var indoors: bool = game.current_location == "room"
	env.background_mode = Environment.BG_COLOR if indoors else Environment.BG_SKY
	env.fog_enabled = not indoors
	if soundscape:
		soundscape.volume_db = -29.0 if indoors else -20.0
	var duration := transition_seconds if animate else 0.01
	night_tween.tween_property(env, "background_color", Color("#344f58") if indoors else Color("#526078") if game.night else Color("#a5c6c8"), duration)
	night_tween.tween_property(env, "ambient_light_color", Color("#e4cfaf") if indoors else Color("#9daed8") if game.night else Color("#bfd8d5"), duration)
	night_tween.tween_property(env, "ambient_light_energy", 0.7 if indoors else 0.5 if game.night else 0.46, duration)
	night_tween.tween_property(env, "fog_light_color", Color("#667694") if game.night else Color("#abc7c8"), duration)
	night_tween.tween_property(sun, "light_energy", 0.45 if indoors else 0.25 if game.night else 0.95, duration)
	night_tween.tween_property(sun, "light_color", Color("#a9c1e4") if game.night else Color("#ffe4bf"), duration)
	night_tween.tween_property(game.water_shader, "shader_parameter/night_amount", 1.0 if game.night else 0.0, duration)
	if env.sky and env.sky.sky_material is ShaderMaterial:
		night_tween.tween_property(env.sky.sky_material, "shader_parameter/night_amount", 1.0 if game.night else 0.0, duration)

func _build_soundscape() -> void:
	if game.get_meta("test_mode", false) or DisplayServer.get_name() == "headless":
		return
	var rate := 11025
	var length := rate * 12
	var pcm := PackedByteArray()
	pcm.resize(length * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 85132
	var wash := 0.0
	for i in length:
		var t := float(i) / rate
		wash = lerpf(wash, rng.randf_range(-1.0, 1.0), 0.09)
		var wave := 0.55 + sin(TAU * t / 6.0) * 0.28
		var pad := sin(TAU * 196.0 * t) * 0.04 + sin(TAU * 293.0 * t) * 0.022
		var envelope := minf(t * 2.0, 1.0) * minf((12.0 - t) * 2.0, 1.0)
		pcm.encode_s16(i * 2, int((wash * wave + pad) * envelope * 19000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = length
	stream.data = pcm
	soundscape = AudioStreamPlayer.new()
	soundscape.stream = stream
	soundscape.volume_db = -20.0
	add_child(soundscape)
	soundscape.play()

func greet_seal() -> void:
	if game.menu_is_open() or game.current_location != "island" or not seal.is_visible_in_tree():
		return
	if seal.global_position.distance_to(game.player.global_position) >= 2.6:
		return
	seal_greeting_left = 2.5
	seal_wandering = false
	seal_rest_left = 1.0

func _physics_process(delta: float) -> void:
	if game.menu_is_open() or game.current_location == "room" or not is_visible_in_tree():
		return
	age += delta
	if seal and seal.visible:
		var moving := _step_seal(delta)
		seal.get_node("SealHead").position.y = 0.65 + sin(age * 1.5) * 0.025
		seal.get_node("SealBody").scale.y = 0.65 + sin(age * 1.5) * 0.012
		for index in seal_flippers.size():
			seal_flippers[index].rotation.z = sin(age * (7.0 if moving else 1.7) + index * PI) * (0.22 if moving else 0.045)

func _step_seal(delta: float) -> bool:
	var to_player: Vector3 = game.player.global_position - seal.global_position
	if seal_greeting_left > 0.0:
		seal_greeting_left = maxf(0.0, seal_greeting_left - delta)
		_face_seal(to_player, delta)
		return false
	if not seal_wandering:
		seal_rest_left -= delta
		if to_player.length() < 3.0:
			_face_seal(to_player, delta)
		if seal_rest_left <= 0.0:
			_choose_seal_target(to_player)
		return false
	var direction := seal_target - seal.position
	var next := seal.position.move_toward(seal_target, delta * (0.35 if game.night else 0.6))
	if direction.length() < 0.07 or not _seal_path_clear(seal.position, next):
		seal_wandering = false
		seal_rest_left = seal_rng.randf_range(3.0, 6.0) if game.night else seal_rng.randf_range(1.5, 3.0)
		return false
	seal.position = next
	_face_seal(direction, delta)
	return true

func _choose_seal_target(to_player: Vector3) -> void:
	for attempt in range(8):
		var candidate := Vector3(seal_rng.randf_range(2.2, 7.8), SEAL_HOME.y, seal_rng.randf_range(-8.8, -4.2))
		# Sometimes join a nearby walker, but never depend on one to become active.
		if attempt == 0 and not game.swimming and to_player.length() > 2.0 and to_player.length() < 5.5 and seal_rng.randf() < 0.4:
			var direction := Vector3(to_player.x, 0, to_player.z).normalized()
			candidate = seal.position + to_player - direction * 1.8
			candidate = Vector3(clampf(candidate.x, 2.2, 7.8), SEAL_HOME.y, clampf(candidate.z, -8.8, -4.2))
		if seal.position.distance_to(candidate) > 0.8 and _seal_path_clear(seal.position, candidate):
			seal_target = candidate
			seal_wandering = true
			return
	seal_rest_left = 1.0

func _seal_path_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(to_global(from) + Vector3(0, 0.35, 0), to_global(to) + Vector3(0, 0.35, 0))
	query.exclude = [game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _face_seal(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.01:
		seal.rotation.y = lerp_angle(seal.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 2.0))

func _exit_tree() -> void:
	if is_instance_valid(soundscape):
		soundscape.stop()
		soundscape.stream = null
