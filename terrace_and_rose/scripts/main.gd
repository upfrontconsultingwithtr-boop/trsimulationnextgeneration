extends Node3D
## Glue between simulation (state), WorldView (3D), Hud/Menus (UI), input and audio.

const SLOT := "household1"
const HOOD_SLOT := "neighborhood"
var story_open := false
var creator: CreatorUI
var preview: AvatarView
var cheat_panel: PanelContainer
var fade: ColorRect
var _speed_before := 1
var sim: Simulation
var furn: Furnishing
var saves := SaveSystem.new()
var world: WorldView
var rig: CameraRig
var hud: Hud
var menus: Menus
var playing := false
var furnishing := false
var acc := 0.0
var ghost: Node3D
var ghost_item := ""
var ghost_rot := 0
var ghost_cell := Vector2i(16, 16)
var ghost_from_mouse := true
var focus_list: Array = []
var focus_idx := -1
var focus_marker: MeshInstance3D
var popup: PopupMenu
var popup_entries: Array = []
var ambient: AudioStreamPlayer
var sfx := {}
var smoke := false
var smoke_runner: RefCounted   # keep a reference so the coroutine survives its awaits

func _ready() -> void:
	InputConfig.apply()
	var args := OS.get_cmdline_user_args()
	WorldView.low_graphics = args.has("--low") or args.has("--smoke") or args.has("--shots") or args.has("--hood") or args.has("--creator")
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.theme = UiTheme.make(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	hud = Hud.new(); root.add_child(hud); hud.visible = false
	menus = Menus.new(); root.add_child(menus)
	creator = CreatorUI.new(); root.add_child(creator); creator.visible = false
	fade = ColorRect.new(); fade.color = Color(0.08, 0.06, 0.05, 0.0); fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(fade)
	popup = PopupMenu.new(); root.add_child(popup); popup.id_pressed.connect(_on_popup)
	cheat_panel = PanelContainer.new(); root.add_child(cheat_panel); cheat_panel.visible = false
	cheat_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); cheat_panel.position.y = 80
	world = WorldView.new(); add_child(world)
	rig = CameraRig.new(); add_child(rig)
	focus_marker = MeshInstance3D.new(); var tor := TorusMesh.new(); tor.inner_radius = 0.42; tor.outer_radius = 0.5; focus_marker.mesh = tor
	var fm := StandardMaterial3D.new(); fm.albedo_color = Palette.BRASS; fm.emission_enabled = true; fm.emission = Palette.BRASS; fm.emission_energy_multiplier = 0.8; focus_marker.material_override = fm
	add_child(focus_marker); focus_marker.visible = false
	_audio()
	_wire_ui()
	menus.has_save = saves.has_save(SLOT)
	menus.has_hood_save = saves.has_save(HOOD_SLOT)
	_show_title_scene("mara")
	menus.show_title()
	smoke = OS.get_cmdline_user_args().has("--smoke") or OS.get_cmdline_user_args().has("--shots") or OS.get_cmdline_user_args().has("--hood") or OS.get_cmdline_user_args().has("--creator")
	if smoke:
		smoke_runner = SmokeTest.new(self)
		if OS.get_cmdline_user_args().has("--creator"): smoke_runner.creator_flow()
		elif OS.get_cmdline_user_args().has("--hood"): smoke_runner.hood()
		elif OS.get_cmdline_user_args().has("--shots"): smoke_runner.quick()
		else: smoke_runner.run()

func _audio() -> void:
	ambient = AudioStreamPlayer.new(); add_child(ambient)
	var st: AudioStreamWAV = AssetLoader.wav("res://assets/audio/ambient_coast.wav")
	if st:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD; st.loop_end = st.data.size() / 2
		ambient.stream = st; ambient.volume_db = -10.0; ambient.play()
	for n in ["ui_click", "ui_error", "chime_done", "knock", "coins", "sizzle"]:
		var p := AudioStreamPlayer.new(); p.stream = AssetLoader.wav("res://assets/audio/%s.wav" % n); p.volume_db = -6.0; add_child(p); sfx[n] = p

