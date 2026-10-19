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

func _has_button(action: String, button_index: int) -> bool:
    if not InputMap.has_action(action):
        return false
    for event in InputMap.action_get_events(action):
        if event is InputEventJoypadButton and event.button_index == button_index:
            return true
    return false

func _has_axis(action: String, axis: int, positive: bool) -> bool:
    if not InputMap.has_action(action):
        return false
    for event in InputMap.action_get_events(action):
        if event is InputEventJoypadMotion and event.axis == axis:
            if positive and event.axis_value > 0.0:
                return true
            if not positive and event.axis_value < 0.0:
                return true
    return false

func _has_mouse_button(action: String, button_index: int) -> bool:
    if not InputMap.has_action(action):
        return false
    for event in InputMap.action_get_events(action):
        if event is InputEventMouseButton and event.button_index == button_index:
            return true
    return false

func _run_tests() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    _check(packed != null, "main scene loads for controller support tests")
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

    _check(_has_axis("move_forward", JOY_AXIS_LEFT_Y, false) and _has_axis("move_back", JOY_AXIS_LEFT_Y, true), "left stick vertical axis maps forward and backward")
    _check(_has_axis("move_left", JOY_AXIS_LEFT_X, false) and _has_axis("move_right", JOY_AXIS_LEFT_X, true), "left stick horizontal axis maps strafing")
    _check(_has_axis("look_up", JOY_AXIS_RIGHT_Y, false) and _has_axis("look_down", JOY_AXIS_RIGHT_Y, true), "right stick vertical axis maps camera pitch")
    _check(_has_axis("look_left", JOY_AXIS_RIGHT_X, false) and _has_axis("look_right", JOY_AXIS_RIGHT_X, true), "right stick horizontal axis maps camera yaw")
    _check(_has_axis("fire", JOY_AXIS_TRIGGER_RIGHT, true) and _has_mouse_button("fire", MOUSE_BUTTON_LEFT), "right trigger and left mouse share the fire action")
    _check(_has_axis("aim", JOY_AXIS_TRIGGER_LEFT, true) and _has_mouse_button("aim", MOUSE_BUTTON_RIGHT), "left trigger and right mouse share the aim action")
    _check(_has_button("jump", JOY_BUTTON_A) and _has_button("crouch", JOY_BUTTON_B), "face buttons map jump and crouch")
    _check(_has_button("reload", JOY_BUTTON_X) and _has_button("throw_grenade", JOY_BUTTON_Y), "face buttons map reload and frag grenade")
    _check(_has_button("interact", JOY_BUTTON_LEFT_SHOULDER), "left shoulder maps mission interaction")
    _check(_has_button("sprint", JOY_BUTTON_LEFT_STICK) and _has_button("prone", JOY_BUTTON_RIGHT_STICK), "stick clicks map sprint and prone")
    _check(_has_button("pause", JOY_BUTTON_START), "controller Start button maps pause")

    var player: Node = scene.get_node("Player")
    player.set_physics_process(false)
    var yaw_before: float = player.rotation.y
    Input.action_press("look_right", 1.0)
    player._physics_process(0.1)
    Input.action_release("look_right")
    _check(not is_equal_approx(player.rotation.y, yaw_before), "right-stick look rotates the player camera rig")
    Input.action_press("look_up", 1.0)
    player._physics_process(0.1)
    Input.action_release("look_up")
    _check(absf(player.pitch) > 0.01, "right-stick vertical look updates camera pitch")
    Input.action_press("aim", 1.0)
    player._physics_process(0.016)
    Input.action_release("aim")
    _check(player.ads, "shared aim action activates aim-down-sights")
    Input.action_press("fire", 1.0)
    player.ammo = 10
    player.fire_cooldown = 0.0
    player._physics_process(0.016)
    Input.action_release("fire")
    _check(player.ammo == 9, "shared fire action fires the weapon")
    player.set_physics_process(true)

    var start_press := InputEventJoypadButton.new()
    start_press.button_index = JOY_BUTTON_START
    start_press.pressed = true
    scene._input(start_press)
    _check(paused, "controller Start opens the pause menu")
    var second_start_press := InputEventJoypadButton.new()
    second_start_press.button_index = JOY_BUTTON_START
    second_start_press.pressed = true
    scene._input(second_start_press)
    _check(not paused, "controller Start resumes gameplay")

    print("GAMEPAD RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
