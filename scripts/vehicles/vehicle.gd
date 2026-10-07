class_name Vehicle
extends Area3D
## A moving traffic vehicle. It drives straight down its lane in the same
## direction as the player, slower than the player. Hitting it ends the run.
## Deliberately dumb: no steering, no braking.

enum Kind { CAR, BIKE, AUTO }

const BODY_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.2, 0.4, 0.85), Color(0.9, 0.9, 0.9),
	Color(0.15, 0.15, 0.2), Color(0.95, 0.6, 0.1), Color(0.5, 0.7, 0.75),
]
const GLASS: Color = Color(0.7, 0.85, 0.95)
const TYRE: Color = Color(0.08, 0.08, 0.09)
const TAIL_LIGHT: Color = Color(0.95, 0.1, 0.1)

@export var kind: Kind = Kind.CAR

var speed: float = 3.5  ## Current speed in m/s along the vehicle's own forward (-Z) direction.
var target_speed: float = 3.5  ## What the traffic rules want right now; speed eases toward it.
var acceleration: float = 2.5
var braking: float = 5.0
var lane: int = 0  ## Set by the spawner; used for spacing rules.
var half_length: float = 1.9  ## Set per kind; used for stop lines and gaps.
var display_name: String = "a vehicle"


func _ready() -> void:
	add_to_group("obstacle")
	match kind:
		Kind.CAR:
			_build_car()
		Kind.BIKE:
			_build_bike()
		Kind.AUTO:
			_build_auto()


func _physics_process(delta: float) -> void:
	speed = move_toward(speed, target_speed, (acceleration if target_speed > speed else braking) * delta)
	translate(Vector3(0.0, 0.0, -speed * delta))  # Local axes, so turned cross-traffic works too.


func _build_car() -> void:
	display_name = "a car"
	half_length = 1.95
	var body: Color = BODY_COLORS[randi() % BODY_COLORS.size()]
	Prim.box(self, Vector3(1.7, 0.7, 3.8), Vector3(0, 0.65, 0), body)
	Prim.box(self, Vector3(1.5, 0.6, 2.0), Vector3(0, 1.25, 0.2), GLASS)
	_add_wheels(0.85, 1.2, 0.5)
	_add_tail_lights(0.65, 1.9, 0.6)
	Prim.box_shape(self, Vector3(1.8, 1.5, 3.9), Vector3(0, 0.75, 0))


func _build_bike() -> void:
	display_name = "a bike"
	half_length = 0.95
	var body: Color = BODY_COLORS[randi() % BODY_COLORS.size()]
	Prim.box(self, Vector3(0.3, 0.5, 1.7), Vector3(0, 0.55, 0), body)
	_add_wheels(0.0, 0.65, 0.5)
	Prim.box(self, Vector3(0.45, 0.7, 0.3), Vector3(0, 1.2, 0.1), Color(0.3, 0.55, 0.3))  # Rider.
	Prim.sphere(self, 0.2, Vector3(0, 1.75, 0.0), body)  # Helmet.
	_add_tail_lights(0.8, 0.85, 0.3)
	Prim.box_shape(self, Vector3(0.7, 1.6, 1.9), Vector3(0, 0.8, 0))


func _build_auto() -> void:
	display_name = "an auto rickshaw"
	half_length = 1.25
	Prim.box(self, Vector3(1.3, 0.8, 2.4), Vector3(0, 0.6, 0), Color(0.1, 0.45, 0.2))
	Prim.box(self, Vector3(1.3, 0.9, 1.5), Vector3(0, 1.45, 0.35), Color(0.98, 0.8, 0.1))  # Canopy.
	Prim.box(self, Vector3(1.0, 0.45, 0.05), Vector3(0, 1.4, -0.42), GLASS)  # Windscreen.
	Prim.cylinder(self, 0.25, 0.25, 0.12, Vector3(0, 0.25, -1.0), TYRE).rotation_degrees.z = 90.0
	_add_wheels(0.65, 0.85, 0.5)
	_add_tail_lights(0.5, 1.2, 0.5)
	Prim.box_shape(self, Vector3(1.4, 1.9, 2.5), Vector3(0, 0.95, 0))


func _add_wheels(x: float, z: float, size: float) -> void:
	if x == 0.0:  # Bike: one wheel front, one back, centred.
		for wheel_z: float in [-z, z]:
			Prim.box(self, Vector3(0.12, size, size), Vector3(0, size / 2.0, wheel_z), TYRE)
		return
	for side: float in [-1.0, 1.0]:
		for wheel_z: float in [-z, z]:
			Prim.box(self, Vector3(0.2, size, size), Vector3(side * x, size / 2.0, wheel_z), TYRE)


func _add_tail_lights(y: float, z: float, spread: float) -> void:
	for side: float in [-1.0, 1.0]:
		Prim.box(self, Vector3(0.25, 0.15, 0.05), Vector3(side * spread / 2.0 * 1.2, y, z), TAIL_LIGHT)
