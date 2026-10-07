class_name AnimalSpawner
extends Node
## Occasionally puts an animal on a sidewalk far ahead. The animal waits there
## and bolts across when the player gets close (see animal.gd).

@export var player: PlayerController
@export var animal_scenes: Array[PackedScene] = []
@export var spawn_distance: float = 90.0
@export var spawn_interval: float = 9.0  ## Seconds between spawns; difficulty lowers this.
@export var road_half_width: float = 3.75  ## Keep equal to RoadSegment (lane_width * lane_count / 2).
@export var sidewalk_center_x: float = 5.25

var enabled: bool = false
var _timer: float = 5.0


func _process(delta: float) -> void:
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval * randf_range(0.7, 1.3)
		_spawn()


## Removes every animal (used when the road turns and the old one disappears).
func clear() -> void:
	for animal in get_children():
		animal.queue_free()


func _spawn() -> void:
	var animal := animal_scenes.pick_random().instantiate() as Animal
	add_child(animal)
	var side: float = -1.0 if randf() < 0.5 else 1.0
	animal.setup(player, side * sidewalk_center_x, road_half_width)
	animal.position.z = player.global_position.z - spawn_distance
