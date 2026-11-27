class_name Neighborhood
extends RefCounted
## The premade starter world: four households with homes, budgets, relationships and stories in progress,
## plus an empty buildable lot for player-made households. All characters and stories are original.

## [id, name, pronouns, age, household, look-overrides, traits, aspiration]
const PEOPLE := [
	["hazel", "Hazel Rowan", "she/her", "elder", "rowan", {"body": "classic", "hair": "bun", "hair_color": "d9d4cc", "hair_natural": "3a2a20", "outfit": "apron", "skin": "c98e64", "top": "ede4d1", "bottom": "6e4b31", "outer": "c2643f"}, ["warm", "stubborn"], "A Quiet Retirement"],
	["delia", "Delia Rowan", "she/her", "adult", "rowan", {"body": "curvy", "hair": "long", "hair_color": "2a1d16", "outfit": "apron", "skin": "b57b54", "top": "86bdb2", "bottom": "4d4842", "outer": "ede4d1"}, ["ambitious", "proud"], "Grow the Family Business"],
	["theo", "Theo Rowan", "he/him", "teen", "rowan", {"body": "slender", "hair": "wavy", "hair_color": "3a2a20", "outfit": "casual", "skin": "b57b54", "top": "e3b04b", "bottom": "4d4842"}, ["creative", "shy"], "Master Painter"],
	["june", "June Park", "she/her", "adult", "park", {"body": "slender", "hair": "bun", "hair_color": "141010", "outfit": "jacket", "skin": "e8c3a0", "top": "86bdb2", "bottom": "c9bba0", "outer": "86bdb2"}, ["loyal", "perfectionist"], "Restore the Tidewell"],
	["iris", "Iris Park", "she/her", "adult", "park", {"body": "slender", "hair": "long", "hair_color": "1a1414", "outfit": "dress", "skin": "e8c3a0", "top": "c2643f", "bottom": "c2643f"}, ["restless", "witty"], "See the World"],
	["marcus", "Marcus Bell", "he/him", "adult", "bell", {"body": "classic", "hair": "curls_short", "hair_color": "15100c", "outfit": "casual", "skin": "5a3826", "top": "4f8f86", "bottom": "3a3532"}, ["outdoorsy", "goofy"], "Family Adventurer"],
	["renee", "Renee Bell", "she/her", "adult", "bell", {"body": "curvy", "hair": "long", "hair_color": "8a4b2a", "outfit": "dress", "skin": "f0d2b6", "top": "ede4d1", "bottom": "ede4d1"}, ["cultured", "planner"], "Close-Knit Family"],
	["avery", "Avery Bell", "they/them", "child", "bell", {"body": "slender", "hair": "coils", "hair_color": "1d1611", "outfit": "casual", "skin": "5a3826", "top": "e3b04b", "bottom": "4f8f86"}, ["curious", "energetic"], "Beach Explorer"],
	["sol", "Sol Bell", "he/him", "teen", "bell", {"body": "slender", "hair": "wavy", "hair_color": "8a4b2a", "outfit": "jacket", "skin": "f0d2b6", "top": "3a3532", "bottom": "4d4842", "outer": "3a3532"}, ["independent", "music lover"], "Find My Crew"],
	["gabriel", "Gabriel Alvarez", "he/him", "adult", "alvarez", {"body": "classic", "hair": "wavy", "hair_color": "1a1410", "outfit": "casual", "skin": "c08a5e", "top": "c2643f", "bottom": "4d4842"}, ["romantic", "traditional"], "Build a Family"],
	["lucia", "Lucia Alvarez", "she/her", "adult", "alvarez", {"body": "curvy", "hair": "long", "hair_color": "241a14", "outfit": "dress", "skin": "a8704a", "top": "d77a8f", "bottom": "d77a8f"}, ["creative", "entrepreneur"], "Bloom into Business"],
	["noor", "Noor Haddad", "she/her", "adult", "haddad", {"body": "slender", "hair": "bun", "hair_color": "1a1410", "outfit": "jacket", "skin": "c99a72", "top": "ede4d1", "bottom": "3a3532", "outer": "c99a45"}, ["bold", "trendsetter"], "Investor Extraordinaire"],
]
const HOUSEHOLDS := {
	"rowan": {"lead": "delia", "name": "The Rowans", "funds": 185000, "lot": "lot_rowan", "teaser": "Three generations above a struggling bakery. Grandma wants to retire, Mum wants to expand, and Theo wants the empty room for art. You decide what they can afford to dream."},
	"park": {"lead": "june", "name": "The Park Sisters", "funds": 90000, "lot": "lot_park", "teaser": "Two sisters inherit a leaky seaside inn. One wants to restore it, one wants to sell and leave town. Buy her out, run it together, or walk away rich and estranged."},
	"bell": {"lead": "renee", "name": "The Bells", "funds": 320000, "lot": "lot_bell", "teaser": "A brand-new blended family planning their first trip. Four people, four ideas of fun, one budget. Will the vacation bring them closer or crack them open?"},
	"alvarez": {"lead": "lucia", "name": "The Alvarezes", "funds": 110000, "lot": "lot_alvarez", "teaser": "Newlyweds turning a weekend flower stall into a real shop while deciding whether to grow their family. Their best friend wants in, with money and opinions."},
	"haddad": {"lead": "noor", "name": "Noor Haddad", "funds": 500000, "lot": "", "teaser": "Lucia's oldest friend, investor and trendsetter. (Visits other households.)"},
}
const LOTS := {"lot_rowan": "rowan_bakery", "lot_park": "park_inn", "lot_bell": "alder_bungalow", "lot_alvarez": "alvarez_cottage", "lot_willow": "willow_lot"}
## [a, b, type, friendship, romance]   type from a's view: parent_of, spouse, sibling, friend
const TIES := [
	["hazel", "delia", "parent_of", 55, 0], ["delia", "theo", "parent_of", 40, 0], ["hazel", "theo", "grandparent_of", 70, 0],
	["june", "iris", "sibling", 35, 0],
	["marcus", "renee", "spouse", 60, 70], ["marcus", "avery", "parent_of", 75, 0], ["renee", "sol", "parent_of", 45, 0],
	["renee", "avery", "stepparent_of", 30, 0], ["marcus", "sol", "stepparent_of", 10, 0], ["avery", "sol", "step_sibling", 20, 0],
	["gabriel", "lucia", "spouse", 70, 80], ["lucia", "noor", "friend", 65, 0], ["gabriel", "noor", "friend", 30, 0],
	["delia", "lucia", "friend", 15, 0], ["hazel", "june", "friend", 25, 0], ["renee", "lucia", "friend", 10, 0],
]
const STORY_ORDER := ["rowan", "park", "bell", "alvarez"]

