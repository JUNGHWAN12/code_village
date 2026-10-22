class_name CodeInterpreter
extends RefCounted
## Parser and tree-walking runner for the robot language: a small subset of Python.
##
## Statements: calls, assignment (= += -= *= /= //= %=), if/elif/else, while, for NAME in ...:,
##   repeat N:, def/return, break, continue, pass, global, import math / import random.
## Expressions: int, float, "text", [lists], True/False/None, + - * / // % **,
##   == != < > <= >= in, not in (chained like Python), and/or/not, calls, math.sqrt, a[i].
## Robot API: commands move() turn_left() turn_right() pick(); conditions is_blocked()
##   on_apple() at_goal(); values get_x() get_y() goal_x() goal_y() apples_left().
## Builtins: print range len abs min max int float str round. Modules: math, random.
## A level can ban names (e.g. at_goal) so the puzzle needs counting instead.
##
## Objects: robots() returns robot objects (r.move(), r.at_goal(), r.name). Classes: class Name:,
##   class Name(Base):, __init__, self.attr, methods, inheritance and super().
## A level can also require features ("random", "class", "inherit") so the lesson gets used.
##
## The host passed to run() must provide (robot is the robot index, 0 for plain move() calls):
##   run_command(name: String, line: int, robot: int) -> String  (may await; "" means success)
##   sense(name: String, robot: int) -> Variant         (conditions and value queries)
##   robot_count() -> int
##   show_step(line: int, text: String, value) -> void  (may await; step mode. value is the
##                                                      bool result for conditions, else null)
##   print_line(text: String) -> void
##   highlight_line(line: int) -> void
##   is_stop_requested() -> bool
## WorldHost is a ready-made synchronous host over a GridWorld.

const COMMANDS: PackedStringArray = ["move", "turn_left", "turn_right", "pick", "face", "drop", "report", "say", "wait"]
## Commands that take a value; every other command takes none.
const COMMAND_ARGS: Dictionary = {"face": 1, "drop": 1, "report": 1, "say": 1}
## The exception a failing command raises (try/except can catch it); others raise RobotError.
const COMMAND_ERRORS: Dictionary = {"move": "Blocked", "pick": "NoItem"}
## Names usable after except. Exception catches every one of them.
const EXCEPTIONS: PackedStringArray = [
	"Exception", "Blocked", "NoItem", "RobotError", "KeyError", "IndexError", "ValueError",
	"TypeError", "ZeroDivisionError", "NameError",
]
const CONDITIONS: PackedStringArray = ["is_blocked", "on_apple", "at_goal"]
const SENSORS: PackedStringArray = [
	"get_x", "get_y", "goal_x", "goal_y", "apples_left", "route", "segments",
	"get_pos", "goal_pos", "item_here", "treasure_map", "order", "market", "read_sign", "customer",
]
const BUILTINS: PackedStringArray = [
	"print", "range", "len", "abs", "min", "max", "int", "float", "str", "round", "robots", "super",
	"sorted", "sum", "enumerate", "zip", "list", "tuple", "dict", "set",
]
## Robot names in robots() order; main.gd tints the robots to match.
const ROBOT_NAMES: PackedStringArray = ["주황", "파랑", "초록", "보라"]
const REQUIRED_MESSAGES: Dictionary = {
	"random": "이 레벨은 import random 으로 무작위를 써서 풀어요.",
	"class": "이 레벨은 class 를 만들어서 풀어요.",
	"inherit": "이 레벨은 다른 class 를 물려받는 class 를 만들어서 풀어요. 예: class Picker(Walker):",
	"dict": "이 레벨은 딕셔너리 {\"키\": 값} 을 만들어서 풀어요.",
	"try": "이 레벨은 try: / except 오류이름: 으로 오류를 잡아서 풀어요.",
}
const MODULES: Dictionary = {
	"math": ["sqrt", "floor", "ceil", "pow", "pi"],
	"random": ["randint", "choice", "random"],
}
const KEYWORDS: PackedStringArray = [
	"if", "elif", "else", "while", "for", "in", "repeat", "def", "return", "break", "continue",
	"pass", "import", "global", "not", "and", "or", "True", "False", "None",
	"class", "lambda", "from", "as", "with", "try", "except", "finally", "raise", "yield",
	"del", "is", "assert", "nonlocal",
]
const UNSUPPORTED: PackedStringArray = [
	"lambda", "from", "as", "with", "raise", "yield", "assert", "nonlocal",
]
const ASSIGN_OPS: PackedStringArray = ["=", "+=", "-=", "*=", "/=", "//=", "%="]
const MAX_STEPS: int = 5000
const MAX_DEPTH: int = 30
const MAX_LIST: int = 10000

enum Flow { NORMAL, BREAK, CONTINUE, RETURN, ERROR }

# --- Parse state ---
var _lines: Array[Dictionary] = []
var _pos: int = 0
var _error: Dictionary = {}
var _toks: Array = []
var _tp: int = 0
var _line: int = 0  # current source line (0-based); also used while running
var _cur_text: String = ""
var _banned: PackedStringArray = []
var _in_cond: bool = false
var _loop_depth: int = 0
var _func_stack: Array = []  # one {"assigned": {}, "globals": {}} per def being parsed
var _defined: Dictionary = {}  # names of every def in the program
var _assigned: Dictionary = {}  # every name that gets a value somewhere
var _calls: Array = []  # [{"name", "line", "cond"}] checked once the whole program is parsed
var _in_class: bool = false
var _last_items_had_comma: bool = false
var _features: Dictionary = {}  # "random", "math", "class", "inherit" -> true when the code uses them

# --- Run state ---
var _host
var _err: Dictionary = {}
var _steps: int = 0
var _depth: int = 0
var _globals: Dictionary = {}
var _frames: Array = []  # [{"vars": Dictionary, "fn": def node}]
var _ret: Variant = null
var _rng := RandomNumberGenerator.new()


## Counts lines that hold code (not blank, not comment-only).
static func count_code_lines(source: String) -> int:
	var n := 0
	for raw in source.split("\n"):
		if not strip_comment(raw).strip_edges().is_empty():
			n += 1
	return n


## Removes a trailing # comment, ignoring # inside quotes.
static func strip_comment(text: String) -> String:
	var quote := ""
	var escaped := false
	for i in text.length():
		var c := text[i]
		if quote != "":
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return text.substr(0, i)
	return text


# =========================================================================
# Parsing
# =========================================================================

## Returns {"ok": true, "program": Array} or {"ok": false, "line": int, "message": String}.
## `banned` names fail where they appear; each `required` feature (see REQUIRED_MESSAGES)
## must be used somewhere in the program.
func parse(source: String, banned: PackedStringArray = PackedStringArray(),
		required: PackedStringArray = PackedStringArray()) -> Dictionary:
	_lines.clear()
	_pos = 0
	_error = {}
	_banned = banned
	_in_class = false
	_features = {}
	_in_cond = false
	_loop_depth = 0
	_func_stack = []
	_defined = {}
	_assigned = {}
	_calls = []

	var raw := source.split("\n")
	for i in raw.size():
		var text := strip_comment(raw[i]).rstrip(" \t\r")
		if text.strip_edges().is_empty():
			continue
		var indent := 0
		var k := 0
		while k < text.length() and (text[k] == " " or text[k] == "\t"):
			indent += 4 if text[k] == "\t" else 1
			k += 1
		var body := text.substr(k)
		_line = i
		var toks := _tokenize(body)
		if not _error.is_empty():
			return _error
		_lines.append({"indent": indent, "text": body, "line": i, "toks": toks})

	if _lines.is_empty():
		return _fail(0, "코드가 비어 있어요. 명령을 적어 보세요. 예: move()")
	if int(_lines[0]["indent"]) != 0:
		return _fail(int(_lines[0]["line"]), "첫 줄은 들여쓰지 않아야 해요.")

	var program := _parse_block(0)
	if not _error.is_empty():
		return _error

	for c in _calls:
		var name: String = c["name"]
		if _is_known(name):
			continue
		var hint := _suggest(name, _callable_names())
		if c["cond"]:
			return _fail(int(c["line"]), "모르는 조건이에요: '%s()'%s" % [name, hint])
		return _fail(int(c["line"]), "모르는 명령이에요: '%s()'%s" % [name, hint])
	for feature in required:
		if not _features.has(feature):
			return _fail(0, REQUIRED_MESSAGES.get(feature, "이 레벨에 필요한 문법이 빠졌어요: %s" % feature))
	return {"ok": true, "program": program}


func _fail(line: int, message: String) -> Dictionary:
	if _error.is_empty():
		_error = {"ok": false, "line": line, "message": message}
	return _error


## Records a parse error and returns an empty node.
func _bad(message: String) -> Dictionary:
	_fail(_line, message)
	return {}


func _is_builtin_name(name: String) -> bool:
	return name in COMMANDS or name in CONDITIONS or name in SENSORS or name in BUILTINS


func _is_known(name: String) -> bool:
	return _is_builtin_name(name) or _defined.has(name) or _assigned.has(name)


func _callable_names() -> Array:
	var names: Array = []
	names.append_array(COMMANDS)
	names.append_array(CONDITIONS)
	names.append_array(SENSORS)
	names.append_array(BUILTINS)
	names.append_array(_defined.keys())
	return names


## " 혹시 'move' 인가요?" for a likely typo of one of `candidates`, else "".
static func _suggest(name: String, candidates: Array) -> String:
	var best := ""
	var best_dist := 1 if name.length() <= 4 else 2
	for c in candidates:
		var dist := _edit_distance(name.to_lower(), String(c).to_lower())
		if dist > 0 and dist <= best_dist:
			best_dist = dist
			best = c
	return "" if best == "" else "  혹시 '%s' 인가요?" % best


