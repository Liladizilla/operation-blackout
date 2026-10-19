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

    _check(scene.enemies[0].combat_role == "ASSAULT", "first hostile is assigned the close-pressure assault role")
    _check(scene.enemies[1].combat_role == "SUPPORT", "second hostile is assigned the wider-lane support role")
    _check(scene.enemies[2].combat_role == "FLANKER", "third hostile is assigned the mobile flanker role")
    var assault_ranges: Vector2 = scene.enemies[0]._combat_engagement_ranges()
    var support_ranges: Vector2 = scene.enemies[1]._combat_engagement_ranges()
    _check(assault_ranges.y < support_ranges.y and assault_ranges.x < support_ranges.x, "assault and support roles use distinct engagement distances")
    _check(scene.enemies[1]._combat_fire_interval_scale() > scene.enemies[2]._combat_fire_interval_scale(), "support fires at a steadier slower cadence than flankers")
    _check(scene.enemies[2]._combat_fire_interval_scale() < scene.enemies[0]._combat_fire_interval_scale(), "flankers use a faster firing cadence than assault units")
    _check(scene.enemies[1]._combat_burst_size() > scene.enemies[2]._combat_burst_size(), "support units use longer controlled bursts than flankers")
    _check(scene.enemies[1]._combat_burst_pause() > scene.enemies[2]._combat_burst_pause(), "support units pause longer between bursts than flankers")
    _check(scene.enemies[2]._combat_reacquire_delay() < scene.enemies[1]._combat_reacquire_delay(), "flankers reacquire targets faster than support units")
    _check(scene.enemies[1]._combat_suppression_weight() > scene.enemies[2]._combat_suppression_weight(), "support units prioritize sustained suppression over maneuver speed")
    _check(scene.enemies[2]._should_take_flank_route(), "designated flankers own the squad's primary maneuver")
    _check(not scene.enemies[0]._should_take_flank_route(), "assault units maintain pressure instead of duplicating the flank")
    var flank_a_position: Vector3 = scene.enemies[2].global_position
    var flank_b_position: Vector3 = scene.enemies[4].global_position
    scene.enemies[2].global_position = scene.enemies[3].global_position + Vector3(5.0, 0.0, 0.0)
    scene.enemies[4].global_position = scene.enemies[3].global_position + Vector3(-5.0, 0.0, 0.0)
    _check(not scene.enemies[3]._should_take_flank_route(), "riflemen hold a firing lane while a living flanker is nearby")
    scene.enemies[2].health = 0.0
    scene.enemies[4].health = 0.0
    _check(scene.enemies[3]._should_take_flank_route(), "riflemen can inherit maneuver duty when no living flankers remain")
    scene.enemies[2].health = 100.0
    scene.enemies[4].health = 100.0
    scene.enemies[2].global_position = flank_a_position
    scene.enemies[4].global_position = flank_b_position
    _check(scene.enemies[0]._combat_can_engage(13.0), "assault units engage within their close-pressure firing envelope")
    _check(not scene.enemies[0]._combat_can_engage(17.0), "assault units do not waste shots beyond their role's firing envelope")
    _check(scene.enemies[1]._combat_can_engage(17.0), "support units retain a wider firing envelope than assault units")
    _check(not scene.enemies[1]._combat_can_engage(19.0), "support units also respect their maximum practical engagement distance")
    var rifleman: Node = scene.enemies[3]
    rifleman.set_combat_role("RIFLEMAN")
    var stationary_spread: float = rifleman._combat_miss_radius(12.0, 0.0)
    var moving_spread: float = rifleman._combat_miss_radius(12.0, 2.5)
    _check(moving_spread > stationary_spread, "moving enemies have a wider shot spread than stationary enemies")
    _check(rifleman._combat_miss_radius(20.0, 0.0) > stationary_spread, "shot spread increases with engagement distance")
    scene.enemies[1].set_combat_role("SUPPORT")
    scene.enemies[2].set_combat_role("FLANKER")
    _check(scene.enemies[1]._combat_miss_radius(12.0, 1.0) < rifleman._combat_miss_radius(12.0, 1.0), "support role fires more steadily while moving")
    _check(scene.enemies[2]._combat_miss_radius(12.0, 1.0) > rifleman._combat_miss_radius(12.0, 1.0), "flanker role trades accuracy for aggressive movement")
    scene.enemies[1].set_combat_role("unknown")
    _check(scene.enemies[1].combat_role == "RIFLEMAN", "unknown combat roles safely fall back to rifleman")
    scene.enemies[1].set_combat_role("SUPPORT")

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
    var suppression_source: Vector3 = alert_source.global_position + Vector3(5.0, 0.0, 2.0)
    alert_receiver.apply_suppression(suppression_source)
    _check(alert_receiver.suppression_timer >= 0.85, "near-miss suppression creates a short tactical reaction window")
    _check(alert_receiver.state == "REPOSITION", "suppressed hostiles break from their current firing lane")
    _check(alert_receiver.last_known_position.is_equal_approx(suppression_source), "suppressed hostiles remember the source of incoming fire")
    alert_receiver.cover_goal = Vector3(8.0, 0.0, 19.0)
    alert_receiver.cover_timer = 1.4
    var repeat_suppression_source := suppression_source + Vector3(1.0, 0.0, -1.0)
    alert_receiver.apply_suppression(repeat_suppression_source)
    _check(is_equal_approx(alert_receiver.cover_timer, 1.4), "repeated suppression preserves an active cover commitment")
    _check(alert_receiver.last_known_position.is_equal_approx(repeat_suppression_source), "repeated suppression updates the remembered firing source")
    _check(alert_receiver._should_hold_committed_cover(), "hostile holds its defensive position after suppression ends while the cover timer remains active")
    alert_receiver.cover_timer = 0.0
    _check(not alert_receiver._should_hold_committed_cover(), "hostile may resume combat once its defensive cover commitment expires")
    alert_receiver.cover_goal = Vector3.ZERO

    _check(is_equal_approx(alert_receiver._cover_approach_scale(1.5), 0.5), "hostile slows to half approach speed near cover")
    _check(is_equal_approx(alert_receiver._cover_approach_scale(0.5), 1.0 / 6.0), "hostile makes a controlled final approach to cover")
    _check(is_equal_approx(alert_receiver._cover_approach_scale(4.0), 1.0), "hostile keeps full approach speed when cover is distant")
    _check(not alert_receiver._has_cover_from_threat(suppression_source, suppression_source), "zero-distance cover candidate is not treated as protection")
    alert_receiver.health = 100.0
    _check(is_equal_approx(alert_receiver._cover_threat_distance_weight(), 0.65), "healthy hostiles balance threat distance against a practical cover route")
    alert_receiver.health = 35.0
    _check(is_equal_approx(alert_receiver._cover_threat_distance_weight(), 1.05), "wounded hostiles prioritize safer distance from incoming fire")
    alert_receiver.health = 100.0
    var first_cover: Vector3 = alert_receiver._choose_cover(suppression_source)
    var second_cover: Vector3 = alert_receiver._choose_cover(suppression_source)
    _check(not first_cover.is_equal_approx(second_cover), "cover selection discourages immediately reusing the previous position")
    alert_source.state = "REPOSITION"
    alert_source.cover_timer = 2.0
    alert_source.cover_goal = Vector3(8.0, 0.0, 19.0)
    var shared_cover_penalty: float = alert_receiver._cover_ally_spacing_penalty(alert_source.cover_goal)
    var distant_cover_penalty: float = alert_receiver._cover_ally_spacing_penalty(Vector3(100.0, 0.0, 100.0))
    _check(shared_cover_penalty > distant_cover_penalty, "cover scoring penalizes crowding a teammate's assigned position")
    alert_source.state = "COMBAT"
    alert_source.cover_timer = 0.0

    # Combat movement chooses a lateral route around the player, not just a fixed strafe.
    alert_receiver.player = player
    alert_receiver.global_position = player.global_position + Vector3(0.0, 0.0, 9.0)
    var flank_goal: Vector3 = alert_receiver._choose_flank_goal()
    var flank_radius: float = Vector2(flank_goal.x - player.global_position.x, flank_goal.z - player.global_position.z).length()
    _check(flank_radius >= 7.4 and flank_radius <= 10.1, "flank goal keeps a useful engagement distance")
    _check(flank_goal.distance_to(alert_receiver.global_position) > 1.5, "flank goal breaks the current firing lane")
    alert_source.flank_goal = flank_goal
    _check(alert_receiver._flank_ally_spacing_penalty(flank_goal) > alert_receiver._flank_ally_spacing_penalty(Vector3(40.0, 0.0, 40.0)), "flank selection discourages teammates from converging on the same flank goal")
    var shared_flank_score: float = alert_receiver._score_flank_candidate(flank_goal, 8.0)
    var open_flank_score: float = alert_receiver._score_flank_candidate(Vector3(40.0, 0.0, 40.0), 8.0)
    _check(shared_flank_score < open_flank_score, "flank route scoring strongly avoids a teammate's chosen flank position")
    alert_source.flank_goal = player.global_position + player.global_transform.basis.x * 8.0 + Vector3(0.0, 0.0, 2.0)
    var occupied_lane_penalty: float = alert_receiver._flank_lane_occupancy_penalty(alert_source.flank_goal + Vector3(1.0, 0.0, 0.0))
    var opposite_lane_penalty: float = alert_receiver._flank_lane_occupancy_penalty(player.global_position - player.global_transform.basis.x * 8.0 + Vector3(0.0, 0.0, 2.0))
    _check(occupied_lane_penalty > opposite_lane_penalty, "flankers prefer the less occupied side of the player's position")
    alert_receiver.flank_goal = player.global_position + player.global_transform.basis.x * 8.0
    var nearby_repeat_score: float = alert_receiver._score_flank_candidate(alert_receiver.flank_goal + Vector3(1.0, 0.0, 0.0), 8.0)
    var distinct_route_score: float = alert_receiver._score_flank_candidate(player.global_position - player.global_transform.basis.x * 8.0, 8.0)
    _check(nearby_repeat_score < distinct_route_score, "flank scoring discourages repeatedly choosing near-identical routes")
    alert_receiver.global_position = alert_source.global_position + Vector3(1.0, 0.0, 0.0)
    var separation_direction: Vector3 = alert_receiver._apply_ally_separation(Vector3.FORWARD)
    _check(separation_direction.dot(Vector3.RIGHT) > 0.0, "movement steering creates lateral separation from a nearby teammate")
    alert_receiver.global_position = saved_receiver_position
    alert_source.flank_goal = Vector3.ZERO

    alert_receiver.global_position = saved_receiver_position
    alert_receiver.set_physics_process(true)

    var hud: Node = scene.hud
    hud.call("show_hostile_fire", player.global_position, player.global_transform.basis, player.global_position + Vector3(4.0, 0.0, 0.0))
    _check(hud.damage_direction_label.text.contains("HOSTILE FIRE"), "HUD identifies the direction of hostile fire before the player is hit")
    hud.call("show_damage_direction", player.global_position, player.global_transform.basis, player.global_position + Vector3(4.0, 0.0, 0.0))
    _check(not hud.damage_direction_label.text.contains("HOSTILE FIRE"), "damage indicator replaces the warning with an incoming-hit cue")

    print("TACTICAL RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
