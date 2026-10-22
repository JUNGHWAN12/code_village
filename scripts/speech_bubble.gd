class_name SpeechBubble
extends PanelContainer
## A comic-style speech bubble drawn over the 3D view. It types its text out, shows a speaker
## name, and points a tail at a screen position (a villager's head) that the owner updates
## every frame with point_at(). Click: finish typing, then go to the next line, then close.

signal typing_changed(typing: bool)
signal closed

const WIDTH: float = 330.0
const CHARS_PER_SECOND: float = 45.0
const TAIL: float = 16.0
const BG := Color(1.0, 0.97, 0.88)
const BORDER := Color(0.36, 0.25, 0.15)

var _name_label: Label
var _text: RichTextLabel
var _lines: Array = []
var _index: int = 0
var _hold: float = 0.0  # > 0: close by itself this many seconds after the last line is typed
var _hold_left: float = 0.0
var _typing: bool = false
var _target: Vector2 = Vector2.ZERO
var _view: Rect2 = Rect2()
var _auto: float = 0.0  # > 0: each line moves on by itself this many seconds after it is typed
var _auto_left: float = 0.0
var _side: int = 0  # 0: bubble above the target; -1 / 1: bubble left / right of it (no room above)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(0.62, 0.32, 0.12))
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name_label)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 32, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("default_color", Color(0.18, 0.13, 0.08))
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_font_size_override("mono_font_size", 16)
	box.add_child(_text)
	hide()


## Shows `lines` one after another. `hold` > 0 closes the bubble by itself after the last line.
## `auto` > 0 also moves to the next line by itself (and closes after the last), for intros.
func say(speaker: String, lines: Array, hold: float = 0.0, auto: float = 0.0) -> void:
	if lines.is_empty():
		return
	_name_label.text = speaker
	_lines = lines
	_index = 0
	_hold = hold
	_auto = auto
	show()
	_show_line()


func dismiss() -> void:
	if not visible:
		return
	_set_typing(false)
	hide()
	closed.emit()


## Keeps the tail on `target` (screen position) and the bubble inside `view`. The bubble sits
## above the target; when there is no room above, it moves beside it so it never covers the speaker.
func point_at(target: Vector2, view: Rect2) -> void:
	_target = target
	_view = view
	var pos := target - Vector2(size.x * 0.5, size.y + TAIL)
	_side = 0
	if pos.y < view.position.y + 8.0:
		_side = 1 if target.x < view.get_center().x else -1
		pos.x = target.x + TAIL + 10.0 if _side == 1 else target.x - size.x - TAIL - 10.0
		pos.y = target.y - size.y * 0.35
	pos.x = clampf(pos.x, view.position.x + 8.0, view.end.x - size.x - 8.0)
	pos.y = clampf(pos.y, view.position.y + 8.0, view.end.y - size.y - 8.0)
	position = pos
	queue_redraw()


## Turns [code]...[/code] into colored monospace text, keeping "[" inside code literal.
## `code_color` suits the bubble's light background; pass a light color for dark panels.
static func format(text: String, code_color: String = "#2f6db5") -> String:
	var out := ""
	var rest := text
	while true:
		var a := rest.find("[code]")
		if a < 0:
			return out + rest
		var b := rest.find("[/code]", a)
		if b < 0:
			return out + rest
		var inner := rest.substr(a + 6, b - a - 6).replace("[", "[lb]")
		out += rest.substr(0, a) + "[color=%s][code]" % code_color + inner + "[/code][/color]"
		rest = rest.substr(b + 7)
	return out


func _show_line() -> void:
	var more := _index < _lines.size() - 1
	var text := format(String(_lines[_index]))
	if more:
		text += "  [color=#b08a5a]▶[/color]"
	_text.text = text
	_text.visible_characters = 0
	_hold_left = _hold
	_auto_left = _auto
	_set_typing(true)


func _process(delta: float) -> void:
	if not visible:
		return
	if _typing:
		var total := _text.get_total_character_count()
		_text.visible_characters = mini(total, _text.visible_characters + maxi(1, int(CHARS_PER_SECOND * delta + 0.5)))
		if _text.visible_characters >= total:
			_set_typing(false)
	elif _auto > 0.0:
		_auto_left -= delta
		if _auto_left <= 0.0:
			advance()
	elif _hold > 0.0 and _index >= _lines.size() - 1:
		_hold_left -= delta
		if _hold_left <= 0.0:
			dismiss()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


## Finishes typing, or moves to the next line, or closes after the last one.
func advance() -> void:
	if _typing:
		_text.visible_characters = -1
		_set_typing(false)
	elif _index < _lines.size() - 1:
		_index += 1
		_show_line()
	else:
		dismiss()


func _set_typing(typing: bool) -> void:
	if _typing != typing:
		_typing = typing
		typing_changed.emit(typing)


func _draw() -> void:
	var tip := _target - position
	if _side != 0:
		# Tail from the side edge facing the target.
		var x := 3.0 if _side == 1 else size.x - 3.0
		var cy := clampf(tip.y, 22.0, size.y - 22.0)
		var out := -TAIL if _side == 1 else TAIL
		var side_pts := PackedVector2Array([Vector2(x, cy - 11), Vector2(x, cy + 11), Vector2(x + out, clampf(tip.y, cy - 26, cy + 26))])
		draw_colored_polygon(side_pts, BG)
		draw_polyline(PackedVector2Array([side_pts[0], side_pts[2], side_pts[1]]), BORDER, 3.0, true)
		return
	# Tail: a triangle from the bubble's bottom edge toward the target.
	var cx := clampf(tip.x, 26.0, size.x - 26.0)
	var y := size.y - 3.0
	var pts := PackedVector2Array([Vector2(cx - 12, y), Vector2(cx + 12, y), Vector2(clampf(tip.x, cx - 30, cx + 30), y + TAIL)])
	draw_colored_polygon(pts, BG)
	draw_polyline(PackedVector2Array([pts[0], pts[2], pts[1]]), BORDER, 3.0, true)
