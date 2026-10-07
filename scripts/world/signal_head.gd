class_name SignalHead
extends RefCounted
## One traffic light: a dark housing with red / amber / green lamps. Each lamp
## owns its own material so it can be switched on and off.

enum State { GREEN, YELLOW, RED }

const RED_ON: Color = Color(1.0, 0.12, 0.08)
const YELLOW_ON: Color = Color(1.0, 0.8, 0.1)
const GREEN_ON: Color = Color(0.15, 1.0, 0.3)
const DIM_FACTOR: float = 0.2

var _lamps: Array[ShaderMaterial] = []  ## Indexed by State.
var _on_colors: Array[Color] = [GREEN_ON, YELLOW_ON, RED_ON]


## `head_pos` is the housing centre; lamps face +Z (toward an approaching player).
func _init(parent: Node3D, head_pos: Vector3) -> void:
	Prim.box(parent, Vector3(0.5, 1.3, 0.4), head_pos, Color(0.08, 0.08, 0.1))
	Prim.box(parent, Vector3(0.7, 1.5, 0.05), head_pos + Vector3(0, 0, -0.2), Color(0.95, 0.95, 0.9))  # Backing plate.
	_lamps.resize(3)
	# Red on top, then amber, then green, like a real signal.
	var lamp_y: Array[float] = [-0.4, 0.0, 0.4]
	for state in 3:
		var lamp: MeshInstance3D = Prim.sphere(parent, 0.15, head_pos + Vector3(0, lamp_y[state], 0.2), Color.BLACK)
		var lamp_material: ShaderMaterial = Prim.new_material(Color.BLACK)
		lamp.material_override = lamp_material
		_lamps[state] = lamp_material
	set_state(State.GREEN)


func set_state(state: int) -> void:
	for lamp_state in 3:
		var color: Color = _on_colors[lamp_state]
		_lamps[lamp_state].set_shader_parameter("albedo", color if lamp_state == state else color * DIM_FACTOR)
