class_name PlayerController
extends CharacterBody3D
## Lane-based auto-runner. Forward is -Z (Godot's default "forward").
## Lanes are numbered 0 (left), 1 (middle), 2 (right).

## Emitted once, the moment the player touches an obstacle.
signal crashed(obstacle: Node)
signal collected(collectible: Collectible)
signal jumped
signal footstep
## Emitted when the player swipes toward the edge during a turn window.
signal turn_requested(direction: int)

const LANE_COUNT: int = 3
const MIDDLE_LANE: int = 1
const STAND_BODY_HEIGHT: float = 1.8
const SLIDE_BODY_HEIGHT: float = 1.0
const STAND_HURT_HEIGHT: float = 1.6  ## Slightly smaller than the visible body = forgiving hits.
const SLIDE_HURT_HEIGHT: float = 0.9  ## Low enough to pass under hanging banners.

@export var forward_speed: float = 8.0  ## Cruising speed; difficulty raises it.
@export var acceleration: float = 14.0
@export var brake_deceleration: float = 18.0  ## Must exceed what TrafficRules plans for.
@export var lane_width: float = 2.5  ## Keep equal to RoadSegment's lane_width.
@export var lane_switch_speed: float = 12.0  ## Higher = snappier lane change.
@export var jump_velocity: float = 8.5
@export var gravity: float = 24.0
@export var fast_fall_speed: float = 20.0  ## Sliding in mid-air slams you down.
@export var slide_duration: float = 0.7
@export var stride_length: float = 3.6  ## Metres per full leg cycle; drives run animation.

var lane_index: int = MIDDLE_LANE
## Set every physics frame by TrafficRules (red lights, stopped vehicles ahead).
var speed_limit: float = INF
var current_speed: float = 0.0  ## Actual speed in m/s; eases toward min(forward_speed, speed_limit).
## Set by the TurnController near intersections.
var turn_window_open: bool = false

var _is_running: bool = false  ## False on the main menu, true during a run.
var _is_crashed: bool = false
var _is_sliding: bool = false
var _slide_on_landing: bool = false
var _slide_time_left: float = 0.0
var _run_phase: float = 0.0
var _last_step_index: int = 0

@onready var player_input: Node = $PlayerInput
@onready var _visual: PlayerVisual = $Visual
@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _hurt_shape: CollisionShape3D = $HurtBox/CollisionShape3D
@onready var _hurt_box: Area3D = $HurtBox


func _ready() -> void:
	player_input.move_left_requested.connect(_change_lane.bind(-1))
	player_input.move_right_requested.connect(_change_lane.bind(1))
	player_input.jump_requested.connect(_jump)
	player_input.slide_requested.connect(_slide)
	_hurt_box.area_entered.connect(_on_hurt_box_area_entered)


func set_running(running: bool) -> void:
	_is_running = running


func is_running() -> bool:
	return _is_running and not _is_crashed


## Called right after the world has been rotated for a turn: put the player
## back on a lane centre at the crossing and swing the model round with the camera.
func complete_turn(center_z: float, world_rotation: float, duration: float) -> void:
	global_position = Vector3(_lane_to_x(lane_index), global_position.y, center_z)
	_visual.start_turn(world_rotation, duration)


func _physics_process(delta: float) -> void:
	var can_move: bool = _is_running and not _is_crashed
	var target_speed: float = minf(forward_speed, speed_limit) if can_move else 0.0
	var rate: float = acceleration if target_speed > current_speed else brake_deceleration
	current_speed = move_toward(current_speed, target_speed, rate * delta)
	velocity.z = -current_speed
	# Steering toward the lane centre proportionally to the remaining distance
	# gives a smooth ease-out instead of a teleport or a constant-speed slide.
	velocity.x = (_lane_to_x(lane_index) - global_position.x) * lane_switch_speed if can_move else 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_update_slide(delta)


func _process(delta: float) -> void:
	if _is_running and not _is_crashed and current_speed > 0.5:
		_run_phase += current_speed * delta / stride_length * TAU
		var step_index: int = int(floor(_run_phase / PI))
		if step_index != _last_step_index:
			_last_step_index = step_index
			if is_on_floor() and not _is_sliding:
				footstep.emit()
	var standing_still: bool = current_speed <= 0.5
	_visual.animate(0.0 if standing_still else _run_phase, is_on_floor(), _is_sliding)


func _can_act() -> bool:
	return _is_running and not _is_crashed


func _change_lane(direction: int) -> void:
	if not _can_act():
		return
	var target_lane: int = lane_index + direction
	if turn_window_open and (target_lane < 0 or target_lane >= LANE_COUNT):
		turn_requested.emit(direction)  # Already in the outer lane: this swipe means "turn".
		return
	lane_index = clampi(target_lane, 0, LANE_COUNT - 1)


func _jump() -> void:
	if _can_act() and is_on_floor():
		_end_slide()
		velocity.y = jump_velocity
		jumped.emit()


func _slide() -> void:
	if not _can_act() or _is_sliding:
		return
	if is_on_floor():
		_begin_slide()
	else:
		velocity.y = -fast_fall_speed
		_slide_on_landing = true


func _begin_slide() -> void:
	_is_sliding = true
	_slide_time_left = slide_duration
	_set_shapes(SLIDE_BODY_HEIGHT, SLIDE_HURT_HEIGHT)
	_visual.set_sliding(true)


func _end_slide() -> void:
	_slide_on_landing = false
	if not _is_sliding:
		return
	_is_sliding = false
	_set_shapes(STAND_BODY_HEIGHT, STAND_HURT_HEIGHT)
	_visual.set_sliding(false)


func _update_slide(delta: float) -> void:
	if _is_sliding:
		_slide_time_left -= delta
		if _slide_time_left <= 0.0:
			_end_slide()
	elif _slide_on_landing and is_on_floor():
		_slide_on_landing = false
		_begin_slide()


## Capsules stay grounded: feet at y = 0, so centre = height / 2.
func _set_shapes(body_height: float, hurt_height: float) -> void:
	(_body_shape.shape as CapsuleShape3D).height = body_height
	_body_shape.position.y = body_height / 2.0
	(_hurt_shape.shape as CapsuleShape3D).height = hurt_height
	_hurt_shape.position.y = hurt_height / 2.0


func _lane_to_x(lane: int) -> float:
	return (lane - MIDDLE_LANE) * lane_width


func _on_hurt_box_area_entered(area: Area3D) -> void:
	if _is_crashed:
		return
	if area.is_in_group("obstacle"):
		_is_crashed = true
		player_input.set_process(false)
		_visual.play_crash()
		crashed.emit(area)
	elif area.is_in_group("collectible"):
		collected.emit(area as Collectible)
