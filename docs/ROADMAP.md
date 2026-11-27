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

## Missions and Case Files (requested; scheduled after P2-1)
### Missions
- **Data-driven missions** (`data/missions/*.json`): steps, conditions, choices, rewards and failure states. They are authored with a small in-project mission editor, the same pattern as the lot editor.
- **Career chains:** each career has 3–5 missions per level. Examples are Baker (wedding catering), Florist (dressing the Park inn), Innkeeper (critic's visit), Detective (Case Files) and Journalist (scoop on a town secret).
- **Gangster career (crime path):** you climb from Lookout to Runner, Enforcer, Lieutenant and finally Boss of your own crew.
  - **Missions:** heists, smuggling at the Brineglass docks, protection rackets on town businesses, and turf disputes with a rival crew.
  - **Systems:**
    - **Heat** draws the Detective's attention: raids, interrogations, possible arrest or jail time.
    - **Reputation** affects fear versus respect.
    - **Dirty money** must be laundered through a business, such as the bakery or the florist.
    - **Loyalty** decides whether crew members stay or betray you.
  - **Links to other systems:** a Detective household can investigate a Gangster household's cases, so players can be on either side of the same crime.
  - **Choices:** go straight, turn informant, or take over the town.
  - Crimes are stylized like a crime drama, not real-world instructions, and violence stays off-screen.
- **Vacation missions:** each destination has 2–3 missions. At Brineglass Harbor these are the lighthouse keeper's lost logbook, a shipwreck beachcombing hunt, and the market tasting rivalry.
- **Outcomes** feed into money, skills, relationships, household memories and the photo album.

### Case Files: murder mystery mode
- **Unlocks** through the Detective career, plus special vacation cases.
- **Gameplay:** examine scenes for clues, interview suspects (their stories can change as they come under pressure), and pin evidence on a case board to link motive, means and opportunity. Then make an accusation. A wrong accusation has story consequences, and there are several endings.
- **Content rules:**
  - Cases are **fictionalized and inspired by famous historical cases** (roughly a century old or more, such as classic Victorian and 1920s puzzles).
  - All names, places and characters are new. No real victims, families or suspects are named, and no recent real crimes are used.
  - Violence happens off-screen; the focus is on deduction.
- **Planned first cases (working titles, all original):** *The Lantern Walk Poisoning* (a locked-room style puzzle), *The Harbor Ledger* (insurance fraud gone wrong), *The Greenhouse Alibi* (a timetable puzzle).
