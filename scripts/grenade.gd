extends RigidBody3D

const FUSE_SECONDS := 2.2
const BLAST_RADIUS := 6.0
const MAX_DAMAGE := 85.0

var fuse_timer := FUSE_SECONDS
var exploded := false

func _ready() -> void:
    collision_layer = 1
    collision_mask = 1
    mass = 0.35
    gravity_scale = 1.0
    linear_damp = 0.18
    angular_damp = 0.45
    var physics_material := PhysicsMaterial.new()
    physics_material.bounce = 0.28
    physics_material.friction = 0.82
    physics_material_override = physics_material

    var collision := CollisionShape3D.new()
    collision.name = "GrenadeCollision"
    var shape := SphereShape3D.new()
    shape.radius = 0.13
    collision.shape = shape
    add_child(collision)

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "GrenadeMesh"
    var mesh := SphereMesh.new()
    mesh.radius = 0.13
    mesh.height = 0.26
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.16, 0.19, 0.15)
    material.metallic = 0.25
    material.roughness = 0.72
    mesh_instance.material_override = material
    add_child(mesh_instance)

func _physics_process(delta: float) -> void:
    if exploded:
        return
    fuse_timer -= delta
    if fuse_timer <= 0.0:
        _explode()

func _damage_for_distance(distance: float) -> float:
    var falloff := clampf(1.0 - distance / BLAST_RADIUS, 0.0, 1.0)
    return MAX_DAMAGE * falloff

func _explode() -> void:
    if exploded:
        return
    exploded = true
    var space := get_world_3d().direct_space_state
    var blast_shape := SphereShape3D.new()
    blast_shape.radius = BLAST_RADIUS
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = blast_shape
    query.transform = Transform3D(Basis(), global_position)
    query.collision_mask = 1
    query.collide_with_areas = false
    query.collide_with_bodies = true
    query.exclude = [get_rid()]
    var hits := space.intersect_shape(query, 32)
    var damaged: Dictionary = {}
    for hit in hits:
        var collider := hit.get("collider") as Node3D
        if not is_instance_valid(collider):
            continue
        var instance_id := collider.get_instance_id()
        if damaged.has(instance_id):
            continue
        var distance := global_position.distance_to(collider.global_position)
        var damage := _damage_for_distance(distance)
        if damage < 5.0:
            continue
        if collider.is_in_group("enemies") and collider.has_method("take_damage"):
            damage *= _line_of_sight_factor(space, collider)
            collider.take_damage(damage, global_position, false)
            _apply_blast_impulse(collider)
            damaged[instance_id] = true
        elif collider.is_in_group("player") and collider.has_method("apply_damage"):
            damage *= _line_of_sight_factor(space, collider)
            collider.apply_damage(damage, global_position)
            _apply_blast_impulse(collider)
            damaged[instance_id] = true
    _spawn_explosion_effect()
    queue_free()

func _apply_blast_impulse(target: Node3D) -> void:
    if not target is CharacterBody3D:
        return
    var push_direction := target.global_position - global_position
    push_direction.y = 0.0
    if push_direction.length_squared() < 0.01:
        push_direction = Vector3.FORWARD
    target.velocity += push_direction.normalized() * 4.0 + Vector3.UP * 1.2

func _line_of_sight_factor(space: PhysicsDirectSpaceState3D, target: Node3D) -> float:
    var target_point := target.global_position + Vector3.UP * 0.8
    var query := PhysicsRayQueryParameters3D.create(global_position, target_point)
    query.exclude = [get_rid()]
    query.collision_mask = 1
    var obstruction := space.intersect_ray(query)
    if obstruction.is_empty() or obstruction.get("collider") == target:
        return 1.0
    return 0.35

func _spawn_explosion_effect() -> void:
    var scene := get_tree().current_scene
    if not is_instance_valid(scene):
        return
    var audio := AudioStreamPlayer3D.new()
    audio.name = "GrenadeExplosionAudio"
    var audio_fx = load("res://scripts/audio_fx.gd")
    audio.stream = audio_fx.create_explosion()
    audio.volume_db = -3.0
    audio.unit_size = 6.0
    audio.max_distance = 75.0
    scene.add_child(audio)
    audio.global_position = global_position
    audio.finished.connect(audio.queue_free)
    audio.play()

    var flash := MeshInstance3D.new()
    flash.name = "GrenadeExplosionFlash"
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 1.0
    flash_mesh.height = 2.0
    flash.mesh = flash_mesh
    flash.scale = Vector3.ONE * 2.2
    var flash_material := StandardMaterial3D.new()
    flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    flash_material.albedo_color = Color(1.0, 0.42, 0.12, 0.42)
    flash_material.emission_enabled = true
    flash_material.emission = Color(1.0, 0.18, 0.035)
    flash.material_override = flash_material
    scene.add_child(flash)
    flash.global_position = global_position

    var light := OmniLight3D.new()
    light.name = "GrenadeExplosionLight"
    light.light_color = Color(1.0, 0.38, 0.12)
    light.light_energy = 3.0
    light.omni_range = BLAST_RADIUS * 1.4
    light.shadow_enabled = false
    scene.add_child(light)
    light.global_position = global_position
    var timer := get_tree().create_timer(0.16)
    timer.timeout.connect(flash.queue_free)
    timer.timeout.connect(light.queue_free)
