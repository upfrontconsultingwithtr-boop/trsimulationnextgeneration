class_name CreatorUI
extends Control
## Household & character creator. Edits a household in the given state in place; emits preview_changed
## so the 3D world can show the selected person live. Works for new and existing households.

signal preview_changed(cid: String)
signal finished(hid: String)
signal cancelled

const SKINS := ["f3d6bf", "e8c3a0", "d9a77c", "c08a5e", "a8704a", "8a5537", "6b3e26", "4b2d1e"]
const HAIR_COLS := ["17120f", "2a1d16", "5a3a22", "8a4b2a", "c89a5a", "e6d3a3", "cfcac2", "d77a8f"]
const CLOTH_COLS := ["c2643f", "86bdb2", "4f8f86", "e3b04b", "ede4d1", "6e4b31", "3a3532", "d77a8f"]
const HAIRS := ["coils", "wavy", "curls_short", "bun", "long", "braid", "bob"]
const BODIES := ["curvy", "slender", "classic"]
const OUTFITS := ["casual", "jumpsuit", "shirt", "knit_jacket", "overalls", "dress"]
const PRONOUNS := ["she/her", "he/him", "they/them"]

var s: Dictionary
var hid := ""
var sel := ""
var editing := false
var roll_seed := 1
var _left: VBoxContainer
var _right: VBoxContainer
var _status: Label

func open(state: Dictionary, household_id: String, is_edit: bool) -> void:
	s = state; hid = household_id; editing = is_edit
	var m: Array = s["households"][hid]["members"]
	sel = m[0] if not m.is_empty() else ""
	visible = true
	_rebuild()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE

func _rebuild() -> void:
	for c in get_children(): c.queue_free()
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "bottom", "right"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; margin.add_child(row)
	var lp := PanelContainer.new(); row.add_child(lp)
	var ls := ScrollContainer.new(); ls.custom_minimum_size = Vector2(360, 0); ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; lp.add_child(ls)
	_left = VBoxContainer.new(); _left.custom_minimum_size.x = 340; ls.add_child(_left)
	var gap := Control.new(); gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; gap.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(gap)
	var rp := PanelContainer.new(); row.add_child(rp)
	var rs := ScrollContainer.new(); rs.custom_minimum_size = Vector2(420, 0); rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; rp.add_child(rs)
	_right = VBoxContainer.new(); _right.custom_minimum_size.x = 400; rs.add_child(_right)
	_build_household_panel()
	_build_person_panel()
	preview_changed.emit(sel)

func _lbl(p: Node, t: String, size: int = 15) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", size); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; p.add_child(l); return l

