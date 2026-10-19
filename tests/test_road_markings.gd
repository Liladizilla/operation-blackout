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
    _check(packed != null, "main scene loads for road marking tests")
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

    var markings: Array = get_nodes_in_group("road_markings")
    var centerline_marks: Array = get_nodes_in_group("road_centerline_markings")
    var edge_marks: Array = get_nodes_in_group("road_edge_markings")
    var crosswalk_marks: Array = get_nodes_in_group("crosswalk_markings")
    var alley_marks: Array = get_nodes_in_group("service_lane_markings")
    _check(markings.size() == 23, "main road and service lane have 23 dedicated markings")
    _check(centerline_marks.size() == 6 and edge_marks.size() == 2, "centerline dashes and worn road edges are present")
    _check(crosswalk_marks.size() == 8, "crosswalk contains eight separate paint strips")
    _check(alley_marks.size() == 7, "service alley has its own interrupted markings")

    var collisionless := true
    var visible_meshes := true
    var centerline_clear_of_blocked_sections := true
    for marking in markings:
        collisionless = collisionless and marking.get_node_or_null("CollisionShape3D") == null
        var mesh := marking.get_child(0) as MeshInstance3D
        visible_meshes = visible_meshes and is_instance_valid(mesh) and mesh.visible and mesh.mesh is BoxMesh
    for marking in centerline_marks:
        centerline_clear_of_blocked_sections = centerline_clear_of_blocked_sections and marking.position.z > -28.0 and marking.position.z < 27.0

    _check(collisionless, "road paint does not create invisible collision obstacles")
    _check(visible_meshes, "all road markings render as lightweight visible meshes")
    _check(centerline_clear_of_blocked_sections, "centerline avoids road sections blocked by buildings")

    print("ROAD MARKING RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
