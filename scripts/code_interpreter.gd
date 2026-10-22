class_name CodeInterpreter
extends RefCounted
## Parser and tree-walking runner for the robot language: a small subset of Python.
##
## Statements: calls, assignment (= and every augmented form, a = b = 0, a, *rest = ...,
##   x[1:3] = ...), if/elif/else, while/for (with else), repeat N:, def (defaults, *args, **kwargs,
##   type hints)/return, break, continue, pass, global, del, assert, import math / import math as m /
##   from math import sqrt. Logical lines like Python: open brackets, triple-quoted strings and a
##   trailing backslash continue a line; ';' and "if x: y" put several statements on one line.
## Expressions: int (also 0x 0o 0b), float, "text" (r"raw", f"{x:>5}", """long"""), [lists],
##   True/False/None, + - * / // % ** | & ^ ~ << >>, comparisons (chained like Python), in, is,
##   and/or/not, a if c else b, lambda, comprehensions, calls with *args / **kwargs, a[i], a[i:j].
## Formatting: f-strings, "%d" % x and str.format() share Python's format-spec mini-language.
## Robot API: commands move() turn_left() turn_right() pick(); conditions is_blocked()
##   on_apple() at_goal(); values get_x() get_y() goal_x() goal_y() apples_left().
## Builtins: see BUILTINS. Modules: math, random.
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
##   print_line(text: String) -> void                  (one finished line; print(end="") is buffered here)
##   highlight_line(line: int) -> void
##   is_stop_requested() -> bool
##   input_line(prompt: String) -> Variant              (optional; may await. The answer to input(), or
##                                                      null when there is none left: EOFError)
## WorldHost is a ready-made synchronous host over a GridWorld.

const COMMANDS: PackedStringArray = [
	"move", "turn_left", "turn_right", "pick", "face", "drop", "report", "say", "wait", "deliver",
]
## Commands that take a value; every other command takes none.
const COMMAND_ARGS: Dictionary = {"face": 1, "drop": 1, "report": 1, "say": 1}
## The exception a failing command raises (try/except can catch it); others raise RobotError.
const COMMAND_ERRORS: Dictionary = {"move": "Blocked", "pick": "NoItem"}
## Names usable after except. Exception catches every one of them.
const EXCEPTIONS: PackedStringArray = [
	"Exception", "Blocked", "NoItem", "RobotError", "KeyError", "IndexError", "ValueError",
	"TypeError", "ZeroDivisionError", "NameError", "AssertionError", "EOFError", "StopIteration",
]
const CONDITIONS: PackedStringArray = ["is_blocked", "on_apple", "at_goal"]
const SENSORS: PackedStringArray = [
	"get_x", "get_y", "goal_x", "goal_y", "apples_left", "route", "segments",
	"get_pos", "goal_pos", "item_here", "treasure_map", "order", "market", "read_sign", "customer", "mailboxes",
	"house_here", "houses", "flags",
]
const BUILTINS: PackedStringArray = [
	"print", "range", "len", "abs", "min", "max", "int", "float", "str", "round", "robots", "super",
	"sorted", "sum", "enumerate", "zip", "list", "tuple", "dict", "set",
	"bool", "input", "any", "all", "map", "filter", "reversed", "divmod", "pow", "ord", "chr",
	"bin", "hex", "oct", "isinstance", "type", "format", "iter", "next",
]
## What type() returns for each kind of value; these names print as <class 'int'>.
const TYPE_NAMES: PackedStringArray = [
	"int", "float", "str", "bool", "list", "tuple", "dict", "set", "NoneType", "function", "type",
	"module", "Robot", "iterator",
]
## Robot names in robots() order; main.gd tints the robots to match.
const ROBOT_NAMES: PackedStringArray = ["주황", "파랑", "초록", "보라"]
const REQUIRED_MESSAGES: Dictionary = {
	"random": "이 레벨은 import random 으로 무작위를 써서 풀어요.",
	"class": "이 레벨은 class 를 만들어서 풀어요.",
	"inherit": "이 레벨은 다른 class 를 물려받는 class 를 만들어서 풀어요. 예: class Picker(Walker):",
	"dict": "이 레벨은 딕셔너리 {\"키\": 값} 을 만들어서 풀어요.",
	"try": "이 레벨은 try: / except 오류이름: 으로 오류를 잡아서 풀어요.",
	"comprehension": "이 레벨은 [x for x in 목록 if 조건] 처럼 한 줄로 목록을 만들어서 풀어요.",
	"lambda": "이 레벨은 lambda 로 작은 함수를 만들어서 풀어요. 예: key=lambda p: p[0]",
	"input": "이 레벨은 input() 으로 마을 사람에게 물어봐서 풀어요. 예: name = input(\"이름이 뭐예요? \")",
}
const MODULES: Dictionary = {
	"math": [
		"sqrt", "floor", "ceil", "pow", "pi", "e", "tau", "inf", "nan", "gcd", "lcm", "factorial", "isqrt",
		"sin", "cos", "tan", "asin", "acos", "atan", "atan2", "radians", "degrees", "log", "log10", "log2",
		"exp", "fabs", "hypot", "trunc", "comb", "perm", "prod", "dist", "isclose",
	],
	"random": ["randint", "choice", "random", "shuffle", "sample", "uniform", "randrange", "seed"],
	"collections": ["Counter", "defaultdict", "deque"],
	"statistics": ["mean", "median", "mode"],
	"itertools": ["permutations", "combinations", "product", "chain", "accumulate"],
	"time": ["sleep"],
	"string": ["ascii_lowercase", "ascii_uppercase", "ascii_letters", "digits", "punctuation"],
}
## Module values that are not functions.
const MODULE_CONSTS: Dictionary = {
	"math.pi": PI, "math.e": 2.718281828459045, "math.tau": TAU, "math.inf": INF, "math.nan": NAN,
	"string.ascii_lowercase": "abcdefghijklmnopqrstuvwxyz",
	"string.ascii_uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"string.ascii_letters": "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"string.digits": "0123456789",
	"string.punctuation": "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
}
## name=value arguments module functions accept.
const MODULE_KWARGS: Dictionary = {
	"itertools.permutations": ["r"], "itertools.combinations": ["r"], "itertools.product": ["repeat"],
	"collections.deque": ["maxlen"], "math.isclose": ["rel_tol", "abs_tol"],
}
## Real Python modules this game leaves out on purpose, and why (shown when imported).
const BLOCKED_MODULES: Dictionary = {
	"os": "컴퓨터의 파일과 폴더를 다루는 모듈", "sys": "Python 프로그램 자체를 다루는 모듈",
	"subprocess": "다른 프로그램을 실행하는 모듈", "shutil": "파일을 복사하고 지우는 모듈",
	"pathlib": "파일 경로를 다루는 모듈", "socket": "네트워크 모듈", "urllib": "인터넷 모듈",
	"requests": "인터넷 모듈", "threading": "여러 일을 동시에 하는 모듈", "json": "파일로 데이터를 저장하는 모듈",
	"datetime": "날짜와 시각 모듈", "re": "정규 표현식 모듈", "pickle": "파일로 데이터를 저장하는 모듈",
}
const KEYWORDS: PackedStringArray = [
	"if", "elif", "else", "while", "for", "in", "repeat", "def", "return", "break", "continue",
	"pass", "import", "global", "not", "and", "or", "True", "False", "None",
	"class", "lambda", "from", "as", "with", "try", "except", "finally", "raise", "yield",
	"del", "is", "assert", "nonlocal",
]
const UNSUPPORTED: PackedStringArray = ["with", "yield", "nonlocal"]
const ASSIGN_OPS: PackedStringArray = [
	"=", "+=", "-=", "*=", "/=", "//=", "%=", "**=", "|=", "&=", "^=", "<<=", ">>=",
]
## Statements that end in ':' and open a block; "if x: y" on one line is split after the ':'.
const BLOCK_WORDS: PackedStringArray = [
	"if", "elif", "else", "while", "for", "def", "class", "try", "except", "finally", "repeat",
]
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
var _in_except: int = 0  # > 0 while parsing an except block (bare raise is allowed there)
var _features: Dictionary = {}  # "random", "math", "class", "inherit" -> true when the code uses them
var _no_in: bool = false  # while reading a for target: 'in' ends it instead of being a comparison

# --- Run state ---
var _host
var _err: Dictionary = {}
var _steps: int = 0
var _depth: int = 0
var _globals: Dictionary = {}
var _frames: Array = []  # [{"vars": Dictionary, "fn": def node}]
var _ret: Variant = null
var _rng := RandomNumberGenerator.new()
var _scopes: Array = []  # comprehension and lambda variables, innermost last (looked up first)
var _handling: Array = []  # errors caught by the except blocks we are in (for a bare raise)
var _out_buf: String = ""  # printed text not yet ended by a newline (print(..., end=""))


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

	for ll in _logical_lines(source):
		var text: String = ll["text"]
		var indent := 0
		var k := 0
		while k < text.length() and (text[k] == " " or text[k] == "\t"):
			indent += 4 if text[k] == "\t" else 1
			k += 1
		var body := text.substr(k)
		_line = int(ll["line"])
		var toks := _tokenize(body)
		if not _error.is_empty():
			return _error
		_add_line(indent, body, _line, toks)
		if not _error.is_empty():
			return _error

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


## Joins physical lines into logical lines like Python: inside ( [ {, inside triple-quoted strings
## and after a trailing backslash. Comments are dropped. Returns [{"text", "line"}] where "line" is
## the (0-based) source line the statement starts on.
static func _logical_lines(source: String) -> Array:
	var src := source.replace("\r\n", "\n").replace("\r", "\n")
	var out: Array = []
	var buf := ""
	var start := -1
	var line := 0
	var depth := 0
	var quote := ""
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if quote != "":
			if c == "\\" and i + 1 < n:
				if src[i + 1] == "\n":
					line += 1
				buf += src.substr(i, 2)
				i += 2
				continue
			if src.substr(i, quote.length()) == quote:
				buf += quote
				i += quote.length()
				quote = ""
				continue
			if c != "\n" or quote.length() == 3:
				if c == "\n":
					line += 1
				buf += c
				i += 1
				continue
			quote = ""  # a one-line string left open: the tokenizer reports it
		if c == "#":
			while i < n and src[i] != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			if start < 0:
				start = line
			quote = c.repeat(3) if src.substr(i, 3) == c.repeat(3) else c
			buf += quote
			i += quote.length()
			continue
		if c == "\\" and i + 1 < n and src[i + 1] == "\n":
			buf += " "
			line += 1
			i += 2
			continue
		if c == "\n":
			line += 1
			i += 1
			if depth > 0:
				buf += " "
				continue
			if not buf.strip_edges().is_empty():
				out.append({"text": buf.rstrip(" \t"), "line": start})
			buf = ""
			start = -1
			continue
		if c in "([{":
			depth += 1
		elif c in ")]}":
			depth = maxi(0, depth - 1)
		if start < 0 and c != " " and c != "\t":
			start = line
		buf += c
		i += 1
	if not buf.strip_edges().is_empty():
		out.append({"text": buf.rstrip(" \t"), "line": start})
	return out


## Adds one logical line to _lines, split like Python: "if x: y" becomes a header and an indented
## body line, and ';' separates statements.
func _add_line(indent: int, text: String, line: int, toks: Array) -> void:
	var at := _header_colon(toks)
	if at >= 0 and toks[at + 1]["t"] != "end":
		var head: Array = toks.slice(0, at + 1)
		head.append({"t": "end", "v": ""})
		_lines.append({"indent": indent, "text": text.substr(0, int(toks[at]["p"]) + 1), "line": line, "toks": head})
		var body := text.substr(int(toks[at + 1]["p"])).strip_edges()
		var body_toks := _tokenize(body)
		if _error.is_empty():
			_add_line(indent + 4, body, line, body_toks)
		return
	for k in toks.size():
		if _is_op(toks[k], ";"):
			var first := text.substr(0, int(toks[k]["p"])).strip_edges()
			var rest := text.substr(int(toks[k]["p"]) + 1).strip_edges()
			if k > 0:
				var head: Array = toks.slice(0, k)
				head.append({"t": "end", "v": ""})
				_lines.append({"indent": indent, "text": first, "line": line, "toks": head})
			if not rest.is_empty():
				var rest_toks := _tokenize(rest)
				if _error.is_empty():
					_add_line(indent, rest, line, rest_toks)
			return
	_lines.append({"indent": indent, "text": text, "line": line, "toks": toks})


## The token index of the ':' that ends a block header (if/for/def/...), or -1. Colons inside
## brackets and the ones that belong to a lambda are skipped.
static func _header_colon(toks: Array) -> int:
	if toks.is_empty() or toks[0]["t"] != "name" or not toks[0]["v"] in BLOCK_WORDS:
		return -1
	var depth := 0
	var lambdas := 0
	for k in toks.size():
		var t: Dictionary = toks[k]
		if t["t"] == "op":
			if t["v"] in ["(", "[", "{"]:
				depth += 1
			elif t["v"] in [")", "]", "}"]:
				depth -= 1
			elif t["v"] == ":" and depth == 0:
				if lambdas > 0:
					lambdas -= 1
				else:
					return k
		elif t["t"] == "name" and t["v"] == "lambda" and depth == 0:
			lambdas += 1
	return -1


func _fail(line: int, message: String) -> Dictionary:
	if _error.is_empty():
		_error = {"ok": false, "line": line, "message": message}
	return _error


## Records a parse error and returns an empty node.
func _bad(message: String) -> Dictionary:
	_fail(_line, message)
	return {}


## A module name the program has imported (it cannot also be a variable, function or class name).
func _module_taken(name: String) -> bool:
	return MODULES.has(name) and _features.has(name)


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


## Splits one logical line into tokens: {"t": "num"|"str"|"fstr"|"name"|"op"|"end", "v": value,
## "p": position in `text`}.
func _tokenize(text: String) -> Array:
	var toks: Array = []
	var i := 0
	var n := text.length()
	var mark := -1  # where the token read in the previous round started
	while i < n:
		if mark >= 0 and not toks.is_empty() and not toks.back().has("p"):
			toks.back()["p"] = mark
		mark = i
		var c := text[i]
		if c == " " or c == "\t" or c == "\n":
			i += 1
			continue
		if _is_digit(c) or (c == "." and i + 1 < n and _is_digit(text[i + 1])):
			i = _read_number(text, i, toks)
			if i < 0:
				return []
			continue
		var prefix := ""
		if c in "fFrR":
			var j := i
			while j < n and j - i < 2 and text[j] in "fFrR":
				j += 1
			if j < n and (text[j] == "\"" or text[j] == "'"):
				prefix = text.substr(i, j - i).to_lower()
		if prefix != "" or c == "\"" or c == "'":
			i = _read_string(text, i + prefix.length(), prefix, toks)
			if i < 0:
				return []
			continue
		if _is_ident_start(c):
			var j := i + 1
			while j < n and _is_ident(text[j]):
				j += 1
			toks.append({"t": "name", "v": text.substr(i, j - i)})
			i = j
			continue
		var three := text.substr(i, 3)
		var two := text.substr(i, 2)
		if three in ["//=", "**=", "<<=", ">>="]:
			toks.append({"t": "op", "v": three})
			i += 3
		elif two in ["==", "!=", "<=", ">=", "//", "+=", "-=", "*=", "/=", "%=", "**", "|=", "&=", "^=", "<<", ">>", "->"]:
			toks.append({"t": "op", "v": two})
			i += 2
		elif c in "+-*/%<>=()[]{},:.|&^~;":
			toks.append({"t": "op", "v": c})
			i += 1
		else:
			_fail(_line, "이해할 수 없는 글자가 있어요: '%s'" % c)
			return []
	if mark >= 0 and not toks.is_empty() and not toks.back().has("p"):
		toks.back()["p"] = mark
	toks.append({"t": "end", "v": "", "p": n})
	return toks


