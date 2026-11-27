class_name Genetics
extends RefCounted
## Child "DNA" from two parents. Used by both in-game pregnancies and the family creator's
## "make a child from two parents" button, so both paths produce consistent results.
## Deterministic for a given seed so a re-roll is reproducible and saves stay exact.

const HAIR_FAMILIES := ["coils", "wavy", "curls_short", "bun", "long"]
const BODIES := ["curvy", "slender", "classic"]
const CHILD_OUTFIT_COLORS := ["c2643f", "86bdb2", "e3b04b", "ede4d1", "6e4b31", "d77a8f", "4f8f86"]

static func _c(look: Dictionary, k: String, fallback: String = "888888") -> Color:
	return Color(String(look.get(k, fallback)))

## Natural hair colour (elders keep their pre-silver colour as a gene).
static func natural_hair(look: Dictionary) -> String:
	return String(look.get("hair_natural", look.get("hair_color", "1d1611")))

## Returns {look, traits, genes}. a/b are character dicts (need "look" and optional "traits").
static func make_child(a: Dictionary, b: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var la: Dictionary = a["look"]; var lb: Dictionary = b["look"]
	# skin: blend with a random weight, then a tiny variation (never outside the parents' range by much)
	var t := rng.randf_range(0.25, 0.75)
	var skin := _c(la, "skin").lerp(_c(lb, "skin"), t)
	skin = skin.lightened(rng.randf_range(-0.03, 0.03)) if rng.randf() < 0.5 else skin.darkened(rng.randf_range(0.0, 0.03))
	# hair colour: dominant darker pigment more likely, otherwise a blend
	var ha := Color(natural_hair(la)); var hb := Color(natural_hair(lb))
	var hair := ha if ha.get_luminance() < hb.get_luminance() else hb
	if rng.randf() < 0.35: hair = ha.lerp(hb, rng.randf())
	# hair texture: inherited from one parent (tighter curl patterns slightly dominant)
	var tex_a := String(la.get("hair_gene", la.get("hair", "wavy"))); var tex_b := String(lb.get("hair_gene", lb.get("hair", "wavy")))
	var curl := {"coils": 3, "curls_short": 2, "wavy": 1, "bun": 0, "long": 0}
	var wa: float = 1.0 + float(curl.get(tex_a, 0)) * 0.25; var wb: float = 1.0 + float(curl.get(tex_b, 0)) * 0.25
	var hair_gene := tex_a if rng.randf() < wa / (wa + wb) else tex_b
	# body frame and height
	var body := String(la.get("body", "classic")) if rng.randf() < 0.5 else String(lb.get("body", "classic"))
	var height := clampf((float(la.get("height", 1.0)) + float(lb.get("height", 1.0))) * 0.5 + rng.randf_range(-0.04, 0.04), 0.9, 1.1)
	var eyes := String(la.get("eyes", "2b1a10")) if rng.randf() < 0.5 else String(lb.get("eyes", "2b1a10"))
	var top: String = CHILD_OUTFIT_COLORS[rng.randi() % CHILD_OUTFIT_COLORS.size()]
	var look := {"body": body, "hair": "curls_short" if hair_gene == "curls_short" else hair_gene, "hair_gene": hair_gene, "outfit": "casual", "accessories": [],
		"skin": skin.to_html(false), "hair_color": hair.to_html(false), "hair_natural": hair.to_html(false), "eyes": eyes, "height": snappedf(height, 0.01),
		"top": top, "bottom": "4d4842", "outer": top, "knit": top, "shoe": "3a3532"}
	# personality: one trait from each parent when possible, plus a chance of something new
	var traits: Array = []
	var ta: Array = a.get("traits", []); var tb: Array = b.get("traits", [])
	if not ta.is_empty(): traits.append(ta[rng.randi() % ta.size()])
	if not tb.is_empty():
		var pick: String = tb[rng.randi() % tb.size()]
		if not traits.has(pick): traits.append(pick)
	return {"look": look, "traits": traits, "genes": {"parents": [a.get("id", ""), b.get("id", "")], "seed": seed, "skin_mix": snappedf(t, 0.01), "hair_from": "a" if hair_gene == tex_a else "b"}}

## How many babies a successful conception produces (twins ~8%, triplets ~1%).
static func litter_size(seed: int) -> int:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var r := rng.randf()
	return 3 if r < 0.01 else (2 if r < 0.09 else 1)
