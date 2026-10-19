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
    _check(packed != null, "main scene loads for sound-awareness tests")
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
    var enemies: Array = scene.enemies
    var original_player_position: Vector3 = player.global_position
    var original_enemy_positions: Array[Vector3] = []
    for enemy in enemies:
        original_enemy_positions.append(enemy.global_position)
        enemy.set_physics_process(false)
        enemy.state = "SEARCH"
        enemy.alert_memory_timer = 0.0

    _check(scene.report_noise(player.global_position, 0.0, "GUNSHOT", player) == 0, "zero-radius noise events are ignored")
    var investigation_test: Node = enemies[0]
    investigation_test.state = "INVESTIGATE"
    investigation_test.alert_memory_timer = 3.0
    investigation_test.patrol_pause_timer = 0.0
    investigation_test.patrol_goal = Vector3(10.0, 0.0, 10.0)
    investigation_test._complete_investigation()
    _check(investigation_test.state == "SEARCH", "guards switch from investigation to a local search after reaching a sound source")
    _check(is_equal_approx(investigation_test.patrol_pause_timer, 1.35), "guards pause briefly to scan the area before resuming patrol")
    _check(investigation_test.alert_memory_timer == 0.0 and investigation_test.patrol_goal == Vector3.ZERO, "completed investigation clears stale alert memory and patrol target")
    investigation_test.state = "SEARCH"
    investigation_test.patrol_pause_timer = 0.0

    # A solid building attenuates footstep noise enough that a distant guard
    # on the opposite side does not hear it.
    player.global_position = Vector3(-25.0, 1.2, -17.0)
    enemies[0].global_position = Vector3(-8.0, 0.95, -17.0)
    for index in range(1, enemies.size()):
        enemies[index].global_position = Vector3(80.0 + float(index) * 5.0, 0.95, 80.0)
    scene.report_noise(player.global_position, 20.0, "FOOTSTEP", player)
    _check(enemies[0].alert_memory_timer == 0.0, "solid cover attenuates distant footstep noise")

    # Prone movement is quieter than crouched movement at the same distance.
    player.global_position = original_player_position
    enemies[0].global_position = player.global_position + Vector3(3.0, -0.25, 0.0)
    enemies[0].state = "SEARCH"
    enemies[0].alert_memory_timer = 0.0
    player.is_prone = true
    player.is_crouched = false
    player.footstep_noise_timer = 0.0
    player._update_footstep_noise(0.016, true, false)
    _check(enemies[0].alert_memory_timer == 0.0, "prone movement stays below the nearby guard's hearing range")

    player.is_prone = false
    player.is_crouched = true
    player.footstep_noise_timer = 0.0
    player._update_footstep_noise(0.016, true, false)
    _check(enemies[0].state == "INVESTIGATE" and enemies[0].alert_memory_timer > 0.0, "crouched footsteps alert a nearby guard")
    player.is_crouched = false

    # A round striking nearby hard cover can reveal the impact location.
    enemies[0].global_position = player.global_position + Vector3(3.0, -0.25, 0.0)
    enemies[0].state = "SEARCH"
    enemies[0].alert_memory_timer = 0.0
    var heard_impact: int = scene.call("report_noise", player.global_position, 24.0, "IMPACT", player)
    _check(heard_impact >= 1, "nearby enemies can hear a bullet strike on hard cover")
    _check(enemies[0].state == "INVESTIGATE" and enemies[0].alert_memory_timer >= 2.8, "impact noise gives guards a short investigation memory")

    # A loud shot carries far enough to put all five enemies on alert.
    for index in range(enemies.size()):
        enemies[index].global_position = original_enemy_positions[index]
        enemies[index].state = "SEARCH"
        enemies[index].alert_memory_timer = 0.0
    var heard_gunshot: int = scene.call("report_noise", player.global_position, 120.0, "GUNSHOT", player)
    _check(heard_gunshot == enemies.size(), "gunshot noise propagates to all enemies within range")
    var all_investigating := true
    for enemy in enemies:
        all_investigating = all_investigating and enemy.alert_memory_timer >= 5.0 and enemy.state == "INVESTIGATE"
    _check(all_investigating, "gunshot creates persistent enemy investigation memory")

    # Hostile gunfire is also audible to nearby members of the opposing squad.
    for index in range(enemies.size()):
        enemies[index].state = "SEARCH"
        enemies[index].alert_memory_timer = 0.0
        enemies[index].global_position = Vector3(100.0 + float(index) * 10.0, 0.95, 100.0)
    enemies[0].global_position = Vector3(0.0, 0.95, 0.0)
    enemies[1].global_position = Vector3(3.0, 0.95, 0.0)
    var heard_hostile_shot: int = scene.call("report_noise", enemies[0].global_position, 42.0, "GUNSHOT", enemies[0])
    _check(heard_hostile_shot >= 1, "hostile gunfire alerts nearby guards other than the shooter")
    _check(enemies[1].state == "INVESTIGATE" and enemies[1].alert_memory_timer >= 5.0, "nearby guards investigate the hostile firing position")

    # The actual grenade explosion reports its own noise, even when enemies
    # are outside the blast damage radius.
    for index in range(enemies.size()):
        enemies[index].global_position = player.global_position + Vector3(8.0 + float(index) * 3.0, -0.25, 0.0)
        enemies[index].state = "SEARCH"
        enemies[index].alert_memory_timer = 0.0
    var grenade := RigidBody3D.new()
    grenade.set_script(load("res://scripts/grenade.gd"))
    scene.add_child(grenade)
    grenade.global_position = player.global_position
    grenade._explode()
    var all_heard_blast := true
    for enemy in enemies:
        all_heard_blast = all_heard_blast and enemy.alert_memory_timer >= 6.0
    _check(all_heard_blast, "grenade blast alerts enemies beyond its damage radius")

    print("SOUND AWARENESS RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
