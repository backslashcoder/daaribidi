class_name RoadSegment
extends Node3D
## One reusable slice of road. The segment's origin is its ENTRY point and it
## extends toward -Z, so the EXIT is at local (0, 0, -length).
## Placing a segment = setting its position.z to where the previous one ended.
##
## Permanent parts (asphalt, floor, ground, spawn points) are built once.
## Everything that depends on the variant (sidewalks, markings, scenery, the
## cross street of an intersection) lives in containers that are cleared and
## refilled every time the segment is recycled.

const ARM_LENGTH: float = 36.0  ## How far a cross street extends from an intersection.
const STOP_LINE_OFFSET: float = 2.9  ## Stop line distance from the road edge of the crossing.
## Signal timing for the main road, in seconds. While the main road is red the
## cross street gets its green, after a short all-red so the junction clears.
const GREEN_TIME: float = 8.0
const YELLOW_TIME: float = 1.5
const RED_TIME: float = 6.0
const CROSS_DELAY: float = 1.0
const CROSS_SPEED: float = 6.5
const CROSSWALK_STRIPES: int = 7

@export var length: float = 48.0  ## Multiple of (dash_length + dash_gap) so dashes line up across segments.
@export var lane_width: float = 2.5  ## Keep equal to the player's lane_width.
@export var lane_count: int = 3
@export var sidewalk_width: float = 3.0
@export var sidewalk_height: float = 0.15
@export var dash_length: float = 3.0
@export var dash_gap: float = 3.0
@export var spawn_spacing: float = 8.0  ## Distance between spawn point rows.
@export var cross_vehicle_scenes: Array[PackedScene] = []  ## Cross traffic at intersections.

var is_intersection: bool = false
var left_name: String = ""  ## Where a left turn leads (intersections only).
var right_name: String = ""
var signal_state: int = SignalHead.State.GREEN  ## State of the main road's signal.

var _clock: float = 0.0
var _main_heads: Array[SignalHead] = []
var _cross_heads: Array[SignalHead] = []
var _cross_vehicles: Array[Vehicle] = []
var _cross_released: bool = false
var _crossers: Array[Pedestrian] = []

var _spawn_points: Array[Marker3D] = []
var _surface_container: Node3D
var _arms_container: Node3D
var _decor_container: Node3D
var _obstacle_container: Node3D
var _collectible_container: Node3D

const ASPHALT: Color = Color(0.2, 0.2, 0.22)
const SIDEWALK: Color = Color(0.62, 0.6, 0.55)
const GROUND: Color = Color(0.45, 0.5, 0.35)
const PAINT: Color = Color(0.95, 0.95, 0.9)


func _ready() -> void:
	Prim.box(self, Vector3(road_width(), 0.2, length), Vector3(0, -0.1, -length / 2.0), ASPHALT)
	# Slight overlap hides seams between segments.
	_add_floor(self, Vector3(road_width() + sidewalk_width * 2.0, 1.0, length + 0.2), Vector3(0, -0.5, -length / 2.0))
	for side: float in [-1.0, 1.0]:
		Prim.box(self, Vector3(20.0, 0.1, length),
				Vector3(side * (road_half() + sidewalk_width + 10.0), -0.15, -length / 2.0), GROUND)
	_add_spawn_points()
	_surface_container = _add_container("Surface")
	_arms_container = _add_container("Arms")
	_decor_container = _add_container("Decor")
	_obstacle_container = _add_container("Obstacles")
	_collectible_container = _add_container("Collectibles")
	set_process(false)


func road_width() -> float:
	return lane_width * lane_count


func road_half() -> float:
	return road_width() / 2.0


## World Z where this segment starts (the side the player enters from).
func get_entry_z() -> float:
	return global_position.z


## World Z where this segment ends; the next segment starts here.
func get_exit_z() -> float:
	return global_position.z - length


## World Z of the middle of the crossing. Only meaningful while the segment is unrotated.
func get_center_z() -> float:
	return global_position.z - length / 2.0


