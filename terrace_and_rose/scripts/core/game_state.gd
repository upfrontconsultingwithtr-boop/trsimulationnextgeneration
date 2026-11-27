class_name GameState
extends RefCounted
## Plain-data world state. Everything here is JSON-safe integers/strings/arrays/dicts so saves are exact.
## Money: integer cents. Time: integer minutes (+ sub-minute ticks). Needs: 0..10000 (hundredths of a percent).

const VERSION := 2
const TICKS_PER_MINUTE := 4
const NEED_KEYS := ["hunger", "energy", "social", "comfort"]
const NEED_MAX := 10000
const START_MINUTE := 8 * 60

## Approved avatar presets (Part 1). All share one rig; bodies/hair/outfits are variants in the GLB.
const PRESETS := {
	"mara": {"name": "Mara", "pronouns": "she/her", "age": "adult",
		"blurb": "Warm, unhurried, and always cooking for one more. Natural coils, gold earrings, terracotta jumpsuit.",
		"look": {"frame": "f", "morphs": {"african": 0.9, "heavy": 0.6, "bust": 0.6, "older": 0.45}, "body": "curvy", "hair": "coils", "outfit": "jumpsuit", "accessories": ["earrings"],
			"skin": "8a5537", "hair_color": "1d1611", "top": "c2643f", "bottom": "c2643f", "outer": "c2643f", "knit": "c2643f", "shoe": "5b3b27"}},
	"jin": {"name": "Jin", "pronouns": "he/him", "age": "adult",
		"blurb": "Quiet designer with a dry sense of humour. Wavy dark hair, sea-glass jacket, relaxed trousers.",
		"look": {"frame": "m", "morphs": {"asian": 0.9, "slim": 0.45}, "body": "slender", "hair": "wavy", "outfit": "jacket", "accessories": [],
			"skin": "e2bb93", "hair_color": "17120f", "top": "86bdb2", "bottom": "c9bba0", "outer": "86bdb2", "knit": "86bdb2", "shoe": "3a3532"}},
	"ellis": {"name": "Ellis", "pronouns": "he/him", "age": "elder",
		"blurb": "Retired boat-builder who knows everyone's story. Silver curls, short beard, cream knit, brown jacket.",
		"look": {"frame": "m", "morphs": {"african": 0.9, "older": 0.35, "slim": 0.15}, "body": "classic", "hair": "curls_short", "outfit": "knit_jacket", "accessories": ["beard"],
			"skin": "4b2d1e", "hair_color": "cfcac2", "top": "ede4d1", "bottom": "4d4842", "outer": "6e4b31", "knit": "ede4d1", "shoe": "2f2520"}},
}
const PRESET_ORDER := ["mara", "jin", "ellis"]

static func new_character(id: String, preset: String, household: String, lot: String, cell: Vector2i) -> Dictionary:
	var p: Dictionary = PRESETS[preset]
	var c := make_character(id, p["name"], p["look"].duplicate(true), p["age"], p["pronouns"], household, lot, cell, [], "")
	c["preset"] = preset
	return c

static func make_character(id: String, name: String, look: Dictionary, age: String, pronouns: String, household: String, lot: String, cell: Vector2i, traits: Array, aspiration: String) -> Dictionary:
	return {"id": id, "name": name, "preset": "", "pronouns": pronouns, "age": age, "look": look, "traits": traits, "aspiration": aspiration,
		"household": household, "lot": lot, "cell": [cell.x, cell.y], "facing": 0, "pose": "stand", "anim": "idle",
		"anchor": [], "holding": "", "queue": [], "current": {}, "react_until": 0, "ai": "player", "ai_next": 0,
		"needs": {"hunger": 7000, "energy": 8000, "social": 5500, "comfort": 6500}}

## Upgrade older saves in place. v1 (Milestone 1) -> v2 (neighborhood-ready). Never drops data.
static func migrate(s: Dictionary) -> Dictionary:
	if int(s.get("version", 0)) == 1:
		s["world"] = "alder"
		s["family"] = []
		s["settings"] = {"inactive_progress": true, "aging": false}
		s["story"] = {"flags": {}, "fired": {}, "pending": [], "log": []}
		for cid in s.get("characters", {}):
			var c: Dictionary = s["characters"][cid]
			if not c.has("traits"): c["traits"] = []
			if not c.has("aspiration"): c["aspiration"] = ""
		s["version"] = 2
	return s

