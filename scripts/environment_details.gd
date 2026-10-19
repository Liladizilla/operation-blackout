extends Node3D

# Low-cost outer-district dressing. Kept separate from main.gd so the core
# combat arena stays readable and its procedural geometry remains maintainable.
var shared_materials: Dictionary = {}

func _ready() -> void:
	_build_perimeter_blocks()
	_build_service_alley()
	_build_rubble_fields()

func _build_perimeter_blocks() -> void:
	var blocks := [
		[Vector3(-42.0, 0.0, -31.0), Vector3(7.0, 6.5, 9.0), Color(0.27, 0.28, 0.26)],
		[Vector3(-42.0, 0.0, -10.0), Vector3(8.0, 8.0, 8.0), Color(0.32, 0.29, 0.25)],
		[Vector3(-42.0, 0.0, 14.0), Vector3(7.0, 5.5, 10.0), Color(0.30, 0.30, 0.27)],
		[Vector3(-41.0, 0.0, 35.0), Vector3(9.0, 7.0, 8.0), Color(0.28, 0.29, 0.27)],
		[Vector3(42.0, 0.0, -34.0), Vector3(8.0, 8.5, 9.0), Color(0.29, 0.28, 0.25)],
		[Vector3(42.0, 0.0, -12.0), Vector3(7.0, 6.0, 8.0), Color(0.34, 0.31, 0.27)],
		[Vector3(42.0, 0.0, 12.0), Vector3(8.0, 7.5, 10.0), Color(0.28, 0.30, 0.28)],
		[Vector3(41.0, 0.0, 35.0), Vector3(9.0, 6.0, 8.0), Color(0.31, 0.29, 0.26)]
	]
	for block in blocks:
		_build_ruined_block(block[0], block[1], block[2])

func _build_ruined_block(pos: Vector3, size: Vector3, color: Color) -> void:
	_box("OuterDistrictBuilding", pos + Vector3(0.0, size.y * 0.5, 0.0), size, color, true)
	_box("CollapsedRoof", pos + Vector3(0.0, size.y + 0.18, 0.0), Vector3(size.x * 0.72, 0.36, size.z * 0.68), color.darkened(0.22), true)

	var columns := 2
	var rows := maxi(1, int(size.y / 3.5))
	for row in range(rows):
		for column in range(columns):
			var x := pos.x - size.x * 0.5 + size.x * (float(column) + 0.5) / float(columns)
			var y := pos.y + 1.8 + float(row) * 2.6
			if y > pos.y + size.y - 0.8:
				continue
			var window_color := Color(0.045, 0.055, 0.055) if (row + column) % 3 != 0 else Color(0.12, 0.11, 0.09)
			_box("DarkWindow", Vector3(x, y, pos.z - size.z * 0.5 - 0.045), Vector3(1.0, 1.15, 0.08), window_color, false)
			_box("DamagedLintel", Vector3(x, y + 0.65, pos.z - size.z * 0.5 - 0.09), Vector3(1.2, 0.12, 0.16), color.lightened(0.08), false)

	# Exposed concrete ribs and a service entry add scale without expensive assets.
	for side in [-1.0, 1.0]:
		_box("ExposedFacadeRib", Vector3(pos.x + side * (size.x * 0.5 - 0.16), pos.y + size.y * 0.5, pos.z - size.z * 0.5 - 0.11), Vector3(0.18, size.y, 0.18), color.darkened(0.18), false)
	_box("BlockedServiceDoor", Vector3(pos.x - size.x * 0.22, pos.y + 0.95, pos.z - size.z * 0.5 - 0.07), Vector3(0.95, 1.9, 0.12), Color(0.11, 0.12, 0.11), false)

	# Broken facade seams, exposed reinforcement, and collapsed concrete at the base.
	for scar_index in range(2):
		var scar_x := pos.x - size.x * 0.27 + float(scar_index) * size.x * 0.48
		var scar_y := pos.y + 2.8 + float(scar_index) * 1.7
		var scar := _box("ConcreteScar", Vector3(scar_x, scar_y, pos.z - size.z * 0.5 - 0.145), Vector3(0.11, 1.05, 0.055), color.darkened(0.24), false)
		scar.rotation_degrees.z = -13.0 if scar_index == 0 else 17.0
	for rebar_index in range(2):
		var rebar := _box("ExposedRebar", Vector3(pos.x - 1.0 + float(rebar_index) * 2.0, pos.y + size.y + 0.38, pos.z - size.z * 0.25), Vector3(0.055, 0.9, 0.055), Color(0.23, 0.12, 0.075), false)
		rebar.rotation_degrees.z = 24.0 if rebar_index == 0 else -19.0
	for rubble_index in range(3):
		var rubble_width := 0.55 + float(rubble_index % 2) * 0.3
		var rubble_height := 0.22 + float(rubble_index % 3) * 0.12
		var rubble_x := pos.x - size.x * 0.3 + float(rubble_index) * size.x * 0.3
		var rubble := _box("FacadeCollapseRubble", Vector3(rubble_x, rubble_height * 0.5, pos.z - size.z * 0.5 - 0.48), Vector3(rubble_width, rubble_height, 0.42 + float(rubble_index % 2) * 0.22), color.darkened(0.16), false)
		rubble.rotation_degrees.y = float((rubble_index * 31 + int(absf(pos.x))) % 90)

