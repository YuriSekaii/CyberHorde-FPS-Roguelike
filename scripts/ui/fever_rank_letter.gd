extends Control

# Big fever rank letter (D/C/B/A/S). The colored fill rises from the bottom of
# the glyph to the top as the current tier's duration fills up.

const FONT_SIZE: int = 96
const CAP_HEIGHT_RATIO: float = 0.72
const OUTLINE_SIZE: int = 10

var letter: String = "D"
var color: Color = Color(0.65, 0.65, 0.65)
var fill_ratio: float = 0.0

var _fill_clip: Control
var _fill_draw: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_clip = Control.new()
	_fill_clip.clip_contents = true
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill_clip)
	_fill_draw = Control.new()
	_fill_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_clip.add_child(_fill_draw)
	_fill_draw.draw.connect(_draw_fill_letter)
	resized.connect(_layout_fill)
	_layout_fill()

func set_state(new_letter: String, new_color: Color, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if new_letter != letter or new_color != color:
		letter = new_letter
		color = new_color
		queue_redraw()
		if _fill_draw:
			_fill_draw.queue_redraw()
	if not is_equal_approx(ratio, fill_ratio):
		fill_ratio = ratio
		_layout_fill()

func _glyph_rect() -> Rect2:
	var font := get_theme_default_font()
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var cap_h := FONT_SIZE * CAP_HEIGHT_RATIO
	return Rect2((size.x - w) * 0.5, (size.y - cap_h) * 0.5, w, cap_h)

func _layout_fill() -> void:
	if not _fill_clip:
		return
	var r := _glyph_rect()
	var top := r.end.y - r.size.y * fill_ratio
	_fill_clip.position = Vector2(0.0, top)
	_fill_clip.size = Vector2(size.x, maxf(0.0, size.y - top))
	_fill_draw.position = Vector2(0.0, -top)
	_fill_draw.size = size
	_fill_draw.queue_redraw()

func _baseline() -> Vector2:
	var r := _glyph_rect()
	return Vector2(r.position.x, r.end.y)

func _draw() -> void:
	var font := get_theme_default_font()
	var pos := _baseline()
	draw_string_outline(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, Color(0.0, 0.0, 0.0, 0.75))
	# Empty (unfilled) part of the letter: a dark tint of the tier color
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9))

func _draw_fill_letter() -> void:
	var font := get_theme_default_font()
	_fill_draw.draw_string(font, _baseline(), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
