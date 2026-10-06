# Foul Fowl 4X — Technical Architecture

Architect pass, 2026-10-06. Status: DRAFT for red team. Engine: Godot 4.6.2, GDScript, static typing. Companion: `GDD.md` (what), `BRIEF.md` (why).

This document is written for the builder agent. Section 16 is the phased build plan; sections 1-15 are the contracts it builds against. Section 17 lists the traps that will otherwise cost a day each.

---

## 1. Non-negotiables

1. **The simulation is pure data.** Everything under `src/sim/` is `RefCounted` classes and static functions. No `Node`, no scene tree, no signals, no autoload references, no `Time`, no `randi()`/`randf()`, no floats in state or decisions. It runs identically in a headless test, in the soak tool, in the editor and on the web.
2. **Determinism.** `(seed, settings, ordered command log) -> identical state hash`, on every platform. Integer math only in the sim; every random draw comes from a keyed stream (§4.4); every iteration over a collection is in ascending id order.
3. **One command API.** The player UI and the AI mutate the game only by submitting `Cmd` objects the sim validates (§4.5). There is no second path.
4. **The AI sees only what the player would see**, plus any vision printed on the difficulty card (GDD §13.1) — enforced structurally by `AiView` (§8.1), not by discipline.
5. **Presentation replays, never decides.** The battle viewer plays a `BattleLog` produced by the resolver. Skipping, watching, replaying and headless all yield the same result.
6. **Web-first.** Single-threaded web export (no `Thread`, no `WorkerThreadPool`, no `SharedArrayBuffer`). Long work is time-sliced across frames (§7.3).
7. **Content is data.** Races, traits, techs, hulls, parts, buildings, presets, events, monsters, balance constants and copy live in JSON under `res://data/` (§5).

---

## 2. Project layout

```
project.godot
export_presets.cfg               Web (threads off) + Windows Desktop
addons/gut/                      GUT 9.6.0, vendored (copy of C:/Dev/InfiniteEmpire/addons/gut, MIT)
data/
  balance.json                   every tunable constant (GDD formulas reference these keys)
  galaxy.json                    sizes, star types, climate/size/mineral tables, specials
  traits.json  races.json  personalities.json  difficulty.json
  techs.json   hulls.json  parts.json  buildings.json  presets.json
  events.json  monsters.json  audio.json
  copy/en.json                   all player-facing strings (writer-owned, §5.4)
audio/music/*.ogg  audio/sfx/*.ogg  audio/CREDITS.md
fonts/                           (empty by default: Godot's built-in font is the plan; optional owner-approved OFL swap)
src/
  sim/                           PURE DATA. No Node, no autoload, no float.
    core/        Rng.gd IntMath.gd Ids.gd StateHash.gd Log.gd
    defs/        ContentDB.gd DefLoader.gd Stats.gd  (+ typed Def classes: RaceDef, TraitDef, TechDef, PartDef, HullDef, BuildingDef, PresetDef, EventDef)
    model/       GameState.gd GameSettings.gd StarSystem.gd Planet.gd Colony.gd QueueItem.gd
                 Empire.gd Species.gd TechState.gd ShipDesign.gd Ship.gd Fleet.gd
                 Knowledge.gd Relation.gd Treaty.gd CouncilState.gd
    gen/         GalaxyGenerator.gd NameGen.gd
    rules/       Modifiers.gd Economy.gd Growth.gd Production.gd Governor.gd Research.gd
                 DesignRules.gd AutoDesign.gd Movement.gd Colonization.gd Visibility.gd
                 GroundCombat.gd Bombardment.gd Espionage.gd Diplomacy.gd Council.gd
                 Events.gd Victory.gd Score.gd
      combat/    CombatResolver.gd CombatParty.gd CombatUnit.gd Targeting.gd BattleLog.gd
    commands/    Cmd.gd CmdColony.gd CmdResearch.gd CmdDesign.gd CmdFleet.gd CmdDiplo.gd CmdMisc.gd
    turn/        TurnProcessor.gd TurnReport.gd
    ai/          AiPlayer.gd AiView.gd AiAssess.gd AiResearch.gd AiDesign.gd AiColonies.gd
                 AiExpansion.gd AiMilitary.gd AiProduction.gd AiDiplomacy.gd AiEspionage.gd
    save/        Serializer.gd Migrations.gd
  autoload/      Settings.gd Session.gd Sfx.gd Copy.gd
  main/          Main.tscn Main.gd CaptureMode.gd
  ui/
    kit/         Ui.gd ThemeFactory.gd Palette.gd DataTable.gd StatTooltip.gd IconDraw.gd
    screens/     ScreenBase.gd UiRouter.gd MainMenu.gd NewGameScreen.gd RaceDesignerScreen.gd
                 GalaxyScreen.gd TopBar.gd ColonyPanel.gd ColoniesListScreen.gd ResearchScreen.gd
                 ShipDesignerScreen.gd FleetPanel.gd FleetsListScreen.gd DiplomacyScreen.gd
                 CouncilScreen.gd TurnSummaryScreen.gd BattleScreen.gd SettingsScreen.gd
                 SaveLoadScreen.gd AvipediaScreen.gd VictoryScreen.gd HelpOverlay.gd
  render/
    common/      BirdShapes.gd EmpireStyle.gd
    galaxy/      GalaxyMapView.gd MapCamera.gd StarfieldLayer.gd NebulaLayer.gd StarLayer.gd
                 FleetLayer.gd OverlayLayer.gd
    battle/      BattleStage.gd BattlePlayer.gd ShipGlyph.gd VfxLayer.gd
test/
  unit/  integration/  fixtures/      (GUT; see §15)
tools/
  run_tests.py                   wraps Godot+GUT, scans log, sets exit code
  soak/ soak_main.gd run_soak.py  AI-vs-AI full games, balance report
  audio/ manifest.json import_audio.py
  check_build_size.py
docs/design/                     GDD.md ARCHITECTURE.md BRIEF.md
```

Rule of thumb for the builder: if a file under `src/sim/` needs `extends Node`, `get_tree()`, an autoload, or a float, the design is wrong; stop and restructure.

---

## 3. Autoloads

Kept to four, all presentation-side. The sim never references them (`-s` tool scripts compile before autoloads exist, and tests must not need them).

