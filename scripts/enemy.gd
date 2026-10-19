extends CharacterBody3D

const SHOT_TRACER_SCRIPT = preload("res://scripts/shot_tracer.gd")

var health := 100.0
var shot_damage := 7.0
var detection_range := 30.0
var fire_interval_min := 0.65
var fire_interval_max := 1.25
var difficulty := "STANDARD"
var combat_role := "RIFLEMAN"
var player: Node3D
var state := "SEARCH"
var think_timer := 0.0
var fire_timer := 0.7
var strafe_sign := 1.0
var flank_timer := 0.0
var flank_goal := Vector3.ZERO
var visual_root: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var gait_time := 0.0
var is_dead := false
var death_timer := 0.0
var death_roll_direction := 1.0
const DEATH_ANIMATION_SECONDS := 0.62
var body_mesh: MeshInstance3D
var body_material: StandardMaterial3D
var enemy_muzzle_flash: MeshInstance3D
var enemy_muzzle_light: OmniLight3D
var enemy_fire_audio: AudioStreamPlayer3D
var muzzle_flash_timer := 0.0
var hit_flash_timer := 0.0
var hit_reaction_timer := 0.0
var hit_reaction_direction := 1.0
var last_known_position := Vector3.ZERO
var cover_goal := Vector3.ZERO
var last_cover_goal := Vector3.ZERO
var has_last_cover_goal := false
var cover_timer := 0.0
var suppression_timer := 0.0
var low_health_retreat_used := false
var alert_memory_timer := 0.0
var alert_broadcast_timer := 0.0
var patrol_goal := Vector3.ZERO
var patrol_index := -1
var patrol_pause_timer := 0.0

func _ready() -> void:
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.6
    var col := CollisionShape3D.new()
    col.shape = capsule
    col.position.y = 0.8
    add_child(col)
    visual_root = Node3D.new()
    visual_root.name = "VisualRoot"
    add_child(visual_root)
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
    visual_root.add_child(body_mesh)
    var head_mesh := MeshInstance3D.new()
    var head := SphereMesh.new()
    head.radius = 0.19
    head.height = 0.38
    head_mesh.mesh = head
    head_mesh.position.y = 1.86
    var hm := StandardMaterial3D.new()
    hm.albedo_color = Color(0.35,0.29,0.23)
    head_mesh.material_override = hm
    visual_root.add_child(head_mesh)
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
    visual_root.add_child(vest)
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
    visual_root.add_child(rifle)

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
    visual_root.add_child(enemy_muzzle_flash)

    enemy_muzzle_light = OmniLight3D.new()
    enemy_muzzle_light.name = "EnemyMuzzleFlashLight"
    enemy_muzzle_light.position = enemy_muzzle_flash.position
    enemy_muzzle_light.light_color = Color(1.0, 0.48, 0.18)
    enemy_muzzle_light.light_energy = 0.0
    enemy_muzzle_light.omni_range = 3.2
    enemy_muzzle_light.shadow_enabled = false
    visual_root.add_child(enemy_muzzle_light)
    _build_limb_meshes()
    _build_equipment_details()

    player = get_tree().get_first_node_in_group("player")
    if not player:
        player = get_tree().current_scene.get_node_or_null("Player") as Node3D
    enemy_fire_audio = AudioStreamPlayer3D.new()
    enemy_fire_audio.name = "EnemyFireAudio"
    var audio_fx = load("res://scripts/audio_fx.gd")
    enemy_fire_audio.stream = audio_fx.create_gunshot()
    enemy_fire_audio.volume_db = -11.0
    enemy_fire_audio.unit_size = 4.0
    enemy_fire_audio.max_distance = 65.0
    add_child(enemy_fire_audio)
    add_to_group("enemies")
    _initialize_patrol()
    set_difficulty(difficulty)

func set_combat_role(value: String) -> void:
    var normalized := value.strip_edges().to_upper()
    combat_role = normalized if normalized in ["ASSAULT", "SUPPORT", "FLANKER", "RIFLEMAN"] else "RIFLEMAN"

func _combat_engagement_ranges() -> Vector2:
    match combat_role:
        "ASSAULT":
            return Vector2(4.5, 10.5)
        "SUPPORT":
            return Vector2(9.0, 15.0)
        _:
            return Vector2(5.5, 13.0)

func _combat_fire_interval_scale() -> float:
    match combat_role:
        "SUPPORT":
            return 1.2
        "FLANKER":
            return 0.86
        "ASSAULT":
            return 0.92
        _:
            return 1.0

