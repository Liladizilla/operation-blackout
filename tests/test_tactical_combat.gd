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
    _check(packed != null, "main scene resource loads for tactical combat tests")
    if packed == null:
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await physics_frame

    var player: Node = scene.get_node("Player")
    player.stamina = 4.0
    player.stamina_regen_delay = 0.0
    player._update_stamina(0.5, true)
    _check(is_equal_approx(player.stamina, 3.5), "sprinting drains stamina")
    _check(is_equal_approx(player.stamina_regen_delay, 1.0), "sprinting starts the stamina recovery delay")

    player._update_stamina(0.75, false)
    _check(is_equal_approx(player.stamina, 3.5), "stamina stays depleted during the recovery delay")
    _check(is_equal_approx(player.stamina_regen_delay, 0.25), "recovery delay counts down accurately")

    player._update_stamina(0.5, false)
    _check(is_equal_approx(player.stamina, 3.85), "stamina recovers only for the portion after the delay")
    player._update_stamina(20.0, false)
    _check(is_equal_approx(player.stamina, 8.0), "stamina recovery respects its maximum")

    var enemy: Node = scene.enemies[0]
    var cover_candidates: Array[Vector3] = enemy._get_district_cover_candidates()
    _check(cover_candidates.size() == 32, "ammo caches and service crates expose 32 tactical cover positions")

    var alert_source: Node = scene.enemies[0]
    var alert_receiver: Node = scene.enemies[1]
    var saved_receiver_position: Vector3 = alert_receiver.global_position
    alert_receiver.set_physics_process(false)
    alert_receiver.global_position = alert_source.global_position + Vector3(3.0, 0.0, 0.0)
    alert_receiver.state = "SEARCH"
    alert_receiver.alert_memory_timer = 0.0

    var first_alert := Vector3(2.0, 0.0, 4.0)
    alert_receiver.hear_alert(first_alert)
    _check(alert_receiver.state == "INVESTIGATE", "alerted hostiles enter investigation state")
    _check(alert_receiver.last_known_position.is_equal_approx(first_alert), "alerted hostiles remember the threat location")
    _check(alert_receiver.alert_memory_timer > 0.0, "enemy threat memory persists briefly")

    alert_source.alert_broadcast_timer = 0.0
    var second_alert := Vector3(4.0, 0.0, 6.0)
    alert_source._broadcast_alert(second_alert)
    _check(alert_receiver.last_known_position.is_equal_approx(second_alert), "broadcast alerts update nearby teammates")
    _check(alert_source.alert_broadcast_timer > 0.0, "alert broadcasts are rate limited")

    alert_receiver.state = "SEARCH"
    alert_receiver.suppression_timer = 0.0
    alert_receiver.cover_timer = 0.0
    alert_receiver.alert_memory_timer = 0.0
    var suppression_source := alert_source.global_position + Vector3(5.0, 0.0, 2.0)
    alert_receiver.apply_suppression(suppression_source)
    _check(alert_receiver.suppression_timer >= 0.85, "near-miss suppression creates a short tactical reaction window")
    _check(alert_receiver.state == "REPOSITION", "suppressed hostiles break from their current firing lane")
    _check(alert_receiver.last_known_position.is_equal_approx(suppression_source), "suppressed hostiles remember the source of incoming fire")

    var first_cover: Vector3 = alert_receiver._choose_cover(suppression_source)
    var second_cover: Vector3 = alert_receiver._choose_cover(suppression_source)
    _check(not first_cover.is_equal_approx(second_cover), "cover selection discourages immediately reusing the previous position")

    alert_receiver.global_position = saved_receiver_position
    alert_receiver.set_physics_process(true)

    var hud: Node = scene.hud
    hud.call("show_hostile_fire", player.global_position, player.global_transform.basis, player.global_position + Vector3(4.0, 0.0, 0.0))
    _check(hud.damage_direction_label.text.contains("HOSTILE FIRE"), "HUD identifies the direction of hostile fire before the player is hit")
    hud.call("show_damage_direction", player.global_position, player.global_transform.basis, player.global_position + Vector3(4.0, 0.0, 0.0))
    _check(not hud.damage_direction_label.text.contains("HOSTILE FIRE"), "damage indicator replaces the warning with an incoming-hit cue")

    print("TACTICAL RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