func play(n: String) -> void:
	if sfx.has(n): sfx[n].play()

func _wire_ui() -> void:
	hud.speed_pressed.connect(func(i): sim.set_speed(i); play("ui_click"))
	hud.action_pressed.connect(_hotkey_action)
	hud.cancel_pressed.connect(func(id): sim.cancel_action(sim.state["controlled"], id))
	hud.furnish_toggled.connect(_toggle_furnish)
	hud.walls_pressed.connect(func(): world.wall_mode = (world.wall_mode + 1) % 3)
	hud.catalog_pressed.connect(_select_item)
	hud.undo_pressed.connect(func(): _history(true))
	hud.redo_pressed.connect(func(): _history(false))
	hud.menu_pressed.connect(_open_pause)
	menus.new_game.connect(start_new)
	menus.continue_game.connect(load_game)
	menus.preset_highlight.connect(func(p): _show_title_scene(p))
	menus.resume.connect(func(): menus.visible = false; hud.visible = true)
	menus.save_requested.connect(save_game)
	menus.load_requested.connect(func(): load_game(_slot()); menus.visible = false)
	menus.neighborhood_new.connect(start_neighborhood)
	menus.neighborhood_continue.connect(func(): load_game(HOOD_SLOT))
	menus.switch_household.connect(_switch_household)
	menus.toggle_inactive.connect(func(): sim.state["settings"]["inactive_progress"] = not bool(sim.state["settings"]["inactive_progress"]); menus.inactive_on = sim.state["settings"]["inactive_progress"]; menus.show_pause())
	hud.story_choice.connect(_on_story_choice)
	menus.create_household.connect(_open_creator_new)
	menus.edit_household.connect(func(): menus.visible = false; _open_creator(sim.state, sim.state["active_household"], true))
	menus.show_family_cb = func(): menus.show_family(sim.state, sim.state["active_household"])
	menus.toggle_aging.connect(func(): sim.state["settings"]["aging"] = not bool(sim.state["settings"].get("aging", false)); menus.show_family(sim.state, sim.state["active_household"]))
	menus.adopt_child.connect(func():
		var r := FamilyLife.adopt(sim.state, sim.state["active_household"], sim.minute())
		if r["ok"]:
			var c: Dictionary = sim.state["characters"][r["id"]]
			c["lot"] = sim.state["active_lot"]; c["cell"] = sim.controlled()["cell"].duplicate()
			hud.push_log("done", "Welcome home, %s!" % c["name"]); play("chime_done")
		else: hud.push_log("error", r["reason"]); play("ui_error")
		menus.show_family(sim.state, sim.state["active_household"]))
	creator.preview_changed.connect(_show_preview)
	creator.finished.connect(_creator_done)
	creator.cancelled.connect(_creator_cancel)
	menus.quit_to_title.connect(func(): playing = false; hud.visible = false; menus.has_save = saves.has_save(SLOT); menus.has_hood_save = saves.has_save(HOOD_SLOT); _show_title_scene("mara"); menus.show_title())

# ------------------------------------------------------------------ scenes
func _show_title_scene(highlight: String) -> void:
	var s := GameState.new_alder_game(highlight)
	var x := 12
	s["characters"].erase("c2")
	s["households"]["h2"]["members"] = []
	s["characters"]["c1"]["cell"] = [16, 22]
	for pid in GameState.PRESET_ORDER:
		if pid == highlight: continue
		var id: String = "c_" + String(pid)
		s["characters"][id] = GameState.new_character(id, pid, "h1", "lot1", Vector2i(x, 23)); x += 8
		s["characters"][id]["facing"] = 0
	sim = Simulation.new(s)
	world.build(sim, "lot1")
	world.set_time(17 * 60 + 20)
	world.wall_mode = 0
	rig.input_enabled = false
	rig.focus(Vector3(8.2, 0.6, 11.6), 6.5); rig.pitch = deg_to_rad(-12); rig.yaw = deg_to_rad(8); rig.auto_orbit = 0.0; rig._apply()