func set_difficulty(value: String) -> void:
    difficulty = value.strip_edges().to_upper()
    match difficulty:
        "RECRUIT":
            shot_damage = 4.0
            detection_range = 25.0
            fire_interval_min = 1.0
            fire_interval_max = 1.7
        "VETERAN":
            shot_damage = 10.0
            detection_range = 34.0
            fire_interval_min = 0.45
            fire_interval_max = 0.9
        _:
            difficulty = "STANDARD"
            shot_damage = 7.0
            detection_range = 30.0
            fire_interval_min = 0.65
            fire_interval_max = 1.25
    fire_timer = fire_interval_max

func _build_equipment_details() -> void:
    var helmet_material := StandardMaterial3D.new()
    helmet_material.albedo_color = Color(0.19, 0.22, 0.18)
    helmet_material.roughness = 0.92
    var rubber_material := StandardMaterial3D.new()
    rubber_material.albedo_color = Color(0.045, 0.052, 0.047)
    rubber_material.roughness = 0.72
    var fabric_material := StandardMaterial3D.new()
    fabric_material.albedo_color = Color(0.16, 0.18, 0.14)
    fabric_material.roughness = 1.0
    var buckle_material := StandardMaterial3D.new()
    buckle_material.albedo_color = Color(0.31, 0.29, 0.22)
    buckle_material.metallic = 0.18
    buckle_material.roughness = 0.82

    var helmet := MeshInstance3D.new()
    helmet.name = "Helmet"
    var helmet_mesh := SphereMesh.new()
    helmet_mesh.radius = 0.205
    helmet_mesh.height = 0.25
    helmet.mesh = helmet_mesh
    helmet.position = Vector3(0.0, 2.025, 0.015)
    helmet.material_override = helmet_material
    visual_root.add_child(helmet)
    _add_equipment_box("HelmetBrim", Vector3(0.0, 1.985, -0.055), Vector3(0.43, 0.055, 0.32), helmet_material)
    _add_equipment_box("HelmetMount", Vector3(0.0, 2.105, -0.155), Vector3(0.105, 0.07, 0.07), rubber_material)
    _add_equipment_box("BallisticGoggles", Vector3(0.0, 1.885, -0.166), Vector3(0.29, 0.085, 0.045), rubber_material)
    _add_equipment_box("GoggleLens", Vector3(0.0, 1.888, -0.191), Vector3(0.235, 0.038, 0.012), buckle_material)

    _add_equipment_box("TacticalBackpack", Vector3(0.0, 1.22, 0.19), Vector3(0.43, 0.54, 0.22), fabric_material)
    _add_equipment_box("BackpackTopFlap", Vector3(0.0, 1.48, 0.19), Vector3(0.36, 0.12, 0.235), helmet_material)
    # Compact squad radio and whip antenna break up the otherwise flat backpack silhouette.
    _add_equipment_box("RadioPack", Vector3(-0.19, 1.34, 0.075), Vector3(0.14, 0.23, 0.12), rubber_material)
    var radio_antenna := MeshInstance3D.new()
    radio_antenna.name = "RadioAntenna"
    var antenna_mesh := CylinderMesh.new()
    antenna_mesh.top_radius = 0.009
    antenna_mesh.bottom_radius = 0.014
    antenna_mesh.height = 0.34
    radio_antenna.mesh = antenna_mesh
    radio_antenna.position = Vector3(-0.22, 1.60, 0.10)
    radio_antenna.rotation.z = -0.12
    radio_antenna.material_override = rubber_material
    visual_root.add_child(radio_antenna)
    _add_equipment_box("SidearmHolster", Vector3(0.285, 0.76, -0.015), Vector3(0.13, 0.23, 0.16), rubber_material)
    _add_equipment_box("WaistBelt", Vector3(0.0, 0.79, -0.005), Vector3(0.55, 0.105, 0.29), rubber_material)
    _add_equipment_box("BeltBuckle", Vector3(0.0, 0.79, -0.165), Vector3(0.09, 0.075, 0.025), buckle_material)

    for index in range(4):
        var pouch_x := -0.205 + float(index) * 0.137
        _add_equipment_box("MagazinePouch_%02d" % index, Vector3(pouch_x, 0.91, -0.155), Vector3(0.105, 0.17, 0.09), fabric_material)
        _add_equipment_box("PouchFlap_%02d" % index, Vector3(pouch_x, 0.96, -0.205), Vector3(0.085, 0.055, 0.018), helmet_material)

    for side in [-1.0, 1.0]:
        var shoulder := MeshInstance3D.new()
        shoulder.name = "ShoulderPadLeft" if side < 0.0 else "ShoulderPadRight"
        var shoulder_mesh := SphereMesh.new()
        shoulder_mesh.radius = 0.145
        shoulder_mesh.height = 0.22
        shoulder.mesh = shoulder_mesh
        shoulder.position = Vector3(side * 0.365, 1.38, -0.025)
        shoulder.material_override = helmet_material
        visual_root.add_child(shoulder)
        _add_equipment_box("ShoulderWebbingLeft" if side < 0.0 else "ShoulderWebbingRight", Vector3(side * 0.28, 1.40, -0.16), Vector3(0.075, 0.29, 0.035), fabric_material)

    _add_equipment_box("RifleMagazine", Vector3(0.32, 1.105, -0.13), Vector3(0.09, 0.22, 0.14), rubber_material)
    _add_equipment_box("RifleStock", Vector3(0.32, 1.24, 0.18), Vector3(0.10, 0.105, 0.25), fabric_material)
    _add_equipment_box("RifleOptic", Vector3(0.32, 1.325, -0.21), Vector3(0.12, 0.085, 0.13), rubber_material)
    _add_equipment_box("RifleGrip", Vector3(0.32, 1.17, -0.005), Vector3(0.075, 0.15, 0.09), rubber_material)
    var barrel := MeshInstance3D.new()
    barrel.name = "RifleBarrel"
    var barrel_mesh := CylinderMesh.new()
    barrel_mesh.top_radius = 0.022
    barrel_mesh.bottom_radius = 0.028
    barrel_mesh.height = 0.32
    barrel.mesh = barrel_mesh
    barrel.position = Vector3(0.32, 1.25, -0.67)
    barrel.rotation.x = PI * 0.5
    barrel.material_override = buckle_material
    visual_root.add_child(barrel)

    _add_limb_end(left_leg_pivot, "LeftKneePad", Vector3(0.0, -0.31, -0.105), Vector3(0.23, 0.19, 0.12), rubber_material)
    _add_limb_end(right_leg_pivot, "RightKneePad", Vector3(0.0, -0.31, -0.105), Vector3(0.23, 0.19, 0.12), rubber_material)
    _add_limb_end(left_leg_pivot, "LeftBootToeCap", Vector3(0.0, -0.69, -0.19), Vector3(0.19, 0.10, 0.12), rubber_material)
    _add_limb_end(right_leg_pivot, "RightBootToeCap", Vector3(0.0, -0.69, -0.19), Vector3(0.19, 0.10, 0.12), rubber_material)

