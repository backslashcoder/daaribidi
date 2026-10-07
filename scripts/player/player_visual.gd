class_name PlayerVisual
extends Node3D
## Placeholder corporate employee built from primitives (origin at the feet,
## facing -Z). Only handles looks and animation; movement lives elsewhere.

const SHIRT: Color = Color(0.9, 0.93, 1.0)
const PANTS: Color = Color(0.15, 0.17, 0.3)
const SKIN: Color = Color(0.85, 0.62, 0.45)
const HAIR: Color = Color(0.08, 0.06, 0.05)
const TIE: Color = Color(0.85, 0.15, 0.2)
const BAG: Color = Color(0.45, 0.28, 0.15)
const CRASH_COLOR: Color = Color(0.9, 0.1, 0.1)
const SLIDE_LEAN_DEGREES: float = 65.0

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_left_leg = _add_limb(Vector3(-0.14, 0.85, 0), Vector3(0.2, 0.85, 0.22), PANTS)
	_right_leg = _add_limb(Vector3(0.14, 0.85, 0), Vector3(0.2, 0.85, 0.22), PANTS)
	_left_arm = _add_limb(Vector3(-0.36, 1.5, 0), Vector3(0.14, 0.6, 0.16), SHIRT)
	_right_arm = _add_limb(Vector3(0.36, 1.5, 0), Vector3(0.14, 0.6, 0.16), SHIRT)
	_track(Prim.box(_right_arm, Vector3(0.1, 0.24, 0.36), Vector3(0.05, -0.72, 0), BAG))  # Briefcase.
	_track(Prim.box(self, Vector3(0.58, 0.72, 0.32), Vector3(0, 1.2, 0), SHIRT))  # Torso.
	_track(Prim.box(self, Vector3(0.08, 0.42, 0.02), Vector3(0, 1.22, -0.17), TIE))
	_track(Prim.sphere(self, 0.2, Vector3(0, 1.74, 0), SKIN))  # Head.
	_track(Prim.box(self, Vector3(0.36, 0.12, 0.38), Vector3(0, 1.9, 0.02), HAIR))


## `phase` advances while running; the sine drives the limb swing.
func animate(phase: float, grounded: bool, sliding: bool) -> void:
	if sliding:
		_pose(0.9, -0.9)
	elif not grounded:
		_pose(0.8, -0.5)  # Jump pose: one knee up.
	else:
		var swing: float = sin(phase) * 0.9
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -swing
		_right_arm.rotation.x = swing * 0.4  # Briefcase arm swings less.


func set_sliding(sliding: bool) -> void:
	var lean: float = deg_to_rad(SLIDE_LEAN_DEGREES) if sliding else 0.0
	create_tween().tween_property(self, "rotation:x", lean, 0.1)


## The world was rotated by `world_rotation`; start rotated with it, then ease to straight.
func start_turn(world_rotation: float, duration: float) -> void:
	rotation.y = world_rotation
	create_tween().tween_property(self, "rotation:y", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func play_crash() -> void:
	for mesh in _meshes:
		mesh.material_override = Prim.material(CRASH_COLOR)
	# A quick squash makes the hit feel solid.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 0.6, 1.4), 0.08)
	tween.tween_property(self, "scale", Vector3.ONE, 0.25)


func _pose(leg_angle: float, other_angle: float) -> void:
	_left_leg.rotation.x = leg_angle
	_right_leg.rotation.x = other_angle
	_left_arm.rotation.x = other_angle
	_right_arm.rotation.x = leg_angle * 0.4


## A limb is a pivot at the joint with a box hanging below it.
func _add_limb(joint_pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint_pos
	add_child(pivot)
	_track(Prim.box(pivot, size, Vector3(0, -size.y / 2.0, 0), color))
	return pivot


func _track(mesh: MeshInstance3D) -> void:
	_meshes.append(mesh)
