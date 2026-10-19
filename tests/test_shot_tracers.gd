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
    _check(packed != null, "main scene loads for shot tracer tests")
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

    var enemies: Array = scene.enemies
    for enemy in enemies:
        enemy.set_physics_process(false)
    var enemy: Node = enemies[0]
    enemy.call("_try_shoot_player")

    var tracers: Array = get_nodes_in_group("shot_tracers")
    _check(tracers.size() == 1, "hostile shots spawn one visible tracer")
    if tracers.is_empty():
        quit(1)
        return
    var tracer := tracers[0] as MeshInstance3D
    _check(tracer.mesh is BoxMesh, "shot tracer uses a lightweight box mesh")
    var tracer_mesh := tracer.mesh as BoxMesh
    _check(tracer_mesh.size.z > 1.0 and tracer_mesh.size.x < 0.05, "tracer is long and thin rather than a heavy projectile")
    var material := tracer.material_override as StandardMaterial3D
    _check(is_instance_valid(material) and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "tracer remains visible without adding dynamic lighting")
    _check(float(tracer.get("lifetime")) > 0.0, "tracer has a bounded lifetime")

    await create_timer(0.16).timeout
    _check(get_nodes_in_group("shot_tracers").is_empty(), "shot tracers clean themselves up after fading")

    print("SHOT TRACER RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
