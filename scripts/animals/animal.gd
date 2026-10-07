class_name Animal
extends Area3D
## A four-legged animal that waits on the sidewalk, then darts across the road.
## Dog today; a cat or cow is just another scene with different exports
## (body_size, body_color, run_speed, display_name).

enum State { IDLE, ENTER_ROAD, CROSSING, EXIT_ROAD, DESPAWN }

@export var display_name: String = "a stray dog"
@export var run_speed: float = 5.5
@export var body_size: Vector3 = Vector3(0.35, 0.35, 0.8)  ## Width, height, length (without legs).
@export var body_color: Color = Color(0.68, 0.46, 0.24)
@export var reaction_time: float = 1.2  ## Seconds before the player arrives that the animal bolts.

var state: State = State.IDLE

var _player: PlayerController
var _direction: float = 1.0  ## +1 = running toward +X, -1 = toward -X.
var _road_half_width: float = 3.75
var _far_sidewalk_x: float = 0.0
var _leg_phase: float = 0.0
var _legs: Array[Node3D] = []


func _ready() -> void:
	add_to_group("obstacle")
	_build_model()


## Place the animal on a sidewalk (`sidewalk_x` is signed) and point it across the road.
func setup(player: PlayerController, sidewalk_x: float, road_half_width: float) -> void:
	_player = player
	position.x = sidewalk_x
	_direction = -signf(sidewalk_x)
	_far_sidewalk_x = -sidewalk_x
	_road_half_width = road_half_width
	rotation.y = -_direction * PI / 2.0  # Model faces -Z; turn it toward its travel direction.
	reaction_time *= randf_range(0.7, 1.3)  # So it doesn't always catch the same lane.


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if _seconds_until_player_arrives() < reaction_time:
				state = State.ENTER_ROAD
		State.ENTER_ROAD:
			_run(delta)
			if absf(position.x) <= _road_half_width:
				state = State.CROSSING
		State.CROSSING:
			_run(delta)
			if position.x * _direction > _road_half_width:
				state = State.EXIT_ROAD
		State.EXIT_ROAD:
			_run(delta)
			if position.x * _direction >= absf(_far_sidewalk_x):
				state = State.DESPAWN
		State.DESPAWN:
			queue_free()
	if position.z - _player.global_position.z > 20.0:
		queue_free()  # The player left it far behind.


func _run(delta: float) -> void:
	position.x += _direction * run_speed * delta
	_leg_phase += delta * run_speed * 3.0
	for i in _legs.size():
		# Diagonal legs move together, like a trot.
		_legs[i].rotation.x = sin(_leg_phase + (PI if i % 3 == 0 else 0.0)) * 0.8


func _seconds_until_player_arrives() -> float:
	var distance_ahead: float = _player.global_position.z - global_position.z
	return distance_ahead / maxf(_player.forward_speed, 0.1)


func _build_model() -> void:
	var leg_length: float = body_size.y * 0.9
	var body_y: float = leg_length + body_size.y / 2.0
	var half_length: float = body_size.z / 2.0
	Prim.box(self, body_size, Vector3(0, body_y, 0), body_color)
	Prim.box(self, Vector3(body_size.x * 0.75, body_size.y * 0.75, body_size.z * 0.35),
			Vector3(0, body_y + body_size.y * 0.25, -half_length - 0.08), body_color)  # Head.
	Prim.box(self, Vector3(0.07, 0.07, 0.3), Vector3(0, body_y + 0.12, half_length + 0.1), body_color)  # Tail.
	for x_side: float in [-1.0, 1.0]:
		for z_side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x_side * body_size.x * 0.35, leg_length, z_side * half_length * 0.75)
			add_child(pivot)
			Prim.box(pivot, Vector3(0.08, leg_length, 0.08), Vector3(0, -leg_length / 2.0, 0), body_color)
			_legs.append(pivot)
	# Total height ~0.75 m, so a well-timed jump clears a crossing dog.
	Prim.box_shape(self, Vector3(body_size.x + 0.2, leg_length + body_size.y, body_size.z + 0.3),
			Vector3(0, (leg_length + body_size.y) / 2.0, 0))
