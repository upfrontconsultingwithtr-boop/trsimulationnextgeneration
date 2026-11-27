class_name Palette
extends RefCounted
## Single source of the art direction: cream stucco, walnut, sea-glass teal, terracotta and brass.
## GLB materials are replaced by name so every model shares the same look.

const CREAM := Color("efe6d6")
const STUCCO := Color("eee5d3")
const WALNUT := Color("5b3a24")
const TEAL := Color("7fb8ad")
const TEAL_DEEP := Color("4f8f86")
const TERRACOTTA := Color("c2643f")
const BRASS := Color("c99a45")
const INK := Color("33251c")

static var _cache := {}

static func tex(name: String) -> Texture2D:
	var p := "res://assets/textures/%s.png" % name
	return AssetLoader.texture(p)

static func _base(albedo: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo; m.roughness = rough; m.metallic = metal
	return m

static func _textured(albedo: Color, rough: float, tex_name: String, normal_name: String, scale: float, nscale: float = 0.6) -> StandardMaterial3D:
	var m := _base(albedo, rough)
	if tex_name != "": m.albedo_texture = tex(tex_name)
	if normal_name != "":
		m.normal_enabled = true; m.normal_texture = tex(normal_name); m.normal_scale = nscale
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Shared (non-character) materials by GLB material name.
static func get_mat(name: String) -> Material:
	if _cache.has(name): return _cache[name]
	var m: StandardMaterial3D
	match name:
		"walnut": m = _textured(Color(1, 1, 1), 0.55, "walnut_albedo", "walnut_normal", 1.0, 0.15)
		"walnut_floor": m = _textured(Color(1, 1, 1), 0.5, "walnut_albedo", "walnut_normal", 0.5, 0.12)
		"stucco":
			m = _textured(Color(1, 1, 1), 0.92, "stucco_albedo", "stucco_normal", 1.4, 0.12)
			m.uv1_triplanar = true; m.uv1_world_triplanar = true
		"teal_paint": m = _base(TEAL, 0.42)
		"brass": m = _base(BRASS, 0.32, 0.9)
		"linen": m = _textured(Color("efe8da"), 0.9, "fabric_detail", "fabric_normal", 3.0)
		"terracotta": m = _textured(Color(1, 1, 1), 0.85, "roof_albedo", "", 1.0)
		"terracotta_tile": m = _textured(Color("e0a37f"), 0.8, "path_albedo", "", 0.5)
		"stone_top": m = _textured(Color("f1ede5"), 0.35, "stucco_albedo", "", 2.0)
		"leaf": m = _base(Color("4f7a3e"), 0.7)
		"soil": m = _base(Color("3b2a1e"), 1.0)
		"glass": m = _base(Color(0.75, 0.88, 0.92, 0.25), 0.05)
		"lamp_shade":
			m = _textured(Color("fff1d6"), 0.8, "fabric_detail", "", 3.0)
			m.emission_enabled = true; m.emission = Color("ffd59a"); m.emission_energy_multiplier = 1.6
		"rug": m = _textured(Color(1, 1, 1), 0.95, "rug_albedo", "fabric_normal", 1.0)
		"book": m = _base(Color("8c4a3c"), 0.8)
		"ceramic": m = _base(Color("f2eee6"), 0.3)
		"roof_tile": m = _textured(Color(1, 1, 1), 0.85, "roof_albedo", "", 0.5)
		"teal_tile": m = _textured(Color(1, 1, 1), 0.25, "teal_tile_albedo", "", 0.5)
		"cedar":
			m = _textured(Color("b6906c"), 0.83, "walnut_albedo", "walnut_normal", 1.7, 0.16)
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
		"slate_roof": m = _textured(Color("6f858a"), 0.9, "roof_albedo", "", 0.6)
		"coastal_grass": m = _textured(Color("9d9b70"), 0.95, "grass_albedo", "", 0.72)
		"grass": m = _textured(Color(1, 1, 1), 1.0, "grass_albedo", "", 0.25)
		"path": m = _textured(Color(1, 1, 1), 0.9, "path_albedo", "", 0.5)
		"terracotta_floor": m = _textured(Color("d9906a"), 0.75, "teal_tile_albedo", "", 0.5)
		_: m = _base(CREAM, 0.7)
	if name == "glass": m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if name == "terracotta_floor":
		m.albedo_texture = tex("path_albedo"); m.albedo_color = Color("d28a63")
	_cache[name] = m
	return m

## Character materials depend on the look (skin, hair and outfit colours).
static func char_mat(name: String, look: Dictionary) -> Material:
	var c := func(k: String) -> Color: return Color(String(look.get(k, "888888")))
	match name:
		"skin":
			var m := _textured(c.call("skin"), 0.55, "", "skin_normal", 6.0, 0.25)
			m.rim_enabled = true; m.rim = 0.25; m.rim_tint = 0.6
			m.subsurf_scatter_enabled = true; m.subsurf_scatter_strength = 0.35
			return m
		"hair":
			var m := _textured(c.call("hair_color"), 0.55, "hair_detail", "hair_normal", 4.0, 0.8)
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			return m
		"cloth_top": return _textured(c.call("top"), 0.85, "fabric_detail", "fabric_normal", 5.0, 0.7)
		"cloth_bottom": return _textured(c.call("bottom"), 0.85, "fabric_detail", "fabric_normal", 5.0, 0.7)
		"cloth_outer": return _textured(c.call("outer"), 0.8, "fabric_detail", "fabric_normal", 4.0, 0.9)
		"cloth_knit": return _textured(c.call("knit"), 0.95, "knit_detail", "knit_normal", 4.0, 1.0)
		"shoe": return _base(c.call("shoe"), 0.45)
		"eye_white": return _base(Color("f3efe8"), 0.2)
		"iris": return _base(Color("2b1a10"), 0.1)
		"brow": return _base(c.call("hair_color").darkened(0.2), 0.8)
		"lip": return _base(c.call("skin").darkened(0.25).lerp(Color("a0524a"), 0.3), 0.45)
		"gold": return _base(Color("d6a84e"), 0.25, 1.0)
	return get_mat(name)

## Replace every surface material on every MeshInstance3D under root.
static func apply(root: Node, look: Dictionary = {}) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var nm := src.resource_name if src else ""
			nm = nm.get_slice(".", 0)
			mi.set_surface_override_material(i, char_mat(nm, look) if not look.is_empty() else get_mat(nm))
