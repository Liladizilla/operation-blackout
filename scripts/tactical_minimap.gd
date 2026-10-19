extends Control

const WORLD_HALF_EXTENT := 50.0
const PADDING := 10.0
const REDRAW_INTERVAL := 0.12

var redraw_timer := 0.0

func _ready() -> void:
    name = "TacticalMinimap"
    custom_minimum_size = Vector2(190.0, 190.0)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _process(delta: float) -> void:
    redraw_timer -= delta
    if redraw_timer <= 0.0:
        redraw_timer = REDRAW_INTERVAL
        queue_redraw()

func world_to_map(world_position: Vector3) -> Vector2:
    var usable_width := maxf(size.x - PADDING * 2.0, 1.0)
    var usable_height := maxf(size.y - PADDING * 2.0, 1.0)
    var scale := minf(usable_width, usable_height) / (WORLD_HALF_EXTENT * 2.0)
    var center := size * 0.5
    return Vector2(
        clampf(center.x + world_position.x * scale, PADDING, maxf(PADDING, size.x - PADDING)),
        clampf(center.y + world_position.z * scale, PADDING, maxf(PADDING, size.y - PADDING))
    )

func get_visible_enemy_contacts() -> Array[Node3D]:
    var contacts: Array[Node3D] = []
    var scene := get_tree().current_scene
    if not is_instance_valid(scene):
        return contacts
    var enemies: Array = scene.get("enemies")
    for enemy in enemies:
        if not is_instance_valid(enemy) or float(enemy.get("health")) <= 0.0:
            continue
        var state := String(enemy.get("state"))
        var memory := float(enemy.get("alert_memory_timer"))
        if state == "COMBAT" or memory > 0.0:
            contacts.append(enemy as Node3D)
    return contacts

func _draw() -> void:
    if size.x < 20.0 or size.y < 20.0:
        return
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.045, 0.04, 0.94), true)
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.43, 0.40, 0.32, 0.95), false, 1.4)
    draw_string(ThemeDB.fallback_font, Vector2(9.0, 15.0), "TACTICAL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.78, 0.75, 0.64))
    draw_string(ThemeDB.fallback_font, Vector2(size.x - 16.0, 15.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.86, 0.84, 0.74))

    for coordinate in [-40.0, -20.0, 0.0, 20.0, 40.0]:
        draw_line(world_to_map(Vector3(coordinate, 0.0, -50.0)), world_to_map(Vector3(coordinate, 0.0, 50.0)), Color(0.15, 0.17, 0.15, 0.85), 1.0)
        draw_line(world_to_map(Vector3(-50.0, 0.0, coordinate)), world_to_map(Vector3(50.0, 0.0, coordinate)), Color(0.15, 0.17, 0.15, 0.85), 1.0)

    var road_start := world_to_map(Vector3(-7.0, 0.0, -42.0))
    var road_end := world_to_map(Vector3(7.0, 0.0, 36.0))
    draw_rect(Rect2(road_start, road_end - road_start), Color(0.105, 0.115, 0.105, 0.96), true)
    var alley_start := world_to_map(Vector3(-28.25, 0.0, -36.0))
    var alley_end := world_to_map(Vector3(-22.75, 0.0, 36.0))
    draw_rect(Rect2(alley_start, alley_end - alley_start), Color(0.09, 0.10, 0.09, 0.96), true)

    _draw_building_group("arena_buildings", Color(0.29, 0.30, 0.27, 1.0))
    _draw_building_group("district_buildings", Color(0.25, 0.27, 0.25, 1.0))
    _draw_building_group("arena_cover", Color(0.50, 0.47, 0.38, 1.0))

    var scene := get_tree().current_scene
    if not is_instance_valid(scene):
        return
    for cache in get_tree().get_nodes_in_group("ammo_caches"):
        if is_instance_valid(cache) and not bool(cache.get("used")):
            _draw_square(world_to_map(cache.global_position), 3.2, Color(0.72, 0.67, 0.42))
    for crate in get_tree().get_nodes_in_group("service_alley_crates"):
        if is_instance_valid(crate):
            _draw_square(world_to_map(crate.global_position), 2.5, Color(0.45, 0.48, 0.39))

    var objective := scene.get_node_or_null("IntelObjective") as Node3D
    if is_instance_valid(objective):
        draw_circle(world_to_map(objective.global_position), 4.2, Color(0.98, 0.64, 0.20))
        draw_circle(world_to_map(objective.global_position), 6.2, Color(0.98, 0.64, 0.20, 0.30), false, 1.0)
    var exfil := scene.get_node_or_null("ExfilZone") as Node3D
    if is_instance_valid(exfil):
        draw_circle(world_to_map(exfil.global_position), 4.2, Color(0.35, 0.85, 0.55))
        draw_circle(world_to_map(exfil.global_position), 6.2, Color(0.35, 0.85, 0.55, 0.30), false, 1.0)

    for enemy in get_visible_enemy_contacts():
        draw_circle(world_to_map(enemy.global_position), 3.2, Color(0.88, 0.24, 0.17))

    var player := scene.get("player") as Node3D
    if is_instance_valid(player):
        var forward: Vector3 = -player.global_transform.basis.z
        var right: Vector3 = player.global_transform.basis.x
        var tip := world_to_map(player.global_position + forward * 2.5)
        var rear_left := world_to_map(player.global_position - forward * 1.2 - right * 0.9)
        var rear_right := world_to_map(player.global_position - forward * 1.2 + right * 0.9)
        draw_colored_polygon(PackedVector2Array([tip, rear_left, rear_right]), Color(0.88, 0.91, 0.80))

func _draw_building_group(group_name: String, color: Color) -> void:
    for building in get_tree().get_nodes_in_group(group_name):
        if not is_instance_valid(building):
            continue
        var collision := building.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if not is_instance_valid(collision):
            continue
        var shape := collision.shape as BoxShape3D
        if not is_instance_valid(shape):
            continue
        var top_left := world_to_map(building.global_position + Vector3(-shape.size.x * 0.5, 0.0, -shape.size.z * 0.5))
        var bottom_right := world_to_map(building.global_position + Vector3(shape.size.x * 0.5, 0.0, shape.size.z * 0.5))
        var rect := Rect2(top_left, bottom_right - top_left)
        draw_rect(rect, color, true)
        draw_rect(rect, Color(0.06, 0.07, 0.06, 0.95), false, 1.0)

func _draw_square(center: Vector2, diameter: float, color: Color) -> void:
    draw_rect(Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), color, true)
