# Foul Fowl: Fly, Flock, Forage, Fight — Game Design Document

Revision 4 (red team round 2), 2026-10-06. Status: BUILD (engineering plan: `docs/engineering/PLAN.md`). Companions: `ARCHITECTURE.md` (how it is built), `BRIEF.md` (why), `MEME_BIBLE.md` (voice, roster flavour), `COPY_PLAN.md` (every string), `redteam/` (findings; round 1 disposition in §22, round 2 in §23).

Conventions:
- **[MVP]** ships in the first public build. **[STRETCH]** only after a complete MVP evening repeatedly finishes in time. The full cut list is §18.
- **[COPY: key]** marks a player-facing string; `key` is its `data/copy/en.json` key (scheme in `COPY_PLAN.md`). Mechanics never depend on copy.
- **Source of truth.** Mechanics and numbers here win over every other design doc. §21 lists meme-bible numbers that were changed, §22-§23 the red-team dispositions.
- Every number is a starting value in `data/balance.json` or content JSON (ARCHITECTURE §5). §17 says what the soak can and cannot verify, and the human playtest gate for the rest.
- Mechanical identifiers (`snake_case`) are stable; display names are copy.

Shared vocabulary:

| Word | Means |
|---|---|
| **Beak** / **Talon** / **Horizon** | Kinetic (close) / beam (middle) / missile (any range) weapons |
| **Grand Roost**, **Supreme Bird** | The galactic council and its winner |
| **Hyper-Preened** | Label of research tiers 5-6 |
| **Evening Standard** | Default preset (§2) |
| **PNN** | Perch News Network, the galaxy ticker |
| **Orn**, **Guardian of Orn** | Core system and its guardian |
| **Coalition** (**Tier List** / **Snowball**) | The galaxy's coordinated response to a leader (§12.4) |
| **DOOMSTACK** | Cosmetic fleet-panel label for 8+ ships |
| **The Big Quiet**, **The Antherons**, **The Moulted** | STRETCH crisis and fallen-empire content |

---

## 1. Pillars

1. **A real MoO2-lineage 4X** with decisions at every scale: where to settle (and when not to), what each colony is for, which branch of each tier to own, what to build for the war you can see coming, and how each fleet fights the enemy in front of it.
2. **No 1993 pain.** Every chore has an automation that explains itself; every number has a breakdown; every turn opens on a summary that links to what needs you.
3. **One evening.** Evening Standard ends between turn 130 and 170 in a measured 75-110 minutes (§2.3). Hard cap turn 200.
4. **Asymmetry with numbers attached.** Eight bird empires from one public trait-point system. Swans are overpowered by a declared amount; the galaxy hunts them for it.
5. **Deterministic and testable.** Same seed + same orders = same game. The game runs headless, AI vs AI, to completion.

---

## 2. Session shape

### 2.1 Presets

| Preset | Stars | Empires | Map (pc) | Grand Roost (first non-binding / binding every) | Cap | Target end | Target wall clock |
|---|---|---|---|---|---|---|---|
| Tiny [MVP] | 16 | 3 | 34 x 24 | T40 / 20 | 140 | T90-120 | 40-60 min |
| **Evening Standard** [MVP] | 24 | 4 | 44 x 30 | T50 / 25 | 200 | T130-170 | 75-110 min |
| Medium, Large [STRETCH] | 36 / 54 | 6 / 8 | — | — | 250 / 300 | — | 2-4 h |

**Evening Standard seating** [MVP]: the three AI seats are Swans, one early-war empire (Geese or Pheasants) and one schemer (Crows or Ducks), seeded; if the player takes one of those, the slot refills from the rest. The card says so. [COPY: menu.preset.evening_standard.seats] Custom lobbies pick freely (the Midgame Sit event is their failsafe).

### 2.2 Arc (design target, measured by soak and playtests)

| Turns | Phase | Player activity |
|---|---|---|
| 1-35 | Explore / Expand | Auto-explore; first Nest Ship lands ~T6; each further colony costs a pop and upkeep, so settle-vs-grow is a choice; outposts stake range |
| 35-80 | Expand / Exploit | 5-9 colonies; specialisations chosen; Dome Perches opens hostile rocks; first border war (the seated early-war AI); Grand Roost publishes its first count at T50 |
| 80-130 | Exploit / Exterminate | Herons/Albatrosses; invasions; Guardian falls to someone; Coalition forms against the leader and attacks it |
| 130-170 | Endgame | Binding Grand Roost sessions, Exodus race, capitulations end wars |
| 200 | Called Game | Score winner; the soak's termination guarantee |

### 2.3 Session-length arithmetic

Measured human decision time is the budget, not an estimate of it. Targets per turn band, Evening Standard:

| Turns | Decision time / turn | Subtotal |
|---|---|---|
| 1-40 | 10 s | 6.7 min |
| 41-80 | 25 s | 16.7 min |
| 81-120 | 35 s | 23.3 min |
| 121-150 | 45 s | 22.5 min |
| Battle Orders stops (at most 1 per turn, ≤ 3 cards each; ~25 stops x 15 s) + watched replays (~20 x 8 s) | | 9 min |
| End-turn processing (150 x ≤ 0.6 s) | | 1.5 min |
| **Total at a T150 ending** | | **≈ 80 min** |
| Each extra turn past 150 | 45 s | +0.75 min/turn → cap T200 ≈ 118 min |

Levers that hold these numbers: fewer research prompts (36 nodes, queue), presets and specialisations, Battle Orders only for big battles by default, N = next decision. The playtest gate (§17.4) measures them; if a band overruns by > 25%, the fix is a design cut, not a lower cap.

---

## 3. Galaxy generation

### 3.1 DECISION: free movement with fuel range (MoO1/MoO2), no star lanes

Range tech is the expansion lever, outposts stake range, travel is `ceil(distance / speed)`, combat only at stars. Mitigations for the doomstack: the battle line (§9.3), Swat/Miss-Field counters, blockade and outpost razing (risk at the frontier), one wormhole corridor. Kept by both red teams.

### 3.2 Star placement

1. Seeded Poisson-disk sampling (min separation 4.5 pc, 30 attempts; relax 5% if short).
2. **Orn**: star nearest the centre; Guardian of Orn (§9.8); Huge Garden Ultra-Rich planet. [COPY: place.orn.name]
3. **Homeworlds**: farthest-point selection among stars ≥ 12 pc from Orn; ties by id.
4. **Race-aware fair start**: within 9 pc of each homeworld, exactly 2 planets good for that species (max pop ≥ 8 at Medium) and 1 outpost target are guaranteed; the generator converts orbits deterministically to meet it. Beyond 9 pc, **habitable (non-hostile) planets are ~30% of orbits**: the good worlds in the middle are contested.
5. **Wormhole** [MVP]: 1 pair (Standard; 0 on Tiny), ≥ 60% map width apart, 1-turn travel, ignores range.
6. **Monsters** [MVP]: Guardian at Orn; 2 Pond-Scum Leviathans on the richest non-homeworld systems ≥ 10 pc from any homeworld.
7. Nebulae: [STRETCH].

### 3.3 Star types

| Star | Weight | Orbits | Habitable bias | Mineral bias |
|---|---|---|---|---|
| Yellow | 30 | 2-5 | Temperate, Ocean, Arid | Abundant |
| Orange | 20 | 2-4 | Arid, Desert, Ice, Jungle | Abundant/Poor |
| Red | 25 | 1-4 | Ice, Bare, Ocean | Poor |
| White | 12 | 2-4 | Bare, Cinder, Temperate | Rich |
| Blue | 8 | 1-3 | Cinder, Sour, Crackle, Bare | Rich/Ultra Rich |
| Neutron (Neutron Clock) | 5 | 1-3 | Crackle, Bare, Sour | Ultra Rich |

25% of orbits are Asteroids or Gas Giants (outposts only).

### 3.4 Planets

Display names from Grok's copy (`climate.<id>.name`); ids unchanged.

| id (display) | pop/size | farm | fish (piscivore) | Class |
|---|---|---|---|---|
| gaia (Garden) | 5 | 3 | 2 | Habitable |
| terran (Temperate) | 4 | 2 | 1 | Habitable |
| ocean (Ocean) | 4 | 2 | 3 | Habitable |
| swamp (Jungle) | 3 | 2 | 2 | Habitable |
| arid (Arid) | 3 | 1 | 0 | Habitable |
| tundra (Ice) | 2 | 1 | 2 | Habitable |
| desert (Desert) | 2 | 1 | 0 | Habitable |
| barren (Bare) | 1 | 0 | 0 | Hostile (Dome Perches, PL2) |
| inferno (Cinder) | 1 | 0 | 0 | Hostile (PL2) |
| toxic (Sour) | 1 | 0 | 0 | Hostile (PL2) |
| radiated (Crackle) | 1 | 0 | 0 | Hostile (Crackle Shutters, PL4 option) |
| asteroids / gas_giant | — | — | — | Outpost only |

**Size**: Tiny 1, Small 2, Medium 3, Large 4, Huge 5 (10/25/35/20/10%). **Max pop** = size x pop/size + bonuses. **Minerals** → PP per worker: Ultra Poor 1, Poor 2, Abundant 3, Rich 4, Ultra Rich 6. **Gravity** derived (Tiny/Small Low unless Rich+; Large Heavy if Rich+; Huge Heavy): -25% all job output per step of mismatch; Gravity Manners removes it.

**Yield precedence** (one rule, shown in the tooltip): (1) base table (farm, or fish for piscivore) → (2) floors (tolerant pop floor; the tolerant food floor does not apply to piscivore species) → (3) adds (traits, buildings, specials) → (4) caps (heat_intolerant) → (5) percentages (gravity, specialisation, government, empire, supply lines) → floor to int.

**Specials** (1 in 8 planets) [MVP]: Old Nest (first colonist gains 1 low tech), Pretty Rocks (+5 cr), Rude Wealth (+10 cr), Kind Soil (+1 food/farmer), Spare Nest (starts at pop 2), Yard Scrap (ships built here -20%). [STRETCH: Sitting Tenants natives.] [COPY: special.<id>.*]

---

## 4. Empires and races

### 4.1 Trait-point system

Budget 10 picks (negatives refund, cap -10; one per group; Specials pick-any). The **Race Designer screen is STRETCH**; the system defines the eight premades and is shown on each race card. [COPY: trait.<id>.name/tip — Grok Part B]

