extends Node3D

var player_inside := false
var progress := 0.0
var completed := false
var current_status := ""
var area: Area3D
var beacon_light: OmniLight3D

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

func _process(delta: float) -> void:
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
        player_inside = false
        progress = 0.0

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
