class_name Collectible
extends Area3D
## Anything the player can pick up. One script, one `kind` per scene; add a new
## kind by extending the enum and adding a _build_* function.

enum Kind { COFFEE }

@export var kind: Kind = Kind.COFFEE
@export var score_value: int = 50
@export var spin_speed: float = 3.0

var _model: Node3D


func _ready() -> void:
	add_to_group("collectible")
	_model = Node3D.new()
	add_child(_model)
	match kind:
		Kind.COFFEE:
			_build_coffee()


func _process(delta: float) -> void:
	_model.rotation.y += spin_speed * delta


## Called by the score system when picked up. Freed after a short pop animation.
func collect() -> void:
	set_deferred("monitorable", false)  # Can't be collected twice.
	var tween: Tween = create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 1.6, 0.08)
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.1)
	tween.tween_callback(queue_free)


func _build_coffee() -> void:
	Prim.cylinder(_model, 0.2, 0.14, 0.36, Vector3(0, 0, 0), Color(0.96, 0.95, 0.9))  # Cup.
	Prim.cylinder(_model, 0.21, 0.21, 0.12, Vector3(0, 0.02, 0), Color(0.55, 0.3, 0.15))  # Sleeve.
	Prim.cylinder(_model, 0.22, 0.22, 0.05, Vector3(0, 0.2, 0), Color(0.25, 0.15, 0.1))  # Lid.
	Prim.sphere_shape(self, 0.55, Vector3.ZERO)
	_model.position = Vector3(0, 0, 0)