## Levenshtein distance where swapping two neighbouring letters counts as one edit.
static func _edit_distance(a: String, b: String) -> int:
	var rows: Array = []
	for i in a.length() + 1:
		var row: Array = []
		row.resize(b.length() + 1)
		row[0] = i
		rows.append(row)
	for j in b.length() + 1:
		rows[0][j] = j
	for i in range(1, a.length() + 1):
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			var d: int = mini(mini(rows[i - 1][j] + 1, rows[i][j - 1] + 1), rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				d = mini(d, rows[i - 2][j - 2] + 1)
			rows[i][j] = d
	return rows[a.length()][b.length()]


func _note_assign(name: String) -> void:
	_assigned[name] = true
	if not _func_stack.is_empty():
		_func_stack.back()["assigned"][name] = true


# --- Tokens ---------------------------------------------------------------

static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_ident_start(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c.unicode_at(0) > 127


static func _is_ident(c: String) -> bool:
	return _is_ident_start(c) or _is_digit(c)


## Splits one line into tokens: {"t": "num"|"str"|"name"|"op"|"end", "v": value}.
func _tokenize(text: String) -> Array:
	var toks: Array = []
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if _is_digit(c) or (c == "." and i + 1 < n and _is_digit(text[i + 1])):
			var j := i
			var is_float := false
			while j < n and (_is_digit(text[j]) or (text[j] == "." and not is_float)):
				if text[j] == ".":
					is_float = true
				j += 1
			var s := text.substr(i, j - i)
			toks.append({"t": "num", "v": s.to_float() if is_float else s.to_int()})
			i = j
			continue
		if (c == "f" or c == "F") and i + 1 < n and (text[i + 1] == "\"" or text[i + 1] == "'"):
			var end := _tokenize_fstring(text, i + 1, toks)
			if end < 0:
				return []
			i = end
			continue
		if _is_ident_start(c):
			var j := i + 1
			while j < n and _is_ident(text[j]):
				j += 1
			toks.append({"t": "name", "v": text.substr(i, j - i)})
			i = j
			continue
		if c == "\"" or c == "'":
			var j := i + 1
			var buf := ""
			while j < n and text[j] != c:
				if text[j] == "\\" and j + 1 < n:
					var e := text[j + 1]
					buf += "\n" if e == "n" else ("\t" if e == "t" else e)
					j += 2
				else:
					buf += text[j]
					j += 1
			if j >= n:
				_fail(_line, "글자의 따옴표(%s)가 닫히지 않았어요." % c)
				return []
			toks.append({"t": "str", "v": buf})
			i = j + 1
			continue
		var three := text.substr(i, 3)
		var two := text.substr(i, 2)
		if three == "//=":
			toks.append({"t": "op", "v": three})
			i += 3
		elif two in ["==", "!=", "<=", ">=", "//", "+=", "-=", "*=", "/=", "%=", "**"]:
			toks.append({"t": "op", "v": two})
			i += 2
		elif c in "+-*/%<>=()[]{},:.|&":
			toks.append({"t": "op", "v": c})
			i += 1
		else:
			_fail(_line, "이해할 수 없는 글자가 있어요: '%s'" % c)
			return []
	toks.append({"t": "end", "v": ""})
	return toks


## Reads f"..." starting at the quote `q_at`. Appends {"t": "fstr", "v": parts} where each part is
## literal text or {"src": expression text, "spec": format spec}. Returns the index after the
## closing quote, or -1 after recording an error.
func _tokenize_fstring(text: String, q_at: int, toks: Array) -> int:
	var quote := text[q_at]
	var parts: Array = []
	var buf := ""
	var j := q_at + 1
	var n := text.length()
	while j < n and text[j] != quote:
		var ch := text[j]
		if ch == "{" and j + 1 < n and text[j + 1] == "{":
			buf += "{"
			j += 2
		elif ch == "}" and j + 1 < n and text[j + 1] == "}":
			buf += "}"
			j += 2
		elif ch == "{":
			var close := text.find("}", j)
			if close < 0 or close > text.find(quote, j):
				_fail(_line, "f-문자열의 '{' 가 '}' 로 닫히지 않았어요.")
				return -1
			var inner := text.substr(j + 1, close - j - 1)
			var spec := ""
			var colon := inner.rfind(":")
			if colon >= 0 and not inner.substr(colon).contains("]") and not inner.substr(colon).contains(")"):
				spec = inner.substr(colon + 1)
				inner = inner.substr(0, colon)
			if inner.strip_edges().is_empty():
				_fail(_line, "f-문자열의 { } 안에 값을 적어 주세요. 예: f\"사과 {n}개\"")
				return -1
			if buf != "":
				parts.append(buf)
				buf = ""
			parts.append({"src": inner, "spec": spec})
			j = close + 1
		elif ch == "\\" and j + 1 < n:
			var e := text[j + 1]
			buf += "\n" if e == "n" else ("\t" if e == "t" else e)
			j += 2
		else:
			buf += ch
			j += 1
	if j >= n:
		_fail(_line, "글자의 따옴표(%s)가 닫히지 않았어요." % quote)
		return -1
	if buf != "":
		parts.append(buf)
	toks.append({"t": "fstr", "v": parts})
	return j + 1


func _peek(offset: int = 0) -> Dictionary:
	return _toks[mini(_tp + offset, _toks.size() - 1)]


func _next() -> Dictionary:
	var t := _peek()
	if _tp < _toks.size() - 1:
		_tp += 1
	return t


static func _is_op(t: Dictionary, v: String) -> bool:
	return t["t"] == "op" and t["v"] == v


static func _is_word(t: Dictionary, v: String) -> bool:
	return t["t"] == "name" and t["v"] == v


func _at_end() -> bool:
	return _peek()["t"] == "end"


func _enter_line(ln: Dictionary) -> void:
	_toks = ln["toks"]
	_tp = 0
	_line = int(ln["line"])
	_cur_text = String(ln["text"])


# --- Blocks and statements --------------------------------------------------

func _parse_block(indent: int) -> Array:
	var body: Array = []
	while _pos < _lines.size() and _error.is_empty():
		var ln: Dictionary = _lines[_pos]
		var ln_indent := int(ln["indent"])
		if ln_indent < indent:
			break
		if ln_indent > indent:
			_fail(int(ln["line"]), "들여쓰기가 맞지 않아요. 위 줄과 칸을 맞춰 보세요.")
			break
		var node := _parse_statement(indent)
		if not _error.is_empty():
			break
		body.append(node)
	return body


## Parses the indented block that must follow a header line ending in ':'.
func _parse_child_block(header: Dictionary, indent: int) -> Array:
	if _pos >= _lines.size() or int(_lines[_pos]["indent"]) <= indent:
		_fail(int(header["line"]), "':' 다음 줄은 한 칸 더 들여써야 해요 (스페이스 4칸).")
		return []
	return _parse_block(int(_lines[_pos]["indent"]))


func _parse_statement(indent: int) -> Dictionary:
	var ln: Dictionary = _lines[_pos]
	_pos += 1
	_enter_line(ln)
	var line := _line
	var first := _peek()
	if first["t"] == "name":
		var w: String = first["v"]
		match w:
			"if":
				_next()
				return _parse_if(ln, indent)
			"elif":
				return _bad("elif 앞에는 if 가 있어야 해요.")
			"else":
				if _is_word(_peek(1), "if"):
					return _bad("else if 대신 elif 를 써요.")
				return _bad("else 앞에는 if 가 있어야 해요.")
			"while":
				_next()
				var cond := _parse_header_expr("while", true)
				if not _error.is_empty():
					return {}
				_loop_depth += 1
				var body := _parse_child_block(ln, indent)
				_loop_depth -= 1
				return {"type": "while", "cond": cond, "text": _header_text(ln, "while"), "body": body, "line": line}
			"for":
				return _parse_for(ln, indent)
			"repeat":
				_next()
				var count := _parse_header_expr("repeat", false)
				if not _error.is_empty():
					return {}
				_loop_depth += 1
				var body := _parse_child_block(ln, indent)
				_loop_depth -= 1
				return {"type": "repeat", "count": count, "body": body, "line": line}
			"def":
				return _parse_def(ln, indent)
			"return":
				_next()
				if _func_stack.is_empty():
					return _bad("return 은 def 안에서만 쓸 수 있어요.")
				var value = null
				if not _at_end():
					value = _parse_expr_list()
				_expect_end()
				return {"type": "return", "value": value, "line": line}
			"del":
				_next()
				var targets: Array = []
				while _error.is_empty():
					var tgt := _parse_expr()
					if not _error.is_empty():
						return {}
					if tgt["type"] != "index":
						return _bad("del 은 목록이나 딕셔너리의 한 칸을 지울 때 써요. 예: del d[\"apple\"]")
					targets.append(tgt)
					if not _is_op(_peek(), ","):
						break
					_next()
				_expect_end()
				return {"type": "del", "targets": targets, "line": line}
			"break", "continue":
				_next()
				if _loop_depth == 0:
					return _bad("%s 는 반복문(while, for, repeat) 안에서만 쓸 수 있어요." % w)
				_expect_end()
				return {"type": w, "line": line}
			"pass":
				_next()
				_expect_end()
				return {"type": "pass", "line": line}
			"import":
				return _parse_import()
			"global":
				_next()
				if _func_stack.is_empty():
					return _bad("global 은 def 안에서만 써요.")
				while true:
					var t := _next()
					if t["t"] != "name" or t["v"] in KEYWORDS:
						return _bad("global 뒤에는 변수 이름을 적어요. 예: global n")
					_func_stack.back()["globals"][t["v"]] = true
					if _is_op(_peek(), ","):
						_next()
						continue
					break
				_expect_end()
				return {"type": "pass", "line": line}
			"try":
				return _parse_try(ln, indent)
			"except", "finally":
				return _bad("%s 앞에는 try: 가 있어야 해요." % w)
			"from":
				return _bad("from 대신 'import math' 처럼 적고 math.sqrt() 로 써 주세요.")
			"class":
				return _parse_class(ln, indent)
		if w in UNSUPPORTED:
			return _bad("'%s' 는 아직 이 게임에서 쓸 수 없어요." % w)
	return _parse_simple()


## Text of a header's expression, e.g. "not at_goal()" for "while not at_goal():".
static func _header_text(ln: Dictionary, word: String) -> String:
	return String(ln["text"]).substr(word.length()).strip_edges().trim_suffix(":").strip_edges()


## Parses the expression after a block keyword, then the ':' that ends the line.
func _parse_header_expr(word: String, is_cond: bool) -> Dictionary:
	if _at_end() or _is_op(_peek(), ":"):
		if word == "repeat":
			return _bad("repeat 뒤에 반복할 횟수를 적어 주세요. 예: repeat 3:")
		return _bad("'%s' 뒤에 조건을 적어 주세요. 예: %s not at_goal():" % [word, word])
	_in_cond = is_cond
	var e := _parse_expr()
	_in_cond = false
	if not _error.is_empty():
		return {}
	_expect_colon(word)
	return e


func _expect_colon(word: String) -> void:
	if not _error.is_empty():
		return
	var t := _peek()
	if _is_op(t, ":"):
		_next()
		if not _at_end():
			_fail(_line, "':' 뒤에는 아무것도 쓰지 말고, 다음 줄에 들여써서 적어요.")
	elif t["t"] == "end":
		_fail(_line, "'%s' 줄 끝에 ':'를 붙여 주세요." % word)
	elif _is_op(t, "="):
		_fail(_line, "같은지 비교할 때는 '=' 대신 '==' 를 써요.")
	else:
		_fail(_line, "'%s' 문장의 모양이 올바르지 않아요." % word)


func _expect_end() -> void:
	if _error.is_empty() and not _at_end():
		_fail(_line, "이해할 수 없는 줄이에요: %s" % _cur_text)


func _parse_if(ln: Dictionary, indent: int) -> Dictionary:
	var line := int(ln["line"])
	var word: String = ln["toks"][0]["v"]
	var cond := _parse_header_expr(word, true)
	if not _error.is_empty():
		return {}
	var body := _parse_child_block(ln, indent)
	var else_body: Array = []
	if _error.is_empty() and _pos < _lines.size() and int(_lines[_pos]["indent"]) == indent:
		var next: Dictionary = _lines[_pos]
		var first: Dictionary = next["toks"][0]
		if _is_word(first, "elif"):
			_pos += 1
			_enter_line(next)
			_next()
			else_body = [_parse_if(next, indent)]
		elif _is_word(first, "else"):
			_pos += 1
			_enter_line(next)
			_next()
			if _is_word(_peek(), "if"):
				return _bad("else if 대신 elif 를 써요.")
			_expect_colon("else")
			if not _error.is_empty():
				return {}
			else_body = _parse_child_block(next, indent)
	return {"type": "if", "cond": cond, "text": _header_text(ln, word), "body": body, "else": else_body, "line": line}


func _parse_for(ln: Dictionary, indent: int) -> Dictionary:
	var line := _line
	_next()
	var vars: Array = []  # one name, or several to unpack: for x, y in points:
	while true:
		var v := _next()
		if v["t"] != "name" or v["v"] in KEYWORDS:
			return _bad("for 뒤에는 변수 이름이 와야 해요. 예: for i in range(3):")
		vars.append(v["v"])
		if not _is_op(_peek(), ","):
			break
		_next()
	if not _is_word(_next(), "in"):
		return _bad("for 문은 'for i in range(3):' 모양으로 적어요.")
	var iter := _parse_header_expr("for", false)
	if not _error.is_empty():
		return {}
	for name in vars:
		_note_assign(name)
	_loop_depth += 1
	var body := _parse_child_block(ln, indent)
	_loop_depth -= 1
	return {"type": "for", "vars": vars, "iter": iter, "body": body, "line": line}


func _parse_def(ln: Dictionary, indent: int) -> Dictionary:
	var line := _line
	_next()
	var nt := _next()
	if nt["t"] != "name" or nt["v"] in KEYWORDS:
		return _bad("def 뒤에는 함수 이름이 와야 해요. 예: def turn_around():")
	var fname: String = nt["v"]
	if _is_builtin_name(fname) or MODULES.has(fname):
		return _bad("'%s' 는 이미 있는 이름이라 새 함수 이름으로 쓸 수 없어요." % fname)
	if not _is_op(_next(), "("):
		return _bad("함수 이름 뒤에 괄호를 붙여 주세요. 예: def %s():" % fname)
	var params: Array = []
	if not _is_op(_peek(), ")"):
		while true:
			var p := _next()
			if p["t"] != "name" or p["v"] in KEYWORDS:
				return _bad("def 괄호 안에는 변수 이름만 적어요. 예: def walk(n):")
			if p["v"] in params:
				return _bad("같은 이름을 두 번 쓸 수 없어요: '%s'" % p["v"])
			params.append(p["v"])
			if _is_op(_peek(), ","):
				_next()
				continue
			break
	if not _is_op(_next(), ")"):
		return _bad("괄호 ')' 가 닫히지 않았어요.")
	_expect_colon("def")
	if not _error.is_empty():
		return {}
	var is_method := _in_class
	if is_method and params.is_empty():
		return _bad("메서드의 첫 번째 값은 self 예요. 예: def %s(self):" % fname)
	if not is_method:
		_defined[fname] = true
		_note_assign(fname)
	_func_stack.push_back({"assigned": {}, "globals": {}})
	var saved_loop := _loop_depth
	_loop_depth = 0
	_in_class = false
	var body := _parse_child_block(ln, indent)
	_in_class = is_method
	_loop_depth = saved_loop
	var scope: Dictionary = _func_stack.pop_back()
	var locals := {}
	for p in params:
		locals[p] = true
	for name in scope["assigned"]:
		if not scope["globals"].has(name):
			locals[name] = true
	return {"type": "def", "name": fname, "params": params, "body": body, "locals": locals, "line": line}


## try: / except [Name | (A, B)] [as e]: ... / finally:
func _parse_try(ln: Dictionary, indent: int) -> Dictionary:
	var line := _line
	_next()
	_expect_colon("try")
	if not _error.is_empty():
		return {}
	var body := _parse_child_block(ln, indent)
	var handlers: Array = []
	var final_body: Array = []
	var has_finally := false
	while _error.is_empty() and _pos < _lines.size() and int(_lines[_pos]["indent"]) == indent:
		var next: Dictionary = _lines[_pos]
		var first: Dictionary = next["toks"][0]
		if _is_word(first, "except"):
			_pos += 1
			_enter_line(next)
			_next()
			var names: Array = []
			var bind := ""
			if not _is_op(_peek(), ":"):
				var grouped := _is_op(_peek(), "(")
				if grouped:
					_next()
				while true:
					var nt := _next()
					if nt["t"] != "name" or not nt["v"] in EXCEPTIONS:
						return _bad("모르는 예외 이름이에요: '%s'  (쓸 수 있는 것: %s)" % [nt["v"], ", ".join(EXCEPTIONS)])
					names.append(nt["v"])
					if not (grouped and _is_op(_peek(), ",")):
						break
					_next()
				if grouped and not _is_op(_next(), ")"):
					return _bad("괄호 ')' 가 닫히지 않았어요.")
				if _is_word(_peek(), "as"):
					_next()
					var v := _next()
					if v["t"] != "name" or v["v"] in KEYWORDS:
						return _bad("as 뒤에는 변수 이름을 적어요. 예: except Blocked as e:")
					bind = v["v"]
					_note_assign(bind)
			_expect_colon("except")
			if not _error.is_empty():
				return {}
			var handler_body := _parse_child_block(next, indent)
			handlers.append({"names": names, "bind": bind, "body": handler_body, "line": int(next["line"])})
		elif _is_word(first, "finally"):
			_pos += 1
			_enter_line(next)
			_next()
			_expect_colon("finally")
			if not _error.is_empty():
				return {}
			final_body = _parse_child_block(next, indent)
			has_finally = true
			break
		else:
			break
	if _error.is_empty() and handlers.is_empty() and not has_finally:
		_fail(line, "try: 다음에는 같은 칸에 except 이름: 이 있어야 해요. 예: except Blocked:")
		return {}
	_features["try"] = true
	return {"type": "try", "body": body, "handlers": handlers, "finally": final_body, "line": line}


func _parse_class(ln: Dictionary, indent: int) -> Dictionary:
	var line := _line
	_next()
	var nt := _next()
	if nt["t"] != "name" or nt["v"] in KEYWORDS:
		return _bad("class 뒤에는 이름이 와야 해요. 예: class Walker:")
	var cname: String = nt["v"]
	if _is_builtin_name(cname) or MODULES.has(cname):
		return _bad("'%s' 는 이미 있는 이름이라 class 이름으로 쓸 수 없어요." % cname)
	if _in_class or not _func_stack.is_empty():
		return _bad("class 는 맨 바깥(들여쓰지 않은 곳)에서만 만들 수 있어요.")
	var base = null
	if _is_op(_peek(), "("):
		_next()
		if not _is_op(_peek(), ")"):
			base = _parse_expr()
			if not _error.is_empty():
				return {}
			_features["inherit"] = true
		if not _is_op(_next(), ")"):
			return _bad("괄호 ')' 가 닫히지 않았어요.")
	_expect_colon("class")
	if not _error.is_empty():
		return {}
	_features["class"] = true
	_defined[cname] = true
	_note_assign(cname)
	var saved_loop := _loop_depth
	_loop_depth = 0
	_in_class = true
	var body := _parse_child_block(ln, indent)
	_in_class = false
	_loop_depth = saved_loop
	if not _error.is_empty():
		return {}
	for st in body:
		var ok: bool = st["type"] in ["def", "pass"] or (st["type"] == "assign" and st["target"]["type"] == "name" and st["op"] == "=")
		if not ok:
			_fail(int(st["line"]), "class 안에는 메서드(def)와 '이름 = 값' 만 적을 수 있어요.")
			return {}
	return {"type": "class", "name": cname, "base": base, "body": body, "line": line}


func _parse_import() -> Dictionary:
	var line := _line
	_next()
	var names: Array = []
	while true:
		var t := _next()
		if t["t"] != "name":
			return _bad("import 뒤에는 모듈 이름을 적어요. 예: import math")
		if not MODULES.has(t["v"]):
			return _bad("가져올 수 있는 모듈은 math, random 이에요: '%s'" % t["v"])
		names.append(t["v"])
		_note_assign(t["v"])
		_features[t["v"]] = true
		if _is_op(_peek(), ","):
			_next()
			continue
		break
	_expect_end()
	return {"type": "import", "names": names, "line": line}


## Assignment or a call on its own line.
func _parse_simple() -> Dictionary:
	var line := _line
	var e := _parse_expr_list()
	if not _error.is_empty():
		return {}
	var t := _peek()
	if t["t"] == "op" and t["v"] in ASSIGN_OPS:
		var targets: Array = e["items"] if e["type"] == "tuple" else [e]
		if e["type"] == "tuple" and t["v"] != "=":
			return _bad("여러 변수에 한꺼번에 담을 때는 '=' 만 쓸 수 있어요.")
		for target in targets:
			var etype: String = target["type"]
			if etype == "name":
				var name: String = target["name"]
				if _is_builtin_name(name) or MODULES.has(name):
					return _bad("'%s' 는 이미 있는 이름이라 변수 이름으로 쓸 수 없어요." % name)
				_note_assign(name)
			elif etype != "index" and etype != "attr":
				return _bad("'%s' 왼쪽에는 변수 이름이 와야 해요." % t["v"])
		_next()
		if _at_end():
			return _bad("'%s' 오른쪽에 값을 적어 주세요." % t["v"])
		var value := _parse_expr_list()
		_expect_end()
		return {"type": "assign", "target": e, "op": t["v"], "value": value, "line": line}
	_expect_end()
	if not _error.is_empty():
		return {}
	if e["type"] == "name":
		var name: String = e["name"]
		if _is_builtin_name(name) or _defined.has(name):
			return _bad("괄호를 붙여 주세요: %s()" % name)
		return _bad("'%s' 만 적혀 있어요. 명령이면 괄호를 붙이고, 변수면 '=' 로 값을 넣어요." % name)
	if e["type"] != "call":
		return _bad("계산만 하고 쓰지 않는 줄이에요. 변수에 담거나 print() 로 보여 주세요.")
	var fn: Dictionary = e["fn"]
	if fn["type"] == "name":
		if fn["name"] in CONDITIONS:
			return _bad("'%s()'는 조건이에요. if 나 while 뒤에 써야 해요." % fn["name"])
		if fn["name"] in SENSORS:
			return _bad("'%s()'는 값을 알려 주는 함수예요. 변수에 담거나 print() 로 보여 주세요." % fn["name"])
	return {"type": "expr", "expr": e, "line": line}


# --- Expressions (Python precedence) ----------------------------------------

func _parse_expr() -> Dictionary:
	return _parse_or()


## An expression, or several separated by commas, which make a tuple: `1, 2` / `x, y`.
func _parse_expr_list() -> Dictionary:
	var first := _parse_expr()
	if not _error.is_empty() or not _is_op(_peek(), ","):
		return first
	var items: Array = [first]
	while _error.is_empty() and _is_op(_peek(), ","):
		_next()
		if _at_end() or (_peek()["t"] == "op" and _peek()["v"] in ASSIGN_OPS):
			break
		items.append(_parse_expr())
	return {"type": "tuple", "items": items}


func _parse_or() -> Dictionary:
	var left := _parse_and()
	while _error.is_empty() and _is_word(_peek(), "or"):
		_next()
		left = {"type": "or", "a": left, "b": _parse_and()}
	return left


func _parse_and() -> Dictionary:
	var left := _parse_not()
	while _error.is_empty() and _is_word(_peek(), "and"):
		_next()
		left = {"type": "and", "a": left, "b": _parse_not()}
	return left


func _parse_not() -> Dictionary:
	if _is_word(_peek(), "not"):
		_next()
		return {"type": "not", "e": _parse_not()}
	return _parse_cmp()


func _parse_cmp() -> Dictionary:
	var first := _parse_bitor()
	var ops: Array = []
	var items: Array = [first]
	while _error.is_empty():
		var t := _peek()
		var op := ""
		if t["t"] == "op" and t["v"] in ["==", "!=", "<", ">", "<=", ">="]:
			op = t["v"]
			_next()
		elif _is_word(t, "in"):
			op = "in"
			_next()
		elif _is_word(t, "not") and _is_word(_peek(1), "in"):
			op = "not in"
			_next()
			_next()
		elif _is_word(t, "is"):
			_next()
			op = "is"
			if _is_word(_peek(), "not"):
				_next()
				op = "is not"
		else:
			break
		ops.append(op)
		items.append(_parse_bitor())
	if ops.is_empty():
		return first
	return {"type": "cmp", "ops": ops, "items": items}


## a | b (set union, or bitwise or on integers).
func _parse_bitor() -> Dictionary:
	var left := _parse_bitand()
	while _error.is_empty() and _is_op(_peek(), "|"):
		_next()
		left = {"type": "bin", "op": "|", "a": left, "b": _parse_bitand()}
	return left


## a & b (set intersection, or bitwise and on integers).
func _parse_bitand() -> Dictionary:
	var left := _parse_add()
	while _error.is_empty() and _is_op(_peek(), "&"):
		_next()
		left = {"type": "bin", "op": "&", "a": left, "b": _parse_add()}
	return left


func _parse_add() -> Dictionary:
	var left := _parse_mul()
	while _error.is_empty() and (_is_op(_peek(), "+") or _is_op(_peek(), "-")):
		var op: String = _next()["v"]
		left = {"type": "bin", "op": op, "a": left, "b": _parse_mul()}
	return left


func _parse_mul() -> Dictionary:
	var left := _parse_unary()
	while _error.is_empty():
		var t := _peek()
		if not (t["t"] == "op" and t["v"] in ["*", "/", "//", "%"]):
			break
		_next()
		left = {"type": "bin", "op": t["v"], "a": left, "b": _parse_unary()}
	return left


func _parse_unary() -> Dictionary:
	if _is_op(_peek(), "-"):
		_next()
		return {"type": "neg", "e": _parse_unary()}
	if _is_op(_peek(), "+"):
		_next()
		return _parse_unary()
	return _parse_power()


func _parse_power() -> Dictionary:
	var base := _parse_postfix()
	if _error.is_empty() and _is_op(_peek(), "**"):
		_next()
		return {"type": "bin", "op": "**", "a": base, "b": _parse_unary()}
	return base


func _parse_postfix() -> Dictionary:
	var e := _parse_atom()
	while _error.is_empty():
		var t := _peek()
		if _is_op(t, "("):
			_next()
			var args: Array = []
			if not _is_op(_peek(), ")"):
				while _error.is_empty():
					args.append(_parse_expr())
					if _is_op(_peek(), ","):
						_next()
						continue
					break
			if not _error.is_empty():
				return {}
			if not _is_op(_next(), ")"):
				return _bad("괄호 ')' 가 닫히지 않았어요.")
			if e["type"] == "name":
				_calls.append({"name": e["name"], "line": _line, "cond": _in_cond})
			e = {"type": "call", "fn": e, "args": args}
		elif _is_op(t, "."):
			_next()
			var nt := _next()
			if nt["t"] != "name":
				return _bad("'.' 뒤에는 이름이 와야 해요. 예: math.sqrt(9)")
			if nt["v"] in _banned:
				return _bad("이 레벨에서는 '%s()' 를 쓸 수 없어요." % nt["v"])
			e = {"type": "attr", "obj": e, "name": nt["v"]}
		elif _is_op(t, "["):
			_next()
			# a[i], or a slice a[start:stop:step] where every part may be left out.
			var bounds: Array = [null, null, null]
			var colons := 0
			while _error.is_empty():
				if _is_op(_peek(), "]"):
					break
				if _is_op(_peek(), ":"):
					_next()
					colons += 1
					if colons > 2:
						return _bad("[ ] 안의 ':' 는 두 개까지예요. 예: s[::-1]")
					continue
				if bounds[colons] != null:
					return _bad("대괄호 ']' 가 닫히지 않았어요.")
				bounds[colons] = _parse_expr()
			if not _error.is_empty():
				return {}
			if not _is_op(_next(), "]"):
				return _bad("대괄호 ']' 가 닫히지 않았어요.")
			if colons == 0:
				if bounds[0] == null:
					return _bad("[ ] 안에 번호를 적어 주세요. 예: s[0]")
				e = {"type": "index", "obj": e, "idx": bounds[0]}
			else:
				e = {"type": "slice", "obj": e, "start": bounds[0], "stop": bounds[1], "step": bounds[2]}
		else:
			break
	return e


## Parses `text` as one expression (the {...} parts of an f-string) without losing our place.
func _parse_sub_expr(text: String) -> Dictionary:
	var saved_toks := _toks
	var saved_tp := _tp
	var toks := _tokenize(text)
	if not _error.is_empty():
		return {}
	_toks = toks
	_tp = 0
	var e := _parse_expr()
	if _error.is_empty() and not _at_end():
		_fail(_line, "f-문자열의 { } 안을 이해할 수 없어요: {%s}" % text)
	_toks = saved_toks
	_tp = saved_tp
	return e


## Comma-separated expressions up to (not including) `close`; a trailing comma is allowed.
## Sets _last_items_had_comma so "(x)" and "(x,)" can be told apart.
func _parse_items(close: String) -> Array:
	var items: Array = []
	var had_comma := false
	while _error.is_empty() and not _is_op(_peek(), close):
		items.append(_parse_expr())
		if not _is_op(_peek(), ","):
			break
		_next()
		had_comma = true
	_last_items_had_comma = had_comma  # set after the nested parses above, which also use it
	return items


func _parse_atom() -> Dictionary:
	if not _error.is_empty():
		return {}
	var t := _next()
	match String(t["t"]):
		"num", "str":
			return {"type": "const", "v": t["v"]}
		"fstr":
			var parts: Array = []
			for part in t["v"]:
				if part is String:
					parts.append(part)
				else:
					var sub := _parse_sub_expr(part["src"])
					if not _error.is_empty():
						return {}
					parts.append({"expr": sub, "spec": part["spec"]})
			return {"type": "fstr", "parts": parts}
		"name":
			var n: String = t["v"]
			match n:
				"True":
					return {"type": "const", "v": true}
				"False":
					return {"type": "const", "v": false}
				"None":
					return {"type": "const", "v": null}
			if n in KEYWORDS:
				return _bad("'%s' 가 올 자리가 아니에요: %s" % [n, _cur_text])
			if n in _banned:
				return _bad("이 레벨에서는 '%s()' 를 쓸 수 없어요." % n)
			return {"type": "name", "name": n}
		"op":
			if t["v"] == "(":
				# (x) is just x; (x, y), (x,) and () are tuples.
				var items := _parse_items(")")
				if not _error.is_empty():
					return {}
				if not _is_op(_next(), ")"):
					return _bad("괄호 ')' 가 닫히지 않았어요.")
				if items.size() == 1 and not _last_items_had_comma:
					return items[0]
				return {"type": "tuple", "items": items}
			if t["v"] == "[":
				var items := _parse_items("]")
				if not _error.is_empty():
					return {}
				if not _is_op(_next(), "]"):
					return _bad("대괄호 ']' 가 닫히지 않았어요.")
				return {"type": "list", "items": items}
			if t["v"] == "{":
				# {} and {k: v, ...} are dicts; {a, b, ...} is a set.
				var keys: Array = []
				var values: Array = []
				var is_set := false
				while _error.is_empty() and not _is_op(_peek(), "}"):
					keys.append(_parse_expr())
					if keys.size() == 1 and not _is_op(_peek(), ":"):
						is_set = true
					if is_set:
						if _is_op(_peek(), ":"):
							return _bad("집합 {a, b} 과 딕셔너리 {키: 값} 을 섞어 쓸 수 없어요.")
					else:
						if not _is_op(_next(), ":"):
							return _bad("딕셔너리는 {\"키\": 값} 모양으로 적어요. 키 뒤에 ':' 가 필요해요.")
						values.append(_parse_expr())
					if not _is_op(_peek(), ","):
						break
					_next()
				if not _error.is_empty():
					return {}
				if not _is_op(_next(), "}"):
					return _bad("중괄호 '}' 가 닫히지 않았어요.")
				if is_set:
					_features["set"] = true
					return {"type": "set", "items": keys}
				_features["dict"] = true
				return {"type": "dict", "keys": keys, "values": values}
		"end":
			return _bad("줄이 덜 끝났어요. 값을 더 적어 주세요: %s" % _cur_text)
	return _bad("이해할 수 없는 줄이에요: %s" % _cur_text)


# =========================================================================
# Running
# =========================================================================

## Runs a parsed program. Returns {"ok": true} or
## {"ok": false, "line": int, "message": String} or {"ok": false, "stopped": true}.
## `rng_seed` makes the random module repeatable for the same run.
func run(program: Array, host, rng_seed: int = 0) -> Dictionary:
	_host = host
	_err = {}
	_steps = 0
	_depth = 0
	_globals = {}
	_frames = []
	_ret = null
	_rng.seed = rng_seed
	await _exec_block(program)
	if not _err.is_empty():
		return _err
	return {"ok": true}


## Records a runtime error. `etype` is the exception name try/except matches against;
## "Fatal" errors (endless loops, runaway recursion) cannot be caught.
func _raise(message: String, etype: String = "TypeError") -> void:
	if _err.is_empty():
		_err = {"ok": false, "line": _line, "message": message, "etype": etype}


func _stop() -> void:
	if _err.is_empty():
		_err = {"ok": false, "stopped": true}


func _tick() -> bool:
	if _host.is_stop_requested():
		_stop()
		return false
	_steps += 1
	if _steps > MAX_STEPS:
		_raise("실행이 너무 길어요. 끝나지 않는 반복인지 확인해 보세요.", "Fatal")
		return false
	return true


func _exec_block(body: Array) -> int:
	for node in body:
		var f: int = await _exec(node)
		if f != Flow.NORMAL:
			return f
	return Flow.NORMAL


func _exec(node: Dictionary) -> int:
	_line = int(node["line"])
	if not _tick():
		return Flow.ERROR
	match String(node["type"]):
		"expr":
			await _eval(node["expr"])
		"assign":
			_host.highlight_line(_line)
			var v = await _eval(node["value"])
			if not _err.is_empty():
				return Flow.ERROR
			var op: String = node["op"]
			if op != "=":
				var cur = await _eval(node["target"])
				if not _err.is_empty():
					return Flow.ERROR
				v = _binop(op.trim_suffix("="), cur, v)
				if not _err.is_empty():
					return Flow.ERROR
			await _store(node["target"], v)
			if not _err.is_empty():
				return Flow.ERROR
			var target: Dictionary = node["target"]
			var shown := "값"
			if target["type"] == "name":
				shown = target["name"]
			elif target["type"] == "tuple":
				shown = ", ".join(PackedStringArray(target["items"].map(func(t: Dictionary) -> String: return t.get("name", "값"))))
			await _host.show_step(_line, "%s = %s" % [shown, _repr(v)], null)
			if _host.is_stop_requested():
				_stop()
		"if":
			_host.highlight_line(_line)
			var taken: bool = await _cond(node)
			if not _err.is_empty():
				return Flow.ERROR
			return await _exec_block(node["body"] if taken else node["else"])
		"while":
			while true:
				_line = int(node["line"])
				_host.highlight_line(_line)
				var go: bool = await _cond(node)
				if not _err.is_empty():
					return Flow.ERROR
				if not go:
					break
				var f: int = await _exec_block(node["body"])
				if f == Flow.BREAK:
					break
				if f == Flow.ERROR or f == Flow.RETURN:
					return f
				_line = int(node["line"])
				if not _tick():
					return Flow.ERROR
		"for":
			_host.highlight_line(_line)
			var it = await _eval(node["iter"])
			if not _err.is_empty():
				return Flow.ERROR
			var seq = _iter(it, "for 문의 'in' 뒤")
			if seq == null:
				return Flow.ERROR
			var vars: Array = node["vars"]
			for item in seq:
				_line = int(node["line"])
				if vars.size() == 1:
					_set_var(vars[0], item)
				else:
					var parts = _unpack(item, vars.size())
					if parts == null:
						return Flow.ERROR
					for k in vars.size():
						_set_var(vars[k], parts[k])
				var f: int = await _exec_block(node["body"])
				if f == Flow.BREAK:
					break
				if f == Flow.ERROR or f == Flow.RETURN:
					return f
				_line = int(node["line"])
				if not _tick():
					return Flow.ERROR
		"repeat":
			_host.highlight_line(_line)
			var n = await _eval(node["count"])
			if not _err.is_empty():
				return Flow.ERROR
			if typeof(n) != TYPE_INT:
				_raise("repeat 뒤에는 정수가 와야 해요 (지금: %s). 나눗셈은 // 를 쓰면 정수가 돼요." % _repr(n))
				return Flow.ERROR
			for i in int(n):
				var f: int = await _exec_block(node["body"])
				if f == Flow.BREAK:
					break
				if f == Flow.ERROR or f == Flow.RETURN:
					return f
				_line = int(node["line"])
				if not _tick():
					return Flow.ERROR
		"def":
			_set_var(node["name"], {"kind": "func", "node": node})
		"return":
			_ret = null
			if node["value"] != null:
				_ret = await _eval(node["value"])
				if not _err.is_empty():
					return Flow.ERROR
			return Flow.RETURN
		"break":
			return Flow.BREAK
		"continue":
			return Flow.CONTINUE
		"import":
			for m in node["names"]:
				_set_var(m, {"kind": "module", "name": m})
		"del":
			for tgt in node["targets"]:
				var obj = await _eval(tgt["obj"])
				var idx = await _eval(tgt["idx"])
				if not _err.is_empty():
					return Flow.ERROR
				if obj is Array:
					var i := _index_of(obj, idx)
					if _err.is_empty():
						(obj as Array).remove_at(i)
				elif _is_kind(obj, "dict"):
					var k := _key(idx)
					if _err.is_empty() and not obj["data"].has(k):
						_raise("딕셔너리에 %s 키가 없어요." % _repr(idx), "KeyError")
					elif _err.is_empty():
						obj["data"].erase(k)
				else:
					_raise("del 로 지울 수 있는 건 목록이나 딕셔너리의 한 칸이에요.")
				if not _err.is_empty():
					return Flow.ERROR
		"try":
			var f: int = await _exec_block(node["body"])
			if f == Flow.ERROR and _catchable():
				var etype: String = _err.get("etype", "TypeError")
				for h in node["handlers"]:
					var names: Array = h["names"]
					if names.is_empty() or "Exception" in names or etype in names:
						var message: String = _err.get("message", "")
						_err = {}
						_line = int(h["line"])
						_host.highlight_line(_line)
						if h["bind"] != "":
							_set_var(h["bind"], message)
						f = await _exec_block(h["body"])
						break
			if not (node["finally"] as Array).is_empty() and not _err.get("stopped", false):
				var saved := _err
				_err = {}
				var ff: int = await _exec_block(node["finally"])
				if ff != Flow.NORMAL:
					return ff
				_err = saved
			return f
		"class":
			var base = null
			if node["base"] != null:
				base = await _eval(node["base"])
				if not _err.is_empty():
					return Flow.ERROR
				if not (base is Dictionary and base.get("kind") == "class"):
					_raise("class 이름 뒤 괄호 안에는 먼저 만든 다른 class 이름을 적어요.")
					return Flow.ERROR
			var cls := {"kind": "class", "name": node["name"], "base": base, "methods": {}, "attrs": {}}
			for st in node["body"]:
				match String(st["type"]):
					"def":
						cls["methods"][st["name"]] = st
					"assign":
						_line = int(st["line"])
						var v = await _eval(st["value"])
						if not _err.is_empty():
							return Flow.ERROR
						cls["attrs"][st["target"]["name"]] = v
			_set_var(node["name"], cls)
	return Flow.ERROR if not _err.is_empty() else Flow.NORMAL


## Evaluates an if/while condition and lets the host show it (step mode).
func _cond(node: Dictionary) -> bool:
	var v = await _eval(node["cond"])
	if not _err.is_empty():
		return false
	var b := _truthy(v)
	await _host.show_step(_line, String(node["text"]), b)
	if _host.is_stop_requested():
		_stop()
	return b


# --- Variables --------------------------------------------------------------

func _set_var(name: String, v: Variant) -> void:
	if not _frames.is_empty():
		var fr: Dictionary = _frames.back()
		if fr["fn"]["locals"].has(name):
			fr["vars"][name] = v
			return
	_globals[name] = v


func _get_var(name: String) -> Variant:
	if not _frames.is_empty():
		var fr: Dictionary = _frames.back()
		if fr["vars"].has(name):
			return fr["vars"][name]
		if fr["fn"]["locals"].has(name):
			_raise("'%s' 에 값을 넣기 전에 읽었어요. 함수 밖의 변수를 바꾸려면 함수 첫 줄에 global %s 를 적어 주세요." % [name, name])
			return null
	if _globals.has(name):
		return _globals[name]
	if _is_builtin_name(name):
		return {"kind": "builtin", "name": name}
	if MODULES.has(name):
		_raise("'%s' 를 쓰려면 먼저 맨 위에 import %s 를 적어 주세요." % [name, name])
	elif _defined.has(name):
		_raise("'%s' 함수가 아직 만들어지지 않았어요. def 를 부르는 줄보다 위에 적어 주세요." % name)
	else:
		var known: Array = _globals.keys()
		if not _frames.is_empty():
			known.append_array(_frames.back()["vars"].keys())
		_raise("아직 만들지 않은 변수예요: '%s'%s" % [name, _suggest(name, known)], "NameError")
	return null


func _store(target: Dictionary, v: Variant) -> void:
	if target["type"] == "name":
		_set_var(target["name"], v)
		return
	if target["type"] == "tuple":
		var targets: Array = target["items"]
		var parts = _unpack(v, targets.size())
		if parts == null:
			return
		for k in targets.size():
			await _store(targets[k], parts[k])
			if not _err.is_empty():
				return
		return
	if target["type"] == "attr":
		var owner = await _eval(target["obj"])
		if not _err.is_empty():
			return
		var kind: String = owner.get("kind", "") if owner is Dictionary else ""
		if kind == "instance":
			owner["fields"][target["name"]] = v
		elif kind == "class":
			owner["attrs"][target["name"]] = v
		else:
			_raise("'.%s' 에 값을 넣을 수 있는 건 class 로 만든 객체뿐이에요." % target["name"])
		return
	var obj = await _eval(target["obj"])
	var idx = await _eval(target["idx"])
	if not _err.is_empty():
		return
	if _is_kind(obj, "dict"):
		_dict_set(obj, idx, v)
		return
	if _is_kind(obj, "tuple"):
		_raise("튜플은 만든 뒤에 바꿀 수 없어요. 새 튜플을 만들어 주세요. 예: pos = (x, y)")
		return
	if not obj is Array:
		_raise("[ ] 로 값을 바꿀 수 있는 건 목록과 딕셔너리예요.")
		return
	var i := _index_of(obj, idx)
	if _err.is_empty():
		obj[i] = v


# --- Tuples and dictionaries --------------------------------------------------
# A tuple is {"kind": "tuple", "items": Array}. A dict is {"kind": "dict", "data": {key: [k, v]}}
# where key is _key(k), so 1 and 1.0 are the same key and tuples work as keys, like Python.

static func _is_kind(v: Variant, kind: String) -> bool:
	return v is Dictionary and v.get("kind") == kind


static func _tuple(items: Array) -> Dictionary:
	return {"kind": "tuple", "items": items}


static func _new_dict() -> Dictionary:
	return {"kind": "dict", "data": {}}


## A hashable value's dictionary key. Lists and dicts cannot be keys.
func _key(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "n"
		TYPE_BOOL, TYPE_INT:
			return "i%d" % int(v)
		TYPE_FLOAT:
			return "i%d" % int(v) if v == floorf(v) and absf(v) < 1e15 else "f%s" % str(v)
		TYPE_STRING:
			return "s" + String(v)
	if _is_kind(v, "tuple"):
		var parts: PackedStringArray = []
		for item in v["items"]:
			parts.append(_key(item))
		return "t(" + ",".join(parts) + ")"
	if v is Dictionary and v.get("kind") in ["func", "builtin", "class", "robot"]:
		return "o%d" % v.get_instance_id() if v.get("kind") != "robot" else "r%d" % v["index"]
	_raise("%s 은(는) 딕셔너리의 키로 쓸 수 없어요. 글자, 숫자, 튜플을 키로 써요." % _type_name(v))
	return ""


func _dict_set(d: Dictionary, k: Variant, v: Variant) -> void:
	var key := _key(k)
	if _err.is_empty():
		d["data"][key] = [k, v]


func _dict_keys(d: Dictionary) -> Array:
	return d["data"].values().map(func(pair: Array) -> Variant: return pair[0])


## The values in a list, tuple, string or dict (its keys), or null with an error.
func _iter(v: Variant, where: String = "") -> Variant:
	if v is Array:
		return (v as Array).duplicate()
	if v is String:
		var chars: Array = []
		for ch in String(v):
			chars.append(ch)
		return chars
	if _is_kind(v, "tuple"):
		return (v["items"] as Array).duplicate()
	if _is_kind(v, "dict"):
		return _dict_keys(v)
	if _is_kind(v, "set"):
		return (v["data"] as Dictionary).values()
	var place := where + "에는" if where != "" else "여기에는"
	_raise("%s 목록, 튜플, 글자, 딕셔너리처럼 하나씩 꺼낼 수 있는 값이 와야 해요 (지금: %s)." % [place, _repr(v)])
	return null


## Splits a sequence into exactly `count` values for `a, b = ...` and `for a, b in ...`.
func _unpack(v: Variant, count: int) -> Variant:
	var items = _iter(v, "여러 변수에 나눠 담을 값")
	if items == null:
		return null
	if items.size() != count:
		_raise("값 %d개를 변수 %d개에 나눠 담을 수 없어요: %s" % [items.size(), count, _repr(v)], "ValueError")
		return null
	return items


func _catchable() -> bool:
	return not _err.is_empty() and not _err.get("stopped", false) and _err.get("etype") != "Fatal"


# --- Sets -----------------------------------------------------------------------
# A set is {"kind": "set", "data": {key: value}} with keys from _key(), like dict keys.

static func _new_set() -> Dictionary:
	return {"kind": "set", "data": {}}


func _set_add(st: Dictionary, v: Variant) -> void:
	var k := _key(v)
	if _err.is_empty():
		st["data"][k] = v


func _set_from(items: Array) -> Variant:
	var st := _new_set()
	for v in items:
		_set_add(st, v)
		if not _err.is_empty():
			return null
	return st


## f-string format spec: "" (plain), "d", ".2f" and the like.
func _format_spec(v: Variant, spec: String) -> Variant:
	if spec == "":
		return _str(v)
	if spec == "d" and typeof(v) == TYPE_INT:
		return str(v)
	if spec.begins_with(".") and spec.ends_with("f") and spec.substr(1, spec.length() - 2).is_valid_int() and _is_num(v):
		return ("%." + spec.substr(1, spec.length() - 2) + "f") % float(v)
	_raise("f-문자열의 형식 '{값:%s}' 은 아직 못 써요. {값:.2f} 처럼 소수 자리만 정할 수 있어요." % spec, "ValueError")
	return null


## Python slicing for lists, tuples and strings: s[start:stop:step], any part may be None.
func _slice(obj: Variant, start: Variant, stop: Variant, step: Variant) -> Variant:
	var seq = obj["items"] if _is_kind(obj, "tuple") else obj
	if not (seq is Array or seq is String):
		_raise("[ : ] 로 자를 수 있는 건 목록, 튜플, 글자예요.")
		return null
	for b in [start, stop, step]:
		if b != null and typeof(b) != TYPE_INT:
			_raise("[ : ] 안에는 정수를 적어요 (지금: %s)." % _repr(b))
			return null
	var n: int = seq.size() if seq is Array else String(seq).length()
	var st: int = 1 if step == null else step
	if st == 0:
		_raise("자르는 간격은 0이 될 수 없어요.", "ValueError")
		return null
	var lo: int
	var hi: int
	if st > 0:
		lo = 0 if start == null else (start + n if start < 0 else start)
		hi = n if stop == null else (stop + n if stop < 0 else stop)
		lo = clampi(lo, 0, n)
		hi = clampi(hi, 0, n)
	else:
		lo = n - 1 if start == null else (start + n if start < 0 else start)
		hi = -1 if stop == null else (stop + n if stop < 0 else stop)
		lo = clampi(lo, -1, n - 1)
		hi = clampi(hi, -1, n - 1)
	var picked: Array = []
	var i := lo
	while (st > 0 and i < hi) or (st < 0 and i > hi):
		picked.append(seq[i])
		i += st
	if seq is String:
		return "".join(PackedStringArray(picked))
	return _tuple(picked) if _is_kind(obj, "tuple") else picked


# --- Expressions ------------------------------------------------------------

func _eval(e: Dictionary) -> Variant:
	if not _err.is_empty():
		return null
	match String(e["type"]):
		"const":
			return e["v"]
		"name":
			return _get_var(e["name"])
		"list", "tuple":
			var out: Array = []
			for item in e["items"]:
				var v = await _eval(item)
				if not _err.is_empty():
					return null
				out.append(v)
			return out if e["type"] == "list" else _tuple(out)
		"dict":
			var d := _new_dict()
			for k in e["keys"].size():
				var key = await _eval(e["keys"][k])
				var val = await _eval(e["values"][k])
				if not _err.is_empty():
					return null
				_dict_set(d, key, val)
				if not _err.is_empty():
					return null
			return d
		"fstr":
			var out := ""
			for part in e["parts"]:
				if part is String:
					out += part
					continue
				var v = await _eval(part["expr"])
				if not _err.is_empty():
					return null
				var text = _format_spec(v, part["spec"])
				if text == null:
					return null
				out += text
			return out
		"slice":
			var obj = await _eval(e["obj"])
			var bounds: Array = []
			for key in ["start", "stop", "step"]:
				bounds.append(null if e[key] == null else await _eval(e[key]))
			if not _err.is_empty():
				return null
			return _slice(obj, bounds[0], bounds[1], bounds[2])
		"set":
			var st := _new_set()
			for item in e["items"]:
				var v = await _eval(item)
				if not _err.is_empty():
					return null
				_set_add(st, v)
				if not _err.is_empty():
					return null
			return st
		"neg":
			var v = await _eval(e["e"])
			if not _err.is_empty():
				return null
			if not _is_num(v):
				_raise("'-' 는 숫자 앞에만 붙일 수 있어요.")
				return null
			return -_num(v)
		"not":
			var v = await _eval(e["e"])
			return not _truthy(v)
		"and":
			var a = await _eval(e["a"])
			if not _err.is_empty() or not _truthy(a):
				return a
			return await _eval(e["b"])
		"or":
			var a = await _eval(e["a"])
			if not _err.is_empty() or _truthy(a):
				return a
			return await _eval(e["b"])
		"bin":
			var a = await _eval(e["a"])
			var b = await _eval(e["b"])
			if not _err.is_empty():
				return null
			return _binop(e["op"], a, b)
		"cmp":
			var items: Array = e["items"]
			var ops: Array = e["ops"]
			var left = await _eval(items[0])
			for i in ops.size():
				var right = await _eval(items[i + 1])
				if not _err.is_empty():
					return null
				if not _compare(ops[i], left, right):
					return false
				left = right
			return true
		"attr":
			var obj = await _eval(e["obj"])
			if not _err.is_empty():
				return null
			return _attr(obj, e["name"])
		"index":
			var obj = await _eval(e["obj"])
			var idx = await _eval(e["idx"])
			if not _err.is_empty():
				return null
			if _is_kind(obj, "dict"):
				var k := _key(idx)
				if not _err.is_empty():
					return null
				if not obj["data"].has(k):
					_raise("딕셔너리에 %s 키가 없어요. 없을 수도 있는 키는 .get(키, 기본값) 으로 꺼내요." % _repr(idx), "KeyError")
					return null
				return obj["data"][k][1]
			if _is_kind(obj, "tuple"):
				obj = obj["items"]
			if not (obj is Array or obj is String):
				_raise("[ ] 는 목록, 튜플, 글자, 딕셔너리에만 쓸 수 있어요.")
				return null
			var i := _index_of(obj, idx)
			return null if not _err.is_empty() else obj[i]
		"call":
			var fn = await _eval(e["fn"])
			if not _err.is_empty():
				return null
			var args: Array = []
			for a in e["args"]:
				var v = await _eval(a)
				if not _err.is_empty():
					return null
				args.append(v)
			return await _call(fn, args)
	return null


func _call(fn: Variant, args: Array) -> Variant:
	if not (fn is Dictionary and (fn as Dictionary).has("kind")):
		_raise("부를 수 있는 함수가 아니에요: %s" % _repr(fn))
		return null
	match String(fn["kind"]):
		"builtin":
			return await _call_builtin(fn["name"], args)
		"modfn":
			return _call_module(fn["mod"], fn["name"], args)
		"method":
			return _call_method(fn["obj"], fn["name"], args)
		"func":
			return await _call_func(fn["node"], args, fn.get("cls"))
		"bound":
			return await _call_func(fn["fn"], [fn["self"]] + args, fn["cls"])
		"class":
			return await _instantiate(fn, args)
		"robotfn":
			return await _robot_call(fn["name"], int(fn["index"]), args)
	_raise("부를 수 있는 함수가 아니에요: %s" % _repr(fn))
	return null


## Calls robot `index`'s command or sensor.
func _robot_call(name: String, index: int, args: Array) -> Variant:
	var need: int = COMMAND_ARGS.get(name, 0)
	if not _need_args(name, args, need):
		return null
	if name in COMMANDS:
		var host_args: Array = args.map(func(a: Variant) -> Variant: return _to_host(a))
		var message: String = await _host.run_command(name, _line, index, host_args)
		if _host.is_stop_requested():
			_stop()
			return null
		if message != "":
			_raise(message, COMMAND_ERRORS.get(name, "RobotError"))
		return null
	return _from_host(_host.sense(name, index))


## Host values -> language values: Vector2i is an (x, y) tuple, a plain Dictionary a dict.
func _from_host(v: Variant) -> Variant:
	if v is Vector2i:
		return _tuple([v.x, v.y])
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _from_host(x))
	if v is Dictionary and not v.has("kind"):
		var d := _new_dict()
		for k in v:
			_dict_set(d, _from_host(k), _from_host(v[k]))
		return d
	return v


## Language values -> plain values for the host: tuples become Arrays, dicts plain Dictionaries.
func _to_host(v: Variant) -> Variant:
	if _is_kind(v, "tuple"):
		return (v["items"] as Array).map(func(x: Variant) -> Variant: return _to_host(x))
	if _is_kind(v, "set"):
		return (v["data"] as Dictionary).values().map(func(x: Variant) -> Variant: return _to_host(x))
	if _is_kind(v, "dict"):
		var out := {}
		for pair in v["data"].values():
			out[_to_host(pair[0])] = _to_host(pair[1])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _to_host(x))
	return v


static func _find_method(cls: Variant, name: String) -> Dictionary:
	var c = cls
	while c != null:
		if c["methods"].has(name):
			return {"node": c["methods"][name], "cls": c}
		c = c["base"]
	return {}


static func _find_class_attr(cls: Variant, name: String) -> Dictionary:
	var c = cls
	while c != null:
		if c["attrs"].has(name):
			return {"value": c["attrs"][name]}
		c = c["base"]
	return {}


func _instantiate(cls: Dictionary, args: Array) -> Variant:
	var inst := {"kind": "instance", "cls": cls, "fields": {}}
	var init := _find_method(cls, "__init__")
	if init.is_empty():
		if not args.is_empty():
			_raise("'%s' 에는 __init__ 메서드가 없어서 괄호 안에 값을 넣을 수 없어요." % cls["name"])
			return null
		return inst
	await _call_func(init["node"], [inst] + args, init["cls"])
	return null if not _err.is_empty() else inst


## `owner` is the class that defines the method (null for plain functions); it makes super() work.
func _call_func(node: Dictionary, args: Array, owner: Variant = null) -> Variant:
	var params: Array = node["params"]
	if args.size() != params.size():
		if owner != null:
			_raise("'%s' 메서드에는 self 말고 값 %d개를 넣어야 해요 (지금 %d개)." % [node["name"], params.size() - 1, args.size() - 1])
		else:
			_raise("'%s' 함수에는 값 %d개를 넣어야 해요 (지금 %d개)." % [node["name"], params.size(), args.size()])
		return null
	if _depth >= MAX_DEPTH:
		_raise("함수가 너무 깊이 불렸어요. 자기 자신을 끝없이 부르고 있지 않은지 확인해 보세요.", "Fatal")
		return null
	var vars := {}
	for i in params.size():
		vars[params[i]] = args[i]
	var call_line := _line
	var self_obj = args[0] if owner != null and not args.is_empty() else null
	_frames.push_back({"vars": vars, "fn": node, "cls": owner, "self": self_obj})
	_depth += 1
	var f: int = await _exec_block(node["body"])
	_depth -= 1
	_frames.pop_back()
	if f == Flow.ERROR:
		return null
	_line = call_line
	var result = _ret if f == Flow.RETURN else null
	_ret = null
	return result


func _need_args(name: String, args: Array, lo: int, hi: int = -1) -> bool:
	if hi < 0:
		hi = lo
	if args.size() < lo or args.size() > hi:
		if lo == 0 and hi == 0:
			_raise("'%s()' 괄호 안에는 아무것도 넣지 않아요." % name)
		elif lo == hi:
			_raise("'%s()' 에는 값 %d개를 넣어요 (지금 %d개)." % [name, lo, args.size()])
		else:
			_raise("'%s()' 에는 값 %d~%d개를 넣어요 (지금 %d개)." % [name, lo, hi, args.size()])
		return false
	return true


func _need_num(name: String, v: Variant) -> bool:
	if not _is_num(v):
		_raise("'%s()' 에는 숫자를 넣어요 (지금: %s)." % [name, _repr(v)])
		return false
	return true


func _need_int(name: String, v: Variant) -> bool:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_BOOL:
		_raise("'%s()' 에는 정수를 넣어요 (지금: %s)." % [name, _repr(v)])
		return false
	return true


func _call_builtin(name: String, args: Array) -> Variant:
	if name in COMMANDS or name in CONDITIONS or name in SENSORS:
		return await _robot_call(name, 0, args)
	match name:
		"robots":
			if not _need_args(name, args, 0):
				return null
			var out: Array = []
			for i in int(_host.robot_count()):
				out.append({"kind": "robot", "index": i})
			return out
		"super":
			if not _need_args(name, args, 0):
				return null
			var fr: Dictionary = {} if _frames.is_empty() else _frames.back()
			if fr.get("cls") == null:
				_raise("super() 는 class 의 메서드 안에서만 써요.")
				return null
			if fr["cls"]["base"] == null:
				_raise("'%s' 는 물려받은 class 가 없어서 super() 를 쓸 수 없어요." % fr["cls"]["name"])
				return null
			return {"kind": "super", "self": fr["self"], "cls": fr["cls"]["base"]}
		"print":
			var parts: PackedStringArray = []
			for a in args:
				parts.append(_str(a))
			_host.print_line(" ".join(parts))
			return null
		"range":
			return _range(args)
		"len":
			if not _need_args(name, args, 1):
				return null
			if args[0] is String:
				return String(args[0]).length()
			if _is_kind(args[0], "dict") or _is_kind(args[0], "set"):
				return args[0]["data"].size()
			var items = _iter(args[0], "len() 안")
			return null if items == null else items.size()
		"abs":
			if _need_args(name, args, 1) and _need_num(name, args[0]):
				var v = _num(args[0])
				return absf(v) if typeof(v) == TYPE_FLOAT else absi(v)
		"sorted":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "sorted() 안")
			return null if items == null else _sorted(items)
		"sum":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "sum() 안")
			if items == null:
				return null
			var total = 0
			for v in items:
				total = _binop("+", total, v)
				if not _err.is_empty():
					return null
			return total
		"enumerate":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "enumerate() 안")
			if items == null:
				return null
			var out: Array = []
			for i in items.size():
				out.append(_tuple([i, items[i]]))
			return out
		"zip":
			if args.size() < 2:
				_raise("zip() 에는 목록을 2개 이상 넣어요.")
				return null
			var lists: Array = []
			var n := MAX_LIST
			for a in args:
				var items = _iter(a, "zip() 안")
				if items == null:
					return null
				lists.append(items)
				n = mini(n, items.size())
			var out: Array = []
			for i in n:
				out.append(_tuple(lists.map(func(l: Array) -> Variant: return l[i])))
			return out
		"list", "tuple":
			if not _need_args(name, args, 0, 1):
				return null
			var items = [] if args.is_empty() else _iter(args[0], "%s() 안" % name)
			if items == null:
				return null
			return items if name == "list" else _tuple(items)
		"dict":
			if not _need_args(name, args, 0, 1):
				return null
			var d := _new_dict()
			if args.is_empty():
				return d
			if _is_kind(args[0], "dict"):
				for pair in args[0]["data"].values():
					_dict_set(d, pair[0], pair[1])
				return d
			var pairs = _iter(args[0], "dict() 안")
			if pairs == null:
				return null
			for p in pairs:
				var kv = _unpack(p, 2)
				if kv == null:
					return null
				_dict_set(d, kv[0], kv[1])
			return d
		"set":
			if not _need_args(name, args, 0, 1):
				return null
			var items = [] if args.is_empty() else _iter(args[0], "set() 안")
			return null if items == null else _set_from(items)
		"min", "max":
			var seq: Array = args
			if args.size() == 1:
				var items = _iter(args[0], "%s() 안" % name)
				if items == null:
					return null
				seq = items
			if seq.is_empty():
				_raise("'%s()' 에 넣은 값이 없어요." % name)
				return null
			var best = seq[0]
			for v in seq.slice(1):
				var better := _compare("<" if name == "min" else ">", v, best)
				if not _err.is_empty():
					return null
				if better:
					best = v
			return best
		"int":
			if not _need_args(name, args, 1):
				return null
			var v = args[0]
			if _is_num(v):
				return int(v)
			if v is String and String(v).strip_edges().is_valid_int():
				return String(v).strip_edges().to_int()
			_raise("정수로 바꿀 수 없는 값이에요: %s" % _repr(v), "ValueError")
		"float":
			if not _need_args(name, args, 1):
				return null
			var v = args[0]
			if _is_num(v):
				return float(v)
			if v is String and String(v).strip_edges().is_valid_float():
				return String(v).strip_edges().to_float()
			_raise("소수로 바꿀 수 없는 값이에요: %s" % _repr(v), "ValueError")
		"str":
			if _need_args(name, args, 1):
				return _str(args[0])
		"round":
			if not (_need_args(name, args, 1, 2) and _need_num(name, args[0])):
				return null
			if args.size() == 2:
				if not _need_int(name, args[1]):
					return null
				var p := pow(10.0, int(args[1]))
				return roundf(float(args[0]) * p) / p
			return _round_half_even(float(args[0]))
	return null


