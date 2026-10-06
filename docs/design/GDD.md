# Foul Fowl 4X — Game Design Document

Architect pass + meme-bible merge, 2026-10-06. Status: DRAFT for red team. Companions: `ARCHITECTURE.md` (how it is built), `BRIEF.md` (why), `MEME_BIBLE.md` (Grok 4.7's voice, roster flavour, names, events, ideas), `COPY_PLAN.md` (where every string goes).

Conventions:
- **[MVP]** must ship in the first public build. **[STRETCH]** only after MVP is green and fun.
- **[COPY: key]** marks a player-facing string owned by the writer. `key` is its `data/copy/en.json` key; `COPY_PLAN.md` maps each key to a meme-bible line or marks it as a gap. Mechanics never depend on copy.
- **Source of truth.** Mechanics and numbers in this document win over `MEME_BIBLE.md`. Where a Grok number was changed to fit the trait-point system, §21 says so.
- Every number here is a starting value. All of them live in `data/balance.json` or the content JSON (ARCHITECTURE §5) so QA tunes them without code changes. §17 lists the balance targets the soak harness measures them against.
- Mechanical identifiers (`snake_case`) are stable; display names are copy.

Shared vocabulary (from the meme bible, used everywhere in UI and copy):

| Word | Means (mechanically) |
|---|---|
| **Beak** | Kinetic weapons (best at close range) |
| **Talon** | Beam weapons (best at mid range) |
| **Horizon** | Missiles (fire from any range) |
| **Grand Roost** | The Galactic Council; its winner is **Supreme Bird** |
| **Hyper-Preened** | The label of research tiers 7-8 and of the repeatable post-tier-8 techs |
| **Evening Standard** | The default game preset (§2.1) |
| **PNN** (Perch News Network) | The galaxy news ticker (§15.2) |
| **Orn** / **Guardian of Orn** | The core system and its guardian monster (§9.8) |
| **The Big Quiet** / **The Antherons** | The end-game crisis and its face [STRETCH] (§14) |
| **The Moulted** | Ancient awakened roosts (fallen-empire NPCs) [STRETCH] |
| **The Perch Review** | The in-world review desk (event §20) |
| **DOOMSTACK** | What a fleet panel calls any fleet of 8+ ships (cosmetic) |

---

## 1. Pillars

1. **A real MoO2-lineage 4X.** Free movement with fuel range, multi-planet systems, integer population on three jobs, a choose-your-path tech tree, ship design that matters, a Grand Roost vote. Veterans should recognise it in five minutes and still find decisions on turn 150.
2. **No 1993 pain.** Every repeated chore has an automation, every number has a breakdown tooltip, every turn ends with a summary that links to what needs you. A turn with nothing to decide takes one keypress.
3. **One evening.** Evening Standard: 4 empires, 24 stars, decided in 150-220 turns, roughly 75-120 minutes. A hard turn cap guarantees an ending.
4. **Asymmetry with numbers attached.** Eight bird empires built from one public trait-point system. Swans really are overpowered, by a declared amount, and the galaxy's patch for it is social (the Coalition), shown on the relations screen.
5. **Deterministic and testable.** Same seed + same orders = same game, bit for bit. The whole game runs headless, AI vs AI, to completion.

---

## 2. Session shape

### 2.1 Galaxy sizes

| Size | Stars | Empires (incl. player) | Map (parsecs) | Grand Roost first / every | Turn cap | Target length |
|---|---|---|---|---|---|---|
| Tiny [MVP] | 16 | 3 | 34 x 24 | T40 / 20 | 180 | 40-60 min |
| **Small = Evening Standard** [MVP] | 24 | 4 | 44 x 30 | T50 / 25 | 250 | 75-120 min |
| Medium [STRETCH] | 36 | 6 | 54 x 36 | T60 / 25 | 300 | 2-3 h |
| Large [STRETCH] | 54 | 8 | 66 x 44 | T70 / 30 | 350 | 3-4 h |

Minimum star separation 4.5 pc; mean nearest-neighbour distance about 6 pc on every size. (The meme bible's Evening Standard was 32 stars / 6 empires / turn-200 horizon; kept at 24 / 4 / 250 because six empires roughly double late-game turn time and the session target is one evening. §21.)

### 2.2 The arc of an Evening Standard (design target, measured by soak)

| Turns | Phase | What the player is doing |
|---|---|---|
| 1-30 | Explore / Expand | 2 scouts on auto-explore, first colony ship lands by ~T8, outposts extend range, first contact ~T15-25 |
| 30-80 | Expand / Exploit | 6-10 colonies, Habitat Domes opens hostile worlds, first border friction, first Grand Roost at T50 |
| 80-150 | Exploit / Exterminate | Large/Huge hulls, first real wars, invasions, the Guardian of Orn falls to someone, a Coalition forms against the leader |
| 150-220 | Endgame | Grand Roost 2/3 bids, the Exodus race, capitulations end wars instead of mop-up slogs |
| 250 | Called Game | Highest score wins (rare; the soak's termination guarantee) |

### 2.3 Turn budget

Early turns: 5-10 s of player time. Late turns: 30-60 s. End-turn processing on the web build: under 1.5 s late game on a mid laptop (ARCHITECTURE §10). Average ~25 s/turn x ~180 turns + battles ≈ 80-100 min.

---

## 3. Galaxy generation

### 3.1 Movement model — DECISION: free movement with fuel range (MoO1/MoO2), no star lanes

Justification:
- It is the defining feel of the lineage this audience asked for. Range technology is an expansion lever ("Downrange Charts or Inertial Dampers?" is a real early choice), and outposts that extend range are a MoO2 classic.
- Straight-line travel is trivial to implement deterministically (`turns = ceil(distance / speed)`), trivial to visualise, and gives the AI a clean threat model (time-to-arrival).
- Combat happens only at star systems (MoO rule). No deep-space interception.

Costs we accept and mitigate: no hard chokepoints and a doomstack tendency. Mitigations: fuel range makes the frontier geographic; nebulae slow and strip shields; planetary defenses scale with tech; Horizon missiles are ammo-limited; one wormhole pair per map creates a strategic corridor; the **battle line** (§9.2) caps how many ships fight at once. (The meme bible assumes lanes in several strings; those are flagged REWRITE in `COPY_PLAN.md`.)

### 3.2 Star placement

1. Seeded Poisson-disk sampling in the map rectangle (min separation 4.5 pc, 30 attempts) until the star count is met; if short, relax separation by 5% and continue.
2. **Orn** (the Orion analogue): the star closest to the map centre. It holds the **Guardian of Orn** (§9.8) and a Huge Gaia Ultra-Rich planet. [COPY: place.orn.name]
3. **Homeworlds**: farthest-point selection among stars at least 12 pc from Orn, maximising the minimum pairwise distance. Ties by star id.
4. **Race-aware fair start**: each homeworld must have at least 2 planets that are *good for its species* (max pop >= 8 for that species at Medium size) and 1 outpost target within 9 pc. If not, the generator converts the nearest qualifying orbits (deterministically) until true. Penguins therefore get Tundra/Ocean neighbours, never a desert ring. Each homeworld system also gets 1-2 extra planets of its own.
5. **Nebulae** [MVP]: 1 (Tiny) to 3 (Standard) elliptical regions, 6-10 pc across, never covering a homeworld. Ships inside move at speed - 1 (min 1); shields are offline in combat in a nebula system.
6. **Wormholes** [MVP]: 1 pair on Standard (0 on Tiny), joining two non-homeworld stars at least 60% of the map width apart. Travel between them takes 1 turn and ignores fuel range.
7. **Monsters** [MVP]: the Guardian at Orn; 2 (Standard) **Pond-Scum Leviathans** on the richest non-homeworld systems at least 10 pc from any homeworld. [COPY: monster.leviathan.name]

### 3.3 Star types

| Star | Weight | Orbits (min-max) | Habitable bias | Mineral bias |
|---|---|---|---|---|
| Yellow | 30 | 2-5 | Terran, Ocean, Arid | Abundant |
| Orange | 20 | 2-4 | Arid, Desert, Tundra, Swamp | Abundant/Poor |
| Red | 25 | 1-4 | Tundra, Barren, Ocean | Poor |
| White | 12 | 2-4 | Barren, Inferno, Terran | Rich |
| Blue | 8 | 1-3 | Inferno, Toxic, Radiated, Barren | Rich/Ultra Rich |
| Neutron | 5 | 1-3 | Radiated, Barren, Toxic | Ultra Rich |

Each orbit independently: 25% Asteroid belt or Gas Giant (50/50), else a planet drawn from the star's weighted climate table (`data/galaxy.json`).

### 3.4 Planets

**Climate** — population per size unit (`pop_per_size`), food per farmer (`farm`), class. Display names are copy; the meme bible's "Ice" is the `tundra` id and "Jungle" is the `swamp` id. [COPY: climate.<id>.name]

| Climate | pop/size | farm | Class |
|---|---|---|---|
| Gaia | 5 | 3 | Habitable |
| Terran | 4 | 2 | Habitable |
| Ocean | 4 | 2 | Habitable |
| Swamp (Jungle) | 3 | 2 | Habitable |
| Arid | 3 | 1 | Habitable |
| Tundra (Ice) | 2 | 1 | Habitable |
| Desert | 2 | 1 | Habitable |
| Barren | 1 | 0 | Hostile (needs Habitat Domes, PL2) |
| Inferno | 1 | 0 | Hostile (PL2) |
| Toxic | 1 | 0 | Hostile (PL2) |
| Radiated | 1 | 0 | Hostile (needs Radiation Shielding, PL4 option) |
| Asteroids / Gas Giant | — | — | Outpost only |

**Size** (`size_units`): Tiny 1 (10%), Small 2 (25%), Medium 3 (35%), Large 4 (20%), Huge 5 (10%).

**Max population** = `size_units x pop_per_size` + building/tech/trait bonuses. Medium Terran = 12, Huge Gaia = 25, Small Barren (with domes) = 2.

**Minerals** → industry per worker: Ultra Poor 1, Poor 2, Abundant 3, Rich 4, Ultra Rich 6.

**Gravity** is derived: Tiny/Small are Low-G unless Rich+ (then Normal); Medium is Normal; Large is Normal unless Rich+ (then Heavy); Huge is Heavy. A species is comfortable at its own gravity (Normal by default). Each step of mismatch: **-25% to all job output on that planet**. Gravity Generator removes it.

**Specials** (about 1 in 8 planets) [MVP: first four; STRETCH: rest]:

| Special | Effect | Copy |
|---|---|---|
| Ancient Nest Ruins | First colonist gains 1 random tech (lowest unresearched tier, any field) | [COPY: special.ruins.*] |
| Gem Deposits | +5 credits/turn | [COPY: special.gems.*] |
| Gold Deposits | +10 credits/turn | [COPY: special.gold.*] |
| Fertile Soil | +1 food per farmer | [COPY: special.fertile.*] |
| Natives (pre-spaceflight birds) | 4 native pop (good farmers +1); gained by invasion only | [COPY: special.natives.*] |
| Splinter Colony | First colonist finds pop 2 instead of 1 | [COPY: special.splinter.*] |
| Space Debris | Shipyard here builds ships at -20% cost | [COPY: special.debris.*] |

---

## 4. Empires and races

### 4.1 Trait-point system (MoO2 custom race, bird edition)

Custom race budget: **10 picks**. Negative traits refund picks; total negatives cap at -10. One choice per trait group; Specials are pick-any. Effects are applied through the modifier engine (ARCHITECTURE §6), so every tooltip explains them. [COPY: trait.<id>.name, trait.<id>.tip]

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
| Weapon band | talon_adepts | +3 | Talon (beam) damage +25% |
| | beak_adepts | +3 | Beak (kinetic) damage +25% |
| | horizon_adepts | +3 | Horizon (missile) damage +25% |
| Government | feudal | -4 | Ship cost -33%, research -25% |
| | dictatorship | 0 | Baseline |
| | democracy | +7 | Research +20%, taxes +50%; enemy spies +20 vs you |
| | unification | +6 | Food and industry +25%; conquered colonies skip occupation; taxes -25% |
| Specials | aquatic | +5 | Ocean/Swamp/Terran: +1 pop per size unit and +1 food per farmer |
| | any_puddle | +4 | Every Habitable-class climate has at least 3 pop/size (Tundra, Desert 2 → 3) |
| | subterranean | +5 | +1 pop per size unit everywhere; ground defense +25% |
| | tolerant | +8 | Every climate has at least 3 pop/size; hostile worlds need no tech; farmers make at least 1 food anywhere |
| | piscivore | 0 | Farmers use the fish table: Ocean 3, Gaia 2, Swamp 2, Tundra 2, Terran 1, all else 0 (Hydroponic Farm unchanged) |
| | heat_intolerant | -3 | Desert, Arid, Inferno and Toxic capped at 1 pop/size (applied after any floor) |
| | low_g | -4 | Comfortable at Low-G (Normal is -25%, Heavy -50%) |
| | high_g | +5 | Comfortable at Normal and Heavy |
| | large_homeworld | +1 | Homeworld is Large |
| | rich_homeworld | +2 | Homeworld minerals Rich |
| | poor_homeworld | -1 | Homeworld minerals Poor |
| | artifact_homeworld | +3 | Start with 2 extra T1 techs |
| | creative | +8 | Researching a tier grants ALL its options |
| | uncreative | -4 | Researching a tier grants ONE RANDOM option (seeded); siblings are never offered later |
| | night_hours | +2 | Research +20% while at peace with every empire met |
| | charismatic | +3 | +20 base relation with all; candidates you vote for at the Grand Roost get +10% of your votes as bonus |
| | repulsive | -6 | -30 base relation; only Peace and War are possible with you |
| | notorious | -3 | -20 base relation with all; the Coalition (§12.4) trips against you at 30% instead of 35%, and its members' mutual bonus is +15 instead of +10 |
| | distrusted | -4 | -30 base relation; nobody signs a Research Agreement with you; AIs price techs they sell you +50% |
| | territorial | -3 | -1 relation per turn with every empire that has a colony within 6 pc of yours and no treaty with you (floor -60); a Non-Aggression Pact with you needs you to have won a battle against that empire or received tribute from it |
| | fantastic_traders | +4 | Trade treaty income x2; Trade Goods converts 1:1 instead of 2:1 |
| | lucky | +3 | Never targeted by negative random events |
| | omniscient | +3 | See every star's planets and every fleet from turn 1 |
| | stealthy_ships | +4 | Enemy scanner range against your fleets halved |
| | warlord | +4 | Ship upkeep -50%; new ships start Veteran (+10 accuracy) |
| | high_upkeep | -1 | Ship upkeep +15% (empire total, rounded up) |
| | fast_ships | +3 | +1 map speed and +1 combat speed |
| | tough_hulls | +3 | Ship HP +15% |
| | v_formation | +4 | +5% weapon damage per armed ship in your battle line beyond the first, max +25% |
| | flush | +3 | When you are the attacker (your fleet arrived this turn), +20% damage in round 1; in the first battle of each war you declared or that was declared on you, enemy retreat is delayed one round |
| | huddle | +3 | Colony defense HP +30%; ships repair to full at any of your colony systems (§8.2) |
| | scavengers | +2 | When you hold the field, gain credits = 20% of destroyed enemy ships' PP, and a 20% chance (keyed) per destroyed enemy design to learn one of its part techs you lack |
| | cache | +4 | Every 12 turns you may start a Cache project: copy one tech you have *seen* (in battle, from a spy report, or offered in diplomacy) at 50% of its tier cost. Hyper-Preened keys excluded |
| | prefab_coops | +3 | Buildings -25% PP |
| | nothing_wasted | +2 | Rush-buy costs 1.5 x remaining PP and is never doubled for zero progress |

**Species vs empire traits.** Every colony records the species living there. *Species traits* (Growth, Farming, Industry, Science, Ground, aquatic, any_puddle, subterranean, tolerant, piscivore, heat_intolerant, gravity) follow the population, so a captured Owl world still has good scientists. *Empire traits* (everything else) come from the founding species and apply empire-wide. [MVP: one species per colony.]

### 4.2 The eight premade empires [MVP]

Names, leaders, archetypes, AI personalities and diplomacy lines are the meme bible's. Traits are this system's translation of the meme bible's bonuses (§21 lists every number changed). Color = Okabe-Ito colorblind-safe palette; each empire also has a unique glyph, so nothing is conveyed by color alone (§16).

| Empire (species) | Leader | Picks | Traits (cost) | Homeworld | AI personality | Color / glyph |
|---|---|---|---|---|---|---|
| **The Pale Supremacy** (Swans) | Cob-Empress Cygnara the Unbothered | **13** | good_science (3), ship_attack_+1 (2), ship_defense_+1 (3), fast_ships (3), ground_+1 (2), rich_homeworld (2), large_homeworld (1), notorious (-3) | Large Terran, Rich | The Unbothered | White #F5F5F5 / crown |
| **The Ringneck Warrant** (Pheasants) | High Cockade Vesper Goldtail | 10 | talon_adepts (3), flush (3), ship_attack_+1 (2), good_industry (3), high_upkeep (-1) | Medium Terran | The Sportsman | Vermillion #D55E00 / triangle |
| **The Dabble League** (Ducks) | First Mallard Deb Quill | 10 | fantastic_traders (4), any_puddle (4), fast_growth (3), charismatic (3), ship_attack_-1 (-2), ground_-1 (-2) | Medium Ocean | The Dealmaker | Bluish green #009E73 / circle |
| **The Night Parliament** (Owls) | Arch-Dean Athene Stillbranch | 10 | creative (8), good_science (3), night_hours (2), poor_industry (-3) | Medium Terran | The Librarian | Yellow #F0E442 / diamond |
| **The Pebble Throne** (Penguins) | Pebble-King Pebble XIV | 10 | tolerant (8), piscivore (0), huddle (3), good_industry (3), ground_+1 (2), large_homeworld (1), heat_intolerant (-3), slow_growth (-4) | Large Tundra ("Ice") | The Patient Rock | Sky blue #56B4E9 / square |
| **The Open Murder** (Crows) | Keeper of the Cache, Kestra Nightcache | 10 | spy_+1 (3), cache (4), scavengers (2), stealthy_ships (4), omniscient (3), distrusted (-4), ground_-1 (-2) | Medium Arid | The Borrower | Reddish purple #CC79A7 / cross |
| **The Marked Airspace** (Geese) | Grand Honk Brenda Ironwing | 10 | v_formation (4), tough_hulls (3), ground_+1 (2), ship_attack_+1 (2), rich_homeworld (2), territorial (-3) | Medium Terran, Rich | The Neighbor | Orange #E69F00 / chevron (V) |
| **The Pecking Order** (Chickens) | Prime Rooster Cluckett of the Ninth | 10 | unification (6), good_industry (3), prefab_coops (3), nothing_wasted (2), uncreative (-4) | Medium Terran | The Floor | Blue #0072B2 / comb (3 bumps) |

Plays like (one line each; flavour is the meme bible's "Pitch" line, [COPY: race.<id>.pitch]):
- **Swans**: research empire that also wins fights, fastest fleets, rich large home; disliked on sight and the first Coalition target.
- **Pheasants**: the gunner's empire; Talon fleets that hit first and pin the enemy in the opening battle; pricey upkeep. The veteran's pick.
- **Ducks**: wide, liked, rich; settles any puddle, grows fast, wins the Grand Roost; undergunned.
- **Owls**: every option of every tier, extra research at peace; thin factories. Interrupting an owl is the point of a war.
- **Penguins**: colonise the rocks and the ice nobody priced; can't stand the heat; turtles that repair at home.
- **Crows**: steal, scavenge, copy what they see; see everything; trusted by no one.
- **Geese**: hulls, troops and the folk art of the doomstack; feuds with every neighbour without a treaty.
- **Chickens**: the floor: enormous cheap output, one idea per tier.

Dropped from the architect pass: Hummingbirds (replaced by the meme bible's Chickens; the Alkari-tribute "fast, hard to hit" niche is partly carried by Swans' fast_ships).

### 4.3 Swans OP [MVP]

- **Swan Privilege:** Swans get 13 picks instead of 10. The race screen shows "13/13 picks". [COPY: trait.swan_privilege.tip]
- **Signature** shown first on the card in gold: "Swans OP" = fast_ships + good_science + ship_attack_+1. [COPY: race.swans.signature, race.swans.footer]
- **Notorious Perfection** = the notorious trait. The patch is social: the Coalition (§12.4) trips against Swans earlier and harder, and the modifier is labelled **Tier List**. [COPY: coalition.label.tier_list]
- **Setup toggle "Seat the Swans"** (default ON): if the player is not Swans, Swans always take one AI seat. [COPY: menu.toggle.seat_swans]
- **Balance target** (soak, §17.3): in 4-AI Evening Standard games, Swans win 35-50% (fair share 25%). Any other empire below 8% is a bug.

### 4.4 Starting state (every empire, Standard)

- Homeworld at 8 pop, Abundant minerals unless traits say otherwise, Normal G. Buildings: Grand Nest (capital), Shipyard, Marine Barracks.
- Ships: 2 Scouts, 1 Colony Ship, 2 Corvettes (Small, 4 Talons). Credits: 100.
- Known tech: Laser, Nuclear Missile, Titanium Armor, Nuclear Drive, Small and Medium hulls, Colony Pod, Outpost Pod, Troop Pod.
- Grand Nest (capital building): +3 food, +5 PP, +3 RP, +5 credits, +2 scan range, shipyard included. Losing the capital: -20% industry and research empire-wide until a new Grand Nest is built (300 PP).

Opening economy check (Dictatorship, no traits, Capital preset): 3 farmers x 2 + 3 = 9 food vs 8 eaten; 3 workers x 3 + 5 = **14 PP**; 2 scientists x 3 + 3 = **9 RP**; taxes 8 + 5 = 13 credits - upkeep 4 = **+9 credits**. Colony ship costs 65 PP: the second colony ship is out by about turn 5.

---

## 5. Colonies and economy

### 5.1 DECISION: integer population on three jobs (MoO2), automated by presets — not sliders, not a single "focus"

- Integer pop on Farmer / Worker / Scientist makes every number legible ("3 workers at 4 PP each"), lets species traits plug in as per-job yields, and makes planet quality visibly matter. MoO1 sliders hide the arithmetic.
- The meme bible's "colony grain" idea (one focus toggle, queue of four) is the right *experience* and is delivered by presets: one click per colony, or none. The jobs stay underneath so traits and planets are readable and a power player can lock any colony to Manual.
- The MoO2 pain was adjusting jobs on 20 planets and moving food with freighters. Presets (§5.6) and pooled food (§5.3) remove both.

### 5.2 Population and growth

Population is stored in milli-units (1 pop = 1000). Only whole units work, eat, and pay taxes.

```
P = pop_milli, M = max_pop_units * 1000   (P < M)
growth_milli = ( P * (M - P) / M * GROWTH_R / 100  +  GROWTH_FLAT ) * (100 + growth_pct) / 100
GROWTH_R = 10, GROWTH_FLAT = 50                                      (integer division, floor)
```

A new colony (1/12) gets 141/turn (~7 turns to 2 pop); half-full (6/12) gets 350/turn; full in ~48 turns with no bonuses. Pop above max decays 100 milli/turn. Housing converts PP into growth: 1 PP = 20 milli.

### 5.3 Food — pooled empire-wide, no freighters

- Each pop unit eats 1 food. Farmers make `farm(climate or fish table) + modifiers`. Food is summed empire-wide.
- **Surplus** becomes credits at 1 food = 1 credit.
- **Deficit D** is auto-imported at **2 credits per food** if the treasury allows. If not, for every 5 unpaid food (min 1) the most-populous colony loses 1000 milli pop. A red banner fires the first turn a deficit is imported.

### 5.4 Yields

```
food_colony     = farmers * farm_per_farmer + flat_food
industry_colony = (workers * pp_per_worker + flat_pp) * (100 + pct_industry) / 100
research_colony = (scientists * rp_per_scientist + flat_rp) * (100 + pct_research) / 100
taxes_colony    = pop_units * TAX_PER_POP(1) * (100 + pct_tax) / 100
```

Per-job yields: base (farm from climate, PP from minerals, 3 RP per scientist) + species trait + buildings; then gravity penalty (percent, floored, never below 1 per job if base >= 1); then empire and government percentages. Occupied colonies (conquered < 10 turns): all output -50%.

### 5.5 Production and the build queue

Per colony. Industry pours into the first queue item; **overflow carries in full to the next item** in the same turn (the meme bible's "Nothing Wasted" is therefore everyone's rule; the Chicken trait of that name improves rush-buying instead); any number of items may complete per turn.

Queue items: Buildings (each once per colony) and Projects (Terraforming STRETCH, Departure Roost); ships from any current design (needs a Shipyard) with **Repeat** and **Count**; **Colony Base** (40 PP, colonises another planet in the same system); **Trade Goods** filler (2 PP = 1 credit); **Housing** filler (1 PP = 20 growth milli).

**Rush buy**: `2 x remaining PP` credits, doubled if the item has 0 progress (nothing_wasted: 1.5x, never doubled). Bought items complete at turn processing.

**Queue templates**: any queue can be saved and applied to any set of colonies.

### 5.6 Colony presets (the governor) [MVP]

A preset = a **job policy** + a **build list**. When the queue is empty the governor appends the first build-list building not yet built and known, else the preset's filler. "Manual" locks jobs and queue.

| Preset | Job policy | Build list (in order; skips unknown/built) | Filler |
|---|---|---|---|
| Capital | Feed self, then 60% workers / 40% scientists | Automated Factory, Research Lab, Hydroponic Farm, Robotic Mines, Supercomputer, Planetary Shield, Missile Base, … | Repeat last warship design |
| Industry | Feed self, all remaining workers | Automated Factory, Robotic Mines, Deep Core Mines, Missile Base, … | Trade Goods |
| Research | Feed self, all remaining scientists | Research Lab, Supercomputer, Autolab, Galactic Cybernet, … | Trade Goods |
| Breadbasket | Farmers only on worlds with farm >= 2 | Hydroponic Farm, Soil Enrichment, Weather Controller, … | Housing |
| Frontier (default for new colonies) | Feed self, rest workers | Marine Barracks if border, Hydroponic Farm if farm < 1, Automated Factory | Housing until pop >= 50% max, then Trade Goods |
| Fortress | Feed self, rest workers | Missile Base, Planetary Shield, Ground Batteries, Star Fortress | Trade Goods |
| Manual | Unchanged | Nothing auto-added | Nothing |

**Job assignment** (deterministic): (1) each non-manual colony assigns farmers until it feeds itself, only if `farm_per_farmer >= 1`; (2) empire balancing: while empire food < 0, add 1 farmer at the non-manual colony with the highest `farm_per_farmer` that still has a non-farmer (ties by colony id); while food > +3 and a colony has an unneeded farmer, remove one at the lowest-yield colony; (3) remaining pop split per preset ratio, workers rounded down. Auto-preset for new colonies: Frontier, switching at 50% pop to Industry (minerals >= Rich) or Research (research special) else Industry. Setting "Auto-assign presets" ON by default.

**Governor digest** [MVP] (meme bible "While You Were Away"): every 10 turns the turn summary has a "Governor log" section listing what governors queued and changed, in plain language. Governors never trade techs, cancel a victory project, or declare war. [STRETCH: one free revert of one colony's queue per game.] [COPY: summary.digest.title, summary.digest.body]

### 5.7 Credits

Income: taxes + Grand Nest + specials + trade treaties + Trade Goods + food surplus + Seed Exchange. Expenses: building upkeep, ship upkeep (§8.2), food import, spy and security funding.

**Negative treasury**: credits cannot go below 0; a shortfall becomes **Strike**: empire-wide industry -25% next turn and a summary alert.

### 5.8 Buildings [MVP list]

Display names: bolded names are the meme bible's; others are placeholders (COPY gap). [COPY: building.<id>.name, building.<id>.tip]

| id | Display | Tech | PP | Upkeep | Effect |
|---|---|---|---|---|---|
| grand_nest | Grand Nest | start | 300 (rebuild) | 0 | Capital: +3 food, +5 PP, +3 RP, +5 cr, +2 scan, shipyard |
| shipyard | Shipyard | start | 60 | 1 | Can build ships here |
| marine_barracks | Marine Barracks | start | 40 | 1 | Garrison 4 marines; +2 marines/turn regen |
| hydroponic_farm | Hydroponic Farm (Penguins: Fishery) | PL1 | 60 | 1 | +2 food |
| automated_factory | **Second Shift Hall** | CN1 | 60 | 1 | +1 PP/worker, +3 PP |
| research_lab | Research Lab | CO1 opt | 60 | 1 | +1 RP/scientist, +3 RP |
| missile_base | Missile Base | WE1 opt | 80 | 1 | Planet defense: 3 launchers of best Horizon, 40 HP x armor mult |
| planetary_shield | Planetary Shield | FF2 | 100 | 2 | Planet shield class 5; bombardment -50% |
| soil_enrichment | Soil Enrichment | PL1 opt | 80 | 1 | +1 food/farmer |
| cloning_center | Cloning Center | PL2 opt | 100 | 2 | Growth +50% here |
| robotic_mines | Robotic Mines | CN3 | 100 | 2 | +1 PP/worker, +5 PP |
| supercomputer | Supercomputer | CO3 opt | 120 | 2 | +1 RP/scientist, +5 RP |
| biospheres | Biospheres | PL3 | 100 | 1 | +1 max pop per size unit |
| ground_batteries | Ground Batteries | WE3 opt | 120 | 2 | Planet defense: 4 heavy-mount Talons of best beam |
| seed_exchange | Seed Exchange | CO4 opt | 150 | 0 | Taxes here +50% |
| gravity_generator | Gravity Generator | FF4 | 150 | 2 | Removes gravity penalty here |
| autolab | Autolab | CO5 opt | 150 | 3 | +10 RP flat |
| weather_controller | Weather Controller | PL5 | 150 | 2 | +1 food/farmer |
| star_fortress | Star Fortress | CN5 | 250 | 3 | Orbital defense 400 HP x armor, 6 best Talons, shield = best ship shield; ships built here -10% |
| galactic_cybernet | Galactic Cybernet | CO6 | 200 | 3 | +2 RP/scientist |
| planetary_flux_shield | Planetary Flux Shield | FF6 | 200 | 3 | Planet shield class 10; bombardment -75% |
| deep_core_mines | Deep Core Mines | CN7 | 200 | 3 | +2 PP/worker, +10 PP |
| star_gate | **Roost Lanes** gate | PR7 opt | 300 | 4 | 1-turn travel between any two of your gate systems [STRETCH] |
| departure_roost | **Departure Roost** | Exodus keys (§14) | 3000 | 0 | Project, capital only: completion = Exodus victory |

Meme-bible buildings not adopted: Lane Perch, Still Perch (no lanes / no culture-flip system), Council Minutes Office, Review Desk (the Grand Roost and the Perch Review need no building). Thesis Range is an empire-wide unlock from an event (§20). See §21.

---

## 6. Research

### 6.1 DECISION: six fields, eight tiers, "core + choose one" per tier, single active project

- **Six fields** (MoO1 set, meme-bible names):

| id | Code | Display | Covers |
|---|---|---|---|
| computers | CO | **Flocknet** | Battle computers, ECM, scanners, labs, spies |
| construction | CN | **Nestworks** | Hulls, armor, industry, ground gear |
| force_fields | FF | *Downfield* (PLACEHOLDER, COPY gap) | Ship and planet shields, defensive fields |
| planetology | PL | **Plumage** | Food, habitability, growth, terraforming |
| propulsion | PR | **Flightcraft** | Drives, fuel range, evasion |
| weapons | WE | **Broodheat** | Talon, Beak and Horizon weapons |

  The meme bible's sixth field, **Roost Law** (government, treaties, spies, council), is not a field here: government is a race trait, and diplomacy, espionage and the Grand Roost are always-on systems, not tech-gated. Shields are core to the combat triangle and keep their own field. (§21)
- **Tiers**: each field is a chain of 8 tiers; tier N needs tier N-1 of the same field. No cross-field prerequisites. Tiers 1-2 are early, 3-5 midgame, 6-8 evening-enders; tiers 7-8 carry the **Hyper-Preened** label. [COPY: tier.hyper_preened.label, tier.hyper_preened.flavor]
- **Core + options**: every tier grants a **core** tech plus **one option of 2-3** chosen when starting the node. Cores carry the backbone (hulls, drives, mainline weapons, shields); options carry specialisation.
- **Unchosen options** (adapted from the meme bible's choice rule): an unchosen option can be researched later as its own project at **150%** of its tier cost (meme bible said +25%; raised so the first choice still matters and Creative keeps its 8-pick value). It can also be traded, stolen, captured, or copied by a Crow Cache. **Creative** (Owls, "Wide-Eyed") gets every option at once. **Uncreative** (Chickens, "One-Note") is shown one random option per tier and can never research the siblings (trade/steal only).
- **One active project** at a time; overflow carries 100%. A **research queue** pre-selects the next nodes and their options.
- **Deterministic completion**, no breakthrough roll.
- **Hyper-Preened repeatables** [MVP]: after tier 8, each field offers "Hyper-Preened <Field> II, III…": +5% to that field's primary stat (CO accuracy, CN armor HP, FF shield class +1 per 2 levels, PL max pop +1 per size per 3 levels, PR +1 range, WE +5% damage). [COPY: tech.hyper_<field>.name]
- **Exodus keys**: **Hyper-Preened Kinematics** (PR8 core) and **Hyper-Preened Genesis** (PL8 core) can never be traded, gifted, stolen, captured or cached (meme bible idea 7).

### 6.2 Cost

```
cost(tier) = RESEARCH_BASE(20) * tier^2              T1 20, T2 80, T3 180, T4 320, T5 500, T6 720, T7 980, T8 1280
unchosen option later = cost(tier) * 150 / 100
hyper(n)   = 1500 + 300 * n
```
Design target (soak-measured): a balanced player finishes all six T4 by ~T100 and all six T7 by ~T185; a research-focused player can reach Exodus by ~T165.

### 6.3 The tree [MVP: all 48 nodes]

**Bold** = meme-bible name adopted (the bible's effect note was mapped onto this effect). Plain = placeholder name, COPY gap. Every row's names are `tech.<id>.name`, flavour `tech.<id>.flavor`.

**Flocknet (CO)**
| T | Core | Options (choose one) |
|---|---|---|
| 1 | **Pecking Logs** — Battle Computer Mk1 (+10 acc) | **Research Roost** — Research Lab (bldg) / **The Shared Glance** — +2 scan range, scouts reveal planets at 3 pc |
| 2 | **Everyone Can Miss** — ECM Jammer I (special) | Security Nest (+25 counter-intel) / Space Academy (new ships Veteran +5 acc) |
| 3 | **Predictive Peck** — Battle Computer Mk2 (+20) | Supercomputer (bldg) / Battle Scanner (special: +10 acc, reveals enemy designs) |
| 4 | ECM Jammer II | Seed Exchange (bldg) / Scanner Net (+4 scan; see fleet destinations) |
| 5 | Battle Computer Mk3 (+30) | Autolab (bldg) / **Battle Transcriber** — +30 spy score; battle autopsy shows enemy loadouts |
| 6 | Galactic Cybernet (bldg) | ECM Jammer III / **Spreadsheet of Fate** — Horizon +10 acc empire-wide (= Thesis Range, §20 event 14) |
| 7 | Battle Computer Mk4 (+40) | Hyper-Scanner (see all fleets) / Sabotage Network (unlocks sabotage) [STRETCH effect] |
| 8 | **Hyper-Preened Cognition** — Battle Computer Mk5 (+50), battle line +1 | Sentient Nest-Mind (+25% research) / Precision Targeting (Beak ignores shields) |

**Nestworks (CN)**
| T | Core | Options |
|---|---|---|
| 1 | **Second Shift** — Second Shift Hall (= Automated Factory) | **Reinforced Roost** — Reinforced Hull (special) / **Drydock of Regret** — ships -10% PP |
| 2 | Large Hull | **Proper Joinery** — Tritanium Armor (x1.5) / Orbital Mining (outposts on asteroids/gas giants +3 PP to the system's best colony) |
| 3 | **Automated Incubators** — Robotic Mines (bldg) | **Standards and Talons** — +5 marine strength / Prefab Nests (buildings -20% PP) |
| 4 | Huge Hull | Zortrium Armor (x2.0) / Fortified Nests (planet defense HP x1.5) |
| 5 | Star Fortress (bldg) | Powered Exoskeleton (+10 marine and militia str) / Recyclotron (building upkeep -25%) |
| 6 | **Titan Perch** — Titan hull | Neutronium Armor (x2.75) / **Self-Sealing Nest** — Damage Control (special) |
| 7 | Deep Core Mines (bldg) | Assembly Swarms (+25% industry) / Advanced Exoskeleton (+10 marine str) |
| 8 | **The Unsinkable Argument** — Adamantium Armor (x3.5) | Planetary Barrier Nest (planet defense HP x2) / Shipyard Swarm (ships -25% PP) |

**Downfield (FF)** — no meme-bible names yet (COPY gap)
| T | Core | Options |
|---|---|---|
| 1 | Deflector Shield class 2 | Personal Shields (+5 marine/militia str) / Scatter Field (incoming Horizon -20 acc) |
| 2 | Planetary Shield (bldg) | Shield Capacitor (ship shield +1 in rounds 1-3) / Inertial Nullifier (+10 evasion) |
| 3 | Shield class 4 | Tractor Lock (enemy retreat delayed 2 rounds) / Hardened Plating (+20% hull HP) |
| 4 | Gravity Generator (bldg) | Warp Dissipator (no enemy retreat in your systems) / Repulsor Field (enemies start 2 range farther) |
| 5 | Shield class 6 | Cloaking Device (special) / Deflector Grid (planet shields +3) |
| 6 | Planetary Flux Shield (bldg) | Phase Shift (special: 25% of hits miss outright) / Stasis Field (special) [STRETCH effect] |
| 7 | Shield class 9 | Hard Shields (shields reduce Beak fully) / Shield Overcharge (+2 shield class) |
| 8 | Planetary Shield 15 upgrade | Reflective Plumage (zero-damage Talon hits reflect 50% raw) / Absolute Barrier (planets immune to bombardment) |

**Plumage (PL)**
| T | Core | Options |
|---|---|---|
| 1 | **Better Feed** — Hydroponic Farm (bldg) | Soil Enrichment (bldg) / Eco Restoration (+1 max pop per size on Terran/Ocean/Swamp/Gaia) |
| 2 | Habitat Domes (colonise Barren/Inferno/Toxic) | **Molt Management** — Cloning Center (bldg) / Universal Antidote (immune to plague events, +10% growth) |
| 3 | Biospheres (bldg) | Advanced Domes (hostile pop/size 2) / **Toxic Preening** — bombardment x2; each use -5 relation with every empire that sees it |
| 4 | **Climate Tailoring** — Terraforming [STRETCH: MVP grants +1 max pop per size on Tundra/Desert/Arid] | Radiation Shielding (colonise Radiated) / Subterranean Farms (+2 food per colony) |
| 5 | Weather Controller (bldg) | Gene Splicing (+25% growth) / Advanced Domes II (hostile pop/size 3) |
| 6 | **Deep Down** — Urban Nests (+1 max pop per size, all colonies) | Evolutionary Mutation (gain 4 trait picks, once) / Survival Pods (colony ships land pop 2) |
| 7 | Gaia Transformation [STRETCH: MVP grants +2 food per colony] | Artificial Planet [STRETCH] / Bio-Harmonics (+1 food/farmer) |
| 8 | **Hyper-Preened Genesis** — +2 max pop per size; **Exodus key** | Genome Uplift (+1 to every job yield) / Rapid Hatching (+50% growth) |

**Flightcraft (PR)**
| T | Core | Options |
|---|---|---|
| 1 | **Downrange Charts** — range 8 | Augmented Engines (special: +1 combat speed) / Inertial Dampers (+10 evasion all ships) |
| 2 | **Warm Current** — Fusion Drive (speed 3) | Extended Fuel Tanks (special: +3 range) / Courier Wings (+1 map speed for Small/Medium) |
| 3 | **Tailwinds** — range 10 | Trade Lanes (trade treaty income +50%) / Logistics Network (ship upkeep -25%) |
| 4 | **The Folded Sky** — Impulse Drive (speed 4) | Inertial Stabilizer (+20 evasion) / Long-Range Colonisation (colony/outpost ships +4 range) |
| 5 | **Migratory Math** — range 13 | Combat Afterburners (+1 combat speed all) / Displacement Device (special: 30% of hits dodged) |
| 6 | Antimatter Drive (speed 5) | Interstellar Highways (+1 speed inside own range) / **Instant Regret** — Emergency Warp (retreat round 1, no receipt) |
| 7 | Hyper Cells (range 17) | **Roost Lanes** — Star Gate (bldg) [STRETCH] / Nebula Runners (no nebula penalties) |
| 8 | **Hyper-Preened Kinematics** — Hyperdrive (speed 7); **Exodus key** | Unlimited Range / Time Warp Facilitator (your ships fire twice in round 1) |

**Broodheat (WE)** — Talon and Beak lines are core; the Horizon line and defenses are options.
| T | Core | Options |
|---|---|---|
| 1 | Mass Driver (Beak) | Missile Base (bldg) / Heavy Mount (Talon mount mod) |
| 2 | **Second Sun** — Fusion Beam (Talon) | Merculite Missile (Horizon) / Point-Defense Mount (mod) |
| 3 | Gauss Cannon (Beak) | Ground Batteries (bldg) / Fusion Bomb (special: bombardment x2) |
| 4 | **Focused Glare** — Phasor (Talon) | Pulson Missile (Horizon) / Armor-Piercing Rounds (Beak ignores 75% shields) [STRETCH alt: Fighter Bay] |
| 5 | Hellbore Cannon (Beak) | Missile Base II (planet Horizon +50% dmg) / Auto-Fire (Talons +1 shot every other round) |
| 6 | **The Long Honk** — Plasma Cannon (Talon) | Zeon Missile (Horizon) / Spinal Mount (Huge/Titan: 1 heavy Talon x3 dmg) |
| 7 | Graviton Driver (Beak) | Enveloping Mount (Talon dmg x1.5, space x1.5) / Plasma Web (special: 15 dmg to every enemy in round 1) |
| 8 | **Hyper-Preened Thermals** — Death Ray (Talon) | **Quiet Star** — Antimatter Torpedo (Horizon) / **Heart of the Roost** — Very Polite Warhead (special: bombardment kills 2 pop/turn regardless of shields; triggers event 6) |

Meme-bible tech names not placed (no matching effect): Shared Body Heat, Pinion Reactor (no reactor/power system), Hyper-Preened Mandate (no Roost Law field; §21), all other Roost Law names.

**Tech you cannot research**: Death Ray is also Guardian loot; capturing a colony grants one random tech the victim knows and you don't (50%, keyed; never an Exodus key).

---

## 7. Ship design

### 7.1 Hulls

| Hull (id) | Tech | Space | Base HP | PP | Evasion | Upkeep (cr) | Specials max | Battle-line slots |
|---|---|---|---|---|---|---|---|---|
| small | start | 24 | 20 | 8 | +15 | 1 | 1 | 1 |
| medium | start | 60 | 60 | 22 | +5 | 1 | 2 | 1 |
| large | CN2 | 130 | 150 | 55 | 0 | 2 | 3 | 1 |
| huge | CN4 | 280 | 350 | 130 | -10 | 4 | 4 | 1 |
| titan (**Titan Perch**) | CN6 | 600 | 800 | 320 | -20 | 8 | 5 | 2 |

Unarmed ships pay no upkeep. [COPY: hull.<id>.name; only Titan Perch has a meme-bible name]

### 7.2 A design

Hull + exactly one **Engine**, one **Armor**, one **Shield** (or none), one **Computer** (or none) + weapon mounts + up to N specials.
- Engine, Shield and Computer take a **percentage of hull space**: Engine 15/13/11/9/7% by tier; Shield 8/10/12/14%; Computer 5%. Rounded up.
- Armor takes no space; it multiplies HP and adds % of hull PP.
- Weapons and specials take **flat space**, shrunk by miniaturisation.

**Miniaturisation** (MoO2): for a part of tier `t` in field `f` where you know tier `T` of `f`:
```
space = ceil(base_space * max(50, 100 - 10*(T - t)) / 100)
cost  = ceil(base_cost  * max(50, 100 - 10*(T - t)) / 100)
```

### 7.3 Parts [MVP]

Weapon bands: **Talon** = beams, **Beak** = kinetic, **Horizon** = missiles. Damage `a-b` is uniform integer. [COPY: part.<id>.name, part.<id>.tip]

| Part | Field/T | Space | PP | Damage | Notes |
|---|---|---|---|---|---|
| **Talon** (beams) | | | | | Range falloff 4%/range unit; full shields apply |
| Laser | start | 5 | 3 | 3-8 | |
| Fusion Beam | WE2 | 6 | 5 | 5-12 | |
| Phasor | WE4 | 8 | 8 | 8-18 | |
| Plasma Cannon | WE6 | 10 | 12 | 12-28 | |
| Death Ray | WE8 | 12 | 18 | 20-45 | |
| **Beak** (kinetic) | | | | | -6 acc per range unit; shields count half |
| Mass Driver | WE1 | 6 | 3 | 5-9 | |
| Gauss Cannon | WE3 | 8 | 6 | 9-15 | |
| Hellbore Cannon | WE5 | 10 | 10 | 14-24 | |
| Graviton Driver | WE7 | 12 | 14 | 22-36 | |
| **Horizon** (missiles) | | | | | Fixed damage; 4 salvos; 1-round flight; full shields; PD and ECM counter |
| Nuclear Missile | start | 6 | 4 | 8 | acc +0 |
| Merculite | WE2 opt | 6 | 6 | 12 | acc +10 |
| Pulson | WE4 opt | 6 | 8 | 17 | acc +15 |
| Zeon | WE6 opt | 7 | 10 | 24 | acc +20 |
| Antimatter Torpedo | WE8 opt | 10 | 14 | 40 | unlimited ammo, fires every other round |
| **Mount mods** (Talons only) | | | | | |
| Heavy Mount | WE1 opt | x2 | x1.5 | x1.5 | falloff 2%/range |
| Point-Defense Mount | WE2 opt | x0.5 | x0.5 | x0.5 | +20 acc; shoots incoming Horizon first (2 shots each) |
| **Systems** | | | | | |
| Engines | PR | % | 10% hull PP | — | Nuclear 2/1, Fusion 3/2, Impulse 4/2, Antimatter 5/3, Hyperdrive 7/3 (map speed / combat speed) |
| Armor | CN | 0 | +0/20/40/60/80% hull PP | — | HP x1.0 / 1.5 / 2.0 / 2.75 / 3.5 |
| Shields | FF | % | 15% hull PP | — | Class 2 / 4 / 6 / 9 |
| Computers | CO | 5% | 10% hull PP | — | +10 … +50 acc |
| **Specials** | | | | | |
| Colony Pod | start | 40 | 40 | | Colonises a planet; consumed |
| Outpost Pod | start | 12 | 18 | | Claims any planet/asteroid/gas giant, no pop; extends range; consumed |
| Troop Pod | start | 20 | 10 | | 4 marines |
| Scanner Pod | start | 4 | 2 | | +2 scan range |
| Reinforced Hull | CN1 opt | 10% | 10% | | HP +50% |
| ECM Jammer I/II/III | CO2/4/6 | 5% | 5 | | Horizon vs this ship -20/-40/-60 acc |
| Battle Scanner | CO3 opt | 4 | 6 | | +10 acc; reveals enemy designs |
| Augmented Engines | PR1 opt | 5% | 5 | | +1 combat speed |
| Extended Fuel Tanks | PR2 opt | 5% | 4 | | +3 range |
| Damage Control | CN6 opt | 8% | 15 | | Heal 10% max HP at end of each round |
| Cloaking Device | FF5 opt | 10% | 20 | | Untargetable in rounds 1-2; may still fire |
| Displacement Device | PR5 opt | 8% | 15 | | 30% of incoming hits dodged |
| Fusion Bomb | WE3 opt | 10 | 8 | | Bombardment x2 (stacks to x3) |
| Very Polite Warhead | WE8 opt | 12 | 30 | | Bombardment kills 2 pop/turn regardless of shields |
| **Orn-Plating** | Guardian loot | 5% | 20 | | Unique to the empire that killed the Guardian: HP +40%, shield class +2 |

### 7.4 Designer UI and auto-design [MVP]

Designer: hull picker; system pickers default to best known; weapon list with +/- and mount mod; specials; a space bar (used/total) that turns red at overflow; live stats: HP, evasion, speed, PP, upkeep, **expected damage per round at range 3 vs shield 0 / 2 / 4 / 6 / 9**, obsolete-part warning. Max 12 active designs.

**Auto-design** (same code the AI uses), roles **Talon Warship / Beak Warship / Horizon Boat** ([COPY: role.horizon_boat.tip] — the bible's "Pure Missile Honesty" line) **/ Point-Defense Escort / Troop Ship / Colony Ship / Outpost Ship / Scout**. Greedy and deterministic: best known engine, armor, computer, shield (no shield on Small); role specials by priority while leaving >= 60% of remaining space for weapons; fill with the role weapon maximising `expected_damage_per_space` vs the highest shield class seen on an enemy design; leftover space gets the cheapest Talon that fits. "Upgrade queued designs" (default ON) swaps queued ships to the new auto-design of the same role.

---

## 8. Fleets and movement

### 8.1 Movement [MVP]

- Fleet speed = slowest ship. Turns = `ceil(distance / speed)`; nebula legs at speed - 1. Fleets in transit **can be redirected** at any time.
- **Fuel range**: a destination is legal only within `range` pc of one of your colonies or outposts (or an ally's with an Alliance). Range: base 6, PR1 8, PR3 10, PR5 13, PR7 17, Unlimited at PR8 option; Extended Fuel Tanks +3 per ship (fleet uses the minimum). The map shows the reachable area as a translucent fill (UI marker).
- **Wormholes**: entering one end continues to the other next turn.
- **Auto-explore** (scouts) and **auto-colonise** suggestions; **rally point** per shipyard colony.
- Standing orders per fleet: **Doctrine** (§9.2), **Retreat if estimated odds < X** (Never / 1:2 / 1:1), Auto-defend.
- A fleet with 8 or more ships is labelled **DOOMSTACK** in the fleet panel (cosmetic; renamable; Geese AI never renames). [COPY: ui.fleet.doomstack, ui.fleet.doomstack_tip]

### 8.2 Upkeep, repair, limits

Ship upkeep per hull (§7.1), Warlord -50%, high_upkeep +15%. No command-point cap. **Repair**: damaged ships regain 20% max HP per turn in a system with one of your colonies, 100% at a Shipyard system, 0 elsewhere (huddle: 100% at any own colony system).

### 8.3 Visibility (fog of war) [MVP]

- Every star's position and colour is known from turn 1. A star's planets are **explored** once any of your ships has been there (or Omniscient / The Shared Glance reveal).
- You **see** fleets within scan range of your colonies (3 pc, +2 capital, + tech) or ships (1 pc; Scanner Pod +2). Stealthy ships halve the range at which they are seen.
- Foreign colonies: owner and pop visible once explored; buildings only while in scan range.
- The AI uses exactly this model, plus any declared difficulty vision (§13.1).

---

## 9. Combat

### 9.1 When and who

Combat happens at a system at the start of the combat step if two or more empires with ships or armed planets there are at war (or one is the Monster faction). Free-for-all by war relation. Unarmed ships participate as targets. One battle per system per turn. **Outcome is resolved fully before anything is shown.** The battle viewer replays the resolved log; skipping cannot change anything.

### 9.2 The range track and the battle line

**Range track** (1D, MoO-readable): each party has an **advance** `c` in 0..5 (starts 0). Distance between A and B = `max(0, 10 - c_A - c_B)`. Planets and starbases are fixed at `c = 0`. A party moves at the minimum combat speed of its armed mobile ships in the line. Bands read on the track: **Beak** wants 0-2, **Talon** 3-6, **Horizon** fires from anywhere.

**Doctrine** (standing order; a party uses the doctrine of its largest fleet): **Auto** (preferred distance from loadout: Talon-weighted 4, Beak-weighted 1, Horizon-weighted 10, mixed by damage-weighted average), **Close In** (0), **Stand Off** (10), **Retreat** (does not advance, fires only point defense, retreats per §9.6). Movement per round: toward preferred distance by `speed`; clamp 0..5; simultaneous.

**Battle line** (adapted from the meme bible's fleet cap): each party fields at most **8 line slots** of ships at a time (Titan = 2 slots; Geese 10; Hyper-Preened Cognition +1). The rest are **reserve**: at the start of each round, reserves fill empty slots left by destroyed or retreated line ships, largest hull first, then lowest id. Planet defenses are not counted. Effects: a 30-ship stack cannot alpha-strike with all 30, defenders with planets trade evenly, depth still matters across rounds and turns. (Meme bible: cap 6, overflow arrives next turn; §21.) [COPY: ui.battle_line.tip]

### 9.3 A round (8 rounds max)

1. **Reserves** fill the line. **Move** (simultaneous).
2. **Horizon missiles in flight arrive**: target party's point-defense mounts shoot first (2 shots each at 60 + acc; each hit destroys one missile). Survivors roll to hit.
3. **Fire**: every line weapon mount (cloaked ships excepted in rounds 1-2) picks a target and rolls. **All shots are computed against the start-of-step state and applied together.**
4. **Missile launch**: launchers with ammo fire (arrive next round; round-8 launches never arrive).
5. **Cleanup**: 0-HP ships destroyed; Damage Control heals; retreat checks.

**To-hit (Talon and Beak)**:
```
to_hit = clamp( 60 + acc_attacker - evasion_target - (beak ? 6*distance : 0), 5, 95 )
acc_attacker   = computer + race ship_attack + veteran + battle_scanner + weapon acc
evasion_target = hull evasion + race ship_defense + techs; planets -30
```
**To-hit (Horizon)**: `clamp( 70 + missile acc - ECM - evasion_target/2 - Scatter Field, 5, 95 )`.

**Damage per hit**:
```
raw    = rng(min..max)                                  (Horizon: fixed)
raw    = raw * (100 + band_trait_pct + v_formation_pct + flush_pct + hyper_pct) / 100
Talon  : raw = raw * (100 - falloff*distance) / 100     (falloff 4, Heavy 2)
shield : Talon/Horizon full class; Beak floor(class/2); 0 in nebula
eff    = max(0, raw - shield)
```
Single HP pool per ship (hull HP x armor x reinforced x tough_hulls). No component damage.

**Targeting** ("they focus what they can kill"): each mount picks the enemy maximising `expected_eff_damage / max(1, remaining_hp_after_assigned_expected_damage)`; ties by lowest unit id. PD mounts prefer missiles in flight. Planets' defense HP is a pool; at 0 the planet is **suppressed** for the battle and regenerates 25% per turn.

### 9.4 End of battle and the autopsy

- Ends early when at most one mutually-hostile side has armed units left.
- After round 8 with several armed sides: **stalemate**; everyone stays, no orbit control, battle repeats next turn.
- The side holding the field **controls orbit**; enemy unarmed ships still present are destroyed.
- **Veterancy**: ships that hit something and survive gain +5 acc (max +15).
- **Autopsy** [MVP] (meme bible idea 3): the battle result card names the **deciding band** (the band that dealt the most damage for the winner), any **retreat and its receipt**, and the **standout hull** (most damage dealt). Battle Transcriber adds enemy loadouts. [COPY: battle.autopsy.*]

### 9.5 Planets in combat

A colony's armed defenses form a party at `c = 0`: Missile Bases (3 launchers each, unlimited ammo), Ground Batteries (4 heavy Talons), Star Fortress (6 Talons, own shield, 400 HP x armor). Defense HP = sum of building HP x armor x Fortified Nests x huddle. Planet shield class applies to every hit on the planet.

### 9.6 Retreat with a receipt

Adapted from the meme bible (idea 4): a retreating party (doctrine Retreat, or its odds threshold triggered at battle start) **always escapes at the end of round 2**, but pays a **receipt**: its slowest ship (ties: most damaged, then lowest id) is destroyed. Modifiers: Emergency Warp (own) escapes at round 1 with no receipt; Tractor Lock (enemy) +2 rounds; flush (enemy, first battle of a war) +1 round; Warp Dissipator (enemy, in their system) forbids retreat. Escaped fleets move toward the nearest friendly colony in range. [COPY: ui.retreat.receipt_tip — bible's "Straggler Coupling" line]

### 9.7 Battle viewer [MVP]

Side-view 2D; party columns at a horizontal position from `c`; planets at the edge. ~1.2 s per round at 1x (8-10 s for a full battle; the bible's 60-90 s target rejected for session length), speeds 1x/2x/4x, **Pause**, Skip, Replay from the turn summary. Each hit shows its number. Drawn projectiles are capped (bible idea 3): beyond the cap, a mount's shots render as a single **volley tick** with a summed number. The autopsy card ends the replay. Setting **Battles**: Watch all mine / Watch big ones (default: my side >= 3 ships or a colony defending) / Never. (VFX rules §15.4.) [COPY: ui.battle.pause_tip]

### 9.8 Monsters [MVP]

Monster faction (at war with everyone, never moves [MVP]):
- **Guardian of Orn** (at Orn): 3000 HP, shield 9, evasion -20, 6 Death Rays, 2 Zeon launchers (unlimited), Damage Control. Fixed strength (the bible's "120% of the strongest fleet" scaling rejected: rubber-band; veterans plan around a known Orion). Beatable ~T5-T6 with 5-7 Large ships. Reward: Orn colonisable, 2 random techs (tier <= your highest + 1), Death Ray, and **Orn-Plating**. First contact shows the **warning volley** card. An empire whose fleet fights it and retreats is **Guardian-Marked**: -10% weapon damage for 10 turns. [COPY: monster.guardian.*, notify.guardian_marked]
- **Pond-Scum Leviathan** (x2 on Standard): 400 HP, shield 2, 4 "pseudopod" Beaks 8-14. Guards a rich system. [COPY: monster.leviathan.*]

---

## 10. Ground invasion and bombardment

**Bombardment** [MVP]: a fleet that controls orbit with order Bombard deals each turn
```
B = sum over armed ships of sum over Talon/Beak mounts of max(0, avg_dmg - planet_shield) * 3 * bomb_mult
pop_killed_milli = B * 1000 / 30
```
(halved / quartered by Planetary Shield / Flux Shield; Absolute Barrier immune; Very Polite Warhead adds 2000 milli regardless). Bombardment zeroes defense regen that turn. Diplomacy: -5 relation per turn with the victim, -2 with all others; Toxic Preening bombardment -5 more with all who see it.

**Invasion** [MVP]: troop ships in a fleet that controls orbit at the end of this turn's combat land with order Invade. Planet defenses must be suppressed or absent.
- Attackers: 4 marines per Troop Pod, strength `10 + tech` x ground modifier.
- Defenders: militia `ceil(pop_units / 2)` at `6 + tech`, plus garrison marines (Barracks: 4, regen 2/turn, `10 + tech`), x ground modifier (Subterranean +25%).
- Duels until one side is empty: `p_attacker = s_a * 100 / (s_a + s_d)`; garrison fights first. Keyed RNG (turn, colony).
- Win: colony changes owner, keeps species, pop and buildings, **Occupied** 10 turns (-50% output; Unification skips). 50% chance to gain one tech the victim knows and you don't (never an Exodus key).
- Lose: all landed marines die.

---

## 11. Espionage (light) [MVP: steal; STRETCH: sabotage, framing]

- Per known rival: **Spy funding** Off / Low 3 / Med 6 / High 12 credits per turn. Per empire: **Security** at the same levels.
- `intel += funding * (100 + spy_trait) / 100` per turn. A steal attempt fires when `intel >= 30 + 3 x L`, L = target techs you lack (cap 20).
- `success = clamp(50 + spy_attacker - security_defender, 10, 90)`; `security_defender = 2 x security_funding + spy trait (+25 Security Nest) (-20 if Democracy)`. Success: steal one random tech you lack (keyed, never an Exodus key). Failure: 50% caught, -15 relation. Intel resets either way.
- A stolen tech also counts as *seen* for a Crow Cache. [STRETCH: Borrower framing — on a caught failure, 50% the blame lands on a random third empire.]

---

## 12. Diplomacy, the Coalition and the Grand Roost

### 12.1 Relations [MVP]

Integer -100..+100 per pair, shown with a full breakdown tooltip. Components:

| Factor | Value |
|---|---|
| Base | 0; charismatic +20; notorious -20; repulsive / distrusted -30; same personality +5 |
| Border tension | -2 per pair of colonies within 6 pc (cap -20); territorial: additional -1/turn accumulating, floor -60, stops while a treaty holds |
| Treaties | +10 each active treaty |
| Trade / research benefits | +1 per 10 credits/RP gained per turn (cap +15) |
| Gifts and tech transfers | +1 per 10 credits of value given (decays 1/turn) — "favours" in the tooltip |
| Incidents ("grudges") | Spy caught -15; bombarded -5/turn; backstab (war while a treaty holds) -40 with victim and -20 with all who saw it; broken Grand Roost pledge -20 |
| War | -30 while at war |
| Coalition | +10 (or +15 vs a notorious leader) among Coalition members |
| Grand Roost | -10 if you voted against them (decays) |

Non-war components decay 1 point/turn toward their steady value (The Neighbor's grudges decay at half rate).

### 12.2 Treaties and exchanges [MVP]

- **Non-Aggression Pact** (relation >= 0; territorial rule applies): breaking it = backstab.
- **Trade Agreement** (>= 10): each side gains `min(pop_A, pop_B) / 4` credits/turn, ramping 20% → 100% over 10 turns. fantastic_traders x2.
- **Research Agreement** (>= 20; never with a distrusted empire): each side gains 10% of the other's RP.
- **Alliance** (>= 50): shared vision, fuel range from ally colonies, AI ally joins your wars if it can.
- **Peace**: 15-turn truce.
- **Exchanges**: tech for tech, tech for credits, credit gifts, **demands** (tribute), and **Grand Roost pledges** ("vote for X at the next session"; AI price ≈ 10 credits per vote it holds, adjusted by relation). Exodus keys are never on the table.
- **Declare war** any time (repulsive: only Peace and War exist).
- AI accepts if `value_to_AI(deal) + relation/2 + personality_bias >= 0`, and the screen shows its reasons. [COPY: diplo.reason.*]

### 12.3 The Grand Roost [MVP]

- Convenes at the first-session turn (§2.1) and then every interval, if at least 3 empires live and the player has met at least one. Announced 5 turns ahead (`Called to the Grand Roost` event can pull it in, §20). [COPY: council.name]
- **Votes** = total whole pop units (charismatic: candidates you vote for get +10% of your votes).
- **Candidates**: the two empires with the most votes. Every empire votes A, B or **Abstain**; candidates vote for themselves; AIs follow pledges, else vote for the candidate with the higher relation if >= -20, else abstain. [COPY: council.abstain_tip]
- A candidate with **>= 2/3 of all votes cast or abstained** becomes **Supreme Bird**. [COPY: council.title, notify.elected]
- Player elected: **Grand Roost victory**. AI elected: the player chooses **Accept** (defeat) or **Defy** (the Grand Roost dissolves forever; every empire that voted for the winner declares war on the player). The player votes at the **start** of the session turn. (Bible: needs Hyper-Preened Mandate and a T120 floor — rejected with Roost Law; §21.)

### 12.4 The Coalition [MVP] (meme bible idea 8 + event 1)

- **Scored power** = Score (§14). When an empire's score is >= **35%** of the sum of all living empires' scores (>= **30%** if notorious), every other empire joins a **Coalition** against it: +10 relation with each other (+15 vs notorious), a **casus belli** (declaring war on the leader is never a backstab), and AI war ratios vs the leader x0.8.
- Ends when the leader falls under 30% (25% if notorious). The modifier is labelled **Tier List** when the leader is Swans, **Snowball** otherwise. The first time it trips in a game, the **"The Tier List Leaks"** PNN bulletin fires (§20 event 1). [COPY: coalition.*]
- Both the player and AIs can be the leader; the player can be a Coalition member.

---

## 13. AI

### 13.1 Fairness contract and difficulty [MVP]

- The AI plans from its own fog-of-war knowledge. **Its only advantages are the ones printed on the difficulty card** (meme bible idea 9: "cheats with their names on them"), shown on the setup screen and in each AI's diplomacy tooltip. It issues orders through the same command API as the player.

| Difficulty | AI industry | AI research | AI growth | Declared extras | Behaviour |
|---|---|---|---|---|---|
| **Nestling** | -25% | -25% | 0 | — | War threshold x2; never targets the player first |
| **Flighted** (default; soak baseline) | 0 | 0 | 0 | — | — |
| **Honk Admiral** | +20% | +20% | 0 | Knows every player ship design | War threshold x0.8 |
| **Lights-Off Ledger** | +40% | +40% | +20% | Knows player designs; sees all player colonies and fleets | War threshold x0.7 |

[COPY: difficulty.<id>.name, difficulty.<id>.tip]

### 13.2 Personalities [MVP] — the meme bible's eight

Weights (0-10) the planners read, plus each personality's special rules. A custom race picks one.

| Personality (race) | Exp | Mil | Aggr | Res | Dipl | Spy | Def | Special rules |
|---|---|---|---|---|---|---|---|---|
| **The Unbothered** (Swans) | 6 | 7 | 5 | 8 | 4 | 3 | 5 | War ratio 2.0 ("declares war when the math is already unkind"); never declares on an empire already at war with someone else (no dogpiling); accepts tribute; prioritises Exodus |
| **The Sportsman** (Pheasants) | 6 | 8 | 7 | 4 | 5 | 2 | 4 | Targets the score leader, not the weakest; never backstabs: cancels a treaty, waits 5 turns, then declares; re-declares on the empire that beat it when a truce expires if ratio >= 1.0 |
| **The Dealmaker** (Ducks) | 7 | 4 | 3 | 5 | 9 | 3 | 4 | Proposes treaties from first contact; sells any tech except its 2 newest; gifts credits to the leader's enemies; declares war only below -50 relation or when attacked; Grand Roost candidate |
| **The Librarian** (Owls) | 5 | 4 | 3 | 10 | 7 | 3 | 6 | No war declarations before T80; sells techs older than its 3 newest; when attacked, refuses peace for 20 turns and adds +25% military share |
| **The Patient Rock** (Penguins) | 8 | 5 | 2 | 5 | 5 | 2 | 8 | Hostile/cold worlds weighted x2 in expansion; accepts peace once no enemy fleet is in its systems; any system it ever owned is a permanent war target |
| **The Borrower** (Crows) | 6 | 5 | 6 | 6 | 3 | 10 | 4 | Max spy funding on all rivals; gifts stolen techs to the victim's enemies (+favour); caught-spy grudges decay at half rate |
| **The Neighbor** (Geese) | 6 | 8 | 8 | 3 | 3 | 2 | 6 | Targets its nearest neighbour from T30; grudges decay at half rate; accepts capitulation and peace cleanly; logs "Honk." when a foreign fleet enters a system within 6 pc of its colonies (once per fleet) |
| **The Floor** (Chickens) | 7 | 9 | 4 | 4 | 4 | 2 | 6 | No war before T60; military share +10%; strike threshold 1.3, keeps attacking while ahead; enemies of the Floor capitulate at < 35% power instead of 25% (the bible's vassalage offer) |

[COPY: personality.<id>.name; diplo.<race>.greeting/threat/peace/war/defeat and taunt.<race>.* are the bible's lines]

### 13.3 Planning loop (each AI turn, fixed order, deterministic)

1. **Assess**: power per known empire (`fleet power = (sum over ships of sqrt(dps_vs_their_shield * hp))^2`, Lanchester); threat per own colony = enemy power within 3 turns; posture Peace / Tension / War / Losing; Coalition status.
2. **Research**: score frontier options by personality weight x need (hostile-only targets → Habitat Domes; enemy shields seen → next weapon; war → computers/armor; capped range → Flightcraft). Queue 2 nodes ahead.
3. **Designs**: auto-design on new parts; obsolete superseded.
4. **Colonies**: presets by role score.
5. **Expansion**: planet score `max_pop*10 + mineral*8 + special - distance_turns*5`; colony/outpost ship target count `min(targets in range, 2 + expansion/3)` minus en route.
6. **Military**: military PP share `15% + military*3%` (+25% at War, +15% threatened). Fleets: Defend / Strike (gather at staging, launch when `strike_power >= 1.5 x known defense`; personality overrides) / Invade (`marines >= 1.3 x defenders`) / Reserve.
7. **War and peace**: declare when `relation < -20 or aggression >= 7`, ratio >= war_ratio(personality, difficulty, Coalition), a reachable target exists, and the personality's rules allow. Seek peace at ratio < 0.7, 20 turns without battle, or a second front. Capitulate when hopeless (§14).
8. **Diplomacy**: NAPs with non-targets; trade/research by threshold; pledges; tribute demands when ratio >= 2 and aggression >= 7.
9. **Production**: queue top-ups to desired composition (PD escorts when enemy Horizon seen, troop ships for planned invasions).
10. **Espionage**: fund vs the tech leader (Borrower: all).

Budget: < 50 ms native / < 150 ms web per empire per late-game turn (ARCHITECTURE §10).

---

## 14. Victory and defeat

| Victory | Rule | MVP |
|---|---|---|
| **Conquest** | Every other empire eliminated (no colonies) or capitulated to you | MVP |
| **Grand Roost** | Elected Supreme Bird by >= 2/3 of votes (§12.3) | MVP |
| **Exodus** | Know **Hyper-Preened Kinematics** and **Hyper-Preened Genesis**, have every field at >= T7, then complete the **Departure Roost** (3000 PP) at your capital. Starting it is announced to all: every AI gets -30 relation toward you and its war planner may target your capital. (Bible: two keys only; raised so a two-field beeline can't end the game by ~T120. §21) | MVP |
| **Called Game** | Highest score at the turn cap | MVP |
| The Big Quiet | End-game crisis: from ~T170, if no victory is within 25 turns (victory clock), **Tall Shapes** arms a 40-turn clock; **The Antherons** arrive at the score leader's border; defeating their fleet is a victory; losing your homeworld to them is a defeat | STRETCH |

**Victory clock** [MVP-lite] (meme bible idea 2): the score screen lists, per empire, progress toward each victory (Grand Roost vote share vs 2/3; Exodus keys/tiers/PP; rivals remaining). [STRETCH: estimated turn.] [COPY: ui.victory_clock.*]

**Capitulation** [MVP]: an AI empire at war that has lost its capital, holds <= 3 colonies, and whose power is < 25% (35% vs The Floor) of its strongest enemy's offers surrender. Accepted → its colonies and ships transfer and it is eliminated. AI-to-AI is automatic; the player chooses; the player never auto-capitulates.

**One More Turn** [MVP]: the victory screen offers *One More Turn* (keep playing; no further victory checks) beside *Quit*. [COPY: menu.quit_confirm, victory.one_more_turn]

**Defeat**: no colonies left; Accepting another Supreme Bird; another empire wins.

**Score** = pop units + 2 x colonies + 2 x techs + fleet PP value / 50 + 20 if you hold your capital + 30 if you hold Orn.

Victory/defeat texts and race banners are the bible's (§6 there). [COPY: victory.<id>.*, defeat.<id>.*, victory.banner.<race>]

---

## 15. Presentation

### 15.1 Screens [MVP]

Main Menu · New Game (size preset with **Evening Standard** default, opponents, difficulty, race premade/custom, **Seat the Swans**, events/monsters/Grand Roost toggles, shareable seed string) · Race Designer · Galaxy Map · Colony panel · **Colonies list** (sortable; bulk preset/template) · Research · Ship Designer · Fleets list · Diplomacy · Grand Roost · Turn Summary · Battle Viewer · Settings · Save/Load · Avipedia (in-game reference generated from data, including the event table: bible idea 10) · Victory/Defeat.

### 15.2 Notifications, PNN and the turn summary [MVP]

Turn Summary at the start of each turn, grouped and filterable: Research, Production, Colonies, Military (battles with Replay and the autopsy line, invasions, enemy fleets sighted with ETA), Diplomacy, Grand Roost, Events, **Governor log** (every 10 turns). Every row has "Go to"; decision rows are pinned. Flavour notifications (scout-only war declaration, Swans leading 10 turns, first contact with Swans, tech done) fire on the simple triggers listed in `COPY_PLAN.md` §J. **PNN** (Perch News Network) is the category and map ticker for galaxy-wide news the player can see: wars between others, Grand Roost results, Guardian killed, Coalition formed, Exodus started. [COPY: news.pnn.ident, news.<kind>]

### 15.3 Tooltips [MVP]

Every number has a breakdown tooltip generated by the modifier engine. Every part, building, tech, trait and event has a stats tooltip generated from data plus its copy line. Hovering a fleet shows ETA and estimated odds vs what is visible at its destination.

### 15.4 Visual direction and VFX rules [MVP]

- All art drawn in Godot from shapes. Birds are silhouettes from a few polygons, one family per empire (swan, pheasant, duck, owl, penguin, crow, goose, chicken), tinted by empire color.
- Stars: shaded discs with radial glow plus a 4-6 spike diffraction cross; planets are shaded circles with a terminator.
- **No ring/doughnut base shapes for effects.** Talons: tapered strokes with bright core and fading tail; Beaks: short streaks; Horizon: dart polygons with particle trails; hits: spark streaks along the impact direction plus tumbling feather polygons; ship death: directional debris shards + feathers + short flash; shields: brief faceted noisy arc segment facing the shot, never a full circle. Explosions may be round.
- Range and selection markers are UI, not effects.
- Projectiles tinted by empire; damage numbers white with dark outline; reduce-motion halves particles and disables shake.

### 15.5 Hotkeys [MVP] (browser-safe: no F-keys, no Ctrl+S/W/T/N/R)

| Key | Action |
|---|---|
| Enter / Space | End turn (Space only when no text field has focus) |
| Esc | Close panel / open menu |
| G / C / R / D / F / P / U / T | Galaxy / Colonies list / Research / Designer / Fleets / Diplomacy / Grand Roost / Turn summary |
| N | Next item needing attention |
| Tab / Shift+Tab | Next / previous colony |
| Home | Centre on capital |
| WASD / arrows, wheel, middle-drag | Pan / zoom |
| 1-5 | Map overlays: ownership, minerals, habitability for my species, fuel range, threats |
| Ctrl+Z / Ctrl+Y | Undo / redo (current turn's orders) |
| Q / L | Quick save / quick load (confirm) |
| H or ? | Help / hotkey sheet |
| Battle viewer: Space / 1-3 / S | Pause / speed / skip |

---

## 16. Accessibility and settings [MVP]

- **Empire colors**: Okabe-Ito palette (§4.2) + per-empire glyph wherever color identifies an owner. "High contrast" option thickens outlines.
- **Font**: the plan is **Godot's built-in default font** (no downloaded font ships). Optional owner-supplied swap: Atkinson Hyperlegible (OFL), only after owner approval; the theme reads the font from one place so the swap is one file. Minimum 14 px at 100% scale.
- **UI scale** 75%-200% in 25% steps. **Reduce motion**; battle speed default; all info in tooltips and lists, not only on the map.
- Audio: Master / Music / SFX / UI sliders; mute on focus loss (web).
- Save/load: manual slots, autosave every turn (rolling 3), quicksave, browser-safe `user://`. [STRETCH: web save export/import.]

---

## 17. Balance tables and soak targets

### 17.1 Key formulas (index)

| Quantity | Formula | § |
|---|---|---|
| Max pop | size x pop/size + bonuses (floors before caps) | 3.4, 4.1 |
| Growth | `(P*(M-P)/M*10/100 + 50) * (100+g)/100` milli | 5.2 |
| Food | farmers x farm - pop; deficit imported 2 cr/food | 5.3 |
| Industry | `(workers x pp + flat) x (100+pct)/100` | 5.4 |
| Research cost | `20 x tier^2`; unchosen option x1.5 | 6.2 |
| Miniaturisation | `max(50, 100 - 10 x tiers above)%` | 7.2 |
| To-hit | `clamp(60 + acc - eva - Beak 6xD, 5, 95)` | 9.3 |
| Damage | `max(0, raw x band/trait pct x falloff - shield)` | 9.3 |
| Battle line | 8 slots (Titan 2; Geese 10) | 9.2 |
| Ground duel | `p = s_a/(s_a+s_d)` | 10 |
| Spy threshold | `30 + 3 x techs lacked (cap 20)` | 11 |
| Coalition | score >= 35% of total (30% notorious) | 12.4 |
| Grand Roost | 2/3 of votes = pop units | 12.3 |
| Rush buy | `2 x remaining (x2 if no progress)`; nothing_wasted 1.5x | 5.5 |
| Score | pop + 2 col + 2 tech + fleet/50 + 20 capital + 30 Orn | 14 |

### 17.2 Reference designs (start of game, for QA sanity)

| Design | Hull | Loadout | PP | HP | Exp. dmg/round at range 3 vs shield 0 / 2 |
|---|---|---|---|---|---|
| Corvette | small | Nuclear drive (4), 4 Lasers (20) | 21 | 20 | ~8.1 / ~4.5 (vs small, 45% hit) |
| Destroyer | medium | Nuclear (9), 10 Lasers (50) | 55 | 60 | ~25 / ~14 (vs medium, 55%) |
| Horizon Boat | medium | Nuclear (9), 8 Nuclear Missiles (48) | 57 | 60 | ~43 / ~33 for 4 salvos (vs medium, no ECM, 68%) |
| Colony Ship | medium | Nuclear (9), Colony Pod (40) | 65 | 60 | — |
| Outpost Ship | small | Nuclear (4), Outpost Pod (12) | 27 | 20 | — |
| Troop Ship | medium | Nuclear (9), 2 Troop Pods (40) = 8 marines | 45 | 60 | — |

Hull PP = hull + engine (10% of hull PP, rounded up) + parts. Intended reads: Talons lose ~45% of their value to the first shield and ~75-80% to class 4; Horizon out-damages Talons for 4 rounds unless PD/ECM answer; a 2-vs-2 Destroyer fight resolves in 3-5 rounds. Pheasant Destroyer (talon_adepts +25% damage, +20 acc: 55% → 75% to-hit) ≈ +70% damage vs the baseline.

### 17.3 Soak balance targets (`tools/soak`, >= 40 seeds, 4 AIs, Evening Standard, Flighted) [gate for Phase 8]

| Metric | Target |
|---|---|
| Games ending by victory before cap | >= 90% |
| Median end turn | 140-220 |
| Swans win rate | 35-50% |
| Any other empire's win rate | >= 8% |
| Victory types | Conquest >= 30%, Grand Roost >= 10%, Exodus >= 5% of games |
| Coalition trips | in >= 50% of games; against Swans in >= 60% of games where Swans live past T100 |
| Median colonies per surviving empire at T80 | 6-10 (Penguins may exceed) |
| Median techs known at T100 | 20-30 |
| Games with an AI starving > 10 turns | 0 |

---

## 18. Modern QoL vs MoO pain points [MVP unless marked]

| MoO pain | Foul Fowl answer |
|---|---|
| Re-balancing jobs/sliders on every planet | Colony presets with empire-wide food balancing; bulk change from the colonies list |
| Empty build queues | Preset build lists + filler; Repeat and Count; queue templates |
| Food freighters (MoO2) | Pooled food, auto-import with credits |
| "Which planet needs me?" | Turn summary with Go-to; N = next item |
| Hidden arithmetic | Breakdown tooltip on every number |
| Governors you can't audit | Governor log every 10 turns (STRETCH: one free revert) |
| Scout micromanagement | Auto-explore; auto-colonise suggestions |
| New ships pile up | Rally points |
| Redesigning after each tech | Auto-design by role; upgrade queued designs |
| Watching every battle | Watch / big ones / never; replay; pause; outcome identical either way; autopsy names why |
| Doomstack collisions | Battle line with reserves; DOOMSTACK label so the joke survives |
| Mop-up slog | Capitulation; Coalition; Grand Roost every 25 turns; Called Game |
| "Who is about to win?" | Victory clock on the score screen |
| Misclick consequences | Undo/redo of the current turn's orders |
| Research prompt every few turns | Research queue with pre-chosen options |
| Unknown AI cheating | Difficulty cards print every AI advantage; AI uses fog of war |
| Events that feel like dice | Choice events show cost and prize before you commit; event table in the Avipedia |
| Saving | Autosave every turn, quicksave, browser-safe saves |
| Losing fleets to range math | Range fill on the map; illegal destinations refused with the reason |
| STRETCH: refit, sabotage, star gates, terraforming, mixed-species colonies, The Big Quiet, The Moulted, Medium/Large galaxies, web save import/export, key rebinding, local Feats (the bible's achievements), abandon colony |

---

## 19. Open questions for the red team

1. Free movement + fuel range vs star lanes (the meme bible assumed lanes): with the battle line, is free movement now right?
2. Watch-only battles with doctrine as the only lever: enough agency?
3. "Core + choose one" with unchosen options at 150%: too generous (guts Creative and Crows) or still too punishing?
4. Swans at 13 picks + notorious + Coalition at 30%: funny for an evening or frustrating? Is 35-50% the right target, and does the Coalition push it below?
5. Pooled food with credit import: deleting a decision or a chore?
6. Presets near-optimal = colonies not a decision?
7. Grand Roost: votes = raw pop, 2/3, Defy, pledges for sale. Too easy for Ducks (charismatic + Dealmaker)?
8. Does Capitulation + Coalition + Grand Roost + Exodus kill the T120-180 slog, or does the Coalition prolong it?
9. Combat depth: 1D track, single HP pool, simultaneous fire, 8 rounds, battle line 8. Enough for ship design to matter for 200 turns?
10. Battle line of 8 vs the bible's per-fleet cap of 6 with next-turn overflow: which kills doomstacks better without killing big battles?
11. Which 30% of the 48-node tree and parts list could be cut for MVP?
12. Can the AI win a war against a competent player at Flighted?

---

## 20. Random events [MVP unless marked]

Rules: from T20, each turn rolls once (keyed) with 4% for a **random-pool** event; **triggered** events fire on their condition (each at most once per game unless stated). Target empire weighted toward those meeting the condition; **lucky** empires are never the target of a negative event. Choice events show the cost and prize of each option before the player commits; AI choices follow personality. Every event has `event.<id>.title`, `.body`, and `.choice.<n>` copy keys; the meme bible's two sentences are the body.

| # | id | Source | Kind | Trigger / effect | Status |
|---|---|---|---|---|---|
| 1 | tier_list_leaks | Bible 1 | Triggered | First Coalition trip in the game: PNN bulletin; Coalition rules (§12.4) apply. Replaces the bible's separate +15/25-turn package | ADAPT, MVP |
| 2 | pond_scum_leviathan | Bible 2 | Random | Spawns a Leviathan (§9.8) in a random unowned system near the target. A scout ordered to *Tag* stays 3 turns there: the tagger's next Plumage tech -20% and the Leviathan leaves. Armed fleets fight it normally (no lanes to block) | ADAPT, MVP |
| 3 | guardian_of_orn | Bible 3 | Triggered | First time any empire explores Orn: reveal card + warning volley; Guardian-Marked rule (§9.8). Guardian exists from turn 1 at fixed strength (no 120% scaling) | ADAPT, MVP |
| 4 | tall_shapes | Bible 4 | Triggered | Arms The Big Quiet: 40-turn clock, Antherons at the score leader's border. Any empire may pay 2 turns of its RP to add 15 turns; buyable twice per galaxy | STRETCH |
| 5 | henhouse_war | Bible 5 | — | Two Moulted NPC empires, Titan loans, industry tithes | REJECT for MVP (needs NPC empires and loans); STRETCH with The Moulted |
| 6 | placid_until | Bible 6 | Triggered | First time anyone researches Heart of the Roost (Very Polite Warhead): the AI with the lowest aggression becomes **Placid, Until** (aggression +5, war ratio x0.7). If the player owns it: **Arm** (-20 relation with all, keep) or **Mothball** (part forbidden to you, +10 relation with all). The Gandhi nod | ADAPT, MVP |
| 7 | midgame_sit | Bible 7 | Triggered | First turn after T70 with nobody at war and no victory clock above 60%: **Rivalry** (name an empire: +10% industry 10 turns, -10 relation with them) or **Pull the Grand Roost** (next session in 5 turns). AI Geese/Pheasants pick Rivalry | ADOPT, MVP |
| 8 | while_you_were_away | Bible 8 | Periodic | = Governor log (§5.6); the revert | ADAPT: log MVP, revert STRETCH |
| 9 | letter_of_marque | Bible 9 | Random (choice) | Pay 150 credits: privateers cost a chosen rival 10 credits/turn for 12 turns; the victim learns it: -25 relation with them, +5 with their enemies. Decline: nothing | ADAPT (no fleet spawned), MVP |
| 10 | corner_colonist | Bible 10 | Random | The lowest-score empire's farthest colony gets 2 free buildings (first two of its preset list) and a free Scout. If that is the player: 1 free building | ADAPT ("rim" = farthest from its capital), MVP |
| 11 | snowball_named | Bible 11 | Triggered | Score leader keeps the lead 10 turns: leader +10% growth and credits for 15 turns (modifier named Snowball); every empire receives one bulletin of the leader's exact fleet and colony totals | ADOPT, MVP |
| 12 | perch_review | Bible 12 | Periodic, player only | Every 40 turns from T40: 5 stars if you won a battle at >= 2:1 PP exchange or completed a T7+ tech in the last 20 turns → +10% industry 20 turns; 2 stars if no tech and no building completed in 20 turns → -10% industry 10 turns and the summary highlights one idle colony; else 3 stars, no effect. (Bible "morale" → industry; no morale system) | ADAPT, MVP |
| 13 | pure_missile_honesty | Bible 13 | — | Extra Horizon slot | REJECT: designs are space-based, not slot-based, so an all-Horizon boat is already legal; the line becomes the Horizon Boat role tooltip |
| 14 | spreadsheet_you_wanted | Bible 14 | Random (choice) | **Adopt**: research -25% for 6 turns, then **Thesis Range** (Horizon +10 acc empire-wide, same as the CO6 option). **Shred**: +5% industry 8 turns | ADAPT, MVP |
| 15 | called_to_the_grand_roost | Bible 15 | Random | If >= 3 living empires have met: next Grand Roost in 8 turns. Pledges (§12.2) are the bribe; threats STRETCH | ADAPT, MVP |
| 16 | mineral_strike | Classic | Random (+) | A colony's minerals +1 step | MVP, COPY gap |
| 17 | derelict_hull | Classic | Random (+) | A free ship of your best warship design appears at a colony | MVP, COPY gap |
| 18 | data_moult | Classic | Random (-) | Research -50% for 3 turns (Universal Antidote does not help; Security Nest halves) | MVP, COPY gap |
| 19 | bountiful_season | Classic | Random (+) | One colony +50% food for 10 turns | MVP, COPY gap |
| 20 | feather_plague | Classic | Random (-) | One colony's growth stops for 10 turns (Universal Antidote immune) | MVP, COPY gap |

---

## 21. Meme-bible merge ledger

### 21.1 Design ideas

| # | Idea | Verdict | Reason / where |
|---|---|---|---|
| 1 | Colony grain: one focus, queue of 4, no jobs | ADAPT | The experience is delivered by presets (one click); jobs stay underneath for trait/planet legibility; no queue limit (Repeat/templates need length). §5.1 |
| 2 | Evening Standard with printed doors | ADAPT | Name adopted; kept 24 stars / 4 empires / cap 250 for session length; victory clock adopted (§14); Grand Roost from T50, not T120; crisis clock STRETCH |
| 3 | Three bands + autopsy | ADOPT (mostly) | Beak/Talon/Horizon = kinetic/beam/missile; autopsy, projectile cap and volley ticks adopted; 60-90 s battles rejected (8-10 s keeps the evening) §9 |
| 4 | Retreat with a receipt | ADOPT | Retreat always works at round 2, slowest ship pays. §9.6 |
| 5 | Fleet cap 6, overflow next turn | ADAPT | Battle line of 8 per party with reserves filling losses; Geese 10; Titan 2 slots; DOOMSTACK label at 8. §9.2 |
| 6 | Automation that accounts for itself | ADAPT | Governor log every 10 turns MVP; one free revert STRETCH; governors can't trade/declare/cancel victory. §5.6 |
| 7 | Trade with a memory | ADAPT | Exodus keys untradeable/unstealable; favours and grudges are relation lines; no separate "threat" stat. §12.1 |
| 8 | Coalition in the open | ADOPT | §12.4, with the Tier List / Snowball labels |
| 9 | Cheats with their names on them | ADOPT | Four named difficulties, every bonus and vision printed. §13.1 |
| 10 | Bills, not slot machines | ADOPT | Choice events show cost/prize; event table in the Avipedia. §20 |

Also rejected: the **Roost Law** field and **Hyper-Preened Mandate** gate (government is a trait; diplomacy/espionage/Grand Roost are not tech-gated; shields keep a field); **pollution**, **morale** and **vassalage** systems (not in this design; the Floor's vassalage offer maps to early capitulation); **lanes**-based strings (free movement).

### 21.2 Numbers changed from the meme bible (and why)

| Empire / item | Bible | Here | Why |
|---|---|---|---|
| Swans research | +25% | good_science (+1 RP/scientist ≈ +33%) | Traits are per-job yields, not percentages |
| Swans weapon damage | +15% all bands | ship_attack_+1 (+20 accuracy) | No all-band damage trait; accuracy is the system's attack stat |
| Swans OP | +1 movement, research costs -15% | fast_ships (+1 map and combat speed); cost cut dropped | The cost cut double-dipped on research; Swans are already at 13 picks |
| Swans relations | -40 all | notorious: -20 all, Coalition at 30% / +15 | -40 starts every AI below the war threshold on turn 1 and locks Swans out of the Grand Roost; the Coalition carries the social patch |
| Swans fill to 13 | — | + ship_defense_+1, ground_+1, rich + large homeworld | Bible's rich terran home; the rest spends Swan Privilege |
| Pheasants | +25% Talon, +20% round-1, +15% upkeep, Flush | talon_adepts, flush, high_upkeep exactly; + ship_attack_+1, good_industry to reach 10 | Kept the bible's numbers |
| Ducks trade | +30% trade credits | fantastic_traders (treaty income x2, Trade Goods 1:1) | Treaty income is small early; +30% would be invisible |
| Ducks growth | +15% | fast_growth +50% | Smallest growth step in the system |
| Ducks weapons | -20% damage all bands | ship_attack_-1 (-20 accuracy) | Same reason as Swans |
| Ducks Any Puddle | 50% habitability floor | any_puddle: habitable climates >= 3 pop/size | Habitability is pop/size here |
| Owls research | +40% | good_science (+33%) + night_hours (+20% at peace) | Per-job yields; Night Hours kept exactly |
| Owls factories | -25% | poor_industry (-1 PP/worker ≈ -33%) | Smallest negative step |
| Penguins | Piscivore (farms do nothing), +50% Ice/Tundra/Ocean, 25% cap on hot worlds, Huddle +30% def + 8% repair | piscivore fish table (hydroponics still works), tolerant floor (Tundra 2→3 = +50%), heat_intolerant (Desert/Arid/Inferno/Toxic capped 1/size), huddle +30% defense + full repair at own colonies | Hydroponics are the only food on hostile rocks; base repair is already 20%/turn so 8% would be invisible; Jungle (swamp) dropped from the cap because piscivore likes swamps |
| Crows spy | +50% success | spy_+1 (+20 score on a 50 base ≈ +40%) | Nearest step |
| Crows salvage | +20% | scavengers 20% exactly | — |
| Crows relations | -30, no research treaties, worse tech prices | distrusted exactly (+50% price) | — |
| Geese ground | +30% | ground_+1 (+25%) | Nearest step |
| Geese hulls | +15% HP | tough_hulls +15% | — |
| Geese fleet cap | 9 (base 6) | battle line 10 (base 8) | Fleet cap became the battle line |
| Chickens industry | +35% | good_industry (+33%) + unification (+25% food and industry) | The Pecking Order as a hierarchy; the stack is the Floor's identity |
| Chickens costs | -25% factory and shipyard | prefab_coops: all buildings -25% | Ships stay full price (unification + industry are enough) |
| Chickens One-Note | one option shown, -15% research | uncreative (one random option, siblings never offered) | -15% research dropped: uncreative is already -4 picks |
| Chickens Nothing Wasted | overflow carries in full | rush-buy 1.5x, never doubled | Full overflow is everyone's rule here |
| Difficulty Flighted | +10% AI industry | 0 | One bonus-free level is the honest default and the soak baseline |
| Difficulty Lights-Off Ledger | colony vision only (on top of Honk Admiral) | +40/+40/+20 + design and colony/fleet vision | The top level needs to be harder than the one below it |
| Exodus | 2 keys + Departure Roost | 2 keys + all fields >= T7 + Departure Roost | A two-field beeline reaches both keys by ~T120 |
| Guardian | 120% of strongest fleet | fixed 3000 HP | No rubber-banding; soak-measurable |
| Grand Roost | from T120, needs Mandate | from T50 every 25 turns, no tech | Roost Law rejected; early sessions rarely reach 2/3 but build the habit |
| Evening Standard | 32 stars, 6 empires, horizon T200 | 24 stars, 4 empires, cap 250 | Session length; brief's 150-250-turn target |
