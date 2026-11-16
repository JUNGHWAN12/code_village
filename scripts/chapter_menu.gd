class_name ChapterMenu
extends Control
## Full-screen chapter picker: one card per chapter (Levels.CHAPTERS) with a button per level.
## Locked levels are greyed out. The owner fills it with open(stars, unlocked, unlock_all).

signal level_chosen(index: int)
signal unlock_all_toggled(on: bool)
signal skin_chosen(index: int)
signal closed

const CARD_BG := Color(0.2, 0.15, 0.11, 0.97)
const CARD_LOCKED := Color(0.15, 0.13, 0.12, 0.92)
const GOLD := Color(1.0, 0.83, 0.42)

var _grid: GridContainer
var _summary: Label
var _unlock_box: CheckBox
var _close_btn: Button
var _skins: HBoxContainer


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
	_skins = HBoxContainer.new()
	_skins.add_theme_constant_override("separation", 6)
	foot.add_child(_skins)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	foot.add_child(gap)
	_close_btn = Button.new()
	_close_btn.text = "닫기"
	_close_btn.custom_minimum_size = Vector2(120, 40)
	_close_btn.pressed.connect(close)
	foot.add_child(_close_btn)
	hide()


## stars[i]: star mask of level i (bit per Levels.star_goals entry, 0 = not cleared).
## unlocked: Callable(i) -> bool. ref_steps: Callable(level index, map index) -> int, the commands the
## reference solution needs (asked only for a level the pointer is on).
## skin: the robot color in use (index into Levels.SKINS).
func open(stars: Array, unlocked: Callable, unlock_all: bool, current: int, ref_steps: Callable = Callable(), skin: int = 0) -> void:
	for child in _grid.get_children():
		child.queue_free()
	var total := 0
	for s in stars:
		total += Levels.star_count(int(s))
	_summary.text = "★ %d / %d" % [total, stars.size() * 3]
	_unlock_box.set_pressed_no_signal(unlock_all)
	_fill_skins(total, skin)
	for c in Levels.CHAPTERS.size():
		_grid.add_child(_card(c, stars, unlocked, current, ref_steps))
	show()


func close() -> void:
	hide()
	closed.emit()


func _card(c: int, stars: Array, unlocked: Callable, current: int, ref_steps: Callable) -> Control:
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
		btn.text = "%d\n%s" % [Levels.number(i), Levels.star_marks(s) if is_open else "🔒"]
		btn.custom_minimum_size = Vector2(54, 50)
		btn.add_theme_font_size_override("font_size", 14)
		btn.disabled = not is_open
		btn.tooltip_text = Levels.title(i)
		if is_open:
			# The commands target needs a run of the solution: work it out when the pointer gets here.
			btn.tooltip_text = star_tip(i, s)
			if ref_steps.is_valid():
				btn.mouse_entered.connect(func() -> void:
					btn.tooltip_text = star_tip(i, s, int(ref_steps.call(i, 0))), CONNECT_ONE_SHOT)
		if i == current:
			btn.add_theme_color_override("font_color", GOLD)
		btn.pressed.connect(func() -> void:
			hide()
			level_chosen.emit(i))
		row.add_child(btn)
	return panel


## The robot colors: a swatch per skin, locked ones showing the stars they need.
func _fill_skins(total: int, current: int) -> void:
	for child in _skins.get_children():
		child.queue_free()
	var label := Label.new()
	label.text = "로봇 색"
	label.add_theme_font_size_override("font_size", 14)
	_skins.add_child(label)
	for i in Levels.SKINS.size():
		var skin: Dictionary = Levels.SKINS[i]
		var is_open := Levels.skin_unlocked(i, total)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(58, 40)
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = ("✔" if i == current else "") if is_open else "★%d" % Levels.skin_stars(i)
		btn.disabled = not is_open
		btn.tooltip_text = "%s 로봇" % skin["name"] if is_open else "%s 로봇: 별 %d개를 모으면 열려요 (지금 %d개)" % [
				skin["name"], Levels.skin_stars(i), total]
		var color: Color = skin["color"]
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = color.darkened(0.6) if state == "disabled" else (color.lightened(0.15) if state == "hover" else color)
			box.set_corner_radius_all(8)
			box.set_border_width_all(3 if i == current else 1)
			box.border_color = GOLD if i == current else Color(0.25, 0.18, 0.12)
			btn.add_theme_stylebox_override(state, box)
		btn.add_theme_color_override("font_color", Color(0.12, 0.09, 0.06))
		btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.75, 0.65))
		btn.pressed.connect(func() -> void: skin_chosen.emit(i))
		_skins.add_child(btn)


## Tooltip of a level button: its title, then one line per star with its target (on the main map).
static func star_tip(i: int, mask: int, ref_steps: int = -1) -> String:
	var text := Levels.title(i)
	var goals := Levels.star_goals(Levels.ALL[i], 0, ref_steps)
	for g in goals.size():
		text += "\n%s %s" % ["★" if mask & (1 << g) else "☆", Levels.star_text(goals[g])]
	return text


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
