extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var enemies: Array[Node] = []
var mission_complete := false
var mission_started := false
var mission_elapsed := 0.0
var shots_fired := 0
var shots_hit := 0
var grenades_used := 0
var ammo_caches_used := 0
var hostiles_eliminated := 0
var difficulty := "STANDARD"
var world_environment: WorldEnvironment
var material_cache: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_input()
    _build_environment()
    _build_arena()
    _build_patrol_points()
    _spawn_atmosphere()
    _spawn_player()
    _spawn_ammo_caches()
    _spawn_enemies()
    _spawn_objective()
    _spawn_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    if mission_started and not mission_complete and not get_tree().paused:
        mission_elapsed += delta

func begin_mission() -> void:
    mission_started = true
    mission_elapsed = 0.0

func set_difficulty(value: String) -> void:
    var normalized := value.strip_edges().to_upper()
    difficulty = normalized if normalized in ["RECRUIT", "STANDARD", "VETERAN"] else "STANDARD"
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.has_method("set_difficulty"):
            enemy.set_difficulty(difficulty)

func register_shot(confirmed_hit: bool) -> void:
    shots_fired += 1
    if confirmed_hit:
        shots_hit += 1

func register_grenade_used() -> void:
    grenades_used += 1

func register_ammo_cache_used() -> void:
    ammo_caches_used += 1

func get_mission_summary() -> Dictionary:
    var accuracy := 0.0
    if shots_fired > 0:
        accuracy = float(shots_hit) / float(shots_fired) * 100.0
    return {
        "mission_seconds": mission_elapsed,
        "hostiles_eliminated": hostiles_eliminated,
        "shots_fired": shots_fired,
        "shots_hit": shots_hit,
        "accuracy": accuracy,
        "grenades_used": grenades_used,
        "ammo_caches_used": ammo_caches_used
    }

func _setup_input() -> void:
    _key_action("move_forward", KEY_W)
    _key_action("move_back", KEY_S)
    _key_action("move_left", KEY_A)
    _key_action("move_right", KEY_D)
    _key_action("sprint", KEY_SHIFT)
    _key_action("crouch", KEY_CTRL)
    _key_action("prone", KEY_Z)
    _key_action("lean_left", KEY_Q)
    _key_action("lean_right", KEY_E)
    _key_action("jump", KEY_SPACE)
    _key_action("reload", KEY_R)
    _key_action("interact", KEY_F)
    _key_action("throw_grenade", KEY_G)
    _key_action("pause", KEY_ESCAPE)

func _key_action(action: String, keycode: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    if not InputMap.action_has_event(action, event):
        InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
    if mission_complete:
        return
    if is_instance_valid(hud) and hud.has_method("is_briefing_open") and hud.call("is_briefing_open"):
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            get_tree().paused = true
            _show_pause()
        else:
            get_tree().paused = false
            if is_instance_valid(hud):
                hud.call("hide_pause")
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not get_tree().paused:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
    world_environment = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = load("res://shaders/battlefield_sky.gdshader") as Shader
    sky_mat.set_shader_parameter("sky_top_color", Color(0.12, 0.17, 0.20))
    sky_mat.set_shader_parameter("sky_horizon_color", Color(0.52, 0.46, 0.36))
    sky_mat.set_shader_parameter("cloud_color", Color(0.47, 0.48, 0.45))
    sky_mat.set_shader_parameter("sun_color", Color(1.0, 0.72, 0.43))
    sky_mat.set_shader_parameter("cloud_coverage", 0.56)
    sky_mat.set_shader_parameter("cloud_contrast", 0.62)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.42, 0.44, 0.43)
    env.ambient_light_energy = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.42, 0.40, 0.35)
    env.fog_density = 0.009
    env.fog_sky_affect = 0.72
    env.tonemap_exposure = 0.92
    world_environment.environment = env
    add_child(world_environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42, -28, 0)
    sun.light_energy = 1.05
    sun.light_color = Color(1.0, 0.87, 0.72)
    sun.directional_shadow_max_distance = 85.0
    sun.shadow_enabled = true
    add_child(sun)

func _build_environment() -> void:
    _setup_environment()


func _build_patrol_points() -> void:
    var route_root := Node3D.new()
    route_root.name = "EnemyPatrolPoints"
    add_child(route_root)
    var positions := [
        Vector3(0, 0, -42), Vector3(-8, 0, -26), Vector3(9, 0, -14),
        Vector3(10, 0, 0), Vector3(10, 0, 22), Vector3(-5, 0, 22),
        Vector3(-8, 0, 0), Vector3(-29, 0, -30), Vector3(-29, 0, -16),
        Vector3(-29, 0, -1), Vector3(-29, 0, 20), Vector3(-29, 0, 34)
    ]
    for index in range(positions.size()):
        var marker := Marker3D.new()
        marker.name = "PatrolPoint_%02d" % (index + 1)
        marker.position = positions[index]
        marker.add_to_group("enemy_patrol_points")
        route_root.add_child(marker)