func _add_equipment_box(label: String, local_position: Vector3, size: Vector3, material: Material) -> void:
    var piece := MeshInstance3D.new()
    piece.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    piece.mesh = mesh
    piece.position = local_position
    piece.material_override = material
    visual_root.add_child(piece)

func _build_limb_meshes() -> void:
    var arm_material := StandardMaterial3D.new()
    arm_material.albedo_color = Color(0.17, 0.19, 0.16)
    arm_material.roughness = 0.96
    var trouser_material := StandardMaterial3D.new()
    trouser_material.albedo_color = Color(0.20, 0.21, 0.18)
    trouser_material.roughness = 0.98
    var glove_material := StandardMaterial3D.new()
    glove_material.albedo_color = Color(0.055, 0.06, 0.055)
    glove_material.roughness = 1.0
    var boot_material := StandardMaterial3D.new()
    boot_material.albedo_color = Color(0.07, 0.075, 0.07)
    boot_material.roughness = 1.0

    left_arm_pivot = _make_limb_pivot("LeftArmPivot", Vector3(-0.34, 1.38, -0.04), 0.62, 0.105, arm_material)
    right_arm_pivot = _make_limb_pivot("RightArmPivot", Vector3(0.34, 1.38, -0.04), 0.62, 0.105, arm_material)
    left_arm_pivot.rotation.z = -0.26
    right_arm_pivot.rotation.z = 0.24
    _add_limb_end(left_arm_pivot, "LeftGlove", Vector3(0.0, -0.54, -0.04), Vector3(0.14, 0.10, 0.13), glove_material)
    _add_limb_end(right_arm_pivot, "RightGlove", Vector3(0.0, -0.54, -0.04), Vector3(0.14, 0.10, 0.13), glove_material)

    left_leg_pivot = _make_limb_pivot("LeftLegPivot", Vector3(-0.18, 0.66, 0.015), 0.76, 0.135, trouser_material)
    right_leg_pivot = _make_limb_pivot("RightLegPivot", Vector3(0.18, 0.66, 0.015), 0.76, 0.135, trouser_material)
    _add_limb_end(left_leg_pivot, "LeftBoot", Vector3(0.0, -0.69, -0.075), Vector3(0.24, 0.13, 0.34), boot_material)
    _add_limb_end(right_leg_pivot, "RightBoot", Vector3(0.0, -0.69, -0.075), Vector3(0.24, 0.13, 0.34), boot_material)

func _make_limb_pivot(label: String, pivot_position: Vector3, length: float, radius: float, material: StandardMaterial3D) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = label
    pivot.position = pivot_position
    var limb := MeshInstance3D.new()
    limb.name = label.replace("Pivot", "Mesh")
    var capsule := CapsuleMesh.new()
    capsule.radius = radius
    capsule.height = length
    limb.mesh = capsule
    limb.position.y = -length * 0.42
    limb.material_override = material
    pivot.add_child(limb)
    visual_root.add_child(pivot)
    return pivot

