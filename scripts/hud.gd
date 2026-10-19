extends CanvasLayer

var root: Control
var ammo_label: Label
var grenade_label: Label
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
var sensitivity_slider: HSlider
var sensitivity_value_label: Label
var briefing_panel: PanelContainer
var briefing_backdrop: ColorRect
var difficulty_selector: OptionButton
var difficulty_description: Label
var hitmarker_timer := 0.0
var damage_direction_label: Label
var damage_direction_timer := 0.0
var mission_panel: PanelContainer
var mission_stats_label: Label
var stamina_label: Label
var navigation_label: Label
var tactical_minimap: Control
var navigation_update_timer := 0.0

func initialize(scene: Node, player: Node) -> void:
    owner_scene = scene
    player_ref = player
    player.set("hud", self)
    _build()
    set_ammo(int(player.get("ammo")), int(player.get("reserve")))
    set_grenades(int(player.get("grenades")))
    health_label.text = "HEALTH  %03d" % int(player.get("health"))
    if scene.has_method("get_remaining_enemies"):
        set_enemy_count(scene.get_remaining_enemies())
    show_briefing()

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
    objective_label = _label("OBJECTIVE  //  ELIMINATE HOSTILES, THEN RECOVER INTEL", 18, Color(0.92,0.90,0.82))
    objective_label.position = Vector2(28,58)
    root.add_child(objective_label)
    enemy_label = _label("VANGUARD HOSTILES: 5", 16, Color(0.82,0.36,0.25))
    enemy_label.position = Vector2(28,88)
    root.add_child(enemy_label)
    health_label = _label("HEALTH  100", 18, Color(0.78,0.83,0.77))
    health_label.anchor_top = 1
    health_label.anchor_bottom = 1
    health_label.offset_left = 28
    health_label.offset_right = 220
    health_label.offset_top = -94
    health_label.offset_bottom = -70
    root.add_child(health_label)
    stamina_label = _label("STAMINA  100%", 15, Color(0.72,0.78,0.70))
    stamina_label.anchor_top = 1
    stamina_label.anchor_bottom = 1
    stamina_label.offset_left = 28
    stamina_label.offset_right = 220
    stamina_label.offset_top = -66
    stamina_label.offset_bottom = -44
    root.add_child(stamina_label)
    navigation_label = _label("INTEL  --m", 16, Color(0.88,0.76,0.50))
    navigation_label.anchor_left = 1
    navigation_label.anchor_right = 1
    navigation_label.offset_left = -320
    navigation_label.offset_right = -28
    navigation_label.offset_top = 24
    navigation_label.offset_bottom = 50
    navigation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(navigation_label)
    tactical_minimap = Control.new()
    tactical_minimap.name = "TacticalMinimap"
    tactical_minimap.set_script(load("res://scripts/tactical_minimap.gd"))
    tactical_minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    tactical_minimap.offset_left = -218.0
    tactical_minimap.offset_right = -28.0
    tactical_minimap.offset_top = 64.0
    tactical_minimap.offset_bottom = 254.0
    tactical_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(tactical_minimap)
    ammo_label = _label("30 / 120", 28, Color(0.92,0.90,0.82))
    ammo_label.anchor_left = 1
    ammo_label.anchor_right = 1
    ammo_label.anchor_top = 1
    ammo_label.anchor_bottom = 1
    ammo_label.offset_left = -240
    ammo_label.offset_right = -30
    ammo_label.offset_top = -86
    ammo_label.offset_bottom = -40
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(ammo_label)
    grenade_label = _label("FRAG  02", 16, Color(0.88,0.76,0.50))
    grenade_label.anchor_left = 1
    grenade_label.anchor_right = 1
    grenade_label.anchor_top = 1
    grenade_label.anchor_bottom = 1
    grenade_label.offset_left = -210
    grenade_label.offset_right = -30
    grenade_label.offset_top = -122
    grenade_label.offset_bottom = -94
    grenade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(grenade_label)
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
    damage_direction_label = _label("", 18, Color(0.92,0.24,0.16))
    damage_direction_label.anchor_left = 0.5
    damage_direction_label.anchor_right = 0.5
    damage_direction_label.anchor_top = 0.5
    damage_direction_label.anchor_bottom = 0.5
    damage_direction_label.offset_left = -100
    damage_direction_label.offset_right = 100
    damage_direction_label.offset_top = 34
    damage_direction_label.offset_bottom = 62
    damage_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(damage_direction_label)
    status_label = _label("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   Z PRONE   RMB AIM   LMB FIRE   R RELOAD   F INTERACT   G GRENADE", 13, Color(0.70,0.72,0.68))
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
    navigation_update_timer -= delta
    if navigation_update_timer <= 0.0:
        navigation_update_timer = 0.15
        _update_navigation()
    if is_instance_valid(player_ref):
        update_stamina(float(player_ref.get("stamina")), 8.0)
    if damage_direction_timer > 0.0:
        damage_direction_timer = maxf(0.0, damage_direction_timer - delta)
        if damage_direction_timer == 0.0 and is_instance_valid(damage_direction_label):
            damage_direction_label.text = ""
    if hitmarker_timer > 0.0:
        hitmarker_timer = maxf(0.0, hitmarker_timer - delta)
        if hitmarker_timer == 0.0 and is_instance_valid(center_dot):
            center_dot.text = "+"
            center_dot.add_theme_color_override("font_color", Color(0.88,0.86,0.76))
    if hit_flash and hit_flash.color.a > 0:
        var c := hit_flash.color
        c.a = maxf(0.0, c.a - delta * 0.8)
        hit_flash.color = c
    if muzzle_flash and muzzle_flash.color.a > 0:
        var m := muzzle_flash.color
        m.a = maxf(0.0, m.a - delta * 8.0)
        muzzle_flash.color = m
    if is_instance_valid(player_ref) and player_ref.get("is_reloading"):
        status_label.text = "RELOADING..."

