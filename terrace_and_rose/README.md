# Terrace & Rose

An original 3D life simulation built with **Godot 4.5 (stable)**, **typed GDScript** and **Blender 4.2 LTS**.
It is offline and desktop-first, uses local saves, and costs $0 to develop: no paid tools, plugins, assets or services.

**Milestone 1 — A Day at Alder Bungalow** (this build): pick an avatar preset, live one day in a furnished
16 × 16 m bungalow, cook and eat, greet the neighbor who visits at 10:00, sit, sleep, and furnish the home with undo/redo.

## Download (Windows / Linux)
Every push builds the game automatically. Open the GitHub repository and go to **Actions**, then **Terrace & Rose desktop builds**.
Pick the latest green run and download **TerraceAndRose-Windows** or **TerraceAndRose-Linux** under *Artifacts*. You must be signed in to GitHub.
Unzip it and run `TerraceAndRose.exe` on Windows or `TerraceAndRose.x86_64` on Linux. Builds are kept for 30 days.
Windows may show a SmartScreen warning because the build isn't code-signed (signing certificates cost money). Choose *More info* and then *Run anyway*.

## Run it
1. Install Godot **4.5.1-stable** (standard build, not .NET) from https://godotengine.org/download.
2. Open Godot, choose **Import**, and select `terrace_and_rose/project.godot`. Then press **Run (F5)**.
   From a terminal: `godot --path terrace_and_rose`

## Tests (exact commands, run from `terrace_and_rose/`)
```bash
godot --headless --path . --import                  # first time only: builds the class cache (see note)
godot --headless --path . -s tests/lint.gd          # every script parses and type-checks
godot --headless --path . -s tests/run_tests.gd     # Milestone-1 regression suite (69 checks)
godot --headless --path . -s tests/genetics_tests.gd       # child DNA (6 checks)
godot --headless --path . -s tests/neighborhood_tests.gd   # 4 households, stories, switching, migration (34 checks)
godot --headless --path . -s tests/family_tests.gd         # creator, ties, adoption, pregnancy/birth, aging, cheats (31 checks)
# graphical smoke test: plays the whole day (11 checks) and writes 12 screenshots to build/smoke/
godot --path . -- --smoke
godot --path . -- --shots          # quick visual check: 3 screenshots (HUD, sleep, furnish)
godot --path . -- --hood           # neighborhood: household picker, story moment, all four homes
godot --path . -- --creator        # creator, DNA child, Willow Lane move-in, family tree, cheat console
# on a machine without a GPU (Linux CI):
xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -- --smoke
```
Each command exits with code 0 on success.

Note: `AssetLoader` uses Godot's imported resources when they exist, as in the editor and in exported builds. Otherwise it loads the
raw GLB/PNG/WAV directly, so a fresh checkout runs even before the first import. The editable `.blend` sources are
excluded from Godot's importer (`assets/source/.gdignore`). Otherwise Godot tries to launch Blender to import them, which can hang.

## The neighborhood (Part 2)
From the start menu you can:
- **Play the Neighborhood** as the Rowans, the Park sisters, the Bells or the Alvarezes. Each family is mid-story, and the storylines cross. They are defined in `data/stories.json`, which you can edit to add new story moments.
- **Create a Household:** names, pronouns (including your own), life stage, body, skin, hair texture and colour, outfit and colours, traits, aspiration, and "can become pregnant". Use **Make a child from two parents** (with re-roll) to combine two adults' DNA, set relationships, then move into Willow Lane.
- **Pause menu:** switch household, edit household, family tree (adopt, aging on/off), and toggle "Inactive households progress".
- **Try for Baby:** click your partner. It appears for adults in a romantic relationship. The moment is off-screen (fade to black), and if it leads to a pregnancy, a baby with DNA from both parents is born 3 days later. Twins happen occasionally.

