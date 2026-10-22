class_name GridWorld
extends RefCounted
## Pure game rules for one level: robots, facing, apples and goals.
## Has no visuals, so the interpreter can be tested headless against it.
##
## Map letters: S = robot 0, R = more robots (in reading order), G = goal (one per robot),
## items A = apple, C = carrot, K = corn, # = blocked, D = door (opens with the password),
## I = signpost (blocked), H = horse (walks back and forth, one step after every robot command). Every robot method takes the robot index
## (default 0), so the plain move() / at_goal() calls of earlier levels act on robot 0.
##
## Optional level keys used by the dictionary chapter:
##   "order":  {"apple": 2, ...}  what must be dropped at the goal with drop(item)
##   "prices": {"apple": 3, ...}  returned by market()
##   "report": "count" | "price"  report(value) must equal the picked items as a dict of counts,
##                                 or their total price
## And by the strings/exceptions chapter:
##   "sign" / "password"   read_sign() text, and what say() must be to open a door ahead
##   "customer" / "speech" customer() name, and a template say() must match, e.g. "{customer}님, 사과 {apples}개요"
##   "rule": "one_each"    pick exactly one item of every kind instead of all items
##   "horse_dir": "S"      direction the horses start walking in
##   "rule": "nearest_first"  pick() only works on an item nearest to the start (Manhattan distance)
##   "mailboxes" / "answer"   mailboxes() list, and the value report() must equal (report: "answer")
##   "inputs": ["철수", "3"]  what input() returns, one answer per call (the villager's replies);
##                           a "speech" template can use them as {in0}, {in1}, ...
##   "report": "receipt"     report() must get "합계 1,234원" (the picked items' total price)

## Facing order is clockwise: N, E, S, W. Vector2i is (column, row).
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_LETTERS: String = "NESW"
const ITEM_LETTERS: Dictionary = {"A": "apple", "C": "carrot", "K": "corn"}
const ITEM_NAMES: Dictionary = {"apple": "사과", "carrot": "당근", "corn": "옥수수"}

var width: int = 0
var height: int = 0
var robots: Array[Vector2i] = []
var dirs: Array[int] = []
var goals: Array[Vector2i] = []
var apples: Dictionary = {}  # Vector2i -> item kind ("apple", ...), items still on the board
var apple_total: int = 0  # all items, of every kind
var collected: int = 0
var picked: Dictionary = {}  # kind -> how many were picked
var delivered: Dictionary = {}  # kind -> how many were dropped at the goal
var wanted: Dictionary = {}  # the level's "order"
var prices: Dictionary = {}
var report_kind: String = ""
var reported: Variant = null  # last value given to report(), null if none
var doors: Dictionary = {}  # Vector2i -> true while the door is closed
var horses: Array[Vector2i] = []
var horse_dirs: Array[int] = []
var sign_text: String = ""
var password: String = ""
var customer_name: String = ""
var speech: String = ""
var rule: String = ""
var said_ok: bool = false
var mailbox_list: Array = []
var answer: Variant = null
var last_pick_error: String = ""  # why the last pick() failed under a rule ("" = nothing to pick)
var inputs: Array = []  # answers input() hands out, in order
var _input_at: int = 0

## Robot 0, for single-robot code.
var robot: Vector2i:
	get:
		return robots[0]
var dir: int:
	get:
		return dirs[0]
var goal: Vector2i:
	get:
		return goals[0] if not goals.is_empty() else Vector2i.ZERO

var _rows: PackedStringArray = []
var _starts: Array[Vector2i] = []
var _start_dir: int = 1
var _start_apples: Dictionary = {}
var _start_doors: Dictionary = {}
var _start_horses: Array[Vector2i] = []
var _horse_dir0: int = 2


