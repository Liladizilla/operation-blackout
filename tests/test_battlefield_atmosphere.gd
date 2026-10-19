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
    _check(packed != null, "main scene loads for battlefield atmosphere tests")
    if packed == null:
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    var atmosphere := scene.get_node_or_null("BattlefieldAtmosphere")
    _check(is_instance_valid(atmosphere), "battlefield atmosphere controller is attached to the scene")
    if not is_instance_valid(atmosphere):
        quit(1)
        return

    var wind := atmosphere.get_node_or_null("AmbientWindAudio") as AudioStreamPlayer
    _check(is_instance_valid(wind), "ambient wind has a dedicated audio player")
    _check(wind.stream is AudioStreamWAV, "wind ambience is generated without external audio assets")
    var wind_stream := wind.stream as AudioStreamWAV
    _check(wind_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and wind_stream.loop_end > 0, "wind audio is configured as a continuous loop")
    _check(wind.volume_db <= -20.0, "ambient wind is mixed quietly beneath combat audio")

    var ash := atmosphere.get_node_or_null("DriftingAsh") as CPUParticles3D
    _check(is_instance_valid(ash), "atmosphere includes drifting ash particles")
    _check(ash.emitting and ash.amount == 36 and ash.mesh != null, "ash uses a bounded lightweight particle setup")
    _check(ash.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "ash particles do not cast expensive shadows")

    var artillery := atmosphere.get_node_or_null("DistantArtilleryAudio") as AudioStreamPlayer3D
    var timer := atmosphere.get_node_or_null("DistantArtilleryTimer") as Timer
    _check(is_instance_valid(artillery) and artillery.stream is AudioStreamWAV, "distant artillery has a generated explosion sound")
    _check(artillery.max_distance >= 150.0 and artillery.volume_db <= -20.0, "distant artillery uses restrained long-range mixing")
    _check(is_instance_valid(timer) and timer.one_shot and timer.is_stopped() == false, "artillery events are scheduled with a one-shot timer")
    atmosphere._play_distant_artillery()
    _check(atmosphere.artillery_events == 1 and artillery.playing, "distant artillery event can be triggered and tracked")
    _check(absf(artillery.global_position.x) >= 44.0 or absf(artillery.global_position.z) >= 44.0, "artillery source is positioned on the distant perimeter")

    print("ATMOSPHERE RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