## Reads a number at `i`: 12, 1_000, 3.5, .5, 1e-3, 0x1F, 0o17, 0b101. Returns the index after it.
func _read_number(text: String, i: int, toks: Array) -> int:
	var n := text.length()
	if text[i] == "0" and i + 1 < n and text[i + 1] in "xXoObB":
		var base: int = {"x": 16, "o": 8, "b": 2}[text[i + 1].to_lower()]
		var j := i + 2
		var digits := ""
		while j < n and _is_ident(text[j]):
			if text[j] != "_":
				digits += text[j]
			j += 1
		var v = _parse_int_base(digits, base)
		if v == null:
			_fail(_line, "숫자를 읽을 수 없어요: %s" % text.substr(i, j - i))
			return -1
		toks.append({"t": "num", "v": v})
		return j
	var j := i
	var s := ""
	var is_float := false
	while j < n:
		var ch := text[j]
		if _is_digit(ch):
			s += ch
		elif ch == "_" and s != "":
			pass
		elif ch == "." and not is_float:
			is_float = true
			s += ch
		elif (ch == "e" or ch == "E") and not s.contains("e") and j + 1 < n and (_is_digit(text[j + 1]) or (text[j + 1] in "+-" and j + 2 < n and _is_digit(text[j + 2]))):
			is_float = true
			s += "e" + text[j + 1]
			j += 1
		else:
			break
		j += 1
	toks.append({"t": "num", "v": s.to_float() if is_float else s.to_int()})
	return j


## Digits in `base` (2..36) as an int, or null when a digit does not belong to the base.
static func _parse_int_base(digits: String, base: int) -> Variant:
	if digits.is_empty():
		return null
	var v := 0
	for ch in digits.to_lower():
		var d := "0123456789abcdefghijklmnopqrstuvwxyz".find(ch)
		if d < 0 or d >= base:
			return null
		v = v * base + d
	return v


## The character a backslash escape stands for (\n, \t, \\, \' ...). Unknown escapes keep the
## backslash, like Python.
static func _escape(e: String) -> String:
	match e:
		"n":
			return "\n"
		"t":
			return "\t"
		"r":
			return "\r"
		"\\", "'", "\"":
			return e
		"0":
			return String.chr(0)
		"\n":
			return ""
	return "\\" + e


## Reads a string literal whose quote is at `q_at` ('..', "..", or tripled quotes), with an
## r (raw) and/or f prefix. Returns the index after it, or -1 after recording an error.
func _read_string(text: String, q_at: int, prefix: String, toks: Array) -> int:
	var q := text[q_at]
	var quote := q.repeat(3) if text.substr(q_at, 3) == q.repeat(3) else q
	var raw := prefix.contains("r")
	if prefix.contains("f"):
		return _tokenize_fstring(text, q_at, quote, raw, toks)
	var n := text.length()
	var j := q_at + quote.length()
	var buf := ""
	while j < n and text.substr(j, quote.length()) != quote:
		if text[j] == "\\" and j + 1 < n:
			buf += text.substr(j, 2) if raw else _escape(text[j + 1])
			j += 2
		else:
			buf += text[j]
			j += 1
	if j >= n:
		_fail(_line, "글자의 따옴표(%s)가 닫히지 않았어요." % quote)
		return -1
	toks.append({"t": "str", "v": buf})
	return j + quote.length()


## Reads f"..." whose quote starts at `q_at`. Appends {"t": "fstr", "v": parts} where each part is
## literal text or {"src": expression text, "spec": format spec, "conv": "r"/"s"/"", "debug": text
## shown before the value for {x=}}. Returns the index after the closing quote, or -1 after an error.
func _tokenize_fstring(text: String, q_at: int, quote: String, raw: bool, toks: Array) -> int:
	var parts: Array = []
	var buf := ""
	var j := q_at + quote.length()
	var n := text.length()
	while j < n and text.substr(j, quote.length()) != quote:
		var ch := text[j]
		if ch == "{" and text.substr(j + 1, 1) == "{":
			buf += "{"
			j += 2
		elif ch == "}" and text.substr(j + 1, 1) == "}":
			buf += "}"
			j += 2
		elif ch == "{":
			var field := _fstring_field(text, j + 1, quote)
			if field.is_empty():
				return -1
			if buf != "":
				parts.append(buf)
				buf = ""
			parts.append(field["part"])
			j = int(field["end"])
		elif ch == "\\" and j + 1 < n:
			buf += text.substr(j, 2) if raw else _escape(text[j + 1])
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
	return j + quote.length()


## One {expression!conv:spec} field of an f-string starting after its '{'.
## Returns {"part": {...}, "end": index after '}'} or {} after recording an error.
func _fstring_field(text: String, from: int, quote: String) -> Dictionary:
	var n := text.length()
	var k := from
	var depth := 0
	var in_str := ""
	var colon := -1
	var bang := -1
	while k < n:
		var ch := text[k]
		if colon >= 0:
			if ch == "}":
				break
		elif in_str != "":
			if ch == in_str:
				in_str = ""
		elif text.substr(k, quote.length()) == quote:
			break
		elif ch == "\"" or ch == "'":
			in_str = ch
		elif ch in "([{":
			depth += 1
		elif ch in ")]":
			depth -= 1
		elif ch == "}":
			if depth == 0:
				break
			depth -= 1
		elif ch == "!" and depth == 0 and text.substr(k + 1, 1) != "=":
			bang = k
		elif ch == ":" and depth == 0:
			colon = k
		k += 1
	if k >= n or text[k] != "}":
		_fail(_line, "f-문자열의 '{' 가 '}' 로 닫히지 않았어요.")
		return {}
	var src_end := bang if bang >= 0 else (colon if colon >= 0 else k)
	var src := text.substr(from, src_end - from)
	var conv := ""
	if bang >= 0:
		conv = text.substr(bang + 1, (colon if colon >= 0 else k) - bang - 1).strip_edges()
	var spec := text.substr(colon + 1, k - colon - 1) if colon >= 0 else ""
	var debug := ""
	var trimmed := src.strip_edges(false, true)
	if trimmed.ends_with("=") and not trimmed.right(2) in ["==", "!=", "<=", ">="]:
		debug = src
		src = trimmed.left(trimmed.length() - 1)
		if conv == "" and spec == "":
			conv = "r"
	if src.strip_edges().is_empty():
		_fail(_line, "f-문자열의 { } 안에 값을 적어 주세요. 예: f\"사과 {n}개\"")
		return {}
	if not conv in ["", "r", "s", "a"]:
		_fail(_line, "f-문자열의 '!%s' 는 쓸 수 없어요. !r 이나 !s 를 써요." % conv)
		return {}
	return {"part": {"src": src, "spec": spec, "conv": conv, "debug": debug}, "end": k + 1}


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
				var else_body := _parse_loop_else(indent)
				return {"type": "while", "cond": cond, "text": _header_text(ln, "while"), "body": body, "else": else_body, "line": line}
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
					if not tgt["type"] in ["index", "slice", "name"]:
						return _bad("del 은 변수나 목록·딕셔너리의 칸을 지울 때 써요. 예: del d[\"apple\"]")
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
			"raise":
				_next()
				if _at_end():
					if _in_except == 0:
						return _bad("이름 없는 raise 는 except 안에서 잡은 오류를 다시 던질 때만 써요.")
					return {"type": "raise", "name": "", "msg": null, "line": line}
				var nt := _next()
				if nt["t"] != "name" or not nt["v"] in EXCEPTIONS:
					return _bad("raise 뒤에는 오류 이름을 적어요. 예: raise ValueError(\"이유\")  (쓸 수 있는 것: %s)" % ", ".join(EXCEPTIONS))
				var msg = null
				if _is_op(_peek(), "("):
					_next()
					if not _is_op(_peek(), ")"):
						msg = _parse_expr()
					if not _is_op(_next(), ")"):
						return _bad("괄호 ')' 가 닫히지 않았어요.")
				_expect_end()
				return {"type": "raise", "name": nt["v"], "msg": msg, "line": line}
			"except", "finally":
				return _bad("%s 앞에는 try: 가 있어야 해요." % w)
			"from":
				return _parse_import()
			"assert":
				_next()
				var cond := _parse_expr()
				var msg = null
				if _error.is_empty() and _is_op(_peek(), ","):
					_next()
					msg = _parse_expr()
				_expect_end()
				return {"type": "assert", "cond": cond, "msg": msg, "line": line}
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


## The optional "else:" block of a while/for loop (runs when the loop ends without break).
func _parse_loop_else(indent: int) -> Array:
	if not _error.is_empty() or _pos >= _lines.size() or int(_lines[_pos]["indent"]) != indent:
		return []
	var next: Dictionary = _lines[_pos]
	if not _is_word(next["toks"][0], "else"):
		return []
	_pos += 1
	_enter_line(next)
	_next()
	_expect_colon("else")
	if not _error.is_empty():
		return []
	return _parse_child_block(next, indent)


func _parse_for(ln: Dictionary, indent: int) -> Dictionary:
	var line := _line
	_next()
	# The target is one name, or several to unpack: for x, y in points: / for i, (a, b) in ...
	_no_in = true
	var target := _parse_expr_list()
	_no_in = false
	if not _error.is_empty():
		return {}
	if not _plain_target(target):
		return _bad("for 뒤에는 변수 이름이 와야 해요. 예: for i in range(3):")
	if not _is_word(_next(), "in"):
		return _bad("for 문은 'for i in range(3):' 모양으로 적어요.")
	if not _check_target(target, "="):
		return {}
	var iter := _parse_header_expr("for", false)
	if not _error.is_empty():
		return {}
	_loop_depth += 1
	var body := _parse_child_block(ln, indent)
	_loop_depth -= 1
	var else_body := _parse_loop_else(indent)
	return {"type": "for", "target": target, "iter": iter, "body": body, "else": else_body, "line": line}


## True for a name, or a tuple/list of names (one of them may have a *), as for/comprehension targets.
static func _plain_target(e: Dictionary) -> bool:
	match String(e.get("type", "")):
		"name":
			return true
		"starred":
			return e["e"]["type"] == "name"
		"tuple", "list":
			for item in e["items"]:
				if not _plain_target(item):
					return false
			return not e["items"].is_empty()
	return false


func _parse_def(ln: Dictionary, indent: int) -> Dictionary:
	var line := _line
	_next()
	var nt := _next()
	if nt["t"] != "name" or nt["v"] in KEYWORDS:
		return _bad("def 뒤에는 함수 이름이 와야 해요. 예: def turn_around():")
	var fname: String = nt["v"]
	if _is_builtin_name(fname) or _module_taken(fname):
		return _bad("'%s' 는 이미 있는 이름이라 새 함수 이름으로 쓸 수 없어요." % fname)
	if not _is_op(_next(), "("):
		return _bad("함수 이름 뒤에 괄호를 붙여 주세요. 예: def %s():" % fname)
	var params: Array = []
	var defaults: Dictionary = {}  # parameter -> default value expression (evaluated at def time)
	var star := ""  # *args
	var dstar := ""  # **kwargs
	while not _is_op(_peek(), ")"):
		var mark := ""
		if _is_op(_peek(), "*") or _is_op(_peek(), "**"):
			mark = _next()["v"]
		var p := _next()
		if p["t"] != "name" or p["v"] in KEYWORDS:
			return _bad("def 괄호 안에는 변수 이름만 적어요. 예: def walk(n):")
		var pname: String = p["v"]
		if pname in params or pname == star or pname == dstar:
			return _bad("같은 이름을 두 번 쓸 수 없어요: '%s'" % pname)
		if dstar != "":
			return _bad("**%s 는 괄호 맨 끝에 적어요." % dstar)
		if _is_op(_peek(), ":"):  # type hint, e.g. def walk(n: int):
			_next()
			_parse_expr()
			if not _error.is_empty():
				return {}
		if mark == "*":
			if star != "":
				return _bad("* 이 붙은 값은 하나만 쓸 수 있어요.")
			star = pname
		elif mark == "**":
			dstar = pname
		else:
			if star != "":
				return _bad("*%s 뒤에는 **이름 만 올 수 있어요." % star)
			params.append(pname)
			if _is_op(_peek(), "="):
				_next()
				defaults[pname] = _parse_expr()
				if not _error.is_empty():
					return {}
			elif not defaults.is_empty():
				return _bad("기본값이 있는 값(%s=...) 뒤에는 기본값 없는 값을 둘 수 없어요." % defaults.keys().back())
		if not _is_op(_peek(), ","):
			break
		_next()
	if not _is_op(_next(), ")"):
		return _bad("괄호 ')' 가 닫히지 않았어요.")
	if _is_op(_peek(), "->"):  # return type hint
		_next()
		_parse_expr()
		if not _error.is_empty():
			return {}
	_expect_colon("def")
	if not _error.is_empty():
		return {}
	var is_method := _in_class
	if is_method and params.is_empty() and star == "":
		return _bad("메서드의 첫 번째 값은 self 예요. 예: def %s(self):" % fname)
	if not is_method:
		_defined[fname] = true
		_note_assign(fname)
	_func_stack.push_back({"assigned": {}, "globals": {}})
	for p in params + [star, dstar]:
		if p != "":
			_note_assign(p)
	var saved_loop := _loop_depth
	_loop_depth = 0
	_in_class = false
	var body := _parse_child_block(ln, indent)
	_in_class = is_method
	_loop_depth = saved_loop
	var scope: Dictionary = _func_stack.pop_back()
	var locals := {}
	for name in scope["assigned"]:
		if not scope["globals"].has(name):
			locals[name] = true
	return {"type": "def", "name": fname, "params": params, "defaults": defaults, "star": star, "dstar": dstar,
			"body": body, "locals": locals, "line": line}


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
			_in_except += 1
			var handler_body := _parse_child_block(next, indent)
			_in_except -= 1
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
	if _is_builtin_name(cname) or _module_taken(cname):
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


## import math / import math as m / import math, random / from math import sqrt, pi / from math import *
func _parse_import() -> Dictionary:
	var line := _line
	var from := _is_word(_next(), "from")
	var items: Array = []  # {"mod", "name" ("" for the module itself, "*" for all), "as"}
	if from:
		var mt := _next()
		if not _module_ok(mt):
			return {}
		var mod: String = mt["v"]
		if not _is_word(_next(), "import"):
			return _bad("from %s import 이름 모양으로 적어요. 예: from math import sqrt" % mod)
		while true:
			var t := _next()
			if _is_op(t, "*"):
				items.append({"mod": mod, "name": "*", "as": ""})
				for nm in MODULES[mod]:
					_note_assign(nm)
				break
			if t["t"] != "name" or not t["v"] in MODULES[mod]:
				return _bad("%s 에는 '%s' 가 없어요. (있는 것: %s)" % [mod, t["v"], ", ".join(PackedStringArray(MODULES[mod]))])
			var alias := _parse_alias(t["v"])
			if alias == "":
				return {}
			items.append({"mod": mod, "name": t["v"], "as": alias})
			if not _is_op(_peek(), ","):
				break
			_next()
		_features[mod] = true
	else:
		while true:
			var t := _next()
			if not _module_ok(t):
				return {}
			var alias := _parse_alias(t["v"])
			if alias == "":
				return {}
			items.append({"mod": t["v"], "name": "", "as": alias})
			_features[t["v"]] = true
			if not _is_op(_peek(), ","):
				break
			_next()
	_expect_end()
	return {"type": "import", "items": items, "line": line}


