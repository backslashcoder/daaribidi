class_name CollectibleSpawner
extends Node
## Lays short lines of collectibles (coffee) along one lane of each segment,
## skipping spots where an obstacle already sits.

@export var road_spawner: RoadSpawner
@export var collectible_scenes: Array[PackedScene] = []
@export var line_chance: float = 0.6  ## Chance a segment gets a line at all.
@export var spacing: float = 2.5
@export var height: float = 0.9
@export var safe_start_distance: float = 15.0


func _ready() -> void:
	road_spawner.segment_placed.connect(_on_segment_placed)


func _on_segment_placed(segment: RoadSegment) -> void:
	# Deferred so the obstacle spawner has filled the segment first,
	# whatever order the two nodes happen to be in the scene tree.
	_populate.call_deferred(segment)


func _populate(segment: RoadSegment) -> void:
	segment.clear_collectibles()
	if not segment.accepts_props():
		return
	if randf() > line_chance:
		return
	var lane: int = randi_range(0, segment.lane_count - 1)
	var count: int = randi_range(3, 6)
	var scene: PackedScene = collectible_scenes.pick_random()
	var start_z: float = -randf_range(4.0, segment.length - count * spacing - 2.0)
	for i in count:
		var local_x: float = segment.get_lane_x(lane)
		var local_z: float = start_z - i * spacing
		if segment.global_position.z + local_z > road_spawner.player.global_position.z - safe_start_distance:
			continue
		if segment.is_blocked(local_x, local_z, 2.0):
			continue
		segment.add_collectible(scene.instantiate() as Node3D, Vector3(local_x, height, local_z))
