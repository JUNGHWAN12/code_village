class_name Dialogue
extends RefCounted
## Villagers who give each mission, and what they say. LEVELS[i] belongs to Levels.ALL[i].
##
## Each level entry: "who" (a CAST key), "intro" (1-2 bubbles when the level opens),
## "hints" (shown one per press of the hint button, before the level's own "hint"),
## "success" (said when the level is cleared). Failure lines come from the speaker's
## style in FAIL, with {left} (apples left) and {line} (line number) filled in.
## Use [code]...[/code] for code; SpeechBubble.format() colors it.

## look: outfit parts of the villager FBX (see Villager.setup). style: key into FAIL.
const CAST: Dictionary = {
	"granny": {
		"name": "과수원 마르타 할머니",
		"style": "granny",
		"look": {"model": "female", "parts": ["Bandana_01a", "Dress_03", "Hair_01a"], "item": "I_bucket"},
	},
	"ivan": {
		"name": "양치기 이반",
		"style": "polite",
		"look": {"model": "male", "parts": ["Eyebrows_01a", "Hair_01b", "Shirt_01a", "Shoes_01b", "Trousers_01a", "Vest_01b"], "item": "I_Villager_Rake_01a"},
	},
	"boris": {
		"name": "대장장이 보리스",
		"style": "gruff",
		"look": {"model": "male", "parts": ["Beard_01a", "Moustache_01c", "Eyebrows_01a", "Shirt_01a", "Shoes_01c", "Trousers_01b", "Vest_02a"], "item": "I_Villager_Hammer_01a"},
	},
	"vera": {
		"name": "측량사 베라",
		"style": "polite",
		"look": {"model": "female", "parts": ["Dress_02", "Hair_01b"], "item": ""},
	},
	"toma": {
		"name": "우체부 토마",
		"style": "polite",
		"look": {"model": "male", "parts": ["Eyebrows_01a", "Hut_01b", "Moustache_01b", "Shirt_01a", "Shoes_01a", "Trousers_01a", "Vest_01a"], "item": "I_Villager_Box_01a"},
	},
	"natasha": {
		"name": "축제 준비위원 나타샤",
		"style": "polite",
		"look": {"model": "female", "parts": ["Bandana_02a", "Dress_04"], "item": "I_Broom"},
	},
	"mikhail": {
		"name": "탐험가 미하일",
		"style": "gruff",
		"look": {"model": "male", "parts": ["Beard_01a", "Eyebrows_01a", "Hair_01b", "Shirt_01a", "Shoes_01c", "Trousers_01a", "Vest_02c"], "item": "I_Villager_Axe_01a"},
	},
	"olga": {
		"name": "시장 상인 올가",
		"style": "polite",
		"look": {"model": "female", "parts": ["Bandana_01b", "Dress_04", "Hair_01a"], "item": ""},
	},
	"petra": {
		"name": "도서관 사서 페트라",
		"style": "polite",
		"look": {"model": "female", "parts": ["Bandana_02a", "Dress_02", "Hair_01a"], "item": ""},
	},
	"igor": {
		"name": "마구간지기 이고르",
		"style": "gruff",
		"look": {"model": "male", "parts": ["Eyebrows_01a", "Hair_01a", "Moustache_01b", "Shirt_01a", "Shoes_01b", "Trousers_01b", "Vest_02b"], "item": "I_Villager_Bucket_01a"},
	},
	"anna": {
		"name": "요리사 안나",
		"style": "polite",
		"look": {"model": "female", "parts": ["Dress_01", "Hair_01b"], "item": "I_kettle_01a"},
	},
	"vlad": {
		"name": "촌장 블라드",
		"style": "chief",
		"look": {"model": "male", "parts": ["Beard_01a", "Hut_01a", "Moustache_01c", "Shirt_01a", "Shoes_01c", "Trousers_01b", "Vest_02b"], "item": "I_mechanic_key"},
	},
}

