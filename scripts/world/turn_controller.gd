class_name TurnController
extends Node
## Handles turning at intersections.
##
## Near an intersection the "turn window" opens. In the window, swiping toward
## an outer lane that has no further lane (left from the left lane, right from
## the right lane) requests a turn instead. The turn happens when the player
## reaches the middle of the crossing; no input means driving straight through.

signal turn_window_changed(is_open: bool)
signal turned(direction: int)

@export var player: PlayerController
@export var road_spawner: RoadSpawner
@export var camera: CameraController
@export var traffic_spawner: TrafficSpawner
@export var animal_spawner: AnimalSpawner
@export var window_distance: float = 16.0  ## Metres before the crossing's centre.
@export var swing_duration: float = 0.5

## Destinations of the current junction (valid while the window is open).
var left_name: String = ""
var right_name: String = ""

var _junction: RoadSegment  ## The intersection whose window is currently open.
var _pending_direction: int = 0  ## -1 left, +1 right, 0 none.


func _ready() -> void:
	player.turn_requested.connect(_on_turn_requested)


func _process(_delta: float) -> void:
	if _junction == null:
		if player.is_running():
			_junction = road_spawner.find_intersection_ahead(player.global_position.z, window_distance)
			if _junction != null:
				left_name = _junction.left_name
				right_name = _junction.right_name
				_set_window(true)
		return
	if player.global_position.z <= _junction.get_center_z():
		if _pending_direction != 0:
			_execute_turn(_junction, _pending_direction)
		_junction = null
		_set_window(false)


func _on_turn_requested(direction: int) -> void:
	_pending_direction = direction


func _set_window(is_open: bool) -> void:
	_pending_direction = 0
	player.turn_window_open = is_open
	turn_window_changed.emit(is_open)


func _execute_turn(junction: RoadSegment, direction: int) -> void:
	var rotation_angle: float = direction * PI / 2.0  # +90 degrees = right turn.
	var center_z: float = junction.get_center_z()
	road_spawner.turn_at(junction, rotation_angle, swing_duration + 0.3)
	traffic_spawner.clear()
	animal_spawner.clear()
	player.complete_turn(center_z, rotation_angle, swing_duration)
	camera.start_swing(rotation_angle, swing_duration)
	turned.emit(direction)
