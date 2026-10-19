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
    _check(packed != null, "main scene loads for patrol regression tests")
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

    var patrol_points: Array = get_nodes_in_group("enemy_patrol_points")
    _check(patrol_points.size() == 12, "district has twelve patrol waypoints")

    var enemies: Array = scene.enemies
    for enemy in enemies:
        enemy.set_physics_process(false)
        var goal: Vector3 = enemy.get("patrol_goal")
        _check(goal != Vector3.ZERO, "each hostile initializes a patrol goal")
        var goal_matches_marker := false
        for marker in patrol_points:
            if goal.is_equal_approx(marker.global_position):
                goal_matches_marker = true
                break
        _check(goal_matches_marker, "hostile patrol goals use authored waypoint markers")

    var player: Node3D = scene.get_node("Player")
    var enemy: Node = enemies[0]
    player.global_position = Vector3(-25.0, 1.2, -17.0)
    enemy.global_position = Vector3(-8.0, 0.95, -17.0)
    enemy.state = "SEARCH"
    enemy.alert_memory_timer = 0.0
    enemy.suppression_timer = 0.0
    enemy.cover_timer = 10.0
    enemy.think_timer = 0.0
    enemy.patrol_pause_timer = 10.0
    enemy.call("_physics_process", 0.016)
    _check(enemy.state == "SEARCH", "hostiles do not magically detect players through solid walls")

    var old_goal: Vector3 = enemy.get("patrol_goal")
    enemy.call("_choose_next_patrol_goal")
    var next_goal: Vector3 = enemy.get("patrol_goal")
    _check(next_goal != old_goal, "patrol selects a different waypoint")
    _check(float(enemy.get("patrol_pause_timer")) > 0.0, "patrol inserts a short pause at each waypoint")

    enemy.patrol_goal = enemy.global_position + Vector3(0.0, 0.0, 5.0)
    enemy.patrol_pause_timer = 0.0
    enemy.think_timer = 100.0
    enemy.state = "SEARCH"
    var start_position: Vector3 = enemy.global_position
    enemy.call("_physics_process", 0.1)
    _check(enemy.global_position.distance_to(start_position) > 0.01, "searching hostiles physically move along their patrol goal")

    scene.call("report_noise", player.global_position, 30.0, "GUNSHOT", player)
    _check(enemy.state == "INVESTIGATE" and enemy.alert_memory_timer > 0.0, "a gunshot interrupts patrol and starts investigation")

    print("ENEMY PATROL RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
