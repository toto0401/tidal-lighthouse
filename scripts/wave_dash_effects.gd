extends Node3D

## A small pool of water ribbons and ripples, anchored to the ground or water surface.
const TRAIL_COUNT := 18
const TRAIL_LIFETIME := 0.6
var wave: Node3D
var ribbons: Array[MeshInstance3D] = []
var trail: Array[Node3D] = []
var ages: Array[float] = []
var next_trail := 0
var emission_clock := 0.0
var wave_time := 0.0

func _ready() -> void:
	wave = Node3D.new()
	wave.name = "Crest"
	add_child(wave)
	var pearl := SphereMesh.new()
	pearl.radius = 0.7
	pearl.height = 1.4
	pearl.radial_segments = 24
	pearl.rings = 12
	var surf := _mesh("Surf", pearl, _water_material(Color("#65d8e2"), 0.65), wave)
	surf.scale = Vector3(0.9, 0.13, 1.7)
	surf.position = Vector3(0, 0.1, -0.15)
	for side in [-1.0, 1.0]:
		var ribbon := _mesh("WaveRibbon", _ribbon_mesh(side), _water_material(Color("#bcfff3"), 0.8), wave)
		ribbons.append(ribbon)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.49
	ring.rings = 20
	ring.ring_segments = 6
	var drop := SphereMesh.new()
	drop.radius = 0.075
	drop.height = 0.15
	drop.radial_segments = 8
	drop.rings = 4
	for index in TRAIL_COUNT:
		var ripple := Node3D.new()
		ripple.name = "Ripple%d" % index
		add_child(ripple)
		var material := _water_material(Color("#83efed"), 0.75)
		var circle := _mesh("Ring", ring, material, ripple)
		circle.scale = Vector3(1.0, 0.2, 1.0)
		for side in [-1.0, 1.0]:
			var droplet := _mesh("Droplet", drop, material, ripple)
			droplet.position = Vector3(side * 0.45, 0.13, -0.1)
			droplet.scale = Vector3(0.7, 1.7, 0.7)
		trail.append(ripple)
		ages.append(TRAIL_LIFETIME)
		ripple.hide()
	wave.hide()

func begin_wave(at: Vector3, direction: Vector3) -> void:
	wave_time = 0.0
	emission_clock = 0.0
	wave.position = at
	wave.rotation.y = atan2(direction.x, direction.z)
	wave.show()
	_emit_ripple(at, direction)

func stop_wave() -> void:
	if is_instance_valid(wave):
		wave.hide()

func clear_trail() -> void:
	stop_wave()
	for index in trail.size():
		ages[index] = TRAIL_LIFETIME
		trail[index].hide()

func update_wave(delta: float, at: Vector3, direction: Vector3, active: bool) -> void:
	for index in trail.size():
		if ages[index] >= TRAIL_LIFETIME:
			continue
		ages[index] += delta
		var phase := clampf(ages[index] / TRAIL_LIFETIME, 0.0, 1.0)
		var ripple := trail[index]
		ripple.visible = phase < 1.0
		var circle := ripple.get_node("Ring") as MeshInstance3D
		circle.scale = Vector3(0.7 + phase * 1.4, 0.2, 0.6 + phase * 1.15)
		var material := circle.material_override as StandardMaterial3D
		material.albedo_color.a = (1.0 - phase) * 0.72
		for child in ripple.get_children():
			if child == circle:
				continue
			child.position.y = 0.12 + sin(phase * PI) * 0.55
			child.scale = Vector3(0.7, 1.7, 0.7) * (1.0 - phase * 0.8)
	wave.visible = active
	if not active:
		return
	wave_time += delta
	wave.position = at
	wave.rotation.y = atan2(direction.x, direction.z)
	for index in ribbons.size():
		ribbons[index].position.y = sin(wave_time * 18.0 + index * PI) * 0.035
	emission_clock -= delta
	if emission_clock <= 0.0:
		emission_clock += 0.045
		_emit_ripple(at - direction * 0.55, direction)

func _emit_ripple(at: Vector3, direction: Vector3) -> void:
	var ripple := trail[next_trail]
	ripple.position = at - Vector3(0, 0.02, 0)
	ripple.rotation.y = atan2(direction.x, direction.z)
	ages[next_trail] = 0.0
	ripple.show()
	next_trail = (next_trail + 1) % TRAIL_COUNT

func _water_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.1
	return material

func _mesh(node_name: String, mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance, true)
	return instance

func _ribbon_mesh(side: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(24):
		var a := float(segment) / 24.0
		var b := float(segment + 1) / 24.0
		var pa := Vector3(side * (0.18 + sin(a * PI) * 0.65), 0.12 + sin(a * PI) * 0.32, 1.3 - a * 3.0)
		var pb := Vector3(side * (0.18 + sin(b * PI) * 0.65), 0.12 + sin(b * PI) * 0.32, 1.3 - b * 3.0)
		var wa := Vector3(side * sin(a * PI) * 0.16, 0.06, 0)
		var wb := Vector3(side * sin(b * PI) * 0.16, 0.06, 0)
		for vertex in [pa, pa + wa, pb, pb, pa + wa, pb + wb]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
