class_name ChapterMenu
extends Control
## Full-screen chapter picker: one card per chapter (Levels.CHAPTERS) with a button per level.
## Locked levels are greyed out. The owner fills it with open(stars, unlocked, unlock_all).

signal level_chosen(index: int)
signal unlock_all_toggled(on: bool)
signal closed

const CARD_BG := Color(0.2, 0.15, 0.11, 0.97)
const CARD_LOCKED := Color(0.15, 0.13, 0.12, 0.92)
const GOLD := Color(1.0, 0.83, 0.42)

var _grid: GridContainer
var _summary: Label
var _unlock_box: CheckBox
var _close_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.05, 0.04, 0.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "코드 빌리지 · 챕터"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 18)
	_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	_unlock_box = CheckBox.new()
	_unlock_box.text = "선생님용: 모든 레벨 열기"
	_unlock_box.add_theme_font_size_override("font_size", 14)
	_unlock_box.toggled.connect(func(on: bool) -> void: unlock_all_toggled.emit(on))
	foot.add_child(_unlock_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	_close_btn = Button.new()
	_close_btn.text = "닫기"
	_close_btn.custom_minimum_size = Vector2(120, 40)
	_close_btn.pressed.connect(close)
	foot.add_child(_close_btn)
	hide()


## stars[i]: best stars of level i (0 = not cleared). unlocked: Callable(i) -> bool.
func open(stars: Array, unlocked: Callable, unlock_all: bool, current: int) -> void:
	for child in _grid.get_children():
		child.queue_free()
	var total := 0
	for s in stars:
		total += int(s)
	_summary.text = "★ %d / %d" % [total, stars.size() * 3]
	_unlock_box.set_pressed_no_signal(unlock_all)
	for c in Levels.CHAPTERS.size():
		_grid.add_child(_card(c, stars, unlocked, current))
	show()


func close() -> void:
	hide()
	closed.emit()


func _card(c: int, stars: Array, unlocked: Callable, current: int) -> Control:
	var chapter: Dictionary = Levels.CHAPTERS[c]
	var levels: Array = chapter["levels"]
	var open_card: bool = unlocked.call(levels[0])
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 170)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG if open_card else CARD_LOCKED
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = GOLD if Levels.chapter_of(current) == c else Color(0.4, 0.3, 0.2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var head := Label.new()
	head.text = ("%d. %s" % [c + 1, chapter["title"]]) + ("" if open_card else "  🔒")
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", GOLD if open_card else Color(0.6, 0.55, 0.5))
	box.add_child(head)
	var topic := Label.new()
	topic.text = chapter["topic"]
	topic.add_theme_font_size_override("font_size", 14)
	topic.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0) if open_card else Color(0.5, 0.5, 0.5))
	box.add_child(topic)
	var who: Dictionary = Dialogue.CAST.get(Dialogue.for_level(levels[0]).get("who", ""), {})
	if not who.is_empty():
		var npc := Label.new()
		npc.text = who["name"]
		npc.add_theme_font_size_override("font_size", 13)
		npc.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
		box.add_child(npc)

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	for i in levels:
		var btn := Button.new()
		var s := int(stars[i])
		var is_open: bool = unlocked.call(i)
		btn.text = "%d\n%s" % [Levels.number(i),("★".repeat(s) + "☆".repeat(3 - s)) if is_open else "🔒"]
		btn.custom_minimum_size = Vector2(54, 50)
		btn.add_theme_font_size_override("font_size", 14)
		btn.disabled = not is_open
		btn.tooltip_text = Levels.title(i)
		if i == current:
			btn.add_theme_color_override("font_color", GOLD)
		btn.pressed.connect(func() -> void:
			hide()
			level_chosen.emit(i))
		row.add_child(btn)
	return panel


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
