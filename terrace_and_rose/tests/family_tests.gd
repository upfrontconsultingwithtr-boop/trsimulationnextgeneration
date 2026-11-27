extends SceneTree
## Family life + creator + cheats. Run: godot --headless --path . -s tests/family_tests.gd
var fails := 0
var passes := 0
func check(c: bool, n: String) -> void:
	print("  %s  %s" % ["PASS" if c else "FAIL", n])
	if c: passes += 1
	else: fails += 1

func _init() -> void:
	var s := Neighborhood.build()
	print("[creator]")
	var hid := FamilyLife.new_household(s, "The Vegas")
	check(FamilyLife.move_in(s, hid, "lot_willow")["ok"] == false, "empty household can't move in")
	var a := FamilyLife.add_member(s, hid, {"name": "Rosa Vega", "pronouns": "she/her", "age": "adult", "can_carry": true, "look": {"body": "curvy", "skin": "8a5537", "hair": "coils"}, "traits": ["warm", "bold"]})
	var b := FamilyLife.add_member(s, hid, {"name": "Tomas Vega", "pronouns": "he/him", "age": "adult", "look": {"body": "slender", "skin": "f3d6bf", "hair": "wavy"}, "traits": ["goofy"]})
	check(FamilyLife.set_tie(s, a, b, "spouse")["ok"], "set spouses")
	var kid := FamilyLife.add_child_from_parents(s, a, b, 1234)
	var k: Dictionary = s["characters"][kid]
	check(k["age"] == "child" and k["genes"]["parents"] == [a, b], "child made from two parents records both")
	check(k["look"]["hair_gene"] in ["coils", "wavy"] and k["name"].ends_with("Vega"), "child inherits a parent's hair texture and surname")
	check(s["family"].filter(func(t): return t["b"] == kid and t["type"] == "parent_of").size() == 2, "both parents linked in the family tree")
	var t2 := FamilyLife.child_spec(s, a, b, 1234); var t3 := FamilyLife.child_spec(s, a, b, 9876)
	check(t2["look"] == k["look"] and t3["look"] != t2["look"], "re-roll gives a different child; same seed reproduces")
	var kid2 := FamilyLife.add_child_from_parents(s, a, b, 55)
	check(s["family"].any(func(t): return t["type"] == "sibling" and ((t["a"] == kid and t["b"] == kid2) or (t["a"] == kid2 and t["b"] == kid))), "new child becomes sibling of existing child")
	check(not FamilyLife.set_tie(s, kid, kid2, "spouse")["ok"], "children can't be partners")
	FamilyLife.edit_member(s, kid, {"name": "Luz Vega", "look": {"top": "c2643f"}})
	check(s["characters"][kid]["name"] == "Luz Vega" and s["characters"][kid]["look"]["top"] == "c2643f", "edit household member later")
	check(FamilyLife.move_in(s, hid, "lot_rowan")["ok"] == false, "can't move into an occupied home")
	check(FamilyLife.move_in(s, hid, "lot_willow")["ok"] and s["lots"]["lot_willow"]["household"] == hid, "move into the empty lot")
	check(GameState.validate(s).is_empty(), "state valid after creating a household")
	var single := FamilyLife.new_household(s, "Solo")
	FamilyLife.add_member(s, single, {"name": "Ana Solo", "age": "adult"})
	var r := FamilyLife.adopt(s, single, 7)
	check(r["ok"] and s["characters"][r["id"]]["adopted"] and int(s["households"][single]["funds"]) == FamilyLife.NEW_HOUSEHOLD_FUNDS - FamilyLife.ADOPTION_FEE, "single parent adopts (fee charged)")
	var teens := FamilyLife.new_household(s, "Teens only")
	FamilyLife.add_member(s, teens, {"name": "Kid", "age": "teen"})
	check(not FamilyLife.validate_household(s, teens).is_empty(), "household without an adult is rejected")

	print("[try for baby -> pregnancy -> birth]")
	check(not FamilyLife.baby_eligibility(s, "theo", "delia")["ok"], "teens can't try for a baby")
	check(not FamilyLife.baby_eligibility(s, "june", "iris")["ok"], "requires a romantic relationship")
	Neighborhood.switch_to(s, "alvarez")
	var sim := Simulation.new(s)
	var pregnant := false
	for attempt in 6:
		var res := FamilyLife.conceive(s, "lucia", "gabriel", 100 + attempt)
		if res["pregnant"]: pregnant = true; break
	check(pregnant and s["pregnancies"][0]["carrier"] == "lucia", "Lucia becomes pregnant (seeded chance)")
	check(not FamilyLife.baby_eligibility(s, "lucia", "gabriel")["ok"], "can't conceive again while expecting")
	var before: int = s["households"]["alvarez"]["members"].size()
	sim.advance_minutes(FamilyLife.PREGNANCY_DAYS * 1440 + 2)
	var after: int = s["households"]["alvarez"]["members"].size()
	check(after > before and s.get("pregnancies", []).is_empty(), "baby is born after the pregnancy (%d new)" % (after - before))
	var baby: Dictionary = s["characters"][s["households"]["alvarez"]["members"][-1]]
	check(baby["genes"]["parents"].has("lucia") and baby["genes"]["parents"].has("gabriel") and baby["lot"] == "lot_alvarez", "baby carries DNA from both parents and lives at home")
	print("[aging]")
	var t: Dictionary = s["characters"]["theo"]
	s["settings"]["aging"] = false; var age0: String = t["age"]
	sim.advance_minutes(8 * 1440)
	check(t["age"] == age0, "aging off: nobody ages")
	s["settings"]["aging"] = true; t["age_days"] = 0
	sim.advance_minutes(8 * 1440)
	check(t["age"] == "adult", "aging on: teen grows into an adult")

	print("[cheats]")
	var key := Crypto.new().generate_rsa(2048)
	var pub := "user://test_cheat_pub.pem"; key.save(pub, true)
	var code := Cheats.make_code(key, "Ricardo")
	check(Cheats.verify("Ricardo", code, pub), "owner-issued code verifies")
	check(Cheats.verify("ricardo ", code, pub), "name match ignores case/spacing")
	check(not Cheats.verify("Someone Else", code, pub), "code can't be reused under another name")
	var other := Crypto.new().generate_rsa(2048)
	check(not Cheats.verify("Ricardo", Cheats.make_code(other, "Ricardo"), pub), "codes signed by any other key are rejected")
	check(not Cheats.verify("Ricardo", "not-a-code", pub), "garbage code rejected")
	Neighborhood.switch_to(s, "rowan")
	var f0 := int(s["households"]["rowan"]["funds"])
	check(Cheats.run(s, "money 250")["ok"] and int(s["households"]["rowan"]["funds"]) == f0 + 25000, "money cheat adds 250.00")
	Cheats.run(s, "needs max")
	check(s["characters"]["hazel"]["needs"]["hunger"] == GameState.NEED_MAX, "needs cheat fills needs")
	check(Cheats.run(s, "pregnant june")["ok"] == false, "pregnancy cheat respects partner requirement")
	s["settings"]["shared"] = true
	check(not Cheats.run(s, "money 1000")["ok"], "cheats disabled in shared worlds")
	print("family: %d passed, %d failed" % [passes, fails])
	quit(1 if fails else 0)
