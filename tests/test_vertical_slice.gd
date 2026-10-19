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
    _check(scene.hud.is_briefing_open(), "mission briefing appears before deployment")
    _check(paused, "mission briefing pauses the operation before deployment")
    scene.hud.dismiss_briefing()
    _check(not paused, "deploying dismisses briefing and resumes the operation")
    _check(scene.mission_phase == "ENGAGEMENT", "deployment begins the engagement mission phase")
    scene.objective_complete()
    _check(scene.mission_phase == "ENGAGEMENT" and scene.get_node_or_null("ExfilZone") == null, "intel completion cannot skip the hostile-clear phase")
    scene.exfiltration_complete()
    _check(not scene.mission_complete and scene.mission_phase == "ENGAGEMENT", "extraction cannot complete before intel recovery")
    await physics_frame

    _check(scene.get_node_or_null("Player") != null, "player spawns")
    _check(InputMap.has_action("throw_grenade"), "G grenade input action is registered")
    _check(scene.get_remaining_enemies() == 5, "five hostiles spawn")
    var visual_test_enemy: Node = scene.enemies[0]
    _check(visual_test_enemy.get_node_or_null("VisualRoot/EnemyMuzzleFlash") != null, "hostiles have muzzle flash geometry")
    _check(visual_test_enemy.get_node_or_null("VisualRoot/RadioPack") != null and visual_test_enemy.get_node_or_null("VisualRoot/RadioAntenna") != null, "hostiles carry a radio pack with a raised antenna")
    _check(visual_test_enemy.get_node_or_null("VisualRoot/SidearmHolster") != null, "hostiles carry a distinct sidearm holster")
    visual_test_enemy.velocity = Vector3.ZERO
    visual_test_enemy.state = "COMBAT"
    visual_test_enemy._animate_visuals(0.2)
    _check(visual_test_enemy.left_arm_pivot.rotation.x < -0.1 and visual_test_enemy.right_arm_pivot.rotation.x < -0.1, "hostile arms settle into a shouldered combat-ready rifle posture")
    _check(visual_test_enemy.visual_root.rotation.x < -0.05, "hostile torso adopts a subtle forward combat lean")
    visual_test_enemy.velocity = visual_test_enemy.global_transform.basis.x * 2.0
    visual_test_enemy._animate_visuals(0.2)
    _check(visual_test_enemy.visual_root.rotation.z < 0.0, "hostile leans into rightward lateral movement")
    visual_test_enemy.velocity = Vector3.ZERO
    for frame in range(8):
        visual_test_enemy._animate_visuals(0.05)
    _check(absf(visual_test_enemy.visual_root.rotation.z) < 0.025, "hostile lateral lean settles smoothly when movement stops")
    visual_test_enemy.state = "SEARCH"
    visual_test_enemy._show_muzzle_flash()
    _check(visual_test_enemy.enemy_muzzle_flash.visible and visual_test_enemy.enemy_muzzle_light.light_energy > 0.0, "hostile muzzle flash activates")
    _check(scene.get_node_or_null("IntelObjective") != null, "intel objective spawns")
    var intel_marker: Node = scene.get_node("IntelObjective")
    _check(intel_marker.get_node_or_null("IntelInteractionArea") != null, "intel objective interaction area initializes in the scene tree")
    _check(intel_marker.get_node_or_null("IntelBeaconBeam") != null and intel_marker.get_node_or_null("IntelBeaconLight") != null, "intel objective has a visible beam and beacon light")
    var objective_script: Node = intel_marker
    var saved_enemy_list: Array = scene.enemies.duplicate()
    scene.enemies.clear()
    objective_script.player_inside = true
    objective_script.progress = 1.0
    Input.action_press("interact")
    objective_script._process(0.1)
    _check(objective_script.beacon_ring.rotation.y > 0.0, "intel beacon ring rotates during collection")
    _check(objective_script.beacon_light.light_energy > 1.0, "intel beacon light intensifies while data is being recovered")
    var objective_beam_material := objective_script.beacon_beam.material_override as StandardMaterial3D
    _check(objective_beam_material.albedo_color.a > 0.28, "intel beacon beam brightens during collection")
    objective_script.progress = 0.8
    objective_script._on_exit(scene.player)
    _check(not objective_script.player_inside and objective_script.progress == 0.0, "leaving the intel radius cancels recovery progress")
    _check(scene.hud.status_label.text.contains("INTEL RECOVERY INTERRUPTED"), "leaving during recovery displays an interruption warning")
    objective_script.player_inside = true
    objective_script.progress = 1.0
    Input.action_release("interact")
    scene.enemies.assign(saved_enemy_list)
    objective_script.player_inside = false
    objective_script.progress = 0.0

    scene.hud.notify_hostile_neutralized(3)
    _check(scene.hud.status_label.text == "HOSTILE NEUTRALIZED  //  3 REMAINING", "HUD confirms a hostile elimination and remaining threat count")
    scene.hud.set_status("READY")
    scene.hostile_contact_reported = false
    scene.report_hostile_contact(scene.enemies[0])
    _check(scene.hostile_contact_reported and scene.hud.status_label.text == "CONTACT  //  HOSTILES HAVE VISUAL", "first hostile visual acquisition raises a combat contact cue")
    _check(scene.hud.status_label.has_theme_color_override("font_color"), "hostile contact uses its dedicated alert color")
    scene.hud.set_mission_state("INTEL SECURED. MOVE TO EXFIL.")
    _check(not scene.hud.status_label.has_theme_color_override("font_color"), "mission updates restore the neutral HUD status color")
    scene.hud.set_status("KEEP THIS UPDATE")
    scene.report_hostile_contact(scene.enemies[1])
    _check(scene.hud.status_label.text == "KEEP THIS UPDATE", "repeat hostile contacts do not spam or overwrite later combat feedback")
    scene.hostile_contact_reported = false
    scene.hostile_investigation_reported = false
    scene.hud.set_status("READY")
    scene.report_hostile_investigation(scene.enemies[0], "GUNSHOT")
    _check(scene.hostile_investigation_reported and scene.hud.status_label.text == "NOISE DETECTED  //  HOSTILES INVESTIGATING GUNFIRE", "gunfire triggers a readable hostile investigation warning")
    scene.hud.set_status("KEEP THIS UPDATE")
    scene.report_hostile_investigation(scene.enemies[1], "GRENADE")
    _check(scene.hud.status_label.text == "KEEP THIS UPDATE", "repeated noise events do not spam investigation warnings")
    scene.report_hostile_contact(scene.enemies[0])
    _check(scene.hud.status_label.text == "CONTACT  //  HOSTILES HAVE VISUAL", "visual contact supersedes the earlier noise investigation warning")
    scene.hostile_search_reported = false
    scene.report_hostile_search(scene.enemies[0])
    _check(not scene.hostile_search_reported and scene.hud.status_label.text == "CONTACT  //  HOSTILES HAVE VISUAL", "search feedback cannot overwrite a visual-contact alert")
    scene.hostile_contact_reported = false
    scene.hud.set_status("READY")
    scene.report_hostile_search(scene.enemies[0])
    _check(scene.hostile_search_reported and scene.hud.status_label.text == "HOSTILES SEARCHING  //  LAST KNOWN POSITION", "hostiles report a search when investigation loses the trail")
    scene.hud.set_status("KEEP THIS UPDATE")
    scene.report_hostile_search(scene.enemies[1])
    _check(scene.hud.status_label.text == "KEEP THIS UPDATE", "search-state updates do not spam the tactical HUD")
    _check(scene.hud.navigation_label != null, "HUD includes the intel rangefinder")
    _check(scene.hud.health_label.anchor_bottom == 1.0 and scene.hud.ammo_label.anchor_bottom == 1.0, "health and ammo HUD stay anchored when the viewport resizes")
    scene.hud.update_stamina(2.0, 8.0)
    _check(scene.hud.stamina_label.text.contains("025%"), "stamina HUD reflects depleted stamina")
    scene.hud.update_stamina(8.0, 8.0)
    scene.hud.set_ammo(5, 30)
    _check(scene.hud.ammo_label.text == "05 / 030", "ammo HUD formats low ammunition")
    _check(scene.get_node_or_null("EnvironmentDetails") != null, "outer district dressing is attached")
    var skyline_nodes := scene.get_tree().get_nodes_in_group("distant_skyline")
    _check(skyline_nodes.size() == 18, "distant skyline uses layered buildings beyond the playable arena")
    _check(scene.get_node_or_null("DistantCityHorizon") != null, "battlefield has a separate distant city horizon")
    var lamp_bodies := scene.get_tree().get_nodes_in_group("street_lamp_collisions")
    _check(lamp_bodies.size() == 8, "street lamps populate both sides of the road")
    var first_lamp := lamp_bodies[0] as StaticBody3D if not lamp_bodies.is_empty() else null
    var lamp_collision_shapes := first_lamp.find_children("*", "CollisionShape3D", true, false) if first_lamp != null else []
    _check(first_lamp != null and not lamp_collision_shapes.is_empty(), "street lamp shafts have physical collision")
    _check(scene.get_tree().get_nodes_in_group("utility_cables").size() == 12, "overhead utility cables span between lamp poles in sagging segments")
    _check(scene.get_tree().get_nodes_in_group("street_drainage").size() >= 39, "road has manhole covers, grip slots and detailed storm-drain grates")
    _check(scene.get_tree().get_nodes_in_group("road_wear").size() == 6, "tire scarring varies along the damaged road surface")
    _check(scene.get_tree().get_nodes_in_group("vehicle_props").size() == 3, "street vehicles use separate detailed assemblies")
    _check(scene.get_tree().get_nodes_in_group("vehicle_collision").size() == 12, "all four wheels on each vehicle have physical collision")
    var vehicle_nodes := scene.get_tree().get_nodes_in_group("vehicle_props")
    var first_vehicle := vehicle_nodes[0] as Node3D if not vehicle_nodes.is_empty() else null
    _check(first_vehicle != null and first_vehicle.find_child("FrontWindshield", true, false) != null and first_vehicle.find_child("FrontGrille", true, false) != null, "vehicles include distinct glass, grille and body details")
    var skyline_environment: WorldEnvironment = scene.world_environment as WorldEnvironment
    _check(skyline_environment != null and skyline_environment.environment.fog_enabled and skyline_environment.environment.fog_density >= 0.008, "depth fog softens the distant skyline")
    _check(skyline_environment.environment.sky.sky_material is ShaderMaterial, "battlefield sky uses a dedicated procedural sky shader")
    var sky_shader_material := skyline_environment.environment.sky.sky_material as ShaderMaterial
    _check(sky_shader_material.shader != null and sky_shader_material.shader.resource_path == "res://shaders/battlefield_sky.gdshader", "procedural sky shader is loaded from the project assets")
    var sun_lights := scene.find_children("*", "DirectionalLight3D", true, false)
    _check(not sun_lights.is_empty() and (sun_lights[0] as DirectionalLight3D).shadow_enabled, "battlefield uses directional sunlight with shadows")
    var ground_node := scene.find_child("Ground", true, false)
    var ground_mesh := ground_node.get_child(0) as MeshInstance3D if ground_node != null and ground_node.get_child_count() > 0 else null
    _check(ground_mesh != null and ground_mesh.material_override is ShaderMaterial, "terrain uses the procedural weathered surface shader")
    var ground_collision := ground_node.get_child(1) as CollisionShape3D if ground_node != null and ground_node.get_child_count() > 1 else null
    _check(ground_collision != null and ground_collision.shape is BoxShape3D, "terrain retains a solid collision surface beneath its material")
    var road_node := scene.find_child("Road", true, false)
    var road_mesh := road_node.get_child(0) as MeshInstance3D if road_node != null and road_node.get_child_count() > 0 else null
    _check(road_mesh != null and road_mesh.material_override is ShaderMaterial, "asphalt uses a distinct procedural surface response")
    var perimeter_buildings := scene.get_tree().get_nodes_in_group("district_buildings")
    var perimeter_building := perimeter_buildings[0] as Node3D if not perimeter_buildings.is_empty() else null
    var perimeter_mesh := perimeter_building.get_child(0) as MeshInstance3D if perimeter_building != null and perimeter_building.get_child_count() > 0 else null
    _check(perimeter_mesh != null and perimeter_mesh.material_override is ShaderMaterial, "perimeter ruins share the weathered concrete material system")
    var environment_node: WorldEnvironment = scene.world_environment as WorldEnvironment
    _check(environment_node != null and environment_node.environment.fog_enabled, "battlefield atmosphere keeps depth fog enabled")
    _check(scene.get_tree().get_nodes_in_group("district_buildings").size() == 8, "eight perimeter buildings are generated")
    _check(scene.get_tree().get_nodes_in_group("service_alley_crates").size() == 5, "service alley utility crates are generated")
    _check(scene.get_tree().get_nodes_in_group("facade_collapse_rubble").size() == 24, "ruined facades have distributed collapse rubble")
    _check(scene.get_tree().get_nodes_in_group("facade_balconies").size() == 6, "main district buildings have varied damaged balcony silhouettes")
    var first_balcony := scene.get_tree().get_nodes_in_group("facade_balconies")[0] as StaticBody3D
    _check(first_balcony != null and first_balcony.get_child_count() >= 2, "damaged balcony platforms have physical collision shapes")
    _check(scene.get_tree().get_nodes_in_group("facade_damage_details").size() >= 24, "main district facades include cracks, exposed rebar and battered service equipment")
    _check(scene.get_tree().get_nodes_in_group("facade_weathering").size() >= 12, "building facades carry varied rain streaks beneath damaged window bays")
    _check(scene.get_tree().get_nodes_in_group("facade_service_details").size() >= 18, "exterior electrical junctions and conduit runs dress the damaged facades")
    _check(scene.get_tree().get_nodes_in_group("roof_water_tanks").size() >= 4, "rooftop water tanks add varied silhouettes to the ruined district")
    _check(scene.get_tree().get_nodes_in_group("ammo_caches").size() == 3, "three ammo resupply caches spawn around the district")

    var node_count := _count_nodes(scene)
    var mesh_count := _count_meshes(scene)
    print("PROFILE: scene_nodes=", node_count, " mesh_instances=", mesh_count)
    _check(node_count < 2350, "procedural scene stays within node budget")
    _check(mesh_count < 1250, "procedural scene stays within mesh budget after adding vehicle, character and horizon detail")

    var player := scene.get_node("Player")
    var audio_fx = load("res://scripts/audio_fx.gd")
    var generated_gunshot: AudioStreamWAV = audio_fx.create_gunshot()
    var generated_explosion: AudioStreamWAV = audio_fx.create_explosion()
    _check(generated_gunshot.data.size() > 0 and generated_explosion.data.size() > 0, "procedural gunshot and explosion audio streams are generated")
    _check(player.get_node_or_null("WeaponFireAudio") != null and scene.enemies[0].get_node_or_null("EnemyFireAudio") != null, "player and hostiles have positional weapon audio")
    var original_sensitivity: float = player.mouse_sensitivity
    scene.hud.show_pause()
    _check(scene.hud.sensitivity_slider != null, "pause menu exposes mouse sensitivity control")
    scene.hud.sensitivity_slider.value = 0.0026
    _check(is_equal_approx(player.mouse_sensitivity, 0.0026), "mouse sensitivity slider updates player look sensitivity")
    scene.hud.hide_pause()
    player.mouse_sensitivity = original_sensitivity
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
    _check(scene.hostiles_eliminated == 1, "first hostile death increments the debrief kill counter once")
    scene.enemy_killed(first_enemy)
    _check(scene.hostiles_eliminated == 1 and scene.get_remaining_enemies() == 4, "duplicate hostile-death callback cannot inflate kill statistics")

    for enemy in scene.enemies.duplicate():
        enemy.take_damage(1000.0)
    await process_frame
    _check(scene.get_remaining_enemies() == 0, "clearing all hostiles updates objective gate")

    var blast_target := CharacterBody3D.new()
    blast_target.set_script(load("res://scripts/enemy.gd"))
    blast_target.position = Vector3(0.0, 0.95, 0.0)
    blast_target.set_physics_process(false)
    scene.add_child(blast_target)
    await physics_frame
    blast_target.global_position = Vector3(0.0, 0.95, 0.0)
    var blast := RigidBody3D.new()
    blast.set_script(load("res://scripts/grenade.gd"))
    scene.add_child(blast)
    blast.global_position = blast_target.global_position
    blast.freeze = true
    await physics_frame
    blast.fuse_timer = 0.001
    await physics_frame
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
    _check(scene.mission_phase == "EXTRACTION", "mission phase advances to extraction after intel recovery")
    var first_exfil: Node = scene.get_node_or_null("ExfilZone")
    scene.objective_complete()
    _check(scene.get_node_or_null("ExfilZone") == first_exfil, "duplicate intel-completion callback cannot create a second extraction zone")

    var exfil: Node = scene.get_node_or_null("ExfilZone")
    if exfil:
        _check(exfil.get_node_or_null("ExfilBeacon") != null, "extraction zone has a visible beacon")
        _check(exfil.get_node_or_null("ExfilSmoke") != null, "extraction beacon emits a visible smoke plume")
        _check(scene.get_tree().get_nodes_in_group("exfil_bollards").size() == 4, "extraction pad has four safety bollards")
        scene.hud._update_navigation()
        _check(scene.hud.navigation_label.text.begins_with("EXFIL"), "HUD switches navigation from intel to extraction")
    if exfil:
        scene.player.global_position = Vector3(0.0, 1.2, 39.0)
        exfil.player_inside = true
        Input.action_press("interact")
        exfil._process(0.5)
        exfil._process(0.1)
        _check(exfil.beacon_mesh_instance.rotation.y > 0.0, "extraction beacon rotates during confirmation")
        _check(exfil.beacon_light.light_energy > 1.0, "extraction beacon intensifies during confirmation")
        var exfil_material := exfil.beacon_mesh_instance.material_override as StandardMaterial3D
        _check(exfil_material.emission.r > 0.75, "extraction beacon emission brightens during confirmation")
        exfil._on_exit(scene.player)
        _check(not exfil.player_inside and exfil.progress == 0.0, "leaving extraction radius resets confirmation progress")
        _check(scene.hud.status_label.text.contains("EXTRACTION INTERRUPTED"), "leaving extraction displays an interruption warning")
        exfil.player_inside = true
        Input.action_press("interact")
        exfil._process(2.1)
        Input.action_release("interact")
    await process_frame
    _check(scene.get_node_or_null("ExfilZone") == null, "holding interact completes extraction and removes the zone")
    _check(scene.mission_complete and scene.hud.objective_label.text.contains("EXFILTRATION COMPLETE"), "extraction completes the mission and updates HUD")
    _check(scene.mission_phase == "COMPLETE", "successful extraction moves mission into its terminal phase")
    var completed_objective_text: String = scene.hud.objective_label.text
    scene.exfiltration_complete()
    _check(scene.mission_phase == "COMPLETE" and scene.hud.objective_label.text == completed_objective_text, "duplicate extraction callback cannot replay or alter completed mission state")
    _check(scene.hud.mission_stats_label != null and scene.hud.mission_stats_label.text.contains("HOSTILES NEUTRALIZED 5"), "mission debrief reports hostiles eliminated")
    var mission_summary: Dictionary = scene.get_mission_summary()
    _check(int(mission_summary.get("hostiles_eliminated", -1)) == 5, "mission summary agrees with the completed hostile count")
    _check(int(mission_summary.get("grenades_used", -1)) == 1 and int(mission_summary.get("ammo_caches_used", -1)) == 2, "mission summary agrees with debrief equipment usage")
    _check(float(mission_summary.get("accuracy", -1.0)) >= 0.0 and float(mission_summary.get("accuracy", -1.0)) <= 100.0, "mission summary reports accuracy within valid percentage bounds")
    _check(scene.hud.mission_stats_label.text.contains("FRAGS 1") and scene.hud.mission_stats_label.text.contains("AMMO CACHES 2"), "mission debrief reports grenade and resupply usage")
    _check(paused, "mission completion pauses gameplay behind the debrief")
    var escape_event := InputEventKey.new()
    escape_event.keycode = KEY_ESCAPE
    escape_event.pressed = true
    scene._input(escape_event)
    _check(paused, "escape cannot bypass the mission-complete debrief")

    print("RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
