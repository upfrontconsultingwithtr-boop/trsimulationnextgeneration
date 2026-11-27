class_name Menus
extends Control
## Start menu, avatar preset selection, pause menu and controls remapping. Keyboard navigable.

signal new_game(preset: String)
signal continue_game
signal preset_highlight(preset: String)
signal resume
signal save_requested
signal load_requested
signal quit_to_title
signal neighborhood_new(hid: String)
signal neighborhood_continue
signal switch_household(hid: String)
signal toggle_inactive

var _rebinding := ""
var _rebind_btns := {}
var has_save := false
var has_hood_save := false
var in_neighborhood := false
var inactive_on := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clear() -> void:
	for c in get_children(): c.queue_free()

func _card(width: int = 520, anchor: int = Control.PRESET_CENTER_LEFT) -> VBoxContainer:
	# full-screen margin -> vertically centred column -> panel (never overflows the screen)
	var m := MarginContainer.new(); add_child(m); m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 36)
	var col := VBoxContainer.new(); col.alignment = BoxContainer.ALIGNMENT_CENTER; col.mouse_filter = Control.MOUSE_FILTER_IGNORE; m.add_child(col)
	var p := PanelContainer.new(); col.add_child(p)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if anchor == Control.PRESET_CENTER else Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new(); v.custom_minimum_size.x = width; v.add_theme_constant_override("separation", 12); p.add_child(v)
	return v

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 48; b.pressed.connect(cb); parent.add_child(b); return b

func show_title() -> void:
	_clear(); visible = true
	var v := _card(460)
	v.add_child(UiTheme.title_label("Terrace & Rose", 54))
	var sub := Label.new(); sub.text = "A life simulation by the sea — Milestone 1: A Day at Alder Bungalow"; sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(sub)
	var first := _btn(v, "Play the Neighborhood — four families, stories in progress", show_households.bind(false))
	var hc := _btn(v, "Continue Neighborhood", func(): neighborhood_continue.emit()); hc.disabled = not has_hood_save
	_btn(v, "A Day at Alder Bungalow (new)", show_presets)
	var cont := _btn(v, "Continue Alder Bungalow", func(): continue_game.emit()); cont.disabled = not has_save
	_btn(v, "Controls", show_controls.bind(show_title))
	_btn(v, "Quit", func(): get_tree().quit())
	first.grab_focus.call_deferred()

func show_presets() -> void:
	_clear(); visible = true
	var v := _card(560)
	v.add_child(UiTheme.title_label("Choose who moves in", 34))
	var info := Label.new(); info.text = "One shared rig, three original people. Use ↑/↓ and Enter, or click."; v.add_child(info)
	var first: Button
	for pid in GameState.PRESET_ORDER:
		var p: Dictionary = GameState.PRESETS[pid]
		var b := Button.new(); b.custom_minimum_size = Vector2(0, 96); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s  (%s, %s)\n%s" % [p["name"], p["pronouns"], p["age"], p["blurb"]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var id: String = pid
		b.pressed.connect(func(): new_game.emit(id))
		b.focus_entered.connect(func(): preset_highlight.emit(id)); b.mouse_entered.connect(func(): preset_highlight.emit(id))
		v.add_child(b)
		if first == null: first = b
	_btn(v, "Back", show_title)
	first.grab_focus.call_deferred()

## Household picker. switching=true when called from the pause menu in a running neighborhood.
func show_households(switching: bool) -> void:
	_clear(); visible = true
	var v := _card(820, Control.PRESET_CENTER)
	v.add_child(UiTheme.title_label("Choose a household" if not switching else "Switch household", 34))
	var info := Label.new(); info.text = "Every family is mid-story. Your choices change their lives and their neighbours'."; v.add_child(info)
	var first: Button
	for hid in Neighborhood.STORY_ORDER:
		var h: Dictionary = Neighborhood.HOUSEHOLDS[hid]
		var names := []
		for p in Neighborhood.PEOPLE: if p[4] == hid: names.append("%s (%s)" % [String(p[1]).get_slice(" ", 0), p[3]])
		var b := Button.new(); b.custom_minimum_size = Vector2(0, 104); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s  ·  %s\n%s" % [h["name"], ", ".join(names), h["teaser"]]
		var id: String = hid
		b.pressed.connect(func(): (switch_household if switching else neighborhood_new).emit(id))
		v.add_child(b)
		if first == null: first = b
	var note := Label.new(); note.add_theme_font_size_override("font_size", 14)
	note.text = "Coming next: create your own household and move into the empty Willow Lane lot."
	v.add_child(note)
	_btn(v, "Back", show_pause if switching else show_title)
	first.grab_focus.call_deferred()

func show_pause() -> void:
	_clear(); visible = true
	var v := _card(380, Control.PRESET_CENTER)
	v.add_child(UiTheme.title_label("Paused", 34))
	var r := _btn(v, "Resume", func(): resume.emit())
	_btn(v, "Save (%s)" % InputConfig.label("quick_save"), func(): save_requested.emit())
	_btn(v, "Load (%s)" % InputConfig.label("quick_load"), func(): load_requested.emit())
	if in_neighborhood:
		_btn(v, "Switch household", show_households.bind(true))
		_btn(v, "Inactive households progress: %s" % ("On" if inactive_on else "Off"), func(): toggle_inactive.emit())
	_btn(v, "Controls", show_controls.bind(show_pause))
	_btn(v, "Quit to title", func(): quit_to_title.emit())
	_btn(v, "Quit game", func(): get_tree().quit())
	r.grab_focus.call_deferred()

func show_controls(back: Callable) -> void:
	_clear(); visible = true
	var p := PanelContainer.new(); add_child(p); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.offset_left = 60; p.offset_right = -60; p.offset_top = 40; p.offset_bottom = -40
	var outer := VBoxContainer.new(); p.add_child(outer)
	outer.add_child(UiTheme.title_label("Controls — select an action, then press a new key", 26))
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; outer.add_child(sc)
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 24); sc.add_child(grid)
	_rebind_btns.clear()
	var first: Button
	for a in InputConfig.DEFAULTS:
		var l := Label.new(); l.text = InputConfig.DEFAULTS[a][0]; l.custom_minimum_size.x = 380; grid.add_child(l)
		var b := Button.new(); b.text = InputConfig.label(a); b.custom_minimum_size.x = 240
		var act: String = a
		b.pressed.connect(func(): _rebinding = act; b.text = "Press a key…")
		grid.add_child(b); _rebind_btns[a] = b
		if first == null: first = b
	var row := HBoxContainer.new(); outer.add_child(row)
	_btn(row, "Reset to defaults", func(): InputConfig.reset_defaults(); show_controls(back))
	_btn(row, "Back", back)
	first.grab_focus.call_deferred()

func _input(e: InputEvent) -> void:
	if _rebinding == "": return
	if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		if e is InputEventKey and (e as InputEventKey).physical_keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT]: return
		InputConfig.bind(_rebinding, e)
		(_rebind_btns[_rebinding] as Button).text = InputConfig.label(_rebinding)
		_rebinding = ""
		get_viewport().set_input_as_handled()
