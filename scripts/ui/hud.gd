class_name HUD
extends CanvasLayer
## In-run display. Pure view: it shows what the score manager reports.

signal pause_requested

@export var score_manager: ScoreManager
@export var turn_controller: TurnController
@export var traffic_rules: TrafficRules

@onready var _score_label: Label = $Root/Margin/Top/Stats/ScoreLabel
@onready var _coffee_label: Label = $Root/Margin/Top/Stats/CoffeeLabel
@onready var _pause_button: Button = $Root/Margin/Top/PauseButton
@onready var _turn_hint: Label = $Root/TurnHint
@onready var _toast: Label = $Root/Toast
@onready var _wait_hint: Label = $Root/WaitHint


func _ready() -> void:
	score_manager.score_changed.connect(func(score: int) -> void: _score_label.text = "SCORE: %d" % score)
	score_manager.coffee_changed.connect(func(count: int) -> void: _coffee_label.text = "COFFEE: %d" % count)
	_pause_button.pressed.connect(pause_requested.emit)
	turn_controller.turn_window_changed.connect(_on_turn_window_changed)
	turn_controller.turned.connect(_on_turned)
	traffic_rules.waiting_for_signal_changed.connect(func(is_waiting: bool) -> void: _wait_hint.visible = is_waiting)


func _on_turn_window_changed(is_open: bool) -> void:
	_turn_hint.visible = is_open
	if is_open:
		_turn_hint.text = "CROSSROAD!
< %s      %s >
Swipe toward the edge to TURN" 				% [turn_controller.left_name, turn_controller.right_name]


func _on_turned(direction: int) -> void:
	var place: String = turn_controller.right_name if direction > 0 else turn_controller.left_name
	_toast.text = "Heading to %s" % place
	_toast.modulate.a = 1.0
	_toast.show()
	var tween: Tween = create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_toast.hide)