func load_level(level: Dictionary) -> void:
	_rows = PackedStringArray(level["map"])
	height = _rows.size()
	width = 0
	for row in _rows:
		width = maxi(width, row.length())
	_start_dir = maxi(0, DIR_LETTERS.find(String(level.get("facing", "E"))))
	_start_apples.clear()
	_start_doors.clear()
	_start_horses.clear()
	goals.clear()
	var first := Vector2i(-1, -1)
	var others: Array[Vector2i] = []
	for y in height:
		for x in _rows[y].length():
			var p := Vector2i(x, y)
			match _rows[y][x]:
				"S":
					first = p
				"R":
					others.append(p)
				"G":
					goals.append(p)
				"D":
					_start_doors[p] = true
				"H":
					_start_horses.append(p)
				var c:
					if ITEM_LETTERS.has(c):
						_start_apples[p] = ITEM_LETTERS[c]
	_starts = [first]
	_starts.append_array(others)
	apple_total = _start_apples.size()
	wanted = level.get("order", {})
	prices = level.get("prices", {})
	report_kind = level.get("report", "")
	sign_text = level.get("sign", "")
	password = level.get("password", "")
	customer_name = level.get("customer", "")
	speech = level.get("speech", "")
	rule = level.get("rule", "")
	mailbox_list = level.get("mailboxes", [])
	answer = level.get("answer")
	inputs = level.get("inputs", []).duplicate()
	_horse_dir0 = maxi(0, DIR_LETTERS.find(String(level.get("horse_dir", "S"))))
	reset()


func reset() -> void:
	robots = _starts.duplicate()
	dirs.clear()
	for i in robots.size():
		dirs.append(_start_dir)
	apples = _start_apples.duplicate()
	collected = 0
	picked = {}
	delivered = {}
	reported = null
	doors = _start_doors.duplicate()
	horses = _start_horses.duplicate()
	horse_dirs.clear()
	for h in horses:
		horse_dirs.append(_horse_dir0)
	said_ok = false
	_input_at = 0


## Item kinds on this map, e.g. ["apple", "corn"].
func item_kinds() -> Array:
	var kinds: Array = []
	for k in _start_apples.values():
		if not k in kinds:
			kinds.append(k)
	return kinds


func robot_count() -> int:
	return robots.size()


func cell(p: Vector2i) -> String:
	if p.y < 0 or p.y >= height or p.x < 0 or p.x >= _rows[p.y].length():
		return "#"
	return _rows[p.y][p.x]


func is_walkable(p: Vector2i) -> bool:
	var c := cell(p)
	return c != "#" and c != "I" and not doors.has(p)


func front(i: int = 0) -> Vector2i:
	return robots[i] + DIRS[dirs[i]]


func _occupied(p: Vector2i, except: int) -> bool:
	for j in robots.size():
		if j != except and robots[j] == p:
			return true
	return p in horses


## True when the cell ahead of robot i holds a horse (move() then fails with Blocked).
func horse_ahead(i: int = 0) -> bool:
	return front(i) in horses


func door_ahead(i: int = 0) -> bool:
	return doors.has(front(i))


## Every horse takes one step, turning back at walls, doors, robots and other horses.
## Called by the host after each robot command. Returns how many horses moved.
func tick() -> int:
	var moved := 0
	for h in horses.size():
		var nxt := horses[h] + DIRS[horse_dirs[h]]
		if not _horse_can(nxt):
			horse_dirs[h] = (horse_dirs[h] + 2) % 4
			nxt = horses[h] + DIRS[horse_dirs[h]]
			if not _horse_can(nxt):
				continue
		horses[h] = nxt
		moved += 1
	return moved


func _horse_can(p: Vector2i) -> bool:
	return is_walkable(p) and not p in robots and not p in horses


# --- Commands -------------------------------------------------------------

## Returns false (and does not move) when the cell ahead is blocked.
func move(i: int = 0) -> bool:
	if is_blocked(i):
		return false
	robots[i] = front(i)
	return true


func turn_left(i: int = 0) -> void:
	dirs[i] = (dirs[i] + 3) % 4


func turn_right(i: int = 0) -> void:
	dirs[i] = (dirs[i] + 1) % 4


## Picks whatever item is under the robot. Returns false when there is none, or when a rule
## forbids it (then last_pick_error says why).
func pick(i: int = 0) -> bool:
	last_pick_error = ""
	if not apples.has(robots[i]):
		return false
	if rule == "nearest_first":
		var here := _start_distance(robots[i])
		var nearest := here
		for p in apples:
			nearest = mini(nearest, _start_distance(p))
		if here > nearest:
			last_pick_error = "더 가까운 보물부터 주워야 해요. (이 보물까지 %d칸, 가장 가까운 보물까지 %d칸)" % [here, nearest]
			return false
	var kind: String = apples[robots[i]]
	apples.erase(robots[i])
	collected += 1
	picked[kind] = int(picked.get(kind, 0)) + 1
	return true


