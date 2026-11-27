class_name HarborScenery
extends Node3D
## Original harbor geometry, kept outside simulation so saves stay small.

var markers := {}

func build() -> void:
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color("c1a984")
	sand.albedo_texture = Palette.tex("path_albedo")
	sand.roughness = 0.97
	sand.uv1_scale = Vector3(30, 40, 1)
	_plane(Vector2(85, 120), Vector3(45, -0.018, 8), sand)

	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/shaders/harbor_water.gdshader")
	_plane(Vector2(180, 220), Vector3(-87.5, -0.055, 8), water)

	var basalt := _mat(Color("6a706c"))
	var pale_stone := _mat(Color("8a8f80"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4907
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	for i in 34:
		var x := lerpf(-16, -6, float(i) / 33.0) + rng.randf_range(-0.6, 0.6)
		var z := -4.8 + rng.randf_range(-0.9, 0.9) + (x + 16) * 0.23
		var node := _mesh(rock, Vector3(x, 0.02, z), basalt if i % 3 != 0 else pale_stone)
		node.scale = Vector3(rng.randf_range(0.7, 1.7), rng.randf_range(0.55, 1.45), rng.randf_range(0.7, 1.7))
		node.rotation.y = rng.randf_range(-PI, PI)
	_build_beacon(Vector3(-14, 0, -4.2))
	_build_deck(rng)
	for spot_id in HarborTrip.SPOTS:
		var spot: Dictionary = HarborTrip.SPOTS[spot_id]
		var marker := Label3D.new()
		marker.position = WorldView.cw(spot["cell"]) + Vector3(0, 0.30, 0)
		marker.text = spot["place"]
		marker.font_size = 32
		marker.pixel_size = 0.006
		marker.outline_size = 8
		marker.modulate = Color("ffe1aa")
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(marker)
		markers[spot_id] = marker

func update_finds(finds: Array) -> void:
	for spot_id in markers:
		markers[spot_id].visible = not finds.has(spot_id)

func _build_deck(rng: RandomNumberGenerator) -> void:
	var deck_materials := [_mat(Color("977657")), _mat(Color("9f8160")), _mat(Color("b09473"))]
	var batches: Array[SurfaceTool] = []
	for material in deck_materials:
		var batch := SurfaceTool.new()
		batch.begin(Mesh.PRIMITIVE_TRIANGLES)
		batch.set_material(material)
		batches.append(batch)
	var plank := BoxMesh.new()
	plank.size = Vector3(1.98, 0.055, 0.155)
	for i in 100:
		var batch := batches[rng.randi_range(0, batches.size() - 1)]
		batch.append_from(plank, 0, Transform3D(Basis(), Vector3(6, -0.01, i * 0.16 + 0.08)))
	var front_plank := BoxMesh.new()
	front_plank.size = Vector3(8.0, 0.062, 0.155)
	for i in 9:
		var batch := batches[rng.randi_range(0, batches.size() - 1)]
		batch.append_from(front_plank, 0, Transform3D(Basis(), Vector3(11, -0.01, 10 + i * 0.16 + 0.08)))
	for batch in batches:
		_mesh(batch.commit(), Vector3.ZERO, null)
	var timber := Palette.get_mat("walnut")
	var post := BoxMesh.new()
	post.size = Vector3(0.13, 1.0, 0.13)
	for x in [7.4, 8.65, 9.9, 12.1, 13.35, 14.6]:
		_mesh(post, Vector3(x, 0.48, 11.4), timber)
	var rail := BoxMesh.new()
	rail.size = Vector3(2.5, 0.075, 0.08)
	for x in [8.65, 13.35]:
		for height in [0.48, 0.9]:
			_mesh(rail, Vector3(x, height, 11.4), timber)

func _build_beacon(at: Vector3) -> void:
	var ivory := _mat(Color("d6d5bb"))
	var copper := _mat(Color("9a5140"))
	var iron := _mat(Color("35474a"))
	var beacon := _mat(Color("f6ce83"))
	beacon.emission_enabled = true
	beacon.emission = Color("ffc26a")
	var base := CylinderMesh.new()
	base.height = 3.6
	base.bottom_radius = 0.86
	base.top_radius = 0.56
	_mesh(base, at + Vector3(0, 1.9, 0), ivory)
	var cap := CylinderMesh.new()
	cap.height = 0.18
	cap.top_radius = 0.79
	cap.bottom_radius = 0.70
	_mesh(cap, at + Vector3(0, 3.68, 0), iron)
	var lens := CylinderMesh.new()
	lens.height = 0.62
	lens.top_radius = 0.42
	lens.bottom_radius = 0.42
	_mesh(lens, at + Vector3(0, 4.05, 0), beacon)
	var dome := CylinderMesh.new()
	dome.height = 0.63
	dome.bottom_radius = 0.62
	dome.top_radius = 0.04
	_mesh(dome, at + Vector3(0, 4.67, 0), copper)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _plane(size: Vector2, at: Vector3, mat: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	_mesh(plane, at, mat)

func _mesh(mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	if mesh is PlaneMesh:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
