# Terrace & Rose

An original 3D life simulation built with **Godot 4.5 (stable)**, **typed GDScript** and **Blender 4.2 LTS**.
It is offline and desktop-first, uses local saves, and costs $0 to develop: no paid tools, plugins, assets or services.

**Milestone 1 — A Day at Alder Bungalow** (this build): pick an avatar preset, live one day in a furnished
16 × 16 m bungalow, cook and eat, greet the neighbor who visits at 10:00, sit, sleep, and furnish the home with undo/redo.

## Run it
1. Install Godot **4.5.1-stable** (standard build, not .NET) from https://godotengine.org/download.
2. Open Godot, choose **Import**, and select `terrace_and_rose/project.godot`. Then press **Run (F5)**.
   From a terminal: `godot --path terrace_and_rose`

## Tests (exact commands, run from `terrace_and_rose/`)
```bash
godot --headless --path . --import                  # first time only: builds the class cache (see note)
godot --headless --path . -s tests/lint.gd          # every script parses and type-checks
godot --headless --path . -s tests/run_tests.gd     # Milestone-1 regression suite (69 checks)
godot --headless --path . -s tests/genetics_tests.gd   # Part 2 genetics (child DNA) checks
# graphical smoke test: plays the day and writes screenshots to build/smoke/
godot --path . -- --smoke
# on a machine without a GPU (Linux CI):
xvfb-run -a godot --path . --rendering-method gl_compatibility -- --smoke
```
Each command exits with code 0 on success.

Note: models, textures and audio load at runtime through `AssetLoader` (Godot's built-in glTF, Image and WAV loaders),
so the game does not depend on the editor's import step. On some headless Linux machines, `--import` registers
the script classes and then idles instead of quitting. If that happens, stop it after about 20 seconds; the class cache is already built.

## Rebuild the art and audio (optional)
`blender -b --python-exit-code 1 -P tools/blender/build_assets.py` regenerates every GLB, texture, WAV and `.blend` source.
To rebuild only part of it, add `-- textures`, `-- audio`, `-- props` or `-- avatars`.

## Controls (all remappable: Menu → Controls; saved to `user://controls.cfg`)
| Action | Default |
|---|---|
| Pan / orbit / zoom | WASD or arrows, middle-drag · Q/E, right-drag · mouse wheel or +/- |
| Walls: up → cutaway → down | V |
| Pause / Normal / Fast | Space / N / F |
| Prepare meal, Eat, Greet, Sit, Sleep | 1 2 3 4 5 |
| Focus next object, interact, walk to it | Tab, Enter, G |
| Cancel current action / clear queue | Backspace / Shift+Backspace |
| Furnish mode · items · rotate · sell · nudge | B · 1–8 · R · X · I J K L |
| Undo / Redo | Ctrl+Z / Ctrl+Y |
| Save / Load / Menu | F5 / F9 / Esc |
Left-click the floor to walk there. Left-click an object or person for a menu (the arrow keys and Enter also work in it).

## Architecture
- `scripts/core/` contains pure state and rules, with no scene or UI code. It is fully testable headless.
  - `game_state.gd` holds JSON-safe data: money in **integer cents**, time in **integer minutes** plus fixed sub-ticks, needs as integers from 0 to 10000, and stable string IDs.
  - `simulation.gd` runs **fixed ticks**: 4 per game minute, at 0, 4 or 24 ticks per second regardless of frame rate. It handles the action queue, approach paths (A*), interaction-slot **reservations** and their release, needs, the schedule and the visitor.
  - `furnishing.gd` handles placement validation and buy/sell, with undo/redo that covers furniture and funds. A failed operation changes nothing.
  - `save_system.gd` writes versioned, checksummed JSON. It writes to a temp file and verifies it, then rotates the old save to `.bak` and swaps in the new one. A corrupt main save falls back to the backup, and a backup is never overwritten by a bad file.
  - `catalog.gd` and `lot_layouts.gd` define the furniture (footprints, approach points, slots) and the lot map as ASCII (the M1 lot editor).
  - `genetics.gd` creates a child's look and traits from two parents (used in Part 2).
- `scripts/view/` contains the 3D rendering: modular walls, doors and windows, cutaway, lighting, avatars, camera, and the `Palette` that owns the art direction.
- `scripts/ui/` contains the HUD, menus, key remapping and theme.

Saves live in `user://saves/household1.json` (plus `.bak.json`). On Linux that is `~/.local/share/godot/app_userdata/Terrace & Rose/`.

## Art status (needs an art pass)
The avatars, furniture and modules are **original procedural placeholders**. They are game-ready and consistent, but not final art:
- **Avatars:** bodies made with Blender's skin modifier and distance-based skin weights. Faces are simple primitives with a blink, brow raise and jaw. Hair is built from primitive clusters. An artist should sculpt and retopologize the heads, hair cards and clothing in the existing `.blend` files and keep the rig's bone names.
- **Animations** are hand-keyed in code: idle, walk, sit_down, sit_idle, stand_up, eat, sit_eat, cook, wave and sleep. They need motion polish.
- **Building:** door leaves are posed open (no swing animation yet). The roof is a simple hip roof.
- **Audio** is synthesised; a sound designer pass is recommended.

See `../docs/ROADMAP.md` for Milestones 2–6 and the Part 2 plan.