func _add_limb_end(parent: Node3D, label: String, local_position: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
    var end_piece := MeshInstance3D.new()
    end_piece.name = label
    var box := BoxMesh.new()
    box.size = size
    end_piece.mesh = box
    end_piece.position = local_position
    end_piece.material_override = material
    parent.add_child(end_piece)

func _process(delta: float) -> void:
    if not is_dead:
        return
    death_timer += delta
    var progress := clampf(death_timer / DEATH_ANIMATION_SECONDS, 0.0, 1.0)
    var eased := progress * progress * (3.0 - 2.0 * progress)
    visual_root.rotation.z = death_roll_direction * 1.22 * eased
    visual_root.rotation.x = -0.22 * eased
    visual_root.position.y = -0.46 * eased
    if progress >= 1.0:
        queue_free()

func _animate_visuals(delta: float) -> void:
    if is_dead or not is_instance_valid(visual_root):
        return
    hit_reaction_timer = maxf(0.0, hit_reaction_timer - delta)
    var reaction_strength := clampf(hit_reaction_timer / 0.28, 0.0, 1.0)
    reaction_strength = reaction_strength * reaction_strength * (3.0 - 2.0 * reaction_strength)
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    var weapon_ready := state == "COMBAT" or state == "REPOSITION"
    if horizontal_speed > 0.22:
        gait_time += delta * lerpf(5.0, 10.0, clampf(horizontal_speed / 3.5, 0.0, 1.0))
        # A cautious, shorter stride while shouldering the rifle reads as combat movement.
        var stride_scale := 0.68 if weapon_ready else 1.0
        var swing := sin(gait_time) * 0.48 * stride_scale
        left_leg_pivot.rotation.x = swing
        right_leg_pivot.rotation.x = -swing
        left_arm_pivot.rotation.x = -swing * 0.42
        right_arm_pivot.rotation.x = swing * 0.42
        visual_root.position.y = absf(sin(gait_time * 2.0)) * (0.024 if weapon_ready else 0.035)
        var local_velocity := global_transform.basis.inverse() * velocity
        var lateral_lean := clampf(-local_velocity.x * 0.018, -0.055, 0.055)
        # Ease into and out of lateral lean so direction changes feel weighted, not snapped.
        var lean_weight := minf(delta * 6.0, 1.0)
        visual_root.rotation.z = lerpf(visual_root.rotation.z - hit_reaction_direction * 0.12 * reaction_strength, lateral_lean, lean_weight)
    else:
        gait_time += delta * 1.2
        left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, 0.0, delta * 7.0)
        right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, 0.0, delta * 7.0)
        left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, 0.0, delta * 7.0)
        right_arm_pivot.rotation.x = lerpf(right_arm_pivot.rotation.x, 0.0, delta * 7.0)
        visual_root.position.y = lerpf(visual_root.position.y, sin(gait_time) * 0.006, delta * 4.0)
        # Remove the previous frame's flinch offset before recentering the idle lean.
        visual_root.rotation.z = lerpf(visual_root.rotation.z - hit_reaction_direction * 0.12 * reaction_strength, 0.0, delta * 4.0)
    # Layer a brief upper-body flinch over locomotion without freezing movement.
    visual_root.rotation.x = (-0.075 if weapon_ready else 0.0) - 0.16 * reaction_strength
    visual_root.rotation.z += hit_reaction_direction * 0.12 * reaction_strength
    left_arm_pivot.rotation.z = -0.26 - hit_reaction_direction * 0.18 * reaction_strength
    right_arm_pivot.rotation.z = 0.24 + hit_reaction_direction * 0.18 * reaction_strength
    # Keep the rifle shouldered while engaging, with gait layered underneath the ready pose.
    var pose_weight := minf(delta * 7.0, 1.0)
    var left_arm_target := -0.30 if weapon_ready else 0.0
    var right_arm_target := -0.22 if weapon_ready else 0.0
    left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, left_arm_target, pose_weight)
    right_arm_pivot.rotation.x = lerpf(right_arm_pivot.rotation.x, right_arm_target, pose_weight)

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
    flank_timer = maxf(0.0, flank_timer - delta)
    suppression_timer = maxf(0.0, suppression_timer - delta)
    alert_memory_timer = maxf(0.0, alert_memory_timer - delta)
    alert_broadcast_timer = maxf(0.0, alert_broadcast_timer - delta)
    if think_timer <= 0:
        think_timer = 0.25
        var distance := global_position.distance_to(player.global_position)
        var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, player.global_position + Vector3.UP * 1.3)
        query.exclude = [get_rid()]
        var sight := get_world_3d().direct_space_state.intersect_ray(query)
        var sees_player: bool = distance < detection_range and (sight.is_empty() or sight.get("collider") == player)
        var grenade_threat := _nearest_grenade_threat()
        if is_instance_valid(grenade_threat):
            if state != "REPOSITION" or cover_timer <= 0.0:
                cover_goal = _choose_cover(grenade_threat.global_position)
                cover_timer = 1.0
            state = "REPOSITION"
            suppression_timer = maxf(suppression_timer, 0.35)
        elif suppression_timer > 0.0:
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
        else:
            # Distance alone does not reveal the player's position; use sight or sound.
            state = "SEARCH"
        if distance < 15.0 and randf() < 0.28:
            strafe_sign *= -1.0
        if state == "INVESTIGATE" and not sees_player and suppression_timer <= 0.0 and cover_timer <= 0.0:
            cover_goal = _choose_cover(last_known_position if last_known_position != Vector3.ZERO else player.global_position)
            cover_timer = randf_range(2.5, 4.0)
    var target_dir := Vector3.ZERO
    var distance_to_player := global_position.distance_to(player.global_position)
    if state == "COMBAT":
        var to_player := player.global_position - global_position
        to_player.y = 0
        var engagement := _combat_engagement_ranges()
        if distance_to_player > engagement.y:
            target_dir = to_player.normalized()
        elif distance_to_player < engagement.x:
            target_dir = -to_player.normalized()
            flank_timer = 0.0
        elif combat_role == "SUPPORT":
            # Support holds a wider firing lane and makes small lateral corrections.
            if flank_timer <= 0.0:
                strafe_sign *= -1.0
                flank_timer = randf_range(1.8, 3.0)
            target_dir = Vector3(-to_player.z, 0.0, to_player.x).normalized() * strafe_sign * 0.22
        else:
            # Flankers and riflemen break predictable left-right strafing with short runs.
            if flank_timer <= 0.0 or global_position.distance_to(flank_goal) < 1.6:
                flank_goal = _choose_flank_goal()
                flank_timer = randf_range(2.2, 3.8)
                strafe_sign *= -1.0
            var to_flank := flank_goal - global_position
            to_flank.y = 0.0
            if to_flank.length() > 1.0:
                target_dir = to_flank.normalized()
            else:
                target_dir = Vector3(-to_player.z, 0.0, to_player.x).normalized() * strafe_sign * 0.42
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
        if distance_to_player < maxf(10.0, detection_range - 5.0) and fire_timer <= 0:
            fire_timer = randf_range(fire_interval_min, fire_interval_max) * _combat_fire_interval_scale()
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
        var investigate_target := cover_goal
        if alert_memory_timer > 0.0 and last_known_position != Vector3.ZERO:
            investigate_target = last_known_position
        var to_target := investigate_target - global_position
        to_target.y = 0.0
        if to_target.length() > 1.4:
            target_dir = to_target.normalized() * 0.72
            look_at(Vector3(investigate_target.x, global_position.y, investigate_target.z), Vector3.UP)
        else:
            state = "SEARCH"
            alert_memory_timer = 0.0
    elif state == "SEARCH":
        if patrol_pause_timer > 0.0:
            patrol_pause_timer = maxf(0.0, patrol_pause_timer - delta)
        else:
            var to_patrol := patrol_goal - global_position
            to_patrol.y = 0.0
            if patrol_goal == Vector3.ZERO or to_patrol.length() < 1.4:
                _choose_next_patrol_goal()
            else:
                target_dir = to_patrol.normalized() * 0.48
                look_at(Vector3(patrol_goal.x, global_position.y, patrol_goal.z), Vector3.UP)
    target_dir = _apply_ally_separation(target_dir)
    target_dir = _avoid_obstacles(target_dir)
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    velocity.x = move_toward(velocity.x, target_dir.x * 2.1, delta * 4.0)
    velocity.z = move_toward(velocity.z, target_dir.z * 2.1, delta * 4.0)
    move_and_slide()
    _animate_visuals(delta)

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
    # Squadmates are handled by separation steering, not treated as solid walls.
    query.exclude = _movement_ray_exclusions()
    query.collision_mask = 1
    return space.intersect_ray(query)

