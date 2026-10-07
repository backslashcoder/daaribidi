class_name SegmentDecor
extends RefCounted
## Builds the roadside scenery for one segment: buildings, shops, trees, street
## lights, signs, plus the special variants (flyover, Namma Metro viaduct,
## tunnel, intersection). Called every time a segment is recycled, so the
## street never looks the same.

enum Variant { STREET, FLYOVER, METRO, TUNNEL, INTERSECTION }

const SLOT_LENGTH: float = 12.0  ## Each building/shop occupies one slot along the road.
const INTERSECTION_CLEAR_RADIUS: float = 16.0  ## No buildings this close to the crossing.
const BUILDING_COLORS: Array[Color] = [
	Color(0.93, 0.78, 0.55), Color(0.85, 0.55, 0.5), Color(0.6, 0.75, 0.85),
	Color(0.9, 0.9, 0.8), Color(0.65, 0.8, 0.6), Color(0.8, 0.65, 0.85),
]
const SHOP_COLORS: Array[Color] = [
	Color(0.95, 0.85, 0.6), Color(0.8, 0.9, 0.85), Color(0.95, 0.75, 0.7),
]
const SIGN_COLORS: Array[Color] = [
	Color(0.95, 0.2, 0.2), Color(0.1, 0.5, 0.9), Color(0.1, 0.7, 0.3),
	Color(0.95, 0.75, 0.1), Color(0.9, 0.4, 0.05),
]
const WINDOW_COLOR: Color = Color(0.35, 0.5, 0.65)
const CONCRETE: Color = Color(0.58, 0.58, 0.6)
const METRO_PURPLE: Color = Color(0.5, 0.2, 0.65)
const POLE_COLOR: Color = Color(0.3, 0.3, 0.33)
const TUNNEL_WALL: Color = Color(0.72, 0.7, 0.62)
const TUNNEL_CEILING: Color = Color(0.5, 0.5, 0.52)
const LAMP_COLOR: Color = Color(1.0, 0.95, 0.7)
const HILL_GREEN: Color = Color(0.3, 0.5, 0.28)
const HIGHWAY_GREEN: Color = Color(0.08, 0.45, 0.28)


## `edge_x` is the X of the outer sidewalk edge (where private property begins).
## `options` comes from the road spawner's plan: "side" (metro side), "first" (first in a run).
## Returns the intersection's signal heads: {"main": [...], "cross": [...]} (empty otherwise).
static func build(container: Node3D, variant: int, length: float, road_half: float,
		edge_x: float, options: Dictionary) -> Dictionary:
	if variant == Variant.TUNNEL:
		_build_tunnel(container, length, edge_x, options.get("first", false))
		return {}
	var metro_side: float = options.get("side", 1.0)
	var center_z: float = -length / 2.0
	var is_intersection: bool = variant == Variant.INTERSECTION
	for side: float in [-1.0, 1.0]:
		var low_only: bool = variant == Variant.METRO and side == metro_side
		_build_side(container, length, edge_x, side, low_only, center_z,
				INTERSECTION_CLEAR_RADIUS if is_intersection else -1.0)
		_build_street_lights(container, length, road_half, side)
		if not is_intersection:
			_maybe_build_extras(container, length, road_half, side)
		_build_walkers(container, length, road_half, side, center_z, INTERSECTION_CLEAR_RADIUS if is_intersection else -1.0)
	var signal_heads: Dictionary = {}
	match variant:
		Variant.FLYOVER:
			if randf() < 0.5:
				_build_flyover(container, length, edge_x)
			else:
				_build_overpass(container, length)
		Variant.METRO:
			_build_metro(container, length, edge_x, metro_side)
		Variant.INTERSECTION:
			signal_heads = _build_intersection_props(container, length, road_half, options)
	return signal_heads


