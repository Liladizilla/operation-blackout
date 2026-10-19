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
    _check(packed != null, "main scene loads for destructible cover tests")
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

    var covers: Array = get_nodes_in_group("destructible_cover")
    _check(covers.size() == 3, "three destructible field-cover panels spawn")
    if covers.size() != 3:
        quit(1)
        return

    var cover: Node = covers[0]
    _check(cover is StaticBody3D, "destructible cover retains solid world collision")
    _check(cover.get_node_or_null("CoverMesh") is MeshInstance3D, "cover has a visible panel mesh")
    _check(cover.get_node_or_null("CollisionShape3D") is CollisionShape3D, "cover has a matching collision shape")
    _check(cover.is_in_group("arena_cover"), "intact destructible panels are valid tactical cover")
    _check(is_equal_approx(cover.health, cover.max_health), "cover begins at full structural health")

    var survived: bool = cover.take_damage(34.0, Vector3.ZERO, false)
    _check(not survived and is_equal_approx(cover.health, 102.0), "first rifle hit damages but does not destroy the panel")
    _check(cover.get_node_or_null("DamageCrack_01").visible, "damaged cover reveals visible fracture marks")
    _check(not cover.get_node("CollisionShape3D").disabled, "partially damaged cover remains solid")

    survived = cover.take_damage(200.0, Vector3.ZERO, false)
    _check(survived and cover.is_destroyed, "lethal damage destroys the cover")
    await physics_frame
    _check(cover.get_node("CollisionShape3D").disabled, "destroyed cover disables its collision")
    _check(not cover.get_node("CoverMesh").visible, "destroyed panel mesh disappears")
    _check(not cover.is_in_group("arena_cover"), "destroyed cover stops being offered to hostile cover selection")
    _check(get_nodes_in_group("destructible_debris_effects").size() == 1, "destruction emits a bounded debris burst")
    _check(get_nodes_in_group("destructible_cover").size() == 3, "cover remains tracked until its short cleanup delay")

    await create_timer(1.1).timeout
    _check(not is_instance_valid(cover), "destroyed cover cleans up after the collision and debris transition")
    _check(get_nodes_in_group("destructible_debris_effects").is_empty(), "debris effect cleans up automatically")

    print("DESTRUCTIBLE COVER RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
