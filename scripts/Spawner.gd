extends Node2D
class_name Spawner

signal spawned_ball

@export var ball_scene: PackedScene
@export var initial_spawn_rate: float = 2.0            # spawns per second at t=0
@export var initial_travel_time: float = 10.0          # seconds to cross screen at t=0
@export var size_variance: float = 0.5                 # ±50%

# difficulty tuning (linear ramps)
@export var speed_increase_per_second: float = 0.02
@export var spawn_rate_increase_per_second: float = 0.01
@export var min_spawn_interval: float = 0.04

# cleanup
@export var offscreen_margin: float = 64.0
@export var cleanup_interval: float = 0.25

# internal
var elapsed: float = 0.0
var spawn_accumulator: float = 0.0
var running: bool = false
var active_balls: Array = []
var cleanup_accumulator: float = 0.0

@onready var pool: ObjectPool = $"../Pool"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func start_spawning() -> void:
	running = true
	elapsed = 0.0
	spawn_accumulator = 0.0
	cleanup_accumulator = 0.0
	active_balls.clear()

func stop_spawning() -> void:
	running = false

# Called by Main.gd every frame to pass total elapsed game time
func set_difficulty(global_elapsed: float) -> void:
	elapsed = global_elapsed

func _process(delta: float) -> void:
	if not running:
		return

	# --- spawn logic ---
	var spawn_rate = initial_spawn_rate * (1.0 + elapsed * spawn_rate_increase_per_second)
	spawn_rate = max(spawn_rate, 0.001)
	var spawn_interval = 1.0 / spawn_rate
	spawn_interval = max(spawn_interval, min_spawn_interval)

	spawn_accumulator += delta
	while spawn_accumulator >= spawn_interval:
		spawn_accumulator -= spawn_interval
		_do_spawn()

	# --- batched cleanup ---
	cleanup_accumulator += delta
	if cleanup_accumulator >= cleanup_interval:
		cleanup_accumulator -= cleanup_interval
		_cleanup_offscreen()

func _do_spawn() -> void:
	if ball_scene == null and pool == null:
		push_warning("Spawner: no ball_scene and no Pool found — can't spawn.")
		return

	var viewport = get_viewport().get_visible_rect()
	var margin := 20.0
	var spawn_pos := Vector2.ZERO
	var target_pos := Vector2.ZERO
	var side := rng.randi_range(0, 3)

	match side:
		0:
			# left -> roughly right
			spawn_pos.x = viewport.position.x - margin
			spawn_pos.y = rng.randf_range(viewport.position.y, viewport.position.y + viewport.size.y)
			target_pos.x = viewport.position.x + viewport.size.x + margin
			target_pos.y = rng.randf_range(viewport.position.y, viewport.position.y + viewport.size.y)
		1:
			# right -> left
			spawn_pos.x = viewport.position.x + viewport.size.x + margin
			spawn_pos.y = rng.randf_range(viewport.position.y, viewport.position.y + viewport.size.y)
			target_pos.x = viewport.position.x - margin
			target_pos.y = rng.randf_range(viewport.position.y, viewport.position.y + viewport.size.y)
		2:
			# top -> down
			spawn_pos.y = viewport.position.y - margin
			spawn_pos.x = rng.randf_range(viewport.position.x, viewport.position.x + viewport.size.x)
			target_pos.y = viewport.position.y + viewport.size.y + margin
			target_pos.x = rng.randf_range(viewport.position.x, viewport.position.x + viewport.size.x)
		3:
			# bottom -> up
			spawn_pos.y = viewport.position.y + viewport.size.y + margin
			spawn_pos.x = rng.randf_range(viewport.position.x, viewport.position.x + viewport.size.x)
			target_pos.y = viewport.position.y - margin
			target_pos.x = rng.randf_range(viewport.position.x, viewport.position.x + viewport.size.x)

	var distance = (target_pos - spawn_pos).length()
	var base_speed = distance / max(initial_travel_time, 0.001)
	var speed_multiplier = 1.0 + elapsed * speed_increase_per_second
	var final_speed = base_speed * speed_multiplier

	var direction = (target_pos - spawn_pos).normalized()
	var angle_jitter = deg_to_rad(rng.randf_range(-8.0, 8.0))
	direction = direction.rotated(angle_jitter)

	var velocity = direction * final_speed

	# size/color
	var size_scale = rng.randf_range(1.0 - size_variance, 1.0 + size_variance)
	var col = Color.from_hsv(rng.randf(), 0.6 + rng.randf() * 0.4, 0.8 + rng.randf() * 0.2)

	# acquire instance (prefer pool)
	var ball: Node = null
	if pool and pool.has_method("get_ball"):
		ball = pool.call("get_ball")
	else:
		if ball_scene == null:
			push_warning("Spawner: ball_scene is null and no Pool; cannot instantiate.")
			return
		ball = ball_scene.instantiate()
		get_parent().add_child(ball)

	# ensure group for collision checks
	if not ball.is_in_group("balls"):
		ball.add_to_group("balls")

	# configure ball (Ball.gd expected)
	if ball.has_method("configure"):
		ball.call("configure", spawn_pos, velocity, size_scale, col)
	else:
		# fallback
		ball.global_position = spawn_pos
		if ball.has_variable("velocity"):
			ball.velocity = velocity

	active_balls.append(ball)
	emit_signal("spawned_ball", ball)

func _cleanup_offscreen() -> void:
	if active_balls.is_empty():
		return
	var viewport = get_viewport().get_visible_rect()
	for b in active_balls.duplicate():
		if not is_instance_valid(b):
			active_balls.erase(b)
			continue

		var off := false
		if b.has_method("is_offscreen"):
			off = b.call("is_offscreen", offscreen_margin, viewport)
		else:
			off = not viewport.grow(offscreen_margin).has_point(b.global_position)

		if off:
			active_balls.erase(b)
			if pool and pool.has_method("release_ball"):
				pool.call("release_ball", b)
			else:
				if is_instance_valid(b):
					b.queue_free()

func clear_active() -> void:
	for b in active_balls.duplicate():
		if is_instance_valid(b):
			if pool and pool.has_method("release_ball"):
				pool.call("release_ball", b)
			else:
				b.queue_free()
	active_balls.clear()
