class_name AssetLoader
extends RefCounted
## Loads the project's original GLB / PNG / WAV files directly at runtime (no editor import step needed).
## Works in the editor, headless CI and exported builds (export preset includes assets/*).

static var _gltf := {}
static var _tex := {}
static var _wav := {}

static func scene(path: String) -> Node3D:
	var st: GLTFState = _gltf.get(path)
	var doc := GLTFDocument.new()
	if st == null:
		st = GLTFState.new()
		var err := doc.append_from_file(path, st)
		if err != OK:
			push_error("AssetLoader: cannot load %s (%d)" % [path, err])
			return Node3D.new()
		_gltf[path] = st
	return doc.generate_scene(st) as Node3D

static func texture(path: String) -> Texture2D:
	if _tex.has(path): return _tex[path]
	if not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(path)
	if img == null: return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[path] = t
	return t

static func wav(path: String) -> AudioStreamWAV:
	if _wav.has(path): return _wav[path]
	var s := AudioStreamWAV.load_from_file(path)
	_wav[path] = s
	return s
