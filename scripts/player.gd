extends CharacterBody3D

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.5
const CROUCH_SPEED := 2.0
const PRONE_SPEED := 1.0
const JUMP_VELOCITY := 4.2
var mouse_sensitivity := 0.0018
const MAG_SIZE := 30
const MAX_STAMINA := 8.0
const STAMINA_REGEN_DELAY := 1.0
const SPENT_CASING_SCRIPT = preload("res://scripts/spent_casing.gd")
const BULLET_IMPACT_SCRIPT = preload("res://scripts/bullet_impact.gd")
const MAX_IMPACT_AUDIO := 8
const MAX_SPENT_CASINGS := 8
const MAX_BULLET_IMPACTS := 12
const STAMINA_REGEN_RATE := 1.4

var camera_pivot: Node3D
var camera: Camera3D
var weapon_audio: AudioStreamPlayer3D
var footstep_audio: AudioStreamPlayer3D
var weapon_root: Node3D
var weapon_magazine: MeshInstance3D
var hud: Node
var pitch := 0.0
var health := 100.0
var ammo := 30
var reserve := 120
var grenades := 2
var fire_cooldown := 0.0
var reload_time := 0.0
var is_reloading := false
var is_crouched := false
var is_prone := false
var stamina := MAX_STAMINA
var stamina_regen_delay := 0.0
var footstep_noise_timer := 0.0
var bob_time := 0.0
var recoil := 0.0
var ads := false
var damage_flash := 0.0
var respawn_invulnerability := 0.0
var recoil_recovery := 0.0
var lean_amount := 0.0
var lean_target := 0.0
var lean_blocked := false
var muzzle_light: OmniLight3D
var muzzle_flash_mesh: MeshInstance3D
var muzzle_flash_timer := 0.0

func _ready() -> void:
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.8
    var collision := CollisionShape3D.new()
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)
    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    camera_pivot.position.y = 1.58
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.fov = 78
    camera.current = true
    camera_pivot.add_child(camera)
    _build_view_weapon()
    _setup_weapon_audio()
    _setup_footstep_audio()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_view_weapon() -> void:
    weapon_root = Node3D.new()
    weapon_root.name = "WeaponRoot"
    weapon_root.position = Vector3(0.28, -0.28, -0.55)
    camera.add_child(weapon_root)
    var body := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.16, 0.17, 0.68)
    body.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.075,0.085,0.08)
    mat.metallic = 0.5
    mat.roughness = 0.48
    body.material_override = mat
    weapon_root.add_child(body)
    muzzle_light = OmniLight3D.new()
    muzzle_light.name = "MuzzleFlashLight"
    muzzle_light.position = Vector3(0.0, 0.0, -0.88)
    muzzle_light.light_color = Color(1.0, 0.62, 0.28)
    muzzle_light.light_energy = 0.0
    muzzle_light.omni_range = 4.5
    muzzle_light.shadow_enabled = false
    weapon_root.add_child(muzzle_light)
    muzzle_flash_mesh = MeshInstance3D.new()
    muzzle_flash_mesh.name = "MuzzleFlashGeometry"
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 0.055
    flash_mesh.height = 0.14
    muzzle_flash_mesh.mesh = flash_mesh
    muzzle_flash_mesh.position = Vector3(0.0, 0.0, -0.88)
    var flash_mat := StandardMaterial3D.new()
    flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash_mat.albedo_color = Color(1.0, 0.72, 0.34)
    flash_mat.emission_enabled = true
    flash_mat.emission = Color(1.0, 0.42, 0.12)
    muzzle_flash_mesh.material_override = flash_mat
    muzzle_flash_mesh.visible = false
    weapon_root.add_child(muzzle_flash_mesh)
    var barrel := MeshInstance3D.new()
    var barrel_mesh := BoxMesh.new()
    barrel_mesh.size = Vector3(0.055,0.055,0.48)
    barrel.mesh = barrel_mesh
    barrel.position = Vector3(0,0.015,-0.48)
    barrel.material_override = mat
    weapon_root.add_child(barrel)
    var sight := MeshInstance3D.new()
    var sight_mesh := BoxMesh.new()
    sight_mesh.size = Vector3(0.08,0.06,0.12)
    sight.mesh = sight_mesh
    sight.position = Vector3(0,0.105,-0.1)
    sight.material_override = mat
    weapon_root.add_child(sight)
    var stock := MeshInstance3D.new()
    var stock_mesh := BoxMesh.new()
    stock_mesh.size = Vector3(0.12, 0.14, 0.25)
    stock.mesh = stock_mesh
    stock.position = Vector3(0, -0.035, 0.34)
    stock.material_override = mat
    weapon_root.add_child(stock)
    var handguard := MeshInstance3D.new()
    var guard_mesh := BoxMesh.new()
    guard_mesh.size = Vector3(0.115, 0.12, 0.28)
    handguard.mesh = guard_mesh
    handguard.position = Vector3(0, -0.005, -0.34)
    handguard.material_override = mat
    weapon_root.add_child(handguard)
    weapon_magazine = MeshInstance3D.new()
    weapon_magazine.name = "WeaponMagazine"
    var mag_mesh := BoxMesh.new()
    mag_mesh.size = Vector3(0.105, 0.24, 0.15)
    weapon_magazine.mesh = mag_mesh
    weapon_magazine.position = Vector3(0, -0.18, -0.02)
    weapon_magazine.rotation.x = -0.12
    weapon_magazine.material_override = mat
    weapon_root.add_child(weapon_magazine)
    var front_sight := MeshInstance3D.new()
    var front_mesh := BoxMesh.new()
    front_mesh.size = Vector3(0.025, 0.09, 0.025)
    front_sight.mesh = front_mesh
    front_sight.position = Vector3(0, 0.075, -0.52)
    front_sight.material_override = mat
    weapon_root.add_child(front_sight)
    _build_view_arms()