| Group | id | Cost | Effect |
|---|---|---|---|
| Growth | slow_growth / fast_growth / prolific | -4 / +3 / +6 | Growth -50% / +50% / +100% |
| Farming | poor_farmers / good_farmers / great_farmers | -3 / +3 / +6 | -1 / +1 / +2 food per farmer |
| Industry | poor_industry / good_industry / great_industry | -3 / +3 / +6 | -1 / +1 / +2 PP per worker (min 1) |
| Science | poor_science / good_science / great_science | -3 / +3 / +6 | -1 / +1 / +2 RP per scientist (min 1) |
| Credits | poor_taxes / rich_taxes | -3 / +4 | Taxes -50% / +50% |
| Ship attack | ship_attack_-1 / _+1 / _+2 | -2 / +2 / +4 | Accuracy -20 / +20 / +40 |
| Ship defense | ship_defense_-1 / _+1 / _+2 | -2 / +3 / +6 | Evasion -20 / +25 / +50 |
| Ground | ground_-1 / _+1 / _+2 | -2 / +2 / +4 | Troops -25% / +25% / +50% |
| Spying | spy_-1 / _+1 / _+2 | -3 / +3 / +6 | Spy score -20 / +20 / +40 |
| Weapon band | talon_adepts / beak_adepts / horizon_adepts | +3 each | That band's damage +25% |
| Government | feudal / dictatorship / democracy / unification | -4 / 0 / +7 / +6 | Ships -33% and research -25% / — / research +20%, taxes +50%, enemy spies +20 / food and industry +25%, no occupation, taxes -25% |
| Specials | aquatic | +5 | Ocean/Jungle/Temperate: +1 pop/size and +1 food/farmer |
| | any_puddle | +4 | Habitable climates ≥ 3 pop/size |
| | subterranean | +5 | +1 pop/size; ground defense +25% |
| | tolerant | +8 | Every climate ≥ 3 pop/size; hostile needs no tech; farmers ≥ 1 food (not for piscivore) |
| | piscivore | 0 | Farmers use the fish table; Feed Hall is called Fishery |
| | heat_intolerant | -3 | Desert, Arid, Cinder, Sour capped at 1 pop/size (after floors) |
| | low_g / high_g | -4 / +5 | Gravity comfort |
| | large_homeworld / rich_homeworld / poor_homeworld / artifact_homeworld | +1 / +2 / -1 / +3 | |
| | creative ("Wide-Eyed") | +6 | Completing a node grants both options at once (no second prompt), including the final Hyper-Preened forks (§6.1) |
| | uncreative ("One-Note") | -4 | You choose one option per tier; the other is never researchable (trade or theft still fetch it) |
| | night_hours | +2 | Research +20% while at peace with every empire met |
| | charismatic | +3 | +20 relations; a Grand Roost candidate you vote for, **other than yourself**, gains 10% of your votes |
| | repulsive / notorious / distrusted | -6 / -3 / -4 | See §12.1; notorious also lowers the Coalition trip to 30% |
| | territorial ("Airspace") | -3 | -1 relation/turn with each empire with a colony within 6 pc and no treaty (floor -60); a NAP needs a won battle or tribute |
| | fantastic_traders | +4 | Trade treaty income x2; Trade Goods 1:1 |
| | lucky | +3 | Never targeted by negative events |
| | omniscient | +3 | See every star's planets and every fleet |
| | informants | +3 | See every met empire's treasury, treaties and ship designs |
| | stealthy_ships | +4 | Enemy scan range vs your fleets halved |
| | warlord | +4 | Ship upkeep -50%; new ships Veteran (+10 acc) |
| | high_upkeep | -1 | Ship upkeep +15% |
| | fast_ships | +3 | +1 map and combat speed |
| | tough_hulls | +3 | Ship HP +15% |
| | v_formation | +4 | +5% damage per armed line ship of the line's **plurality band**, after the first, max +25%; applies to that band only |
| | flush | +3 | Attacking (your fleet arrived this turn): round-1 damage +20%; first battle of each war: enemy retreat +1 round |
| | huddle | +3 | Colony defense HP +30%; ships repair fully at any own colony system |
| | scavengers | +2 | Holding the field: 20% of wrecks' PP as credits; 20% per destroyed design to learn one of its part techs |
| | cache | +4 | Every 12 turns: copy one *seen* tech at 50% of its tier cost (not Exodus keys) |
| | prefab_coops | +3 | Buildings -25% PP |
| | nothing_wasted | +2 | Rush-buy 1.5x remaining, never doubled |

**Species traits** (Growth, Farming, Industry, Science, Ground, aquatic, any_puddle, subterranean, tolerant, piscivore, heat_intolerant, gravity) follow each colony's population; all others are empire-wide.

### 4.2 The eight premade empires [MVP; the phase plan builds 4 first]

| Empire | Leader | Picks | Traits | Homeworld | AI personality | Color / glyph |
|---|---|---|---|---|---|---|
| **The Pale Supremacy** (Swans) | Cob-Empress Cygnara the Unbothered | **13** | good_science, ship_attack_+1, ship_defense_+1, fast_ships, ground_+1, rich_homeworld, large_homeworld, notorious | Large Temperate, Rich | The Unbothered | White #F5F5F5 / crown |
| **The Ringneck Warrant** (Pheasants) | High Cockade Vesper Goldtail | 10 | talon_adepts, flush, ship_attack_+1, good_industry, high_upkeep | Medium Temperate | The Sportsman | Vermillion #D55E00 / triangle |
| **The Dabble League** (Ducks) | First Mallard Deb Quill | 10 | fantastic_traders, any_puddle, fast_growth, charismatic, ship_attack_-1, ground_-1 | Medium Ocean | The Dealmaker | Bluish green #009E73 / circle |
| **The Night Parliament** (Owls) | Arch-Dean Athene Stillbranch | 10 | creative, good_science, night_hours, ship_attack_+1, poor_industry | Medium Temperate | The Librarian | Yellow #F0E442 / diamond |
| **The Pebble Throne** (Penguins) | Pebble-King Pebble XIV | 10 | tolerant, piscivore, huddle, good_industry, ground_+1, large_homeworld, heat_intolerant, slow_growth | Large Ice | The Patient Rock | Sky blue #56B4E9 / square |
| **The Open Murder** (Crows) | Keeper of the Cache, Kestra Nightcache | 10 | spy_+1, cache, scavengers, stealthy_ships, informants, distrusted, ground_-1 | Medium Arid | The Borrower | Reddish purple #CC79A7 / cross |
| **The Marked Airspace** (Geese) | Grand Honk Brenda Ironwing | 10 | v_formation, tough_hulls, ground_+1, ship_attack_+1, rich_homeworld, territorial | Medium Temperate, Rich | The Neighbor | Orange #E69F00 / chevron |
| **The Pecking Order** (Chickens) | Prime Rooster Cluckett of the Ninth | 10 | unification, good_industry, prefab_coops, nothing_wasted, uncreative | Medium Temperate | The Floor | Blue #0072B2 / comb |

Pick sums: Swans 3+2+3+3+2+2+1-3 = 13; Pheasants 3+3+2+3-1 = 10; Ducks 4+4+3+3-2-2 = 10; Owls 6+3+2+2-3 = 10 (revision 4: Wide-Eyed repriced from 8 to 6; the freed 2 buy Mean Aim, so the few ships a thin-factory library builds hit what the library told them to); Penguins 8+0+3+3+2+1-3-4 = 10; Crows 3+4+2+4+3-4-2 = 10; Geese 4+3+2+2+2-3 = 10; Chickens 6+3+3+2-4 = 10. Penguin food uses the fish table with no tolerant food floor, and the heat cap applies after the pop floor (§3.4). Crows get informants instead of omniscient: the spy empire still has to explore.

### 4.3 Swans OP [MVP]

13 picks ("Swan Privilege", printed), the gold "Swans OP" signature line, and the printed patch: **"They get hunted. That is the patch."** [COPY: race.swans.patch_line]. The hunt is mechanical (Coalition, §12.4). Seat the Swans is ON by default. Target: Swans' conditional win rate 40% ± 5 (§17.2). No picks are taken off the card.

### 4.4 Starting state

Homeworld 8 pop; Grand Nest (+3 food, +5 PP, +3 RP, +5 cr, +2 scan, counts as a Yard), The Yard, Boot Barracks. Ships: 2 Glances (scouts), 1 Nest Ship, 2 Sparrow corvettes (4 Wick Talons each). Credits 100. Known: Wick Talon, Bomb Bay, Walk Drive, Pinfeather Plate, Sparrow and Kestrel hulls, Nest/Perch/Boot/Glance Pods. **No Horizon weapon at start**, so the starter kit does not contain the winning band.

Opening check: 3 farmers x 2 + 3 = 9 food (8 eaten); 3 workers x 3 + 5 = 14 PP; 2 scientists x 3 + 3 = 9 RP; 8 + 5 = 13 credits - upkeep 4 = +9.

---

## 5. Colonies and economy

### 5.1 DECISION: integer pop on three jobs, automated by presets, shaped by a specialisation

Jobs keep every number legible; presets remove the chore; the **specialisation** is the colony decision, with an opportunity cost (red team: presets alone were the last decision).

### 5.2 Growth

```
growth_milli = ( P*(M-P)/M * 10/100 + 50 ) * (100 + growth_pct) / 100     (P, M in milli; P < M)
```
New colony 1/12: 141/turn; full in ~48 turns unbonused. Housing: 1 PP = 20 milli.

### 5.3 Food (pooled)

Each pop eats 1. Food is summed empire-wide. **Surplus sells at 2 food = 1 credit** (red team: at 1:1, farms were a mint). Deficits auto-import at 2 credits/food; if the import cannot be paid, the most-populous colony loses 1 pop per 5 unpaid food.

### 5.4 Yields

`food = farmers x farm + flat`; `industry = (workers x pp + flat) x (100+pct)/100`; `research = (scientists x rp + flat) x (100+pct)/100`; `taxes = pop x 1 x (100+pct)/100`. Order per §3.4. Occupied colonies: -50% for 10 turns. **Long supply lines**: colonies more than 15 pc from the Grand Nest lose 10% of industry, research and taxes per 5 pc beyond (max -30%). **Food is exempt** (revision 4): food is already the pooled constraint, and a farm-2 frontier world at -20% food would only feed itself.

### 5.5 Expansion costs (red team: expansion must be a decision)

- **A Nest Pod drains 1 pop** from the colony that builds it (needs pop ≥ 3 at completion; waits otherwise). The starting Nest Ship is free.
- **Colony administration**: 1 credit/turn per colony beyond the capital; colonies beyond the 8th cost 2.
- **Outposts** (Perch Pods, 27 PP) claim range but have no defense: a hostile armed fleet that controls orbit at end of turn **razes** the outpost.
- **Blockade**: a hostile armed fleet controlling orbit stops the colony's growth and halves its industry; its trade income stops.
- Net effect at T5 (corrected in revision 4): a second Nest Ship costs 65 PP (4.6 turns of capital output), 1 capital pop and 1 credit/turn. At the capital (pop 7 of 12 after the drain) growth is `(7000 x 5000 / 12000) x 10% + 50 ≈ 341` milli/turn, so the drained pop **regrows in about 3 turns** (≈ 9 PP or RP lost in total), not 8; the drain bites only on small frontier colonies (pop 3 of 9: ≈ 183 milli/turn, ~5.5 turns). Costs are **not** raised on that basis: the brake is the 30% habitable rate past 9 pc plus admin upkeep, and the playtest gate (H3) and the soak's per-colony payback report (§17.2) decide whether more is needed.
- **Prospect line** [MVP]: the Nest Ship order and the colonise target tooltip show one line for the target world after supply lines and admin: net food, net credits, net PP at the colony's pop 3 and at its max pop. [COPY: ui.expansion.prospect]

### 5.6 Specialisation [MVP]

Each colony with pop ≥ 4 may take one specialisation. Changing it costs 10 turns of **Retooling** (the new bonus is halved and the new penalty applies in full).

| id | Display [COPY] | Effect | Opportunity cost |
|---|---|---|---|
| forge | Forge | Industry +25% | Research -25% |
| academy | Academy | Research +25% | Industry -25% |
| yard | Yard | Ships built here -15% PP; **only Yards and the capital can build Heron, Albatross and Titan Perch hulls**; refits allowed here | Research -25%; needs The Yard building |
| (none) | — | — | — |

STRETCH: Granary, Bastion. Where your Yards sit decides where your big fleets come from.

### 5.7 Production, queue, presets and the military budget

- Per-colony queue; overflow carries in full; Repeat and Count; Colony Base (40 PP, colonises a same-system planet, also drains 1 pop); Trade Goods filler (2 PP = 1 cr); Housing filler; queue templates. Rush-buy costs `2 x remaining` (x2 if zero progress).
- **Presets** (job policy + build list): Capital, Industry, Research, Breadbasket, Frontier (default), Fortress, Manual. Fillers are Trade Goods or Housing; **no preset queues warships on its own**.
- **Military budget** [MVP] (empire policy): Peace 10% / Guarded 20% (default) / War 40% of total industry targeted at warships. Governors at Yards and the capital add the role designs the budget calls for and **stop at the target**. They stop entirely when fleet upkeep exceeds 30% of income. The AI uses the same policy field. Every governor-added item carries a "why queued" tooltip ("Military budget Guarded 20%: current 14%"). [COPY: summary.why_queued.*]
- **Governor log** every 10 turns in the summary. Governors never trade tech, declare war or cancel a victory project.
- **Refit** [MVP]: at a Yard (or capital) system, a ship can switch to another design of the same hull; pay the positive PP difference; the ship is out of action 2 turns.

