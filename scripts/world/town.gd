class_name Town
extends Node2D

## The market square around the stall, in art pixels (drawn at 2x).
## Customers walk in from the right along the path and queue at the counter.

const SIZE := Vector2(200, 140)
const FLOOR := "Backgrounds/Tilesets/TilesetFloor.png"
const HOUSE := "Backgrounds/Tilesets/TilesetHouse.png"
const NATURE := "Backgrounds/Tilesets/TilesetNature.png"
const ENTRY := Vector2(214, 90)
const COUNTER_FRONT := Vector2(84, 90)
const QUEUE_GAP := 18.0

var merchant: Actor
var lantern: PointLight2D


func _ready() -> void:
	_fill(Style.tile(FLOOR, Rect2i(0, 192, 16, 16)), Rect2(0, 0, SIZE.x, SIZE.y))
	# Tufts of grass so the field isn't flat.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22:
		var tuft := Sprite2D.new()
		tuft.texture = Style.piece(FLOOR, Rect2([16, 32, 48][i % 3], 176 + 16 * int(i % 3 == 0), 16, 16))
		tuft.centered = false
		tuft.position = Vector2(rng.randi_range(0, 11) * 16, rng.randi_range(0, 8) * 16)
		add_child(tuft)
	# Path to the stall: left cap, then dirt running off the right edge.
	_fill(Style.tile(FLOOR, Rect2i(16, 160, 16, 16)), Rect2(64, 80, 144, 16))
	_prop(Style.piece(FLOOR, Rect2(0, 160, 16, 16)), Vector2(48, 80))

	# Your house behind the stall, where you sleep, and some greenery.
	_prop(Style.piece(HOUSE, Rect2(0, 0, 64, 48)), Vector2(2, 0))
	_prop(Style.piece(NATURE, Rect2(48, 288, 48, 48)), Vector2(148, 2))
	_prop(Style.piece(NATURE, Rect2(0, 0, 32, 32)), Vector2(124, 14))
	for at in [Vector2(10, 52), Vector2(140, 52), Vector2(176, 104), Vector2(24, 112), Vector2(96, 116)]:
		_prop(Style.piece(NATURE, Rect2(32, 160, 16, 16)), at)
	for at in [Vector2(30, 56), Vector2(160, 110), Vector2(60, 108)]:
		_prop(Style.piece(NATURE, Rect2(0, 176, 16, 16)), at)

	merchant = Actor.new().setup("merchant")
	merchant.position = Vector2(84, 58)
	add_child(merchant)

	# Stall: counter in front of the merchant, goods around it.
	_prop(Style.piece(HOUSE, Rect2(256, 256, 48, 26)), Vector2(60, 52))
	_prop(Style.piece(HOUSE, Rect2(256, 208, 16, 16)), Vector2(62, 44))
	_prop(Style.piece(HOUSE, Rect2(288, 208, 16, 16)), Vector2(92, 44))
	_prop(Style.piece(HOUSE, Rect2(304, 224, 16, 16)), Vector2(110, 58))
	_prop(Style.piece(HOUSE, Rect2(320, 224, 16, 16)), Vector2(110, 42))
	_prop(Style.piece(HOUSE, Rect2(272, 224, 16, 16)), Vector2(42, 58))
	_prop(Style.piece(HOUSE, Rect2(336, 208, 16, 16)), Vector2(44, 42))

	lantern = PointLight2D.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 128
	g.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.85, 0.55, 1))
	grad.set_color(1, Color(1, 0.85, 0.55, 0))
	g.gradient = grad
	lantern.texture = g
	lantern.position = Vector2(84, 60)
	lantern.energy = 0.0
	add_child(lantern)


func queue_spot(i: int) -> Vector2:
	return COUNTER_FRONT + Vector2(QUEUE_GAP * i, 0)


func _fill(tex: Texture2D, rect: Rect2) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.position = rect.position
	add_child(s)


func _prop(tex: Texture2D, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = at
	add_child(s)
	return s


## Daylight tint for a minute of the day.
static func sky(minute: int) -> Color:
	var h := minute / 60.0
	var keys := [[6.0, Color(0.85, 0.8, 0.95)], [9.0, Color.WHITE], [17.0, Color.WHITE],
		[19.0, Color(1.0, 0.75, 0.6)], [21.0, Color(0.38, 0.38, 0.6)], [24.0, Color(0.25, 0.25, 0.45)]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if h <= b[0]:
			return (a[1] as Color).lerp(b[1], clampf((h - a[0]) / (b[0] - a[0]), 0, 1))
	return keys[-1][1]