func _build_view_arms() -> void:
    var sleeve_material := StandardMaterial3D.new()
    sleeve_material.albedo_color = Color(0.19, 0.22, 0.18)
    sleeve_material.roughness = 0.96
    var glove_material := StandardMaterial3D.new()
    glove_material.albedo_color = Color(0.055, 0.06, 0.055)
    glove_material.roughness = 1.0

    var left_forearm := MeshInstance3D.new()
    left_forearm.name = "LeftFirstPersonForearm"
    var left_mesh := CapsuleMesh.new()
    left_mesh.radius = 0.075
    left_mesh.height = 0.52
    left_forearm.mesh = left_mesh
    left_forearm.position = Vector3(-0.17, -0.15, -0.23)
    left_forearm.rotation = Vector3(-1.08, 0.0, -0.28)
    left_forearm.material_override = sleeve_material
    weapon_root.add_child(left_forearm)

    var right_forearm := MeshInstance3D.new()
    right_forearm.name = "RightFirstPersonForearm"
    var right_mesh := CapsuleMesh.new()
    right_mesh.radius = 0.078
    right_mesh.height = 0.46
    right_forearm.mesh = right_mesh
    right_forearm.position = Vector3(0.17, -0.17, 0.11)
    right_forearm.rotation = Vector3(-0.78, 0.0, 0.24)
    right_forearm.material_override = sleeve_material
    weapon_root.add_child(right_forearm)

    var left_hand := MeshInstance3D.new()
    left_hand.name = "LeftFirstPersonGlove"
    var left_hand_mesh := BoxMesh.new()
    left_hand_mesh.size = Vector3(0.13, 0.09, 0.14)
    left_hand.mesh = left_hand_mesh
    left_hand.position = Vector3(-0.055, -0.075, -0.43)
    left_hand.rotation.z = -0.16
    left_hand.material_override = glove_material
    weapon_root.add_child(left_hand)

    var right_hand := MeshInstance3D.new()
    right_hand.name = "RightFirstPersonGlove"
    var right_hand_mesh := BoxMesh.new()
    right_hand_mesh.size = Vector3(0.13, 0.09, 0.14)
    right_hand.mesh = right_hand_mesh
    right_hand.position = Vector3(0.095, -0.105, 0.015)
    right_hand.rotation.z = 0.18
    right_hand.material_override = glove_material
    weapon_root.add_child(right_hand)

func _input(event: InputEvent) -> void:
    # Read mouse motion before full-screen HUD Controls can consume it.
    # The camera should only rotate while the game owns the captured mouse.
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-85), deg_to_rad(85))
        camera_pivot.rotation.x = pitch

