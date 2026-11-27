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

func run() -> void:
	print("SMOKE start")
	for i in 6:
		var t0 := Time.get_ticks_msec(); await m.get_tree().process_frame
		print("  frame %d took %d ms" % [i, Time.get_ticks_msec() - t0])
	await shot("01_title")
	m.menus.show_presets(); m._show_title_scene("jin"); await wait(20)
	await shot("02_presets")
	m.start_new("mara"); await wait(30)
	await shot("03_bungalow_morning")
	var me: Dictionary = m.sim.controlled()
	check(m.sim.funds() == 60000 and m.sim.minute() == 480, "starts 600.00 at 08:00")
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
	var snap := JSON.stringify(m.sim.state, "", true)
	m.save_game(); m.sim.advance_minutes(30); m.load_game(); await wait(10)
	check(JSON.stringify(m.sim.state, "", true) == snap, "reload restores exact state")
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
