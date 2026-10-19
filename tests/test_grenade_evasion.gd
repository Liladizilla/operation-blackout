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
    _check(packed != null, "main scene loads for grenade evasion tests")
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

    var enemy: Node = scene.enemies[0]
    enemy.set_physics_process(false)
    var grenade := RigidBody3D.new()
    grenade.set_script(load("res://scripts/grenade.gd"))
    scene.add_child(grenade)
    grenade.global_position = enemy.global_position + Vector3(2.0, 0.0, 0.0)
    grenade.fuse_timer = 1.4

    _check(grenade.is_in_group("active_grenades"), "live grenades register in the active threat group")
    var threat: Node3D = enemy.call("_nearest_grenade_threat") as Node3D
    _check(threat == grenade, "hostile detects an armed grenade inside its danger radius")

    enemy.state = "SEARCH"
    enemy.think_timer = 0.0
    enemy.cover_timer = 0.0
    enemy.suppression_timer = 0.0
    enemy.call("_physics_process", 0.016)
    _check(enemy.state == "REPOSITION", "hostile switches to evasive movement when a grenade is imminent")
    _check(enemy.suppression_timer >= 0.35, "grenade threat triggers a brief urgent reaction")

    grenade.fuse_timer = 2.1
    threat = enemy.call("_nearest_grenade_threat") as Node3D
    _check(threat == null, "hostile ignores grenades that still have ample fuse time")
    grenade.fuse_timer = 1.4
    grenade.global_position = enemy.global_position + Vector3(12.0, 0.0, 0.0)
    threat = enemy.call("_nearest_grenade_threat") as Node3D
    _check(threat == null, "hostile ignores grenades outside its danger radius")
    grenade.global_position = enemy.global_position + Vector3(2.0, 0.0, 0.0)
    grenade.exploded = true
    threat = enemy.call("_nearest_grenade_threat") as Node3D
    _check(threat == null, "already-exploded grenades are not treated as live threats")

    print("GRENADE EVASION RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
