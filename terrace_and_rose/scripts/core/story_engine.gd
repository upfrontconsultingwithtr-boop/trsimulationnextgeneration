class_name StoryEngine
extends RefCounted
## Data-driven storylines (data/stories.json). Beats fire for the active household when their day/hour
## arrives and their flag conditions hold; the player picks a choice, whose effects change funds,
## relationships and flags, which in turn unlock or block later beats (including other households').

const PATH := "res://data/stories.json"
static var _beats: Array = []

static func beats() -> Array:
	if _beats.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY: _beats = GameState.normalize(d["beats"])
	return _beats

static func beat(id: String) -> Dictionary:
	for b in beats():
		if b["id"] == id: return b
	return {}

static func has_flag(s: Dictionary, f: String) -> bool:
	return s["story"]["flags"].has(f)

static func _conditions_ok(s: Dictionary, b: Dictionary) -> bool:
	for f in b.get("requires", []):
		if not has_flag(s, f): return false
	var any: Array = b.get("requires_any", [])
	if not any.is_empty() and not any.any(func(f): return has_flag(s, f)): return false
	for f in b.get("excludes", []):
		if has_flag(s, f): return false
	return true

## Called every game minute. Queues due beats for the active household; returns the newly queued ids.
static func check(s: Dictionary) -> Array:
	var out := []
	var hid: String = s["active_household"]
	var m := int(s["minute"])
	var day := m / 1440 + 1
	var hour := (m / 60) % 24
	for b in beats():
		if b["household"] != hid or s["story"]["fired"].has(b["id"]): continue
		if day < int(b["day"]) or (day == int(b["day"]) and hour < int(b["hour"])): continue
		if not _conditions_ok(s, b): continue
		s["story"]["fired"][b["id"]] = m
		s["story"]["pending"].append(b["id"])
		out.append(b["id"])
	return out

static func choice_status(s: Dictionary, b: Dictionary, idx: int) -> Dictionary:
	var c: Dictionary = b["choices"][idx]
	for f in c.get("requires", []):
		if not has_flag(s, f): return {"ok": false, "reason": "Locked — something else has to happen first."}
	var cost := int(c.get("cost", 0))
	if cost > 0 and int(s["households"][b["household"]]["funds"]) < cost:
		return {"ok": false, "reason": "Can't afford %s." % Catalog.format_cents(cost)}
	return {"ok": true, "reason": ""}

## Apply a choice. Returns {ok, text}. Effects are all-or-nothing.
static func choose(s: Dictionary, beat_id: String, idx: int) -> Dictionary:
	var b := beat(beat_id)
	if b.is_empty() or not s["story"]["pending"].has(beat_id): return {"ok": false, "text": "That moment has passed."}
	var st := choice_status(s, b, idx)
	if not st["ok"]: return {"ok": false, "text": st["reason"]}
	var c: Dictionary = b["choices"][idx]
	var fx: Dictionary = c.get("effects", {})
	var funds: Dictionary = fx.get("funds", {})
	for hid in funds:
		if s["households"].has(hid): s["households"][hid]["funds"] = int(s["households"][hid]["funds"]) + int(funds[hid])
	for r in fx.get("rel", []):
		var k := GameState.rel_key(r[0], r[1])
		var rel: Dictionary = s["relationships"].get(k, {"friendship": 0, "romance": 0, "met": true})
		rel["friendship"] = clampi(int(rel["friendship"]) + int(r[2]), -100, 100)
		s["relationships"][k] = rel
	for f in fx.get("set", []): s["story"]["flags"][f] = true
	for f in fx.get("clear", []): s["story"]["flags"].erase(f)
	var text: String = c.get("result", "")
	if fx.has("score"):
		var sc: Dictionary = fx["score"]
		var hits := 0
		for f in sc["flags"]: if has_flag(s, f): hits += 1
		var ending: String = sc["good"] if hits >= 2 else sc["bad"]
		s["story"]["flags"][ending] = true
		text += " " + ending_text(ending)
	s["story"]["pending"].erase(beat_id)
	s["story"]["log"].append({"minute": int(s["minute"]), "beat": beat_id, "choice": idx, "household": b["household"]})
	return {"ok": true, "text": text}

static func ending_text(flag: String) -> String:
	return {
		"ending_inn_thrives": "Five stars: 'Breakfast worth the trip, a lobby like a garden.' Iris unpacks her suitcase. The sisters stay.",
		"ending_inn_struggles": "Three stars: 'Charming, but…' Iris books her ticket. June keeps the lights on alone.",
		"ending_trip_closer": "Every photo has all four of them in it. Sol even made one the lock screen.",
		"ending_trip_tension": "Half the photos are of the view. Something still needs saying at home.",
		"ending_shop_blooms": "Petal & Pine is the talk of the town, and the friendship survived the business.",
		"ending_shop_strained": "Sales are fine. Dinners with Noor are quieter than they used to be.",
	}.get(flag, "")
