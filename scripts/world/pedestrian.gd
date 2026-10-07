class_name Pedestrian
extends Node3D
## A person on the sidewalk. Pure scenery: no collision. Faces -Z like every
## other model, so set `rotation.y` to turn them.
##   STAND  - waits, with a tiny sway
##   PATROL - strolls up and down the sidewalk between two Z limits
##   GOTO   - walks to a target position, then stands (used at zebra crossings)

enum Mode { STAND, PATROL, GOTO }

const SHIRTS: Array[Color] = [
	Color(0.85, 0.25, 0.25), Color(0.25, 0.5, 0.85), Color(0.95, 0.8, 0.25),
	Color(0.3, 0.7, 0.4), Color(0.9, 0.5, 0.15), Color(0.6, 0.35, 0.75),
	Color(0.95, 0.95, 0.95), Color(0.2, 0.7, 0.7),
]
const PANTS: Array[Color] = [Color(0.15, 0.17, 0.3), Color(0.25, 0.22, 0.2), Color(0.1, 0.1, 0.12)]
const SKIN: Array[Color] = [Color(0.85, 0.62, 0.45), Color(0.65, 0.45, 0.3), Color(0.5, 0.33, 0.22)]
const SCALE: float = 0.92

var mode: Mode = Mode.STAND
var walk_speed: float = 1.2

var _z_min: float = 0.0
var _z_max: float = 0.0
var _direction: float = 1.0  ## +1 = toward +Z (toward the camera).
var _target: Vector3 = Vector3.ZERO
var _phase: float = randf() * TAU
var _legs: Array[Node3D] = []


func _ready() -> void:
	scale = Vector3.ONE * SCALE
	_build()


func patrol(z_min: float, z_max: float, speed: float = 1.2) -> void:
	mode = Mode.PATROL
	_z_min = z_min
	_z_max = z_max
	walk_speed = speed
	_direction = 1.0 if randf() < 0.5 else -1.0
	_face_direction()


func walk_to(target: Vector3, speed: float = 1.6) -> void:
	mode = Mode.GOTO
	_target = target
	walk_speed = speed
	var heading: Vector3 = target - position
	heading.y = 0.0
	if heading.length() > 0.01:
		rotation.y = atan2(-heading.x, -heading.z)  # Model faces -Z.


func _process(delta: float) -> void:
	match mode:
		Mode.PATROL:
			position.z += _direction * walk_speed * delta
			if position.z > _z_max or position.z < _z_min:
				_direction = -_direction
				position.z = clampf(position.z, _z_min, _z_max)
				_face_direction()
			_swing_legs(delta)
		Mode.GOTO:
			var step: Vector3 = _target - position
			step.y = 0.0
			if step.length() <= walk_speed * delta:
				position = Vector3(_target.x, position.y, _target.z)
				mode = Mode.STAND
				_reset_legs()
			else:
				position += step.normalized() * walk_speed * delta
				_swing_legs(delta)
		Mode.STAND:
			_phase += delta * 1.5
			position.y = absf(sin(_phase)) * 0.015  # Barely visible shifting of weight.


func _face_direction() -> void:
	rotation.y = PI if _direction > 0.0 else 0.0


func _swing_legs(delta: float) -> void:
	_phase += walk_speed * 4.5 * delta
	var swing: float = sin(_phase) * 0.7
	for i in _legs.size():
		_legs[i].rotation.x = swing if i == 0 else -swing


func _reset_legs() -> void:
	for leg in _legs:
		leg.rotation.x = 0.0


func _build() -> void:
	var shirt: Color = SHIRTS[randi() % SHIRTS.size()]
	var skin: Color = SKIN[randi() % SKIN.size()]
	var pants: Color = PANTS[randi() % PANTS.size()]
	var in_dress: bool = randf() < 0.35
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.12, 0.8, 0.0)
		add_child(pivot)
		Prim.box(pivot, Vector3(0.18, 0.8, 0.2), Vector3(0, -0.4, 0), shirt.darkened(0.3) if in_dress else pants)
		_legs.append(pivot)
	Prim.box(self, Vector3(0.5, 0.65, 0.28), Vector3(0, 1.12, 0), shirt)
	if in_dress:
		Prim.box(self, Vector3(0.52, 0.45, 0.3), Vector3(0, 0.7, 0), shirt)  # Kurta / saree skirt.
	Prim.sphere(self, 0.19, Vector3(0, 1.62, 0), skin)
	Prim.box(self, Vector3(0.34, 0.1, 0.36), Vector3(0, 1.78, 0.02), Color(0.08, 0.06, 0.05))  # Hair.
	if randf() < 0.4:
		Prim.box(self, Vector3(0.28, 0.32, 0.12), Vector3(0, 1.1, 0.22), Color(0.4, 0.3, 0.2))  # Backpack (on the back: +Z).