func _apply_ally_separation(direction: Vector3) -> Vector3:
    var desired := direction
    desired.y = 0.0
    if desired.length_squared() < 0.0001:
        return Vector3.ZERO
    var separation := Vector3.ZERO
    for node in get_tree().get_nodes_in_group("enemies"):
        if node == self or not is_instance_valid(node) or not node is Node3D:
            continue
        var ally := node as Node3D
        if float(ally.get("health")) <= 0.0:
            continue
        var offset := global_position - ally.global_position
        offset.y = 0.0
        var distance := offset.length()
        if distance > 2.2 or distance < 0.001:
            continue
        separation += offset.normalized() * ((2.2 - distance) / 2.2)
    if separation.length_squared() < 0.0001:
        return desired.normalized() * minf(direction.length(), 1.0)
    var strength := minf(separation.length(), 1.0) * 0.8
    var steered := desired.normalized() + separation.normalized() * strength
    if steered.length_squared() < 0.0001:
        return separation.normalized() * minf(direction.length(), 1.0)
    return steered.normalized() * minf(direction.length(), 1.0)

func _get_patrol_points() -> Array[Node3D]:
    var points: Array[Node3D] = []
    for node in get_tree().get_nodes_in_group("enemy_patrol_points"):
        var marker := node as Node3D
        if is_instance_valid(marker):
            points.append(marker)
    return points

