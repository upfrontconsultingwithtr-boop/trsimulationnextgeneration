# Rebuilding the realistic humans

The generated GLBs are already committed, so you only need this to change or add bodies.

1. Install Blender 4.2 LTS (free).
2. Install the MPFB extension. In Blender, open Edit → Preferences → Get Extensions and search for "MPFB". From a terminal:
   `blender -b --command extension install-file -r user_default -e add-on-mpfb-v2.0.18.zip`
3. Download the CC0 asset packs from https://static.makehumancommunity.org/assets/assetpacks.html: **makehuman_system_assets**, **skins01**, **hair01** and **eyebrows01**.
   Unzip them into MPFB's user data folder. Blender reports its location; on Linux it is `~/.config/blender/4.2/extensions/.user/user_default/mpfb/data`.
4. From `terrace_and_rose/`, run:
   `blender -b --python-exit-code 1 -P tools/blender/build_humans.py` (or add `-- f_adult m_elder …` to build only some bodies).
   This takes about 20 seconds per body and writes `assets/models/humans/human_<body>.glb`.
5. After a rebuild, make sure each `human_*.glb.import` has `gltf/embedded_image_handling=3` so Godot keeps textures inside the model.

Bodies: f/m adult, teen and elder, plus a child. Morphs on every mesh: african, asian, caucasian, heavy, slim, muscular, older, and bust (female bodies).
Hair: coils, wavy, curls_short, bun, long, braid, bob. Outfits: casual, shirt, knit_jacket, dress, overalls, plus shoes.