func _module_ok(t: Dictionary) -> bool:
	if t["t"] != "name":
		_bad("import 뒤에는 모듈 이름을 적어요. 예: import math")
		return false
	if BLOCKED_MODULES.has(t["v"]):
		_bad("'%s' 는 %s이라 이 게임에서는 쓰지 않아요. (쓸 수 있는 모듈: %s)" % [t["v"], BLOCKED_MODULES[t["v"]], ", ".join(PackedStringArray(MODULES.keys()))])
		return false
	if not MODULES.has(t["v"]):
		_bad("가져올 수 있는 모듈은 %s 이에요: '%s'" % [", ".join(PackedStringArray(MODULES.keys())), t["v"]])
		return false
	return true


## The name an import binds: `name`, or the one after "as". "" after an error.
func _parse_alias(name: String) -> String:
	var bound := name
	if _is_word(_peek(), "as"):
		_next()
		var t := _next()
		if t["t"] != "name" or t["v"] in KEYWORDS:
			_bad("as 뒤에는 새 이름을 적어요. 예: import math as m")
			return ""
		bound = t["v"]
	_note_assign(bound)
	return bound


## Assignment or a call on its own line.
func _parse_simple() -> Dictionary:
	var line := _line
	var e := _parse_expr_list()
	if not _error.is_empty():
		return {}
	var t := _peek()
	if _is_op(t, ":") and e["type"] in ["name", "attr", "index"]:  # type hint: x: int = 5
		_next()
		_parse_expr()
		if not _error.is_empty():
			return {}
		if _at_end():
			return {"type": "pass", "line": line}
		t = _peek()
		if not _is_op(t, "="):
			return _bad("이해할 수 없는 줄이에요: %s" % _cur_text)
	if t["t"] == "op" and t["v"] in ASSIGN_OPS:
		var op: String = t["v"]
		if not _check_target(e, op):
			return {}
		_next()
		if _at_end():
			return _bad("'%s' 오른쪽에 값을 적어 주세요." % op)
		var value := _parse_expr_list()
		var more: Array = []  # a = b = 0: every target after the first
		while _error.is_empty() and op == "=" and _is_op(_peek(), "="):
			if not _check_target(value, op):
				return {}
			more.append(value)
			_next()
			if _at_end():
				return _bad("'=' 오른쪽에 값을 적어 주세요.")
			value = _parse_expr_list()
		_expect_end()
		var node := {"type": "assign", "target": e, "op": op, "value": value, "line": line}
		if not more.is_empty():
			node["more"] = more
		return node
	_expect_end()
	if not _error.is_empty():
		return {}
	if e["type"] == "const" and e["v"] is String:
		return {"type": "pass", "line": line}  # a docstring, or a string used as a note
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


## Checks what stands left of `op` (a name, a.b, a[i], a[i:j], or a tuple/list of them with at most
## one *name) and notes the names that get a value. false after recording an error.
func _check_target(e: Dictionary, op: String) -> bool:
	var many: bool = e["type"] in ["tuple", "list"]
	if many and op != "=":
		_bad("여러 변수에 한꺼번에 담을 때는 '=' 만 쓸 수 있어요.")
		return false
	var stars := 0
	for target in (e["items"] if many else [e]):
		var tt: Dictionary = target
		if tt["type"] == "starred" and many:
			stars += 1
			tt = tt["e"]
		match String(tt["type"]):
			"name":
				var name: String = tt["name"]
				if _is_builtin_name(name) or _module_taken(name):
					_bad("'%s' 는 이미 있는 이름이라 변수 이름으로 쓸 수 없어요." % name)
					return false
				_note_assign(name)
			"index", "attr", "slice":
				pass
			"tuple", "list":
				if not _check_target(tt, op):
					return false
			_:
				_bad("'%s' 왼쪽에는 변수 이름이 와야 해요." % op)
				return false
	if stars > 1:
		_bad("* 이 붙은 변수는 하나만 쓸 수 있어요.")
		return false
	return true


# --- Expressions (Python precedence) ----------------------------------------

## An expression, including the conditional form `a if cond else b`.
func _parse_expr() -> Dictionary:
	var e := _parse_or()
	if _error.is_empty() and _is_word(_peek(), "if"):
		_next()
		var cond := _parse_or()
		if _error.is_empty() and not _is_word(_peek(), "else"):
			return _bad("'값 if 조건 else 다른 값' 모양으로 적어요. else 가 빠졌어요.")
		_next()
		var other := _parse_expr()
		return {"type": "ifexp", "cond": cond, "a": e, "b": other}
	return e


## An expression, or *expr (unpacking) where Python allows it: tuples, lists, call arguments, targets.
func _parse_item() -> Dictionary:
	if _is_op(_peek(), "*"):
		_next()
		return {"type": "starred", "e": _parse_or()}
	return _parse_expr()


## An expression, or several separated by commas, which make a tuple: `1, 2` / `x, y`.
func _parse_expr_list() -> Dictionary:
	var first := _parse_item()
	if not _error.is_empty() or not _is_op(_peek(), ","):
		return first
	var items: Array = [first]
	while _error.is_empty() and _is_op(_peek(), ","):
		_next()
		if _at_end() or (_peek()["t"] == "op" and _peek()["v"] in ASSIGN_OPS) or (_no_in and _is_word(_peek(), "in")):
			break
		items.append(_parse_item())
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
		elif _is_word(t, "in") and not _no_in:
			op = "in"
			_next()
		elif _is_word(t, "not") and _is_word(_peek(1), "in") and not _no_in:
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
	var left := _parse_bitxor()
	while _error.is_empty() and _is_op(_peek(), "|"):
		_next()
		left = {"type": "bin", "op": "|", "a": left, "b": _parse_bitxor()}
	return left


## a ^ b (symmetric difference of sets, or bitwise xor on integers).
func _parse_bitxor() -> Dictionary:
	var left := _parse_bitand()
	while _error.is_empty() and _is_op(_peek(), "^"):
		_next()
		left = {"type": "bin", "op": "^", "a": left, "b": _parse_bitand()}
	return left


## a & b (set intersection, or bitwise and on integers).
func _parse_bitand() -> Dictionary:
	var left := _parse_shift()
	while _error.is_empty() and _is_op(_peek(), "&"):
		_next()
		left = {"type": "bin", "op": "&", "a": left, "b": _parse_shift()}
	return left


## a << b, a >> b on integers.
func _parse_shift() -> Dictionary:
	var left := _parse_add()
	while _error.is_empty() and (_is_op(_peek(), "<<") or _is_op(_peek(), ">>")):
		var op: String = _next()["v"]
		left = {"type": "bin", "op": op, "a": left, "b": _parse_add()}
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
	if _is_op(_peek(), "~"):
		_next()
		return {"type": "invert", "e": _parse_unary()}
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
			var kwargs: Dictionary = {}  # name=value arguments, e.g. key=lambda p: p[0]
			var spread: Array = []  # **dict arguments
			if not _is_op(_peek(), ")"):
				while _error.is_empty():
					if _is_op(_peek(), "**"):
						_next()
						spread.append(_parse_expr())
					elif _is_op(_peek(), "*"):
						_next()
						args.append({"type": "starred", "e": _parse_expr()})
					elif _peek()["t"] == "name" and _is_op(_peek(1), "="):
						var kw: String = _next()["v"]
						_next()
						if kwargs.has(kw):
							return _bad("'%s=' 을 두 번 넣었어요." % kw)
						kwargs[kw] = _parse_expr()
					else:
						if not kwargs.is_empty() or not spread.is_empty():
							return _bad("이름 붙은 값(key=...) 뒤에는 이름 없는 값을 쓸 수 없어요.")
						var arg := _parse_expr()
						if _error.is_empty() and _is_word(_peek(), "for"):
							arg = _parse_comp_tail("list", arg, null, "")  # sum(x for x in xs)
						args.append(arg)
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
				if e["name"] == "input":
					_features["input"] = true
				if e["name"] == "input":
					_features["input"] = true
			e = {"type": "call", "fn": e, "args": args, "kwargs": kwargs}
			if not spread.is_empty():
				e["spread"] = spread
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


## The "for x in xs if cond ..." part of a comprehension; `elem` (and `key` for dicts) is already
## parsed. Several for/if clauses nest like Python. `close` is the bracket to consume, or "" when
## the caller does (sum(x for x in xs)).
func _parse_comp_tail(kind: String, elem: Dictionary, key: Variant, close: String) -> Dictionary:
	var clauses: Array = []  # {"target", "iter"} or {"cond"}, outermost first
	while _error.is_empty() and _is_word(_peek(), "for"):
		_next()
		_no_in = true
		var target := _parse_expr_list()
		_no_in = false
		if not _error.is_empty():
			return {}
		if not _plain_target(target):
			return _bad("for 뒤에는 변수 이름이 와야 해요. 예: [x * 2 for x in 목록]")
		if not _is_word(_next(), "in"):
			return _bad("[값 for 이름 in 목록] 모양으로 적어요.")
		clauses.append({"target": target, "iter": _parse_or()})
		while _error.is_empty() and _is_word(_peek(), "if"):
			_next()
			clauses.append({"cond": _parse_or()})
	if not _error.is_empty():
		return {}
	if close != "" and not _is_op(_next(), close):
		return _bad("괄호 '%s' 가 닫히지 않았어요." % close)
	_features["comprehension"] = true
	return {"type": "comp", "kind": kind, "elem": elem, "key": key, "clauses": clauses}


## lambda a, b: expression
func _parse_lambda() -> Dictionary:
	var params: Array = []
	while not _is_op(_peek(), ":"):
		var v := _next()
		if v["t"] != "name" or v["v"] in KEYWORDS:
			return _bad("lambda 뒤에는 이름과 ':' 를 적어요. 예: lambda p: p[0]")
		params.append(v["v"])
		if _is_op(_peek(), ","):
			_next()
	_next()  # :
	var body := _parse_expr()
	_features["lambda"] = true
	return {"type": "lambda", "params": params, "body": body}


## Comma-separated expressions up to (not including) `close`; a trailing comma is allowed.
## Sets _last_items_had_comma so "(x)" and "(x,)" can be told apart.
func _parse_items(close: String) -> Array:
	var items: Array = []
	var had_comma := false
	while _error.is_empty() and not _is_op(_peek(), close):
		items.append(_parse_item())
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
					parts.append({"expr": sub, "spec": part["spec"], "conv": part["conv"], "debug": part["debug"]})
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
			if n == "lambda":
				return _parse_lambda()
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
				var items: Array = []
				if not _is_op(_peek(), "]"):
					var first := _parse_item()
					if _error.is_empty() and _is_word(_peek(), "for") and first["type"] != "starred":
						return _parse_comp_tail("list", first, null, "]")
					items.append(first)
					while _error.is_empty() and _is_op(_peek(), ","):
						_next()
						if _is_op(_peek(), "]"):
							break
						items.append(_parse_item())
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
					if keys.size() == 1 and _is_word(_peek(), "for"):
						return _parse_comp_tail("set", keys[0], null, "}")
					if keys.size() == 1 and not _is_op(_peek(), ":"):
						is_set = true
					if is_set:
						if _is_op(_peek(), ":"):
							return _bad("집합 {a, b} 과 딕셔너리 {키: 값} 을 섞어 쓸 수 없어요.")
					else:
						if not _is_op(_next(), ":"):
							return _bad("딕셔너리는 {\"키\": 값} 모양으로 적어요. 키 뒤에 ':' 가 필요해요.")
						values.append(_parse_expr())
						if keys.size() == 1 and _error.is_empty() and _is_word(_peek(), "for"):
							return _parse_comp_tail("dict", values[0], keys[0], "}")
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
	_scopes = []
	_handling = []
	_out_buf = ""
	await _exec_block(program)
	_flush_output()
	if not _err.is_empty():
		return _err
	return {"ok": true}


## Sends printed text to the host one finished line at a time; the rest waits for a newline.
func _emit(text: String) -> void:
	var lines := (_out_buf + text).split("\n")
	for k in lines.size() - 1:
		_host.print_line(lines[k])
	_out_buf = lines[lines.size() - 1]


func _flush_output() -> void:
	if _out_buf != "":
		_host.print_line(_out_buf)
		_out_buf = ""


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
				if op == "+=" and cur is Array:
					# Like Python, += changes the list itself (other names for it see the change).
					var more = _iter(v, "+= 오른쪽")
					if more == null:
						return Flow.ERROR
					(cur as Array).append_array(more)
					v = cur
				else:
					v = _binop(op.trim_suffix("="), cur, v)
				if not _err.is_empty():
					return Flow.ERROR
			await _store(node["target"], v)
			if not _err.is_empty():
				return Flow.ERROR
			for extra in node.get("more", []):
				await _store(extra, v)
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
			var broke := false
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
					broke = true
					break
				if f == Flow.ERROR or f == Flow.RETURN:
					return f
				_line = int(node["line"])
				if not _tick():
					return Flow.ERROR
			if not broke and not (node["else"] as Array).is_empty():
				return await _exec_block(node["else"])
		"for":
			_host.highlight_line(_line)
			var it = await _eval(node["iter"])
			if not _err.is_empty():
				return Flow.ERROR
			var seq = _iter(it, "for 문의 'in' 뒤")
			if seq == null:
				return Flow.ERROR
			var broke := false
			for item in seq:
				_line = int(node["line"])
				await _store(node["target"], item)
				if not _err.is_empty():
					return Flow.ERROR
				var f: int = await _exec_block(node["body"])
				if f == Flow.BREAK:
					broke = true
					break
				if f == Flow.ERROR or f == Flow.RETURN:
					return f
				_line = int(node["line"])
				if not _tick():
					return Flow.ERROR
			if not broke and not (node["else"] as Array).is_empty():
				return await _exec_block(node["else"])
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
			var defaults_ok: bool = await _eval_defaults(node)
			if not defaults_ok:
				return Flow.ERROR
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
			for it in node["items"]:
				var mod := {"kind": "module", "name": it["mod"]}
				var names: Array = MODULES[it["mod"]] if it["name"] == "*" else [it["name"]]
				for nm in names:
					if nm == "":
						_set_var(it["as"], mod)
						continue
					var v = _attr(mod, nm)
					if not _err.is_empty():
						return Flow.ERROR
					_set_var(nm if it["name"] == "*" else it["as"], v)
		"assert":
			var ok = await _eval(node["cond"])
			if not _err.is_empty():
				return Flow.ERROR
			if not _truthy(ok):
				var text := ""
				if node["msg"] != null:
					var m = await _eval(node["msg"])
					if not _err.is_empty():
						return Flow.ERROR
					text = _str(m)
				_raise("AssertionError: " + (text if text != "" else "assert 로 확인한 조건이 거짓이에요."), "AssertionError")
				_err["text"] = text
				return Flow.ERROR
		"del":
			for tgt in node["targets"]:
				if tgt["type"] == "name":
					_del_var(tgt["name"])
					if not _err.is_empty():
						return Flow.ERROR
					continue
				var obj = await _eval(tgt["obj"])
				if tgt["type"] == "slice":
					var bounds = await _eval_bounds(tgt)
					if bounds == null:
						return Flow.ERROR
					if not obj is Array:
						_raise("del 로 [ : ] 를 지울 수 있는 건 목록이에요.")
						return Flow.ERROR
					var picked = _slice_indices((obj as Array).size(), bounds[0], bounds[1], bounds[2])
					if picked == null:
						return Flow.ERROR
					picked.sort()
					for k in range(picked.size() - 1, -1, -1):
						(obj as Array).remove_at(picked[k])
					continue
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
						var caught := _err
						_err = {}
						_line = int(h["line"])
						_host.highlight_line(_line)
						if h["bind"] != "":
							_set_var(h["bind"], caught.get("text", caught.get("message", "")))
						_handling.push_back(caught)
						f = await _exec_block(h["body"])
						_handling.pop_back()
						break
			if not (node["finally"] as Array).is_empty() and not _err.get("stopped", false):
				var saved := _err
				_err = {}
				var ff: int = await _exec_block(node["finally"])
				if ff != Flow.NORMAL:
					return ff
				_err = saved
			return f
		"raise":
			if node["name"] == "":
				if _handling.is_empty():
					_raise("다시 던질 오류가 없어요.")
				else:
					_err = (_handling.back() as Dictionary).duplicate()
					_err["line"] = _line
				return Flow.ERROR
			var text: String = node["name"]
			if node["msg"] != null:
				var m = await _eval(node["msg"])
				if not _err.is_empty():
					return Flow.ERROR
				text = _str(m)
			_raise("%s: %s" % [node["name"], text] if node["msg"] != null else text, node["name"])
			_err["text"] = text
			return Flow.ERROR
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
						var defaults_ok: bool = await _eval_defaults(st)
						if not defaults_ok:
							return Flow.ERROR
						cls["methods"][st["name"]] = st
					"assign":
						_line = int(st["line"])
						var v = await _eval(st["value"])
						if not _err.is_empty():
							return Flow.ERROR
						cls["attrs"][st["target"]["name"]] = v
			_set_var(node["name"], cls)
	return Flow.ERROR if not _err.is_empty() else Flow.NORMAL