## Milestone-1 scenario: one controlled adult at Alder Bungalow, a neighbor who visits at 10:00 on day 1.
static func new_alder_game(preset: String) -> Dictionary:
	var neighbor := "ellis" if preset != "ellis" else "mara"
	var s := {
		"version": VERSION, "world": "alder", "family": [], "settings": {"inactive_progress": true, "aging": false},
		"story": {"flags": {}, "fired": {}, "pending": [], "log": []}, "minute": START_MINUTE, "subtick": 0, "speed": 1, "next_id": 1,
		"active_household": "h1", "active_lot": "lot1", "controlled": "c1",
		"households": {"h1": {"id": "h1", "name": "Alder Household", "funds": 60000, "members": ["c1"], "lot": "lot1"},
			"h2": {"id": "h2", "name": "Down the Lane", "funds": 120000, "members": ["c2"], "lot": ""}},
		"lots": {"lot1": {"id": "lot1", "layout": "alder_bungalow", "household": "h1", "furniture": {}}},
		"characters": {}, "relationships": {}, "reservations": {}, "stats": {"arrivals": {}},
		"schedule": [
			{"id": "neighbor_arrives", "at": 10 * 60, "kind": "visitor_arrive", "who": "c2", "lot": "lot1", "fired": false},
			{"id": "neighbor_leaves", "at": 15 * 60, "kind": "visitor_leave", "who": "c2", "lot": "lot1", "fired": false}],
	}
	s["characters"]["c1"] = new_character("c1", preset, "h1", "lot1", Vector2i(16, 22))
	var n := new_character("c2", neighbor, "h2", "", Vector2i(15, 31))
	n["ai"] = "visitor"
	s["characters"]["c2"] = n
	s["next_id"] = 3
	var lay := LotLayouts.layout("alder_bungalow")
	for f in lay["furniture"]:
		var fid := "f%d" % s["next_id"]
		s["next_id"] += 1
		s["lots"]["lot1"]["furniture"][fid] = {"id": fid, "item": f[0], "cell": [f[1], f[2]], "rot": f[3]}
	return s

static func new_id(s: Dictionary, prefix: String) -> String:
	var id := "%s%d" % [prefix, int(s["next_id"])]
	s["next_id"] = int(s["next_id"]) + 1
	return id

static func cell_of(a: Variant) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))

static func rel_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func hour_text(minute: int) -> String:
	return "Day %d · %02d:%02d" % [minute / 1440 + 1, (minute / 60) % 24, minute % 60]

## JSON parses numbers as floats; our state only stores integers, so convert back.
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, roundf(v)) else v
		TYPE_ARRAY:
			var a: Array = []
			for x in v: a.append(normalize(x))
			return a
		TYPE_DICTIONARY:
			var d := {}
			for k in v: d[k] = normalize(v[k])
			return d
	return v

static func checksum(s: Dictionary) -> String:
	# normalise first so whole-number floats (1.0) and ints (1) hash identically before and after a JSON round trip
	return JSON.stringify(normalize(s), "", true).sha256_text()

## Structural validation; returns a list of problems (empty = valid).
static func validate(s: Variant) -> Array[String]:
	var e: Array[String] = []
	if typeof(s) != TYPE_DICTIONARY:
		return ["state is not an object"]
	for k in ["version", "minute", "subtick", "speed", "next_id", "active_household", "active_lot", "controlled", "households", "lots", "characters", "relationships", "reservations", "schedule", "story", "settings", "family"]:
		if not s.has(k): e.append("missing key: " + k)
	if not e.is_empty(): return e
	if int(s["version"]) != VERSION: e.append("unsupported version %s" % s["version"])
	for k in ["minute", "subtick", "speed", "next_id"]:
		if typeof(s[k]) != TYPE_INT or int(s[k]) < 0: e.append("bad integer: " + k)
	for hid in s["households"]:
		var h: Dictionary = s["households"][hid]
		if typeof(h.get("funds")) != TYPE_INT: e.append("household %s funds not integer cents" % hid)
		for m in h.get("members", []):
			if not s["characters"].has(m): e.append("household %s member %s missing" % [hid, m])
	if not s["households"].has(s["active_household"]): e.append("active household missing")
	if not s["characters"].has(s["controlled"]): e.append("controlled character missing")
	for lid in s["lots"]:
		var lot: Dictionary = s["lots"][lid]
		if LotLayouts.layout(String(lot.get("layout", ""))).is_empty(): e.append("lot %s unknown layout" % lid)
		var edits: Variant = lot.get("structure", {})
		if not edits is Dictionary:
			e.append("lot %s structure must be an object" % lid)
		else:
			for key in edits:
				var parts := String(key).split(",")
				if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
					e.append("lot %s has an invalid structure cell" % lid)
					continue
				var cell := Vector2i(parts[0].to_int(), parts[1].to_int())
				if key != LotLayouts.cell_key(cell) or not Rect2i(0, 0, LotLayouts.SIZE, LotLayouts.SIZE).has_point(cell) or edits[key] not in [" ", ".", "#", "D", "W", "t"]:
					e.append("lot %s has an invalid structure edit" % lid)
		for fid in lot.get("furniture", {}):
			var f: Dictionary = lot["furniture"][fid]
			if not Catalog.has(String(f.get("item", ""))): e.append("unknown item in %s" % fid)
			var c: Array = f.get("cell", [])
			if c.size() != 2 or int(c[0]) < 0 or int(c[1]) < 0 or int(c[0]) >= LotLayouts.SIZE or int(c[1]) >= LotLayouts.SIZE: e.append("furniture %s out of bounds" % fid)
	for cid in s["characters"]:
		var ch: Dictionary = s["characters"][cid]
		if not PRESETS.has(String(ch.get("preset", ""))) and not ch.has("look"): e.append("character %s has no look" % cid)
		for n in NEED_KEYS:
			var v: Variant = ch.get("needs", {}).get(n)
			if typeof(v) != TYPE_INT or int(v) < 0 or int(v) > NEED_MAX: e.append("character %s need %s invalid" % [cid, n])
	if e.is_empty(): e.append_array(HarborTrip.validate(s))
	return e
