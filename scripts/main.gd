extends Control
## Game controller: wires the UI, runs player code on the robot, tracks progress.
## Also acts as the CodeInterpreter host (run_command / check_condition / ...).

signal step_advanced

const SAVE_PATH: String = "user://progress.cfg"
const BASE_STEP_TIME: float = 0.5

const COLOR_CMD := Color(0.98, 0.86, 0.62)
const COLOR_FLOW := Color(0.62, 0.82, 1.0)
const COLOR_COND := Color(0.7, 0.95, 0.62)
const COLOR_VAR := Color(0.95, 0.72, 0.92)
## Methods that take a value: completion inserts "name(" instead of "name()".
const VALUE_METHODS: PackedStringArray = [
	"append", "get", "add", "pop", "remove", "split", "join", "replace", "count", "index", "insert",
	"discard", "startswith", "endswith", "extend", "update", "setdefault", "find", "rfind", "zfill",
	"center", "ljust", "rjust", "format", "union", "intersection", "difference", "symmetric_difference",
	"appendleft", "extendleft", "most_common", "subtract", "rotate",
	"issubset", "issuperset", "isdisjoint", "strip", "lstrip", "rstrip",
]
const VILLAGER_SCALE: float = 1.6
const BUBBLE_TOP_MARGIN: float = 60.0
## Extra meters the camera frames behind the board so the villager and their bubble fit.
const VILLAGER_FRAME_MARGIN: float = 6.0
## Level intro close-up on the villager: camera distance (m), downward pitch (rad), seconds per line.
const INTRO_DISTANCE: float = 7.5
const INTRO_PITCH: float = -0.3
const INTRO_LINE_SECONDS: float = 2.4
## Body colors for robots() order; names are CodeInterpreter.ROBOT_NAMES.
const ROBOT_COLORS: Array[Color] = [
	Color(0.78, 0.5, 0.27), Color(0.3, 0.52, 0.85), Color(0.35, 0.7, 0.35), Color(0.62, 0.42, 0.8),
]
const COLOR_RUN_LINE := Color(1.0, 0.8, 0.3, 0.22)
const COLOR_ERROR_LINE := Color(1.0, 0.3, 0.25, 0.32)