| Autoload | Role |
|---|---|
| `Settings` | User prefs (`user://settings.cfg` via `ConfigFile`): UI scale, volumes, battle-watch mode, reduce motion, high contrast, summary filters, hotkey sheet, last new-game options. Emits `changed(key)`. |
| `Copy` | String lookup `Copy.t(key: String, fallback: String = "") -> String` from `data/copy/en.json`; missing keys return the fallback and are logged once (a test lists all missing keys). |
| `Session` | Owns the current `GameState`, `ContentDB`, the undo stack, and the `TurnRunner` (time-sliced `TurnProcessor`). API: `new_game(settings)`, `load_game(path)`, `save_game(path)`, `submit(cmd) -> String` (error or ""), `undo()`, `redo()`, `end_turn()`. Signals: `state_changed(scope: StringName, ids: Array[int])`, `turn_processing(progress_pct: int)`, `turn_started(report: TurnReport)`, `battle_ready(log: BattleLog)`, `game_over(result: Dictionary)`. |
| `Sfx` | Audio: `Sfx.play(id: StringName)`, `Sfx.music(state: StringName)`; pools and buses (§13). |

---

## 4. Simulation core

### 4.1 State model

`GameState` (RefCounted) is the whole game:
```
seed: int                         # 31-bit positive, from the shareable seed string
settings: GameSettings            # size, difficulty, toggles, rules version
turn: int
next_ids: Dictionary              # {"fleet": int, "ship": int, "colony": int, "design": int, ...}
systems: Array[StarSystem]        # dense, index == id, immutable after generation except ownership caches
planets: Array[Planet]            # dense, index == id
colonies: Dictionary              # int -> Colony   (iterate via sorted_ids())
empires: Array[Empire]            # dense, index == id; player is id 0; MONSTER_EMPIRE = 100 lives in `monsters`
fleets: Dictionary                # int -> Fleet
designs: Dictionary               # int -> ShipDesign (owned by empires, ids global)
relations: Array                  # Relation per unordered pair, index from Ids.pair_index(a, b)
council: CouncilState
pending: Array                    # deferred effects (event timers, truce timers), sorted by (turn, id)
report: TurnReport                # what happened in the last processed turn (also persisted)
battle_logs: Array[BattleLog]     # last turn's logs (persisted for replay after load)
```
- **Ids** are ints from `next_ids`; never reused. "No id" is `-1`. **Empire 0 is the player and is a valid id**: never gate an id with `> 0`.
- **Positions** are integers in deci-parsecs (1 pc = 10 units). Distance = `IntMath.isqrt(dx*dx + dy*dy)` (integer Newton sqrt). Travel turns = `ceil_div(dist, speed_pc * 10)`.
- A fleet in transit stores `origin_pos`, `dest_system`, `depart_turn`, `arrive_turn`; its current position is derived with integer lerp, never accumulated.
- `Empire` holds: race/species id, traits, treasury, `TechState` (known tech ids, current project, progress, queue, hyper levels), spy/security funding, `Knowledge`, AI personality id (or `""` for human), flags (eliminated, capitulated_to, defied_council).
- `Colony` holds: planet id, owner, species id, `pop_milli`, jobs `{farmers, workers, scientists}`, `locked: bool`, `preset_id`, buildings (Array[String] of building ids), queue (Array[QueueItem]), production progress, occupied_until, garrison, defense_hp.

Every model class implements `to_dict() -> Dictionary` and `static func from_dict(d: Dictionary) -> X`. Defs are referenced by **string id** in state (readable saves); ContentDB resolves them.

### 4.2 Integer math (`IntMath.gd`)

`floor_div(a, b)`, `ceil_div(a, b)`, `pct(v, p) = floor_div(v * p, 100)`, `clamp_i`, `isqrt`, `lerp_i(a, b, num, den)`. GDScript `/` on ints truncates toward zero; every sim division whose operand can be negative goes through `floor_div`. Percent modifiers are summed then applied once: `value * (100 + sum_pct) / 100`.

### 4.3 Determinism rules (enforced by tests in §15)

1. No `float` in `src/sim/` (a grep test fails on `: float`, `float(`, `randf`, `randi`, `Time.`, `OS.` in `src/sim/`).
2. Iterate `Dictionary` collections only via `GameState.sorted_ids(dict)`; arrays of entities are id-ordered.
3. All randomness via `Rng.keyed(...)` (§4.4). There is no RNG state in the save.
4. Simultaneous resolution where order would matter (combat fire, colonisation conflicts): compute all outcomes from the pre-step state, then apply.

### 4.4 Keyed RNG (`Rng.gd`)

