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

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	# top-left: clock and speed
	var top := _panel(Control.PRESET_TOP_LEFT, Vector2(16, 16))
	var tv := HBoxContainer.new(); tv.add_theme_constant_override("separation", 8); top.add_child(tv)
	clock = UiTheme.title_label("Day 1 · 08:00", 24); clock.custom_minimum_size.x = 190; tv.add_child(clock)
	for i in 3:
		var b := Button.new(); b.toggle_mode = true; b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): speed_pressed.emit(i)); tv.add_child(b); speed_btns.append(b)
	# top-right: funds, mode, walls
	var tr := _panel(Control.PRESET_TOP_RIGHT, Vector2(-16, 16))
	var trv := HBoxContainer.new(); trv.add_theme_constant_override("separation", 12); tr.add_child(trv)
	funds = UiTheme.title_label("Funds 600.00", 24); trv.add_child(funds)
	mode_label = Label.new(); trv.add_child(mode_label)
	walls_btn = Button.new(); walls_btn.focus_mode = Control.FOCUS_NONE; walls_btn.pressed.connect(func(): walls_pressed.emit()); trv.add_child(walls_btn)
	var mb := Button.new(); mb.text = "Menu (%s)" % InputConfig.label("menu"); mb.focus_mode = Control.FOCUS_NONE; mb.pressed.connect(func(): menu_pressed.emit()); trv.add_child(mb)
	# left: needs
	var np := _panel(Control.PRESET_CENTER_LEFT, Vector2(16, -40))
	var nv := VBoxContainer.new(); nv.custom_minimum_size.x = 300; np.add_child(nv)
	nv.add_child(UiTheme.title_label("Needs", 20))
	for k in GameState.NEED_KEYS:
		var row := VBoxContainer.new(); nv.add_child(row)
		var lab := Label.new(); row.add_child(lab)
		var bar := ProgressBar.new(); bar.max_value = 100; bar.show_percentage = false; bar.custom_minimum_size = Vector2(280, 16); row.add_child(bar)
		need_rows[k] = [lab, bar]
	holding_label = Label.new(); nv.add_child(holding_label)
	# right: queue
	var qp := _panel(Control.PRESET_CENTER_RIGHT, Vector2(-16, -60))
	queue_box = VBoxContainer.new(); queue_box.custom_minimum_size = Vector2(320, 120); qp.add_child(queue_box)
	# bottom: action bar
	var bp := _panel(Control.PRESET_CENTER_BOTTOM, Vector2(0, -16))
	var bv := VBoxContainer.new(); bp.add_child(bv)
	focus_label = Label.new(); focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(focus_label)
	action_bar = HBoxContainer.new(); action_bar.add_theme_constant_override("separation", 8); bv.add_child(action_bar)
	for a in [["prepare_meal", "act_prepare"], ["eat", "act_eat"], ["greet", "act_greet"], ["sit", "act_sit"], ["sleep", "act_sleep"]]:
		var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  %s" % [InputConfig.label(a[1]), Simulation.ACTIONS[a[0]]["label"]]
		var t: String = a[0]; b.pressed.connect(func(): action_pressed.emit(t)); action_bar.add_child(b)
	var fb := Button.new(); fb.focus_mode = Control.FOCUS_NONE; fb.text = "%s  Furnish" % InputConfig.label("furnish_toggle"); fb.pressed.connect(func(): furnish_toggled.emit()); action_bar.add_child(fb)
	# bottom-right: feedback log
	var lp := _panel(Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -16))
	log_box = VBoxContainer.new(); log_box.custom_minimum_size = Vector2(420, 0); lp.add_child(log_box)
	# furnish catalog (hidden by default)
	furnish_panel = _panel(Control.PRESET_CENTER_BOTTOM, Vector2(0, -130))
	var fv := VBoxContainer.new(); furnish_panel.add_child(fv)
	var fh := HBoxContainer.new(); fv.add_child(fh)
	fh.add_child(UiTheme.title_label("Furnish", 20))
	var u := Button.new(); u.text = "Undo (%s)" % InputConfig.label("undo"); u.focus_mode = Control.FOCUS_NONE; u.pressed.connect(func(): undo_pressed.emit()); fh.add_child(u)
	var r := Button.new(); r.text = "Redo (%s)" % InputConfig.label("redo"); r.focus_mode = Control.FOCUS_NONE; r.pressed.connect(func(): redo_pressed.emit()); fh.add_child(r)
	var grid := HBoxContainer.new(); grid.add_theme_constant_override("separation", 6); fv.add_child(grid)
	for i in Catalog.ORDER.size():
		var item: String = Catalog.ORDER[i]
		var b := Button.new(); b.toggle_mode = true; b.focus_mode = Control.FOCUS_NONE
		b.text = "%d  %s\n%s" % [i + 1, Catalog.get_def(item)["name"], Catalog.format_cents(Catalog.get_def(item)["price"])]
		b.pressed.connect(func(): catalog_pressed.emit(item)); grid.add_child(b); cat_btns[item] = b
	furnish_status = Label.new(); fv.add_child(furnish_status)
	var help := Label.new(); help.add_theme_font_size_override("font_size", 14)
	help.text = "Click or %s place · %s rotate · %s sell hovered · %s/%s/%s/%s nudge · %s exit" % [InputConfig.label("interact"), InputConfig.label("furnish_rotate"), InputConfig.label("furnish_sell"), InputConfig.label("furnish_nudge_up"), InputConfig.label("furnish_nudge_left"), InputConfig.label("furnish_nudge_down"), InputConfig.label("furnish_nudge_right"), InputConfig.label("furnish_toggle")]
	fv.add_child(help)
	furnish_panel.visible = false

func _panel(preset: int, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new(); add_child(p)
	p.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_CENTER_RIGHT, Control.PRESET_BOTTOM_RIGHT] else (Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_BOTTOM else Control.GROW_DIRECTION_END)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] else (Control.GROW_DIRECTION_BOTH if preset in [Control.PRESET_CENTER_LEFT, Control.PRESET_CENTER_RIGHT] else Control.GROW_DIRECTION_END)
	p.position += offset
	return p

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
	mode_label.text = "Furnish mode" if furnishing_mode else ("Paused" if sp == 0 else "Live mode")
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
	var prefix: String = {"done": "Done:", "error": "Can't:", "arrive": "Visitor:", "leave": "Visitor:", "info": "Note:", "save": "Saved:"}.get(kind, "Note:")
	var col: Color = {"done": Palette.TEAL_DEEP, "error": Palette.TERRACOTTA, "arrive": Palette.BRASS, "leave": Palette.BRASS, "save": Palette.TEAL_DEEP}.get(kind, Palette.INK)
	var l := Label.new(); l.text = "%s %s" % [prefix, text]; l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 400
	log_box.add_child(l)
	while log_box.get_child_count() > 5: log_box.get_child(0).free()
