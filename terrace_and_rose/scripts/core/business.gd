class_name Business
extends RefCounted
## Shops run by households: name, lot, hours, menu prices, stock (with reservations), customers,
## orders and a ledger. Money moves only through post() so the ledger always reconciles with funds.

const TYPES := {
	"bakery": {"label": "Bakery & Café", "products": {
		"rye_loaf": {"name": "Rye Loaf", "base": 600, "uses": {"flour": 2}, "prep": 3},
		"cardamom_bun": {"name": "Cardamom Bun", "base": 350, "uses": {"flour": 1, "butter": 1, "spice": 1}, "prep": 2},
		"coffee": {"name": "Coffee", "base": 300, "uses": {"beans": 1, "milk": 1}, "prep": 2},
		"tide_cake": {"name": "Tide Cake Slice", "base": 550, "uses": {"flour": 1, "butter": 1, "sugar": 1}, "prep": 3}},
		"ingredients": {"flour": 60, "butter": 90, "spice": 40, "beans": 70, "milk": 40, "sugar": 30},
		"customers_per_hour": 5},
	"florist": {"label": "Florist", "products": {
		"posy": {"name": "Posy", "base": 1200, "uses": {"stems": 5}, "prep": 4},
		"bouquet": {"name": "Seaside Bouquet", "base": 3800, "uses": {"stems": 12, "wrap": 1}, "prep": 8},
		"potted_fig": {"name": "Potted Fig", "base": 2500, "uses": {"pots": 1}, "prep": 2}},
		"ingredients": {"stems": 120, "wrap": 80, "pots": 1100},
		"customers_per_hour": 3},
}
const PATIENCE := 40          # minutes a customer waits before giving up
const MAX_WAITING := 6

static func create(s: Dictionary, hid: String, lid: String, type: String, name: String) -> Dictionary:
	if not TYPES.has(type): return {"ok": false, "reason": "Unknown business type."}
	var lot: Dictionary = s["lots"].get(lid, {})
	if lot.is_empty(): return {"ok": false, "reason": "No such lot."}
	if lot["household"] != hid: return {"ok": false, "reason": "Run a business from a lot your household owns."}
	for b in s.get("businesses", {}).values():
		if b["lot"] == lid: return {"ok": false, "reason": "This lot already has a business."}
	if not s.has("businesses"): s["businesses"] = {}
	var bid := GameState.new_id(s, "b")
	var menu := {}
	for pid in TYPES[type]["products"]: menu[pid] = {"price": TYPES[type]["products"][pid]["base"], "enabled": true}
	var stock := {}
	for ing in TYPES[type]["ingredients"]: stock[ing] = 0
	s["businesses"][bid] = {"id": bid, "name": name if name.strip_edges() != "" else TYPES[type]["label"], "type": type, "lot": lid, "household": hid,
		"open_hour": 8, "close_hour": 16, "auto_open": true, "is_open": false, "menu": menu, "stock": stock, "reserved": {},
		"orders": {}, "ledger": [], "reputation": 50, "shift": {}, "last_summary": {}, "rng": 1}
	return {"ok": true, "reason": "", "id": bid}

static func for_lot(s: Dictionary, lid: String) -> Dictionary:
	for b in s.get("businesses", {}).values():
		if b["lot"] == lid: return b
	return {}

static func available(b: Dictionary, ing: String) -> int:
	return int(b["stock"].get(ing, 0)) - int(b["reserved"].get(ing, 0))

static func set_price(b: Dictionary, pid: String, cents: int) -> void:
	if b["menu"].has(pid): b["menu"][pid]["price"] = clampi(cents, 50, 100000)

static func set_hours(b: Dictionary, open_h: int, close_h: int) -> Dictionary:
	if open_h < 5 or close_h > 23 or close_h - open_h < 2: return {"ok": false, "reason": "Open between 05:00 and 23:00 for at least 2 hours."}
	b["open_hour"] = open_h; b["close_hour"] = close_h
	return {"ok": true, "reason": ""}

