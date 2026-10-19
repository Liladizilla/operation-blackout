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
    _check(packed != null, "main scene loads for enemy survival tests")
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

    var enemies: Array = scene.enemies
    for unit in enemies:
        unit.set_physics_process(false)

    var healthy_enemy: Node = enemies[1]
    healthy_enemy.health = 100.0
    healthy_enemy.low_health_retreat_used = false
    healthy_enemy.suppression_timer = 0.0
    healthy_enemy.take_damage(10.0)
    _check(not healthy_enemy.low_health_retreat_used, "healthy hostiles do not spend their low-health retreat early")
    _check(healthy_enemy.suppression_timer < 2.0, "ordinary damage keeps the normal suppression duration")
    _check(healthy_enemy.hit_reaction_timer >= 0.22, "ordinary hits trigger a short procedural flinch")
    healthy_enemy._animate_visuals(0.01)
    _check(healthy_enemy.visual_root.rotation.x < 0.0, "hit flinch visibly leans the hostile upper body")

    var wounded_enemy: Node = enemies[0]
    wounded_enemy.health = 45.0
    wounded_enemy.low_health_retreat_used = false
    wounded_enemy.suppression_timer = 0.0
    wounded_enemy.take_damage(12.0)
    _check(is_equal_approx(wounded_enemy.health, 33.0), "damage correctly crosses the critical-health threshold")
    _check(wounded_enemy.low_health_retreat_used, "critical damage triggers the one-time survival response")
    _check(wounded_enemy.state == "REPOSITION" and wounded_enemy.suppression_timer >= 2.0, "wounded hostiles get a longer retreat window")
    wounded_enemy.hit_reaction_timer = 0.0
    wounded_enemy.take_damage(1.0, wounded_enemy.global_position + Vector3.LEFT, true)
    _check(wounded_enemy.hit_reaction_timer >= 0.32, "headshots trigger a stronger, longer hit reaction")

    wounded_enemy.call("_physics_process", 0.016)
    _check(wounded_enemy.cover_timer > 0.0, "critical retreat selects a cover destination")
    wounded_enemy.take_damage(1.0)
    _check(wounded_enemy.suppression_timer >= 1.9, "follow-up hits do not erase the active retreat window")

    print("ENEMY SURVIVAL RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