func start_new(preset: String) -> void:
	_begin(Simulation.new(GameState.new_alder_game(preset)))
	hud.push_log("info", "Welcome to Alder Bungalow. Your neighbor is expected around 10:00.")

func _begin(s: Simulation) -> void:
	sim = s; furn = Furnishing.new(sim)
	world.build(sim, sim.state["active_lot"])
	world.wall_mode = 1
	playing = true; furnishing = false; menus.visible = false; hud.visible = true
	rig.input_enabled = true; rig.auto_orbit = 0.0; rig.dist = 17.0; rig.pitch = deg_to_rad(-45); rig.yaw = deg_to_rad(30)
	rig.focus(world.house_center + Vector3(0, 0, 1.5))
	focus_list.clear(); focus_idx = -1; focus_marker.visible = false
	menus.in_neighborhood = String(sim.state.get("world", "")) == "neighborhood"
	menus.inactive_on = bool(sim.state.get("settings", {}).get("inactive_progress", true))
	story_open = false; hud.hide_story()
	play("chime_done")

func start_neighborhood(hid: String) -> void:
	var s := Neighborhood.build()
	Neighborhood.switch_to(s, hid)
	_begin(Simulation.new(s))
	hud.push_log("info", "Welcome to Terrace & Rose. You're playing %s." % s["households"][hid]["name"])

# ------------------------------------------------------------------ creator
var _creator_new := false
func _open_creator_new() -> void:
	var s := Neighborhood.build()
	var hid := FamilyLife.new_household(s, "The Newcomers")
	var a := FamilyLife.add_member(s, hid, {"name": "Alex Newcomer", "pronouns": "they/them", "age": "adult", "look": GameState.PRESETS["jin"]["look"].duplicate(true)})
	sim = Simulation.new(s)
	world.build(sim, "lot_willow"); world.set_time(11 * 60)
	_creator_new = true
	_open_creator(s, hid, false)

func _open_creator(s: Dictionary, hid: String, is_edit: bool) -> void:
	menus.visible = false; hud.visible = false
	if is_edit: _creator_new = false; sim.set_speed(0)
	rig.input_enabled = false
	rig.focus(Vector3(8.0, 0.9, 8.0), 4.2); rig.pitch = deg_to_rad(-10); rig.yaw = deg_to_rad(0); rig._apply()
	creator.open(s, hid, is_edit)

func _show_preview(cid: String) -> void:
	_clear_preview()
	if cid == "" or not sim.state["characters"].has(cid): return
	var c: Dictionary = sim.state["characters"][cid].duplicate(true)
	c["anchor"] = []; c["cell"] = [16, 15]; c["facing"] = 0; c["pose"] = "stand"
	preview = AvatarView.new(); add_child(preview); preview.setup(c)
	preview.position = Vector3(8.25, 0, 7.75 if not playing else 7.75)
	if playing: preview.position = world.house_center + Vector3(0, 0, 2)
	rig.focus(preview.position + Vector3(0, 0.9 * ({"child": 0.62, "teen": 0.9}.get(c["age"], 1.0)), 0), 4.2)

func _clear_preview() -> void:
	if preview: preview.queue_free(); preview = null

func _creator_cancel() -> void:
	creator.visible = false; _clear_preview()
	if playing and not _creator_new: hud.visible = true; rig.input_enabled = true; sim.set_speed(1)
	else: playing = false; _show_title_scene("mara"); menus.show_title()