## Local X of a lane centre (0 = left, 1 = middle, 2 = right).
func get_lane_x(lane: int) -> float:
	return (lane - (lane_count - 1) / 2.0) * lane_width


func get_spawn_points() -> Array[Marker3D]:
	return _spawn_points


## Obstacles and pickups never go on a crossing.
func accepts_props() -> bool:
	return not is_intersection


## Rebuild everything that depends on the variant. `options` comes from the
## road spawner's plan (see SegmentDecor.build).
func set_variant(variant: int, options: Dictionary = {}) -> void:
	is_intersection = variant == SegmentDecor.Variant.INTERSECTION
	left_name = options.get("left_name", "")
	right_name = options.get("right_name", "")
	_clear(_surface_container)
	_clear(_arms_container)
	_clear(_decor_container)
	_build_surface()
	if is_intersection:
		_build_arms()
	var heads: Dictionary = SegmentDecor.build(_decor_container, variant, length, road_half(),
			road_half() + sidewalk_width, options)
	_main_heads.assign(heads.get("main", []))
	_cross_heads.assign(heads.get("cross", []))
	set_process(is_intersection)
	if is_intersection:
		_start_signals()


## Adds an obstacle at a segment-local position (usually a spawn point's).
func add_obstacle(obstacle: Node3D, local_position: Vector3) -> void:
	_obstacle_container.add_child(obstacle)
	obstacle.position = local_position


func add_collectible(collectible: Node3D, local_position: Vector3) -> void:
	_collectible_container.add_child(collectible)
	collectible.position = local_position


func clear_obstacles() -> void:
	_clear(_obstacle_container)


func clear_collectibles() -> void:
	_clear(_collectible_container)


## The cross street stops existing once the player has turned onto it
## (a freshly built road takes its place).
func release_arms() -> void:
	set_process(false)  # The junction is history: no more signal cycles or cross traffic.
	_clear(_arms_container)
	_cross_vehicles.clear()


## Keeps only the road surface; used for the leftover junction behind a turn.
func strip_props() -> void:
	_clear(_decor_container)
	_clear(_obstacle_container)
	_clear(_collectible_container)


## The leftover junction behind a turn keeps only its asphalt: sidewalks and
## markings would otherwise cut across the new road.
func strip_to_asphalt() -> void:
	strip_props()
	_clear(_surface_container)


## Empties the segment so it can sit in the spare pool.
func reset_content() -> void:
	is_intersection = false
	set_process(false)
	_cross_vehicles.clear()
	_crossers.clear()
	_main_heads.clear()
	_cross_heads.clear()
	strip_props()
	_clear(_surface_container)
	_clear(_arms_container)


## World Z of the stop line: vehicles and the player halt just before it.
func get_stop_line_z() -> float:
	return get_center_z() + road_half() + STOP_LINE_OFFSET


func _process(delta: float) -> void:
	_clock += delta
	var cycle: float = GREEN_TIME + YELLOW_TIME + RED_TIME
	if _clock >= cycle:
		_clock -= cycle
		_begin_cycle()
	var state: int = SignalHead.State.GREEN
	if _clock >= GREEN_TIME + YELLOW_TIME:
		state = SignalHead.State.RED
	elif _clock >= GREEN_TIME:
		state = SignalHead.State.YELLOW
	if state != signal_state:
		signal_state = state
		_apply_signal_state()
	if signal_state == SignalHead.State.RED and not _cross_released \
			and _clock >= GREEN_TIME + YELLOW_TIME + CROSS_DELAY:
		_release_cross_traffic()
	_remove_finished_cross_vehicles()


func _start_signals() -> void:
	_clock = randf() * GREEN_TIME * 0.5
	signal_state = SignalHead.State.GREEN
	_apply_signal_state()
	_begin_cycle()


