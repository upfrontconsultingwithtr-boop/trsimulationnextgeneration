class_name BusinessPanel
extends PanelContainer
## Run the household's shop: name, hours, menu prices, stock purchasing, open/close, live shift and ledger.

signal closed
var sim: Simulation
var _v: VBoxContainer

func open(s: Simulation) -> void:
	sim = s; visible = true; refresh()

func refresh() -> void:
	for c in get_children(): c.queue_free()
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(640, 560); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(sc)
	_v = VBoxContainer.new(); _v.custom_minimum_size.x = 620; _v.add_theme_constant_override("separation", 8); sc.add_child(_v)
	var lid: String = sim.state["active_lot"]
	var b := Business.for_lot(sim.state, lid)
	if b.is_empty(): _setup(lid); return
	var mine: bool = b["household"] == sim.state["active_household"]
	var head := HBoxContainer.new(); _v.add_child(head)
	var name := LineEdit.new(); name.text = b["name"]; name.custom_minimum_size.x = 320; name.editable = mine
	name.text_changed.connect(func(t): if t.strip_edges() != "": b["name"] = t); head.add_child(name)
	var st := Label.new(); st.text = "  %s · %s · reputation %d" % [Business.TYPES[b["type"]]["label"], "OPEN" if b["is_open"] else "Closed", int(b["reputation"])]
	st.add_theme_color_override("font_color", Palette.TEAL_DEEP if b["is_open"] else Palette.TERRACOTTA); head.add_child(st)
	if not mine: _lbl("You can visit, but only the owners can run this shop."); _close_btn(); return
	var row := HBoxContainer.new(); _v.add_child(row)
	_lbl_in(row, "Hours")
	var o := SpinBox.new(); o.min_value = 5; o.max_value = 21; o.value = b["open_hour"]; o.suffix = ":00"; row.add_child(o)
	_lbl_in(row, "to")
	var c := SpinBox.new(); c.min_value = 7; c.max_value = 23; c.value = b["close_hour"]; c.suffix = ":00"; row.add_child(c)
	var apply := Button.new(); apply.text = "Set hours"; row.add_child(apply)
	apply.pressed.connect(func(): var r := Business.set_hours(b, int(o.value), int(c.value)); _flash(r["reason"] if not r["ok"] else "Hours saved."))
	var oc := Button.new(); oc.text = "Close now" if b["is_open"] else "Open now"; row.add_child(oc)
	oc.pressed.connect(func():
		var r: Dictionary = sim.close_business(b) if b["is_open"] else Business.open_shift(sim.state, b)
		if r["ok"] and b["is_open"]: b["opened_day"] = sim.minute() / 1440
		_flash(r.get("reason", "") if not r["ok"] else ""); refresh())
	_title("Menu & prices")
	var t: Dictionary = Business.TYPES[b["type"]]
	for pid in b["menu"]:
		var p: Dictionary = t["products"][pid]
		var r2 := HBoxContainer.new(); _v.add_child(r2)
		var en := CheckBox.new(); en.button_pressed = b["menu"][pid]["enabled"]; en.text = p["name"]; en.custom_minimum_size.x = 200
		var id: String = pid
		en.toggled.connect(func(on): b["menu"][id]["enabled"] = on); r2.add_child(en)
		var pr := SpinBox.new(); pr.min_value = 0.5; pr.max_value = 1000; pr.step = 0.25; pr.value = int(b["menu"][pid]["price"]) / 100.0; pr.custom_minimum_size.x = 110; pr.tooltip_text = "Price"
		pr.value_changed.connect(func(v): Business.set_price(b, id, int(round(v * 100)))); r2.add_child(pr)
		var uses := []
		for ing in p["uses"]: uses.append("%d %s" % [p["uses"][ing], ing])
		_lbl_in(r2, "base %s · uses %s · %s" % [Catalog.format_cents(p["base"]), ", ".join(uses), "can make" if Business.can_make(b, pid) else "OUT OF STOCK"])
	_title("Stock (available / on hand)")
	for ing in t["ingredients"]:
		var r3 := HBoxContainer.new(); _v.add_child(r3)
		_lbl_in(r3, "%s: %d / %d" % [String(ing).capitalize(), Business.available(b, ing), int(b["stock"][ing])]).custom_minimum_size.x = 200
		for q in [10, 50]:
			var bt := Button.new(); bt.text = "Buy %d (%s)" % [q, Catalog.format_cents(int(t["ingredients"][ing]) * q)]
			var ingn: String = ing; var qq: int = q
			bt.pressed.connect(func(): var r := Business.buy_stock(sim.state, b, ingn, qq); _flash("" if r["ok"] else r["reason"]); refresh())
			r3.add_child(bt)
	_title("Shift")
	if b["is_open"]:
		var sh: Dictionary = b["shift"]
		var waiting := 0
		for oo in b["orders"].values(): if oo["status"] == "waiting": waiting += 1
		_lbl("Open since %s · served %d · waiting %d · walked out %d · sales %s · supplies %s" % [GameState.hour_text(int(sh["start"])), int(sh.get("served", 0)), waiting, int(sh.get("lost", 0)) + int(sh.get("walkouts", 0)), Catalog.format_cents(int(sh.get("sale", 0))), Catalog.format_cents(-int(sh.get("stock", 0)))])
		_lbl("Tip: someone must work the register (press %s or let the family do it)." % InputConfig.label("act_work"))
	if not b["last_summary"].is_empty():
		var sm: Dictionary = b["last_summary"]
		_lbl("Last shift (%s–%s): served %d, lost %d · revenue %s · supplies %s · profit %s · ledger %s" % [GameState.hour_text(int(sm["start"])), GameState.hour_text(int(sm["end"])), int(sm["served"]), int(sm["lost"]) + int(sm["walkouts"]),
			Catalog.format_cents(int(sm["revenue"])), Catalog.format_cents(int(sm["expenses"])), Catalog.format_cents(int(sm["profit"])), "reconciled ✓" if sm["reconciled"] else "differs from funds (other spending during shift)"])
	_title("Ledger (latest)")
	var led: Array = b["ledger"]
	for e in led.slice(maxi(0, led.size() - 8)):
		_lbl("%s  %-6s  %s  %s" % [GameState.hour_text(int(e["minute"])), e["kind"], Catalog.format_cents(int(e["amount"])), e["note"]])
	_close_btn()

