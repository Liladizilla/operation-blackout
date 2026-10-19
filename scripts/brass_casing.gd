extends Node3D

const CASING_LIFETIME := 2.1
const FLOOR_HEIGHT := 0.045

var lifetime := CASING_LIFETIME
var velocity := Vector3.ZERO
var spin_velocity := Vector3(13.0, 8.0, 11.0)
var has_bounced := false
var casing_material: StandardMaterial3D

func _ready() -> void:
    add_to_group("brass_casings")
    var casing_mesh := MeshInstance3D.new()
    casing_mesh.name = "BrassCasingMesh"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.0065
    cylinder.bottom_radius = 0.009
    cylinder.height = 0.065
    cylinder.radial_segments = 6
    casing_mesh.mesh = cylinder
    casing_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    casing_material = StandardMaterial3D.new()
    casing_material.albedo_color = Color(0.70, 0.43, 0.13)
    casing_material.metallic = 0.82
    casing_material.roughness = 0.24
    casing_mesh.material_override = casing_material
    add_child(casing_mesh)

func configure(start_position: Vector3, initial_velocity: Vector3) -> void:
    global_position = start_position
    velocity = initial_velocity
    spin_velocity = Vector3(randf_range(9.0, 17.0), randf_range(7.0, 14.0), randf_range(8.0, 18.0))

func _process(delta: float) -> void:
    lifetime = maxf(0.0, lifetime - delta)
    velocity.y -= 9.8 * delta
    var next_position := global_position + velocity * delta
    if next_position.y <= FLOOR_HEIGHT:
        next_position.y = FLOOR_HEIGHT
        if velocity.y < -1.2 and not has_bounced:
            velocity.y = absf(velocity.y) * 0.22
            velocity.x *= 0.55
            velocity.z *= 0.55
            has_bounced = true
        else:
            velocity.y = 0.0
            velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
            velocity.z = move_toward(velocity.z, 0.0, delta * 3.0)
    global_position = next_position
    rotation += spin_velocity * delta
    if lifetime <= 0.0:
        queue_free()
        return
    if lifetime < 0.35 and is_instance_valid(casing_material):
        var alpha := clampf(lifetime / 0.35, 0.0, 1.0)
        casing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        casing_material.albedo_color = Color(0.70, 0.43, 0.13, alpha)
