extends RigidBody3D

var amount: int = 300
var can_collect: bool = false
var lifetime: float = 30.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var label: Label3D = $Label
@onready var area: Area3D = $Area3D

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	
	# Начальный импульс, чтобы монетка вылетела из врага
	apply_central_impulse(Vector3(randf_range(-2, 2), randf_range(3, 5), randf_range(-2, 2)))
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	
	label.text = "+$" + str(amount)
	
	await get_tree().create_timer(0.5).timeout
	can_collect = true

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	elif lifetime < 5.0:
		visible = int(lifetime * 10) % 2 == 0

func _on_body_entered(body: Node) -> void:
	if can_collect and body.name == "Player" and body.has_method("take_damage"):
		GameManager.add_money(amount)
		
		var audio = AudioStreamPlayer3D.new()
		audio.stream = preload("res://scripts/utils/SoundGen.gd").get_clink_sound()
		audio.pitch_scale = 2.0
		audio.volume_db = 0.0
		body.add_child(audio)
		audio.play()
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)
		queue_free()
