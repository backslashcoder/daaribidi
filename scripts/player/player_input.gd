extends Node
## Turns raw input (keyboard and touch swipes) into simple intent signals.
## The player controller only listens to these signals, so new input methods
## (gamepad, on-screen buttons) only ever touch THIS file.

signal move_left_requested
signal move_right_requested
signal jump_requested
signal slide_requested

@export var swipe_threshold: float = 40.0  ## Pixels a finger must travel to count as a swipe.

var _touch_starts: Dictionary = {}  ## finger index -> where it first touched.


func _process(_delta: float) -> void:
	# just_pressed fires once per key press (no repeat while held).
	if Input.is_action_just_pressed("move_left"):
		move_left_requested.emit()
	if Input.is_action_just_pressed("move_right"):
		move_right_requested.emit()
	if Input.is_action_just_pressed("jump"):
		jump_requested.emit()
	if Input.is_action_just_pressed("slide"):
		slide_requested.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_starts[event.index] = event.position
		else:
			_touch_starts.erase(event.index)
	elif event is InputEventScreenDrag and _touch_starts.has(event.index):
		# Fire as soon as the finger has moved far enough (feels responsive),
		# then ignore the rest of this gesture so one swipe = one action.
		var delta: Vector2 = event.position - _touch_starts[event.index]
		if delta.length() >= swipe_threshold:
			_touch_starts.erase(event.index)
			_emit_swipe(delta)


func _emit_swipe(delta: Vector2) -> void:
	if absf(delta.x) > absf(delta.y):
		if delta.x < 0.0:
			move_left_requested.emit()
		else:
			move_right_requested.emit()
	elif delta.y < 0.0:
		jump_requested.emit()
	else:
		slide_requested.emit()
