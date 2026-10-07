class_name ObstacleSpawner
extends Node
## Fills each road segment with static obstacles (potholes, barriers, banners)
## when the road spawner places it. Obstacles are children of the segment, so
## they travel with it when it is recycled and are cleared before refilling.

@export var road_spawner: RoadSpawner
@export var obstacle_scenes: Array[PackedScene] = []
@export var safe_start_distance: float = 30.0  ## No obstacles this close ahead of the player (matters at the start and after turns).
@export var row_spawn_chance: float = 0.22  ## Difficulty raises this over time.
@export var max_obstacles_per_row: int = 2  ## Keep below lane count so a lane is always free.


func _ready() -> void:
	road_spawner.segment_placed.connect(_on_segment_placed)


func _on_segment_placed(segment: RoadSegment) -> void:
	segment.clear_obstacles()
	if not segment.accepts_props():
		return
	# Spawn points are stored row by row, `lane_count` markers per row.
	var points: Array[Marker3D] = segment.get_spawn_points()
	for start in range(0, points.size(), segment.lane_count):
		var row: Array[Marker3D] = points.slice(start, start + segment.lane_count)
		_fill_row(segment, row)


func _fill_row(segment: RoadSegment, row: Array[Marker3D]) -> void:
	if row[0].global_position.z > road_spawner.player.global_position.z - safe_start_distance:
		return
	if randf() > row_spawn_chance:
		return
	row.shuffle()  # Random lanes.
	var count: int = randi_range(1, mini(max_obstacles_per_row, row.size() - 1))
	for i in count:
		var scene: PackedScene = obstacle_scenes.pick_random()
		segment.add_obstacle(scene.instantiate() as Node3D, row[i].position)