### 5.8 Credits

Income: taxes, Grand Nest, specials, trade treaties, Trade Goods, food surplus (2:1), Seed Exchange. Expenses: building upkeep, colony administration, ship upkeep, food import, spy and security funding. A shortfall triggers a **Strike** (industry -25% next turn).

### 5.9 Buildings [MVP]

Ids follow Grok's display names (COPY_PLAN maps the old ids).

| id | Tech | PP | Upkeep | Effect |
|---|---|---|---|---|
| grand_nest | start | 300 | 0 | Capital (§4.4) |
| the_yard | start | 60 | 1 | Ships can be built here |
| boot_barracks | start | 40 | 1 | Garrison 4 marines, +2/turn regen |
| feed_hall | PL1 | 60 | 1 | +2 food (Fishery for piscivores) |
| second_shift_hall | CN1 | 60 | 1 | +1 PP/worker, +3 PP |
| research_roost | CO1 opt | 60 | 1 | +1 RP/scientist, +3 RP |
| horizon_perch | WE1 opt | 80 | 1 | Planet defense: 3 launchers (best Horizon, or the Hatch Dart profile), 40 HP x armor |
| colony_mantle | FF2 | 100 | 2 | Planet shield 5; bombardment -50% |
| richer_dirt | PL1 opt | 80 | 1 | +1 food/farmer |
| second_clutch | PL2 opt | 100 | 2 | Growth +50% here |
| tireless_picks | CN3 | 100 | 2 | +1 PP/worker, +5 PP |
| loud_abacus | CO3 opt | 120 | 2 | +1 RP/scientist, +5 RP |
| more_perch | PL3 | 100 | 1 | +1 max pop per size |
| talon_batteries | WE3 opt | 120 | 2 | Planet defense: 4 Primary-mount Talons of the best beam |
| seed_exchange | CO4 opt | 150 | 0 | Taxes here +50% |
| gravity_manners | FF4 | 150 | 2 | Removes the gravity penalty |
| night_lab | CO5 opt | 150 | 3 | +10 RP |
| climate_lever | PL5 opt | 150 | 2 | +1 food/farmer |
| ugly_perch | CN5 | 250 | 3 | Orbital defense 400 HP x armor, 6 best Talons, best ship shield; ships built here -10% |
| flock_brain | CO6 opt | 200 | 3 | +2 RP/scientist |
| storm_mantle | FF5 opt | 200 | 3 | Planet shield 10; bombardment -75% |
| deep_scratch | CN6 opt | 200 | 3 | +2 PP/worker, +10 PP |
| roost_gate | PR6 opt | 300 | 4 | 1-turn travel between any two of your gate systems |
| departure_roost | Exodus keys | 3000 | 0 | Capital project; completion = Exodus victory |

---

## 6. Research

### 6.1 DECISION: six fields x six tiers, core + one of two options, one active project

| id | Display | Covers |
|---|---|---|
| computers (CO) | **Flocknet** | Computers, Miss Fields, scanners, labs, spies |
| construction (CN) | **Nestworks** | Hulls, armor, industry, ground gear |
| force_fields (FF) | **Mantle** | Ship and planet shields, retreat control |
| planetology (PL) | **Plumage** | Food, habitability, growth |
| propulsion (PR) | **Flightcraft** | Drives, range, evasion |
| weapons (WE) | **Broodheat** | Talon, Beak, Horizon, bombs, planet guns |

- 36 nodes, each = **core** (backbone, always granted) + **one of two options**. One prompt per node; the research queue pre-chooses. Every option has an MVP effect: no dead buttons.
- **The fork holds** (revision 4): the unchosen option of a **tier 1-4** node cannot be started until **two further tiers of that field** are complete (T1 sibling after T3, T2 after T4, T3 after T5, T4 after T6), and then costs **150%** of its tier. **Hyper-Preened forks (tiers 5 and 6) are final**: their unchosen option can never be researched, only received by trade, theft, capture or Cache (round 2: there is no T7 or T8 to wait for, so the old wording silently made them permanent; now it is a printed rule). Trade, theft, capture and Cache bypass every wait. Creative (Owls) receives both options of every node, including the final forks, on the same completion with no second prompt; One-Note (Chickens) never researches a sibling at any tier. [COPY: ui.research.fork_locked, ui.research.fork_final]
- **Tech-transfer limit**: an empire can **receive** at most one tech by trade or gift per 10 turns (steal, capture, Cache and Guardian loot do not count). Exodus keys never move.
- Tiers 5-6 carry the **Hyper-Preened** label. Repeatable Hyper-Preened techs: [STRETCH].
- Completion is deterministic; overflow carries.

### 6.2 Cost

`cost(tier) = 30 x tier²` → T1 30, T2 120, T3 270, T4 480, T5 750, T6 1080 (field total 2730, tree 16,380). An unchosen T1-T4 option researched later costs 150%.

