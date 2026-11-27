class_name SmokeTest
extends RefCounted
## Graphical smoke test. Run: godot --path . -- --smoke   (add --rendering-method gl_compatibility on software GL)
## Drives the real scene: menu -> preset -> meal -> visitor -> greet -> sit -> furnish -> save/reload -> sleep.
## Screenshots go to build/smoke/. Exits with code 0 on success.

var m: Node
var out := ""
var fails: Array[String] = []

func _init(main: Node) -> void:
	m = main
	out = ProjectSettings.globalize_path("res://").path_join("build/smoke")
	DirAccess.make_dir_recursive_absolute(out)

func wait(frames: int = 10) -> void:
	for i in frames: await m.get_tree().process_frame

func shot(name: String) -> void:
	await wait(3)
	print("  fps=%d draw_calls=%d" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	m.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

func check(c: bool, n: String) -> void:
	print("  %s  %s" % ["PASS" if c else "FAIL", n])
	if not c: fails.append(n)

func until(cond: Callable, max_minutes: int) -> void:
	for i in max_minutes * GameState.TICKS_PER_MINUTE:
		if cond.call(): return
		m.sim.tick()
		if i % 40 == 0: await wait(1)

func quick() -> void:
	await wait(3)
	m.start_new("jin"); await wait(8)
	await shot("q1_hud")
	var me: Dictionary = m.sim.controlled()
	m.sim.queue_action("c1", "sleep")
	await until(func(): return me["pose"] == "lie", 300)
	m.sim.advance_minutes(20)
	m.rig.focus(Vector3(4, 0, 3.5), 7.0); await wait(12)
	await shot("q2_sleep")
	m.sim.cancel_action("c1"); await wait(4)
	m._toggle_furnish(); m._select_item("lamp"); m.ghost_from_mouse = false; m.ghost_cell = Vector2i(24, 15)
	m.rig.focus(Vector3(10, 0, 8), 15.0); await wait(8)
	await shot("q3_furnish")
	m.get_tree().quit(0)

func people() -> void:
	await wait(3)
	m.menus.visible = false
	m._show_title_scene("mara"); await wait(10)
	m.rig.focus(Vector3(8.2, 0.9, 11.4), 6.0); m.rig.pitch = deg_to_rad(-6); m.rig.yaw = deg_to_rad(8); m.rig._apply(); await wait(6)
	await shot("p1_presets")
	for who in ["mara", "jin", "ellis"]:
		var a: Node3D = m.world.avatars["c1" if who == "mara" else "c_" + who]
		m.world.wall_mode = 2
		m.rig.focus(a.position + Vector3(0, 0.95, 0), 1.1); m.rig.pitch = deg_to_rad(-3); m.rig.yaw = deg_to_rad(12); m.rig._apply(); await wait(8)
		await shot("p2_face_" + who)
	m.start_neighborhood("bell"); await wait(4)
	m.sim.state["story"]["pending"].clear(); m.story_open = false; m.hud.hide_story(); m.hud.visible = false
	var i := 0
	for cid in m.sim.state["households"]["bell"]["members"]:
		m.sim.state["characters"][cid]["cell"] = [12 + i * 3, 23]; m.sim.state["characters"][cid]["facing"] = 0; i += 1
		m.sim.state["characters"][cid]["ai"] = "player"
	m.sim.set_speed(0); await wait(30)
	m.rig.focus(Vector3(8.6, 0.9, 11.6), 7.5); m.rig.pitch = deg_to_rad(-8); m.rig.yaw = 0.0; m.rig._apply(); await wait(6)
	await shot("p3_bell_family")
	m.get_tree().quit(0)

func shop() -> void:
	await wait(3)
	m.start_neighborhood("rowan"); await wait(3)
	var s: Dictionary = m.sim.state
	for b in StoryEngine.beats(): if b["household"] == "rowan": s["story"]["fired"][b["id"]] = 0
	s["story"]["pending"].clear(); m.story_open = false; m.hud.hide_story()
	var bake := Business.for_lot(s, "lot_rowan")
	await until(func(): return bake["is_open"] and bake["shift"].get("served", 0) >= 3, 120)
	m.sim.set_speed(1)
	m.rig.focus(Vector3(7.5, 0, 8.6), 9.0); m.rig.pitch = deg_to_rad(-40); m.rig._apply(); await wait(12)
	check(bake["is_open"] and int(bake["shift"].get("served", 0)) >= 3, "bakery open and serving customers")
	await shot("s1_bakery_open")
	m._toggle_business(); await wait(6)
	await shot("s2_business_panel")
	m._toggle_business()
	await until(func(): return not bake["is_open"], 600)
	await wait(6)
	check(not bake["last_summary"].is_empty() and bake["last_summary"]["reconciled"], "shift closed with a reconciled ledger")
	await shot("s3_shift_summary")
	print("SHOP: %d failures" % fails.size())
	m.get_tree().quit(0 if fails.is_empty() else 1)

func creator_flow() -> void:
	await wait(3)
	m._open_creator_new(); await wait(6)
	await shot("c1_creator_start")
	var s: Dictionary = m.sim.state
	var hid: String = m.creator.hid
	m.creator._add("adult"); await wait(2)
	var adults: Array = s["households"][hid]["members"]
	FamilyLife.edit_member(s, adults[0], {"look": {"body": "curvy", "skin": "6b3e26", "hair": "coils", "hair_color": "17120f"}, "can_carry": true})
	FamilyLife.edit_member(s, adults[1], {"look": {"body": "slender", "skin": "f3d6bf", "hair": "long", "hair_color": "c89a5a"}})
	FamilyLife.set_tie(s, adults[0], adults[1], "spouse")
	var kid := FamilyLife.add_child_from_parents(s, adults[0], adults[1], 42)
	m.creator.sel = kid; m.creator._rebuild(); await wait(8)
	await shot("c2_creator_dna_child")
	check(s["characters"][kid]["genes"]["parents"].size() == 2, "creator child has two DNA parents")
	m.creator.finished.emit(hid); await wait(10)
	check(m.playing and m.sim.state["active_household"] == hid and m.sim.state["active_lot"] == "lot_willow", "new household moves into Willow Lane and is playable")
	await shot("c3_willow_lane")
	m._open_pause(); m.menus.show_family(m.sim.state, hid); await wait(4)
	await shot("c4_family_tree")
	m.menus.visible = false; m.hud.visible = true
	m._toggle_cheats(); await wait(3)
	await shot("c5_cheat_console")
	print("CREATOR: %d failures" % fails.size())
	m.get_tree().quit(0 if fails.is_empty() else 1)

func hood() -> void:
	await wait(3)
	m.menus.show_households(false); await wait(4)
	await shot("h1_household_picker")
	m.start_neighborhood("rowan"); await wait(4)
	await until(func(): return m.story_open, 120)
	await wait(4)
	check(m.story_open, "story dialog opens for the Rowans")
	await shot("h2_story_rowan")
	m._on_story_choice("rowan_ledger", 2); await wait(4)
	await shot("h3_story_result")
	m.hud.hide_story(); m.story_open = false; m.sim.set_speed(1)
	m.rig.focus(m.world.house_center, 20.0); await wait(8)
	await shot("h4_rowan_bakery")
	for hid in ["park", "bell", "alvarez"]:
		m._switch_household(hid); m.sim.state["story"]["pending"].clear(); m.story_open = false; m.hud.hide_story()
		m.rig.focus(m.world.house_center, 20.0); await wait(8)
		await shot("h5_" + hid)
	print("HOOD: %d failures" % fails.size())
	m.get_tree().quit(0 if fails.is_empty() else 1)

func run() -> void:
	print("SMOKE start")
	for i in 6:
		var t0 := Time.get_ticks_msec(); await m.get_tree().process_frame
		print("  frame %d took %d ms" % [i, Time.get_ticks_msec() - t0])
	await shot("01_title")
	m.menus.show_presets(); m._show_title_scene("jin"); await wait(20)
	await shot("02_presets")
	m.start_new("mara")
	check(m.sim.funds() == 60000 and m.sim.minute() == 480, "starts 600.00 at 08:00")
	check(m.world.furn_nodes.size() == m.sim.furniture("lot1").size() and m.world.furn_nodes.size() > 10, "all furniture has scene nodes")
	await wait(30)
	check(m.world.avatars.has("c1") and m.world.avatars["c1"].anim != null, "player avatar built with animations")
	await shot("03_bungalow_morning")
	var me: Dictionary = m.sim.controlled()
	m._hotkey_action("prepare_meal")
	await until(func(): return me["current"].get("phase", "") == "perform", 60)
	for i in 30: m.sim.tick()
	m.rig.focus(Vector3(9, 0, 3.5), 8.0); await wait(20)
	await shot("04_cooking")
	await until(func(): return me["holding"] == "meal", 60)
	m._hotkey_action("eat")
	await until(func(): return me["current"].get("phase", "") == "perform", 60)
	await wait(30); await shot("05_eating")
	await until(func(): return me["current"].is_empty() and me["queue"].is_empty(), 60)
	check(me["holding"] == "", "meal eaten")
	await until(func(): return m.sim.character("c2")["lot"] == "lot1", 200)
	await until(func(): return m.sim.character("c2")["pose"] == "sit", 120)
	check(m.sim.character("c2")["lot"] == "lot1", "visitor arrived")
	m._hotkey_action("greet")
	await until(func(): return me["current"].get("phase", "") == "perform", 60)
	m.rig.focus(m.world.avatars["c1"].position, 7.0); await wait(25)
	await shot("06_greeting")
	await until(func(): return me["current"].is_empty(), 30)
	m._hotkey_action("sit")
	await until(func(): return me["pose"] == "sit", 120)
	await wait(40); m.rig.focus(m.world.avatars["c1"].position, 6.0); await wait(20)
	await shot("07_sitting")
	m.sim.cancel_action("c1"); await wait(30)
	check(me["pose"] == "stand", "stand after cancelling sit")
	# furnishing
	m._toggle_furnish(); m._select_item("chair"); m.ghost_from_mouse = false; m.ghost_cell = Vector2i(24, 15)
	m.rig.focus(Vector3(11, 0, 8), 14.0); await wait(10)
	await shot("08_furnish_preview")
	var f0: int = m.sim.funds()
	m._place(); await wait(5)
	check(m.sim.funds() == f0 - 3500, "chair costs 35.00")
	m._history(true); check(m.sim.funds() == f0, "undo refunds chair")
	m._history(false); check(m.sim.funds() == f0 - 3500, "redo re-buys chair")
	m.ghost_cell = Vector2i(4, 10); await wait(5)
	var before: int = m.sim.funds(); m._place()
	check(m.sim.funds() == before, "blocked placement does not charge")
	await shot("09_furnish_blocked")
	m._toggle_furnish()
	# save / reload
	var snap := JSON.stringify(GameState.normalize(m.sim.state), "", true)
	m.save_game(); m.sim.advance_minutes(30); m.load_game()   # compare before any frame can tick the clock
	var now := JSON.stringify(m.sim.state, "", true)
	check(now == snap, "reload restores exact state")
	if now != snap:
		var i := 0
		while i < mini(now.length(), snap.length()) and now[i] == snap[i]: i += 1
		print("    first difference near: …%s… vs …%s…" % [snap.substr(maxi(0, i - 80), 140), now.substr(maxi(0, i - 80), 140)])
	# cutaway modes + night + sleep
	m.world.wall_mode = 0; m.rig.focus(m.world.house_center, 22.0); await wait(30); await shot("10_walls_up_roof")
	m.world.wall_mode = 1
	m._hotkey_action("sleep")
	await until(func(): return me["pose"] == "lie", 300)
	m.sim.advance_minutes(maxi(0, 22 * 60 - m.sim.minute()))
	m.rig.focus(Vector3(4, 0, 3.5), 9.0); await wait(40)
	await shot("11_sleeping_night")
	m.sim.set_speed(2); m.hud.refresh(m.sim, false, 1, ""); await wait(5)
	await shot("12_hud")
	print("SMOKE: %d failures" % fails.size())
	m.get_tree().quit(0 if fails.is_empty() else 1)
