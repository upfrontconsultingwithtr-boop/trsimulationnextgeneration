class_name CameraRig
extends Node3D
## Orbiting three-quarter camera: Q/E or right-drag orbit, WASD or middle-drag pan, wheel or +/- zoom.

var yaw := deg_to_rad(35.0)
var pitch := deg_to_rad(-42.0)
var dist := 17.0
var bounds := Rect2(-4, -4, 24, 24)
var cam: Camera3D
var _drag := 0
var input_enabled := true
var auto_orbit := 0.0

func _ready() -> void:
	cam = Camera3D.new(); cam.fov = 40.0; cam.far = 300.0; add_child(cam)
	_apply()

func focus(p: Vector3, d: float = -1.0) -> void:
	position = p
	if d > 0: dist = d
	_apply()

func _apply() -> void:
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.position = off
	cam.look_at(global_position + Vector3(0, 0.6, 0), Vector3.UP)

func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled: return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT: _drag = 1 if mb.pressed else 0
		elif mb.button_index == MOUSE_BUTTON_MIDDLE: _drag = 2 if mb.pressed else 0
	elif e is InputEventMouseMotion and _drag != 0:
		var mm := e as InputEventMouseMotion
		if _drag == 1:
			yaw -= mm.relative.x * 0.008
			pitch = clampf(pitch - mm.relative.y * 0.006, deg_to_rad(-80), deg_to_rad(-15))
		else:
			_pan(Vector2(-mm.relative.x, -mm.relative.y) * 0.02 * dist / 15.0)
		_apply()
	elif e is InputEventPanGesture:
		_pan((e as InputEventPanGesture).delta * 0.3); _apply()
	elif e is InputEventMagnifyGesture:
		dist = clampf(dist / (e as InputEventMagnifyGesture).factor, 4.0, 40.0); _apply()

func _pan(v: Vector2) -> void:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	position += right * v.x + fwd * -v.y

func _process(delta: float) -> void:
	if auto_orbit != 0.0:
		yaw += auto_orbit * delta; _apply(); return
	if not input_enabled: return
	var v := Vector2(Input.get_axis("cam_pan_left", "cam_pan_right"), Input.get_axis("cam_pan_back", "cam_pan_forward"))
	var changed := false
	if v != Vector2.ZERO: _pan(Vector2(v.x, -v.y) * delta * 9.0 * dist / 15.0); changed = true
	var o := Input.get_axis("cam_orbit_left", "cam_orbit_right")
	if o != 0.0: yaw += o * delta * 1.8; changed = true
	if Input.is_action_just_pressed("cam_zoom_in"): dist = maxf(4.0, dist * 0.88); changed = true
	if Input.is_action_just_pressed("cam_zoom_out"): dist = minf(40.0, dist * 1.12); changed = true
	if changed: _apply()

func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))
