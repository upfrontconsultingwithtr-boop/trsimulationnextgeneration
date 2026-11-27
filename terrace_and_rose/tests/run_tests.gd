extends SceneTree
## Headless regression tests for Milestone 1 core rules.
## Run: godot --headless --path . -s tests/run_tests.gd

var passed := 0
var failed: Array[String] = []

func check(cond: bool, name: String) -> void:
	if cond: passed += 1; print("  PASS  ", name)
	else: failed.append(name); print("  FAIL  ", name)

func fresh(preset: String = "mara") -> Simulation:
	return Simulation.new(GameState.new_alder_game(preset))

func run_until_idle(sim: Simulation, cid: String, max_minutes: int = 900) -> void:
	for i in max_minutes * GameState.TICKS_PER_MINUTE:
		sim.tick()
		var c := sim.character(cid)
		if c["current"].is_empty() and c["queue"].is_empty(): return

func _init() -> void:
	print("Terrace & Rose — headless regression tests")
	test_layout_and_start()
	test_day_loop()
	test_chair_undo_redo()
	test_structure_editor()
	test_invalid_placement()
	test_unreachable_and_reservations()
	test_removed_object_releases()
	test_pause_and_fast_visitor()
	test_save_load_and_corruption()
	test_world_snapshots()
	print("\n%d passed, %d failed" % [passed, failed.size()])
	for f in failed: print("  failed: ", f)
	quit(0 if failed.is_empty() else 1)

func test_layout_and_start() -> void:
	print("[start state]")
	var sim := fresh()
	check(sim.funds() == 60000, "household starts with 600.00")
	check(sim.minute() == 480, "clock starts at 08:00")
	check(GameState.hour_text(sim.minute()) == "Day 1 · 08:00", "clock text")
	check(GameState.validate(sim.state).is_empty(), "initial state validates")
	var f := Furnishing.new(sim)
	var bad := 0
	for fid in sim.furniture("lot1"):
		var r: Dictionary = sim.furniture("lot1")[fid]
		if not f.can_place(r["item"], GameState.cell_of(r["cell"]), int(r["rot"]), fid)["ok"]: bad += 1; print("    starter item invalid: ", r)
	check(bad == 0, "all starter furniture placements are valid")
	var counters := 0
	for fid in sim.furniture("lot1"): if sim.furniture("lot1")[fid]["item"] == "prep_counter": counters += 1
	check(counters >= 1, "starter home has a kitchen counter")
	for cid in sim.state["characters"]: check(sim.state["characters"][cid]["id"] == cid, "stable id " + cid)

func test_day_loop() -> void:
	print("[acceptance: prepare, eat, greet, sit, sleep]")
	var sim := fresh("jin")
	var me := sim.controlled()
	me["needs"]["hunger"] = 2000; me["needs"]["energy"] = 2000; me["needs"]["comfort"] = 2000
	check(sim.queue_action("c1", "walk", "", Vector2i(16, 16))["ok"], "queue walk")
	run_until_idle(sim, "c1")
	check(GameState.cell_of(me["cell"]) == Vector2i(16, 16), "walk reaches target cell")
	sim.queue_action("c1", "prepare_meal")
	run_until_idle(sim, "c1")
	check(me["holding"] == "meal", "prepare meal produces a meal")
	var h0: int = me["needs"]["hunger"]
	sim.queue_action("c1", "eat")
	run_until_idle(sim, "c1")
	check(me["holding"] == "" and int(me["needs"]["hunger"]) > h0 + 4000, "eating consumes meal and restores hunger")
	check(sim.state["reservations"].is_empty(), "no reservations left after eating")
	# wait for the visitor
	while sim.minute() < 640: sim.tick()
	var n := sim.character("c2")
	check(n["lot"] == "lot1", "neighbor has arrived by 10:40")
	var s0: int = me["needs"]["social"]
	sim.queue_action("c1", "greet", "c2")
	run_until_idle(sim, "c1")
	var rel: Dictionary = sim.state["relationships"].get(GameState.rel_key("c1", "c2"), {})
	check(rel.get("friendship", 0) == 10 and rel.get("met", false), "greet creates relationship")
	check(int(me["needs"]["social"]) > s0, "greet raises social")
	var c0: int = me["needs"]["comfort"]
	sim.queue_action("c1", "sit")
	for i in 40: sim.tick()
	check(me["pose"] == "sit" or not me["current"].is_empty(), "sit action seats or approaches")
	run_until_idle(sim, "c1")
	check(int(me["needs"]["comfort"]) > c0 and me["pose"] == "stand", "sit raises comfort and stands up after")
	var e0: int = me["needs"]["energy"]
	sim.queue_action("c1", "sleep")
	run_until_idle(sim, "c1")
	check(int(me["needs"]["energy"]) > e0 + 3000 and me["pose"] == "stand", "sleep restores energy, control returns")
	check(me["current"].is_empty() and me["queue"].is_empty(), "queue empty after day loop")
	var held := 0
	for fid in sim.state["reservations"]: for s in sim.state["reservations"][fid]: if sim.state["reservations"][fid][s] == "c1": held += 1
	check(held == 0, "player holds no reservations when idle")