- Algorithm: **xoshiro128\*\*** on four 32-bit lanes, every operation masked with `& 0xFFFFFFFF` (all intermediate products stay below 2^63, so GDScript's int64 never overflows).
- Seeding: **FNV-1a 32-bit** over the key parts (each int split into 4 bytes), producing four lanes (lane i hashes the key plus i); an all-zero state is replaced by a constant.
- API: `static func keyed(seed: int, turn: int, stream: int, a: int = 0, b: int = 0) -> Rng`; `next_u32()`, `range_i(lo, hi)` (inclusive), `chance(pct)`, `pick(arr)`, `shuffle(arr)`.
- Streams are an enum in `Rng.gd`: `GALAXY, COMBAT, GROUND, EVENTS, ESPIONAGE, AI, RESEARCH, COLONIZE, LOOT`. Example: the battle at system 12 on turn 57 uses `Rng.keyed(seed, 57, Rng.COMBAT, 12)`. Consequence: adding an AI decision can never perturb a battle roll, and a battle can be re-resolved bit-exact for debugging.
- A golden test pins the first 8 outputs for 3 keys (this is a save-compatibility contract, not a tuning snapshot).

### 4.5 Commands

```gdscript
class_name Cmd extends RefCounted
var empire_id: int
func kind() -> StringName            # "colony.set_preset", "fleet.move", ...
func validate(gs: GameState, db: ContentDB) -> String   # "" = OK, else a player-readable reason (copy key)
func apply(gs: GameState, db: ContentDB) -> void         # only called after validate() == ""
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Cmd             # via a registry in Cmd.gd
```
Planning-phase commands change **orders and settings only** (jobs, preset, queue, buy, research choice, designs, fleet destination/doctrine/split/merge, diplomacy proposals, spy funding, council vote). Outcomes are resolved only in the turn pipeline.

**Undo** (Session): before applying a player command, push `Serializer.to_dict(gs)` (cap 30 per turn, cleared on End Turn). Ctrl+Z restores the snapshot. Full snapshots are chosen over per-command inverses because they are trivially correct for a builder agent; a Standard late-game state is ~200-400 KB of Dictionary, well within budget. If profiling disagrees, switch to inverse commands behind the same API.

**Command log**: Session appends every applied command (player and AI) with the turn to an in-memory log; a debug setting writes it next to the save. `seed + settings + log` replays a game exactly (bug repro tool).

### 4.6 Knowledge (fog of war)

`Knowledge` per empire: `explored: PackedByteArray` per system; `seen_colonies: Dictionary` colony id -> {owner, species, pop_units, buildings_if_in_scan, turn_seen}; `visible_fleets: Array` of snapshots {fleet_id, owner, pos, dest_if_scanner_net, ship_count, design_ids_if_battle_scanner, est_power}; `known_designs: Dictionary` (enemy designs seen in battle or via Battle Scanner); `met: Array[int]` empires. Rebuilt in the `visibility` step every turn. The UI reads foreign objects only through the player's `Knowledge`.

---

## 5. Content data

### 5.1 DECISION: JSON, not `.tres`

- Agent-authored and writer-authored text: diffable, reviewable, no editor needed, no hidden `ResourceSaver` behaviour (it omits fields equal to class defaults, so a `.tres` that "lacks" a field is not unauthored — a known trap in the owner's other project).
- Grok writes `data/copy/en.json` in parallel without touching mechanics files.
- Validated at boot and by tests against typed Def classes (§5.3). Cost: no inspector editing, and **JSON numbers parse as float** — every loader casts with `int()` (trap #1, §17).

### 5.2 File shapes (abbreviated; the builder writes the full files from GDD tables)

```jsonc
// data/balance.json
{ "growth_r": 10, "growth_flat": 50, "tax_per_pop": 1, "food_import_cost": 2,
  "research_base": 20, "hyper_base": 1500, "hyper_step": 300,
  "rush_mult": 2, "rush_zero_progress_mult": 2, "housing_milli_per_pp": 20, "trade_goods_pp_per_credit": 2,
  "base_to_hit": 60, "missile_base_to_hit": 70, "kinetic_range_penalty": 6, "beam_falloff": 4,
  "combat_rounds": 8, "start_distance": 10, "max_advance": 5,
  "occupation_turns": 10, "occupation_output_pct": -50, ... }

// data/techs.json
{ "fields": ["computers","construction","force_fields","planetology","propulsion","weapons"],
  "nodes": [
    { "id": "co1", "field": "computers", "tier": 1,
      "core": "battle_computer_1",
      "options": ["research_lab", "deep_space_scanner"] } , ...],
  "techs": [
    { "id": "battle_computer_1", "unlocks": {"parts": ["computer_mk1"]}, "effects": [] },
    { "id": "deep_space_scanner", "unlocks": {}, "effects": [
        {"stat": "scan_range_colony", "op": "add", "value": 2, "scope": "empire"} ] }, ...] }

// data/races.json
{ "races": [ { "id": "swans", "picks": 13, "traits": ["ship_attack_2","ship_defense_1","ground_1","good_industry","large_homeworld"],
               "homeworld": {"climate": "terran", "size": "large"}, "personalities": ["aggressor","imperialist"],
               "color": "#F5F5F5", "glyph": "crown", "bird_shape": "swan" }, ...] }
```
Every def has `"id"`. Display names are **not** in mechanics files; they come from `copy/en.json` by key `<kind>.<id>.name` (e.g. `tech.deep_space_scanner.name`; scheme in `COPY_PLAN.md`), with the id prettified as fallback.

### 5.3 Effects and the stat vocabulary

All traits, techs, buildings, specials, events and difficulty bonuses express their mechanics as **effects** over a closed vocabulary of stats declared in `src/sim/defs/Stats.gd` (const StringNames). Shape:
```
{ "stat": "<Stats key>", "op": "add" | "pct" | "min" | "flag", "value": int,
  "scope": "colony" | "empire" | "ship" | "planet_defense",
  "when": { "climate_in": [...], "hull_in": [...], "species_trait": "...", ... }   // optional, closed set of predicates
}
```
Examples of stats: `food_per_farmer`, `pp_per_worker`, `rp_per_scientist`, `flat_food`, `flat_pp`, `flat_rp`, `tax_pct`, `growth_pct`, `max_pop_per_size`, `industry_pct`, `research_pct`, `ship_cost_pct`, `building_cost_pct`, `ship_accuracy`, `ship_evasion`, `ship_speed`, `combat_speed`, `fuel_range`, `scan_range_colony`, `ground_strength_pct`, `spy_score`, `security_score`, `relation_base`, `trade_mult_pct`, `upkeep_pct`, `bombard_mult_pct`, flags like `creative`, `uncreative`, `tolerant`, `lucky`, `omniscient`. Content validation fails on any unknown stat or predicate.

### 5.4 Copy layer

`data/copy/en.json` is a flat `{key: string}` map owned by the writer. The key scheme and the mapping of every GDD `[COPY: key]` slot to a meme-bible line or a gap is `docs/design/COPY_PLAN.md`; it supersedes the `name.<kind>.<id>` convention above (use `<kind>.<id>.name`). Keys used by code are listed in `src/autoload/Copy.gd` constants or follow that scheme. A test emits the list of keys the code and content reference and the subset missing from `en.json` (warning, not failure, until Phase 10; failure after).

### 5.5 ContentDB

`ContentDB.load_from(dir: String = "res://data") -> ContentDB` parses every JSON with `JSON.parse_string`, converts to typed Defs (casting numbers to int), builds indices, and runs `validate() -> PackedStringArray` (empty = OK). Loaded once by Session at boot and directly by tests and tools (no autoload). Defs are read-only after load; never mutate a Def at runtime.

---

## 6. Modifier engine and "explain"

`Modifiers.gd` is the single place where effects are evaluated:
```gdscript
static func eval(stat: StringName, base: int, ctx: ModCtx) -> ModResult
# ModCtx: gs, db, empire_id, colony_id (or -1), ship design (or null)
# ModResult: value: int, adds: int, pct: int, lines: Array[Dictionary]  # {source_key, op, value}
```
Order: base -> sum of `add` -> sum of `pct` applied once -> `min` clamps -> gravity/occupation multipliers (expressed as `pct` lines with their own source) -> floor. Sources gathered deterministically: species traits, empire traits, government, known techs, colony buildings, planet special, active events, difficulty (AI only). Every breakdown tooltip in the UI renders `ModResult.lines` with `Copy` names. This is how "every number has a tooltip" is implemented without per-screen code.

Performance: `Economy.recompute_colony(colony)` caches yields per colony each turn (and after any planning command touching it); UI reads the cache.

---

## 7. Turn pipeline

### 7.1 Order (`TurnProcessor.gd`)

| # | Step | Notes |
|---|---|---|
| 0 | `ai_plan` | One sub-step per AI empire, ascending id. Each builds an `AiView` from last turn's knowledge, produces `Cmd`s, which are validated and applied. The human's commands were already applied during planning. |
| 1 | `diplomacy` | Resolve proposals/answers, war declarations, treaty expiries, truce timers. |
| 2 | `movement` | All fleets advance simultaneously; arrivals recorded; wormhole hops; nebula speed. |
| 3 | `combat` | One sub-step per contested system, ascending id. `CombatResolver` -> `BattleLog`; apply losses; set orbit control; veterancy. |
| 4 | `orbital` | Bombardment, then invasions (ground combat), then colonisation and outposts (conflicts: orbit controller wins, else keyed coin). Destroy unarmed ships in systems where an enemy controls orbit. |
| 5 | `production` | Per colony: industry into queue, overflow carry, completions (ships spawn at the colony's system and move to rally point next turn; buildings activate). Rush-bought items complete here. |
| 6 | `research` | RP into current project, completions, queue advance, Creative/Uncreative resolution. |
| 7 | `population` | Empire food balance, auto-import, starvation, growth, overpop decay. |
| 8 | `finance` | Taxes, trade (ramp), surplus food sale, upkeep, Strike flag. |
| 9 | `espionage` | Intel accrual, steal attempts. |
| 10 | `events` | Random events (keyed RNG), timed event effects expire. |
| 11 | `council` | If a session is due: tally (human vote was submitted as a command at the start of this turn), resolve. |
| 12 | `victory` | Eliminations, capitulation offers/acceptance, victory checks, turn cap. |
| 13 | `visibility` | Rebuild every `Knowledge`. |
| 14 | `governor` | Preset job assignment and auto-queue for next turn, so the player starts the turn with a consistent state. |
| 15 | `finalize` | `turn += 1`, finalize `TurnReport`, Session autosaves. |

Every step appends structured entries to `TurnReport` (`{category, kind, empire_ids, refs, values}`); the UI turns them into text via `Copy` keys. The sim never formats strings for players.

### 7.2 Invariants checked after every step in debug and test builds

Pop >= 0; treasury >= 0; every ship belongs to exactly one fleet; every fleet's owner exists and is not eliminated; no colony on an asteroid/gas giant; each planet has at most one colony; tech known sets contain only valid ids; sum of jobs == whole pop units. `TurnProcessor.check_invariants(gs) -> PackedStringArray`; non-empty in tests = failure; in release = logged once.

### 7.3 Time-slicing (web)

`TurnRunner` (in Session) calls `TurnProcessor.run_next_substep()` repeatedly inside `_process` until ~8 ms of the frame are used, then yields to the next frame and emits `turn_processing(pct)`. The galaxy screen shows a progress bar and stays responsive (camera pan works). Headless tools call `TurnProcessor.run_all()`. Sub-steps (per AI empire, per battle) keep each slice small.

---

## 8. AI architecture

### 8.1 AiView — the fairness boundary

`AiView` is constructed per AI empire per turn from `GameState` and that empire's `Knowledge`. It exposes:
- the empire's own entities in full (colonies, fleets, designs, techs, treasury);
- foreign information **only** from `Knowledge` (explored systems, seen colonies, visible fleets, known designs, relations, treaties); declared difficulty vision (Honk Admiral: player designs; Lights-Off Ledger: player colonies and fleets) is written into that empire's `Knowledge` by the `visibility` step, so `AiView` itself never special-cases difficulty;
- static galaxy geometry (star positions, explored planets);
- read-only `ContentDB`, `Modifiers` evaluation for its own objects, and `Rng.keyed(seed, turn, Rng.AI, empire_id, salt)`.

AI modules receive an `AiView`, never the `GameState`. A test (§15) proves isolation: two states that differ only in an unseen enemy fleet produce identical AI command lists.

### 8.2 Planners

`AiPlayer.plan(view) -> Array[Cmd]` calls, in order: `AiAssess` (power, threats, posture), `AiResearch`, `AiDesign` (auto-design by role), `AiColonies` (presets), `AiExpansion` (colony/outpost targets), `AiMilitary` (fleet roles, strike/invasion planning, defend), `AiProduction` (queue top-ups), `AiDiplomacy`, `AiEspionage`. Each reads the personality weights and difficulty from data. Algorithms and thresholds: GDD §13.3. Planners are utility scorers with explicit tie-breaks by id; no search trees.

Persistent AI memory (strike targets, staging points, war goals) lives in `Empire.ai_memory: Dictionary` inside the state (saved, deterministic).

### 8.3 Shared code with the player

Auto-design, auto-explore, auto-colonise suggestions, the governor and power estimates are `rules/` functions used by both the AI and the player's automation, so improving one improves both.

---

## 9. Combat resolver

- Input: system id, the parties (each: empire id, list of `CombatUnit` built from ships and planet defenses with all modifiers pre-evaluated into plain ints), doctrine per party, nebula flag, keyed RNG.
- Output: `BattleLog` + per-unit final HP + retreat set + orbit controller.
- Rules: GDD §9. Implementation notes:
  - Units sorted by (party empire id, unit id). Each party has a **line** (max slots per GDD §9.2: 8, Titan = 2, Geese 10, +1 Hyper-Preened Cognition) and an ordered **reserve** (largest hull, then id). Each round: reserves fill empty line slots -> moves -> missile arrivals (PD first) -> fire (line units only; targets chosen and rolls made against the start-of-step snapshot, damage accumulated into a pending array) -> apply -> launches -> cleanup -> retreat checks.
  - Retreat (GDD §9.6): escape at the end of round 2 (modifiers shift it); the **receipt** destroys the party's slowest ship (ties: most damaged, lowest id), logged as a `retreat_receipt` event.
  - Percent damage modifiers (band traits, v_formation, flush, Hyper-Preened, Guardian-Marked) are pre-summed per unit per round into one integer percent before the roll.
  - Target choice uses expected damage (integer, per-mille) — no floats.
  - RNG draw order is fixed: by unit order then mount index; an **order-independence test** shuffles input order and expects an identical log hash.
- `BattleLog` (compact, persisted for the last turn):
```
{ system_id, turn, nebula, parties: [{empire_id, doctrine, units: [{uid, kind: "ship"|"planet", design_id, hull, hp_max, shield, bird_shape}]}],
  rounds: [{ advance: {empire_id: c}, events: [ [type, src_uid, dst_uid, value, weapon_class], ... ] }],
  result: { winner_empire_id | -1, retreated: [...], destroyed: [...],
            autopsy: { deciding_band: "talon"|"beak"|"horizon", standout_uid, receipt_uid | -1, damage_by_band: {empire_id: {band: int}} } } }
```
Event types: `reserve_in`, `fire_hit`, `fire_miss`, `shield_block`, `missile_launch`, `missile_hit`, `missile_miss`, `pd_kill`, `destroyed`, `retreat`, `retreat_receipt`, `heal`, `suppressed`. The autopsy is computed by the resolver from these events (so the viewer and the summary card agree).

---

## 10. Performance budget

| Item | Budget | Measured by |
|---|---|---|
| Standard AI-vs-AI full game, headless native | median <= 90 s, max <= 180 s | soak report |
| End-turn processing at T200, Standard, native | <= 300 ms total | soak per-turn timings |
| End-turn processing at T200, web (mid laptop) | <= 1.5 s wall, UI >= 30 fps meanwhile | in-game perf overlay (debug setting) |
| AI plan per empire, native | p95 <= 50 ms | soak |
| One battle, 60 units | <= 5 ms native | combat micro-bench in soak tool |
| Galaxy map, web | 60 fps with 54 stars, 200 fleets | perf overlay |
| Battle viewer, web | 60 fps with 400 live VFX primitives | perf overlay |
| Save / load (web) | <= 300 ms / <= 500 ms; file <= 1 MB before gzip | Session timings |

Timing numbers are **not** asserted in the gated GUT suite (they flake); the soak tool fails its own run when a budget is exceeded by more than 2x and prints the measured value.

---

## 11. UI architecture

### 11.1 DECISION: Control UI built in code with a small kit; one scene

The builder is an AI agent; hand-written `.tscn` files are its most error-prone artefact. So: `Main.tscn` is the only authored scene. Every screen is a script extending `ScreenBase` (Control) that builds its children in `build()` with helpers from `Ui.gd` (`Ui.label(text, style)`, `Ui.button(text, cb, tooltip)`, `Ui.hbox()`, `Ui.panel(title)`, `Ui.number(stat_result)` which attaches a breakdown tooltip, `Ui.table(columns)`). `refresh()` re-reads state; screens subscribe to `Session.state_changed` and refresh only for their scope.

### 11.2 Scene structure

```
Main (Node)                               Main.gd: boot, ContentDB, routing, CaptureMode
├─ World (Node2D)                         GalaxyMapView + MapCamera (only while a game is open)
├─ BattleLayer (CanvasLayer, layer 5)     BattleStage (hidden unless a battle plays)
└─ UiLayer (CanvasLayer, layer 10)
   └─ UiRoot (Control, full rect)         UiRouter.gd
      ├─ ScreenHost (Control)             one full screen at a time (menus, research, designer, lists…)
      ├─ HudHost (Control)                TopBar + side panels over the galaxy map
      ├─ ModalHost (Control)              stack: turn summary, council vote, dialogs
      └─ ToastHost (Control)
```
`UiRouter.show_screen(id: StringName, args := {})`, `push_modal(...)`, `pop()`. Hotkeys are handled in one place (`UiRouter._unhandled_input`) from a table in `HelpOverlay.gd` so the help sheet and the bindings cannot drift.

### 11.3 Layout and theming rules

- Base resolution 1280x720, stretch mode `canvas_items`, aspect `expand`. UI scale setting multiplies `get_window().content_scale_factor`.
- `ThemeFactory.build(palette, font, scale) -> Theme` creates the whole theme in code. `font` defaults to Godot's built-in font (`ThemeDB.fallback_font`); an owner-supplied font in `fonts/` is a one-line swap (no `.tres` theme to hand-edit). `Palette.gd` holds color tokens (background, panel, text, accent, positive, negative, warning) plus the 8 empire colors/glyphs; a high-contrast variant.
- **Fixed-width rule** (lesson from the owner's other project): any container whose content changes (button labels with numbers, rows that gain buttons) gets an explicit `custom_minimum_size.x` and clipping; dynamic detail goes into tooltips, never into button faces. Tables use fixed column widths.
- Tooltips: `StatTooltip` (a `PanelContainer` built in `_make_custom_tooltip`) renders `ModResult.lines`.

### 11.4 Screen inventory (what each reads/writes)

| Screen | Reads | Commands |
|---|---|---|
| GalaxyScreen (+TopBar, ColonyPanel, FleetPanel) | state, player Knowledge | fleet.move/split/merge/doctrine/auto_explore, colonize, invade, bombard |
| ColoniesListScreen | colonies, yield cache | colony.set_preset (bulk), apply_template, set_jobs, queue ops, buy |
| ResearchScreen | TechState, techs.json | research.set_project, research.queue |
| ShipDesignerScreen | parts, hulls, known techs | design.save, design.obsolete, design.auto(role) |
| FleetsListScreen | fleets | fleet ops, rally points |
| DiplomacyScreen | relations, treaties, Knowledge | diplo.propose/answer/declare_war, spy/security funding |
| CouncilScreen | CouncilState | council.vote, council.accept_or_defy |
| TurnSummaryScreen | TurnReport, battle_logs | go-to navigation, replay |
| BattleScreen | BattleLog | none |
| RaceDesigner / NewGame | traits, races | (pre-game settings only) |

---

## 12. Rendering

### 12.1 Galaxy map

- `GalaxyMapView` (Node2D) composed of child Node2D layers, each with its own `_draw()` so redraws are scoped: `StarfieldLayer` (seeded background points, drawn once), `NebulaLayer` (noise-jittered translucent polygons), `OverlayLayer` (fuel-range fill, map overlay modes 1-5, selection brackets), `StarLayer` (stars with radial glow and diffraction spikes, planet pips, owner banner + glyph under the name), `FleetLayer` (bird-chevron fleet icons with empire color and glyph, path lines with ETA ticks).
- Scale: 1 pc = 40 px. `MapCamera` (Camera2D): wheel zoom 0.35-3.0, pan by WASD/arrows/middle-drag/edge, Home to capital. Labels drawn with `draw_string` at an inverse-zoom scale so text stays readable.
- Picking: linear scan of stars/fleets within a pixel radius (<= 54 stars; no spatial index needed).
- Redraw only on state change or camera move (layers call `queue_redraw()` from signals). Enable `application/run/low_processor_mode` on desktop.

### 12.2 Battle viewer

- `BattlePlayer` converts a `BattleLog` into timed cues (round length 1.2 s / speed); `BattleStage` positions each party's units in a column at `x = f(c)`; planets at the right edge.
- `ShipGlyph` (Node2D) draws the empire's bird silhouette from `BirdShapes` scaled by hull (small 18 px … titan 70 px), outlined, with a thin HP bar.
- `VfxLayer` is a single Node2D that owns a pooled array of effect structs (Dictionary or small RefCounted) updated in `_process` and drawn in one `_draw()`: beam strokes (tapered quad strip, core + glow, fading tail), kinetic streaks, missile darts with a short particle trail, hit sparks along the impact normal, tumbling feather polygons, debris shards on death, a faceted noisy shield arc segment facing the shot, damage numbers. No GPUParticles (web Compatibility renderer); no ring/doughnut primitives (GDD §15.4). Reduce-motion halves counts and disables shake.

### 12.3 Bird shapes

`BirdShapes.gd` returns `PackedVector2Array` polygons for 8 families (swan, pheasant, duck, owl, penguin, crow, goose, chicken) in three uses: map fleet icon (12-16 px chevron-like silhouette), ship glyph (side view), and race portrait (larger, 2-3 polygons + eye dot) for diplomacy and the race screen. All tinted by `EmpireStyle`.

---

## 13. Audio

### 13.1 Buses and playback

`Master` -> `Music`, `SFX`, `UI`. Volumes only. **No bus effects**: the single-threaded web export plays audio in "sample" mode, where bus effects are not applied, so the mix must not depend on them. `Sfx` keeps a pool of 10 `AudioStreamPlayer`s for SFX (oldest-steal), 2 for UI, 2 for music (crossfade with tweens on `volume_db`). Per-sound cooldown (50 ms) and per-battle cap (6 simultaneous weapon sounds) keep big fights from clipping. All game audio is non-positional (`AudioStreamPlayer`), so stereo files are fine; SFX are still converted to mono to save size.

### 13.2 Sources (from `<FOULFOWL_SOUND_ASSETS>\`)

| Event ids (`data/audio.json`) | Source subfolder | Picks |
|---|---|---|
| `ui_click`, `ui_back`, `ui_confirm`, `ui_open`, `ui_close`, `ui_error` | `kenney_interface-sounds/Audio` (click_, back_, confirmation_, open_, close_, error_), `SCI-FI_UI_SFX_PACK/Clicks` | 6-8 |
| `notify_alert`, `notify_info`, `war_declared` | `Sci-Fi Combat Systems Sound Effects Pack/UI` (SFCS_UI_Alert_Notification1/2) | 3 |
| `turn_end`, `turn_start`, `tech_done`, `colony_founded`, `council_bell` | `SCI-FI_UI_SFX_PACK/Tone1-3`, `SCI-FI_UI_SFX_PACK/FX Sounds` | 5 |
| `fleet_depart`, `fleet_arrive`, `wormhole` | `Shapeforms Audio Free Sound Effects/Sci Fi Warp Speed Preview`, `kenney_sci-fi-sounds` (spaceEngine*) | 3 |
| `beam_fire` (by tier: light/heavy) | `kenney_sci-fi-sounds/Audio` (laserSmall_, laserLarge_, laserRetro_), `Shapeforms-Sci-Fi-Weapons/Sci Fi Weapons 16 44` | 4 |
| `kinetic_fire` | `Sci-Fi Combat Systems Sound Effects Pack/Weapons` (Ballistic_SciFi, Gattling) | 2 |
| `missile_launch` | `Sci-Fi Combat Systems Sound Effects Pack/Weapons` / Shapeforms Cyberpunk Arsenal preview | 2 |
| `hit_hull`, `hit_shield` | `kenney_impact-sounds` (impactMetal), `kenney_sci-fi-sounds` (forceField_) | 4 |
| `explode_small`, `explode_big`, `planet_suppressed` | `kenney_sci-fi-sounds` (explosionCrunch_, lowFrequency_explosion_), `Explosion SFX Pack - 96k/Designed Sci-Fi` | 4 |
| Music `map` (rotating) | `IESunoMusic/empire` — 3 tracks (e.g. "Cartographer of the Outer Throne", "Orbital Workbench", "Gravities of Command") | 3 |
| Music `battle` | `IESunoMusic/combat` | 1 |
| Music `war` (war declared on you / Guardian / endgame) | `IESunoMusic/boss` | 1 |
| Stingers `victory`, `defeat` | `SnakeSunoMusic` VICTORY_1, DEFEAT_1 (trimmed) | 2 |

### 13.3 Conversion and budget

- `tools/audio/manifest.json`: `[{ "src": "<absolute path>", "dest": "audio/sfx/ui_click_1.ogg", "mono": true, "start": 0.0, "duration": 1.2, "fade_out": 0.1, "q": 3 }]`. `tools/audio/import_audio.py` runs ffmpeg for each entry: SFX `-ac 1 -ar 44100 -c:a libvorbis -q:a 3`; music `-ac 2 -ar 44100 -c:a libvorbis -q:a 1`, trimmed to a loopable 120-150 s with a 2 s fade; stingers 20-30 s. It also writes `audio/CREDITS.md` (pack, file, license) and refuses to run if the output exceeds budget. WAV sources are never committed.
- Budget: **SFX <= 1.5 MB** (<= 50 files), **music <= 7 MB** (3 map + 1 battle + 1 war + 2 stingers), **audio total <= 8.5 MB**. Music `.ogg` import: loop enabled for tracks, off for stingers.

---

## 14. Save format and versioning

- Path: `user://saves/<slot>.sav` (slots: `auto_1..3`, `quick`, `slot_1..10`). On web, `user://` is IndexedDB-backed; at boot, `OS.is_userfs_persistent()` false shows a one-time warning ("saves will not persist in this browser mode").
- Write: `FileAccess.open_compressed(tmp, WRITE, FileAccess.COMPRESSION_GZIP)`, store `JSON.stringify(envelope)`, close, then `DirAccess.rename_absolute(tmp, final)` (atomic replace). Read: `open_compressed(..., READ, COMPRESSION_GZIP)`.
- Envelope:
```json
{ "format": "foulfowl-save", "version": 1, "game_version": "0.1.0",
  "created_unix": 0, "turn": 57, "seed_string": "MALLARD-4821",
  "summary": { "empire": "ducks", "turn": 57, "score": 212, "size": "small" },
  "state": { "...": "GameState.to_dict()" } }
```
- `created_unix` is presentation metadata written by Session (the sim never reads time).
- **Versioning**: `version` is the state schema version. `Migrations.migrate(env) -> Dictionary` applies `v1->v2->...` in order; each migration is a pure function with a fixture test (`test/fixtures/saves/v<N>.sav`). Loading a newer version than the game knows refuses with a clear message. Content changes that rename ids require a migration entry.
- All numbers come back as floats from JSON: `from_dict` casts every int field.
- Autosave: after `finalize`, rolling `auto_1..3`. Settings in `user://settings.cfg`.
- [STRETCH] Web export/import of a save file via `JavaScriptBridge.download_buffer` and a file input.

---

## 15. Testing

### 15.1 Tools and commands

- Godot: `C:/Dev/InfiniteEmpire/GodotExe/Godot_v4.6.2-stable_win64_console.exe` (env `GODOT_EXE` overrides; export templates 4.6.2 are installed on the owner's machine).
- First run and after adding any `class_name`: `"$GODOT_EXE" --headless --path C:/Dev/FoulFowl --import`
- Tests: `"$GODOT_EXE" --headless --path C:/Dev/FoulFowl -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
- Wrapper (use this): `python tools/run_tests.py [--filter test_combat]` — runs the above, fails on non-zero exit, on any `SCRIPT ERROR` / `ERROR:` / `Parse Error` line in the log, and if the GUT summary line is missing or reports 0 tests (an all-skipped green is a failure).
- Soak: `python tools/soak/run_soak.py --seeds 1-10 --size small --players 4 --difficulty flighted` -> runs `"$GODOT_EXE" --headless --path . -s res://tools/soak/soak_main.gd -- <args>` per seed, writes `build/soak/report.json` + a markdown summary (end turn, victory type, winner race, per-turn timing p50/p95, colonies/techs curves, invariant violations, script errors). Exit non-zero on: any script error, any invariant violation, any game not finishing by the cap, budget exceeded 2x.
- Windowed capture for visual QA: `"$GODOT_EXE" --path . -- --capture=<screen> --fixture=res://test/fixtures/<name>.json --out=<abs png path>` -> `CaptureMode` loads the fixture state, opens the screen, waits 10 frames, saves the viewport PNG, quits.
- **Never** use `--check-only` (it boots the game and hangs).

### 15.2 What is tested (gated GUT suite)

Invariants and contracts only — no tuning snapshots. A test that pins a balance number is a snapshot and does not belong in the suite; balance lives in the soak report against GDD §17.3.

| Area | Tests |
|---|---|
| Core | Rng golden outputs (format contract), keyed independence, IntMath edge cases (negative floor_div, isqrt) |
| Determinism | Two runs of the same seed for 50 AI-only turns (Tiny) -> equal `StateHash`; save at T25, load, continue -> equal hash to the uninterrupted run; sim grep test (no float/randi/Time/Node in `src/sim/`) |
| Content | All refs resolve; unknown stats rejected; each tech node has exactly 1 core and 1-3 options; each premade race's trait costs sum to its picks; every part's tier exists; every building's tech exists |
| Economy | Growth formula vs hand-computed cases from GDD §5.2; food import and starvation paths; overflow carry; rush cost; governor keeps empire food >= 0 whenever feasible; jobs sum to pop |
| Research | Choose-one locks siblings; Creative gets all; Uncreative is seeded; queue advance; overflow |
| Ships/movement | Design space never exceeded; miniaturisation floor 50%; auto-design deterministic and legal; travel turns; range legality; wormhole; nebula |
| Combat | Order-independence (shuffled input -> same log hash); shields reduce per hit (Talon full, Beak half, nebula none); battle line never exceeds its slots and reserves fill in order; retreat at round 2 with exactly one receipt; PD intercept; planet suppression; battles end <= 8 rounds; 500 random battles without errors or invariant violations |
| Ground | Duel resolution terminates; occupation applied; tech capture keyed |
| AI | `AiView` isolation (unseen fleet does not change commands); AI commands always validate; Tiny 1-seed 60-turn AI-only run without invariant violations |
| Diplomacy/Council | Vote tally and 2/3 threshold; Defy declares war from every voter for the winner; capitulation transfer; each victory type triggers on a fixture |
| Save | Round-trip hash equality; migration fixtures; gzip read/write |
| UI smoke (headless) | Every screen `build()`s against fixture states without errors (Control trees work under `--headless`) |

---

## 16. Phased build plan

Each phase ends **playable or testable on its own**, with all prior tests still green, committed as one PR-sized change. "Accept" items are harness-checkable: a GUT test name, a soak report field, or a capture PNG. Phase file lists name PRODUCT files; tests and data are additional.

**P0 — Skeleton and core** 
Files: `project.godot` (Compatibility renderer, 1280x720, canvas_items stretch, autoloads), `export_presets.cfg` (Web: threads off, include filter `data/*.json`, exclude `test/*,tools/*,docs/*,addons/gut/*`; Windows), `addons/gut/` (vendored), `src/main/Main.tscn`+`Main.gd`, `src/autoload/{Settings,Copy,Session,Sfx}.gd` (stubs), `src/sim/core/{Rng,IntMath,Ids,StateHash,Log}.gd`, `src/sim/defs/{ContentDB,DefLoader,Stats}.gd`, `data/balance.json`, `tools/run_tests.py`.
Accept: `--import` clean; `run_tests.py` green with test_rng, test_intmath, test_content_db; web export builds to `build/web/index.html` and shows a placeholder main menu.

**P1 — Galaxy and map**
Files: `sim/model/{GameState,GameSettings,StarSystem,Planet}.gd`, `sim/gen/{GalaxyGenerator,NameGen}.gd`, `sim/save/Serializer.gd`, `data/galaxy.json`, `render/galaxy/{GalaxyMapView,MapCamera,StarfieldLayer,NebulaLayer,StarLayer}.gd`, `ui/kit/{Ui,ThemeFactory,Palette}.gd`, `ui/screens/{ScreenBase,UiRouter,MainMenu,NewGameScreen,GalaxyScreen}.gd`, `main/CaptureMode.gd`.
Accept: `test_galaxy_gen`: for seeds 1-200 x {tiny, small}: exact star count, separation rule, race-aware fair-start rule, Orn is the most central star, wormhole rule, generation twice -> equal hash; `test_serializer` round-trip; capture `galaxy` PNG shows stars, nebulae, names.

**P2 — Colonies, economy, turn loop** 
Files: `sim/model/{Empire,Species,Colony,QueueItem}.gd`, `sim/rules/{Modifiers,Economy,Growth,Production,Governor}.gd`, `sim/turn/{TurnProcessor,TurnReport}.gd`, `sim/commands/{Cmd,CmdColony}.gd`, `data/{traits,races,buildings,presets}.json`, `ui/screens/{TopBar,ColonyPanel,ColoniesListScreen,TurnSummaryScreen}.gd`, `ui/kit/{DataTable,StatTooltip}.gd`.
Accept: test_growth / test_economy / test_production / test_governor pass; 150-turn no-ships solo run has zero invariant violations; capture `colonies_list` and `colony_panel` with breakdown tooltip open. Playable: grow an empire of one, end turns, read summaries.

**P3 — Research** 
Files: `data/techs.json` (all 48 nodes + hyper), `sim/model/TechState.gd`, `sim/rules/Research.gd`, `sim/commands/CmdResearch.gd`, `ui/screens/ResearchScreen.gd`.
Accept: test_research and content tests; unlocking Automated Factory makes it buildable and the governor queues it; capture `research`.

**P4 — Ships, fleets, movement, colonisation, fog**
Files: `data/{hulls,parts}.json`, `sim/model/{ShipDesign,Ship,Fleet,Knowledge}.gd`, `sim/rules/{DesignRules,AutoDesign,Movement,Colonization,Visibility}.gd`, `sim/commands/{CmdDesign,CmdFleet}.gd`, `ui/screens/{ShipDesignerScreen,FleetPanel,FleetsListScreen}.gd`, `render/galaxy/{FleetLayer,OverlayLayer}.gd`, `render/common/{BirdShapes,EmpireStyle}.gd`.
Accept: movement/range/wormhole/nebula/colonise/outpost/colony-base tests; auto-design legality; auto-explore explores every reachable star on Tiny by T60 in a solo run; capture `designer`, `galaxy_fleets`. Playable: solo explore and expand.

**P5 — Combat, invasion, monsters**
Files: `sim/rules/combat/{CombatResolver,CombatParty,CombatUnit,Targeting,BattleLog}.gd`, `sim/rules/{GroundCombat,Bombardment}.gd`, `data/monsters.json`, `ui/screens/BattleScreen.gd`, `render/battle/{BattleStage,BattlePlayer,ShipGlyph,VfxLayer}.gd`.
Accept: combat and ground tests (§15.2); capture `battle` at round 3 of a fixture battle shows beams, missiles, shield facet, damage numbers; viewer replay of a log equals the resolved outcome (test compares final HP from log events with the resolver's result).

**P6 — AI v1 and soak**
Files: `sim/ai/{AiPlayer,AiView,AiAssess,AiResearch,AiDesign,AiColonies,AiExpansion,AiMilitary,AiProduction}.gd`, `data/{personalities,difficulty}.json`, `tools/soak/{soak_main.gd,run_soak.py}`.
Accept: AI isolation + AI-validity tests; `run_soak.py --seeds 1-10 --size small` exits 0: every game ends (conquest or cap), zero script errors and invariant violations, median AI colonies at T80 >= 5, budgets met. Playable: a real game against 3 AIs that can be won or lost by conquest.

**P7 — Diplomacy, council, espionage, victory**
Files: `sim/rules/{Diplomacy,Council,Espionage,Victory,Score}.gd` (Coalition lives in `Diplomacy.gd`), `sim/ai/{AiDiplomacy,AiEspionage}.gd`, `sim/commands/CmdDiplo.gd`, `ui/screens/{DiplomacyScreen,CouncilScreen,VictoryScreen}.gd`.
Accept: diplomacy/council/victory tests plus Coalition trip/end thresholds (35%/30%, notorious 30%/25%) on fixtures; soak 20 seeds: >= 80% of games end by victory before the cap and Grand Roost victories occur in at least one seed.

**P8 — Races and balance**
Files: `ui/screens/RaceDesignerScreen.gd`, `NewGameScreen.gd` (full options incl. Swans toggle and seed string), trait effects completed in `data/traits.json`/`races.json`, soak balance report section.
Accept: content race-budget tests; custom-race validation tests; soak 40 seeds report evaluated against GDD §17.3 (the report prints PASS/FAIL per target; failures are tuned in data, not code, and re-run).

**P9 — Events, QoL, accessibility, audio**
Files: `data/events.json`, `sim/rules/Events.gd`, `ui/screens/{SettingsScreen,SaveLoadScreen,AvipediaScreen,HelpOverlay}.gd`, `autoload/Sfx.gd` (full), `data/audio.json`, `audio/**`, `tools/audio/{manifest.json,import_audio.py}`.
Accept: events tests (lucky immunity, keyed, each GDD §20 MVP event fires on a fixture and applies its effect); settings persist; every hotkey in the table is bound (test reads the table and the router map); `import_audio.py` reports budget OK; UI smoke tests for all screens; capture at 75%, 100%, 200% UI scale.

**P10 — Web, copy, polish**
Files: `data/copy/en.json` (from the writer), `tools/check_build_size.py`, export preset tuning.
Accept: copy-coverage test now failing on missing keys -> zero missing; web build zip <= 25 MB and `.pck` <= 12 MB (`check_build_size.py`); full GUT + 40-seed soak green; owner plays a Standard game in a browser.

**STRETCH after P10** (each its own phase): refit, terraforming/Gaia projects, star gates, sabotage, mixed-species colonies, Cuckoo crisis, Medium/Large galaxies, web save export/import, key rebinding, tactical mode (only if the red team wins that argument).

---

## 17. Builder traps (read before writing code)

1. **JSON numbers are floats.** `JSON.parse_string` returns `float` for every number. Cast with `int()` in every `from_dict`/loader. Dictionary keys are type-strict: `d[0]` and `d[0.0]` are different keys. JSON object keys are always strings — convert id-keyed maps back with `int(key)`.
2. **No floats, no global RNG, no time in `src/sim/`** (§4.3). A grep test enforces it.
3. **Integer division truncates toward zero**; use `IntMath.floor_div` when an operand can be negative. `%` follows the dividend's sign.
4. **Dictionary order is insertion order**, which differs between a fresh game and a loaded one. Always iterate sorted ids in the sim.
5. **Empire 0 is the player.** Never test ids with `> 0`; use `>= 0` or `!= -1`.
6. **Explicit types from untyped containers**: `var c: Colony = gs.colonies[id]`, not `:=`.
7. **No `assert()` in product code**; validate and return an error string / log.
8. **No threads** (web build is single-threaded). Time-slice instead (§7.3).
9. **Non-resource files are not exported by default**: `data/*.json` must be in the export include filter or the web build boots with no content.
10. **Web audio has no bus effects** (sample playback mode).
11. **Run `--import` after adding a `class_name`**, or headless runs fail with "Could not find type".
12. **`-s` tool scripts must not reference autoloads**; keep tools on `src/sim` + `ContentDB.load_from()`.
13. **Do not mutate Defs** (shared, read-only).
14. **Browser-reserved keys**: no F1-F12, Ctrl+S/W/T/N/R bindings.
15. **Never `--check-only`.**
16. **Fixed widths** for any container whose content changes; numbers go in tooltips, not button faces.

---

## 18. Open architecture questions for the red team

1. Full-state snapshot undo (30 per turn): acceptable memory/latency on web late game, or go straight to inverse commands?
2. Code-built UI vs `.tscn`: is the builder (Gemini Flash) better at either? Does code-built UI make visual iteration by the owner harder?
3. JSON content vs `.tres`: does losing inspector editing hurt the owner's tuning workflow enough to matter?
4. xoshiro128** in GDScript vs Godot's `RandomNumberGenerator` (PCG32): is our own RNG worth its maintenance for version-proof determinism?
5. Time-sliced turn processing at 8 ms/frame: will the web build stay under 1.5 s late game, or must the AI be cheaper by design (e.g. plan military every other turn)?
6. Persisting last-turn `BattleLog`s in saves: size risk with large late-game battles?
7. Phase order: AI (P6) before diplomacy (P7) means the first soak games can only end by conquest or cap; is that a sufficient gate for P6?