func _creator_done(hid: String) -> void:
	creator.visible = false; _clear_preview()
	if _creator_new:
		var r := FamilyLife.move_in(sim.state, hid, "lot_willow")
		if not r["ok"]: hud.push_log("error", r["reason"]); return
		Neighborhood.switch_to(sim.state, hid)
		_begin(sim)
		hud.push_log("info", "%s moved into Willow Lane with %s. Press B to furnish your new home." % [sim.household()["name"], Catalog.format_cents(sim.funds())])
	else:
		hud.visible = true; rig.input_enabled = true; sim.set_speed(1)
		hud.push_log("done", "Household saved.")

# ------------------------------------------------------------------ cheats
func _toggle_cheats() -> void:
	if cheat_panel.visible: cheat_panel.visible = false; return
	for c in cheat_panel.get_children(): c.queue_free()
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 560; cheat_panel.add_child(v)
	v.add_child(UiTheme.title_label("Cheat console", 22))
	var out := Label.new(); out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; out.custom_minimum_size.x = 540
	if bool(sim.state.get("settings", {}).get("shared", false)):
		out.text = "Cheats are disabled in shared worlds."; v.add_child(out); cheat_panel.visible = true; return
	var who := Cheats.unlocked_name()
	if who == "":
		if not FileAccess.file_exists(Cheats.PUBLIC_KEY):
			out.text = "The owner hasn't set up cheat keys yet. See README → Cheat codes."
			v.add_child(out); cheat_panel.visible = true; return
		var n := LineEdit.new(); n.placeholder_text = "Your name (as issued)"; v.add_child(n)
		var code := LineEdit.new(); code.placeholder_text = "Access code"; v.add_child(code)
		var b := Button.new(); b.text = "Unlock"; v.add_child(b); v.add_child(out)
		b.pressed.connect(func():
			if Cheats.unlock(n.text, code.text): _toggle_cheats(); _toggle_cheats()
			else: out.text = "That code isn't valid for that name.")
		cheat_panel.visible = true; n.grab_focus.call_deferred(); return
	out.text = "Access: %s. %s" % [who, Cheats.HELP]
	var line := LineEdit.new(); line.placeholder_text = "e.g. money 500"
	line.text_submitted.connect(func(t):
		var r := Cheats.run(sim.state, t); out.text = r["text"]; line.clear()
		play("coins" if r["ok"] else "ui_error"))
	v.add_child(line); v.add_child(out)
	cheat_panel.visible = true; line.grab_focus.call_deferred()

func _fade_moment(text: String) -> void:
	hud.push_log("info", text)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.96, 0.6)
	tw.tween_interval(1.4)
	tw.tween_property(fade, "color:a", 0.0, 0.8)

func _switch_household(hid: String) -> void:
	var r := Neighborhood.switch_to(sim.state, hid)
	if not r["ok"]: hud.push_log("error", r["reason"]); return
	_begin(sim)
	hud.push_log("info", "Now playing %s." % sim.household()["name"])

func _slot() -> String: return HOOD_SLOT if String(sim.state.get("world", "alder")) == "neighborhood" else SLOT

func _open_story_if_pending() -> void:
	if story_open or sim.state["story"]["pending"].is_empty() or furnishing: return
	story_open = true
	_speed_before = maxi(1, int(sim.state["speed"])); sim.set_speed(0)
	hud.show_story(sim.state, sim.state["story"]["pending"][0])

func _on_story_choice(beat_id: String, idx: int) -> void:
	var title: String = StoryEngine.beat(beat_id)["title"]
	var r := StoryEngine.choose(sim.state, beat_id, idx)
	if not r["ok"]: hud.push_log("error", r["text"]); play("ui_error"); return
	play("chime_done")
	hud.show_story_result(title, r["text"], func():
		hud.hide_story(); story_open = false
		if sim.state["story"]["pending"].is_empty(): sim.set_speed(_speed_before)
		else: _open_story_if_pending())

func save_game() -> void:
	var r := saves.save(_slot(), sim.state)
	hud.push_log("save" if r["ok"] else "error", "Game saved." if r["ok"] else "Save failed: %s" % r["error"])
	play("chime_done" if r["ok"] else "ui_error")