func test_chair_undo_redo() -> void:
	print("[acceptance: chair purchase, undo, redo]")
	var sim := fresh()
	var f := Furnishing.new(sim)
	var n0: int = sim.furniture("lot1").size()
	var r := f.buy("chair", Vector2i(24, 15), 0)
	check(r["ok"], "buy chair at open spot")
	check(sim.funds() == 56500 and Catalog.format_cents(sim.funds()) == "565.00", "funds 600.00 -> 565.00")
	check(sim.furniture("lot1").size() == n0 + 1, "chair added")
	check(f.undo()["ok"] and sim.funds() == 60000 and sim.furniture("lot1").size() == n0, "undo refunds to 600.00 and removes chair")
	check(f.redo()["ok"] and sim.funds() == 56500 and sim.furniture("lot1").has(r["id"]), "redo re-buys the same chair (565.00)")
	check(f.undo()["ok"] and f.undo()["ok"] == false and sim.funds() == 60000, "history bottom is safe")

func test_invalid_placement() -> void:
	print("[acceptance: blocked placement leaves state unchanged]")
	var sim := fresh()
	var f := Furnishing.new(sim)
	var before := JSON.stringify(sim.state)
	var cases := [["chair", Vector2i(4, 10), "wall"], ["chair", Vector2i(17, 4), "on counter"], ["bed", Vector2i(14, 19), "doorway"], ["chair", Vector2i(40, 3), "outside lot"], ["chair", Vector2i(16, 22), "on actor"]]
	for cs in cases:
		var r := f.buy(cs[0], cs[1], 0)
		check(not r["ok"] and r["reason"] != "", "rejects %s with reason: %s" % [cs[2], r["reason"]])
	check(JSON.stringify(sim.state) == before and f.undo_stack.is_empty(), "funds, furniture and history unchanged")
	sim.household()["funds"] = 1000
	check(not f.buy("bed", Vector2i(22, 14), 0)["ok"] and sim.funds() == 1000, "insufficient funds rejected without charge")