func flash_hitmarker(killed: bool = false, headshot: bool = false) -> void:
    if not is_instance_valid(center_dot):
        return
    center_dot.text = "X" if killed else ("x" if headshot else "+")
    center_dot.add_theme_color_override("font_color", Color(0.95,0.30,0.18) if killed else (Color(1.0,0.68,0.24) if headshot else Color(0.95,0.92,0.80)))
    hitmarker_timer = 0.22 if killed or headshot else 0.11

func set_grenades(count: int) -> void:
    if not is_instance_valid(grenade_label):
        return
    grenade_label.text = "FRAG  %02d" % count
    grenade_label.add_theme_color_override("font_color", Color(0.88,0.76,0.50) if count > 0 else Color(0.95,0.30,0.18))

func set_ammo(current: int, reserve: int) -> void:
    ammo_label.text = "%02d / %03d" % [current, reserve]
    var ammo_color := Color(0.92, 0.90, 0.82)
    if current <= 5:
        ammo_color = Color(0.95, 0.27, 0.18)
    elif current <= 10:
        ammo_color = Color(0.95, 0.65, 0.25)
    ammo_label.add_theme_color_override("font_color", ammo_color)

func update_stamina(value: float, maximum: float) -> void:
    if not is_instance_valid(stamina_label):
        return
    var ratio := clampf(value / maxf(maximum, 0.001), 0.0, 1.0)
    stamina_label.text = "STAMINA  %03d%%" % int(round(ratio * 100.0))
    var stamina_color := Color(0.72, 0.78, 0.70)
    if ratio <= 0.25:
        stamina_color = Color(0.95, 0.35, 0.22)
    elif ratio <= 0.5:
        stamina_color = Color(0.95, 0.68, 0.30)
    stamina_label.add_theme_color_override("font_color", stamina_color)