## Failure lines per speech style.
## apples: at the goal with apples left. goal: code ended away from the goal.
## error: the code stopped on a line. other: worked here but failed on a hidden map or seed.
## order: delivered items differ from the order. report: report() got a wrong value (or none).
## rule: not exactly one item of each kind. speech: say() never matched the expected greeting.
const FAIL: Dictionary = {
	"granny": {
		"apples": "사과가 {left}개 남았구나. 하나도 빠짐없이 주워 오렴.",
		"goal": "아직 여기까지 못 왔구나. 칸 수를 다시 세어 보렴.",
		"error": "{line}번째 줄에서 멈췄구나. 빨갛게 칠해진 줄을 살펴보렴.",
		"other": "이 길에서는 됐는데, 다른 길에서는 안 되는구나. 어느 길에서나 되게 해 보렴.",
		"order": "주문한 것과 다르구나. 주문서를 다시 보렴.",
		"report": "보고한 값이 실제와 다르구나. 다시 세어 보렴.",
		"rule": "종류마다 하나씩만 가져오렴.",
		"speech": "인사를 제대로 해 주렴. 이름과 개수를 넣어서.",
	},
	"polite": {
		"apples": "사과가 {left}개 남았어요. 모두 주워 주세요!",
		"goal": "아직 목표에 도착하지 못했어요.",
		"error": "{line}번째 줄에서 문제가 생겼어요. 빨간 줄을 확인해 보세요.",
		"other": "여기서는 됐지만 다른 경우에는 실패했어요. 그 경우를 보여 드릴게요!",
		"order": "주문과 배달이 달라요. 주문서를 다시 확인해 주세요!",
		"report": "보고한 값이 실제와 달라요. 다시 계산해 볼까요?",
		"rule": "종류마다 딱 하나씩만 주워야 해요.",
		"speech": "인사말이 달라요. 이름과 개수를 넣어 다시 말해 볼까요?",
	},
	"gruff": {
		"apples": "흠, 사과가 {left}개 남았군.",
		"goal": "아직 멀었네. 다시 해 보게.",
		"error": "{line}번째 줄이 말썽이군. 빨간 줄을 보게.",
		"other": "여기선 통했지만 다른 길에선 안 통하는군. 그 길을 보게.",
		"order": "주문서와 다르군. 다시 보게.",
		"report": "보고가 틀렸군. 다시 세어 보게.",
		"rule": "종류마다 하나씩이라고 했지.",
		"speech": "인사가 틀렸군. 다시 말해 보게.",
	},
	"chief": {
		"apples": "사과가 {left}개 남았소. 모두 거두어 주시오.",
		"goal": "아직 목표에 닿지 않은 로봇이 있소.",
		"error": "{line}번째 줄에서 일이 멈췄소. 빨간 줄을 살펴보시오.",
		"other": "여기서는 되었으나 다른 경우에는 실패했소. 그 경우를 보여 주겠소.",
		"order": "주문과 배달이 맞지 않소.",
		"report": "보고한 값이 실제와 다르오.",
		"rule": "종류마다 하나씩만 거두시오.",
		"speech": "인사말이 틀렸소.",
	},
}

