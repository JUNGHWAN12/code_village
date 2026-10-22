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
		"title": "1. 첫 걸음",
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
		"title": "2. 사과 줍기",
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
		"title": "3. 모퉁이 돌기",
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
		"title": "4. 반복의 힘",
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
		"title": "5. 계단 내려가기",
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
		"title": "6. 사과가 있을 때만",
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
		"title": "7. 소용돌이 길",
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
		"title": "8. 마을 한 바퀴",
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
		"title": "9. 걸음 세기",
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
		"title": "10. 한가운데",
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
		"title": "11. 나만의 명령",
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
		"title": "12. 점점 커지는 소용돌이",
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
		"title": "13. 좌표 계산",
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
		"title": "14. 정사각형 사과밭",
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
		"title": "15. 쪽지 따라가기",
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
		"title": "16. 숫자 쪽지",
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
		"title": "17. 넓은 광장",
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
		"title": "18. 광장의 사과",
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
		"title": "19. 로봇 여러 대",
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
		"title": "20. 저마다 기억하기",
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
		"title": "21. 물려받기",
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
		"title": "22. 좌표 쪽지",
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
		"title": "23. 보물 지도",
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
		"title": "24. 바구니 세기",
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
		"title": "25. 주문 배달",
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
		"title": "26. 명령표",
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
		"title": "27. 장보기 계산",
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
		"title": "28. 암호 문",
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
		"title": "29. 배달 인사",
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
		"title": "30. 종류마다 하나씩",
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
		"title": "31. 조심조심 줍기",
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
		"title": "32. 말이 지나가는 길",
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
]


## Chapters for the chapter screen: title, what they teach, and their level indexes (in order).
const CHAPTERS: Array[Dictionary] = [
	{"title": "첫 걸음", "topic": "명령을 순서대로", "levels": [0, 1, 2]},
	{"title": "반복", "topic": "repeat", "levels": [3, 4]},
	{"title": "조건", "topic": "if · while", "levels": [5, 6, 7]},
	{"title": "변수", "topic": "n = 0 · n += 1 · //", "levels": [8, 9]},
	{"title": "함수", "topic": "def", "levels": [10, 11]},
	{"title": "수학", "topic": "abs · import math", "levels": [12, 13]},
	{"title": "리스트", "topic": "[ ] · for ... in", "levels": [14, 15]},
	{"title": "무작위", "topic": "import random", "levels": [16, 17]},
	{"title": "객체와 클래스", "topic": "robots() · class · 상속", "levels": [18, 19, 20]},
	{"title": "튜플", "topic": "(x, y) · 나눠 담기", "levels": [21, 22]},
	{"title": "딕셔너리", "topic": "{키: 값}", "levels": [23, 24, 25, 26]},
	{"title": "문자열 · 집합 · 예외", "topic": "s[::-1] · f\"\" · set · try", "levels": [27, 28, 29, 30, 31]},
]


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
const PER_MAP: Dictionary = {"orders": "order", "signs": "sign", "passwords": "password", "customers": "customer"}


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
