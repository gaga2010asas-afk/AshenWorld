extends RigidBody3D

func _ready() -> void:
    var t = get_tree().create_timer(3.0)
    t.timeout.connect(queue_free)
