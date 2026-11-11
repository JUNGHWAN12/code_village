# Code Village (Godot 4.7 coding-game prototype)

Players write a subset of Python (plus `repeat N:`) to move a robot through a 3D village grid.

## Layout
- `scenes/main.tscn`: UI (code editor, palette, console) on the left, 3D view in a SubViewport on the right.
- `scripts/grid_world.gd`: pure rules (no visuals), including value sensors (`get_x`, `apples_left`, ...).
- `scripts/code_interpreter.gd`: tokenizer + recursive-descent parser + async tree-walking runner.
  Supports variables, + - * / // % **, lists, strings, def/return/global, for/while/repeat, break/continue,
  `import math` / `import random` (seeded per run), class/__init__/self/inheritance/super(), and robot objects
  from `robots()`, tuples (`{"kind": "tuple"}`), dicts (`{"kind": "dict"}`, keys via `_key()`), sets, slicing
  (also slice assignment/del), f-strings / `format()` / `str.format()` / `"%d" % x` (one formatter, `_format_value`,
  full format-spec mini-language), str/list/dict/set methods, try/except/finally/raise, assert, list/dict/set
  comprehensions with several for/if clauses (own scope via `_scopes`), lambda, `a if c else b`, def defaults /
  `*args` / `**kwargs` / type hints, call-site `*x` / `**d`, `a = b = 0`, `a, *rest = ...`, loop `else:`,
  bit operators, `import math as m` / `from math import sqrt`, `input()` and `print(end=, sep=)`.
  Modules (`MODULES`, constants in `MODULE_CONSTS`): math, random, collections, statistics, itertools, time, string.
  `BLOCKED_MODULES` (os, sys, json, datetime, re, ...) fail with the reason. A Counter is a dict with
  `"counter": true`, a defaultdict a dict with `"factory"`, a deque `{"kind": "deque", "items", "maxlen"}`;
  itertools results are iterators. Floats print like Python (`_float_repr`, shortest round-trip digits).
  A module name is a free variable name until that module is imported (`_module_taken`).
  `parse()` first joins physical lines into logical ones (`_logical_lines`: brackets, triple quotes, trailing
  backslash), then `_add_line` splits `if x: y` and `a; b`; a node's "line" is its first physical line. Runtime errors carry an
  `etype` (`_raise(msg, etype)`); robot commands raise `COMMAND_ERRORS` (`move` -> Blocked, `pick` -> NoItem);
  "Fatal" (endless loop, runaway recursion) cannot be caught.
  The supported subset and the host API are listed at the top of the file. Host values cross over through
  `_from_host` (Vector2i -> tuple, plain Dictionary -> dict) and `_to_host`; commands with a value are in `COMMAND_ARGS`.
- Several robots: map letter `R` adds robots after `S`; `GridWorld` methods take a robot index (default 0),
  `main.gd` spawns and tints one `Robot` node per robot (`ROBOT_COLORS` ↔ `CodeInterpreter.ROBOT_NAMES`).
  Keep it real Python apart from `repeat`, and keep error messages in friendly Korean (tests match on them).
  To add a robot function: add it to `COMMANDS` (action, awaited) or `CONDITIONS`/`SENSORS` (value),
  then to `GridWorld` (sensors are read through `host.sense(name)` → `world.call(name)`) and to the palette in `main.gd`.
- `scripts/world_host.gd`: synchronous interpreter host over a GridWorld (tests + hidden-variant checks).
  The host API is listed at the top of `code_interpreter.gd`; `main.gd` and `WorldHost` must both implement it.
  `input()` asks the host (`input_line`): the level's prepared answers (`inputs`, per map `input_lists`; the
  villager replies), otherwise main.gd opens a box under the console for the player to type into.
