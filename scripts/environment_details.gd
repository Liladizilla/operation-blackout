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

func _box(label: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
	var node: Node3D = StaticBody3D.new() if collision else Node3D.new()
	node.name = label
	if label == "OuterDistrictBuilding":
		node.add_to_group("district_buildings")
	elif label == "UtilityCrate":
		node.add_to_group("service_alley_crates")
	node.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	node.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		node.add_child(shape_node)
	add_child(node)
	return node