func _range(args: Array) -> Variant:
	if not _need_args("range", args, 1, 3):
		return null
	for a in args:
		if not _need_int("range", a):
			return null
	var start := 0
	var stop := int(args[0])
	var step := 1
	if args.size() >= 2:
		start = int(args[0])
		stop = int(args[1])
	if args.size() == 3:
		step = int(args[2])
	if step == 0:
		_raise("range() 의 간격은 0이 될 수 없어요.")
		return null
	var out: Array = []
	var i := start
	while (step > 0 and i < stop) or (step < 0 and i > stop):
		out.append(i)
		if out.size() > MAX_LIST:
			_raise("range() 가 너무 커요.")
			return null
		i += step
	return out


func _call_module(mod: String, name: String, args: Array) -> Variant:
	var full := "%s.%s" % [mod, name]
	match full:
		"math.sqrt":
			if _need_args(full, args, 1) and _need_num(full, args[0]):
				if _num(args[0]) < 0:
					_raise("음수의 제곱근은 구할 수 없어요.")
					return null
				return sqrt(float(args[0]))
		"math.floor":
			if _need_args(full, args, 1) and _need_num(full, args[0]):
				return floori(float(args[0]))
		"math.ceil":
			if _need_args(full, args, 1) and _need_num(full, args[0]):
				return ceili(float(args[0]))
		"math.pow":
			if _need_args(full, args, 2) and _need_num(full, args[0]) and _need_num(full, args[1]):
				return pow(float(args[0]), float(args[1]))
		"random.randint":
			if _need_args(full, args, 2) and _need_int(full, args[0]) and _need_int(full, args[1]):
				if int(args[0]) > int(args[1]):
					_raise("random.randint(a, b) 는 a 가 b 보다 작거나 같아야 해요.")
					return null
				return _rng.randi_range(int(args[0]), int(args[1]))
		"random.choice":
			if not _need_args(full, args, 1):
				return null
			var seq = args[0]
			if not (seq is Array or seq is String) or seq.is_empty():
				_raise("random.choice() 에는 비어 있지 않은 목록을 넣어요.")
				return null
			var size: int = seq.size() if seq is Array else String(seq).length()
			return seq[_rng.randi_range(0, size - 1)]
		"random.random":
			if _need_args(full, args, 0):
				return _rng.randf()
	return null


