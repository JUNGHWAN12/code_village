class_name WorldHost
extends RefCounted
## Synchronous CodeInterpreter host over a GridWorld: no visuals, no waiting.
## Used by the tests and to check player code against a level's hidden map variants.

var world: GridWorld
var commands: int = 0  # robot commands run so far (for the "명령 n번" star rule)


func _init(w: GridWorld) -> void:
	world = w


## Runs an already parsed program on `map` of `level`.
## Returns {"result": Dictionary from CodeInterpreter.run, "world": GridWorld}.
static func run_on_map(level: Dictionary, map_index: int, program: Array, rng_seed: int = 0) -> Dictionary:
	var w := GridWorld.new()
	w.load_level(Levels.for_map(level, map_index))
	var result: Dictionary = await CodeInterpreter.new().run(program, WorldHost.new(w), rng_seed)
	return {"result": result, "world": w}


## The maps of a level (main first) crossed with its seeds: [{"map": int, "seed": int}].
## Every pair must be solved; levels without "seeds" use only seed 1.
static func checks(level: Dictionary) -> Array:
	var out: Array = []
	var maps := Levels.maps(level)
	for i in maps.size():
		for s in Levels.seeds(level):
			out.append({"map": i, "seed": s})
	return out


func run_command(name: String, _line: int, robot: int = 0, args: Array = []) -> String:
	commands += 1
	var message := _command(name, robot, args)
	world.tick()  # horses take their step after every robot command
	return message


func _command(name: String, robot: int, args: Array) -> String:
	match name:
		"move":
			if world.move(robot):
				return ""
			return BLOCKED_HORSE if world.horse_ahead(robot) else BLOCKED
		"turn_left":
			world.turn_left(robot)
		"turn_right":
			world.turn_right(robot)
		"pick":
			if world.pick(robot):
				return ""
			return world.last_pick_error if world.last_pick_error != "" else "여기에는 주울 것이 없어요."
		"face":
			return "" if world.face(robot, args[0]) >= 0 else FACE_ERROR % str(args[0])
		"drop":
			return world.drop(robot, args[0])
		"report":
			return world.report(args[0])
		"say":
			return world.say(robot, args[0])
		"deliver":
			return world.deliver(robot)
		"wait":
			world.wait(robot)
	return ""


const BLOCKED: String = "앞이 막혀 있어서 부딪혔어요!"
const BLOCKED_HORSE: String = "말이 길을 막고 있어서 부딪혔어요!"
const FACE_ERROR: String = "face() 에는 \"N\", \"E\", \"S\", \"W\" 중 하나를 넣어요 (지금: %s)."


func sense(name: String, robot: int = 0) -> Variant:
	return world.call(name, robot)


func robot_count() -> int:
	return world.robot_count()


func show_step(_line: int, _text: String, _value: Variant) -> void:
	pass


func print_line(_text: String) -> void:
	pass


## input(): the level's next prepared answer, echoed after the prompt like a terminal shows it.
func input_line(prompt: String) -> Variant:
	var answer: Variant = world.next_input()
	if answer != null:
		print_line(prompt + str(answer))
	return answer


func highlight_line(_line: int) -> void:
	pass


func is_stop_requested() -> bool:
	return false