func test_unreachable_and_reservations() -> void:
	print("[acceptance: unreachable interaction]")
	var sim := fresh()
	sim.queue_action("c1", "walk", "", Vector2i(6, 1))   # garden bed (blocked)
	for i in 8: sim.tick()
	check(sim.controlled()["current"].is_empty() and sim.events.any(func(e): return e["kind"] == "error"), "walk to blocked cell fails with feedback")
	# box in a chair with shelves so its approach cells are unreachable
	var f := Furnishing.new(sim)
	var r := f.buy("chair", Vector2i(24, 17), 0)
	check(r["ok"], "place test chair")
	for p in [[Vector2i(24, 18), 0], [Vector2i(23, 16), 1], [Vector2i(25, 16), 1]]:
		check(f.buy("shelf", p[0], p[1])["ok"], "box in chair with shelf %s" % [p[0]])
	sim.events.clear()
	var funds0 := sim.funds()
	sim.queue_action("c1", "sit", r["id"])
	for i in 8: sim.tick()
	var me := sim.controlled()
	var failed_ok: bool = me["current"].is_empty() and sim.events.any(func(e): return e["kind"] == "error")
	check(failed_ok, "unreachable sit fails with feedback")
	check(not sim.state["reservations"].has(r["id"]), "no reservation left on unreachable chair")
	check(sim.funds() == funds0, "no charge for failed interaction")
	sim.queue_action("c1", "walk", "", Vector2i(16, 16))
	run_until_idle(sim, "c1")
	check(GameState.cell_of(me["cell"]) == Vector2i(16, 16), "actor is not stuck afterwards")

func test_removed_object_releases() -> void:
	print("[reservations release on cancel/removal]")
	var sim := fresh()
	var f := Furnishing.new(sim)
	sim.queue_action("c1", "sit", "")
	for i in 3: sim.tick()
	var cur: Dictionary = sim.controlled()["current"]
	check(sim.state["reservations"].size() == 1, "seat reserved while approaching")
	sim.cancel_action("c1")
	check(sim.state["reservations"].is_empty(), "cancel releases reservation")
	sim.queue_action("c1", "sit", "")
	run_until_idle(sim, "c1", 0)
	for i in 200:
		sim.tick()
		if sim.controlled()["pose"] == "sit": break
	var fid: String = sim.controlled()["current"]["target"]
	check(sim.controlled()["pose"] == "sit", "seated")
	f.sell(fid)
	check(sim.controlled()["current"].is_empty() and sim.controlled()["pose"] == "stand" and not sim.state["reservations"].has(fid), "selling an in-use chair stands the actor up and releases it")

func test_pause_and_fast_visitor() -> void:
	print("[acceptance: pause and fast speed]")
	var sim := fresh()
	sim.set_speed(0)
	var m0 := sim.minute()
	var needs0: Dictionary = sim.controlled()["needs"].duplicate()
	var acc := 0.0
	for frame in 600:   # 10 s of frames at 60 fps through the same accumulator the game uses
		acc += (1.0 / 60.0) * Simulation.SPEED_TICKS[int(sim.state["speed"])]
		while acc >= 1.0: acc -= 1.0; sim.tick()
	check(sim.minute() == m0 and sim.controlled()["needs"] == needs0, "paused: time and needs do not advance")
	sim.set_speed(2)
	while sim.minute() < 16 * 60:
		acc += (1.0 / 30.0) * Simulation.SPEED_TICKS[int(sim.state["speed"])]
		while acc >= 1.0: acc -= 1.0; sim.tick()
	check(int(sim.state["stats"]["arrivals"].get("c2", 0)) == 1, "visitor arrives exactly once at fast speed")
	check(sim.character("c2")["lot"] == "" , "visitor left at 15:00")
	var mid := fresh(); mid.advance_minutes(119)
	check(mid.character("c2")["lot"] == "", "visitor not present before 10:00")
	mid.advance_minutes(2)
	check(mid.character("c2")["lot"] == "lot1", "visitor present at 10:00")

