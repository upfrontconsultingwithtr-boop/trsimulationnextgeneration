class_name Cheats
extends RefCounted
## Owner-issued cheat access. The owner keeps a PRIVATE key outside the repo and issues a signed code per
## person (e.g. themself, Ricardo, invitees) with tools/cheat_keys.gd. The game ships only the PUBLIC key
## (data/cheat_public_key.pem), so it can verify codes but nobody can mint new ones without the private key.
## Limits: an offline game can be modified by someone determined; this stops casual sharing, not hackers.
## Cheats only work in private worlds (settings.shared != true).

const PUBLIC_KEY := "res://data/cheat_public_key.pem"
const ACCESS_FILE := "user://cheat_access.cfg"

static func payload(name: String) -> PackedByteArray:
	return ("terrace-and-rose-cheats:" + name.strip_edges().to_lower()).sha256_buffer()

static func make_code(private_key: CryptoKey, name: String) -> String:
	return Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, payload(name), private_key))

static func verify(name: String, code: String, public_key_path: String = PUBLIC_KEY) -> bool:
	if name.strip_edges() == "" or code.strip_edges() == "" or not FileAccess.file_exists(public_key_path): return false
	var key := CryptoKey.new()
	if key.load(public_key_path, true) != OK: return false
	var sig := Marshalls.base64_to_raw(code.strip_edges())
	if sig.is_empty(): return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, payload(name), sig, key)

static func unlock(name: String, code: String) -> bool:
	if not verify(name, code): return false
	var cfg := ConfigFile.new(); cfg.set_value("access", "name", name); cfg.set_value("access", "code", code); cfg.save(ACCESS_FILE)
	return true

static func unlocked_name() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(ACCESS_FILE) != OK: return ""
	var n: String = cfg.get_value("access", "name", ""); var c: String = cfg.get_value("access", "code", "")
	return n if verify(n, c) else ""

const HELP := "money <amount> · needs max · time +<hours> · speed <0-2> · aging on|off · ageup <name> · pregnant <name> · flag <name> · skipstory · help"

## Run one command against the state. Returns {ok, text}. Caller must check access and world type.
static func run(s: Dictionary, line: String) -> Dictionary:
	if bool(s.get("settings", {}).get("shared", false)): return {"ok": false, "text": "Cheats are disabled in shared worlds."}
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty(): return {"ok": false, "text": HELP}
	var cmd := parts[0].to_lower()
	var arg := " ".join(parts.slice(1)) if parts.size() > 1 else ""
	var h: Dictionary = s["households"][s["active_household"]]
	match cmd:
		"help": return {"ok": true, "text": HELP}
		"money":
			if not arg.is_valid_float(): return {"ok": false, "text": "Usage: money 500"}
			h["funds"] = int(h["funds"]) + int(round(arg.to_float() * 100.0))
			return {"ok": true, "text": "Funds now %s." % Catalog.format_cents(int(h["funds"]))}
		"needs":
			for cid in h["members"]:
				for k in GameState.NEED_KEYS: s["characters"][cid]["needs"][k] = GameState.NEED_MAX
			return {"ok": true, "text": "Everyone in %s feels great." % h["name"]}
		"time":
			var hrs := arg.trim_prefix("+")
			if not hrs.is_valid_int(): return {"ok": false, "text": "Usage: time +3"}
			s["minute"] = int(s["minute"]) + int(hrs) * 60
			return {"ok": true, "text": "Skipped %s hours." % hrs}
		"speed":
			s["speed"] = clampi(int(arg), 0, 2); return {"ok": true, "text": "Speed set."}
		"aging":
			s["settings"]["aging"] = arg == "on"; return {"ok": true, "text": "Aging %s." % ("on" if arg == "on" else "off")}
		"ageup", "pregnant":
			var cid := find_character(s, arg)
			if cid == "": return {"ok": false, "text": "No one called '%s'." % arg}
			var c: Dictionary = s["characters"][cid]
			if cmd == "ageup":
				var i := FamilyLife.AGES.find(c["age"])
				if i >= FamilyLife.AGES.size() - 1: return {"ok": false, "text": "%s is already an elder." % c["name"]}
				c["age"] = FamilyLife.AGES[i + 1]; c["age_days"] = 0
				return {"ok": true, "text": "%s is now %s." % [c["name"], c["age"]]}
			if c["age"] != "adult" or not bool(c.get("can_carry", false)): return {"ok": false, "text": "%s can't carry a pregnancy." % c["name"]}
			var partner := ""
			for t in s["family"]:
				if t["type"] in ["spouse", "partner"] and (t["a"] == cid or t["b"] == cid): partner = t["b"] if t["a"] == cid else t["a"]
			if partner == "": return {"ok": false, "text": "%s needs a partner." % c["name"]}
			if not s.has("pregnancies"): s["pregnancies"] = []
			s["pregnancies"].append({"carrier": cid, "partner": partner, "due": int(s["minute"]) + FamilyLife.PREGNANCY_DAYS * 1440, "seed": int(s["minute"]), "count": 1})
			return {"ok": true, "text": "%s is expecting." % c["name"]}
		"flag":
			s["story"]["flags"][arg] = true; return {"ok": true, "text": "Story flag set: %s" % arg}
		"skipstory":
			var n: int = s["story"]["pending"].size(); s["story"]["pending"].clear()
			return {"ok": true, "text": "Dismissed %d story moment(s)." % n}
	return {"ok": false, "text": "Unknown cheat. " + HELP}

static func find_character(s: Dictionary, q: String) -> String:
	var ql := q.strip_edges().to_lower()
	for cid in s["characters"]:
		var n := String(s["characters"][cid]["name"]).to_lower()
		if cid == ql or n == ql or n.get_slice(" ", 0) == ql: return cid
	return ""
