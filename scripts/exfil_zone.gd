extends Node3D

var player_inside := false
var progress := 0.0
var completed := false
var current_status := ""
var beacon_pulse_time := 0.0
var area: Area3D
var beacon_light: OmniLight3D
var beacon_mesh_instance: MeshInstance3D

func _ready() -> void:
    _build_marker()
    area = Area3D.new()
    area.name = "ExfilInteractionArea"
    area.collision_layer = 0
    area.collision_mask = 1
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 2.6
    shape_node.shape = shape
    area.add_child(shape_node)
    add_child(area)
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)

func _build_marker() -> void:
    var pad := MeshInstance3D.new()
    pad.name = "ExfilLandingPad"
    var pad_mesh := CylinderMesh.new()
    pad_mesh.top_radius = 2.25
    pad_mesh.bottom_radius = 2.25
    pad_mesh.height = 0.045
    pad.mesh = pad_mesh
    var pad_material := StandardMaterial3D.new()
    pad_material.albedo_color = Color(0.12, 0.16, 0.13)
    pad_material.roughness = 0.95
    pad.material_override = pad_material
    pad.position.y = 0.035
    add_child(pad)

    var beacon := MeshInstance3D.new()
    beacon.name = "ExfilBeacon"
    beacon_mesh_instance = beacon
    var beacon_mesh := CylinderMesh.new()
    beacon_mesh.top_radius = 0.07
    beacon_mesh.bottom_radius = 0.13
    beacon_mesh.height = 1.6
    beacon.mesh = beacon_mesh
    beacon.position = Vector3(0.0, 0.85, 0.0)
    var beacon_material := StandardMaterial3D.new()
    beacon_material.albedo_color = Color(0.92, 0.48, 0.12)
    beacon_material.emission_enabled = true
    beacon_material.emission = Color(0.75, 0.22, 0.035)
    beacon_material.roughness = 0.65
    beacon.material_override = beacon_material
    add_child(beacon)

    beacon_light = OmniLight3D.new()
    beacon_light.name = "ExfilBeaconLight"
    beacon_light.position = Vector3(0.0, 1.25, 0.0)
    beacon_light.light_color = Color(1.0, 0.45, 0.16)
    beacon_light.light_energy = 0.8
    beacon_light.omni_range = 5.0
    beacon_light.shadow_enabled = false
    add_child(beacon_light)

    var bollard_material := StandardMaterial3D.new()
    bollard_material.albedo_color = Color(0.10, 0.12, 0.11)
    bollard_material.roughness = 0.82
    var band_material := StandardMaterial3D.new()
    band_material.albedo_color = Color(0.88, 0.48, 0.14)
    band_material.emission_enabled = true
    band_material.emission = Color(0.22, 0.07, 0.015)
    for index in range(4):
        var angle := TAU * float(index) / 4.0
        var bollard_position := Vector3(cos(angle) * 1.78, 0.4, sin(angle) * 1.78)
        var bollard := MeshInstance3D.new()
        bollard.name = "ExfilBollard_%02d" % (index + 1)
        bollard.add_to_group("exfil_bollards")
        var bollard_mesh := CylinderMesh.new()
        bollard_mesh.top_radius = 0.055
        bollard_mesh.bottom_radius = 0.09
        bollard_mesh.height = 0.8
        bollard.mesh = bollard_mesh
        bollard.position = bollard_position
        bollard.material_override = bollard_material
        add_child(bollard)

        var band := MeshInstance3D.new()
        band.name = "ExfilBollardBand_%02d" % (index + 1)
        var band_mesh := BoxMesh.new()
        band_mesh.size = Vector3(0.17, 0.09, 0.17)
        band.mesh = band_mesh
        band.position = bollard_position + Vector3(0.0, 0.12, 0.0)
        band.material_override = band_material
        add_child(band)

    var smoke := CPUParticles3D.new()
    smoke.name = "ExfilSmoke"
    smoke.amount = 14
    smoke.lifetime = 1.6
    smoke.preprocess = 0.8
    smoke.emitting = true
    smoke.direction = Vector3.UP
    smoke.spread = 10.0
    smoke.gravity = Vector3(0.0, -0.18, 0.0)
    smoke.initial_velocity_min = 0.18
    smoke.initial_velocity_max = 0.55
    smoke.scale_amount_min = 0.35
    smoke.scale_amount_max = 0.75
    var smoke_mesh := SphereMesh.new()
    smoke_mesh.radius = 0.14
    smoke_mesh.height = 0.28
    var smoke_material := StandardMaterial3D.new()
    smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_material.albedo_color = Color(0.75, 0.33, 0.15, 0.18)
    smoke_mesh.material = smoke_material
    smoke.mesh = smoke_mesh
    smoke.position = Vector3(0.0, 0.45, 0.0)
    add_child(smoke)

func _process(delta: float) -> void:
    beacon_pulse_time += delta
    var extraction_ratio := clampf(progress / 2.0, 0.0, 1.0) if player_inside and Input.is_action_pressed("interact") else 0.0
    if is_instance_valid(beacon_light):
        beacon_light.light_energy = 0.65 + (sin(beacon_pulse_time * (2.6 + extraction_ratio * 4.0)) + 1.0) * 0.18 + extraction_ratio * 1.2
    if is_instance_valid(beacon_mesh_instance):
        beacon_mesh_instance.rotation.y += delta * (0.45 + extraction_ratio * 2.4)
        beacon_mesh_instance.scale = Vector3.ONE * (1.0 + extraction_ratio * 0.12)
        var beacon_material := beacon_mesh_instance.material_override as StandardMaterial3D
        if is_instance_valid(beacon_material):
            beacon_material.emission = Color(0.75, 0.22, 0.035).lerp(Color(1.0, 0.56, 0.14), extraction_ratio)
    if completed:
        return
    if not player_inside:
        progress = 0.0
        _set_status("INTEL SECURED. MOVE TO THE EXFIL BEACON.")
        return
    if Input.is_action_pressed("interact"):
        progress += delta
        _set_status("EXFIL IN PROGRESS  %d%%" % int(minf(progress / 2.0, 1.0) * 100.0))
        if progress >= 2.0:
            _complete()
    else:
        progress = 0.0
        _set_status("HOLD F TO CONFIRM EXTRACTION")

func _on_enter(body: Node3D) -> void:
    if body.is_in_group("player") or body.name == "Player":
        player_inside = true

func _on_exit(body: Node3D) -> void:
    if body.is_in_group("player") or body.name == "Player":
        var was_extracting := progress > 0.0
        player_inside = false
        progress = 0.0
        if was_extracting and not completed:
            _set_status("EXTRACTION INTERRUPTED  //  RETURN TO THE EXFIL BEACON")

func _set_status(message: String) -> void:
    if current_status == message:
        return
    current_status = message
    var scene := get_tree().current_scene
    if scene:
        var hud_node := scene.get("hud") as Node
        if is_instance_valid(hud_node) and hud_node.has_method("set_status"):
            hud_node.set_status(message)

func _complete() -> void:
    if completed:
        return
    completed = true
    var scene := get_tree().current_scene
    if scene and scene.has_method("exfiltration_complete"):
        scene.exfiltration_complete()
    queue_free()