const LIST_METHODS: PackedStringArray = ["append", "pop", "insert", "remove", "index", "count", "sort", "reverse"]
const DICT_METHODS: PackedStringArray = ["get", "keys", "values", "items", "pop"]
const TUPLE_METHODS: PackedStringArray = ["index", "count"]
const SET_METHODS: PackedStringArray = ["add", "remove", "discard"]
const STR_METHODS: PackedStringArray = ["upper", "lower", "count", "index", "startswith", "endswith", "split", "join", "replace", "strip"]


func _call_method(obj: Variant, name: String, args: Array) -> Variant:
	if _is_kind(obj, "dict"):
		return _call_dict_method(obj, name, args)
	if _is_kind(obj, "set"):
		if not _need_args(name, args, 1):
			return null
		var k := _key(args[0])
		if not _err.is_empty():
			return null
		match name:
			"add":
				obj["data"][k] = args[0]
			"remove":
				if not obj["data"].has(k):
					_raise("집합 안에 %s 이(가) 없어요." % _repr(args[0]), "KeyError")
					return null
				obj["data"].erase(k)
			"discard":
				obj["data"].erase(k)
		return null
	if obj is String:
		return _call_str_method(obj, name, args)
	var items: Array = obj["items"] if _is_kind(obj, "tuple") else obj
	match name:
		"append":
			if _need_args("append", args, 1):
				if items.size() >= MAX_LIST:
					_raise("목록이 너무 커요.")
					return null
				items.append(args[0])
		"insert":
			if _need_args("insert", args, 2) and _need_int("insert", args[0]):
				items.insert(clampi(int(args[0]) + (items.size() if int(args[0]) < 0 else 0), 0, items.size()), args[1])
		"pop":
			if not _need_args("pop", args, 0, 1):
				return null
			if items.is_empty():
				_raise("빈 목록에서는 pop() 할 수 없어요.")
				return null
			if args.is_empty():
				return items.pop_back()
			var i := _index_of(items, args[0])
			return null if not _err.is_empty() else items.pop_at(i)
		"remove", "index":
			if not _need_args(name, args, 1):
				return null
			for i in items.size():
				if _eq(items[i], args[0]):
					if name == "index":
						return i
					items.remove_at(i)
					return null
			_raise("%s 안에 %s 이(가) 없어요." % [_type_name(obj), _repr(args[0])], "ValueError")
		"count":
			if _need_args("count", args, 1):
				return items.filter(func(x: Variant) -> bool: return _eq(x, args[0])).size()
		"sort":
			if _need_args("sort", args, 0):
				var sorted = _sorted(items)
				if sorted != null:
					items.assign(sorted)
		"reverse":
			if _need_args("reverse", args, 0):
				items.reverse()
	return null