## Evaluates a def's default values once, when the def runs (like Python), into node["default_values"].
func _eval_defaults(node: Dictionary) -> bool:
	var out := {}
	var defs: Dictionary = node.get("defaults", {})
	for p in defs:
		out[p] = await _eval(defs[p])
		if not _err.is_empty():
			return false
	node["default_values"] = out
	return true


func _del_var(name: String) -> void:
	if not _frames.is_empty() and _frames.back()["vars"].has(name):
		_frames.back()["vars"].erase(name)
	elif _globals.has(name):
		_globals.erase(name)
	else:
		_raise("아직 만들지 않은 변수예요: '%s'" % name, "NameError")


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
	for k in range(_scopes.size() - 1, -1, -1):
		if _scopes[k].has(name):
			return _scopes[k][name]
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
	match String(target["type"]):
		"name":
			_set_var(target["name"], v)
			return
		"tuple", "list":
			var targets: Array = target["items"]
			var parts = _split_for(targets, v)
			if parts == null:
				return
			for k in targets.size():
				var tk: Dictionary = targets[k]
				await _store(tk["e"] if tk["type"] == "starred" else tk, parts[k])
				if not _err.is_empty():
					return
			return
		"starred":
			_raise("* 이 붙은 변수는 'a, *rest = 목록' 처럼 여러 변수 사이에 써요.")
			return
		"attr":
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
		"slice":
			var obj = await _eval(target["obj"])
			var bounds = await _eval_bounds(target)
			if bounds == null:
				return
			if not obj is Array:
				_raise("[ : ] 로 값을 바꿀 수 있는 건 목록이에요.")
				return
			var items = _iter(v, "[ : ] 에 넣을 값")
			if items == null:
				return
			var list: Array = obj
			if bounds[2] == null or bounds[2] == 1:
				var n := list.size()
				var lo := 0 if bounds[0] == null else _clamp_index(bounds[0], n)
				var hi := n if bounds[1] == null else maxi(lo, _clamp_index(bounds[1], n))
				list.assign(list.slice(0, lo) + items + list.slice(hi))
				return
			var picked = _slice_indices(list.size(), bounds[0], bounds[1], bounds[2])
			if picked == null:
				return
			if picked.size() != items.size():
				_raise("자른 칸 수(%d)와 넣을 값의 수(%d)가 같아야 해요." % [picked.size(), items.size()], "ValueError")
				return
			for k in picked.size():
				list[picked[k]] = items[k]
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
	if _is_kind(obj, "deque"):
		obj = obj["items"]
	if not obj is Array:
		_raise("[ ] 로 값을 바꿀 수 있는 건 목록과 딕셔너리예요.")
		return
	var i := _index_of(obj, idx)
	if _err.is_empty():
		obj[i] = v


## The values for `targets` (a, b / a, *rest, b) taken from `v`, or null with an error.
func _split_for(targets: Array, v: Variant) -> Variant:
	var star := -1
	for k in targets.size():
		if targets[k]["type"] == "starred":
			star = k
	if star < 0:
		return _unpack(v, targets.size())
	var items = _iter(v, "여러 변수에 나눠 담을 값")
	if items == null:
		return null
	if items.size() < targets.size() - 1:
		_raise("값 %d개를 변수 %d개에 나눠 담을 수 없어요: %s" % [items.size(), targets.size(), _repr(v)], "ValueError")
		return null
	var after := targets.size() - 1 - star
	var middle: Array = items.slice(star, items.size() - after)
	return items.slice(0, star) + [middle] + items.slice(items.size() - after)


## Evaluates a slice's start, stop and step (null where left out). null with an error.
func _eval_bounds(e: Dictionary) -> Variant:
	var bounds: Array = []
	for key in ["start", "stop", "step"]:
		bounds.append(null if e[key] == null else await _eval(e[key]))
	if not _err.is_empty():
		return null
	for b in bounds:
		if b != null and typeof(b) != TYPE_INT:
			_raise("[ : ] 안에는 정수를 적어요 (지금: %s)." % _repr(b))
			return null
	return bounds


static func _clamp_index(i: int, n: int) -> int:
	return clampi(i + n if i < 0 else i, 0, n)


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
	if _is_kind(v, "tuple") or _is_kind(v, "deque"):
		return (v["items"] as Array).duplicate()
	if _is_kind(v, "dict"):
		return _dict_keys(v)
	if _is_kind(v, "set"):
		return (v["data"] as Dictionary).values()
	if _is_kind(v, "iterator"):  # takes what is left, like Python
		var rest: Array = (v["items"] as Array).slice(int(v["pos"]))
		v["pos"] = (v["items"] as Array).size()
		return rest
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


# --- Formatting (f-strings, format(), str.format(), "%d" % x) --------------------

## Python's format(value, spec) with the format-spec mini-language:
## [[fill]align][sign][#][0][width][,|_][.precision][type], type one of s d f F % e E g G x X o b c.
## Returns the text, or null with a ValueError.
func _format_value(v: Variant, spec: String) -> Variant:
	if spec == "":
		return _str(v)
	var f = _parse_spec(spec)
	if f == null:
		_raise("형식 '%s' 을 이해할 수 없어요. 예: {값:>5}  {값:.2f}  {값:,}  {값:03d}" % spec, "ValueError")
		return null
	var kind: String = f["type"]
	var prec: int = f["prec"]
	if not _is_num(v):
		if kind != "" and kind != "s":
			_raise("형식 '%s' 는 숫자에만 쓸 수 있어요 (지금: %s)." % [kind, _repr(v)], "ValueError")
			return null
		var text := _str(v)
		if prec >= 0:
			text = text.left(prec)
		return _pad(text, f, false, "")
	if kind == "s":
		_raise("형식 's' 는 글자에만 써요 (지금: %s). str() 로 바꾸거나 형식을 지워 보세요." % _repr(v), "ValueError")
		return null
	var x = _num(v)
	var negative := false
	var body := ""
	var prefix := ""
	if kind in ["d", "x", "X", "o", "b", "c", "n"] or (kind == "" and typeof(x) == TYPE_INT and prec < 0):
		if typeof(x) != TYPE_INT:
			_raise("형식 '%s' 는 정수에만 쓸 수 있어요 (지금: %s). int() 로 바꿔 보세요." % [kind, _repr(v)], "ValueError")
			return null
		if kind == "c":
			return _pad(String.chr(x), f, false, "")
		negative = x < 0
		var mag: int = absi(x)
		match kind:
			"x", "X":
				body = _to_base(mag, 16)
			"o":
				body = _to_base(mag, 8)
			"b":
				body = _to_base(mag, 2)
			_:
				body = str(mag)
		if kind == "X":
			body = body.to_upper()
		if f["alt"] and kind in ["x", "X", "o", "b"]:
			prefix = "0" + kind
	else:
		var fx := float(x)
		negative = fx < 0.0
		var a := absf(fx)
		var p := 6 if prec < 0 else prec
		match kind:
			"f", "F":
				body = _fixed(a, p)
			"%":
				body = _fixed(a * 100.0, p) + "%"
			"e", "E":
				body = _sci(a, p)
			"g", "G":
				body = _general(a, maxi(p, 1), f["alt"])
			_:
				body = _repr(a) if prec < 0 else _general(a, maxi(prec, 1), false)
		if kind in ["E", "G", "F"]:
			body = body.to_upper()
	if f["group"] != "":
		body = _group_digits(body, f["group"])
	var sign := "-" if negative else ("+" if f["sign"] == "+" else (" " if f["sign"] == " " else ""))
	return _pad(body, f, true, sign + prefix)


## A format spec split into its parts, or null when it is not valid.
static func _parse_spec(spec: String) -> Variant:
	var f := {"fill": " ", "align": "", "sign": "", "alt": false, "zero": false, "width": 0, "group": "", "prec": -1, "type": ""}
	var i := 0
	var n := spec.length()
	if n >= 2 and spec[1] in ["<", ">", "^", "="]:
		f["fill"] = spec[0]
		f["align"] = spec[1]
		i = 2
	elif n >= 1 and spec[0] in ["<", ">", "^", "="]:
		f["align"] = spec[0]
		i = 1
	if i < n and spec[i] in ["+", "-", " "]:
		f["sign"] = spec[i]
		i += 1
	if i < n and spec[i] == "#":
		f["alt"] = true
		i += 1
	if i < n and spec[i] == "0":
		f["zero"] = true
		i += 1
	var w := ""
	while i < n and _is_digit(spec[i]):
		w += spec[i]
		i += 1
	if w != "":
		f["width"] = w.to_int()
	if i < n and spec[i] in [",", "_"]:
		f["group"] = spec[i]
		i += 1
	if i < n and spec[i] == ".":
		i += 1
		var p := ""
		while i < n and _is_digit(spec[i]):
			p += spec[i]
			i += 1
		if p == "":
			return null
		f["prec"] = p.to_int()
	if i < n:
		f["type"] = spec[i]
		i += 1
	if i != n or not f["type"] in ["", "s", "d", "n", "f", "F", "%", "e", "E", "g", "G", "x", "X", "o", "b", "c"]:
		return null
	return f


## Pads `text` (after `lead`, the sign and 0x prefix) to the spec's width.
static func _pad(text: String, f: Dictionary, numeric: bool, lead: String) -> String:
	var align: String = f["align"]
	var fill: String = f["fill"]
	if f["zero"] and align == "":
		fill = "0"
		align = "=" if numeric else "<"
	if align == "":
		align = ">" if numeric else "<"
	var gap: int = int(f["width"]) - lead.length() - text.length()
	if gap <= 0:
		return lead + text
	match align:
		"<":
			return lead + text + fill.repeat(gap)
		"^":
			var left := floori(gap / 2.0)
			return fill.repeat(left) + lead + text + fill.repeat(gap - left)
		"=":
			return lead + fill.repeat(gap) + text
	return fill.repeat(gap) + lead + text


static func _fixed(a: float, places: int) -> String:
	return ("%." + str(places) + "f") % a


## a in scientific notation with `places` digits after the point: 1.50e+03.
static func _sci(a: float, places: int) -> String:
	var e := _exp10(a)
	var mant := _fixed(a / pow(10.0, e), places) if a != 0.0 else _fixed(0.0, places)
	if mant.to_float() >= 10.0:
		e += 1
		mant = _fixed(a / pow(10.0, e), places)
	return mant + "e" + ("-" if e < 0 else "+") + ("%02d" % absi(e))


## The 'g' format: `digits` significant digits, fixed or scientific, trailing zeros removed.
static func _general(a: float, digits: int, keep_zeros: bool) -> String:
	var e := _exp10(_sci(a, digits - 1).to_float())  # after rounding: 999999.9 -> 1e+06
	var text := ""
	if e < -4 or e >= digits:
		text = _sci(a, digits - 1)
		if not keep_zeros:
			var at := text.find("e")
			text = _trim_zeros(text.left(at)) + text.substr(at)
	else:
		text = _fixed(a, maxi(0, digits - 1 - e))
		if not keep_zeros:
			text = _trim_zeros(text)
	return text


## The power of ten of a (a >= 0): 1234.5 -> 3, 0.05 -> -2, 0 -> 0.
static func _exp10(a: float) -> int:
	if a == 0.0:
		return 0
	var e := floori(log(a) / log(10.0))
	if pow(10.0, e + 1) <= a:
		e += 1
	elif pow(10.0, e) > a:
		e -= 1
	return e


static func _trim_zeros(text: String) -> String:
	if not text.contains("."):
		return text
	return text.rstrip("0").trim_suffix(".")


## Puts `sep` between every three digits of the integer part: 1234567.5 -> 1,234,567.5
static func _group_digits(text: String, sep: String) -> String:
	var end := 0
	while end < text.length() and _is_digit(text[end]):
		end += 1
	var digits := text.left(end)
	var out := ""
	for k in digits.length():
		if k > 0 and (digits.length() - k) % 3 == 0:
			out += sep
		out += digits[k]
	return out + text.substr(end)


static func _to_base(n: int, base: int) -> String:
	if n == 0:
		return "0"
	var out := ""
	while n > 0:
		out = "0123456789abcdefghijklmnopqrstuvwxyz"[n % base] + out
		n = floori(n / float(base))
	return out


## int("ff", 16): text in `base` (0 = from its 0x/0o/0b prefix), or null with a ValueError.
func _int_from_text(v: Variant, base_v: Variant) -> Variant:
	if not v is String:
		_raise("int(값, 진법) 의 값은 글자여야 해요 (지금: %s)." % _repr(v))
		return null
	if not _need_int("int", base_v):
		return null
	var base := int(base_v)
	var text := String(v).strip_edges().to_lower().replace("_", "")
	var negative := text.begins_with("-")
	if text.begins_with("-") or text.begins_with("+"):
		text = text.substr(1)
	var prefixes := {"0x": 16, "0o": 8, "0b": 2}
	var head := text.left(2)
	if prefixes.has(head) and (base == 0 or base == prefixes[head]):
		base = prefixes[head]
		text = text.substr(2)
	elif base == 0:
		base = 10
	if base < 2 or base > 36:
		_raise("진법은 2부터 36까지예요 (지금: %d)." % base, "ValueError")
		return null
	var n = _parse_int_base(text, base)
	if n == null:
		_raise("%d진수로 읽을 수 없는 글자예요: %s" % [base, _repr(v)], "ValueError")
		return null
	return -int(n) if negative else n


