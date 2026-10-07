class_name TrafficRules
extends Node
## Makes the player obey the road like everyone else: the runner brakes for a
## red light, queues behind vehicles that have stopped in their lane, and sets
## off again when the way is clear. It only sets PlayerController.speed_limit;
## movement itself stays in the player controller.

signal waiting_for_signal_changed(is_waiting: bool)

@export var player: PlayerController
@export var road_spawner: RoadSpawner
@export var traffic_spawner: TrafficSpawner
@export var planned_deceleration: float = 12.0  ## Gentler than the player's real braking.
@export var stop_margin: float = 0.4  ## Metres short of the stop line to halt.
@export var vehicle_gap: float = 1.6  ## Metres kept behind a stopped vehicle.
@export var stopped_speed: float = 1.0  ## Vehicles slower than this count as "stopped".
@export var lane_half_width: float = 1.4  ## How far sideways counts as "my lane".

var _is_waiting: bool = false


func _physics_process(_delta: float) -> void:
	if not player.is_running():
		player.speed_limit = INF
		_set_waiting(false)
		return
	var signal_limit: float = _signal_limit()
	player.speed_limit = minf(signal_limit, _vehicle_limit())
	_set_waiting(signal_limit < 1.0 and player.current_speed < 1.5)


## How fast we may go so that we can still stop at a red (or soon-to-be-red) light.
func _signal_limit() -> float:
	var limit: float = INF
	var front_z: float = player.global_position.z - 0.4
	var braking_distance: float = player.current_speed * player.current_speed / (2.0 * planned_deceleration)
	for segment in road_spawner.get_segments():
		if not segment.is_intersection or segment.signal_state == SignalHead.State.GREEN:
			continue
		var distance: float = front_z - segment.get_stop_line_z()
		if distance < -0.3:
			continue  # Already over the line.
		if segment.signal_state == SignalHead.State.YELLOW and distance < braking_distance:
			continue  # Too late to stop: carry on through.
		limit = minf(limit, _speed_to_stop_in(distance - stop_margin))
	return limit


## How fast we may go without hitting a stopped vehicle in our own lane.
func _vehicle_limit() -> float:
	var limit: float = INF
	var front_z: float = player.global_position.z - 0.4
	for vehicle in traffic_spawner.get_vehicles():
		if not is_instance_valid(vehicle) or vehicle.speed > stopped_speed:
			continue
		if absf(vehicle.position.x - player.global_position.x) > lane_half_width:
			continue
		var gap: float = front_z - (vehicle.position.z + vehicle.half_length)
		if gap < -0.5:
			continue  # Alongside or behind us.
		limit = minf(limit, _speed_to_stop_in(gap - vehicle_gap))
	return limit


func _speed_to_stop_in(distance: float) -> float:
	return sqrt(2.0 * planned_deceleration * maxf(0.0, distance))


func _set_waiting(waiting: bool) -> void:
	if waiting != _is_waiting:
		_is_waiting = waiting
		waiting_for_signal_changed.emit(waiting)