func _call_dict_method(d: Dictionary, name: String, args: Array) -> Variant:
	var data: Dictionary = d["data"]
	match name:
		"get":
			if not _need_args("get", args, 1, 2):
				return null
			var k := _key(args[0])
			if not _err.is_empty():
				return null
			if data.has(k):
				return data[k][1]
			return args[1] if args.size() == 2 else null
		"keys":
			return _dict_keys(d) if _need_args("keys", args, 0) else null
		"values":
			if _need_args("values", args, 0):
				return data.values().map(func(pair: Array) -> Variant: return pair[1])
		"items":
			if _need_args("items", args, 0):
				return data.values().map(func(pair: Array) -> Variant: return _tuple([pair[0], pair[1]]))
		"pop":
			if not _need_args("pop", args, 1, 2):
				return null
			var k := _key(args[0])
			if not _err.is_empty():
				return null
			if data.has(k):
				var value = data[k][1]
				data.erase(k)
				return value
			if args.size() == 2:
				return args[1]
			_raise("딕셔너리에 %s 키가 없어요." % _repr(args[0]), "KeyError")
	return null


func _call_str_method(s: String, name: String, args: Array) -> Variant:
	match name:
		"upper", "lower", "strip":
			if _need_args(name, args, 0):
				return s.to_upper() if name == "upper" else (s.to_lower() if name == "lower" else s.strip_edges())
		"count", "index", "startswith", "endswith":
			if not (_need_args(name, args, 1) and _need_str(name, args[0])):
				return null
			match name:
				"count":
					return s.count(args[0])
				"startswith":
					return s.begins_with(args[0])
				"endswith":
					return s.ends_with(args[0])
			var at := s.find(args[0])
			if at < 0:
				_raise("글자 안에 %s 이(가) 없어요." % _repr(args[0]), "ValueError")
				return null
			return at
		"split":
			if not _need_args(name, args, 0, 1):
				return null
			if args.is_empty():
				return Array(s.split(" ", false))
			return Array(s.split(args[0])) if _need_str(name, args[0]) else null
		"join":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "join() 안")
			if items == null:
				return null
			var parts: PackedStringArray = []
			for it in items:
				if not it is String:
					_raise("join() 할 목록에는 글자만 있어야 해요 (지금: %s)." % _repr(it))
					return null
				parts.append(it)
			return s.join(parts)
		"replace":
			if _need_args(name, args, 2) and _need_str(name, args[0]) and _need_str(name, args[1]):
				return s.replace(args[0], args[1])
	return null


