extends SceneTree
## Part 2 / Milestone P2-1 tests. Run: godot --headless --path . -s tests/neighborhood_tests.gd
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
	print("[world]")
	var s := Neighborhood.build()
	check(GameState.validate(s).is_empty(), "neighborhood state validates")
	for hid in ["rowan", "park", "bell", "alvarez"]:
		var h: Dictionary = s["households"][hid]
		check(h["members"].size() >= 2 and int(h["funds"]) > 0 and String(h["lot"]) != "", "%s has members, funds and a home" % h["name"])
		check(Neighborhood.family_tree(s, hid)["edges"].size() >= 1, "%s has a family tree" % h["name"])
	check(s["lots"]["lot_willow"]["furniture"].is_empty() and s["lots"]["lot_willow"]["household"] == "", "empty buildable lot is available")
	var sim := Simulation.new(s)
	var f := Furnishing.new(sim)
	var bad := 0
	for lid in s["lots"]:
		s["active_lot"] = lid
		for fid in sim.furniture(lid):
			var r: Dictionary = sim.furniture(lid)[fid]
			if not f.can_place(r["item"], GameState.cell_of(r["cell"]), int(r["rot"]), fid)["ok"]: bad += 1; print("    invalid ", lid, " ", r, " ", f.can_place(r["item"], GameState.cell_of(r["cell"]), int(r["rot"]), fid))
	s["active_lot"] = "lot_rowan"
	check(bad == 0, "every premade home's furniture placement is valid")
	var blended: bool = Neighborhood.family_tree(s, "bell")["edges"].any(func(e): return e["type"] == "stepparent_of")
	check(blended, "Bells are a blended family (step ties)")

	print("[story: choices change what happens next]")
	run_to(sim, 1, 9)
	check(s["story"]["pending"].has("rowan_ledger"), "Rowan opening beat fires at 09:00")
	check(not s["story"]["pending"].has("park_will"), "other households' beats wait until they are played")
	var funds0 := int(s["households"]["rowan"]["funds"])
	check(StoryEngine.choose(s, "rowan_ledger", 2)["ok"], "choose: pitch the inn")
	check(int(s["households"]["rowan"]["funds"]) == funds0 and StoryEngine.has_flag(s, "pitch_inn"), "choice sets a flag without spending")
	check(not StoryEngine.choice_status(s, StoryEngine.beat("rowan_announcement"), 2)["ok"], "locked choice (needs Hazel to mediate) is unavailable")
	check(Neighborhood.switch_to(s, "park")["ok"] and s["controlled"] in ["june", "iris"] and s["active_lot"] == "lot_park", "switch to the Park household")
	run_to(sim, 1, 15)
	check(s["story"]["pending"].has("park_will") and s["story"]["pending"].has("park_baker"), "Delia's pitch unlocks a beat in the Parks' story")
	check(not StoryEngine.choice_status(s, StoryEngine.beat("park_will"), 1)["ok"], "unaffordable buyout is blocked with a reason")
	StoryEngine.choose(s, "park_will", 0)
	var p0 := int(s["households"]["park"]["funds"]); var r0 := int(s["households"]["rowan"]["funds"])
	StoryEngine.choose(s, "park_baker", 0)
	check(int(s["households"]["park"]["funds"]) == p0 - 6000 and int(s["households"]["rowan"]["funds"]) == r0 + 6000, "supply deal moves money between households")
	check(int(s["relationships"][GameState.rel_key("june", "delia")]["friendship"]) >= 15, "cross-household relationship grows")
	Neighborhood.switch_to(s, "alvarez")
	run_to(sim, 2, 11)
	check(s["story"]["pending"].has("alvarez_inn_order"), "running the inn together unlocks the Alvarez flower order")
	StoryEngine.choose(s, "alvarez_stall", 2)
	check(not StoryEngine.has_flag(s, "alvarez_open_to_partners"), "declining Noor closes the Rose & Rye partnership path")
	Neighborhood.switch_to(s, "rowan")
	run_to(sim, 4, 9)
	for b in ["rowan_sketchbook", "rowan_announcement"]: if s["story"]["pending"].has(b): StoryEngine.choose(s, b, 0)
	check(s["story"]["pending"].has("rowan_loan"), "loan beat arrives")
	check(not StoryEngine.choice_status(s, StoryEngine.beat("rowan_loan"), 1)["ok"], "Rose & Rye option locked by the Alvarez decision")
	StoryEngine.choose(s, "rowan_loan", 0)
	run_to(sim, 4, 10)
	check(s["story"]["pending"].has("rowan_end_expand") and not s["story"]["pending"].has("rowan_end_cafe"), "the loan leads to the expansion ending, not the café ending")
	StoryEngine.choose(s, "rowan_end_expand", 0)
	check(StoryEngine.has_flag(s, "ending_expansion"), "ending recorded")

	print("[autonomy and inactive households]")
	var any_auto_acted := false
	for cid in ["hazel", "theo"]:
		var c: Dictionary = s["characters"][cid]
		if not c["current"].is_empty() or int(c["needs"]["hunger"]) > 3000: any_auto_acted = true
	check(any_auto_acted, "household members look after themselves autonomously")
	s["settings"]["inactive_progress"] = false
	var iris_needs: Dictionary = s["characters"]["iris"]["needs"].duplicate()
	sim.advance_minutes(60)
	check(s["characters"]["iris"]["needs"] == iris_needs, "inactive household frozen when progression is off")
	s["settings"]["inactive_progress"] = true
	sim.advance_minutes(60)
	check(s["characters"]["iris"]["needs"] != iris_needs, "inactive household progresses when on")

	print("[saves]")
	var ss := SaveSystem.new("user://test_saves_p2")
	check(ss.save("hood", s)["ok"], "neighborhood saves")
	var l := ss.load_game("hood")
	check(l["ok"] and JSON.stringify(l["state"], "", true) == JSON.stringify(GameState.normalize(s), "", true), "neighborhood reloads exactly (stories, flags, households)")
	# a Milestone-1 (v1) save still loads
	var old := GameState.new_alder_game("mara")
	for k in ["world", "family", "settings", "story"]: old.erase(k)
	old["version"] = 1
	for cid in old["characters"]: old["characters"][cid].erase("traits"); old["characters"][cid].erase("aspiration")
	var txt := JSON.stringify({"format": SaveSystem.FORMAT, "version": 1, "checksum": GameState.checksum(old), "state": old})
	var d := SaveSystem.decode(txt)
	check(d["ok"] and int(d["state"]["version"]) == 2 and d["state"]["world"] == "alder" and int(d["state"]["households"]["h1"]["funds"]) == 60000, "Milestone-1 save migrates to v2 with progress intact")

	print("neighborhood: %d passed, %d failed" % [passes, fails])
	quit(1 if fails else 0)
