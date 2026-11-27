class_name WorldView
extends Node3D
## Builds the active lot from data: floors, modular walls/doors/windows, porch arches, pendants, roof,
## furniture (each with its own collision body) and characters. Reads state; never mutates it.

const WALL_H := 2.7
const WALL_T := 0.22
const CUT_H := 0.45
var sim: Simulation
var lid := ""
var walls: Array[Dictionary] = []      # {node, center}
var roof: Node3D
var furn_nodes := {}                  # fid -> Node3D
var avatars := {}                     # cid -> AvatarView
var lights_interior: Array[OmniLight3D] = []
var sun: DirectionalLight3D
var env: Environment
var wall_mode := 1                    # 0 up, 1 cutaway, 2 down
var house_center := Vector3(8, 0, 6)
var _lay := ""
var structure_nodes: Array[Node] = []
static var low_graphics := false   # software GL / low-end PCs: one cheap sun shadow, no per-light passes

func build(s: Simulation, lot_id: String) -> void:
	sim = s; lid = lot_id; _lay = sim.layout_id(lid)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	structure_nodes.clear()
	walls.clear(); furn_nodes.clear(); avatars.clear(); lights_interior.clear()
	_environment()
	_ground()
	refresh_structure()
	_decor()
	refresh_furniture()

func refresh_structure() -> void:
	for node in structure_nodes:
		remove_child(node)
		node.queue_free()
	structure_nodes.clear()
	for i in range(walls.size() - 1, -1, -1):
		if not walls[i].get("porch", false):
			walls.remove_at(i)
	var start := get_child_count()
	house_center = Vector3(8, 0, 6)
	_floors()
	_walls_and_openings()
	_roof()
	for i in range(start, get_child_count()):
		structure_nodes.append(get_child(i))

static func cw(c: Vector2i) -> Vector3:   # cell centre in world space
	return Vector3((c.x + 0.5) * Catalog.CELL, 0.0, (c.y + 0.5) * Catalog.CELL)

# ------------------------------------------------------------------ environment & light
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("8fbfd0"); sm.sky_horizon_color = Color("f1e3cc"); sm.ground_horizon_color = Color("e7d8bf"); sm.ground_bottom_color = Color("6c7a5a")
	sm.sun_angle_max = 20.0; sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_white = 6.0
	env.ssao_enabled = true; env.ssao_radius = 0.9; env.ssao_intensity = 1.6
	env.glow_enabled = true; env.glow_intensity = 0.35; env.glow_bloom = 0.05
	env.fog_enabled = true; env.fog_light_color = Color("e9dcc7"); env.fog_density = 0.004
	env.adjustment_enabled = true; env.adjustment_saturation = 1.05
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.shadow_blur = 2.0
	if low_graphics:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; env.glow_enabled = false; env.ambient_light_energy = 1.0
	sun.directional_shadow_max_distance = 45.0; sun.light_angular_distance = 1.5
	add_child(sun)

## Coastal day/night: warm morning, soft noon, golden evening, blue night with warm interiors.
func set_time(minute: int) -> void:
	var h := fmod(float(minute) / 60.0, 24.0)
	var day := clampf(sin((h - 6.0) / 12.0 * PI), 0.0, 1.0)
	var golden := clampf(1.0 - absf(h - 18.0) / 2.0, 0.0, 1.0) + clampf(1.0 - absf(h - 7.0) / 1.5, 0.0, 1.0)
	sun.rotation = Vector3(-deg_to_rad(15.0 + 55.0 * day), deg_to_rad(-40.0 + (h - 12.0) * 12.0), 0)
	sun.light_energy = 0.15 + 1.25 * day
	sun.light_color = Color("fff2df").lerp(Color("ffb27a"), clampf(golden, 0.0, 0.8))
	if day <= 0.02: sun.light_color = Color("9fb4e0")
	env.ambient_light_energy = 0.3 + 0.5 * day
	var sm := env.sky.sky_material as ProceduralSkyMaterial
	sm.sky_top_color = Color("1d2848").lerp(Color("8fbfd0"), day)
	sm.sky_horizon_color = Color("3a3f5c").lerp(Color("f1e3cc"), day).lerp(Color("f3b98a"), clampf(golden, 0, 0.6))
	var night := 1.0 - day
	for l in lights_interior: l.light_energy = 0.35 + 1.4 * night

