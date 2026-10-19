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
    _check(packed != null, "main scene loads for footstep audio tests")
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
    var audio := player.get_node("FootstepAudio") as AudioStreamPlayer3D
    _check(is_instance_valid(audio), "player has a dedicated positional footstep emitter")
    _check(audio.stream is AudioStreamWAV, "footsteps use generated WAV audio without external assets")
    _check(audio.stream.get_length() >= 0.1 and audio.max_distance >= 20.0, "footstep audio has a usable duration and hearing range")

    player.is_prone = true
    player.is_crouched = false
    player.footstep_noise_timer = 0.0
    player._update_footstep_noise(0.016, true, false)
    _check(is_equal_approx(audio.volume_db, -17.0) and is_equal_approx(audio.pitch_scale, 0.72), "prone footsteps are soft and low-pitched")

    player.is_prone = false
    player.is_crouched = true
    player.footstep_noise_timer = 0.0
    player._update_footstep_noise(0.016, true, false)
    _check(is_equal_approx(audio.volume_db, -12.0) and is_equal_approx(audio.pitch_scale, 0.84), "crouched footsteps use a restrained sound profile")

    player.is_crouched = false
    player.footstep_noise_timer = 0.0
    player._update_footstep_noise(0.016, true, true)
    _check(is_equal_approx(audio.volume_db, -3.0) and is_equal_approx(audio.pitch_scale, 1.12), "sprinting produces louder, sharper footsteps")
    _check(is_equal_approx(player.footstep_noise_timer, 0.32), "sprinting footsteps use a faster cadence")

    player.footstep_noise_timer = 0.0
    player._update_footstep_noise(0.016, true, false)
    _check(is_equal_approx(audio.volume_db, -8.0) and is_equal_approx(player.footstep_noise_timer, 0.52), "normal walking uses a moderate footstep cadence")

    print("FOOTSTEP AUDIO RESULT: ", passed, " checks passed; failed=", failed)
    quit(1 if failed else 0)