## A new light cycle: cross traffic lines up at its stop lines and
## pedestrians gather at the corners.
func _begin_cycle() -> void:
	_cross_released = false
	for head in _cross_heads:
		head.set_state(SignalHead.State.RED)
	_spawn_cross_vehicles()
	_spawn_crossers()


func _apply_signal_state() -> void:
	for head in _main_heads:
		head.set_state(signal_state)
	if signal_state == SignalHead.State.RED:
		_send_crossers()


func _release_cross_traffic() -> void:
	_cross_released = true
	for head in _cross_heads:
		head.set_state(SignalHead.State.GREEN)
	for vehicle in _cross_vehicles:
		if is_instance_valid(vehicle):
			vehicle.target_speed = CROSS_SPEED


## One vehicle (sometimes two) waits at each side of the cross street.
## India drives on the left: eastbound traffic uses the north half of the road.
func _spawn_cross_vehicles() -> void:
	if cross_vehicle_scenes.is_empty():
		return
	for vehicle in _cross_vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	_cross_vehicles.clear()
	var center_z: float = -length / 2.0
	for direction: float in [1.0, -1.0]:
		for slot in randi_range(1, 2):
			var vehicle := cross_vehicle_scenes.pick_random().instantiate() as Vehicle
			vehicle.speed = 0.0
			vehicle.target_speed = 0.0
			_arms_container.add_child(vehicle)
			vehicle.rotation.y = -direction * PI / 2.0  # Model faces -Z; turn it along the cross street.
			var back_off: float = road_half() + 1.8 + vehicle.half_length + (slot - 1) * 5.5
			vehicle.position = Vector3(-direction * back_off, 0.0, center_z - direction * road_width() / 4.0)
			_cross_vehicles.append(vehicle)


func _remove_finished_cross_vehicles() -> void:
	var end_x: float = road_half() + ARM_LENGTH - 2.0
	for i in range(_cross_vehicles.size() - 1, -1, -1):
		var vehicle: Vehicle = _cross_vehicles[i]
		if not is_instance_valid(vehicle):
			_cross_vehicles.remove_at(i)
		elif absf(vehicle.position.x) > end_x:
			vehicle.queue_free()
			_cross_vehicles.remove_at(i)


## Pedestrians wait on the pavement corners before the crossing.
func _spawn_crossers() -> void:
	for crosser in _crossers:
		if is_instance_valid(crosser):
			crosser.queue_free()
	_crossers.clear()
	var z: float = -length / 2.0 + road_half() + 1.2  # On the zebra stripes.
	for side: float in [-1.0, 1.0]:
		var crosser := Pedestrian.new()
		_decor_container.add_child(crosser)
		crosser.position = Vector3(side * (road_half() + 0.9), 0.0, z + side * 0.4)
		crosser.rotation.y = side * PI / 2.0  # Face the road.
		_crossers.append(crosser)


## When the main road is red the traffic is stopped, so the pedestrians cross.
func _send_crossers() -> void:
	for crosser in _crossers:
		if is_instance_valid(crosser):
			var target_x: float = -signf(crosser.position.x) * (road_half() + 0.9)
			crosser.walk_to(Vector3(target_x, 0.0, crosser.position.z), 1.8)


## True if an obstacle already sits within `margin` metres of this lane position.
func is_blocked(local_x: float, local_z: float, margin: float) -> bool:
	for obstacle: Node3D in _obstacle_container.get_children():
		if absf(obstacle.position.x - local_x) < lane_width / 2.0 \
				and absf(obstacle.position.z - local_z) < margin:
			return true
	return false


func _clear(container: Node3D) -> void:
	for child in container.get_children():
		container.remove_child(child)  # Removed immediately; freed at end of frame.
		child.queue_free()


func _add_container(container_name: String) -> Node3D:
	var container := Node3D.new()
	container.name = container_name
	add_child(container)
	return container


