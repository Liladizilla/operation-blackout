extends MeshInstance3D

const DEFAULT_LIFETIME := 12.0

var lifetime := DEFAULT_LIFETIME
var initial_lifetime := DEFAULT_LIFETIME
var impact_color := Color(0.075, 0.068, 0.052, 0.92)
var impact_material: StandardMaterial3D

func _ready() -> void:
    add_to_group("bullet_impacts")
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func configure(hit_position: Vector3, hit_normal: Vector3) -> void:
    var normal := hit_normal.normalized() if hit_normal.length_squared() > 0.01 else Vector3.UP
    var width := randf_range(0.065, 0.11)
    var mark_mesh := BoxMesh.new()
    mark_mesh.size = Vector3(width, width * randf_range(0.65, 0.95), 0.008)
    mesh = mark_mesh

    impact_material = StandardMaterial3D.new()
    impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    impact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    impact_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    impact_material.albedo_color = impact_color
    impact_material.roughness = 1.0
    material_override = impact_material

    global_position = hit_position + normal * 0.012
    var up := Vector3.UP
    if absf(normal.dot(up)) > 0.96:
        up = Vector3.FORWARD
    look_at(global_position + normal, up)

func _process(delta: float) -> void:
    lifetime = maxf(0.0, lifetime - delta)
    if is_instance_valid(impact_material):
        var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0) * impact_color.a
        impact_material.albedo_color = Color(impact_color.r, impact_color.g, impact_color.b, alpha)
    if lifetime <= 0.0:
        remove_from_group("bullet_impacts")
        queue_free()
