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
    _check(InputMap.has_action("throw_grenade"), "G grenade input action is registered")
    _check(scene.get_remaining_enemies() == 5, "five hostiles spawn")
    var visual_test_enemy: Node = scene.enemies[0]
    _check(visual_test_enemy.get_node_or_null("EnemyMuzzleFlash") != null, "hostiles have muzzle flash geometry")
    visual_test_enemy._show_muzzle_flash()
    _check(visual_test_enemy.enemy_muzzle_flash.visible and visual_test_enemy.enemy_muzzle_light.light_energy > 0.0, "hostile muzzle flash activates")
    _check(scene.get_node_or_null("IntelObjective") != null, "intel objective spawns")
    _check(scene.hud.navigation_label != null, "HUD includes the intel rangefinder")
    _check(scene.hud.health_label.anchor_bottom == 1.0 and scene.hud.ammo_label.anchor_bottom == 1.0, "health and ammo HUD stay anchored when the viewport resizes")
    scene.hud.update_stamina(2.0, 8.0)
    _check(scene.hud.stamina_label.text.contains("025%"), "stamina HUD reflects depleted stamina")
    scene.hud.update_stamina(8.0, 8.0)
    scene.hud.set_ammo(5, 30)
    _check(scene.hud.ammo_label.text == "05 / 030", "ammo HUD formats low ammunition")
    _check(scene.get_node_or_null("EnvironmentDetails") != null, "outer district dressing is attached")
    _check(scene.get_tree().get_nodes_in_group("district_buildings").size() == 8, "eight perimeter buildings are generated")
    _check(scene.get_tree().get_nodes_in_group("service_alley_crates").size() == 5, "service alley utility crates are generated")
    _check(scene.get_tree().get_nodes_in_group("facade_collapse_rubble").size() == 24, "ruined facades have distributed collapse rubble")
    _check(scene.get_tree().get_nodes_in_group("ammo_caches").size() == 3, "three ammo resupply caches spawn around the district")

    var node_count := _count_nodes(scene)
    var mesh_count := _count_meshes(scene)
    print("PROFILE: scene_nodes=", node_count, " mesh_instances=", mesh_count)
    _check(node_count < 1800, "procedural scene stays within node budget")
    _check(mesh_count < 650, "procedural scene stays within mesh budget")

    var player := scene.get_node("Player")
    _check(player.grenades == 2 and scene.hud.grenade_label.text == "FRAG  02", "player starts with two grenades and HUD inventory")
    var grenades_before: int = player.grenades
    player._throw_grenade()
    var test_grenade: Node = scene.get_node_or_null("FragGrenade")
    _check(player.grenades == grenades_before - 1 and scene.hud.grenade_label.text == "FRAG  01", "throwing a grenade consumes one inventory slot")
    _check(is_instance_valid(test_grenade) and is_equal_approx(test_grenade._damage_for_distance(0.0), 85.0), "grenade uses full damage at the blast center")
    _check(is_equal_approx(test_grenade._damage_for_distance(3.0), 42.5), "grenade damage falls off with distance")
    if is_instance_valid(test_grenade):
        test_grenade.set_process(false)
        test_grenade.set_physics_process(false)
        test_grenade.queue_free()
    await process_frame
    player.grenades = 0
    scene.hud.set_grenades(0)
    player._throw_grenade()
    _check(player.grenades == 0 and scene.hud.grenade_label.text == "FRAG  00", "player cannot throw grenades after inventory is depleted")
    player.grenades = 2
    scene.hud.set_grenades(2)
    var ammo_caches: Array = scene.get_tree().get_nodes_in_group("ammo_caches")
    var first_cache: Node = ammo_caches[0]
    player.reserve = 0
    first_cache.player_inside = true
    first_cache._process(0.016)
    _check(not first_cache.used, "ammo cache does not resupply without interaction")
    Input.action_press("interact")
    first_cache._process(0.016)
    Input.action_release("interact")
    _check(first_cache.used and player.reserve == 30, "ammo cache resupplies reserve ammunition")
    _check(scene.hud.ammo_label.text == "30 / 030", "ammo cache refreshes the HUD")
    await process_frame
    var second_cache: Node = ammo_caches[1]
    player.reserve = 170
    second_cache.player_inside = true
    Input.action_press("interact")
    second_cache._process(0.016)
    Input.action_release("interact")
    _check(player.reserve == 180 and second_cache.used, "ammo cache respects the reserve ammunition cap")

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

    var blast_target := CharacterBody3D.new()
    blast_target.set_script(load("res://scripts/enemy.gd"))
    blast_target.position = Vector3(0.0, 0.95, 0.0)
    scene.add_child(blast_target)
    await process_frame
    blast_target.set_physics_process(false)
    var blast := RigidBody3D.new()
    blast.set_script(load("res://scripts/grenade.gd"))
    scene.add_child(blast)
    blast.global_position = blast_target.global_position
    blast._explode()
    _check(blast_target.health < 100.0, "grenade explosion damages a hostile inside the blast radius")
    _check(blast_target.velocity.length() > 0.0, "grenade blast applies physical knockback")
    blast_target.queue_free()
    await process_frame

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

    var exfil: Node = scene.get_node_or_null("ExfilZone")
    if exfil:
        _check(exfil.get_node_or_null("ExfilBeacon") != null, "extraction zone has a visible beacon")
        scene.hud._update_navigation()
        _check(scene.hud.navigation_label.text.begins_with("EXFIL"), "HUD switches navigation from intel to extraction")
    if exfil:
        scene.player.global_position = Vector3(0.0, 1.2, 39.0)
        exfil.player_inside = true
        Input.action_press("interact")
        exfil._process(2.1)
        Input.action_release("interact")
    await process_frame
    _check(scene.get_node_or_null("ExfilZone") == null, "holding interact completes extraction and removes the zone")
    _check(scene.mission_complete and scene.hud.objective_label.text.contains("EXFILTRATION COMPLETE"), "extraction completes the mission and updates HUD")

    print("RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