## Cheat codes (owner-approved access)
Cheats only work in private worlds. You, as the owner, issue a personal code to each person you approve:
```bash
# once: creates YOUR private key outside the repo (keep it secret, back it up) and writes data/cheat_public_key.pem
godot --headless --path . -s tools/cheat_keys.gd -- init
# for each person you approve (you, Ricardo, anyone you both choose):
godot --headless --path . -s tools/cheat_keys.gd -- issue "Ricardo"
```
Commit `data/cheat_public_key.pem` and rebuild the game. To use a code in game, press **Ctrl+Shift+C** and enter your name and code once.
Commands: `money 500`, `needs max`, `time +3`, `speed 2`, `aging on|off`, `ageup <name>`, `pregnant <name>`, `flag <story_flag>`, `skipstory`.
Codes can't be forged without your private key, and a code only works for the name it was issued to. Because the game is offline, someone
determined could still modify the program itself, so treat this as access control for friends, not anti-piracy.

## Businesses
The Rowans run **Rowan & Rye Bakery** (07:00–14:00) and the Alvarezes run **Petal & Pine** (10:00–17:00). This is sample starting stock.
Press **O** (Shop) to rename the business, set hours, set menu prices, turn items on and off, buy stock, open or close, and review the shift and ledger.
Someone has to work the register: press **6**, or family members will do it on their own. Customers order and wait, then pay or walk out.
- **Orders:** an order reserves its ingredients. A cancelled or abandoned order releases them, and only served orders consume stock and earn money.
- **Prices:** higher prices bring fewer customers. Reputation and story outcomes (such as supplying the inn, flowers in the lobby, or Rose & Rye) raise demand.
- **Shift summary:** closing reports customers served and walked out, revenue, supply costs and profit, and checks that the ledger matches the change in household funds.
Any household can start a business on its own lot: open the Shop panel, then place a **Shop Register** from Furnish.

## Home editor

Press **B** or select **Build**, then choose Furniture, Stucco wall, Door, Window, Walnut floor or Remove.
Point at a lot cell for a placement and budget preview. Click, tap, or use the mapped interact key to apply it.
Doors and windows span two cells. Use **Rotate** or **R** to switch their direction, and **Walls** to cycle the cutaway view.
Undo and redo cover structure, furniture and funds in the current session. Save to keep your changes.

## Desktop builds
Export templates for 4.5.1 are free from the Godot download page (Editor → Manage Export Templates).
```bash
godot --headless --path . --export-release "Linux Desktop" export/linux/TerraceAndRose.x86_64
godot --headless --path . --export-release "Windows Desktop" export/windows/TerraceAndRose.exe
```
Builds go to `export/`, which is git-ignored because the binaries are 80–110 MB. Add `-- --low` at launch for low-end PCs:
it uses one cheap sun shadow and skips the per-lamp lighting passes.

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

## Realistic characters
Characters use realistic MakeHuman-based bodies (CC0). These include real skin textures across ancestries and ages, eyes, brows and lashes, strand hair, and fitted clothing on one shared game skeleton.
- **Face and body:** morphs (ancestry blend, fuller, slimmer, muscle, bust, mature face) are editable in the creator and blend in children's DNA.
- **Skin tone:** picks the closest of 21 real skin textures, then fine-tints it.
- **Clothes:** recoloured per character with the project's fabrics. Skin under the worn outfit is hidden, so nothing pokes through.
- **Fallback:** the original stylised avatars remain available (`AvatarView.stylized = true`).
See `tools/blender/README_humans.md` to rebuild them.

## Art status (needs an art pass)
The avatars, furniture and modules are **original procedural placeholders**. They are game-ready and consistent, but not final art:
- **Realistic avatars (MakeHuman):** these replaced the stylised placeholders. Still to do:
  - Facial expressions and blinking are not yet on the new skeleton.
  - Mara's gold earrings and Ellis's beard need CC0 or custom meshes.
  - There's no Mature/young skin-detail pass yet.
- **Animations** are hand-keyed in code: idle, walk, sit_down, sit_idle, stand_up, eat, sit_eat, cook, wave and sleep. They need motion polish.
- **Building:** door leaves are posed open (no swing animation yet). The roof is a simple hip roof.
- **Audio** is synthesised; a sound designer pass is recommended.

See `../docs/ROADMAP.md` for Milestones 2–6 and the Part 2 plan.
