extends SceneTree
## Headless checks for the interpreter and level data.
## Run: godot --headless --path . --script res://tests/run_tests.gd

## WorldHost that also records print() output.
class CaptureHost:
	extends WorldHost
	var out: PackedStringArray = []

	func _init(w: GridWorld) -> void:
		super(w)

	func print_line(text: String) -> void:
		out.append(text)


var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	await process_frame
	await _run_all()
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _run_source(level: Dictionary, source: String) -> Dictionary:
	var world := GridWorld.new()
	world.load_level(Levels.for_map(level, 0) if level.has("variants") else level)
	var interp := CodeInterpreter.new()
	var parsed := interp.parse(source, PackedStringArray(level.get("banned", [])),
			PackedStringArray(level.get("required", [])))
	if not parsed["ok"]:
		return {"parsed": parsed, "world": world}
	var result: Dictionary = await interp.run(parsed["program"], WorldHost.new(world), 1)
	return {"parsed": parsed, "result": result, "world": world}


## Runs `source` on level 1's map and returns {"ok", "message", "out": printed text joined by "|"}.
func _run_print(source: String, rng_seed: int = 0) -> Dictionary:
	var world := GridWorld.new()
	world.load_level(Levels.ALL[0])
	var interp := CodeInterpreter.new()
	var parsed := interp.parse(source)
	if not parsed["ok"]:
		return {"ok": false, "message": "parse: " + String(parsed["message"]), "out": ""}
	var host := CaptureHost.new(world)
	var result: Dictionary = await interp.run(parsed["program"], host, rng_seed)
	return {"ok": result["ok"], "message": String(result.get("message", "")), "out": "|".join(host.out)}


func _expect_print(source: String, expected: String, label: String) -> void:
	var r := await _run_print(source)
	_expect(r["ok"] and r["out"] == expected, "%s -> %s %s" % [label, r["out"], r["message"]])


func _expect_run_error(source: String, needle: String, label: String) -> void:
	var r := await _run_print(source)
	_expect(not r["ok"] and String(r["message"]).contains(needle), "%s -> %s" % [label, r["message"]])