static func _build_side(c: Node3D, length: float, edge_x: float, side: float, low_only: bool,
		clear_center_z: float, clear_radius: float) -> void:
	var slots: int = int(length / SLOT_LENGTH)
	for i in slots:
		var z: float = -(i + 0.5) * SLOT_LENGTH
		if absf(z - clear_center_z) < clear_radius:
			continue
		var roll: float = randf()
		if roll < 0.55 and not low_only:
			_building(c, side, edge_x, z)
		elif roll < 0.9:
			_shop(c, side, edge_x, z)
		if randf() < 0.6:
			_tree(c, Vector3(side * (edge_x - 0.8), 0.0, z + randf_range(-3.0, 3.0)))


static func _building(c: Node3D, side: float, edge_x: float, z: float) -> void:
	var depth: float = randf_range(7.0, 10.0)
	var height: float = randf_range(9.0, 22.0)
	var width: float = SLOT_LENGTH - 1.0
	var face_x: float = side * (edge_x + 1.0)
	Prim.box(c, Vector3(depth, height, width),
			Vector3(face_x + side * depth / 2.0, height / 2.0, z), _pick(BUILDING_COLORS))
	# A few window bands are much cheaper than individual windows.
	for level in mini(3, int(height / 4.0)):
		Prim.box(c, Vector3(0.15, 1.2, width - 1.5),
				Vector3(face_x - side * 0.05, 3.0 + level * 3.5, z), WINDOW_COLOR)


static func _shop(c: Node3D, side: float, edge_x: float, z: float) -> void:
	var depth: float = 6.0
	var height: float = 4.0
	var width: float = SLOT_LENGTH - 1.5
	var face_x: float = side * (edge_x + 1.0)
	Prim.box(c, Vector3(depth, height, width),
			Vector3(face_x + side * depth / 2.0, height / 2.0, z), _pick(SHOP_COLORS))
	Prim.box(c, Vector3(0.1, 2.4, width - 2.5), Vector3(face_x - side * 0.05, 1.2, z), POLE_COLOR)  # Shutter.
	Prim.box(c, Vector3(1.6, 0.12, width - 1.0), Vector3(face_x - side * 0.8, 3.0, z), _pick(SIGN_COLORS))  # Awning.
	Prim.box(c, Vector3(0.2, 0.9, width * 0.7), Vector3(face_x - side * 0.1, 3.7, z), _pick(SIGN_COLORS))  # Fascia board.
	_build_shop_blade_sign(c, side, face_x, z + width * 0.3)
	_build_shoppers(c, side, edge_x, z)


## A board hanging out over the pavement, facing the oncoming player so the
## name can be read from far away.
static func _build_shop_blade_sign(c: Node3D, side: float, face_x: float, z: float) -> void:
	var texture: Texture2D = PlaceSigns.get_shop_texture(PlaceSigns.pick_shop())
	var x: float = face_x - side * 1.3
	Prim.box(c, Vector3(1.0, 0.08, 0.08), Vector3(face_x - side * 0.65, 4.8, z), POLE_COLOR)  # Bracket.
	if texture == null:
		Prim.box(c, Vector3(2.6, 1.3, 0.08), Vector3(x, 4.35, z), _pick(SIGN_COLORS))
		return
	Prim.box(c, Vector3(2.75, 1.45, 0.06), Vector3(x, 4.35, z - 0.05), Color(0.12, 0.12, 0.14))
	Prim.textured_quad(c, Vector2(2.6, 1.3), Vector3(x, 4.35, z + 0.02), texture)


## People standing outside a shop: a pair chatting, or someone at the counter.
static func _build_shoppers(c: Node3D, side: float, edge_x: float, z: float) -> void:
	var x: float = side * (edge_x - 0.5)
	var roll: float = randf()
	if roll < 0.4:  # Two people chatting, facing each other.
		var first := Pedestrian.new()
		first.position = Vector3(x, 0.0, z - 0.5)
		first.rotation.y = PI  # Faces +Z.
		c.add_child(first)
		var second := Pedestrian.new()
		second.position = Vector3(x, 0.0, z + 0.5)
		c.add_child(second)  # Default faces -Z, toward the first.
	elif roll < 0.75:  # One customer facing the shop.
		var customer := Pedestrian.new()
		customer.position = Vector3(x, 0.0, z + randf_range(-2.0, 2.0))
		customer.rotation.y = -side * PI / 2.0
		c.add_child(customer)