func load_game(slot: String = SLOT) -> void:
	if playing and slot == SLOT: slot = _slot()
	var r := saves.load_game(slot)
	if not r["ok"]:
		hud.push_log("error", r["error"]); play("ui_error")
		if not playing: menus.show_title()
		return
	_begin(Simulation.new(r["state"]))
	hud.push_log("info", "Loaded save (%s)." % r["from"])
	if r["warning"] != "": hud.push_log("error", r["warning"])

func _open_pause() -> void:
	if not playing: return
	sim.set_speed(0); hud.visible = false; menus.show_pause()

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	if playing and not menus.visible:
		acc += delta * Simulation.SPEED_TICKS[int(sim.state["speed"])]
		var n := 0
		while acc >= 1.0 and n < 200:
			acc -= 1.0; n += 1; sim.tick()
		for e in sim.events:
			if e["kind"] == "fade": _fade_moment(e["text"]); continue
			hud.push_log(e["kind"], e["text"])
			play({"done": "chime_done", "error": "ui_error", "arrive": "knock"}.get(e["kind"], "ui_click"))
		sim.events.clear()
		_open_story_if_pending()
		hud.refresh(sim, furnishing, world.wall_mode, _focus_text())
		var cooking: bool = sim.controlled()["anim"] == "cook" and sim.controlled()["current"].get("phase", "") == "perform"
		if cooking and not sfx["sizzle"].playing: sfx["sizzle"].play()
		elif not cooking and sfx["sizzle"].playing: sfx["sizzle"].stop()
	if sim and not creator.visible:
		world.set_time(sim.minute() if playing else 17 * 60 + 20)
		world.sync_characters(delta, sim.minute())
		world.update_cutaway(rig.flat_forward())
	if furnishing: _update_ghost()
	_update_focus_marker()

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("cheat_console") and playing: _toggle_cheats(); return
	if story_open or cheat_panel.visible or creator.visible: return
	if not playing or menus.visible: 
		if playing and e.is_action_pressed("menu"): menus.visible = false; hud.visible = true
		return
	if e.is_action_pressed("menu"):
		if popup.visible: popup.hide()
		elif furnishing: _toggle_furnish()
		else: _open_pause()
	elif e.is_action_pressed("speed_pause"): sim.set_speed(1 if int(sim.state["speed"]) == 0 else 0)
	elif e.is_action_pressed("speed_normal"): sim.set_speed(1)
	elif e.is_action_pressed("speed_fast"): sim.set_speed(2)
	elif e.is_action_pressed("toggle_walls"): world.wall_mode = (world.wall_mode + 1) % 3
	elif e.is_action_pressed("cam_reset"): rig.focus(world.house_center)
	elif e.is_action_pressed("quick_save"): save_game()
	elif e.is_action_pressed("quick_load"): load_game(_slot())
	elif e.is_action_pressed("furnish_toggle"): _toggle_furnish()
	elif furnishing: _furnish_input(e)
	else: _live_input(e)

func _live_input(e: InputEvent) -> void:
	var me: String = sim.state["controlled"]
	if e.is_action_pressed("clear_queue"): sim.clear_queue(me)
	elif e.is_action_pressed("cancel_action"): sim.cancel_action(me)
	elif e.is_action_pressed("act_prepare"): _hotkey_action("prepare_meal")
	elif e.is_action_pressed("act_eat"): _hotkey_action("eat")
	elif e.is_action_pressed("act_greet"): _hotkey_action("greet")
	elif e.is_action_pressed("act_sit"): _hotkey_action("sit")
	elif e.is_action_pressed("act_sleep"): _hotkey_action("sleep")
	elif e.is_action_pressed("focus_next"): _cycle_focus()
	elif e.is_action_pressed("interact") and focus_idx >= 0: _open_menu_for(focus_list[focus_idx], _screen_of(focus_list[focus_idx]))
	elif e.is_action_pressed("act_walk_focus") and focus_idx >= 0: _walk_to_focus()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _click(e.position)

