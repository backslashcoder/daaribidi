class_name RoadSpawner
extends Node3D
## Keeps the road filled ahead of the player.
##
## * Segments that fall far enough behind are moved to the front (recycled).
## * The scenery "theme" comes from a plan: a few normal street segments, then
##   one special stretch (intersection, flyover, Metro, tunnel), and repeat.
## * When the player turns at an intersection, turn_at() rotates the old world
##   out of the way and starts a fresh straight road in the new direction.
##   Gameplay code never has to know the road turned: forward is always -Z.

## Emitted every time a segment is (re)positioned; listeners can fill it with content.
signal segment_placed(segment: RoadSegment)

@export var segment_scene: PackedScene
@export var player: PlayerController
@export var first_segment_z: float = 20.0  ## Start slightly behind the player.
@export var spawn_ahead_distance: float = 160.0
@export var despawn_behind_distance: float = 30.0
@export var pool_size: int = 4  ## Spare segments kept ready so a turn doesn't hitch.
@export var cross_street_keep_distance: float = 90.0  ## Leftover junctions vanish beyond this.

@export_group("Stretch lengths (segments)")
@export var street_run: Vector2i = Vector2i(2, 5)
@export var flyover_run: Vector2i = Vector2i(1, 2)
@export var metro_run: Vector2i = Vector2i(3, 5)
@export var tunnel_run: Vector2i = Vector2i(2, 3)

@export_group("How often each special stretch appears (relative)")
@export var intersection_weight: float = 4.0
@export var flyover_weight: float = 2.0
@export var metro_weight: float = 2.0
@export var tunnel_weight: float = 2.5

var _segments: Array[RoadSegment] = []  ## Ordered oldest (front of array) to newest.
var _pool: Array[RoadSegment] = []  ## Built, empty, parked out of sight.
var _cross_streets: Array[RoadSegment] = []  ## Junctions left behind by turns.
var _plan: Array[Dictionary] = []  ## One entry per upcoming segment.
var _next_segment_z: float
var _initial_fill_done: bool = false


func _ready() -> void:
	_next_segment_z = first_segment_z
	_add_run(SegmentDecor.Variant.STREET, 4)  # Always begin with a calm street.
	PlaceSigns.build_textures(self)
	# Deferred so other nodes' _ready() can connect to segment_placed first.
	_initial_fill.call_deferred()


func _process(_delta: float) -> void:
	if not _initial_fill_done:
		return
	_fill_road_ahead(1)  # One per frame spreads the building cost out.
	_top_up_pool()
	_cull_cross_streets()


func get_segments() -> Array[RoadSegment]:
	return _segments


## The intersection whose centre is ahead of `player_z` by at most `window` metres.
func find_intersection_ahead(player_z: float, window: float) -> RoadSegment:
	for segment in _segments:
		if segment.is_intersection:
			var distance: float = player_z - segment.get_center_z()
			if distance >= 0.0 and distance <= window:
				return segment
	return null


## Turn the world: afterwards the road ahead is a brand new straight road
## starting at the junction, and `phi` is the rotation that was applied to
## everything old (positive = right turn). `hold_time` is how long the old
## world stays visible so the camera swing doesn't show empty space.
func turn_at(junction: RoadSegment, phi: float, hold_time: float) -> void:
	var center_z: float = junction.get_center_z()
	var pivot := Vector3(0.0, 0.0, center_z)
	var rotation_basis := Basis(Vector3.UP, phi)
	var rigid := Transform3D(rotation_basis, pivot - rotation_basis * pivot)

	junction.release_arms()  # The new road is about to grow where the arm was.
	var retiring: Array[RoadSegment] = _segments.duplicate()
	for segment in retiring:
		segment.global_transform = rigid * segment.global_transform
	_segments.clear()

	_next_segment_z = center_z - junction.road_half()
	_plan.clear()
	_add_run(SegmentDecor.Variant.STREET, 2)
	get_tree().create_timer(hold_time).timeout.connect(_finish_turn.bind(retiring, junction))


