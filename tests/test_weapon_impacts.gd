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
    _check(packed != null, "main scene loads for weapon impact tests")
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

    var player: Node = scene.get_node("Player")
    player.set_physics_process(false)
    for enemy in scene.enemies:
        enemy.set_physics_process(false)
    player.rotation.y = 0.0
    player.camera_pivot.rotation = Vector3.ZERO
    player.pitch = 0.0

    var wall := StaticBody3D.new()
    wall.name = "ImpactTestWall"
    var wall_collision := CollisionShape3D.new()
    var wall_shape := BoxShape3D.new()
    wall_shape.size = Vector3(4.0, 4.0, 0.2)
    wall_collision.shape = wall_shape
    wall.add_child(wall_collision)
    scene.add_child(wall)
    wall.global_position = player.camera.global_position + (-player.camera.global_transform.basis.z * 8.0)
    await physics_frame

    player.ammo = 30
    player.fire_cooldown = 0.0
    player.is_reloading = false
    player._fire()
    await physics_frame

    _check(player.ammo == 29, "firing still consumes exactly one round")
    var casings: Array = get_nodes_in_group("spent_casings")
    var impacts: Array = get_nodes_in_group("bullet_impacts")
    _check(casings.size() == 1, "a fired round ejects one spent casing")
    _check(impacts.size() == 1, "a hit on solid world geometry creates an impact mark")

    if not casings.is_empty():
        var casing := casings[0] as RigidBody3D
        _check(casing.get_node_or_null("CasingMesh") is MeshInstance3D, "spent casing uses a visible lightweight cylinder")
        _check(casing.get_node_or_null("CollisionShape3D") is CollisionShape3D, "spent casing can collide with the world")
        _check(casing.linear_velocity.length() > 0.1, "spent casing receives an ejection impulse")
        _check(casing.collision_layer == 0 and casing.collision_mask == 1, "casing physics is restricted to world collision")
    if not impacts.is_empty():
        var impact := impacts[0] as MeshInstance3D
        _check(impact.mesh is BoxMesh, "impact mark uses a thin box mesh")
        _check((impact.mesh as BoxMesh).size.z < 0.02, "impact mark is thin enough to sit against a surface")
        _check(impact.get_node_or_null("CollisionShape3D") == null, "impact mark adds no invisible collision")
        _check(is_instance_valid(impact.material_override as StandardMaterial3D), "impact mark has its own surface material")

    for index in range(15):
        player._spawn_bullet_impact(Vector3(float(index), 1.0, -2.0), Vector3.UP)
    _check(get_nodes_in_group("bullet_impacts").size() <= 12, "impact mark count stays within the visual budget")

    for index in range(12):
        player._spawn_spent_casing()
    _check(get_nodes_in_group("spent_casings").size() <= 8, "spent casing count stays bounded during sustained fire")

    var expiring_casing: Node = get_nodes_in_group("spent_casings")[0]
    expiring_casing.call("_process", 4.0)
    var expiring_impact: Node = get_nodes_in_group("bullet_impacts")[0]
    expiring_impact.call("_process", 13.0)
    await process_frame
    _check(not is_instance_valid(expiring_casing), "spent casings self-clean after their short lifetime")
    _check(not is_instance_valid(expiring_impact), "impact marks self-clean after fading")

    print("WEAPON IMPACT RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
