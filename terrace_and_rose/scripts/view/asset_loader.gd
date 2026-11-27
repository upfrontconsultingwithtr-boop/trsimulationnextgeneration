class_name AssetLoader
extends RefCounted
## Loads the project's original GLB / PNG / WAV files directly at runtime (no editor import step needed).
## Works in the editor, headless CI and exported builds (export preset includes assets/*).

static var _gltf := {}
static var _tex := {}
static var _wav := {}

static func scene(path: String) -> Node3D:
	# GLTFState can only generate a scene once, so the first result is packed and instanced from then on.
	var packed: PackedScene = _gltf.get(path)
	if packed == null and ResourceLoader.exists(path):   # imported (editor / exported build)
		packed = load(path) as PackedScene
		if packed: _gltf[path] = packed
	if packed == null:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		var err := doc.append_from_file(path, st)
		if err != OK:
			push_error("AssetLoader: cannot load %s (%d)" % [path, err])
			return Node3D.new()
		var root := doc.generate_scene(st) as Node3D
		for n in root.find_children("*", "", true, false): n.owner = root
		packed = PackedScene.new()
		packed.pack(root)
		root.free()
		_gltf[path] = packed
	return packed.instantiate() as Node3D

static func texture(path: String) -> Texture2D:
	if _tex.has(path): return _tex[path]
	if ResourceLoader.exists(path):
		var r := load(path) as Texture2D
		if r: _tex[path] = r; return r
	if not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(path)
	if img == null: return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[path] = t
	return t

static func wav(path: String) -> AudioStreamWAV:
	if _wav.has(path): return _wav[path]
	if ResourceLoader.exists(path):
		var r := load(path) as AudioStreamWAV
		if r: _wav[path] = r; return r
	var s := AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else null
	_wav[path] = s
	return s
