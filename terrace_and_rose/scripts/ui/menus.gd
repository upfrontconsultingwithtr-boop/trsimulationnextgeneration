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

var _rebinding := ""
var _rebind_btns := {}
var has_save := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clear() -> void:
	for c in get_children(): c.queue_free()

func _card(width: int = 520, anchor: int = Control.PRESET_CENTER_LEFT) -> VBoxContainer:
	var p := PanelContainer.new(); add_child(p)
	p.set_anchors_and_offsets_preset(anchor, Control.PRESET_MODE_MINSIZE)
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.position.x += 48 if anchor == Control.PRESET_CENTER_LEFT else 0
	if anchor == Control.PRESET_CENTER: p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new(); v.custom_minimum_size.x = width; v.add_theme_constant_override("separation", 12); p.add_child(v)
	return v

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 48; b.pressed.connect(cb); parent.add_child(b); return b

func show_title() -> void:
	_clear(); visible = true
	var v := _card(460)
	v.add_child(UiTheme.title_label("Terrace & Rose", 54))
	var sub := Label.new(); sub.text = "A life simulation by the sea — Milestone 1: A Day at Alder Bungalow"; sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(sub)
	var first := _btn(v, "New Game", show_presets)
	var cont := _btn(v, "Continue", func(): continue_game.emit()); cont.disabled = not has_save
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

func show_pause() -> void:
	_clear(); visible = true
	var v := _card(380, Control.PRESET_CENTER)
	v.add_child(UiTheme.title_label("Paused", 34))
	var r := _btn(v, "Resume", func(): resume.emit())
	_btn(v, "Save (%s)" % InputConfig.label("quick_save"), func(): save_requested.emit())
	_btn(v, "Load (%s)" % InputConfig.label("quick_load"), func(): load_requested.emit())
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
