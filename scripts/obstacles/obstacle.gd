class_name Obstacle
extends Area3D
## Static road hazards. One script, one `kind` per scene. The player's HurtBox
## only looks for the "obstacle" group, so new hazard types need no player changes.
##   POTHOLE -> jump over it
##   BARRIER -> jump over it or change lane
##   BANNER  -> hanging flex banner: slide under it or change lane

enum Kind { POTHOLE, BARRIER, BANNER }

@export var kind: Kind = Kind.POTHOLE

var display_name: String = "an obstacle"  ## Shown on the game over screen.


func _ready() -> void:
	add_to_group("obstacle")
	match kind:
		Kind.POTHOLE:
			_build_pothole()
		Kind.BARRIER:
			_build_barrier()
		Kind.BANNER:
			_build_banner()


func _build_pothole() -> void:
	display_name = "a pothole"
	Prim.cylinder(self, 1.05, 1.05, 0.015, Vector3(0, 0.012, 0), Color(0.12, 0.12, 0.13))
	Prim.cylinder(self, 0.9, 0.9, 0.02, Vector3(0, 0.02, 0), Color(0.03, 0.03, 0.04))
	# Hit zone is only ~0.2 m tall, so any jump clears it.
	Prim.box_shape(self, Vector3(1.4, 0.3, 1.4), Vector3(0, 0.05, 0))


func _build_barrier() -> void:
	display_name = "a road barrier"
	Prim.box(self, Vector3(2.0, 0.6, 0.3), Vector3(0, 0.3, 0), Color(0.95, 0.95, 0.95))
	Prim.box(self, Vector3(2.0, 0.4, 0.3), Vector3(0, 0.8, 0), Color(1.0, 0.45, 0.05))
	# 1 m tall: a jump reaches ~1.5 m, so it is jumpable.
	Prim.box_shape(self, Vector3(2.0, 1.0, 0.4), Vector3(0, 0.5, 0))


func _build_banner() -> void:
	display_name = "a flex banner"
	for side: float in [-1.0, 1.0]:
		Prim.cylinder(self, 0.05, 0.05, 2.0, Vector3(side * 1.15, 1.0, 0), Color(0.3, 0.3, 0.33))
	Prim.box(self, Vector3(2.2, 0.9, 0.1), Vector3(0, 1.55, 0), Color(0.9, 0.2, 0.25))
	Prim.box(self, Vector3(2.0, 0.25, 0.12), Vector3(0, 1.55, 0), Color(1.0, 0.85, 0.1))
	# Bottom edge at 1.1 m: too low to stand under, too high to slide under.
	Prim.box_shape(self, Vector3(2.2, 0.9, 0.3), Vector3(0, 1.55, 0))