func _run_all() -> void:
	print("== Every script compiles ==")
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			var scr := load("res://scripts/" + file) as GDScript
			_expect(scr != null and scr.can_instantiate(), "%s compiles" % file)

	print("== Level solutions ==")
	for level in Levels.ALL:
		var out := await _run_source(level, level["solution"])
		var world: GridWorld = out["world"]
		var ok: bool = out["parsed"]["ok"] and out["result"]["ok"] and world.is_solved()
		var why: String = out["parsed"].get("message", "") if not out["parsed"]["ok"] else String(out["result"].get("message", ""))
		_expect(ok, "%s solved (apples %d/%d) %s" % [level["title"], world.collected, world.apple_total, why])
		var lines := CodeInterpreter.count_code_lines(level["solution"])
		_expect(lines <= int(level["par"]), "%s solution %d lines <= par %d" % [level["title"], lines, level["par"]])
		var starter_parse := CodeInterpreter.new().parse(level["starter"]) if level["starter"] != "" else {"ok": true}
		_expect(starter_parse["ok"], "%s starter code parses" % level["title"])
		var maps := Levels.maps(level)
		for i in maps.size():
			var text := "\n".join(PackedStringArray(maps[i]))
			_expect(text.count("S") == 1 and text.count("G") == 1 + text.count("R"),
					"%s map %d has one S and one G per robot" % [level["title"], i])
		if not out["parsed"]["ok"]:
			continue
		var program: Array = out["parsed"]["program"]
		for check in WorldHost.checks(level):
			var run: Dictionary = await WorldHost.run_on_map(level, check["map"], program, check["seed"])
			var vw: GridWorld = run["world"]
			_expect(run["result"]["ok"] and vw.is_solved(), "%s solves map %d seed %d %s" % [
				level["title"], check["map"], check["seed"], run["result"].get("message", "")])

	print("== Parser errors ==")
	var lvl: Dictionary = Levels.ALL[0]
	var cases := {
		"move": "괄호",
		"repeat 3\n    move()": "':'",
		"repeat 3:\nmove()": "들여써야",
		"move()\n    move()": "들여쓰기",
		"jump()": "모르는 명령",
		"is_blocked()": "조건",
		"else:\n    move()": "if",
		"while maybe():\n    move()": "모르는 조건",
		"": "비어",
	}
	for src in cases:
		var parsed := CodeInterpreter.new().parse(src)
		var msg: String = parsed.get("message", "")
		_expect(not parsed["ok"] and msg.contains(cases[src]), "error for %s -> %s" % [JSON.stringify(src), msg])

	print("== Syntax variants ==")
	var out := await _run_source(lvl, "for i in range(4):\n\tmove()  # tab indent\n")
	_expect(out["result"]["ok"] and out["world"].is_solved(), "for-range + tab indent + comment")
	out = await _run_source(Levels.ALL[5], "repeat 8:\n    move()\n    if not on_apple():\n        turn_left()\n        turn_right()\n    elif on_apple():\n        pick()\n")
	_expect(out["result"]["ok"] and out["world"].is_solved(), "if not / elif")

	print("== Hidden variants ==")
	var hard := "move()\nmove()\npick()\nmove()\nmove()\npick()\nmove()\npick()\nmove()\nmove()\npick()\nmove()\n"
	out = await _run_source(Levels.ALL[5], hard)
	_expect(out["result"]["ok"] and out["world"].is_solved(), "hard-coded moves solve level 6's visible map")
	var hard_prog: Array = CodeInterpreter.new().parse(hard)["program"]
	var hard_run: Dictionary = await WorldHost.run_on_map(Levels.ALL[5], 1, hard_prog)
	_expect(not hard_run["result"]["ok"] or not hard_run["world"].is_solved(), "hard-coded moves fail a level 6 variant")

	print("== Runtime errors ==")
	out = await _run_source(lvl, "repeat 5:\n    move()\n")
	_expect(not out["result"]["ok"] and out["result"]["line"] == 1, "bump into wall reports line 1")
	out = await _run_source(lvl, "pick()")
	_expect(not out["result"]["ok"], "pick on empty cell fails")
	out = await _run_source(lvl, "while not at_goal():\n    turn_left()\n")
	_expect(not out["result"]["ok"] and String(out["result"]["message"]).contains("반복"), "infinite loop is stopped")
	out = await _run_source(Levels.ALL[1], "repeat 4:\n    move()\n")
	_expect(out["result"]["ok"] and not out["world"].is_solved(), "goal without apples is not solved")

	print("== Banned names ==")
	for level in Levels.ALL:
		for name in level.get("banned", []):
			var src := "while not %s():\n    move()\n" % name
			var parsed := CodeInterpreter.new().parse(src, PackedStringArray(level["banned"]))
			_expect(not parsed["ok"] and String(parsed["message"]).contains("쓸 수 없어요"), "%s bans %s()" % [level["title"], name])

	print("== Values and operators ==")
	await _expect_print("print(7 // 2, 7 % 3, -7 // 2, -7 % 3, 2 ** 10, 7 / 2)", "3 1 -4 2 1024 3.5", "integer math like Python")
	await _expect_print("print(1 + 2 * 3, (1 + 2) * 3, -2 ** 2, 10 - 2 - 3)", "7 9 -4 5", "precedence")
	await _expect_print("print(1 < 2 < 3, 2 in [1, 2], 'a' not in 'abc', True and 0, None or 5, not [])", "True True False 0 5 True", "comparisons and logic")
	await _expect_print("n = 5\nn += 2\nn *= 3\nn //= 4\nn -= 1\nprint(n)", "4", "augmented assignment")
	await _expect_print("print('사과' + str(3), 'ab' * 2, len('hello'), int('42') + 1, float(2), str(2.0))", "사과3 abab 5 43 2.0 2.0", "strings and conversion")
	await _expect_print("a = [3, 1]\na.append(2)\na[0] = 9\nprint(a, len(a), a[-1], a.pop(), a, [0] * 3)", "[9, 1] 3 2 2 [9, 1] [0, 0, 0]", "lists (same list object, like Python)")
	await _expect_print("print(abs(-3), min(4, 2), max([1, 9, 5]), round(2.5), round(3.5), round(2.567, 2))", "3 2 9 2 4 2.57", "builtins")
	await _expect_print("print('a#b')  # real comment", "a#b", "# inside a string is not a comment")
	_expect(CodeInterpreter.count_code_lines("x = '#'\n# note\n\nmove()") == 2, "count_code_lines ignores comments, not # in strings")

	print("== Loops and functions ==")
	await _expect_print("t = 0\nfor i in range(1, 11):\n    if i % 2 == 1:\n        continue\n    if i > 8:\n        break\n    t += i\nprint(t)", "20", "for / continue / break")
	await _expect_print("for c in 'abc':\n    print(c)", "a|b|c", "for over a string")
	await _expect_print("i = 0\nwhile True:\n    i += 1\n    if i == 3:\n        break\nprint(i)", "3", "while True with break")
	await _expect_print("def f(n):\n    if n <= 1:\n        return 1\n    return n * f(n - 1)\nprint(f(5))", "120", "recursion and return")
	await _expect_print("def hi():\n    pass\nprint(hi())", "None", "function without return gives None")
	await _expect_print("n = 0\ndef inc():\n    global n\n    n += 1\ninc()\ninc()\nprint(n)", "2", "global")
	await _expect_print("n = 1\ndef show():\n    print(n)\nshow()", "1", "read a global without global")
	await _expect_print("x = 1\ndef f():\n    x = 2\n    return x\nprint(f(), x)", "2 1", "assignment in a function is local")

	print("== Modules ==")
	await _expect_print("import math\nprint(math.sqrt(16), math.floor(2.7), math.ceil(2.1), math.floor(-0.5), round(math.pi, 2))", "4.0 2 3 -1 3.14", "math")
	var r1 := await _run_print("import random\nprint(random.randint(1, 6), random.randint(1, 6), random.choice(['a', 'b', 'c']))", 7)
	var r2 := await _run_print("import random\nprint(random.randint(1, 6), random.randint(1, 6), random.choice(['a', 'b', 'c']))", 7)
	_expect(r1["ok"] and r1["out"] == r2["out"], "random repeats for the same seed -> %s" % r1["out"])
	await _expect_print("import random\nok = True\nfor i in range(200):\n    v = random.randint(1, 6)\n    if v < 1 or v > 6:\n        ok = False\nprint(ok)", "True", "random.randint stays in range")

	print("== New error messages ==")
	var parse_cases := {
		"if x = 3:\n    move()": "==",
		"if True:\n    move()\nelse if True:\n    move()": "elif",
		"break": "반복문",
		"return 1": "def",
		"print('hi)": "따옴표",
		"mvoe()": "move",
		"import os": "math, random",
		"move() move()": "이해할 수 없는",
		"x = (1 + 2": "괄호",
		"get_x()": "값을 알려",
		"1 + 2": "print",
		"move = 3": "이미 있는 이름",
		"def move():\n    pass": "이미 있는 이름",
		"while True: move()": "다음 줄",
		"lambda x: x": "아직",
		"class A:\n    move()": "메서드",
		"class A:\n    def go():\n        pass": "self",
		"x = 1\ndef f():\n    class B:\n        pass": "바깥",
		"x = 3 @ 2": "글자",
	}
	for src in parse_cases:
		var parsed := CodeInterpreter.new().parse(src)
		var msg: String = parsed.get("message", "")
		_expect(not parsed["ok"] and msg.contains(parse_cases[src]), "parse error for %s -> %s" % [JSON.stringify(src), msg])
	await _expect_run_error("print(math.sqrt(4))", "import math", "module used before import")
	await _expect_run_error("print(y)", "아직 만들지 않은 변수", "unknown variable")
	await _expect_run_error("print('a' + 1)", "str()", "string + number")
	await _expect_run_error("print(1 / 0)", "0으로", "division by zero")
	await _expect_run_error("repeat 7 / 2:\n    move()", "//", "repeat needs an integer")
	await _expect_run_error("move(1)", "아무것도", "command takes no values")
	await _expect_run_error("walk(2)\ndef walk(n):\n    move()", "위에", "function called before def")
	await _expect_run_error("def f(n):\n    return f(n + 1)\nf(0)", "깊이", "runaway recursion is stopped")
	await _expect_run_error("n = 0\ndef inc():\n    n += 1\ninc()", "global", "local read before assignment")
	await _expect_run_error("a = [1]\nprint(a[3])", "범위", "index out of range")
	await _expect_run_error("def f(a, b):\n    pass\nf(1)", "2개", "wrong number of values")

	print("== Classes ==")
	var counter := "class Counter:\n    start = 10\n    def __init__(self, step):\n        self.n = Counter.start\n        self.step = step\n    def add(self):\n        self.n += self.step\n        return self.n\n"
	await _expect_print(counter + "c = Counter(5)\nd = Counter(1)\nc.add()\nprint(c.add(), d.add(), c.n, d.n, c == d, c == c)", "20 11 20 11 False True", "fields are per object")
	var shapes := "class Animal:\n    def __init__(self, name):\n        self.name = name\n    def sound(self):\n        return '...'\n    def speak(self):\n        return self.name + ': ' + self.sound()\nclass Dog(Animal):\n    def __init__(self, name):\n        super().__init__(name)\n        self.tricks = []\n    def sound(self):\n        return '멍멍'\n"
	await _expect_print(shapes + "print(Animal('고양이').speak())\nprint(Dog('바둑이').speak())", "고양이: ...|바둑이: 멍멍", "inheritance, override, super()")
	await _expect_print("class A:\n    pass\na = A()\na.x = 3\nprint(a.x, A)", "3 <class A>", "attributes set from outside")
	await _expect_run_error("class A:\n    pass\nprint(A().missing)", "self.missing", "missing attribute")
	await _expect_run_error("class A:\n    def __init__(self, x):\n        self.x = x\nA()", "self 말고 값 1개", "constructor arity")
	await _expect_run_error("class A:\n    def go(self):\n        super().go()\nA().go()", "물려받은", "super() without a base")
	await _expect_run_error("x = 5\nclass B(x):\n    pass", "class 이름", "base must be a class")
	var need_class := CodeInterpreter.new().parse("move()", PackedStringArray(), PackedStringArray(["class"]))
	_expect(not need_class["ok"] and String(need_class["message"]).contains("class"), "required class is enforced")
	var need_inherit := CodeInterpreter.new().parse("class A:\n    pass", PackedStringArray(), PackedStringArray(["class", "inherit"]))
	_expect(not need_inherit["ok"] and String(need_inherit["message"]).contains("물려받는"), "required inheritance is enforced")

	print("== Tuples ==")
	await _expect_print("p = (3, 4)\nx, y = p\nprint(p, x + y, len(p), p[0], (5,), (), (1, 2) + (3,))", "(3, 4) 7 2 3 (5,) () (1, 2, 3)", "tuple basics")
	await _expect_print("a, b = 1, 2\na, b = b, a\nprint(a, b)", "2 1", "swap with tuples")
	await _expect_print("def mm(xs):\n    return min(xs), max(xs)\nlo, hi = mm([4, 1, 9])\nprint(lo, hi)", "1 9", "return a tuple")
	await _expect_print("for i, x in enumerate(['a', 'b']):\n    print(i, x)", "0 a|1 b", "enumerate")
	await _expect_print("for x, y in [(1, 2), (3, 4)]:\n    print(x * y)", "2|12", "for unpacks tuples")
	await _expect_print("print((1, 5) < (2, 0), (1, 2) == (1, 2), min([(3, 'c'), (1, 'z')]), sorted([(2, 1), (1, 9)]))", "True True (1, 'z') [(1, 9), (2, 1)]", "tuples compare item by item")
	await _expect_print("print(list(zip([1, 2], ['a', 'b'])), 2 in (1, 2), (0, 1).count(1))", "[(1, 'a'), (2, 'b')] True 1", "zip, in, count")
	await _expect_run_error("p = (1, 2)\np[0] = 5", "튜플은", "tuples cannot change")
	await _expect_run_error("a, b = (1, 2, 3)", "3개", "unpack count mismatch")

	print("== Dictionaries ==")
	await _expect_print("d = {'apple': 2, 'corn': 1}\nd['apple'] += 1\nd['carrot'] = 4\nprint(d, len(d), d['apple'], d.get('x', 0), 'corn' in d)", "{'apple': 3, 'corn': 1, 'carrot': 4} 3 3 0 True", "dict basics")
	await _expect_print("d = {'a': 1, 'b': 2}\nfor k, v in d.items():\n    print(k, v)\nprint(d.keys(), d.values(), sorted(d))", "a 1|b 2|['a', 'b'] [1, 2] ['a', 'b']", "items, keys, values")
	await _expect_print("c = {}\nfor w in ['x', 'y', 'x']:\n    c[w] = c.get(w, 0) + 1\nprint(c)", "{'x': 2, 'y': 1}", "counting pattern")
	await _expect_print("d = {(1, 2): 'a', 1: 'one'}\nprint(d[(1, 2)], d[1.0], dict([('k', 9)]), d.pop(1), d)", "a one {'k': 9} one {(1, 2): 'a'}", "tuple keys, 1 == 1.0, dict(), pop")
	await _expect_print("d = {'a': 1}\ndel d['a']\nx = [1, 2, 3]\ndel x[0]\nprint(d, x, {} == {}, {'a': 1} == {'a': 1})", "{} [2, 3] True True", "del and equality")
	await _expect_print("act = {'p': print}\nact['p']('hi')\nprint(sum([1, 2, 3]), None is None, 1 is not None)", "hi|6 True True", "functions in a dict, sum, is")
	await _expect_run_error("d = {}\nprint(d['nope'])", ".get(", "missing key")
	await _expect_run_error("d = {[1]: 2}", "키로 쓸 수 없어요", "lists cannot be keys")

	print("== Strings and list methods ==")
	await _expect_print("s = 'Hello World'\nprint(s.lower(), s.upper(), s.split(), '-'.join(['a', 'b']), s.replace('o', '0'), s.count('l'), s.startswith('He'))", "hello world HELLO WORLD ['Hello', 'World'] a-b Hell0 W0rld 3 True", "string methods")
	await _expect_print("x = [3, 1, 2]\nx.sort()\nx.insert(0, 9)\nx.remove(1)\nprint(x, x.index(3))\nx.reverse()\nprint(x)", "[9, 2, 3] 2|[3, 2, 9]", "list methods")

	print("== Slicing, f-strings, sets ==")
	await _expect_print("s = 'ELPPA'
x = [0, 1, 2, 3, 4]
print(s[::-1].lower(), s[1:3], s[-2:], x[::2], x[3:1:-1], x[:], (1, 2, 3)[1:])", "apple LP PA [0, 2, 4] [3, 2] [0, 1, 2, 3, 4] (2, 3)", "slicing")
	await _expect_print("n = 3
name = '마르타'
print(f'{name}님, 사과 {n}개!', f'{n * 2 + 1}', f'{{}}', f'{2 / 3:.2f}')", "마르타님, 사과 3개! 7 {} 0.67", "f-strings")
	await _expect_print("s = {1, 2, 2}
s.add(5)
t = set([2, 3])
print(s, len(s), 2 in s, s | t, s & t, s - t, set(), {1, 2} == {2, 1})", "{1, 2, 5} 3 True {1, 2, 5, 3} {2} {1, 5} set() True", "sets")
	await _expect_run_error("n = 1
print(f'{n:>5}')", "형식", "unsupported f-string spec")
	await _expect_run_error("s = set()
s.remove(1)", "집합 안에", "remove missing from set")

	print("== try / except ==")
	await _expect_print("try:
    print(1 / 0)
except ZeroDivisionError as e:
    print('잡았다', e)
print('계속')", "잡았다 0으로 나눌 수 없어요.|계속", "catch with as")
	await _expect_print("d = {}
try:
    v = d['x']
except (IndexError, KeyError):
    print('k')
finally:
    print('f')", "k|f", "tuple of names and finally")
	await _expect_print("try:
    v = [1][5]
except Exception:
    print('any')", "any", "Exception catches all")
	await _expect_print("for i in range(3):
    try:
        if i == 1:
            int('x')
        print(i)
    except ValueError:
        print('bad')", "0|bad|2", "try inside a loop")
	await _expect_run_error("try:
    print(1 / 0)
except KeyError:
    pass", "0으로", "unmatched except lets the error through")
	await _expect_run_error("try:
    while True:
        pass
except Exception:
    print('no')", "너무 길어요", "endless loops cannot be caught")
	var try_cases := {
		"try:
    move()": "except",
		"except Blocked:
    pass": "try",
		"try:
    move()
except Oops:
    pass": "모르는 예외",
	}
	for src in try_cases:
		var parsed := CodeInterpreter.new().parse(src)
		_expect(not parsed["ok"] and String(parsed["message"]).contains(try_cases[src]), "parse error for %s -> %s" % [JSON.stringify(src), parsed.get("message", "")])
	var lvl1: Dictionary = Levels.ALL[0]
	var caught := await _run_source(lvl1, "repeat 9:
    try:
        move()
    except Blocked:
        pass")
	_expect(caught["result"]["ok"] and caught["world"].at_goal(), "Blocked from a wall can be caught")

	print("== Doors, horses, speech ==")
	var dw := GridWorld.new()
	dw.load_level({"map": ["#####", "#SDG#", "#####"], "facing": "E", "sign": "X", "password": "open"})
	_expect(dw.is_blocked() and dw.say(0, "nope") != "" and dw.say(0, "open") == "" and not dw.is_blocked(), "door opens with the password")
	var hw := GridWorld.new()
	hw.load_level({"map": ["##.##", "#SH.G", "##.##"], "facing": "E", "horse_dir": "S"})
	_expect(hw.horse_ahead() and not hw.move(), "horse blocks the robot")
	hw.tick()
	_expect(hw.horses[0] == Vector2i(2, 2) and hw.move(), "horse steps away, robot passes")
	var sw := GridWorld.new()
	sw.load_level({"map": ["#####", "#SAG#", "#####"], "facing": "E", "customer": "이반", "speech": "{customer}님, 사과 {apples}개"})
	sw.move()
	sw.pick()
	sw.move()
	_expect(sw.failure().get("kind") == "speech" and sw.say(0, "이반님, 사과 1개") == "" and sw.is_solved(), "speech must match the template")

	print("== Item worlds ==")
	var iw := GridWorld.new()
	iw.load_level({"map": ["#######", "#SACKG#", "#######"], "facing": "E", "report": "count"})
	_expect(iw.item_kinds() == ["apple", "carrot", "corn"] and iw.apples_left() == 1, "mixed items load")
	iw.move()
	_expect(iw.item_here() == "apple" and iw.pick() and iw.picked == {"apple": 1}, "pick counts by kind")
	_expect(iw.report({"apple": 2}) != "" and iw.report({"apple": 1}) == "", "report checks counts")
	_expect(iw.face(0, "S") == 1 and iw.face(0, "N") == 2 and iw.face(0, "x") == -1, "face turns")
	var ow := GridWorld.new()
	ow.load_level({"map": ["####", "#SG#", "####"], "facing": "E", "order": {"corn": 2}})
	_expect(ow.drop(0, "corn") != "", "drop only at the goal")
	ow.move()
	ow.drop(0, "corn")
	_expect(ow.failure().get("kind") == "order", "half an order is not solved")
	ow.drop(0, "corn")
	_expect(ow.is_solved(), "full order is solved")

	print("== Chapters and reference steps ==")
	var listed: Array = []
	for ch in Levels.CHAPTERS:
		listed.append_array(ch["levels"])
	var all_levels: Array = range(Levels.ALL.size())
	_expect(listed == all_levels, "chapters list every level once, in order")
	for i in Levels.ALL.size():
		var level: Dictionary = Levels.ALL[i]
		if level.has("seeds"):
			continue
		var w := GridWorld.new()
		w.load_level(Levels.for_map(level, 0))
		var host := WorldHost.new(w)
		await CodeInterpreter.new().run(CodeInterpreter.new().parse(level["solution"])["program"], host, 1)
		_expect(host.commands > 0 and w.is_solved(), "%s reference needs %d commands" % [level["title"], host.commands])

	print("== Villagers and dialogue ==")
	_expect(Dialogue.LEVELS.size() == Levels.ALL.size(), "one dialogue entry per level (%d / %d)" % [Dialogue.LEVELS.size(), Levels.ALL.size()])
	for i in Dialogue.LEVELS.size():
		var d: Dictionary = Dialogue.LEVELS[i]
		var ok_entry: bool = Dialogue.CAST.has(d.get("who", "")) and not d.get("intro", []).is_empty() \
				and String(d.get("success", "")) != "" and d.get("hints", []).size() >= 1
		_expect(ok_entry, "dialogue %d has a known speaker, intro, hints and success" % (i + 1))
	for style in Dialogue.FAIL:
		for kind in ["apples", "goal", "error", "other", "order", "report", "rule", "speech"]:
			_expect(Dialogue.FAIL[style].has(kind), "fail style %s has %s" % [style, kind])
	_expect(SpeechBubble.format("a [code]s[0][/code] b") == "a [color=#2f6db5][code]s[lb]0][/code][/color] b", "bubble formats code and escapes [")
	var holder := Node3D.new()
	get_root().add_child(holder)
	for who in Dialogue.CAST:
		var look: Dictionary = Dialogue.CAST[who]["look"]
		var v := Villager.new()
		holder.add_child(v)
		v.setup(look)
		var names := {}
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			names[String(mi.name)] = mi.visible
		var prefix := "Villager_Male_" if look["model"] == "male" else "Villager_Female_"
		var missing := []
		for p in look["parts"]:
			if not names.get(prefix + p, false) and not names.get(p, false):
				missing.append(p)
		if look.get("item", "") != "" and not names.get(look["item"], false):
			missing.append(look["item"])
		_expect(missing.is_empty(), "villager %s outfit parts exist %s" % [who, missing])
		var head := v.head_position()
		_expect(head.y > 1.6 and head.y < 2.3, "villager %s stands about %.2f m tall" % [who, head.y])
	holder.queue_free()

	print("== Robots and routes ==")
	await _expect_print("r = robots()\nprint(len(r), r[0].name, r[0].get_x(), r[0] == robots()[0])", "1 주황 1 True", "robots() list")
	await _expect_print("print(route(), segments())", "['F', 'F', 'F', 'F'] [4]", "route() on level 1")
	var two := {"map": ["#####", "#S.G#", "#R.G#", "#####"], "facing": "E"}
	var tw := GridWorld.new()
	tw.load_level(two)
	var tp := CodeInterpreter.new().parse("for r in robots():\n    while not r.at_goal():\n        r.move()\n")
	var tr: Dictionary = await CodeInterpreter.new().run(tp["program"], WorldHost.new(tw))
	_expect(tr["ok"] and tw.is_solved() and tw.robot_count() == 2, "two robots each reach a goal")
	var block := {"map": ["#####", "#S.R#", "#..G#", "#..G#", "#####"], "facing": "E"}
	var bw := GridWorld.new()
	bw.load_level(block)
	bw.move(0)
	_expect(bw.is_blocked(0), "a robot blocks another robot")