func _setup_weapon_audio() -> void:
    weapon_audio = AudioStreamPlayer3D.new()
    weapon_audio.name = "WeaponFireAudio"
    var audio_fx = load("res://scripts/audio_fx.gd")
    weapon_audio.stream = audio_fx.create_gunshot()
    weapon_audio.volume_db = -5.0
    weapon_audio.unit_size = 5.0
    weapon_audio.max_distance = 55.0
    add_child(weapon_audio)

func _setup_footstep_audio() -> void:
    footstep_audio = AudioStreamPlayer3D.new()
    footstep_audio.name = "FootstepAudio"
    var audio_fx = load("res://scripts/audio_fx.gd")
    footstep_audio.stream = audio_fx.create_footstep()
    footstep_audio.volume_db = -8.0
    footstep_audio.unit_size = 3.5
    footstep_audio.max_distance = 26.0
    add_child(footstep_audio)

func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    damage_flash = maxf(0.0, damage_flash - delta)
    respawn_invulnerability = maxf(0.0, respawn_invulnerability - delta)
    if muzzle_flash_timer > 0.0:
        muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
        if muzzle_flash_timer == 0.0:
            muzzle_light.light_energy = 0.0
            muzzle_flash_mesh.visible = false
    if is_reloading:
        reload_time -= delta
        if reload_time <= 0:
            var needed := MAG_SIZE - ammo
            var loaded := mini(needed, reserve)
            ammo += loaded
            reserve -= loaded
            is_reloading = false
            if hud and hud.has_method("set_ammo"):
                hud.set_ammo(ammo, reserve)
            if hud and hud.has_method("set_status"):
                hud.set_status("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   Z PRONE   RMB AIM   LMB FIRE   R RELOAD   F INTERACT   G GRENADE")
    if Input.is_action_just_pressed("reload"):
        _start_reload()
    if Input.is_action_just_pressed("throw_grenade"):
        _throw_grenade()
    ads = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    if Input.is_action_just_pressed("crouch"):
        is_crouched = not is_crouched
        if is_crouched:
            is_prone = false
        _set_stance()
    if Input.is_action_just_pressed("prone"):
        is_prone = not is_prone
        is_crouched = false
        _set_stance()
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x,0,input_dir.y)).normalized()
    var sprinting := not is_prone and not is_crouched and Input.is_action_pressed("sprint") and input_dir.length() > 0.0 and stamina > 0.1
    _update_stamina(delta, sprinting)
    var speed := WALK_SPEED
    if is_prone:
        speed = PRONE_SPEED
    elif is_crouched:
        speed = CROUCH_SPEED
    elif sprinting:
        speed = SPRINT_SPEED
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    elif Input.is_action_just_pressed("jump") and not is_prone:
        velocity.y = JUMP_VELOCITY
    velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
    move_and_slide()
    _update_lean(delta, Input.get_axis("lean_left", "lean_right"))
    var moving_on_foot := is_on_floor() and input_dir.length() > 0.1 and Vector2(velocity.x, velocity.z).length() > 0.45
    _update_footstep_noise(delta, moving_on_foot, sprinting)
    bob_time += delta * (velocity.length() * 0.65)
    var bob_scale := 0.0 if input_dir.length() < 0.1 else (0.012 if ads else 0.035)
    if is_crouched:
        bob_scale *= 0.4
    if is_prone:
        bob_scale *= 0.1
    camera_pivot.position.y = lerpf(camera_pivot.position.y, (0.72 if is_prone else (1.12 if is_crouched else 1.58)) + sin(bob_time) * bob_scale, delta * 9.0)
    camera.fov = lerpf(camera.fov, 62.0 if ads else 78.0, delta * 10.0)
    recoil = lerpf(recoil, 0.0, delta * 7.0)
    var reload_duration := 2.7 if ammo <= 0 else 2.0
    var reload_progress := clampf(1.0 - reload_time / reload_duration, 0.0, 1.0) if is_reloading else 0.0
    _update_magazine_reload(reload_progress)
    var reload_drop := sin(reload_progress * PI) * 0.14
    var weapon_base := Vector3(0.06, -0.17, -0.43) if ads else Vector3(0.28, -0.28, -0.55)
    weapon_root.position = Vector3(
        weapon_base.x + lean_amount * 0.18,
        weapon_base.y + sin(bob_time * 0.5) * (0.004 if ads else 0.008) + recoil * 0.65 - reload_drop,
        weapon_base.z + recoil * 1.8 + reload_drop * 0.3
    )
    weapon_root.rotation.x = recoil + reload_drop * 1.4
    weapon_root.rotation.y = lerpf(weapon_root.rotation.y, -input_dir.x * 0.035, delta * 8.0)
    var weapon_roll_target := (-0.22 if is_reloading else 0.0) - lean_amount * 0.16
    weapon_root.rotation.z = lerpf(weapon_root.rotation.z, weapon_roll_target, delta * 7.0)
    camera.rotation.z = lerpf(camera.rotation.z, -input_dir.x * 0.006 + sin(bob_time * 0.4) * 0.0015 - lean_amount * 0.12, delta * 4.0)
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0 and not is_reloading:
        _fire()