func _need_str(name: String, v: Variant) -> bool:
	if not v is String:
		_raise("'%s()' 에는 글자를 넣어요 (지금: %s)." % [name, _repr(v)])
		return false
	return true


## A sorted copy (numbers, strings, or tuples/lists of them), or null with an error.
func _sorted(items: Array) -> Variant:
	var out := items.duplicate()
	# Insertion sort with _compare, so mixed types raise a friendly error instead of crashing.
	for i in range(1, out.size()):
		var v = out[i]
		var j := i - 1
		while j >= 0 and _compare(">", out[j], v):
			out[j + 1] = out[j]
			j -= 1
		if not _err.is_empty():
			return null
		out[j + 1] = v
	return out


func _attr(obj: Variant, name: String) -> Variant:
	var kind: String = obj.get("kind", "") if obj is Dictionary else ""
	match kind:
		"robot":
			var i: int = obj["index"]
			if name in COMMANDS or name in CONDITIONS or name in SENSORS:
				return {"kind": "robotfn", "index": i, "name": name}
			if name == "name":
				return ROBOT_NAMES[i % ROBOT_NAMES.size()]
			_raise("로봇에게는 '%s' 가 없어요. (예: r.move(), r.at_goal(), r.name)" % name)
			return null
		"instance":
			if obj["fields"].has(name):
				return obj["fields"][name]
			var m := _find_method(obj["cls"], name)
			if not m.is_empty():
				return {"kind": "bound", "self": obj, "fn": m["node"], "cls": m["cls"]}
			var a := _find_class_attr(obj["cls"], name)
			if not a.is_empty():
				return a["value"]
			_raise("'%s' 객체에는 '%s' 가 없어요. __init__ 에서 self.%s = ... 로 먼저 만들어 주세요." % [obj["cls"]["name"], name, name])
			return null
		"class":
			var m := _find_method(obj, name)
			if not m.is_empty():
				return {"kind": "func", "node": m["node"], "cls": m["cls"]}
			var a := _find_class_attr(obj, name)
			if not a.is_empty():
				return a["value"]
			_raise("class '%s' 에는 '%s' 가 없어요." % [obj["name"], name])
			return null
		"super":
			var m := _find_method(obj["cls"], name)
			if not m.is_empty():
				return {"kind": "bound", "self": obj["self"], "fn": m["node"], "cls": m["cls"]}
			_raise("물려받은 class 에 '%s' 메서드가 없어요." % name)
			return null
	if obj is Dictionary and obj.get("kind") == "module":
		var mod: String = obj["name"]
		if not name in MODULES[mod]:
			_raise("%s 에는 '%s' 가 없어요. (있는 것: %s)" % [mod, name, ", ".join(PackedStringArray(MODULES[mod]))])
			return null
		if full_name(mod, name) == "math.pi":
			return PI
		return {"kind": "modfn", "mod": mod, "name": name}
	var methods: PackedStringArray = []
	if obj is Array:
		methods = LIST_METHODS
	elif obj is String:
		methods = STR_METHODS
	elif kind == "dict":
		methods = DICT_METHODS
	elif kind == "tuple":
		methods = TUPLE_METHODS
	elif kind == "set":
		methods = SET_METHODS
	if name in methods:
		return {"kind": "method", "obj": obj, "name": name}
	if not methods.is_empty():
		_raise("%s 에는 '.%s' 가 없어요. (쓸 수 있는 것: %s)" % [_type_name(obj), name, ", ".join(methods)])
		return null
	_raise("'.%s' 를 쓸 수 없는 값이에요: %s" % [name, _repr(obj)])
	return null


