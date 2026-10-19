extends CharacterBody3D

var health := 100.0
var player: Node3D
var state := "SEARCH"
var think_timer := 0.0
var fire_timer := 0.7
var strafe_sign := 1.0
var body_mesh: MeshInstance3D
var body_material: StandardMaterial3D
var enemy_muzzle_flash: MeshInstance3D
var enemy_muzzle_light: OmniLight3D
var muzzle_flash_timer := 0.0
var hit_flash_timer := 0.0
var last_known_position := Vector3.ZERO
var cover_goal := Vector3.ZERO
var cover_timer := 0.0
var suppression_timer := 0.0
var alert_memory_timer := 0.0
var alert_broadcast_timer := 0.0

func _ready() -> void:
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.6
    var col := CollisionShape3D.new()
    col.shape = capsule
    col.position.y = 0.8
    add_child(col)
    body_mesh = MeshInstance3D.new()
    var body := CapsuleMesh.new()
    body.radius = 0.36
    body.height = 1.65
    body_mesh.mesh = body
    body_material = StandardMaterial3D.new()
    body_material.albedo_color = Color(0.22,0.25,0.22)
    body_material.roughness = 0.9
    body_mesh.material_override = body_material
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
    var head_area := Area3D.new()
    head_area.name = "HeadHitZone"
    head_area.collision_layer = 2
    head_area.collision_mask = 0
    head_area.set_meta("headshot", true)
    var head_collision := CollisionShape3D.new()
    var head_shape := SphereShape3D.new()
    head_shape.radius = 0.22
    head_collision.shape = head_shape
    head_collision.position.y = 1.82
    head_area.add_child(head_collision)
    add_child(head_area)
    var vest := MeshInstance3D.new()
    var vest_mesh := BoxMesh.new()
    vest_mesh.size = Vector3(0.54, 0.55, 0.25)
    vest.mesh = vest_mesh
    vest.position = Vector3(0, 1.05, -0.015)
    var vest_mat := StandardMaterial3D.new()
    vest_mat.albedo_color = Color(0.12, 0.14, 0.12)
    vest_mat.roughness = 1.0
    vest.material_override = vest_mat
    add_child(vest)
    var rifle := MeshInstance3D.new()
    var rifle_mesh := BoxMesh.new()
    rifle_mesh.size = Vector3(0.08,0.08,0.75)
    rifle.mesh = rifle_mesh
    rifle.position = Vector3(0.32,1.25,-0.2)
    rifle.rotation.x = -0.12
    var rifle_material := StandardMaterial3D.new()
    rifle_material.albedo_color = Color(0.10,0.12,0.10)
    rifle_material.metallic = 0.28
    rifle_material.roughness = 0.72
    rifle.material_override = rifle_material
    add_child(rifle)

    enemy_muzzle_flash = MeshInstance3D.new()
    enemy_muzzle_flash.name = "EnemyMuzzleFlash"
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 0.07
    flash_mesh.height = 0.16
    enemy_muzzle_flash.mesh = flash_mesh
    enemy_muzzle_flash.position = Vector3(0.32, 1.25, -0.62)
    var flash_material := StandardMaterial3D.new()
    flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_material.albedo_color = Color(1.0, 0.67, 0.28)
    flash_material.emission_enabled = true
    flash_material.emission = Color(1.0, 0.34, 0.08)
    enemy_muzzle_flash.material_override = flash_material
    enemy_muzzle_flash.visible = false
    add_child(enemy_muzzle_flash)

    enemy_muzzle_light = OmniLight3D.new()
    enemy_muzzle_light.name = "EnemyMuzzleFlashLight"
    enemy_muzzle_light.position = enemy_muzzle_flash.position
    enemy_muzzle_light.light_color = Color(1.0, 0.48, 0.18)
    enemy_muzzle_light.light_energy = 0.0
    enemy_muzzle_light.omni_range = 3.2
    enemy_muzzle_light.shadow_enabled = false
    add_child(enemy_muzzle_light)

    player = get_tree().get_first_node_in_group("player")
    if not player:
        player = get_tree().current_scene.get_node_or_null("Player") as Node3D
    add_to_group("enemies")

