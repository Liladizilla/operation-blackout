extends CanvasLayer

var root: Control
var ammo_label: Label
var health_label: Label
var enemy_label: Label
var status_label: Label
var objective_label: Label
var center_dot: Label
var hit_flash: ColorRect
var muzzle_flash: ColorRect
var owner_scene: Node
var player_ref: Node
var pause_panel: PanelContainer

func initialize(scene: Node, player: Node) -> void:
    owner_scene = scene
    player_ref = player
    player.set("hud", self)
    _build()

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    hit_flash = ColorRect.new()
    hit_flash.color = Color(0.65,0.03,0.02,0.0)
    hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hit_flash)
    muzzle_flash = ColorRect.new()
    muzzle_flash.color = Color(1.0,0.7,0.32,0.0)
    muzzle_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    muzzle_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(muzzle_flash)
    var top := _label("OPERATION BLACKOUT  /  FIRST LIGHT", 22, Color(0.85,0.78,0.61))
    top.position = Vector2(28,22)
    root.add_child(top)
    objective_label = _label("OBJECTIVE  //  SECURE THE INTERCEPTED INTEL", 18, Color(0.92,0.90,0.82))
    objective_label.position = Vector2(28,58)
    root.add_child(objective_label)
    enemy_label = _label("VANGUARD HOSTILES: 5", 16, Color(0.82,0.36,0.25))
    enemy_label.position = Vector2(28,88)
    root.add_child(enemy_label)
    health_label = _label("HEALTH  100", 18, Color(0.78,0.83,0.77))
    health_label.position = Vector2(28, get_viewport().get_visible_rect().size.y - 68)
    root.add_child(health_label)
    ammo_label = _label("30 / 120", 28, Color(0.92,0.90,0.82))
    ammo_label.anchor_left = 1
    ammo_label.anchor_right = 1
    ammo_label.offset_left = -240
    ammo_label.offset_right = -30
    ammo_label.offset_top = get_viewport().get_visible_rect().size.y - 86
    ammo_label.offset_bottom = get_viewport().get_visible_rect().size.y - 40
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(ammo_label)
    center_dot = _label("+", 30, Color(0.88,0.86,0.76))
    center_dot.anchor_left = 0.5
    center_dot.anchor_right = 0.5
    center_dot.anchor_top = 0.5
    center_dot.anchor_bottom = 0.5
    center_dot.offset_left = -10
    center_dot.offset_right = 10
    center_dot.offset_top = -22
    center_dot.offset_bottom = 22
    center_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(center_dot)
    status_label = _label("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   Z PRONE   RMB AIM   LMB FIRE   R RELOAD   F INTERACT", 13, Color(0.70,0.72,0.68))
    status_label.anchor_top = 1
    status_label.anchor_bottom = 1
    status_label.offset_left = 28
    status_label.offset_right = -28
    status_label.offset_top = -30
    status_label.offset_bottom = -8
    root.add_child(status_label)

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

func _process(delta: float) -> void:
    if hit_flash and hit_flash.color.a > 0:
        var c := hit_flash.color
        c.a = maxf(0.0, c.a - delta * 0.8)
        hit_flash.color = c
    if muzzle_flash and muzzle_flash.color.a > 0:
        var m := muzzle_flash.color
        m.a = maxf(0.0, m.a - delta * 8.0)
        muzzle_flash.color = m
    if is_instance_valid(player_ref):
        if player_ref.get("is_reloading"):
            status_label.text = "RELOADING..."
        elif objective_label.text.contains("RECOVER"):
            status_label.text = "REACH THE MARKER AND HOLD F TO RECOVER INTEL"
        else:
            status_label.text = "WASD MOVE   SHIFT SPRINT   CTRL CROUCH   Z PRONE   RMB AIM   LMB FIRE   R RELOAD   F INTERACT"

func set_ammo(current: int, reserve: int) -> void:
    ammo_label.text = "%02d / %03d" % [current, reserve]

func set_health(value: float) -> void:
    health_label.text = "HEALTH  %03d" % int(value)
    var c := hit_flash.color
    c.a = 0.22
    hit_flash.color = c

func set_enemy_count(count: int) -> void:
    enemy_label.text = "VANGUARD HOSTILES: %d" % count
    if count == 0:
        objective_label.text = "AREA SECURE  //  RECOVER THE INTERCEPTED INTEL"

func set_status(message: String) -> void:
    status_label.text = message

func set_mission_state(message: String) -> void:
    objective_label.text = message
    status_label.text = "MISSION UPDATE"

func flash_muzzle() -> void:
    var c := muzzle_flash.color
    c.a = 0.06
    muzzle_flash.color = c

func show_pause() -> void:
    if pause_panel:
        pause_panel.queue_free()
    pause_panel = PanelContainer.new()
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    pause_panel.offset_left = -180
    pause_panel.offset_right = 180
    pause_panel.offset_top = -100
    pause_panel.offset_bottom = 100
    var box := VBoxContainer.new()
    pause_panel.add_child(box)
    var title := _label("PAUSED", 28, Color(0.9,0.82,0.65))
    box.add_child(title)
    var resume := Button.new()
    resume.text = "RESUME"
    resume.pressed.connect(func():
        get_tree().paused = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        pause_panel.queue_free()
    )
    box.add_child(resume)
    var quit := Button.new()
    quit.text = "QUIT TO DESKTOP"
    quit.pressed.connect(func(): get_tree().quit())
    box.add_child(quit)
    root.add_child(pause_panel)