## "text %s, %d개" % values: old-style formatting with %s %r %d %i %f %e %g %x %o %c %%,
## flags - + 0 # space, a width and a .precision. null with an error.
func _percent_format(fmt: String, v: Variant) -> Variant:
	var values: Array = v["items"] if _is_kind(v, "tuple") else [v]
	var out := ""
	var used := 0
	var i := 0
	var n := fmt.length()
	while i < n:
		var c := fmt[i]
		if c != "%":
			out += c
			i += 1
			continue
		i += 1
		var flags := ""
		while i < n and fmt[i] in ["-", "+", "0", " ", "#"]:
			flags += fmt[i]
			i += 1
		var width := ""
		while i < n and _is_digit(fmt[i]):
			width += fmt[i]
			i += 1
		var prec := ""
		if i < n and fmt[i] == ".":
			prec = "."
			i += 1
			while i < n and _is_digit(fmt[i]):
				prec += fmt[i]
				i += 1
			if prec == ".":
				prec = ".0"
		if i >= n:
			_raise("'%' 뒤에 형식 글자(s, d, f ...)가 빠졌어요.", "ValueError")
			return null
		var kind := fmt[i]
		i += 1
		if kind == "%":
			out += "%"
			continue
		if used >= values.size():
			_raise("서식 칸(%s, %d 같은 것)이 넣은 값보다 많아요.", "TypeError")
			return null
		var val = values[used]
		used += 1
		var spec := "<" if flags.contains("-") else ""
		if flags.contains("+"):
			spec += "+"
		elif flags.contains(" "):
			spec += " "
		if flags.contains("#"):
			spec += "#"
		if flags.contains("0") and not flags.contains("-"):
			spec += "0"
		spec += width
		var piece = null
		match kind:
			"s", "r", "a":
				var text := _str(val) if kind == "s" else _repr(val)
				if prec != "":
					text = text.left(prec.substr(1).to_int())
				piece = _pad(text, {"fill": " ", "align": "<" if flags.contains("-") else ">", "zero": false, "width": width.to_int()}, false, "")
			"d", "i", "u":
				if not _is_num(val):
					_raise("%%d 에는 숫자를 넣어요 (지금: %s)." % _repr(val), "TypeError")
					return null
				piece = _format_value(int(val), spec + "d")
			"f", "F", "e", "E", "g", "G":
				if not _is_num(val):
					_raise("%%%s 에는 숫자를 넣어요 (지금: %s)." % [kind, _repr(val)], "TypeError")
					return null
				piece = _format_value(float(val), spec + prec + kind)
			"x", "X", "o", "c":
				piece = _format_value(val, spec + kind)
			_:
				_raise("모르는 서식 글자예요: %%%s" % kind, "ValueError")
				return null
		if piece == null:
			return null
		out += piece
	if used < values.size():
		_raise("넣은 값이 서식 칸(%s, %d 같은 것)보다 많아요.", "TypeError")
		return null
	return out


## "{} 님, {0} {name:>5}".format(...): fields {} {0} {name} with !r / !s and :spec.
func _str_format(s: String, args: Array, kwargs: Dictionary) -> Variant:
	var out := ""
	var auto := 0
	var i := 0
	var n := s.length()
	while i < n:
		var c := s[i]
		if (c == "{" or c == "}") and s.substr(i + 1, 1) == c:
			out += c
			i += 2
			continue
		if c == "}":
			_raise("'}' 가 혼자 있어요. 글자 '}' 를 쓰려면 }} 로 적어요.", "ValueError")
			return null
		if c != "{":
			out += c
			i += 1
			continue
		var close := s.find("}", i)
		if close < 0:
			_raise("'{' 가 '}' 로 닫히지 않았어요.", "ValueError")
			return null
		var field := s.substr(i + 1, close - i - 1)
		i = close + 1
		var spec := ""
		var conv := ""
		var colon := field.find(":")
		if colon >= 0:
			spec = field.substr(colon + 1)
			field = field.left(colon)
		var bang := field.find("!")
		if bang >= 0:
			conv = field.substr(bang + 1)
			field = field.left(bang)
		var v = null
		if field == "":
			if auto >= args.size():
				_raise("{} 칸이 format() 에 넣은 값보다 많아요.", "IndexError")
				return null
			v = args[auto]
			auto += 1
		elif field.is_valid_int():
			var k := field.to_int()
			if k < 0 or k >= args.size():
				_raise("format() 에 %d번 값이 없어요 (값은 %d개, 번호는 0부터)." % [k, args.size()], "IndexError")
				return null
			v = args[k]
		elif kwargs.has(field):
			v = kwargs[field]
		else:
			_raise("format() 에 '%s=' 값을 넣지 않았어요." % field, "KeyError")
			return null
		if conv == "r":
			v = _repr(v)
		elif conv == "s":
			v = _str(v)
		var text = _format_value(v, spec)
		if text == null:
			return null
		out += text
	return out


## isinstance(v, t): t is int/str/... or a class, or a tuple of them. null with an error.
func _isinstance(v: Variant, t: Variant) -> Variant:
	if _is_kind(t, "tuple"):
		for x in t["items"]:
			var r = _isinstance(v, x)
			if r == null or r:
				return r
		return false
	if _is_kind(t, "class"):
		if not _is_kind(v, "instance"):
			return false
		var c = v["cls"]
		while c != null:
			if is_same(c, t):
				return true
			c = c["base"]
		return false
	if _is_kind(t, "builtin") and t["name"] in TYPE_NAMES:
		var actual := _py_type(v)
		return actual == t["name"] or (t["name"] == "int" and actual == "bool")
	_raise("isinstance() 의 두 번째 값은 int, str 같은 자료형이나 class 예요 (지금: %s)." % _repr(t))
	return null


