class_name SaveSystem
extends RefCounted
## Versioned JSON saves with checksum. Writes go to a temp file, are re-read and validated, then the
## previous valid primary is rotated to .bak before the temp file replaces it. A corrupt primary is
## never copied over a good backup, and loading never writes.

const FORMAT := "terrace_and_rose_save"

var dir: String

func _init(save_dir: String = "user://saves") -> void:
	dir = save_dir

func primary(slot: String) -> String: return dir.path_join(slot + ".json")
func backup(slot: String) -> String: return dir.path_join(slot + ".bak.json")
func temp(slot: String) -> String: return dir.path_join(slot + ".tmp.json")

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(primary(slot)) or FileAccess.file_exists(backup(slot))

static func encode(state: Dictionary) -> String:
	return JSON.stringify({"format": FORMAT, "version": GameState.VERSION, "checksum": GameState.checksum(state), "state": state}, "\t", true)

## Returns {ok, state, error}
static func decode(text: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(text) != OK: return {"ok": false, "error": "not valid JSON (line %d)" % j.get_error_line()}
	var d: Variant = GameState.normalize(j.data)
	if typeof(d) != TYPE_DICTIONARY or d.get("format") != FORMAT: return {"ok": false, "error": "not a Terrace & Rose save"}
	var ver := int(d.get("version", -1))
	if ver < 1 or ver > GameState.VERSION: return {"ok": false, "error": "unsupported save version %s" % d.get("version")}
	var s: Variant = d.get("state")
	if typeof(s) != TYPE_DICTIONARY: return {"ok": false, "error": "state missing"}
	if GameState.checksum(s) != d.get("checksum"): return {"ok": false, "error": "checksum mismatch (file damaged)"}
	s = GameState.migrate(s)   # older saves are upgraded, never discarded
	var errs := GameState.validate(s)
	if not errs.is_empty(): return {"ok": false, "error": "; ".join(errs)}
	return {"ok": true, "state": s, "error": "", "migrated_from": ver}

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "error": "no file"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {"ok": false, "error": "cannot open"}
	return decode(f.get_as_text())

func save(slot: String, state: Dictionary) -> Dictionary:
	var errs := GameState.validate(state)
	if not errs.is_empty(): return {"ok": false, "error": "refusing to save invalid state: " + "; ".join(errs)}
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(temp(slot), FileAccess.WRITE)
	if f == null: return {"ok": false, "error": "cannot write temp file"}
	f.store_string(encode(state))
	f.close()
	if not _read(temp(slot))["ok"]: return {"ok": false, "error": "written save failed verification"}
	var d := DirAccess.open(dir)
	if _read(primary(slot))["ok"]:
		if d.file_exists(backup(slot).get_file()): d.remove(backup(slot).get_file())
		d.rename(primary(slot).get_file(), backup(slot).get_file())
	elif d.file_exists(primary(slot).get_file()):
		d.remove(primary(slot).get_file())   # damaged primary: discard it, keep the existing backup
	var err := d.rename(temp(slot).get_file(), primary(slot).get_file())
	if err != OK: return {"ok": false, "error": "rename failed (%d)" % err}
	return {"ok": true, "error": ""}

## Returns {ok, state, from: "primary"|"backup", error, warning}
func load_game(slot: String) -> Dictionary:
	var p := _read(primary(slot))
	if p["ok"]: return {"ok": true, "state": p["state"], "from": "primary", "error": "", "warning": ""}
	var b := _read(backup(slot))
	if b["ok"]:
		return {"ok": true, "state": b["state"], "from": "backup", "error": "", "warning": "Main save was damaged (%s); loaded the previous backup." % p["error"]}
	return {"ok": false, "state": {}, "from": "", "error": "No usable save: main %s, backup %s." % [p["error"], b["error"]], "warning": ""}