## Sidewalks, edge lines, lane dashes and crosswalks. Skips the crossing square.
func _build_surface() -> void:
	var center_z: float = -length / 2.0
	var half: float = road_half()
	# Z ranges (from, to) of road that is NOT inside the crossing.
	var pieces: Array[Vector2] = [Vector2(0.0, -length)]
	if is_intersection:
		pieces = [Vector2(0.0, center_z + half), Vector2(center_z - half, -length)]
	for piece in pieces:
		var piece_length: float = piece.x - piece.y
		var piece_center: float = (piece.x + piece.y) / 2.0
		for side: float in [-1.0, 1.0]:
			Prim.box(_surface_container, Vector3(sidewalk_width, sidewalk_height, piece_length),
					Vector3(side * (half + sidewalk_width / 2.0), sidewalk_height / 2.0 - 0.02, piece_center), SIDEWALK)
			Prim.box(_surface_container, Vector3(0.15, 0.02, piece_length),
					Vector3(side * (half - 0.15), 0.011, piece_center), PAINT)

	var step: float = dash_length + dash_gap
	for lane_gap in range(1, lane_count):
		var x: float = (lane_gap - lane_count / 2.0) * lane_width
		for i in int(length / step):
			var z: float = -i * step - dash_length / 2.0
			if is_intersection and absf(z - center_z) < half + 2.8:
				continue  # Keep the crossing and its zebra stripes clear.
			Prim.box(_surface_container, Vector3(0.12, 0.02, dash_length), Vector3(x, 0.011, z), PAINT)
	if is_intersection:
		_build_crosswalks(center_z)


func _build_crosswalks(center_z: float) -> void:
	var half: float = road_half()
	var stripe_spacing: float = road_width() / CROSSWALK_STRIPES
	for z_offset: float in [-(half + 1.2), half + 1.2]:
		for i in CROSSWALK_STRIPES:
			var x: float = (i + 0.5) * stripe_spacing - half
			Prim.box(_surface_container, Vector3(stripe_spacing * 0.5, 0.02, 1.6),
					Vector3(x, 0.012, center_z + z_offset), PAINT)


## The cross street: plain asphalt, sidewalks and ground running sideways.
func _build_arms() -> void:
	var center_z: float = -length / 2.0
	var half: float = road_half()
	for side: float in [-1.0, 1.0]:
		var arm_x: float = side * (half + ARM_LENGTH / 2.0)
		Prim.box(_arms_container, Vector3(ARM_LENGTH, 0.2, road_width()), Vector3(arm_x, -0.1, center_z), ASPHALT)
		for edge: float in [-1.0, 1.0]:
			Prim.box(_arms_container, Vector3(ARM_LENGTH, sidewalk_height, sidewalk_width),
					Vector3(arm_x, sidewalk_height / 2.0 - 0.02, center_z + edge * (half + sidewalk_width / 2.0)), SIDEWALK)
			Prim.box(_arms_container, Vector3(ARM_LENGTH, 0.1, 20.0),
					Vector3(arm_x, -0.15, center_z + edge * (half + sidewalk_width + 10.0)), GROUND)
		_add_floor(_arms_container, Vector3(ARM_LENGTH, 1.0, road_width() + sidewalk_width * 2.0),
				Vector3(arm_x, -0.5, center_z))


func _add_spawn_points() -> void:
	# One marker per lane per row, stored row by row.
	var container := _add_container("SpawnPoints")
	var rows: int = int(length / spawn_spacing)
	for row in rows:
		for lane in lane_count:
			var marker := Marker3D.new()
			marker.name = "Lane%d_Row%d" % [lane, row]
			marker.position = Vector3(get_lane_x(lane), 0.0, -(row + 0.5) * spawn_spacing)
			container.add_child(marker)
			_spawn_points.append(marker)


## A flat collision slab; centre it at y = -0.5 so its top surface sits at y = 0.
func _add_floor(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	Prim.box_shape(body, size, Vector3.ZERO)
	body.position = center
	parent.add_child(body)