func test_save_load_and_corruption() -> void:
	print("[acceptance: save, reload, corruption recovery]")
	var dir := "user://test_saves"
	for fn in ["slot.json", "slot.bak.json", "slot.tmp.json"]:
		if FileAccess.file_exists(dir.path_join(fn)): DirAccess.remove_absolute(dir.path_join(fn))
	var ss := SaveSystem.new(dir)
	var sim := fresh("ellis")
	var f := Furnishing.new(sim)
	f.buy("chair", Vector2i(24, 15), 0)
	sim.advance_minutes(37)
	sim.controlled()["needs"]["hunger"] = 4321
	sim.state["relationships"][GameState.rel_key("c1", "c2")] = {"friendship": 20, "met": true}
	check(ss.save("slot", sim.state)["ok"], "first save ok")
	var l := ss.load_game("slot")
	check(l["ok"] and l["from"] == "primary", "load primary")
	var s2: Dictionary = l["state"]
	check(s2["characters"]["c1"]["preset"] == "ellis", "avatar preset restored")
	check(int(s2["households"]["h1"]["funds"]) == 56500, "funds restored")
	check(int(s2["minute"]) == 480 + 37, "clock restored")
	check(int(s2["characters"]["c1"]["needs"]["hunger"]) == 4321, "needs restored")
	check(s2["lots"]["lot1"]["furniture"].size() == sim.furniture("lot1").size(), "furniture restored")
	check(int(s2["relationships"][GameState.rel_key("c1", "c2")]["friendship"]) == 20, "relationships restored")
	check(JSON.stringify(s2, "", true) == JSON.stringify(sim.state, "", true), "round trip is exact")
	var sim2 := Simulation.new(s2)
	sim2.advance_minutes(10)
	check(sim2.minute() == 527, "reloaded world keeps simulating")
	# second save rotates first into backup
	sim.advance_minutes(5)
	check(ss.save("slot", sim.state)["ok"] and FileAccess.file_exists(ss.backup("slot")), "second save keeps backup")
	var bak_text := FileAccess.get_file_as_string(ss.backup("slot"))
	# corrupt the primary
	var fw := FileAccess.open(ss.primary("slot"), FileAccess.WRITE); fw.store_string("{\"format\": \"terrace_and_rose_save\", \"vers"); fw.close()
	var l2 := ss.load_game("slot")
	check(l2["ok"] and l2["from"] == "backup" and l2["warning"] != "", "corrupt primary recovers from backup")
	check(FileAccess.get_file_as_string(ss.backup("slot")) == bak_text, "backup untouched by load")
	# tampered numbers fail checksum
	var t := SaveSystem.encode(sim.state).replace("\"funds\": 56500", "\"funds\": 99999999")
	check(not SaveSystem.decode(t)["ok"], "tampered save rejected by checksum")
	# saving over a corrupt primary must not overwrite the good backup
	fw = FileAccess.open(ss.primary("slot"), FileAccess.WRITE); fw.store_string("garbage"); fw.close()
	check(ss.save("slot", sim.state)["ok"] and FileAccess.get_file_as_string(ss.backup("slot")) == bak_text, "save over corrupt primary keeps prior backup")
	# both damaged: no crash, clear error
	fw = FileAccess.open(ss.primary("slot"), FileAccess.WRITE); fw.store_string("x"); fw.close()
	fw = FileAccess.open(ss.backup("slot"), FileAccess.WRITE); fw.store_string("y"); fw.close()
	var l3 := ss.load_game("slot")
	check(not l3["ok"] and l3["error"] != "", "both saves damaged -> graceful error")
	check(not ss.save("slot", {"bad": true})["ok"], "invalid state is never written")