func _update_lean(delta: float, requested_axis: float) -> void:
    var desired := clampf(requested_axis, -1.0, 1.0) * 0.32
    lean_blocked = false
    if absf(desired) > 0.01:
        var height := 0.72 if is_prone else (1.12 if is_crouched else 1.35)
        var origin := global_position + Vector3.UP * height
        var target := origin + global_transform.basis.x * desired
        var query := PhysicsRayQueryParameters3D.create(origin, target)
        query.exclude = [get_rid()]
        query.collision_mask = 1
        if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
            desired = 0.0
            lean_blocked = true
    lean_target = desired
    lean_amount = lerpf(lean_amount, lean_target, clampf(delta * 10.0, 0.0, 1.0))
    camera_pivot.position.x = lerpf(camera_pivot.position.x, lean_amount, clampf(delta * 12.0, 0.0, 1.0))

func _update_footstep_noise(delta: float, moving: bool, sprinting: bool) -> void:
    footstep_noise_timer = maxf(0.0, footstep_noise_timer - delta)
    if not moving or footstep_noise_timer > 0.0:
        return
    var radius := 10.0
    var step_volume := -8.0
    var step_pitch := randf_range(0.94, 1.04)
    if is_prone:
        radius = 1.5
        footstep_noise_timer = 0.95
        step_volume = -17.0
        step_pitch = 0.72
    elif is_crouched:
        radius = 4.5
        footstep_noise_timer = 0.72
        step_volume = -12.0
        step_pitch = 0.84
    elif sprinting:
        radius = 20.0
        footstep_noise_timer = 0.32
        step_volume = -3.0
        step_pitch = 1.12
    else:
        footstep_noise_timer = 0.52
    if is_instance_valid(footstep_audio):
        footstep_audio.volume_db = step_volume
        footstep_audio.pitch_scale = step_pitch
        footstep_audio.play()
    var active_scene := get_tree().current_scene
    if is_instance_valid(active_scene) and active_scene.has_method("report_noise"):
        active_scene.report_noise(global_position, radius, "FOOTSTEP", self)

func _update_stamina(delta: float, sprinting: bool) -> void:
    if sprinting:
        stamina = maxf(0.0, stamina - delta)
        stamina_regen_delay = STAMINA_REGEN_DELAY
        return
    if stamina_regen_delay > 0.0:
        var delay_elapsed := minf(stamina_regen_delay, delta)
        stamina_regen_delay = maxf(0.0, stamina_regen_delay - delta)
        var recovery_delta := delta - delay_elapsed
        if recovery_delta > 0.0:
            stamina = minf(MAX_STAMINA, stamina + recovery_delta * STAMINA_REGEN_RATE)
        return
    stamina = minf(MAX_STAMINA, stamina + delta * STAMINA_REGEN_RATE)

func _set_stance() -> void:
    var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if col:
        var shape := col.shape as CapsuleShape3D
        if is_prone:
            shape.height = 0.75
            shape.radius = 0.3
            col.position.y = 0.38
        elif is_crouched:
            shape.height = 1.2
            shape.radius = 0.34
            col.position.y = 0.6
        else:
            shape.height = 1.8
            shape.radius = 0.36
            col.position.y = 0.9