func _btn(p: Node, t: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = t; b.pressed.connect(cb); p.add_child(b); return b

func _opt(p: Node, items: Array, current: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(String(items[i]).replace("_", " ").capitalize())
		if String(items[i]) == current: o.select(i)
	o.item_selected.connect(func(i): cb.call(items[i])); p.add_child(o); return o

func _swatches(p: Node, cols: Array, cb: Callable) -> void:
	var g := HBoxContainer.new(); p.add_child(g)
	for c in cols:
		var b := Button.new(); b.custom_minimum_size = Vector2(34, 30); b.tooltip_text = "#" + c
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(c); sb.set_corner_radius_all(6); sb.set_border_width_all(2); sb.border_color = Color("cfc5b6")
		for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, sb)
		var col: String = c
		b.pressed.connect(func(): cb.call(col)); g.add_child(b)

func _build_household_panel() -> void:
	var h: Dictionary = s["households"][hid]
	_left.add_child(UiTheme.title_label("Edit Household" if editing else "Create a Household", 26))
	var name_edit := LineEdit.new(); name_edit.text = h["name"]; name_edit.placeholder_text = "Household name"
	name_edit.text_changed.connect(func(t): h["name"] = t); _left.add_child(name_edit)
	_lbl(_left, "Household funds: %s" % Catalog.format_cents(int(h["funds"])))
	_lbl(_left, "People (click to edit):", 17)
	for cid in h["members"]:
		var c: Dictionary = s["characters"][cid]
		var b := _btn(_left, "%s%s — %s, %s" % ["▶ " if cid == sel else "", c["name"], c["age"], c["pronouns"]], func(): sel = cid; _rebuild())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var add := HBoxContainer.new(); _left.add_child(add)
	_btn(add, "+ Adult", func(): _add("adult"))
	_btn(add, "+ Teen", func(): _add("teen"))
	_btn(add, "+ Child", func(): _add("child"))
	_lbl(_left, "Make a child from two parents", 17)
	var adults: Array = h["members"].filter(func(cid): return s["characters"][cid]["age"] in ["adult", "elder"])
	if adults.size() >= 2:
		var pr := HBoxContainer.new(); _left.add_child(pr)
		var o1 := OptionButton.new(); var o2 := OptionButton.new()
		for cid in adults: o1.add_item(String(s["characters"][cid]["name"]).get_slice(" ", 0)); o2.add_item(String(s["characters"][cid]["name"]).get_slice(" ", 0))
		o2.select(1); pr.add_child(o1); pr.add_child(o2)
		var row := HBoxContainer.new(); _left.add_child(row)
		_btn(row, "Create child (DNA)", func():
			if o1.selected == o2.selected: _say("Pick two different parents."); return
			sel = FamilyLife.add_child_from_parents(s, adults[o1.selected], adults[o2.selected], roll_seed); roll_seed += 1; _rebuild())
		_btn(row, "Re-roll child", func():
			if sel == "" or not s["characters"][sel].has("genes"): _say("Select a DNA child to re-roll."); return
			var g: Dictionary = s["characters"][sel]["genes"]
			roll_seed += 1
			var spec := FamilyLife.child_spec(s, g["parents"][0], g["parents"][1], roll_seed, s["characters"][sel]["name"])
			FamilyLife.edit_member(s, sel, {"look": spec["look"], "traits": spec["traits"]}); s["characters"][sel]["genes"] = spec["genes"]; _rebuild())
	else:
		_lbl(_left, "Add two adults to combine their DNA.")
	_lbl(_left, "Relationships", 17)
	var tr := HBoxContainer.new(); _left.add_child(tr)
	var ta := OptionButton.new(); var tt := OptionButton.new(); var tb := OptionButton.new()
	for cid in h["members"]: ta.add_item(String(s["characters"][cid]["name"]).get_slice(" ", 0)); tb.add_item(String(s["characters"][cid]["name"]).get_slice(" ", 0))
	for t in FamilyLife.TIE_TYPES: tt.add_item(String(t).replace("_of", " of").replace("_", " "))
	if h["members"].size() > 1: tb.select(1)
	tr.add_child(ta); tr.add_child(tt); tr.add_child(tb)
	_btn(_left, "Set relationship", func():
		if h["members"].size() < 2: _say("Add another person first."); return
		var r := FamilyLife.set_tie(s, h["members"][ta.selected], h["members"][tb.selected], FamilyLife.TIE_TYPES[tt.selected])
		_say("Saved." if r["ok"] else r["reason"]); if r["ok"]: _rebuild())
	for t in s["family"]:
		if h["members"].has(t["a"]) and h["members"].has(t["b"]):
			_lbl(_left, "• %s — %s — %s" % [String(s["characters"][t["a"]]["name"]).get_slice(" ", 0), String(t["type"]).replace("_of", " of").replace("_", " "), String(s["characters"][t["b"]]["name"]).get_slice(" ", 0)], 14)
	_status = _lbl(_left, "", 15); _status.add_theme_color_override("font_color", Palette.TERRACOTTA)
	var fin := HBoxContainer.new(); _left.add_child(fin)
	_btn(fin, "Done — play this household" if not editing else "Save changes", func():
		var errs := FamilyLife.validate_household(s, hid)
		if not errs.is_empty(): _say(errs[0]); return
		finished.emit(hid))
	_btn(fin, "Cancel", func(): cancelled.emit())

func _add(age: String) -> void:
	if s["households"][hid]["members"].size() >= 8: _say("A household can have at most 8 people."); return
	var rng := RandomNumberGenerator.new(); rng.seed = roll_seed; roll_seed += 1
	var look := Genetics.random_look(rng); look["outfit"] = "casual"; look["top"] = CLOTH_COLS[rng.randi() % CLOTH_COLS.size()]
	var surname := String(s["households"][hid]["name"]).trim_prefix("The ").trim_suffix("s")
	sel = FamilyLife.add_member(s, hid, {"name": ["Alex", "Sam", "Jordan", "Remy", "Noa", "Quinn"][rng.randi() % 6] + " " + surname, "pronouns": PRONOUNS[rng.randi() % 3], "age": age, "look": look})
	_rebuild()

func _say(t: String) -> void:
	if _status: _status.text = t

func _build_person_panel() -> void:
	if sel == "" or not s["characters"].has(sel):
		_right.add_child(UiTheme.title_label("Add someone to begin", 22)); return
	var c: Dictionary = s["characters"][sel]
	var L: Dictionary = c["look"]
	_right.add_child(UiTheme.title_label(c["name"], 24))
	var ne := LineEdit.new(); ne.text = c["name"]; ne.text_submitted.connect(func(t): c["name"] = t; _rebuild()); ne.focus_exited.connect(func(): c["name"] = ne.text); _right.add_child(ne)
	_lbl(_right, "Pronouns")
	var pr := HBoxContainer.new(); _right.add_child(pr)
	_opt(pr, PRONOUNS + ([c["pronouns"]] if not PRONOUNS.has(c["pronouns"]) else []), c["pronouns"], func(v): c["pronouns"] = v; _rebuild())
	var custom := LineEdit.new(); custom.placeholder_text = "or type your own"; custom.custom_minimum_size.x = 160
	custom.text_submitted.connect(func(t): if t.strip_edges() != "": c["pronouns"] = t.strip_edges(); _rebuild())
	pr.add_child(custom)
	_lbl(_right, "Life stage"); _opt(_right, FamilyLife.AGES, c["age"], func(v): c["age"] = v; _rebuild())
	_lbl(_right, "Body frame (independent of pronouns)")
	_opt(_right, ["f", "m"], HumanStyle.frame_of(L, c["pronouns"]), func(v): L["frame"] = v; _changed())
	if not L.has("morphs"): L["morphs"] = Genetics.morphs_of(L).duplicate()
	var mg := GridContainer.new(); mg.columns = 2; _right.add_child(mg)
	for k in ["african", "asian", "caucasian", "heavy", "slim", "muscular", "bust", "older"]:
		var lab := Label.new(); lab.text = {"african": "Ancestry: African", "asian": "Ancestry: Asian", "caucasian": "Ancestry: European", "heavy": "Fuller body", "slim": "Slimmer body", "muscular": "Muscle", "bust": "Bust", "older": "Mature face"}[k]
		lab.add_theme_font_size_override("font_size", 14); mg.add_child(lab)
		var sl := HSlider.new(); sl.min_value = 0; sl.max_value = 1; sl.step = 0.05; sl.custom_minimum_size.x = 200
		sl.value = float(L["morphs"].get(k, 0.0)); var key: String = k
		sl.drag_ended.connect(func(_c): L["morphs"][key] = sl.value; _changed())
		mg.add_child(sl)
	_lbl(_right, "Skin tone"); _swatches(_right, SKINS, func(v): L["skin"] = v; _changed())
	_lbl(_right, "Hair texture & style"); _opt(_right, HAIRS, L["hair"], func(v): L["hair"] = v; L["hair_gene"] = v; _changed())
	_lbl(_right, "Hair colour"); _swatches(_right, HAIR_COLS, func(v): L["hair_color"] = v; _changed())
	_lbl(_right, "Outfit"); _opt(_right, OUTFITS, L.get("outfit", "casual"), func(v): L["outfit"] = v; _changed())
	_lbl(_right, "Top / main colour"); _swatches(_right, CLOTH_COLS, func(v): L["top"] = v; L["outer"] = v if L.get("outfit", "") == "jacket" else L.get("outer", v); _changed())
	_lbl(_right, "Bottom colour"); _swatches(_right, CLOTH_COLS, func(v): L["bottom"] = v; _changed())
	var acc := HBoxContainer.new(); _right.add_child(acc)
	for a in ["earrings", "beard"]:
		var cb := CheckBox.new(); cb.text = a.capitalize(); cb.button_pressed = L.get("accessories", []).has(a)
		var an: String = a
		cb.toggled.connect(func(on): (L["accessories"].append(an) if on else L["accessories"].erase(an)); _changed()); acc.add_child(cb)
	_lbl(_right, "Traits (pick up to 3)")
	var tg := GridContainer.new(); tg.columns = 4; _right.add_child(tg)
	for t in FamilyLife.TRAITS:
		var b := Button.new(); b.toggle_mode = true; b.text = t.capitalize(); b.button_pressed = c["traits"].has(t)
		var tn: String = t
		b.toggled.connect(func(on):
			if on and not c["traits"].has(tn):
				c["traits"].append(tn)
				if c["traits"].size() > 3: c["traits"].pop_front()
			elif not on: c["traits"].erase(tn)
			_rebuild())
		tg.add_child(b)
	_lbl(_right, "Aspiration"); _opt(_right, FamilyLife.ASPIRATIONS + ([c["aspiration"]] if c["aspiration"] != "" and not FamilyLife.ASPIRATIONS.has(c["aspiration"]) else []), c["aspiration"], func(v): c["aspiration"] = v)
	var cc := CheckBox.new(); cc.text = "Can become pregnant"; cc.button_pressed = bool(c.get("can_carry", false)); cc.toggled.connect(func(on): c["can_carry"] = on); _right.add_child(cc)
	if c.has("genes"): _lbl(_right, "DNA: child of %s" % " & ".join(c["genes"]["parents"].map(func(p): return String(s["characters"].get(p, {}).get("name", p)).get_slice(" ", 0))), 14)
	_btn(_right, "Remove from household", func():
		FamilyLife.remove_member(s, sel); var m: Array = s["households"][hid]["members"]; sel = m[0] if not m.is_empty() else ""; _rebuild())

func _changed() -> void:
	preview_changed.emit(sel)