## The Python type name of a value: int, str, list, ...
static func _py_type(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "NoneType"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "str"
		TYPE_ARRAY:
			return "list"
	var kind: String = v.get("kind", "") if v is Dictionary else ""
	match kind:
		"dict":
			return "Counter" if v.get("counter", false) else ("defaultdict" if v.has("factory") else "dict")
		"tuple", "set", "module", "iterator", "deque":
			return kind
		"class":
			return "type"
		"robot":
			return "Robot"
		"builtin":
			return "type" if v["name"] in TYPE_NAMES else "function"
		"instance":
			return v["cls"]["name"]
	return "function"


## The positions seq[start:stop:step] picks from a sequence of length `n` (any part may be null),
## or null with an error.
func _slice_indices(n: int, start: Variant, stop: Variant, step: Variant) -> Variant:
	for b in [start, stop, step]:
		if b != null and typeof(b) != TYPE_INT:
			_raise("[ : ] 안에는 정수를 적어요 (지금: %s)." % _repr(b))
			return null
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
		picked.append(i)
		i += st
	return picked


## Python slicing for lists, tuples and strings: s[start:stop:step], any part may be None.
func _slice(obj: Variant, start: Variant, stop: Variant, step: Variant) -> Variant:
	var seq = obj["items"] if _is_kind(obj, "tuple") else obj
	if not (seq is Array or seq is String):
		_raise("[ : ] 로 자를 수 있는 건 목록, 튜플, 글자예요.")
		return null
	var n: int = seq.size() if seq is Array else String(seq).length()
	var at = _slice_indices(n, start, stop, step)
	if at == null:
		return null
	var picked: Array = []
	for i in at:
		picked.append(seq[i])
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
			var out = await _eval_items(e["items"])
			if out == null:
				return null
			return out if e["type"] == "list" else _tuple(out)
		"starred":
			_raise("'*' 는 목록, 튜플, 함수의 괄호 안에서 값을 풀어 넣을 때 써요. 예: print(*목록)")
			return null
		"ifexp":
			var c = await _eval(e["cond"])
			if not _err.is_empty():
				return null
			return await _eval(e["a"] if _truthy(c) else e["b"])
		"invert":
			var v = await _eval(e["e"])
			if not _err.is_empty():
				return null
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_BOOL:
				_raise("'~' 는 정수 앞에만 붙여요 (지금: %s)." % _repr(v))
				return null
			return ~int(v)
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
				match String(part.get("conv", "")):
					"r", "a":
						v = _repr(v)
					"s":
						v = _str(v)
				var text = _format_value(v, part["spec"])
				if text == null:
					return null
				out += String(part.get("debug", "")) + text
			return out
		"slice":
			var obj = await _eval(e["obj"])
			var bounds = await _eval_bounds(e)
			if bounds == null:
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
					if obj.get("counter", false):
						return 0  # a Counter counts a missing key as 0
					if obj.get("factory") != null:  # defaultdict makes the missing value
						var made = await _call(obj["factory"], [])
						if not _err.is_empty():
							return null
						obj["data"][k] = [idx, made]
						return made
					_raise("딕셔너리에 %s 키가 없어요. 없을 수도 있는 키는 .get(키, 기본값) 으로 꺼내요." % _repr(idx), "KeyError")
					return null
				return obj["data"][k][1]
			if _is_kind(obj, "tuple") or _is_kind(obj, "deque"):
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
			var args = await _eval_items(e["args"])
			if args == null:
				return null
			var kwargs := {}
			for kw in e.get("kwargs", {}):
				kwargs[kw] = await _eval(e["kwargs"][kw])
				if not _err.is_empty():
					return null
			for d in e.get("spread", []):  # f(**options)
				var dv = await _eval(d)
				if not _err.is_empty():
					return null
				if not _is_kind(dv, "dict"):
					_raise("** 뒤에는 딕셔너리를 적어요 (지금: %s)." % _repr(dv))
					return null
				for pair in dv["data"].values():
					if not pair[0] is String:
						_raise("** 로 넣는 딕셔너리의 키는 글자여야 해요 (지금: %s)." % _repr(pair[0]))
						return null
					if kwargs.has(pair[0]):
						_raise("'%s' 값을 두 번 넣었어요." % pair[0])
						return null
					kwargs[pair[0]] = pair[1]
			return await _call(fn, args, kwargs)
		"comp":
			return await _eval_comp(e)
		"lambda":
			return {"kind": "lambda", "node": e}
	return null


## Values of list/tuple items or call arguments; *x items are spread out. null with an error.
func _eval_items(items: Array) -> Variant:
	var out: Array = []
	for item in items:
		if item["type"] == "starred":
			var v = await _eval(item["e"])
			if not _err.is_empty():
				return null
			var spread = _iter(v, "* 뒤")
			if spread == null:
				return null
			out.append_array(spread)
			continue
		var v = await _eval(item)
		if not _err.is_empty():
			return null
		out.append(v)
	return out


## [elem for x in xs if cond ...], {elem ...} (set) or {key: elem ...} (dict). The loop variables
## live in their own scope, like Python 3, so they do not overwrite variables outside.
func _eval_comp(e: Dictionary) -> Variant:
	var out: Variant = [] if e["kind"] == "list" else (_new_set() if e["kind"] == "set" else _new_dict())
	var scope := {}
	_scopes.push_back(scope)
	await _comp_clause(e, 0, out, scope)
	_scopes.pop_back()
	return null if not _err.is_empty() else out


## Runs clause `at` of a comprehension (a for or an if); past the last clause, adds one element.
func _comp_clause(e: Dictionary, at: int, out: Variant, scope: Dictionary) -> void:
	var clauses: Array = e["clauses"]
	if at == clauses.size():
		var v = await _eval(e["elem"])
		if not _err.is_empty():
			return
		match String(e["kind"]):
			"list":
				if (out as Array).size() >= MAX_LIST:
					_raise("목록이 너무 커요.")
					return
				out.append(v)
			"set":
				_set_add(out, v)
			"dict":
				var k = await _eval(e["key"])
				if _err.is_empty():
					_dict_set(out, k, v)
		return
	var cl: Dictionary = clauses[at]
	if cl.has("cond"):
		var ok = await _eval(cl["cond"])
		if _err.is_empty() and _truthy(ok):
			await _comp_clause(e, at + 1, out, scope)
		return
	var src = await _eval(cl["iter"])
	if not _err.is_empty():
		return
	var seq = _iter(src, "for ... in 뒤")
	if seq == null:
		return
	for item in seq:
		if not _tick():
			return
		_bind_scope(cl["target"], item, scope)
		if not _err.is_empty():
			return
		await _comp_clause(e, at + 1, out, scope)
		if not _err.is_empty():
			return


## Puts `v` into comprehension variables: a name, or a tuple/list of names (with one *name).
func _bind_scope(target: Dictionary, v: Variant, scope: Dictionary) -> void:
	match String(target["type"]):
		"name":
			scope[target["name"]] = v
		"tuple", "list":
			var targets: Array = target["items"]
			var parts = _split_for(targets, v)
			if parts == null:
				return
			for k in targets.size():
				var tk: Dictionary = targets[k]
				_bind_scope(tk["e"] if tk["type"] == "starred" else tk, parts[k], scope)


func _call(fn: Variant, args: Array, kwargs: Dictionary = {}) -> Variant:
	if not (fn is Dictionary and (fn as Dictionary).has("kind")):
		_raise("부를 수 있는 함수가 아니에요: %s" % _repr(fn))
		return null
	var kind := String(fn["kind"])
	if not kwargs.is_empty() and not kind in ["builtin", "method", "func", "bound", "class", "modfn"]:
		_raise("이 함수에는 이름 붙은 값(%s=...)을 넣을 수 없어요." % kwargs.keys()[0])
		return null
	match kind:
		"builtin":
			return await _call_builtin(fn["name"], args, kwargs)
		"modfn":
			return await _call_module(fn["mod"], fn["name"], args, kwargs)
		"method":
			return await _call_method(fn["obj"], fn["name"], args, kwargs)
		"func":
			return await _call_func(fn["node"], args, fn.get("cls"), kwargs)
		"bound":
			return await _call_func(fn["fn"], [fn["self"]] + args, fn["cls"], kwargs)
		"lambda":
			var node: Dictionary = fn["node"]
			var params: Array = node["params"]
			if args.size() != params.size():
				_raise("lambda 에는 값 %d개를 넣어야 해요 (지금 %d개)." % [params.size(), args.size()])
				return null
			var scope := {}
			for i in params.size():
				scope[params[i]] = args[i]
			_scopes.push_back(scope)
			var result = await _eval(node["body"])
			_scopes.pop_back()
			return result
		"class":
			return await _instantiate(fn, args, kwargs)
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
		if name == "say":
			host_args = [_str(args[0])]  # say(100.0) says "100.0", like print
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
	if _is_kind(v, "tuple") or _is_kind(v, "deque"):
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


func _instantiate(cls: Dictionary, args: Array, kwargs: Dictionary = {}) -> Variant:
	var inst := {"kind": "instance", "cls": cls, "fields": {}}
	var init := _find_method(cls, "__init__")
	if init.is_empty():
		if not args.is_empty() or not kwargs.is_empty():
			_raise("'%s' 에는 __init__ 메서드가 없어서 괄호 안에 값을 넣을 수 없어요." % cls["name"])
			return null
		return inst
	await _call_func(init["node"], [inst] + args, init["cls"], kwargs)
	return null if not _err.is_empty() else inst


## The local variables for calling `node`: positional values, name=value values, defaults,
## *args (a tuple) and **kwargs (a dict). null with an error.
func _bind_args(node: Dictionary, args: Array, kwargs: Dictionary, owner: Variant) -> Variant:
	var params: Array = node["params"]
	var defaults: Dictionary = node.get("default_values", {})
	var star: String = node.get("star", "")
	var dstar: String = node.get("dstar", "")
	var fname: String = node["name"]
	if args.size() > params.size() and star == "":
		_arity_error(node, args.size(), owner)
		return null
	var vars := {}
	for i in mini(args.size(), params.size()):
		vars[params[i]] = args[i]
	if star != "":
		vars[star] = _tuple(args.slice(params.size()))
	var extra := _new_dict()
	for kw in kwargs:
		if kw in params:
			if vars.has(kw):
				_raise("'%s' 값을 두 번 넣었어요." % kw)
				return null
			vars[kw] = kwargs[kw]
		elif dstar != "":
			_dict_set(extra, kw, kwargs[kw])
		else:
			_raise("'%s' 에는 '%s' 라는 이름의 값이 없어요." % [fname, kw])
			return null
	for p in params:
		if vars.has(p):
			continue
		if defaults.has(p):
			vars[p] = defaults[p]
		elif kwargs.is_empty() and defaults.is_empty():
			_arity_error(node, args.size(), owner)
			return null
		else:
			_raise("'%s' 함수에 '%s' 값이 빠졌어요." % [fname, p])
			return null
	if dstar != "":
		vars[dstar] = extra
	return vars


func _arity_error(node: Dictionary, given: int, owner: Variant) -> void:
	var params: Array = node["params"]
	var skip := 1 if owner != null else 0
	var most := params.size() - skip
	var least := most - (node.get("default_values", {}) as Dictionary).size()
	var amount := "%d개" % most if least == most else "%d~%d개" % [least, most]
	if node.get("star", "") != "":
		amount = "%d개 이상" % least
	if owner != null:
		_raise("'%s' 메서드에는 self 말고 값 %s를 넣어야 해요 (지금 %d개)." % [node["name"], amount, given - skip])
	else:
		_raise("'%s' 함수에는 값 %s를 넣어야 해요 (지금 %d개)." % [node["name"], amount, given])


## `owner` is the class that defines the method (null for plain functions); it makes super() work.
func _call_func(node: Dictionary, args: Array, owner: Variant = null, kwargs: Dictionary = {}) -> Variant:
	var bound = _bind_args(node, args, kwargs, owner)
	if bound == null:
		return null
	if _depth >= MAX_DEPTH:
		_raise("함수가 너무 깊이 불렸어요. 자기 자신을 끝없이 부르고 있지 않은지 확인해 보세요.", "Fatal")
		return null
	var vars: Dictionary = bound
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


func _call_builtin(name: String, args: Array, kwargs: Dictionary = {}) -> Variant:
	var allowed: Array = BUILTIN_KWARGS.get(name, [])
	for kw in kwargs:
		if not kw in allowed:
			_raise("'%s()' 에는 '%s=' 을 쓸 수 없어요.%s" % [name, kw, "" if allowed.is_empty() else " (쓸 수 있는 것: %s)" % ", ".join(allowed)])
			return null
	if name in COMMANDS or name in CONDITIONS or name in SENSORS:
		return await _robot_call(name, 0, args)
	match name:
		"_count_of":
			return args[0]["items"][1]
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
			var sep = kwargs.get("sep")
			var end = kwargs.get("end")
			_emit((" " if sep == null else _str(sep)).join(parts) + ("\n" if end == null else _str(end)))
			return null
		"input":
			if not _need_args(name, args, 0, 1):
				return null
			var prompt := _out_buf + ("" if args.is_empty() else _str(args[0]))
			_out_buf = ""
			var answer = null
			if _host.has_method("input_line"):
				answer = await _host.input_line(prompt)
			if _host.is_stop_requested():
				_stop()
				return null
			if answer == null:
				_raise("더 받을 입력이 없어요. input() 을 준비된 대답보다 많이 불렀어요.", "EOFError")
				return null
			return str(answer)
		"bool":
			if not _need_args(name, args, 0, 1):
				return null
			return false if args.is_empty() else _truthy(args[0])
		"any", "all":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "%s() 안" % name)
			if items == null:
				return null
			for x in items:
				var t := _truthy(x)
				if name == "any" and t:
					return true
				if name == "all" and not t:
					return false
			return name == "all"
		"map":
			if args.size() < 2:
				_raise("map() 에는 함수와 목록을 넣어요. 예: map(abs, 목록)")
				return null
			var lists: Array = []
			var n := MAX_LIST
			for a in args.slice(1):
				var items = _iter(a, "map() 안")
				if items == null:
					return null
				lists.append(items)
				n = mini(n, items.size())
			var out: Array = []
			for i in n:
				var r = await _call(args[0], lists.map(func(l: Array) -> Variant: return l[i]))
				if not _err.is_empty():
					return null
				out.append(r)
			return out
		"filter":
			if not _need_args(name, args, 2):
				return null
			var items = _iter(args[1], "filter() 안")
			if items == null:
				return null
			var out: Array = []
			for x in items:
				var keep = x
				if args[0] != null:
					keep = await _call(args[0], [x])
					if not _err.is_empty():
						return null
				if _truthy(keep):
					out.append(x)
			return out
		"reversed":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "reversed() 안")
			if items == null:
				return null
			items.reverse()
			return items
		"divmod":
			if not (_need_args(name, args, 2) and _need_num(name, args[0]) and _need_num(name, args[1])):
				return null
			var q = _binop("//", args[0], args[1])
			if not _err.is_empty():
				return null
			return _tuple([q, _binop("%", args[0], args[1])])
		"pow":
			if not _need_args(name, args, 2, 3):
				return null
			if args.size() == 3:
				if not (_need_int(name, args[0]) and _need_int(name, args[1]) and _need_int(name, args[2])):
					return null
				var m := int(args[2])
				if m == 0:
					_raise("pow(a, b, m) 의 m 은 0이 될 수 없어요.", "ValueError")
					return null
				var r := 1
				var base := posmod(int(args[0]), m)
				var e := int(args[1])
				while e > 0:
					if e % 2 == 1:
						r = posmod(r * base, m)
					base = posmod(base * base, m)
					e = e >> 1
				return r
			return _binop("**", args[0], args[1])
		"ord":
			if not _need_args(name, args, 1):
				return null
			if not (args[0] is String and String(args[0]).length() == 1):
				_raise("ord() 에는 글자 한 개를 넣어요 (지금: %s)." % _repr(args[0]))
				return null
			return String(args[0]).unicode_at(0)
		"chr":
			if not (_need_args(name, args, 1) and _need_int(name, args[0])):
				return null
			if int(args[0]) < 0 or int(args[0]) > 0x10FFFF:
				_raise("chr() 에 넣을 수 있는 번호가 아니에요: %d" % int(args[0]), "ValueError")
				return null
			return String.chr(int(args[0]))
		"bin", "hex", "oct":
			if not (_need_args(name, args, 1) and _need_int(name, args[0])):
				return null
			var v := int(args[0])
			var base: int = {"bin": 2, "hex": 16, "oct": 8}[name]
			var prefix: String = {"bin": "0b", "hex": "0x", "oct": "0o"}[name]
			return ("-" if v < 0 else "") + prefix + _to_base(absi(v), base)
		"isinstance":
			if not _need_args(name, args, 2):
				return null
			return _isinstance(args[0], args[1])
		"type":
			if not _need_args(name, args, 1):
				return null
			if _is_kind(args[0], "instance"):
				return args[0]["cls"]
			return {"kind": "builtin", "name": _py_type(args[0])}
		"format":
			if not _need_args(name, args, 1, 2):
				return null
			if args.size() == 2 and not _need_str(name, args[1]):
				return null
			return _format_value(args[0], "" if args.size() == 1 else String(args[1]))
		"iter":
			if not _need_args(name, args, 1):
				return null
			if _is_kind(args[0], "iterator"):
				return args[0]
			var items = _iter(args[0], "iter() 안")
			return null if items == null else {"kind": "iterator", "items": items, "pos": 0}
		"next":
			if not _need_args(name, args, 1, 2):
				return null
			if not _is_kind(args[0], "iterator"):
				_raise("next() 에는 iter() 로 만든 값을 넣어요 (지금: %s)." % _repr(args[0]))
				return null
			var it: Dictionary = args[0]
			var pos: int = it["pos"]
			if pos >= (it["items"] as Array).size():
				if args.size() == 2:
					return args[1]
				_raise("더 꺼낼 값이 없어요.", "StopIteration")
				return null
			it["pos"] = pos + 1
			return it["items"][pos]
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
			return null if items == null else await _sorted(items, kwargs.get("key"), _truthy(kwargs.get("reverse", false)))
		"sum":
			if not _need_args(name, args, 1, 2):
				return null
			var items = _iter(args[0], "sum() 안")
			if items == null:
				return null
			var total = 0 if args.size() == 1 else args[1]
			for v in items:
				total = _binop("+", total, v)
				if not _err.is_empty():
					return null
			return total
		"enumerate":
			if not _need_args(name, args, 1, 2):
				return null
			var first = args[1] if args.size() == 2 else kwargs.get("start", 0)
			if not _need_int(name, first):
				return null
			var items = _iter(args[0], "enumerate() 안")
			if items == null:
				return null
			var out: Array = []
			for i in items.size():
				out.append(_tuple([int(first) + i, items[i]]))
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
				_raise("'%s()' 에 넣은 값이 없어요." % name, "ValueError")
				return null
			var keys = await _keys_for(seq, kwargs.get("key"))
			if keys == null:
				return null
			var best := 0
			for i in range(1, seq.size()):
				var better := _compare("<" if name == "min" else ">", keys[i], keys[best])
				if not _err.is_empty():
					return null
				if better:
					best = i
			return seq[best]
		"int":
			if not _need_args(name, args, 0, 2):
				return null
			if args.is_empty():
				return 0
			var v = args[0]
			if args.size() == 2:
				return _int_from_text(v, args[1])
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
			if _need_args(name, args, 0, 1):
				return "" if args.is_empty() else _str(args[0])
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


func _call_module(mod: String, name: String, args: Array, kwargs: Dictionary = {}) -> Variant:
	var full := "%s.%s" % [mod, name]
	var allowed: Array = MODULE_KWARGS.get(full, [])
	for kw in kwargs:
		if not kw in allowed:
			_raise("'%s()' 에는 '%s=' 을 쓸 수 없어요." % [full, kw])
			return null
	match mod:
		"math":
			return _call_math(full, name, args, kwargs)
		"random":
			return _call_random(full, name, args)
		"collections":
			return _call_collections(full, name, args, kwargs)
		"statistics":
			return await _call_statistics(full, name, args)
		"itertools":
			return await _call_itertools(full, name, args, kwargs)
		"time":
			if _need_args(full, args, 1) and _need_num(full, args[0]):
				if _num(args[0]) < 0:
					_raise("time.sleep() 에는 0 이상의 수를 넣어요.", "ValueError")
					return null
				# The village has no clock: sleep() waits one turn, like wait() (horses take a step).
				var message: String = await _host.run_command("wait", _line, 0, [])
				if _host.is_stop_requested():
					_stop()
				elif message != "":
					_raise(message, "RobotError")
	return null