## People strolling along the pavement, up and down the segment.
static func _build_walkers(c: Node3D, length: float, road_half: float, side: float,
		clear_center_z: float, clear_radius: float) -> void:
	for i in randi_range(0, 2):
		var z: float = -randf_range(3.0, length - 3.0)
		if absf(z - clear_center_z) < clear_radius * 0.5:
			continue  # Leave the crossing to the zebra crossers.
		var walker := Pedestrian.new()
		walker.position = Vector3(side * (road_half + randf_range(1.2, 2.0)), 0.0, z)
		c.add_child(walker)
		walker.patrol(maxf(-length + 1.0, z - 7.0), minf(-1.0, z + 7.0), randf_range(1.0, 1.5))


static func _tree(c: Node3D, pos: Vector3) -> void:
	Prim.cylinder(c, 0.12, 0.18, 2.2, pos + Vector3(0, 1.1, 0), Color(0.4, 0.28, 0.18))
	var green: Color = Color(0.2, 0.5, 0.2).lerp(Color(0.35, 0.65, 0.25), randf())
	Prim.sphere(c, randf_range(1.1, 1.5), pos + Vector3(0, 3.2, 0), green)


static func _build_street_lights(c: Node3D, length: float, road_half: float, side: float) -> void:
	for fraction: float in [0.25, 0.75]:
		var pos := Vector3(side * (road_half + 0.5), 0.0, -length * fraction)
		Prim.cylinder(c, 0.07, 0.1, 6.5, pos + Vector3(0, 3.25, 0), POLE_COLOR)
		Prim.box(c, Vector3(1.4, 0.1, 0.1), pos + Vector3(-side * 0.7, 6.45, 0), POLE_COLOR)
		Prim.box(c, Vector3(0.5, 0.12, 0.28), pos + Vector3(-side * 1.4, 6.35, 0), LAMP_COLOR)


## Signboards, traffic signals and construction barriers: the Bengaluru clutter.
static func _maybe_build_extras(c: Node3D, length: float, road_half: float, side: float) -> void:
	if randf() < 0.25:
		var z: float = -randf_range(4.0, length - 4.0)
		var x: float = side * (road_half + 1.0)
		Prim.cylinder(c, 0.06, 0.06, 3.6, Vector3(x, 1.8, z - 1.0), POLE_COLOR)
		Prim.cylinder(c, 0.06, 0.06, 3.6, Vector3(x, 1.8, z + 1.0), POLE_COLOR)
		Prim.box(c, Vector3(0.1, 0.9, 2.4), Vector3(x, 3.4, z), Color(0.1, 0.5, 0.3))
		Prim.box(c, Vector3(0.12, 0.2, 1.8), Vector3(x - side * 0.02, 3.4, z), Color.WHITE)
	if randf() < 0.2:
		var pos := Vector3(side * (road_half + 1.7), 0.0, -randf_range(4.0, length - 4.0))
		Prim.box(c, Vector3(0.3, 0.45, 2.6), pos + Vector3(0, 0.25, 0), Color(1.0, 0.45, 0.05))
		Prim.box(c, Vector3(0.32, 0.2, 2.6), pos + Vector3(0, 0.55, 0), Color.WHITE)


## A signal on a pole with an arm reaching over the road from the given side.
## Returns the head so the junction can switch its lamps.
static func _traffic_signal(c: Node3D, pos: Vector3, side: float) -> SignalHead:
	Prim.cylinder(c, 0.07, 0.09, 6.4, pos + Vector3(0, 3.2, 0), POLE_COLOR)
	Prim.box(c, Vector3(2.4, 0.1, 0.1), pos + Vector3(-side * 1.2, 6.3, 0), POLE_COLOR)
	return SignalHead.new(c, pos + Vector3(-side * 2.3, 5.3, 0.0))  # Housing bottom is above camera height.


