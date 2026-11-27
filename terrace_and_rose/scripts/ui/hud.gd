class_name Hud
extends Control
## In-game HUD: clock + speed, funds, needs, action queue, action bar, feedback log, furnish catalog.

signal speed_pressed(i: int)
signal action_pressed(type: String)
signal cancel_pressed(action_id: String)
signal furnish_toggled
signal walls_pressed
signal catalog_pressed(item: String)
signal undo_pressed
signal redo_pressed
signal menu_pressed
signal story_choice(beat_id: String, idx: int)
signal business_pressed

var clock: Label
var funds: Label
var mode_label: Label
var speed_btns: Array[Button] = []
var need_rows := {}
var queue_box: VBoxContainer
var log_box: VBoxContainer
var focus_label: Label
var action_bar: HBoxContainer
var furnish_panel: PanelContainer
var furnish_status: Label
var walls_btn: Button
var holding_label: Label
var cat_btns := {}
var story_layer: CenterContainer
var household_label: Label
var family_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Container layout (scales with the window, never overflows): top row, middle row, bottom row.
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var rows := VBoxContainer.new(); rows.mouse_filter = Control.MOUSE_FILTER_IGNORE; margin.add_child(rows)
	var top_row := _row(rows); var mid_row := _row(rows, true); var bottom_row := _row(rows)
	# top-left: clock and speed
	var tv := HBoxContainer.new(); tv.add_theme_constant_override("separation", 8); _panel(top_row).add_child(tv)
	clock = UiTheme.title_label("Day 1 · 08:00", 24); clock.custom_minimum_size.x = 190; tv.add_child(clock)
	for i in 3:
		var b := Button.new(); b.toggle_mode = true; b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): speed_pressed.emit(i)); tv.add_child(b); speed_btns.append(b)
	_spacer(top_row)
	# top-right: funds, mode, walls, menu
	var trv := HBoxContainer.new(); trv.add_theme_constant_override("separation", 12); _panel(top_row).add_child(trv)
	household_label = Label.new(); trv.add_child(household_label)
	funds = UiTheme.title_label("Funds 600.00", 24); trv.add_child(funds)
	mode_label = Label.new(); trv.add_child(mode_label)
	walls_btn = Button.new(); walls_btn.focus_mode = Control.FOCUS_NONE; walls_btn.pressed.connect(func(): walls_pressed.emit()); trv.add_child(walls_btn)
	var mb := Button.new(); mb.text = "Menu (%s)" % InputConfig.label("menu"); mb.focus_mode = Control.FOCUS_NONE; mb.pressed.connect(func(): menu_pressed.emit()); trv.add_child(mb)
	# middle-left: needs
	var nv := VBoxContainer.new(); nv.custom_minimum_size.x = 290; var np := _panel(mid_row); np.size_flags_vertical = Control.SIZE_SHRINK_CENTER; np.add_child(nv)
	nv.add_child(UiTheme.title_label("Needs", 20))
	for k in GameState.NEED_KEYS:
		var row := VBoxContainer.new(); nv.add_child(row)
		var lab := Label.new(); row.add_child(lab)
		var bar := ProgressBar.new(); bar.max_value = 100; bar.show_percentage = false; bar.custom_minimum_size = Vector2(270, 14); row.add_child(bar)
		need_rows[k] = [lab, bar]
	holding_label = Label.new(); nv.add_child(holding_label)
	family_label = Label.new(); family_label.add_theme_font_size_override("font_size", 14); family_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; family_label.custom_minimum_size.x = 270; nv.add_child(family_label)
	_spacer(mid_row)
	# middle-right: queue (top) and feedback log (bottom)
	var right := VBoxContainer.new(); right.mouse_filter = Control.MOUSE_FILTER_IGNORE; right.add_theme_constant_override("separation", 10); mid_row.add_child(right)
	queue_box = VBoxContainer.new(); queue_box.custom_minimum_size = Vector2(340, 0); _panel(right).add_child(queue_box)
	var gap := Control.new(); gap.size_flags_vertical = Control.SIZE_EXPAND_FILL; gap.mouse_filter = Control.MOUSE_FILTER_IGNORE; right.add_child(gap)
	log_box = VBoxContainer.new(); log_box.custom_minimum_size = Vector2(340, 0); _panel(right).add_child(log_box)
	# bottom centre: action bar or furnish catalog
	_spacer(bottom_row)
	var bottom := VBoxContainer.new(); bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE; bottom_row.add_child(bottom)
	_spacer(bottom_row)
	var bp := _panel(bottom); var bv := VBoxContainer.new(); bp.add_child(bv)
	focus_label = Label.new(); focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(focus_label)
	action_bar = HBoxContainer.new(); action_bar.add_theme_constant_override("separation", 8); bv.add_child(action_bar)
	for a in [["prepare_meal", "act_prepare"], ["eat", "act_eat"], ["greet", "act_greet"], ["sit", "act_sit"], ["sleep", "act_sleep"], ["work_register", "act_work"]]:
		var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  %s" % [InputConfig.label(a[1]), Simulation.ACTIONS[a[0]]["label"]]
		var t: String = a[0]; b.pressed.connect(func(): action_pressed.emit(t)); action_bar.add_child(b)
	var fb := Button.new(); fb.focus_mode = Control.FOCUS_NONE; fb.text = "%s  Furnish" % InputConfig.label("furnish_toggle"); fb.pressed.connect(func(): furnish_toggled.emit()); action_bar.add_child(fb)
	var bz := Button.new(); bz.focus_mode = Control.FOCUS_NONE; bz.text = "%s  Shop" % InputConfig.label("business_panel"); bz.pressed.connect(func(): business_pressed.emit()); action_bar.add_child(bz)
	furnish_panel = PanelContainer.new(); bv.add_child(furnish_panel)
	furnish_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var fv := VBoxContainer.new(); furnish_panel.add_child(fv)
	var fh := HBoxContainer.new(); fv.add_child(fh)
	fh.add_child(UiTheme.title_label("Furnish", 20))
	var u := Button.new(); u.text = "Undo (%s)" % InputConfig.label("undo"); u.focus_mode = Control.FOCUS_NONE; u.pressed.connect(func(): undo_pressed.emit()); fh.add_child(u)
	var r := Button.new(); r.text = "Redo (%s)" % InputConfig.label("redo"); r.focus_mode = Control.FOCUS_NONE; r.pressed.connect(func(): redo_pressed.emit()); fh.add_child(r)
	var x := Button.new(); x.text = "Done (%s)" % InputConfig.label("furnish_toggle"); x.focus_mode = Control.FOCUS_NONE; x.pressed.connect(func(): furnish_toggled.emit()); fh.add_child(x)
	var grid := GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 6); fv.add_child(grid)
	for i in Catalog.ORDER.size():
		var item: String = Catalog.ORDER[i]
		var b := Button.new(); b.toggle_mode = true; b.focus_mode = Control.FOCUS_NONE; b.custom_minimum_size.x = 190
		b.text = "%d  %s — %s" % [i + 1, Catalog.get_def(item)["name"], Catalog.format_cents(Catalog.get_def(item)["price"])]
		b.pressed.connect(func(): catalog_pressed.emit(item)); grid.add_child(b); cat_btns[item] = b
	furnish_status = Label.new(); fv.add_child(furnish_status)
	var help := Label.new(); help.add_theme_font_size_override("font_size", 14)
	help.text = "Click or %s place · %s rotate · %s sell hovered · %s/%s/%s/%s nudge" % [InputConfig.label("interact"), InputConfig.label("furnish_rotate"), InputConfig.label("furnish_sell"), InputConfig.label("furnish_nudge_up"), InputConfig.label("furnish_nudge_left"), InputConfig.label("furnish_nudge_down"), InputConfig.label("furnish_nudge_right")]
	fv.add_child(help)
	furnish_panel.visible = false
	story_layer = CenterContainer.new(); story_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); story_layer.visible = false
	add_child(story_layer)

