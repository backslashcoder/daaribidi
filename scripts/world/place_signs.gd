class_name PlaceSigns
extends RefCounted
## Bengaluru place names (crossroads signs) and shop names (blade signs), and
## the textures that show them. Text is drawn once at startup into small
## textures (so it can use the bent world shader like everything else), then
## reused by every sign.

const PLACES: Array[String] = [
	"Koramangala", "Indiranagar", "Jayanagar", "Malleshwaram", "Whitefield",
	"HSR Layout", "Majestic", "MG Road", "Hebbal", "Yelahanka",
	"Electronic City", "Banashankari", "Basavanagudi", "Marathahalli", "Bellandur",
	"Rajajinagar", "Shivajinagar", "Yeshwanthpur", "Silk Board", "KR Puram",
	"JP Nagar", "BTM Layout", "Cubbon Park", "Lalbagh",
]
const PLACE_TEXTURE_SIZE: Vector2i = Vector2i(500, 200)
const PLACE_BOARD_COLOR: Color = Color(0.08, 0.45, 0.28)

## Typical shop boards on a Bengaluru street. "\n" splits long names over two lines.
const SHOPS: Array[Dictionary] = [
	{"name": "Sri Krishna\nBakery", "color": Color(0.85, 0.15, 0.15)},
	{"name": "Darshini\nTiffins", "color": Color(0.1, 0.5, 0.25)},
	{"name": "Kaapi\nKatte", "color": Color(0.45, 0.25, 0.1)},
	{"name": "Namma\nMedicals", "color": Color(0.05, 0.55, 0.35)},
	{"name": "MTR\nFoods", "color": Color(0.8, 0.1, 0.1)},
	{"name": "Iyengar\nBakery", "color": Color(0.95, 0.75, 0.1), "text": Color(0.2, 0.1, 0.05)},
	{"name": "Chai\nPoint", "color": Color(0.1, 0.4, 0.75)},
	{"name": "Mobile\nHub", "color": Color(0.35, 0.2, 0.7)},
	{"name": "Vijaya\nStores", "color": Color(0.9, 0.45, 0.05)},
	{"name": "Sri Lakshmi\nProvisions", "color": Color(0.7, 0.15, 0.4)},
	{"name": "Tender\nCoconut", "color": Color(0.3, 0.6, 0.2)},
	{"name": "Idli\nCorner", "color": Color(0.95, 0.85, 0.2), "text": Color(0.35, 0.1, 0.05)},
	{"name": "Namma\nKirana", "color": Color(0.1, 0.55, 0.6)},
	{"name": "Ganesh\nHardware", "color": Color(0.25, 0.3, 0.35)},
	{"name": "Meghana\nBiryani", "color": Color(0.6, 0.1, 0.1)},
	{"name": "Adigas\nRestaurant", "color": Color(0.9, 0.55, 0.1)},
	{"name": "Fruit Juice\nCentre", "color": Color(0.95, 0.5, 0.15)},
	{"name": "Kamat\nHotel", "color": Color(0.2, 0.35, 0.7)},
	{"name": "Pai\nElectronics", "color": Color(0.1, 0.25, 0.55)},
	{"name": "Bangalore\nTailors", "color": Color(0.55, 0.2, 0.55)},
	{"name": "Fresh\nFlowers", "color": Color(0.85, 0.3, 0.55)},
	{"name": "Namma\nSalon", "color": Color(0.5, 0.25, 0.65)},
	{"name": "Super\nSweets", "color": Color(0.95, 0.35, 0.1)},
	{"name": "Raghavendra\nStores", "color": Color(0.15, 0.45, 0.4)},
]
const SHOP_TEXTURE_SIZE: Vector2i = Vector2i(320, 160)

static var _place_textures: Dictionary = {}  ## place name -> ImageTexture
static var _shop_textures: Dictionary = {}  ## shop name -> ImageTexture
static var _building: bool = false


## Two different random place names: [left destination, right destination].
static func pick_pair() -> Array[String]:
	var left: String = PLACES[randi() % PLACES.size()]
	var right: String = left
	while right == left:
		right = PLACES[randi() % PLACES.size()]
	return [left, right]


static func pick_shop() -> String:
	return SHOPS[randi() % SHOPS.size()]["name"]


## Null until the textures have been built (the first crossroads is far away).
static func get_texture(place: String) -> Texture2D:
	return _place_textures.get(place)


static func get_shop_texture(shop_name: String) -> Texture2D:
	return _shop_textures.get(shop_name)


## Renders every name once. `host` is any node in the tree; it is only used to
## wait for frames and to hold the temporary viewport.
static func build_textures(host: Node) -> void:
	if _building or not _place_textures.is_empty():
		return
	_building = true
	for place in PLACES:
		_place_textures[place] = await _render(host, place, PLACE_TEXTURE_SIZE, PLACE_BOARD_COLOR, Color.WHITE)
	for shop in SHOPS:
		var text_color: Color = shop.get("text", Color.WHITE)
		_shop_textures[shop["name"]] = await _render(host, shop["name"], SHOP_TEXTURE_SIZE, shop["color"], text_color)
	_building = false


static func _render(host: Node, text: String, size: Vector2i, background_color: Color, text_color: Color) -> ImageTexture:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var background := ColorRect.new()
	background.color = background_color
	background.size = Vector2(size)
	viewport.add_child(background)
	# A lighter border makes a shop board look like a board.
	var border := ReferenceRect.new()
	border.border_color = text_color
	border.border_width = 6.0
	border.editor_only = false
	border.size = Vector2(size)
	viewport.add_child(border)
	var label := Label.new()
	label.text = text
	label.size = Vector2(size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var longest_line: int = 1
	for line in text.split("\n"):
		longest_line = maxi(longest_line, line.length())
	var lines: int = text.count("\n") + 1
	var font_size: int = int(minf(size.x / (longest_line * 0.6), size.y / (lines * 1.35)))
	label.add_theme_font_size_override("font_size", clampi(font_size, 30, 90))
	label.add_theme_color_override("font_color", text_color)
	viewport.add_child(label)
	host.add_child(viewport)
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return ImageTexture.create_from_image(image)