func _hotkey_action(type: String) -> void:
	var me: String = sim.state["controlled"]
	var target := ""
	if type == "greet":
		for ch in sim.chars_on(sim.state["active_lot"]):
			if ch["id"] != me: target = ch["id"]
		if target == "": hud.push_log("error", "No one here to greet yet."); play("ui_error"); return
	if focus_idx >= 0 and focus_list[focus_idx]["kind"] == "furniture":
		var f: Dictionary = sim.furniture(sim.state["active_lot"]).get(focus_list[focus_idx]["id"], {})
		if not f.is_empty() and Catalog.get_def(f["item"])["actions"].has(Simulation.ACTIONS[type].get("item", "-")): target = f["id"]
	sim.queue_action(me, type, target)
	play("ui_click")

func _ray(pos: Vector2, mask: int) -> Dictionary:
	var from := rig.cam.project_ray_origin(pos); var dir := rig.cam.project_ray_normal(pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)

func _ground_cell(pos: Vector2) -> Vector2i:
	var from := rig.cam.project_ray_origin(pos); var dir := rig.cam.project_ray_normal(pos)
	var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(from, dir)
	if hit == null: return Vector2i(-1, -1)
	return Vector2i(floori(hit.x / Catalog.CELL), floori(hit.z / Catalog.CELL))

func _click(pos: Vector2) -> void:
	var hit := _ray(pos, 2 | 4)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		if col.has_meta("cid") and col.get_meta("cid") != sim.state["controlled"]:
			_open_menu_for({"kind": "character", "id": col.get_meta("cid")}, pos); return
		if col.has_meta("fid") and String(col.get_meta("fid")) != "":
			_open_menu_for({"kind": "furniture", "id": col.get_meta("fid")}, pos); return
	var c := _ground_cell(pos)
	if c.x >= 0:
		var r := sim.queue_action(sim.state["controlled"], "walk", "", c)
		if r["ok"]: play("ui_click")

func _open_menu_for(t: Dictionary, pos: Vector2) -> void:
	popup.clear(); popup_entries.clear()
	var lid: String = sim.state["active_lot"]
	if t["kind"] == "character":
		var ch := sim.character(t["id"])
		popup.add_separator(ch["name"])
		popup.add_item("Greet %s" % ch["name"]); popup_entries.append(["greet", t["id"]])
		var el := FamilyLife.baby_eligibility(sim.state, sim.state["controlled"], t["id"])
		if el["ok"]: popup.add_item("Try for Baby (private moment)"); popup_entries.append(["try_for_baby", t["id"]])
	else:
		var f: Dictionary = sim.furniture(lid)[t["id"]]
		var def := Catalog.get_def(f["item"])
		popup.add_separator(def["name"])
		for verb in def["actions"]:
			var label: String = {"sit": "Sit", "eat": "Eat here", "sleep": "Sleep", "prepare_meal": "Prepare a meal"}[verb]
			popup.add_item(label); popup_entries.append([verb, t["id"]])
		popup.add_item("Walk here"); popup_entries.append(["walk_to", t["id"]])
	popup.position = Vector2i(pos); popup.reset_size(); popup.popup()
	popup.set_focused_item(1)

func _on_popup(id: int) -> void:
	var idx := popup.get_item_index(id)
	var real := 0
	for i in idx: if not popup.is_item_separator(i): real += 1
	var ent: Array = popup_entries[real]
	if ent[0] == "walk_to": focus_list = [{"kind": "furniture", "id": ent[1]}]; focus_idx = 0; _walk_to_focus()
	else: sim.queue_action(sim.state["controlled"], ent[0], ent[1])
	play("ui_click")

