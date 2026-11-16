class_name ProgressExport
extends RefCounted
## Turns a player's progress into a CSV table a teacher can open in a spreadsheet:
## one row per level in play order, then a total row. See main._on_export_requested.

const HEADER: PackedStringArray = [
	"번호", "챕터", "레벨", "별", "클리어", "둘째 별 조건", "둘째 별", "셋째 별 조건", "셋째 별",
	"코드 줄 수", "목표 줄 수", "코드",
]
## Excel reads a UTF-8 file as Korean only when it starts with this mark.
const BOM: String = "﻿"


## masks[i]: star mask of Levels.ALL[i] (bit per Levels.star_goals entry). codes[i]: the saved code
## of that level ("" when the player has not written any).
static func csv(masks: Array, codes: Array) -> String:
	var rows: PackedStringArray = [_row(HEADER)]
	var total := 0
	for i in Levels.order():
		var level: Dictionary = Levels.ALL[i]
		var mask := int(masks[i])
		var code := String(codes[i])
		var goals := Levels.star_goals(level, 0, WorldHost.reference_steps(level, 0))
		total += Levels.star_count(mask)
		rows.append(_row([
			str(Levels.number(i)), Levels.CHAPTERS[Levels.chapter_of(i)]["title"], level["title"],
			str(Levels.star_count(mask)), _mark(mask, 0),
			Levels.star_text(goals[1]), _mark(mask, 1), Levels.star_text(goals[2]), _mark(mask, 2),
			str(CodeInterpreter.count_code_lines(code)) if code != "" else "", str(level["par"]), code,
		]))
	rows.append(_row(["", "", "합계", "%d / %d" % [total, Levels.ALL.size() * 3]]))
	return BOM + "\r\n".join(rows) + "\r\n"


## Writes the table to `path`. Returns "" or what went wrong.
static func save(path: String, masks: Array, codes: Array) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "파일을 쓸 수 없어요 (오류 %d): %s" % [FileAccess.get_open_error(), path]
	file.store_string(csv(masks, codes))
	file.close()
	return ""


static func _mark(mask: int, bit: int) -> String:
	return "O" if mask & (1 << bit) else ""


## One CSV line: every field quoted, so commas, quotes and line breaks in code stay in their cell.
## A field starting with = + - @ gets a leading ' so a spreadsheet shows it instead of running it.
static func _row(fields: Array) -> String:
	var out: PackedStringArray = []
	for field in fields:
		var text := String(field)
		if text != "" and text[0] in ["=", "+", "-", "@"]:
			text = "'" + text
		out.append("\"" + text.replace("\"", "\"\"") + "\"")
	return ",".join(out)
