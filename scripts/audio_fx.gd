extends RefCounted

const SAMPLE_RATE := 22050

static func create_gunshot() -> AudioStreamWAV:
    return _make_burst(0.24, false)

static func create_explosion() -> AudioStreamWAV:
    return _make_burst(0.78, true)

static func create_footstep() -> AudioStreamWAV:
    var duration := 0.13
    var sample_count := int(SAMPLE_RATE * duration)
    var pcm := PackedByteArray()
    pcm.resize(sample_count * 2)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for index in range(sample_count):
        var time := float(index) / float(SAMPLE_RATE)
        var noise := rng.randf_range(-1.0, 1.0)
        var transient := exp(-time * 38.0)
        var tail := exp(-time * 18.0)
        var thump := sin(TAU * 62.0 * time) * exp(-time * 18.0) * 0.42
        thump += sin(TAU * 115.0 * time) * exp(-time * 28.0) * 0.18
        var sample := noise * transient * 0.26 + noise * tail * 0.07 + thump
        sample *= clampf(1.0 - time / duration, 0.0, 1.0)
        pcm.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = pcm
    return stream

static func _make_burst(duration: float, explosion: bool) -> AudioStreamWAV:
    var sample_count := int(SAMPLE_RATE * duration)
    var pcm := PackedByteArray()
    pcm.resize(sample_count * 2)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for index in range(sample_count):
        var time := float(index) / float(SAMPLE_RATE)
        var noise := rng.randf_range(-1.0, 1.0)
        var sample := 0.0
        if explosion:
            var transient := exp(-time * 42.0)
            var tail := exp(-time * 4.6)
            var low_rumble := sin(TAU * 48.0 * time) * exp(-time * 4.0) * 0.62
            low_rumble += sin(TAU * 91.0 * time) * exp(-time * 7.0) * 0.22
            sample = noise * transient * 0.42 + noise * tail * 0.32 + low_rumble
        else:
            var transient := exp(-time * 82.0)
            var tail := exp(-time * 17.0)
            var weapon_body := sin(TAU * 75.0 * time) * exp(-time * 13.0) * 0.23
            weapon_body += sin(TAU * 155.0 * time) * exp(-time * 24.0) * 0.10
            sample = noise * (transient * 0.70 + tail * 0.16) + weapon_body
        sample *= clampf(1.0 - time / duration, 0.0, 1.0)
        pcm.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = pcm
    return stream