func _initial_fill() -> void:
	_fill_road_ahead(-1)
	_initial_fill_done = true


func _fill_road_ahead(max_segments: int) -> void:
	var furthest_needed_z: float = player.global_position.z - spawn_ahead_distance
	var placed: int = 0
	while _next_segment_z > furthest_needed_z and (max_segments < 0 or placed < max_segments):
		_place_next_segment()
		placed += 1


func _place_next_segment() -> void:
	if _plan.is_empty():
		_plan_next_stretch()
	var entry: Dictionary = _plan.pop_front()
	var segment: RoadSegment = _take_segment()
	segment.position = Vector3(0, 0, _next_segment_z)
	_next_segment_z = segment.get_exit_z()
	_segments.append(segment)
	segment.set_variant(entry["variant"], entry)
	segment_placed.emit(segment)


## Recycle the oldest segment if the player has passed it, then try the spare
## pool, otherwise build a new one.
func _take_segment() -> RoadSegment:
	if not _segments.is_empty():
		var oldest: RoadSegment = _segments[0]
		if oldest.get_exit_z() > player.global_position.z + despawn_behind_distance:
			return _segments.pop_front()
	if not _pool.is_empty():
		var spare: RoadSegment = _pool.pop_back()
		spare.visible = true
		return spare
	return _make_segment()


func _make_segment() -> RoadSegment:
	var segment := segment_scene.instantiate() as RoadSegment
	add_child(segment)
	return segment


func _top_up_pool() -> void:
	if _pool.size() < pool_size:
		_release_to_pool(_make_segment())


func _release_to_pool(segment: RoadSegment) -> void:
	segment.reset_content()
	segment.transform = Transform3D(Basis.IDENTITY, Vector3(0, -1000, 0))
	segment.visible = false
	_pool.append(segment)


func _finish_turn(retiring: Array[RoadSegment], junction: RoadSegment) -> void:
	for segment in retiring:
		if not is_instance_valid(segment):
			continue
		if segment == junction:
			segment.strip_to_asphalt()  # Keep just the bare crossing behind the player.
			_cross_streets.append(segment)
		else:
			_release_to_pool(segment)


func _cull_cross_streets() -> void:
	for i in range(_cross_streets.size() - 1, -1, -1):
		var segment: RoadSegment = _cross_streets[i]
		if segment.global_position.distance_to(player.global_position) > cross_street_keep_distance:
			_cross_streets.remove_at(i)
			_release_to_pool(segment)


# --- Planning -----------------------------------------------------------------

func _plan_next_stretch() -> void:
	_add_run(SegmentDecor.Variant.STREET, randi_range(street_run.x, street_run.y))
	var weights: Dictionary = {
		SegmentDecor.Variant.INTERSECTION: intersection_weight,
		SegmentDecor.Variant.FLYOVER: flyover_weight,
		SegmentDecor.Variant.METRO: metro_weight,
		SegmentDecor.Variant.TUNNEL: tunnel_weight,
	}
	var roll: float = randf() * (intersection_weight + flyover_weight + metro_weight + tunnel_weight)
	for variant: int in weights:
		roll -= weights[variant]
		if roll <= 0.0:
			_add_run(variant, _run_length(variant), -1.0 if randf() < 0.5 else 1.0)
			return


func _run_length(variant: int) -> int:
	match variant:
		SegmentDecor.Variant.FLYOVER:
			return randi_range(flyover_run.x, flyover_run.y)
		SegmentDecor.Variant.METRO:
			return randi_range(metro_run.x, metro_run.y)
		SegmentDecor.Variant.TUNNEL:
			return randi_range(tunnel_run.x, tunnel_run.y)
	return 1


func _add_run(variant: int, count: int, side: float = 1.0) -> void:
	for i in count:
		var entry: Dictionary = {"variant": variant, "side": side, "first": i == 0, "last": i == count - 1}
		if variant == SegmentDecor.Variant.INTERSECTION:
			var places: Array[String] = PlaceSigns.pick_pair()
			entry["left_name"] = places[0]
			entry["right_name"] = places[1]
		_plan.append(entry)