- `scripts/levels.gd`: level maps (`#` blocked, `.` path, `S`/`R` robots, `G` goal, items `A` apple, `C` carrot, `K` corn,
  `D` door, `I` signpost, `H` horse), par, hint, reference solution. Extra keys (documented in `grid_world.gd`):
  `order`, `prices`, `report` (`count`/`price`/`receipt`/`answer`/`distance`/`gcd`/`most`/`sample`), `sign`/`password`,
  `customer`/`speech` (a template; `{in0}` is the first input() answer), `rule` (`one_each`/`nearest_first`/`shortest`:
  no more steps than the best order through all items, failure kind `route`), `horse_dir`, `inputs`. `Levels.PER_MAP` keys (`orders`,
  `signs`, `passwords`, `customers`, `mailbox_lists`, `answers`, `input_lists`) hold one value per map; always load
  a map with `Levels.for_map(level, i)`.
- Horses step after every robot command: hosts call `GridWorld.tick()` (WorldHost and `main.run_command` both do).
- `scripts/board.gd`: builds the board from `res://asset/glb/glb/*.glb`, auto-fitting each model to a footprint.
- `scripts/robot.gd`, `scripts/camera_rig.gd`, `scripts/main.gd` (controller + interpreter host).

## Villagers (quest givers)
- `scripts/dialogue.gd`: `CAST` (name, speech style, outfit) and `LEVELS[i]` (intro, hints, success) for `Levels.ALL[i]`;
  failure lines come from the speaker's style in `FAIL`. Tests check one entry per level and that outfit parts exist.
- `scripts/villager.gd`: the villager FBX has a skeleton but no animations; pose is set from code (arms down from
  the T-pose, idle sway, talk/happy/sad). Bone axes are measured at setup; bone positions are computed from local
  poses because `Skeleton3D.get_bone_global_pose` is stale before the first frame. The FBX skeleton is z-up.
- `scripts/speech_bubble.gd`: 2D bubble over the view, tail on the villager's head (`main._process`). `[code]` in
  dialogue text is colored by `SpeechBubble.format()`. The hint button walks the villager's hints, then the level's `hint`.

## UI features (main.gd)
- Chapter screen (`chapter_menu.gd`, `Levels.CHAPTERS`) opens at startup; a level unlocks when the previous one has
  a star (`_unlocked`), or with the teacher checkbox (`meta/unlock_all` in the save). Dev runs open everything
  unless `--locks` is given.
- "⏩ 빨리" (F7) runs without animation: commands go through `WorldHost._command` on `_world` (`_command_fast`).
- Stars: -1 for lines > par, -1 for lines > par + 3, -1 for more robot commands than the reference solution needs on
  that map (`_reference_steps`; levels with `seeds` are not scored on commands).
- Code completion (`_on_completion_requested`), villager click = next hint, failed hidden check re-runs itself.
- Sounds: `scripts/sfx.gd` plays `audio/sfx/*.wav`, synthesized for this project (no third-party audio).
- Sky: `shaders/sky_slavica.tres` (EmacEArt sky shader); grass tufts use `shaders/EA_GrassWind.gdshader`
  with its tint layers off (`Board._spawn_grass`).
- Tests load every script in `scripts/` (`can_instantiate`), because main.gd is not otherwise exercised headless.

## Assets
- EmacEArt license: use in games is fine, redistributing the asset files on their own is not. Keep `asset/` out of
  any public repository (private repo or .gitignore).
- Not in git (see .gitignore), copy in after cloning: `asset/` (glb pack, `characters/`, `props/` FBX taken from the
  PRO Unity package) and `shaders/EA_Skybox.gdshader`, `shaders/EA_GrassWind.gdshader`, `shaders/sky_slavica.tres`
  (from `SlavicWorldFree_Godot_*`). Then run `godot --headless --path . --import`.
- `asset/props/`: horse and road-sign FBX from the PRO package (3 LODs, no texture; `Board._fix_fbx_prop` keeps LOD0
  and applies the glb palette). Pass a full `res://` path to `Board._spawn` for these.
- `asset/characters/`: villager FBX (male, female) and palettes, extracted from the PRO Unity package. Outfits are
  mesh names toggled on/off (from the Unity prefabs). The 25 Unity `.anim` clips are not converted yet.
