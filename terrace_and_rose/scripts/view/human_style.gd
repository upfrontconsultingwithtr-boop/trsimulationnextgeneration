class_name HumanStyle
extends RefCounted
## Realistic MakeHuman-based characters: chooses the body GLB for frame + life stage, shows the selected hair and
## outfit, mixes face/body morphs, and applies skin, hair and clothing shaders from the character's look.

const SKIN_SHADER := "res://assets/shaders/human_skin.gdshader"
const CLOTH_SHADER := "res://assets/shaders/cloth.gdshader"
const HAIR_SHADER := "res://assets/shaders/hair.gdshader"
const MORPHS := ["african", "asian", "caucasian", "heavy", "slim", "muscular", "older", "bust"]
const OUTFIT_BITS := {"casual": 0, "shirt": 1, "knit_jacket": 2, "dress": 3, "overalls": 4}
## older style ids from the stylised avatars map onto the realistic sets
const HAIR_MAP := {"coils": "coils", "wavy": "wavy", "curls_short": "curls_short", "bun": "bun", "long": "long", "braid": "braid", "bob": "bob"}
const OUTFIT_MAP := {"casual": "casual", "jumpsuit": "casual", "jacket": "shirt", "shirt": "shirt", "knit_jacket": "knit_jacket", "dress": "dress", "apron": "overalls", "overalls": "overalls"}
static var _skins := {}
static var _shaders := {}

static func available() -> bool:
	return ResourceLoader.exists("res://assets/models/humans/human_f_adult.glb") or FileAccess.file_exists("res://assets/models/humans/human_f_adult.glb")

static func frame_of(look: Dictionary, pronouns: String = "") -> String:
	if look.has("frame"): return String(look["frame"])
	match String(look.get("body", "")):
		"curvy": return "f"
		"slender": return "m" if pronouns == "he/him" else "f"
		"classic": return "f" if pronouns == "she/her" else "m"
	return "f" if pronouns == "she/her" else "m"

static func body_file(look: Dictionary, age: String, pronouns: String) -> String:
	var f := frame_of(look, pronouns)
	var name := "child" if age == "child" else "%s_%s" % [f, {"teen": "teen", "elder": "elder"}.get(age, "adult")]
	return "res://assets/models/humans/human_%s.glb" % name

## Default morph mix derived from skin tone when a look has none (keeps older saves and presets meaningful).
static func morphs_for(look: Dictionary) -> Dictionary:
	return Genetics.morphs_of(look)

static func _unused_morphs_for(look: Dictionary) -> Dictionary:
	if look.has("morphs"): return look["morphs"]
	var m := {}
	var tone := Color(String(look.get("skin", "b57b54")))
	var dark := clampf(1.0 - tone.get_luminance() * 1.6, 0.0, 1.0)
	m["african"] = dark * 0.85
	m["caucasian"] = (1.0 - dark) * 0.45
	m["asian"] = (1.0 - dark) * 0.2
	match String(look.get("body", "")):
		"curvy": m["heavy"] = 0.55; m["bust"] = 0.5
		"slender": m["slim"] = 0.5
		"classic": m["muscular"] = 0.2
	return m

static func skin_meta() -> Dictionary:
	if _skins.is_empty():
		var f := FileAccess.open("res://assets/textures/skins/skins.json", FileAccess.READ)
		if f: _skins = JSON.parse_string(f.get_as_text())
	return _skins

static func pick_skin(look: Dictionary, age: String, frame: String) -> String:
	if look.has("skin_tex") and skin_meta().has(look["skin_tex"]): return look["skin_tex"]
	var want := Color(String(look.get("skin", "b57b54")))
	var stage: String = {"elder": "old", "child": "young", "teen": "young"}.get(age, "young" if age == "adult" else "middleage")
	var best := ""; var bd := INF
	for n in skin_meta():
		var gender_ok: bool = n.ends_with("_female") or n.ends_with("female_skin") or n.contains("female") if frame == "f" else n.ends_with("_male")
		if frame != "f" and frame != "m": gender_ok = true
		if not gender_ok: continue
		var c := Color(String(skin_meta()[n]["tone"]))
		var d := Vector3(c.r - want.r, c.g - want.g, c.b - want.b).length() + (0.0 if n.begins_with(stage) else 0.06)
		if d < bd: bd = d; best = n
	return best

