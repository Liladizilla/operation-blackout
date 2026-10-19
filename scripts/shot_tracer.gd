extends MeshInstance3D

const DEFAULT_LIFETIME := 0.095

var lifetime := DEFAULT_LIFETIME
var initial_lifetime := DEFAULT_LIFETIME
var tracer_color := Color(1.0, 0.45, 0.16, 0.9)

func _ready() -> void:
    add_to_group("shot_tracers")
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func configure(start_position: Vector3, end_position: Vector3, tint: Color) -> void:
    var direction := end_position - start_position
    var distance := direction.length()
    if distance < 0.1:
        queue_free()
        return
    tracer_color = tint
    lifetime = DEFAULT_LIFETIME
    initial_lifetime = DEFAULT_LIFETIME
    var tracer_mesh := BoxMesh.new()
    tracer_mesh.size = Vector3(0.018, 0.018, distance)
    mesh = tracer_mesh
    var tracer_material := StandardMaterial3D.new()
    tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    tracer_material.albedo_color = tracer_color
    tracer_material.emission_enabled = true
    tracer_material.emission = Color(tracer_color.r, tracer_color.g, tracer_color.b)
    tracer_material.roughness = 1.0
    material_override = tracer_material
    global_position = (start_position + end_position) * 0.5
    look_at(end_position, Vector3.UP)

func _process(delta: float) -> void:
    lifetime = maxf(0.0, lifetime - delta)
    if lifetime <= 0.0:
        queue_free()
        return
    var material := material_override as StandardMaterial3D
    if is_instance_valid(material):
        var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0) * tracer_color.a
        material.albedo_color = Color(tracer_color.r, tracer_color.g, tracer_color.b, alpha)
