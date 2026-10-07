class_name TrafficSpawner
extends Node
## Spawns slow vehicles far ahead of the player, and makes them follow the
## road rules: stop at red lights, queue behind the vehicle in front, move off
## on green. Rules are applied here, centrally, so Vehicle stays dumb.

@export var player: PlayerController
@export var road_spawner: RoadSpawner
@export var vehicle_scenes: Array[PackedScene] = []
@export var spawn_distance: float = 100.0
@export var spawn_interval: float = 3.0  ## Seconds between spawns; difficulty lowers this.
@export var vehicle_speed: float = 3.5  ## Cruising speed; must stay below the player's speed.
@export var lane_width: float = 2.5  ## Keep equal to RoadSegment's lane_width.
@export var lane_count: int = 3
@export var min_gap: float = 14.0  ## Vehicles closer than this (in Z) count as "side by side" when spawning.
@export_group("Driving rules")
@export var planned_deceleration: float = 3.0  ## How gently vehicles plan to brake for a stop.
@export var stop_margin: float = 0.5  ## Metres short of the stop line to halt.
@export var following_gap: float = 1.6  ## Bumper-to-bumper gap kept when queueing.

var enabled: bool = false
var _timer: float = 1.0
var _vehicles: Array[Vehicle] = []


func _physics_process(_delta: float) -> void:
	for vehicle in _vehicles:
		if is_instance_valid(vehicle):
			vehicle.target_speed = _allowed_speed(vehicle)


func _process(delta: float) -> void:
	_remove_passed_vehicles()
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval * randf_range(0.7, 1.3)
		_try_spawn()


func get_vehicles() -> Array[Vehicle]:
	return _vehicles


## Removes every vehicle (used when the road turns and the old one disappears).
func clear() -> void:
	for vehicle in _vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	_vehicles.clear()


## The speed this vehicle may drive right now, after red lights and the car in front.
func _allowed_speed(vehicle: Vehicle) -> float:
	var allowed: float = vehicle_speed
	var front_z: float = vehicle.position.z - vehicle.half_length
	for segment in road_spawner.get_segments():
		if not segment.is_intersection or segment.signal_state == SignalHead.State.GREEN:
			continue
		var distance: float = front_z - segment.get_stop_line_z()
		if distance < -0.3:
			continue  # Already past the line.
		var braking_distance: float = vehicle.speed * vehicle.speed / (2.0 * planned_deceleration)
		if segment.signal_state == SignalHead.State.YELLOW and distance < braking_distance:
			continue  # Too late to stop comfortably: drive on through.
		allowed = minf(allowed, _speed_to_stop_in(distance - stop_margin))
	for other in _vehicles:
		if other == vehicle or not is_instance_valid(other) or other.lane != vehicle.lane:
			continue
		var gap: float = front_z - (other.position.z + other.half_length)
		if gap < -0.5 or gap > 30.0:
			continue  # Behind us, or too far ahead to matter.
		# Don't drive faster than we could stop in the space behind them.
		allowed = minf(allowed, sqrt(other.speed * other.speed + 2.0 * planned_deceleration * maxf(0.0, gap - following_gap)))
	return allowed


func _speed_to_stop_in(distance: float) -> float:
	return sqrt(2.0 * planned_deceleration * maxf(0.0, distance))


func _try_spawn() -> void:
	var lane: int = randi_range(0, lane_count - 1)
	var z: float = player.global_position.z - spawn_distance
	if not _lane_is_allowed(lane, z):
		return
	var vehicle := vehicle_scenes.pick_random().instantiate() as Vehicle
	vehicle.speed = vehicle_speed
	vehicle.target_speed = vehicle_speed
	vehicle.lane = lane
	add_child(vehicle)
	vehicle.position = Vector3((lane - (lane_count - 1) / 2.0) * lane_width, 0.0, z)
	_vehicles.append(vehicle)


## Reject the spawn if its lane is taken, or if it would complete a wall of
## vehicles across every lane (which would be impossible to dodge).
func _lane_is_allowed(lane: int, z: float) -> bool:
	var occupied_lanes: Dictionary = {}
	for vehicle in _vehicles:
		if absf(vehicle.position.z - z) < min_gap:
			occupied_lanes[vehicle.lane] = true
	if occupied_lanes.has(lane):
		return false
	return occupied_lanes.size() < lane_count - 1


func _remove_passed_vehicles() -> void:
	for i in range(_vehicles.size() - 1, -1, -1):
		if not is_instance_valid(_vehicles[i]) \
				or _vehicles[i].position.z - player.global_position.z > 15.0:
			if is_instance_valid(_vehicles[i]):
				_vehicles[i].queue_free()
			_vehicles.remove_at(i)
