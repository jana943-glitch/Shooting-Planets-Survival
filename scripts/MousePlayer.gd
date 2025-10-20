extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	get_tree().create_timer(1).timeout.connect(on_start, CONNECT_ONE_SHOT)
	
func on_start():
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	

func _process(delta: float) -> void:
	global_position = get_global_mouse_position()