static func _build_flyover(c: Node3D, length: float, edge_x: float) -> void:
	var width: float = (edge_x + 1.0) * 2.0
	Prim.box(c, Vector3(width, 1.0, length), Vector3(0, 6.5, -length / 2.0), CONCRETE)
	for side: float in [-1.0, 1.0]:
		Prim.box(c, Vector3(0.3, 0.9, length), Vector3(side * (width / 2.0 - 0.15), 7.45, -length / 2.0), CONCRETE)
		for fraction: float in [0.25, 0.75]:
			Prim.cylinder(c, 0.6, 0.7, 6.0, Vector3(side * (edge_x - 0.5), 3.0, -length * fraction), CONCRETE)
	for fraction: float in [0.25, 0.75]:  # Underpass lamps.
		Prim.box(c, Vector3(1.5, 0.1, 0.4), Vector3(0, 5.95, -length * fraction), LAMP_COLOR)


## An elevated road crossing ABOVE the street from side to side.
static func _build_overpass(c: Node3D, length: float) -> void:
	var z: float = -length / 2.0
	Prim.box(c, Vector3(80.0, 1.0, 9.0), Vector3(0, 6.5, z), CONCRETE)
	for offset: float in [-4.35, 4.35]:
		Prim.box(c, Vector3(80.0, 0.9, 0.3), Vector3(0, 7.45, z + offset), CONCRETE)
	for x: float in [-14.0, 14.0]:
		Prim.cylinder(c, 0.8, 0.9, 6.0, Vector3(x, 3.0, z), CONCRETE)
	for i in 3:  # A few blocky vehicles up on the deck.
		var lane_z: float = z + (-1.8 if i % 2 == 0 else 1.8)
		Prim.box(c, Vector3(3.6, 0.9, 1.7), Vector3(randf_range(-30.0, 30.0), 7.5, lane_z), _pick(SIGN_COLORS))


static func _build_metro(c: Node3D, length: float, edge_x: float, side: float) -> void:
	var x: float = side * (edge_x - 0.6)
	Prim.box(c, Vector3(3.8, 1.4, length), Vector3(x, 9.2, -length / 2.0), METRO_PURPLE)
	Prim.box(c, Vector3(3.9, 0.25, length), Vector3(x, 8.4, -length / 2.0), CONCRETE)
	for fraction: float in [0.25, 0.75]:
		var z: float = -length * fraction
		Prim.cylinder(c, 0.7, 0.8, 8.0, Vector3(x, 4.0, z), CONCRETE)
		Prim.box(c, Vector3(4.6, 0.7, 1.6), Vector3(x, 8.2, z), CONCRETE)


## Enclosed tunnel: tiled walls, ceiling, lamp strips and a hill on top.
## Only the first segment of a tunnel gets the entrance portal.
static func _build_tunnel(c: Node3D, length: float, edge_x: float, first: bool) -> void:
	var wall_x: float = edge_x + 0.4
	var height: float = 6.0
	var portal_height: float = 12.0
	for side: float in [-1.0, 1.0]:
		Prim.box(c, Vector3(0.8, height, length), Vector3(side * wall_x, height / 2.0, -length / 2.0), TUNNEL_WALL)
		Prim.box(c, Vector3(0.1, 0.5, length), Vector3(side * (wall_x - 0.45), 1.4, -length / 2.0), Color(0.95, 0.55, 0.1))
		Prim.box(c, Vector3(0.1, 0.25, length), Vector3(side * (wall_x - 0.45), 4.8, -length / 2.0), Color(0.95, 0.95, 0.95))
	Prim.box(c, Vector3(wall_x * 2.0 + 1.6, 0.8, length), Vector3(0, height + 0.4, -length / 2.0), TUNNEL_CEILING)
	for i in int(length / 6.0):
		Prim.box(c, Vector3(2.0, 0.1, 0.5), Vector3(0, height - 0.05, -(i + 0.5) * 6.0), LAMP_COLOR)
		for side: float in [-1.0, 1.0]:
			Prim.box(c, Vector3(0.15, 0.4, 0.8), Vector3(side * (wall_x - 0.45), 3.2, -(i + 0.5) * 6.0), LAMP_COLOR)
	Prim.box(c, Vector3(40.0, portal_height - height - 0.8 + 3.0, length),
			Vector3(0, height + 0.8 + (portal_height - height - 0.8 + 3.0) / 2.0, -length / 2.0), HILL_GREEN)
	if first:
		var block_width: float = 16.0
		for side: float in [-1.0, 1.0]:
			Prim.box(c, Vector3(block_width, portal_height, 1.0),
					Vector3(side * (wall_x - 0.4 + block_width / 2.0), portal_height / 2.0, -0.5), CONCRETE)
		Prim.box(c, Vector3(wall_x * 2.0, portal_height - height, 1.0),
				Vector3(0, height + (portal_height - height) / 2.0, -0.5), CONCRETE)
		Prim.box(c, Vector3(7.0, 1.3, 0.15), Vector3(0, height + 1.8, 0.1), HIGHWAY_GREEN)
		Prim.box(c, Vector3(5.0, 0.25, 0.17), Vector3(0, height + 1.8, 0.12), Color.WHITE)