func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    if muzzle_flash_timer > 0.0:
        muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
        if muzzle_flash_timer == 0.0:
            enemy_muzzle_flash.visible = false
            enemy_muzzle_light.light_energy = 0.0
    if hit_flash_timer > 0.0:
        hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
        if hit_flash_timer == 0.0 and health > 0.0:
            body_material.albedo_color = Color(0.22,0.25,0.22)
    if not is_instance_valid(player):
        player = get_tree().current_scene.get_node_or_null("Player") as Node3D
        return
    think_timer -= delta
    fire_timer -= delta
    cover_timer = maxf(0.0, cover_timer - delta)
    suppression_timer = maxf(0.0, suppression_timer - delta)
    alert_memory_timer = maxf(0.0, alert_memory_timer - delta)
    alert_broadcast_timer = maxf(0.0, alert_broadcast_timer - delta)
    if think_timer <= 0:
        think_timer = 0.25
        var distance := global_position.distance_to(player.global_position)
        var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, player.global_position + Vector3.UP * 1.3)
        query.exclude = [get_rid()]
        var sight := get_world_3d().direct_space_state.intersect_ray(query)
        var sees_player: bool = distance < 30.0 and (sight.is_empty() or sight.get("collider") == player)
        if suppression_timer > 0.0:
            state = "REPOSITION"
            last_known_position = player.global_position
            alert_memory_timer = 5.0
            if cover_timer <= 0.0:
                cover_goal = _choose_cover(player.global_position)
                cover_timer = 1.6
        elif sees_player:
            if state != "COMBAT":
                _broadcast_alert(player.global_position)
            state = "COMBAT"
            last_known_position = player.global_position
            alert_memory_timer = 5.0
        elif alert_memory_timer > 0.0:
            state = "INVESTIGATE"
        elif distance < 42.0:
            state = "INVESTIGATE"
        else:
            state = "SEARCH"
        if distance < 15.0 and randf() < 0.28:
            strafe_sign *= -1.0
        if not sees_player and suppression_timer <= 0.0 and cover_timer <= 0.0:
            cover_goal = _choose_cover(last_known_position if last_known_position != Vector3.ZERO else player.global_position)
            cover_timer = randf_range(2.5, 4.0)
    var target_dir := Vector3.ZERO
    var distance_to_player := global_position.distance_to(player.global_position)
    if state == "COMBAT":
        var to_player := player.global_position - global_position
        to_player.y = 0
        if distance_to_player > 13:
            target_dir = to_player.normalized()
        elif distance_to_player < 5.5:
            target_dir = -to_player.normalized()
        else:
            target_dir = Vector3(-to_player.z,0,to_player.x).normalized() * strafe_sign * 0.42
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
        if distance_to_player < 25 and fire_timer <= 0:
            fire_timer = randf_range(0.65,1.25)
            _try_shoot_player()
    elif state == "REPOSITION":
        var to_cover := cover_goal - global_position
        to_cover.y = 0.0
        if to_cover.length() > 1.1:
            target_dir = to_cover.normalized()
        else:
            # If no nearby cover is reachable, at least break the player's firing line.
            var retreat := global_position - player.global_position
            retreat.y = 0.0
            target_dir = retreat.normalized()
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
    elif state == "INVESTIGATE":
        var to_cover := cover_goal - global_position
        to_cover.y = 0.0
        if to_cover.length() > 1.0:
            target_dir = to_cover.normalized() * 0.72
            look_at(Vector3(last_known_position.x, global_position.y, last_known_position.z), Vector3.UP)
        else:
            state = "SEARCH"
    target_dir = _avoid_obstacles(target_dir)
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    velocity.x = move_toward(velocity.x, target_dir.x * 2.1, delta * 4.0)
    velocity.z = move_toward(velocity.z, target_dir.z * 2.1, delta * 4.0)
    move_and_slide()

func _avoid_obstacles(direction: Vector3) -> Vector3:
    var forward := direction
    forward.y = 0.0
    var speed_scale := minf(forward.length(), 1.0)
    if speed_scale < 0.01:
        return Vector3.ZERO
    forward = forward.normalized()
    var origin := global_position + Vector3.UP * 0.25
    var space := get_world_3d().direct_space_state
    var forward_hit := _steering_ray(space, origin, forward)
    if forward_hit.is_empty() or forward_hit.get("collider") == player:
        return forward * speed_scale

    # Try either side of the obstruction before committing to a new cover goal.
    var left := forward.rotated(Vector3.UP, -0.72)
    var right := forward.rotated(Vector3.UP, 0.72)
    var left_hit := _steering_ray(space, origin, left)
    var right_hit := _steering_ray(space, origin, right)
    if left_hit.is_empty() and right_hit.is_empty():
        return (left if global_position.x <= cover_goal.x else right) * speed_scale
    if left_hit.is_empty():
        return left * speed_scale
    if right_hit.is_empty():
        return right * speed_scale

    var wall_normal: Vector3 = forward_hit.get("normal", Vector3.ZERO)
    wall_normal.y = 0.0
    if wall_normal.length_squared() > 0.01:
        return (wall_normal.normalized() + left * 0.45).normalized() * speed_scale
    return left * speed_scale

func _steering_ray(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 2.0)
    query.exclude = [get_rid()]
    query.collision_mask = 1
    return space.intersect_ray(query)

