extends SceneTree
## Loads every script so parse/type errors surface in one pass. Run: godot --headless --path . -s tests/lint.gd
func _init() -> void:
	var bad := 0
	for dir in ["res://scripts/core", "res://scripts/view", "res://scripts/ui", "res://scripts", "res://tests"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "lint.gd" and not f.ends_with("_tests.gd") and f != "run_tests.gd":
				var s: Script = load(dir.path_join(f))
				if s == null or not s.can_instantiate(): bad += 1; print("LINT FAIL ", dir.path_join(f))
	print("lint: %d failing scripts" % bad)
	quit(1 if bad else 0)
