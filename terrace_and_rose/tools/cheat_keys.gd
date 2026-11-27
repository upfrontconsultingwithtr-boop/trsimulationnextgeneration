extends SceneTree
## Owner tool for cheat access codes. Keep the private key OUT of the repository.
##   godot --headless --path . -s tools/cheat_keys.gd -- init  [private_key_path]
##       creates an owner private key (default ~/terrace_rose_owner_private.key) and writes the public key into data/
##   godot --headless --path . -s tools/cheat_keys.gd -- issue "Ricardo" [private_key_path]
##       prints the access code for that name; send it privately. In game: Ctrl+Shift+C, enter name + code.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var home := OS.get_environment("HOME") if OS.get_environment("HOME") != "" else OS.get_environment("USERPROFILE")
	var default_key := home.path_join("terrace_rose_owner_private.key")
	if a.size() >= 1 and a[0] == "init":
		var path: String = a[1] if a.size() > 1 else default_key
		if FileAccess.file_exists(path): print("A private key already exists at ", path, " — not overwriting."); quit(1); return
		var key := Crypto.new().generate_rsa(2048)
		key.save(path)
		key.save(ProjectSettings.globalize_path(Cheats.PUBLIC_KEY), true)
		print("Private key (keep secret, back it up): ", path)
		print("Public key written to ", Cheats.PUBLIC_KEY, " — commit this file and rebuild the game.")
		quit(0); return
	if a.size() >= 2 and a[0] == "issue":
		var path: String = a[2] if a.size() > 2 else default_key
		var key := CryptoKey.new()
		if key.load(path) != OK: print("Cannot read private key at ", path); quit(1); return
		print("Name: ", a[1]); print("Code: ", Cheats.make_code(key, a[1]))
		quit(0); return
	print("Usage: init [key_path] | issue \"Name\" [key_path]")
	quit(1)