## Signals on all four corners and a gantry sign naming where each way leads.
## The two corners before the crossing face the player (main road); the two
## beyond it face the cross street.
static func _build_intersection_props(c: Node3D, length: float, road_half: float, options: Dictionary) -> Dictionary:
	var center_z: float = -length / 2.0
	var main_heads: Array[SignalHead] = []
	var cross_heads: Array[SignalHead] = []
	for side: float in [-1.0, 1.0]:
		main_heads.append(_traffic_signal(c, Vector3(side * (road_half + 0.6), 0.0, center_z + road_half + 1.5), side))
		cross_heads.append(_traffic_signal(c, Vector3(side * (road_half + 0.6), 0.0, center_z - road_half - 1.5), side))
	# Stop line, a little before the zebra crossing.
	Prim.box(c, Vector3(road_half * 2.0, 0.02, 0.35), Vector3(0, 0.013, center_z + road_half + 2.9), Color(0.95, 0.95, 0.9))
	# Gantry sign before the junction. Kept above camera height (4 m) so the camera passes underneath.
	var gantry_z: float = center_z + 22.0
	var board_width: float = 7.6
	for side: float in [-1.0, 1.0]:
		Prim.cylinder(c, 0.1, 0.1, 6.8, Vector3(side * (road_half + 1.0), 3.4, gantry_z), POLE_COLOR)
	Prim.box(c, Vector3(road_half * 2.0 + 2.2, 0.3, 0.3), Vector3(0, 6.7, gantry_z), POLE_COLOR)
	Prim.box(c, Vector3(board_width, 1.5, 0.12), Vector3(0, 5.6, gantry_z + 0.1), HIGHWAY_GREEN)
	Prim.box(c, Vector3(0.1, 1.5, 0.14), Vector3(0, 5.6, gantry_z + 0.1), Color.WHITE)  # Divider.
	# Place names: left destination on the left half, right on the right half.
	var names: Array = [options.get("left_name", ""), options.get("right_name", "")]
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		_arrow(c, Vector3(side * (board_width / 2.0 - 0.6), 5.6, gantry_z + 0.2), side)
		var texture: Texture2D = PlaceSigns.get_texture(names[i])
		if texture != null:
			Prim.textured_quad(c, Vector2(2.8, 1.12), Vector3(side * 1.55, 5.6, gantry_z + 0.18), texture)
	return {"main": main_heads, "cross": cross_heads}


## A white arrow on the sign, pointing toward `direction` (-1 left, 1 right).
static func _arrow(c: Node3D, pos: Vector3, direction: float) -> void:
	Prim.box(c, Vector3(0.9, 0.14, 0.06), pos, Color.WHITE)
	for tilt: float in [-40.0, 40.0]:
		var head: MeshInstance3D = Prim.box(c, Vector3(0.4, 0.14, 0.06),
				pos + Vector3(direction * 0.38, tilt * 0.003, 0.0), Color.WHITE)
		head.rotation_degrees.z = tilt * direction * -1.0


static func _pick(colors: Array[Color]) -> Color:
	return colors[randi() % colors.size()]
