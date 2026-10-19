shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.3, 0.29, 0.26, 1.0);
uniform float surface_kind = 0.0;
uniform float detail_scale = 1.0;
varying vec3 world_position;
varying vec3 world_normal;

float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash31(i);
    float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);
    return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 p = world_position;
    float broad = noise3(p * 0.42 * detail_scale);
    float medium = noise3(p * 2.8 * detail_scale);
    float grain = noise3(p * 17.0 * detail_scale);
    float fleck = noise3(p * 39.0 * detail_scale);
    float weathering = noise3(vec3(p.x * 0.7, p.y * 0.18, p.z * 0.7));
    float variation = (broad - 0.5) * 0.23 + (medium - 0.5) * 0.12 + (grain - 0.5) * 0.075;
    variation += (fleck - 0.5) * 0.045;

    if (surface_kind < 0.5) {
        float pores = smoothstep(0.61, 0.83, grain) * 0.12;
        float stains = smoothstep(0.42, 0.78, weathering) * 0.13;
        ALBEDO = base_color.rgb * (0.80 + variation - pores - stains);
        ROUGHNESS = 0.96;
    } else if (surface_kind < 1.5) {
        float aggregate = smoothstep(0.48, 0.76, grain) * 0.10;
        float worn = smoothstep(0.57, 0.78, broad) * 0.11;
        ALBEDO = base_color.rgb * (0.82 + variation * 0.68 + worn - aggregate);
        ROUGHNESS = 0.91;
    } else {
        float grit = smoothstep(0.46, 0.76, grain) * 0.16;
        float damp = smoothstep(0.60, 0.86, weathering) * 0.10;
        ALBEDO = base_color.rgb * (0.78 + variation + grit - damp);
        ROUGHNESS = 1.0;
    }

    float edge_wear = smoothstep(0.72, 0.96, fleck) * 0.035;
    ALBEDO = clamp(ALBEDO + vec3(edge_wear), vec3(0.0), vec3(1.0));
}
