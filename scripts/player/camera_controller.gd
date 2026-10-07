class_name CameraController
extends Camera3D
## Third-person chase camera. Lives outside the player so camera tuning
## never touches movement code.

@export var target_path: NodePath
@export var distance_behind: float = 7.0
@export var height: float = 4.0
@export var look_ahead_distance: float = 8.0  ## How far in front of the player we aim.
@export var lateral_follow: float = 0.6  ## 0 = ignore lane changes, 1 = follow fully.
@export var lateral_smoothing: float = 6.0
@export var jump_follow: float = 0.4  ## Fraction of a jump the camera rises with the player.
@export var orbit_radius: float = 5.0
@export var orbit_height: float = 1.9
@export var orbit_speed: float = 0.3  ## Radians per second.

var _target: Node3D
var _lateral: float = 0.0  ## Smoothed sideways position of the camera's anchor.
var _yaw: float = 0.0  ## Extra rotation around the player; non-zero only during a turn swing.
var _menu_blend: float = 0.0  ## 1 = orbiting the player (main menu), 0 = normal chase camera.
var _orbit_angle: float = 2.6


func _ready() -> void:
	_target = get_node(target_path) as Node3D
	_lateral = _target.global_position.x * lateral_follow
	_update_camera(1.0, 0.0)


func _physics_process(delta: float) -> void:
	# Runs in physics so it stays in step with the player's movement.
	_update_camera(1.0 - exp(-lateral_smoothing * delta), delta)


## On the main menu the camera slowly circles the player; starting a run
## eases it back behind them.
func set_menu_mode(on: bool, duration: float) -> void:
	var blend: float = 1.0 if on else 0.0
	if duration <= 0.0:
		_menu_blend = blend
		return
	create_tween().tween_property(self, "_menu_blend", blend, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## After a turn the world is rotated by `world_rotation` radians. Rotating the
## camera by the same amount keeps the picture identical for that one frame,
## then we ease the camera round to sit behind the player in the new direction.
func start_swing(world_rotation: float, duration: float) -> void:
	_yaw = world_rotation
	var tween: Tween = create_tween()
	tween.tween_property(self, "_yaw", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_camera(lateral_blend: float, delta: float) -> void:
	var target_pos: Vector3 = _target.global_position
	_lateral = lerpf(_lateral, target_pos.x * lateral_follow, lateral_blend)
	var anchor := Vector3(_lateral, 0.0, target_pos.z)
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var jump_lift: float = target_pos.y * jump_follow
	var chase_position: Vector3 = anchor + yaw_basis * Vector3(0.0, height + jump_lift, distance_behind)
	# Aim straight down the road so the view doesn't yaw on lane changes.
	var chase_target: Vector3 = anchor + yaw_basis * Vector3(0.0, 1.0 + jump_lift, -look_ahead_distance)
	if _menu_blend <= 0.0:
		global_position = chase_position
		look_at(chase_target)
		return
	_orbit_angle += orbit_speed * delta
	var orbit_position: Vector3 = target_pos + Vector3(sin(_orbit_angle) * orbit_radius, orbit_height, cos(_orbit_angle) * orbit_radius)
	var orbit_target: Vector3 = target_pos + Vector3(0.0, 1.1, 0.0)
	global_position = chase_position.lerp(orbit_position, _menu_blend)
	look_at(chase_target.lerp(orbit_target, _menu_blend))