func _fire() -> void:
    if ammo <= 0:
        _start_reload()
        return
    if is_instance_valid(weapon_audio):
        weapon_audio.pitch_scale = randf_range(0.96, 1.04)
        weapon_audio.play()
    var active_scene := get_tree().current_scene
    if is_instance_valid(active_scene) and active_scene.has_method("report_noise"):
        active_scene.report_noise(global_position, 58.0, "GUNSHOT", self)
    ammo -= 1
    _spawn_spent_casing()
    fire_cooldown = 0.095
    recoil = 0.055 if ads else 0.09
    weapon_root.rotation.y = randf_range(-0.018, 0.018)
    camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - recoil * (0.48 if ads else 0.7), deg_to_rad(-85), deg_to_rad(85))
    pitch = camera_pivot.rotation.x
    var spread := 0.002 if ads else 0.009
    var dir := -camera.global_transform.basis.z
    dir += camera.global_transform.basis.x * randf_range(-spread, spread)
    dir += camera.global_transform.basis.y * randf_range(-spread, spread)
    var from := camera.global_position
    var to := from + dir.normalized() * 180.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    query.collide_with_areas = true
    query.collision_mask = 3
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var shot_end: Vector3 = hit.get("position", to) if not hit.is_empty() else to
    var direct_target: Node = hit.get("collider") if not hit.is_empty() else null
    if direct_target is Area3D and direct_target.has_meta("headshot"):
        direct_target = direct_target.get_parent()
    _suppress_nearby_enemies(from, shot_end, direct_target)
    var confirmed_hit := false
    if not hit.is_empty():
        var collider = hit.get("collider")
        var damage_target: Node = collider
        var headshot := false
        if collider is Area3D and collider.has_meta("headshot"):
            damage_target = collider.get_parent()
            headshot = true
        confirmed_hit = is_instance_valid(damage_target) and damage_target.is_in_group("enemies")
        if damage_target and damage_target.has_method("take_damage"):
            var killed: bool = damage_target.take_damage(34.0, hit.get("position", to), headshot)
            if hud and hud.has_method("flash_hitmarker"):
                hud.flash_hitmarker(killed, headshot)
        if not confirmed_hit and collider is StaticBody3D:
            _spawn_bullet_impact(hit.get("position", to), hit.get("normal", Vector3.UP))
            _play_impact_audio(hit.get("position", to))
            var impact_scene := get_tree().current_scene
            if is_instance_valid(impact_scene) and impact_scene.has_method("report_noise"):
                impact_scene.report_noise(hit.get("position", to), 24.0, "IMPACT", self)
        _impact_spark(hit.get("position", to), hit.get("normal", Vector3.UP))
    var scene := get_tree().current_scene
    if is_instance_valid(scene) and scene.has_method("register_shot"):
        scene.register_shot(confirmed_hit)
    if hud and hud.has_method("set_ammo"):
        hud.set_ammo(ammo, reserve)
    muzzle_light.light_energy = randf_range(1.4, 2.2)
    muzzle_flash_mesh.visible = true
    muzzle_flash_timer = 0.045
    if hud and hud.has_method("flash_muzzle"):
        hud.flash_muzzle()

func _suppress_nearby_enemies(line_start: Vector3, line_end: Vector3, direct_target: Node = null) -> void:
    var segment := line_end - line_start
    var segment_length_squared := segment.length_squared()
    if segment_length_squared <= 0.001:
        return
    for candidate in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(candidate) or candidate == direct_target or not candidate.has_method("apply_suppression"):
            continue
        var enemy := candidate as Node3D
        if not is_instance_valid(enemy) or float(enemy.get("health")) <= 0.0:
            continue
        var target_point := enemy.global_position + Vector3.UP * 0.9
        var along := clampf((target_point - line_start).dot(segment) / segment_length_squared, 0.0, 1.0)
        var nearest_point := line_start + segment * along
        if target_point.distance_to(nearest_point) <= 1.35:
            enemy.call("apply_suppression", global_position)

