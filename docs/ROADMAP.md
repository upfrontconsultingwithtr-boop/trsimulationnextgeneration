# Terrace & Rose — Roadmap

Status key: ✅ done · 🔨 in progress · ⏳ planned

## Part 1 milestones
| # | Milestone | Status |
|---|---|---|
| M1 | A Day at Alder Bungalow: presets, needs, 6 actions, furnishing with undo/redo, HUD, cutaway, versioned saves with backup | ✅ (see terrace_and_rose/README.md) |
| M2 | Build & customize: editable walls, doors and windows; room finishes; fuller creator (body, age, skin undertone, hair texture, outfits, pronouns, voice); outfit fit tests while walking, sitting and reaching | ⏳ |
| M3 | Stem & Steam florist café: hours, menu, prices, stock, orders, ledger reconciliation | ⏳ |
| M4 | Seasons and holidays: 7-day seasons, weather, Lantern Walk, custom holidays | ⏳ |
| M5 | Brineglass Harbor: cedar lodge, boardwalk, beachcombing, market tasting, booking with full cost, memories | ⏳ |
| M6 | Careers, skills, gardening, pets, life stages, journals, photo album, UI scaling, reduced motion, port evaluation | ⏳ |

## Part 2 — Build a Living World (continues from Part 1, same name, designs and save format)
| # | Milestone | Status |
|---|---|---|
| P2-1 | First playable neighborhood: Rowan, Park, Bell and Alvarez households (homes, budgets, relationships, goals, stories in progress); one story with branching outcomes; household and character creator with family tree; **"child from two parents"** genetics; household switching; save/reload | 🔨 genetics module done and tested |
| P2-2 | Build, work, travel: walls/doors/windows/floors editor with budget preview and touch controls; one complete bakery/café shift; one complete vacation; private God Mode with snapshots | ⏳ |
| P2-3 | Play together: accounts, profiles, friends, invite-only shared world (self-hosted or local server), preset interactions, mutual-consent shared family that persists; blocking, reporting, privacy | ⏳ |
| P2-4 | Community: share households and lots, more social activities, more stories | ⏳ |

### Family life and genetics (requested)
- Adult partners in a committed relationship can choose **Try for Baby**. Like other family life sims, it happens off-screen (a fade-out, no explicit content). It can lead to a pregnancy that lasts a set number of in-game days and ends in a birth. Adoption is available as an alternative.
- Children inherit **DNA from both parents** (`scripts/core/genetics.gd`): a skin tone blend within the parents' range, hair colour (darker pigment slightly dominant) and hair texture from either parent, body frame, height, eye colour, and one trait from each parent. There is a small chance of twins or triplets. Results are seeded, so they are reproducible and saves stay exact.
- The **household creator** offers "Make a child from two parents" with a re-roll button, using the same genetics.
- Online, both players must agree before any shared relationship, move-in, household change or new child, as the Part 2 brief requires. Child characters only take part in age-appropriate family gameplay.

### Free hosting notes for P2-3 (to verify before use)
The first online test runs locally (two clients plus a local Godot or Node server). Any hosted option needs your explicit approval and must be documented with its limits on capacity, sleep/uptime and storage before use.