## Story moment: title, speaker, text and choices (locked/unaffordable choices show why). Number keys work.
func show_story(s: Dictionary, beat_id: String) -> void:
	for c in story_layer.get_children(): c.queue_free()
	var b := StoryEngine.beat(beat_id)
	var p := PanelContainer.new(); story_layer.add_child(p)
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 640; v.add_theme_constant_override("separation", 10); p.add_child(v)
	var tag := Label.new(); tag.text = "%s · Day %d" % [s["households"][b["household"]]["name"], int(s["minute"]) / 1440 + 1]
	tag.add_theme_color_override("font_color", Palette.TERRACOTTA); v.add_child(tag)
	v.add_child(UiTheme.title_label(b["title"], 30))
	if b.has("speaker"):
		var sp := Label.new(); sp.text = b["speaker"]; sp.add_theme_color_override("font_color", Palette.TEAL_DEEP); v.add_child(sp)
	var t := Label.new(); t.text = b["text"]; t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t.custom_minimum_size.x = 620; v.add_child(t)
	var first: Button
	for i in b["choices"].size():
		var ch: Dictionary = b["choices"][i]
		var st := StoryEngine.choice_status(s, b, i)
		var btn := Button.new(); btn.custom_minimum_size.y = 46; btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cost := int(ch.get("cost", 0))
		btn.text = "%d. %s%s%s" % [i + 1, ch["label"], ("  (%s)" % Catalog.format_cents(cost)) if cost > 0 else "", "" if st["ok"] else "  — " + st["reason"]]
		btn.disabled = not st["ok"]
		var idx: int = i
		btn.pressed.connect(func(): story_choice.emit(beat_id, idx))
		v.add_child(btn)
		if first == null and st["ok"]: first = btn
	story_layer.visible = true
	if first: first.grab_focus.call_deferred()

