extends CharacterBody3D

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.5
const CROUCH_SPEED := 2.0
const PRONE_SPEED := 1.0
const JUMP_VELOCITY := 4.2
const MOUSE_SENSITIVITY := 0.0018
const MAG_SIZE := 30

var camera_pivot: Node3D
var camera: Camera3D
var weapon_root: Node3D
var hud: Node
var pitch := 0.0
var health := 100.0
var ammo := 30
var reserve := 120
var fire_cooldown := 0.0
var reload_time := 0.0
var is_reloading := false
var is_crouched := false
var is_prone := false
var stamina := 8.0
var bob_time := 0.0
var recoil := 0.0
var ads := false
var damage_flash := 0.0

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

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85), deg_to_rad(85))
        camera_pivot.rotation.x = pitch

func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    damage_flash = maxf(0.0, damage_flash - delta)
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
                hud.set_status("READY")
    if Input.is_action_just_pressed("reload"):
        _start_reload()
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
    var speed := WALK_SPEED
    if is_prone:
        speed = PRONE_SPEED
    elif is_crouched:
        speed = CROUCH_SPEED
    elif Input.is_action_pressed("sprint") and stamina > 0.1 and input_dir.length() > 0:
        speed = SPRINT_SPEED
        stamina = maxf(0.0, stamina - delta)
    else:
        stamina = minf(8.0, stamina + delta * 1.4)
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
    weapon_root.position = Vector3(0.28, -0.28 + sin(bob_time*0.5)*0.008, -0.55)
    weapon_root.rotation.x = recoil
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0 and not is_reloading:
        _fire()

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
    ammo -= 1
    fire_cooldown = 0.095
    recoil = 0.025 if ads else 0.045
    var spread := 0.002 if ads else 0.009
    var dir := -camera.global_transform.basis.z
    dir += camera.global_transform.basis.x * randf_range(-spread, spread)
    dir += camera.global_transform.basis.y * randf_range(-spread, spread)
    var from := camera.global_position
    var to := from + dir.normalized() * 180.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    query.collide_with_areas = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var collider = hit.get("collider")
        if collider and collider.has_method("take_damage"):
            var killed: bool = collider.take_damage(34.0, hit.get("position", to))
            if hud and hud.has_method("flash_hitmarker"):
                hud.flash_hitmarker(killed)
        _impact_spark(hit.get("position", to), hit.get("normal", Vector3.UP))
    if hud and hud.has_method("set_ammo"):
        hud.set_ammo(ammo, reserve)
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

func apply_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    if hud and hud.has_method("set_health"):
        hud.set_health(health)
    if health <= 0:
        health = 100.0
        ammo = MAG_SIZE
        reserve = 120
        is_reloading = false
        reload_time = 0.0
        global_position = Vector3(0,1.2,25)
        velocity = Vector3.ZERO
        if hud and hud.has_method("set_status"):
            hud.set_status("WOUNDED. BACK IN THE FIGHT.")
        if hud and hud.has_method("set_health"):
            hud.set_health(health)
        if hud and hud.has_method("set_ammo"):
            hud.set_ammo(ammo, reserve)