**Creative price** (revision 4): Wide-Eyed is worth the 24 early siblings without the wait or the 150% (a full set costs an ordinary empire `1.5 x (30+120+270+480) x 6 = 8,100` RP, and it gets them two tiers late) plus 12 final options nobody else can research. Against that, Owls carry poor_industry, so half of the extra options are buildings their factories queue slowly, and trade, theft and Cache let others reach any single sibling. Priced at **6 picks** (round 2 bracketed it between Grok's 5 and the old 8). `creative_tier_cost_pct` (default 0) stays the measured knob: it is raised only if the soak shows Owls above their band (§17.2).

Pacing check (balanced player; RP ≈ 9 → 25 (T30) → 60 (T60) → 110 (T90) → 160 (T120) → 200 (T150)): cumulative RP ≈ 1,800 by T60, 4,300 by T90, 8,400 by T120, 13,800 by T150. So: all six T3 by ~T70, all T4 by ~T100, Exodus requirements (§14, ≈ 12,100 RP) by ~T140. A research-focused empire (+50% RP) gets there by ≈ T115, then needs the 3000-PP Departure Roost.

### 6.3 The tree [MVP]

Names are Grok's (Part B) or the meme bible's; ids are the snake_case of the name. Cores are granted; the two options are the choice.

**Flocknet (CO)**
| T | Core | Option A | Option B |
|---|---|---|---|
| 1 | Pecking Logs (computer +10) | Research Roost (bldg) | The Shared Glance (+2 scan; scouts read planets at 3 pc) |
| 2 | Everyone Can Miss (Miss Field I special: Horizon vs ship -20) | Security Nest (+25 security) | Drill Roost (new ships Veteran +5 acc) |
| 3 | Predictive Peck (computer +20) | Loud Abacus (bldg) | Loadout Glance (special: +10 acc, reveals enemy designs) |
| 4 | Miss Field II (-40) | Seed Exchange (bldg) | Destination Board (+4 scan; see fleet destinations) |
| 5 | Grudge Ledger (computer +30) | Night Lab (bldg) | Battle Transcriber (+30 spy; autopsy shows enemy loadouts) |
| 6 | Hyper-Preened Cognition (Preened Cognition computer +40; battle line +1) | Flock Brain (bldg) | Between the Feathers (Beak ignores shields) |

**Nestworks (CN)**
| T | Core | Option A | Option B |
|---|---|---|---|
| 1 | Second Shift (Second Shift Hall) | Reinforced Roost (Roost Bracing special: HP +50%) | Drydock of Regret (ships -10% PP) |
| 2 | The Large Keel (Heron hull) | Proper Joinery (Joined Plate x1.5) | Rock Picking (asteroid/gas-giant outposts +3 PP to the system's best colony) |
| 3 | Automated Incubators (Tireless Picks) | Standards and Talons (+5 marine str) | Kit Nests (buildings -20% PP) |
| 4 | The Wide Keel (Albatross hull) + Keel Plate (x2.0) | Fortified Nests (planet defense HP x1.5) | Boot Frame (+10 marine and militia str) |
| 5 | Ugly Perch (bldg) | Marrow Plate (x2.75) | Self-Sealing Nest (special: heal 10%/round) |
| 6 | Titan Perch (hull) + The Unsinkable Argument (Unsinkable Plate x3.5) | Deep Scratch (bldg) | Yard Swarm (ships -25% PP) |

**Mantle (FF)**
| T | Core | Option A | Option B |
|---|---|---|---|
| 1 | Dust Cover (shield 2) | Personal Down (+5 marine/militia str) | Scatter Molt (incoming Horizon -20 acc, all ships) |
| 2 | Colony Mantle (bldg) | Early Mantle (ship shield +1 in rounds 1-3) | Null Glide (+10 evasion) |
| 3 | Half Mantle (shield 4) | Tractor Etiquette (enemy retreat +2 rounds) | Hard Down (+20% hull HP) |
| 4 | Gravity Manners (bldg) | No Exit (in your colony systems enemies cannot retreat before round 8) | Two Steps Back (battles at your colonies start at distance 12) |
| 5 | Full Mantle (shield 6) | Gone to Molt (special: untargetable rounds 1-2; still fires) | Storm Mantle (bldg) |
| 6 | Closed Season (shield 9) | Overpreen (+2 shield class) | Not This Feather (special: 25% of hits miss outright) |

**Plumage (PL)**
| T | Core | Option A | Option B |
|---|---|---|---|
| 1 | Better Feed (Feed Hall) | Richer Dirt (bldg) | Old Green (+1 pop/size on Garden/Temperate/Ocean/Jungle) |
| 2 | Dome Perches (colonise Bare/Cinder/Sour at 1 pop/size) | Molt Management (Second Clutch bldg) | The Dose (plague immunity, growth +10%) |
| 3 | More Perch (bldg) | Dome Perches II (hostile 2 pop/size) | Toxic Preening (bombardment x2; -5 relation with every empire that sees it) |
| 4 | Climate Tailoring (+1 pop/size on Ice/Desert/Arid, all colonies) | Crackle Shutters (colonise Crackle) | Root Scratch (+2 food per colony) |
| 5 | Deep Down (+1 pop/size, all colonies) | Climate Lever (bldg) | Quick Genes (growth +25%) |
| 6 | Hyper-Preened Genesis (+2 pop/size; **Exodus key**) | Every Job, Up (+1 to every job yield) | Two-Chick Pods (Nest Ships land 2 pop) |

**Flightcraft (PR)**
| T | Core | Option A | Option B |
|---|---|---|---|
| 1 | Downrange Charts (range 8) | Lean-In (special: +1 combat speed) | Soft Bones (+10 evasion) |
| 2 | Warm Current (Current Drive 3/2) | Crop Tanks (special: +3 range) | Courier Wings (+1 map speed, Sparrow/Kestrel) |
| 3 | Tailwinds (range 10) | Trade Winds (trade income +50%) | The Upkeep Diet (ship upkeep -25%) |
| 4 | The Folded Sky (Fold Drive 4/2) | Steady Bird (+20 evasion) | Far Nests (Nest/Stake ships +4 range) |
| 5 | Migratory Math (range 13) | The Kick (+1 combat speed all) | Instant Regret (your retreats leave at round 1; the receipt is still paid) |
| 6 | Hyper-Preened Kinematics (Migration Drive 6/3; **Exodus key**) | Roost Lanes (Roost Gate bldg) | Far Cells (range 17) |

**Broodheat (WE)** — Talon and Beak lines are cores; the Horizon line is all options (a commitment); every empire gets the Swat answer at T2.
| T | Core | Option A | Option B |
|---|---|---|---|
| 1 | Peck Driver (Beak) | Hatch Dart (first Horizon) | Horizon Perch (bldg) |
| 2 | Second Sun (Sun Quill, Talon) + **Swat Mount** | Ink Dart (Horizon; opens the line if Hatch Dart was skipped) | Primary Mount (Talon mod) |
| 3 | Clatter Bill (Beak) | Talon Batteries (bldg) | Rude Sun (bomb part, x2 Bomb Bay) |
| 4 | Focused Glare (Banded Glare, Talon) | Cited Dart (Horizon) | Between the Ribs (Beak ignores 75% of shields) |
| 5 | Gizzard Bore (Beak) | Horizon Perch II (planet Horizon +50%) | The Long Honk (Talons fire an extra shot every other round) |
| 6 | Hyper-Preened Thermals (Last Glare, Talon) + Anvil Beak (Beak) | Quiet Star (Indoor Torpedo, Horizon) | Heart of the Roost (Very Polite Warhead; triggers Placid, Until) |

Not placed (Grok names kept for STRETCH): Miss Field III, Annotated Grudge, Every Perch, Loose Feathers, Second Reader, Thrift Nest, The Extra Shift, Barrier Nest, Hold Still, Extra Coverts, The Closed Sky, Beak-Proof, Reflective Plumage, Absolute No, Midlife Molt, Made Ground, Garden Intent, Table Manners, Rapid Hatching, Ash Drive, Empty Perch, Home Stretch, Nebula Runners, The Map Is Yours, Round-One Encore, Long Quill, Appendix Dart, Spread Quill, Keel Gun, Opening Web, Spreadsheet of Fate (event-only, STRETCH).

Captured colonies: 50% chance (keyed) to gain one tech the victim knows and you don't (never an Exodus key).

---

## 7. Ship design

### 7.1 Hulls

| id (display) | Tech | Space | HP | PP | Evasion | Upkeep | Specials | Line slots | Built at |
|---|---|---|---|---|---|---|---|---|---|
| small (Sparrow) | start | 24 | 20 | 8 | +15 | 1 | 1 | 1 | any colony with The Yard |
| medium (Kestrel) | start | 60 | 60 | 22 | +5 | 1 | 2 | 1 | any colony with The Yard |
| large (Heron) | CN2 | 130 | 150 | 55 | 0 | 2 | 3 | 1 | Yard specialisation / capital |
| huge (Albatross) | CN4 | 280 | 350 | 130 | -10 | 4 | 4 | 1 | Yard specialisation / capital |
| titan (Titan Perch) | CN6 | 600 | 800 | 320 | -20 | 8 | 5 | 2 | Yard specialisation / capital |

Unarmed ships pay no upkeep.

### 7.2 Design rules

Hull + one Drive, one Plate, one Mantle (or none), one Computer (or none) + mounts + specials. Drive, Mantle and Computer take a % of hull space (Drive 15/13/11/9%, Mantle 8/10/12/14%, Computer 5%; round up). The plate takes no space (+0/20/40/60/80% of hull PP). Weapons and specials take flat space. **Miniaturisation**: `space, cost x max(50, 100 - 15 x (tiers known above the part's tier))%` (15 per tier with 6 tiers).

### 7.3 Parts [MVP]

| Part | Tech | Space | PP | Damage | Notes |
|---|---|---|---|---|---|
| **Talon** | | | | | Falloff 4%/distance unit; full shields |
| Wick Talon | start | 5 | 3 | 3-8 | |
| Sun Quill | WE2 | 6 | 5 | 5-12 | |
| Banded Glare | WE4 | 8 | 8 | 8-18 | |
| Last Glare | WE6 | 11 | 15 | 14-32 | |
| **Beak** | | | | | -6 acc per distance unit; shields count half |
| Peck Driver | WE1 | 6 | 3 | 5-9 | |
| Clatter Bill | WE3 | 8 | 6 | 9-15 | |
| Gizzard Bore | WE5 | 10 | 10 | 14-24 | |
| Anvil Beak | WE6 | 12 | 14 | 20-34 | |
| **Horizon** | | | | | Fixed damage; **3 salvos**; 1-round flight; full shields; Swat and Miss Fields counter |
| Hatch Dart | WE1 opt | 6 | 4 | 5 | acc +0 |
| Ink Dart | WE2 opt | 6 | 6 | 9 | acc +10 |
| Cited Dart | WE4 opt | 6 | 8 | 13 | acc +15 |
| Indoor Torpedo | WE6 opt | 10 | 14 | 30 | unlimited ammo; fires every other round |
| **Mounts** (Talon) | | | | | |
| Primary Mount | WE2 opt | x2 | x1.5 | x1.5 | falloff 2% |
| Swat Mount | WE2 core | x0.5 | x0.5 | x0.5 | +20 acc; Swat mode (§9.4) |
| **Systems** | | | | | |
| Walk / Current / Fold / Migration Drive | start / PR2 / PR4 / PR6 | 15/13/11/9% | 10% hull | — | map / combat speed 2/1, 3/2, 4/2, 6/3 |
| Pinfeather / Joined / Keel / Marrow / Unsinkable Plate | start / CN2 opt / CN4 / CN5 opt / CN6 | 0 | +0..80% hull | — | HP x1.0 / 1.5 / 2.0 / 2.75 / 3.5 |
| Dust Cover / Half Mantle / Full Mantle / Closed Season | FF1 / FF3 / FF5 / FF6 | 8-14% | 15% hull | — | shield 2 / 4 / 6 / 9 |
| Pecking Logs / Predictive Peck / Grudge Ledger / Preened Cognition | CO1 / CO3 / CO5 / CO6 | 5% | 10% hull | — | +10 / +20 / +30 / +40 acc |
| **Specials** | | | | | |
| Nest Pod / Perch Pod / Boot Pod / Glance Pod | start | 40 / 12 / 20 / 4 | 40 / 18 / 10 / 2 | | colonise (drains 1 pop) / outpost / 4 marines / +2 scan |
| Bomb Bay | start | 10 | 6 | | Bombardment: 250 milli-pop/turn |
| Rude Sun | WE3 opt | 10 | 10 | | Bombardment: 500 milli-pop/turn |
| Very Polite Warhead | WE6 opt | 12 | 30 | | 2000 milli-pop/turn, ignores planet shields |
| Roost Bracing | CN1 opt | 10% | 10% | | HP +50% |
| Miss Field I / II | CO2 / CO4 core | 5% | 5 | | Horizon vs this ship -20 / -40 acc |
| Loadout Glance | CO3 opt | 4 | 6 | | +10 acc; reveals designs |
| Lean-In / Crop Tanks | PR1 / PR2 opt | 5% | 5 / 4 | | +1 combat speed / +3 range |
| Self-Sealing Nest | CN5 opt | 8% | 15 | | Heal 10% max HP per round |
| Gone to Molt | FF5 opt | 10% | 20 | | Untargetable rounds 1-2; fires normally |
| Not This Feather | FF6 opt | 8% | 15 | | 25% of hits on this ship miss |
| Orn-Plating | Guardian loot | 5% | 20 | | HP +40%, shield +2; only the empire that killed the Guardian |

Starter-kit check: at distance 3, no shields, vs Kestrels, a Wick Talon does 2.5 expected damage per mount-round (12.5 over 5 rounds); a Hatch Dart does 3.4 per launcher-round for 3 salvos (10.2 total). Darts lead rounds 1-3; Talons win any fight that lasts.

### 7.4 Designer and auto-design [MVP]

Designer as in revision 2 (space bar; live stats: HP, evasion, speed, PP, upkeep, expected damage per round at distance 3 vs shield 0/2/4/6/9; obsolete warning; 12 active designs). Auto-design roles: Talon Line, Beak Line, Horizon Boat, Swat Escort, Boot Ship, Nest Ship, Stake Ship, Glance (deterministic greedy; the band weapon is chosen against the highest enemy shield seen). "Upgrade queued designs" defaults to ON; **Refit** per §5.7.

---

## 8. Fleets and movement

- Speed = slowest ship; `turns = ceil(distance / speed)`; redirect any time. **Fuel range** is measured from own colonies and outposts (also allies under an Alliance, and Coalition members for operations against the leader, §12.4): base 6, then 8 / 10 / 13 / 17 by Flightcraft. Wormhole and Roost Gates: 1 turn.
- Auto-explore, auto-colonise suggestions, rally points per Yard.
- **Standing battle plan per fleet** (§9.4): posture, target priority, Swat mode, line order, retreat threshold. 8+ ships: DOOMSTACK label.
- **Repair**: 20% max HP/turn at own colony systems, 100% at Yard or capital systems (huddle: 100% at any own colony).
- **Visibility**: all stars known; planets explored on visit; fleets seen within scan range (colony 3 pc, capital +2, ships 1 pc, Glance Pod +2, stealthy halves). The AI uses the same model plus printed difficulty vision.

---

## 9. Combat

### 9.1 When

At a system, at the combat step, if parties at war (or the Monster faction) have ships or armed planets there. One battle per system per turn. Unarmed ships are targets.

### 9.2 The Battle Orders card [MVP] (red team: agency)

Before a battle resolves, each side issues **one set of orders**:
- **The player** gets a Battle Orders card for a battle that qualifies. Setting Always / Big (default) / Never. **Big** (revision 4) means the player has at least 1 armed ship in the battle **and** (own side ≥ 3 armed ships, **or** enemy side ≥ 3 armed ships, **or** a bomb part is present on either side). A colony defending alone, or a lone scout, never stops the turn; planets fight on their defaults.
- **One stop per turn** (revision 4): all of a turn's qualifying battles are presented together on one Battle Orders stop, one card each, the **3 largest by total armed PP** first; any further battles that turn use standing plans and are listed as "auto" lines on the same stop. Enter accepts all; each card is also accepted on its own.
- Each card shows the enemy as visible (hull counts, designs if known, estimated odds), the five orders below pre-filled from the standing plan, and a **range projection line** computed by the §9.3 rule from your posture and speed against the enemy's visible line speed: "Talon band by round {t}, Beak band by round {b} at worst" (the worst case is when they open at full speed; §9.3 makes it exact). [COPY: battle.orders.projection]
- **Combined fleets**: when several of your fleets are in one battle, they form one party; its orders are the standing plan of the fleet with the largest armed PP (ties: lowest fleet id), and the line order concatenates the fleets' line orders in that same ranking. The card edits the party's orders.
- **The AI** chooses at the same point from the same visible information (AiBattle, §13.3). Neither side sees the other's orders.
- Headless runs and the "Never" setting use standing plans. Orders are commands, so replays reproduce them.

Turn processing pauses once for the stop (ARCHITECTURE §7.3); it is the only mid-turn prompt. Whether orders change outcomes is measured, not assumed: probe P9 (§17.3).

### 9.3 Range, posture and the line

**Distance** `D` between two opposing parties starts at **10** (12 with Two Steps Back at your colony) and stays within 0..12. Bands on the strip (drawn on the battle view with the words): **Beak 0-3, Talon 3-7, Horizon anywhere**.

**Posture** sets a preferred distance P: **Close** 0, **Talon range** 5, **Stand Off** 12, **Auto** (loadout-weighted: Beak 1, Talon 5, Horizon 12; switches to the remaining band when Horizon ammo is spent), **Retreat** (§9.6).

**Movement each round** (revision 4; replaces the simultaneous-sum rule, which froze equal-speed Close vs Stand Off at D = 10 for all 8 rounds). `s` = the party's line combat speed, the minimum over its armed line ships, at least 1 for a fleet; planets have `s = 0` and never move or resist. For each pair of opposing parties, `c` is the **closer** (the lower P) and `o` the **opener** (the higher P):
```
if P_a == P_b or s_a == 0 or s_b == 0:        # no contest: each moves toward its own P
    D = clamp(D + clamp(P_a - D, -s_a, s_a) + clamp(P_b - D, -s_b, s_b), 0, 12)
elif D > P_c:                                 # the closer still wants in
    if D > P_o:  gain = s_c + min(s_o, D - P_o)               # both come in
    else:        gain = max(1, s_c - min(s_o, 12 - D))        # contested: never less than 1
    D = max(P_c, D - gain)
elif D == P_c:                                # closer is on its number
    D = min(12, D + max(0, min(s_o, P_o - D, 12 - D) - s_c))  # opener pulls away only if strictly faster
else:                                         # D < P_c: both want out
    D = min(P_c, D + s_c + min(s_o, max(0, P_o - D)))
```
Spoken rule (printed in the battle help and on the strip tooltip): **"While the distance is above the closer's number, it shrinks every round: by the closer's speed minus the opener's, never by less than 1. The opener can only pull away from a closer that is already on its number, and only by what it is strictly faster."** [COPY: ui.battle.range_rule]

**Proof that every closer reaches its band.** Whenever `D > P_c`, every branch lowers D by at least 1 (no-contest: the closer's own step is ≥ 1 and a planet adds 0; both-in: `gain ≥ s_c ≥ 1`; contested: `gain ≥ 1`), and D never drops below `P_c`. So from any start the closer reaches `P_c` in at most `D0 - P_c` rounds, for **every** speed pairing; at `P_c` it is pushed out only by `s_o - s_c` and is back in band within that many rounds. From the standard start of 10: the Talon band (≤ 7) within **3** rounds and the Beak band (≤ 3) within **7** rounds, inside the 8-round battle. Measured over all P ∈ {0, 1, 5, 12} x s ∈ {0..5} x D0 ∈ {0..12}: zero violations. Rounds to reach the band, Close (0) vs Stand Off (12), start 10, as `Talon/Beak`:

| s_c \ s_o | 0 (planet) | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| 1 | 3/7 | 3/7 | 3/7 | 3/7 | 3/7 |
| 2 | 2/4 | 3/7 | 3/7 | 3/7 | 3/7 |
| 3 | 1/3 | 2/4 | 3/7 | 3/7 | 3/7 |
| 4 | 1/2 | 1/3 | 2/4 | 2/6 | 2/6 |

What kiting buys is **time, not immunity**: a Stand Off fleet at least as fast holds a Beak fleet out of its band for 7 of 8 rounds (that is the Horizon boat's whole job); being faster than the closer is how you earn the lead (`s_c - s_o` per round). Two Steps Back starts at 12, which is 9 rounds for a speed-1 closer: the stalemate carry-over (§9.7) finishes it next turn.

Consequences (each pinned by the P6 table fixture):
- A faster closer gains `s_c - s_o` per round; an equal or slower closer still gains 1 per round.
- Two closers meet at the sum of their speeds; two parties with the same P go to it and hold.
- Talon range (5) against Close (0) cannot anchor: the pair falls into the Beak band, and the Talon fleet gets the rounds between 10 and 3 to shoot.
- In three-way battles, each pair's D resolves independently with the same rule.

**The battle line**: each party fields at most **8 line slots** (Titan Perch takes 2; Geese 10; Hyper-Preened Cognition +1). The rest wait in reserve and fill empty slots at the start of each round, in reserve order. **Line order** belongs to the fleet. The default is by role: Swat Escorts and ships of the posture's band first, then other warships by hull size, unarmed ships last. The player can reorder in the fleet panel or on the card. Planet defenses are not counted.

### 9.4 Orders

| Order | Choices | Effect |
|---|---|---|
| Posture | Auto / Close / Talon range / Stand Off / Retreat | §9.3 |
| Target priority | Auto (kill what can die) / Biggest first / Swat Escorts first / Band (Talon, Beak or Horizon ships first) / Planet defenses first / Transports first | Each mount picks among in-range enemies with the priority as the first key, then Auto's score, then lowest id |
| Swat mode | Missiles first (default) / Ships first | Swat Mounts shoot incoming Horizon first, or treat it as secondary |
| Line order | Default / custom | §9.3 |
| Retreat threshold | Never / odds below 1:2 / below 1:1 | Evaluated at battle start; sets posture Retreat |

### 9.5 A round (8 max)

1. Reserves fill the line; parties move.
2. Horizon in flight arrives. Swat Mounts in Missiles-first mode shoot first (2 shots each at 60 + acc, one missile per hit). Survivors roll `clamp(70 + missile acc - Miss Field - evasion/2 - Scatter Molt, 5, 95)`.
3. All line mounts fire, including Gone to Molt ships (they cannot be **targeted** in rounds 1-2). Shots are computed against the start-of-step state and applied together.
4. Horizon launchers with ammo fire (arriving next round).
5. Cleanup: destroyed ships removed, Self-Sealing heals, retreats resolved.

To-hit (Talon/Beak): `clamp(60 + acc - evasion - (Beak ? 6 x D : 0), 5, 95)`. Damage: `raw x (100 + band/v_formation/flush pcts)/100`; Talon `x (100 - falloff x D)/100`; then `- shield` (Talon/Horizon full, Beak half); min 0. Single HP pool per ship.

### 9.6 Retreat (red team: one consistent rule)

A party with posture Retreat escapes at the **end of round R**, where `R = 2`; **Instant Regret** (own) sets `R = 1`; **Tractor Etiquette** (enemy) `+2`; **flush** (enemy, first battle of a war) `+1`; **No Exit** (enemy, at the enemy's colony system) sets `R = 8` (the party must survive the battle). Every escape pays the **receipt**: the slowest ship (ties: most damaged, then lowest id) is destroyed. This applies always, including Instant Regret. While retreating, the party moves toward D = 12 and fires only Swat Mounts. Escaped fleets go to the nearest friendly colony in range. Fixtures pin every combination.

### 9.7 End, autopsy, viewer

- The battle ends early when at most one mutually-hostile armed side remains. After round 8 with several, it is a stalemate (repeat next turn, no orbit control). **Stalemate carry-over** (revision 4): if the same two parties (same empires) fight at that system next turn, each pair starts at the distance it ended on, not at 10 or 12. The side holding the field controls orbit; enemy unarmed ships there are destroyed. Veterancy: +5 acc (max +15).
- **Autopsy** [MVP]: deciding band, standout hull, receipt, and (with Battle Transcriber) enemy loadouts.
- **Viewer** [MVP]: side view with the range strip and band words; ~1.2 s/round at 1x; pause, 1x/2x/4x, skip, replay. The **first Horizon wave is drawn as darts being swatted**; volley ticks are used only for overflow beyond the projectile cap. Watching never changes anything.

### 9.8 Planets and monsters

Colony defenses form a party with s = 0: Horizon Perch (3 launchers, unlimited ammo), Talon Batteries (4 Primary Talons), Ugly Perch (6 Talons, own shield, 400 HP x armor). Defense HP is multiplied by Fortified Nests and huddle; the planet shield applies to every hit; at 0 HP the defenses are suppressed (regen 25%/turn).

- **Guardian of Orn** [MVP]: 3000 HP, shield 9, evasion -20, 6 Last Glares (its own; not loot), 2 Indoor Torpedo launchers, Self-Sealing. A warning-volley card shows on first contact. An empire that fights it and retreats is **Guardian-Marked** (-10% damage, 10 turns). Reward: Orn becomes colonisable, plus **Orn-Plating** and 2 random techs from Flocknet/Nestworks/Mantle/Plumage at ≤ (your highest tier in that field + 1). No reward skips a weapon band.
- **Pond-Scum Leviathan** x2 [MVP]: 400 HP, shield 2, 4 Beaks 8-14.

---

## 10. Bombardment, blockade, invasion

- **Blockade**: an armed fleet controlling orbit stops growth, halves industry and stops trade income; outposts are razed.
- **Bombardment** (order Bombard): only bomb parts kill pop. Per turn: `sum(Bomb Bay 250, Rude Sun 500) milli`, doubled by Toxic Preening, halved by Colony Mantle, quartered by Storm Mantle. A Very Polite Warhead kills 2000 milli ignoring shields. Diplomacy: -5/turn with the victim, -2 with all others (Toxic Preening -5 more). A starting Sparrow has no Bomb Bay and kills nobody.
- **Invasion**: Boot Ships in a fleet controlling orbit after combat land with order Invade; defenses must be suppressed or absent. Attackers bring 4 marines per Boot Pod at `10 + tech` x ground modifier. Defenders: militia `ceil(pop/2)` at `6 + tech`, plus the garrison (Boot Barracks 4, regen 2) at `10 + tech`. Duels resolve at `p = s_a/(s_a+s_d)`, garrison first, keyed RNG. On a win, the owner changes; species, pop and buildings are kept; the colony is Occupied for 10 turns (-50%; unification skips this); 50% chance of one tech. Invasion is the only way to take productive worlds; bombardment is a siege tool.

---

## 11. Espionage [MVP]

- One **Spy Target** (any met empire) with funding Off / Low 3 / Med 6 / High 12 credits/turn; one empire-wide **Security** level at the same prices.
- `intel += funding x (100 + spy_score)/100`. At `30 + 3 x L` (L = target techs you lack, cap 20), an attempt fires: `success = clamp(50 + spy - security, 10, 90)`, where `security = 2 x security funding + spy trait + Security Nest 25 - 20 if Democracy`.
- Success: **choose one of up to 3** lackable techs (keyed draw; never Exodus keys). Failure: 50% chance of being caught (-15 relation). Intel resets either way. Stolen techs count as *seen* for Cache. [STRETCH: sabotage, framing.]

---

## 12. Diplomacy, the Grand Roost and the Coalition

### 12.1 Relations

Range -100..+100, with a breakdown tooltip:
- Base: charismatic +20, notorious -20, repulsive/distrusted -30.
- Border tension: -2 per close colony pair (cap -20). Territorial: -1/turn (floor -60, stops under a treaty).
- Positive lines: treaties +10 each; trade/research benefit +1 per 10/turn (cap 15); favours +1 per 10 credits of value given (decays); Coalition +10 / +15 among members.
- Grudges: spy caught -15, bombarded -5/turn, backstab -40 (victim) / -20 (witnesses), broken pledge -20, voted against -10.
- War: -30.

Non-war lines decay 1/turn (The Neighbor's grudges at half rate).

### 12.2 Treaties and exchanges

| Treaty | Needs relation | Effect |
|---|---|---|
| NAP | ≥ 0 (territorial rule applies) | — |
| Trade | ≥ 10 | `min(pop_A, pop_B)/4` credits/turn each, 10-turn ramp; x2 fantastic_traders; +50% Trade Winds |
| Research | ≥ 20 | 10% of partner RP; never with distrusted |
| Alliance | ≥ 50 | Shared vision and range |
| Peace | — | 15-turn truce |

Exchanges: tech (receiver limit 1 per 10 turns), credits, tribute demands, **Grand Roost pledges** (§12.3). The AI accepts if `value + relation/2 + personality bias ≥ 0` and shows its reasons. [COPY: diplo.reason.*]

### 12.3 The Grand Roost [MVP] (red team: no early ballot win)

- Sessions happen at the preset's first turn and then every interval, while ≥ 3 empires live and the player has met one. The **first session is non-binding**: it publishes the count and names no Supreme Bird. Each session is announced 5 turns ahead.
- **Votes** = whole pop units. Charismatic adds 10% of the charismatic empire's votes to a candidate it votes for, **never itself**.
- **Candidates**: the two empires with the most votes. A candidate is **electable** only if it has met every living empire **and** holds ≥ 30% of all votes itself.
- **Pledges**: an AI's vote can be bought for the next session. Price = `10 x votes x (1 + 4 x buyer's own vote share)` credits, so it scales with victory leverage. Pledged votes counted for one candidate are capped at **15% of all votes**; that cap is the anti-buyout. Breaking a pledge: -20. (Revision 4: the old "an AI refuses a pledge that would carry a non-ally over 2/3" is **deleted**; it made the 52% route below illegal.)
- **Unpledged AI votes** (revision 4), in this order: (1) a candidate votes for itself; (2) a Coalition member never votes for the Coalition leader while the Coalition is active; (3) an AI votes for an **Acknowledged** candidate it is not at war with (§12.4); (4) for an allied candidate; (5) for the candidate it has the higher relation with, if that relation ≥ 0; (6) otherwise it abstains. Ties: lower empire id. The player's vote is the player's.
- A candidate with **≥ 2/3 of all votes** (cast or abstained) becomes Supreme Bird. If that is the player, it is victory. If it is an AI, the player chooses **Accept** (defeat) or **Defy** (the Grand Roost dissolves; every empire that voted for the winner declares war; the Defy card lists them by leader name). The player votes at the start of the session turn.
- **Routes to 2/3** (Evening Standard, 4 empires; stated on `council.electability_tip`): (a) **unallied**: ≥ 52% of the votes yourself + ≤ 15% bought; (b) **with friends**: ≥ 30% yourself + an ally's votes + voluntary votes (rule 5: AIs that like you more than your rival) + ≤ 15% bought; (c) **Acknowledged**: ≥ 30% yourself, survive a Coalition (§12.4), and every AI not at war with you votes for you. The earliest binding session is T75. Soak check: Grand Roost wins before T120 in ≤ 1/3 of games containing Ducks (§17.2).

### 12.4 The Coalition [MVP] (red team: a real hunt, not a label)

- **Coalition power** (revision 4) = `fleet PP / 20 + 3 x colonies + pop / 2` (integer division last). It has no tech term, so reading does not make you the leader, and it weighs fleets and colonies over population, so the hunt and the ballot (votes = pop) are not aimed at the same number. Score (with techs) is used only for Called Game.
- **Trip**: from T40, when one empire's power ≥ **35%** of the living total (**30%** if notorious), it has no active Coalition against it, and it is neither in cooldown nor Acknowledged.
- **Effects while active**:
  - Members get +10 relations with each other (+15 against a notorious leader).
  - Declaring war on the leader is never a backstab.
  - Members share vision of the leader and draw fuel range from each other's colonies for operations against it.
  - **Coalition duty** (revision 4): every AI member **not allied** with the leader goes to war with it. A NAP or Trade treaty with the leader is cancelled with no backstab penalty ("Coalition duty"); only an **Alliance** exempts. Its war evaluation uses aggression 8 and war ratio x0.8 on the Coalition's combined power, overriding personality restraints (Librarian, Patient Rock, Dealmaker). [COPY: coalition.duty_tip]
  - **Strike pair** (revision 4): the **two members whose capitals are nearest the Coalition target** (the leader's colony nearest the members' power-weighted centroid, announced on PNN) commit a joint strike: each sizes its share on the **pair's combined** strike force (launch at combined ≥ 1.2 x estimated defense), and both set the **same arrival turn** (the earlier one waits at a staging system within its range). Other members stay at war and defend. If the player is one of the two nearest, the next-nearest AI member is paired instead and the player is free to join.
  - Players can join or ignore it.
- **Every Coalition ends, in one of two ways, each with an effect** (revision 4; round 2: no 25/15 loop without an outcome):
  - **Cut Down**: the leader loses a colony (captured by anyone at war with it, or depopulated), or its power falls below trip - 5 points. The Coalition dissolves at once; members at war with the leader may make peace normally; PNN announces it; the leader cannot be tripped again for **20 turns**. [COPY: coalition.end.cut_down]
  - **Held**: **25 turns** pass without a Cut Down. The Coalition dissolves; every AI member at war with the leader offers it peace (a 15-turn truce, accepted automatically by AI leaders); the leader becomes **Acknowledged** for the rest of the game: no Coalition can trip against it again, and every AI not at war with it votes for it at Grand Roost sessions (§12.3 rule 3). Surviving the hunt is a door, not a reprieve: an electable Acknowledged leader usually wins the next binding session unless someone Defies or declares war. [COPY: coalition.end.held, coalition.acknowledged_tip]
- A game can host several Coalitions (one at a time), but each Cut Down costs the leader a colony and each Held ends hunting that empire for good, so every trip moves the game toward an ending. The soak reports trips per game, outcomes, captures, capitulations and Called Games after a trip (§17.2).
- Labels: **Tier List** against Swans, **Snowball** otherwise. The first trip fires "The Tier List Leaks".

---

## 13. AI

### 13.1 Fairness and difficulty [MVP]

The AI plans from its own fog-of-war knowledge; its only advantages are printed on the difficulty card.

| Difficulty | AI industry / research / growth | Printed extras | Behaviour |
|---|---|---|---|
| Nestling | -25 / -25 / 0% | — | War threshold x2; never targets the player first |
| **Flighted** (default, balance baseline) | 0 | — | — |
| Honk Admiral | +20 / +20 / 0% | Knows player designs | War threshold x0.8 |
| Lights-Off Ledger | +40 / +40 / +20% | Player designs, colonies and fleets | War threshold x0.7 |

### 13.2 Personalities

The eight personalities are the Unbothered (Swans), Sportsman (Pheasants), Dealmaker (Ducks), Librarian (Owls), Patient Rock (Penguins), Borrower (Crows), Neighbor (Geese) and Floor (Chickens). Their weights (expansion, military, aggression, research, diplomacy, spy, defense) and special rules are as in revision 2, with one change: **Coalition duty overrides their restraint rules** (§12.4). Military budget policy per personality: Floor, Neighbor and Sportsman switch from Guarded to War at first contact with a rival within 15 pc; the others stay Guarded.

### 13.3 Planning loop and competence

Order per AI turn (each a bounded sub-step, ARCHITECTURE §7.3): Assess → Research → Design → Colonies (specialisations, presets) → Expansion → Military → War/peace → Diplomacy → Production (via the military budget) → Espionage.

**When the AI thinks** (revision 4): the **economy planners** (Research, Design, Colonies, Production) run during the player's turn, time-sliced in idle frames, on the turn-start state; their commands are held and applied at End Turn. They read only the AI's own entities and its Knowledge, which no player planning command can change, so precomputing them is a pure cache: a test asserts the same commands result whether they are computed at turn start or at End Turn after any player commands. The **war planners** (Assess, Expansion, Military, War/peace, Diplomacy, Espionage) run at End Turn on the committed orders, so a fleet the player just sent is seen if the AI's sensors say so.

At each battle, **AiBattle** picks orders by counter-picking:
- Enemy Horizon-heavy and own Swat Mounts → Missiles first and Close.
- Faster Beak fleet → Close.
- Slower Talon fleet against Beak → Talon range.
- Odds below threshold → Retreat.
- Own fleet Horizon-heavy → target Swat Escorts first.

Competence requirements (each has a scripted probe, §17.3):
- **Stale intelligence**: a seen colony's defense estimate grows +10% per 5 turns since it was seen; targets with intel older than 10 turns are re-scouted before a strike.
- **Strike sizing**: launch at `own ≥ 1.5 x estimated defense` (personality overrides apply). After a failed strike, the next attempt on that target needs `≥ 1.5 x` the defense actually met. No more than 2 failed strikes per target per 20 turns.
- **Invasion logistics**: Boot Ships travel one turn behind the strike fleet and land the turn orbit is secured; sized `marines ≥ 1.3 x defenders`.
- **Defense response**: a visible strike fleet within 3 turns of a colony triggers reinforcement or defense builds within 2 turns.
- **Command hygiene**: every AI command validates; a rejected command is a planner bug, and the soak fails on any.

Budget: each sub-step ≤ 8 ms on the low-end web target (BRIEF "Performance target"; measured locally in a browser with the CPU throttled 4x, ARCHITECTURE §10).

---

## 14. Victory and defeat

| Victory | Rule | MVP |
|---|---|---|
| **Conquest** | All rivals eliminated or capitulated | MVP |
| **Grand Roost** | Elected Supreme Bird at a binding session (§12.3) | MVP |
| **Exodus** | Hyper-Preened Kinematics + Hyper-Preened Genesis, every field ≥ T5, then the Departure Roost (3000 PP, capital). Starting it is announced (every AI -30 relation; they may target your capital) | MVP |
| **Called Game** | Highest score at the cap | MVP (fallback) |
| The Big Quiet | Crisis clock, Antherons | STRETCH |

- **Victory clock** [MVP]: per empire, progress and a linear ETA for each door (votes vs 2/3 and electability; Exodus keys, tiers and PP; rivals left). [COPY: ui.victory_clock.*]
- **Capitulation** [MVP]: an AI at war that has lost its capital, holds ≤ 3 colonies and has < 25% (35% against The Floor) of its strongest enemy's power offers surrender on a two-line card. If accepted, everything transfers.
- **One More Turn** after victory.
- **Defeat**: no colonies left; Accepting another Supreme Bird; another empire wins.
- **Score** (Called Game only): pop + 2 x colonies + 2 x techs + fleet PP/50 + 20 for the capital + 30 for Orn.

---

## 15. Presentation

- **Screens** [MVP]: Main Menu, New Game (Tiny / Evening Standard, difficulty, race, Seat the Swans, seed string), Galaxy Map, Colony panel, Colonies list (sortable; bulk specialisation/preset/template), Research, Ship Designer, Fleets list (with battle plans and line order), Diplomacy, Grand Roost, Turn Summary, **Battle Orders card**, Battle Viewer, Settings, Save/Load, Credits, Avipedia, Victory/Defeat. [STRETCH: Race Designer.]
- **Turn summary**: Research, Production (with "why queued"), Colonies, Military (battles + autopsy line + replay), Diplomacy, Grand Roost, Events, PNN, Governor log. Every row has Go-to; decisions are pinned; flavour notifications per COPY_PLAN §J.
- **Screenshot staging** (red team): the range strip with band words; the Defy card listing the leaders at war with you; the capitulation card; the Perch Review panel with stars; an audible honk on the Goose border taunt; map climate labels Ice and Jungle.
- **Tooltips**: every number via the modifier engine; every part, building, tech, trait and event from data + copy.
- **VFX**: shapes only; bird silhouettes per empire; stars with diffraction spikes; planets as shaded circles; Talons as tapered strokes, Beaks as streaks, Horizon as darts with trails; sparks and feathers on hits; debris on death; shields as a faceted, noisy arc segment facing the shot; no ring/doughnut base shapes.
- **Hotkeys** (browser-safe): Enter/Space end turn; Esc; G/C/R/D/F/P/U/T screens; N next decision; Tab colonies; Home capital; WASD/wheel; 1-5 overlays; Ctrl+Z/Y undo/redo; Q/L quicksave/load; H help; battle viewer Space/1-3/S; Battle Orders card Enter accepts.

---

## 16. Accessibility and settings [MVP]

- Okabe-Ito empire colors plus glyphs; high-contrast option.
- **Atkinson Hyperlegible (SIL OFL 1.1, `assets/fonts/`) is the default UI font**, minimum 14 px at 100%; UI scale 75-200%.
- Reduce motion; battle speed default; Battle Orders setting.
- Volumes (Master/Music/SFX/UI); mute on focus loss.
- Manual saves, autosave every turn (rolling 3), quicksave; browser-safe `user://` with a persistence warning.

---

## 17. Balance, verification and the playtest gate

### 17.1 Formula index

| Quantity | Formula | § |
|---|---|---|
| Growth | `(P(M-P)/M x 10% + 50) x (100+g)%` milli | 5.2 |
| Food surplus | 2 food = 1 credit | 5.3 |
| Supply lines | -10% per 5 pc beyond 15 pc (max -30%) | 5.4 |
| Research cost | `30 x tier²`; unchosen T1-T4 option after +2 tiers at 150%; T5-T6 forks final | 6.1-6.2 |
| Miniaturisation | `max(50, 100 - 15 x tiers above)%` | 7.2 |
| Movement | Above the closer's P: `D -= max(1, s_c - min(s_o, 12 - D))` (contested), floor P_c; at P_c the opener pulls away by `max(0, s_o - s_c)` | 9.3 |
| To-hit | `clamp(60 + acc - eva - Beak 6D, 5, 95)` | 9.5 |
| Pledge price / cap | `10 x votes x (1 + 4 x share)`; ≤ 15% of votes | 12.3 |
| Coalition | power `fleet PP/20 + 3 x colonies + pop/2` ≥ 35% (30% notorious), from T40; ends Cut Down (20-turn cooldown) or Held after 25 turns (Acknowledged) | 12.4 |

### 17.2 Soak balance targets (gate for the balance phase)

**Method**: 280 games, Evening Standard, Flighted, Seat the Swans OFF. The 4 AIs per game are drawn from all 70 four-race subsets of the 8 races, each subset used 4 times. Each race appears in exactly 140 games (50%), and every pair co-occurs equally. Every game has exactly one winner (Called Game included), so `Σ_race (wins_r / 140) = 280 / 140 = 2.0`: conditional win rates average 25%.

**Gate rule for win rates** (revision 4; round 2: interval overlap is not confirmation): the **point estimate** must lie in the band; the 95% Wilson interval is printed beside it as the uncertainty. If a point estimate is outside its band but its interval overlaps the band, the run is **inconclusive**, not failed: run another 280 games with fresh seeds and judge the pooled n = 280 per race on its point estimate. A point estimate outside the band whose interval lies entirely outside it fails at once.

| Metric | Target | Gate rule |
|---|---|---|
| Swans conditional win rate | 40% (35-45) | Point estimate in band (n = 140 → interval ±8, printed) |
| Each other race | 15-35% | Point estimate in band. Consistency: with Swans at 40%, the other seven average 22.9% |
| Games ending before the cap | ≥ 90% | Point estimate |
| Victory mix | Conquest ≥ 30%; Grand Roost 10-35%; Exodus ≥ 5%; Called Game ≤ 10% | Point estimates (the minimums sum to 45% ≤ 100) |
| Grand Roost wins before T120 in games with Ducks | ≤ 1/3 of those games | Point estimate |
| Coalition trips | ≥ 50% of games | Point estimate |
| Coalition bite (revision 4; replaces "power fell 5 points") | In ≥ 50% of trips the leader **lost a colony or fought a defensive battle at one of its colonies** within the trip | Point estimate |
| Coalition report (no gate) | Trips per game, Cut Down vs Held, captures during trips, capitulations and Called Games in games with ≥ 1 trip, end turn after the last trip | Reported |
| Colony payback (no gate) | Median turns until a new colony's cumulative net PP + RP + credits repays its Nest Ship (65 PP + 1 pop), by distance band and climate | Reported; feeds the H3 decision on expansion costs |
| Median end turn (AI-only) | 120-180 | Point estimate (AI turns are not human turns; see §17.4) |
| AI starving > 10 turns; rejected AI commands; invariant violations; script errors | 0 | Hard |

A second 40-game run with Seat the Swans ON (the default experience) reports the same metrics without a gate. Runtime: 280 games x ~90 s native / 8 processes ≈ 55 min.

### 17.3 Scripted strategic probes (headless; gate alongside the soak)

| Probe | Pass |
|---|---|
| P1a Capital assault (smoke) | Fixed fixture (`test/probes/p1a_capital.json`): a Flighted AI attacker with **+100% industry** (a difficulty-style modifier; starting assets equal) at war from turn 1 with a **passive** defender whose capital has Horizon Perch, Talon Batteries, Colony Mantle (buildings are one per colony, so "x2" became two defense buildings) and a **4-ship guard squadron** parked in orbit; the fixture grants both sides the same T1-T3 techs. Pass: the capital is captured within **25 turns** in **10 of 10** fixed seeds. A floor, not a threat test |
| P1b Contested war | Parity economy: two Flighted AIs with **full planners** (the defender builds, reinforces and intercepts), adjacent homeworlds 14 pc apart, war declared at the fixture's T30 state (`test/probes/p1b_contested.json`). Pass over 10 seeds: the attacker takes or razes ≥ 1 defender colony or outpost within 40 turns in ≥ 6 seeds; the defender's response (P5) fires in every seed with a visible strike; no seed ends with zero battles |
| P2 Surprise defenses | After a failed strike, the next strike on that target has ≥ 1.5x the defense met; ≤ 2 failures per target per 20 turns |
| P3 Stale intel | No strike launched on intel older than 10 turns without a re-scout |
| P4 Invasion logistics | Boot Ships land within 1 turn of orbit control in ≥ 80% of AI invasions |
| P5 Defense response | Visible threat within 3 turns → reinforcement or defense queued within 2 turns |
| P6 Range pairings | Every posture pair x speed pair (0-5) x start (0-12) follows the §9.3 rule; every closer reaches its P within `D0 - P_c` rounds; the §9.3 table reproduces exactly (table fixture) |
| P7 Grand Roost | No Supreme Bird before the second session; pledge cap and electability hold |
| P8 Manual gap (report) | Tutorial seed: Frontier→Industry vs locked Breadbasket on a high-farm, poor-mineral world at T40; reported, and investigated if the gap is < 10% |
| P9 Orders matter (report) | 40 fixture battles (mixed bands, speeds, sizes): each is resolved under every posture x target-priority pair for the player side against fixed AI orders. Reported: the share of battles where the best and worst order sets differ in winner or in own PP lost by ≥ 15%. Investigated if < 50% |
| P10 AI precompute is a cache | 20 seeds x 30 turns: AI economy commands computed at turn start (then random player planning commands applied) equal those computed at End Turn; state hashes equal |

### 17.4 What the soak cannot verify — human playtest gate (before public release)

The soak verifies termination, stability, determinism, native performance, gross balance between AIs, victory mix, AI expansion and war mechanics, and coalition behaviour. It cannot verify human decision time, session length, whether decisions are interesting, UI clarity, whether the AI threatens a competent human, copy, browser performance, or itch save persistence. Gate: **5 recorded browser playtests** (≥ 2 by 4X veterans) on the itch build, Evening Standard, Flighted:

| # | Check | Pass |
|---|---|---|
| H1 | Wall clock to game end | Median ≤ 110 min; none > 130 min (the cap protects) |
| H2 | Decision time per turn band (§2.3) | No band > 25% over budget |
| H3 | Settling | ≥ 3 of 5 players postponed a Nest Ship at least once for something else |
| H4 | Colony decision | Players changed ≥ 2 specialisations or presets after T40 without being prompted |
| H5 | Battle agency | Players changed orders on ≥ 30% of Battle Orders cards and can explain one battle's outcome from the autopsy |
| H6 | AI threat | At Flighted, the seated early-war AI took or razed ≥ 1 player colony or outpost in ≥ 3 of 5 games |
| H7 | Swans | The Coalition visibly attacked Swans in every game where it tripped against them |
| H8 | Endings | Every game ended by a door before the cap, or the player could name the nearest door on the victory clock |
| H9 | Web perf | BRIEF "Performance target": no End-Turn frame > 50 ms, galaxy map 60 fps, battle viewer ≥ 30 fps, measured in Chrome with the CPU throttled 4x and spot-checked in Firefox, Edge and Safari; mouse-only playable at 1280x720; initial download < 25 MB; saves survive a browser restart on the itch page |
| H10 | Copy | Each tester screenshots ≥ 1 line unprompted (soft) |

---

## 18. MVP scope and cuts

**MVP (first public build)**:
- Presets: Tiny + Evening Standard.
- Empires: 8 premades (the first playable milestone has 4: Swans, Pheasants, Ducks, Geese).
- Research and ships: 6 fields x 6 tiers (108 techs); 5 hulls; the parts in §7.3; 24 buildings.
- Economy: presets, specialisations (Forge/Academy/Yard), military budget, governor log, refit; pooled food; expansion costs.
- Diplomacy: espionage (one target); treaties, pledges, Grand Roost, Coalition.
- Combat: Battle Orders, range strip, line, autopsy and viewer; blockade, bombardment and invasion; Guardian + 2 Leviathans; wormhole.
- Endings: 6 events (§20); capitulation; 3 victories + Called Game + victory clock.
- Platform: saves; tooltips; hotkeys; accessibility; two-tier audio; credits screen.

**Cut to STRETCH** (each requires a green MVP evening first): Race Designer screen; nebulae; repeatable Hyper-Preened techs; Medium/Large presets; the other 14 events; The Big Quiet; The Moulted; sabotage and framing; governor revert; Granary/Bastion; terraforming beyond Climate Tailoring; mixed-species colonies; Natives special; local Feats; web save import/export; key rebinding; abandon colony.

**Rejected cuts** (from Codex's MVP list):
- 4 fields x 5 tiers: 6 x 6 is kept because each field carries a counter in the combat triangle or the expansion lever, and the names are the marketing.
- Dropping the Guardian, espionage, events and 4 of 8 empires: the roster, the Orion fight and the Crows are the brief's meme core. Scope is controlled by phase order instead (ARCHITECTURE §16).

---

## 19. Open questions

Round 2's questions are answered in §23. Open for the build: the Creative price and Coalition numbers (measured by the soak, §17.2), and expansion costs (H3 + the payback report).

---

## 20. Random events

From T20, there is a 4% chance per turn of a random-pool event (keyed); triggered events fire on their condition. Lucky empires never take negative events. Choice events show cost and prize; the AI picks by personality.

| id | Kind | Effect | Status |
|---|---|---|---|
| tier_list_leaks | Triggered | First Coalition trip: PNN bulletin; §12.4 applies | MVP |
| guardian_of_orn | Triggered | First exploration of Orn: reveal card + warning volley | MVP |
| snowball_named | Triggered | Coalition-power leader for 10 straight turns: leader +10% growth and credits for 15 turns; everyone gets one bulletin of its fleet and colony totals | MVP |
| perch_review | Periodic (player) | Every 40 turns from T40: 5 stars (won a ≥ 2:1 battle or finished a T5+ tech in the last 20 turns) → industry +10% for 20 turns; 2 stars (no tech and no building in 20 turns) → -10% for 10 turns + idle colony highlighted; otherwise 3 stars | MVP |
| placid_until | Triggered | First Heart of the Roost: the lowest-aggression AI becomes Placid, Until (aggression +5, war ratio x0.7); if the player owns it: Arm (-20 with all, keep) / Mothball (part forbidden, +10 with all) | MVP |
| midgame_sit | Triggered | First turn after T70 with no war and no victory clock above 60%: Rivalry (+10% industry 10 turns, -10 with the named empire) / Pull the Grand Roost (next session in 5 turns) | MVP |
| pond_scum_leviathan, letter_of_marque, corner_colonist, spreadsheet_you_wanted, called_to_the_grand_roost, tall_shapes, henhouse_war, mineral_strike, derelict_hull, data_moult, bountiful_season, feather_plague | — | As revision 2 (effects in git history and COPY_PLAN) | STRETCH |
| pure_missile_honesty | — | Rejected (designs are space-based) | — |

---

## 21. Meme-bible merge ledger (updated)

Design ideas:

| # | Idea | Disposition |
|---|---|---|
| 1 | Colony grain | Presets + specialisation |
| 2 | Evening Standard | Adopted with seating, 24 stars, cap 200, victory clock |
| 3 | Bands + autopsy | Adopted; battles 8-10 s |
| 4 | Retreat receipt | Adopted; always paid |
| 5 | Fleet cap | Battle line of 8 with player line order |
| 6 | Automation digest | Governor log (revert STRETCH) |
| 7 | Trade memory | Exodus keys locked + transfer limit |
| 8 | Coalition | Adopted with forced aggression |
| 9 | Named cheats | Adopted |
| 10 | Bills, not slot machines | Adopted |

Rejected: the Roost Law field, the Mandate gate, pollution, morale, vassalage, lanes.

Numbers changed from the bible (unchanged from revision 2 unless marked **revision 3**):

| Empire / item | Bible | Here |
|---|---|---|
| Swans | research +25%; damage +15%; +1 movement; research cost -15%; relations -40 | good_science; accuracy +20; fast_ships; cost cut dropped; notorious -20 |
| Ducks | trade +30%; growth +15%; weapons -20%; Any Puddle | x2 treaty income; growth +50%; accuracy -20; ≥ 3 pop/size |
| Owls | research +40%; factories -25% | good_science + Night Hours; poor_industry; Wide-Eyed 6 picks + Mean Aim (**revision 4**) |
| Penguins | piscivore, habitability, Huddle | Fish table, tolerant floor, heat cap, Huddle full repair |
| Crows | omniscient | informants (**revision 3**) |
| Geese | ground +30%; fleet cap 9 | +25%; battle line 10 |
| Chickens | industry +35%; costs -25%; One-Note; Nothing Wasted | good_industry + unification; buildings -25%; choose one, sibling never offered (**revision 3**; was random); rush-buy |
| Difficulty | Flighted +10% | 0; Ledger strengthened |
| Exodus | two keys | Two keys + every field ≥ T5 (**revision 3**, 6-tier tree) |
| Guardian | scales with the strongest fleet; top beam as loot | Fixed strength; loot no longer includes the top beam (**revision 3**) |
| Grand Roost | — | From T50, first session non-binding |
| Evening Standard | cap 250 | Cap 200 (**revision 3**) |

---

## 22. Red team 1 disposition

C = Codex (`redteam/codex_redteam_1.md`), G = Grok (`redteam/grok_redteam_and_copy_1.md` Part A).

| # | Finding | Severity | Disposition | Resolution |
|---|---|---|---|---|
| C1 | Session length vs 250 cap | BLOCKER | ACCEPT | §2.3 arithmetic on measured decision time; cap 200; 36-node tree; H1/H2 playtest gate |
| C2 | Expansion autopilot | MAJOR | ACCEPT | Pop drain, admin upkeep, supply lines, outpost razing, blockade, 30% habitable beyond 9 pc (§5.5, §3.2); H3 |
| C3 | Presets last colony decision | MAJOR | ACCEPT | Specialisations with opportunity cost and retooling (§5.6); H4, P8 |
| C4 | Capital auto-warships vs AI share | MAJOR | ACCEPT | Empire military budget; governors stop at the target; "why queued" (§5.7) |
| C5 | Stand Off locks range at 5 | BLOCKER | ACCEPT | Shared-distance rule with edge (§9.3); P6 fixtures |
| C6 | Little battle agency | MAJOR | ACCEPT | Battle Orders card: posture, target priority, Swat mode, line order, retreat (§9.2-9.4); H5 |
| C7 | Retreat / tractor / cloak conflicts | MAJOR | ACCEPT | Single `R` rule, receipt always paid, cloaked ships fire (§9.5-9.6) |
| C8 | Early bombardment erases pop | MAJOR | ACCEPT | Only bomb parts kill pop; guns blockade (§10) |
| C9 | Choose-one loses force | MAJOR | ACCEPT | +2 tiers wait + 150%; transfer limit; One-Note strict; Creative knob measured (§6.1) |
| C10 | Pledges buy a T50 win | BLOCKER | ACCEPT | Non-binding first session, electability 30%, pledge cap 15%, leverage pricing, no self-charisma (§12.3); P7 |
| C11 | Coalition only relations | MAJOR | ACCEPT | Forced aggression, combined power, shared vision/range, common target, 25-turn limit + cooldown, T40 floor (§12.4); H7 |
| C12 | Soak targets impossible | BLOCKER | ACCEPT | Balanced 280-game design, conditional rates summing to 2.0, CI-based gates (§17.2) |
| C13 | Soak can't prove session or fun | MAJOR | ACCEPT | §17.4 scope statement + H1-H10 |
| C14 | AI competence untested | MAJOR | ACCEPT | Stale intel, strike resizing, logistics, defense response, command hygiene (§13.3) + probes P1-P5 |
| C15 | Web frame stalls | MAJOR | ACCEPT | Per-planner bounded sub-steps ≤ 8 ms; max-frame metric (ARCHITECTURE §7.3, §10); H9 |
| C16 | Undo snapshot cost | MAJOR | ACCEPT | Compact per-command deltas with a byte cap (ARCHITECTURE §4.5); itch persistence in H9 |
| C17 | Code UI vs iteration; JSON export | MAJOR | ADAPT | Code-built kit kept; every phase exports to web with captures; copy from P2; mechanics before the balance phase; JSON include-filter test (ARCHITECTURE §11, §16) |
| C18 | MoO-coined names | MINOR | ACCEPT | All replaced with Grok Part B names; do-not-ship list in COPY_PLAN; title/faction trademark check is an owner pre-release item |
| C-MVP | Recommended cuts | — | ADAPT | §18: cut Race Designer, nebulae, repeatables, 14 events, larger presets; kept 6x6, 8 empires (4 first), Guardian, espionage |
| G1 | Starter kit has the winning band | High | ACCEPT | No Horizon at start; Hatch Dart a T1 option; Swat Mount a T2 core; 3 salvos, 5 damage (§7.3 check) |
| G2 | Dead STRETCH buttons | BLOCKER | ACCEPT | Every option has an MVP effect; dead ones removed from the tree |
| G3 | Fork is a coupon; corridor clicks | High | ACCEPT | +2 tiers wait; one prompt per node with queue (core granted) |
| G4 | Line order by tonnage | High | ACCEPT | Player line order; role-based default (§9.3) |
| G5 | Fights are a standing order + replay | High | ACCEPT | Battle Orders card; range strip; first wave drawn; receipt kept on Instant Regret |
| G6 | Swans optional on the map | High | ACCEPT | Forced Coalition aggression; target 40 ± 5; picks unchanged |
| G7 | Ducks win by ballot | High | ACCEPT | No self-charisma, 15% pledge cap, first session non-binding, soak check |
| G8 | Penguins/Crows/Chickens/Geese card | High | ACCEPT | Yield precedence rule; Crows informants not omniscient, pick-1-of-3 steals, one target; One-Note choose-one; V-Formation plurality band |
| G9 | Guardian pays the top beam | High | ACCEPT | Loot = Orn-Plating + 2 non-weapon techs |
| G10 | Food mint; manual gap | Medium | ACCEPT | Surplus 2:1; probe P8 |
| G11 | Museum of legal ships | Medium | ACCEPT | Dumb refit in MVP (§5.7) |
| G12 | Polite default opponents; score targets the library | Medium | ACCEPT | Evening Standard seating; Coalition power excludes tech |
| G13 | Staged screenshots | Low | ACCEPT | §15 |
| G14 | Outposts are paint | — | ADAPT | Outposts razed by an orbiting hostile fleet (no defensive mount) |

---

## 23. Red team 2 disposition

C = Codex (`redteam/codex_redteam_2.md`, verdict BUILD WITH AMENDMENTS), G = Grok (`redteam/grok_redteam_2.md`). AQ = ARCHITECTURE §18 question. Both families agreed on every BLOCKER.

| # | Finding | Severity | Disposition | Resolution |
|---|---|---|---|---|
| C1 / G2 | Equal-speed Close vs Stand Off freezes D at 10 (C5 unresolved) | BLOCKER | ACCEPT (rule replaced) | §9.3: closer/opener rule; contested rounds shrink D by `max(1, s_c - s_o')`; opener pulls away only at the closer's number and only if strictly faster; proof + table; stalemate carry-over (§9.7); P6 covers P x s 0-5 x D0 0-12. Grok's "same speed drifts toward the shorter preference" is the same idea generalised to every speed |
| C2 / G1 | Several cards per turn vs ~25 per game; colony trigger; orders may not matter; combined fleets undefined | MAJOR | ACCEPT | §9.2: one stop per turn, ≤ 3 cards (largest), the rest auto; Big trigger needs ≥ 1 own armed ship and 3+ armed on either side or a bomb part; no colony trigger; range projection line; combined-fleet plan rule; P9 measures whether orders matter. The line editor stays in the fleet panel (G1) |
| C3 / G3 | Pop drain regrows in ~3 turns, not 8; supply lines starve frontier food | MAJOR | ACCEPT (correct, do not raise) | §5.5 corrected arithmetic; costs not raised; prospect line; soak payback report; §5.4 supply lines exempt food |
| C4 / G4 | Coalition loops 25/15 without an ending; NAP deletes duty; strikers arrive piecemeal; "power -5" is a weak metric | MAJOR | ACCEPT | §12.4: power formula split from votes; duty ignores NAP/Trade (Alliance exempts); strike pair with combined sizing and a shared arrival turn; every Coalition ends Cut Down (20-turn cooldown) or Held (Acknowledged: no more Coalitions, AI bandwagon votes); §17.2 "bite" metric + outcome report |
| C5 / G5 | AI pledge refusal makes the 52% route illegal; unpledged votes unspecified; hunt and ballot aim at the same bird | MAJOR | ACCEPT | §12.3: refusal deleted (15% cap is the anti-buyout); unpledged vote order; three routes printed; Coalition power no longer pop-led. Electability 30%, cap 15%, non-binding first session and no self-charisma kept |
| C6 / G6 | "+2 tiers" can never unlock T5/T6 siblings; Creative overpriced/unmeasured | BLOCKER | ACCEPT (ADAPT price) | §6.1: T1-T4 siblings after +2 tiers at 150%; Hyper-Preened (T5-T6) forks are final (trade/theft/capture/Cache only); Creative grants both on the same completion. §6.2: Creative repriced 8 → 6 (between Grok's 5 and 8, because final forks make Wide-Eyed's late value permanent); Owls take Mean Aim with the freed 2; `creative_tier_cost_pct` stays 0 until the soak says otherwise |
| C7 / G7 | P1 "2x economy" ambiguous; passive capital proves only overwhelming force; plan timing | MAJOR | ACCEPT | §17.3: P1a fixed fixture, +100% industry, 4-ship guard, 25 turns, 10/10; P1b parity contested war vs a reinforcing AI. §13.3: economy planners precompute during the player turn (pure cache, proved by P10 and a GUT test), war planners at End Turn |
| C8 / G8 | Hand-written per-command revert is brittle; undo vs replay log diverge | BLOCKER | ACCEPT (mechanism differs from both proposals) | ARCHITECTURE §4.5: undo = restore the start-of-turn snapshot (checkpointed every 10 commands) and replay this turn's command list minus the last; no command implements revert, so there is nothing to keep in sync. The replay log is the turn's command list by construction. Budget ≤ 200 ms web at T150, measured in P05 (`tools/perf/undo_bench`); fallback: player-scope snapshots. Chosen over Grok's `set_value` recorder because a literal builder that writes one direct assignment silently breaks a recorder, while snapshot+replay has no per-command code at all |
| C9 | Wilson overlap is a loose gate | MAJOR | ACCEPT | §17.2: point estimate gates; interval printed; inconclusive → pooled rerun |
| C10 | Round-1 blocker audit (C1 partly, C5 open, C10, C12 resolved) | — | NOTED | C5 closed by C1 above; C1 session length stays gated by H1/H2 |
| G-open | G5 (equal speed), G6 (treaty cancels hunt, piecemeal arrival), G3 (substitute next tier, Creative head start), G12 (seating line unwritten, NAP adjourns), G13 (screenshot words) | — | ACCEPT | G5 → C1; G6, G12 NAP → C4; G3 → C6 (Ink Dart as the T2 second chance into Horizon is kept on purpose: it costs the WE2 choice); G12 seating line and G13 words → COPY_PLAN GROK2 rows |
| G-copy | Ten copy lines (battle orders, expansion tips, electability, Defy, duty, capitulation, seating) | — | ACCEPT with 2 REWRITES | COPY_PLAN §M: adopted; `battle.orders.odds` and `coalition.duty_tip` rewritten to the revision-4 rules |
| AQ1 | Battle Orders pause vs determinism/saves | — | ANSWERED | Orders for all of a turn's battles are collected before any resolves; saves are between turns only; the stop is not saveable |
| AQ2 | Incremental AiMilitary vs player-turn planning | — | ANSWERED | Both: economy precompute in the player turn, war planners sliced at End Turn (C7) |
| AQ3 | Per-command revert maintainability | — | ANSWERED | Replaced (C8) |
| AQ4 | pck boot check vs real browser smoke | — | ANSWERED | pck boot check every phase; a real-browser boot (local static server, screenshot) is part of every phase's acceptance from P00 (PLAN.md) |
| AQ5 | Ship both audio tiers or bake the choice | — | ANSWERED | Ship both (open SFX ≤ 1.5 MB); runtime resolution keeps one code path |