func _update_navigation() -> void:
    if not is_instance_valid(navigation_label) or not is_instance_valid(player_ref):
        return
    var target: Node3D = null
    var target_label := "INTEL"
    if is_instance_valid(owner_scene):
        target = owner_scene.get_node_or_null("IntelObjective") as Node3D
        if not is_instance_valid(target):
            target = owner_scene.get_node_or_null("ExfilZone") as Node3D
            target_label = "EXFIL"
    if not is_instance_valid(target):
        navigation_label.text = "EXFIL COMPLETE"
        return
    var offset: Vector3 = target.global_position - player_ref.global_position
    var distance := int(round(Vector2(offset.x, offset.z).length()))
    var local_offset: Vector3 = player_ref.global_transform.basis.inverse() * offset
    var direction := "FRONT"
    if absf(local_offset.x) > absf(local_offset.z) * 1.5:
        direction = "RIGHT" if local_offset.x > 0.0 else "LEFT"
    elif local_offset.z > 0.0:
        direction = "BEHIND"
    elif absf(local_offset.x) > 1.5:
        direction = "FRONT-RIGHT" if local_offset.x > 0.0 else "FRONT-LEFT"
    navigation_label.text = "%s  %02dm  /  %s" % [target_label, distance, direction]

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
    if message.contains("EXFILTRATION COMPLETE"):
        _show_mission_complete()

func show_damage_direction(player_position: Vector3, player_basis: Basis, source_position: Vector3) -> void:
    if not is_instance_valid(damage_direction_label):
        return
    var local_source: Vector3 = player_basis.inverse() * (source_position - player_position)
    if absf(local_source.x) > absf(local_source.z):
        damage_direction_label.text = "<  INCOMING" if local_source.x < 0.0 else "INCOMING  >"
    else:
        damage_direction_label.text = "v INCOMING" if local_source.z > 0.0 else "^ INCOMING"
    damage_direction_timer = 0.55

func _show_mission_complete() -> void:
    if is_instance_valid(mission_panel):
        return
    mission_panel = PanelContainer.new()
    mission_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    mission_panel.offset_left = -270
    mission_panel.offset_right = 270
    mission_panel.offset_top = -170
    mission_panel.offset_bottom = 170
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    mission_panel.add_child(box)
    var title := _label("OPERATION COMPLETE", 28, Color(0.88,0.72,0.43))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var detail := _label("INTEL SECURED  /  TALON ACTUAL, OUT", 14, Color(0.82,0.83,0.78))
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(detail)
    var summary: Dictionary = {}
    if is_instance_valid(owner_scene) and owner_scene.has_method("get_mission_summary"):
        summary = owner_scene.call("get_mission_summary")
    var total_seconds := int(round(float(summary.get("mission_seconds", 0.0))))
    var minutes := int(total_seconds / 60)
    var seconds := total_seconds % 60
    var hostiles := int(summary.get("hostiles_eliminated", 0))
    var fired := int(summary.get("shots_fired", 0))
    var hits := int(summary.get("shots_hit", 0))
    var accuracy := int(round(float(summary.get("accuracy", 0.0))))
    var frags := int(summary.get("grenades_used", 0))
    var caches := int(summary.get("ammo_caches_used", 0))
    mission_stats_label = _label("HOSTILES NEUTRALIZED %d  /  ACCURACY %d%%\nROUNDS FIRED %d  /  HITS %d\nFRAGS %d  /  AMMO CACHES %d  /  TIME %02d:%02d" % [hostiles, accuracy, fired, hits, frags, caches, minutes, seconds], 13, Color(0.77,0.81,0.74))
    mission_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_stats_label.custom_minimum_size = Vector2(490, 70)
    box.add_child(mission_stats_label)
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var redeploy := Button.new()
    redeploy.text = "REDEPLOY  /  REPLAY MISSION"
    redeploy.custom_minimum_size = Vector2(250, 42)
    redeploy.pressed.connect(func():
        get_tree().paused = false
        get_tree().reload_current_scene()
    )
    box.add_child(redeploy)
    var quit := Button.new()
    quit.text = "QUIT TO DESKTOP"
    quit.custom_minimum_size = Vector2(250, 36)
    quit.pressed.connect(func(): get_tree().quit())
    box.add_child(quit)
    root.add_child(mission_panel)