func _spawn_atmosphere() -> void:
    _smoke_plume(Vector3(-12.0, 1.0, -18.0), 12)
    _smoke_plume(Vector3(15.0, 0.5, 7.0), 10)
    _smoke_plume(Vector3(3.0, 0.8, -35.0), 12)

func _smoke_plume(pos: Vector3, particle_count: int) -> void:
    var particles := CPUParticles3D.new()
    particles.name = "BattlefieldSmoke"
    particles.position = pos
    particles.amount = particle_count
    particles.lifetime = 5.5
    particles.preprocess = 1.0
    particles.emitting = true
    particles.direction = Vector3(0.0, 1.0, 0.0)
    particles.spread = 24.0
    particles.gravity = Vector3(0.0, -0.12, 0.0)
    particles.initial_velocity_min = 0.25
    particles.initial_velocity_max = 0.8
    particles.angular_velocity_min = -12.0
    particles.angular_velocity_max = 12.0
    particles.scale_amount_min = 0.7
    particles.scale_amount_max = 1.7
    var puff := SphereMesh.new()
    puff.radius = 0.32
    puff.height = 0.64
    var smoke_mat := StandardMaterial3D.new()
    smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
    smoke_mat.albedo_color = Color(0.26, 0.27, 0.25, 0.19)
    smoke_mat.roughness = 1.0
    puff.material = smoke_mat
    particles.mesh = puff
    add_child(particles)

func _build_arena() -> void:
    _box("Ground", Vector3(0, -0.5, 0), Vector3(100, 1, 100), Color(0.19, 0.20, 0.18), true)
    _box("Road", Vector3(0, 0.015, -3), Vector3(14, 0.04, 78), Color(0.105, 0.11, 0.105), false)
    for z in [-26, -18, -10, -2, 6, 14]:
        var center_mark := _box("WornCenterline", Vector3(0, 0.047, float(z)), Vector3(0.15, 0.018, 3.3), Color(0.52, 0.46, 0.32), false)
        center_mark.add_to_group("road_markings")
        center_mark.add_to_group("road_centerline_markings")
    _building(Vector3(-17, 0, -17), Vector3(12, 9, 12), Color(0.32, 0.30, 0.26))
    _building(Vector3(18, 0, -23), Vector3(13, 12, 15), Color(0.28, 0.29, 0.27))
    _building(Vector3(-22, 0, 8), Vector3(10, 7, 14), Color(0.36, 0.32, 0.27))
    _building(Vector3(21, 0, 13), Vector3(12, 8, 12), Color(0.31, 0.30, 0.28))
    _building(Vector3(-7, 0, -34), Vector3(12, 6, 7), Color(0.34, 0.30, 0.25))
    _building(Vector3(9, 0, 33), Vector3(15, 7, 8), Color(0.29, 0.30, 0.28))
    for p in [Vector3(-7,0,-10), Vector3(7,0,-18), Vector3(-5,0,7), Vector3(6,0,19), Vector3(-12,0,25), Vector3(13,0,-1)]:
        var barrier := _box("ConcreteBarrier", p + Vector3(0,0.65,0), Vector3(3.4,1.3,0.7), Color(0.39,0.38,0.33), true)
        barrier.add_to_group("arena_cover")
    _car(Vector3(-3,0,-25), -12)
    _car(Vector3(4,0,10), 15)
    _car(Vector3(-10,0,17), 80)
    for i in range(14):
        var x := -26.0 + float((i * 17) % 52)
        var z := -40.0 + float((i * 23) % 80)
        if abs(x) > 9:
            _box("Rubble", Vector3(x, 0.35, z), Vector3(0.8 + fmod(float(i), 2.0), 0.6, 0.7), Color(0.29,0.28,0.25), true)
    for i in range(5):
        _box("Sandbag", Vector3(-2.5 + i * 1.15, 0.35, -29), Vector3(1.05, 0.7, 0.55), Color(0.40,0.35,0.25), true)
    _box("ObjectiveLight", Vector3(0, 2.4, -30.5), Vector3(0.25, 0.25, 0.25), Color(0.85,0.58,0.18), false)
    _street_furniture()
    _add_road_markings()
    _build_distant_skyline()

