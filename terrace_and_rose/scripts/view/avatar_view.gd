class_name AvatarView
extends Node3D
## Renders one character from state: shared-rig GLB body + hair/outfit/accessory variants,
## smooth movement between simulation ticks, and walk/sit/stand/sleep animation transitions.

const LOOPS := ["idle", "walk", "sit_idle", "sit_eat", "eat", "cook", "sleep"]
var cid := ""
var model: Node3D
var anim: AnimationPlayer
var _pose := "stand"
var _queued_anim := ""
var _look_hash := 0
var pick: StaticBody3D
var holding_mesh: MeshInstance3D

static func cell_to_world(c: Vector2) -> Vector3:
	return Vector3(c.x * Catalog.CELL, 0.0, c.y * Catalog.CELL)

func setup(ch: Dictionary) -> void:
	cid = ch["id"]
	_build(ch)
	position = _target_pos(ch)
	rotation.y = deg_to_rad(float(ch["facing"]))

func _build(ch: Dictionary) -> void:
	if model: model.queue_free()
	var look: Dictionary = ch["look"]
	_look_hash = hash(look)
	var scene: PackedScene = load("res://assets/models/avatars/avatar_%s.glb" % look.get("body", "curvy"))
	model = scene.instantiate()
	add_child(model)
	var age := String(ch.get("age", "adult"))
	model.scale = Vector3.ONE * {"child": 0.62, "teen": 0.9, "adult": 1.0, "elder": 0.98}.get(age, 1.0)
	var accs: Array = look.get("accessories", [])
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.begins_with("hair_"): mi.visible = n == "hair_" + String(look.get("hair", "coils"))
		elif n.begins_with("outfit_"): mi.visible = n.begins_with("outfit_%s__" % look.get("outfit", "casual"))
		elif n.begins_with("acc_"): mi.visible = accs.has(n.substr(4))
	Palette.apply(model, look)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in LOOPS:
			if anim.has_animation(a): anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_anim_finished)
		anim.play("idle")
	if pick == null:
		pick = StaticBody3D.new(); pick.set_meta("cid", cid); pick.collision_layer = 2
		var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
		cs.shape = cap; cs.position.y = 0.85; pick.add_child(cs); add_child(pick)
		holding_mesh = MeshInstance3D.new()
		var plate := CylinderMesh.new(); plate.top_radius = 0.13; plate.bottom_radius = 0.1; plate.height = 0.03
		holding_mesh.mesh = plate; holding_mesh.material_override = Palette.get_mat("ceramic")
		holding_mesh.position = Vector3(0, 1.0, 0.32); add_child(holding_mesh)

func _target_pos(ch: Dictionary) -> Vector3:
	var a: Array = ch["anchor"]
	if a.size() == 2: return cell_to_world(Vector2(a[0], a[1]) / 100.0)
	var c := GameState.cell_of(ch["cell"])
	return cell_to_world(Vector2(c) + Vector2(0.5, 0.5))

func sync(ch: Dictionary, delta: float, speed_ticks: int, minute: int) -> void:
	if hash(ch["look"]) != _look_hash: _build(ch)
	var target := _target_pos(ch)
	var walking: bool = ch["anim"] == "walk" and position.distance_to(target) > 0.02
	var rate := maxf(4.0, float(speed_ticks)) * Catalog.CELL * 1.05   # cells/s * m/cell
	if ch["pose"] != "stand" or position.distance_to(target) > 2.0: position = position.lerp(target, minf(1.0, delta * 10.0))
	else: position = position.move_toward(target, rate * delta)
	var yaw := deg_to_rad(float(ch["facing"]))
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 12.0))
	holding_mesh.visible = ch["holding"] == "meal"
	if anim == null: return
	anim.speed_scale = clampf(float(speed_ticks) / 4.0, 1.0, 3.0) if walking else 1.0
	var pose: String = ch["pose"]
	var want: String = ch["anim"]
	if walking: want = "walk"
	elif ch["anim"] == "walk": want = "idle"
	if pose == "stand" and int(ch.get("react_until", 0)) > minute and ch["current"].is_empty(): want = "wave"
	if pose != _pose:
		if _pose == "sit" and pose == "stand": _transition("stand_up", want)
		elif pose == "sit": _transition("sit_down", want)
		else: anim.play(want, 0.25)
		_pose = pose
		return
	if _queued_anim != "": return
	if anim.current_animation != want and anim.has_animation(want): anim.play(want, 0.2)

func _transition(t: String, after: String) -> void:
	_queued_anim = after
	anim.play(t, 0.15)

func _on_anim_finished(n: StringName) -> void:
	if _queued_anim != "":
		var a := _queued_anim; _queued_anim = ""
		anim.play(a, 0.2)
	elif n == "wave": anim.play("idle", 0.2)
