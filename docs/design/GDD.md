# Foul Fowl 4X — Game Design Document

Architect pass, 2026-10-06. Status: DRAFT for red team. Companion: `ARCHITECTURE.md` (how it is built), `BRIEF.md` (why).

Conventions:
- **[MVP]** must ship in the first public build. **[STRETCH]** only after MVP is green and fun.
- **[COPY: ...]** marks a slot owned by the writer (Grok). Text in a COPY slot here is placeholder only and is labelled `PLACEHOLDER`. Mechanics never depend on copy.
- Every number in this document is a starting value. All of them live in `data/balance.json` or the content JSON (ARCHITECTURE §5) so QA tunes them without code changes. Section 17 lists the balance targets the soak harness measures them against.
- Mechanical identifiers (`snake_case`) are stable; display names are copy.

---

## 1. Pillars

1. **A real MoO2-lineage 4X.** Free movement with fuel range, multi-planet systems, integer population on three jobs, a choose-your-path tech tree, ship design that matters, a Galactic Council. Veterans should recognise it in five minutes and still find decisions on turn 150.
2. **No 1993 pain.** Every repeated chore has an automation, every number has a breakdown tooltip, every turn ends with a summary that links to what needs you. A turn with nothing to decide takes one keypress.
3. **One evening.** Standard game: 4 empires, 24 stars, decided in 150-220 turns, roughly 75-120 minutes. A hard turn cap guarantees an ending.
4. **Asymmetry with numbers attached.** Eight bird empires built from one public trait-point system. Swans really are overpowered, by a declared amount, and the game says so.
5. **Deterministic and testable.** Same seed + same orders = same game, bit for bit. The whole game runs headless, AI vs AI, to completion.

---

## 2. Session shape

### 2.1 Galaxy sizes

| Size | Stars | Empires (incl. player) | Map (parsecs) | Council first / every | Turn cap | Target length |
|---|---|---|---|---|---|---|
| Tiny [MVP] | 16 | 3 | 34 x 24 | T40 / 20 | 180 | 40-60 min |
| **Small = Standard** [MVP] | 24 | 4 | 44 x 30 | T50 / 25 | 250 | 75-120 min |
| Medium [STRETCH] | 36 | 6 | 54 x 36 | T60 / 25 | 300 | 2-3 h |
| Large [STRETCH] | 54 | 8 | 66 x 44 | T70 / 30 | 350 | 3-4 h |

Minimum star separation 4.5 pc; mean nearest-neighbour distance about 6 pc on every size.

### 2.2 The arc of a standard game (design target, measured by soak)

