extends SceneTree

var failed := false
var passed := 0

func _initialize() -> void:
    call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
    if condition:
        passed += 1
        print("PASS: ", message)
    else:
        failed = true
        push_error("FAIL: " + message)

func _run_tests() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    _check(packed != null, "main scene loads for casing tests")
    if packed == null:
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    if scene.hud.is_briefing_open():
        scene.hud.dismiss_briefing()
    await physics_frame

    for enemy in scene.enemies:
        enemy.set_physics_process(false)
    var player: Node = scene.get_node("Player")
    player.set_physics_process(false)
    var ammo_before: int = player.ammo
    player._fire()

    var casings: Array = get_nodes_in_group("brass_casings")
    _check(player.ammo == ammo_before - 1, "firing still consumes exactly one round")
    _check(casings.size() == 1, "each rifle shot ejects one brass casing")
    if casings.is_empty():
        quit(1)
        return

    var casing: Node3D = casings[0] as Node3D
    var mesh_node := casing.get_node("BrassCasingMesh") as MeshInstance3D
    _check(is_instance_valid(mesh_node) and mesh_node.mesh is CylinderMesh, "casing uses a small cylindrical mesh")
    var material := mesh_node.material_override as StandardMaterial3D
    _check(is_instance_valid(material) and material.metallic >= 0.8, "casing has a metallic brass material")
    _check(casing.velocity.length() > 1.0, "casing receives a visible ejection velocity")

    var start_position: Vector3 = casing.global_position
    casing.call("_process", 0.05)
    _check(casing.global_position.distance_to(start_position) > 0.01, "casing simulates flight and rotation without a rigid body")

    await create_timer(2.2).timeout
    _check(get_nodes_in_group("brass_casings").is_empty(), "spent casings clean themselves up")

    print("BRASS CASING RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
