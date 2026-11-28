# Terrace & Rose — Roadmap

## Vision

Build an original life simulation in a believable, present-day coastal town. Detailed human characters, grounded movement, everyday routines, recognizable architecture, and consistent lighting should give the player a sense of presence from both camera perspectives. Add fantasy selectively through specific stories and places.
Use free tooling such as Godot and Blender, with original or freely licensed assets. Favor reusable locations, rigs, animations, and materials to keep production costs and credit use low. Get approval before using a paid or credit-metered service.

Mix the household depth of a life sim with the freedom of a third-person open world. A player can leave a family home, head into town, and return to the same household. Time, ongoing obligations, relationships, and consequences carry across both views.
- **Home mode** (built in M1): use an orbiting camera to build a home, manage needs and relationships, raise a family, and run a business.
- **Street mode** (new): a third-person camera you walk, run and drive through an open coastal town:
  - **Districts:** Terrace Hill homes, the Rose Market downtown, the Brineglass docks, and the industrial edge.
  - **Vehicles:** cars, scooters and boats you own, borrow or steal.
  - **Police:** a **Heat** level brings patrols, chases and roadblocks. You can be arrested, and a court case and jail time follow.
  - **Open-world jobs:** taxi, delivery, Detective cases, and Gangster or crime missions that start anywhere in town.
  - **Combat:** stylized non-graphic fights and takedowns, with knockouts rather than gore. The police response is part of the fun.
- **One world:** money, relationships, Heat, injuries and reputation carry over between modes. A raid can hit your house, your kids can hear about your arrest, and a bakery can launder your money.
- **Scope note:** Street mode is a large build that needs a town-scale map, vehicle physics (Godot's VehicleBody3D, free), traffic and pedestrian AI, and streaming districts. It is planned as milestones S1–S4 below.

### Street mode milestones
| # | Milestone | Status |
|---|---|---|
| S1 | Third-person controller (walk, run, enter lots seamlessly from the street), one district, day/night | ⏳ |
| S2 | Vehicles: drive, park, own and steal; a simple traffic loop; gas and repair costs | ⏳ |
| S3 | Heat and police: witnesses, wanted levels, chases, arrest, bail, jail | ⏳ |
| S4 | Open-world missions: jobs, crime and Detective cases on one shared mission system; four districts | ⏳ |

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
| P2-2 | Build, work, travel: walls/doors/windows/floors editor with budget preview and touch controls; one complete bakery/café shift; one complete vacation; private God Mode with snapshots | 🔨 Home editor, business shifts, and private God Mode implemented |
| P2-3 | Play together: accounts, profiles, friends, invite-only shared world (self-hosted or local server), preset interactions, mutual-consent shared family that persists; blocking, reporting, privacy | ⏳ |
| P2-4 | Community: share households and lots, more social activities, more stories | ⏳ |

### Family life and genetics (requested)
- Adult partners in a committed relationship can choose **Try for Baby**. Like other family life sims, it happens off-screen (a fade-out, no explicit content). It can lead to a pregnancy that lasts a set number of in-game days and ends in a birth. Adoption is available as an alternative.
- Let players choose exclusive relationships or have multiple consenting adult partners. Show each relationship separately and let the player select the intended partner for relationship and family actions.
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

## Crime roles (requested)
In addition to the Gangster career, criminal paths are available for both player characters and townies:
- **Thief / Burglar:** pickpocketing, break-ins and fencing stolen goods. Each lot's security (locks, alarms, a nosy neighbor) affects the odds.
- **Robber:** planned stick-ups and the bank or armored-truck jobs that cap the Gangster chain.
- **Murderer (story-driven):** an NPC or player character can commit a murder that becomes a **Case Files** investigation. The killer's household tries to hide evidence while a Detective household gathers it.
- **Consequences:** Heat, witnesses, arrest, trial, jail time, and damaged relationships.
- **Presentation:** stylized like a crime drama, not real-world instructions. Violence is off-screen or cut away; the aftermath, the investigation and the consequences are what you see.

## Desktop and live audience requirements

- The planned desktop release is one adult-only explicit edition. Players can opt in to visible, player-controlled intimacy between consenting adult characters and can skip or exit a scene. Intimacy fades to black in the current development build.
- The live community will offer age-appropriate experiences across age groups. A player can discover, see, and interact only with players in the same age group.
- Apply the same age-group rule server-side to profiles, search, presence, invitations, matchmaking, public and private spaces, chat, and shared households. Cross-group players must be absent from results and inaccessible through direct links or requests.
- Define the age groups and how eligibility is established before opening the community. Test account changes and cross-group visibility and interaction before launch.
