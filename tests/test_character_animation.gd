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
    _check(packed != null, "main scene loads for character animation tests")
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
    _check(player.weapon_root.get_node_or_null("LeftFirstPersonForearm") != null, "first-person weapon has a left forearm view model")
    _check(player.weapon_root.get_node_or_null("RightFirstPersonForearm") != null, "first-person weapon has a right forearm view model")
    _check(player.weapon_root.get_node_or_null("LeftFirstPersonGlove") != null and player.weapon_root.get_node_or_null("RightFirstPersonGlove") != null, "first-person hands have glove geometry")

    var enemy: Node = scene.enemies[0]
    enemy.set_physics_process(false)
    _check(enemy.get_node_or_null("VisualRoot") != null, "hostile visuals have an independent animation root")
    _check(enemy.visual_root.get_node_or_null("LeftArmPivot") != null and enemy.visual_root.get_node_or_null("RightArmPivot") != null, "hostile model includes two animated arms")
    _check(enemy.visual_root.get_node_or_null("LeftLegPivot") != null and enemy.visual_root.get_node_or_null("RightLegPivot") != null, "hostile model includes two animated legs")
    _check(enemy.visual_root.get_node_or_null("LeftLegPivot/LeftLegMesh") != null and enemy.visual_root.get_node_or_null("RightLegPivot/RightLegMesh") != null, "hostile legs use lightweight mesh geometry")

    enemy.velocity = Vector3(2.0, 0.0, 0.0)
    enemy.gait_time = 0.0
    enemy._animate_visuals(0.1)
    _check(enemy.gait_time > 0.0, "hostile gait advances with elapsed movement time")
    _check(absf(enemy.left_leg_pivot.rotation.x) > 0.01 and absf(enemy.right_leg_pivot.rotation.x) > 0.01, "moving hostiles swing their legs")
    _check(enemy.left_leg_pivot.rotation.x * enemy.right_leg_pivot.rotation.x < 0.0, "hostile legs alternate during the gait cycle")
    _check(enemy.left_arm_pivot.rotation.x * enemy.right_arm_pivot.rotation.x < 0.0, "hostile arms counter-swing during movement")

    var enemy_count_before: int = scene.get_remaining_enemies()
    var died: bool = enemy.take_damage(1000.0)
    _check(died and enemy.is_dead, "lethal damage begins the enemy death sequence")
    _check(not enemy.is_in_group("enemies") and scene.get_remaining_enemies() == enemy_count_before - 1, "dead hostiles leave combat tracking immediately")
    _check(not enemy.is_physics_processing(), "dead hostile physics is disabled during collapse")
    _check(enemy.get_node_or_null("HeadHitZone") == null or not enemy.get_node("HeadHitZone").monitoring, "dead hostile head hit zone is disabled")
    enemy._process(0.25)
    _check(absf(enemy.visual_root.rotation.z) > 0.1 and enemy.visual_root.position.y < 0.0, "death animation visibly rolls the hostile down")
    enemy._process(0.5)
    await process_frame
    _check(not is_instance_valid(enemy), "collapsed hostile frees its scene nodes after the animation")

    print("CHARACTER ANIMATION RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
