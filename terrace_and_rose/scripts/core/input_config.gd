class_name InputConfig
extends RefCounted
## Named, remappable input actions. Defaults live here; player overrides are stored in user://controls.cfg.

const PATH := "user://controls.cfg"
# action: [label, [key specs]]; key spec = keycode name, optionally prefixed "ctrl+" / "shift+", or "mouse:N"
const DEFAULTS := {
	"cam_pan_forward": ["Pan camera forward", ["W", "Up"]],
	"cam_pan_back": ["Pan camera back", ["S", "Down"]],
	"cam_pan_left": ["Pan camera left", ["A", "Left"]],
	"cam_pan_right": ["Pan camera right", ["D", "Right"]],
	"cam_orbit_left": ["Orbit left", ["Q"]],
	"cam_orbit_right": ["Orbit right", ["E"]],
	"cam_zoom_in": ["Zoom in", ["Equal", "mouse:4"]],
	"cam_zoom_out": ["Zoom out", ["Minus", "mouse:5"]],
	"cam_reset": ["Recenter camera", ["Home"]],
	"toggle_walls": ["Walls: up / cutaway / down", ["V"]],
	"speed_pause": ["Pause / resume", ["Space"]],
	"speed_normal": ["Normal speed", ["N"]],
	"speed_fast": ["Fast speed", ["F"]],
	"act_prepare": ["Prepare a meal", ["1"]],
	"act_eat": ["Eat", ["2"]],
	"act_greet": ["Greet visitor", ["3"]],
	"act_sit": ["Sit", ["4"]],
	"act_sleep": ["Sleep", ["5"]],
	"act_walk_focus": ["Walk to focused object", ["G"]],
	"focus_next": ["Focus next object", ["Tab"]],
	"interact": ["Interact / place", ["Enter", "KP Enter"]],
	"cancel_action": ["Cancel current action", ["Backspace"]],
	"clear_queue": ["Clear action queue", ["shift+Backspace"]],
	"furnish_toggle": ["Furnish mode", ["B"]],
	"furnish_rotate": ["Rotate item", ["R"]],
	"furnish_sell": ["Sell hovered item", ["X", "Delete"]],
	"furnish_nudge_up": ["Nudge item up", ["I"]],
	"furnish_nudge_down": ["Nudge item down", ["K"]],
	"furnish_nudge_left": ["Nudge item left", ["J"]],
	"furnish_nudge_right": ["Nudge item right", ["L"]],
	"undo": ["Undo", ["ctrl+Z"]],
	"redo": ["Redo", ["ctrl+Y", "ctrl+shift+Z"]],
	"quick_save": ["Save", ["F5"]],
	"quick_load": ["Load", ["F9"]],
	"menu": ["Menu / back", ["Escape"]],
	"cheat_console": ["Cheat console (owner-approved access)", ["ctrl+shift+C"]],
}

static func make_event(spec: String) -> InputEvent:
	if spec.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(spec.substr(6)) as MouseButton
		return m
	var k := InputEventKey.new()
	var parts := spec.split("+")
	for p in parts.slice(0, parts.size() - 1):
		if p == "ctrl": k.ctrl_pressed = true
		if p == "shift": k.shift_pressed = true
	k.physical_keycode = OS.find_keycode_from_string(parts[-1])
	return k

static func apply() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for action in DEFAULTS:
		if InputMap.has_action(action): InputMap.erase_action(action)
		InputMap.add_action(action)
		var specs: Array = cfg.get_value("bindings", action, DEFAULTS[action][1])
		for s in specs: InputMap.action_add_event(action, make_event(s))

static func bind(action: String, ev: InputEvent) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var spec := event_spec(ev)
	cfg.set_value("bindings", action, [spec])
	cfg.save(PATH)
	apply()

static func reset_defaults() -> void:
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(PATH)
	apply()

static func event_spec(ev: InputEvent) -> String:
	if ev is InputEventMouseButton: return "mouse:%d" % ev.button_index
	var k := ev as InputEventKey
	var pre := ("ctrl+" if k.ctrl_pressed else "") + ("shift+" if k.shift_pressed else "")
	return pre + OS.get_keycode_string(k.physical_keycode)

static func label(action: String) -> String:
	if not InputMap.has_action(action): return "?"
	var evs := InputMap.action_get_events(action)
	if evs.is_empty(): return "unbound"
	var s := event_spec(evs[0])
	return s.replace("mouse:4", "Wheel up").replace("mouse:5", "Wheel down").replace("ctrl+", "Ctrl+").replace("shift+", "Shift+")
