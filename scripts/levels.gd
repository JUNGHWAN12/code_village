class_name Levels
extends RefCounted
## Level data. Map legend:
##   #  blocked (bushes, rocks, barrels)
##   .  path
##   S  start of robot 0 (direction from "facing": N, E, S, W)
##   R  start of another robot (robots() order is S, then R in reading order)
##   A  apple on the path
##   G  goal (one per robot; a level is solved when every G has a robot and no apple is left)
## "par" is the target number of code lines for 3 stars.
## "solution" is used by tests/run_tests.gd and is never shown to the player.
## "tools" picks which palette buttons are shown.
## "banned" (optional) lists robot functions this level does not allow, so the puzzle
## needs counting or math instead (e.g. no at_goal() means the robot must count its steps).
## "variants" (optional) are hidden extra maps with the same "facing". After the visible run
## succeeds, the code must also solve every variant, so hard-coded move lists do not pass.
## "seeds" (optional) are extra random seeds every map is also checked with (levels using random).
## "required" (optional) features the code must use: "random", "class", "inherit".

const ALL: Array[Dictionary] = [
	{
		"title": "첫 걸음",
		"goal": "로봇을 [color=#ffd36b]빛나는 목표[/color]까지 보내세요.",
		"hint": "move() 는 앞으로 한 칸 움직여요. 몇 칸 가야 할까요?",
		"map": [
			"#######",
			"#S...G#",
			"#######",
		],
		"facing": "E",
		"par": 4,
		"tools": ["move"],
		"starter": "# 한 줄에 명령 하나씩 적어요.\nmove()\n",
		"solution": "move()\nmove()\nmove()\nmove()\n",
	},
	{
		"title": "사과 줍기",
		"goal": "가는 길에 [color=#ff7a6b]사과[/color]를 주운 뒤 목표에 도착하세요.",
		"hint": "사과 위에 섰을 때 pick() 을 쓰면 사과를 주워요.",
		"map": [
			"#######",
			"#S.A.G#",
			"#######",
		],
		"facing": "E",
		"par": 5,
		"tools": ["move", "pick"],
		"starter": "",
		"solution": "move()\nmove()\npick()\nmove()\nmove()\n",
	},
	{
		"title": "모퉁이 돌기",
		"goal": "길을 따라 방향을 바꾸며 목표까지 가세요.",
		"hint": "turn_right() 와 turn_left() 는 제자리에서 방향만 바꿔요.",
		"map": [
			"#######",
			"#S..###",
			"###.###",
			"###...#",
			"#####G#",
			"#######",
		],
		"facing": "E",
		"par": 10,
		"tools": ["move", "turn"],
		"starter": "",
		"solution": "move()\nmove()\nturn_right()\nmove()\nmove()\nturn_left()\nmove()\nmove()\nturn_right()\nmove()\n",
	},
	{
		"title": "반복의 힘",
		"goal": "사과 7개를 모두 줍고 목표에 도착하세요. [color=#9fd4ff]4줄[/color] 안에 해낼 수 있을까요?",
		"hint": "repeat 7: 아래에 들여쓴 줄들은 7번 반복돼요.",
		"map": [
			"###########",
			"#SAAAAAAAG#",
			"###########",
		],
		"facing": "E",
		"par": 4,
		"tools": ["move", "pick", "repeat"],
		"starter": "repeat 7:\n    move()\n",
		"solution": "repeat 7:\n    move()\n    pick()\nmove()\n",
	},
	{
		"title": "계단 내려가기",
		"goal": "계단 모양 길의 사과 4개를 줍고 목표로 가세요.",
		"hint": "한 계단을 내려가는 동작을 찾아서 repeat 로 묶어 보세요.",
		"map": [
			"########",
			"#S.#####",
			"##A.####",
			"###A.###",
			"####A.##",
			"#####AG#",
			"########",
		],
		"facing": "E",
		"par": 7,
		"tools": ["move", "turn", "pick", "repeat"],
		"starter": "",
		"solution": "repeat 4:\n    move()\n    turn_right()\n    move()\n    pick()\n    turn_left()\nmove()\n",
	},
	{
		"title": "사과가 있을 때만",
		"goal": "사과가 있는 칸에서만 주워야 해요. 빈 칸에서 pick() 하면 실패! [color=#9fd4ff]사과 위치가 다른 길[/color]에서도 통해야 해요.",
		"hint": "if on_apple(): 아래 명령은 사과 위에 있을 때만 실행돼요.",
		"map": [
			"###########",
			"#S.A.AA.AG#",
			"###########",
		],
		"variants": [
			["###########", "#SAA..A..G#", "###########"],
			["###########", "#S..AA.AAG#", "###########"],
		],
		"facing": "E",
		"par": 4,
		"tools": ["move", "pick", "repeat", "if", "cond"],
		"starter": "",
		"solution": "repeat 8:\n    move()\n    if on_apple():\n        pick()\n",
	},
	{
		"title": "소용돌이 길",
		"goal": "길이 끝날 때마다 오른쪽으로 돌면 목표에 닿아요. [color=#9fd4ff]모양이 다른 소용돌이[/color]에서도 통해야 해요. 5줄로 도전!",
		"hint": "while not at_goal(): 은 목표에 닿을 때까지 반복해요. 앞이 막혔는지는 is_blocked() 로 알 수 있어요.",
		"map": [
			"#########",
			"#S......#",
			"#######.#",
			"#.....#.#",
			"#.###.#.#",
			"#.#G..#.#",
			"#.#####.#",
			"#.......#",
			"#########",
		],
		"variants": [
			["#######", "#S....#", "#####.#", "#...#.#", "#.#G#.#", "#.....#", "#######"],
			["########", "#S.....#", "######.#", "#....#.#", "#.##.#.#", "#.#G.#.#", "#.####.#", "#......#", "########"],
		],
		"facing": "E",
		"par": 5,
		"tools": ["move", "turn", "while", "if", "else", "cond"],
		"starter": "while not at_goal():\n    move()\n",
		"solution": "while not at_goal():\n    if is_blocked():\n        turn_right()\n    else:\n        move()\n",
	},
	{
		"title": "마을 한 바퀴",
		"goal": "모든 것을 합쳐 보세요! 사과를 모두 줍고 목표로. [color=#9fd4ff]다른 마을 길[/color]에서도 통해야 해요.",
		"hint": "while 안에 if 를 두 개 써 보세요. 하나는 사과, 하나는 벽(왼쪽으로 돌기).",
		"map": [
			"########",
			"#G.A..A#",
			"######.#",
			"######A#",
			"######.#",
			"#S.AA..#",
			"########",
		],
		"variants": [
			["#######", "#A..A.#", "#.###.#", "#G#S.A#", "#######"],
			["#########", "#...G.A.#", "#######.#", "#######A#", "#######.#", "#SA.A...#", "#########"],
		],
		"facing": "E",
		"par": 7,
		"tools": ["move", "turn", "pick", "repeat", "while", "if", "else", "cond"],
		"starter": "",
		"solution": "while not at_goal():\n    if on_apple():\n        pick()\n    if is_blocked():\n        turn_left()\n    else:\n        move()\n",
	},
	# --- Chapter 4: variables -------------------------------------------------
	{
		"title": "걸음 세기",
		"goal": "끝까지 가서 [color=#ff7a6b]사과[/color]를 줍고, 출발한 칸 바로 뒤의 [color=#ffd36b]목표[/color]로 돌아오세요. 안개 때문에 목표가 보이지 않아요. 걸음을 [color=#e6b8e0]변수[/color]로 세어 보세요.",
		"hint": "n = 0 으로 시작해서 move() 할 때마다 n += 1. 돌아올 때는 repeat n + 1: 로 정확히 그만큼 걸어요.",
		"map": [
			"###########",
			"#..GS....A#",
			"###########",
		],
		"variants": [
			["##########", "#...GS..A#", "##########"],
			["#############", "#.GS.......A#", "#############"],
		],
		"facing": "E",
		"banned": ["at_goal"],
		"par": 9,
		"tools": ["move", "turn", "pick", "repeat", "while", "cond", "var", "print"],
		"starter": "n = 0\nwhile not is_blocked():\n    move()\n",
		"solution": "n = 0\nwhile not is_blocked():\n    move()\n    n += 1\npick()\nturn_left()\nturn_left()\nrepeat n + 1:\n    move()\n",
	},
	{
		"title": "한가운데",
		"goal": "벽까지 간 뒤 되돌아와서 길의 [color=#ffd36b]한가운데[/color]에 멈추세요. 길이는 매번 달라요.",
		"hint": "걸음 수를 n 에 세었다면, 돌아올 때는 n // 2 칸이에요. // 는 나눗셈의 몫(정수)이에요.",
		"map": [
			"##########",
			"#S...G...#",
			"##########",
		],
		"variants": [
			["#############", "#S....G.....#", "#############"],
			["########", "#S..G..#", "########"],
		],
		"facing": "E",
		"banned": ["at_goal"],
		"par": 8,
		"tools": ["move", "turn", "repeat", "while", "cond", "var", "ops", "print"],
		"starter": "",
		"solution": "n = 0\nwhile not is_blocked():\n    move()\n    n += 1\nturn_left()\nturn_left()\nrepeat n // 2:\n    move()\n",
	},
	# --- Chapter 5: functions -------------------------------------------------
	{
		"title": "나만의 명령",
		"goal": "[color=#9fd4ff]def[/color] 로 'n칸 걷기' 명령을 만들어 길을 따라가세요. 12줄 안에 해낼 수 있을까요?",
		"hint": "def walk(n): 아래에 repeat n: 과 move() 를 들여써서 넣고, walk(3) 처럼 불러요.",
		"map": [
			"############",
			"#S...#######",
			"####.#######",
			"####.....###",
			"########.###",
			"########.###",
			"########..G#",
			"############",
		],
		"facing": "E",
		"banned": ["is_blocked"],
		"par": 12,
		"tools": ["move", "turn", "repeat", "def"],
		"starter": "def walk(n):\n    repeat n:\n        move()\n\nwalk(3)\n",
		"solution": "def walk(n):\n    repeat n:\n        move()\nwalk(3)\nturn_right()\nwalk(2)\nturn_left()\nwalk(4)\nturn_right()\nwalk(3)\nturn_left()\nwalk(2)\n",
	},
	{
		"title": "점점 커지는 소용돌이",
		"goal": "1칸, 1칸, 2칸, 2칸, 3칸, 3칸… 오른쪽으로 돌 때마다 길이 길어져요. 함수와 변수를 함께 써 보세요.",
		"hint": "walk(n) 을 두 번 하고 n 을 1 늘리는 것을 목표에 닿을 때까지 반복해요.",
		"map": [
			"#######",
			"#G#####",
			"#.....#",
			"#..S..#",
			"#.....#",
			"#.....#",
			"#######",
		],
		"variants": [
			["######", "#....#", "#.S..#", "#....#", "####G#", "######"],
			["########", "#......#", "#......#", "#..S...#", "#......#", "#......#", "######G#", "########"],
		],
		"facing": "E",
		"banned": ["is_blocked"],
		"par": 10,
		"tools": ["move", "turn", "repeat", "while", "cond", "var", "def"],
		"starter": "",
		"solution": "def walk(n):\n    repeat n:\n        move()\nn = 1\nwhile not at_goal():\n    walk(n)\n    turn_right()\n    walk(n)\n    turn_right()\n    n += 1\n",
	},
	# --- Chapter 6: math --------------------------------------------------------
	{
		"title": "좌표 계산",
		"goal": "목표의 가로 위치는 goal_x(), 로봇의 위치는 get_x() 로 알 수 있어요. 차이를 계산해서 정확히 그만큼 가세요. 목표가 왼쪽일 수도 있어요!",
		"hint": "dx = goal_x() - get_x(). dx 가 음수면 뒤로 돌아요. 걸을 칸 수는 abs(dx) 예요.",
		"map": [
			"#############",
			"#.G.....S...#",
			"#############",
		],
		"variants": [
			["#############", "#....S...G..#", "#############"],
			["#############", "#S.........G#", "#############"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked"],
		"par": 6,
		"tools": ["move", "turn", "repeat", "if", "var", "pos", "abs", "print"],
		"starter": "dx = goal_x() - get_x()\nprint(dx)\n",
		"solution": "dx = goal_x() - get_x()\nif dx < 0:\n    turn_left()\n    turn_left()\nrepeat abs(dx):\n    move()\n",
	},
	{
		"title": "정사각형 사과밭",
		"goal": "사과밭은 가로와 세로가 같은 정사각형이에요. [color=#9fd4ff]import math[/color] 의 math.sqrt() 로 한 변의 길이를 구해서, 줄마다 지그재그로 모든 사과를 줍고 목표로 가세요.",
		"hint": "사과가 16개면 한 변은 math.sqrt(16) → 4.0, int() 로 4. 줄 번호 row 가 짝수면 오른쪽으로, 홀수면 왼쪽으로 돌아 다음 줄로 가요 (row % 2).",
		"map": [
			"#######",
			"#SAAAA#",
			"##AAAA#",
			"##AAAA#",
			"##AAAA#",
			"##G####",
			"#######",
		],
		"variants": [
			["######", "#SAAA#", "##AAA#", "##AAA#", "####G#", "######"],
			["########", "#SAAAAA#", "##AAAAA#", "##AAAAA#", "##AAAAA#", "##AAAAA#", "######G#", "########"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked"],
		"par": 16,
		"tools": ["move", "turn", "pick", "repeat", "for", "if", "else", "var", "ops", "apples", "math", "print"],
		"starter": "import math\n\nprint(apples_left())\n",
		"solution": "import math\nmove()\nk = int(math.sqrt(apples_left()))\nfor row in range(k):\n    repeat k - 1:\n        pick()\n        move()\n    pick()\n    if row % 2 == 0:\n        turn_right()\n        move()\n        turn_right()\n    else:\n        turn_left()\n        move()\n        turn_left()\n",
	},
	# --- Chapter 7: lists -------------------------------------------------------
	{
		"title": "쪽지 따라가기",
		"goal": "route() 는 목표까지 가는 방법을 [color=#e6b8e0]목록[/color]으로 알려 줘요. 예: [\"F\", \"F\", \"R\", \"F\"] (F 앞으로, L 왼쪽, R 오른쪽). 목록을 하나씩 꺼내 그대로 움직이세요.",
		"hint": "for step in route(): 로 하나씩 꺼내고, if step == \"F\": / elif step == \"L\": / else: 로 나눠요. 먼저 print(route()) 로 쪽지를 읽어 봐도 좋아요.",
		"map": [
			"##########",
			"#S..######",
			"###.######",
			"###....###",
			"######.###",
			"#G.....###",
			"##########",
		],
		"variants": [
			["#########", "####...G#", "####.####", "#S...####", "#########"],
			["########", "#S.#####", "##.#..G#", "##.#.###", "##...###", "########"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked"],
		"par": 7,
		"tools": ["move", "turn", "for_in", "if", "elif", "else", "route", "print"],
		"starter": "print(route())\n",
		"solution": "for step in route():\n    if step == \"F\":\n        move()\n    elif step == \"L\":\n        turn_left()\n    else:\n        turn_right()\n",
	},
	{
		"title": "숫자 쪽지",
		"goal": "segments() 는 곧게 가는 칸 수를 목록으로 알려 줘요. 예: [3, 2, 1]. 계단길이라 오른쪽, 왼쪽으로 번갈아 돌아요. 목록의 [color=#e6b8e0]번호[/color]로 값을 꺼내 보세요.",
		"hint": "s = segments() 로 받고, for i in range(len(s)): 안에서 s[i] 칸 걸어요. i 가 짝수면 turn_right(), 홀수면 turn_left().",
		"map": [
			"#########",
			"#S...####",
			"####.####",
			"####..###",
			"#####.###",
			"#####.###",
			"#####..G#",
			"#########",
		],
		"variants": [
			["#########", "#S..#####", "###.....#", "#######.#", "#######G#", "#########"],
			["#########", "#S.######", "##.######", "##.######", "##...####", "####....#", "#######G#", "#########"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked", "route"],
		"par": 8,
		"tools": ["move", "turn", "repeat", "for", "if", "else", "var", "ops", "list", "segments", "print"],
		"starter": "s = segments()\nprint(s, len(s), s[0])\n",
		"solution": "s = segments()\nfor i in range(len(s)):\n    repeat s[i]:\n        move()\n    if i % 2 == 0:\n        turn_right()\n    else:\n        turn_left()\n",
	},
	# --- Chapter 8: random ------------------------------------------------------
	{
		"title": "넓은 광장",
		"goal": "벽에 닿을 때만 돌면 광장 가장자리만 빙빙 돌아요. [color=#9fd4ff]import random[/color] 으로 가끔 무작위로 방향을 바꿔서 광장 안쪽의 목표를 찾아보세요. 목표 위치는 매번 달라요.",
		"hint": "random.randint(1, 3) == 1 이면 세 번에 한 번꼴로 참이에요. 그때나 앞이 막혔을 때 random.randint(0, 1) 로 왼쪽/오른쪽을 골라 돌아요. 속도를 올려서 보세요!",
		"map": [
			"#########",
			"#S......#",
			"#.......#",
			"#...G...#",
			"#.......#",
			"#########",
		],
		"variants": [
			["#########", "#S......#", "#.....G.#", "#.......#", "#.......#", "#########"],
			["#########", "#S......#", "#.......#", "#.......#", "#.G.....#", "#########"],
		],
		"seeds": [2, 3, 4],
		"facing": "E",
		"banned": ["route", "segments", "goal_x", "goal_y"],
		"required": ["random"],
		"par": 9,
		"tools": ["move", "turn", "while", "if", "else", "cond", "random"],
		"starter": "import random\n\nwhile not at_goal():\n    if is_blocked():\n        turn_right()\n    else:\n        move()\n",
		"solution": "import random\nwhile not at_goal():\n    if is_blocked() or random.randint(1, 3) == 1:\n        if random.randint(0, 1) == 0:\n            turn_left()\n        else:\n            turn_right()\n    else:\n        move()\n",
	},
	{
		"title": "광장의 사과",
		"goal": "광장 어딘가의 사과를 모두 줍고 목표로 가세요. 사과가 남았거나 목표가 아니면 계속 돌아다녀요. 방향은 random.choice() 로 목록에서 골라 보세요.",
		"hint": "while apples_left() > 0 or not at_goal(): 로 반복하고, random.choice([\"L\", \"R\"]) 로 돌 방향을 골라요.",
		"map": [
			"########",
			"#S.....#",
			"#..A...#",
			"#....A.#",
			"#.....G#",
			"########",
		],
		"variants": [
			["########", "#S...A.#", "#......#", "#A.....#", "#..G...#", "########"],
		],
		"seeds": [2, 3],
		"facing": "E",
		"banned": ["route", "segments", "goal_x", "goal_y"],
		"required": ["random"],
		"par": 12,
		"tools": ["move", "turn", "pick", "while", "if", "else", "cond", "var", "apples", "random"],
		"starter": "import random\n",
		"solution": "import random\nwhile apples_left() > 0 or not at_goal():\n    if on_apple():\n        pick()\n    if is_blocked() or random.randint(1, 3) == 1:\n        turn = random.choice([\"L\", \"R\"])\n        if turn == \"L\":\n            turn_left()\n        else:\n            turn_right()\n    else:\n        move()\n",
	},
	# --- Chapter 9: objects and classes ------------------------------------------
	{
		"title": "로봇 여러 대",
		"goal": "로봇이 여러 대예요! robots() 는 로봇 [color=#e6b8e0]객체[/color]의 목록이에요. 객체마다 r.move(), r.pick(), r.at_goal() 처럼 명령해요. 모든 로봇이 사과를 줍고 목표로 가게 하세요. 로봇 수는 매번 달라요.",
		"hint": "for r in robots(): 안에서 while not r.at_goal(): 로 한 로봇씩 끝까지 보내요. 그냥 move() 는 주황 로봇만 움직여요.",
		"map": [
			"#########",
			"#S.A..AG#",
			"#########",
			"#R..A..G#",
			"#########",
		],
		"variants": [
			["#########", "#SA....G#", "#########", "#R...A.G#", "#########", "#R.A.A.G#", "#########"],
			["#######", "#S.A.G#", "#######", "#R.AAG#", "#######"],
		],
		"facing": "E",
		"par": 5,
		"tools": ["robots", "for_robots", "while", "if", "not"],
		"starter": "for r in robots():\n    print(r.name)\n",
		"solution": "for r in robots():\n    while not r.at_goal():\n        r.move()\n        if r.on_apple():\n            r.pick()\n",
	},
	{
		"title": "저마다 기억하기",
		"goal": "로봇마다 길 끝의 사과를 줍고 출발한 칸 바로 뒤의 목표로 돌아와요. 목표는 안개에 가려져 있어요. [color=#9fd4ff]class[/color] 로 '로봇 + 걸음 수' 를 묶은 객체를 만들어, 모두 먼저 사과를 주운 뒤 돌아오게 해 보세요.",
		"hint": "class Walker: 의 __init__(self, robot) 에서 self.robot = robot, self.steps = 0. go(self) 는 벽까지 가며 self.steps 를 세고, back(self) 는 돌아서 self.steps + 1 칸 걸어요.",
		"map": [
			"###########",
			"#GS....A###",
			"###########",
			"#GR..A#####",
			"###########",
			"#GR......A#",
			"###########",
		],
		"variants": [
			["#########", "#GS..A###", "#########", "#GR....A#", "#########"],
			["###########", "#GS.A######", "###########", "#GR......A#", "###########", "#GR...A####", "###########", "#GR..A#####", "###########"],
		],
		"facing": "E",
		"banned": ["at_goal"],
		"required": ["class"],
		"par": 22,
		"tools": ["robots", "for_robots", "repeat", "while", "not", "var", "list", "class"],
		"starter": "class Walker:\n    def __init__(self, robot):\n        self.robot = robot\n        self.steps = 0\n\n",
		"solution": "class Walker:\n    def __init__(self, robot):\n        self.robot = robot\n        self.steps = 0\n    def go(self):\n        while not self.robot.is_blocked():\n            self.robot.move()\n            self.steps += 1\n        self.robot.pick()\n    def back(self):\n        self.robot.turn_left()\n        self.robot.turn_left()\n        repeat self.steps + 1:\n            self.robot.move()\nwalkers = []\nfor r in robots():\n    walkers.append(Walker(r))\nfor w in walkers:\n    w.go()\nfor w in walkers:\n    w.back()\n",
	},
	{
		"title": "물려받기",
		"goal": "주황 로봇은 걷기만 하고, 파랑 로봇은 걸으면서 사과도 주워요. 걷는 [color=#9fd4ff]Walker[/color] class 를 만들고, 그것을 [color=#9fd4ff]물려받아(상속)[/color] step() 만 바꾼 Picker class 를 만들어 보세요.",
		"hint": "class Picker(Walker): 안에서 def step(self): 를 다시 만들고, super().step() 으로 원래 걷기를 부른 뒤 사과를 주워요.",
		"map": [
			"#########",
			"#S.....G#",
			"#########",
			"#R.A.AAG#",
			"#########",
		],
		"variants": [
			["###########", "#S.......G#", "###########", "#RA..A.A.G#", "###########"],
		],
		"facing": "E",
		"required": ["class", "inherit"],
		"par": 15,
		"tools": ["robots", "while", "if", "not", "class"],
		"starter": "class Walker:\n    def __init__(self, robot):\n        self.robot = robot\n    def step(self):\n        self.robot.move()\n    def run(self):\n        while not self.robot.at_goal():\n            self.step()\n\n",
		"solution": "class Walker:\n    def __init__(self, robot):\n        self.robot = robot\n    def step(self):\n        self.robot.move()\n    def run(self):\n        while not self.robot.at_goal():\n            self.step()\nclass Picker(Walker):\n    def step(self):\n        super().step()\n        if self.robot.on_apple():\n            self.robot.pick()\nWalker(robots()[0]).run()\nPicker(robots()[1]).run()\n",
	},
	# --- Chapter 10: tuples -----------------------------------------------------
	{
		"title": "좌표 쪽지",
		"goal": "get_pos() 와 goal_pos() 는 위치를 [color=#e6b8e0]튜플[/color] (x, y) 로 알려 줘요. [color=#9fd4ff]x, y = get_pos()[/color] 처럼 두 변수에 나눠 담고, face(\"E\") 로 방향을 정해 목표까지 가세요.",
		"hint": "가로로 abs(gx - x) 칸, 세로로 abs(gy - y) 칸 가요. gx 가 x 보다 크면 face(\"E\"), 아니면 face(\"W\"). 세로는 face(\"S\") / face(\"N\").",
		"map": [
			"#########",
			"#.......#",
			"#.S.....#",
			"#.......#",
			"#.....G.#",
			"#.......#",
			"#########",
		],
		"variants": [
			["#########", "#G......#", "#.......#", "#.......#", "#.....S.#", "#.......#", "#########"],
			["#########", "#......G#", "#.......#", "#.......#", "#.......#", "#S......#", "#########"],
			["#########", "#.......#", "#.......#", "#G.....S#", "#.......#", "#.......#", "#########"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked", "goal_x", "goal_y", "get_x", "get_y", "route", "segments"],
		"par": 14,
		"tools": ["move", "repeat", "if", "else", "var", "tuple_pos", "abs", "print"],
		"starter": "x, y = get_pos()\ngx, gy = goal_pos()\nprint(x, y, gx, gy)\n",
		"solution": "x, y = get_pos()\ngx, gy = goal_pos()\nif gx > x:\n    face(\"E\")\nelse:\n    face(\"W\")\nrepeat abs(gx - x):\n    move()\nif gy > y:\n    face(\"S\")\nelse:\n    face(\"N\")\nrepeat abs(gy - y):\n    move()\n",
	},
	{
		"title": "보물 지도",
		"goal": "treasure_map() 은 보물(사과) 위치 튜플의 목록이에요. 예: [(3, 1), (6, 2)]. 위치로 가는 [color=#9fd4ff]go(tx, ty)[/color] 함수를 만들어 보물을 모두 줍고 목표로 가세요.",
		"hint": "for tx, ty in treasure_map(): 처럼 튜플을 바로 나눠 꺼낼 수 있어요. go 안에서는 x, y = get_pos() 로 지금 위치를 알아내요. 목표는 gx, gy = goal_pos() 후 go(gx, gy).",
		"map": [
			"#########",
			"#..A....#",
			"#.S...A.#",
			"#.......#",
			"#A....G.#",
			"#....A..#",
			"#########",
		],
		"variants": [
			["#########", "#A.....A#", "#.......#", "#...S...#", "#.......#", "#A.G...A#", "#########"],
			["#########", "#S.A....#", "#.......#", "#....A..#", "#..A....#", "#......G#", "#########"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked", "on_apple", "item_here", "goal_x", "goal_y", "get_x", "get_y", "route", "segments"],
		"par": 19,
		"tools": ["move", "pick", "repeat", "if", "else", "var", "tuple_pos", "treasure", "abs", "def"],
		"starter": "print(treasure_map())\n",
		"solution": "def go(tx, ty):\n    x, y = get_pos()\n    if tx > x:\n        face(\"E\")\n    else:\n        face(\"W\")\n    repeat abs(tx - x):\n        move()\n    if ty > y:\n        face(\"S\")\n    else:\n        face(\"N\")\n    repeat abs(ty - y):\n        move()\nfor tx, ty in treasure_map():\n    go(tx, ty)\n    pick()\ngx, gy = goal_pos()\ngo(gx, gy)\n",
	},
	# --- Chapter 11: dictionaries --------------------------------------------------
	{
		"title": "바구니 세기",
		"goal": "길에 사과, 당근, 옥수수가 섞여 있어요. 모두 주우면서 종류별로 몇 개인지 [color=#e6b8e0]딕셔너리[/color]에 세고, 목표에서 report(count) 로 보고하세요. 예: {\"apple\": 2, \"corn\": 1}",
		"hint": "item = item_here() 는 \"apple\" 같은 이름이나 None 이에요. count[item] = count.get(item, 0) + 1 로 세요.",
		"map": [
			"############",
			"#SACK.AC.KG#",
			"############",
		],
		"variants": [
			["############", "#SAAK.C.AAG#", "############"],
			["##########", "#S.KK.CKG#", "##########"],
		],
		"facing": "E",
		"report": "count",
		"par": 8,
		"tools": ["move", "pick", "while", "if", "cond", "not", "var", "items", "dict", "report", "print"],
		"starter": "count = {}\n",
		"solution": "count = {}\nwhile not at_goal():\n    move()\n    item = item_here()\n    if item is not None:\n        pick()\n        count[item] = count.get(item, 0) + 1\nreport(count)\n",
	},
	{
		"title": "주문 배달",
		"goal": "손님의 주문서 order() 는 딕셔너리예요. 예: {\"apple\": 2, \"carrot\": 1}. 손님 집 앞(목표)까지 간 뒤, 주문서대로 drop(\"apple\") 로 하나씩 배달하세요. 주문은 매번 달라요.",
		"hint": "for item, n in order().items(): 로 이름과 개수를 함께 꺼내고, repeat n: 안에서 drop(item) 해요.",
		"map": [
			"##########",
			"#S......##",
			"#######.##",
			"#G......##",
			"##########",
		],
		"variants": [
			["##########", "#S......##", "#######.##", "#G......##", "##########"],
			["##########", "#S......##", "#######.##", "#G......##", "##########"],
		],
		"orders": [
			{"apple": 2, "carrot": 1},
			{"corn": 3},
			{"carrot": 2, "corn": 1, "apple": 1},
		],
		"facing": "E",
		"par": 8,
		"tools": ["move", "turn", "while", "if", "else", "cond", "not", "repeat", "for_in", "order", "dict", "print"],
		"starter": "print(order())\n",
		"solution": "while not at_goal():\n    if is_blocked():\n        turn_right()\n    else:\n        move()\nfor item, n in order().items():\n    repeat n:\n        drop(item)\n",
	},
	{
		"title": "명령표",
		"goal": "쪽지 따라가기를 다시 해 봐요. 이번엔 if 대신 [color=#e6b8e0]딕셔너리에 명령을 담아[/color] 꺼내 쓰세요. 예: act[\"F\"] 가 move 라면 act[\"F\"]() 는 move() 예요. 3줄 도전!",
		"hint": "act = {\"F\": move, \"L\": turn_left, \"R\": turn_right} 처럼 괄호 없이 명령 이름을 값으로 넣어요. 그다음 for step in route(): 안에서 act[step]().",
		"map": [
			"##########",
			"#S..######",
			"###.######",
			"###....###",
			"######.###",
			"#G.....###",
			"##########",
		],
		"variants": [
			["#########", "####...G#", "####.####", "#S...####", "#########"],
			["########", "#S.#####", "##.#..G#", "##.#.###", "##...###", "########"],
		],
		"facing": "E",
		"banned": ["at_goal", "is_blocked"],
		"required": ["dict"],
		"par": 3,
		"tools": ["for_in", "route", "dict", "move", "turn"],
		"starter": "act = {}\n",
		"solution": "act = {\"F\": move, \"L\": turn_left, \"R\": turn_right}\nfor step in route():\n    act[step]()\n",
	},
	{
		"title": "장보기 계산",
		"goal": "market() 은 가격표 딕셔너리예요. 예: {\"apple\": 3, \"carrot\": 2, \"corn\": 5}. 길의 채소를 모두 담고 [color=#e6b8e0]가격표에서 값을 찾아[/color] 더한 총액을 report(total) 로 알려 주세요.",
		"hint": "prices = market() 로 받아 두고, 채소를 주울 때마다 total += prices[item].",
		"map": [
			"############",
			"#SKA.C.AK.G#",
			"############",
		],
		"variants": [
			["############", "#S.CCA..K.G#", "############"],
			["#########", "#SAAAC.G#", "#########"],
		],
		"prices": {"apple": 3, "carrot": 2, "corn": 5},
		"facing": "E",
		"report": "price",
		"par": 9,
		"tools": ["move", "pick", "while", "if", "cond", "not", "var", "items", "dict", "market", "report", "print"],
		"starter": "prices = market()\nprint(prices)\n",
		"solution": "prices = market()\ntotal = 0\nwhile not at_goal():\n    move()\n    item = item_here()\n    if item is not None:\n        pick()\n        total += prices[item]\nreport(total)\n",
	},
	# --- Chapter 12: strings, sets and exceptions ---------------------------------
	{
		"title": "암호 문",
		"goal": "길을 막은 문은 암호를 말하면 열려요. 표지판 read_sign() 에는 암호가 [color=#e6b8e0]거꾸로, 대문자로[/color] 적혀 있어요. 예: \"ELPPA\" → \"apple\". 문 앞에서 say(암호) 하세요.",
		"hint": "s[::-1] 은 글자를 거꾸로 뒤집고, .lower() 는 소문자로 바꿔요. say(read_sign()[::-1].lower())",
		"map": [
			"###I######",
			"#S...D..G#",
			"##########",
		],
		"variants": [
			["#####I#####", "#S..D....G#", "###########"],
			["##I#######", "#S.....DG#", "##########"],
		],
		"signs": ["ELPPA", "NROC", "TORRAC"],
		"passwords": ["apple", "corn", "carrot"],
		"facing": "E",
		"par": 4,
		"tools": ["move", "while", "if", "cond", "not", "strings", "print"],
		"starter": "print(read_sign())\n",
		"solution": "while not at_goal():\n    if is_blocked():\n        say(read_sign()[::-1].lower())\n    move()\n",
	},
	{
		"title": "배달 인사",
		"goal": "사과를 모두 주워 손님에게 가서, 손님 이름과 사과 수를 넣어 인사하세요. 예: say(\"마르타님, 사과 3개 왔어요!\"). 손님과 사과 수는 매번 달라요. [color=#9fd4ff]f-문자열[/color] f\"{이름}님\" 을 써 보세요.",
		"hint": "n 에 주운 사과 수를 세고, 마지막에 say(f\"{customer()}님, 사과 {n}개 왔어요!\")",
		"map": [
			"##########",
			"#SA.A..AG#",
			"##########",
		],
		"variants": [
			["##########", "#S.A....G#", "##########"],
			["############", "#SAA.A.A.AG#", "############"],
		],
		"customers": ["마르타", "이반", "보리스"],
		"speech": "{customer}님, 사과 {apples}개 왔어요!",
		"facing": "E",
		"par": 7,
		"tools": ["move", "pick", "while", "if", "cond", "not", "var", "fstring", "print"],
		"starter": "print(customer())\n",
		"solution": "n = 0\nwhile not at_goal():\n    move()\n    if on_apple():\n        pick()\n        n += 1\nsay(f\"{customer()}님, 사과 {n}개 왔어요!\")\n",
	},
	{
		"title": "종류마다 하나씩",
		"goal": "시식용으로 [color=#e6b8e0]종류마다 딱 하나씩만[/color] 주워 오세요. 이미 주운 종류는 지나쳐요. 이미 본 것을 기억할 때는 [color=#9fd4ff]집합 set()[/color] 이 좋아요.",
		"hint": "seen = set() 을 만들고, item not in seen 일 때만 pick() 하고 seen.add(item).",
		"map": [
			"###########",
			"#SAACAKKCG#",
			"###########",
		],
		"variants": [
			["###########", "#SKK.KAA.G#", "###########"],
			["#########", "#SCCCCAG#", "#########"],
		],
		"rule": "one_each",
		"facing": "E",
		"par": 7,
		"tools": ["move", "pick", "while", "if", "cond", "not", "var", "items", "set"],
		"starter": "seen = set()\n",
		"solution": "seen = set()\nwhile not at_goal():\n    move()\n    item = item_here()\n    if item is not None and item not in seen:\n        pick()\n        seen.add(item)\n",
	},
	{
		"title": "조심조심 줍기",
		"goal": "안개 때문에 발밑이 안 보여요. 그냥 pick() 하면 빈 칸에서 [color=#ff9f8a]NoItem[/color] 오류가 나요. [color=#9fd4ff]try / except[/color] 로 오류를 잡아서, 사과가 없으면 그냥 지나가세요.",
		"hint": "try: 아래에 pick(), except NoItem: 아래에 pass. 오류가 나도 프로그램이 멈추지 않아요.",
		"map": [
			"###########",
			"#S.A..AA.G#",
			"###########",
		],
		"variants": [
			["###########", "#SA.A.A.AG#", "###########"],
			["#########", "#S..A..G#", "#########"],
		],
		"facing": "E",
		"banned": ["item_here", "on_apple"],
		"required": ["try"],
		"par": 6,
		"tools": ["move", "pick", "while", "cond", "not", "try"],
		"starter": "while not at_goal():\n    move()\n    pick()\n",
		"solution": "while not at_goal():\n    move()\n    try:\n        pick()\n    except NoItem:\n        pass\n",
	},
	{
		"title": "말이 지나가는 길",
		"goal": "말이 길을 가로질러 오가요. 말에 부딪히면 [color=#ff9f8a]Blocked[/color] 오류가 나요. 오류를 잡아서 wait() 로 한 번 기다렸다가 다시 가세요. 앞을 살피는 is_blocked() 는 이번엔 못 써요.",
		"hint": "while not at_goal(): 안에서 try: move() / except Blocked: wait()",
		"map": [
			"######.#####",
			"######H#####",
			"#S........G#",
			"######.#####",
			"######.#####",
			"############",
		],
		"variants": [
			["####.###.###", "####H###.###", "#S........G#", "####.###H###", "####.###.###", "############"],
			["###.####.###", "###.####.###", "#S.H....H.G#", "###.####.###", "###.####.###", "############"],
		],
		"horse_dir": "S",
		"facing": "E",
		"banned": ["is_blocked"],
		"required": ["try"],
		"par": 5,
		"tools": ["move", "while", "cond", "not", "try"],
		"starter": "while not at_goal():\n    move()\n",
		"solution": "while not at_goal():\n    try:\n        move()\n    except Blocked:\n        wait()\n",
	},
	# --- Added later (ALL is append-only; Levels.CHAPTERS places these in their chapters) ---
	{
		"title": "짝수 우편함",
		"goal": "오늘 온 편지의 집 번호 목록이 mailboxes() 예요. 이번엔 [color=#e6b8e0]짝수 번호 집에 온 편지만[/color] 배달해요. 길을 따라가며 집(이름표 칸) 앞에서 house_here() 로 번호를 보고, 배달할 집이면 deliver() 하세요. 배달할 번호는 [color=#9fd4ff]리스트 컴프리헨션[/color] [n for n in 목록 if 조건] 으로 먼저 골라 두세요.",
		"hint": "targets = [n for n in mailboxes() if n % 2 == 0] 로 고르고, 걸어가다가 if house_here() in targets: deliver(). 편지가 없는 짝수 집도 있으니 조심!",
		"map": [
			"############",
			"#SMMMMMMMMG#",
			"############",
		],
		"variants": [["#########", "#SMMMMMG#", "#########"], ["###########", "#SMMMMMMMG#", "###########"]],
		"mailbox_lists": [[3, 8, 12, 5, 6, 9], [10, 7, 4, 1], [1, 2, 3, 4, 5, 6]],
		"house_lists": [[2, 3, 5, 6, 8, 9, 10, 12], [1, 2, 4, 7, 10], [1, 2, 3, 4, 5, 6, 8]],
		"answers": [[8, 12, 6], [10, 4], [2, 4, 6]],
		"deliver": "set",
		"facing": "E",
		"required": ["comprehension"],
		"par": 5,
		"tools": ["move", "while", "if", "cond", "not", "ops", "comprehension", "mailboxes", "house", "print"],
		"starter": "print(mailboxes())\n",
		"solution": "targets = [n for n in mailboxes() if n % 2 == 0]\nwhile not at_goal():\n    move()\n    if house_here() in targets:\n        deliver()\n",
	},
	{
		"title": "가까운 보물부터",
		"goal": "보물은 [color=#e6b8e0]출발점에서 가까운 것부터[/color] 주워야 해요 (가로 칸 수 + 세로 칸 수). 먼 것을 먼저 주우면 실패! [color=#9fd4ff]sorted(목록, key=lambda p: 거리)[/color] 로 줄을 세워 보세요.",
		"hint": "sx, sy = get_pos() 로 출발점을 기억하고, sorted(treasure_map(), key=lambda p: abs(p[0] - sx) + abs(p[1] - sy)) 순서대로 go(x, y) 후 pick().",
		"map": [
			"#########",
			"#..A....#",
			"#.S...A.#",
			"#.......#",
			"#A....G.#",
			"#....A..#",
			"#########",
		],
		"variants": [
			["#########", "#A......#", "#....A..#", "#..S....#", "#......A#", "#.A...G.#", "#########"],
			["#########", "#S.....A#", "#..A....#", "#.......#", "#.A.....#", "#......G#", "#########"],
		],
		"rule": "nearest_first",
		"facing": "E",
		"banned": ["at_goal", "is_blocked", "on_apple", "item_here", "goal_x", "goal_y", "get_x", "get_y", "route", "segments"],
		"par": 20,
		"tools": ["move", "pick", "repeat", "if", "else", "var", "tuple_pos", "treasure", "abs", "def", "sort_key"],
		"starter": "sx, sy = get_pos()\nprint(treasure_map())\n",
		"solution": "def go(tx, ty):\n    x, y = get_pos()\n    if tx > x:\n        face(\"E\")\n    else:\n        face(\"W\")\n    repeat abs(tx - x):\n        move()\n    if ty > y:\n        face(\"S\")\n    else:\n        face(\"N\")\n    repeat abs(ty - y):\n        move()\nsx, sy = get_pos()\nfor tx, ty in sorted(treasure_map(), key=lambda p: abs(p[0] - sx) + abs(p[1] - sy)):\n    go(tx, ty)\n    pick()\ngx, gy = goal_pos()\ngo(gx, gy)\n",
	},
	{
		"title": "이름 묻기",
		"goal": "손님이 누구인지 몰라요. [color=#9fd4ff]input(\"질문\")[/color] 으로 물어보면 손님이 대답해 줘요. 대답을 변수에 담아 두었다가, 목표에 도착해서 say(f\"어서 오세요, {이름}님!\") 하세요. 손님은 매번 달라요.",
		"hint": "name = input(\"이름이 뭐예요? \") 로 대답을 받아 두고, 마지막에 say(f\"어서 오세요, {name}님!\")",
		"map": [
			"#########",
			"#S.....G#",
			"#########",
		],
		"variants": [
			["#######", "#S...G#", "#######"],
			["###########", "#S.......G#", "###########"],
		],
		"input_lists": [["마르타"], ["이반"], ["보리스"]],
		"speech": "어서 오세요, {in0}님!",
		"facing": "E",
		"required": ["input"],
		"par": 4,
		"tools": ["move", "while", "cond", "not", "input", "fstring_say", "print"],
		"starter": "name = input(\"이름이 뭐예요? \")\nprint(name)\n",
		"solution": "name = input(\"이름이 뭐예요? \")\nwhile not at_goal():\n    move()\nsay(f\"어서 오세요, {name}님!\")\n",
	},
	{
		"title": "몇 개 드릴까요?",
		"goal": "손님에게 [color=#9fd4ff]무엇을[/color], [color=#9fd4ff]몇 개[/color] 원하는지 input() 으로 두 번 물어보세요. 손님 집 앞(목표)에서 그만큼 drop() 으로 배달해요. input() 의 대답은 언제나 [color=#e6b8e0]글자[/color]라서, 개수는 int() 로 숫자로 바꿔야 해요.",
		"hint": "item = input(\"무엇을 드릴까요? \")\nn = int(input(\"몇 개 드릴까요? \"))\n그리고 목표에서 repeat n: drop(item)",
		"map": [
			"##########",
			"#S......##",
			"#######.##",
			"#G......##",
			"##########",
		],
		"variants": [
			["#########", "#S.....##", "######.##", "#G.....##", "#########"],
			["###########", "#S.......##", "########.##", "#G.......##", "###########"],
		],
		"input_lists": [["apple", "3"], ["corn", "5"], ["carrot", "2"]],
		"orders": [{"apple": 3}, {"corn": 5}, {"carrot": 2}],
		"facing": "E",
		"required": ["input"],
		"par": 9,
		"tools": ["move", "turn", "while", "if", "else", "cond", "not", "repeat", "input", "int_input", "drop", "print"],
		"starter": "item = input(\"무엇을 드릴까요? \")\nprint(item)\n",
		"solution": "item = input(\"무엇을 드릴까요? \")\nn = int(input(\"몇 개 드릴까요? \"))\nwhile not at_goal():\n    if is_blocked():\n        turn_right()\n    else:\n        move()\nrepeat n:\n    drop(item)\n",
	},
	{
		"title": "영수증",
		"goal": "길의 채소를 모두 담고, 가격표 market() 로 값을 더해 영수증을 report() 하세요. 영수증은 [color=#e6b8e0]\"합계 12,500원\"[/color] 처럼 세 자리마다 쉼표를 찍어요. f-문자열의 [color=#9fd4ff]{total:,}[/color] 가 쉼표를 찍어 줘요.",
		"hint": "total 에 가격을 더해 두고, 마지막에 report(f\"합계 {total:,}원\")",
		"map": [
			"############",
			"#SKA.C.AK.G#",
			"############",
		],
		"variants": [
			["############", "#S.CCA..K.G#", "############"],
			["#########", "#SAAAC.G#", "#########"],
		],
		"prices": {"apple": 1200, "carrot": 850, "corn": 2300},
		"facing": "E",
		"report": "receipt",
		"par": 10,
		"tools": ["move", "pick", "while", "if", "cond", "not", "var", "items", "dict", "market", "report", "format_spec", "print"],
		"starter": "prices = market()\nprint(prices)\nprint(f\"{1234567:,}\")\n",
		"solution": "prices = market()\ntotal = 0\nwhile not at_goal():\n    move()\n    item = item_here()\n    if item is not None:\n        pick()\n        total += prices[item]\nreport(f\"합계 {total:,}원\")\n",
	},
	{
		"title": "비밀 편지",
		"goal": "문의 암호가 [color=#e6b8e0]카이사르 암호[/color]로 적혀 있어요: 글자마다 알파벳 3칸 뒤의 글자로 바뀌었어요 (a→d, b→e, ..., x→a). 표지판 read_sign() 을 3칸 앞으로 되돌려 읽고 문 앞에서 say() 하세요. [color=#9fd4ff]ord(\"a\")[/color] 는 글자의 번호 97, [color=#9fd4ff]chr(97)[/color] 은 번호의 글자 \"a\" 예요.",
		"hint": "chr((ord(c) - ord(\"a\") - 3) % 26 + ord(\"a\")) 가 글자 c 를 3칸 되돌려요. % 26 덕분에 a 앞은 z 로 돌아가요.",
		"map": [
			"###I######",
			"#S...D..G#",
			"##########",
		],
		"variants": [
			["#####I#####", "#S..D....G#", "###########"],
			["##I#######", "#S.....DG#", "##########"],
		],
		"signs": ["dssoh", "fruq", "fduurw"],
		"passwords": ["apple", "corn", "carrot"],
		"facing": "E",
		"par": 9,
		"tools": ["move", "while", "if", "cond", "not", "def", "for_in", "var", "ord_chr", "strings", "print"],
		"starter": "print(read_sign())\nprint(ord(\"a\"), chr(100))\n",
		"solution": "def decode(word):\n    out = \"\"\n    for c in word:\n        out += chr((ord(c) - ord(\"a\") - 3) % 26 + ord(\"a\"))\n    return out\nwhile not at_goal():\n    if is_blocked():\n        say(decode(read_sign()))\n    move()\n",
	},
	{
		"title": "숫자만 골라 더하기",
		"goal": "창고 문의 암호는 우편함 쪽지 mailboxes() 중 [color=#e6b8e0]숫자로만 된 쪽지를 모두 더한 값[/color]이에요. 예: [\"12\", \"x3\", \"7\"] → 19. 쪽지에는 글자가 섞여 있어요. 암호를 계산해서 문 앞에서 say() 하고 목표로 가세요. [color=#9fd4ff]filter()[/color] 로 고르고 [color=#9fd4ff]map(int, ...)[/color] 로 바꿔 보세요.",
		"hint": "s.isdigit() 는 s 가 숫자로만 되어 있으면 True. total = sum(map(int, filter(lambda s: s.isdigit(), mailboxes()))) 을 문 앞에서 say(total).",
		"map": [
			"##########",
			"#S...D..G#",
			"##########",
		],
		"variants": [["########", "#S.D..G#", "########"], ["###########", "#S.....D.G#", "###########"]],
		"mailbox_lists": [["12", "7", "x3", "20", "?"], ["5", "a", "15"], ["100", "1", "b2", "9", "1o"]],
		"passwords": ["39", "20", "110"],
		"facing": "E",
		"par": 5,
		"tools": ["move", "while", "if", "cond", "not", "mailboxes", "map_filter", "door_say", "print"],
		"starter": "print(mailboxes())\n",
		"solution": "total = sum(map(int, filter(lambda s: s.isdigit(), mailboxes())))\nwhile not at_goal():\n    if is_blocked():\n        say(total)\n    move()\n",
	},
	{
		"title": "곧은 거리",
		"goal": "밭에 깃발이 여러 개 있어요. 그중 [color=#e6b8e0]새가 날아가듯 곧게 잰 거리가 가장 가까운 깃발[/color]로 가야 해요. 걸어서 가까운 깃발과는 다를 수 있어요! 가로 a칸, 세로 b칸 떨어진 곳의 곧은 거리는 [color=#9fd4ff]math.hypot(a, b)[/color] 예요. 깃발 위치 목록은 flags() 예요.",
		"hint": "x, y = get_pos() 다음 fx, fy = min(flags(), key=lambda f: math.hypot(f[0] - x, f[1] - y)) 로 고르고 go(fx, fy).",
		"map": [
			"###########",
			"#.........#",
			"#.........#",
			"#S.......G#",
			"#........G#",
			"#.......G.#",
			"#.........#",
			"###########",
		],
		"variants": [["##########", "#........#", "#......G.#", "#.S....G.#", "#........#", "#........#", "#....G...#", "##########"], ["###########", "#.........#", "#G....S...#", "#.........#", "#G........#", "#........G#", "###########"]],
		"rule": "nearest_flag",
		"facing": "E",
		"par": 12,
		"tools": ["move", "repeat", "def", "var", "tuple_pos", "abs", "math", "math_more", "flags", "sort_key", "print"],
		"starter": "import math\nprint(get_pos(), flags())\n",
		"solution": "import math\ndef go(tx, ty):\n    x, y = get_pos()\n    face(\"E\" if tx > x else \"W\")\n    repeat abs(tx - x):\n        move()\n    face(\"S\" if ty > y else \"N\")\n    repeat abs(ty - y):\n        move()\nx, y = get_pos()\nfx, fy = min(flags(), key=lambda f: math.hypot(f[0] - x, f[1] - y))\ngo(fx, fy)\n",
	},
	{
		"title": "똑같이 나눠 담기",
		"goal": "사과와 당근을 모두 담고, [color=#e6b8e0]상자마다 사과 수도 같고 당근 수도 같게[/color] 나눠 담으려고 해요. 상자를 가장 많이 쓰면 몇 개일까요? 그 수를 report() 하세요. 두 수를 모두 나누어떨어지게 하는 가장 큰 수, [color=#9fd4ff]math.gcd(a, b)[/color] 예요.",
		"hint": "사과 수와 당근 수를 따로 세고, report(math.gcd(apples, carrots)). 예: 사과 6, 당근 4 → 상자 2개 (사과 3, 당근 2씩).",
		"map": [
			"#################",
			"#SC.A.AACC.AACAG#",
			"#################",
		],
		"variants": [["######################", "#SCCA.AAAACACC.CA.AAG#", "######################"], ["###########################", "#SA.CACA.CCACC.CCAACCACCAG#", "###########################"]],
		"report": "gcd",
		"facing": "E",
		"par": 13,
		"tools": ["move", "pick", "while", "if", "elif", "cond", "not", "var", "items", "math", "math_more", "report", "print"],
		"starter": "import math\nprint(math.gcd(6, 4))\n",
		"solution": "import math\napples = 0\ncarrots = 0\nwhile not at_goal():\n    move()\n    item = item_here()\n    if item == \"apple\":\n        apples += 1\n    elif item == \"carrot\":\n        carrots += 1\n    if item is not None:\n        pick()\nreport(math.gcd(apples, carrots))\n",
	},
	{
		"title": "당번 뽑기",
		"goal": "오늘의 청소 당번을 뽑아 알림을 돌려요. 촌장님께 [color=#9fd4ff]input()[/color] 으로 몇 명을 뽑을지 묻고, 마을 사람 명단 mailboxes() 에서 [color=#e6b8e0]서로 다른 사람[/color]을 무작위로 그만큼 뽑으세요. 길을 따라가며 뽑힌 사람의 집 앞에서 deliver() 해요. [color=#9fd4ff]random.sample(목록, k)[/color] 은 겹치지 않게 k개를 뽑아요.",
		"hint": "k = int(input(\"몇 명 뽑을까요? \")), chosen = random.sample(mailboxes(), k). 걸어가다가 if house_here() in chosen: deliver()",
		"map": [
			"###############",
			"#S.M.M.M.M.M.G#",
			"###############",
		],
		"variants": [["#################", "#S.M.M.M.M.M.M.G#", "#################"], ["#############", "#S.M.M.M.M.G#", "#############"]],
		"mailbox_lists": [["민지", "철수", "영희", "준호", "수아"], ["가온", "나래", "다솜", "라온", "마루", "바다"], ["별", "달", "해", "구름"]],
		"house_lists": [["영희", "민지", "수아", "철수", "준호"], ["마루", "가온", "바다", "나래", "라온", "다솜"], ["해", "구름", "별", "달"]],
		"input_lists": [["2"], ["3"], ["2"]],
		"deliver": "sample",
		"facing": "E",
		"required": ["random", "input"],
		"seeds": [2, 3],
		"par": 7,
		"tools": ["move", "while", "if", "cond", "not", "input", "int_input", "mailboxes", "random", "random_more", "house", "print"],
		"starter": "import random\nprint(mailboxes())\n",
		"solution": "import random\nk = int(input(\"몇 명 뽑을까요? \"))\nchosen = random.sample(mailboxes(), k)\nwhile not at_goal():\n    move()\n    if house_here() in chosen:\n        deliver()\n",
	},
	{
		"title": "가장 많은 채소",
		"goal": "길의 채소를 모두 담고, [color=#e6b8e0]가장 많이 담은 채소의 이름[/color]을 report() 하세요. 예: \"carrot\". [color=#9fd4ff]collections.Counter[/color] 는 목록 안의 값마다 개수를 세 주고, .most_common(1) 은 가장 많은 것을 알려 줘요.",
		"hint": "담은 채소 이름을 basket 목록에 모으고, report(Counter(basket).most_common(1)[0][0]). most_common(1) 은 [(이름, 개수)] 모양이에요.",
		"map": [
			"################",
			"#S.AK.CAKCCACCG#",
			"################",
		],
		"variants": [["###############", "#S.AKKAAKACC.G#", "###############"], ["################", "#SKKCCK..AKKCKG#", "################"]],
		"report": "most",
		"facing": "E",
		"par": 9,
		"tools": ["move", "pick", "while", "if", "cond", "not", "var", "items", "list", "counter", "report", "print"],
		"starter": "from collections import Counter\nprint(Counter([\"apple\", \"corn\", \"apple\"]))\n",
		"solution": "from collections import Counter\nbasket = []\nwhile not at_goal():\n    move()\n    item = item_here()\n    if item is not None:\n        pick()\n        basket.append(item)\nreport(Counter(basket).most_common(1)[0][0])\n",
	},
	{
		"title": "빵집 대기줄",
		"goal": "빵집 앞 줄의 기록 mailboxes() 를 차례대로 따라가며 누가 어떤 순서로 빵을 받는지 알아내고, [color=#e6b8e0]그 순서대로[/color] 그 사람 집에 빵을 배달(deliver)하세요. 이름은 줄 맨 뒤에 서고, \"!이름\" 은 급한 손님이라 맨 앞에 서고, \"-\" 는 맨 앞 사람이 빵을 받아요. 집 위치는 houses() 에 있어요. [color=#9fd4ff]deque[/color] 는 양쪽 끝에 넣고 빼기 좋은 줄이에요.",
		"hint": "line = deque() 에서 append(이름) 은 뒤에, appendleft(이름) 은 앞에 넣고, popleft() 는 맨 앞 사람을 꺼내요. 받은 사람마다 x, y = houses()[이름] 으로 가서 deliver().",
		"map": [
			"############",
			"#S.M.M.M.M.#",
			"############",
		],
		"variants": [["############", "#S..M.M.M.M#", "############"], ["############", "#SM.M..M.M.#", "############"]],
		"mailbox_lists": [["민지", "철수", "-", "!할머니", "영희", "-", "-"], ["가온", "나래", "!다솜", "-", "-", "라온", "-"], ["별", "!달", "!해", "-", "구름", "-", "-", "-"]],
		"house_lists": [["철수", "영희", "민지", "할머니"], ["나래", "라온", "가온", "다솜"], ["별", "구름", "해", "달"]],
		"answers": [["민지", "할머니", "철수"], ["다솜", "가온", "나래"], ["해", "달", "별", "구름"]],
		"deliver": "order",
		"facing": "E",
		"par": 17,
		"tools": ["move", "repeat", "if", "elif", "else", "cond", "for_in", "var", "abs", "tuple_pos", "mailboxes", "deque", "houses", "print"],
		"starter": "from collections import deque\nprint(mailboxes())\nprint(houses())\n",
		"solution": "from collections import deque\nline = deque()\nserved = []\nfor e in mailboxes():\n    if e == \"-\":\n        served.append(line.popleft())\n    elif e.startswith(\"!\"):\n        line.appendleft(e[1:])\n    else:\n        line.append(e)\nspots = houses()\nfor name in served:\n    x, y = spots[name]\n    face(\"E\" if x > get_x() else \"W\")\n    repeat abs(x - get_x()):\n        move()\n    deliver()\n",
	},
	{
		"title": "사과 무게",
		"goal": "사과 저장고에는 문이 두 개 있어요. 첫 문의 암호는 사과 무게 기록 mailboxes() 의 [color=#e6b8e0]평균[/color], 둘째 문의 암호는 [color=#e6b8e0]가운데 값(중앙값)[/color]이에요. 가운데 값은 무게를 줄 세웠을 때 한가운데 값이에요. [color=#9fd4ff]statistics.mean[/color] 과 [color=#9fd4ff]statistics.median[/color] 으로 계산해서 문마다 say() 하세요.",
		"hint": "codes = [statistics.mean(w), statistics.median(w)] 를 만들어 두고, 문 앞에서 say(codes.pop(0)) 하면 차례대로 꺼내져요.",
		"map": [
			"##########",
			"#S.D..D.G#",
			"##########",
		],
		"variants": [["#########", "#S.D.D.G#", "#########"], ["############", "#S..D...D.G#", "############"]],
		"mailbox_lists": [[120, 135, 150, 110, 135], [98, 102, 101, 99], [140, 126, 133]],
		"passwords": [["130", "135"], ["100", "100.0"], ["133", "133"]],
		"facing": "E",
		"par": 7,
		"tools": ["move", "while", "if", "cond", "not", "var", "list", "mailboxes", "statistics", "door_say", "print"],
		"starter": "import statistics\nprint(mailboxes())\n",
		"solution": "import statistics\nw = mailboxes()\ncodes = [statistics.mean(w), statistics.median(w)]\nwhile not at_goal():\n    if is_blocked():\n        say(codes.pop(0))\n    move()\n",
	},
	{
		"title": "가장 짧은 배달",
		"goal": "보물을 모두 주워 목표로 가요. 이번엔 [color=#e6b8e0]가장 적게 걷는 순서[/color]로만 통과해요. 가까운 것부터 줍는 방법은 손해일 때가 있어요! [color=#9fd4ff]itertools.permutations[/color] 로 가능한 순서를 모두 만들어, 걸음 수가 가장 적은 순서를 고르세요.",
		"hint": "순서 하나의 걸음 수는 출발→보물들→목표 사이의 (가로 칸 수 + 세로 칸 수) 합이에요. min(permutations(treasure_map()), key=걸음수함수)",
		"map": [
			"##########",
			"#.A.A....#",
			"#......A.#",
			"#....S...#",
			"#..G.....#",
			"#........#",
			"##########",
		],
		"variants": [["#########", "#.......#", "#.S.....#", "#.....G.#", "#...AA..#", "#A......#", "#########"], ["##########", "#.A......#", "#.......G#", "#..A.A...#", "#........#", "#........#", "#A.....S.#", "##########"]],
		"rule": "shortest",
		"facing": "E",
		"par": 16,
		"tools": ["move", "pick", "repeat", "def", "var", "tuple_pos", "treasure", "abs", "sort_key", "itertools", "print"],
		"starter": "from itertools import permutations\nprint(list(permutations([1, 2, 3])))\nprint(treasure_map())\n",
		"solution": "from itertools import permutations\ndef go(tx, ty):\n    x, y = get_pos()\n    face(\"E\" if tx > x else \"W\")\n    repeat abs(tx - x):\n        move()\n    face(\"S\" if ty > y else \"N\")\n    repeat abs(ty - y):\n        move()\ndef steps(order):\n    stops = [get_pos()] + list(order) + [goal_pos()]\n    return sum(abs(a[0] - b[0]) + abs(a[1] - b[1]) for a, b in zip(stops, stops[1:]))\nfor x, y in min(permutations(treasure_map()), key=steps):\n    go(x, y)\n    pick()\ngo(*goal_pos())\n",
	},
]


## Chapters for the chapter screen: title, what they teach, and their level indexes (in order).
const CHAPTERS: Array[Dictionary] = [
	{"title": "첫 걸음", "topic": "명령을 순서대로", "levels": [0, 1, 2]},
	{"title": "반복", "topic": "repeat", "levels": [3, 4]},
	{"title": "조건", "topic": "if · while", "levels": [5, 6, 7]},
	{"title": "변수", "topic": "n = 0 · n += 1 · //", "levels": [8, 9]},
	{"title": "함수", "topic": "def", "levels": [10, 11]},
	{"title": "수학", "topic": "abs · import math", "levels": [12, 13]},
	{"title": "리스트", "topic": "[ ] · for ... in · [x for x in ...]", "levels": [14, 15, 32]},
	{"title": "무작위", "topic": "import random · random.sample", "levels": [16, 17, 41]},
	{"title": "객체와 클래스", "topic": "robots() · class · 상속", "levels": [18, 19, 20]},
	{"title": "튜플", "topic": "(x, y) · 나눠 담기 · sorted(key=)", "levels": [21, 22, 33]},
	{"title": "딕셔너리", "topic": "{키: 값}", "levels": [23, 24, 25, 26]},
	{"title": "문자열 · 집합 · 예외", "topic": "s[::-1] · f\"\" · set · try", "levels": [27, 28, 29, 30, 31]},
	{"title": "입력과 서식", "topic": "input() · int() · f\"{x:,}\"", "levels": [34, 35, 36]},
	{"title": "내장 함수", "topic": "ord · chr · map · filter", "levels": [37, 38]},
	{"title": "모듈 탐험", "topic": "math.gcd · hypot · collections · statistics · itertools", "levels": [40, 42, 43, 44, 39, 45]},
]


## Levels in play order (chapter by chapter). ALL itself is append-only: progress is saved by
## index, so new levels go at the end of ALL and are placed in a chapter here.
static func order() -> Array:
	var out: Array = []
	for ch in CHAPTERS:
		out.append_array(ch["levels"])
	return out


## The number players see ("15."), from the play order.
static func number(index: int) -> int:
	return order().find(index) + 1


static func title(index: int) -> String:
	return "%d. %s" % [number(index), ALL[index]["title"]]


## Next / previous level in play order, or -1.
static func next_of(index: int) -> int:
	var o := order()
	var at := o.find(index)
	return o[at + 1] if at >= 0 and at + 1 < o.size() else -1


static func prev_of(index: int) -> int:
	var o := order()
	var at := o.find(index)
	return o[at - 1] if at > 0 else -1


static func chapter_of(level_index: int) -> int:
	for c in CHAPTERS.size():
		if level_index in CHAPTERS[c]["levels"]:
			return c
	return -1


## The level as seen on map `index`: "map" replaced by that map, and each PER_MAP key
## (e.g. "orders") turned into its single value for that map (e.g. "order").
static func for_map(level: Dictionary, index: int) -> Dictionary:
	var data := level.duplicate()
	data["map"] = maps(level)[index]
	for many in PER_MAP:
		if level.has(many):
			data[PER_MAP[many]] = level[many][index]
	return data


## Level keys holding one value per map (main map first, then variants) -> the single key.
const PER_MAP: Dictionary = {
	"orders": "order", "signs": "sign", "passwords": "password", "customers": "customer",
	"mailbox_lists": "mailboxes", "answers": "answer", "input_lists": "inputs", "house_lists": "houses",
}


## Random seeds every map is checked with: 1 (the visible run) plus the level's "seeds".
static func seeds(level: Dictionary) -> Array:
	var result: Array = [1]
	result.append_array(level.get("seeds", []))
	return result


## The visible map followed by any hidden variants.
static func maps(level: Dictionary) -> Array:
	var result: Array = [level["map"]]
	result.append_array(level.get("variants", []))
	return result