## Palette tool groups: [label, snippet, tooltip, color, inline]
const PALETTE: Dictionary = {
	"move": [["move()", "move()", "앞으로 한 칸 가요", COLOR_CMD, false]],
	"turn": [
		["turn_left()", "turn_left()", "왼쪽으로 90도 돌아요", COLOR_CMD, false],
		["turn_right()", "turn_right()", "오른쪽으로 90도 돌아요", COLOR_CMD, false],
	],
	"pick": [["pick()", "pick()", "발밑의 사과를 주워요", COLOR_CMD, false]],
	"repeat": [["repeat N:", "repeat 3:\n    ", "아래에 들여쓴 줄들을 N번 반복해요", COLOR_FLOW, false]],
	"while": [["while ...:", "while not at_goal():\n    ", "조건이 참인 동안 계속 반복해요", COLOR_FLOW, false]],
	"if": [["if ...:", "if is_blocked():\n    ", "조건이 참일 때만 실행해요", COLOR_FLOW, false]],
	"else": [["else:", "else:\n    ", "if 조건이 거짓일 때 실행해요 (if 와 같은 칸에 맞춰요)", COLOR_FLOW, false]],
	"cond": [
		["is_blocked()", "is_blocked()", "조건: 앞 칸이 막혀 있나요?", COLOR_COND, true],
		["on_apple()", "on_apple()", "조건: 발밑에 사과가 있나요?", COLOR_COND, true],
		["at_goal()", "at_goal()", "조건: 목표에 도착했나요?", COLOR_COND, true],
		["not", "not ", "조건을 반대로 뒤집어요", COLOR_COND, true],
	],
	"var": [
		["n = 0", "n = 0", "변수 n 을 만들고 0을 넣어요", COLOR_VAR, false],
		["n += 1", "n += 1", "n 에 1을 더해요", COLOR_VAR, false],
		["n", "n", "변수 n 의 값", COLOR_VAR, true],
	],
	"ops": [
		["//", " // ", "나눗셈의 몫 (정수): 7 // 2 → 3", COLOR_VAR, true],
		["%", " % ", "나눗셈의 나머지: 7 % 2 → 1", COLOR_VAR, true],
	],
	"print": [["print()", "print()", "값을 콘솔에 보여 줘요", COLOR_CMD, false]],
	"for": [["for i in range(3):", "for i in range(3):\n    ", "i 가 0, 1, 2 로 바뀌며 반복해요", COLOR_FLOW, false]],
	"def": [
		["def walk(n):", "def walk(n):\n    ", "새 명령(함수)을 만들어요. n 은 넣어 줄 값이에요", COLOR_FLOW, false],
		["return", "return ", "함수에서 값을 돌려줘요", COLOR_FLOW, false],
	],
	"pos": [
		["get_x()", "get_x()", "로봇의 가로 위치 (왼쪽 끝이 0)", COLOR_COND, true],
		["get_y()", "get_y()", "로봇의 세로 위치 (위쪽 끝이 0)", COLOR_COND, true],
		["goal_x()", "goal_x()", "목표의 가로 위치", COLOR_COND, true],
		["goal_y()", "goal_y()", "목표의 세로 위치", COLOR_COND, true],
	],
	"apples": [["apples_left()", "apples_left()", "보드에 남은 사과 수", COLOR_COND, true]],
	"abs": [["abs()", "abs()", "절댓값: abs(-3) → 3", COLOR_VAR, true]],
	"math": [
		["import math", "import math", "math 모듈을 가져와요 (맨 위에 적어요)", COLOR_FLOW, false],
		["math.sqrt()", "math.sqrt()", "제곱근: math.sqrt(16) → 4.0", COLOR_VAR, true],
		["int()", "int()", "정수로 바꿔요: int(4.0) → 4", COLOR_VAR, true],
	],
	"not": [["not", "not ", "조건을 반대로 뒤집어요", COLOR_COND, true]],
	"elif": [["elif ...:", "elif is_blocked():\n    ", "앞의 if 가 거짓일 때 다른 조건을 확인해요", COLOR_FLOW, false]],
	"for_in": [["for x in 목록:", "for step in route():\n    ", "목록에서 하나씩 꺼내며 반복해요", COLOR_FLOW, false]],
	"route": [
		["route()", "route()", "목표까지 가는 방법 목록: F 앞으로, L 왼쪽, R 오른쪽", COLOR_COND, true],
		["\"F\"", "\"F\"", "글자 F (따옴표로 감싸요)", COLOR_VAR, true],
		["\"L\"", "\"L\"", "글자 L", COLOR_VAR, true],
	],
	"segments": [["segments()", "segments()", "곧게 가는 칸 수의 목록. 예: [3, 2, 1]", COLOR_COND, true]],
	"list": [
		["len()", "len()", "목록의 길이: len([3, 2, 1]) → 3", COLOR_VAR, true],
		["s[i]", "s[i]", "목록 s 의 i 번째 값 (0번부터)", COLOR_VAR, true],
		["[]", "[]", "빈 목록", COLOR_VAR, true],
		[".append()", ".append()", "목록 끝에 값을 넣어요", COLOR_VAR, true],
	],
	"random": [
		["import random", "import random", "random 모듈을 가져와요 (맨 위에 적어요)", COLOR_FLOW, false],
		["random.randint(1, 3)", "random.randint(1, 3)", "1, 2, 3 중 하나를 무작위로", COLOR_VAR, true],
		["random.choice()", "random.choice([\"L\", \"R\"])", "목록에서 하나를 무작위로 골라요", COLOR_VAR, true],
	],
	"robots": [
		["robots()", "robots()", "로봇 객체 목록 (주황, 파랑, 초록, 보라 순서)", COLOR_COND, true],
		["r.move()", "r.move()", "로봇 r 을 한 칸 움직여요", COLOR_CMD, false],
		["r.pick()", "r.pick()", "로봇 r 이 사과를 주워요", COLOR_CMD, false],
		["r.turn_left()", "r.turn_left()", "로봇 r 이 왼쪽으로 돌아요", COLOR_CMD, false],
		["r.on_apple()", "r.on_apple()", "로봇 r 의 발밑에 사과가 있나요?", COLOR_COND, true],
		["r.at_goal()", "r.at_goal()", "로봇 r 이 목표에 있나요?", COLOR_COND, true],
		["r.is_blocked()", "r.is_blocked()", "로봇 r 의 앞이 막혔나요?", COLOR_COND, true],
	],
	"for_robots": [["for r in robots():", "for r in robots():\n    ", "로봇을 하나씩 r 에 담아 반복해요", COLOR_FLOW, false]],
	"class": [
		["class 이름:", "class Walker:\n    ", "새 객체의 설계도(class)를 만들어요", COLOR_FLOW, false],
		["def __init__(self, robot):", "def __init__(self, robot):\n    ", "객체를 만들 때 처음 실행돼요", COLOR_FLOW, false],
		["self.robot = robot", "self.robot = robot", "객체 안에 값을 저장해요", COLOR_VAR, false],
		["def 메서드(self):", "def go(self):\n    ", "객체의 명령(메서드)을 만들어요", COLOR_FLOW, false],
		["self.", "self.", "이 객체 자신", COLOR_VAR, true],
		["super()", "super()", "물려받은 class 의 메서드를 불러요", COLOR_VAR, true],
	],
}
## More palette groups (same format as PALETTE) for the tuple and dictionary chapters.
const PALETTE_MORE: Dictionary = {
	"tuple_pos": [
		["x, y = get_pos()", "x, y = get_pos()", "지금 위치 튜플 (x, y) 를 두 변수에 나눠 담아요", COLOR_VAR, false],
		["gx, gy = goal_pos()", "gx, gy = goal_pos()", "목표 위치 튜플을 두 변수에 나눠 담아요", COLOR_VAR, false],
		["face(\"E\")", "face(\"E\")", "방향을 바꿔요: \"N\" 북, \"E\" 동, \"S\" 남, \"W\" 서", COLOR_CMD, false],
	],
	"treasure": [
		["treasure_map()", "treasure_map()", "보물 위치 튜플의 목록", COLOR_COND, true],
		["for tx, ty in 목록:", "for tx, ty in treasure_map():\n    ", "튜플을 두 변수에 나눠 꺼내며 반복해요", COLOR_FLOW, false],
	],
	"items": [
		["item_here()", "item_here()", "발밑 물건 이름 (\"apple\", \"carrot\", \"corn\") 또는 None", COLOR_COND, true],
		["is not None", " is not None", "None 이 아닌지 확인해요", COLOR_FLOW, true],
	],
	"dict": [
		["{}", "{}", "빈 딕셔너리", COLOR_VAR, true],
		["d[키]", "count[item]", "딕셔너리에서 키의 값", COLOR_VAR, true],
		[".get(키, 0)", ".get(item, 0)", "키가 없으면 0 을 줘요", COLOR_VAR, true],
		[".items()", ".items()", "(키, 값) 튜플의 목록", COLOR_VAR, true],
	],
	"order": [
		["order()", "order()", "손님의 주문서 딕셔너리", COLOR_COND, true],
		["drop(item)", "drop(item)", "목표에서 물건 하나를 배달해요", COLOR_CMD, false],
	],
	"market": [["market()", "market()", "가격표 딕셔너리", COLOR_COND, true]],
	"report": [["report()", "report()", "알아낸 값을 보고해요", COLOR_CMD, false]],
	"strings": [
		["read_sign()", "read_sign()", "표지판에 적힌 글자", COLOR_COND, true],
		["[::-1]", "[::-1]", "글자나 목록을 거꾸로 뒤집어요", COLOR_VAR, true],
		[".lower()", ".lower()", "소문자로 바꿔요", COLOR_VAR, true],
		["say()", "say()", "로봇이 말해요. 문 앞에서는 암호가 돼요", COLOR_CMD, false],
	],
	"fstring": [
		["f\"...{n}...\"", "f\"{n}\"", "f-문자열: { } 안의 값이 글자 속에 들어가요", COLOR_VAR, true],
		["customer()", "customer()", "손님 이름", COLOR_COND, true],
		["say()", "say()", "로봇이 말해요", COLOR_CMD, false],
	],
	"set": [
		["set()", "set()", "빈 집합 (같은 값은 한 번만 들어가요)", COLOR_VAR, true],
		[".add()", ".add()", "집합에 값을 넣어요", COLOR_VAR, true],
		["not in", " not in ", "들어 있지 않은지 확인해요", COLOR_FLOW, true],
	],
	"input": [
		["input(\"질문\")", "input(\"\")", "마을 사람에게 묻고, 대답(글자)을 돌려받아요", COLOR_VAR, true],
		["name = input(...)", "name = input(\"이름이 뭐예요? \")\n", "대답을 변수에 담아 둬요", COLOR_VAR, false],
	],
	"fstring_say": [
		["say(f\"...\")", "say(f\"{name}\")", "f-문자열로 만든 말을 해요", COLOR_CMD, false],
	],
	"int_input": [
		["int(input(...))", "int(input(\"\"))", "대답을 숫자로 바꿔요: \"3\" → 3", COLOR_VAR, true],
	],
	"drop": [["drop(\"apple\")", "drop()", "목표에서 하나 배달해요", COLOR_CMD, false]],
	"format_spec": [
		["{x:,}", "{total:,}", "f-문자열 안에서 세 자리마다 쉼표: 12500 → 12,500", COLOR_VAR, true],
		["{x:>5}", "{x:>5}", "다섯 칸 오른쪽 정렬", COLOR_VAR, true],
		["{x:.2f}", "{x:.2f}", "소수 둘째 자리까지", COLOR_VAR, true],
	],
	"ord_chr": [
		["ord(\"a\")", "ord()", "글자의 번호: ord(\"a\") → 97", COLOR_VAR, true],
		["chr(97)", "chr()", "번호의 글자: chr(97) → \"a\"", COLOR_VAR, true],
		["% 26", " % 26", "26으로 나눈 나머지: 알파벳 끝에서 처음으로 돌아가요", COLOR_VAR, true],
	],
	"map_filter": [
		["filter(함수, 목록)", "filter(lambda s: s.isdigit(), )", "함수가 True 인 값만 골라요", COLOR_VAR, true],
		["map(함수, 목록)", "map(int, )", "값마다 함수를 적용해요: map(int, [\"1\"]) → [1]", COLOR_VAR, true],
		["sum()", "sum()", "모두 더해요", COLOR_VAR, true],
		[".isdigit()", ".isdigit()", "숫자로만 된 글자인지", COLOR_VAR, true],
	],
	"math_more": [
		["math.hypot(a, b)", "math.hypot(, )", "가로 a, 세로 b 만큼 떨어진 곳까지 곧은 거리", COLOR_VAR, true],
		["math.gcd(a, b)", "math.gcd(, )", "a 와 b 를 모두 나누어떨어지게 하는 가장 큰 수", COLOR_VAR, true],
		["round(x, 2)", "round(, 2)", "소수 둘째 자리까지 반올림", COLOR_VAR, true],
	],
	"random_more": [
		["random.sample(목록, k)", "random.sample(, )", "목록에서 겹치지 않게 k개를 무작위로 뽑아요", COLOR_VAR, true],
		["random.shuffle(목록)", "random.shuffle()", "목록의 순서를 무작위로 섞어요", COLOR_CMD, false],
	],
	"counter": [
		["from collections import Counter", "from collections import Counter\n", "Counter 를 가져와요", COLOR_FLOW, false],
		["Counter(목록)", "Counter()", "값마다 개수를 세어 딕셔너리처럼 돌려줘요", COLOR_VAR, true],
		[".most_common(1)", ".most_common(1)", "가장 많은 것: [(값, 개수)]", COLOR_VAR, true],
	],
	"deque": [
		["from collections import deque", "from collections import deque\n", "deque 를 가져와요", COLOR_FLOW, false],
		["deque()", "deque()", "양쪽 끝에 넣고 뺄 수 있는 줄", COLOR_VAR, true],
		[".appendleft()", ".appendleft()", "맨 앞에 넣어요", COLOR_CMD, true],
		[".popleft()", ".popleft()", "맨 앞을 꺼내요", COLOR_VAR, true],
	],
	"statistics": [
		["import statistics", "import statistics\n", "statistics 모듈을 가져와요", COLOR_FLOW, false],
		["statistics.mean()", "statistics.mean()", "평균", COLOR_VAR, true],
		["statistics.median()", "statistics.median()", "가운데 값(중앙값)", COLOR_VAR, true],
	],
	"itertools": [
		["from itertools import permutations", "from itertools import permutations\n", "permutations 를 가져와요", COLOR_FLOW, false],
		["permutations(목록)", "permutations()", "가능한 모든 순서 (튜플들)", COLOR_VAR, true],
		["min(..., key=함수)", "min(, key=)", "함수 값이 가장 작은 것", COLOR_VAR, true],
	],
	"comprehension": [
		["[x for x in 목록]", "[x for x in ]", "목록의 값마다 계산해서 새 목록을 만들어요", COLOR_VAR, true],
		["... if 조건]", " if ", "조건에 맞는 값만 골라요: [n for n in 목록 if n > 0]", COLOR_FLOW, true],
	],
	"mailboxes": [["mailboxes()", "mailboxes()", "우편함 번호 목록", COLOR_COND, true]],
	"sort_key": [
		["sorted(목록, key=...)", "sorted(, key=lambda p: )", "key 가 돌려준 값 순서대로 줄을 세워요", COLOR_VAR, true],
		["lambda p: ...", "lambda p: ", "이름 없는 작은 함수: 값 p 를 받아 계산 결과를 돌려줘요", COLOR_FLOW, true],
		["sx, sy = get_pos()", "sx, sy = get_pos()", "지금(출발) 위치를 기억해요", COLOR_VAR, false],
	],
	"try": [
		["try / except", "try:
    
except NoItem:
    pass", "오류가 나도 멈추지 않고 except 아래를 실행해요", COLOR_FLOW, false],
		["except Blocked:", "except Blocked:
    ", "부딪혔을 때의 오류를 잡아요", COLOR_FLOW, false],
		["pass", "pass", "아무것도 하지 않아요", COLOR_FLOW, false],
		["wait()", "wait()", "한 번 기다려요 (말이 한 칸 움직여요)", COLOR_CMD, false],
	],
}
const TOOL_ORDER: PackedStringArray = [
	"move", "turn", "pick", "repeat", "for", "for_in", "for_robots", "while", "if", "elif", "else",
	"cond", "not", "var", "ops", "print", "def", "pos", "apples", "abs", "math", "route", "segments",
	"list", "random", "robots", "class", "tuple_pos", "treasure", "items", "dict", "order", "market", "report",
	"strings", "fstring", "set", "try", "comprehension", "mailboxes", "sort_key",
	"input", "fstring_say", "int_input", "drop", "format_spec", "ord_chr", "map_filter",
	"math_more", "random_more", "counter", "deque", "statistics", "itertools",
]

var _level_index: int = 0
var _map_index: int = 0  # 0 = the level's main map, 1+ = hidden variants (Levels.maps)
var _level_loaded: bool = false
var _dev_args: Dictionary = {}  # command-line dev automation; when set, progress is never saved
var _world := GridWorld.new()
var _interp := CodeInterpreter.new()
var _progress := ConfigFile.new()
var _codes: Dictionary = {}  # level index -> code text

var _running: bool = false
var _stop_requested: bool = false
var _step_mode: bool = false
var _step_tokens: int = 0
var _marked_line: int = -1
var _error_line: int = -1
var _speed: float = 1.0
var _run_seed: int = 1  # random seed for the visible run; switches to a failing seed after a hidden check
var _robots: Array[Robot] = []  # robot 0 is the scene's %Robot, extra ones are spawned per level
var _villager: Villager  # the level's quest giver (Dialogue), standing behind the board
var _villager_who: String = ""
var _bubble: SpeechBubble
var _robot_bubble: SpeechBubble  # say() text over robot 0's head
var _hint_stage: int = 0
var _intro_active: bool = false  # camera is on the villager for the level intro
var _sfx: Sfx
var _fast: bool = false  # this run skips animations (the "빨리" button)
var _fast_host: WorldHost  # applies commands to _world without animation in fast runs
var _fast_count: int = 0
var _replay_pending: bool = false  # re-run on the map/seed where the hidden check failed
var _run_commands: int = 0  # robot commands executed in the current run
var _ref_steps: Dictionary = {}  # "level:map" -> commands the reference solution needs (-1: not scored)
var _menu: ChapterMenu
var _fast_btn: Button
var _mute_btn: Button
var _input_box: LineEdit  # where the player types an answer for input() (levels without prepared answers)
var _input_answer: Variant = null  # the submitted text while input() waits
var _press_pos: Vector2 = Vector2(-1000, -1000)
var _word_re := RegEx.create_from_string("([A-Za-z_][A-Za-z_0-9]*)$")
var _dot_re := RegEx.create_from_string("([A-Za-z_][A-Za-z_0-9]*)\\.([A-Za-z_0-9]*)$")
var _ident_re := RegEx.create_from_string("[A-Za-z_][A-Za-z_0-9]*")

@onready var _board: Board = %Board
@onready var _robot: Robot = %Robot
@onready var _cam: CameraRig = %CameraRig
@onready var _code: CodeEdit = %CodeEdit
@onready var _console: RichTextLabel = %Console
@onready var _palette: HFlowContainer = %Palette
@onready var _level_select: OptionButton = %LevelSelect
@onready var _level_title: Label = %LevelTitle
@onready var _goal_text: RichTextLabel = %GoalText
@onready var _hud: Label = %HudLabel
@onready var _run_btn: Button = %RunButton
@onready var _step_btn: Button = %StepButton
@onready var _reset_btn: Button = %ResetButton
@onready var _result: Control = %ResultOverlay
@onready var _view: SubViewportContainer = %ViewContainer
@onready var _camera: Camera3D = %CameraRig.get_node("Camera3D")


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_dev_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	_progress.load(SAVE_PATH)
	_setup_code_edit()
	_connect_ui()
	_villager = Villager.new()
	_villager.name = "Villager"
	_robot.get_parent().add_child(_villager)
	_bubble = SpeechBubble.new()
	_bubble.name = "SpeechBubble"
	add_child(_bubble)  # last child: drawn above the 3D view and the result card's dim
	_bubble.typing_changed.connect(func(typing: bool) -> void: _villager.talk(typing))
	_bubble.closed.connect(_end_intro)
	_robot_bubble = SpeechBubble.new()
	_robot_bubble.name = "RobotBubble"
	add_child(_robot_bubble)
	_sfx = Sfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	_sfx.muted = bool(_progress.get_value("meta", "muted", false))
	_setup_extra_ui()
	_setup_sky()
	_menu = ChapterMenu.new()
	_menu.name = "ChapterMenu"
	add_child(_menu)  # above everything else
	_menu.level_chosen.connect(_change_level)
	_menu.unlock_all_toggled.connect(_on_unlock_all_toggled)
	_refresh_level_select()
	var start_level := clampi(int(_progress.get_value("meta", "last_level", 0)), 0, Levels.ALL.size() - 1)
	while Levels.prev_of(start_level) >= 0 and not _unlocked(start_level):
		start_level = Levels.prev_of(start_level)
	_load_level(start_level)
	if _dev_args.is_empty():
		_open_menu()
	_run_dev_automation()


## Buttons that are not in the scene file: fast run, sound on/off, chapter screen.
func _setup_extra_ui() -> void:
	var controls := _run_btn.get_parent()
	_fast_btn = Button.new()
	_fast_btn.text = "⏩ 빨리"
	_fast_btn.tooltip_text = "애니메이션 없이 바로 결과를 봐요 (F7). 실행 중에 누르면 남은 부분을 빨리 끝내요."
	_fast_btn.pressed.connect(_on_fast_pressed)
	controls.add_child(_fast_btn)
	controls.move_child(_fast_btn, _step_btn.get_index() + 1)
	_mute_btn = Button.new()
	_mute_btn.tooltip_text = "효과음 켜기/끄기"
	_mute_btn.pressed.connect(_on_mute_pressed)
	controls.add_child(_mute_btn)
	controls.move_child(_mute_btn, %HintButton.get_index())
	_update_mute_button()
	var chapters := Button.new()
	chapters.text = "📖"
	chapters.tooltip_text = "챕터 선택"
	chapters.pressed.connect(_open_menu)
	var title_row := %PrevButton.get_parent()
	title_row.add_child(chapters)
	title_row.move_child(chapters, 0)
	_input_box = LineEdit.new()
	_input_box.placeholder_text = "input() 의 대답을 적고 Enter"
	_input_box.visible = false
	_input_box.text_submitted.connect(func(text: String) -> void: _input_answer = text)
	var console_card := _console.get_parent()
	console_card.get_parent().add_child(_input_box)
	console_card.get_parent().move_child(_input_box, console_card.get_index() + 1)


## Stylized sky (EmacEArt shader) instead of the plain procedural one; it also lights the scene.
func _setup_sky() -> void:
	var env_node := get_node_or_null("Layout/ViewContainer/SubViewport/WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment and env_node.environment.sky:
		env_node.environment.sky.sky_material = load("res://shaders/sky_slavica.tres")


# --- Setup ----------------------------------------------------------------

func _setup_code_edit() -> void:
	var hl := CodeHighlighter.new()
	hl.number_color = Color(0.95, 0.65, 0.95)
	hl.symbol_color = Color(0.75, 0.72, 0.66)
	hl.function_color = Color(0.9, 0.9, 0.9)
	hl.member_variable_color = Color(0.92, 0.89, 0.83)
	for word in ["repeat", "while", "if", "elif", "else", "not", "and", "or", "for", "in", "def",
			"return", "break", "continue", "pass", "import", "global", "True", "False", "None",
			"class", "self", "is", "del", "try", "except", "finally"]:
		hl.add_keyword_color(word, COLOR_FLOW)
	for word in CodeInterpreter.COMMANDS:
		hl.add_keyword_color(word, COLOR_CMD)
	for word in CodeInterpreter.CONDITIONS + CodeInterpreter.SENSORS:
		hl.add_keyword_color(word, COLOR_COND)
	for word in CodeInterpreter.BUILTINS:
		hl.add_keyword_color(word, COLOR_VAR)
	hl.add_color_region("#", "", Color(0.55, 0.52, 0.46), true)
	hl.add_color_region("\"", "\"", Color(0.85, 0.8, 0.55))
	hl.add_color_region("'", "'", Color(0.85, 0.8, 0.55))
	_code.syntax_highlighter = hl
	_code.indent_size = 4
	_code.code_completion_enabled = true
	_code.code_completion_prefixes = ["."]
	_code.code_completion_requested.connect(_on_completion_requested)


func _connect_ui() -> void:
	_run_btn.pressed.connect(_on_run_pressed)
	_step_btn.pressed.connect(_on_step_pressed)
	_reset_btn.pressed.connect(_on_reset_pressed)
	%HintButton.pressed.connect(_on_hint_pressed)
	%PrevButton.pressed.connect(func() -> void: _change_level(Levels.prev_of(_level_index)))
	%NextButton.pressed.connect(func() -> void: _change_level(Levels.next_of(_level_index)))
	_level_select.item_selected.connect(func(item: int) -> void: _change_level(_level_select.get_item_id(item)))
	%SpeedSlider.value_changed.connect(_on_speed_changed)
	%RetryButton.pressed.connect(_on_retry_pressed)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	_code.text_changed.connect(_on_code_changed)


func _refresh_level_select() -> void:
	_level_select.clear()
	for i in Levels.order():
		var stars := _stars(i)
		var label := "레벨 %d" % Levels.number(i)
		if not _unlocked(i):
			label = "🔒 " + label
		elif stars > 0:
			label += "  " + "★".repeat(stars)
		_level_select.add_item(label, i)
		_level_select.set_item_disabled(_level_select.get_item_index(i), not _unlocked(i))
	_select_current()
	_update_nav()


func _stars(i: int) -> int:
	return int(_progress.get_value("stars", str(i), 0))


func _unlock_all() -> bool:
	return bool(_progress.get_value("meta", "unlock_all", false))


## A level opens once the one before it (in play order) is cleared; dev runs and
## "모든 레벨 열기" open everything.
func _unlocked(i: int) -> bool:
	var dev_open := not _dev_args.is_empty() and not _dev_args.has("locks")
	var prev := Levels.prev_of(i)
	# A level already cleared stays open even if a new level was inserted before it.
	return prev < 0 or _unlock_all() or dev_open or _stars(prev) > 0 or _stars(i) > 0


func _select_current() -> void:
	_level_select.select(_level_select.get_item_index(_level_index))


func _update_nav() -> void:
	%PrevButton.disabled = _running or Levels.prev_of(_level_index) < 0
	var next := Levels.next_of(_level_index)
	%NextButton.disabled = _running or next < 0 or not _unlocked(next)


func _open_menu() -> void:
	if _running:
		return
	var stars: Array = []
	for i in Levels.ALL.size():
		stars.append(_stars(i))
	_menu.open(stars, _unlocked, _unlock_all(), _level_index)


## Test commands: type one alone in the code editor and press ▶ 실행. "#unlock" opens every level,
## "#lock" turns the locks back on (the same setting as the teacher checkbox, kept in the save).
## The level's code comes back afterwards and the command itself is never saved.
func _test_command(text: String) -> bool:
	if text != "#unlock" and text != "#lock":
		return false
	var on := text == "#unlock"
	_code.text = _codes.get(_level_index, _progress.get_value("code", str(_level_index), Levels.ALL[_level_index]["starter"]))
	_on_unlock_all_toggled(on)
	_log("모든 레벨을 열었어요. 다시 잠그려면 #lock 을 실행해요." if on else "레벨 잠금을 다시 켰어요.", "#9fd4ff")
	return true


func _on_unlock_all_toggled(on: bool) -> void:
	_progress.set_value("meta", "unlock_all", on)
	_save_progress()
	_refresh_level_select()
	_open_menu()


func _build_palette(tools: Array, banned: Array) -> void:
	for child in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	var entries: Array = []
	for group in TOOL_ORDER:
		if not group in tools:
			continue
		for entry in PALETTE.get(group, PALETTE_MORE.get(group, [])):
			var hidden := false
			for b in banned:
				if String(entry[0]).contains(b + "("):
					hidden = true
			if not hidden and not entries.any(func(e: Array) -> bool: return e[0] == entry[0]):
				entries.append(entry)
	# Later levels show many blocks; shrink them so the code editor keeps its room.
	var compact := entries.size() > 12
	_palette.add_theme_constant_override("v_separation", 3 if compact else 6)
	_palette.add_theme_constant_override("h_separation", 4 if compact else 6)
	for entry in entries:
		var btn := Button.new()
		btn.text = entry[0]
		btn.tooltip_text = entry[2]
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_color_override("font_color", entry[3])
		btn.add_theme_font_size_override("font_size", 13 if compact else 16)
		btn.pressed.connect(_insert_snippet.bind(entry[1], entry[4]))
		_palette.add_child(btn)


# --- Levels ---------------------------------------------------------------

func _change_level(index: int) -> void:
	if _running or index < 0 or index >= Levels.ALL.size() or not _unlocked(index):
		_select_current()
		return
	_load_level(index)


func _load_level(index: int) -> void:
	if _level_loaded:
		_save_code()
	_level_loaded = true
	_level_index = index
	var level: Dictionary = Levels.ALL[index]
	_show_map(0)

	_level_title.text = Levels.title(index)
	var goal: String = level["goal"]
	var banned: Array = level.get("banned", [])
	if not banned.is_empty():
		var names := PackedStringArray()
		for b in banned:
			names.append(b + "()")
		goal += "\n[color=#ff9f8a]이 레벨에서 못 쓰는 것: %s[/color]" % ", ".join(names)
	_goal_text.text = goal
	_select_current()
	_update_nav()
	_build_palette(level["tools"], level.get("banned", []))

	var code: String = _codes.get(index, _progress.get_value("code", str(index), level["starter"]))
	_code.text = code
	_code.clear_undo_history()
	_code.set_caret_line(_code.get_line_count() - 1)
	_code.set_caret_column(_code.get_line(_code.get_line_count() - 1).length())
	_clear_marks()
	_result.hide()

	_console.clear()
	_log("[b]%s[/b]" % Levels.title(index), "#ffd36b")
	_log("코드를 적고 [b]▶ 실행[/b]을 눌러요. 막히면 [b]힌트[/b]!")
	_update_hud()
	_hint_stage = 0
	var npc := Dialogue.for_level(index)
	if not npc.is_empty():
		_start_intro(npc["intro"])
	_progress.set_value("meta", "last_level", index)
	_save_progress()


## Loads one of the current level's maps (0 = main, 1+ = hidden variant) and rebuilds the board.
func _show_map(map_index: int) -> void:
	_map_index = map_index
	_world.load_level(Levels.for_map(Levels.ALL[_level_index], map_index))
	_board.build(_world)
	_place_robots()
	_place_villager()
	_cam.frame(Vector2(_world.width, _world.height) * Board.CELL, VILLAGER_FRAME_MARGIN if _villager.visible else 0.0)
	_update_hud()


## Dresses the villager as this level's speaker and stands them just behind the board's far
## edge, in line with the goal, facing the camera.
func _place_villager() -> void:
	var who: String = Dialogue.for_level(_level_index).get("who", "")
	_villager.visible = who != ""
	if who == "":
		return
	if who != _villager_who:
		_villager.setup(Dialogue.CAST[who]["look"])
		_villager_who = who
	# One column beside the goal, so the goal's light beam never stands between camera and villager.
	var col := _world.goal.x + 1 if _world.goal.x + 1 <= _world.width - 2 else _world.goal.x - 1
	col = clampi(col, 1, maxi(1, _world.width - 2))
	_villager.position = _board.cell_to_world(Vector2i(col, -1)) + Vector3(0, 0, -0.3)
	_villager.rotation.y = 0.0
	# Larger than life: the far edge of the board is small on screen.
	_villager.scale = Vector3.ONE * VILLAGER_SCALE


## Level intro: the camera starts on the villager's face, the request plays line by line, then
## the camera glides back to the board. A click skips a line; Run (or Esc) ends it at once.
func _start_intro(lines: Array) -> void:
	var look_at := _villager.global_position + Vector3(0, 1.45 * VILLAGER_SCALE, 0)
	_cam.focus_on(look_at, INTRO_DISTANCE, INTRO_PITCH, true)
	_intro_active = true
	_npc_say(lines, Villager.Mood.IDLE, 0.0, INTRO_LINE_SECONDS)


func _end_intro() -> void:
	if _intro_active:
		_intro_active = false
		_cam.show_board()


## Shows lines in the villager's bubble. mood: Villager.Mood for a reaction (HAPPY/SAD).
func _npc_say(lines: Array, mood: int = Villager.Mood.IDLE, hold: float = 0.0, auto: float = 0.0) -> void:
	var who := Dialogue.speaker(_level_index)
	if who.is_empty() or lines.is_empty():
		return
	if mood != Villager.Mood.IDLE:
		_villager.say_mood(mood, 2.5)
	_bubble.say(who["name"], lines, hold, auto)


func _npc_fail(kind: String, values: Dictionary = {}) -> void:
	_npc_say([Dialogue.fail_line(_level_index, kind, values)], Villager.Mood.SAD)


func _process(_delta: float) -> void:
	var hover := not _running and not _menu.visible and _over_villager(get_viewport().get_mouse_position())
	_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover else Control.CURSOR_ARROW
	if _bubble.visible and _villager.visible:
		var head := _villager.head_position()
		var view := _view.get_global_rect()
		var target := view.get_center() if _camera.is_position_behind(head) else view.position + _camera.unproject_position(head)
		# Keep clear of the HUD panel along the top of the view.
		_bubble.point_at(target, view.grow_side(SIDE_TOP, -BUBBLE_TOP_MARGIN))
	if _robot_bubble.visible:
		var view := _view.get_global_rect()
		var head := _robot.global_position + Vector3(0, 2.4, 0)
		if not _camera.is_position_behind(head):
			_robot_bubble.point_at(view.position + _camera.unproject_position(head), view.grow_side(SIDE_TOP, -BUBBLE_TOP_MARGIN))


## Puts the robot and apples back without rebuilding the scenery.
func _reset_board() -> void:
	_world.reset()
	_board.reset_items(_world)
	_place_robots()
	_update_hud()


## Makes one Robot node per robot in the world (spawning or removing extras) and puts each on its start.
func _place_robots() -> void:
	if _robots.is_empty():
		_robots.append(_robot)
	while _robots.size() < _world.robot_count():
		var extra := Robot.new()
		extra.name = "Robot%d" % _robots.size()
		_robot.get_parent().add_child(extra)
		_robots.append(extra)
	while _robots.size() > _world.robot_count():
		_robots.pop_back().queue_free()
	for i in _robots.size():
		_robots[i].set_body_color(ROBOT_COLORS[i % ROBOT_COLORS.size()])
		var tag := CodeInterpreter.ROBOT_NAMES[i % CodeInterpreter.ROBOT_NAMES.size()] if _robots.size() > 1 else ""
		_robots[i].set_label(tag, ROBOT_COLORS[i % ROBOT_COLORS.size()])
		_robots[i].place(_board.surface(_world.robots[i]), _world.dirs[i])


# --- Running --------------------------------------------------------------

func _on_run_pressed() -> void:
	if _running:
		if _step_mode:
			_step_mode = false
			step_advanced.emit()
		return
	_start_run(false)


## "빨리": run without animations, or finish the current run without them.
func _on_fast_pressed() -> void:
	if _running:
		_fast = true
		_step_mode = false
		step_advanced.emit()
		return
	_start_run(false, true)


func _on_mute_pressed() -> void:
	_sfx.muted = not _sfx.muted
	_progress.set_value("meta", "muted", _sfx.muted)
	_save_progress()
	_update_mute_button()


func _update_mute_button() -> void:
	_mute_btn.text = "🔇" if _sfx.muted else "🔊"


func _on_step_pressed() -> void:
	if _running:
		_step_mode = true
		_step_tokens += 1
		step_advanced.emit()
		return
	_start_run(true)


func _on_reset_pressed() -> void:
	if _running:
		_stop_requested = true
		step_advanced.emit()
		return
	_clear_marks()
	_reset_board()
	_log("처음 상태로 돌아왔어요.", "#b8ad9c")


func _start_run(step_mode: bool, fast: bool = false) -> void:
	if _test_command(_code.text.strip_edges()):
		return
	_result.hide()
	_bubble.dismiss()
	_robot_bubble.dismiss()
	_clear_marks()
	_reset_board()
	_save_code()
	var level: Dictionary = Levels.ALL[_level_index]
	var parsed := _interp.parse(_code.text, PackedStringArray(level.get("banned", [])),
			PackedStringArray(level.get("required", [])))
	if not parsed["ok"]:
		_show_error(parsed)
		_robot.shrug(0.6)
		return

	_running = true
	_stop_requested = false
	_fast = fast
	_fast_count = 0
	_run_commands = 0
	_fast_host = WorldHost.new(_world)
	_step_mode = step_mode
	_step_tokens = 1 if step_mode else 0
	_set_running_ui(true)
	_log("실행!" if not step_mode else "한 단계씩 실행해요. [b]한 단계[/b]를 계속 눌러요.", "#9fd4ff")
	if level.has("seeds"):
		_log("주사위 시드: %d (같은 시드면 random 결과도 같아요)" % _run_seed, "#b8ad9c")

	var result: Dictionary = await _interp.run(parsed["program"], self, _run_seed)

	if _fast:
		_sync_visuals()
	_fast = false
	_update_hud()
	_set_marked_line(-1)
	if result.get("stopped", false):
		_log("멈췄어요. 처음 상태로 돌아갔어요.", "#b8ad9c")
		_reset_board()
	elif not result["ok"]:
		_show_error(result)
	else:
		# Stay in the running state until the celebration and result overlay are done,
		# so the player cannot start another run or switch levels in between.
		await _evaluate_finish(parsed["program"])
	_running = false
	_set_running_ui(false)
	if _replay_pending:
		# Show the failing map/seed right away instead of leaving the player to press Run again.
		_replay_pending = false
		_log("그 경우로 다시 실행해 볼게요.", "#b8ad9c")
		var level_at_start := _level_index
		await get_tree().create_timer(1.2).timeout
		if not _running and _level_index == level_at_start:
			_start_run(false)


## After a fast run: put robots and horses where the world says they are.
func _sync_visuals() -> void:
	for i in mini(_robots.size(), _world.robot_count()):
		_robots[i].place(_board.surface(_world.robots[i]), _world.dirs[i])
	_board.move_horses(_world, 0.05)
	_update_hud()


func _evaluate_finish(program: Array) -> void:
	if _world.is_solved():
		var failed := await _check_other_maps(program)
		if not failed.is_empty():
			var other_map := int(failed["map"]) != _map_index
			if other_map:
				_log("이 길에서는 성공! 하지만 다른 길에서는 실패했어요: %s" % failed["reason"], "#ffb35c")
				_log("그 길을 보여줄게요. 어느 길에서나 통하는 코드를 만들어 보세요.", "#ffb35c")
			else:
				_log("이번엔 성공! 하지만 주사위 시드 %d 에서는 실패했어요: %s" % [failed["seed"], failed["reason"]], "#ffb35c")
				_log("다음 실행은 그 시드로 해요. 운이 나빠도 통하는 코드를 만들어 보세요.", "#ffb35c")
			_npc_fail("other")
			_sfx.play("fail")
			await _robot.shrug(0.6)
			_run_seed = int(failed["seed"])
			_replay_pending = true
			if other_map:
				_show_map(int(failed["map"]))
			else:
				_update_hud()
			return
		var lines := CodeInterpreter.count_code_lines(_code.text)
		var par := int(Levels.ALL[_level_index]["par"])
		var steps := _run_commands
		var ref := _reference_steps(_level_index, _map_index)
		# One star off for each: more lines than par, many more lines, more commands than needed.
		var stars := 3
		if lines > par:
			stars -= 1
		if lines > par + 3:
			stars -= 1
		if ref >= 0 and steps > ref:
			stars -= 1
		stars = maxi(1, stars)
		if ref >= 0:
			_log("성공! 코드 %d줄 (목표 %d줄) · 명령 %d번 (목표 %d번)" % [lines, par, steps, ref], "#9dff8a")
		else:
			_log("성공! 코드 %d줄 (목표 %d줄)" % [lines, par], "#9dff8a")
		_sfx.play("success")
		var best := int(_progress.get_value("stars", str(_level_index), 0))
		_progress.set_value("stars", str(_level_index), maxi(best, stars))
		_save_progress()
		_refresh_level_select()
		_npc_say([Dialogue.for_level(_level_index).get("success", "")], Villager.Mood.HAPPY)
		await _robot.celebrate()
		_show_result(stars, lines, par, steps, ref)
	else:
		var f := _world.failure()
		_log(_failure_text(_world, f), "#ffb35c")
		_npc_fail(f["kind"], {"left": f.get("left", 0)})
		_sfx.play("fail")
		_robot.shrug(0.6)


## Robot commands the reference solution needs on this map (cached), or -1 for levels whose
## result depends on random seeds. Runs synchronously on a WorldHost.
func _reference_steps(level_index: int, map_index: int) -> int:
	var key := "%d:%d" % [level_index, map_index]
	if _ref_steps.has(key):
		return _ref_steps[key]
	var level: Dictionary = Levels.ALL[level_index]
	var steps := -1
	if not level.has("seeds"):
		var parsed := CodeInterpreter.new().parse(level["solution"])
		var w := GridWorld.new()
		w.load_level(Levels.for_map(level, map_index))
		var host := WorldHost.new(w)
		CodeInterpreter.new().run(parsed["program"], host, 1)  # no real await inside: finishes now
		steps = host.commands if w.is_solved() else -1
	_ref_steps[key] = steps
	return steps


## Console text for GridWorld.failure().
static func _failure_text(w: GridWorld, f: Dictionary) -> String:
	match String(f.get("kind", "")):
		"goal":
			if w.robot_count() > 1:
				return "코드가 끝났지만 아직 목표에 도착하지 않은 로봇이 있어요."
			return "코드가 끝났지만 아직 목표에 도착하지 않았어요."
		"apples":
			var what := "사과" if w.item_kinds() == ["apple"] else "물건"
			return "목표에 도착했지만 %s이(가) %d개 남았어요." % [what, int(f["left"])]
		"order":
			return "주문과 배달이 달라요. 주문: %s / 배달: %s" % [GridWorld._show(w.wanted), GridWorld._show(w.delivered)]
		"report":
			if w.reported == null:
				return "아직 report() 로 보고하지 않았어요."
			return "보고한 값이 실제와 달라요. 실제 값: %s" % GridWorld._show(w.expected_report())
		"rule":
			return "종류마다 딱 하나씩만 주워야 해요. 주운 것: %s" % GridWorld._show(w.picked)
		"route":
			return "목표에 도착했지만 더 짧은 순서가 있어요. 걸은 칸: %d / 가장 짧으면: %d" % [int(f["steps"]), int(f["best"])]
		"speech":
			return "손님에게 아직 제대로 인사하지 않았어요. 들어야 할 말: \"%s\"" % w.expected_speech()
	return ""


## Runs the program on every other map and random seed of the level (hidden variants, and
## the main map when a variant is shown). Returns {} when all are solved,
## else {"map": int, "seed": int, "reason": String}.
func _check_other_maps(program: Array) -> Dictionary:
	var level: Dictionary = Levels.ALL[_level_index]
	for check in WorldHost.checks(level):
		var i := int(check["map"])
		var s := int(check["seed"])
		if i == _map_index and s == _run_seed:
			continue
		var run: Dictionary = await WorldHost.run_on_map(level, i, program, s)
		var result: Dictionary = run["result"]
		var w: GridWorld = run["world"]
		var reason := ""
		if not result["ok"]:
			reason = "%d번째 줄에서 %s" % [int(result["line"]) + 1, result["message"]]
		elif not w.is_solved():
			reason = _failure_text(w, w.failure())
		if reason != "":
			return {"map": i, "seed": s, "reason": reason}
	return {}


func _set_running_ui(running: bool) -> void:
	_code.editable = not running
	_run_btn.text = "▶ 계속" if running else "▶ 실행"
	_reset_btn.text = "■ 멈춤" if running else "■ 처음으로"
	_level_select.disabled = running
	_update_nav()
	_fast_btn.text = "⏩ 끝까지" if running else "⏩ 빨리"
	for btn in _palette.get_children():
		(btn as Button).disabled = running


func _step_time() -> float:
	return BASE_STEP_TIME / _speed


# --- Interpreter host API -------------------------------------------------

func is_stop_requested() -> bool:
	return _stop_requested


func highlight_line(line: int) -> void:
	_set_marked_line(line)


func sense(name: String, robot: int = 0) -> Variant:
	return _world.call(name, robot)


func robot_count() -> int:
	return _world.robot_count()


func print_line(text: String) -> void:
	_log(_escape(text), "#f2ead8")


## input(): the villager answers with the level's next prepared answer ("inputs"); levels without
## prepared answers let the player type one. null when the run was stopped.
func input_line(prompt: String) -> Variant:
	await _wait_step()
	if _stop_requested:
		return null
	var answer: Variant = _world.next_input()
	if answer != null:
		_log(_escape(prompt) + "[color=#9fd4ff]%s[/color]" % _escape(str(answer)), "#f2ead8")
		if not _fast:
			_npc_say([_escape(str(answer))], Villager.Mood.IDLE, 0.0, 1.2)
			await get_tree().create_timer(maxf(0.4, _step_time() * 2.5)).timeout
		return answer
	if Levels.ALL[_level_index].has("input_lists"):
		return null  # the villager has no more answers: EOFError, like Python at the end of input
	_log(_escape(prompt) + "[color=#9fd4ff](대답을 아래 칸에 적어 주세요)[/color]", "#f2ead8")
	_input_answer = null
	_input_box.text = ""
	_input_box.placeholder_text = (prompt.strip_edges() + "  " if prompt.strip_edges() != "" else "") + "대답을 적고 Enter"
	_input_box.visible = true
	_input_box.grab_focus()
	while _input_answer == null and not _stop_requested:
		await get_tree().process_frame
	_input_box.visible = false
	_code.grab_focus()
	if _stop_requested:
		return null
	_log("→ " + _escape(str(_input_answer)), "#9fd4ff")
	return _input_answer


## In step mode every condition check and assignment is its own step, and is shown.
## `value` is the bool result of a condition, or null for an assignment.
func show_step(line: int, text: String, value: Variant) -> void:
	if not _step_mode:
		return
	_set_marked_line(line)
	await _wait_step()
	if _stop_requested:
		return
	if typeof(value) == TYPE_NIL:
		_log("%d번째 줄: %s" % [line + 1, _escape(text)], "#e6b8e0")
	elif value:
		_log("%d번째 줄: %s → 참" % [line + 1, _escape(text)], "#a8e89a")
	else:
		_log("%d번째 줄: %s → 거짓" % [line + 1, _escape(text)], "#ffb35c")


## In step mode, waits until the player presses "한 단계" (or switches to continuous run).
func _wait_step() -> void:
	while _step_mode and _step_tokens <= 0 and not _stop_requested:
		await step_advanced
	_step_tokens = maxi(0, _step_tokens - 1)


func run_command(name: String, line: int, robot: int = 0, args: Array = []) -> String:
	_set_marked_line(line)
	await _wait_step()
	if _stop_requested:
		return ""
	_run_commands += 1
	_update_hud()
	if _fast:
		var fast_message := _command_fast(name, robot, args)
		_world.tick()
		_fast_count += 1
		if _fast_count % 25 == 0:
			_sync_visuals()
			await get_tree().process_frame  # keep the window responsive during long runs
		return fast_message
	var message: String = await _command(name, robot, args)
	# Horses take their step after every robot command, like in WorldHost.
	if _world.tick() > 0:
		_board.move_horses(_world, _step_time() * 0.8)
		_sfx.play("hoof", 0.1)
	return message


## The same rules as _command, applied through WorldHost with no animation; only the board items
## (apples, doors) and the console are updated as they change.
func _command_fast(name: String, robot: int, args: Array) -> String:
	var cell := _world.robots[robot]
	var doors_before := _world.doors.duplicate()
	var message := _fast_host._command(name, robot, args)
	if name == "pick" and message == "":
		_board.collect_apple(cell)
	for d in doors_before:
		if not _world.doors.has(d):
			_board.open_door(d)
	match name:
		"drop":
			if message == "":
				_log("배달: %s" % GridWorld.ITEM_NAMES[args[0]], "#e6b8e0")
		"report":
			_log("보고: %s" % GridWorld._show(args[0]), "#e6b8e0")
		"say":
			_log("로봇: \"%s\"" % _escape(str(args[0])), "#e6b8e0")
	if message == "":
		return ""
	var who := "" if _world.robot_count() == 1 else "%s 로봇: " % CodeInterpreter.ROBOT_NAMES[robot]
	return who + message


func _command(name: String, robot: int, args: Array) -> String:

	var t := _step_time()
	var node: Robot = _robots[robot]
	var who := "" if _world.robot_count() == 1 else "%s 로봇: " % CodeInterpreter.ROBOT_NAMES[robot]
	match name:
		"move":
			if _world.is_blocked(robot):
				var horse := _world.horse_ahead(robot)
				_sfx.play("bump")
				await node.bump(t * 1.2)
				return who + (WorldHost.BLOCKED_HORSE if horse else WorldHost.BLOCKED)
			_world.move(robot)
			_sfx.play("move", 0.12)
			await node.move_to(_board.surface(_world.robots[robot]), t)
		"turn_left":
			_world.turn_left(robot)
			_sfx.play("turn", 0.1)
			await node.turn(PI * 0.5, t * 0.7)
		"turn_right":
			_world.turn_right(robot)
			_sfx.play("turn", 0.1)
			await node.turn(-PI * 0.5, t * 0.7)
		"pick":
			if _world.item_here(robot) == null:
				_sfx.play("bump")
				await node.shrug(t * 1.2)
				return who + ("여기에는 사과가 없어요." if _world.item_kinds() == ["apple"] else "여기에는 주울 것이 없어요.")
			var cell := _world.robots[robot]
			if not _world.pick(robot):
				_sfx.play("bump")
				await node.shrug(t * 1.2)
				return who + _world.last_pick_error
			_sfx.play("pick", 0.05)
			_board.collect_apple(cell)
			await node.pick_up(t)
			_update_hud()
		"face":
			var turns := _world.face(robot, args[0])
			if turns < 0:
				await node.shrug(t * 1.2)
				return who + WorldHost.FACE_ERROR % str(args[0])
			if turns > 0:
				_sfx.play("turn", 0.1)
			if turns == 3:
				await node.turn(PI * 0.5, t * 0.7)
			for i in (turns if turns < 3 else 0):
				await node.turn(-PI * 0.5, t * 0.7)
		"drop":
			var err := _world.drop(robot, args[0])
			if err != "":
				await node.shrug(t * 1.2)
				return who + err
			_board.show_drop(_world.robots[robot], String(args[0]))
			_sfx.play("drop", 0.05)
			_log("배달: %s" % GridWorld.ITEM_NAMES[args[0]], "#e6b8e0")
			await node.pick_up(t)
		"report":
			var err := _world.report(args[0])
			_log("보고: %s" % GridWorld._show(args[0]), "#e6b8e0")
			if err != "":
				await node.shrug(t * 1.2)
				return who + err
			_villager.say_mood(Villager.Mood.TALK, 1.0)
		"say":
			var door := _world.front(robot)
			var had_door := _world.doors.has(door)
			var err := _world.say(robot, args[0])
			_sfx.play("say", 0.05)
			if robot == 0:
				_robot_bubble.say("로봇", [str(args[0]).replace("[", "[lb]")], maxf(1.2, t * 3.0))
			_log("로봇: \"%s\"" % _escape(str(args[0])), "#e6b8e0")
			await get_tree().create_timer(maxf(0.3, t * 1.5)).timeout
			if err != "":
				await node.shrug(t * 1.2)
				return who + err
			if had_door and not _world.doors.has(door):
				_board.open_door(door)
				_sfx.play("door")
				await get_tree().create_timer(t).timeout
		"wait":
			_sfx.play("click")
			await get_tree().create_timer(t * 0.8).timeout
	return ""


# --- Code editor helpers --------------------------------------------------

func _insert_snippet(snippet: String, inline: bool) -> void:
	if _running:
		return
	if inline:
		_code.insert_text_at_caret(snippet)
		_code.grab_focus()
		return
	var line := _code.get_caret_line()
	var text := _code.get_line(line)
	var indent := text.substr(0, text.length() - text.lstrip(" \t").length())
	var body := snippet.replace("\n", "\n" + indent)
	_code.set_caret_column(text.length())
	if text.strip_edges().is_empty():
		_code.insert_text_at_caret(body)
	else:
		_code.insert_text_at_caret("\n" + indent + body)
	_code.grab_focus()


func _on_code_changed() -> void:
	if _error_line >= 0 and _error_line < _code.get_line_count():
		_code.set_line_background_color(_error_line, Color(0, 0, 0, 0))
	_error_line = -1
	_update_hud()
	# Offer completions while a word is being typed (2+ letters), but not inside text or comments.
	var before := _code.get_line(_code.get_caret_line()).substr(0, _code.get_caret_column())
	var m := _word_re.search(before)
	if m and m.get_string(1).length() >= 2 and _in_code(before) and _code.has_focus():
		_code.request_code_completion()


## True when the end of `before` is code, not inside a "string" or after a # comment.
static func _in_code(before: String) -> bool:
	var quote := ""
	for ch in before:
		if quote != "":
			if ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			return false
	return quote == ""


## Completion list: after "x." the members that fit x; otherwise keywords, builtins, this level's
## robot functions (from its palette) and the names already used in the code. Banned names are left out.
func _on_completion_requested() -> void:
	var level: Dictionary = Levels.ALL[_level_index]
	var banned: Array = level.get("banned", [])
	var before := _code.get_line(_code.get_caret_line()).substr(0, _code.get_caret_column())
	var options := {}  # display -> [kind, insert]
	var dot := _dot_re.search(before)
	if dot:
		var owner := dot.get_string(1)
		if owner == "self":
			for m in RegEx.create_from_string("self\\.([A-Za-z_][A-Za-z_0-9]*)\\s*=").search_all(_code.text):
				options[m.get_string(1)] = [CodeEdit.KIND_MEMBER, m.get_string(1)]
			for m in RegEx.create_from_string("def\\s+([A-Za-z_][A-Za-z_0-9]*)\\s*\\(\\s*self").search_all(_code.text):
				if not m.get_string(1).begins_with("__"):
					options[m.get_string(1) + "()"] = [CodeEdit.KIND_FUNCTION, m.get_string(1) + "("]
		elif CodeInterpreter.MODULES.has(owner):
			for n in CodeInterpreter.MODULES[owner]:
				options[n] = [CodeEdit.KIND_FUNCTION, n if n == "pi" else n + "("]
		else:
			var members: Array = []
			members.append_array(CodeInterpreter.LIST_METHODS)
			members.append_array(CodeInterpreter.DICT_METHODS)
			members.append_array(CodeInterpreter.STR_METHODS)
			members.append_array(CodeInterpreter.SET_METHODS)
			if "robots" in level["tools"]:
				members.append_array(CodeInterpreter.COMMANDS)
				members.append_array(CodeInterpreter.CONDITIONS)
				members.append_array(CodeInterpreter.SENSORS)
			for n in members:
				if not n in banned:
					options[n + "()"] = [CodeEdit.KIND_FUNCTION, n + ("(" if n in VALUE_METHODS else "()")]
	else:
		for kw in ["if", "elif", "else", "while", "for", "in", "not", "and", "or", "def", "return", "repeat",
				"break", "continue", "pass", "import", "class", "True", "False", "None", "try", "except", "is",
				"lambda", "from", "as", "assert", "del", "global", "raise", "finally"]:
			options[kw] = [CodeEdit.KIND_PLAIN_TEXT, kw]
		for n in CodeInterpreter.BUILTINS:
			options[n + "()"] = [CodeEdit.KIND_FUNCTION, n + "("]
		for group in level["tools"]:
			for entry in PALETTE.get(group, PALETTE_MORE.get(group, [])):
				for m in _ident_re.search_all(String(entry[1])):
					var n := m.get_string()
					if (n in CodeInterpreter.COMMANDS or n in CodeInterpreter.CONDITIONS or n in CodeInterpreter.SENSORS) and not n in banned:
						var takes_value: bool = CodeInterpreter.COMMAND_ARGS.has(n)
						options[n + "()"] = [CodeEdit.KIND_FUNCTION, n + ("(" if takes_value else "()")]
		var typing := ""
		var w := _word_re.search(before)
		if w:
			typing = w.get_string(1)
		var code_words := {}
		for m in _ident_re.search_all(_code.text):
			code_words[m.get_string()] = true
		for n in code_words:
			if n != typing and n.length() >= 2 and not options.has(n) and not options.has(n + "()") and not n in CodeInterpreter.KEYWORDS:
				options[n] = [CodeEdit.KIND_VARIABLE, n]
	for display in options:
		_code.add_code_completion_option(options[display][0], display, options[display][1])
	_code.update_code_completion_options(false)


func _set_marked_line(line: int) -> void:
	if _marked_line >= 0 and _marked_line < _code.get_line_count() and _marked_line != _error_line:
		_code.set_line_background_color(_marked_line, Color(0, 0, 0, 0))
	_marked_line = line
	if line >= 0 and line < _code.get_line_count():
		_code.set_line_background_color(line, COLOR_RUN_LINE)


func _clear_marks() -> void:
	for i in _code.get_line_count():
		_code.set_line_background_color(i, Color(0, 0, 0, 0))
	_marked_line = -1
	_error_line = -1


func _show_error(err: Dictionary) -> void:
	var line := int(err.get("line", 0))
	_set_marked_line(-1)
	if line >= 0 and line < _code.get_line_count():
		_error_line = line
		_code.set_line_background_color(line, COLOR_ERROR_LINE)
		_code.set_caret_line(line)
	_log("%d번째 줄: %s" % [line + 1, _escape(String(err.get("message", "")))], "#ff7a6b")
	_sfx.play("fail")
	# A wrong report() stops the run too; the villager should say what was wrong, not just the line.
	if _world.reported != null and _world.failure().get("kind") == "report":
		_npc_fail("report")
	else:
		_npc_fail("error", {"line": line + 1})


# --- UI events ------------------------------------------------------------

## Each press gives the next hint: the villager's nudges first, then the level's own hint.
func _on_hint_pressed() -> void:
	_end_intro()
	var hints: Array = Dialogue.for_level(_level_index).get("hints", []).duplicate()
	hints.append(Levels.ALL[_level_index]["hint"])
	var i := mini(_hint_stage, hints.size() - 1)
	_hint_stage = i + 1
	_log("힌트 %d/%d: %s" % [i + 1, hints.size(), SpeechBubble.format(hints[i], "#9fd4ff")], "#ffd36b")
	_npc_say([hints[i]])


func _on_speed_changed(value: float) -> void:
	_speed = value
	%SpeedValue.text = "x%s" % str(value)


func _on_retry_pressed() -> void:
	_result.hide()
	_reset_board()


func _on_continue_pressed() -> void:
	_result.hide()
	if Levels.next_of(_level_index) >= 0:
		_load_level(Levels.next_of(_level_index))
	else:
		_reset_board()


func _show_result(stars: int, lines: int, par: int, steps: int = 0, ref: int = -1) -> void:
	var last := Levels.next_of(_level_index) < 0
	%ResultTitle.text = "모든 레벨 완료!" if last else "레벨 클리어!"
	%ResultStars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	var body := "코드 %d줄 · 목표 %d줄 이하" % [lines, par]
	if ref >= 0:
		body += "\n명령 %d번 · 목표 %d번 이하" % [steps, ref]
	if lines > par:
		body += "\n줄 수를 줄이면 별이 늘어요. 반복이나 함수를 써 보세요."
	if ref >= 0 and steps > ref:
		body += "\n더 짧은 길로 가거나 쓸데없는 회전을 줄여 보세요."
	%ResultBody.text = body
	%ContinueButton.text = "닫기" if last else "다음 레벨 ▶"
	_result.show()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_villager_click(event as InputEventMouseButton)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if _menu.visible:
		if key.keycode == KEY_ESCAPE:
			_menu.close()
			get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F7:
		_on_fast_pressed()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F5 or (key.keycode == KEY_ENTER and key.ctrl_pressed):
		_on_run_pressed()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F6:
		_on_step_pressed()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		if _result.visible:
			_result.hide()
		elif _bubble.visible:
			_bubble.dismiss()
		elif _running or not _code.has_focus():
			# While typing code, Esc must not wipe the board; it only stops a run.
			_on_reset_pressed()
		get_viewport().set_input_as_handled()


## A click (press and release without dragging) on the villager asks for the next hint.
## The release is not consumed, so the camera's drag state stays correct.
func _villager_click(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		_press_pos = mb.position
		return
	var clicked := mb.position.distance_to(_press_pos) < 6.0
	_press_pos = Vector2(-1000, -1000)
	if clicked and not _running and not _menu.visible and not _result.visible and _over_villager(mb.position):
		_on_hint_pressed()


## Whether a screen position is over the villager (a box from their feet to the top of the head).
func _over_villager(screen_pos: Vector2) -> bool:
	if not _villager.visible or not _view.get_global_rect().has_point(screen_pos):
		return false
	var head := _villager.head_position()
	var feet := _villager.global_position
	if _camera.is_position_behind(head) or _camera.is_position_behind(feet):
		return false
	var origin := _view.get_global_rect().position
	var top := origin + _camera.unproject_position(head)
	var bottom := origin + _camera.unproject_position(feet)
	var h := maxf(bottom.y - top.y, 20.0)
	return Rect2(top.x - h * 0.3, top.y, h * 0.6, h).has_point(screen_pos)


# --- Persistence & misc ---------------------------------------------------

func _save_code() -> void:
	_codes[_level_index] = _code.text
	_progress.set_value("code", str(_level_index), _code.text)
	_save_progress()


func _save_progress() -> void:
	if not _dev_args.is_empty():
		return  # dev automation runs must not touch the player's save
	_progress.save(SAVE_PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _level_loaded:
		_save_code()


func _update_hud() -> void:
	var lines := CodeInterpreter.count_code_lines(_code.text)
	var par := int(Levels.ALL[_level_index]["par"])
	var parts: PackedStringArray = []
	var map_count := Levels.maps(Levels.ALL[_level_index]).size()
	if map_count > 1:
		parts.append("길 %d/%d" % [_map_index + 1, map_count])
	if _world.apple_total > 0:
		var what := "사과" if _world.item_kinds() == ["apple"] else "물건"
		parts.append("%s %d/%d" % [what, _world.collected, _world.apple_total])
	parts.append("코드 %d/%d줄" % [lines, par])
	var ref := _reference_steps(_level_index, _map_index)
	if ref >= 0:
		parts.append("명령 %d/%d번" % [_run_commands, ref])
	_hud.text = "   ·   ".join(parts)


func _log(text: String, color: String = "") -> void:
	if color.is_empty():
		_console.append_text(text + "\n")
	else:
		_console.append_text("[color=%s]%s[/color]\n" % [color, text])


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# --- Dev automation (command line, for screenshots and smoke tests) -------
# Usage: godot --path . -- --level=3 --solve --shot=user://shot.png
#   --level=N   open level N (1-based)
#   --map=K     show map K of the level (0 = main, 1+ = hidden variant)
#   --code=S    load code S (use \n for new lines) instead of the reference solution
#   --solve     load the reference solution (or --code) and run it at high speed
#   --step=N    instead of --solve: run in step mode and press "한 단계" N times
#   --hint=N    press the hint button N times
#   --fast      with --solve: run without animations
#   --answer=A  with --solve: type A when input() asks the player (without it, stop at the input box)
#   --menu      open the chapter screen   --locks  keep level locks (normally all open in dev runs)
#   --complete=W  type W in an empty editor and open the completion list
#   --click-villager  click the villager (asks for a hint)
#   --wait=S    wait S seconds before the screenshot (lets speech bubbles finish typing)
#   --shot=P    save a screenshot to P after the run (or after load) and quit
# Any of these flags turns off saving, so the player's progress file is never touched.

func _run_dev_automation() -> void:
	var args := _dev_args
	if args.is_empty():
		return
	if args.has("level"):
		var o := Levels.order()
		_load_level(o[clampi(int(args["level"]) - 1, 0, o.size() - 1)])  # --level is the number players see
	if args.has("map"):
		_show_map(clampi(int(args["map"]), 0, Levels.maps(Levels.ALL[_level_index]).size() - 1))
	if args.has("code"):
		_code.text = String(args["code"]).replace("\\n", "\n")
	elif args.has("solve") or args.has("step"):
		_code.text = Levels.ALL[_level_index]["solution"]
	await get_tree().create_timer(0.6).timeout
	if args.has("step"):
		_start_run(true)
		for i in int(args["step"]) - 1:
			await get_tree().create_timer(0.5).timeout
			_on_step_pressed()
		await get_tree().create_timer(0.8).timeout
	elif args.has("solve"):
		%SpeedSlider.value = 10.0
		_start_run(false, args.has("fast"))
		while _running:
			await get_tree().process_frame
			if _input_box.visible:
				if not args.has("answer"):
					break  # leave the input box open for the screenshot
				await get_tree().create_timer(0.8).timeout
				_input_box.text_submitted.emit(String(args["answer"]))
		await get_tree().create_timer(1.5).timeout
		print("DEV solved=%s apples=%d/%d map=%d" % [_world.is_solved(), _world.collected, _world.apple_total, _map_index])
	for i in int(args.get("hint", "0")):
		_on_hint_pressed()
	if args.has("click-villager"):
		await get_tree().create_timer(0.3).timeout
		var head := _view.get_global_rect().position + _camera.unproject_position(_villager.head_position())
		var feet := _view.get_global_rect().position + _camera.unproject_position(_villager.global_position)
		var spot := (head + feet) * 0.5
		print("DEV over villager: ", _over_villager(spot))
		for pressed in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = pressed
			mb.position = spot
			_villager_click(mb)
	if args.has("complete"):
		_code.text = String(args["complete"]).replace("\\n", "\n")
		_code.set_caret_line(_code.get_line_count() - 1)
		_code.set_caret_column(_code.get_line(_code.get_line_count() - 1).length())
		_code.grab_focus()
		_code.request_code_completion()
	if args.has("menu"):
		_open_menu()
	if args.has("wait"):
		await get_tree().create_timer(float(args["wait"])).timeout
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(args["shot"]))
		print("DEV screenshot saved: ", ProjectSettings.globalize_path(String(args["shot"])))
		get_tree().quit()
