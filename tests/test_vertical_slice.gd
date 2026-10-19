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
    var count := 1 if node.name == target_name or node.name.begins_with(target_name) else 0
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
    var visual_test_enemy: Node = scene.enemies[0]
    _check(visual_test_enemy.get_node_or_null("EnemyMuzzleFlash") != null, "hostiles have muzzle flash geometry")
    visual_test_enemy._show_muzzle_flash()
    _check(visual_test_enemy.enemy_muzzle_flash.visible and visual_test_enemy.enemy_muzzle_light.light_energy > 0.0, "hostile muzzle flash activates")
    _check(visual_test_enemy._shot_spread(1.0) < visual_test_enemy._shot_spread(30.0), "hostile fire becomes less accurate at longer range")
    _check(is_equal_approx(visual_test_enemy._shot_spread(0.0), 0.12) and is_equal_approx(visual_test_enemy._shot_spread(30.0), 0.9), "hostile shot spread remains within intended close and long-range limits")
    var cover_test_goal: Vector3 = visual_test_enemy._choose_cover(scene.get_node("Player").global_position)
    _check(absf(cover_test_goal.x) <= 50.0 and absf(cover_test_goal.z) <= 50.0, "hostile cover selection stays within the playable district")
    var flank_test_enemy: Node = scene.enemies[0]
    var saved_flank_position: Vector3 = flank_test_enemy.global_position
    flank_test_enemy.global_position = Vector3(200.0, 0.95, 200.0)
    var flank_allies: Array[Node3D] = []
    for ally_position in [Vector3(198.0, 0.95, 200.0), Vector3(197.0, 0.95, 201.0), Vector3(202.0, 0.95, 200.0)]:
        var flank_ally := Node3D.new()
        flank_ally.add_to_group("enemies")
        scene.add_child(flank_ally)
        flank_ally.global_position = ally_position
        flank_allies.append(flank_ally)
    var coordinated_flank: float = flank_test_enemy._choose_flank_sign(Vector3(200.0, 0.95, 210.0))
    _check(is_equal_approx(coordinated_flank, -1.0), "hostiles choose the less crowded flank instead of stacking on one side")
    for flank_ally in flank_allies:
        flank_ally.remove_from_group("enemies")
        flank_ally.queue_free()
    flank_test_enemy.global_position = saved_flank_position
    visual_test_enemy.state = "SEARCH"
    visual_test_enemy.last_known_position = Vector3.ZERO
    visual_test_enemy.global_position = Vector3(-18.0, 0.95, -38.0)
    var search_direction: Vector3 = visual_test_enemy.player.global_position - visual_test_enemy.global_position
    search_direction.y = 0.0
    _check(search_direction.length() > 3.0, "distant search test starts outside close-search radius")
    var cautious_search: Vector3 = visual_test_enemy._search_direction(scene.get_node("Player").global_position)
    _check(cautious_search.length() > 0.45 and cautious_search.length() < 0.51, "distant hostiles advance cautiously instead of remaining idle")
    var near_search: Vector3 = visual_test_enemy._search_direction(visual_test_enemy.global_position + Vector3(1.0, 0.0, 0.0))
    _check(near_search.length() > 0.2 and near_search.length() < 0.24, "nearby search movement drifts laterally")
    _check(scene.get_node_or_null("IntelObjective") != null, "intel objective spawns")
    _check(scene.hud.navigation_label != null, "HUD includes the intel rangefinder")
    _check(scene.hud.health_label.anchor_bottom == 1.0 and scene.hud.ammo_label.anchor_bottom == 1.0, "health and ammo HUD stay anchored when the viewport resizes")
    scene.hud.update_stamina(2.0, 8.0)
    _check(scene.hud.stamina_label.text.contains("025%"), "stamina HUD reflects depleted stamina")
    scene.hud.update_stamina(8.0, 8.0)
    var stability_player = scene.get_node("Player")
    stability_player.velocity = Vector3.ZERO
    stability_player.is_crouched = false
    stability_player.is_prone = false
    stability_player.stamina = 8.0
    var standing_spread: float = stability_player._current_weapon_spread()
    stability_player.is_crouched = true
    var crouched_spread: float = stability_player._current_weapon_spread()
    stability_player.is_crouched = false
    stability_player.is_prone = true
    var prone_spread: float = stability_player._current_weapon_spread()
    stability_player.is_prone = false
    stability_player.velocity = Vector3(0.0, 0.0, -6.0)
    var moving_spread: float = stability_player._current_weapon_spread()
    stability_player.velocity = Vector3.ZERO
    _check(crouched_spread < standing_spread and prone_spread < crouched_spread, "lower stances improve weapon stability")
    _check(moving_spread > standing_spread, "movement increases weapon spread")
    scene.hud.set_ammo(5, 30)
    _check(scene.hud.ammo_label.text == "05 / 030", "ammo HUD formats low ammunition")
    scene.hud.flash_hitmarker(false, false)
    _check(scene.hud.hit_feedback_label.text == "TARGET HIT" and scene.hud.hit_feedback_label.visible, "ordinary hits display readable confirmation")
    scene.hud.flash_hitmarker(false, true)
    _check(scene.hud.hit_feedback_label.text == "HEADSHOT", "headshots receive distinct confirmation")
    scene.hud.flash_hitmarker(true, true)
    _check(scene.hud.hit_feedback_label.text == "HEADSHOT  /  ELIMINATED", "headshot eliminations preserve both combat cues")
    _check(scene.get_node_or_null("EnvironmentDetails") != null, "outer district dressing is attached")
    _check(scene.get_tree().get_nodes_in_group("district_buildings").size() == 8, "eight perimeter buildings are generated")
    _check(scene.get_tree().get_nodes_in_group("service_alley_crates").size() == 5, "service alley utility crates are generated")
    _check(scene.get_tree().get_nodes_in_group("facade_collapse_rubble").size() == 24, "ruined facades have distributed collapse rubble")

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
    _check(player.respawn_invulnerability > 0.0, "respawn grants brief damage protection")
    player.apply_damage(20.0)
    _check(is_equal_approx(player.health, 100.0), "respawn protection blocks immediate follow-up damage")
    player.respawn_invulnerability = 0.0

    player.ammo = 5
    player.reserve = 30
    player._start_reload()
    _check(player.is_reloading, "reload enters active state")
    player.reload_time = 0.01
    player._physics_process(0.02)
    _check(not player.is_reloading and player.ammo == 30 and player.reserve == 5, "reload transfers ammunition and exits state")

    var avoidance_enemy: Node = scene.enemies[0]
    var saved_enemy_position: Vector3 = avoidance_enemy.global_position
    avoidance_enemy.set_physics_process(false)
    avoidance_enemy.global_position = Vector3(-9.5, 0.95, -17.0)
    await physics_frame
    var steered_direction: Vector3 = avoidance_enemy._avoid_obstacles(Vector3.LEFT)
    _check(steered_direction.dot(Vector3.LEFT) < 0.99, "hostile steering diverts around a concrete barrier")
    _check(avoidance_enemy._avoid_obstacles(Vector3.ZERO) == Vector3.ZERO, "hostile steering safely handles a zero direction")
    avoidance_enemy.global_position = saved_enemy_position
    avoidance_enemy.set_physics_process(true)

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

    var gated_objective: Node = scene.get_node("IntelObjective")
    gated_objective.player_inside = true
    Input.action_press("interact")
    gated_objective._process(1.0)
    Input.action_release("interact")
    _check(not gated_objective.completed and is_equal_approx(gated_objective.progress, 0.0), "intel recovery stays locked while hostiles remain")
    gated_objective.progress = 1.0
    gated_objective._on_exit(player)
    _check(is_equal_approx(gated_objective.progress, 0.0), "leaving the intel zone cancels partial recovery progress")
    _check(scene.hud.status_label.text == "INTEL RECOVERY INTERRUPTED", "leaving the intel zone reports interrupted recovery")

    var headshot_test_enemy: Node = scene.enemies[2]
    headshot_test_enemy.take_damage(10.0, Vector3.ZERO, true)
    _check(is_equal_approx(headshot_test_enemy.health, 70.0), "headshots apply the intended three-times damage multiplier")
    _check(headshot_test_enemy.suppression_timer >= 1.25, "headshots trigger an extended hostile suppression response")

    var first_enemy: Node = scene.enemies[0]
    var chosen_cover: Vector3 = first_enemy._choose_cover(player.global_position)
    var solid_obstacle_centers := [
        Vector3(-7, 0, -10), Vector3(7, 0, -18), Vector3(-5, 0, 7),
        Vector3(6, 0, 19), Vector3(-12, 0, 25), Vector3(13, 0, -1)
    ]
    _check(not solid_obstacle_centers.has(chosen_cover), "hostile cover goals sit beside obstacles instead of inside them")
    var slow_steering: Vector3 = first_enemy._avoid_obstacles(Vector3(0.0, 0.0, -0.42))
    _check(is_equal_approx(slow_steering.length(), 0.42), "obstacle steering preserves tactical movement speed")
    var survived: bool = first_enemy.take_damage(10.0)
    _check(not survived and is_equal_approx(first_enemy.health, 90.0), "enemy survives nonlethal damage")
    _check(first_enemy.hit_flash_timer > 0.0, "nonlethal hits trigger a temporary enemy hit reaction")
    _check(first_enemy.state == "REPOSITION" and first_enemy.suppression_timer > 0.0, "incoming fire triggers suppression reposition")
    survived = first_enemy.take_damage(100.0)
    _check(survived, "enemy death is reported")
    await process_frame
    _check(scene.get_remaining_enemies() == 4, "enemy death updates remaining-hostile count")

    for enemy in scene.enemies.duplicate():
        enemy.take_damage(1000.0)
    await process_frame
    _check(scene.get_remaining_enemies() == 0, "clearing all hostiles updates objective gate")
    _check(scene.mission_phase == "RECOVER_INTEL", "clearing hostiles advances mission into intel recovery")

    var objective := scene.get_node_or_null("IntelObjective")
    if objective:
        objective.player_inside = true
        Input.action_press("interact")
        objective._process(2.1)
        Input.action_release("interact")
    await process_frame
    _check(scene.get_node_or_null("IntelObjective") == null, "intel objective completes and is removed")
    _check(scene.get_node_or_null("ExfilZone") != null, "recovering intel activates the extraction zone")
    _check(not scene.mission_complete and scene.hud.objective_label.text.contains("MOVE TO EXFIL"), "intel recovery starts a separate extraction phase")
    _check(scene.mission_phase == "EXFIL", "intel recovery advances mission into extraction phase")
    scene.objective_complete()
    _check(scene.get_node_or_null("ExfilZone") != null, "duplicate objective completion does not duplicate extraction")

    var exfil: Node = scene.get_node_or_null("ExfilZone")
    if exfil:
        _check(exfil.get_node_or_null("ExfilBeacon") != null, "extraction zone has a visible beacon")
        scene.hud._update_navigation()
        _check(scene.hud.navigation_label.text.begins_with("EXFIL"), "HUD switches navigation from intel to extraction")
        exfil.progress = 1.0
        exfil._on_exit(player)
        _check(is_equal_approx(exfil.progress, 0.0), "leaving the extraction zone cancels partial extraction progress")
        _check(scene.hud.status_label.text == "EXTRACTION INTERRUPTED. RETURN TO THE BEACON.", "extraction interruption is surfaced to the player")
        exfil._process(0.1)
        _check(scene.hud.status_label.text == "EXTRACTION INTERRUPTED. RETURN TO THE BEACON.", "interruption feedback persists instead of disappearing next frame")
    if exfil:
        scene.player.global_position = Vector3(0.0, 1.2, 39.0)
        exfil.player_inside = true
        Input.action_press("interact")
        exfil._process(2.1)
        Input.action_release("interact")
    await process_frame
    _check(scene.get_node_or_null("ExfilZone") == null, "holding interact completes extraction and removes the zone")
    _check(scene.mission_complete and scene.hud.objective_label.text.contains("EXFILTRATION COMPLETE"), "extraction completes the mission and updates HUD")
    _check(scene.mission_phase == "COMPLETE", "successful extraction closes the mission state machine")
    _check(scene.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mission completion freezes combat and releases the mouse for the results panel")
    _check(is_instance_valid(scene.hud.mission_panel), "mission completion presents replay and quit controls")
    scene.exfiltration_complete()
    _check(scene.mission_complete and scene.mission_phase == "COMPLETE", "duplicate extraction completion remains harmless")

    print("RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