func _spawn_spent_casing() -> void:
    var active_scene := get_tree().current_scene
    if not is_instance_valid(active_scene) or not is_instance_valid(weapon_root):
        return
    var existing := get_tree().get_nodes_in_group("spent_casings")
    while existing.size() >= MAX_SPENT_CASINGS:
        var oldest := existing.pop_front() as Node
        if is_instance_valid(oldest):
            oldest.remove_from_group("spent_casings")
            oldest.queue_free()

    var casing := RigidBody3D.new()
    casing.name = "SpentCasing"
    casing.set_script(SPENT_CASING_SCRIPT)
    casing.mass = 0.018
    casing.gravity_scale = 1.0
    casing.linear_damp = 1.4
    casing.angular_damp = 2.0
    casing.collision_layer = 0
    casing.collision_mask = 1
    var physics_material := PhysicsMaterial.new()
    physics_material.friction = 0.62
    physics_material.bounce = 0.12
    casing.physics_material_override = physics_material

    var casing_mesh := MeshInstance3D.new()
    casing_mesh.name = "CasingMesh"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.025
    cylinder.bottom_radius = 0.025
    cylinder.height = 0.09
    cylinder.radial_segments = 8
    casing_mesh.mesh = cylinder
    casing_mesh.rotation.z = PI * 0.5
    var brass := StandardMaterial3D.new()
    brass.albedo_color = Color(0.58, 0.39, 0.13, 1.0)
    brass.metallic = 0.72
    brass.roughness = 0.36
    brass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    casing_mesh.material_override = brass
    casing.add_child(casing_mesh)

    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var casing_shape := CylinderShape3D.new()
    casing_shape.radius = 0.025
    casing_shape.height = 0.09
    collision.shape = casing_shape
    collision.rotation.z = PI * 0.5
    casing.add_child(collision)

    active_scene.add_child(casing)
    casing.global_position = weapon_root.global_transform * Vector3(0.18, 0.04, 0.0)
    casing.linear_velocity = camera.global_transform.basis.x * randf_range(1.2, 2.1) + Vector3.UP * randf_range(0.8, 1.6) + (-camera.global_transform.basis.z) * randf_range(-0.4, 0.4)
    casing.angular_velocity = Vector3(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))

func _spawn_bullet_impact(pos: Vector3, normal: Vector3) -> void:
    var active_scene := get_tree().current_scene
    if not is_instance_valid(active_scene):
        return
    var existing := get_tree().get_nodes_in_group("bullet_impacts")
    while existing.size() >= MAX_BULLET_IMPACTS:
        var oldest := existing.pop_front() as Node
        if is_instance_valid(oldest):
            oldest.remove_from_group("bullet_impacts")
            oldest.queue_free()
    var mark := MeshInstance3D.new()
    mark.name = "BulletImpactMark"
    mark.set_script(BULLET_IMPACT_SCRIPT)
    active_scene.add_child(mark)
    mark.call("configure", pos, normal)

func _play_impact_audio(pos: Vector3) -> void:
    var active_scene := get_tree().current_scene
    if not is_instance_valid(active_scene):
        return
    var existing := get_tree().get_nodes_in_group("impact_audio")
    while existing.size() >= MAX_IMPACT_AUDIO:
        var oldest := existing.pop_front() as Node
        if is_instance_valid(oldest):
            # Remove the oldest emitter immediately so rapid-fire impacts cannot
            # temporarily exceed the cap before deferred frees are processed.
            oldest.free()
    var audio_fx = load("res://scripts/audio_fx.gd")
    var emitter := AudioStreamPlayer3D.new()
    emitter.name = "BulletImpactAudio"
    emitter.add_to_group("impact_audio")
    emitter.stream = audio_fx.create_impact()
    emitter.volume_db = -10.0
    emitter.unit_size = 4.0
    emitter.max_distance = 32.0
    active_scene.add_child(emitter)
    emitter.global_position = pos
    emitter.play()
    emitter.finished.connect(emitter.queue_free)

func _impact_spark(pos: Vector3, normal: Vector3) -> void:
    var active_scene := get_tree().current_scene
    if not is_instance_valid(active_scene):
        return
    var existing := get_tree().get_nodes_in_group("impact_spark_bursts")
    while existing.size() >= 8:
        var oldest := existing.pop_front() as Node
        if is_instance_valid(oldest):
            oldest.queue_free()

    # A short GPU particle burst gives hard impacts directional, scattered sparks
    # instead of the old single glowing bead. The burst is deliberately brief.
    var burst := GPUParticles3D.new()
    burst.name = "ImpactSparkBurst"
    burst.add_to_group("impact_spark_bursts")
    burst.amount = 10
    burst.lifetime = 0.24
    burst.one_shot = true
    burst.explosiveness = 1.0
    burst.local_coords = false
    burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var particles := ParticleProcessMaterial.new()
    particles.direction = normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
    particles.spread = 38.0
    particles.initial_velocity_min = 1.4
    particles.initial_velocity_max = 4.2
    particles.gravity = Vector3(0.0, -10.0, 0.0)
    particles.scale_min = 0.025
    particles.scale_max = 0.065
    particles.damping_min = 2.0
    particles.damping_max = 5.0
    burst.process_material = particles

    var spark_mesh := SphereMesh.new()
    spark_mesh.radius = 0.025
    spark_mesh.height = 0.05
    burst.draw_pass_1 = spark_mesh
    var spark_material := StandardMaterial3D.new()
    spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark_material.albedo_color = Color(1.0, 0.62, 0.22)
    spark_material.emission_enabled = true
    spark_material.emission = Color(1.0, 0.3, 0.055)
    spark_material.emission_energy_multiplier = 2.0
    burst.material_override = spark_material

    active_scene.add_child(burst)
    burst.global_position = pos + (normal.normalized() * 0.035 if normal.length_squared() > 0.01 else Vector3.UP * 0.035)
    burst.emitting = true
    burst.finished.connect(burst.queue_free)