func _build_distant_skyline() -> void:
    # A layered horizon prevents the playable block from ending at a hard wall.
    # Distant silhouettes are visual-only; gameplay collision stays in the arena.
    var skyline_root := Node3D.new()
    skyline_root.name = "DistantCityHorizon"
    add_child(skyline_root)
    var palettes := [Color(0.15, 0.17, 0.17), Color(0.19, 0.19, 0.17), Color(0.22, 0.20, 0.18), Color(0.17, 0.19, 0.19)]
    var index := 0
    for side in [-1.0, 1.0]:
        for row in range(9):
            var depth := -62.0 + float(row) * 14.0
            var height := 9.0 + float(absi(row * 7 + int(side * 3.0)) % 8) * 2.1
            var width := 5.5 + float((row * 3) % 5) * 1.7
            var x: float = side * (53.0 + float((row * 11) % 9))
            var z := depth + float((row % 3) - 1) * 4.0
            var color: Color = palettes[index % palettes.size()]
            index += 1
            var tower := _box_child(skyline_root, "HorizonBuilding_%02d" % index, Vector3(x, height * 0.5, z), Vector3(width, height, 7.0 + float(row % 4) * 1.8), color, false)
            tower.add_to_group("distant_skyline")
            # A few roof plants, elevator overruns and aerials break the flat roofline.
            if row % 3 == 0:
                _box_child(skyline_root, "RoofOverrun_%02d" % index, Vector3(x - width * 0.18, height + 0.65, z), Vector3(width * 0.28, 1.3, 2.2), color.darkened(0.16), false)
            if row % 4 == 1:
                _box_child(skyline_root, "RoofAerial_%02d" % index, Vector3(x + width * 0.22, height + 1.25, z), Vector3(0.08, 2.5, 0.08), Color(0.10, 0.11, 0.10), false)
            # Sparse, dim window slits provide scale without turning the horizon into a grid.
            for window_index in range(2 + row % 3):
                var window_x: float = x - width * 0.35 + float(window_index) * width * 0.28
                var window_y := 2.0 + float((window_index * 3 + row) % maxi(1, int(height / 3.0))) * 2.5
                if window_y < height - 0.8:
                    _box_child(skyline_root, "HorizonWindow_%02d_%02d" % [index, window_index], Vector3(window_x, window_y, z - (4.0 + float(row % 4) * 1.8) * 0.5 - 0.035), Vector3(0.38, 0.7, 0.06), Color(0.10, 0.12, 0.12), false)

func _add_road_markings() -> void:
    var faded_white := Color(0.50, 0.51, 0.46)
    var faded_yellow := Color(0.52, 0.46, 0.32)
    for side in [-1.0, 1.0]:
        var edge_line := _box("WornRoadEdge", Vector3(side * 6.45, 0.047, -0.5), Vector3(0.10, 0.016, 52.0), faded_white, false)
        edge_line.add_to_group("road_markings")
        edge_line.add_to_group("road_edge_markings")
    for x in [-5.4, -3.8, -2.2, -0.6, 1.0, 2.6, 4.2, 5.8]:
        var stripe := _box("CrosswalkStripe", Vector3(x, 0.047, 22.0), Vector3(0.55, 0.018, 0.14), faded_white, false)
        stripe.add_to_group("road_markings")
        stripe.add_to_group("crosswalk_markings")
    for z in [-32, -24, -16, -8, 18, 26, 32]:
        var alley_mark := _box("ServiceLaneMark", Vector3(-25.5, 0.047, float(z)), Vector3(0.09, 0.016, 2.8), faded_yellow, false)
        alley_mark.add_to_group("road_markings")
        alley_mark.add_to_group("service_lane_markings")

