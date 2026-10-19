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
    _check(packed != null, "main scene loads for tactical lean tests")
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
    _check(InputMap.has_action("lean_left") and InputMap.has_action("lean_right"), "Q/E lean actions are registered")

    player._update_lean(0.1, -1.0)
    _check(player.lean_target < 0.0 and player.lean_amount < 0.0, "left input produces a left lean")
    _check(player.camera_pivot.position.x < 0.0, "left lean moves the camera pivot laterally")
    _check(not player.lean_blocked, "clear left side allows the lean")

    player._update_lean(0.1, 1.0)
    _check(player.lean_target > 0.0 and player.lean_amount > 0.0, "right input transitions to a right lean")
    _check(player.camera_pivot.position.x > 0.0, "right lean moves the camera pivot laterally")

    var wall := StaticBody3D.new()
    wall.name = "LeanObstructionTest"
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.12, 2.5, 2.0)
    collision.shape = shape
    wall.add_child(collision)
    scene.add_child(wall)
    wall.global_position = player.global_position - player.global_transform.basis.x * 0.2 + Vector3.UP * 1.2
    await physics_frame

    player._update_lean(0.1, -1.0)
    _check(player.lean_blocked, "side obstruction blocks leaning through solid geometry")
    _check(is_equal_approx(player.lean_target, 0.0), "blocked lean safely targets the neutral position")
    _check(absf(player.lean_amount) < 0.01, "camera recenters instead of clipping through the wall")

    player._update_lean(0.1, 0.0)
    _check(is_equal_approx(player.lean_target, 0.0), "releasing Q/E returns to a neutral stance")
    _check(not player.lean_blocked, "neutral stance does not retain a stale blocked flag")

    print("TACTICAL LEAN RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
