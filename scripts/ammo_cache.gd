extends Node3D

const RESUPPLY_AMOUNT := 30
const MAX_RESERVE_AMMO := 180

var player_inside := false
var used := false
var current_status := ""
var area: Area3D
var crate_body: StaticBody3D
var ammo_visuals: Node3D

func _ready() -> void:
    add_to_group("ammo_caches")
    _build_cache_visuals()
    area = Area3D.new()
    area.name = "AmmoPickupArea"
    area.collision_layer = 0
    area.collision_mask = 1
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 2.1
    shape_node.shape = shape
    area.add_child(shape_node)
    add_child(area)
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)

func _build_cache_visuals() -> void:
    crate_body = StaticBody3D.new()
    crate_body.name = "AmmoCrateBody"
    crate_body.position.y = 0.42
    var crate_mesh := MeshInstance3D.new()
    crate_mesh.name = "AmmoCrateMesh"
    var box := BoxMesh.new()
    box.size = Vector3(1.15, 0.84, 0.9)
    crate_mesh.mesh = box
    var crate_material := StandardMaterial3D.new()
    crate_material.albedo_color = Color(0.20, 0.23, 0.18)
    crate_material.roughness = 0.95
    crate_mesh.material_override = crate_material
    crate_body.add_child(crate_mesh)
    var collision := CollisionShape3D.new()
    var collision_shape := BoxShape3D.new()
    collision_shape.size = box.size
    collision.shape = collision_shape
    crate_body.add_child(collision)
    add_child(crate_body)

    ammo_visuals = Node3D.new()
    ammo_visuals.name = "AmmoContents"
    for index in range(3):
        var round_mesh := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.045
        cylinder.bottom_radius = 0.045
        cylinder.height = 0.22
        round_mesh.mesh = cylinder
        round_mesh.position = Vector3(-0.22 + float(index) * 0.22, 0.93, 0.0)
        var round_material := StandardMaterial3D.new()
        round_material.albedo_color = Color(0.56, 0.43, 0.22)
        round_material.metallic = 0.42
        round_material.roughness = 0.55
        round_mesh.material_override = round_material
        ammo_visuals.add_child(round_mesh)
    add_child(ammo_visuals)

func _process(_delta: float) -> void:
    if used or not player_inside or not Input.is_action_pressed("interact"):
        return
    var scene := get_tree().current_scene
    var player: Node = null
    if is_instance_valid(scene):
        player = scene.get("player") as Node
    if not is_instance_valid(player):
        return
    var reserve := int(player.get("reserve"))
    var available := MAX_RESERVE_AMMO - reserve
    if available <= 0:
        _set_status("AMMUNITION RESERVES FULL")
        return
    var added := mini(RESUPPLY_AMOUNT, available)
    player.set("reserve", reserve + added)
    used = true
    if scene.has_method("register_ammo_cache_used"):
        scene.register_ammo_cache_used()
    crate_body.queue_free()
    ammo_visuals.queue_free()
    var hud_node := scene.get("hud") as Node
    if is_instance_valid(hud_node) and hud_node.has_method("set_ammo"):
        hud_node.set_ammo(int(player.get("ammo")), reserve + added)
    _set_status("AMMO CACHE COLLECTED  +%d" % added)

func _on_enter(body: Node3D) -> void:
    if body.is_in_group("player") or body.name == "Player":
        player_inside = true
        if not used:
            _set_status("PRESS F TO RESUPPLY  /  +30 ROUNDS")

func _on_exit(body: Node3D) -> void:
    if body.is_in_group("player") or body.name == "Player":
        player_inside = false
        _set_status("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   Z PRONE   RMB AIM   LMB FIRE   R RELOAD   F INTERACT   G GRENADE")

func _set_status(message: String) -> void:
    if current_status == message:
        return
    current_status = message
    var scene := get_tree().current_scene
    if scene:
        var hud_node := scene.get("hud") as Node
        if is_instance_valid(hud_node) and hud_node.has_method("set_status"):
            hud_node.set_status(message)
