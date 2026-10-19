shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.12, 0.17, 0.20);
uniform vec3 sky_horizon_color : source_color = vec3(0.52, 0.46, 0.36);
uniform vec3 cloud_color : source_color = vec3(0.47, 0.48, 0.45);
uniform vec3 sun_color : source_color = vec3(1.0, 0.72, 0.43);
uniform float cloud_coverage = 0.56;
uniform float cloud_contrast = 0.62;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloud_fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 5; octave++) {
        value += noise21(p) * amplitude;
        p = p * 2.03 + vec2(17.1, 9.2);
        amplitude *= 0.5;
    }
    return value;
}

void sky() {
    vec3 direction = normalize(EYEDIR);
    float height = clamp(direction.y * 0.5 + 0.5, 0.0, 1.0);
    float horizon_blend = smoothstep(0.03, 0.82, height);
    vec3 sky_base = mix(sky_horizon_color, sky_top_color, horizon_blend);

    // High, broken cloud banks drift slowly across the smoky late-afternoon sky.
    vec2 cloud_uv = direction.xz / max(direction.y + 0.34, 0.14);
    cloud_uv = cloud_uv * vec2(0.48, 0.68) + TIME * vec2(0.0032, 0.0011);
    float cloud_field = cloud_fbm(cloud_uv);
    float cloud_mask = smoothstep(cloud_coverage - 0.12, cloud_coverage + 0.13, cloud_field);
    cloud_mask *= smoothstep(-0.035, 0.16, direction.y);
    cloud_mask *= 1.0 - smoothstep(0.42, 0.70, direction.y);
    float cloud_lighting = 0.72 + cloud_field * cloud_contrast;
    vec3 cloud_tint = cloud_color * cloud_lighting;
    sky_base = mix(sky_base, cloud_tint, cloud_mask * 0.72);

    vec3 sun_direction = normalize(vec3(-0.46, 0.63, -0.39));
    float sun_disc = pow(max(dot(direction, sun_direction), 0.0), 240.0);
    float sun_halo = pow(max(dot(direction, sun_direction), 0.0), 13.0) * 0.11;
    sky_base += sun_color * (sun_disc * 0.75 + sun_halo);
    COLOR = sky_base;
}