static func build() -> Dictionary:
	var s := {
		"version": GameState.VERSION, "world": "neighborhood", "minute": GameState.START_MINUTE, "subtick": 0, "speed": 1, "next_id": 100,
		"active_household": "rowan", "active_lot": "lot_rowan", "controlled": "delia",
		"households": {}, "lots": {}, "characters": {}, "relationships": {}, "reservations": {}, "stats": {"arrivals": {}},
		"schedule": [], "family": [], "settings": {"inactive_progress": true, "aging": false},
		"story": {"flags": {}, "fired": {}, "pending": [], "log": []},
	}
	for hid in HOUSEHOLDS:
		var h: Dictionary = HOUSEHOLDS[hid]
		s["households"][hid] = {"id": hid, "name": h["name"], "funds": h["funds"], "members": [], "lot": h["lot"], "premade": true}
	for lid in LOTS:
		var owner := ""
		for hid in HOUSEHOLDS: if HOUSEHOLDS[hid]["lot"] == lid: owner = hid
		s["lots"][lid] = {"id": lid, "layout": LOTS[lid], "household": owner, "furniture": {}}
		for f in LotLayouts.layout(LOTS[lid])["furniture"]:
			var fid := GameState.new_id(s, "f")
			s["lots"][lid]["furniture"][fid] = {"id": fid, "item": f[0], "cell": [f[1], f[2]], "rot": f[3]}
	var spawn_i := {}
	for p in PEOPLE:
		var hid: String = p[4]
		var lid: String = s["households"][hid]["lot"]
		var k: int = spawn_i.get(hid, 0); spawn_i[hid] = k + 1
		var look := {"accessories": [], "shoe": "3a3532", "knit": "ede4d1", "outer": "6e4b31"}
		look.merge(p[5], true)
		var c := GameState.make_character(p[0], p[1], look, p[3], p[2], hid, lid, Vector2i(14 + k * 2, 28) if lid != "" else Vector2i(15, 31), p[6], p[7])
		c["ai"] = "auto"
		c["can_carry"] = p[0] in ["delia", "june", "iris", "renee", "lucia", "noor"]
		c["age_days"] = 0
		s["characters"][p[0]] = c
		s["households"][hid]["members"].append(p[0])
	for t in TIES:
		s["family"].append({"a": t[0], "b": t[1], "type": t[2]})
		s["relationships"][GameState.rel_key(t[0], t[1])] = {"friendship": t[3], "romance": t[4], "met": true}
	s["characters"]["delia"]["ai"] = "player"
	# premade businesses (sample starting stock)
	var rb := Business.create(s, "rowan", "lot_rowan", "bakery", "Rowan & Rye Bakery")
	var b1: Dictionary = s["businesses"][rb["id"]]
	b1["stock"] = {"flour": 40, "butter": 15, "spice": 10, "beans": 20, "milk": 20, "sugar": 10}
	b1["open_hour"] = 7; b1["close_hour"] = 14
	var fb := Business.create(s, "alvarez", "lot_alvarez", "florist", "Petal & Pine")
	var b2: Dictionary = s["businesses"][fb["id"]]
	b2["stock"] = {"stems": 60, "wrap": 6, "pots": 3}
	b2["open_hour"] = 10; b2["close_hour"] = 17
	return s

## Switch which household the player controls. Returns {ok, reason}.
static func switch_to(s: Dictionary, hid: String) -> Dictionary:
	if HarborTrip.is_away(s):
		return {"ok": false, "reason": "Check out of Brineglass Harbor before switching households."}
	var h: Dictionary = s["households"].get(hid, {})
	if h.is_empty(): return {"ok": false, "reason": "No such household."}
	if String(h["lot"]) == "": return {"ok": false, "reason": "%s has no home lot to play." % h["name"]}
	for cid in s["characters"]:
		var c: Dictionary = s["characters"][cid]
		if c["ai"] == "player": c["ai"] = "auto"
	s["active_household"] = hid
	s["active_lot"] = h["lot"]
	var pick: String = HOUSEHOLDS.get(hid, {}).get("lead", "")
	if not h["members"].has(pick): pick = ""
	for m in h["members"]:
		var c: Dictionary = s["characters"][m]
		if pick == "" and c["age"] in ["adult", "elder"]: pick = m
	if pick == "": pick = h["members"][0]
	s["controlled"] = pick
	s["characters"][pick]["ai"] = "player"
	return {"ok": true, "reason": ""}

## Family tree for a household: nodes are characters, edges are typed family ties.
static func family_tree(s: Dictionary, hid: String) -> Dictionary:
	var members: Array = s["households"][hid]["members"]
	var edges := []
	for t in s["family"]:
		if members.has(t["a"]) or members.has(t["b"]): edges.append(t)
	return {"members": members, "edges": edges}
