class_name FamilyLife
extends RefCounted
## Household creation and editing, family ties, adoption, "Try for Baby" (off-screen, fade to black),
## pregnancy, birth with genetics from both parents, and optional aging. Pure state functions.

const AGES := ["child", "teen", "adult", "elder"]
const AGE_UP_DAYS := {"child": 7, "teen": 7, "adult": 28}   # demo-length life stages; toggle with settings.aging
const PREGNANCY_DAYS := 3
const ADOPTION_FEE := 100000
const NEW_HOUSEHOLD_FUNDS := 300000
const TIE_TYPES := ["parent_of", "spouse", "partner", "sibling", "friend", "roommate"]
const TRAITS := ["warm", "ambitious", "creative", "shy", "loyal", "witty", "romantic", "goofy", "planner", "bold", "stubborn", "curious", "outdoorsy", "perfectionist", "independent", "traditional"]
const ASPIRATIONS := ["Grow the Family Business", "Close-Knit Family", "Master Painter", "See the World", "Bloom into Business", "A Quiet Retirement", "Find My Crew", "Town Legend"]

static func default_look() -> Dictionary:
	return {"body": "classic", "hair": "wavy", "hair_color": "2a1d16", "outfit": "casual", "accessories": [], "skin": "b57b54",
		"top": "86bdb2", "bottom": "4d4842", "outer": "6e4b31", "knit": "ede4d1", "shoe": "3a3532"}

static func new_household(s: Dictionary, name: String) -> String:
	var hid := GameState.new_id(s, "h")
	s["households"][hid] = {"id": hid, "name": name if name.strip_edges() != "" else "New Household", "funds": NEW_HOUSEHOLD_FUNDS, "members": [], "lot": "", "premade": false}
	return hid

## spec: {name, pronouns, age, look, traits, aspiration, can_carry}
static func add_member(s: Dictionary, hid: String, spec: Dictionary) -> String:
	var cid := GameState.new_id(s, "c")
	var look := default_look(); look.merge(spec.get("look", {}), true)
	var c := GameState.make_character(cid, String(spec.get("name", "New Person")), look, String(spec.get("age", "adult")),
		String(spec.get("pronouns", "they/them")), hid, String(s["households"][hid]["lot"]), Vector2i(15, 30), spec.get("traits", []), String(spec.get("aspiration", "")))
	c["can_carry"] = bool(spec.get("can_carry", false))
	c["ai"] = "auto"
	c["age_days"] = 0
	if spec.has("genes"): c["genes"] = spec["genes"]
	s["characters"][cid] = c
	s["households"][hid]["members"].append(cid)
	return cid

static func edit_member(s: Dictionary, cid: String, spec: Dictionary) -> void:
	var c: Dictionary = s["characters"][cid]
	for k in ["name", "pronouns", "age", "traits", "aspiration", "can_carry"]:
		if spec.has(k): c[k] = spec[k]
	if spec.has("look"): c["look"].merge(spec["look"], true)

