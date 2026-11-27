extends SceneTree
## Businesses. Run: godot --headless --path . -s tests/business_tests.gd
var fails := 0
var passes := 0
func check(c: bool, n: String) -> void:
	print("  %s  %s" % ["PASS" if c else "FAIL", n])
	if c: passes += 1
	else: fails += 1

func run_to(sim: Simulation, day: int, hour: int) -> void:
	var target := (day - 1) * 1440 + hour * 60
	while sim.minute() < target: sim.tick()

func _init() -> void:
	var s := Neighborhood.build()
	var bake: Dictionary = Business.for_lot(s, "lot_rowan")
	var flor: Dictionary = Business.for_lot(s, "lot_alvarez")
	print("[setup]")
	check(not bake.is_empty() and bake["type"] == "bakery" and not flor.is_empty(), "premade bakery and florist exist")
	check(not Business.create(s, "bell", "lot_rowan", "bakery", "X")["ok"], "can't open a business on someone else's lot")
	check(not Business.create(s, "rowan", "lot_rowan", "florist", "X")["ok"], "one business per lot")
	check(not Business.set_hours(bake, 9, 10)["ok"] and Business.set_hours(bake, 7, 14)["ok"], "hours validated")
	var f0 := int(s["households"]["rowan"]["funds"])
	var r := Business.buy_stock(s, bake, "flour", 10)
	check(r["ok"] and int(s["households"]["rowan"]["funds"]) == f0 - 600 and int(bake["stock"]["flour"]) == 50 and bake["ledger"][-1]["amount"] == -600, "buying stock charges funds and logs the expense")
	check(not Business.buy_stock(s, bake, "gold", 1)["ok"], "unknown supply rejected")
	print("[orders and reserved stock]")
	Business.open_shift(s, bake)
	var o := Business.place_order(s, bake, "x", "rye_loaf")
	check(o["ok"] and Business.available(bake, "flour") == 48 and int(bake["stock"]["flour"]) == 50, "order reserves stock without consuming it")
	Business.cancel_order(s, bake, o["id"], "test")
	check(Business.available(bake, "flour") == 50 and bake["orders"][o["id"]]["status"] == "cancelled", "cancelled order releases reserved stock")
	var o2 := Business.place_order(s, bake, "y", "coffee")
	var f1 := int(s["households"]["rowan"]["funds"])
	Business.serve_order(s, bake, o2["id"])
	check(int(bake["stock"]["beans"]) == 19 and int(s["households"]["rowan"]["funds"]) == f1 + 300, "serving consumes stock and earns the menu price")
	bake["stock"]["sugar"] = 0
	check(not Business.place_order(s, bake, "z", "tide_cake")["ok"], "out-of-stock item can't be ordered")
	Business.close_shift(s, bake)
	print("[pricing]")
	var d_base := Business.demand(s, bake, 10)
	Business.set_price(bake, "rye_loaf", 1800); Business.set_price(bake, "coffee", 900); Business.set_price(bake, "cardamom_bun", 1000); Business.set_price(bake, "tide_cake", 1600)
	check(Business.demand(s, bake, 10) < d_base * 0.6, "tripling prices cuts demand")
	for pid in bake["menu"]: Business.set_price(bake, pid, Business.TYPES["bakery"]["products"][pid]["base"])
	print("[one complete bakery shift, 07:00-14:00]")
	bake["stock"] = {"flour": 60, "butter": 25, "spice": 20, "beans": 30, "milk": 30, "sugar": 15}
	Neighborhood.switch_to(s, "rowan")
	s["story"]["fired"]["rowan_ledger"] = 0   # keep the story out of the way for this test
	var sim := Simulation.new(s)
	var funds_before := int(s["households"]["rowan"]["funds"])
	run_to(sim, 1, 7); sim.advance_minutes(2)
	check(bake["is_open"], "bakery opens itself at 07:00 when family is home")
	var saw_customer := false; var saw_staff := false
	var mid_saved := false
	while sim.minute() < 14 * 60 + 2:
		sim.tick()
		if not saw_customer: saw_customer = s["characters"].values().any(func(c): return c["ai"] == "customer")
		if not saw_staff: saw_staff = s["characters"].values().any(func(c): return c["current"].get("type", "") == "work_register" and c["current"].get("phase", "") == "perform")
		if not mid_saved and sim.minute() == 10 * 60:
			mid_saved = true
			var ss := SaveSystem.new("user://test_saves_biz")
			var sv := ss.save("mid", s); if not sv["ok"]: print("    save error: ", sv["error"])
			var l := ss.load_game("mid")
			var a := JSON.stringify(l.get("state", {}), "", true); var bb := JSON.stringify(GameState.normalize(s), "", true)
			check(l["ok"] and a == bb, "mid-shift save reloads exactly (customers, orders, stock)")
			if a != bb:
				var i := 0
				while i < mini(a.length(), bb.length()) and a[i] == bb[i]: i += 1
				print("    diff: …", bb.substr(maxi(0, i - 120), 200), "…  vs  …", a.substr(maxi(0, i - 120), 200), "… err=", l.get("error", ""))
	check(saw_customer, "customers came in")
	check(saw_staff, "a family member worked the register")
	check(not bake["is_open"], "bakery closes itself at 14:00")
	var sm: Dictionary = bake["last_summary"]
	print("    summary: ", sm)
	check(int(sm["served"]) > 5, "served customers during the shift (%d)" % int(sm["served"]))
	check(sm["reconciled"] and int(sm["funds_delta"]) == int(sm["profit"]), "ledger reconciles with the household balance")
	check(int(s["households"]["rowan"]["funds"]) - funds_before == int(sm["profit"]), "household funds changed by exactly the shift profit")
	sim.advance_minutes(30)   # give the last customers time to walk out
	var left_customers: Array = s["characters"].values().filter(func(c): return c["ai"] == "customer")
	var reserved_total := 0
	for k in bake["reserved"]: reserved_total += int(bake["reserved"][k])
	check(left_customers.is_empty() and reserved_total == 0 and bake["orders"].is_empty(), "after closing: no customers left, no reserved stock, no open orders")
	check(sim.events.any(func(e): return e["kind"] == "shift"), "shift summary reported to the player")
	print("[florist shift with a story boost]")
	Neighborhood.switch_to(s, "alvarez")
	for k in s["story"]["pending"].duplicate(): s["story"]["pending"].erase(k)
	for bid in ["alvarez_stall", "alvarez_nursery", "alvarez_inn_order", "alvarez_rebrand", "alvarez_end"]: s["story"]["fired"][bid] = 0
	var plain := Business.demand(s, flor, 12)
	s["story"]["flags"]["inn_flowers"] = true
	check(Business.demand(s, flor, 12) > plain, "story outcome (flowers at the inn) boosts florist demand")
	flor["stock"] = {"stems": 200, "wrap": 20, "pots": 10}
	run_to(sim, 2, 17); sim.advance_minutes(3)
	var fs: Dictionary = flor["last_summary"]
	check(not fs.is_empty() and int(fs["served"]) > 0 and fs["reconciled"], "florist completes a reconciled shift (%s served)" % str(fs.get("served", 0)))
	print("business: %d passed, %d failed" % [passes, fails])
	quit(1 if fails else 0)
