class_name LotLayouts
extends RefCounted
## Lot maps on a 0.5 m grid (32×32 cells = 16×16 m). Legend:
##   ' ' lawn   '=' stone path   '.' walnut floor   't' terracotta porch tile   'g' garden bed (blocked)
##   '#' stucco wall   'D' door   'W' window   'A' porch arch column (blocked)   'G' gate / arrival point
## Pendants and starter furniture are listed per lot. Editing these strings is the lot editor of M1.

const SIZE := 32

const LAYOUTS := {
	"alder_bungalow": {
		"name": "Alder Bungalow",
		"rows": [
			"                                ",
			"      g  g  g  g  g  g  g       ",
			"                                ",
			"    ####WW###########WW#####    ",
			"    #........#.............#    ",
			"    #........#.............#    ",
			"    #........#.............#    ",
			"    W........#.............W    ",
			"    W........D.............W    ",
			"    #........D.............#    ",
			"    #........#.............#    ",
			"    #........#.............#    ",
			"    ##########.............#    ",
			"    #......................#    ",
			"    #......................#    ",
			"    W......................#    ",
			"    W......................#    ",
			"    #......................#    ",
			"    #......................#    ",
			"    #......................#    ",
			"    ####WW#####DD####WW#####    ",
			"         tttttttttttttt         ",
			"         tttttttttttttt         ",
			"         tttttttttttttt         ",
			"  gggggg tttttttttttttt gggggg  ",
			"  gggggg tttttttttttttt gggggg  ",
			"         AttAtAttAtAttA         ",
			"               ==               ",
			"               ==               ",
			"               ==               ",
			"               ==               ",
			"               GG               ",
		],
		"rooms": {"Bedroom": [5, 4, 12, 11], "Kitchen": [14, 4, 26, 11], "Living Area": [5, 13, 26, 19], "Garden Porch": [9, 21, 22, 26]},
		"pendants": [[17.0, 7.0], [22.0, 7.0], [10.0, 16.5], [20.0, 16.5], [9.0, 8.0], [16.0, 23.5]],
		"furniture": [
			["prep_counter", 16, 4, 0], ["prep_counter", 18, 4, 0], ["prep_counter", 20, 4, 0], ["shelf", 24, 4, 0],
			["table", 18, 8, 0], ["chair", 17, 8, 3], ["chair", 20, 9, 1],
			["bed", 6, 5, 0], ["lamp", 11, 4, 0], ["plant", 5, 11, 0], ["shelf", 6, 13, 0],
			["rug", 9, 15, 0], ["chair", 9, 14, 0], ["chair", 12, 14, 0], ["table", 10, 18, 0], ["lamp", 5, 18, 0],
			["plant", 26, 19, 0], ["plant", 26, 13, 0],
			["chair", 11, 22, 0], ["chair", 20, 22, 0], ["plant", 9, 21, 0], ["plant", 22, 21, 0],
		],
	},
}

static func layout(id: String) -> Dictionary:
	return LAYOUTS.get(id, {})

static func tile(id: String, c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= SIZE or c.y >= SIZE:
		return "X"
	var rows: Array = LAYOUTS[id]["rows"]
	return String(rows[c.y])[c.x]

static func is_structural_block(t: String) -> bool:
	return t == "#" or t == "W" or t == "A" or t == "g" or t == "X"

static func is_indoor(t: String) -> bool:
	return t == "."

static func cells_of(id: String, ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows: Array = LAYOUTS[id]["rows"]
	for y in rows.size():
		for x in String(rows[y]).length():
			if String(rows[y])[x] == ch:
				out.append(Vector2i(x, y))
	return out

## Cells that furniture may never cover: doors, their thresholds, and the arrival gate.
static func keep_clear(id: String) -> Dictionary:
	var out := {}
	for d in cells_of(id, "D") + cells_of(id, "G"):
		out[d] = true
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			out[d + n] = true
	return out