static func full_name(mod: String, name: String) -> String:
	return "%s.%s" % [mod, name]


# --- Values (Python semantics) ------------------------------------------------

static func _is_num(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_BOOL


static func _num(v: Variant) -> Variant:
	return int(v) if typeof(v) == TYPE_BOOL else v


static func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0
		TYPE_STRING:
			return not String(v).is_empty()
		TYPE_ARRAY:
			return not (v as Array).is_empty()
	if _is_kind(v, "tuple"):
		return not (v["items"] as Array).is_empty()
	if _is_kind(v, "dict") or _is_kind(v, "set"):
		return not (v["data"] as Dictionary).is_empty()
	return true


static func _floordiv(x: int, y: int) -> int:
	var q := x / y
	if x % y != 0 and ((x < 0) != (y < 0)):
		q -= 1
	return q


static func _round_half_even(x: float) -> int:
	var f := floorf(x)
	var diff := x - f
	if diff > 0.5:
		return int(f) + 1
	if diff < 0.5:
		return int(f)
	return int(f) if int(f) % 2 == 0 else int(f) + 1


func _binop(op: String, a: Variant, b: Variant) -> Variant:
	if op == "|" or op == "&" or (op == "-" and _is_kind(a, "set")):
		if _is_kind(a, "set") and _is_kind(b, "set"):
			var out := _new_set()
			var da: Dictionary = a["data"]
			var db: Dictionary = b["data"]
			match op:
				"|":
					out["data"] = da.merged(db)
				"&":
					for k in da:
						if db.has(k):
							out["data"][k] = da[k]
				"-":
					for k in da:
						if not db.has(k):
							out["data"][k] = da[k]
			return out
		if op != "-" and typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
			return (a | b) if op == "|" else (a & b)
		if op != "-":
			_raise("'%s' 는 집합끼리나 정수끼리 써요 (지금: %s, %s)." % [op, _type_name(a), _type_name(b)])
			return null
	if _is_num(a) and _is_num(b):
		var x = _num(a)
		var y = _num(b)
		var both_int: bool = typeof(x) == TYPE_INT and typeof(y) == TYPE_INT
		match op:
			"+":
				return x + y
			"-":
				return x - y
			"*":
				return x * y
			"/", "//", "%":
				if y == 0:
					_raise("0으로 나눌 수 없어요.", "ZeroDivisionError")
					return null
				if op == "/":
					return float(x) / float(y)
				if both_int:
					var q := _floordiv(x, y)
					return q if op == "//" else x - y * q
				var fq := floorf(float(x) / float(y))
				return fq if op == "//" else float(x) - float(y) * fq
			"**":
				if both_int and y >= 0:
					var r := 1
					for i in int(y):
						r *= int(x)
					return r
				return pow(float(x), float(y))
	if op == "+" and a is String and b is String:
		return a + b
	if op == "+" and a is Array and b is Array:
		return (a as Array) + (b as Array)
	if op == "+" and _is_kind(a, "tuple") and _is_kind(b, "tuple"):
		return _tuple((a["items"] as Array) + (b["items"] as Array))
	if op == "*":
		if _is_kind(a, "tuple") and typeof(b) == TYPE_INT:
			return _tuple(_repeat_seq(a["items"], b))
		if (a is String or a is Array) and typeof(b) == TYPE_INT:
			return _repeat_seq(a, b)
		if (b is String or b is Array) and typeof(a) == TYPE_INT:
			return _repeat_seq(b, a)
	if op == "+" and (a is String or b is String):
		_raise("글자와 숫자는 바로 더할 수 없어요. str() 로 숫자를 글자로 바꿔 보세요.")
		return null
	_raise("%s 와 %s 는 '%s' 계산을 할 수 없어요." % [_type_name(a), _type_name(b), op])
	return null


func _repeat_seq(seq: Variant, times: int) -> Variant:
	if seq is String:
		return String(seq).repeat(maxi(0, times))
	var out: Array = []
	for i in maxi(0, times):
		out.append_array(seq)
		if out.size() > MAX_LIST:
			_raise("목록이 너무 커요.")
			return null
	return out


static func _eq(a: Variant, b: Variant) -> bool:
	if _is_num(a) and _is_num(b):
		return _num(a) == _num(b)
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var ka = a.get("kind")
		if ka != b.get("kind"):
			return false
		match ka:
			"robot":
				return a["index"] == b["index"]
			"tuple":
				return _eq(a["items"], b["items"])
			"set":
				var sa: Dictionary = a["data"]
				var sb: Dictionary = b["data"]
				return sa.size() == sb.size() and sa.keys().all(func(k: String) -> bool: return sb.has(k))
			"dict":
				var da: Dictionary = a["data"]
				var db: Dictionary = b["data"]
				if da.size() != db.size():
					return false
				for k in da:
					if not db.has(k) or not _eq(da[k][1], db[k][1]):
						return false
				return true
		return is_same(a, b)
	if a is Array:
		var la: Array = a
		var lb: Array = b
		if la.size() != lb.size():
			return false
		for i in la.size():
			if not _eq(la[i], lb[i]):
				return false
		return true
	return a == b


func _compare(op: String, a: Variant, b: Variant) -> bool:
	match op:
		"==":
			return _eq(a, b)
		"!=":
			return not _eq(a, b)
		"is", "is not":
			# Identity: None/True/False/numbers/strings by value, objects by reference.
			var same: bool = is_same(a, b) if (a is Dictionary or a is Array) else (typeof(a) == typeof(b) and a == b)
			return same if op == "is" else not same
		"in", "not in":
			var found := false
			if _is_kind(b, "dict") or _is_kind(b, "set"):
				var k := _key(a)
				found = _err.is_empty() and b["data"].has(k)
			elif b is String and a is String:
				found = String(b).contains(a)
			elif b is Array or _is_kind(b, "tuple"):
				for item in (b if b is Array else b["items"]):
					if _eq(a, item):
						found = true
						break
			else:
				_raise("'in' 뒤에는 목록, 튜플, 글자, 딕셔너리가 와야 해요.")
				return false
			return found if op == "in" else not found
	# Lists and tuples compare item by item, like Python: (1, 5) < (2, 0).
	var a_seq = a if a is Array else (a["items"] if _is_kind(a, "tuple") else null)
	var b_seq = b if b is Array else (b["items"] if _is_kind(b, "tuple") else null)
	if a_seq != null and b_seq != null and (a is Array) == (b is Array):
		for i in mini(a_seq.size(), b_seq.size()):
			if not _eq(a_seq[i], b_seq[i]):
				return _compare(op, a_seq[i], b_seq[i])
		var la: int = a_seq.size()
		var lb: int = b_seq.size()
		match op:
			"<":
				return la < lb
			">":
				return la > lb
			"<=":
				return la <= lb
			">=":
				return la >= lb
	var ok := (_is_num(a) and _is_num(b)) or (a is String and b is String)
	if not ok:
		_raise("%s 와 %s 는 '%s' 로 비교할 수 없어요." % [_type_name(a), _type_name(b), op])
		return false
	var x = _num(a) if _is_num(a) else a
	var y = _num(b) if _is_num(b) else b
	match op:
		"<":
			return x < y
		">":
			return x > y
		"<=":
			return x <= y
		">=":
			return x >= y
	return false


func _index_of(seq: Variant, idx: Variant) -> int:
	if typeof(idx) != TYPE_INT:
		_raise("[ ] 안의 번호는 정수여야 해요 (지금: %s)." % _repr(idx))
		return 0
	var n: int = seq.size() if seq is Array else String(seq).length()
	var i: int = idx
	if i < 0:
		i += n
	if i < 0 or i >= n:
		_raise("범위를 벗어난 번호예요 (길이 %d, 번호 %d)." % [n, idx], "IndexError")
		return 0
	return i


static func _type_name(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "참/거짓"
		TYPE_INT, TYPE_FLOAT:
			return "숫자"
		TYPE_STRING:
			return "글자"
		TYPE_ARRAY:
			return "목록"
	if _is_kind(v, "tuple"):
		return "튜플"
	if _is_kind(v, "dict"):
		return "딕셔너리"
	if _is_kind(v, "set"):
		return "집합"
	return "객체"


## Text that print() shows: strings as-is, everything else like Python's repr.
static func _str(v: Variant) -> String:
	return String(v) if v is String else _repr(v)


static func _repr(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floorf(f) and absf(f) < 1e15:
				return "%d.0" % int(f)
			return str(f)
		TYPE_STRING:
			return "'%s'" % v
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for item in v:
				parts.append(_repr(item))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			match String(v.get("kind", "")):
				"func":
					return "<함수 %s>" % v["node"]["name"]
				"builtin":
					return "<명령 %s>" % v["name"]
				"module":
					return "<모듈 %s>" % v["name"]
				"modfn":
					return "<함수 %s.%s>" % [v["mod"], v["name"]]
				"method":
					return "<함수 %s>" % v["name"]
				"class":
					return "<class %s>" % v["name"]
				"instance":
					return "<%s 객체>" % v["cls"]["name"]
				"bound":
					return "<메서드 %s>" % v["fn"]["name"]
				"robot":
					return "<로봇 %s>" % ROBOT_NAMES[int(v["index"]) % ROBOT_NAMES.size()]
				"robotfn":
					return "<로봇 명령 %s>" % v["name"]
				"super":
					return "<super>"
				"tuple":
					var items: Array = v["items"]
					if items.size() == 1:
						return "(%s,)" % _repr(items[0])
					return "(" + ", ".join(PackedStringArray(items.map(func(x: Variant) -> String: return _repr(x)))) + ")"
				"set":
					if v["data"].is_empty():
						return "set()"
					return "{" + ", ".join(PackedStringArray(v["data"].values().map(func(x: Variant) -> String: return _repr(x)))) + "}"
				"dict":
					var parts: PackedStringArray = []
					for pair in v["data"].values():
						parts.append("%s: %s" % [_repr(pair[0]), _repr(pair[1])])
					return "{" + ", ".join(parts) + "}"
	return str(v)