func _street_furniture() -> void:
    # Roadside infrastructure now has collision bodies separate from its visible meshes.
    for side in [-1.0, 1.0]:
        _box("RoadGutter", Vector3(side * 7.25, 0.035, -3.0), Vector3(0.28, 0.07, 76.0), Color(0.075, 0.08, 0.075), true)
        for lamp_index in range(4):
            var lamp_z := -29.0 + float(lamp_index) * 20.0
            var pole := StaticBody3D.new()
            pole.name = "DamagedStreetLamp"
            pole.position = Vector3(side * 8.4, 0.0, lamp_z)
            pole.add_to_group("street_lamp_collisions")
            add_child(pole)

            var shaft := MeshInstance3D.new()
            var shaft_mesh := CylinderMesh.new()
            shaft_mesh.top_radius = 0.075
            shaft_mesh.bottom_radius = 0.12
            shaft_mesh.height = 5.4
            shaft.mesh = shaft_mesh
            shaft.position.y = 2.7
            shaft.material_override = _material(Color(0.12, 0.13, 0.12))
            pole.add_child(shaft)
            var shaft_collision := CollisionShape3D.new()
            var shaft_shape := CapsuleShape3D.new()
            shaft_shape.radius = 0.13
            shaft_shape.height = 5.5
            shaft_collision.shape = shaft_shape
            shaft_collision.position.y = 2.75
            pole.add_child(shaft_collision)

            var arm := MeshInstance3D.new()
            var arm_mesh := BoxMesh.new()
            arm_mesh.size = Vector3(1.2, 0.08, 0.08)
            arm.mesh = arm_mesh
            arm.position = Vector3(-side * 0.48, 5.25, 0.0)
            arm.material_override = _material(Color(0.12, 0.13, 0.12))
            pole.add_child(arm)
            var arm_collision := CollisionShape3D.new()
            var arm_shape := BoxShape3D.new()
            arm_shape.size = Vector3(1.2, 0.08, 0.08)
            arm_collision.shape = arm_shape
            arm_collision.position = arm.position
            pole.add_child(arm_collision)

            var fixture := MeshInstance3D.new()
            var fixture_mesh := BoxMesh.new()
            fixture_mesh.size = Vector3(0.34, 0.12, 0.22)
            fixture.mesh = fixture_mesh
            fixture.position = Vector3(-side * 0.95, 5.18, 0.0)
            var fixture_mat := _material(Color(0.48, 0.34, 0.18))
            fixture_mat.emission_enabled = true
            fixture_mat.emission = Color(0.22, 0.10, 0.035)
            fixture.material_override = fixture_mat
            pole.add_child(fixture)

            if lamp_index < 3:
                var next_z := lamp_z + 20.0
                var cable_material := _material(Color(0.055, 0.06, 0.055))
                _cable_segment(Vector3(side * 8.4, 5.72, lamp_z), Vector3(side * 8.4, 5.35, lamp_z + 10.0), 0.018, cable_material)
                _cable_segment(Vector3(side * 8.4, 5.35, lamp_z + 10.0), Vector3(side * 8.4, 5.72, next_z), 0.018, cable_material)

    for patch in [Vector3(-4.8, 0.035, -21.0), Vector3(4.2, 0.035, -5.5), Vector3(-3.1, 0.035, 12.0), Vector3(4.8, 0.035, 29.0)]:
        var asphalt := _box("BrokenAsphalt", patch, Vector3(1.8, 0.025, 2.4), Color(0.14, 0.145, 0.135), false)
        asphalt.rotation_degrees.y = randf_range(-18.0, 18.0)
    for i in range(8):
        var x := -6.2 + float((i * 13) % 12)
        var z := -34.0 + float((i * 19) % 68)
        var debris := _box("StreetDebris", Vector3(x, 0.12, z), Vector3(0.25 + float(i % 3) * 0.12, 0.18, 0.22 + float(i % 2) * 0.14), Color(0.25, 0.24, 0.21), false)
        debris.rotation_degrees.y = float((i * 37) % 90)

