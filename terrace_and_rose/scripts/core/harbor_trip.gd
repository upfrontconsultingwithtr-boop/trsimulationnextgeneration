class_name HarborTrip
extends RefCounted
## Brineglass bookings and memories live in the same save as the traveling household.

const LOT := "lot_brineglass"
const LAYOUT := "brineglass_harbor"
const NAME := "Brineglass Harbor"
const BASE_PRICE := 14500
const GUEST_PRICE := 1500
const ARRIVAL := Vector2i(20, 24)
const SPOTS := {
	"shell": {"cell": Vector2i(7, 8), "place": "North dune", "find": "Ribbed cockle shell"},
	"glass": {"cell": Vector2i(6, 17), "place": "Low-tide bend", "find": "Sea-green glass"},
	"stone": {"cell": Vector2i(8, 26), "place": "South beach", "find": "Striped worry stone"},
}

static func is_away(s: Dictionary) -> bool:
	return s["active_lot"] == LOT

static func quote(s: Dictionary) -> int:
	return BASE_PRICE + GUEST_PRICE * s["households"][s["active_household"]]["members"].size()

static func add_lodge(s: Dictionary) -> void:
	if s["lots"].has(LOT):
		return
	var furniture := {}
	for entry in LotLayouts.layout(LAYOUT)["furniture"]:
		var id := GameState.new_id(s, "f")
		furniture[id] = {"id": id, "item": entry[0], "cell": [entry[1], entry[2]], "rot": entry[3]}
	s["lots"][LOT] = {"id": LOT, "layout": LAYOUT, "household": "", "furniture": furniture}

static func memories(s: Dictionary) -> Array:
	return s["households"][s["active_household"]].get("travel_memories", [])

static func record_visit(s: Dictionary) -> void:
	var stay: Dictionary = s["harbor_stay"]
	var household: Dictionary = s["households"][stay["household"]]
	var journal: Array = household.get_or_add("travel_memories", [])
	journal.append({
		"destination": NAME,
		"departed": stay["departed"],
		"returned": s["minute"],
		"finds": stay["finds"].duplicate(),
	})

static func validate(s: Dictionary) -> Array[String]:
	if not s.has("harbor_stay"):
		if is_away(s):
			return ["harbor lot selected without a booking"]
		return []
	var stay: Variant = s["harbor_stay"]
	if not stay is Dictionary or not is_away(s):
		return ["invalid active harbor booking"]
	if stay.get("household") != s["active_household"] or not s["lots"].has(LOT):
		return ["harbor booking household or lot is missing"]
	var home: Variant = stay.get("home")
	if home == LOT or not s["lots"].has(home):
		return ["harbor booking home lot is missing"]
	if not stay.get("departed") is int or not stay.get("home_cells") is Dictionary or not stay.get("finds") is Array:
		return ["invalid harbor booking details"]
	for cell in stay["home_cells"].values():
		if not cell is Array or cell.size() != 2 or not cell[0] is int or not cell[1] is int:
			return ["invalid harbor booking return cell"]
	for spot in stay["finds"]:
		if not SPOTS.has(spot):
			return ["invalid harbor beachcombing find"]
	return []
