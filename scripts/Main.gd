extends Node

var ball_scene = preload("res://scenes/Ball.tscn")

@onready var hud: CanvasLayer = $HUD
@onready var game_over_panel: TextureRect = $HUD/GameOverPanel
@onready var mouse_area: Area2D = $MouseArea
@onready var restart_button: TextureButton = $HUD/GameOverPanel/RestartButton
@onready var high_score_label: Label = $"HUD/GameOverPanel/highscore container/Control/HighScoreLabel"
@onready var score_label: Label = $HUD/MarginContainer/ScoreLabel

var score: int = 0
var high_score: int = 0
var spawn_interval: float = 0.5  # Initial 2/sec
var speed_multiplier: float = 1.0
var difficulty_scale: float = 1.1  # Exponential increase
var base_cross_time: float = 10.0

var score_timer: Timer
var spawn_timer: Timer
var difficulty_timer: Timer

const CONFIG_PATH: String = "user://high_score.cfg"

func _ready() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # Hide default cursor
	
	# Load high score
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		high_score = config.get_value("scores", "high_score", 0)
	high_score_label.text = "High Score: " + str(high_score)
	
	# Timers
	score_timer = Timer.new()
	add_child(score_timer)
	score_timer.wait_time = 1.0
	score_timer.timeout.connect(_on_score_timeout)
	score_timer.start()
	
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timeout)
	spawn_timer.start()
	
	difficulty_timer = Timer.new()
	add_child(difficulty_timer)
	difficulty_timer.wait_time = 10.0
	difficulty_timer.timeout.connect(_on_difficulty_timeout)
	difficulty_timer.start()
	
	# Connections
	mouse_area.area_entered.connect(_on_mouse_hit)
	restart_button.pressed.connect(_on_restart_pressed)
	
	_on_spawn_timeout()  # Initial spawn

func _process(_delta: float) -> void:
	mouse_area.global_position = get_viewport().get_mouse_position()

func _on_score_timeout() -> void:
	score += 1
	score_label.text = "Score: " + str(score)

func _on_spawn_timeout() -> void:
	var ball = ball_scene.instantiate()
	add_child(ball)
	
	# Spawn off-screen
	var viewport_size = get_viewport().get_visible_rect().size
	var side = randi() % 4
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.ZERO
	
	match side:
		0:  # Left
			pos = Vector2(-50, randf_range(-50, viewport_size.y + 50))
			dir = Vector2(1.0, randf_range(-0.3, 0.3))
		1:  # Top
			pos = Vector2(randf_range(-50, viewport_size.x + 50), -50)
			dir = Vector2(randf_range(-0.3, 0.3), 1.0)
		2:  # Right
			pos = Vector2(viewport_size.x + 50, randf_range(-50, viewport_size.y + 50))
			dir = Vector2(-1.0, randf_range(-0.3, 0.3))
		3:  # Bottom
			pos = Vector2(randf_range(-50, viewport_size.x + 50), viewport_size.y + 50)
			dir = Vector2(randf_range(-0.3, 0.3), -1.0)
	
	ball.position = pos
	var base_speed = max(viewport_size.x, viewport_size.y) / base_cross_time
	ball.set_velocity(dir, base_speed, speed_multiplier)

func _on_difficulty_timeout() -> void:
	speed_multiplier *= difficulty_scale
	spawn_interval /= difficulty_scale
	spawn_timer.wait_time = max(0.1, spawn_interval)  # Min interval to prevent overload

func _on_mouse_hit(area: Area2D) -> void:
	if area.is_in_group("balls"):
		game_over()

func game_over() -> void:
	score_timer.stop()
	spawn_timer.stop()
	difficulty_timer.stop()
	game_over_panel.visible = true
	
	# Update high score
	if score > high_score:
		high_score = score
		high_score_label.text = "High Score: " + str(high_score)
		var config = ConfigFile.new()
		config.set_value("scores", "high_score", high_score)
		config.save(CONFIG_PATH)

func _on_restart_pressed() -> void:
	# Fade transition
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(fade)
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	await tween.finished
	get_tree().reload_current_scene()
