extends RigidBody3D

func _ready() -> void:
    get_tree().create_timer(3.0).timeout.connect(queue_free)
    
    # Даем им немного случайного вращения
    angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
