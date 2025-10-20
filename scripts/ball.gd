extends Area2D

@export var base_radius: float = 20.0
@export var base_speed: float = 100.0 

var velocity: Vector2 = Vector2.ZERO
var speed_multiplier: float = 1.0 

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var scale_factor = randf_range(1, 1.5)
	scale = Vector2(scale_factor, scale_factor)
	sprite.texture = g.PLANETS.pick_random()
	
	
func _process(delta: float) -> void:
	position += velocity * delta * speed_multiplier
	
	# Check if off-screen
	var viewport = get_viewport_rect().size
	if position.x < -50 or position.x > viewport.x + 50 or position.y < -50 or position.y > viewport.y + 50:
		await get_tree().create_timer(0.5).timeout
		queue_free()

func set_velocity(dir: Vector2, speed: float, multiplier: float) -> void:
	velocity = dir.normalized() * speed
	speed_multiplier = multiplier
	
