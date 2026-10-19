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
    _check(packed != null, "main scene loads for difficulty tests")
    if packed == null:
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await physics_frame

    var selector: OptionButton = scene.hud.difficulty_selector
    _check(selector != null, "deployment briefing exposes a threat-profile selector")
    if selector == null:
        quit(1)
        return
    _check(selector.item_count == 3, "briefing offers exactly three difficulty profiles")
    _check(selector.get_item_text(0) == "RECRUIT" and selector.get_item_text(1) == "STANDARD" and selector.get_item_text(2) == "VETERAN", "difficulty choices have stable names and order")

    var enemy: Node = scene.enemies[0]
    scene.hud._on_difficulty_selected(0)
    _check(scene.difficulty == "RECRUIT" and enemy.difficulty == "RECRUIT", "Recruit selection propagates to active hostiles")
    _check(is_equal_approx(enemy.shot_damage, 4.0) and is_equal_approx(enemy.detection_range, 25.0), "Recruit reduces incoming damage and detection range")
    _check(is_equal_approx(enemy.fire_interval_min, 1.0) and is_equal_approx(enemy.fire_interval_max, 1.7), "Recruit slows hostile firing cadence")
    _check(scene.hud.difficulty_description.text.contains("Reduced damage"), "Recruit profile explains its balance changes")

    scene.hud._on_difficulty_selected(1)
    _check(scene.difficulty == "STANDARD" and is_equal_approx(enemy.shot_damage, 7.0), "Standard restores the default combat profile")
    _check(is_equal_approx(enemy.detection_range, 30.0) and is_equal_approx(enemy.fire_interval_min, 0.65), "Standard restores default awareness and firing cadence")

    scene.hud._on_difficulty_selected(2)
    _check(scene.difficulty == "VETERAN" and is_equal_approx(enemy.shot_damage, 10.0), "Veteran increases incoming damage")
    _check(is_equal_approx(enemy.detection_range, 34.0), "Veteran increases hostile detection range")
    _check(is_equal_approx(enemy.fire_interval_min, 0.45) and is_equal_approx(enemy.fire_interval_max, 0.9), "Veteran increases hostile firing cadence")
    _check(scene.hud.difficulty_description.text.contains("harder hits"), "Veteran profile explains its balance changes")

    scene.set_difficulty("not-a-profile")
    _check(scene.difficulty == "STANDARD" and enemy.difficulty == "STANDARD", "invalid difficulty input safely falls back to Standard")
    _check(is_equal_approx(enemy.shot_damage, 7.0), "fallback restores the default damage value")

    scene.hud.dismiss_briefing()
    _check(not paused, "difficulty selection remains compatible with deployment")
    print("RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