func _has_clear_patrol_path(target: Node3D) -> bool:
    var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, target.global_position + Vector3.UP * 1.0)
    var exclusions: Array[RID] = [get_rid()]
    if is_instance_valid(player):
        exclusions.append(player.get_rid())
    for ally in get_tree().get_nodes_in_group("enemies"):
        var ally_body := ally as CollisionObject3D
        if is_instance_valid(ally_body):
            exclusions.append(ally_body.get_rid())
    query.exclude = exclusions
    query.collision_mask = 1
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _initialize_patrol() -> void:
    var points := _get_patrol_points()
    if points.is_empty():
        return
    var nearest_index := 0
    var nearest_distance := INF
    var clear_index := -1
    var clear_distance := INF
    for index in range(points.size()):
        var distance := global_position.distance_to(points[index].global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = index
        if distance < 26.0 and distance < clear_distance and _has_clear_patrol_path(points[index]):
            clear_distance = distance
            clear_index = index
    patrol_index = clear_index if clear_index >= 0 else nearest_index
    patrol_goal = points[patrol_index].global_position
    patrol_pause_timer = randf_range(0.2, 0.65)

func _choose_next_patrol_goal() -> void:
    var points := _get_patrol_points()
    if points.size() < 2:
        return
    var candidates: Array[int] = []
    for index in range(points.size()):
        if index == patrol_index:
            continue
        var distance := global_position.distance_to(points[index].global_position)
        if distance < 3.0 or distance > 24.0:
            continue
        if _has_clear_patrol_path(points[index]):
            candidates.append(index)
    if candidates.is_empty():
        for index in range(points.size()):
            if index == patrol_index:
                continue
            if global_position.distance_to(points[index].global_position) <= 30.0:
                candidates.append(index)
    if candidates.is_empty():
        return
    patrol_index = candidates[randi_range(0, candidates.size() - 1)]
    patrol_goal = points[patrol_index].global_position
    patrol_pause_timer = randf_range(0.45, 1.25)

func _nearest_grenade_threat() -> Node3D:
    var nearest: Node3D = null
    var nearest_distance := 9.0
    for grenade in get_tree().get_nodes_in_group("active_grenades"):
        var grenade_node := grenade as Node3D
        if not is_instance_valid(grenade_node) or bool(grenade_node.get("exploded")):
            continue
        if float(grenade_node.get("fuse_timer")) > 1.85:
            continue
        var distance := global_position.distance_to(grenade_node.global_position)
        if distance < nearest_distance:
            nearest = grenade_node
            nearest_distance = distance
    return nearest

func hear_noise(source_position: Vector3, noise_type: String) -> void:
    if health <= 0.0:
        return
    var memory_duration := 3.0
    match noise_type:
        "FOOTSTEP":
            memory_duration = 2.0
        "GUNSHOT":
            memory_duration = 5.0
        "IMPACT":
            memory_duration = 2.8
        "GRENADE":
            memory_duration = 6.0
    last_known_position = source_position
    alert_memory_timer = maxf(alert_memory_timer, memory_duration)
    if state != "COMBAT":
        state = "INVESTIGATE"
        if cover_timer <= 0.0 or noise_type != "FOOTSTEP":
            cover_goal = _choose_cover(source_position)
            cover_timer = 1.2 if noise_type == "FOOTSTEP" else 1.6
    think_timer = minf(think_timer, 0.1)

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

func _get_district_cover_candidates() -> Array[Vector3]:
    var candidates: Array[Vector3] = []
    var offsets := [Vector3(-1.65, 0, 0), Vector3(1.65, 0, 0), Vector3(0, 0, -1.35), Vector3(0, 0, 1.35)]
    for group_name in ["ammo_caches", "service_alley_crates"]:
        for prop in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(prop):
                continue
            var prop_position: Vector3 = prop.global_position
            for offset in offsets:
                candidates.append(prop_position + offset)
    return candidates

func _choose_flank_goal() -> Vector3:
    if not is_instance_valid(player):
        return global_position
    var away := global_position - player.global_position
    away.y = 0.0
    if away.length_squared() < 0.01:
        away = Vector3.FORWARD
    away = away.normalized()
    var best := global_position
    var best_score := -INF
    # Offset around the player's position instead of charging directly down the same lane.
    for angle in [-1.25, 1.25, -0.78, 0.78, 2.2, -2.2]:
        var direction := away.rotated(Vector3.UP, angle)
        var candidate := player.global_position + direction * randf_range(7.5, 10.0)
        candidate.y = global_position.y
        var travel := candidate.distance_to(global_position)
        if travel < 1.5:
            continue
        var score := _score_flank_candidate(candidate, travel)
        if score > best_score:
            best_score = score
            best = candidate
    return best

func _score_flank_candidate(candidate: Vector3, travel: float) -> float:
    var score := -travel * 0.35 + randf_range(-0.25, 0.25)
    score -= _flank_ally_spacing_penalty(candidate)
    var space := get_world_3d().direct_space_state
    var origin := global_position + Vector3.UP * 0.9
    var flat_to_candidate := candidate - global_position
    flat_to_candidate.y = 0.0
    if flat_to_candidate.length_squared() > 0.01:
        var direction := flat_to_candidate.normalized()
        var direct_path := PhysicsRayQueryParameters3D.create(origin, origin + direction * minf(travel, 4.0))
        direct_path.exclude = _movement_ray_exclusions()
        direct_path.collision_mask = 1
        if not space.intersect_ray(direct_path).is_empty():
            score -= 4.5
    var cover_ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.25, candidate + Vector3.UP * 1.0)
    cover_ray.exclude = [get_rid(), player.get_rid()]
    cover_ray.collision_mask = 1
    if not space.intersect_ray(cover_ray).is_empty():
        score += 1.8
    return score

