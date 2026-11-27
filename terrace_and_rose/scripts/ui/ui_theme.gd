class_name UiTheme
extends RefCounted
## Cream panels with walnut ink, sea-glass buttons, brass focus rings, terracotta warnings.

static func _box(bg: Color, border: Color, bw: int = 2, r: int = 12, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(r); s.set_content_margin_all(pad)
	s.shadow_color = Color(0, 0, 0, 0.18); s.shadow_size = 6
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", Palette.INK)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.96, 0.93, 0.87, 0.94), Color("d8c7ac")))
	t.set_stylebox("panel", "Panel", _box(Color(0.96, 0.93, 0.87, 0.94), Color("d8c7ac")))
	var b := _box(Color("dcebe7"), Color("7fb8ad"), 2, 10, 8)
	var bh := _box(Color("c8e2dc"), Color("4f8f86"), 2, 10, 8)
	var bp := _box(Color("7fb8ad"), Color("4f8f86"), 2, 10, 8)
	var bf := _box(Color("dcebe7"), Palette.BRASS, 3, 10, 8)
	var bd := _box(Color("e6e0d6"), Color("cfc5b6"), 2, 10, 8)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		t.set_stylebox(st, "Button", {"normal": b, "hover": bh, "pressed": bp, "hover_pressed": bp, "focus": bf, "disabled": bd}[st])
	t.set_color("font_color", "Button", Palette.INK)
	t.set_color("font_hover_color", "Button", Palette.INK)
	t.set_color("font_pressed_color", "Button", Color("1f1712"))
	t.set_color("font_focus_color", "Button", Palette.INK)
	t.set_color("font_disabled_color", "Button", Color("8b7f72"))
	var bar_bg := _box(Color("e4dccd"), Color("cdbfa8"), 1, 6, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", _box(Palette.TEAL, Color("4f8f86"), 1, 6, 0))
	t.set_color("font_color", "ProgressBar", Palette.INK)
	t.set_stylebox("panel", "PopupMenu", _box(Color(0.97, 0.94, 0.88), Palette.BRASS, 2, 10, 8))
	t.set_stylebox("hover", "PopupMenu", _box(Color("c8e2dc"), Color("4f8f86"), 1, 6, 4))
	t.set_color("font_color", "PopupMenu", Palette.INK); t.set_color("font_hover_color", "PopupMenu", Palette.INK)
	t.set_font_size("font_size", "PopupMenu", 18)
	return t

static func title_label(text: String, size: int = 28) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.WALNUT); return l

static func need_state(v: int) -> Array:
	# returns [word, color] — always shown as text, colour is secondary
	if v >= 7000: return ["Good", Palette.TEAL_DEEP]
	if v >= 4000: return ["Okay", Color("8c8a5a")]
	if v >= 1500: return ["Low", Palette.BRASS]
	return ["Critical", Palette.TERRACOTTA]
