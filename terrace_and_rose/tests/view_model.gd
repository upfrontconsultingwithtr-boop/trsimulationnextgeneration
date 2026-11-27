extends SceneTree
## Render a GLB in a neutral studio for art review. godot --path . -s tests/view_model.gd -- <glb> <out.png> [yaw_deg]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var root := Node3D.new(); get_root().add_child(root)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("e9e1d3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("fff6ea"); env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; we.environment = env; root.add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, 35, 0); key.light_energy = 1.6; key.shadow_enabled = true; root.add_child(key)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-15, -140, 0); fill.light_energy = 0.5; root.add_child(fill)
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(a[0], st)
	var m: Node3D = doc.generate_scene(st)
	m.rotation_degrees.y = float(a[2]) if a.size() > 2 else 20.0
	root.add_child(m)
	var cam := Camera3D.new(); cam.fov = 30; root.add_child(cam)
	var close := a.size() > 3 and a[3] == "face"
	cam.position = Vector3(0, 1.55, 1.0) if close else Vector3(0, 1.0, 4.4); cam.look_at(Vector3(0, 1.5 if close else 0.9, 0))
	for i in 12: await process_frame
	get_root().get_texture().get_image().save_png(a[1])
	quit()
