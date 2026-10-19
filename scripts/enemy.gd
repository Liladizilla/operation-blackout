extends CharacterBody3D

var health := 100.0
var player: Node3D
var state := "SEARCH"
var think_timer := 0.0
var fire_timer := 0.7
var strafe_sign := 1.0
var body_mesh: MeshInstance3D

func _ready() -> void:
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.8
    var col := CollisionShape3D.new()
    col.shape = capsule
    col.position.y = 0.9
    add_child(col)
    body_mesh = MeshInstance3D.new()
    var body := CapsuleMesh.new()
    body.radius = 0.36
    body.height = 1.65
    body_mesh.mesh = body
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.22,0.25,0.22)
    mat.roughness = 0.9
    body_mesh.material_override = mat
    body_mesh.position.y = 0.92
    add_child(body_mesh)
    var head_mesh := MeshInstance3D.new()
    var head := SphereMesh.new()
    head.radius = 0.19
    head.height = 0.38
    head_mesh.mesh = head
    head_mesh.position.y = 1.86
    var hm := StandardMaterial3D.new()
    hm.albedo_color = Color(0.35,0.29,0.23)
    head_mesh.material_override = hm
    add_child(head_mesh)
    var rifle := MeshInstance3D.new()
    var rifle_mesh := BoxMesh.new()
    rifle_mesh.size = Vector3(0.08,0.08,0.75)
    rifle.mesh = rifle_mesh
    rifle.position = Vector3(0.32,1.25,-0.2)
    rifle.rotation.x = -0.12
    rifle.material_override = mat
    add_child(rifle)
    player = get_tree().get_first_node_in_group("player")
    if not player:
        player = get_tree().current_scene.get_node_or_null("Player") as Node3D
    add_to_group("enemies")

func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    if not is_instance_valid(player):
        player = get_tree().current_scene.get_node_or_null("Player") as Node3D
        return
    think_timer -= delta
    fire_timer -= delta
    if think_timer <= 0:
        think_timer = 0.25
        var distance := global_position.distance_to(player.global_position)
        var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP*1.2, player.global_position + Vector3.UP*1.3)
        query.exclude = [get_rid()]
        var sight := get_world_3d().direct_space_state.intersect_ray(query)
        if distance < 30 and (sight.is_empty() or sight.get("collider") == player):
            state = "COMBAT"
        elif distance < 42:
            state = "INVESTIGATE"
        else:
            state = "SEARCH"
        if distance < 11 and randf() < 0.35:
            strafe_sign *= -1
    var target_dir := Vector3.ZERO
    var distance_to_player := global_position.distance_to(player.global_position)
    if state == "COMBAT":
        var to_player := player.global_position - global_position
        to_player.y = 0
        if distance_to_player > 10:
            target_dir = to_player.normalized()
        elif distance_to_player < 6:
            target_dir = -to_player.normalized()
        else:
            target_dir = Vector3(-to_player.z,0,to_player.x).normalized() * strafe_sign * 0.35
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
        if distance_to_player < 25 and fire_timer <= 0:
            fire_timer = randf_range(0.65,1.25)
            _try_shoot_player()
    elif state == "INVESTIGATE":
        var to_player := player.global_position - global_position
        to_player.y = 0
        target_dir = to_player.normalized() * 0.6
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    velocity.x = move_toward(velocity.x, target_dir.x * 2.1, delta * 4.0)
    velocity.z = move_toward(velocity.z, target_dir.z * 2.1, delta * 4.0)
    move_and_slide()

func _try_shoot_player() -> void:
    var from := global_position + Vector3.UP*1.35
    var to := player.global_position + Vector3.UP*1.2
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.get("collider") == player:
        if player.has_method("apply_damage"):
            player.apply_damage(7.0)

func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO) -> bool:
    health -= amount
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.55,0.12,0.08) if health > 0 else Color(0.08,0.09,0.08)
    body_mesh.material_override = mat
    if health <= 0:
        var scene := get_tree().current_scene
        if scene and scene.has_method("enemy_killed"):
            scene.enemy_killed(self)
        queue_free()
        return true
    return false
