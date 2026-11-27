class_name Catalog
extends RefCounted
## Static furniture catalog. Cells are 0.5 m. At rotation 0 an item's front faces +Z (toward the street).
## slots: interaction slots; approach = candidate cells (local, rot 0) where the actor stands; anchor = local point (cells)
## used for seated/lying poses; face = facing offset (0 front, 2 back) relative to the item.

const CELL := 0.5

const ITEMS := {
	"chair": {"name": "Walnut Chair", "price": 3500, "size": [1, 1], "layer": "object", "height": 0.9,
		"model": "res://assets/models/furniture/chair.glb", "actions": ["sit", "eat"],
		"slots": [{"approach": [[0, 1], [-1, 0], [1, 0]], "anchor": [0.5, 0.45], "face": 0, "pose": "sit"}]},
	"table": {"name": "Walnut Table", "price": 9000, "size": [2, 2], "layer": "object", "height": 0.76,
		"model": "res://assets/models/furniture/table.glb", "actions": [], "slots": []},
	"bed": {"name": "Linen Double Bed", "price": 25000, "size": [4, 4], "layer": "object", "height": 0.6,
		"model": "res://assets/models/furniture/bed.glb", "actions": ["sleep"],
		"slots": [{"approach": [[-1, 2], [-1, 1]], "anchor": [1.0, 2.2], "face": 0, "pose": "lie"},
			{"approach": [[4, 2], [4, 1]], "anchor": [3.0, 2.2], "face": 0, "pose": "lie"}]},
	"prep_counter": {"name": "Teal Prep Counter", "price": 18000, "size": [2, 1], "layer": "object", "height": 0.92,
		"model": "res://assets/models/furniture/prep_counter.glb", "actions": ["prepare_meal"],
		"slots": [{"approach": [[0, 1]], "face": 2, "pose": "stand"}, {"approach": [[1, 1]], "face": 2, "pose": "stand"}]},
	"lamp": {"name": "Brass Floor Lamp", "price": 4500, "size": [1, 1], "layer": "object", "height": 1.6,
		"model": "res://assets/models/furniture/lamp.glb", "actions": [], "slots": [], "light": true},
	"rug": {"name": "Tide Rug", "price": 6000, "size": [4, 3], "layer": "floor", "height": 0.02,
		"model": "res://assets/models/furniture/rug.glb", "actions": [], "slots": []},
	"plant": {"name": "Potted Fig", "price": 2500, "size": [1, 1], "layer": "object", "height": 1.0,
		"model": "res://assets/models/furniture/plant.glb", "actions": [], "slots": []},
	"shelf": {"name": "Walnut Shelf", "price": 7000, "size": [2, 1], "layer": "object", "height": 1.8,
		"model": "res://assets/models/furniture/shelf.glb", "actions": [], "slots": []},
	"register": {"name": "Shop Register", "price": 40000, "size": [2, 1], "layer": "object", "height": 1.1,
		"model": "res://assets/models/furniture/register.glb", "actions": ["work_register", "order"],
		"slots": [{"approach": [[0, -1], [1, -1]], "face": 0, "pose": "stand", "role": "staff"},
			{"approach": [[0, 1], [1, 1]], "face": 2, "pose": "stand", "role": "customer"}]},
	"display_case": {"name": "Bakery Display Case", "price": 30000, "size": [2, 1], "layer": "object", "height": 1.2,
		"model": "res://assets/models/furniture/display_case.glb", "actions": [], "slots": []},
	"flower_stand": {"name": "Flower Stand", "price": 15000, "size": [2, 1], "layer": "object", "height": 0.9,
		"model": "res://assets/models/furniture/flower_stand.glb", "actions": [], "slots": []},
}

const ORDER := ["chair", "table", "bed", "prep_counter", "lamp", "rug", "plant", "shelf", "register", "display_case", "flower_stand"]

static func has(item: String) -> bool:
	return ITEMS.has(item)

static func get_def(item: String) -> Dictionary:
	return ITEMS.get(item, {})

static func footprint_size(item: String, rot: int) -> Vector2i:
	var s: Array = ITEMS[item]["size"]
	return Vector2i(s[1], s[0]) if rot % 2 == 1 else Vector2i(s[0], s[1])

## Rotate a local point (in cells, rot-0 frame of a w×h footprint) into the rotated footprint frame.
static func rotate_point(p: Vector2, size: Vector2i, rot: int) -> Vector2:
	var w := float(size.x)
	var h := float(size.y)
	match rot % 4:
		1: return Vector2(h - p.y, p.x)
		2: return Vector2(w - p.x, h - p.y)
		3: return Vector2(p.y, w - p.x)
	return p

static func local_cell_to_world(item: String, origin: Vector2i, rot: int, local: Array) -> Vector2i:
	var s: Array = ITEMS[item]["size"]
	var p := rotate_point(Vector2(local[0] + 0.5, local[1] + 0.5), Vector2i(s[0], s[1]), rot)
	return origin + Vector2i(floori(p.x), floori(p.y))

static func local_point_to_world(item: String, origin: Vector2i, rot: int, local: Array) -> Vector2:
	var s: Array = ITEMS[item]["size"]
	return Vector2(origin) + rotate_point(Vector2(local[0], local[1]), Vector2i(s[0], s[1]), rot)

static func cells(item: String, origin: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var fs := footprint_size(item, rot)
	for x in fs.x:
		for y in fs.y:
			out.append(origin + Vector2i(x, y))
	return out

## Facing index: 0 +Z, 1 -X, 2 -Z, 3 +X. Item rotation r turns its front by r steps.
static func facing_dir(face: int) -> Vector2:
	match posmod(face, 4):
		1: return Vector2(-1, 0)
		2: return Vector2(0, -1)
		3: return Vector2(1, 0)
	return Vector2(0, 1)

static func format_cents(cents: int) -> String:
	var sign := "-" if cents < 0 else ""
	var a := absi(cents)
	return "%s%d.%02d" % [sign, a / 100, a % 100]