func test_structure_editor() -> void:
	print("[home editor]")
	var sim := fresh()
	var editor := Furnishing.new(sim)
	var start := sim.funds()
	var wall := Vector2i(2, 16)
	var opening := Vector2i(2, 17)
	var floor_cell := Vector2i(3, 17)
	check(editor.edit_structure("wall", wall, false)["ok"], "place wall")
	check(not sim.walkable("lot1", wall), "wall updates navigation")
	check(not editor.can_place("plant", wall, 0)["ok"], "furniture respects edited walls")
	check(editor.edit_structure("door", opening, true)["ok"], "place two-cell door")
	check(sim.tile("lot1", opening + Vector2i.DOWN) == "D", "vertical orientation applies to both cells")
	check(editor.edit_structure("floor", floor_cell, false)["ok"], "lay walnut flooring")
	check(sim.funds() == start - 13700, "exact funds after construction")
	check(editor.edit_structure("erase", opening + Vector2i.DOWN, false)["ok"], "remove from either half of door")
	check(sim.tile("lot1", opening) == " ", "opening erased as a pair")
	check(editor.undo()["ok"] and sim.tile("lot1", opening) == "D", "undo restores paired opening")
	check(editor.redo()["ok"] and sim.tile("lot1", opening) == " ", "redo removes paired opening")
	var front := Vector2i(4, 3)
	check(editor.edit_structure("window", front, false)["ok"], "replace two wall cells with a window")
	check(editor.undo()["ok"] and sim.tile("lot1", front) == "#", "undo restores original wall")
	check(editor.redo()["ok"] and sim.tile("lot1", front + Vector2i.RIGHT) == "W", "redo restores both halves of window")
	check(not editor.edit_structure("wall", Vector2i(15, 31), false)["ok"], "gate cannot be blocked")
	check(not editor.edit_structure("wall", Vector2i(6, 5), false)["ok"], "furniture footprint cannot be blocked")
	check(not editor.edit_structure("wall", GameState.cell_of(sim.controlled()["cell"]), false)["ok"], "character cannot be built over")
	var save := SaveSystem.decode(SaveSystem.encode(sim.state))
	check(save["ok"], "edited save round trips")
	if save["ok"]:
		var loaded := Simulation.new(save["state"])
		check(loaded.tile("lot1", floor_cell) == "." and not loaded.walkable("lot1", wall), "reload restores flooring and blocked navigation")
	sim.household()["funds"] = 0
	check(not editor.edit_structure("wall", Vector2i(2, 19), false)["ok"] and sim.tile("lot1", Vector2i(2, 19)) == " ", "unaffordable edits leave lot unchanged")

func test_world_snapshots() -> void:
	print("[private God Mode snapshots]")
	var directory := "user://test_snapshots_%d" % Time.get_ticks_usec()
	var snapshots := WorldSnapshots.new(directory)
	var sim := fresh()
	var hood := Neighborhood.build()
	var editor := Furnishing.new(sim)
	check(editor.edit_structure("wall", Vector2i(2, 16), false)["ok"], "checkpoint fixture has a construction edit")
	sim.queue_action("c1", "prepare_meal")
	sim.advance_minutes(1)
	var checkpoint := GameState.checksum(sim.state)
	check(snapshots.capture(sim.state, 1)["ok"], "captures a private world with an action in progress")
	check(not snapshots.has_snapshot(hood, 1), "Alder and neighborhood checkpoints have separate slots")
	sim.advance_minutes(13)
	var later := GameState.checksum(sim.state)
	var restored := snapshots.restore(sim.state, 1)
	check(restored["ok"] and GameState.checksum(restored.get("state", {})) == checkpoint, "restore includes edited structure, funds, needs, clock, and queued and current actions")
	check(GameState.checksum(sim.state) == later, "reading a restore leaves the live world intact until it is applied")
	var rollback := snapshots.restore(restored["state"], WorldSnapshots.BEFORE_RESTORE)
	check(rollback["ok"] and GameState.checksum(rollback.get("state", {})) == later, "Before restore returns the complete prior world")
	sim.state["settings"]["shared"] = true
	check(not snapshots.capture(sim.state, 2)["ok"] and not snapshots.restore(sim.state, 1)["ok"], "shared worlds cannot capture or restore")
	sim.state["settings"]["shared"] = false
	check(not snapshots.capture(sim.state, WorldSnapshots.BEFORE_RESTORE)["ok"] and not snapshots.restore(sim.state, 4)["ok"], "only manual slots can be captured and out-of-range slots are rejected")
	check(snapshots.capture(sim.state, 1)["ok"], "a replacement capture can be saved")
	var file := FileAccess.open(directory.path_join("alder_1.json"), FileAccess.WRITE)
	file.store_string("damaged")
	file.close()
	var recovered := snapshots.read_snapshot(sim.state, 1)
	check(recovered["ok"] and recovered.get("from") == "backup" and GameState.checksum(recovered.get("state", {})) == checkpoint, "a damaged snapshot uses its verified backup")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
