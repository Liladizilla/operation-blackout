extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var enemies: Array[Node] = []
var mission_complete := false
var world_environment: WorldEnvironment

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_input()
    _build_environment()
    _build_arena()
    _spawn_player()
    _spawn_enemies()
    _spawn_objective()
    _spawn_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_input() -> void:
    _key_action("move_forward", KEY_W)
    _key_action("move_back", KEY_S)
    _key_action("move_left", KEY_A)
    _key_action("move_right", KEY_D)
    _key_action("sprint", KEY_SHIFT)
    _key_action("crouch", KEY_CTRL)
    _key_action("prone", KEY_Z)
    _key_action("jump", KEY_SPACE)
    _key_action("reload", KEY_R)
    _key_action("interact", KEY_F)
    _key_action("pause", KEY_ESCAPE)

func _key_action(action: String, keycode: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    if not InputMap.action_has_event(action, event):
        InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            get_tree().paused = true
            _show_pause()
        else:
            get_tree().paused = false
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not get_tree().paused:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
    world_environment = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.12, 0.17, 0.20)
    sky_mat.sky_horizon_color = Color(0.48, 0.43, 0.34)
    sky_mat.ground_bottom_color = Color(0.055, 0.06, 0.055)
    sky_mat.ground_horizon_color = Color(0.28, 0.26, 0.22)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.42, 0.44, 0.43)
    env.ambient_light_energy = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.42, 0.40, 0.35)
    env.fog_density = 0.006
    world_environment.environment = env
    add_child(world_environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42, -28, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

func _build_environment() -> void:
    _setup_environment()

func _build_arena() -> void:
    _box("Ground", Vector3(0, -0.5, 0), Vector3(100, 1, 100), Color(0.19, 0.20, 0.18), true)
    _box("Road", Vector3(0, 0.015, -3), Vector3(14, 0.04, 78), Color(0.105, 0.11, 0.105), false)
    for z in range(-36, 38, 12):
        _box("RoadMark", Vector3(0, 0.04, float(z)), Vector3(0.18, 0.02, 4.5), Color(0.55, 0.49, 0.35), false)
    _building(Vector3(-17, 0, -17), Vector3(12, 9, 12), Color(0.32, 0.30, 0.26))
    _building(Vector3(18, 0, -23), Vector3(13, 12, 15), Color(0.28, 0.29, 0.27))
    _building(Vector3(-22, 0, 8), Vector3(10, 7, 14), Color(0.36, 0.32, 0.27))
    _building(Vector3(21, 0, 13), Vector3(12, 8, 12), Color(0.31, 0.30, 0.28))
    _building(Vector3(-7, 0, -34), Vector3(12, 6, 7), Color(0.34, 0.30, 0.25))
    _building(Vector3(9, 0, 33), Vector3(15, 7, 8), Color(0.29, 0.30, 0.28))
    for p in [Vector3(-7,0,-10), Vector3(7,0,-18), Vector3(-5,0,7), Vector3(6,0,19), Vector3(-12,0,25), Vector3(13,0,-1)]:
        _box("ConcreteBarrier", p + Vector3(0,0.65,0), Vector3(3.4,1.3,0.7), Color(0.39,0.38,0.33), true)
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

func _building(pos: Vector3, size: Vector3, color: Color) -> void:
    _box("Building", pos + Vector3(0,size.y/2,0), size, color, true)
    _box("RoofRubble", pos + Vector3(0,size.y + 0.3,0), Vector3(size.x*0.45,0.6,size.z*0.5), color.darkened(0.18), true)
    for i in range(3):
        var wx := pos.x - size.x*0.28 + float(i)*size.x*0.28
        _box("DarkWindow", Vector3(wx, pos.y + size.y*0.63, pos.z - size.z/2 - 0.025), Vector3(1.2,1.4,0.06), Color(0.07,0.09,0.09), false)

func _car(pos: Vector3, yaw: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation_degrees.y = yaw
    add_child(root)
    _box_child(root, "CarBody", Vector3(0,0.65,0), Vector3(2.0,0.75,4.0), Color(0.17,0.20,0.19), true)
    _box_child(root, "CarCabin", Vector3(0,1.25,-0.2), Vector3(1.55,0.7,1.8), Color(0.10,0.13,0.13), true)
    for x in [-0.85, 0.85]:
        for z in [-1.25, 1.25]:
            var wheel := _mesh_box(Vector3(0.22,0.22,0.42), Color(0.045,0.045,0.04))
            wheel.position = Vector3(x,0.28,z)
            root.add_child(wheel)
            var col := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = Vector3(0.22,0.22,0.42)
            col.shape = shape
            col.position = wheel.position
            root.add_child(col)

func _box(name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
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
    add_child(root)
    return root

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

func _mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.92
    mi.material_override = mat
    return mi

func _spawn_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 1.2, 25)
    add_child(player)

func _spawn_enemies() -> void:
    var positions := [Vector3(-8,0,-13), Vector3(8,0,-24), Vector3(17,0,1), Vector3(-17,0,16), Vector3(3,0,-38)]
    for i in range(positions.size()):
        var enemy := CharacterBody3D.new()
        enemy.name = "Vanguard_%02d" % (i+1)
        enemy.set_script(ENEMY_SCRIPT)
        enemy.position = positions[i] + Vector3(0,0.95,0)
        enemy.set_meta("arena", self)
        add_child(enemy)
        enemies.append(enemy)

func _spawn_objective() -> void:
    var marker := Node3D.new()
    marker.name = "IntelObjective"
    marker.position = Vector3(0, 0.05, -31)
    add_child(marker)
    var ring := MeshInstance3D.new()
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
    marker.set_script(load("res://scripts/objective.gd"))

func _spawn_hud() -> void:
    hud = CanvasLayer.new()
    hud.set_script(HUD_SCRIPT)
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(hud)
    hud.call("initialize", self, player)

func _show_pause() -> void:
    if is_instance_valid(hud):
        hud.call("show_pause")

func enemy_killed(enemy: Node) -> void:
    if enemies.has(enemy):
        enemies.erase(enemy)
    if is_instance_valid(hud):
        hud.call("set_enemy_count", enemies.size())
    if enemies.is_empty():
        mission_complete = true
        if is_instance_valid(hud):
            hud.call("set_mission_state", "AREA SECURE. RECOVER THE INTEL.")

func objective_complete() -> void:
    mission_complete = true
    if is_instance_valid(hud):
        hud.call("set_mission_state", "INTEL RECOVERED. EXFILTRATION COMPLETE.")