func _setup(lid: String) -> void:
	_title("Start a business here")
	var owner: String = sim.state["lots"][lid]["household"]
	if owner != sim.state["active_household"]: _lbl("You can only start a business on your own lot."); _close_btn(); return
	var name := LineEdit.new(); name.placeholder_text = "Business name"; _v.add_child(name)
	var type := OptionButton.new()
	for k in Business.TYPES: type.add_item(Business.TYPES[k]["label"])
	_v.add_child(type)
	_lbl("You'll need a Shop Register (Furnish → %s) and some stock." % Catalog.format_cents(Catalog.get_def("register")["price"]))
	var go := Button.new(); go.text = "Create business"; _v.add_child(go)
	go.pressed.connect(func():
		var r := Business.create(sim.state, sim.state["active_household"], lid, Business.TYPES.keys()[type.selected], name.text)
		_flash("" if r["ok"] else r["reason"]); refresh())
	_close_btn()

var _msg: Label
func _flash(t: String) -> void:
	if t == "": return
	if _msg == null or not is_instance_valid(_msg): _msg = _lbl("")
	_msg.text = t; _msg.add_theme_color_override("font_color", Palette.TERRACOTTA)

func _title(t: String) -> void: _v.add_child(UiTheme.title_label(t, 20))
func _lbl(t: String) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 600; l.add_theme_font_size_override("font_size", 15); _v.add_child(l); return l
func _lbl_in(p: Node, t: String) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 15); p.add_child(l); return l
func _close_btn() -> void:
	var b := Button.new(); b.text = "Close (%s)" % InputConfig.label("business_panel"); b.pressed.connect(func(): visible = false; closed.emit()); _v.add_child(b)