func _call_math(full: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	match name:
		"gcd", "lcm":
			var out := 0 if name == "gcd" else 1
			for a in args:
				if not _need_int(full, a):
					return null
				var v := absi(int(a))
				if name == "gcd":
					var x := out
					var y := v
					while y != 0:
						var t := x % y
						x = y
						y = t
					out = x
				else:
					if v == 0 or out == 0:
						out = 0
						continue
					var g := out
					var h := v
					while h != 0:
						var t := g % h
						g = h
						h = t
					out = out / g * v
			return out
		"factorial", "isqrt":
			if not (_need_args(full, args, 1) and _need_int(full, args[0])):
				return null
			var n := int(args[0])
			if n < 0:
				_raise("%s() 에는 0 이상의 정수를 넣어요." % full, "ValueError")
				return null
			if name == "isqrt":
				var r := int(sqrt(float(n)))
				while r * r > n:
					r -= 1
				while (r + 1) * (r + 1) <= n:
					r += 1
				return r
			if n > 20:
				_raise("math.factorial() 은 20 까지만 계산할 수 있어요 (이 게임의 수 범위).", "ValueError")
				return null
			var f := 1
			for k in range(2, n + 1):
				f *= k
			return f
		"comb", "perm":
			if not (_need_args(full, args, 1 if name == "perm" else 2, 2) and _need_int(full, args[0])):
				return null
			var n := int(args[0])
			var k := n if args.size() == 1 else int(args[1])
			if args.size() == 2 and not _need_int(full, args[1]):
				return null
			if n < 0 or k < 0:
				_raise("%s() 에는 0 이상의 정수를 넣어요." % full, "ValueError")
				return null
			if k > n:
				return 0
			if name == "comb":
				k = mini(k, n - k)
			var r := 1
			for i in k:
				r = r * (n - i)
				if name == "comb":
					r = r / (i + 1)
			return r
		"prod":
			if not _need_args(full, args, 1):
				return null
			var items = _iter(args[0], "math.prod() 안")
			if items == null:
				return null
			var total = 1
			for v in items:
				total = _binop("*", total, v)
				if not _err.is_empty():
					return null
			return total
		"hypot", "dist":
			var coords: Array = args
			if name == "dist":
				if not _need_args(full, args, 2):
					return null
				var p = _iter(args[0], "math.dist() 안")
				var q = _iter(args[1], "math.dist() 안")
				if p == null or q == null:
					return null
				if p.size() != q.size():
					_raise("math.dist() 의 두 점은 좌표 수가 같아야 해요.", "ValueError")
					return null
				coords = []
				for i in p.size():
					if not (_need_num(full, p[i]) and _need_num(full, q[i])):
						return null
					coords.append(float(p[i]) - float(q[i]))
			var sq := 0.0
			for c in coords:
				if not _need_num(full, c):
					return null
				sq += float(c) * float(c)
			return sqrt(sq)
		"isclose":
			if not (_need_args(full, args, 2) and _need_num(full, args[0]) and _need_num(full, args[1])):
				return null
			var rel := float(kwargs.get("rel_tol", 1e-09))
			var abs_tol := float(kwargs.get("abs_tol", 0.0))
			var a := float(args[0])
			var b := float(args[1])
			return absf(a - b) <= maxf(rel * maxf(absf(a), absf(b)), abs_tol)
		"atan2", "pow", "log":
			var lo := 1 if name == "log" else 2
			if not _need_args(full, args, lo, 2):
				return null
			for a in args:
				if not _need_num(full, a):
					return null
			var x := float(args[0])
			match name:
				"atan2":
					return atan2(x, float(args[1]))
				"pow":
					return pow(x, float(args[1]))
			if x <= 0.0:
				_raise("math.log() 에는 0보다 큰 수를 넣어요.", "ValueError")
				return null
			if args.size() == 1:
				return log(x)
			return _log_base(x, float(args[1]))
	# one number in, one number out
	if not (_need_args(full, args, 1) and _need_num(full, args[0])):
		return null
	var x := float(args[0])
	match name:
		"sqrt":
			if x < 0.0:
				_raise("음수의 제곱근은 구할 수 없어요.", "ValueError")
				return null
			return sqrt(x)
		"floor":
			return floori(x)
		"ceil":
			return ceili(x)
		"trunc":
			return int(x)
		"fabs":
			return absf(x)
		"sin":
			return sin(x)
		"cos":
			return cos(x)
		"tan":
			return tan(x)
		"asin", "acos":
			if x < -1.0 or x > 1.0:
				_raise("%s() 에는 -1 부터 1 사이의 수를 넣어요." % full, "ValueError")
				return null
			return asin(x) if name == "asin" else acos(x)
		"atan":
			return atan(x)
		"radians":
			return deg_to_rad(x)
		"degrees":
			return rad_to_deg(x)
		"exp":
			return exp(x)
		"log10", "log2":
			if x <= 0.0:
				_raise("%s() 에는 0보다 큰 수를 넣어요." % full, "ValueError")
				return null
			return _log_base(x, 10.0 if name == "log10" else 2.0)
	return null


## log of x in `base`, exact for whole powers (math.log10(1000) is 3.0, like Python).
static func _log_base(x: float, base: float) -> float:
	var r := log(x) / log(base)
	var whole := roundf(r)
	if absf(r - whole) < 1e-9 and pow(base, whole) == x:
		return whole
	return r


func _call_random(full: String, name: String, args: Array) -> Variant:
	match name:
		"randint":
			if _need_args(full, args, 2) and _need_int(full, args[0]) and _need_int(full, args[1]):
				if int(args[0]) > int(args[1]):
					_raise("random.randint(a, b) 는 a 가 b 보다 작거나 같아야 해요.", "ValueError")
					return null
				return _rng.randi_range(int(args[0]), int(args[1]))
		"choice":
			if not _need_args(full, args, 1):
				return null
			var seq = _iter(args[0], "random.choice() 안") if not args[0] is String else _iter(args[0])
			if seq == null:
				return null
			if seq.is_empty():
				_raise("random.choice() 에는 비어 있지 않은 목록을 넣어요.", "IndexError")
				return null
			return seq[_rng.randi_range(0, seq.size() - 1)]
		"random":
			if _need_args(full, args, 0):
				return _rng.randf()
		"uniform":
			if _need_args(full, args, 2) and _need_num(full, args[0]) and _need_num(full, args[1]):
				return float(args[0]) + (float(args[1]) - float(args[0])) * _rng.randf()
		"randrange":
			var options = _range(args)
			if options == null:
				return null
			if options.is_empty():
				_raise("random.randrange() 의 범위가 비어 있어요.", "ValueError")
				return null
			return options[_rng.randi_range(0, options.size() - 1)]
		"shuffle":
			if not _need_args(full, args, 1):
				return null
			if not args[0] is Array:
				_raise("random.shuffle() 에는 목록을 넣어요 (지금: %s)." % _repr(args[0]))
				return null
			var items: Array = args[0]
			for i in range(items.size() - 1, 0, -1):
				var j := _rng.randi_range(0, i)
				var t = items[i]
				items[i] = items[j]
				items[j] = t
		"sample":
			if not (_need_args(full, args, 2) and _need_int(full, args[1])):
				return null
			var pool = _iter(args[0], "random.sample() 안")
			if pool == null:
				return null
			var k := int(args[1])
			if k < 0 or k > pool.size():
				_raise("random.sample() 로 %d개를 뽑을 수 없어요 (값은 %d개)." % [k, pool.size()], "ValueError")
				return null
			for i in k:
				var j := _rng.randi_range(i, pool.size() - 1)
				var t = pool[i]
				pool[i] = pool[j]
				pool[j] = t
			return pool.slice(0, k)
		"seed":
			if not _need_args(full, args, 0, 1):
				return null
			_rng.seed = hash(args[0]) if not args.is_empty() and typeof(args[0]) != TYPE_INT else (int(args[0]) if not args.is_empty() else 0)
	return null


func _call_collections(full: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	match name:
		"Counter":
			if not _need_args(full, args, 0, 1):
				return null
			var c := {"kind": "dict", "data": {}, "counter": true}
			if not args.is_empty():
				_counter_add(c, args[0], 1)
			return null if not _err.is_empty() else c
		"defaultdict":
			if not _need_args(full, args, 0, 1):
				return null
			var factory = null if args.is_empty() else args[0]
			if factory != null and not (factory is Dictionary and factory.has("kind")):
				_raise("defaultdict() 에는 int, list 처럼 기본값을 만드는 함수를 넣어요 (지금: %s)." % _repr(factory))
				return null
			return {"kind": "dict", "data": {}, "factory": factory}
		"deque":
			if not _need_args(full, args, 0, 1):
				return null
			var maxlen = kwargs.get("maxlen")
			if maxlen != null and not _need_int(full, maxlen):
				return null
			var items = [] if args.is_empty() else _iter(args[0], "deque() 안")
			if items == null:
				return null
			var dq := {"kind": "deque", "items": items, "maxlen": maxlen}
			_deque_trim(dq, true)
			return dq
	return null


## Adds `sign` (1 or -1) for each value of `src` (or each count of a dict) to Counter `c`.
func _counter_add(c: Dictionary, src: Variant, sign: int) -> void:
	var data: Dictionary = c["data"]
	if _is_kind(src, "dict"):
		for pair in src["data"].values():
			var k := _key(pair[0])
			if not _err.is_empty():
				return
			if not _need_num("Counter", pair[1]):
				return
			data[k] = [pair[0], (data[k][1] if data.has(k) else 0) + sign * _num(pair[1])]
		return
	var items = _iter(src, "Counter() 안")
	if items == null:
		return
	for v in items:
		var k := _key(v)
		if not _err.is_empty():
			return
		data[k] = [v, (data[k][1] if data.has(k) else 0) + sign]


## Drops items beyond maxlen: from the left after appending on the right, and the other way round.
static func _deque_trim(dq: Dictionary, from_left: bool) -> void:
	if dq["maxlen"] == null:
		return
	var items: Array = dq["items"]
	while items.size() > int(dq["maxlen"]):
		if from_left:
			items.pop_front()
		else:
			items.pop_back()


func _call_statistics(full: String, name: String, args: Array) -> Variant:
	if not _need_args(full, args, 1):
		return null
	var data = _iter(args[0], "%s() 안" % full)
	if data == null:
		return null
	if data.is_empty():
		_raise("%s() 에 넣은 값이 없어요." % full, "ValueError")
		return null
	match name:
		"mode":
			var counts := {}
			var best = data[0]
			var best_n := 0
			for v in data:
				var k := _key(v)
				if not _err.is_empty():
					return null
				counts[k] = int(counts.get(k, 0)) + 1
				if counts[k] > best_n:
					best_n = counts[k]
					best = v
			return best
	for v in data:
		if not _need_num(full, v):
			return null
	if name == "mean":
		var total = 0
		var all_int := true
		for v in data:
			total = _binop("+", total, _num(v))
			all_int = all_int and typeof(_num(v)) == TYPE_INT
		if all_int and int(total) % data.size() == 0:
			return int(total) / data.size()
		return float(total) / data.size()
	var sorted = await _sorted(data)
	if sorted == null:
		return null
	var n: int = sorted.size()
	if n % 2 == 1:
		return sorted[floori(n / 2.0)]
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


## itertools results are iterators (iter()/next()/for/list() work), like Python.
func _call_itertools(full: String, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var out: Array = []
	match name:
		"permutations", "combinations":
			if not _need_args(full, args, 1 if name == "permutations" else 2, 2):
				return null
			var pool = _iter(args[0], "%s() 안" % full)
			if pool == null:
				return null
			var r = kwargs.get("r", args[1] if args.size() == 2 else pool.size())
			if not _need_int(full, r):
				return null
			if _count_choices(pool.size(), int(r), name == "permutations") > MAX_LIST:
				_raise("경우의 수가 너무 많아요. 값을 줄여 보세요.")
				return null
			_choose(pool, int(r), name == "permutations", [], out)
		"product":
			var repeat := int(kwargs.get("repeat", 1))
			var pools: Array = []
			for a in args:
				var p = _iter(a, "itertools.product() 안")
				if p == null:
					return null
				pools.append(p)
			var all_pools: Array = []
			for i in repeat:
				all_pools.append_array(pools)
			var combos: Array = [[]]
			for p in all_pools:
				var next: Array = []
				for c in combos:
					for v in p:
						next.append(c + [v])
						if next.size() > MAX_LIST:
							_raise("경우의 수가 너무 많아요. 값을 줄여 보세요.")
							return null
				combos = next
			for c in combos:
				out.append(_tuple(c))
		"chain":
			for a in args:
				var p = _iter(a, "itertools.chain() 안")
				if p == null:
					return null
				out.append_array(p)
		"accumulate":
			if not _need_args(full, args, 1):
				return null
			var p = _iter(args[0], "itertools.accumulate() 안")
			if p == null:
				return null
			var total = null
			for v in p:
				total = v if total == null else _binop("+", total, v)
				if not _err.is_empty():
					return null
				out.append(total)
	return {"kind": "iterator", "items": out, "pos": 0}


static func _count_choices(n: int, r: int, ordered: bool) -> int:
	if r > n or r < 0:
		return 0
	var c := 1
	for i in r:
		c = c * (n - i) if ordered else c * (n - i) / (i + 1)
		if c > MAX_LIST:
			return c
	return c


## Every r-length arrangement (or selection) of `pool` positions, in Python's order.
func _choose(pool: Array, r: int, ordered: bool, picked: Array, out: Array) -> void:
	if picked.size() == r:
		out.append(_tuple(picked.map(func(i: int) -> Variant: return pool[i])))
		return
	var start: int = 0 if ordered or picked.is_empty() else int(picked.back()) + 1
	for i in range(start, pool.size()):
		if ordered and i in picked:
			continue
		_choose(pool, r, ordered, picked + [i], out)


## name=value arguments each builtin accepts.
const BUILTIN_KWARGS: Dictionary = {
	"sorted": ["key", "reverse"], "min": ["key"], "max": ["key"], "print": ["sep", "end"], "enumerate": ["start"],
}
const LIST_METHODS: PackedStringArray = [
	"append", "pop", "insert", "remove", "index", "count", "sort", "reverse", "extend", "copy", "clear",
]
const DICT_METHODS: PackedStringArray = ["get", "keys", "values", "items", "pop", "update", "setdefault", "copy", "clear"]
const TUPLE_METHODS: PackedStringArray = ["index", "count"]
const COUNTER_METHODS: PackedStringArray = ["most_common", "total", "elements", "update", "subtract"]
const DEQUE_METHODS: PackedStringArray = [
	"append", "appendleft", "pop", "popleft", "extend", "extendleft", "rotate", "clear", "count", "index",
	"remove", "reverse", "copy", "insert",
]
const SET_METHODS: PackedStringArray = [
	"add", "remove", "discard", "pop", "clear", "copy", "update", "union", "intersection", "difference",
	"symmetric_difference", "issubset", "issuperset", "isdisjoint",
]
const STR_METHODS: PackedStringArray = [
	"upper", "lower", "count", "index", "startswith", "endswith", "split", "join", "replace", "strip",
	"lstrip", "rstrip", "find", "rfind", "isdigit", "isalpha", "isalnum", "isupper", "islower", "isspace",
	"title", "capitalize", "swapcase", "zfill", "center", "ljust", "rjust", "format",
]


func _call_method(obj: Variant, name: String, args: Array, kwargs: Dictionary = {}) -> Variant:
	if not kwargs.is_empty() and not name in ["sort", "format"]:
		_raise("'.%s()' 에는 이름 붙은 값을 넣을 수 없어요." % name)
		return null
	if _is_kind(obj, "dict"):
		if obj.get("counter", false) and name in COUNTER_METHODS:
			return await _call_counter_method(obj, name, args)
		return _call_dict_method(obj, name, args)
	if _is_kind(obj, "set"):
		return _call_set_method(obj, name, args)
	if obj is String:
		return _call_str_method(obj, name, args, kwargs)
	if _is_kind(obj, "deque"):
		match name:
			"appendleft":
				if _need_args(name, args, 1):
					(obj["items"] as Array).push_front(args[0])
					_deque_trim(obj, false)
				return null
			"popleft":
				if not _need_args(name, args, 0):
					return null
				if (obj["items"] as Array).is_empty():
					_raise("빈 deque 에서는 popleft() 할 수 없어요.", "IndexError")
					return null
				return (obj["items"] as Array).pop_front()
			"extendleft":
				if not _need_args(name, args, 1):
					return null
				var more = _iter(args[0], "extendleft() 안")
				if more == null:
					return null
				for v in more:
					(obj["items"] as Array).push_front(v)
				_deque_trim(obj, false)
				return null
			"rotate":
				if not _need_args(name, args, 0, 1):
					return null
				if not args.is_empty() and not _need_int(name, args[0]):
					return null
				var dq: Array = obj["items"]
				if dq.is_empty():
					return null
				var steps := posmod(1 if args.is_empty() else int(args[0]), dq.size())
				dq.assign(dq.slice(dq.size() - steps) + dq.slice(0, dq.size() - steps))
				return null
			"copy":
				if _need_args(name, args, 0):
					return {"kind": "deque", "items": (obj["items"] as Array).duplicate(), "maxlen": obj["maxlen"]}
				return null
		var result = await _call_method(obj["items"], name, args, kwargs)
		if name in ["append", "extend", "insert"]:
			_deque_trim(obj, true)
		return result
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
				var sorted = await _sorted(items, kwargs.get("key"), _truthy(kwargs.get("reverse", false)))
				if sorted != null:
					items.assign(sorted)
		"reverse":
			if _need_args("reverse", args, 0):
				items.reverse()
		"extend":
			if not _need_args(name, args, 1):
				return null
			var more = _iter(args[0], "extend() 안")
			if more == null:
				return null
			if items.size() + more.size() > MAX_LIST:
				_raise("목록이 너무 커요.")
				return null
			items.append_array(more)
		"copy":
			if _need_args(name, args, 0):
				return items.duplicate()
		"clear":
			if _need_args(name, args, 0):
				items.clear()
	return null


func _call_set_method(st: Dictionary, name: String, args: Array) -> Variant:
	var data: Dictionary = st["data"]
	match name:
		"add", "remove", "discard":
			if not _need_args(name, args, 1):
				return null
			var k := _key(args[0])
			if not _err.is_empty():
				return null
			if name == "add":
				data[k] = args[0]
			elif data.has(k):
				data.erase(k)
			elif name == "remove":
				_raise("집합 안에 %s 이(가) 없어요." % _repr(args[0]), "KeyError")
		"pop":
			if not _need_args(name, args, 0):
				return null
			if data.is_empty():
				_raise("빈 집합에서는 pop() 할 수 없어요.", "KeyError")
				return null
			var k: String = data.keys()[0]
			var v = data[k]
			data.erase(k)
			return v
		"clear":
			if _need_args(name, args, 0):
				data.clear()
		"copy":
			if _need_args(name, args, 0):
				return {"kind": "set", "data": data.duplicate()}
		_:
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "%s() 안" % name)
			if items == null:
				return null
			var other = _set_from(items)
			if other == null:
				return null
			var od: Dictionary = other["data"]
			match name:
				"union":
					return _binop("|", st, other)
				"intersection":
					return _binop("&", st, other)
				"difference":
					return _binop("-", st, other)
				"symmetric_difference":
					return _binop("^", st, other)
				"update":
					data.merge(od)
				"issubset":
					return data.keys().all(func(k: String) -> bool: return od.has(k))
				"issuperset":
					return od.keys().all(func(k: String) -> bool: return data.has(k))
				"isdisjoint":
					return not data.keys().any(func(k: String) -> bool: return od.has(k))
	return null


## Counter's own methods (the dict methods work too).
func _call_counter_method(c: Dictionary, name: String, args: Array) -> Variant:
	var data: Dictionary = c["data"]
	match name:
		"most_common":
			if not _need_args(name, args, 0, 1):
				return null
			if not args.is_empty() and args[0] != null and not _need_int(name, args[0]):
				return null
			var pairs: Array = data.values().map(func(p: Array) -> Variant: return _tuple([p[0], p[1]]))
			var ranked = await _sorted(pairs, {"kind": "builtin", "name": "_count_of"}, true)
			if ranked == null:
				return null
			return ranked if args.is_empty() or args[0] == null else ranked.slice(0, maxi(0, int(args[0])))
		"total":
			if not _need_args(name, args, 0):
				return null
			var t = 0
			for p in data.values():
				t = _binop("+", t, p[1])
			return t
		"elements":
			if not _need_args(name, args, 0):
				return null
			var out: Array = []
			for p in data.values():
				for i in maxi(0, int(p[1])):
					out.append(p[0])
			return {"kind": "iterator", "items": out, "pos": 0}
		"update", "subtract":
			if not _need_args(name, args, 0, 1):
				return null
			if not args.is_empty():
				_counter_add(c, args[0], 1 if name == "update" else -1)
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
		"update":
			if not _need_args(name, args, 1):
				return null
			if _is_kind(args[0], "dict"):
				for pair in args[0]["data"].values():
					_dict_set(d, pair[0], pair[1])
				return null
			var pairs = _iter(args[0], "update() 안")
			if pairs == null:
				return null
			for p in pairs:
				var kv = _unpack(p, 2)
				if kv == null:
					return null
				_dict_set(d, kv[0], kv[1])
		"setdefault":
			if not _need_args(name, args, 1, 2):
				return null
			var k := _key(args[0])
			if not _err.is_empty():
				return null
			if data.has(k):
				return data[k][1]
			var value = args[1] if args.size() == 2 else null
			data[k] = [args[0], value]
			return value
		"copy":
			if _need_args(name, args, 0):
				var copied := d.duplicate()  # keeps Counter / defaultdict
				copied["data"] = data.duplicate()
				return copied
		"clear":
			if _need_args(name, args, 0):
				data.clear()
	return null


func _call_str_method(s: String, name: String, args: Array, kwargs: Dictionary = {}) -> Variant:
	match name:
		"upper", "lower", "swapcase", "title", "capitalize":
			if not _need_args(name, args, 0):
				return null
			match name:
				"upper":
					return s.to_upper()
				"lower":
					return s.to_lower()
				"capitalize":
					return s.left(1).to_upper() + s.substr(1).to_lower()
			var out := ""
			var after_letter := false
			for ch in s:
				if name == "swapcase":
					out += ch.to_lower() if ch != ch.to_lower() else ch.to_upper()
					continue
				var letter := _is_letter(ch)
				out += (ch.to_lower() if after_letter else ch.to_upper()) if letter else ch
				after_letter = letter
			return out
		"strip", "lstrip", "rstrip":
			if not _need_args(name, args, 0, 1):
				return null
			var chars := " \t\n\r"
			if not args.is_empty() and args[0] != null:
				if not _need_str(name, args[0]):
					return null
				chars = args[0]
			var lo := 0
			var hi := s.length()
			if name != "rstrip":
				while lo < hi and chars.contains(s[lo]):
					lo += 1
			if name != "lstrip":
				while hi > lo and chars.contains(s[hi - 1]):
					hi -= 1
			return s.substr(lo, hi - lo)
		"count", "index", "startswith", "endswith", "find", "rfind":
			if not (_need_args(name, args, 1) and _need_str(name, args[0])):
				return null
			match name:
				"count":
					return s.count(args[0])
				"startswith":
					return s.begins_with(args[0])
				"endswith":
					return s.ends_with(args[0])
				"find":
					return s.find(args[0])
				"rfind":
					return s.rfind(args[0])
			var at := s.find(args[0])
			if at < 0:
				_raise("글자 안에 %s 이(가) 없어요." % _repr(args[0]), "ValueError")
				return null
			return at
		"isdigit", "isalpha", "isalnum", "isupper", "islower", "isspace":
			if not _need_args(name, args, 0):
				return null
			if s.is_empty():
				return false
			match name:
				"isupper":
					return s.to_upper() == s and s.to_lower() != s
				"islower":
					return s.to_lower() == s and s.to_upper() != s
			for ch in s:
				var ok := false
				match name:
					"isdigit":
						ok = _is_digit(ch)
					"isalpha":
						ok = _is_letter(ch)
					"isalnum":
						ok = _is_letter(ch) or _is_digit(ch)
					"isspace":
						ok = ch in [" ", "\t", "\n", "\r"]
				if not ok:
					return false
			return true
		"zfill", "center", "ljust", "rjust":
			var hi := 1 if name == "zfill" else 2
			if not (_need_args(name, args, 1, hi) and _need_int(name, args[0])):
				return null
			var fill := " "
			if args.size() == 2:
				if not (args[1] is String and String(args[1]).length() == 1):
					_raise("'%s()' 의 두 번째 값은 글자 한 개예요. 예: s.%s(10, \"*\")" % [name, name])
					return null
				fill = args[1]
			var width := int(args[0])
			var gap := width - s.length()
			if gap <= 0:
				return s
			match name:
				"zfill":
					var sign := s.left(1) if s.left(1) in ["+", "-"] else ""
					return sign + "0".repeat(gap) + s.substr(sign.length())
				"ljust":
					return s + fill.repeat(gap)
				"rjust":
					return fill.repeat(gap) + s
			var left := floori(gap / 2.0) + (gap & width & 1)
			return fill.repeat(left) + s + fill.repeat(gap - left)
		"split":
			if not _need_args(name, args, 0, 1):
				return null
			if args.is_empty() or args[0] == null:
				return Array(s.replace("\t", " ").replace("\n", " ").replace("\r", " ").split(" ", false))
			if not _need_str(name, args[0]):
				return null
			if String(args[0]).is_empty():
				_raise("split() 에 빈 글자는 넣을 수 없어요.", "ValueError")
				return null
			return Array(s.split(args[0]))
		"join":
			if not _need_args(name, args, 1):
				return null
			var items = _iter(args[0], "join() 안")
			if items == null:
				return null
			var parts: PackedStringArray = []
			for it in items:
				if not it is String:
					_raise("join() 할 목록에는 글자만 있어야 해요 (지금: %s). str() 로 바꿔 보세요." % _repr(it))
					return null
				parts.append(it)
			return s.join(parts)
		"replace":
			if _need_args(name, args, 2) and _need_str(name, args[0]) and _need_str(name, args[1]):
				return s.replace(args[0], args[1])
		"format":
			return _str_format(s, args, kwargs)
	return null


## A letter for isalpha()/title(): Latin and other cased letters, Hangul and CJK.
static func _is_letter(ch: String) -> bool:
	if ch.to_lower() != ch.to_upper():
		return true
	var c := ch.unicode_at(0)
	return (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3131 and c <= 0x318E) or (c >= 0x4E00 and c <= 0x9FFF)


func _need_str(name: String, v: Variant) -> bool:
	if not v is String:
		_raise("'%s()' 에는 글자를 넣어요 (지금: %s)." % [name, _repr(v)])
		return false
	return true


## Values to compare for each item: the item itself, or key(item). null with an error.
func _keys_for(items: Array, key: Variant) -> Variant:
	if key == null:
		return items
	var keys: Array = []
	for it in items:
		var k = await _call(key, [it])
		if not _err.is_empty():
			return null
		keys.append(k)
	return keys


## A sorted copy, by key(item) when a key function is given, largest first with reverse.
## Stable, like Python. null with an error for values that cannot be compared.
func _sorted(items: Array, key: Variant = null, reverse: bool = false) -> Variant:
	var keys = await _keys_for(items, key)
	if keys == null:
		return null
	var order: Array = range(items.size())
	var op := "<" if reverse else ">"
	# Insertion sort with _compare, so mixed types raise a friendly error instead of crashing.
	for i in range(1, order.size()):
		var v: int = order[i]
		var j := i - 1
		while j >= 0 and _compare(op, keys[order[j]], keys[v]):
			order[j + 1] = order[j]
			j -= 1
		if not _err.is_empty():
			return null
		order[j + 1] = v
	return order.map(func(i: int) -> Variant: return items[i])


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
		if MODULE_CONSTS.has(full_name(mod, name)):
			return MODULE_CONSTS[full_name(mod, name)]
		return {"kind": "modfn", "mod": mod, "name": name}
	var methods: PackedStringArray = []
	if obj is Array:
		methods = LIST_METHODS
	elif obj is String:
		methods = STR_METHODS
	elif kind == "dict":
		methods = DICT_METHODS
		if obj.get("counter", false):
			methods = DICT_METHODS + COUNTER_METHODS
	elif kind == "deque":
		methods = DEQUE_METHODS
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


static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_BOOL


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
	if _is_kind(v, "tuple") or _is_kind(v, "deque"):
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
	if op == "%" and a is String:
		return _percent_format(a, b)
	if (op == "+" or op == "-") and _is_kind(a, "dict") and a.get("counter", false) and _is_kind(b, "dict"):
		var c := {"kind": "dict", "data": (a["data"] as Dictionary).duplicate(), "counter": true}
		_counter_add(c, b, 1 if op == "+" else -1)
		for k in (c["data"] as Dictionary).keys():
			if c["data"][k][1] <= 0:
				c["data"].erase(k)  # like Python, only positive counts stay
		return c
	if op == "|" and _is_kind(a, "dict") and _is_kind(b, "dict"):
		var merged := {"kind": "dict", "data": (a["data"] as Dictionary).duplicate()}
		(merged["data"] as Dictionary).merge(b["data"], true)
		return merged
	if op in ["|", "&", "^"] or (op == "-" and _is_kind(a, "set")):
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
				"-", "^":
					for k in da:
						if not db.has(k):
							out["data"][k] = da[k]
					if op == "^":
						for k in db:
							if not da.has(k):
								out["data"][k] = db[k]
			return out
		if op != "-" and _is_int(a) and _is_int(b):
			match op:
				"|":
					return int(a) | int(b)
				"&":
					return int(a) & int(b)
			return int(a) ^ int(b)
		if op != "-":
			_raise("'%s' 는 집합끼리나 정수끼리 써요 (지금: %s, %s)." % [op, _type_name(a), _type_name(b)])
			return null
	if op == "<<" or op == ">>":
		if not (_is_int(a) and _is_int(b)):
			_raise("'%s' 는 정수끼리 써요 (지금: %s, %s)." % [op, _type_name(a), _type_name(b)])
			return null
		if int(b) < 0:
			_raise("음수만큼 밀 수는 없어요.", "ValueError")
			return null
		return int(a) << int(b) if op == "<<" else int(a) >> int(b)
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
			"builtin":
				return a["name"] == b["name"]
			"modfn":
				return a["mod"] == b["mod"] and a["name"] == b["name"]
			"tuple", "deque":
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
			if _is_kind(a, "builtin") and _is_kind(b, "builtin"):
				same = a["name"] == b["name"]  # type([]) is list
			return same if op == "is" else not same
		"in", "not in":
			var found := false
			if _is_kind(b, "dict") or _is_kind(b, "set"):
				var k := _key(a)
				found = _err.is_empty() and b["data"].has(k)
			elif b is String and a is String:
				found = String(b).contains(a)
			elif b is Array or _is_kind(b, "tuple") or _is_kind(b, "deque"):
				for item in (b if b is Array else b["items"]):
					if _eq(a, item):
						found = true
						break
			else:
				_raise("'in' 뒤에는 목록, 튜플, 글자, 딕셔너리가 와야 해요.")
				return false
			return found if op == "in" else not found
	if _is_kind(a, "set") and _is_kind(b, "set"):
		var da: Dictionary = a["data"]
		var db: Dictionary = b["data"]
		var sub := da.keys().all(func(k: String) -> bool: return db.has(k))
		var sup := db.keys().all(func(k: String) -> bool: return da.has(k))
		match op:
			"<=":
				return sub
			"<":
				return sub and da.size() < db.size()
			">=":
				return sup
			">":
				return sup and da.size() > db.size()
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
	if _is_kind(v, "deque"):
		return "deque"
	return "객체"


## Text that print() shows: strings as-is, everything else like Python's repr.
static func _str(v: Variant) -> String:
	return String(v) if v is String else _repr(v)


## A float the way Python prints it: the shortest digits that read back as the same number,
## in fixed notation from 1e-4 up to 1e16 and scientific outside (0.30000000000000004, 1e-05, 1e+16).
static func _float_repr(f: float) -> String:
	if is_nan(f):
		return "nan"
	if is_inf(f):
		return "inf" if f > 0 else "-inf"
	var text := var_to_str(f)  # shortest round-trip digits, e.g. "1e-05" or "0.1"
	var sign := ""
	if text.begins_with("-"):
		sign = "-"
		text = text.substr(1)
	var exp10 := 0
	var at := text.find("e")
	if at >= 0:
		exp10 = text.substr(at + 1).to_int()
		text = text.left(at)
	var dot := text.find(".")
	var whole := text if dot < 0 else text.left(dot)
	var digits := whole + ("" if dot < 0 else text.substr(dot + 1))
	var point := whole.length() + exp10  # value = 0.<digits> * 10^point
	while digits.begins_with("0"):
		digits = digits.substr(1)
		point -= 1
	digits = digits.rstrip("0")
	if digits.is_empty():
		return sign + "0.0"
	var e := point - 1
	if e < -4 or e >= 16:
		var mant := digits.left(1) + ("." + digits.substr(1) if digits.length() > 1 else "")
		return sign + mant + "e" + ("-" if e < 0 else "+") + ("%02d" % absi(e))
	if point <= 0:
		return sign + "0." + "0".repeat(-point) + digits
	if point >= digits.length():
		return sign + digits + "0".repeat(point - digits.length()) + ".0"
	return sign + digits.left(point) + "." + digits.substr(point)


static func _repr(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _float_repr(v)
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
					if v["name"] in TYPE_NAMES:
						return "<class '%s'>" % v["name"]
					return "<명령 %s>" % v["name"]
				"iterator":
					return "<iterator>"
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
				"lambda":
					return "<lambda>"
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
					var pairs: Array = v["data"].values()
					if v.get("counter", false):
						pairs = pairs.duplicate()
						# most common first; equal counts keep their order (a stable sort)
						for i in range(1, pairs.size()):
							var cur: Array = pairs[i]
							var j := i - 1
							while j >= 0 and _num(pairs[j][1]) < _num(cur[1]):
								pairs[j + 1] = pairs[j]
								j -= 1
							pairs[j + 1] = cur
					var parts: PackedStringArray = []
					for pair in pairs:
						parts.append("%s: %s" % [_repr(pair[0]), _repr(pair[1])])
					var body := "{" + ", ".join(parts) + "}"
					if v.get("counter", false):
						return "Counter()" if parts.is_empty() else "Counter(%s)" % body
					if v.has("factory"):
						return "defaultdict(%s, %s)" % [_repr(v["factory"]), body]
					return body
				"deque":
					var inner := "deque(%s" % _repr(v["items"])
					return inner + (")" if v["maxlen"] == null else ", maxlen=%d)" % int(v["maxlen"]))
	return str(v)