func _cable_segment(start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
    var delta := finish - start
    var cable := MeshInstance3D.new()
    cable.name = "SaggingUtilityCable"
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = delta.length()
    cable.mesh = mesh
    cable.position = (start + finish) * 0.5
    cable.quaternion = Quaternion(Vector3.UP, delta.normalized())
    cable.material_override = material
    add_child(cable)
    cable.add_to_group("utility_cables")

func _material(color: Color) -> StandardMaterial3D:
    var key := color.to_html(true)
    if material_cache.has(key):
        return material_cache[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.92
    material_cache[key] = mat
    return mat

func _building(pos: Vector3, size: Vector3, color: Color) -> void:
    var building := _box("Building", pos + Vector3(0,size.y/2,0), size, color, true)
    building.add_to_group("arena_buildings")
    _box("RoofRubble", pos + Vector3(0,size.y + 0.3,0), Vector3(size.x*0.45,0.6,size.z*0.5), color.darkened(0.18), true)
    # Repeated window bays with recessed glass, chipped concrete surrounds, and sill lines.
    var columns := maxi(2, int(size.x / 3.0))
    var rows := maxi(1, int(size.y / 3.2))
    for row in range(rows):
        var wy := pos.y + 1.9 + float(row) * 2.65
        if wy > pos.y + size.y - 1.0:
            continue
        for col in range(columns):
            var wx := pos.x - size.x * 0.5 + size.x * (float(col) + 0.5) / float(columns)
            var ww := minf(1.15, size.x / float(columns) * 0.48)
            var glass := Color(0.055, 0.07, 0.07) if (row + col) % 3 != 0 else Color(0.12, 0.13, 0.12)
            _box("WindowRecess", Vector3(wx, wy, pos.z - size.z * 0.5 - 0.035), Vector3(ww, 1.15, 0.07), glass, false)
            _box("WindowLintel", Vector3(wx, wy + 0.64, pos.z - size.z * 0.5 - 0.08), Vector3(ww + 0.22, 0.12, 0.16), color.lightened(0.08), false)
            _box("WindowSill", Vector3(wx, wy - 0.64, pos.z - size.z * 0.5 - 0.08), Vector3(ww + 0.28, 0.13, 0.18), color.darkened(0.12), false)
            if (row + col) % 4 == 1:
                _box("BrokenShutter", Vector3(wx + ww * 0.25, wy, pos.z - size.z * 0.5 - 0.13), Vector3(0.08, 0.95, 0.08), Color(0.16, 0.15, 0.12), false)
    # One damaged balcony per block gives the skyline a different silhouette
    # while keeping the collision hull simple and predictable.
    var balcony_col := columns - 1 if pos.x < 0.0 else 0
    var balcony_x := pos.x - size.x * 0.5 + size.x * (float(balcony_col) + 0.5) / float(columns)
    var balcony_y := pos.y + 2.1
    var balcony_width := minf(1.15, size.x / float(columns) * 0.48)
    var balcony_z := pos.z - size.z * 0.5 - 0.58
    var balcony := _box("DamagedBalcony", Vector3(balcony_x, balcony_y - 0.72, balcony_z), Vector3(balcony_width + 0.52, 0.14, 0.82), color.darkened(0.12), true)
    balcony.add_to_group("facade_balconies")
    var rail_material := Color(0.15, 0.16, 0.14)
    _box("BalconyFrontRail", Vector3(balcony_x, balcony_y - 0.12, balcony_z - 0.36), Vector3(balcony_width + 0.42, 0.075, 0.065), rail_material, true)
    for side in [-1.0, 1.0]:
        _box("BalconySideRail", Vector3(balcony_x + side * (balcony_width + 0.42) * 0.5, balcony_y - 0.35, balcony_z), Vector3(0.065, 0.62, 0.72), rail_material, true)
        _box("BalconyRailPost", Vector3(balcony_x + side * (balcony_width + 0.42) * 0.5, balcony_y - 0.35, balcony_z - 0.36), Vector3(0.065, 0.62, 0.065), rail_material, true)

    # Exposed reinforcement, cracked plaster, and battered service equipment.
    for damage_index in range(2):
        var crack_x := pos.x + (-0.24 if damage_index == 0 else 0.31) * size.x
        var crack_y := pos.y + size.y * (0.42 if damage_index == 0 else 0.68)
        var crack := _box("FacadeCrack", Vector3(crack_x, crack_y, pos.z - size.z * 0.5 - 0.17), Vector3(0.055, minf(2.1, size.y * 0.34), 0.035), color.darkened(0.32), false)
        crack.rotation_degrees.z = -18.0 if damage_index == 0 else 13.0
        crack.add_to_group("facade_damage_details")
        var rebar := _box("RustedRebar", Vector3(pos.x + (-0.32 if damage_index == 0 else 0.34) * size.x, pos.y + size.y + 0.34, pos.z - size.z * 0.2), Vector3(0.045, 0.78, 0.045), Color(0.23, 0.12, 0.075), false)
        rebar.rotation_degrees.z = 24.0 if damage_index == 0 else -21.0
        rebar.add_to_group("facade_damage_details")
    var ac_unit := _box("BatteredAirConditioner", Vector3(pos.x + size.x * 0.27, pos.y + minf(3.1, size.y * 0.52), pos.z - size.z * 0.5 - 0.24), Vector3(0.72, 0.46, 0.28), Color(0.19, 0.20, 0.18), true)
    ac_unit.add_to_group("facade_damage_details")
    for grille_index in range(3):
        _box("AirConditionerGrille", Vector3(pos.x + size.x * 0.27 - 0.2 + float(grille_index) * 0.2, pos.y + minf(3.1, size.y * 0.52), pos.z - size.z * 0.5 - 0.40), Vector3(0.035, 0.29, 0.025), Color(0.07, 0.08, 0.075), false)

    # Side-wall vents and a service entrance break up the large silhouette.
    for side in [-1.0, 1.0]:
        for row in range(rows):
            var wy := pos.y + 2.0 + float(row) * 2.7
            if wy > pos.y + size.y - 0.8:
                continue
            var wz: float = pos.z + side * size.z * 0.5 + side * 0.045
            for col in range(2):
                var wx := pos.x - size.x * 0.22 + float(col) * size.x * 0.44
                _box("SideWindow", Vector3(wx, wy, wz), Vector3(0.06, 0.9, 1.0), Color(0.055, 0.065, 0.06), false)
        _box("FacadePipe", Vector3(pos.x + side * (size.x * 0.5 - 0.28), pos.y + size.y * 0.5, pos.z - size.z * 0.5 - 0.1), Vector3(0.09, size.y, 0.09), Color(0.20, 0.20, 0.18), false)
    _box("ServiceDoor", Vector3(pos.x - size.x * 0.28, pos.y + 1.0, pos.z - size.z * 0.5 - 0.06), Vector3(1.0, 2.0, 0.1), Color(0.12, 0.13, 0.12), false)
    _box("FacadeBand", Vector3(pos.x, pos.y + size.y - 0.25, pos.z - size.z * 0.5 - 0.08), Vector3(size.x + 0.25, 0.18, 0.18), color.darkened(0.16), false)

func _car(pos: Vector3, yaw: float) -> void:
    var root := Node3D.new()
    root.name = "WreckedVehicle"
    root.position = pos
    root.rotation_degrees.y = yaw
    root.add_to_group("vehicle_props")
    add_child(root)

    _box_child(root, "CarBody", Vector3(0, 0.65, 0), Vector3(2.0, 0.75, 4.0), Color(0.17, 0.20, 0.19), true)
    _box_child(root, "CarHood", Vector3(0, 1.02, -1.18), Vector3(1.78, 0.16, 1.42), Color(0.14, 0.17, 0.16), true)
    _box_child(root, "CarTrunk", Vector3(0, 1.02, 1.45), Vector3(1.72, 0.15, 0.82), Color(0.13, 0.16, 0.15), true)
    _box_child(root, "CarCabin", Vector3(0, 1.25, -0.2), Vector3(1.55, 0.7, 1.8), Color(0.075, 0.09, 0.09), true)

    var glass_material := StandardMaterial3D.new()
    glass_material.albedo_color = Color(0.045, 0.075, 0.078)
    glass_material.metallic = 0.18
    glass_material.roughness = 0.24
    glass_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    _box_child(root, "FrontWindshield", Vector3(0, 1.49, -1.12), Vector3(1.38, 0.43, 0.055), glass_material.albedo_color, false)
    _box_child(root, "RearWindow", Vector3(0, 1.49, 0.78), Vector3(1.32, 0.40, 0.055), glass_material.albedo_color, false)
    for side in [-1.0, 1.0]:
        _box_child(root, "FrontSideWindow", Vector3(side * 0.79, 1.48, -0.62), Vector3(0.045, 0.38, 0.72), glass_material.albedo_color, false)
        _box_child(root, "RearSideWindow", Vector3(side * 0.79, 1.48, 0.27), Vector3(0.045, 0.34, 0.58), glass_material.albedo_color, false)
        _box_child(root, "SideMirror", Vector3(side * 0.96, 1.32, -0.75), Vector3(0.16, 0.12, 0.20), Color(0.09, 0.10, 0.095), true)
        _box_child(root, "FrontDoorHandle", Vector3(side * 1.01, 0.91, -0.35), Vector3(0.035, 0.045, 0.20), Color(0.28, 0.29, 0.26), false)
        _box_child(root, "RearDoorHandle", Vector3(side * 1.01, 0.91, 0.43), Vector3(0.035, 0.045, 0.20), Color(0.28, 0.29, 0.26), false)

    _box_child(root, "FrontBumper", Vector3(0, 0.43, -2.02), Vector3(1.92, 0.19, 0.16), Color(0.10, 0.11, 0.105), true)
    _box_child(root, "RearBumper", Vector3(0, 0.43, 2.02), Vector3(1.92, 0.19, 0.16), Color(0.10, 0.11, 0.105), true)
    _box_child(root, "FrontGrille", Vector3(0, 0.69, -2.025), Vector3(0.64, 0.25, 0.045), Color(0.035, 0.04, 0.038), false)
    for grille_bar in range(5):
        _box_child(root, "GrilleBar_%02d" % grille_bar, Vector3(-0.25 + float(grille_bar) * 0.125, 0.69, -2.055), Vector3(0.035, 0.22, 0.025), Color(0.24, 0.25, 0.22), false)

    var headlight_material := StandardMaterial3D.new()
    headlight_material.albedo_color = Color(0.72, 0.61, 0.42)
    headlight_material.emission_enabled = true
    headlight_material.emission = Color(0.35, 0.22, 0.09)
    for side in [-1.0, 1.0]:
        var headlight := _box_child(root, "Headlight", Vector3(side * 0.69, 0.78, -2.04), Vector3(0.34, 0.18, 0.05), headlight_material.albedo_color, false)
        var headlight_mesh := headlight.get_child(0) as MeshInstance3D
        headlight_mesh.material_override = headlight_material
        _box_child(root, "TailLight", Vector3(side * 0.70, 0.78, 2.025), Vector3(0.30, 0.17, 0.055), Color(0.34, 0.075, 0.045), false)
    for side in [-1.0, 1.0]:
        for axle in [-1.0, 1.0]:
            var wheel_body := StaticBody3D.new()
            wheel_body.name = "VehicleWheel"
            wheel_body.position = Vector3(side * 0.91, 0.31, axle * 1.28)
            wheel_body.rotation.z = PI * 0.5
            wheel_body.add_to_group("vehicle_collision")
            root.add_child(wheel_body)
            var wheel_mesh := MeshInstance3D.new()
            var tire := CylinderMesh.new()
            tire.top_radius = 0.32
            tire.bottom_radius = 0.32
            tire.height = 0.24
            wheel_mesh.mesh = tire
            wheel_mesh.material_override = _material(Color(0.035, 0.038, 0.036))
            wheel_body.add_child(wheel_mesh)
            var wheel_collision := CollisionShape3D.new()
            var wheel_shape := CylinderShape3D.new()
            wheel_shape.radius = 0.31
            wheel_shape.height = 0.26
            wheel_collision.shape = wheel_shape
            wheel_body.add_child(wheel_collision)
            var rim := MeshInstance3D.new()
            var rim_mesh := CylinderMesh.new()
            rim_mesh.top_radius = 0.16
            rim_mesh.bottom_radius = 0.16
            rim_mesh.height = 0.255
            rim.mesh = rim_mesh
            rim.material_override = _material(Color(0.24, 0.25, 0.23))
            wheel_body.add_child(rim)
            for spoke_index in range(5):
                var spoke := MeshInstance3D.new()
                var spoke_mesh := BoxMesh.new()
                spoke_mesh.size = Vector3(0.045, 0.035, 0.018)
                spoke.mesh = spoke_mesh
                spoke.position = Vector3(0.0, cos(float(spoke_index) * TAU / 5.0) * 0.095, sin(float(spoke_index) * TAU / 5.0) * 0.095)
                spoke.rotation.y = float(spoke_index) * TAU / 5.0
                spoke.material_override = _material(Color(0.35, 0.36, 0.33))
                wheel_body.add_child(spoke)
    for side in [-1.0, 1.0]:
        _box_child(root, "HoodDamageSeam", Vector3(side * 0.62, 1.11, -1.20), Vector3(0.035, 0.018, 1.15), Color(0.075, 0.085, 0.08), false)
    _box_child(root, "CrackedTailgatePanel", Vector3(0, 1.105, 1.86), Vector3(1.2, 0.025, 0.04), Color(0.075, 0.085, 0.08), false)

func _box(name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
    var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
    root.name = name
    root.position = pos
    root.add_child(_mesh_box(size, color, _surface_kind_for_name(name)))
    if collision:
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        root.add_child(col)
    add_child(root)
    return root

func _surface_kind_for_name(label: String) -> float:
    if label in ["Ground", "Terrain", "Dirt", "Rubble", "ConcreteRubble", "FacadeCollapseRubble", "StreetDebris"]:
        return 2.0
    if label in ["Road", "BrokenAsphalt", "RoadGutter", "ServiceLane"]:
        return 1.0
    if label in ["Building", "OuterDistrictBuilding", "RoofRubble", "CollapsedRoof", "ConcreteBarrier", "ExposedFacadeRib", "DamagedBalcony"]:
        return 0.0
    return -1.0

func _surface_material(color: Color, surface_kind: float) -> ShaderMaterial:
    var key := "surface:%s:%s" % [color.to_html(true), str(surface_kind)]
    if material_cache.has(key):
        return material_cache[key] as ShaderMaterial
    var shader_material := ShaderMaterial.new()
    shader_material.shader = load("res://shaders/battlefield_surface.gdshader") as Shader
    shader_material.set_shader_parameter("base_color", color)
    shader_material.set_shader_parameter("surface_kind", surface_kind)
    shader_material.set_shader_parameter("detail_scale", 1.0)
    material_cache[key] = shader_material
    return shader_material

func _box_child(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
    var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
    root.name = name
    root.position = pos
    root.add_child(_mesh_box(size, color))
    if collision:
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        root.add_child(col)
    parent.add_child(root)
    return root

func _mesh_box(size: Vector3, color: Color, surface_kind: float = -1.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _surface_material(color, surface_kind) if surface_kind >= 0.0 else _material(color)
    return mi

func _spawn_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.add_to_group("player")
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 1.2, 25)
    add_child(player)

func _spawn_ammo_caches() -> void:
    var positions := [Vector3(-12.0, 0.0, 22.0), Vector3(12.0, 0.0, -4.0), Vector3(27.0, 0.0, 18.0)]
    for index in range(positions.size()):
        var cache := Node3D.new()
        cache.name = "AmmoCache_%02d" % (index + 1)
        cache.position = positions[index]
        cache.set_script(load("res://scripts/ammo_cache.gd"))
        add_child(cache)

func _spawn_enemies() -> void:
    var positions := [Vector3(-8,0,-13), Vector3(8,0,-24), Vector3(17,0,1), Vector3(-17,0,16), Vector3(3,0,-38)]
    var roles := ["ASSAULT", "SUPPORT", "FLANKER", "RIFLEMAN", "FLANKER"]
    for i in range(positions.size()):
        var enemy := CharacterBody3D.new()
        enemy.name = "Vanguard_%02d" % (i+1)
        enemy.set_script(ENEMY_SCRIPT)
        enemy.position = positions[i] + Vector3(0,0.95,0)
        enemy.set_meta("arena", self)
        add_child(enemy)
        enemy.set_combat_role(roles[i])
        enemy.set_difficulty(difficulty)
        enemies.append(enemy)

func _spawn_objective() -> void:
    var marker := Node3D.new()
    marker.name = "IntelObjective"
    marker.position = Vector3(0, 0.05, -31)
    var ring := MeshInstance3D.new()
    ring.name = "IntelBeaconRing"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.55
    mesh.bottom_radius = 0.55
    mesh.height = 0.08
    ring.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.82,0.48,0.12)
    mat.emission_enabled = true
    mat.emission = Color(0.65,0.25,0.04)
    ring.material_override = mat
    marker.add_child(ring)

    var beam := MeshInstance3D.new()
    beam.name = "IntelBeaconBeam"
    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.035
    beam_mesh.bottom_radius = 0.035
    beam_mesh.height = 2.2
    beam.mesh = beam_mesh
    beam.position.y = 1.1
    var beam_material := StandardMaterial3D.new()
    beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_material.albedo_color = Color(1.0, 0.55, 0.16, 0.28)
    beam_material.emission_enabled = true
    beam_material.emission = Color(0.55, 0.16, 0.025)
    beam.material_override = beam_material
    marker.add_child(beam)

    var beacon_light := OmniLight3D.new()
    beacon_light.name = "IntelBeaconLight"
    beacon_light.position = Vector3(0.0, 1.2, 0.0)
    beacon_light.light_color = Color(1.0, 0.48, 0.14)
    beacon_light.light_energy = 0.8
    beacon_light.omni_range = 5.0
    beacon_light.shadow_enabled = false
    marker.add_child(beacon_light)

    marker.set_script(load("res://scripts/objective.gd"))
    add_child(marker)

func _spawn_hud() -> void:
    hud = CanvasLayer.new()
    hud.set_script(HUD_SCRIPT)
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(hud)
    hud.call("initialize", self, player)

func _show_pause() -> void:
    if is_instance_valid(hud):
        hud.call("show_pause")

func report_noise(source_position: Vector3, radius: float, noise_type: String = "GUNSHOT", source_node: Node3D = null) -> int:
    if radius <= 0.0:
        return 0
    var heard_count := 0
    var space := get_world_3d().direct_space_state
    for enemy in enemies:
        var enemy_body := enemy as CharacterBody3D
        if not is_instance_valid(enemy_body) or float(enemy_body.get("health")) <= 0.0:
            continue
        var distance := enemy_body.global_position.distance_to(source_position)
        if distance > radius:
            continue
        var query := PhysicsRayQueryParameters3D.create(source_position + Vector3.UP * 1.1, enemy_body.global_position + Vector3.UP * 1.1)
        var exclusions: Array[RID] = [enemy_body.get_rid()]
        if is_instance_valid(player):
            exclusions.append(player.get_rid())
        var source_body := source_node as CollisionObject3D
        if is_instance_valid(source_body):
            exclusions.append(source_body.get_rid())
        query.exclude = exclusions
        query.collision_mask = 1
        var obstruction := space.intersect_ray(query)
        var effective_radius := radius
        if not obstruction.is_empty():
            effective_radius *= 0.45 if noise_type == "FOOTSTEP" else 0.72
        if distance > effective_radius:
            continue
        if enemy_body.has_method("hear_noise"):
            enemy_body.call("hear_noise", source_position, noise_type)
            heard_count += 1
    return heard_count

func enemy_killed(enemy: Node) -> void:
    if enemies.has(enemy):
        enemies.erase(enemy)
        hostiles_eliminated += 1
    if is_instance_valid(hud):
        hud.call("set_enemy_count", enemies.size())
    if enemies.is_empty():
        if is_instance_valid(hud):
            hud.call("set_mission_state", "AREA SECURE. RECOVER THE INTEL.")

func get_remaining_enemies() -> int:
    return enemies.size()

func objective_complete() -> void:
    _spawn_exfil_zone()
    if is_instance_valid(hud):
        hud.call("set_mission_state", "INTEL SECURED. MOVE TO EXFIL.")

func _spawn_exfil_zone() -> void:
    if get_node_or_null("ExfilZone"):
        return
    var zone := Node3D.new()
    zone.name = "ExfilZone"
    zone.position = Vector3(0.0, 0.05, 39.0)
    zone.set_script(load("res://scripts/exfil_zone.gd"))
    add_child(zone)

func exfiltration_complete() -> void:
    mission_complete = true
    if is_instance_valid(hud):
        hud.call("set_mission_state", "INTEL RECOVERED. EXFILTRATION COMPLETE.")