func _walk_to_focus() -> void:
	var t: Dictionary = focus_list[focus_idx]
	var lid: String = sim.state["active_lot"]
	var cell := Vector2i(-1, -1)
	if t["kind"] == "character": cell = GameState.cell_of(sim.character(t["id"])["cell"]) + Vector2i(0, 1)
	else:
		var f: Dictionary = sim.furniture(lid)[t["id"]]
		var def := Catalog.get_def(f["item"])
		if def["slots"].is_empty(): cell = GameState.cell_of(f["cell"]) + Vector2i(0, Catalog.footprint_size(f["item"], int(f["rot"])).y)
		else: cell = Catalog.local_cell_to_world(f["item"], GameState.cell_of(f["cell"]), int(f["rot"]), def["slots"][0]["approach"][0])
	sim.queue_action(sim.state["controlled"], "walk", "", cell)

func _cycle_focus() -> void:
	var lid: String = sim.state["active_lot"]
	var here := Vector2(GameState.cell_of(sim.controlled()["cell"]))
	focus_list.clear()
	for fid in sim.furniture(lid):
		if not Catalog.get_def(sim.furniture(lid)[fid]["item"])["actions"].is_empty(): focus_list.append({"kind": "furniture", "id": fid})
	for ch in sim.chars_on(lid):
		if ch["id"] != sim.state["controlled"]: focus_list.append({"kind": "character", "id": ch["id"]})
	focus_list.sort_custom(func(a, b): return here.distance_to(_target_cell(a)) < here.distance_to(_target_cell(b)))
	focus_idx = (focus_idx + 1) % focus_list.size() if not focus_list.is_empty() else -1

func _target_cell(t: Dictionary) -> Vector2:
	if t["kind"] == "character": return Vector2(GameState.cell_of(sim.character(t["id"])["cell"]))
	return Vector2(GameState.cell_of(sim.furniture(sim.state["active_lot"])[t["id"]]["cell"]))

func _focus_world(t: Dictionary) -> Vector3:
	if t["kind"] == "character":
		var a: Node3D = world.avatars.get(t["id"]); return a.position if a else Vector3.ZERO
	var n: Node3D = world.furn_nodes.get(t["id"]); return n.position if n else Vector3.ZERO

func _screen_of(t: Dictionary) -> Vector2: return rig.cam.unproject_position(_focus_world(t) + Vector3(0, 1, 0))

func _focus_valid() -> bool:
	if focus_idx < 0 or focus_idx >= focus_list.size(): return false
	var t: Dictionary = focus_list[focus_idx]
	return sim.character(t["id"]).get("lot", "") == sim.state["active_lot"] if t["kind"] == "character" else sim.furniture(sim.state["active_lot"]).has(t["id"])

func _focus_text() -> String:
	if not _focus_valid(): focus_idx = -1; return "%s focus an object · Click an object or the floor" % InputConfig.label("focus_next")
	var t: Dictionary = focus_list[focus_idx]
	var nm: String = sim.character(t["id"])["name"] if t["kind"] == "character" else Catalog.get_def(sim.furniture(sim.state["active_lot"])[t["id"]]["item"])["name"]
	return "Focus: %s · %s interact · %s walk there · %s next" % [nm, InputConfig.label("interact"), InputConfig.label("act_walk_focus"), InputConfig.label("focus_next")]

func _update_focus_marker() -> void:
	focus_marker.visible = playing and not furnishing and _focus_valid()
	if focus_marker.visible: focus_marker.position = _focus_world(focus_list[focus_idx]) + Vector3(0, 0.05, 0)

# ------------------------------------------------------------------ furnishing
func _toggle_furnish() -> void:
	furnishing = not furnishing
	if not furnishing and ghost: ghost.queue_free(); ghost = null; ghost_item = ""
	for b in hud.cat_btns.values(): b.button_pressed = false
	play("ui_click")
	if furnishing: hud.furnish_status.text = "Pick an item (1–8) to start placing."