## Turns robot i to face "N", "E", "S" or "W". Returns how many quarter turns to the right
## that took (0-3), or -1 for an unknown direction.
func face(i: int, letter: Variant) -> int:
	if not letter is String or String(letter).length() != 1 or DIR_LETTERS.find(String(letter).to_upper()) < 0:
		return -1
	var want := DIR_LETTERS.find(String(letter).to_upper())
	var turns := (want - dirs[i] + 4) % 4
	dirs[i] = want
	return turns


## Drops one `kind` at the goal for the order. Returns an error message, or "" when done.
func drop(i: int, kind: Variant) -> String:
	if not kind is String or not ITEM_NAMES.has(kind):
		return "drop() 에는 \"apple\", \"carrot\", \"corn\" 중 하나를 넣어요 (지금: %s)." % str(kind)
	if not at_goal(i):
		return "배달은 목표(손님 집 앞)에 도착해서 해야 해요."
	delivered[kind] = int(delivered.get(kind, 0)) + 1
	return ""


## Checks a reported value against what was really picked. Returns an error message or "".
func report(value: Variant) -> String:
	reported = value
	var want = expected_report()
	if want == null:
		return "이 레벨에서는 보고할 것이 없어요."
	if not _same_value(value, want):
		return "보고가 틀렸어요. 보고한 값: %s / 실제 값: %s" % [_show(value), _show(want)]
	return ""


## Robot i says `text`. Facing a closed door, the right password opens it. On a level with a
## "speech" template the words must match it. Returns an error message, or "".
func say(i: int, text: Variant) -> String:
	var words := str(text)
	if door_ahead(i):
		if password != "" and words == password:
			doors.erase(front(i))
			return ""
		return "문이 열리지 않아요. 암호가 틀렸어요. (말한 것: \"%s\")" % words
	if speech != "":
		var want := expected_speech()
		if words == want:
			said_ok = true
			return ""
		return "손님이 고개를 갸웃해요. 말한 것: \"%s\" / 들어야 할 말: \"%s\"" % [words, want]
	return ""


func expected_speech() -> String:
	var values := {"customer": customer_name, "apples": int(picked.get("apple", 0)), "items": collected}
	for k in inputs.size():
		values["in%d" % k] = str(inputs[k])  # {in0}: the first input() answer
	return speech.format(values)


func wait(_i: int = 0) -> void:
	pass


func _start_distance(p: Vector2i) -> int:
	return absi(p.x - _starts[0].x) + absi(p.y - _starts[0].y)


## What report() must receive on this level: a dict of counts, a total price or a given answer.
## null if unused.
func expected_report() -> Variant:
	match report_kind:
		"answer":
			return answer
		"count":
			return picked.duplicate()
		"price", "receipt":
			var total := 0
			for k in picked:
				total += int(prices.get(k, 0)) * int(picked[k])
			if report_kind == "receipt":
				return "합계 %s원" % _grouped(total)
			return total
	return null


## 1234567 -> "1,234,567"
static func _grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for k in digits.length():
		if k > 0 and (digits.length() - k) % 3 == 0:
			out += ","
		out += digits[k]
	return ("-" if n < 0 else "") + out