func _build_service_alley() -> void:
	# A narrow service lane and loading-yard clutter create alternate movement
	# silhouettes at the edge of the existing central road.
	_box("ServiceLane", Vector3(-25.5, 0.012, 0.0), Vector3(5.5, 0.035, 72.0), Color(0.095, 0.10, 0.095), false)
	for z in [-28.0, -16.0, -4.0, 8.0, 20.0, 32.0]:
		_box("AlleyDrain", Vector3(-28.0, 0.04, z), Vector3(0.12, 0.045, 3.2), Color(0.18, 0.18, 0.16), false)
	for i in range(5):
		var z := -25.0 + float(i) * 12.0
		_box("UtilityCrate", Vector3(-30.0, 0.65, z), Vector3(1.1, 1.3, 1.0), Color(0.22, 0.23, 0.20), true)
		_box("CrateBand", Vector3(-30.0, 0.72, z - 0.52), Vector3(1.12, 0.12, 0.06), Color(0.36, 0.32, 0.24), false)

func _build_rubble_fields() -> void:
	for i in range(18):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (29.0 + float((i * 7) % 9))
		var z := -35.0 + float((i * 17) % 70)
		var width := 0.45 + float(i % 3) * 0.22
		var height := 0.22 + float(i % 4) * 0.12
		var chunk := _box("ConcreteRubble", Vector3(x, height * 0.5, z), Vector3(width, height, 0.45 + float(i % 2) * 0.3), Color(0.25, 0.25, 0.22), false)
		chunk.rotation_degrees.y = float((i * 29) % 90)

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if shared_materials.has(key):
		return shared_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	shared_materials[key] = material
	return material

func _surface_kind_for_name(label: String) -> float:
	if label in ["ConcreteRubble", "FacadeCollapseRubble"]:
		return 2.0
	if label == "ServiceLane":
		return 1.0
	if label in ["OuterDistrictBuilding", "CollapsedRoof", "ExposedFacadeRib"]:
		return 0.0
	return -1.0

func _surface_material(color: Color, surface_kind: float) -> ShaderMaterial:
	var key := "surface:%s:%s" % [color.to_html(true), str(surface_kind)]
	if shared_materials.has(key):
		return shared_materials[key] as ShaderMaterial
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/battlefield_surface.gdshader") as Shader
	shader_material.set_shader_parameter("base_color", color)
	shader_material.set_shader_parameter("surface_kind", surface_kind)
	shader_material.set_shader_parameter("detail_scale", 1.0)
	shared_materials[key] = shader_material
	return shader_material

func _box(label: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
	var node: Node3D = StaticBody3D.new() if collision else Node3D.new()
	node.name = label
	if label == "OuterDistrictBuilding":
		node.add_to_group("district_buildings")
	elif label == "UtilityCrate":
		node.add_to_group("service_alley_crates")
	elif label == "FacadeCollapseRubble":
		node.add_to_group("facade_collapse_rubble")
	node.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var surface_kind := _surface_kind_for_name(label)
	mesh_instance.material_override = _surface_material(color, surface_kind) if surface_kind >= 0.0 else _material(color)
	node.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		node.add_child(shape_node)
	add_child(node)
	return node
