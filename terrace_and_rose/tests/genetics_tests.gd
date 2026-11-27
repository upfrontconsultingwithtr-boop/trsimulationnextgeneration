extends SceneTree
## Run: godot --headless --path . -s tests/genetics_tests.gd
var fails := 0
func check(c: bool, n: String) -> void:
	print("  %s  %s" % ["PASS" if c else "FAIL", n]); if not c: fails += 1

func _init() -> void:
	var a := {"id": "p1", "look": GameState.PRESETS["mara"]["look"], "traits": ["warm", "cook"]}
	var b := {"id": "p2", "look": GameState.PRESETS["jin"]["look"], "traits": ["quiet", "designer"]}
	var k1 := Genetics.make_child(a, b, 42)
	var k2 := Genetics.make_child(a, b, 42)
	check(k1 == k2, "same seed -> same child (reproducible)")
	var sa := Color("8a5537"); var sb := Color("e2bb93")
	var ok := true; var hairs := {}; var bodies := {}
	for s in 200:
		var k := Genetics.make_child(a, b, s)
		var c := Color(String(k["look"]["skin"]))
		var lo := minf(sa.get_luminance(), sb.get_luminance()) - 0.05; var hi := maxf(sa.get_luminance(), sb.get_luminance()) + 0.05
		if c.get_luminance() < lo or c.get_luminance() > hi: ok = false
		hairs[k["look"]["hair_gene"]] = true; bodies[k["look"]["body"]] = true
		if k["traits"].size() < 1: ok = false
	check(ok, "skin stays within both parents' range; traits inherited")
	check(hairs.has("coils") and hairs.has("wavy") and hairs.size() == 2, "hair texture comes from either parent")
	check(bodies.has("curvy") and bodies.has("slender"), "body frame from either parent")
	var t := Genetics.make_child(a, b, 7)
	check(t["genes"]["parents"] == ["p1", "p2"], "child records both parents")
	var twins := 0
	for s in 1000: if Genetics.litter_size(s) >= 2: twins += 1
	check(twins > 40 and twins < 160, "twins happen occasionally (%d/1000)" % twins)
	print("genetics: %d failures" % fails)
	quit(1 if fails else 0)
