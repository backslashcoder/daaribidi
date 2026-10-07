class_name WorldBend
extends Node
## Drives the bend shader's global parameters. Every `section_length` metres it
## picks a new target curve and eases toward it, so the road appears to turn
## left/right and rise/fall as you run. Purely visual; lanes stay straight.

@export var player: PlayerController
@export var max_bend_x: float = 0.0010  ## Sideways curve strength (turns).
@export var max_bend_y: float = 0.0004  ## Vertical curve strength (hills).
@export var section_length: float = 160.0
@export var straight_chance: float = 0.3

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO  ## The first section stays straight.
var _section_start: float = 0.0


func _process(_delta: float) -> void:
	var z: float = player.global_position.z
	RenderingServer.global_shader_parameter_set("bend_origin_z", z)

	var progress: float = (maxf(0.0, -z) - _section_start) / section_length
	while progress >= 1.0:
		_section_start += section_length
		_from = _to
		_to = _pick_target()
		progress -= 1.0
	var bend: Vector2 = _from.lerp(_to, smoothstep(0.0, 1.0, progress))
	RenderingServer.global_shader_parameter_set("bend_x", bend.x)
	RenderingServer.global_shader_parameter_set("bend_y", bend.y)


func _pick_target() -> Vector2:
	if randf() < straight_chance:
		return Vector2.ZERO
	var side: float = -1.0 if randf() < 0.5 else 1.0
	return Vector2(side * randf_range(0.5, 1.0) * max_bend_x, randf_range(-1.0, 1.0) * max_bend_y)