static func remove_member(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["characters"][cid]
	s["households"][c["household"]]["members"].erase(cid)
	s["characters"].erase(cid)
	s["family"] = s["family"].filter(func(t): return t["a"] != cid and t["b"] != cid)
	for k in s["relationships"].keys():
		if String(k).split("|").has(cid): s["relationships"].erase(k)

static func set_tie(s: Dictionary, a: String, b: String, type: String) -> Dictionary:
	if a == b or not s["characters"].has(a) or not s["characters"].has(b): return {"ok": false, "reason": "Pick two different people."}
	if not TIE_TYPES.has(type): return {"ok": false, "reason": "Unknown relationship."}
	var ca: Dictionary = s["characters"][a]; var cb: Dictionary = s["characters"][b]
	if type in ["spouse", "partner"] and (not _is_adult(ca) or not _is_adult(cb)):
		return {"ok": false, "reason": "Only adults can be partners or spouses."}
	if type == "parent_of" and AGES.find(ca["age"]) <= AGES.find(cb["age"]) and not (_is_adult(ca) and not _is_adult(cb)):
		return {"ok": false, "reason": "A parent must be older than their child."}
	s["family"] = s["family"].filter(func(t): return not ((t["a"] == a and t["b"] == b) or (t["a"] == b and t["b"] == a)))
	s["family"].append({"a": a, "b": b, "type": type})
	var k := GameState.rel_key(a, b)
	var rel: Dictionary = s["relationships"].get(k, {"friendship": 0, "romance": 0, "met": true})
	rel["friendship"] = maxi(int(rel["friendship"]), 40 if type != "friend" else 30)
	if type in ["spouse", "partner"]: rel["romance"] = maxi(int(rel.get("romance", 0)), 60)
	s["relationships"][k] = rel
	return {"ok": true, "reason": ""}

static func _is_adult(c: Dictionary) -> bool:
	return c["age"] == "adult" or c["age"] == "elder"

static func validate_household(s: Dictionary, hid: String) -> Array[String]:
	var e: Array[String] = []
	var m: Array = s["households"][hid]["members"]
	if m.is_empty(): e.append("Add at least one person.")
	if m.size() > 8: e.append("A household can have at most 8 people.")
	if not m.any(func(cid): return _is_adult(s["characters"][cid])): e.append("Every household needs at least one adult.")
	return e

static func move_in(s: Dictionary, hid: String, lid: String) -> Dictionary:
	var lot: Dictionary = s["lots"].get(lid, {})
	if lot.is_empty(): return {"ok": false, "reason": "No such lot."}
	if String(lot["household"]) != "" and lot["household"] != hid: return {"ok": false, "reason": "Someone already lives there."}
	var errs := validate_household(s, hid)
	if not errs.is_empty(): return {"ok": false, "reason": errs[0]}
	lot["household"] = hid
	s["households"][hid]["lot"] = lid
	var gates := LotLayouts.cells_of(lot["layout"], "G")
	var i := 0
	for cid in s["households"][hid]["members"]:
		var c: Dictionary = s["characters"][cid]
		c["lot"] = lid; c["cell"] = [gates[0].x - 2 + i % 5, gates[0].y - 2 - i / 5]; i += 1
	return {"ok": true, "reason": ""}

## Genetics-backed child spec from two characters (creator button and births share this).
static func child_spec(s: Dictionary, a: String, b: String, seed: int, name: String = "") -> Dictionary:
	var g := Genetics.make_child(s["characters"][a], s["characters"][b], seed)
	var rng := RandomNumberGenerator.new(); rng.seed = seed + 7
	var surname: String = String(s["characters"][a]["name"]).get_slice(" ", 1)
	var first: String = ["Rosa", "Milo", "Ada", "Kai", "Iris", "Leo", "Nia", "Ezra", "Juno", "Theo", "Lark", "Sage"][rng.randi() % 12]
	return {"name": name if name != "" else (first + (" " + surname if surname != "" else "")), "pronouns": ["she/her", "he/him", "they/them"][rng.randi() % 3],
		"age": "child", "look": g["look"], "traits": g["traits"], "aspiration": "", "can_carry": false, "genes": g["genes"]}

static func add_child_from_parents(s: Dictionary, a: String, b: String, seed: int, name: String = "") -> String:
	var hid: String = s["characters"][a]["household"]
	var cid := add_member(s, hid, child_spec(s, a, b, seed, name))
	_link_child(s, cid, [a, b])
	return cid

static func _link_child(s: Dictionary, cid: String, parents: Array) -> void:
	for p in parents: set_tie(s, p, cid, "parent_of")
	for t in s["family"].duplicate():
		if t["type"] == "parent_of" and parents.has(t["a"]) and t["b"] != cid: set_tie(s, t["b"], cid, "sibling")

static func adopt(s: Dictionary, hid: String, seed: int) -> Dictionary:
	if int(s["households"][hid]["funds"]) < ADOPTION_FEE: return {"ok": false, "reason": "Adoption fees are %s." % Catalog.format_cents(ADOPTION_FEE)}
	var adults: Array = s["households"][hid]["members"].filter(func(cid): return _is_adult(s["characters"][cid]))
	if adults.is_empty(): return {"ok": false, "reason": "Only adults can adopt."}
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var donor_a := {"look": Genetics.random_look(rng), "traits": [FamilyLife.TRAITS[rng.randi() % TRAITS.size()]]}
	var donor_b := {"look": Genetics.random_look(rng), "traits": [FamilyLife.TRAITS[rng.randi() % TRAITS.size()]]}
	var g := Genetics.make_child(donor_a, donor_b, seed)
	s["households"][hid]["funds"] = int(s["households"][hid]["funds"]) - ADOPTION_FEE
	var surname: String = String(s["characters"][adults[0]]["name"]).get_slice(" ", 1)
	var cid := add_member(s, hid, {"name": "Robin " + surname, "pronouns": "they/them", "age": "child", "look": g["look"], "traits": g["traits"]})
	s["characters"][cid]["adopted"] = true
	_link_child(s, cid, adults.slice(0, 2))
	return {"ok": true, "reason": "", "id": cid}

## Who can Try for Baby: two adults in a romantic relationship, one of whom can carry and isn't already pregnant.
static func baby_eligibility(s: Dictionary, a: String, b: String) -> Dictionary:
	var ca: Dictionary = s["characters"].get(a, {}); var cb: Dictionary = s["characters"].get(b, {})
	if ca.is_empty() or cb.is_empty() or a == b: return {"ok": false, "reason": "Choose a partner."}
	if ca["age"] != "adult" or cb["age"] != "adult": return {"ok": false, "reason": "Only adults can try for a baby."}
	var rel: Dictionary = s["relationships"].get(GameState.rel_key(a, b), {})
	var committed: bool = s["family"].any(func(t): return t["type"] in ["spouse", "partner"] and ((t["a"] == a and t["b"] == b) or (t["a"] == b and t["b"] == a)))
	if not committed and int(rel.get("romance", 0)) < 50: return {"ok": false, "reason": "They need a romantic relationship first."}
	if not (bool(ca.get("can_carry", false)) or bool(cb.get("can_carry", false))): return {"ok": false, "reason": "Neither partner can carry a pregnancy — consider adoption."}
	for p in s.get("pregnancies", []):
		if p["carrier"] == a or p["carrier"] == b: return {"ok": false, "reason": "Already expecting!"}
	return {"ok": true, "reason": ""}

## Called when a Try for Baby moment completes (off-screen). Seeded chance of pregnancy.
static func conceive(s: Dictionary, a: String, b: String, seed: int) -> Dictionary:
	var el := baby_eligibility(s, a, b)
	if not el["ok"]: return {"ok": false, "pregnant": false, "reason": el["reason"]}
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var k := GameState.rel_key(a, b)
	s["relationships"][k]["romance"] = mini(100, int(s["relationships"][k].get("romance", 0)) + 5)
	if rng.randf() >= 0.5: return {"ok": true, "pregnant": false, "reason": ""}
	var carrier := a if bool(s["characters"][a].get("can_carry", false)) else b
	var other := b if carrier == a else a
	if not s.has("pregnancies"): s["pregnancies"] = []
	s["pregnancies"].append({"carrier": carrier, "partner": other, "due": int(s["minute"]) + PREGNANCY_DAYS * 1440, "seed": seed, "count": Genetics.litter_size(seed)})
	return {"ok": true, "pregnant": true, "reason": "", "carrier": carrier}

## Per-minute upkeep: births and (optionally) aging. Returns event dicts for the UI.
static func update(s: Dictionary) -> Array:
	var ev := []
	var m := int(s["minute"])
	for p in s.get("pregnancies", []).duplicate():
		if m >= int(p["due"]):
			s["pregnancies"].erase(p)
			var kids := []
			for i in int(p["count"]):
				var cid := add_child_from_parents(s, p["carrier"], p["partner"], int(p["seed"]) + i * 101)
				var c: Dictionary = s["characters"][cid]
				c["lot"] = s["characters"][p["carrier"]]["lot"]; c["cell"] = s["characters"][p["carrier"]]["cell"].duplicate()
				kids.append(c["name"])
			ev.append({"kind": "done", "text": "%s and %s welcomed %s!" % [String(s["characters"][p["carrier"]]["name"]).get_slice(" ", 0), String(s["characters"][p["partner"]]["name"]).get_slice(" ", 0), " and ".join(kids)]})
	if m % 1440 == 0 and bool(s.get("settings", {}).get("aging", false)):
		for cid in s["characters"]:
			var c: Dictionary = s["characters"][cid]
			if not bool(s["settings"].get("inactive_progress", true)) and c["lot"] != s["active_lot"]: continue
			c["age_days"] = int(c.get("age_days", 0)) + 1
			var limit: int = AGE_UP_DAYS.get(c["age"], 0)
			if limit > 0 and int(c["age_days"]) >= limit:
				c["age"] = AGES[AGES.find(c["age"]) + 1]; c["age_days"] = 0
				ev.append({"kind": "info", "text": "%s is now %s %s." % [c["name"], "an" if c["age"] in ["adult", "elder"] else "a", c["age"]]})
	return ev
