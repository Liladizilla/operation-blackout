extends Node3D

const AUDIO_FX = preload("res://scripts/audio_fx.gd")
const ASH_PARTICLE_COUNT := 36

var wind_audio: AudioStreamPlayer
var artillery_audio: AudioStreamPlayer3D
var artillery_timer: Timer
var random := RandomNumberGenerator.new()
var artillery_events := 0

func _ready() -> void:
    random.randomize()
    _build_wind_bed()
    _build_drifting_ash()
    _build_distant_artillery()

func _build_wind_bed() -> void:
    wind_audio = AudioStreamPlayer.new()
    wind_audio.name = "AmbientWindAudio"
    wind_audio.stream = AUDIO_FX.create_wind_loop()
    wind_audio.volume_db = -27.0
    wind_audio.bus = "Master"
    add_child(wind_audio)
    wind_audio.play()

func _build_drifting_ash() -> void:
    var ash := CPUParticles3D.new()
    ash.name = "DriftingAsh"
    ash.amount = ASH_PARTICLE_COUNT
    ash.lifetime = 8.0
    ash.preprocess = 2.0
    ash.emitting = true
    ash.direction = Vector3(1.0, 0.12, 0.25)
    ash.spread = 115.0
    ash.gravity = Vector3(0.0, -0.015, 0.0)
    ash.initial_velocity_min = 0.12
    ash.initial_velocity_max = 0.42
    ash.angular_velocity_min = -8.0
    ash.angular_velocity_max = 8.0
    ash.scale_amount_min = 0.025
    ash.scale_amount_max = 0.07
    ash.color = Color(0.52, 0.49, 0.41, 0.42)
    var fleck := SphereMesh.new()
    fleck.radius = 0.045
    fleck.height = 0.09
    var ash_material := StandardMaterial3D.new()
    ash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ash_material.albedo_color = Color(0.62, 0.57, 0.46, 0.62)
    ash_material.roughness = 1.0
    fleck.material = ash_material
    ash.mesh = fleck
    ash.position = Vector3(0.0, 2.0, 0.0)
    add_child(ash)

func _build_distant_artillery() -> void:
    artillery_audio = AudioStreamPlayer3D.new()
    artillery_audio.name = "DistantArtilleryAudio"
    artillery_audio.stream = AUDIO_FX.create_explosion()
    artillery_audio.volume_db = -25.0
    artillery_audio.unit_size = 22.0
    artillery_audio.max_distance = 180.0
    artillery_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    add_child(artillery_audio)

    artillery_timer = Timer.new()
    artillery_timer.name = "DistantArtilleryTimer"
    artillery_timer.one_shot = true
    artillery_timer.wait_time = random.randf_range(7.0, 12.0)
    artillery_timer.timeout.connect(_on_artillery_timer_timeout)
    add_child(artillery_timer)
    artillery_timer.start()

func _on_artillery_timer_timeout() -> void:
    _play_distant_artillery()
    artillery_timer.wait_time = random.randf_range(14.0, 24.0)
    artillery_timer.start()

func _play_distant_artillery() -> void:
    if not is_instance_valid(artillery_audio):
        return
    var x := random.randf_range(-44.0, 44.0)
    var z := random.randf_range(-44.0, 44.0)
    match random.randi_range(0, 3):
        0:
            x = -46.0
        1:
            x = 46.0
        2:
            z = -46.0
        _:
            z = 46.0
    artillery_audio.global_position = Vector3(x, 1.0, z)
    artillery_audio.pitch_scale = random.randf_range(0.82, 1.08)
    artillery_audio.play()
    artillery_events += 1