func flash_muzzle() -> void:
    var c := muzzle_flash.color
    c.a = 0.06
    muzzle_flash.color = c

func is_briefing_open() -> bool:
    return is_instance_valid(briefing_panel)

func show_briefing() -> void:
    if is_briefing_open():
        return
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    briefing_backdrop = ColorRect.new()
    briefing_backdrop.name = "MissionBriefingBackdrop"
    briefing_backdrop.color = Color(0.015, 0.02, 0.018, 0.88)
    briefing_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    briefing_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(briefing_backdrop)

    briefing_panel = PanelContainer.new()
    briefing_panel.name = "MissionBriefingPanel"
    briefing_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    briefing_panel.offset_left = -310
    briefing_panel.offset_right = 310
    briefing_panel.offset_top = -260
    briefing_panel.offset_bottom = 260
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.035, 0.045, 0.04, 0.98)
    panel_style.border_color = Color(0.62, 0.37, 0.14, 1.0)
    panel_style.set_border_width_all(1)
    panel_style.set_content_margin_all(24.0)
    panel_style.corner_radius_top_left = 3
    panel_style.corner_radius_top_right = 3
    panel_style.corner_radius_bottom_left = 3
    panel_style.corner_radius_bottom_right = 3
    briefing_panel.add_theme_stylebox_override("panel", panel_style)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    briefing_panel.add_child(box)

    var eyebrow := _label("FIELD OPERATIONS  /  MISSION 01", 13, Color(0.82, 0.48, 0.20))
    box.add_child(eyebrow)
    var title := _label("OPERATION BLACKOUT", 30, Color(0.91, 0.88, 0.78))
    box.add_child(title)
    var subtitle := _label("FIRST LIGHT  /  INTERCEPT RECOVERY", 16, Color(0.72, 0.77, 0.69))
    box.add_child(subtitle)
    var divider := ColorRect.new()
    divider.custom_minimum_size = Vector2(0, 1)
    divider.color = Color(0.36, 0.29, 0.19, 0.9)
    box.add_child(divider)
    var briefing := _label("Hostile elements occupy the ruined district. Clear the area, recover the intercepted intelligence, then reach the extraction beacon.", 16, Color(0.82, 0.84, 0.78))
    briefing.custom_minimum_size = Vector2(520, 58)
    briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(briefing)
    var objectives := _label("01   ELIMINATE ALL HOSTILES\n02   HOLD F TO RECOVER INTEL\n03   REACH EXFIL AND HOLD F TO CONFIRM", 14, Color(0.89, 0.75, 0.52))
    objectives.custom_minimum_size = Vector2(520, 66)
    box.add_child(objectives)
    var controls := _label("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   Z PRONE\nLMB FIRE   RMB AIM   R RELOAD   G GRENADE", 12, Color(0.65, 0.70, 0.65))
    controls.custom_minimum_size = Vector2(520, 40)
    box.add_child(controls)

    var difficulty_row := HBoxContainer.new()
    difficulty_row.add_theme_constant_override("separation", 14)
    var difficulty_label := _label("THREAT PROFILE", 13, Color(0.82, 0.48, 0.20))
    difficulty_label.custom_minimum_size = Vector2(170, 34)
    difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    difficulty_row.add_child(difficulty_label)
    difficulty_selector = OptionButton.new()
    difficulty_selector.name = "DifficultySelector"
    difficulty_selector.custom_minimum_size = Vector2(190, 34)
    difficulty_selector.add_item("RECRUIT")
    difficulty_selector.add_item("STANDARD")
    difficulty_selector.add_item("VETERAN")
    difficulty_selector.select(1)
    difficulty_selector.item_selected.connect(_on_difficulty_selected)
    difficulty_row.add_child(difficulty_selector)
    box.add_child(difficulty_row)
    difficulty_description = _label("STANDARD  /  Balanced enemy awareness, damage, and firing cadence.", 12, Color(0.65, 0.70, 0.65))
    difficulty_description.custom_minimum_size = Vector2(520, 24)
    difficulty_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(difficulty_description)
    _on_difficulty_selected(1)

    var deploy := Button.new()
    deploy.name = "DeployButton"
    deploy.text = "DEPLOY  /  BEGIN OPERATION"
    deploy.custom_minimum_size = Vector2(300, 42)
    deploy.pressed.connect(dismiss_briefing)
    box.add_child(deploy)
    root.add_child(briefing_panel)

