class_name GameOver
extends CanvasLayer
## Game over screen. It only displays info and reports button presses;
## deciding what "restart" means is up to the listener.

signal restart_requested
signal menu_requested

@onready var _details_label: Label = $Root/Center/VBox/Details
@onready var _score_label: Label = $Root/Center/VBox/ScoreLabel
@onready var _best_label: Label = $Root/Center/VBox/BestLabel
@onready var _restart_button: Button = $Root/Center/VBox/RestartButton
@onready var _menu_button: Button = $Root/Center/VBox/MenuButton


func _ready() -> void:
	_restart_button.pressed.connect(restart_requested.emit)
	_menu_button.pressed.connect(menu_requested.emit)


func show_result(hit_name: String, score: int, best: int, coffees: int, is_new_best: bool) -> void:
	_details_label.text = "Ayyo! You hit %s.\n%d coffees collected" % [hit_name, coffees]
	_score_label.text = "Score: %d" % score
	_best_label.text = "NEW BEST!" if is_new_best else "Best: %d" % best
	show()
	_restart_button.grab_focus()  # Enter / Space also restarts.
