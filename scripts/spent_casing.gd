extends RigidBody3D

const DEFAULT_LIFETIME := 3.2

var lifetime := DEFAULT_LIFETIME
var initial_lifetime := DEFAULT_LIFETIME
var casing_material: StandardMaterial3D

func _ready() -> void:
    add_to_group("spent_casings")
    var mesh_node := get_node_or_null("CasingMesh") as MeshInstance3D
    if is_instance_valid(mesh_node):
        casing_material = mesh_node.material_override as StandardMaterial3D

func _process(delta: float) -> void:
    lifetime = maxf(0.0, lifetime - delta)
    if is_instance_valid(casing_material):
        var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0)
        var current := casing_material.albedo_color
        casing_material.albedo_color = Color(current.r, current.g, current.b, alpha)
    if lifetime <= 0.0:
        remove_from_group("spent_casings")
        queue_free()