const LEVELS: Array[Dictionary] = [
	# 1-5: sequence and repeat
	{
		"who": "granny",
		"intro": ["얘야, 내 바구니를 저 빛나는 곳에 두고 왔단다.", "[code]move()[/code] 로 한 칸씩 가서 찾아 주겠니?"],
		"hints": ["로봇과 빛나는 곳 사이가 몇 칸인지 세어 보렴.", "한 줄에 [code]move()[/code] 하나씩 적는 거란다."],
		"success": "아이고, 고맙구나! 바구니가 무사하네.",
	},
	{
		"who": "granny",
		"intro": ["가는 길에 사과가 하나 떨어져 있구나.", "주워서 바구니까지 가져다주렴."],
		"hints": ["사과 위에 섰을 때 [code]pick()[/code] 을 쓰렴.", "사과까지 몇 칸, 사과에서 바구니까지 몇 칸인지 따로 세어 보렴."],
		"success": "잘 주웠구나! 오늘은 사과 파이를 굽겠다.",
	},
	{
		"who": "granny",
		"intro": ["과수원 길은 구불구불하단다.", "모퉁이에서는 방향을 바꿔야 해."],
		"hints": ["로봇 발밑의 노란 화살표가 보는 방향이란다.", "오른쪽으로 꺾이는 곳에서는 [code]turn_right()[/code] 를 쓰렴."],
		"success": "길을 참 잘 찾는구나!",
	},
	{
		"who": "granny",
		"intro": ["사과가 일곱 개나 줄지어 있구나!", "같은 일을 일곱 번 적기는 힘들지? 반복을 써 보렴."],
		"hints": ["[code]move()[/code] 하고 [code]pick()[/code] 하는 일이 계속 되풀이되는구나.", "[code]repeat 7:[/code] 아래에 되풀이할 줄을 들여써 보렴."],
		"success": "네 줄로 해냈다니, 정말 똑똑하구나!",
	},
	{
		"who": "granny",
		"intro": ["언덕 계단길에도 사과가 있단다.", "한 계단 내려가는 동작을 찾아보렴."],
		"hints": ["오른쪽으로 한 칸, 아래로 한 칸이 한 계단이란다.", "한 계단 동작을 [code]repeat 4:[/code] 로 묶어 보렴."],
		"success": "계단도 문제없구나! 바구니가 한가득이야.",
	},
	# 6-8: conditions
	{
		"who": "ivan",
		"intro": ["안녕하세요! 저는 양치기 이반이에요.", "사과가 있는 칸에서만 주워 주세요. 다른 길은 사과 위치가 달라요!"],
		"hints": ["빈 칸에서 [code]pick()[/code] 하면 실패예요. 먼저 확인해야 해요.", "[code]if on_apple():[/code] 아래에 들여쓴 줄은 사과가 있을 때만 실행돼요."],
		"success": "어느 길에서나 통하는 코드네요! 최고예요.",
	},
	{
		"who": "ivan",
		"intro": ["양들이 소용돌이 길 한가운데로 들어갔어요!", "길이 막히면 오른쪽으로 돌면서 가운데까지 가 주세요."],
		"hints": ["목표에 닿을 때까지 계속 반복해야 해요. [code]while not at_goal():[/code]", "앞이 막혔으면 오른쪽으로 돌고, 아니면 앞으로 가요. if 와 else 를 써 보세요."],
		"success": "양들을 찾았어요! 고마워요.",
	},
	{
		"who": "ivan",
		"intro": ["마을을 한 바퀴 돌면서 사과를 모두 모아야 해요.", "지금까지 배운 걸 다 써 볼 시간이에요!"],
		"hints": ["while 안에 if 를 두 개 써요. 사과 확인 하나, 벽 확인 하나.", "이번 길은 막히면 왼쪽으로 돌아요."],
		"success": "완벽한 마을 한 바퀴예요!",
	},
	# 9-12: variables and functions
	{
		"who": "boris",
		"intro": ["흠, 안개가 짙어서 목표가 안 보이는군.", "몇 걸음 갔는지 세어 두면 정확히 돌아올 수 있지."],
		"hints": ["[code]n = 0[/code] 처럼 숫자를 담아 둘 변수를 만들게.", "[code]move()[/code] 할 때마다 [code]n += 1[/code]. 돌아올 땐 그만큼 걸으면 되네."],
		"success": "정확하군! 대장간 일꾼으로 딱이야.",
	},
	{
		"who": "boris",
		"intro": ["이 쇠막대 길의 정확히 한가운데를 찾아 주게.", "길이는 매번 달라."],
		"hints": ["끝까지 가며 걸음을 세고, 돌아올 땐 그 절반만 걸어야지.", "[code]n // 2[/code] 는 n 을 2로 나눈 몫이야."],
		"success": "딱 한가운데! 망치질하기 좋은 자리군.",
	},
	{
		"who": "boris",
		"intro": ["같은 동작을 자꾸 적는 건 시간 낭비지.", "'n칸 걷기' 명령을 직접 만들어 쓰게나."],
		"hints": ["[code]def walk(n):[/code] 로 새 명령을 만들 수 있네.", "만든 뒤에는 [code]walk(3)[/code] 처럼 불러 쓰면 돼."],
		"success": "좋은 연장을 만들었군. 두고두고 쓰게.",
	},
	{
		"who": "boris",
		"intro": ["돌 때마다 한 칸씩 길어지는 소용돌이 길이야.", "자네가 만든 walk 명령과 변수를 함께 써 보게."],
		"hints": ["걷는 칸 수가 1, 1, 2, 2, 3, 3… 으로 늘어나지.", "[code]walk(n)[/code] 두 번 하고 [code]n += 1[/code]. 이걸 반복하게."],
		"success": "훌륭해! 쇠를 감는 솜씨 같군.",
	},
	# 13-14: math
	{
		"who": "vera",
		"intro": ["안녕하세요, 측량사 베라예요.", "지도 위의 숫자, 좌표로 목표까지 정확히 가 볼까요?"],
		"hints": ["[code]goal_x() - get_x()[/code] 가 가야 할 칸 수예요. 음수면 왼쪽이에요.", "[code]abs()[/code] 는 음수를 양수로 바꿔 줘요."],
		"success": "오차 없이 정확해요! 측량사가 되어도 되겠어요.",
	},
	{
		"who": "vera",
		"intro": ["이 사과밭은 완벽한 정사각형이에요.", "사과 수만 알면 한 변의 길이를 구할 수 있죠."],
		"hints": ["사과가 16개면 한 변은 4칸, 제곱근이에요! [code]import math[/code]", "줄이 바뀔 때마다 도는 방향이 번갈아 바뀌어요. [code]row % 2[/code] 를 써 보세요."],
		"success": "밭 전체를 빈틈없이! 계산이 완벽해요.",
	},
	# 15-16: lists
	{
		"who": "toma",
		"intro": ["우체부 토마입니다! 배달 쪽지를 받았어요.", "쪽지에 적힌 순서대로만 가면 돼요."],
		"hints": ["[code]print(route())[/code] 로 쪽지를 먼저 읽어 보세요.", "[code]for step in route():[/code] 로 하나씩 꺼내서 F, L, R 에 맞게 움직여요."],
		"success": "편지가 제때 도착했어요!",
	},
	{
		"who": "toma",
		"intro": ["이번 쪽지에는 숫자만 적혀 있어요.", "곧게 갈 칸 수예요. 계단길이라 오른쪽, 왼쪽을 번갈아 돌아요."],
		"hints": ["[code]s[0][/code] 은 첫 번째 숫자, [code]s[1][/code] 은 두 번째 숫자예요.", "[code]for i in range(len(s)):[/code] 로 번호를 돌리면서 [code]s[i][/code] 를 써요."],
		"success": "숫자 쪽지도 척척! 최고의 배달부예요.",
	},
	# 17-18: random
	{
		"who": "natasha",
		"intro": ["축제 준비 중인데 광장이 너무 넓어요!", "벽만 따라 돌면 가운데에 못 가요. 가끔은 운에 맡겨 보세요."],
		"hints": ["[code]import random[/code] 을 쓰면 무작위 수를 뽑을 수 있어요.", "[code]random.randint(1, 3) == 1[/code] 이면 세 번에 한 번꼴로 방향을 바꿔요."],
		"success": "찾았다! 운도 실력이에요!",
	},
	{
		"who": "natasha",
		"intro": ["축제 파이에 쓸 사과가 광장에 흩어졌어요.", "모두 줍고 목표로 와 주세요!"],
		"hints": ["사과가 남았거나 목표가 아니면 계속 돌아다녀야 해요. [code]or[/code] 를 써 보세요.", "[code]random.choice([\"L\", \"R\"])[/code] 는 목록에서 하나를 골라요."],
		"success": "축제 파이 재료 완성!",
	},
	# 19-21: objects and classes
	{
		"who": "vlad",
		"intro": ["촌장 블라드요. 마을에 로봇이 더 왔다오!", "로봇마다 일을 시켜 주시오. 로봇 수는 날마다 다르오."],
		"hints": ["[code]robots()[/code] 는 로봇 객체 목록이오. [code]r.move()[/code] 처럼 명령하오.", "[code]for r in robots():[/code] 로 한 대씩 끝까지 보내시오."],
		"success": "모든 로봇이 제 몫을 했구려!",
	},
	{
		"who": "vlad",
		"intro": ["로봇마다 걸은 걸음 수를 따로 기억해야 하오.", "로봇과 걸음 수를 한데 묶는 [code]class[/code] 를 만들어 보시오."],
		"hints": ["[code]class Walker:[/code] 의 [code]__init__[/code] 에서 [code]self.robot[/code] 과 [code]self.steps[/code] 를 정하시오.", "모든 로봇이 먼저 사과를 주운 뒤에 돌아오게 하시오. 객체마다 걸음 수를 기억하오."],
		"success": "각자 제 기억을 가진 일꾼들이군. 훌륭하오!",
	},
	{
		"who": "vlad",
		"intro": ["주황 로봇은 걷기만, 파랑 로봇은 사과도 줍는다오.", "Walker 를 물려받아 조금만 바꾼 class 를 만들어 보시오."],
		"hints": ["[code]class Picker(Walker):[/code] 처럼 괄호 안에 물려받을 class 를 적으시오.", "Picker 의 [code]step()[/code] 에서 [code]super().step()[/code] 으로 원래 걷기를 부르고 사과를 주우시오."],
		"success": "물려받아 고쳐 쓰는 법까지! 이 마을의 자랑이오.",
	},
	# 22-23: tuples
	{
		"who": "mikhail",
		"intro": ["탐험가 미하일일세. 이 쪽지에 목표의 좌표가 적혀 있지.", "[code]gx, gy = goal_pos()[/code] 처럼 튜플을 두 변수에 나눠 담아 보게."],
		"hints": ["[code]x, y = get_pos()[/code] 로 지금 위치를 알 수 있네. 가로 먼저, 세로는 나중에.", "[code]face(\"E\")[/code] 는 동쪽을 보게 하지. N 북, E 동, S 남, W 서일세."],
		"success": "좌표 하나 틀림없군! 탐험대에 들어오게.",
	},
	{
		"who": "mikhail",
		"intro": ["보물 지도를 찾았네! 보물 위치가 튜플로 줄줄이 적혀 있어.", "좌표로 가는 [code]go(tx, ty)[/code] 함수를 만들면 편하지."],
		"hints": ["[code]for tx, ty in treasure_map():[/code] 로 튜플을 바로 나눠 꺼내게.", "go 안에서 [code]x, y = get_pos()[/code] 로 지금 위치를 알아낸 뒤 가로, 세로로 움직이게."],
		"success": "보물을 모조리 찾았군! 대단한 탐험가야.",
	},
	# 24-27: dictionaries
	{
		"who": "olga",
		"intro": ["시장 상인 올가예요. 채소가 길에 섞여 있어요.", "모두 주우면서 종류별로 몇 개인지 딕셔너리에 세어서 알려 주세요."],
		"hints": ["[code]count = {}[/code] 는 빈 딕셔너리예요. [code]count[\"apple\"] = 3[/code] 처럼 이름표에 숫자를 붙여요.", "[code]count.get(item, 0)[/code] 은 아직 없는 이름이면 0 을 줘요."],
		"success": "정확해요! 장부에 그대로 적을게요.",
	},
	{
		"who": "anna",
		"intro": ["요리사 안나예요. 오늘 수프 재료 주문서예요!", "주문서는 딕셔너리예요. 이름과 개수를 보고 그대로 배달해 주세요."],
		"hints": ["[code]print(order())[/code] 로 주문서를 먼저 읽어 보세요. 주문은 매번 달라요.", "[code]for item, n in order().items():[/code] 로 이름과 개수를 함께 꺼내요."],
		"success": "재료가 딱 맞아요! 맛있는 수프가 되겠어요.",
	},
	{
		"who": "toma",
		"intro": ["또 쪽지 배달이에요! 이번엔 if 없이 해 볼까요?", "딕셔너리에 명령을 담아 두면 쪽지 글자로 바로 꺼내 쓸 수 있어요."],
		"hints": ["명령 이름에 괄호를 안 붙이면 명령 자체를 값으로 담을 수 있어요. [code]{\"F\": move}[/code]", "[code]act[step]()[/code] 은 딕셔너리에서 꺼낸 명령을 실행해요."],
		"success": "세 줄로 배달 끝! 정말 깔끔해요.",
	},
	{
		"who": "olga",
		"intro": ["이번엔 계산을 부탁해요. 가격표는 [code]market()[/code] 에 있어요.", "채소를 모두 담고 총액을 알려 주세요."],
		"hints": ["[code]prices = market()[/code] 로 가격표를 받아 두세요. [code]prices[\"corn\"][/code] 은 옥수수 값이에요.", "주울 때마다 [code]total += prices[item][/code] 로 더해요."],
		"success": "계산이 딱 맞아요! 거스름돈도 필요 없겠네요.",
	},
	# 28-32: strings, sets, exceptions
	{
		"who": "petra",
		"intro": ["사서 페트라예요. 도서관 문은 암호로 열려요.", "표지판 암호는 거꾸로, 대문자로 적혀 있으니 바르게 고쳐서 말해 주세요."],
		"hints": ["[code]print(read_sign())[/code] 로 표지판을 먼저 읽어 보세요.", "[code]s[::-1][/code] 은 글자를 거꾸로, [code]s.lower()[/code] 는 소문자로 바꿔요."],
		"success": "문이 열렸네요! 글자를 다루는 솜씨가 훌륭해요.",
	},
	{
		"who": "petra",
		"intro": ["배달이 끝나면 손님께 인사를 해야죠.", "손님 이름과 사과 개수를 넣어서요. 손님은 매번 달라요."],
		"hints": ["[code]customer()[/code] 는 손님 이름이에요. 주운 사과 수는 변수에 세어 두세요.", "[code]f\"{customer()}님, 사과 {n}개 왔어요!\"[/code] 처럼 { } 안에 값을 넣어요."],
		"success": "공손하고 정확한 인사예요!",
	},
	{
		"who": "olga",
		"intro": ["시식 행사를 해요. 종류마다 하나씩만 필요해요!", "이미 주운 종류는 그냥 지나쳐 주세요."],
		"hints": ["이미 본 종류를 기억하려면 [code]seen = set()[/code] 이 좋아요.", "[code]item not in seen[/code] 일 때만 줍고, [code]seen.add(item)[/code] 으로 기억해요."],
		"success": "종류별로 하나씩, 완벽해요!",
	},
	{
		"who": "igor",
		"intro": ["마구간지기 이고르일세. 안개 때문에 발밑이 안 보이지.", "그냥 줍다가 빈 칸이면 오류가 나. 오류를 잡아서 넘어가게."],
		"hints": ["[code]try:[/code] 아래에 해 볼 일을, [code]except NoItem:[/code] 아래에 오류가 났을 때 할 일을 적게.", "할 일이 없으면 [code]pass[/code] 라고 적으면 돼."],
		"success": "오류에도 끄떡없군! 든든해.",
	},
	{
		"who": "igor",
		"intro": ["내 말들이 길을 왔다 갔다 하는군.", "부딪히면 Blocked 오류가 나지. 잡아서 잠깐 기다렸다 가게."],
		"hints": ["[code]try: move()[/code] 를 해 보고, [code]except Blocked:[/code] 에서 [code]wait()[/code] 하게.", "기다리는 동안 말이 한 칸 지나가지. 그다음에 다시 가면 돼."],
		"success": "말을 놀라게 하지 않고 지나갔군. 훌륭해!",
	},
	# Added later (same order as the end of Levels.ALL)
	{
		"who": "toma",
		"intro": ["우편함 번호 목록이 왔어요. 이번엔 짝수 집에만 배달해요!", "목록에서 짝수만 골라 [code]report()[/code] 로 알려 주세요. 한 줄로요!"],
		"hints": ["[code]n % 2 == 0[/code] 이면 짝수예요.", "[code][n for n in 목록 if 조건][/code] 은 조건에 맞는 것만 모은 새 목록이에요."],
		"success": "짝수 집만 쏙쏙! 깔끔한 목록이에요.",
	},
	{
		"who": "mikhail",
		"intro": ["이번 보물 지도는 순서가 뒤죽박죽이야.", "출발점에서 가까운 보물부터 주워야 하네. 먼 것부터 주우면 안 돼."],
		"hints": ["출발점과의 거리는 [code]abs(x - sx) + abs(y - sy)[/code] 지.", "[code]sorted(목록, key=lambda p: ...)[/code] 는 lambda 가 돌려준 값 순서대로 줄을 세우네."],
		"success": "가까운 것부터 차례차례. 노련한 탐험가로군!",
	},
	{
		"who": "anna",
		"intro": ["처음 보는 로봇이네요!", "제 이름이 궁금하면 [code]input(\"이름이 뭐예요? \")[/code] 으로 물어봐 주세요. 대답해 줄게요."],
		"hints": ["[code]name = input(\"이름이 뭐예요? \")[/code] 하면 제 대답이 name 에 담겨요.", "인사는 [code]say(f\"어서 오세요, {name}님!\")[/code] 처럼요."],
		"success": "제 이름을 기억해 줬군요! 반가워요.",
	},
	{
		"who": "boris",
		"intro": ["주문하러 왔소. 뭘, 몇 개 원하는지는 물어보시오.", "대답은 늘 글자로 하겠소. \"3\" 은 숫자가 아니라 글자요."],
		"hints": ["[code]n = int(input(\"몇 개 드릴까요? \"))[/code] 처럼 int() 로 감싸면 숫자가 되오.", "목표에 가서 [code]repeat n:[/code] 안에 [code]drop(item)[/code]."],
		"success": "딱 주문한 만큼이군. 셈이 정확하오.",
	},
	{
		"who": "olga",
		"intro": ["이번엔 값이 큰 채소들이에요. 영수증이 필요해요.", "\"합계 12,500원\" 처럼 세 자리마다 쉼표를 찍어 주세요."],
		"hints": ["f-문자열에서 [code]{total:,}[/code] 는 쉼표를 찍어 줘요.", "[code]report(f\"합계 {total:,}원\")[/code]"],
		"success": "깔끔한 영수증이네요. 장부에 붙여 둘게요!",
	},
	{
		"who": "vera",
		"intro": ["문에 이상한 글자가 적혀 있어요. 옛날 로마 장군이 쓰던 암호래요.", "글자마다 3칸씩 밀려 있대요. 되돌리면 암호가 나와요."],
		"hints": ["[code]ord(\"d\") - 3[/code] 은 [code]ord(\"a\")[/code] 와 같아요. 다시 [code]chr()[/code] 로 글자로 바꿔요.", "a 앞으로 넘어가면 z 로 돌아오게 [code]% 26[/code] 을 써요."],
		"success": "암호를 풀었어요! 로마 장군도 깜짝 놀라겠어요.",
	},
	{
		"who": "toma",
		"intro": ["우편함 쪽지에 장난꾸러기가 글자를 섞어 놨어요!", "숫자 쪽지만 골라서 더해 주세요."],
		"hints": ["[code]\"12\".isdigit()[/code] 는 True, [code]\"x3\".isdigit()[/code] 는 False 예요.", "[code]filter(조건함수, 목록)[/code] 은 고르고, [code]map(int, 목록)[/code] 은 모두 숫자로 바꿔요."],
		"success": "숫자만 쏙쏙 골라 더했네요. 고마워요!",
	},
]


static func for_level(index: int) -> Dictionary:
	return LEVELS[index] if index < LEVELS.size() else {}


static func speaker(index: int) -> Dictionary:
	var d := for_level(index)
	return CAST.get(d.get("who", ""), {})


## A failure line for the level's speaker. kind: "apples", "goal", "error" or "other".
static func fail_line(index: int, kind: String, values: Dictionary = {}) -> String:
	var who := speaker(index)
	var lines: Dictionary = FAIL.get(who.get("style", "polite"), FAIL["polite"])
	return String(lines.get(kind, "")).format(values)
