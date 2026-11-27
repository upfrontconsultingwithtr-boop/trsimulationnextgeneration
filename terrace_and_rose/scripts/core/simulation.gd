class_name Simulation
extends RefCounted
## Fixed-tick life simulation over a GameState dictionary. No scene or UI access.
## Call tick() a fixed number of times per real second (see SPEED_TICKS); rendering only reads state.

const SPEED_TICKS := [0, 4, 24]          # ticks per real second for Pause / Normal / Fast
const SPEED_NAMES := ["Paused", "Normal", "Fast"]
const MAX_QUEUE := 6
const ACTIONS := {
	"walk": {"label": "Walk", "minutes": 0},
	"prepare_meal": {"label": "Prepare a meal", "item": "prepare_meal", "minutes": 30, "anim": "cook"},
	"eat": {"label": "Eat", "item": "eat", "minutes": 20, "anim": "eat"},
	"greet": {"label": "Greet", "minutes": 5, "anim": "wave"},
	"sit": {"label": "Sit", "item": "sit", "minutes": 60, "anim": "sit_idle"},
	"sleep": {"label": "Sleep", "item": "sleep", "minutes": 480, "anim": "sleep"},
	"try_for_baby": {"label": "Try for Baby", "minutes": 30, "anim": "idle"},
	"work_register": {"label": "Work the register", "item": "work_register", "minutes": 720, "anim": "idle"},
}
const DECAY := {"hunger": 8, "energy": 6, "social": 5, "comfort": 4}

var state: Dictionary
var events: Array[Dictionary] = []   # {kind: info|done|error|arrive|leave, text, actor}
var _nav := {}

func _init(s: Dictionary) -> void:
	state = s
	for lid in state["lots"]:
		rebuild_nav(lid)

# ------------------------------------------------------------------ queries
func minute() -> int: return int(state["minute"])
func controlled() -> Dictionary: return state["characters"][state["controlled"]]
func character(id: String) -> Dictionary: return state["characters"].get(id, {})
func household() -> Dictionary: return state["households"][state["active_household"]]
func funds() -> int: return int(household()["funds"])
func lot(lid: String) -> Dictionary: return state["lots"][lid]
func layout_id(lid: String) -> String: return String(state["lots"][lid]["layout"])
func furniture(lid: String) -> Dictionary: return state["lots"][lid]["furniture"]
func chars_on(lid: String) -> Array:
	var out := []
	for cid in state["characters"]:
		if state["characters"][cid]["lot"] == lid: out.append(state["characters"][cid])
	return out

func set_speed(i: int) -> void:
	state["speed"] = clampi(i, 0, 2)

func _emit(kind: String, text: String, actor: String = "", lot_id: String = "") -> void:
	if lot_id == "" and state["characters"].has(actor): lot_id = state["characters"][actor]["lot"]
	events.append({"kind": kind, "text": text, "actor": actor, "lot": lot_id})

# ------------------------------------------------------------------ navigation
func rebuild_nav(lid: String) -> void:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, LotLayouts.SIZE, LotLayouts.SIZE)
	g.cell_size = Vector2.ONE
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	var lay := layout_id(lid)
	for y in LotLayouts.SIZE:
		for x in LotLayouts.SIZE:
			if LotLayouts.is_structural_block(LotLayouts.tile(lay, Vector2i(x, y))): g.set_point_solid(Vector2i(x, y))
	for fid in furniture(lid):
		var f: Dictionary = furniture(lid)[fid]
		if Catalog.get_def(f["item"])["layer"] == "floor": continue
		for c in Catalog.cells(f["item"], GameState.cell_of(f["cell"]), int(f["rot"])):
			if g.is_in_boundsv(c): g.set_point_solid(c)
	_nav[lid] = g

func walkable(lid: String, c: Vector2i) -> bool:
	var g: AStarGrid2D = _nav[lid]
	return g.is_in_boundsv(c) and not g.is_point_solid(c)