## Record money in the ledger and move it in the owning household's funds in one step.
static func post(s: Dictionary, b: Dictionary, kind: String, cents: int, note: String) -> void:
	b["ledger"].append({"minute": int(s["minute"]), "kind": kind, "amount": cents, "note": note})
	var h: Dictionary = s["households"][b["household"]]
	h["funds"] = int(h["funds"]) + cents
	if not b["shift"].is_empty(): b["shift"][kind] = int(b["shift"].get(kind, 0)) + cents

static func buy_stock(s: Dictionary, b: Dictionary, ing: String, qty: int) -> Dictionary:
	var unit: int = TYPES[b["type"]]["ingredients"].get(ing, -1)
	if unit < 0 or qty <= 0: return {"ok": false, "reason": "Unknown supply."}
	var cost := unit * qty
	if int(s["households"][b["household"]]["funds"]) < cost: return {"ok": false, "reason": "Not enough funds (%s)." % Catalog.format_cents(cost)}
	b["stock"][ing] = int(b["stock"][ing]) + qty
	post(s, b, "stock", -cost, "%d × %s" % [qty, ing])
	return {"ok": true, "reason": "", "cost": cost}

static func can_make(b: Dictionary, pid: String) -> bool:
	var p: Dictionary = TYPES[b["type"]]["products"][pid]
	for ing in p["uses"]:
		if available(b, ing) < int(p["uses"][ing]): return false
	return true

# ------------------------------------------------------------------ orders
static func place_order(s: Dictionary, b: Dictionary, customer: String, pid: String) -> Dictionary:
	if not b["is_open"]: return {"ok": false, "reason": "closed"}
	if not b["menu"][pid]["enabled"]: return {"ok": false, "reason": "not on the menu"}
	if not can_make(b, pid): return {"ok": false, "reason": "out of stock"}
	var p: Dictionary = TYPES[b["type"]]["products"][pid]
	for ing in p["uses"]: b["reserved"][ing] = int(b["reserved"].get(ing, 0)) + int(p["uses"][ing])
	var oid := GameState.new_id(s, "o")
	b["orders"][oid] = {"id": oid, "customer": customer, "product": pid, "price": int(b["menu"][pid]["price"]), "status": "waiting", "placed": int(s["minute"])}
	return {"ok": true, "reason": "", "id": oid}

static func _unreserve(b: Dictionary, pid: String) -> void:
	var p: Dictionary = TYPES[b["type"]]["products"][pid]
	for ing in p["uses"]: b["reserved"][ing] = maxi(0, int(b["reserved"].get(ing, 0)) - int(p["uses"][ing]))

## Cancelling releases the reserved stock (nothing is consumed, nothing is charged).
static func cancel_order(s: Dictionary, b: Dictionary, oid: String, why: String) -> void:
	var o: Dictionary = b["orders"].get(oid, {})
	if o.is_empty() or o["status"] != "waiting": return
	_unreserve(b, o["product"])
	o["status"] = "cancelled"; o["why"] = why
	if not b["shift"].is_empty(): b["shift"]["lost"] = int(b["shift"].get("lost", 0)) + 1
	b["reputation"] = clampi(int(b["reputation"]) - 2, 0, 100)

## Serving consumes the reserved ingredients and records the sale.
static func serve_order(s: Dictionary, b: Dictionary, oid: String) -> Dictionary:
	var o: Dictionary = b["orders"].get(oid, {})
	if o.is_empty() or o["status"] != "waiting": return {"ok": false, "reason": "No such waiting order."}
	var p: Dictionary = TYPES[b["type"]]["products"][o["product"]]
	_unreserve(b, o["product"])
	for ing in p["uses"]: b["stock"][ing] = int(b["stock"][ing]) - int(p["uses"][ing])
	o["status"] = "served"
	post(s, b, "sale", int(o["price"]), p["name"])
	if not b["shift"].is_empty(): b["shift"]["served"] = int(b["shift"].get("served", 0)) + 1
	b["reputation"] = clampi(int(b["reputation"]) + 1, 0, 100)
	return {"ok": true, "reason": "", "product": p["name"], "price": int(o["price"])}

