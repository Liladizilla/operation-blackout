extends Node3D

var player_inside := false
var progress := 0.0
var completed := false

func _ready() -> void:
    var area := Area3D.new()
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 2.0
    shape_node.shape = shape
    area.add_child(shape_node)
    add_child(area)
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)

func _process(delta: float) -> void:
    if completed:
        return
    if player_inside and Input.is_action_pressed("interact"):
        progress += delta
        if progress >= 2.0:
            _complete()

func _on_enter(body: Node3D) -> void:
    if body.name == "Player":
        player_inside = true

func _on_exit(body: Node3D) -> void:
    if body.name == "Player":
        player_inside = false

func interact(_player: Node) -> void:
    if completed:
        return
    progress += 0.5
    if progress >= 2.0:
        _complete()

func _complete() -> void:
    completed = true
    var scene := get_tree().current_scene
    if scene and scene.has_method("objective_complete"):
        scene.objective_complete()
    queue_free()