func find_path(lid: String, from: Vector2i, to: Vector2i) -> Array:
	if not walkable(lid, to): return []
	if from == to: return [[to.x, to.y]]
	var g: AStarGrid2D = _nav[lid]
	var was_solid := g.is_point_solid(from)
	if was_solid: g.set_point_solid(from, false)   # never trap an actor standing on a newly blocked cell
	var p := g.get_id_path(from, to)
	if was_solid: g.set_point_solid(from, true)
	var out := []
	for c in p: out.append([c.x, c.y])
	return out

# ------------------------------------------------------------------ action queue API
func queue_action(cid: String, type: String, target: String = "", cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var c := character(cid)
	if c.is_empty() or c["lot"] == "":
		return {"ok": false, "reason": "That person isn't here."}
	if not ACTIONS.has(type):
		return {"ok": false, "reason": "Unknown action."}
	if c["queue"].size() >= MAX_QUEUE:
		_emit("error", "Queue is full (max %d)." % MAX_QUEUE, cid)
		return {"ok": false, "reason": "Queue is full."}
	var a := {"id": GameState.new_id(state, "a"), "type": type, "target": target, "cell": [cell.x, cell.y],
		"slot": -1, "phase": "queued", "remaining": 0, "path": [], "label": _label(type, target)}
	c["queue"].append(a)
	return {"ok": true, "action": a}

func _label(type: String, target: String) -> String:
	var l: String = ACTIONS[type]["label"]
	if target != "":
		if state["characters"].has(target): return "%s %s" % [l, state["characters"][target]["name"]]
		for lid in state["lots"]:
			if furniture(lid).has(target): return "%s (%s)" % [l, Catalog.get_def(furniture(lid)[target]["item"])["name"]]
	return l

func cancel_action(cid: String, action_id: String = "", reason: String = "") -> bool:
	var c := character(cid)
	if c.is_empty(): return false
	var cur: Dictionary = c["current"]
	if not cur.is_empty() and (action_id == "" or cur["id"] == action_id):
		_finish(c, false)
		_emit("info", reason if reason != "" else "Cancelled: %s." % cur["label"], cid)
		return true
	for i in c["queue"].size():
		if c["queue"][i]["id"] == action_id:
			var a: Dictionary = c["queue"][i]
			c["queue"].remove_at(i)
			_emit("info", reason if reason != "" else "Removed from queue: %s." % a["label"], cid)
			return true
	return false

func clear_queue(cid: String) -> void:
	var c := character(cid)
	c["queue"].clear()
	if not c["current"].is_empty(): cancel_action(cid)

# ------------------------------------------------------------------ reservations
func reserved_by(fid: String, slot: int) -> String:
	return String(state["reservations"].get(fid, {}).get(str(slot), ""))

func _reserve(fid: String, slot: int, cid: String) -> void:
	if not state["reservations"].has(fid): state["reservations"][fid] = {}
	state["reservations"][fid][str(slot)] = cid

func _release(fid: String, slot: int, cid: String) -> void:
	var r: Dictionary = state["reservations"].get(fid, {})
	if r.get(str(slot), "") == cid: r.erase(str(slot))
	if r.is_empty(): state["reservations"].erase(fid)

## Called by furnishing when an object disappears: cancel anything that targets it and free its slots.
func on_furniture_removed(lid: String, fid: String) -> void:
	for c in chars_on(lid):
		if not c["current"].is_empty() and c["current"]["target"] == fid:
			cancel_action(c["id"], "", "Stopped: that object was removed.")
		for a in c["queue"].duplicate():
			if a["target"] == fid: cancel_action(c["id"], a["id"], "Removed from queue: its object is gone.")
	state["reservations"].erase(fid)
	rebuild_nav(lid)

# ------------------------------------------------------------------ ticking
func _frozen(c: Dictionary) -> bool:
	# inactive households pause when the player turns "inactive households progress" off
	return not bool(state.get("settings", {}).get("inactive_progress", true)) and c["lot"] != state["active_lot"]

func tick() -> void:
	for cid in state["characters"]:
		var c: Dictionary = state["characters"][cid]
		if c["lot"] == "" or _frozen(c): continue
		_step_character(c)
	state["subtick"] = int(state["subtick"]) + 1
	if int(state["subtick"]) >= GameState.TICKS_PER_MINUTE:
		state["subtick"] = 0
		state["minute"] = int(state["minute"]) + 1
		_on_minute()

func advance_minutes(n: int) -> void:
	for i in n * GameState.TICKS_PER_MINUTE: tick()

func _on_minute() -> void:
	var m := minute()
	for ev in state["schedule"]:
		if not ev["fired"] and m >= int(ev["at"]):
			ev["fired"] = true
			_fire(ev)
	for e in FamilyLife.update(state): _emit(e["kind"], e["text"])
	_businesses_minute()
	if state.has("story"):
		for bid in StoryEngine.check(state):
			_emit("story", StoryEngine.beat(bid)["title"], bid)
	for cid in state["characters"]:
		var c: Dictionary = state["characters"][cid]
		if c["lot"] == "" or _frozen(c): continue
		var cur: Dictionary = c["current"]
		var doing := String(cur.get("type", "")) if cur.get("phase", "") == "perform" else ""
		for k in GameState.NEED_KEYS:
			var d: int = DECAY[k]
			if k == "energy" and doing == "sleep": d = 0
			if k == "comfort" and (c["pose"] == "sit" or c["pose"] == "lie"): d = 0
			_need(c, k, -d)
		if doing != "": _perform_minute(c, cur)
		if c["ai"] == "customer": _customer_ai(c)
		elif c["current"].is_empty() and c["queue"].is_empty() and m >= int(c["ai_next"]):
			if c["ai"] == "visitor": _visitor_ai(c)
			elif c["ai"] == "auto": _auto_ai(c)

func _need(c: Dictionary, k: String, d: int) -> void:
	c["needs"][k] = clampi(int(c["needs"][k]) + d, 0, GameState.NEED_MAX)

func _step_character(c: Dictionary) -> void:
	if c["current"].is_empty():
		if c["queue"].is_empty(): return
		var a: Dictionary = c["queue"].pop_front()
		c["current"] = a
		if not _start(c, a): return
	var cur: Dictionary = c["current"]
	if cur["phase"] == "approach":
		if cur["type"] == "greet" or cur["type"] == "try_for_baby":
			_retarget_greet(c, cur)
			if c["current"].is_empty(): return
		if cur["path"].is_empty():
			_arrive(c, cur)
			return
		var nxt := GameState.cell_of(cur["path"][0])
		if not walkable(c["lot"], nxt):
			var goal := GameState.cell_of(cur["path"][-1])
			var p := find_path(c["lot"], GameState.cell_of(c["cell"]), goal)
			if p.is_empty():
				_fail(c, "Can't reach the destination anymore.")
				return
			p.pop_front()
			cur["path"] = p
			return
		cur["path"].pop_front()
		_face_towards(c, Vector2(nxt) - Vector2(GameState.cell_of(c["cell"])))
		c["cell"] = [nxt.x, nxt.y]
		c["anim"] = "walk"
		if cur["path"].is_empty(): _arrive(c, cur)

func _face_towards(c: Dictionary, d: Vector2) -> void:
	if d.length_squared() > 0.0: c["facing"] = posmod(int(round(rad_to_deg(atan2(d.x, d.y)))), 360)

## Resolve target, reserve a slot and plan a path. Returns false if the action failed immediately.
func _start(c: Dictionary, a: Dictionary) -> bool:
	var lid: String = c["lot"]
	var here := GameState.cell_of(c["cell"])
	var type: String = a["type"]
	if c["pose"] != "stand":
		c["pose"] = "stand"; c["anchor"] = []
	match type:
		"walk":
			var goal := GameState.cell_of(a["cell"])
			var p := find_path(lid, here, goal)
			if p.is_empty(): return _fail(c, "Can't walk there — no clear path.")
			p.pop_front(); a["path"] = p; a["phase"] = "approach"
			return true
		"greet", "try_for_baby":
			var t := character(a["target"])
			if t.is_empty() or t["lot"] != lid: return _fail(c, "Nobody to greet here.")
			if type == "try_for_baby":
				var el := FamilyLife.baby_eligibility(state, c["id"], t["id"])
				if not el["ok"]: return _fail(c, el["reason"])
			if t["id"] == c["id"]: return _fail(c, "You can't greet yourself.")
			var p := _path_next_to(lid, here, GameState.cell_of(t["cell"]))
			if p.is_empty() and here.distance_to(GameState.cell_of(t["cell"])) > 1.5: return _fail(c, "Can't reach %s." % t["name"])
			if not p.is_empty(): p.pop_front()
			a["path"] = p; a["phase"] = "approach"
			return true
		"eat":
			if c["holding"] != "meal": return _fail(c, "Nothing to eat — prepare a meal first.")
			if a["target"] == "":
				var seat := _nearest_free(lid, here, "eat")
				if seat.is_empty():
					a["path"] = []; a["phase"] = "approach"
					return true
				a["target"] = seat["fid"]
	return _start_object_action(c, a)

func _start_object_action(c: Dictionary, a: Dictionary) -> bool:
	var lid: String = c["lot"]
	var fid: String = a["target"]
	if fid == "": 
		var near := _nearest_free(lid, GameState.cell_of(c["cell"]), ACTIONS[a["type"]]["item"])
		if near.is_empty(): return _fail(c, "No free %s nearby." % _object_word(a["type"]))
		fid = near["fid"]; a["target"] = fid
	var f: Dictionary = furniture(lid).get(fid, {})
	if f.is_empty(): return _fail(c, "That object is gone.")
	var def := Catalog.get_def(f["item"])
	if not def["actions"].has(ACTIONS[a["type"]]["item"]): return _fail(c, "%s can't do that." % def["name"])
	var any_free := false
	for si in def["slots"].size():
		var role: String = def["slots"][si].get("role", "")
		if (a["type"] == "work_register") != (role == "staff"): continue
		var who := reserved_by(fid, si)
		if who != "" and who != c["id"]: continue
		any_free = true
		for cand in def["slots"][si]["approach"]:
			var ap := Catalog.local_cell_to_world(f["item"], GameState.cell_of(f["cell"]), int(f["rot"]), cand)
			var p := find_path(lid, GameState.cell_of(c["cell"]), ap)
			if p.is_empty(): continue
			_reserve(fid, si, c["id"])
			p.pop_front()
			a["slot"] = si; a["path"] = p; a["phase"] = "approach"
			a["label"] = _label(a["type"], fid)
			return true
	if not any_free: return _fail(c, "%s is in use." % def["name"])
	return _fail(c, "Can't reach the %s." % def["name"])

func _object_word(type: String) -> String:
	return {"prepare_meal": "counter", "sit": "seat", "sleep": "bed", "eat": "seat", "work_register": "register"}.get(type, "object")

func _nearest_free(lid: String, from: Vector2i, verb: String) -> Dictionary:
	var best := {}
	var bd := INF
	for fid in furniture(lid):
		var f: Dictionary = furniture(lid)[fid]
		var def := Catalog.get_def(f["item"])
		if not def["actions"].has(verb): continue
		for si in def["slots"].size():
			if reserved_by(fid, si) != "": continue
			if (verb == "work_register") != (def["slots"][si].get("role", "") == "staff"): continue
			var ap := Catalog.local_cell_to_world(f["item"], GameState.cell_of(f["cell"]), int(f["rot"]), def["slots"][si]["approach"][0])
			var d := Vector2(from).distance_to(Vector2(ap))
			if d < bd and walkable(lid, ap) and not find_path(lid, from, ap).is_empty():
				bd = d; best = {"fid": fid, "slot": si}
	return best

func _path_next_to(lid: String, from: Vector2i, target: Vector2i) -> Array:
	var best := []
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var p := find_path(lid, from, target + d)
		if not p.is_empty() and (best.is_empty() or p.size() < best.size()): best = p
	return best

func _retarget_greet(c: Dictionary, a: Dictionary) -> void:
	var t := character(a["target"])
	if t.is_empty() or t["lot"] != c["lot"]:
		_fail(c, "They left before you could say hello.")
		return
	var tc := GameState.cell_of(t["cell"])
	if a["path"].is_empty() or GameState.cell_of(a["path"][-1]).distance_to(tc) > 1.5:
		var p := _path_next_to(c["lot"], GameState.cell_of(c["cell"]), tc)
		if not p.is_empty(): p.pop_front()
		a["path"] = p

func _arrive(c: Dictionary, a: Dictionary) -> void:
	var type: String = a["type"]
	if type == "walk":
		_finish(c, true)
		if c["ai"] == "visitor" and c.get("leaving", false):
			c["lot"] = ""; c["leaving"] = false
			_emit("leave", "%s headed home. See you soon!" % c["name"], c["id"])
		return
	a["phase"] = "perform"
	a["remaining"] = int(ACTIONS[type]["minutes"])
	c["anim"] = ACTIONS[type].get("anim", "idle")
	if type == "try_for_baby":
		_emit("fade", "%s and %s share a private moment…" % [c["name"].get_slice(" ", 0), character(a["target"])["name"].get_slice(" ", 0)], c["id"])
		return
	if type == "greet":
		var t := character(a["target"])
		_face_towards(c, Vector2(GameState.cell_of(t["cell"]) - GameState.cell_of(c["cell"])))
		t["react_until"] = minute() + 4
		if t["current"].is_empty(): _face_towards(t, Vector2(GameState.cell_of(c["cell"]) - GameState.cell_of(t["cell"])))
		return
	if a["target"] == "":   # standing meal
		return
	var f: Dictionary = furniture(c["lot"])[a["target"]]
	var slot: Dictionary = Catalog.get_def(f["item"])["slots"][int(a["slot"])]
	var face := int(f["rot"]) + int(slot["face"])
	var dir := Catalog.facing_dir(face)
	c["facing"] = posmod(int(round(rad_to_deg(atan2(dir.x, dir.y)))), 360)
	var pose: String = slot.get("pose", "stand")
	if pose != "stand":
		var p := Catalog.local_point_to_world(f["item"], GameState.cell_of(f["cell"]), int(f["rot"]), slot["anchor"])
		c["anchor"] = [int(round(p.x * 100)), int(round(p.y * 100))]
		c["pose"] = pose
		if type == "eat": c["anim"] = "sit_eat"
	else:
		var center := Vector2(GameState.cell_of(f["cell"])) + Vector2(Catalog.footprint_size(f["item"], int(f["rot"]))) * 0.5
		_face_towards(c, center - (Vector2(GameState.cell_of(c["cell"])) + Vector2(0.5, 0.5)))

func _perform_minute(c: Dictionary, a: Dictionary) -> void:
	a["remaining"] = int(a["remaining"]) - 1
	match a["type"]:
		"eat":
			_need(c, "hunger", 300)
			if c["pose"] == "sit": _need(c, "comfort", 20)
		"sit": _need(c, "comfort", 60)
		"work_register": _register_minute(c, a)
		"sleep":
			_need(c, "energy", 25); _need(c, "comfort", 10)
			if int(c["needs"]["energy"]) >= GameState.NEED_MAX: a["remaining"] = 0
	if int(a["remaining"]) > 0: return
	match a["type"]:
		"prepare_meal":
			c["holding"] = "meal"
			_emit("done", "%s prepared a meal. Choose Eat to enjoy it." % c["name"], c["id"])
		"eat":
			c["holding"] = ""
			_emit("done", "%s finished eating. Hunger restored." % c["name"], c["id"])
		"greet":
			var t := character(a["target"])
			if not t.is_empty():
				_need(c, "social", 2000); _need(t, "social", 2000)
				var k := GameState.rel_key(c["id"], t["id"])
				var r: Dictionary = state["relationships"].get(k, {"friendship": 0, "met": false})
				var first: bool = not r["met"]
				r["friendship"] = clampi(int(r["friendship"]) + 10, -100, 100); r["met"] = true
				state["relationships"][k] = r
				_emit("done", ("%s met %s. Friendship +10." if first else "%s greeted %s. Friendship +10.") % [c["name"], t["name"]], c["id"])
		"sit": _emit("done", "%s feels rested after sitting." % c["name"], c["id"])
		"work_register": _emit("done", "%s finished at the register." % c["name"], c["id"])
		"try_for_baby":
			var r := FamilyLife.conceive(state, c["id"], a["target"], minute() * 31 + hash(c["id"]) % 997)
			_need(c, "social", 2500); _need(c, "comfort", 1500)
			if r.get("pregnant", false): _emit("done", "It's happening — %s is expecting! (due in %d days)" % [character(r["carrier"])["name"], FamilyLife.PREGNANCY_DAYS], c["id"])
			elif r["ok"]: _emit("info", "Not this time. They can try again.", c["id"])
			else: _emit("error", r["reason"], c["id"])
		"sleep": _emit("done", "%s woke up refreshed." % c["name"], c["id"])
	_finish(c, true)

func _finish(c: Dictionary, _ok: bool) -> void:
	var a: Dictionary = c["current"]
	if not a.is_empty() and a.get("target", "") != "" and int(a.get("slot", -1)) >= 0:
		_release(a["target"], int(a["slot"]), c["id"])
	if c["pose"] != "stand":
		# step off the seat/bed onto the approach cell
		c["anchor"] = []
	c["pose"] = "stand"
	c["anim"] = "idle"
	c["current"] = {}

func _fail(c: Dictionary, why: String) -> bool:
	_finish(c, false)
	_emit("error", why, c["id"])
	return false

# ------------------------------------------------------------------ schedule + simple visitor AI
func _fire(ev: Dictionary) -> void:
	var c := character(ev["who"])
	if c.is_empty(): return
	match ev["kind"]:
		"visitor_arrive":
			if c["lot"] != "": return
			var gates := LotLayouts.cells_of(layout_id(ev["lot"]), "G")
			c["lot"] = ev["lot"]; c["cell"] = [gates[0].x, gates[0].y]; c["current"] = {}; c["queue"] = []; c["pose"] = "stand"; c["anchor"] = []
			state["stats"]["arrivals"][c["id"]] = int(state["stats"]["arrivals"].get(c["id"], 0)) + 1
			_emit("arrive", "Knock knock! %s from down the lane is at the gate." % c["name"], c["id"])
			queue_action(c["id"], "walk", "", Vector2i(16, 24))
			c["ai_next"] = minute() + 5
		"visitor_leave":
			if c["lot"] == "": return
			clear_queue(c["id"])
			c["leaving"] = true
			var gates := LotLayouts.cells_of(layout_id(c["lot"]), "G")
			queue_action(c["id"], "walk", "", gates[0])

# ------------------------------------------------------------------ businesses
func _businesses_minute() -> void:
	var m := minute()
	var hour := (m / 60) % 24
	for bid in state.get("businesses", {}):
		var b: Dictionary = state["businesses"][bid]
		var lid: String = b["lot"]
		if not bool(state["settings"].get("inactive_progress", true)) and lid != state["active_lot"]: continue
		var staff_here := chars_on(lid).any(func(ch): return ch["household"] == b["household"] and ch["age"] != "child")
		if not b["is_open"] and b["auto_open"] and hour >= int(b["open_hour"]) and hour < int(b["close_hour"]) and staff_here and int(b.get("opened_day", -1)) != m / 1440:
			var r := Business.open_shift(state, b)
			if r["ok"]: b["opened_day"] = m / 1440; _emit_lot(lid, "info", "%s is open until %02d:00." % [b["name"], int(b["close_hour"])])
		if b["is_open"] and hour >= int(b["close_hour"]):
			close_business(b)
			continue
		if not b["is_open"]: continue
		# integer thousandths keep saves exact
		b["spawn_acc"] = int(b.get("spawn_acc", 0)) + int(round(Business.demand(state, b, hour) * 1000.0 / 60.0))
		var waiting := 0
		for ch in chars_on(lid): if ch["ai"] == "customer": waiting += 1
		while int(b["spawn_acc"]) >= 1000:
			b["spawn_acc"] = int(b["spawn_acc"]) - 1000
			if waiting < Business.MAX_WAITING: _spawn_customer(b); waiting += 1

func _emit_lot(lid: String, kind: String, text: String, actor: String = "") -> void:
	_emit(kind, text, actor, lid)

func close_business(b: Dictionary) -> Dictionary:
	var r := Business.close_shift(state, b)
	if not r["ok"]: return r
	for ch in chars_on(b["lot"]):
		if ch["current"].get("type", "") == "work_register": cancel_action(ch["id"], "", "Closing time — the register is closed.")
		if ch["ai"] == "customer" and ch["cust"]["state"] != "leaving": _customer_leave(ch)
	var sm: Dictionary = r["summary"]
	_emit_lot(b["lot"], "shift", "%s closed: %d served, %d walked out. Revenue %s, supplies %s, profit %s.%s" % [sm["business"], sm["served"], sm["lost"] + sm["walkouts"],
		Catalog.format_cents(sm["revenue"]), Catalog.format_cents(sm["expenses"]), Catalog.format_cents(sm["profit"]), "" if sm["reconciled"] else " (other household spending during the shift)"], b["id"])
	return r

func _spawn_customer(b: Dictionary) -> void:
	if not state["households"].has("townies"):
		state["households"]["townies"] = {"id": "townies", "name": "Townsfolk", "funds": 0, "members": [], "lot": "", "premade": true}
	var rng := RandomNumberGenerator.new(); rng.seed = int(b["rng"]) * 7 + minute()
	var look := Genetics.random_look(rng)
	look.merge({"outfit": ["casual", "jacket", "dress", "knit_jacket"][rng.randi() % 4], "top": ["c2643f", "86bdb2", "e3b04b", "ede4d1", "4f8f86"][rng.randi() % 5], "bottom": "4d4842", "outer": "6e4b31", "knit": "ede4d1", "shoe": "3a3532", "accessories": []}, true)
	var id := GameState.new_id(state, "cu")
	var gates := LotLayouts.cells_of(layout_id(b["lot"]), "G")
	var first: String = ["Ivy", "Omar", "Bea", "Felix", "Mina", "Otis", "Tess", "Ravi", "Lena", "Hugo"][rng.randi() % 10]
	var c := GameState.make_character(id, first + " (customer)", look, "adult" if rng.randf() > 0.15 else "elder", "they/them", "townies", b["lot"], gates[rng.randi() % gates.size()], [], "")
	c["ai"] = "customer"
	c["cust"] = {"bid": b["id"], "state": "arrive", "order": "", "since": minute()}
	state["characters"][id] = c
	state["households"]["townies"]["members"].append(id)
	queue_action(id, "walk", "", _counter_spot(b))

func _register_of(b: Dictionary) -> Dictionary:
	for fid in furniture(b["lot"]):
		if furniture(b["lot"])[fid]["item"] == "register": return furniture(b["lot"])[fid]
	return {}

func _counter_spot(b: Dictionary) -> Vector2i:
	var reg := _register_of(b)
	if reg.is_empty(): return GameState.cell_of(chars_on(b["lot"])[0]["cell"])
	var front := Catalog.local_cell_to_world("register", GameState.cell_of(reg["cell"]), int(reg["rot"]), [0, 1])
	var taken := {}
	for ch in chars_on(b["lot"]):
		if ch["ai"] == "customer": taken[GameState.cell_of(ch["cell"])] = true; if not ch["current"].is_empty() and not ch["current"]["path"].is_empty(): taken[GameState.cell_of(ch["current"]["path"][-1])] = true
	for r in range(0, 5):
		for dx in range(-r, r + 1):
			for dz in range(0, r + 1):
				var cc := front + Vector2i(dx, dz)
				if not taken.has(cc) and walkable(b["lot"], cc): return cc
	return front

func _customer_ai(c: Dictionary) -> void:
	var cu: Dictionary = c["cust"]
	var b: Dictionary = state["businesses"].get(cu["bid"], {})
	if b.is_empty(): _remove_customer(c); return
	match cu["state"]:
		"arrive":
			if not c["current"].is_empty() or not c["queue"].is_empty():
				if minute() - int(cu["since"]) > 60: _customer_leave(c)
				return
			var pid := Business.pick_product(b, Business.rand(b))
			var r := Business.place_order(state, b, c["id"], pid) if pid != "" else {"ok": false, "reason": "nothing on the menu"}
			if r["ok"]:
				cu["order"] = r["id"]; cu["state"] = "waiting"; cu["since"] = minute()
				c["bubble"] = Business.TYPES[b["type"]]["products"][pid]["name"]
			else:
				if not b["shift"].is_empty(): b["shift"]["walkouts"] = int(b["shift"].get("walkouts", 0)) + 1
				_emit("error", "%s left: %s." % [c["name"].get_slice(" ", 0), r["reason"]], c["id"])
				_customer_leave(c)
		"waiting":
			var o: Dictionary = b["orders"].get(cu["order"], {})
			if o.is_empty() or o["status"] == "cancelled": _customer_leave(c)
			elif o["status"] == "served": c["holding"] = "meal"; _customer_leave(c)
			elif minute() - int(cu["since"]) > Business.PATIENCE:
				Business.cancel_order(state, b, cu["order"], "waited too long")
				_emit("error", "%s gave up waiting and left." % c["name"].get_slice(" ", 0), c["id"])
				_customer_leave(c)
		"leaving":
			if c["current"].is_empty() and c["queue"].is_empty(): _remove_customer(c)

func _customer_leave(c: Dictionary) -> void:
	c["cust"]["state"] = "leaving"
	c["queue"].clear()
	if not c["current"].is_empty(): _finish(c, false)
	var gates := LotLayouts.cells_of(layout_id(c["lot"]), "G")
	if queue_action(c["id"], "walk", "", gates[0])["ok"] == false: _remove_customer(c)

func _remove_customer(c: Dictionary) -> void:
	state["households"]["townies"]["members"].erase(c["id"])
	state["characters"].erase(c["id"])

func _register_minute(c: Dictionary, a: Dictionary) -> void:
	var b := Business.for_lot(state, c["lot"])
	if b.is_empty() or not b["is_open"]:
		a["remaining"] = 0; return
	a["remaining"] = maxi(int(a["remaining"]), 2)
	if String(a.get("serving", "")) == "":
		var oid := Business.next_waiting(b)
		if oid == "": c["anim"] = "idle"; return
		a["serving"] = oid
		a["serve_left"] = int(Business.TYPES[b["type"]]["products"][b["orders"][oid]["product"]]["prep"])
		c["anim"] = "cook"
	a["serve_left"] = int(a["serve_left"]) - 1
	if int(a["serve_left"]) > 0: return
	var r := Business.serve_order(state, b, a["serving"])
	a["serving"] = ""
	if r["ok"]: _emit("sale", "Sold %s for %s." % [r["product"], Catalog.format_cents(r["price"])], c["id"])

## Simple needs-driven autonomy for everyone the player isn't controlling.
func _auto_ai(c: Dictionary) -> void:
	c["ai_next"] = minute() + 20
	var biz := Business.for_lot(state, c["lot"])
	if not biz.is_empty() and biz["is_open"] and biz["household"] == c["household"] and c["age"] != "child" and int(c["needs"]["energy"]) > 2000:
		var someone := chars_on(c["lot"]).any(func(o): return o["current"].get("type", "") == "work_register" or o["queue"].any(func(q): return q["type"] == "work_register"))
		if not someone: queue_action(c["id"], "work_register"); return
	var n: Dictionary = c["needs"]
	var cid: String = c["id"]
	if c["holding"] == "meal": queue_action(cid, "eat"); return
	if int(n["energy"]) < 2500: queue_action(cid, "sleep"); return
	if int(n["hunger"]) < 4000: queue_action(cid, "prepare_meal"); return
	if int(n["social"]) < 4500:
		for o in chars_on(c["lot"]):
			if o["id"] != cid and o["pose"] == "stand": queue_action(cid, "greet", o["id"]); return
	if int(n["comfort"]) < 5000: queue_action(cid, "sit"); return
	c["ai_next"] = minute() + 45

func _visitor_ai(c: Dictionary) -> void:
	c["ai_next"] = minute() + 45
	if c.get("leaving", false): return
	if c["pose"] == "stand":
		queue_action(c["id"], "sit")