func _broadcast_alert(threat_position: Vector3) -> void:
    if alert_broadcast_timer > 0.0:
        return
    alert_broadcast_timer = 1.5
    for ally in get_tree().get_nodes_in_group("enemies"):
        if ally == self or not is_instance_valid(ally) or not ally.has_method("hear_alert"):
            continue
        if ally.global_position.distance_to(global_position) <= 36.0:
            ally.hear_alert(threat_position)

func hear_alert(threat_position: Vector3) -> void:
    if health <= 0.0:
        return
    last_known_position = threat_position
    alert_memory_timer = 5.0
    if state != "COMBAT":
        state = "INVESTIGATE"
        cover_goal = _choose_cover(threat_position)
        cover_timer = 1.2
    think_timer = minf(think_timer, 0.1)

func _choose_cover(threat_position: Vector3) -> Vector3:
    # Candidate positions sit near concrete barriers and wreckage in the arena.
    # Stand beside cover rather than targeting the solid center of each obstacle.
    var candidates := [
        Vector3(-9.1, 0, -10), Vector3(-7, 0, -11.5),
        Vector3(9.0, 0, -18), Vector3(7, 0, -19.4),
        Vector3(-7.0, 0, 7), Vector3(-5, 0, 5.5),
        Vector3(8.0, 0, 19), Vector3(6, 0, 17.5),
        Vector3(-14.0, 0, 25), Vector3(-12, 0, 23.5),
        Vector3(15.0, 0, -1), Vector3(13, 0, -2.4),
        Vector3(-2, 0, -30.2),
        Vector3(-28.5, 0, -24), Vector3(-28.5, 0, -12),
        Vector3(-28.5, 0, 0), Vector3(-28.5, 0, 12),
        Vector3(-28.5, 0, 24)
    ]
    # Add positions beside actual service-alley caches so nearby enemies can use
    # the expanded district rather than treating the original arena as the map.
    for cache in get_tree().get_nodes_in_group("ammo_caches"):
        if not is_instance_valid(cache):
            continue
        var cache_position: Vector3 = cache.global_position
        for offset in [Vector3(-1.65, 0, 0), Vector3(1.65, 0, 0), Vector3(0, 0, -1.35), Vector3(0, 0, 1.35)]:
            candidates.append(cache_position + offset)
    for crate in get_tree().get_nodes_in_group("service_alley_crates"):
        if not is_instance_valid(crate):
            continue
        var crate_position: Vector3 = crate.global_position
        for offset in [Vector3(-1.65, 0, 0), Vector3(1.65, 0, 0), Vector3(0, 0, -1.35), Vector3(0, 0, 1.35)]:
            candidates.append(crate_position + offset)
    var best := global_position
    var best_score := -INF
    for candidate in candidates:
        var flat: Vector3 = candidate - global_position
        flat.y = 0.0
        if flat.length() > 18.0:
            continue
        var away: Vector3 = candidate - threat_position
        away.y = 0.0
        var score: float = away.length() * 0.65 - flat.length() * 0.55 + randf_range(-0.6, 0.6)
        var cover_ray := PhysicsRayQueryParameters3D.create(threat_position + Vector3.UP * 1.25, candidate + Vector3.UP * 1.0)
        cover_ray.exclude = [get_rid()]
        var obstruction := get_world_3d().direct_space_state.intersect_ray(cover_ray)
        if not obstruction.is_empty():
            score += 5.0
        if score > best_score:
            best_score = score
            best = candidate
    return best

func _try_shoot_player() -> void:
    _show_muzzle_flash()
    var from := global_position + Vector3.UP*1.35
    var to := player.global_position + Vector3.UP*1.2
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.get("collider") == player:
        if player.has_method("apply_damage"):
            player.apply_damage(7.0, global_position)

func _show_muzzle_flash() -> void:
    enemy_muzzle_flash.visible = true
    enemy_muzzle_light.light_energy = 1.6
    muzzle_flash_timer = 0.055

func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, headshot: bool = false) -> bool:
    health -= amount * (3.0 if headshot else 1.0)
    # Incoming fire alerts the unit and forces a short break from its current firing lane.
    if is_instance_valid(player):
        last_known_position = player.global_position
        state = "REPOSITION"
        suppression_timer = 1.1 if headshot else 0.75
        cover_timer = 0.0
        think_timer = 0.0
        alert_memory_timer = 5.0
        _broadcast_alert(player.global_position)
    if health > 0.0:
        body_material.albedo_color = Color(0.55,0.12,0.08)
        hit_flash_timer = 0.14
    else:
        body_material.albedo_color = Color(0.08,0.09,0.08)
        hit_flash_timer = 0.0
    if health <= 0:
        var scene := get_tree().current_scene
        if scene and scene.has_method("enemy_killed"):
            scene.enemy_killed(self)
        queue_free()
        return true
    return false
