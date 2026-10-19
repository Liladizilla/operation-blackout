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
    _check(packed != null, "main scene loads for tactical map tests")
    if packed == null:
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await physics_frame

    var map: Control = scene.hud.tactical_minimap
    _check(is_instance_valid(map), "combat HUD includes the tactical minimap")
    _check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tactical map does not intercept gameplay input")
    _check(map.size.x >= 180.0 and map.size.y >= 180.0, "tactical map has a stable HUD footprint")

    var center: Vector2 = map.call("world_to_map", Vector3.ZERO)
    _check(center.distance_to(map.size * 0.5) < 0.01, "world origin maps to the center of the tactical map")
    var edge: Vector2 = map.call("world_to_map", Vector3(100.0, 0.0, 100.0))
    _check(edge.x <= map.size.x - 10.0 and edge.y <= map.size.y - 10.0, "map coordinates clamp to the map boundary")

    var enemies: Array = scene.enemies
    for enemy in enemies:
        enemy.set_physics_process(false)
        enemy.state = "SEARCH"
        enemy.alert_memory_timer = 0.0
    enemies[0].state = "COMBAT"
    var contacts: Array = map.call("get_visible_enemy_contacts")
    _check(contacts.size() == 1, "minimap only shows alerted or actively engaging hostiles")
    enemies[1].alert_memory_timer = 2.0
    contacts = map.call("get_visible_enemy_contacts")
    _check(contacts.size() == 2, "shared threat memory adds hostile contacts to the minimap")

    _check(scene.get_tree().get_nodes_in_group("arena_buildings").size() == 6, "central buildings are tagged for tactical map geometry")
    _check(scene.get_tree().get_nodes_in_group("arena_cover").size() == 9, "concrete barriers and destructible panels are tagged for tactical map geometry")

    print("TACTICAL MAP RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