func show_story_result(title: String, text: String, on_close: Callable) -> void:
	for c in story_layer.get_children(): c.queue_free()
	var p := PanelContainer.new(); story_layer.add_child(p)
	var v := VBoxContainer.new(); v.custom_minimum_size.x = 600; p.add_child(v)
	v.add_child(UiTheme.title_label(title, 26))
	var t := Label.new(); t.text = text; t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t.custom_minimum_size.x = 580; v.add_child(t)
	var ok := Button.new(); ok.text = "Continue"; ok.custom_minimum_size.y = 44; ok.pressed.connect(on_close); v.add_child(ok)
	story_layer.visible = true
	ok.grab_focus.call_deferred()

func hide_story() -> void:
	story_layer.visible = false

func _row(parent: Node, expand: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new(); h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand: h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(h); return h

func _spacer(parent: Node) -> void:
	var c := Control.new(); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; c.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(c)

func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new(); parent.add_child(p); return p

func refresh(sim: Simulation, furnishing_mode: bool, wall_mode: int, focus_text: String) -> void:
	var me := sim.controlled()
	var sp := int(sim.state["speed"])
	clock.text = GameState.hour_text(sim.minute())
	var keys := ["speed_pause", "speed_normal", "speed_fast"]
	var names := ["Pause", "Normal", "Fast"]
	for i in 3:
		speed_btns[i].button_pressed = i == sp
		speed_btns[i].text = "%s%s (%s)" % ["● " if i == sp else "", names[i], InputConfig.label(keys[i])]
	funds.text = "Funds %s" % Catalog.format_cents(sim.funds())
	household_label.text = String(sim.household()["name"])
	var fam := []
	for t in sim.state.get("family", []):
		if t["a"] == me["id"] or t["b"] == me["id"]:
			var other: String = t["b"] if t["a"] == me["id"] else t["a"]
			var rel: Dictionary = sim.state["relationships"].get(GameState.rel_key(me["id"], other), {})
			fam.append("%s %s (%s, friendship %d)" % [_tie_word(t, me["id"]), sim.character(other).get("name", other).get_slice(" ", 0), String(sim.character(other).get("age", "")), int(rel.get("friendship", 0))])
	family_label.text = ("Family & friends:\n" + "\n".join(fam)) if not fam.is_empty() else ""
	mode_label.text = "Furnish mode" if furnishing_mode else ("Paused" if sp == 0 else "Live mode")
	var biz := Business.for_lot(sim.state, sim.state["active_lot"])
	if not biz.is_empty():
		var waiting := 0
		for o in biz["orders"].values(): if o["status"] == "waiting": waiting += 1
		mode_label.text += "  ·  %s: %s" % [biz["name"], ("OPEN, %d waiting, sales %s" % [waiting, Catalog.format_cents(int(biz["shift"].get("sale", 0)))]) if biz["is_open"] else "closed"]
	walls_btn.text = "Walls: %s (%s)" % [["Up", "Cutaway", "Down"][wall_mode], InputConfig.label("toggle_walls")]
	for k in GameState.NEED_KEYS:
		var v := int(me["needs"][k])
		var st := UiTheme.need_state(v)
		var row: Array = need_rows[k]
		(row[0] as Label).text = "%s  %d%%  —  %s" % [String(k).capitalize(), v / 100, st[0]]
		var bar := row[1] as ProgressBar; bar.value = v / 100.0
		bar.modulate = Color.WHITE if st[0] != "Critical" else Color(1.15, 0.85, 0.8)
	holding_label.text = "Holding: a warm meal" if me["holding"] == "meal" else ""
	focus_label.text = focus_text
	action_bar.visible = not furnishing_mode
	furnish_panel.visible = furnishing_mode
	_refresh_queue(me)

func _tie_word(t: Dictionary, me: String) -> String:
	var forward: bool = t["a"] == me
	return {"parent_of": "Child" if forward else "Parent", "grandparent_of": "Grandchild" if forward else "Grandparent",
		"stepparent_of": "Stepchild" if forward else "Stepparent", "spouse": "Spouse", "sibling": "Sibling", "step_sibling": "Step-sibling",
		"friend": "Friend", "partner": "Partner", "roommate": "Roommate"}.get(t["type"], t["type"])

func _refresh_queue(me: Dictionary) -> void:
	for c in queue_box.get_children(): c.queue_free()
	queue_box.add_child(UiTheme.title_label("%s's actions" % me["name"], 20))
	var items := []
	if not me["current"].is_empty(): items.append(me["current"])
	items.append_array(me["queue"])
	if items.is_empty():
		var l := Label.new(); l.text = "Idle — choose an action"; queue_box.add_child(l)
	for a in items:
		var row := HBoxContainer.new(); queue_box.add_child(row)
		var l := Label.new(); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var phase: String = {"queued": "Queued", "approach": "Walking", "perform": "Doing"}.get(a["phase"], a["phase"])
		var extra := (" · %d min left" % int(a["remaining"])) if a["phase"] == "perform" and int(a["remaining"]) > 0 else ""
		l.text = "%s — %s%s" % [phase, a["label"], extra]
		row.add_child(l)
		var x := Button.new(); x.text = "Cancel"; x.focus_mode = Control.FOCUS_NONE
		var id: String = a["id"]; x.pressed.connect(func(): cancel_pressed.emit(id)); row.add_child(x)
	var hint := Label.new(); hint.add_theme_font_size_override("font_size", 14)
	hint.text = "%s cancel current · %s clear all" % [InputConfig.label("cancel_action"), InputConfig.label("clear_queue")]
	queue_box.add_child(hint)

func push_log(kind: String, text: String) -> void:
	var prefix: String = {"sale": "Sale:", "shift": "Shift:", "done": "Done:", "error": "Can't:", "arrive": "Visitor:", "leave": "Visitor:", "info": "Note:", "save": "Saved:"}.get(kind, "Note:")
	var col: Color = {"sale": Palette.TEAL_DEEP, "shift": Palette.BRASS, "done": Palette.TEAL_DEEP, "error": Palette.TERRACOTTA, "arrive": Palette.BRASS, "leave": Palette.BRASS, "save": Palette.TEAL_DEEP}.get(kind, Palette.INK)
	var l := Label.new(); l.text = "%s %s" % [prefix, text]; l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 330
	log_box.add_child(l)
	while log_box.get_child_count() > 4: log_box.get_child(0).free()