# ------------------------------------------------------------------ static geometry
func _quad_mesh(cells: Array[Vector2i], y: float) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in cells:
		var x0 := c.x * Catalog.CELL; var z0 := c.y * Catalog.CELL; var x1 := x0 + Catalog.CELL; var z1 := z0 + Catalog.CELL
		for v in [[x0, z0], [x1, z0], [x1, z1], [x0, z0], [x1, z1], [x0, z1]]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(v[0], v[1])); st.add_vertex(Vector3(v[0], y, v[1]))
	st.generate_tangents()
	return st.commit()

func _mesh(m: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = mat; mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

func _ground() -> void:
	var p := PlaneMesh.new(); p.size = Vector2(70, 70)
	var g := _mesh(p, Palette.get_mat("grass"), Vector3(8, -0.01, 8), false)
	(g.material_override as StandardMaterial3D).uv1_scale = Vector3(17, 17, 17)

func _floors() -> void:
	var by := {".": [] as Array[Vector2i], "t": [] as Array[Vector2i], "=": [] as Array[Vector2i]}
	for y in LotLayouts.SIZE:
		for x in LotLayouts.SIZE:
			var t := sim.tile(lid, Vector2i(x, y))
			if t == "D" or t == "#" or t == "W": by["."].append(Vector2i(x, y))
			elif by.has(t): by[t].append(Vector2i(x, y))
			elif t == "G": by["="].append(Vector2i(x, y))
	for spec in [[".", 0.03, "walnut_floor"], ["t", 0.02, "terracotta_floor"], ["=", 0.015, "path"]]:
		if not by[spec[0]].is_empty():
			_mesh(_quad_mesh(by[spec[0]], spec[1]), Palette.get_mat(spec[2]), Vector3.ZERO, false)
	var xs := []; var zs := []
	for c in by["."]: xs.append(c.x); zs.append(c.y)
	if not xs.is_empty(): house_center = Vector3((xs.min() + xs.max() + 1) * 0.25, 0, (zs.min() + zs.max() + 1) * 0.25)

func _is_wallish(c: Vector2i) -> bool:
	var t := sim.tile(lid, c)
	return t == "#" or t == "W" or t == "D"

func _walls_and_openings() -> void:
	var stucco := Palette.get_mat("stucco")
	var done := {}
	for y in LotLayouts.SIZE:
		for x in LotLayouts.SIZE:
			var c := Vector2i(x, y)
			var t := sim.tile(lid, c)
			if t != "#" and t != "W" and t != "D": continue
			var node := Node3D.new(); node.position = cw(c); add_child(node)
			if t == "#":
				var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var post := BoxMesh.new(); post.size = Vector3(WALL_T, WALL_H, WALL_T)
				st.append_from(post, 0, Transform3D(Basis(), Vector3(0, WALL_H / 2, 0)))
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _is_wallish(c + d):
						var arm := BoxMesh.new()
						arm.size = Vector3(0.25 if d.x != 0 else WALL_T, WALL_H, 0.25 if d.y != 0 else WALL_T)
						st.append_from(arm, 0, Transform3D(Basis(), Vector3(d.x * 0.125, WALL_H / 2, d.y * 0.125)))
				_child_mesh(node, st.commit(), stucco, Vector3.ZERO)
			elif not done.has(c):
				# W/D come in pairs: place one 1 m module centred between the pair
				var horiz := sim.tile(lid, c + Vector2i(1, 0)) == t
				var other := c + (Vector2i(1, 0) if horiz else Vector2i(0, 1))
				done[other] = true
				var mid := (cw(c) + cw(other)) * 0.5 - node.position
				var mod := Node3D.new(); mod.position = mid; mod.rotation.y = 0.0 if horiz else PI / 2; node.add_child(mod)
				if t == "W": _glb(mod, "res://assets/models/building/window.glb")
				else:
					_glb(mod, "res://assets/models/building/door_frame.glb")
					var leaf := _glb(mod, "res://assets/models/building/door_leaf.glb")
					# hinge on the left jamb; open 90 degrees toward the indoor side
					var inside_plus := sim.tile(lid, c + (Vector2i(0, 1) if horiz else Vector2i(1, 0))) == "."
					leaf.position.x = -0.44; leaf.rotation.y = -PI / 2 if inside_plus else PI / 2
			walls.append({"node": node, "pos": node.position})

func _child_mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func _glb(parent: Node3D, path: String) -> Node3D:
	var n: Node3D = AssetLoader.scene(path)
	Palette.apply(n); parent.add_child(n); return n

func _roof() -> void:
	var xs := []; var zs := []
	for c in LotLayouts.cells_of(_lay, "#", sim.lot(lid).get("structure", {})): xs.append(c.x); zs.append(c.y)
	roof = Node3D.new(); add_child(roof)
	if xs.is_empty(): return
	var x0: float = xs.min() * 0.5 - 0.45; var x1: float = (xs.max() + 1) * 0.5 + 0.45
	var z0: float = zs.min() * 0.5 - 0.45; var z1: float = (zs.max() + 1) * 0.5 + 0.45
	var h := 2.2; var y := WALL_H
	var inset := minf(z1 - z0, x1 - x0) * 0.5
	var r0 := Vector3(x0 + inset, y + h, (z0 + z1) / 2)
	var r1 := Vector3(x1 - inset, y + h, (z0 + z1) / 2)
	var a := Vector3(x0, y, z0); var b := Vector3(x1, y, z0); var c := Vector3(x1, y, z1); var d := Vector3(x0, y, z1)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[a, r0, r1], [a, r1, b], [b, r1, c], [c, r1, r0], [c, r0, d], [d, r0, a], [a, b, c], [a, c, d]]:
		if tri[0] == tri[1] or tri[1] == tri[2] or tri[0] == tri[2]: continue
		for v in tri: st.set_uv(Vector2(v.x + v.z, v.y * 1.4)); st.add_vertex(v)
	st.generate_normals(); st.generate_tangents()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = Palette.get_mat("roof_tile"); roof.add_child(mi)
	(mi.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED

func _decor() -> void:
	var lay := LotLayouts.layout(_lay)
	# porch arches: 'A' column cells pair up left to right
	var cols := LotLayouts.cells_of(_lay, "A")
	if lay["pendants"].is_empty() and cols.is_empty(): pass
	for i in range(0, cols.size() - 1, 2):
		var n := Node3D.new(); n.position = (cw(cols[i]) + cw(cols[i + 1])) * 0.5; add_child(n)
		_glb(n, "res://assets/models/building/porch_arch.glb")
		n.scale.x = (cw(cols[i + 1]).x - cw(cols[i]).x) / 1.75
		walls.append({"node": n, "pos": n.position, "porch": true})
	for p in lay["pendants"]:
		var n := Node3D.new(); n.position = Vector3(p[0] * 0.5, 0, p[1] * 0.5); add_child(n)
		_glb(n, "res://assets/models/building/pendant.glb")
		var l := OmniLight3D.new(); l.light_color = Color("ffc98a"); l.omni_range = 5.5; l.light_energy = 1.0; l.position.y = 1.8
		l.shadow_enabled = false; l.visible = not low_graphics; n.add_child(l); lights_interior.append(l)
	# garden beds, flowers and the low walnut fence are merged into three meshes (few draw calls)
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var flower_cols := [Palette.TERRACOTTA, Color("f2e7d5"), Palette.TEAL, Color("e3b04b"), Color("d77a8f")]
	var beds := SurfaceTool.new(); beds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flowers := SurfaceTool.new(); flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mound := SphereMesh.new(); mound.radius = 0.32; mound.height = 0.25; mound.radial_segments = 12; mound.rings = 6
	var bloom := SphereMesh.new(); bloom.radius = 0.06; bloom.height = 0.1; bloom.radial_segments = 8; bloom.rings = 4
	for c in LotLayouts.cells_of(_lay, "g"):
		beds.append_from(mound, 0, Transform3D(Basis(), cw(c) + Vector3(0, 0.02, 0)))
		for k in 3:
			flowers.set_color(flower_cols[rng.randi() % flower_cols.size()])
			flowers.append_from(bloom, 0, Transform3D(Basis(), cw(c) + Vector3(rng.randf_range(-0.18, 0.18), 0.16, rng.randf_range(-0.18, 0.18))))
	_mesh(beds.commit(), Palette.get_mat("leaf"))
	var fm := StandardMaterial3D.new(); fm.vertex_color_use_as_albedo = true; fm.roughness = 0.7
	_mesh(flowers.commit(), fm, Vector3.ZERO, false)
	var fence := SurfaceTool.new(); fence.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post := BoxMesh.new(); post.size = Vector3(0.08, 0.7, 0.08)
	var gates := LotLayouts.cells_of(_lay, "G")
	for i in LotLayouts.SIZE:
		for e in [Vector2i(i, 0), Vector2i(i, LotLayouts.SIZE - 1), Vector2i(0, i), Vector2i(LotLayouts.SIZE - 1, i)]:
			if not gates.has(e): fence.append_from(post, 0, Transform3D(Basis(), cw(e) + Vector3(0, 0.35, 0)))
	for yy in [0.3, 0.6]:
		var rx := BoxMesh.new(); rx.size = Vector3(16, 0.06, 0.05)
		var rz := BoxMesh.new(); rz.size = Vector3(0.05, 0.06, 16)
		var rs := BoxMesh.new(); rs.size = Vector3(7.5, 0.06, 0.05)
		fence.append_from(rx, 0, Transform3D(Basis(), Vector3(8, yy, 0.25)))
		fence.append_from(rs, 0, Transform3D(Basis(), Vector3(3.75, yy, 15.75))); fence.append_from(rs, 0, Transform3D(Basis(), Vector3(12.25, yy, 15.75)))
		fence.append_from(rz, 0, Transform3D(Basis(), Vector3(0.25, yy, 8))); fence.append_from(rz, 0, Transform3D(Basis(), Vector3(15.75, yy, 8)))
	_mesh(fence.commit(), Palette.get_mat("walnut"))

# ------------------------------------------------------------------ dynamic content
func refresh_furniture() -> void:
	var f := sim.furniture(lid)
	for fid in furn_nodes.keys():
		if not f.has(fid): furn_nodes[fid].queue_free(); furn_nodes.erase(fid)
	for fid in f:
		if furn_nodes.has(fid): continue
		furn_nodes[fid] = make_furniture(f[fid]["item"], GameState.cell_of(f[fid]["cell"]), int(f[fid]["rot"]), fid)
		add_child(furn_nodes[fid])

static func furniture_transform(item: String, cell: Vector2i, rot: int) -> Transform3D:
	var fs := Catalog.footprint_size(item, rot)
	var p := Vector3((cell.x + fs.x * 0.5) * Catalog.CELL, 0, (cell.y + fs.y * 0.5) * Catalog.CELL)
	return Transform3D(Basis(Vector3.UP, -rot * PI / 2.0), p)

## One reusable furniture module: model, collision box sized to its footprint, and light if any.
static func make_furniture(item: String, cell: Vector2i, rot: int, fid: String = "") -> Node3D:
	var def := Catalog.get_def(item)
	var root := Node3D.new(); root.name = "F_" + (fid if fid != "" else item)
	root.transform = furniture_transform(item, cell, rot)
	var m: Node3D = AssetLoader.scene(def["model"])
	Palette.apply(m); root.add_child(m)
	var body := StaticBody3D.new(); body.collision_layer = 4; body.set_meta("fid", fid)
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new()
	var s: Array = def["size"]
	box.size = Vector3(s[0] * Catalog.CELL * 0.95, maxf(0.1, def["height"]), s[1] * Catalog.CELL * 0.95)
	cs.shape = box; cs.position.y = box.size.y / 2; body.add_child(cs); root.add_child(body)
	if def.get("light", false):
		var l := OmniLight3D.new(); l.light_color = Color("ffcf94"); l.omni_range = 4.0; l.light_energy = 0.9; l.position.y = 1.45; l.visible = not low_graphics; root.add_child(l)
	return root

func sync_characters(delta: float, minute: int) -> void:
	var speed := int(Simulation.SPEED_TICKS[int(sim.state["speed"])])
	var present := {}
	for ch in sim.chars_on(lid):
		present[ch["id"]] = true
		if not avatars.has(ch["id"]):
			var a := AvatarView.new(); add_child(a); a.setup(ch); avatars[ch["id"]] = a
		(avatars[ch["id"]] as AvatarView).sync(ch, delta, speed, minute)
	for cid in avatars.keys():
		if not present.has(cid): avatars[cid].queue_free(); avatars.erase(cid)

## Cutaway: lower walls between camera and the house centre so rooms and people stay visible.
func update_cutaway(cam_dir_flat: Vector3) -> void:
	roof.visible = wall_mode == 0
	for w in walls:
		var n: Node3D = w["node"]
		var low := false
		if wall_mode == 2: low = not w.get("porch", false)
		elif wall_mode == 1:
			var v: Vector3 = w["pos"] - house_center; v.y = 0
			low = v.normalized().dot(-cam_dir_flat) > 0.15 and not w.get("porch", false)
		var target := CUT_H / WALL_H if low else 1.0
		n.scale.y = lerpf(n.scale.y, target, 0.25)