func _on_difficulty_selected(index: int) -> void:
    var profiles := ["RECRUIT", "STANDARD", "VETERAN"]
    var descriptions := [
        "RECRUIT  /  Reduced damage, shorter detection range, and slower hostile fire.",
        "STANDARD  /  Balanced enemy awareness, damage, and firing cadence.",
        "VETERAN  /  Longer detection range, harder hits, and faster hostile fire."
    ]
    if index < 0 or index >= profiles.size():
        return
    difficulty_description.text = descriptions[index]
    if is_instance_valid(owner_scene) and owner_scene.has_method("set_difficulty"):
        owner_scene.call("set_difficulty", profiles[index])

func dismiss_briefing() -> void:
    if is_instance_valid(briefing_panel):
        briefing_panel.queue_free()
    if is_instance_valid(briefing_backdrop):
        briefing_backdrop.queue_free()
    briefing_panel = null
    briefing_backdrop = null
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if is_instance_valid(owner_scene) and owner_scene.has_method("begin_mission"):
        owner_scene.call("begin_mission")

func _input(event: InputEvent) -> void:
    if not is_briefing_open():
        return
    if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
        dismiss_briefing()

func hide_pause() -> void:
    if is_instance_valid(pause_panel):
        pause_panel.queue_free()
    pause_panel = null

func show_pause() -> void:
    hide_pause()
    pause_panel = PanelContainer.new()
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    pause_panel.offset_left = -210
    pause_panel.offset_right = 210
    pause_panel.offset_top = -180
    pause_panel.offset_bottom = 180
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    pause_panel.add_child(box)
    var title := _label("PAUSED", 28, Color(0.9,0.82,0.65))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var controls := _label("WASD MOVE  /  SHIFT SPRINT  /  CTRL CROUCH  /  Z PRONE\nLMB FIRE  /  RMB AIM  /  R RELOAD  /  F INTERACT  /  G GRENADE", 12, Color(0.70,0.73,0.68))
    controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(controls)
    sensitivity_value_label = _label("MOUSE SENSITIVITY", 14, Color(0.82,0.84,0.78))
    box.add_child(sensitivity_value_label)
    sensitivity_slider = HSlider.new()
    sensitivity_slider.min_value = 0.0006
    sensitivity_slider.max_value = 0.004
    sensitivity_slider.step = 0.0002
    sensitivity_slider.custom_minimum_size = Vector2(300, 24)
    var current_sensitivity: float = 0.0018
    if is_instance_valid(player_ref):
        current_sensitivity = float(player_ref.get("mouse_sensitivity"))
    sensitivity_slider.value = clampf(current_sensitivity, sensitivity_slider.min_value, sensitivity_slider.max_value)
    sensitivity_value_label.text = "MOUSE SENSITIVITY  %.1fx" % (sensitivity_slider.value / 0.0018)
    sensitivity_slider.value_changed.connect(func(value: float):
        if is_instance_valid(player_ref):
            player_ref.set("mouse_sensitivity", value)
        sensitivity_value_label.text = "MOUSE SENSITIVITY  %.1fx" % (value / 0.0018)
    )
    box.add_child(sensitivity_slider)
    var resume := Button.new()
    resume.text = "RESUME"
    resume.custom_minimum_size = Vector2(300, 36)
    resume.pressed.connect(func():
        get_tree().paused = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        hide_pause()
    )
    box.add_child(resume)
    var quit := Button.new()
    quit.text = "QUIT TO DESKTOP"
    quit.custom_minimum_size = Vector2(300, 36)
    quit.pressed.connect(func(): get_tree().quit())
    box.add_child(quit)
    root.add_child(pause_panel)
