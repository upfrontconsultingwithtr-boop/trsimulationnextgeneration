# Terrace & Rose — Handoff (2026-11-27)

**Base branch:** `ccr-049c17c9-ws2j7q`.
**Game folder:** `terrace_and_rose/` (Godot 4.5.1). The older web prototype in the repo root (`src/`, `server/`) is kept but no longer developed.

## Play it
- **Download:** GitHub → Actions → "Terrace & Rose desktop builds" → latest green run → Artifacts → TerraceAndRose-Windows / -Linux.
- **Or from source:** install Godot 4.5.1, Import `terrace_and_rose/project.godot`, then press F5.

## Done
1. **Alder Bungalow day (Part 1 M1):** needs, 6 actions, action queue, furnishing with undo/redo, versioned saves with backup, HUD, cutaway, remappable controls.
2. **Neighborhood (Part 2 P2-1):**
   - Four premade households (Rowan, Park, Bell, Alvarez) with 21 branching, cross-linked story beats (`data/stories.json`).
   - Household switching and autonomy.
   - Household and character creator with "child from two parents" DNA, family tree, adoption, Try for Baby (fade to black), pregnancy and birth, aging toggle.
   - Owner-signed cheat codes (`tools/cheat_keys.gd`).
3. **Businesses:** Rowan & Rye Bakery and Petal & Pine florist. Hours, prices, stock reservations, customers, register staffing, and full shifts with a reconciled ledger (press O).
4. **Realistic humans:** MakeHuman/MPFB CC0 bodies (7 frames × ages) with morphs (ancestry, build, age), 21 skin textures, recolourable fitted clothes and strand hair. Generator: `tools/blender/build_humans.py`.
5. **Home editor:** open Build to place and remove walls, doors, windows and floors. The preview shows cost and remaining funds. Edits support touch, undo/redo, save and reload.
6. **Private God Mode:** open it from Pause or Ctrl+Shift+C. Owner-issued codes unlock quick controls, the cheat console and three world snapshots per campaign. Before restore preserves the world you were playing. Normal saves are independent.
7. **Brineglass Harbor:** use Travel to book the lodge and take the active household there. Search three beach spots, save mid-trip, and check out to return home with a Travel memory.
8. **CI:** every push to `terrace_and_rose/**` runs all tests and builds Windows and Linux downloads.

## Tests
See the commands in `terrace_and_rose/README.md` for headless regression tests and the graphical smoke test. The regression suite now covers construction and snapshot restoration.

## Next, in order (see docs/ROADMAP.md)
1. **Street mode:** open town, driving, police/Heat, Gangster/crime and Detective careers, missions, Case Files mysteries (fictionalised, inspired by century-old cases).
2. **Online:** invite-only shared worlds, friends, consent-gated shared families.
3. **Character polish:** blink and expressions, earrings and beard meshes, more outfits.

## Known limits
- The planned desktop release is one adult-only explicit edition. Intimacy fades to black in the current development build. The future online community requires age-appropriate experiences and same-age-group visibility and interaction.
- Cheat keys: the owner must run `tools/cheat_keys.gd -- init` locally (the private key stays with them) and commit the public key.
- Builds aren't code-signed, so Windows SmartScreen shows a warning.