static func _shader(path: String) -> Shader:
	if not _shaders.has(path): _shaders[path] = load(path)
	return _shaders[path]

static func _orig_texture(mi: MeshInstance3D, surface: int) -> Texture2D:
	var m := mi.mesh.surface_get_material(surface)
	return (m as BaseMaterial3D).albedo_texture if m is BaseMaterial3D else null

static func apply(model: Node3D, look: Dictionary, age: String, pronouns: String) -> void:
	var hair: String = HAIR_MAP.get(String(look.get("hair", "wavy")), "wavy")
	var outfit: String = OUTFIT_MAP.get(String(look.get("outfit", "casual")), "casual")
	var frame := frame_of(look, pronouns)
	var morphs := morphs_for(look)
	var tone_name := pick_skin(look, age, frame)
	var skin_tex: Texture2D = AssetLoader.texture("res://assets/textures/skins/%s.jpg" % tone_name)
	var base_tone := Color(String(skin_meta().get(tone_name, {}).get("tone", "b57b54")))
	var want := Color(String(look.get("skin", base_tone.to_html(false))))
	var tint := Vector3(clampf(want.r / maxf(0.05, base_tone.r), 0.75, 1.3), clampf(want.g / maxf(0.05, base_tone.g), 0.75, 1.3), clampf(want.b / maxf(0.05, base_tone.b), 0.75, 1.3))
	var hc := Color(String(look.get("hair_color", "2a1d16")))
	var same := String(look.get("outfit", "")) == "jumpsuit"
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.begins_with("hair_"): mi.visible = nm == "hair_" + hair
		elif nm.begins_with("outfit_"): mi.visible = nm == "outfit_" + outfit
		if not mi.visible: continue
		for i in MORPHS.size():
			var idx := mi.find_blend_shape_by_name(MORPHS[i])
			if idx >= 0: mi.set_blend_shape_value(idx, clampf(float(morphs.get(MORPHS[i], 0.0)), 0.0, 1.0))
		for s in mi.mesh.get_surface_count():
			var mat: Material = null
			if nm == "body":
				var sm := ShaderMaterial.new(); sm.shader = _shader(SKIN_SHADER)
				sm.set_shader_parameter("skin_tex", skin_tex if skin_tex else _orig_texture(mi, s))
				sm.set_shader_parameter("tint", tint); sm.set_shader_parameter("outfit_bit", int(OUTFIT_BITS.get(outfit, -1)))
				mat = sm
			elif nm.begins_with("outfit_"):
				var sm := ShaderMaterial.new(); sm.shader = _shader(CLOTH_SHADER)
				sm.set_shader_parameter("orig_tex", _orig_texture(mi, s))
				sm.set_shader_parameter("fabric_tex", Palette.tex("knit_detail" if outfit == "knit_jacket" else "fabric_detail"))
				var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if src and src.normal_enabled and src.normal_texture: sm.set_shader_parameter("normal_tex", src.normal_texture); sm.set_shader_parameter("has_normal", true)
				var top := Color(String(look.get("top", "c2643f")))
				sm.set_shader_parameter("top_color", top)
				sm.set_shader_parameter("bottom_color", top if same else Color(String(look.get("bottom", "4d4842"))))
				sm.set_shader_parameter("outer_color", Color(String(look.get("outer", "6e4b31"))))
				mat = sm
			elif nm.begins_with("hair_"):
				var sm := ShaderMaterial.new(); sm.shader = _shader(HAIR_SHADER)
				sm.set_shader_parameter("hair_tex", _orig_texture(mi, s)); sm.set_shader_parameter("hair_color", hc)
				mat = sm
			elif nm == "brows" or nm == "lashes":
				var sm := ShaderMaterial.new(); sm.shader = _shader(HAIR_SHADER)
				sm.set_shader_parameter("hair_tex", _orig_texture(mi, s)); sm.set_shader_parameter("hair_color", hc.darkened(0.25) if nm == "brows" else Color(0.05, 0.04, 0.035))
				sm.set_shader_parameter("alpha_cut", 0.3)
				mat = sm
			elif nm == "eyes":
				var src := mi.mesh.surface_get_material(s)
				if src is BaseMaterial3D:
					var em := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
					em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; em.roughness = 0.08; em.metallic_specular = 0.8
					mat = em
			if mat: mi.set_surface_override_material(s, mat)
