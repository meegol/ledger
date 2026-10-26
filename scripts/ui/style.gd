class_name Style
extends RefCounted

## Shared look: one pixel font, a warm wood palette, flat square boxes.

const PACK := "res://assets/third_party/ninja_adventure/"
const FONT_SIZE := 16

const INK := Color("f4e4c1")
const DIM := Color("b39a7a")
const PANEL := Color("2b1d14")
const PANEL_EDGE := Color("6b4a2f")
const BUTTON := Color("5a3b24")
const BUTTON_HOVER := Color("7a5232")
const BUTTON_PRESS := Color("3d2717")
const GOOD := Color("9ed36a")
const BAD := Color("e5644e")
const WARN := Color("f2b64a")
const GHOST := Color("9fd8e8")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var file: FontFile = load(PACK + "Ui/Font/NormalFont.ttf")
	file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	file.hinting = TextServer.HINTING_NONE
	file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var font := FontVariation.new()
	font.base_font = file
	font.set_spacing(TextServer.SPACING_SPACE, 4)
	t.default_font = font
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_EDGE))
	t.set_stylebox("panel", "Panel", box(PANEL, PANEL_EDGE))
	t.set_stylebox("normal", "Button", box(BUTTON, PANEL_EDGE, 6, 2))
	t.set_stylebox("hover", "Button", box(BUTTON_HOVER, INK, 6, 2))
	t.set_stylebox("pressed", "Button", box(BUTTON_PRESS, PANEL_EDGE, 6, 2))
	t.set_stylebox("disabled", "Button", box(Color(BUTTON, 0.4), Color(PANEL_EDGE, 0.4), 6, 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.5))
	t.set_stylebox("background", "ProgressBar", box(PANEL_EDGE, PANEL_EDGE, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(WARN, WARN, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, INK, 6, 3))
	t.set_color("font_color", "TooltipLabel", INK)
	_theme = t
	return t


static func box(bg: Color, edge: Color, pad_x: int = 9, pad_y: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(3)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func label(text: String = "", color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func icon(tex: Texture2D, size: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r


## A 16px tile cut out of a tileset, as its own texture so it can repeat.
static func tile(path: String, rect: Rect2i) -> Texture2D:
	var img: Image = load(PACK + path).get_image()
	return ImageTexture.create_from_image(img.get_region(rect))


## A piece of a tileset, for one-off props.
static func piece(path: String, rect: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(PACK + path)
	a.region = rect
	return a


## Centered modal card on a dimmed backdrop. Returns the VBox to fill.
static func modal(parent: Node, width: int = 360) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", box(PANEL, INK, 20, 18))
	card.custom_minimum_size.x = width
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	return v


static func wrap(text: String, color: Color = INK) -> Label:
	var l := label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