func _movement_ray_exclusions() -> Array[RID]:
    var exclusions: Array[RID] = [get_rid()]
    if is_instance_valid(player):
        exclusions.append(player.get_rid())
    for ally in get_tree().get_nodes_in_group("enemies"):
        if ally != self and is_instance_valid(ally) and ally is CollisionObject3D:
            exclusions.append(ally.get_rid())
    return exclusions

func _flank_ally_spacing_penalty(candidate: Vector3) -> float:
    var penalty := 0.0
    for node in get_tree().get_nodes_in_group("enemies"):
        if node == self or not is_instance_valid(node) or not node is Node3D:
            continue
        var ally := node as Node3D
        if float(ally.get("health")) <= 0.0:
            continue
        var ally_goal: Vector3 = ally.get("flank_goal")
        if ally_goal != Vector3.ZERO:
            var goal_distance := candidate.distance_to(ally_goal)
            if goal_distance < 5.0:
                penalty += (5.0 - goal_distance) * 1.8
        var body_distance := candidate.distance_to(ally.global_position)
        if body_distance < 2.8:
            penalty += (2.8 - body_distance) * 1.1
    return penalty

func _cover_ally_spacing_penalty(candidate: Vector3) -> float:
    var penalty := 0.0
    for node in get_tree().get_nodes_in_group("enemies"):
        if node == self or not is_instance_valid(node) or not node is Node3D:
            continue
        var ally := node as Node3D
        if float(ally.get("health")) <= 0.0:
            continue
        var ally_state := str(ally.get("state"))
        var ally_cover_timer := float(ally.get("cover_timer"))
        var ally_cover_goal: Vector3 = ally.get("cover_goal")
        if ally_state == "REPOSITION" and ally_cover_timer > 0.0 and ally_cover_goal != Vector3.ZERO:
            var goal_distance := candidate.distance_to(ally_cover_goal)
            if goal_distance < 4.0:
                penalty += (4.0 - goal_distance) * 2.5
        var body_distance := candidate.distance_to(ally.global_position)
        if body_distance < 2.6:
            penalty += (2.6 - body_distance) * 1.2
    return penalty

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
        score -= _cover_ally_spacing_penalty(candidate)
        # Avoid cycling straight back to the last position when other cover is available.
        if has_last_cover_goal and candidate.distance_to(last_cover_goal) < 4.5:
            score -= 12.0
        var cover_ray := PhysicsRayQueryParameters3D.create(threat_position + Vector3.UP * 1.25, candidate + Vector3.UP * 1.0)
        cover_ray.exclude = [get_rid()]
        var obstruction := get_world_3d().direct_space_state.intersect_ray(cover_ray)
        if not obstruction.is_empty():
            score += 5.0
        if score > best_score:
            best_score = score
            best = candidate
    if best.distance_to(global_position) > 0.75:
        last_cover_goal = best
        has_last_cover_goal = true
    return best

