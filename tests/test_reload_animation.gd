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
    _check(packed != null, "main scene loads for reload animation tests")
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
    player.set_physics_process(false)
    var magazine := player.get("weapon_magazine") as MeshInstance3D
    _check(is_instance_valid(magazine), "view weapon exposes a separately animated magazine")
    _check(magazine.visible, "magazine is visible outside reload")

    player.is_reloading = true
    player.ammo = 30
    player.reserve = 90
    player.reload_time = 1.2
    player.call("_physics_process", 0.016)
    _check(not magazine.visible, "magazine is removed during the middle of the reload")

    player.reload_time = 0.6
    player.call("_physics_process", 0.016)
    _check(magazine.visible, "magazine becomes visible during reinsertion")
    _check(magazine.position.y > -0.42 and magazine.position.y < -0.18, "magazine slides upward into the receiver")

    player.reload_time = 0.1
    player.call("_physics_process", 0.016)
    _check(is_equal_approx(magazine.position.y, -0.18) and is_equal_approx(magazine.rotation.x, -0.12), "magazine settles into its seated position")

    player.is_reloading = false
    player.call("_update_magazine_reload", 0.0)
    _check(magazine.visible and is_equal_approx(magazine.position.y, -0.18), "cancelled or completed reload restores the magazine safely")

    print("RELOAD ANIMATION RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
