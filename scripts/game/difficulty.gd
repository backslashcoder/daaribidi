class_name Difficulty
extends Node
## Very simple difficulty: one integer level that rises with distance.
## At each new level it nudges a few numbers on other systems. All tunables
## are exports, so balancing never means touching code.

signal level_changed(level: int)

@export var player: PlayerController
@export var obstacle_spawner: ObstacleSpawner
@export var traffic_spawner: TrafficSpawner
@export var animal_spawner: AnimalSpawner

@export var meters_per_level: float = 200.0
@export var max_level: int = 12

@export_group("Player speed (m/s)")
@export var start_speed: float = 8.0
@export var max_speed: float = 15.0

@export_group("Obstacle chance per row")
@export var start_obstacle_chance: float = 0.22
@export var max_obstacle_chance: float = 0.45

@export_group("Seconds between spawns")
@export var start_traffic_interval: float = 3.0
@export var min_traffic_interval: float = 1.4
@export var start_animal_interval: float = 9.0
@export var min_animal_interval: float = 4.5

var difficulty_level: int = 0
var enabled: bool = false

var _start_z: float = 0.0


func start_run() -> void:
	enabled = true
	_start_z = player.global_position.z
	_apply(0)


func _process(_delta: float) -> void:
	if not enabled:
		return
	var level: int = clampi(int((_start_z - player.global_position.z) / meters_per_level), 0, max_level)
	if level != difficulty_level:
		_apply(level)


func _apply(level: int) -> void:
	difficulty_level = level
	var t: float = float(level) / max_level
	player.forward_speed = lerpf(start_speed, max_speed, t)
	obstacle_spawner.row_spawn_chance = lerpf(start_obstacle_chance, max_obstacle_chance, t)
	traffic_spawner.spawn_interval = lerpf(start_traffic_interval, min_traffic_interval, t)
	animal_spawner.spawn_interval = lerpf(start_animal_interval, min_animal_interval, t)
	level_changed.emit(level)
