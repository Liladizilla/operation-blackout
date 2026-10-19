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


func _count_nodes(node: Node) -> int:
    var count := 1
    for child in node.get_children():
        count += _count_nodes(child)
    return count

func _count_meshes(node: Node) -> int:
    var count := 1 if node is MeshInstance3D else 0
    for child in node.get_children():
        count += _count_meshes(child)
    return count

func _count_named_nodes(node: Node, target_name: String) -> int:
    var count := 1 if node.name == target_name else 0
    for child in node.get_children():
        count += _count_named_nodes(child, target_name)
    return count

func _run_tests() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    _check(packed != null, "main scene resource loads")
    if packed == null:
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await physics_frame

    _check(scene.get_node_or_null("Player") != null, "player spawns")
    _check(scene.get_remaining_enemies() == 5, "five hostiles spawn")
    _check(scene.get_node_or_null("IntelObjective") != null, "intel objective spawns")
    _check(scene.get_node_or_null("EnvironmentDetails") != null, "outer district dressing is attached")
    _check(_count_named_nodes(scene, "OuterDistrictBuilding") == 8, "eight perimeter buildings are generated")
    _check(_count_named_nodes(scene, "UtilityCrate") == 5, "service alley utility crates are generated")

    var node_count := _count_nodes(scene)
    var mesh_count := _count_meshes(scene)
    print("PROFILE: scene_nodes=", node_count, " mesh_instances=", mesh_count)
    _check(node_count < 1800, "procedural scene stays within node budget")
    _check(mesh_count < 650, "procedural scene stays within mesh budget")

    var player := scene.get_node("Player")
    var starting_health: float = player.health
    player.apply_damage(12.0, Vector3(3, 0, 3))
    _check(is_equal_approx(player.health, starting_health - 12.0), "player takes damage")
    player.health = 1.0
    player.apply_damage(10.0)
    _check(is_equal_approx(player.health, 100.0), "player respawn restores health")

    player.ammo = 5
    player.reserve = 30
    player._start_reload()
    _check(player.is_reloading, "reload enters active state")
    player.reload_time = 0.01
    player._physics_process(0.02)
    _check(not player.is_reloading and player.ammo == 30 and player.reserve == 5, "reload transfers ammunition and exits state")

    # Place a target in the camera's forward line and exercise the actual hitscan path.
    var firing_target: Node = scene.enemies[1]
    firing_target.set_physics_process(false)
    firing_target.global_position = Vector3(0.0, 0.95, 19.0)
    await physics_frame
    player.camera_pivot.rotation = Vector3.ZERO
    player.pitch = 0.0
    player.ammo = 30
    player.fire_cooldown = 0.0
    player._fire()
    _check(player.ammo == 29, "firing consumes one round")
    _check(firing_target.health < 100.0 or not scene.enemies.has(firing_target), "hitscan shot damages target")

    var first_enemy: Node = scene.enemies[0]
    var survived: bool = first_enemy.take_damage(10.0)
    _check(not survived and is_equal_approx(first_enemy.health, 90.0), "enemy survives nonlethal damage")
    _check(first_enemy.state == "REPOSITION" and first_enemy.suppression_timer > 0.0, "incoming fire triggers suppression reposition")
    survived = first_enemy.take_damage(100.0)
    _check(survived, "enemy death is reported")
    await process_frame
    _check(scene.get_remaining_enemies() == 4, "enemy death updates remaining-hostile count")

    for enemy in scene.enemies.duplicate():
        enemy.take_damage(1000.0)
    await process_frame
    _check(scene.get_remaining_enemies() == 0, "clearing all hostiles updates objective gate")

    var objective := scene.get_node_or_null("IntelObjective")
    if objective:
        objective.player_inside = true
        Input.action_press("interact")
        objective._process(2.1)
        Input.action_release("interact")
    await process_frame
    _check(scene.get_node_or_null("IntelObjective") == null, "intel objective completes and is removed")
    _check(scene.hud.objective_label.text.contains("EXFILTRATION COMPLETE"), "mission completion reaches HUD")

    print("RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