- Otherwise only `asset/glb/glb` is used. `asset/FBX`, `asset/Texture`, the `.blend` pack and `SlavicWorldFree_Godot_*` have `.gdignore`
  (Unity duplicates, Blender files, and Slavic prefabs that expect `res://` at the pack root).
- The pack colors everything from one 32x32 palette texture. Always run new glb instances through
  `Board.fix_palette_materials()`, or colors wash out to grey-blue (mipmap blending).

## Commands
Godot: `C:/Users/wjdgh/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- Tests (interpreter + every level's solution): `godot --headless --path . --script res://tests/run_tests.gd`
  The "More Python" section's expected outputs come from real Python: add cases to `tests/gen_python_cases.py`,
  run `python tests/gen_python_cases.py out.gd` and paste the lines into `_run_python_more()`.
- Re-import after adding assets or `class_name` scripts: `godot --headless --path . --import`
- Screenshot / smoke run: `godot --path . -- --level=5 --solve --shot=<abs path>.png`
  Other flags: `--map=K` (hidden variant), `--code=<src with \n>`, `--step=N` (step mode, N presses),
  `--answer=A` (types A when input() asks the player; without it the run stops at the input box for the shot).
  Any dev flag turns off saving, so `user://progress.cfg` is never touched.
- `project.godot` was once overwritten with stale settings (no `run/main_scene`), most likely by a Godot editor
  that had been open since before the settings changed. Close the editor before editing `project.godot` by hand.

## Adding a level
`Levels.ALL` is append-only: progress (stars, code) is saved by index. Add new levels at the END of ALL
(and of `Dialogue.LEVELS`), then put the index where it belongs in `Levels.CHAPTERS`; the number players see
(`Levels.number`/`title`) and Prev/Next/unlock order come from CHAPTERS. Titles carry no number. Append to `Levels.ALL` with a `solution`, then run the tests: they check that the solution solves the level
(and every map in `variants`) within `par` lines. Add `variants` to levels that teach `if`/`while`/variables, so a
hard-coded move list fails on a hidden map. Use `banned` (e.g. `["at_goal"]`) when a level must force counting or
math; banned names fail at parse time and are hidden from the palette. `tools` picks palette groups (`PALETTE` in `main.gd`).
`required` (`random`, `class`, `inherit`) makes the lesson's feature mandatory. Levels using random need `seeds`:
every map is checked with seed 1 (the visible run) plus those seeds, and the tests run the solution on all of them.
Chapters: 1-3 sequence, 4-5 repeat, 6-8 conditions, 9-10 variables, 11-12 functions, 13-14 math, 15-16 lists,
17-18 random, 19 robot objects, 20-21 classes and inheritance, 22-23 tuples, 24-27 dictionaries,
28-29 strings (slicing, f-strings), 30 sets, 31-32 exceptions, then (display numbers) 35-37 input and formatting,
38-39 builtins (ord/chr, map/filter), 42-46 modules (gcd, Counter, deque, statistics, permutations);
math.hypot is level 15 and random.sample level 21. `required` also takes `dict`, `try`, `comprehension`, `lambda`, `input`.
When writing level text from a shell heredoc, check that `\n` inside GDScript strings stayed escaped.

## Tooling
- MCP `godot` (@coding-solo/godot-mcp, project scope in `.mcp.json`). Keep `GODOT_PATH` with forward slashes; backslashes get stripped.
  Not local scope: VS Code opens the folder as `d:\...` but local scope is keyed by `D:/...`, so the server never loads there.
- Only `godot-interactive` loads from the skills plugin; the other 4 `SKILL.md` files have no YAML frontmatter.
- Skills plugin `godot-claude-skills` is enabled in `.claude/settings.json`. Its `godot-interactive` / `godot-live-edit`
  skills name tools from a different MCP (alexmeckes/godot-mcp, `godot_editor_*`); with coding-solo use
  `run_project`, `get_debug_output`, `stop_project`, `create_scene`, `add_node`, `save_scene` instead.
