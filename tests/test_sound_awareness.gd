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

    # A loud shot carries far enough to put all five enemies on alert.
    for index in range(enemies.size()):
        enemies[index].global_position = original_enemy_positions[index]
        enemies[index].state = "SEARCH"
        enemies[index].alert_memory_timer = 0.0
    var heard_gunshot := scene.report_noise(player.global_position, 120.0, "GUNSHOT", player)
    _check(heard_gunshot == enemies.size(), "gunshot noise propagates to all enemies within range")
    var all_investigating := true
    for enemy in enemies:
        all_investigating = all_investigating and enemy.alert_memory_timer >= 5.0 and enemy.state == "INVESTIGATE"
    _check(all_investigating, "gunshot creates persistent enemy investigation memory")

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