func _select_item(item: String) -> void:
	if ghost: ghost.queue_free()
	ghost_item = item; ghost_rot = 0
	ghost = WorldView.make_furniture(item, ghost_cell, 0); add_child(ghost)
	for b in ghost.find_children("*", "StaticBody3D", true, false): b.queue_free()
	for b in hud.cat_btns: hud.cat_btns[b].button_pressed = b == item
	play("ui_click")

func _furnish_input(e: InputEvent) -> void:
	for i in Catalog.ORDER.size():
		if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_1 + i: _select_item(Catalog.ORDER[i]); return
	if e.is_action_pressed("undo"): _history(true)
	elif e.is_action_pressed("redo"): _history(false)
	elif e.is_action_pressed("furnish_rotate") and ghost: ghost_rot = (ghost_rot + 1) % 4
	elif e.is_action_pressed("furnish_sell"): _sell_hovered()
	elif e.is_action_pressed("interact") and ghost: _place()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if ghost: _place()
	elif e is InputEventMouseMotion: ghost_from_mouse = true
	for d in [["furnish_nudge_up", Vector2i(0, -1)], ["furnish_nudge_down", Vector2i(0, 1)], ["furnish_nudge_left", Vector2i(-1, 0)], ["furnish_nudge_right", Vector2i(1, 0)]]:
		if e.is_action_pressed(d[0]): ghost_from_mouse = false; ghost_cell += d[1]

func _update_ghost() -> void:
	if ghost == null: return
	if ghost_from_mouse:
		var c := _ground_cell(get_viewport().get_mouse_position())
		var fs := Catalog.footprint_size(ghost_item, ghost_rot)
		if c.x >= 0: ghost_cell = c - Vector2i((fs.x - 1) / 2, (fs.y - 1) / 2)
	ghost.transform = WorldView.furniture_transform(ghost_item, ghost_cell, ghost_rot)
	var v := furn.can_place(ghost_item, ghost_cell, ghost_rot)
	var price: int = Catalog.get_def(ghost_item)["price"]
	var afford := sim.funds() >= price
	var ok: bool = v["ok"] and afford
	var tint := StandardMaterial3D.new(); tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(0.3, 0.85, 0.6, 0.35) if ok else Color(0.95, 0.35, 0.25, 0.45); tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in ghost.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_overlay = tint
	hud.furnish_status.text = ("Valid — %s for %s. After purchase: %s" % [Catalog.get_def(ghost_item)["name"], Catalog.format_cents(price), Catalog.format_cents(sim.funds() - price)]) if ok else ("Blocked — %s" % (v["reason"] if not v["ok"] else "not enough funds"))

func _place() -> void:
	var r := furn.buy(ghost_item, ghost_cell, ghost_rot)
	if r["ok"]:
		world.refresh_furniture(); play("coins")
		hud.push_log("done", "Bought %s for %s." % [Catalog.get_def(ghost_item)["name"], Catalog.format_cents(Catalog.get_def(ghost_item)["price"])])
	else:
		hud.push_log("error", r["reason"]); play("ui_error")

func _sell_hovered() -> void:
	var hit := _ray(get_viewport().get_mouse_position(), 4)
	var fid := String(hit["collider"].get_meta("fid")) if not hit.is_empty() else ""
	if fid == "": hud.push_log("error", "Point at an item to sell it."); play("ui_error"); return
	var item: String = sim.furniture(sim.state["active_lot"])[fid]["item"]
	var r := furn.sell(fid)
	if r["ok"]: world.refresh_furniture(); play("coins"); hud.push_log("done", "Sold %s (+%s). Undo restores it." % [Catalog.get_def(item)["name"], Catalog.format_cents(Catalog.get_def(item)["price"])])

func _history(is_undo: bool) -> void:
	var r := furn.undo() if is_undo else furn.redo()
	if r["ok"]: world.refresh_furniture(); play("ui_click"); hud.push_log("info", "%s. Funds now %s." % ["Undone" if is_undo else "Redone", Catalog.format_cents(sim.funds())])
	else: hud.push_log("error", r["reason"]); play("ui_error")