static func _same_value(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for k in a.size():
			if not _same_value(a[k], b[k]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same_value(a[k], b[k]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b


static func _show(v: Variant) -> String:
	if v is Array:
		return "[" + ", ".join(PackedStringArray(v.map(func(x: Variant) -> String: return _show(x)))) + "]"
	if v is Dictionary:
		var parts: PackedStringArray = []
		for k in v:
			parts.append("'%s': %s" % [k, v[k]])
		return "{" + ", ".join(parts) + "}"
	return str(v)


# --- Conditions -----------------------------------------------------------

## Walls and other robots both block.
func is_blocked(i: int = 0) -> bool:
	return not is_walkable(front(i)) or _occupied(front(i), i)


func on_apple(i: int = 0) -> bool:
	return apples.get(robots[i], "") == "apple"


func at_goal(i: int = 0) -> bool:
	return robots[i] in goals


# --- Values (column x grows east, row y grows south) ------------------------

func get_x(i: int = 0) -> int:
	return robots[i].x


func get_y(i: int = 0) -> int:
	return robots[i].y


## Goal of robot i: the i-th G in reading order (the only G in single-robot levels).
func goal_x(i: int = 0) -> int:
	return goals[mini(i, goals.size() - 1)].x


func goal_y(i: int = 0) -> int:
	return goals[mini(i, goals.size() - 1)].y


func apples_left(_i: int = 0) -> int:
	return apples.values().count("apple")


## (x, y) of robot i. Vector2i becomes a tuple in the robot language.
func get_pos(i: int = 0) -> Vector2i:
	return robots[i]


func goal_pos(i: int = 0) -> Vector2i:
	return goals[mini(i, goals.size() - 1)]


## Kind of item under robot i ("apple", "carrot", "corn"), or null.
func item_here(i: int = 0) -> Variant:
	return apples.get(robots[i])


## Positions of every item still on the board, in reading order (top row first).
func treasure_map(_i: int = 0) -> Array:
	var out: Array = apples.keys()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func order(_i: int = 0) -> Dictionary:
	return wanted.duplicate()


func market(_i: int = 0) -> Dictionary:
	return prices.duplicate()


## The next prepared answer for input(), or null when there are no more.
func next_input() -> Variant:
	if _input_at >= inputs.size():
		return null
	_input_at += 1
	return str(inputs[_input_at - 1])


func mailboxes(_i: int = 0) -> Array:
	return mailbox_list.duplicate()


func read_sign(_i: int = 0) -> String:
	return sign_text


func customer(_i: int = 0) -> String:
	return customer_name


## Shortest way from robot i to the nearest goal as actions: "F" (move), "L", "R".
func route(i: int = 0) -> Array:
	var path := _shortest_path(robots[i])
	var out: Array = []
	var d := dirs[i]
	for k in range(1, path.size()):
		var need := DIRS.find(path[k] - path[k - 1])
		var turn := (need - d + 4) % 4
		if turn == 1:
			out.append("R")
		elif turn == 3:
			out.append("L")
		elif turn == 2:
			out.append_array(["R", "R"])
		d = need
		out.append("F")
	return out


## Lengths of the straight parts of route(i), e.g. ["F","F","R","F"] -> [2, 1].
func segments(i: int = 0) -> Array:
	var out: Array = []
	var run := 0
	for a in route(i):
		if a == "F":
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	return out


func _shortest_path(from: Vector2i) -> Array:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var found := Vector2i(-1, -1)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p in goals:
			found = p
			break
		for d in DIRS:
			var q := p + d
			if is_walkable(q) and not prev.has(q):
				prev[q] = p
				queue.append(q)
	if found.x < 0:
		return [from]
	var path: Array = [found]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path


## All apples collected and every goal has a robot on it.
func is_solved() -> bool:
	return failure().is_empty()


## Why the level is not solved yet, most important first:
## {"kind": "goal"} / {"kind": "apples", "left": n} / {"kind": "order"} / {"kind": "report"}; {} when solved.
func failure() -> Dictionary:
	if not all_goals_reached():
		return {"kind": "goal"}
	if rule == "one_each":
		var want := {}
		for k in item_kinds():
			want[k] = 1
		if not _same_value(picked, want):
			return {"kind": "rule"}
	elif collected != apple_total:
		return {"kind": "apples", "left": apple_total - collected}
	if not wanted.is_empty() and not _same_value(_without_zeros(delivered), _without_zeros(wanted)):
		return {"kind": "order"}
	if report_kind != "" and (reported == null or not _same_value(reported, expected_report())):
		return {"kind": "report"}
	if speech != "" and not said_ok:
		return {"kind": "speech"}
	return {}


static func _without_zeros(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if int(d[k]) != 0:
			out[k] = d[k]
	return out


func all_goals_reached() -> bool:
	for g in goals:
		if not g in robots:
			return false
	return true
