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
const STAMINA_REGEN_RATE := 1.4

var camera_pivot: Node3D
var camera: Camera3D
var weapon_audio: AudioStreamPlayer3D
var weapon_root: Node3D
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
var bob_time := 0.0
var recoil := 0.0
var ads := false
var damage_flash := 0.0
var respawn_invulnerability := 0.0
var recoil_recovery := 0.0
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
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_view_weapon() -> void:
    weapon_root = Node3D.new()
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
    var magazine := MeshInstance3D.new()
    var mag_mesh := BoxMesh.new()
    mag_mesh.size = Vector3(0.105, 0.24, 0.15)
    magazine.mesh = mag_mesh
    magazine.position = Vector3(0, -0.18, -0.02)
    magazine.rotation.x = -0.12
    magazine.material_override = mat
    weapon_root.add_child(magazine)
    var front_sight := MeshInstance3D.new()
    var front_mesh := BoxMesh.new()
    front_mesh.size = Vector3(0.025, 0.09, 0.025)
    front_sight.mesh = front_mesh
    front_sight.position = Vector3(0, 0.075, -0.52)
    front_sight.material_override = mat
    weapon_root.add_child(front_sight)

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
    var reload_drop := sin(reload_progress * PI) * 0.14
    var weapon_base := Vector3(0.06, -0.17, -0.43) if ads else Vector3(0.28, -0.28, -0.55)
    weapon_root.position = Vector3(
        weapon_base.x,
        weapon_base.y + sin(bob_time * 0.5) * (0.004 if ads else 0.008) + recoil * 0.65 - reload_drop,
        weapon_base.z + recoil * 1.8 + reload_drop * 0.3
    )
    weapon_root.rotation.x = recoil + reload_drop * 1.4
    weapon_root.rotation.y = lerpf(weapon_root.rotation.y, -input_dir.x * 0.035, delta * 8.0)
    weapon_root.rotation.z = lerpf(weapon_root.rotation.z, -0.22 if is_reloading else 0.0, delta * 7.0)
    camera.rotation.z = lerpf(camera.rotation.z, -input_dir.x * 0.006 + sin(bob_time * 0.4) * 0.0015, delta * 4.0)
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0 and not is_reloading:
        _fire()

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
    ammo -= 1
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

func _impact_spark(pos: Vector3, normal: Vector3) -> void:
    var marker := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.045
    mesh.height = 0.09
    marker.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.95,0.58,0.18)
    mat.emission_enabled = true
    mat.emission = Color(0.9,0.28,0.05)
    marker.material_override = mat
    get_tree().current_scene.add_child(marker)
    marker.global_position = pos + normal * 0.04
    var timer := get_tree().create_timer(0.18)
    timer.timeout.connect(marker.queue_free)

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
