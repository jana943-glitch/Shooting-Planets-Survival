extends Node
class_name ObjectPool

const ball_scene = preload("res://scenes/ball.tscn")
@export var initial_pool_size: int = 32

var available: Array = []
var in_use: Array = []
func _ready() -> void:
	# Pre-instantiate a bunch of balls so we avoid allocations during play
	if ball_scene == null:
		push_warning("ObjectPool: ball_scene is not set.")
		return
	for i in range(initial_pool_size):
		var ball = ball_scene.instantiate()
		ball.visible = false
		# optional: put pooled nodes on a separate sublayer to keep scene tidy
		add_child(ball)
		available.append(ball)

func get_ball() -> Node:
	var ball: Node = null
	if available.is_empty():
		# grow pool when needed
		if ball_scene == null:
			push_warning("ObjectPool: cannot instantiate ball - ball_scene is null.")
			return null
		ball = ball_scene.instantiate()
		add_child(ball)
	else:
		ball = available.pop_back()
	# prepare ball for reuse
	if is_instance_valid(ball):
		ball.visible = true
		# ensure physics/processing is enabled on reused nodes
		if ball.has_method("set_process"):
			ball.set_process(true)
		in_use.append(ball)
	return ball

func release_ball(ball: Node) -> void:
	if not is_instance_valid(ball):
		return
	# reset some basic state so next taker gets clean object
	ball.visible = false
	if ball.has_method("set_process"):
		ball.set_process(false)
	ball.global_position = Vector2.ZERO
	# clear groups or state if necessary (optional)
	if in_use.has(ball):
		in_use.erase(ball)
	available.append(ball)

# helpful utility for editor / restart
func clear_all() -> void:
	for b in in_use.duplicate():
		if is_instance_valid(b):
			# safe: put back into available
			release_ball(b)
	in_use.clear()
