class_name WorldSnapshots
extends RefCounted
## Private campaign checkpoints. Restoring returns a complete state and keeps a rollback checkpoint.

const MANUAL_SLOTS := 3
const BEFORE_RESTORE := 0

var _saves: SaveSystem

func _init(directory: String = "user://snapshots") -> void:
	_saves = SaveSystem.new(directory)

static func is_private(state: Dictionary) -> bool:
	return not bool(state.get("settings", {}).get("shared", false))

func _key(state: Dictionary, slot: int) -> String:
	var campaign := "neighborhood" if state.get("world") == "neighborhood" else "alder"
	return "%s_%d" % [campaign, slot]

func has_snapshot(state: Dictionary, slot: int) -> bool:
	return is_private(state) and slot >= BEFORE_RESTORE and slot <= MANUAL_SLOTS and _saves.has_save(_key(state, slot))

func read_snapshot(state: Dictionary, slot: int) -> Dictionary:
	if not is_private(state) or slot < BEFORE_RESTORE or slot > MANUAL_SLOTS:
		return {"ok": false, "error": "Snapshot unavailable in this world."}
	var result := _saves.load_game(_key(state, slot))
	if result["ok"]:
		var saved: Dictionary = result["state"]
		if not is_private(saved) or saved.get("world") != state.get("world"):
			return {"ok": false, "error": "This snapshot belongs to a different world."}
	return result

func capture(state: Dictionary, slot: int) -> Dictionary:
	if not is_private(state) or slot < 1 or slot > MANUAL_SLOTS:
		return {"ok": false, "error": "Snapshot unavailable in this world or slot."}
	return _saves.save(_key(state, slot), state)

func restore(state: Dictionary, slot: int) -> Dictionary:
	var result := read_snapshot(state, slot)
	if not result["ok"]:
		return result
	var rollback := _saves.save(_key(state, BEFORE_RESTORE), state)
	if not rollback["ok"]:
		return {"ok": false, "error": "Could not save the current world before restoring: " + rollback["error"]}
	return result
