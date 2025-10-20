extends CanvasLayer
signal restart_requested

@onready var score_label: Label = $MarginContainer/ScoreLabel
@onready var game_over_panel: Control = $GameOverPanel
@onready var restart_button: TextureButton = $GameOverPanel/RestartButton

func _ready() -> void:
	# hide overlay initially
	game_over_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)

func set_score(value: int) -> void:
	if is_instance_valid(score_label):
		score_label.text = str(value)

func show_game_over() -> void:
	game_over_panel.visible = true

func hide_game_over() -> void:
	game_over_panel.visible = false

func _on_restart_pressed() -> void:
	emit_signal("restart_requested")