func _try_shoot_player() -> void:
    _show_muzzle_flash()
    if is_instance_valid(player):
        var player_hud = player.get("hud")
        if is_instance_valid(player_hud) and player_hud.has_method("show_hostile_fire"):
            player_hud.call("show_hostile_fire", player.global_position, player.global_transform.basis, global_position)
    if is_instance_valid(enemy_fire_audio):
        enemy_fire_audio.pitch_scale = randf_range(0.94, 1.06)
        enemy_fire_audio.play()
    var from := global_position + Vector3.UP*1.35
    var to := player.global_position + Vector3.UP*1.2
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var tracer_end: Vector3 = hit.get("position", to) if not hit.is_empty() else to
    var tracer_tint := Color(1.0, 0.43, 0.16, 0.9)
    if not hit.is_empty() and hit.get("collider") == player:
        tracer_tint = Color(1.0, 0.70, 0.30, 0.95)
        if player.has_method("apply_damage"):
            player.apply_damage(shot_damage, global_position)
    _spawn_shot_tracer(from, tracer_end, tracer_tint)
    var active_scene := get_tree().current_scene
    if is_instance_valid(active_scene) and active_scene.has_method("report_noise"):
        active_scene.call("report_noise", from, 42.0, "GUNSHOT", self)
    if not hit.is_empty() and hit.get("collider") is StaticBody3D and is_instance_valid(player):
        if player.has_method("_spawn_bullet_impact"):
            player.call("_spawn_bullet_impact", hit.get("position", tracer_end), hit.get("normal", Vector3.UP))
        if player.has_method("_play_impact_audio"):
            player.call("_play_impact_audio", hit.get("position", tracer_end))

func _spawn_shot_tracer(start_position: Vector3, end_position: Vector3, tint: Color) -> void:
    var active_scene := get_tree().current_scene
    if not is_instance_valid(active_scene):
        return
    var tracer := MeshInstance3D.new()
    tracer.set_script(SHOT_TRACER_SCRIPT)
    active_scene.add_child(tracer)
    tracer.call("configure", start_position, end_position, tint)

func _show_muzzle_flash() -> void:
    enemy_muzzle_flash.visible = true
    enemy_muzzle_light.light_energy = 1.6
    muzzle_flash_timer = 0.055

func apply_suppression(source_position: Vector3) -> void:
    if is_dead or health <= 0.0:
        return
    last_known_position = source_position
    alert_memory_timer = maxf(alert_memory_timer, 3.5)
    suppression_timer = maxf(suppression_timer, 0.85)
    cover_timer = 0.0
    think_timer = 0.0
    if state != "COMBAT":
        state = "REPOSITION"
    _broadcast_alert(source_position)

func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, headshot: bool = false) -> bool:
    if is_dead:
        return true
    health -= amount * (3.0 if headshot else 1.0)
    if health <= 0.0:
        _begin_death()
        return true

    # Incoming fire alerts the unit and forces a short break from its current firing lane.
    if is_instance_valid(player):
        last_known_position = player.global_position
        state = "REPOSITION"
        suppression_timer = maxf(suppression_timer, 1.1 if headshot else 0.75)
        if health <= 35.0 and not low_health_retreat_used:
            low_health_retreat_used = true
            suppression_timer = maxf(suppression_timer, 2.0)
        cover_timer = 0.0
        think_timer = 0.0
        alert_memory_timer = 5.0
        _broadcast_alert(player.global_position)
    body_material.albedo_color = Color(0.55,0.12,0.08)
    hit_flash_timer = 0.14
    hit_reaction_timer = maxf(hit_reaction_timer, 0.32 if headshot else 0.22)
    if hit_position != Vector3.ZERO:
        var local_hit := global_transform.basis.inverse() * (hit_position - global_position)
        hit_reaction_direction = -1.0 if local_hit.x < 0.0 else 1.0
    else:
        hit_reaction_direction = -hit_reaction_direction
    return false

func _begin_death() -> void:
    is_dead = true
    state = "DEAD"
    death_timer = 0.0
    death_roll_direction = -1.0 if randf() < 0.5 else 1.0
    velocity = Vector3.ZERO
    set_physics_process(false)
    collision_layer = 0
    collision_mask = 0
    var body_collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if is_instance_valid(body_collision):
        body_collision.set_deferred("disabled", true)
    var head_area := get_node_or_null("HeadHitZone") as Area3D
    if is_instance_valid(head_area):
        head_area.monitoring = false
        head_area.monitorable = false
        for child in head_area.get_children():
            if child is CollisionShape3D:
                child.set_deferred("disabled", true)
    remove_from_group("enemies")
    body_material.albedo_color = Color(0.08,0.09,0.08)
    hit_flash_timer = 0.0
    enemy_muzzle_flash.visible = false
    enemy_muzzle_light.light_energy = 0.0
    if is_instance_valid(enemy_fire_audio):
        enemy_fire_audio.stop()
    var scene := get_tree().current_scene
    if is_instance_valid(scene) and scene.has_method("enemy_killed"):
        scene.enemy_killed(self)
