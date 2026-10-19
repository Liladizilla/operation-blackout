extends StaticBody3D

@export var cover_size := Vector3(2.6, 2.2, 0.2)
@export var base_color := Color(0.30, 0.22, 0.14)
@export var max_health := 136.0

var health := 136.0
var is_destroyed := false
var visual_mesh: MeshInstance3D
var collision_shape: CollisionShape3D
var damage_material: StandardMaterial3D
var crack_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
    health = max_health
    visual_mesh = get_node_or_null("CoverMesh") as MeshInstance3D
    collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
    if is_instance_valid(visual_mesh):
        var source_material := visual_mesh.material_override as StandardMaterial3D
        if is_instance_valid(source_material):
            damage_material = source_material.duplicate() as StandardMaterial3D
            visual_mesh.material_override = damage_material
            base_color = source_material.albedo_color
    _build_crack_marks()

func _build_crack_marks() -> void:
    for index in range(3):
        var crack := MeshInstance3D.new()
        crack.name = "DamageCrack_%02d" % (index + 1)
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.035, 0.55 + float(index % 2) * 0.24, 0.018)
        crack.mesh = mesh
        crack.position = Vector3(
            -cover_size.x * 0.28 + float(index) * cover_size.x * 0.27,
            0.05 + float(index % 2) * 0.24,
            -cover_size.z * 0.5 - 0.012
        )
        crack.rotation_degrees.z = -18.0 if index % 2 == 0 else 23.0
        var crack_material := StandardMaterial3D.new()
        crack_material.albedo_color = base_color.darkened(0.72)
        crack_material.roughness = 1.0
        crack.material_override = crack_material
        crack.visible = false
        add_child(crack)
        crack_meshes.append(crack)

func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, _headshot: bool = false) -> bool:
    if is_destroyed:
        return true
    health = maxf(0.0, health - maxf(amount, 0.0))
    _update_damage_visuals()
    if health <= 0.0:
        _destroy_cover()
        return true
    return false

func _update_damage_visuals() -> void:
    var damage_ratio := clampf(1.0 - health / maxf(max_health, 1.0), 0.0, 1.0)
    if is_instance_valid(damage_material):
        damage_material.albedo_color = base_color.lerp(base_color.darkened(0.58), damage_ratio * 0.82)
    var visible_cracks := clampi(int(ceil(damage_ratio * float(crack_meshes.size()))), 0, crack_meshes.size())
    for index in range(crack_meshes.size()):
        crack_meshes[index].visible = index < visible_cracks

func _destroy_cover() -> void:
    if is_destroyed:
        return
    is_destroyed = true
    remove_from_group("arena_cover")
    if is_instance_valid(collision_shape):
        collision_shape.set_deferred("disabled", true)
    if is_instance_valid(visual_mesh):
        visual_mesh.visible = false
    for crack in crack_meshes:
        crack.visible = false
    _spawn_debris_effect()
    get_tree().create_timer(0.15).timeout.connect(queue_free)

func _spawn_debris_effect() -> void:
    var scene := get_tree().current_scene
    if not is_instance_valid(scene):
        return
    var debris := CPUParticles3D.new()
    debris.name = "DestructibleCoverDebris"
    debris.add_to_group("destructible_debris_effects")
    debris.amount = 18
    debris.lifetime = 0.7
    debris.one_shot = true
    debris.explosiveness = 1.0
    debris.emitting = true
    debris.direction = Vector3.UP
    debris.spread = 180.0
    debris.gravity = Vector3(0.0, -9.8, 0.0)
    debris.initial_velocity_min = 1.4
    debris.initial_velocity_max = 3.8
    debris.scale_amount_min = 0.05
    debris.scale_amount_max = 0.14
    debris.color = Color(base_color.r, base_color.g, base_color.b, 0.92)
    debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var debris_mesh := BoxMesh.new()
    debris_mesh.size = Vector3(0.11, 0.11, 0.11)
    var debris_material := StandardMaterial3D.new()
    debris_material.albedo_color = base_color
    debris_material.roughness = 1.0
    debris_mesh.material = debris_material
    debris.mesh = debris_mesh
    scene.add_child(debris)
    debris.global_position = global_position + Vector3.UP * (cover_size.y * 0.5)
    get_tree().create_timer(1.0).timeout.connect(debris.queue_free)
