extends Node3D

var player_inside := false
var progress := 0.0
var completed := false
var area: Area3D
var beacon_ring: MeshInstance3D
var beacon_light: OmniLight3D
var beacon_beam: MeshInstance3D
var pulse_time := 0.0

func _ready() -> void:
    beacon_ring = get_node_or_null("IntelBeaconRing") as MeshInstance3D
    beacon_light = get_node_or_null("IntelBeaconLight") as OmniLight3D
    beacon_beam = get_node_or_null("IntelBeaconBeam") as MeshInstance3D
    area = Area3D.new()
    area.name = "IntelInteractionArea"
    area.collision_layer = 0
    area.collision_mask = 1
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 2.0
    shape_node.shape = shape
    area.add_child(shape_node)
    add_child(area)
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)

func _process(delta: float) -> void:
    if completed:
        return
    pulse_time += delta
    var collection_ratio := clampf(progress / 2.0, 0.0, 1.0) if player_inside and _all_hostiles_down() and Input.is_action_pressed("interact") else 0.0
    if is_instance_valid(beacon_ring):
        var pulse := 1.0 + sin(pulse_time * (2.4 + collection_ratio * 5.0)) * (0.08 + collection_ratio * 0.035)
        beacon_ring.scale = Vector3.ONE * pulse
        beacon_ring.rotation.y += delta * (0.35 + collection_ratio * 2.2)
    if is_instance_valid(beacon_light):
        beacon_light.light_energy = 0.58 + (sin(pulse_time * (2.1 + collection_ratio * 4.0)) + 1.0) * 0.22 + collection_ratio * 1.1
    if is_instance_valid(beacon_beam):
        var beam_material := beacon_beam.material_override as StandardMaterial3D
        if is_instance_valid(beam_material):
            beam_material.albedo_color.a = 0.28 + collection_ratio * 0.42
            beam_material.emission = Color(0.55, 0.16, 0.025).lerp(Color(1.0, 0.48, 0.12), collection_ratio)
    if not player_inside:
        progress = 0.0
        return
    var scene := get_tree().current_scene
    if scene and scene.has_method("get_remaining_enemies") and scene.get_remaining_enemies() > 0:
        progress = 0.0
        _set_status("ELIMINATE ALL HOSTILES BEFORE RECOVERING INTEL")
        return
    if Input.is_action_pressed("interact"):
        progress += delta
        _set_status("RECOVERING INTEL  %d%%" % int(minf(progress / 2.0, 1.0) * 100.0))
        if progress >= 2.0:
            _complete()
    else:
        progress = 0.0
        _set_status("HOLD F TO RECOVER INTEL")

func _on_enter(body: Node3D) -> void:
    if body.name == "Player":
        player_inside = true

func _on_exit(body: Node3D) -> void:
    if body.name == "Player":
        var was_collecting := progress > 0.0
        player_inside = false
        progress = 0.0
        if was_collecting and not completed:
            _set_status("INTEL RECOVERY INTERRUPTED  //  RETURN TO THE BEACON")

func interact(_player: Node) -> void:
    # Kept as an interaction hook for future controller/input variants.
    if not completed and player_inside and _all_hostiles_down():
        progress = minf(2.0, progress + 0.5)
        if progress >= 2.0:
            _complete()

func _all_hostiles_down() -> bool:
    var scene := get_tree().current_scene
    return not scene or not scene.has_method("get_remaining_enemies") or scene.get_remaining_enemies() == 0

func _set_status(message: String) -> void:
    var scene := get_tree().current_scene
    if scene:
        var hud_node := scene.get("hud") as Node
        if is_instance_valid(hud_node) and hud_node.has_method("set_status"):
            hud_node.set_status(message)

func _complete() -> void:
    if completed or not _all_hostiles_down():
        return
    completed = true
    var scene := get_tree().current_scene
    if scene and scene.has_method("objective_complete"):
        scene.objective_complete()
    queue_free()