| Turns | Phase | What the player is doing |
|---|---|---|
| 1-30 | Explore / Expand | 2 scouts on auto-explore, first colony ship lands by ~T8, outposts extend range, first contact ~T15-25 |
| 30-80 | Expand / Exploit | 6-10 colonies, Habitat Domes opens hostile worlds, first border friction, first council session at T50 |
| 80-150 | Exploit / Exterminate | Large/Huge hulls, first real wars, invasions, the Guardian falls to someone |
| 150-220 | Endgame | Council 2/3 bids, the Ascension race, capitulations end wars instead of mop-up slogs |
| 250 | Cap | Highest score wins (never reached in a normal game; it is the soak's termination guarantee) |

### 2.3 Turn budget

Early turns: 5-10 s of player time. Late turns: 30-60 s. End-turn processing on the web build: under 1.5 s late game on a mid laptop (ARCHITECTURE §10). Average ~25 s/turn x ~180 turns + battles ≈ 80-100 min.

---

## 3. Galaxy generation

### 3.1 Movement model — DECISION: free movement with fuel range (MoO1/MoO2), no star lanes

Justification:
- It is the defining feel of the lineage this audience asked for. Range technology is an expansion lever ("Fuel Cells or Inertial Dampers?" is a real early choice), and outposts that extend range are a MoO2 classic.
- Straight-line travel is trivial to implement deterministically (`turns = ceil(distance / speed)`), trivial to visualise, and gives the AI a clean threat model (time-to-arrival), which matters for an AI-built project.
- Combat happens only at star systems (MoO rule). No deep-space interception. This keeps the battle trigger rule one line long.

Costs we accept and mitigate: no hard chokepoints and a doomstack tendency. Mitigations: fuel range makes the frontier geographic; nebulae slow and strip shields; planetary defenses scale with tech; missiles are ammo-limited so alpha-strike stacks run dry; one wormhole pair per map creates one real strategic corridor. The red team should attack this decision (§19).

### 3.2 Star placement

1. Seeded Poisson-disk sampling in the map rectangle (min separation 4.5 pc, 30 attempts) until the star count is met; if short, relax separation by 5% and continue.
2. **Avian Prime** (the Orion analogue): the star closest to the map centre. It gets the Guardian (§13.4) and a Huge Gaia Ultra-Rich planet. [COPY: name of Avian Prime and the Guardian, PLACEHOLDER "Avian Prime" / "The Roc"]
3. **Homeworlds**: farthest-point selection among stars at least 12 pc from Avian Prime, maximising the minimum pairwise distance. Ties by star id.
4. **Fair start guarantee**: each homeworld must have at least 2 colonisable (non-hostile) planets and 1 outpost target within 9 pc. If not, the generator converts the nearest qualifying orbits (deterministically) until true. Each homeworld system also gets 1-2 extra planets of its own.
5. **Nebulae** [MVP]: 1 (Tiny) to 3 (Standard) elliptical regions, 6-10 pc across, never covering a homeworld. Ships inside move at speed - 1 (min 1); shields are offline in combat in a nebula system.
6. **Wormholes** [MVP]: 1 pair on Standard (0 on Tiny), joining two non-homeworld stars at least 60% of the map width apart. Travel between them takes 1 turn and ignores fuel range (you still need range to reach the entrance).
7. **Monsters** [MVP]: Guardian at Avian Prime; 2 (Standard) lesser monsters on the richest non-homeworld systems at least 10 pc from any homeworld.

### 3.3 Star types

| Star | Weight | Orbits (min-max) | Habitable bias | Mineral bias |
|---|---|---|---|---|
| Yellow | 30 | 2-5 | Terran, Ocean, Arid | Abundant |
| Orange | 20 | 2-4 | Arid, Desert, Tundra, Swamp | Abundant/Poor |
| Red | 25 | 1-4 | Tundra, Barren, Ocean | Poor |
| White | 12 | 2-4 | Barren, Inferno, Terran | Rich |
| Blue | 8 | 1-3 | Inferno, Toxic, Radiated, Barren | Rich/Ultra Rich |
| Neutron | 5 | 1-3 | Radiated, Barren, Toxic | Ultra Rich |

Each orbit independently: 25% Asteroid belt or Gas Giant (50/50), else a planet. Planet climate is drawn from the star's weighted climate table (in `data/galaxy.json`).

### 3.4 Planets

**Climate** — population per size unit (`pop_per_size`), food per farmer (`farm`), and class:

| Climate | pop/size | farm | Class |
|---|---|---|---|
| Gaia | 5 | 3 | Habitable |
| Terran | 4 | 2 | Habitable |
| Ocean | 4 | 2 | Habitable |
| Swamp | 3 | 2 | Habitable |
| Arid | 3 | 1 | Habitable |
| Tundra | 2 | 1 | Habitable |
| Desert | 2 | 1 | Habitable |
| Barren | 1 | 0 | Hostile (needs Habitat Domes, PL2) |
| Inferno | 1 | 0 | Hostile (PL2) |
| Toxic | 1 | 0 | Hostile (PL2) |
| Radiated | 1 | 0 | Hostile (needs Radiation Shielding, PL4 option) |
| Asteroids / Gas Giant | — | — | Outpost only |

**Size** (`size_units`): Tiny 1 (10%), Small 2 (25%), Medium 3 (35%), Large 4 (20%), Huge 5 (10%).

**Max population** = `size_units x pop_per_size` + building/tech/trait bonuses. Medium Terran = 12, Huge Gaia = 25, Small Barren (with domes) = 2.

**Minerals** → industry per worker: Ultra Poor 1, Poor 2, Abundant 3, Rich 4, Ultra Rich 6.

**Gravity** is derived, not rolled: Tiny/Small are Low-G unless Rich+ (then Normal); Medium is Normal; Large is Normal unless Rich+ (then Heavy); Huge is Heavy. A species is comfortable at its own gravity (Normal by default). Each step of mismatch: **-25% to all job output on that planet** (Low-G race on Heavy = -50%). Gravity Generator building removes it.

**Specials** (about 1 in 8 planets) [MVP: first four; STRETCH: rest]:

| Special | Effect | |
|---|---|---|
| Ancient Nest Ruins | First colonist gains 1 random tech (lowest unresearched tier, any field) | [COPY] |
| Gem Deposits | +5 credits/turn | [COPY] |
| Gold Deposits | +10 credits/turn | [COPY] |
| Fertile Soil | +1 food per farmer | [COPY] |
| Natives (pre-spaceflight birds) | Planet starts with 4 native pop of species `natives` (good farmers +1, no other traits); can only be gained by invasion or by "Uplift" diplomacy event [STRETCH] | [COPY: dodos?] |
| Splinter Colony | First colonist finds pop 2 instead of 1 | [COPY] |
| Space Debris | Shipyard here builds ships at -20% cost | [COPY] |

---

## 4. Empires and races

### 4.1 Trait-point system (MoO2 custom race, bird edition)

Custom race budget: **10 picks**. Negative traits refund picks; total negatives cap at -10. One choice per trait group. Government is a group. Costs are integers; effects are applied through the modifier engine (ARCHITECTURE §6) so every tooltip can explain them.

| Group | Option (id) | Cost | Effect |
|---|---|---|---|
| Growth | slow_growth | -4 | Pop growth -50% |
| | fast_growth | +3 | +50% |
| | prolific | +6 | +100% |
| Farming | poor_farmers | -3 | -1 food/farmer (min 0) |
| | good_farmers | +3 | +1 |
| | great_farmers | +6 | +2 |
| Industry | poor_industry | -3 | -1 PP/worker (min 1) |
| | good_industry | +3 | +1 |
| | great_industry | +6 | +2 |
| Science | poor_science | -3 | -1 RP/scientist (min 1) |
| | good_science | +3 | +1 |
| | great_science | +6 | +2 |
| Credits | poor_taxes | -3 | Taxes -50% |
| | rich_taxes | +4 | Taxes +50% |
| Ship attack | ship_attack_-1 / +1 / +2 | -2 / +2 / +4 | Accuracy -20 / +20 / +40 |
| Ship defense | ship_defense_-1 / +1 / +2 | -2 / +3 / +6 | Evasion -20 / +25 / +50 |
| Ground | ground_-1 / +1 / +2 | -2 / +2 / +4 | Troop strength -25% / +25% / +50% |
| Spying | spy_-1 / +1 / +2 | -3 / +3 / +6 | Spy score -20 / +20 / +40 |
| Government | feudal | -4 | Ship cost -33%, research -25% |
| | dictatorship | 0 | Baseline |
| | democracy | +7 | Research +20%, taxes +50%; enemy spies +20 vs you |
| | unification | +6 | Food and industry +25%; conquered colonies skip occupation; taxes -25% |
| Specials (any number) | aquatic | +5 | Ocean/Swamp/Terran: +1 pop per size unit and +1 food per farmer |
| | subterranean | +5 | +1 pop per size unit everywhere; ground defense +25% |
| | tolerant | +8 | Every climate has at least 3 pop/size; hostile worlds need no tech; farmers make at least 1 food anywhere |
| | low_g | -4 | Comfortable at Low-G (Normal is -25%, Heavy -50%) |
| | high_g | +5 | Comfortable at Normal and Heavy |
| | large_homeworld | +1 | Homeworld is Large |
| | rich_homeworld | +2 | Homeworld minerals Rich |
| | poor_homeworld | -1 | Homeworld minerals Poor |
| | artifact_homeworld | +3 | Start with 2 extra T1 techs (the first option of the 2 lowest-id fields) |
| | creative | +8 | Researching a tier grants ALL its options |
| | uncreative | -4 | Researching a tier grants ONE RANDOM option (seeded) instead of your choice |
| | charismatic | +3 | +20 base relation with all; council candidates you back get +10% of your votes as bonus |
| | repulsive | -6 | -30 base relation; only Peace and War are possible with you |
| | fantastic_traders | +4 | Trade treaty income x2; Trade Goods converts 1:1 instead of 2:1 |
| | lucky | +3 | Never targeted by negative random events |
| | omniscient | +3 | See every star's planets and every fleet from turn 1 |
| | stealthy_ships | +4 | Enemy scanner range against your fleets halved |
| | warlord | +4 | Ship upkeep -50%; new ships start Veteran (+10 accuracy) |
| | fast_ships | +3 | +1 map speed and +1 combat speed |

**Species vs empire traits.** Every colony records the species living there. *Species traits* (Growth, Farming, Industry, Science, Ground, Aquatic, Subterranean, Tolerant, gravity) follow the population, so a captured Owl world still has great scientists. *Empire traits* (Government, ship combat, Spying, Credits, Creative/Uncreative, diplomacy, Lucky, Omniscient, Stealthy, Warlord, Fast Ships) come from the founding species and apply empire-wide. [MVP: one species per colony; mixed-species planets are STRETCH.]

### 4.2 The eight premade empires [MVP]

Color = Okabe-Ito colorblind-safe palette; every empire also has a unique glyph so nothing is conveyed by color alone (§16).

| Empire | Picks | Traits (cost) | Homeworld | Personality pool | Color / glyph | Plays like |
|---|---|---|---|---|---|---|
| **Ducks** | 10 | aquatic (5), charismatic (3), fantastic_traders (4), ground_-1 (-2) | Medium Ocean (15 max pop) | Diplomat, Trader | Bluish green #009E73 / circle | Wide water empire, money, treaties, the natural Council candidate |
| **Pheasants** | 10 | prolific (6), good_farmers (3), feudal (-4), ship_attack_+1 (2), good_industry (3), poor_science (-3), large_homeworld (1), ground_+1 (2) | Large Terran | Expansionist, Aggressor | Vermillion #D55E00 / triangle | Out-breed and out-number; cheap ships, weak labs. "For the win." |
| **Swans** | **13** (Swan Privilege, §4.3) | ship_attack_+2 (4), ship_defense_+1 (3), ground_+1 (2), good_industry (3), large_homeworld (1) | Large Terran | Aggressor, Imperialist | White #F5F5F5 / crown (5-point) | Best warships in the galaxy on turn 1 and a big industrial base. OP, working as intended. |
| **Geese** | 10 | unification (6), good_industry (3), ground_+1 (2), ship_attack_+1 (2), poor_science (-3) | Medium Terran | Aggressor, Industrialist | Orange #E69F00 / chevron (V) | Hive industry, no occupation unrest, honk first and ask later |
| **Owls** | 10 | creative (8), democracy (7), good_science (3), ground_-1 (-2), ship_attack_-1 (-2), slow_growth (-4) | Medium Terran | Technologist, Diplomat | Yellow #F0E442 / diamond | Get every option of every tier; fragile and slow to grow. A parliament of owls. |
| **Crows** | 10 | spy_+2 (6), stealthy_ships (4), good_science (3), omniscient (3), repulsive (-6) | Medium Arid | Schemer, Aggressor | Reddish purple #CC79A7 / cross | Steal what they cannot research; see everything; nobody likes them |
| **Penguins** | 10 | tolerant (8), slow_growth (-4), good_industry (3), ground_+1 (2), large_homeworld (1) | Large Tundra (12) | Industrialist, Turtle | Sky blue #56B4E9 / square | Colonise the rocks nobody wants; huddle and build |
| **Hummingbirds** | 10 | fast_ships (3), ship_defense_+2 (6), ship_attack_+1 (2), lucky (3), poor_farmers (-3), ground_-1 (-2), large_homeworld (1) | Large Terran | Raider, Expansionist | Blue #0072B2 / star (4-point) | Fastest, hardest-to-hit ships; hungry. The Alkari tribute. |

[COPY: empire names, leader names, homeworld names, one-line blurb, diplomacy greeting/war/peace lines for each. PLACEHOLDER: "The Grand Paddling of Ducks".]

### 4.3 Swans OP [MVP]

- **Swan Privilege:** Swans get 13 picks instead of 10. The race screen shows it: "13/13 picks [Swan Privilege]". [COPY: tooltip joke, PLACEHOLDER "Patch notes: Swans OP. Status: working as intended."]
- **Setup option "Swans in every galaxy"** (default ON): if the player is not Swans, Swans always take one AI seat.
- **Balance target** (soak, §17): in 4-AI Standard games, Swans win 35-50% (fair share is 25%). Any other empire below 8% is a bug.
- Swans' AI is never Hatchling-passive: their personality pool has no Turtle or Diplomat.

### 4.4 Starting state (every empire, Standard)

- Homeworld at 8 pop (Pheasants 9), Abundant minerals unless traits say otherwise, Normal G (Low-G for low_g races). Buildings: Grand Nest (capital), Shipyard, Marine Barracks.
- Ships: 2 Scouts, 1 Colony Ship, 2 Corvettes (Small, 4 lasers). Credits: 100.
- Known tech: Laser, Nuclear Missile, Titanium Armor, Nuclear Drive, Small and Medium hulls, Colony Pod, Outpost Pod, Troop Pod.
- Grand Nest (capital building): +3 food, +5 PP, +3 RP, +5 credits, +2 scan range, shipyard included. Losing the capital: -20% industry and research empire-wide until a new Grand Nest is built (cost 300 PP).

Opening economy check (Dictatorship, no traits, Capital preset): 3 farmers x 2 + 3 = 9 food vs 8 eaten; 3 workers x 3 + 5 = **14 PP**; 2 scientists x 3 + 3 = **9 RP**; taxes 8 + 5 = 13 credits - upkeep 4 = **+9 credits**. Colony ship costs 65 PP: the second colony ship is out by about turn 5.

---

## 5. Colonies and economy

### 5.1 DECISION: integer population on three jobs (MoO2), automated by presets — not sliders

Justification:
- Integer pop on Farmer / Worker / Scientist makes every number legible ("this world has 3 workers at 4 PP each"), lets species traits plug in as per-job yields, and makes planet quality (minerals, climate, gravity) visibly matter. MoO1 sliders hide the arithmetic and still need per-planet tending.
- The MoO2 pain was never the jobs; it was adjusting them on 20 planets every few turns and moving food with freighters. Presets (§5.6) and pooled food (§5.3) remove both. A player who never opens a colony still has a well-run empire; a player who wants to optimise can lock any colony to manual.

### 5.2 Population and growth

Population is stored in milli-units (1 pop = 1000). Only whole units work jobs, eat, and pay taxes.

```
P = pop_milli, M = max_pop_units * 1000   (P < M)
growth_milli = ( P * (M - P) / M * GROWTH_R / 100  +  GROWTH_FLAT ) * (100 + growth_pct) / 100
GROWTH_R = 10, GROWTH_FLAT = 50                                      (integer division, floor)
```

A new colony (1/12) gets 141/turn (~7 turns to 2 pop); half-full (6/12) gets 350/turn; full in ~48 turns with no bonuses; Prolific halves that. Growth stops at max; pop above max (after a max-pop loss) decays 100 milli/turn.

Housing (queue item, §5.5) converts PP into growth: 1 PP = 20 milli.

### 5.3 Food — pooled empire-wide, no freighters

- Each pop unit eats 1 food. Farmers make `farm(climate) + modifiers`. Food is summed empire-wide.
- **Surplus** is not stored; it becomes credits at 1 food = 1 credit (MoO2 sold surplus too). 
- **Deficit D** is auto-imported at **2 credits per food** if the treasury allows. If it does not, the unpaid food starves: each turn, for every 5 unpaid food (min 1), the most-populous colony loses 1000 milli pop. A red banner and turn-summary item fire the first turn a deficit is imported.

### 5.4 Yields

```
food_colony     = farmers * farm_per_farmer + flat_food
industry_colony = (workers * pp_per_worker + flat_pp) * (100 + pct_industry) / 100
research_colony = (scientists * rp_per_scientist + flat_rp) * (100 + pct_research) / 100
taxes_colony    = pop_units * TAX_PER_POP(1) * (100 + pct_tax) / 100
```

Per-job yields: base (farm from climate, PP from minerals, 3 RP per scientist) + species trait + buildings; then gravity penalty (percent, floored, never below 1 per job if base >= 1); then empire and government percentages. Occupied (conquered < 10 turns): all output -50%.

### 5.5 Production and the build queue

Per colony, MoO2 style. Industry pours into the first queue item; **overflow carries to the next item** in the same turn; any number of items may complete per turn.

Queue items:
- Buildings (each once per colony) and **Projects** (Terraforming steps, Gaia Transformation, Ascension) [MVP: buildings; Terraform STRETCH].
- Ships from any current design (needs a Shipyard at that colony). **Repeat** flag: when done, re-append. **Count** field: "x5".
- **Colony Base** (40 PP): colonises another planet in the same system, no ship needed.
- **Trade Goods** (permanent filler): 2 PP = 1 credit (Fantastic Traders 1:1).
- **Housing** (permanent filler): 1 PP = 20 growth milli.

**Rush buy**: cost = `2 x remaining PP` credits, doubled if the item has 0 progress (MoO2). Bought items complete at turn processing, not instantly.

**Queue templates**: any queue can be saved as a named template and applied to any set of colonies.

### 5.6 Colony presets (the governor) [MVP]

A preset = a **job policy** + a **build list**. When the queue is empty the governor appends the first build-list building not yet built and affordable in tech, else the preset's filler. Every colony has a preset; the player can switch it from the colony list in bulk; "Manual" locks jobs and queue.

| Preset | Job policy | Build list (in order; skips unknown/built) | Filler |
|---|---|---|---|
| Capital | Feed self, then 60% workers / 40% scientists | Automated Factory, Research Lab, Hydroponic Farm, Robotic Mines, Supercomputer, Planetary Shield, Missile Base, … | Repeat last warship design |
| Industry | Feed self, all remaining workers | Automated Factory, Robotic Mines, Deep Core Mines, Missile Base, … | Trade Goods |
| Research | Feed self, all remaining scientists | Research Lab, Supercomputer, Autolab, Galactic Cybernet, … | Trade Goods |
| Breadbasket | All farmers on farm >= 2 worlds | Hydroponic Farm, Soil Enrichment, Weather Controller, … | Housing |
| Frontier (default for new colonies) | Feed self, rest workers | Marine Barracks if border, Hydroponic Farm if farm < 1, Automated Factory | Housing until pop >= 50% max, then Trade Goods |
| Fortress | Feed self, rest workers | Missile Base, Planetary Shield, Ground Batteries, Star Fortress | Trade Goods |
| Manual | Unchanged | Nothing auto-added | Nothing |

**Job assignment algorithm** (deterministic): (1) each non-manual colony assigns farmers until it feeds itself, only if its `farm_per_farmer >= 1`; (2) empire balancing: while empire food < 0, add 1 farmer at the non-manual colony with the highest `farm_per_farmer` that still has a non-farmer (ties by colony id); while food > +3 and a colony has a farmer it does not need, remove one at the lowest-yield colony; (3) remaining pop split per preset ratio, rounding workers down, scientists take the remainder. Auto-preset for new colonies: Frontier, switching to Industry at 50% pop if minerals >= Rich, Research if a Research special/lab bonus exists, else Industry. Setting: "Auto-assign presets" ON by default.

### 5.7 Credits

Income: taxes + Grand Nest + specials + trade treaties + Trade Goods + food surplus + buildings (Seed Exchange +50% colony taxes). Expenses: building upkeep, ship upkeep (§8.2), food import, spy funding.

**Negative treasury**: credits cannot go below 0. If expenses exceed treasury, the shortfall becomes **Strike**: empire-wide industry -25% next turn and a summary alert. (No auto-scrapping; MoO-like but readable.)

### 5.8 Buildings [MVP list]

| id | Tech | PP | Upkeep | Effect |
|---|---|---|---|---|
| grand_nest | start | 300 (rebuild) | 0 | Capital: +3 food, +5 PP, +3 RP, +5 cr, +2 scan, shipyard |
| shipyard | start | 60 | 1 | Can build ships here |
| marine_barracks | start | 40 | 1 | Garrison 4 marines; +2 marines/turn regen |
| hydroponic_farm | PL1 | 60 | 1 | +2 food |
| automated_factory | CN1 | 60 | 1 | +1 PP/worker, +3 PP |
| research_lab | CO1 opt | 60 | 1 | +1 RP/scientist, +3 RP |
| missile_base | WE1 opt | 80 | 1 | Planet defense: 3 launchers of best missile, 40 HP x armor mult |
| planetary_shield | FF2 | 100 | 2 | Planet shield class 5; bombardment -50% |
| soil_enrichment | PL1 opt | 80 | 1 | +1 food/farmer |
| cloning_center | PL2 opt | 100 | 2 | Growth +50% here |
| robotic_mines | CN3 | 100 | 2 | +1 PP/worker, +5 PP |
| supercomputer | CO3 opt | 120 | 2 | +1 RP/scientist, +5 RP |
| biospheres | PL3 | 100 | 1 | +1 max pop per size unit |
| ground_batteries | WE3 opt | 120 | 2 | Planet defense: 4 heavy-mount beams of best beam |
| seed_exchange | CO4 opt | 150 | 0 | Taxes here +50% |
| gravity_generator | FF4 | 150 | 2 | Removes gravity penalty here |
| autolab | CO5 opt | 150 | 3 | +10 RP flat (no pop needed) |
| weather_controller | PL5 | 150 | 2 | +1 food/farmer |
| star_fortress | CN5 | 250 | 3 | Orbital defense 400 HP x armor, 6 best beams, shield = best ship shield; ships built here -10% cost |
| galactic_cybernet | CO6 | 200 | 3 | +2 RP/scientist |
| planetary_flux_shield | FF6 | 200 | 3 | Planet shield class 10; bombardment -75% |
| deep_core_mines | CN7 | 200 | 3 | +2 PP/worker, +10 PP |
| star_gate | PR7 opt | 300 | 4 | 1-turn travel between any two of your Star Gate systems [STRETCH] |
| ascension_nest | all six T8 | 3000 | 0 | Project, capital only: completion = Ascension victory (§14) |

Building upkeep scales with nothing else; a 15-colony empire pays roughly 40-60 credits/turn, which is the intended pressure toward Trade Goods and Seed Exchanges.

---

## 6. Research

### 6.1 DECISION: six fields, eight tiers, "core + choose one" per tier, single active project (MoO2 hybrid)

- **Six fields** (MoO1): Computers (CO), Construction (CN), Force Fields (FF), Planetology (PL), Propulsion (PR), Weapons (WE). [COPY: bird names per field, PLACEHOLDER "Nest Engineering" for Construction.]
- **Tiers**: each field is a linear chain of 8 tiers; tier N needs tier N-1 of the same field. No cross-field prerequisites (readable at a glance).
- **Core + options**: every tier node grants a **core** tech always, plus **one option of 2-3** the player chooses when starting the node. Unchosen options are lost unless traded, stolen, captured, or the empire is Creative. Core techs carry the backbone (hulls, engines, mainline weapons, shields) so a choice never strands you; options carry the specialisation (missile line, defenses, economy buildings, specials). This keeps MoO2's signature tension (Creative is worth 8 picks, tech trading and espionage have targets) without MoO2's "I picked wrong and now I have no armor" trap.
- **One active project** at a time; all RP pours into it; overflow carries 100%. A **research queue** lets the player line up the next N nodes (and their option choice) so the research prompt only appears when the queue is empty.
- **Deterministic completion**, no breakthrough roll: veterans plan around exact turn counts, and the soak harness gets stable numbers. (MoO1's random completion is a red-team question, §19.)
- **Hyper-Advanced** [MVP]: after tier 8, each field offers a repeatable "Hyper-Advanced <Field> N": +5% to that field's primary stat (CO accuracy, CN armor HP, FF shield class +1 per 2 levels, PL max pop +1 per size per 3 levels, PR +1 range, WE +5% damage). [COPY: names, "Hyper-Advanced Feathering I".]

### 6.2 Cost

```
cost(tier) = RESEARCH_BASE(20) * tier^2              T1 20, T2 80, T3 180, T4 320, T5 500, T6 720, T7 980, T8 1280
hyper(n)   = 1500 + 300 * n                          (n = times already researched in that field)
```
Design target (soak-measured): a balanced player finishes all six T4 by ~T100 and all six T8 by ~T210; a research-focused player can reach Ascension by ~T170.

### 6.3 The tree [MVP: all 48 nodes; names are PLACEHOLDER, COPY renames]

Option effects in short form; parts are defined in §7.

**Computers (CO)**
| T | Core | Options (choose one) |
|---|---|---|
| 1 | Battle Computer Mk1 (+10 acc) | Research Lab (bldg) / Deep-Space Scanner (+2 scan range, scouts reveal planets at 3 pc) |
| 2 | ECM Jammer I (special) | Security Nest (+25 counter-intel) / Space Academy (new ships Veteran +5 acc) |
| 3 | Battle Computer Mk2 (+20) | Supercomputer (bldg) / Battle Scanner (special: +10 acc, reveals enemy designs) |
| 4 | ECM Jammer II | Seed Exchange (bldg) / Scanner Net (+4 scan; see fleet destinations) |
| 5 | Battle Computer Mk3 (+30) | Autolab (bldg) / Psionic Interrogation (+30 spy) |
| 6 | Galactic Cybernet (bldg) | ECM Jammer III / Virtual Flock Network (+25% taxes empire) |
| 7 | Battle Computer Mk4 (+40) | Hyper-Scanner (see all fleets) / Sabotage Network (unlocks sabotage) [STRETCH effect] |
| 8 | Battle Computer Mk5 (+50) | Sentient Nest-Mind (+25% research empire) / Precision Targeting (kinetic ignores shields) |

**Construction (CN)**
| T | Core | Options |
|---|---|---|
| 1 | Automated Factory (bldg) | Reinforced Hull (special) / Fast Shipyards (ships -10% PP) |
| 2 | Large Hull | Tritanium Armor (x1.5) / Orbital Mining (outposts on asteroids/gas giants give +3 PP to the best colony in system) |
| 3 | Robotic Mines (bldg) | Battle Suits (+5 marine str) / Prefab Nests (buildings -20% PP) |
| 4 | Huge Hull | Zortrium Armor (x2.0) / Fortified Nests (planet defense HP x1.5) |
| 5 | Star Fortress (bldg) | Powered Exoskeleton (+10 marine and militia str) / Recyclotron (building upkeep -25%) |
| 6 | Titan Hull | Neutronium Armor (x2.75) / Damage Control (special: repair 10% HP per round) |
| 7 | Deep Core Mines (bldg) | Assembly Swarms (+25% industry empire) / Advanced Exoskeleton (+10 marine str) |
| 8 | Adamantium Armor (x3.5) | Planetary Barrier Nest (planet defense HP x2) / Shipyard Swarm (ships -25% PP) |

**Force Fields (FF)**
| T | Core | Options |
|---|---|---|
| 1 | Deflector Shield class 2 | Personal Shields (+5 marine/militia str) / Scatter Field (incoming missiles -20 acc, all ships) |
| 2 | Planetary Shield (bldg) | Shield Capacitor (ships' shield +1 in first 3 rounds) / Inertial Nullifier (+10 evasion) |
| 3 | Shield class 4 | Tractor Lock (enemy retreat delayed 2 rounds) / Hardened Plating (+20% hull HP) |
| 4 | Gravity Generator (bldg) | Warp Dissipator (no enemy retreat in your systems) / Repulsor Field (enemies start 2 range farther) |
| 5 | Shield class 6 | Cloaking Device (special: untargetable rounds 1-2) / Deflector Grid (planet shields +3) |
| 6 | Planetary Flux Shield (bldg) | Phase Shift (special: 25% of hits miss outright) / Stasis Field (special: 1 enemy ship skips round 1) [STRETCH effect] |
| 7 | Shield class 9 | Hard Shields (shields also reduce kinetic fully) / Shield Overcharge (+2 shield class) |
| 8 | Planetary Shield 15 upgrade | Reflective Plumage (beams that hit 0 damage reflect 50% raw dmg) / Absolute Barrier (planets immune to bombardment) |

**Planetology (PL)**
| T | Core | Options |
|---|---|---|
| 1 | Hydroponic Farm (bldg) | Soil Enrichment (bldg) / Eco Restoration (+1 max pop per size on Terran/Ocean/Swamp/Gaia) |
| 2 | Habitat Domes (colonise Barren/Inferno/Toxic) | Cloning Center (bldg) / Universal Antidote (immune to plague events, +10% growth) |
| 3 | Biospheres (bldg) | Advanced Domes (hostile pop/size 2) / Bio-Weapons (bombardment x2) |
| 4 | Terraforming project [STRETCH: MVP grants +1 max pop per size on Tundra/Desert/Arid instead] | Radiation Shielding (colonise Radiated) / Subterranean Farms (+2 food per colony) |
| 5 | Weather Controller (bldg) | Gene Splicing (+25% growth empire) / Advanced Domes II (hostile pop/size 3) |
| 6 | Urban Nests (+1 max pop per size, all colonies) | Evolutionary Mutation (gain 4 trait picks, chosen in the race screen once) / Survival Pods (colony ships land pop 2) |
| 7 | Gaia Transformation project [STRETCH: MVP grants +2 food per colony] | Artificial Planet (gas giant outpost becomes a Large Barren planet) [STRETCH] / Bio-Harmonics (+1 food/farmer) |
| 8 | Ecumenopolis Nests (+2 max pop per size) | Genome Uplift (+1 to every job yield) / Rapid Hatching (+50% growth empire) |

**Propulsion (PR)**
| T | Core | Options |
|---|---|---|
| 1 | Fuel Cells (range 8) | Augmented Engines (special: +1 combat speed) / Inertial Dampers (+10 evasion all ships) |
| 2 | Fusion Drive (speed 3) | Extended Fuel Tanks (special: +3 range) / Courier Wings (+1 map speed for Small/Medium hulls) |
| 3 | Deuterium Cells (range 10) | Trade Lanes (trade treaty income +50%) / Logistics Network (ship upkeep -25%) |
| 4 | Impulse Drive (speed 4) | Inertial Stabilizer (+20 evasion) / Long-Range Colonisation (colony/outpost ships +4 range) |
| 5 | Plasma Cells (range 13) | Combat Afterburners (+1 combat speed all) / Displacement Device (special: 30% of hits dodged) |
| 6 | Antimatter Drive (speed 5) | Interstellar Highways (+1 speed inside own range) / Emergency Warp (retreat always succeeds) |
| 7 | Hyper Cells (range 17) | Star Gate (bldg) [STRETCH] / Nebula Runners (no nebula penalties) |
| 8 | Hyperdrive (speed 7) | Unlimited Range / Time Warp Facilitator (your ships fire twice in round 1) |

**Weapons (WE)** — beams and kinetic are core; the missile line and defenses are options.
| T | Core | Options |
|---|---|---|
| 1 | Mass Driver (kinetic) | Missile Base (bldg) / Heavy Mount (beam mount mod) |
| 2 | Fusion Beam | Merculite Missile / Point-Defense Mount (mod) |
| 3 | Gauss Cannon | Ground Batteries (bldg) / Fusion Bomb (bombardment x2, special) |
| 4 | Phasor | Pulson Missile / Fighter Bay [STRETCH; MVP option: Armor-Piercing rounds, kinetic ignores 75% shields] |
| 5 | Hellbore Cannon | Missile Base II (planet missiles +50% dmg) / Auto-Fire (beams +1 shot every other round) |
| 6 | Plasma Cannon | Zeon Missile / Spinal Mount (Huge/Titan only: 1 Heavy beam with x3 dmg) |
| 7 | Graviton Driver | Enveloping Mount (beam dmg x1.5, space x1.5) / Plasma Web (special: 15 dmg to every enemy in round 1) |
| 8 | Death Ray | Antimatter Torpedo / Stellar Disruptor (bombardment kills 2 pop/turn regardless of shields) |

**Tech that cannot be researched**: Death Ray is also on the Guardian's loot table; capturing a colony grants one random tech the victim knows and you don't, 50% chance (seeded).

---

## 7. Ship design

### 7.1 Hulls

| Hull (id) | Tech | Space | Base HP | PP | Evasion | Upkeep (cr) | Specials max |
|---|---|---|---|---|---|---|---|
| small | start | 24 | 20 | 8 | +15 | 1 | 1 |
| medium | start | 60 | 60 | 22 | +5 | 1 | 2 |
| large | CN2 | 130 | 150 | 55 | 0 | 2 | 3 |
| huge | CN4 | 280 | 350 | 130 | -10 | 4 | 4 |
| titan | CN6 | 600 | 800 | 320 | -20 | 8 | 5 |

Unarmed ships (no weapons) pay no upkeep. [COPY: hull names, PLACEHOLDER Sparrow / Kestrel / Heron / Albatross / Doom Goose.]

### 7.2 A design

A design = hull + exactly one **Engine**, one **Armor**, one **Shield** (or none), one **Computer** (or none) + any number of **weapon mounts** + up to N **specials**. Space rules:
- Engine, Shield and Computer take a **percentage of hull space** (so they scale with hull): Engine 15/13/11/9/7% by tier; Shield 8/10/12/14%; Computer 5%. Rounded up.
- Armor takes no space; it multiplies HP and adds % of hull PP.
- Weapons and specials take **flat space**, shrunk by miniaturisation.

**Miniaturisation** (MoO2): for a part of tier `t` in field `f` where you know tier `T` of `f`:
```
space = ceil(base_space * max(50, 100 - 10*(T - t)) / 100)
cost  = ceil(base_cost  * max(50, 100 - 10*(T - t)) / 100)
```
A Laser at WE8 takes half the space and half the PP it did at start.

### 7.3 Parts [MVP]

Damage `a-b` is uniform integer. Acc = accuracy modifier on top of the base to-hit (§9.3).

| Part | Field/T | Space | PP | Damage | Notes |
|---|---|---|---|---|---|
| **Beams** | | | | | Range falloff 4%/range unit; full shields apply |
| Laser | start | 5 | 3 | 3-8 | |
| Fusion Beam | WE2 | 6 | 5 | 5-12 | |
| Phasor | WE4 | 8 | 8 | 8-18 | |
| Plasma Cannon | WE6 | 10 | 12 | 12-28 | |
| Death Ray | WE8 | 12 | 18 | 20-45 | |
| **Kinetic** | | | | | -6 acc per range unit; shields count half |
| Mass Driver | WE1 | 6 | 3 | 5-9 | |
| Gauss Cannon | WE3 | 8 | 6 | 9-15 | |
| Hellbore Cannon | WE5 | 10 | 10 | 14-24 | |
| Graviton Driver | WE7 | 12 | 14 | 22-36 | |
| **Missiles** | | | | | Fixed damage; 4 salvos; 1-round flight; full shields; PD and ECM counter |
| Nuclear Missile | start | 6 | 4 | 8 | acc +0 |
| Merculite | WE2 opt | 6 | 6 | 12 | acc +10 |
| Pulson | WE4 opt | 6 | 8 | 17 | acc +15 |
| Zeon | WE6 opt | 7 | 10 | 24 | acc +20 |
| Antimatter Torpedo | WE8 opt | 10 | 14 | 40 | unlimited ammo, fires every other round |
| **Mount mods** (beams only) | | | | | |
| Heavy Mount | WE1 opt | x2 | x1.5 | x1.5 | falloff 2%/range |
| Point-Defense Mount | WE2 opt | x0.5 | x0.5 | x0.5 | +20 acc; shoots incoming missiles first (2 shots each) |
| **Systems** | | | | | |
| Engines | PR | % | 10% hull PP | — | Nuclear 2/1, Fusion 3/2, Impulse 4/2, Antimatter 5/3, Hyperdrive 7/3 (map speed / combat speed) |
| Armor | CN | 0 | +0/20/40/60/80% hull PP | — | HP x1.0 / 1.5 / 2.0 / 2.75 / 3.5 |
| Shields | FF | % | 15% hull PP | — | Class 2 / 4 / 6 / 9 |
| Computers | CO | 5% | 10% hull PP | — | +10 … +50 acc |
| **Specials** | | | | | |
| Colony Pod | start | 40 | 40 | | Colonises a planet; consumed |
| Outpost Pod | start | 12 | 18 | | Claims any planet/asteroid/gas giant, no pop; extends range; consumed |
| Troop Pod | start | 20 | 10 | | 4 marines |
| Scanner Pod | start | 4 | 2 | | +2 scan range (Scouts) |
| Reinforced Hull | CN1 opt | 10% | 10% | | HP +50% |
| ECM Jammer I/II/III | CO2/4/6 | 5% | 5 | | Missiles vs this ship -20/-40/-60 acc |
| Battle Scanner | CO3 opt | 4 | 6 | | +10 acc; reveals enemy designs |
| Augmented Engines | PR1 opt | 5% | 5 | | +1 combat speed |
| Extended Fuel Tanks | PR2 opt | 5% | 4 | | +3 range |
| Damage Control | CN6 opt | 8% | 15 | | Heal 10% max HP at end of each round |
| Cloaking Device | FF5 opt | 10% | 20 | | Untargetable in rounds 1-2; may still fire |
| Displacement Device | PR5 opt | 8% | 15 | | 30% of incoming hits dodged |
| Fusion Bomb | WE3 opt | 10 | 8 | | Bombardment x2 (stacks to x3) |

### 7.4 Designer UI and auto-design [MVP]

Designer: hull picker on the left; system pickers (engine/armor/shield/computer default to best known); weapon list with +/- counts and mount mod; specials list; a space bar (used/total) that turns red at overflow; live stats panel: HP, evasion, speed, PP, upkeep, **expected damage per round at range 3 vs shield 0 / 2 / 4 / 6 / 9** (the readable answer to "is this good?"), and an "obsolete parts" warning. Max 12 active designs; obsolete designs stay buildable from existing queues.

**Auto-design** (same code the AI uses): role buttons **Warship (Beam) / Warship (Kinetic) / Missile Boat / Point Defense Escort / Troop Ship / Colony Ship / Outpost Ship / Scout**. Algorithm (deterministic, greedy): best known engine, armor, computer, shield (skip shield on Small); add role specials by priority (warships: Reinforced Hull, Battle Scanner, ECM…) while they leave at least 60% of remaining space for weapons; fill remaining space with the role weapon that maximises `expected_damage_per_space` versus the **highest shield class seen on an enemy design** (else 0); leftover space gets the cheapest beam that fits. "Upgrade queued designs" setting (default ON) swaps queued ships to the auto-redesign of the same role when a new design is created by auto-design.

---

## 8. Fleets and movement

### 8.1 Movement [MVP]

- A fleet is a set of ships at a system or in transit. Fleet speed = slowest ship.
- Order: destination system. Turns = `ceil(distance / speed)` (nebula: speed - 1 for any leg starting or ending in a nebula; simple and visible). Fleets in transit **can be redirected** at any time (they continue from their current point).
- **Fuel range**: a destination is legal only if it is within `range` pc of one of your colonies or outposts (or an ally's with an Alliance). Range: base 6, PR1 8, PR3 10, PR5 13, PR7 17, Unlimited at PR8 option; Extended Fuel Tanks +3 per ship (fleet uses the minimum). The map shows the reachable area as a translucent fill when a fleet is selected (a UI marker, not an effect).
- **Wormholes**: entering one end continues to the other the next turn.
- **Auto-explore** (scouts): each turn, pick the nearest unexplored reachable star not already targeted by another of your auto-explorers (ties by id). **Auto-colonise** toggle per colony/outpost ship: picks the best target by the AI's planet score (§13.3), confirmable.
- **Rally point** per shipyard colony: new ships auto-move to it and merge.
- Standing orders per fleet: **Doctrine** (§9.2), **Retreat if estimated odds < X** (Never / 1:2 / 1:1), Auto-defend (return to nearest threatened colony in range).

### 8.2 Upkeep and limits

Ship upkeep per hull (§7.1), Warlord -50%. No command-point cap (upkeep is the cap). Max 40 ships per fleet [UI soft cap, not a rule].

### 8.3 Visibility (fog of war) [MVP]

- You know every star's position and colour from turn 1. A star's planets are **explored** once any of your ships has been there (or Omniscient / Deep-Space Scanner reveal).
- You **see** fleets within scan range of your colonies (3 pc, +2 capital, + tech) or ships (1 pc; Scanner Pod +2). Stealthy ships halve the range at which you see them.
- Foreign colonies: owner and pop visible once explored; buildings visible only while in scan range.
- The AI uses exactly this knowledge model (§13.1).

---

## 9. Combat

### 9.1 When and who

Combat happens at a system at the start of the combat step if two or more empires with ships or armed planets there are at war (or one is the Monster faction). All parties fight simultaneously, free-for-all by war relation. Unarmed ships participate as targets. One battle per system per turn. **Outcome is resolved fully before anything is shown.** The battle viewer replays the resolved log; skipping cannot change anything.

### 9.2 The range track (1D, MoO-readable, ES1-inspired)

Each party has an **advance** value `c` in 0..5 (starts 0). Distance between parties A and B = `max(0, 10 - c_A - c_B)`. Planets and starbases are fixed at `c = 0`. A party moves at the minimum combat speed of its armed mobile ships.

**Doctrine** (per fleet, standing order; the party uses the doctrine of its largest fleet in the battle):
- **Auto** (default): preferred distance from loadout: beam-weighted 4, kinetic-weighted 1, missile-weighted 10, mixed by damage-weighted average.
- **Close In**: preferred distance 0.
- **Stand Off**: preferred distance 10.
- **Retreat**: does not advance; fires only point defense; attempts escape (§9.6).

Movement each round: if distance to its nearest enemy party > preferred, `c += speed`; if < preferred, `c -= speed`; clamp 0..5. Simultaneous.

### 9.3 A round (8 rounds max)

1. **Move** (simultaneous).
2. **Missiles in flight arrive**: point-defense mounts of the target party shoot first (2 shots each at 60+acc, each hit destroys one missile; missiles have 1 HP). Surviving missiles roll to hit.
3. **Fire**: every weapon mount of every ship (cloaked ships excepted in rounds 1-2) picks a target and rolls. **All shots are computed against the start-of-step state and applied together** (simultaneous; input order cannot change the result).
4. **Missile launch**: launchers with ammo fire (arrive next round). Missiles launched in round 8 never arrive.
5. **Cleanup**: ships at 0 HP destroyed; Damage Control heals; retreat checks.

**To-hit (beams and kinetic)**:
```
to_hit = clamp( 60 + acc_attacker - evasion_target - (kinetic ? 6*distance : 0), 5, 95 )
acc_attacker  = computer + race ship_attack + veteran + battle_scanner + weapon acc
evasion_target = hull evasion + race ship_defense + techs (Inertial Dampers/Stabilizer/Nullifier); planets -30
```
**To-hit (missiles)**: `clamp( 70 + missile acc - ECM - evasion_target/2 - Scatter Field, 5, 95 )`.

**Damage per hit**:
```
raw    = rng(min..max)                                   (missiles: fixed)
beams  : raw = raw * (100 - falloff*distance) / 100      (falloff 4, Heavy 2)
shield : beams/missiles full class; kinetic floor(class/2); 0 in nebula
eff    = max(0, raw - shield)
```
Damage goes to a single HP pool per ship (hull HP x armor mult x reinforced). No component damage (readability; MoO1 did the same).

**Targeting** (deterministic, readable — "they focus what they can kill"): each mount chooses the enemy (in a party it is at war with) maximising `expected_eff_damage / max(1, remaining_hp_after_already_assigned_expected_damage)`; ties by lowest ship id. Point-defense mounts prefer missiles in flight, then ships. Planets are targeted like ships (their defense HP is a pool; at 0 the planet's defenses are **suppressed** for the rest of the battle and regenerate 25% per turn).

### 9.4 End of battle

- Ends early when at most one hostile-to-each-other side has armed units left.
- After round 8 with several armed sides left: **stalemate**; everyone stays, no one controls orbit, battle repeats next turn (fleets may be redirected).
- The side holding the field **controls orbit**. Unarmed enemy ships still in the system at that point are destroyed (colony ships, transports — MoO rule; it makes escorts matter).
- **Veterancy**: ships that survive a battle in which they hit something gain +5 acc (max +15).

### 9.5 Planets in combat

A colony's armed defenses form a party at `c = 0`: Missile Bases (3 launchers each, unlimited ammo), Ground Batteries (4 heavy beams), Star Fortress (6 beams, own shield, 400 HP x armor). Planet defense HP = sum of building HP x armor mult x Fortified Nests. Planet shield class from Planetary Shield buildings applies to every hit on the planet. An undefended colony with no fleet simply has its orbit controlled by the arriving hostile fleet.

### 9.6 Retreat

A party with doctrine Retreat (or whose fleet's retreat-odds threshold triggers at battle start) escapes at the end of round 2 if its combat speed >= the fastest enemy party's, else at the end of round 4; Warp Dissipator (enemy) forbids, Emergency Warp (own) always succeeds at round 1. Escaped fleets move toward the nearest friendly colony in range.

### 9.7 Battle viewer [MVP]

Side-view 2D: each party's ships in a column at a horizontal position derived from `c`; planets at the edge with their defenses. Round-by-round playback ~1.2 s per round at 1x (8-10 s for a full battle), speeds 1x/2x/4x, Skip, and "Replay" from the turn summary. Each hit shows its number. A small strip under the battle names the doctrine of each party and the exchange totals per round. (VFX rules §15.4.) Setting **Battles**: Watch all mine / Watch big ones (default: watch when my side has >= 3 ships or a colony is defending) / Never (auto).

### 9.8 Monsters [MVP]

Monster faction (at war with everyone, never moves [MVP]):
- **The Roc** (Guardian, Avian Prime): 3000 HP, shield 9, evasion -20, 6 Death Rays, 2 Zeon launchers (unlimited), damage control. Beatable ~T5-T6 with 5-7 Large ships. Reward: Avian Prime colonisable, 2 random techs (tier <= your highest + 1), and Death Ray.
- **Space Amoeba** (x2 on Standard): 400 HP, shield 2, 4 "pseudopod" kinetic 8-14. Guards a rich system.
[COPY: monster names and the one-line roars. Stellaris nod.]

---

## 10. Ground invasion and bombardment

**Bombardment** [MVP]: a fleet that controls orbit and has order Bombard deals each turn
```
B = sum over armed ships of sum over beam/kinetic mounts of max(0, avg_dmg - planet_shield) * 3 * bomb_mult
pop_killed_milli = B * 1000 / 30
```
(halved / quartered by Planetary Shield / Flux Shield; Absolute Barrier immune). Bombardment also zeroes defense regen that turn. Diplomatic: -5 relation per turn with the victim, -2 with all others.

**Invasion** [MVP]: troop ships in a fleet that controls orbit **at the end of this turn's combat** land with order Invade (same turn). Planet defenses must be suppressed or absent.
- Attackers: 4 marines per Troop Pod, strength `10 + tech` x race ground modifier.
- Defenders: militia `ceil(pop_units / 2)` at strength `6 + tech`, plus garrison marines (Barracks: 4, regen 2/turn, strength `10 + tech`), x ground modifier (Subterranean +25%).
- Resolution, duels until one side is empty: `p_attacker = s_a * 100 / (s_a + s_d)`; roll 0..99 < p: one defender dies, else one attacker dies. Militia/marines fight in order: garrison first, then militia. Keyed RNG (turn, colony).
- Win: colony changes owner, keeps species, pop and buildings (except garrison), is **Occupied** for 10 turns (-50% output; Unification skips). 50% chance to gain one tech the victim knows and you don't. Capital captured: victim loses Grand Nest effects.
- Lose: all landed marines die.

---

## 11. Espionage (light) [MVP: steal; STRETCH: sabotage]

- Per known rival, set **Spy funding**: Off / Low 3 / Med 6 / High 12 credits per turn. Per empire, set **Security**: Off / Low 3 / Med 6 / High 12.
- `intel += funding * (100 + spy_trait) / 100` per turn. A steal attempt fires when `intel >= 30 + 3 x L`, where L = the number of the target's techs you lack (cap 20).
- On reaching it: `success = clamp(50 + spy_attacker - security_defender, 10, 90)` where `security_defender = 2 x security_funding + spy_trait_defender (+25 Security Nest) (-20 if the defender is a Democracy)`. Success: steal one random tech you lack (seeded). Failure: 50% caught: -15 relation, notification to both. Intel resets either way.
- Crows (spy +40) are the only race that should expect a steal every ~6-8 turns at Med funding.

---

## 12. Diplomacy and the Galactic Council

### 12.1 Relations [MVP]

Integer -100..+100 per pair, shown with a full breakdown tooltip (Stellaris-style opinion list). Components (each visible):

| Factor | Value |
|---|---|
| Base | 0; Charismatic +20; Repulsive -30; same personality +5 |
| Border tension | -2 per pair of colonies within 6 pc of each other (cap -20) |
| Treaties | +10 each active treaty |
| Trade / research benefits | +1 per 10 credits/RP gained per turn from them (cap +15) |
| Gifts | +1 per 10 credits given (decays 1/turn) |
| Incidents | Spy caught -15, bombarded -5/turn, backstab (war while treaty) -40 with victim and -20 with all who saw it |
| War | -30 while at war |
| Council | -10 if you voted against them (decays) |
| Personality | Aggressors -10 to everyone weaker; Diplomats +10 |

Non-war components decay 1 point/turn toward their steady value.

### 12.2 Treaties and exchanges [MVP]

- **Non-Aggression Pact** (needs relation >= 0): breaking it = backstab.
- **Trade Agreement** (>= 10): each side gains `min(pop_A, pop_B) / 4` credits/turn, ramping from 20% to 100% over 10 turns (MoO1). Fantastic Traders x2.
- **Research Agreement** (>= 20): each side gains 10% of the other's RP as RP.
- **Alliance** (>= 50): shared vision, fuel range from ally colonies, AI ally joins your wars if it can.
- **Peace** (to end a war): 15-turn truce, no re-declaration.
- **Exchanges**: tech for tech, tech for credits, credits gifts, **demands** (AI may demand tribute when strong).
- **Declare war**: any time (Repulsive empires: only Peace and War exist with anyone).
- AI accepts a deal if `value_to_AI(deal) + relation/2 + personality_bias >= 0`, and the screen shows the AI's reasons ("Tech is worth 320 to them; they distrust you: -15").

### 12.3 The Galactic Council [MVP]

MoO1/MoO2 lineage.
- Convenes at the first-session turn (§2.1) and then every interval, if at least 3 empires live and the player has met at least one. Announced 5 turns ahead.
- **Votes** = total whole pop units of the empire (Charismatic: candidates you vote for get +10% of your votes).
- **Candidates**: the two empires with the most votes.
- Every empire votes Candidate A, Candidate B or Abstain. Candidates vote for themselves. AI votes for the candidate with the higher relation if that relation is >= -20, else abstains; Aggressor AIs never vote for the strongest military rival.
- A candidate with **>= 2/3 of all votes cast or abstained** is elected **Lord of the Flock** [COPY].
- Player elected: **Council victory**. AI elected: the player chooses **Accept** (defeat) or **Defy** (the council dissolves forever; every empire that voted for the winner declares war on the player; the game goes on). MoO1's rule; it turns a loss into a dramatic last stand.
- The player casts their vote at the **start** of the session turn (modal, never mid-turn processing).

---

## 13. AI

### 13.1 Fairness contract [MVP]

- **The AI sees what you see.** It plans from its own fog-of-war knowledge model, never the true state.
- **No hidden bonuses.** Every AI advantage is a declared difficulty modifier shown on the setup screen and in each AI's diplomacy tooltip.
- The AI issues orders through the same command API as the player; the sim validates them identically.

| Difficulty [COPY names] | AI production | AI research | AI growth | Behaviour |
|---|---|---|---|---|
| Hatchling | -25% | -25% | 0 | War threshold x2, never targets player first |
| Fledgling | -10% | -10% | 0 | War threshold x1.5 |
| Raptor (default) | 0 | 0 | 0 | — |
| Apex | +25% | +25% | +25% | War threshold x0.8 |
| Swan Mode | +50% | +50% | +50% | War threshold x0.7; Swans always present |

### 13.2 Personalities [MVP]

Weights the planners read (0-10): expansion, industry, research, military, aggression, diplomacy, espionage, defense. Each premade empire has a pool of two; one is picked per game (seeded).

| Personality | Expand | Military | Aggression | Research | Diplomacy | Notes |
|---|---|---|---|---|---|---|
| Expansionist | 9 | 5 | 5 | 5 | 5 | Colonises everything in range first |
| Aggressor | 6 | 9 | 9 | 4 | 2 | Attacks the weakest neighbour |
| Technologist | 5 | 4 | 3 | 9 | 6 | Research presets, ascension seeker |
| Industrialist | 6 | 6 | 4 | 5 | 5 | Industry presets, big fleets late |
| Diplomat | 5 | 4 | 2 | 6 | 9 | Treaties, council candidate |
| Trader | 6 | 4 | 3 | 5 | 8 | Trade treaties, Trade Goods |
| Schemer | 5 | 5 | 6 | 6 | 3 | Heavy spy funding |
| Raider | 6 | 7 | 7 | 4 | 3 | Fast strikes on undefended colonies, bombards |
| Imperialist | 7 | 8 | 7 | 5 | 3 | Swans only: council candidate by force |
| Turtle | 4 | 5 | 2 | 6 | 6 | Fortress presets, defends |

[STRETCH: an "Erratic" personality — peaceful until turn 150, then nukes everything. COPY: the Gandhi joke.]

### 13.3 Planning loop (each AI turn, fixed order, deterministic)

1. **Assess**: power estimate per known empire (`power = sum over ships of sqrt(dps_vs_their_shield * hp)`, squared at fleet level per Lanchester: fleet power = (sum sqrt)^2); threat per own colony = enemy power within 3 turns' travel; posture = Peace / Tension / War / Losing.
2. **Research**: score each frontier option: `personality weight x need`; needs: hostile-only targets in range -> Habitat Domes; enemy shields seen -> next weapon; at war -> computers/armor; capped range -> fuel. Queue 2 nodes ahead.
3. **Designs**: regenerate role designs via auto-design whenever a new part arrives; obsolete superseded ones.
4. **Colonies**: assign presets by role score (minerals, climate, research specials, frontier distance); capital keeps Capital preset.
5. **Expansion**: planet score = `max_pop*10 + mineral*8 + special bonus - distance_turns*5` (hostile needs tech). Target count of colony/outpost ships = min(targets in range, 2 + expansion/3) minus en route.
6. **Military**: desired military PP share = 15% + military*3% (+25% at War, +15% if threatened). Fleets assigned to Defend (threatened colonies), Strike (gathers at staging colony nearest the target), Invade (troop ships following the strike fleet, sized so `expected marines >= 1.3 x defenders`), Reserve. A strike launches when `own_strike_power >= 1.5 x known_defense_power` of the target system (Aggressor 1.2).
7. **War and peace**: declare war on a neighbour when `relation < -20 or aggression >= 7`, `own_power / their_power >= war_ratio(personality, difficulty)`, and the AI has at least one reachable target colony. Seek peace when `own/their < 0.7`, or no battle for 20 turns, or a second front opens. Capitulate (§14) when hopeless.
8. **Diplomacy**: propose NAP to neighbours it is not targeting; trade/research with relation >= threshold; accept per §12.2; demand tribute when `own/their >= 2` and Aggressor.
9. **Production**: per shipyard colony, top-up queues to match desired composition (escort ratio, PD escorts when enemy missiles seen, troop ships for planned invasions); buildings via presets.
10. **Espionage**: fund vs the tech leader among known rivals (Schemer: all).

Budget: the AI must plan a Standard late-game turn in < 50 ms native / < 150 ms web per empire (ARCHITECTURE §10).

---

## 14. Victory and defeat

| Victory | Rule | MVP |
|---|---|---|
| **Conquest** | Every other empire eliminated (no colonies) or capitulated to you | MVP |
| **Council** | Elected by >= 2/3 of the votes (§12.3) | MVP |
| **Ascension** | Know all six T8 cores, then complete the Ascension Nest project (3000 PP) at your capital. Starting it is announced to everyone: every AI gets -30 relation toward you and its war planner may target your capital. | MVP |
| **Score at turn cap** | Highest score at the cap | MVP |
| Cuckoo Crisis | End-game crisis (Antaran/Stellaris-crisis nod): from ~T150, a brood-parasite faction raids colonies and lays "eggs" that convert pop; destroying the Cuckoo Nest = victory | STRETCH |

**Capitulation** [MVP] (anti mop-up slog): an AI empire at war that has lost its capital, holds <= 3 colonies, and whose power is < 25% of its strongest enemy's offers that enemy its surrender. If accepted, its colonies and ships transfer and it counts as eliminated. The player is offered the choice; AI-to-AI capitulation is accepted automatically. The player never auto-capitulates.

**Defeat**: you lose all colonies; council elects someone else and you Accept; someone else wins.

**Score** = pop units + 2 x colonies + 2 x techs + fleet PP value / 50 + 20 if you hold your capital + 30 if you hold Avian Prime.

---

## 15. Presentation

### 15.1 Screens [MVP]

Main Menu · New Game (size, opponents, difficulty, race premade/custom, Swans toggle, events/monsters/council toggles, **shareable seed string**) · Race Designer · Galaxy Map (main) · Colony panel (side panel) · **Colonies list** (sortable table: pop, food, PP, RP, preset, queue head, turns-to-complete; bulk preset/template actions) · Research · Ship Designer · Fleets list · Diplomacy · Council · Turn Summary · Battle Viewer · Settings · Save/Load · Avipedia (in-game reference generated from the same data) [COPY] · Victory/Defeat.

### 15.2 Notifications and the turn summary [MVP]

At the start of each turn a **Turn Summary** panel lists everything that happened, grouped and filterable: Research (tech done + "choose next" if queue empty), Production (completed items, empty queues — rare with presets), Colonies (new colony, starvation, max pop reached, strike), Military (battles with Replay / outcome, invasions, enemy fleets sighted near your colonies with ETA), Diplomacy (proposals awaiting answer, war declared, treaty ended), Council (session in N turns), Events. Every row has a "Go to" button. Rows needing a decision are pinned on top with a badge. Settings: per-category "show in summary / toast only / off". The End Turn button shows a count of unresolved decisions; pressing it with decisions pending asks once (with "don't ask again").

### 15.3 Tooltips [MVP]

Every number on screen has a breakdown tooltip generated by the modifier engine: base, each modifier with its source, final value. Every part, building and tech has a stats tooltip generated from data. Hovering a fleet shows ETA and estimated odds against what is visible at its destination.

### 15.4 Visual direction and VFX rules [MVP]

- All art drawn in Godot from shapes. Birds are silhouettes from a few polygons (body, wing, beak), one silhouette family per empire, tinted with the empire color.
- Stars: small shaded discs with a soft radial glow, **plus a 4-6 spike diffraction cross** sized by star class (so stars are not just circles); planets are shaded circles with a terminator (planets are round).
- **No ring/doughnut base shapes for effects.** Beams are tapered strokes with a bright core and a fading tail; kinetic shots are short streaks with a trail; missiles are small dart polygons with a particle trail; hits spawn spark streaks along the impact direction plus 3-6 tumbling feather polygons; ship death is a directional debris burst (hull polygon shards + feathers) with a short flash; shields show as a brief faceted arc segment on the side facing the shot, broken by noise, never a full circle. Explosions may be round (fireballs are round).
- Range and selection markers are UI, not effects (a translucent filled range area and a selection bracket are fine).
- Readability first: each empire's projectiles are tinted its color; damage numbers in white with dark outline; reduce-motion setting disables shake and halves particle counts.

### 15.5 Hotkeys [MVP] (browser-safe: no F-keys, no Ctrl+S/W/T/N/R)

| Key | Action |
|---|---|
| Enter / Space | End turn (Space only when no text field has focus) |
| Esc | Close panel / open menu |
| G / C / R / D / F / P / U / T | Galaxy / Colonies list / Research / Designer / Fleets / Diplomacy (Parley) / Council / Turn summary |
| N | Next item needing attention (idle fleet, empty queue, pending decision) |
| Tab / Shift+Tab | Next / previous colony |
| Home | Centre on capital |
| WASD / arrows, wheel, middle-drag | Pan / zoom |
| 1-5 | Map overlays: ownership, minerals, habitability for my species, fuel range, threats |
| Ctrl+Z / Ctrl+Y | Undo / redo (current turn's orders) |
| Q / L | Quick save / quick load (confirm) |
| H or ? | Help / hotkey sheet |

---

## 16. Accessibility and settings [MVP]

- **Empire colors**: Okabe-Ito palette (§4.2) + per-empire glyph shown wherever color identifies an owner (map labels, fleets, diplomacy, battle). A "high contrast" option thickens outlines.
- **Fonts**: one hyperlegible sans (Atkinson Hyperlegible, OFL — owner to approve and supply the TTF; fallback Godot default), minimum 14 px at 100% scale; numbers tabular.
- **UI scale**: 75% to 200% in 25% steps (content scale factor).
- **Reduce motion**; battle speed default; color-independent damage numbers; all info available in tooltips and lists, not just on the map.
- Audio: Master / Music / SFX / UI volume sliders; mute on focus loss (web) toggle.
- Save/load: manual slots, autosave every turn (rolling 3), quicksave. Browser-safe `user://` (IndexedDB on web). [STRETCH: export/import save file on web.]

---

## 17. Balance tables and soak targets

### 17.1 Key formulas (index)

| Quantity | Formula | § |
|---|---|---|
| Max pop | size x pop/size + bonuses | 3.4 |
| Growth | `(P*(M-P)/M*10/100 + 50) * (100+g)/100` milli | 5.2 |
| Food | farmers x farm - pop; deficit imported 2 cr/food | 5.3 |
| Industry | `(workers x pp + flat) x (100+pct)/100` | 5.4 |
| Research cost | `20 x tier^2` | 6.2 |
| Miniaturisation | `max(50, 100 - 10 x tiers above)%` | 7.2 |
| To-hit | `clamp(60 + acc - eva - kinetic 6xD, 5, 95)` | 9.3 |
| Damage | `max(0, raw x falloff - shield)` | 9.3 |
| Ground duel | `p = s_a/(s_a+s_d)` | 10 |
| Spy threshold | `30 + 3 x techs lacked (cap 20)` | 11 |
| Council | 2/3 of votes = pop units | 12.3 |
| Rush buy | `2 x remaining (x2 if no progress)` | 5.5 |
| Score | pop + 2 col + 2 tech + fleet/50 + 20 capital + 30 Avian Prime | 14 |

### 17.2 Reference designs (start of game, for QA sanity)

| Design | Hull | Loadout | PP | HP | Exp. dmg/round at range 3 vs shield 0 / 2 |
|---|---|---|---|---|---|
| Corvette | small | Nuclear drive (4), 4 Lasers (20) | 21 | 20 | ~8.1 / ~4.5 (vs small, 45% hit) |
| Destroyer | medium | Nuclear (9), 10 Lasers (50) | 55 | 60 | ~25 / ~14 (vs medium, 55%) |
| Missile Boat | medium | Nuclear (9), 8 Nuclear Missiles (48) | 57 | 60 | ~43 / ~33 for 4 salvos (vs medium, no ECM, 68%) |
| Colony Ship | medium | Nuclear (9), Colony Pod (40) | 65 | 60 | — |
| Outpost Ship | small | Nuclear (4), Outpost Pod (12) | 27 | 20 | — |
| Troop Ship | medium | Nuclear (9), 2 Troop Pods (40) = 8 marines | 45 | 60 | — |

Hull PP = hull + engine (10% of hull PP, rounded up) + parts. Intended reads: lasers lose ~45% of their value to the first shield and ~75-80% to class 4 (upgrade pressure); missiles out-damage beams for 4 rounds unless PD/ECM answer; a 2-vs-2 Destroyer fight resolves in 3-5 rounds.

### 17.3 Soak balance targets (measured by `tools/soak` over >= 40 seeds, 4 AIs, Standard, Raptor) [gate for Phase 8]

| Metric | Target |
|---|---|
| Games ending by victory before cap | >= 90% |
| Median end turn | 140-220 |
| Swans win rate | 35-50% |
| Any other empire's win rate | >= 8% |
| Each victory type occurs | Conquest >= 30%, Council >= 10%, Ascension >= 5% of games |
| Median colonies per surviving empire at T80 | 6-10 |
| Median techs known at T100 | 20-30 |
| Games with an AI starving > 10 turns | 0 |

---

## 18. Modern QoL vs MoO pain points [MVP unless marked]

| MoO pain | Foul Fowl answer |
|---|---|
| Re-balancing jobs/sliders on every planet | Colony presets with empire-wide food balancing; bulk change from the colonies list |
| Empty build queues every few turns | Preset build lists + filler; Repeat and Count on ships; queue templates |
| Food freighters (MoO2) | Pooled food, auto-import with credits |
| "Which planet needs me?" | Turn summary with Go-to, N = next item needing attention |
| Hidden arithmetic | Breakdown tooltip on every number |
| Scout micromanagement | Auto-explore; auto-colonise suggestions |
| New ships pile up at shipyards | Rally points per shipyard |
| Redesigning every ship after each tech | Auto-design by role; "upgrade queued designs" |
| Watching every battle | Watch / big ones / never; replay from summary; outcome identical either way |
| Mop-up slog | Capitulation; council every 25 turns; score cap |
| Misclick consequences | Undo/redo of the current turn's orders |
| Research prompt every few turns | Research queue with pre-chosen options |
| Unknown AI cheating | Declared difficulty bonuses only, shown in UI; AI uses fog of war |
| Saving | Autosave every turn, quicksave, browser-safe saves |
| Losing fleets to range math | Range fill on the map; illegal destinations refused with the reason in the tooltip |
| STRETCH: refit at shipyard (pay the PP difference), sabotage, star gates, terraforming, mixed-species colonies, Cuckoo crisis, Medium/Large galaxies, save import/export on web, key rebinding |

---

## 19. Open questions for the red team

1. Free movement + fuel range vs star lanes: does the doomstack + no-chokepoint cost outweigh MoO authenticity? Are nebulae, one wormhole pair and ammo-limited missiles enough mitigation?
2. Watch-only battles with doctrine as the only lever: is that enough agency for this audience, or do we need a MoO2-style tactical mode (and can the builder afford it)?
3. "Core + choose one" tiers: is the core too generous (does it gut Creative's value and the trade economy)?
4. Swan Privilege (+3 picks) and "Swans in every galaxy" default ON: funny for an evening or a frustration? Is 35-50% the right target?
5. Pooled food with credit import: does it delete a real decision (MoO2 food logistics) rather than just a chore?
6. Presets: if the default governor is near-optimal, are colonies still a decision? If it is not, is it a trap?
7. Council: votes = raw pop, 2/3 threshold, Defy rule. Too easy for Ducks/Pheasants? Too hard to ever trigger?
8. Turn cap 250 + capitulation + ascension: enough to kill the mid-game slog, or does the game still stall around T120-180?
9. Combat model: 1D range track, single HP pool, simultaneous fire, 8 rounds. Is there enough design depth (beam/kinetic/missile/PD/ECM/shields) for ship design to matter for 200 turns?
10. Deterministic research completion (no MoO1 breakthrough roll): right call?
11. Is the 48-node tree plus parts too much content for MVP; which 30% could be cut without hurting the game?
12. AI power estimate and the 1.5x strike threshold: will the AI ever win a war against a competent player without cheating?
