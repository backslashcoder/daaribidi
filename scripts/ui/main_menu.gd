class_name MainMenu
extends CanvasLayer
## Splash screen, then the main menu: pulsing title, rotating taglines and a
## How to Play panel. The 3D world behind it is the live game, with the camera
## circling the runner (see CameraController.set_menu_mode).

signal start_requested

const TAGLINES: Array[String] = [
	"Reach office before stand-up!",
	"Dodge dogs, autos and potholes.",
	"Silk Board junction is waiting...",
	"Namma Bengaluru, namma traffic.",
	"Filter coffee keeps you going.",
	"Red signal? Even you must wait.",
	"Cows have right of way. Always.",
]
const SPLASH_SECONDS: float = 1.8
const DASH_COUNT: int = 9

## The splash only plays once per launch, not every time we return to the menu.
static var _splash_shown: bool = false

var _tagline_index: int = 0

@onready var _content: MarginContainer = $Root/Content
@onready var _title: Label = $Root/Content/VBox/Title
@onready var _dashes: HBoxContainer = $Root/Content/VBox/Dashes
@onready var _tagline: Label = $Root/Content/VBox/Tagline
@onready var _start_button: Button = $Root/Content/VBox/StartButton
@onready var _how_to_button: Button = $Root/Content/VBox/HowToButton
@onready var _best_label: Label = $Root/Content/VBox/BestLabel
@onready var _how_to_panel: CenterContainer = $Root/HowToPanel
@onready var _back_button: Button = $Root/HowToPanel/Panel/Margin/VBox/BackButton
@onready var _splash: Control = $Root/Splash
@onready var _splash_logo: Label = $Root/Splash/Center/VBox/Logo
@onready var _splash_loading: Label = $Root/Splash/Center/VBox/Loading


func _ready() -> void:
	_build_road_dashes()
	_start_button.pressed.connect(start_requested.emit)
	_how_to_button.pressed.connect(_show_how_to)
	_back_button.pressed.connect(_hide_how_to)
	for button: Button in [_start_button, _how_to_button, _back_button]:
		_make_bouncy(button)
	_pulse(_title, 1.04, 1.6)
	var timer := Timer.new()
	timer.wait_time = 3.4
	timer.timeout.connect(_next_tagline)
	add_child(timer)
	timer.start()
	visibility_changed.connect(_on_visibility_changed)
	if _splash_shown:
		_splash.hide()
		_start_button.grab_focus()
	else:
		_play_splash()


func set_best_score(best: int) -> void:
	_best_label.text = "Best Score: %d" % best


## A strip of yellow dashes, like the lane markings on the road.
func _build_road_dashes() -> void:
	for i in DASH_COUNT:
		var dash := ColorRect.new()
		dash.color = Color(1.0, 0.85, 0.2, 1.0)
		dash.custom_minimum_size = Vector2(26, 7)
		_dashes.add_child(dash)


func _play_splash() -> void:
	_splash_shown = true
	_start_button.disabled = true
	_splash.show()
	_splash.modulate.a = 1.0
	_pulse(_splash_logo, 1.06, 0.7)
	_pulse(_splash_loading, 1.0, 0.5)
	var tween: Tween = create_tween()
	tween.tween_interval(SPLASH_SECONDS)
	tween.tween_property(_splash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_splash.hide)
	tween.tween_callback(func() -> void:
		_start_button.disabled = false
		_start_button.grab_focus())


func _show_how_to() -> void:
	_how_to_panel.show()
	_back_button.grab_focus()


func _hide_how_to() -> void:
	_how_to_panel.hide()
	_start_button.grab_focus()


func _next_tagline() -> void:
	_tagline_index = (_tagline_index + 1) % TAGLINES.size()
	var tween: Tween = create_tween()
	tween.tween_property(_tagline, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _tagline.text = TAGLINES[_tagline_index])
	tween.tween_property(_tagline, "modulate:a", 1.0, 0.25)


func _on_visibility_changed() -> void:
	if visible:
		_content.modulate.a = 0.0
		create_tween().tween_property(_content, "modulate:a", 1.0, 0.5)


## Endless gentle grow/shrink, scaling around the control's centre.
func _pulse(control: Control, strength: float, seconds: float) -> void:
	control.resized.connect(func() -> void: control.pivot_offset = control.size / 2.0)
	control.pivot_offset = control.size / 2.0
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(control, "scale", Vector2.ONE * strength, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_SINE)


## Buttons swell a little under the cursor or when focused.
func _make_bouncy(button: Button) -> void:
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	var grow: Callable = func() -> void: _scale_to(button, 1.06)
	var shrink: Callable = func() -> void: _scale_to(button, 1.0)
	button.mouse_entered.connect(grow)
	button.focus_entered.connect(grow)
	button.mouse_exited.connect(shrink)
	button.focus_exited.connect(shrink)


func _scale_to(control: Control, factor: float) -> void:
	create_tween().tween_property(control, "scale", Vector2.ONE * factor, 0.12).set_trans(Tween.TRANS_BACK)