func _update_magazine_reload(progress: float) -> void:
    if not is_instance_valid(weapon_magazine):
        return
    if not is_reloading:
        weapon_magazine.visible = true
        weapon_magazine.position = Vector3(0.0, -0.18, -0.02)
        weapon_magazine.rotation.x = -0.12
        return
    if progress < 0.24:
        weapon_magazine.visible = true
        weapon_magazine.position = Vector3(0.0, -0.18, -0.02)
        weapon_magazine.rotation.x = -0.12
    elif progress < 0.62:
        weapon_magazine.visible = false
    else:
        weapon_magazine.visible = true
        var insert_progress := clampf((progress - 0.62) / 0.20, 0.0, 1.0)
        insert_progress = insert_progress * insert_progress * (3.0 - 2.0 * insert_progress)
        weapon_magazine.position = Vector3(0.0, lerpf(-0.42, -0.18, insert_progress), -0.02)
        weapon_magazine.rotation.x = lerpf(-0.72, -0.12, insert_progress)

func _start_reload() -> void:
    if is_reloading or ammo == MAG_SIZE or reserve <= 0:
        return
    is_reloading = true
    reload_time = 2.0 if ammo > 0 else 2.7
    if hud and hud.has_method("set_status"):
        hud.set_status("RELOADING")

func _throw_grenade() -> void:
    if grenades <= 0:
        if hud and hud.has_method("set_status"):
            hud.set_status("NO FRAG GRENADES REMAINING")
        return
    var scene := get_tree().current_scene
    if not is_instance_valid(scene):
        return
    var direction := -camera.global_transform.basis.z
    var grenade := RigidBody3D.new()
    grenade.name = "FragGrenade"
    grenade.set_script(load("res://scripts/grenade.gd"))
    scene.add_child(grenade)
    grenade.global_position = camera.global_position + direction * 0.75 - Vector3.UP * 0.12
    grenade.linear_velocity = direction * 12.0 + Vector3.UP * 4.2
    grenade.angular_velocity = Vector3(randf_range(-5.0, 5.0), randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
    grenades -= 1
    if is_instance_valid(scene) and scene.has_method("register_grenade_used"):
        scene.register_grenade_used()
    if hud and hud.has_method("set_grenades"):
        hud.set_grenades(grenades)
    if hud and hud.has_method("set_status"):
        hud.set_status("FRAG GRENADE DEPLOYED")

func _try_interact() -> void:
    var from := camera.global_position
    var to := from + (-camera.global_transform.basis.z) * 3.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var collider = hit.get("collider")
        if collider and collider.has_method("interact"):
            collider.interact(self)

func apply_damage(amount: float, source_position: Vector3 = Vector3.ZERO) -> void:
    if respawn_invulnerability > 0.0:
        return
    health = maxf(0.0, health - amount)
    if hud and hud.has_method("show_damage_direction"):
        hud.show_damage_direction(global_position, global_transform.basis, source_position)
    if hud and hud.has_method("set_health"):
        hud.set_health(health)
    if health <= 0:
        health = 100.0
        ammo = MAG_SIZE
        reserve = 120
        is_reloading = false
        reload_time = 0.0
        respawn_invulnerability = 1.5
        global_position = Vector3(0,1.2,25)
        velocity = Vector3.ZERO
        camera_pivot.rotation = Vector3.ZERO
        pitch = 0.0
        if hud and hud.has_method("set_status"):
            hud.set_status("WOUNDED. BACK IN THE FIGHT.")
        if hud and hud.has_method("set_health"):
            hud.set_health(health)
        if hud and hud.has_method("set_ammo"):
            hud.set_ammo(ammo, reserve)