static func next_waiting(b: Dictionary) -> String:
	var best := ""; var t := 1 << 30
	for oid in b["orders"]:
		var o: Dictionary = b["orders"][oid]
		if o["status"] == "waiting" and int(o["placed"]) < t: t = int(o["placed"]); best = oid
	return best

# ------------------------------------------------------------------ demand
## Expected customers this hour: base rate × price appeal × reputation × story boosts × time-of-day.
static func demand(s: Dictionary, b: Dictionary, hour: int) -> float:
	var t: Dictionary = TYPES[b["type"]]
	var ratio := 0.0; var n := 0
	for pid in b["menu"]:
		if b["menu"][pid]["enabled"]:
			ratio += float(t["products"][pid]["base"]) / maxf(1.0, float(b["menu"][pid]["price"])); n += 1
	if n == 0: return 0.0
	var appeal := clampf(pow(ratio / n, 1.3), 0.25, 1.8)
	var rep := 0.6 + float(b["reputation"]) / 125.0
	var rush := 1.5 if (b["type"] == "bakery" and hour in [8, 9, 12]) or (b["type"] == "florist" and hour in [11, 12, 17]) else 1.0
	var boost := 1.0
	var f: Dictionary = s.get("story", {}).get("flags", {})
	if b["type"] == "bakery" and (f.has("bakery_supplies_inn") or f.has("rose_and_rye")): boost += 0.3
	if b["type"] == "florist" and (f.has("inn_flowers") or f.has("neon_sign") or f.has("rose_and_rye")): boost += 0.3
	return float(t["customers_per_hour"]) * appeal * rep * rush * boost

static func pick_product(b: Dictionary, roll: float) -> String:
	var ids := []
	for pid in b["menu"]: if b["menu"][pid]["enabled"]: ids.append(pid)
	if ids.is_empty(): return ""
	ids.sort()
	return ids[mini(ids.size() - 1, int(roll * ids.size()))]

static func rand(b: Dictionary) -> float:
	var r := RandomNumberGenerator.new(); r.seed = int(b["rng"]); b["rng"] = int(b["rng"]) + 1
	return r.randf()

# ------------------------------------------------------------------ shifts
static func open_shift(s: Dictionary, b: Dictionary) -> Dictionary:
	if b["is_open"]: return {"ok": false, "reason": "Already open."}
	var lot: Dictionary = s["lots"][b["lot"]]
	var has_register := false
	for f in lot["furniture"].values(): if f["item"] == "register": has_register = true
	if not has_register: return {"ok": false, "reason": "Place a Shop Register first."}
	b["is_open"] = true
	b["shift"] = {"start": int(s["minute"]), "funds_start": int(s["households"][b["household"]]["funds"]), "ledger_start": b["ledger"].size(), "served": 0, "lost": 0, "walkouts": 0, "sale": 0, "stock": 0}
	return {"ok": true, "reason": ""}

static func close_shift(s: Dictionary, b: Dictionary) -> Dictionary:
	if not b["is_open"]: return {"ok": false, "reason": "Not open."}
	for oid in b["orders"].keys(): cancel_order(s, b, oid, "closing time")
	b["is_open"] = false
	var sh: Dictionary = b["shift"]
	var entries: Array = b["ledger"].slice(int(sh["ledger_start"]))
	var ledger_total := 0
	for e in entries: ledger_total += int(e["amount"])
	var funds_delta := int(s["households"][b["household"]]["funds"]) - int(sh["funds_start"])
	var summary := {"business": b["name"], "start": sh["start"], "end": int(s["minute"]), "served": sh["served"], "lost": sh["lost"], "walkouts": sh["walkouts"],
		"revenue": int(sh.get("sale", 0)), "expenses": -int(sh.get("stock", 0)), "profit": ledger_total, "funds_delta": funds_delta,
		"reconciled": ledger_total == funds_delta, "reputation": b["reputation"], "entries": entries.size()}
	b["last_summary"] = summary
	b["orders"] = {}
	b["shift"] = {}
	return {"ok": true, "reason": "", "summary": summary}
