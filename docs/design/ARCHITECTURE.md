# Foul Fowl 4X — Technical Architecture

Revision 4 (red team round 2), 2026-10-06. Engine: Godot 4.6.2, GDScript, static typing. Companions: `GDD.md` (what), `BRIEF.md` (why, incl. open source and licensing), `COPY_PLAN.md` (strings), `docs/engineering/PLAN.md` (the build plan and phase briefs).

Written for the builder agent. §1-15 are the contracts; §16 points at the build plan; §17 the traps. Where a phase brief and this file disagree, this file wins; report the conflict.

---

## 1. Non-negotiables

1. **The simulation is pure data.** `src/sim/` is `RefCounted` classes and static functions: no `Node`, scene tree, signals, autoloads, `Time`, `randi()`/`randf()`, or floats in state or decisions.
2. **Determinism.** `(seed, settings, ordered command log) -> identical state hash` on every platform: integer math, keyed RNG streams (§4.4), ascending-id iteration.
3. **One command API.** The UI, the AI and the Battle Orders card mutate the game only through `Cmd` objects the sim validates (§4.5).
4. **The AI sees only what the player would see**, plus vision printed on the difficulty card, enforced by `AiView` (§8.1).
5. **Presentation replays, never decides.** The viewer plays a `BattleLog`; skipping, watching, replaying and headless runs yield the same result. Player input that matters (Battle Orders) is a command issued **before** resolution.
6. **Web-first.** Single-threaded web export; all long work is split into bounded sub-steps time-sliced across frames (§7.3).
7. **Content is data.** All content and tuning in JSON under `res://data/` (§5).
8. **Open source, two-tier assets** (BRIEF). Code is MIT. Only redistributable assets are committed: Atkinson Hyperlegible (OFL) in `assets/fonts/`, Kenney CC0 audio and the owner's Suno music in `assets/audio/open/`. Licensed packs live in `assets/audio/licensed/` (gitignored), produced at build time by `tools/fetch_licensed_audio.py`; **a fresh public clone must run and sound acceptable without them** (§13).

---

## 2. Project layout

```
project.godot
export_presets.cfg                 Web (threads off) + Windows Desktop
LICENSE                            MIT (code)
addons/gut/                        GUT 9.6.0, vendored from C:/Dev/InfiniteEmpire/addons/gut (MIT)
assets/
  fonts/                           AtkinsonHyperlegible-Regular.ttf, -Bold.ttf, OFL.txt (committed)
  audio/open/music/                owner Suno tracks, OGG (committed)
  audio/open/sfx/                  Kenney CC0 sounds, OGG (committed)
  audio/licensed/                  GITIGNORED: built by tools/fetch_licensed_audio.py
data/
  balance.json galaxy.json traits.json races.json personalities.json difficulty.json
  techs.json hulls.json parts.json buildings.json presets.json specializations.json
  events.json monsters.json audio.json credits.json
  copy/en.json                     all player-facing strings (writer-owned)
src/
  sim/                             PURE DATA
    core/      Rng.gd IntMath.gd Ids.gd StateHash.gd Log.gd
    defs/      ContentDB.gd DefLoader.gd Stats.gd (+ typed Def classes)
    model/     GameState.gd GameSettings.gd StarSystem.gd Planet.gd Colony.gd QueueItem.gd Empire.gd
               Species.gd TechState.gd ShipDesign.gd Ship.gd Fleet.gd BattlePlan.gd Knowledge.gd
               Relation.gd Treaty.gd CouncilState.gd CoalitionState.gd
    gen/       GalaxyGenerator.gd NameGen.gd
    rules/     Modifiers.gd Economy.gd Growth.gd Production.gd Governor.gd Specialization.gd
               MilitaryBudget.gd Research.gd DesignRules.gd AutoDesign.gd Refit.gd Movement.gd
               Colonization.gd Visibility.gd Blockade.gd Bombardment.gd GroundCombat.gd
               Espionage.gd Diplomacy.gd Council.gd Coalition.gd Events.gd Victory.gd Score.gd
      combat/  CombatResolver.gd CombatParty.gd CombatUnit.gd RangeTrack.gd Targeting.gd BattleLog.gd Autopsy.gd
    commands/  Cmd.gd CmdColony.gd CmdResearch.gd CmdDesign.gd CmdFleet.gd CmdBattle.gd CmdDiplo.gd CmdMisc.gd
    turn/      TurnProcessor.gd TurnReport.gd
    ai/        AiPlayer.gd AiView.gd AiAssess.gd AiResearch.gd AiDesign.gd AiColonies.gd AiExpansion.gd
               AiMilitary.gd AiWar.gd AiProduction.gd AiDiplomacy.gd AiEspionage.gd AiBattle.gd
    save/      Serializer.gd Migrations.gd
  autoload/    Settings.gd Session.gd Sfx.gd Copy.gd
  main/        Main.tscn Main.gd CaptureMode.gd
  ui/
    kit/       Ui.gd ThemeFactory.gd Palette.gd DataTable.gd StatTooltip.gd IconDraw.gd
    screens/   ScreenBase.gd UiRouter.gd MainMenu.gd NewGameScreen.gd GalaxyScreen.gd TopBar.gd
               ColonyPanel.gd ColoniesListScreen.gd ResearchScreen.gd ShipDesignerScreen.gd FleetPanel.gd
               FleetsListScreen.gd BattleOrdersCard.gd BattleScreen.gd DiplomacyScreen.gd CouncilScreen.gd
               TurnSummaryScreen.gd VictoryClockPanel.gd SettingsScreen.gd SaveLoadScreen.gd CreditsScreen.gd
               AvipediaScreen.gd VictoryScreen.gd HelpOverlay.gd
  render/
    common/    BirdShapes.gd EmpireStyle.gd
    galaxy/    GalaxyMapView.gd MapCamera.gd StarfieldLayer.gd StarLayer.gd FleetLayer.gd OverlayLayer.gd
    battle/    BattleStage.gd BattlePlayer.gd ShipGlyph.gd RangeStrip.gd VfxLayer.gd
test/  unit/ integration/ probes/ fixtures/
tools/
  run_tests.py                     Godot+GUT wrapper, log scan, exit code
  soak/ soak_main.gd run_soak.py probes_main.gd
  audio/ open_manifest.json licensed_manifest.json import_open_audio.py
  fetch_licensed_audio.py          licensed tier: owner machine only
  export_web.py check_build_size.py
docs/design/
```

If a file under `src/sim/` needs `extends Node`, `get_tree()`, an autoload or a float, the design is wrong.

---

## 3. Autoloads

| Autoload | Role |
|---|---|
| `Settings` | User prefs in `user://settings.cfg`: UI scale, volumes, battle watch mode, **Battle Orders mode (Always/Big/Never)**, reduce motion, high contrast, summary filters |
| `Copy` | `Copy.t(key, fallback)` from `data/copy/en.json`; missing keys logged once |
| `Session` | Owns `GameState`, `ContentDB`, the turn's command list + checkpoints (undo, §4.5), the command log and `TurnRunner`. API: `new_game`, `load_game`, `save_game`, `submit(cmd) -> String`, `undo`, `redo`, `end_turn`, `answer_battle_orders(cmds: Array)`. Signals: `state_changed(scope, ids)`, `turn_processing(pct)`, `battle_orders_needed(requests)`, `turn_started(report)`, `game_over(result)` |
| `Sfx` | `play(id)`, `music(state)`; buses, pools, open/licensed resolution (§13) |

The sim and the tools never reference autoloads.

---

## 4. Simulation core

### 4.1 State model

`GameState`: `seed`, `settings`, `turn`, `next_ids`, `systems` (dense), `planets` (dense), `colonies` (Dictionary id → Colony), `empires` (dense; player id 0; Monster faction id 100), `fleets`, `designs`, `relations` (pair-indexed), `council`, `coalition`, `pending`, `report`, `battle_logs`.
- Ids are ints, never reused, `-1` = none. **Empire 0 is valid**: never gate ids with `> 0`.
- Positions are integer deci-parsecs; `IntMath.isqrt` distances; transit position derived by integer lerp.
- `Empire`: species, traits, treasury, `TechState` (known, current project, progress, queue, `unchosen_unlock_tier` per field, last transfer turn), spy target and funding, security level, **military budget policy**, `Knowledge`, AI personality and `ai_memory` (strike history, intel ages, coalition target), flags.
- `Colony`: planet, owner, species, `pop_milli`, jobs, locked, preset, **specialisation and retool_until**, buildings, queue (items carry `added_by` and `why` for governor items), progress, occupied_until, garrison, defense_hp, blockaded.
- `Fleet`: ships, orders, **`BattlePlan`** (posture, target priority, Swat mode, line order (ship ids), retreat threshold), refit timers.

All model classes implement `to_dict()` / `from_dict()`; defs referenced by string id.

### 4.2 Integer math

`floor_div`, `ceil_div`, `pct`, `clamp_i`, `isqrt`, `lerp_i`; percent modifiers summed then applied once.

### 4.3 Determinism rules (tests in §15)

No floats/`randi`/`Time`/`OS` in `src/sim/` (grep test); iterate dictionaries via `sorted_ids`; all randomness keyed; simultaneous resolution where order would matter.

### 4.4 Keyed RNG

xoshiro128** on four 32-bit masked lanes; FNV-1a seeding; `Rng.keyed(seed, turn, stream, a, b)`; streams `GALAXY, COMBAT, GROUND, EVENTS, ESPIONAGE, AI, RESEARCH, COLONIZE, LOOT, LINEUP`; golden-output test (format contract).

### 4.5 Commands and undo (revision 4: snapshot + replay)

```gdscript
class_name Cmd extends RefCounted
var empire_id: int
func kind() -> StringName
func validate(gs: GameState, db: ContentDB) -> String   # "" or a copy key with the reason
func apply(gs: GameState, db: ContentDB) -> void         # mutate; NO undo delta, NO revert method
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Cmd             # dispatches on d["kind"] via CmdRegistry
```
- Planning commands change **orders and settings only** (jobs, preset, specialisation, queue, buy, research choice, designs, refit order, fleet orders and battle plan, diplomacy proposals, spy target/funding, security, military budget, council vote). Outcomes resolve only in the pipeline. `apply` must be a pure function of `(state, cmd)`: no RNG except `Rng.keyed`, no time.
- **Undo = restore + replay** (red team round 2: hand-written revert is brittle for the builder, and undo diverged from the replay log). Session keeps, for the current player turn: `turn_cmds: Array[Cmd]` (applied, in order), `checkpoints: Dictionary` (command index → `GameState.to_dict()` snapshot; index 0 is taken at turn start, then one every `undo_checkpoint_every` = 10 applied commands) and `redo_cmds: Array[Cmd]`.
  - `submit(cmd)`: validate → apply → append to `turn_cmds` → clear `redo_cmds` → checkpoint if `turn_cmds.size() % 10 == 0`.
  - `undo()`: pop the last command into `redo_cmds`; drop checkpoints at indexes > the new size; restore the largest checkpoint index `k ≤ size` with `GameState.from_dict`; re-apply `turn_cmds[k..size-1]` (no re-validation needed, they validated on this exact state before; a failing re-apply is a bug and is logged as `UNDO_DIVERGED`).
  - `redo()`: pop from `redo_cmds` and `submit` it without clearing the rest of `redo_cmds`.
  - Cap: 50 commands back (older ones cannot be undone; the checkpoint at the cap boundary becomes the base). Everything clears at End Turn. Battle Orders answers and pipeline results never enter `turn_cmds`.
  - **No command implements its own revert**, so a new command kind needs no undo code; a lint test fails if any `Cmd` subclass defines `revert`.
- **Command log**: at End Turn, `turn_cmds` (the player's surviving commands) are appended to the log, followed by the AI commands and Battle Orders answers in pipeline order; `seed + settings + log` replays a game exactly, and an undone command is never in the log by construction. Test: apply N random commands, undo k, redo j, end turn → state hash equals a fresh game fed only the surviving commands.
- **Budget**: undo ≤ 80 ms native / ≤ 200 ms web at T150 (restore one checkpoint + ≤ 9 re-applies). Measured by `tools/perf/undo_bench.gd` from P05, when a T150 state exists. Fallback if over: snapshot only the player-scoped slice (`Empire[player]`, its colonies, fleets, designs, pending proposals, `next_ids`), with a test that every command kind leaves the rest of the state hash unchanged.

### 4.6 Knowledge

Per empire: explored systems, seen colonies (owner, species, pop, buildings if in scan, **turn seen**), visible fleets, known designs, met empires, treasuries/treaties (informants), coalition-shared vision of the leader. Rebuilt in `visibility`; declared difficulty vision is written here, so `AiView` never special-cases difficulty.

---

## 5. Content data

- **JSON, not `.tres`** (agent- and writer-authored, diffable; no `ResourceSaver` default-omission trap). JSON numbers parse as float: every loader casts with `int()`.
- Files listed in §2; `specializations.json`, `audio.json` (sound slots → open + licensed paths), `credits.json` (attribution lines) are new in revision 3.
- **Effects** use a closed stat vocabulary in `Stats.gd`; unknown stats or predicates fail validation.
- **Copy**: `data/copy/en.json`, key scheme in `COPY_PLAN.md` (`<kind>.<id>.name` etc.). From P2 on, every screen reads real keys; a test lists missing keys (warning until P10, failure after).
- **Export**: non-resource files must be in the include filter. Use `*.json` (covers `data/` and `data/copy/`); the P0 web export test boots the exported build and asserts ContentDB and Copy loaded (§16 P0).
- `ContentDB.load_from("res://data")` is used by Session, tests and tools alike; Defs are read-only.

---

## 6. Modifier engine and explain

`Modifiers.eval(stat, base, ctx) -> ModResult {value, lines}` implements GDD §3.4 yield precedence: base table → floors → adds → caps → percentages (gravity, specialisation, retooling, government, supply lines, occupation, empire, difficulty) → floor. Every breakdown tooltip renders `lines`. Yields are cached per colony per turn and after planning commands that touch it.

---

## 7. Turn pipeline

### 7.1 Order

| # | Step | Sub-steps (each bounded, §7.3) |
|---|---|---|
| 0 | `ai_plan` | Per AI empire (ascending id): (a) apply the held **economy** commands (research, design, colonies, production) precomputed during the player turn (computed now if precompute did not finish); (b) run the **war** planners (assess, expansion, military, war, diplomacy, espionage), one bounded sub-step each. Commands validated and applied |
| 1 | `diplomacy` | Proposals, war declarations, treaty timers, **coalition update** (power, trip/end/cooldown, target) |
| 2 | `movement` | Simultaneous advance, arrivals, wormhole and Roost Gate hops |
| 3 | `combat` | **3a orders** for every contested system first: AI orders via AiBattle; then ONE Battle Orders pause for all qualifying player battles (§7.3) or standing plans; **3b resolve** per system (ascending id): CombatResolver → BattleLog + autopsy; apply losses, orbit control, veterancy, stalemate carry-over distances |
| 4 | `orbital` | Outpost razing, blockade flags, bombardment, invasions, colonisation (orbit controller wins conflicts, else keyed coin), unarmed ships destroyed |
| 5 | `production` | Queues, overflow, completions (Nest Pod pop drain), refits, rush-buys |
| 6 | `research` | Projects, fork unlocks, Creative/One-Note |
| 7 | `population` | Food balance, import, starvation, growth (blockade stops it) |
| 8 | `finance` | Taxes, trade, surplus 2:1, upkeep, colony administration, Strike |
| 9 | `espionage` | Intel, attempts (player steal choice is queued as a decision for next turn's summary; AI picks immediately) |
| 10 | `events` | Triggered and random events |
| 11 | `council` | Session if due (non-binding first), electability, pledges, tally |
| 12 | `victory` | Eliminations, capitulation offers, victories, cap |
| 13 | `visibility` | Rebuild Knowledge (incl. coalition-shared and difficulty vision) |
| 14 | `governor` | Job assignment, presets, military-budget queueing with `why` |
| 15 | `finalize` | `turn += 1`, report, autosave (Session) |

### 7.2 Invariants after every step (debug and tests)

Pop ≥ 0; treasury ≥ 0; each ship in exactly one fleet; owners exist; no colony on outpost-only bodies; ≤ 1 colony per planet; jobs sum to whole pop; battle line ≤ its slots; known techs valid; no Exodus key ever transferred.

### 7.3 Time slicing and the Battle Orders pause

- `TurnRunner` runs `TurnProcessor.run_next_substep()` in `_process` until **6 ms** of the frame are used, then yields. Every sub-step has a budget of **8 ms on the web reference laptop**; any planner that cannot meet it iterates incrementally across sub-steps (e.g. `AiMilitary` processes one fleet group per sub-step). Debug builds record per-sub-step time and the max frame time during end-turn.
- **AI economy precompute** (revision 4): while the player's turn is open, `TurnRunner` spends idle frame time (same 6 ms slice) running each AI's economy planners on the live state and stores the resulting commands in `Session.ai_held[empire_id]`. Their inputs (the AI's own entities and Knowledge) cannot be changed by player planning commands, so this is a cache; `ai_plan` step 0a applies the held commands, or computes them if precompute did not finish. Undo, redo and load **restart** the precompute from scratch (it only costs idle time), because a restore replaces the objects a half-finished planner holds; the results cannot differ, only the work is redone. GUT test + probe P10 assert equality with End-Turn computation.
- **Battle Orders pause** (revision 4: one per turn): at step 3a, after all AI orders are fixed, `TurnProcessor` collects every qualifying player battle (GDD §9.2 Big rule or Settings mode), ranks them by total armed PP, and returns `NEEDS_INPUT(requests)` with up to 3 cards plus the auto list; Session emits `battle_orders_needed(requests)`, the stop shows, and `answer_battle_orders(cmds)` resumes. AI orders are not exposed to the UI. Headless (`run_all`) and mode Never use standing plans (combined-fleet rule, GDD §9.2). Each answer is a `CmdBattle` in the command log, so replays reproduce them.

---

## 8. AI architecture

### 8.1 AiView

Built per AI empire per sub-step from `GameState` + that empire's `Knowledge`: own entities in full; foreign information only from Knowledge (with intel age); galaxy geometry; read-only ContentDB; `Rng.keyed(..., AI, empire_id, salt)`. Planners never receive `GameState`.

### 8.2 Planners and competence features (GDD §13.3)

- `AiAssess`: power estimates with **stale-intel inflation** (+10% per 5 turns since seen), threats, posture, coalition duty.
- `AiMilitary`: fleet roles; strikes at `≥ 1.5x` estimated defense (Coalition strike pair: `≥ 1.2x` on the pair's combined force, shared arrival turn via a staging system, GDD §12.4); **re-scout** targets with intel older than 10 turns; after a failure, the next strike needs `≥ 1.5x` the defense met, max 2 failures per target per 20 turns (`ai_memory`); Boot Ships one turn behind; defense response within 2 turns; coalition target priority.
- `AiWar`: declarations/peace with personality rules, overridden by coalition duty (aggression 8, ratio x0.8 on combined coalition power; NAP/Trade with the leader cancelled, Alliance exempts); auto-accepts the Held truce.
- `AiProduction`: sets the empire **military budget policy**; queues only through the same Governor path as the player (`why` recorded).
- `AiBattle`: per battle, from the visible enemy: posture, target priority, Swat mode, line order, retreat (counter-pick table, GDD §13.3).
- `AiDiplomacy`: treaties, pledges (sells at the GDD §12.3 price; no kingmaker refusal; the 15% cap is enforced by `Council`), unpledged votes by the GDD §12.3 order, tribute; `AiEspionage`: one target, picks highest-value steal.
- **Command hygiene**: every AI command must validate; a rejection is logged as `AI_REJECT` and fails the soak.

Shared with the player's automation: auto-design, auto-explore, governor/military budget, power estimates.

---

## 9. Combat resolver

- Inputs: system id, parties (empire, `CombatUnit`s with pre-evaluated integer stats, **orders**: posture, priority, Swat mode, line order, retreat), Two Steps Back flag, keyed RNG.
- `RangeTrack`: one `D` per pair of opposing parties (start 10, 12 with Two Steps Back, or the stalemate carry-over value; range 0..12). Each round applies `RangeTrack.step(d, p_a, s_a, p_b, s_b) -> int`, the closer/opener rule of GDD §9.3 verbatim (static, pure, integer). `s` = min combat speed of the party's armed line ships, at least 1; planets `s = 0`. Auto posture re-evaluates P when Horizon ammo is spent. `RangeTrack.project(d0, p_own, s_own, s_enemy) -> {talon_round, beak_round}` (worst case: the enemy opens at full speed) feeds the card's projection line.
- Line: max slots (8; Titan 2; +modifiers); reserve queue in the party's line order; reserves fill at round start.
- Round: reserves → move → Horizon arrivals (Swat first if mode) → fire (all line mounts incl. cloaked; targets from priority key → auto score → id; computed on the start-of-step snapshot, applied together) → launches → cleanup → retreat checks (`R` rule, receipt).
- RNG draw order fixed by (party empire id, unit id, mount index); **order-independence test** shuffles inputs and expects an identical log hash.
- Output `BattleLog` `{system_id, turn, parties: [{empire_id, orders, units}], rounds: [{distance: {pair: D}, events: [...]}], result: {winner, retreated, receipts, destroyed, autopsy: {deciding_band, standout_uid, receipt_uids, damage_by_band}}}`. Events: `reserve_in, move, fire_hit, fire_miss, shield_block, missile_launch, missile_hit, missile_miss, swat_kill, destroyed, retreat, retreat_receipt, heal, suppressed`.

---

## 10. Performance budget

| Item | Budget | Measured by |
|---|---|---|
| Evening Standard AI-vs-AI game, headless native | median ≤ 90 s, max ≤ 180 s | soak |
| End-turn total at T150, native | ≤ 300 ms | soak per-turn timings |
| End-turn total at T150, web reference laptop | ≤ 1.5 s wall; **no frame > 50 ms**; UI ≥ 30 fps | in-game perf overlay (debug), H9 |
| Any sub-step, web | ≤ 8 ms | debug sub-step timer |
| One battle, 60 units, native | ≤ 5 ms | soak micro-bench |
| Galaxy map / battle viewer, web | 60 fps (54 stars, 200 fleets / 400 VFX primitives) | perf overlay |
| Save / load, web | ≤ 300 / 500 ms; file ≤ 1 MB pre-gzip | Session timings |
| Undo (restore checkpoint + ≤ 9 re-applies) at T150 | ≤ 80 ms native, ≤ 200 ms web; ≤ 6 checkpoints held | `tools/perf/undo_bench.gd` (from P05) |

Timing is never asserted in the gated GUT suite; the soak and probe tools fail their own runs at > 2x budget. The **reference laptop** is named by the owner before P11 (H9).

---

## 11. UI architecture

- **Code-built Control UI with a small kit** (`Ui.gd`), one authored scene (`Main.tscn`); `ThemeFactory` builds the theme in code with **Atkinson Hyperlegible** (`assets/fonts/`) as the default font and `ThemeDB.fallback_font` only if the file is missing.
- Red-team adaptation: the kit and **real screens arrive from P1**, not P9; **every phase ends with a web export and capture PNGs** of its screens (CaptureMode) for owner review; copy keys are live from P2.
- Structure: `Main` → World (map), BattleLayer (viewer), UiLayer → UiRoot (`UiRouter`) → ScreenHost, HudHost, ModalHost (Battle Orders card, summary, council, dialogs), ToastHost. Hotkeys live in one table (`HelpOverlay.gd`) bound by the router.
- Fixed-width rule: dynamic content in tooltips, fixed column widths; numbers via `Ui.number(ModResult)` with breakdown tooltips.
- Screen → commands: Galaxy/Fleet panel (moves, battle plan, line order, refit), Colonies list (specialisation, preset, templates, jobs, buy), Research (project, queue), Designer (designs, auto-design), **Battle Orders card** (CmdBattle), Diplomacy (treaties, pledges, spy target, security, military budget), Council (vote, Accept/Defy), Summary (go-to, replay, steal choice).

---

## 12. Rendering

- **Galaxy map**: Node2D layers with scoped `_draw()`: starfield (once), stars (glow + diffraction spikes, owner glyph), fleets (bird chevrons, empire color + glyph, ETA ticks), overlays (fuel range fill, Coalition target marker, minerals/habitability/threat modes). 1 pc = 40 px; camera zoom 0.35-3.0; redraw on change only.
- **Battle viewer**: `BattleStage` positions party columns from the pair distance; `RangeStrip` draws the 0-12 strip with the words **Beak / Talon / Horizon** over their bands and each party's marker; `ShipGlyph` bird silhouettes by hull; `VfxLayer` one pooled `_draw()`: tapered Talon strokes, Beak streaks, Horizon darts with trails (the **first Horizon wave is always drawn per dart, with Swat intercepts**; volley ticks only for overflow past the cap), sparks + feathers, debris, faceted noisy shield arc segments. No GPUParticles, no ring/doughnut primitives.
- **Cards for screenshots**: Defy card (leader names), capitulation card, Perch Review panel, Battle Orders card, autopsy card.
- `BirdShapes`: swan, pheasant, duck, owl, penguin, crow, goose, chicken (icon, side view, portrait).

---

## 13. Audio (two-tier, per BRIEF)

### 13.1 Slots and resolution

`data/audio.json` maps every sound id to `{ "open": "res://assets/audio/open/...", "licensed": "res://assets/audio/licensed/..." | null }`. `Sfx` resolves at boot: use `licensed` if `ResourceLoader.exists(path)`, else `open`. **Every slot has an open sound**; a public clone sounds complete, the owner's itch build sounds richer. Buses Master → Music / SFX / UI, volume only (web sample playback has no bus effects). Pools: 10 SFX, 2 UI, 2 music (crossfade); 50 ms per-sound cooldown; 6 simultaneous weapon sounds per battle.

### 13.2 Sources

| Slot group | Open tier (committed) | Licensed tier (fetched; optional) |
|---|---|---|
| UI click/back/confirm/open/close/error | `kenney_interface-sounds` | `SCI-FI_UI_SFX_PACK/Clicks` |
| Notifications, war declared, honk taunt | `kenney_interface-sounds`, `kenney_sci-fi-sounds` (honk: pitched `kenney_impact` or a Suno sting) | `Sci-Fi Combat Systems.../UI` |
| Turn start/end, tech done, colony founded, council bell | `kenney_interface-sounds` | `SCI-FI_UI_SFX_PACK/Tone1-3`, `FX Sounds` |
| Fleet depart/arrive, wormhole | `kenney_sci-fi-sounds` (spaceEngine*, thrusterFire) | Shapeforms Warp Speed |
| Talon / Beak / Horizon fire | `kenney_sci-fi-sounds` (laserSmall/Large/Retro) | Shapeforms Sci-Fi Weapons; Combat Systems Weapons |
| Hits, shields | `kenney_impact-sounds` (impactMetal), `kenney_sci-fi-sounds` (forceField) | — |
| Explosions | `kenney_sci-fi-sounds` (explosionCrunch, lowFrequency_explosion) | Explosion SFX Pack (David Dumais) Designed Sci-Fi |
| Music: menu, galaxy early/mid/late, battle, diplomacy, Swans theme, victory, defeat, crisis | Owner Suno: `docs/design/MUSIC_PROMPTS.md` slots (essentials 1, 2, 3, 5, 8, 9); until generated, `IESunoMusic/empire` (map), `IESunoMusic/combat` (battle), `SnakeSunoMusic` VICTORY_1 / DEFEAT_1 | — |

### 13.3 Tools and budget

- `tools/audio/open_manifest.json` + `import_open_audio.py`: converts open sources to `assets/audio/open/` (SFX mono 44.1 kHz Vorbis q3; music stereo q1, trimmed loops), outputs **committed**.
- `tools/audio/licensed_manifest.json` (committed: source path under the owner's SoundAssets folder → target name) + `tools/fetch_licensed_audio.py` (owner machine only): copies and converts into `assets/audio/licensed/` (gitignored). Missing sources are skipped with a warning; the build still works.
- `.gitignore` already excludes `assets/audio/licensed/`; a test fails if any tracked file lives there (§15).
- Budget: SFX ≤ 1.5 MB per tier, music ≤ 7 MB, audio total ≤ 10 MB in the itch build.

### 13.4 Credits

`data/credits.json` → Credits screen and `CREDITS.md`: code MIT; Atkinson Hyperlegible (Braille Institute, SIL OFL 1.1); Kenney (CC0, credited anyway); the owner's music; and, only when the licensed folder is present at build time, the licensed vendors by name (David Dumais Audio Explosion SFX Pack, Shapeforms Audio, the Sci-Fi UI SFX pack and Sci-Fi Combat Systems pack vendors). `export_web.py` regenerates the credits list from what is actually bundled.

---

## 14. Save format and versioning

`user://saves/<slot>.sav`, gzip JSON envelope `{format, version, game_version, created_unix, turn, seed_string, summary, state}`, atomic write via temp + rename, `Migrations.migrate` chain with fixture saves per version, ints cast on load, autosave rolling 3. The state includes battle plans, coalition state, intel ages and pending battle-order requests (a save made mid-turn is not possible: saves happen between turns only). `OS.is_userfs_persistent()` warning on web; H9 verifies persistence on the itch page.

---

## 15. Testing

### 15.1 Commands

- Godot: `C:/Dev/InfiniteEmpire/GodotExe/Godot_v4.6.2-stable_win64_console.exe` (`GODOT_EXE` overrides). After adding any `class_name`: `--headless --path . --import`.
- `python tools/run_tests.py [--filter X]` → GUT (`-s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`), fails on non-zero exit, `SCRIPT ERROR`/`ERROR:`/`Parse Error`, or a missing/zero-test summary.
- `python tools/soak/run_soak.py --design balanced280 --procs 8` → balance soak (GDD §17.2): lineups from all 70 four-race subsets x 4, Seat the Swans off, Flighted; writes `build/soak/report.json` + markdown with conditional win rates and **95% Wilson intervals**, victory mix, end turns, coalition stats, timings, and PASS/FAIL per gate rule. `--design swans40` runs the default-experience report. Exit non-zero on any hard failure (script error, invariant, `AI_REJECT`, unfinished game, > 2x budget) or gate FAIL.
- `python tools/soak/run_soak.py --probes` → strategic probes P1-P8 from fixtures in `test/probes/` (GDD §17.3).
- `python tools/export_web.py` → web export to `build/web/`, then a headless-browser-free check: the exported `.pck` is opened with `--main-pack` headless and a boot script asserts ContentDB and Copy loaded and fonts/audio resolve (catches the JSON include filter trap).
- CaptureMode: `--path . -- --capture=<screen> --fixture=<json> --out=<png>`.
- Never `--check-only`.

### 15.2 Gated GUT suite (invariants and contracts only)

| Area | Tests |
|---|---|
| Core | Rng golden outputs; IntMath edge cases |
| Determinism | Same seed 50 AI turns → equal hash; save/load mid-game → equal hash; sim grep (no float/randi/Time/Node) |
| Content | Refs resolve; each tech node has 1 core + exactly 2 options; **no option without an MVP effect** (every option's effects/unlocks non-empty); race pick sums; do-not-ship names absent from `en.json` and data (list in COPY_PLAN) |
| Licensing | No tracked file under `assets/audio/licensed/`; every `audio.json` slot has an existing open file; credits include every bundled source |
| Economy | Growth cases; surplus 2:1; import/starvation; Nest Pod drain; admin upkeep; supply lines; specialisation + retooling; military budget stops at target; `why` set on governor items |
| Research | Fork: option unavailable until +2 tiers, then 150%; Creative both; One-Note never; transfer limit; Exodus keys never transfer |
| Ships/movement | Space limits; miniaturisation floor; auto-design legal; refit cost and downtime; range; wormhole/gate |
| Combat | `RangeTrack.step` over P ∈ {0,1,5,12} x s ∈ {0..5}² x D0 ∈ {0..12}: D strictly falls while above P_c, P_c reached within `D0 - P_c` rounds, GDD §9.3 table exact; stalemate carry-over; line slots and reserve order; target priority keys; Swat modes; retreat `R` for every modifier combination with exactly one receipt; cloaked ships fire but are not targeted in rounds 1-2; order independence; 500 random battles without errors |
| Siege | Guns blockade but never kill pop; bomb parts kill per table; outposts razed; invasion duels |
| AI | AiView isolation; all AI commands validate on fixtures; AiBattle counter-pick table |
| Diplomacy | Grand Roost: first session non-binding, electability, pledge cap and price, no self-charisma, unpledged vote order, Defy wars; Coalition power formula, trip, Cut Down / Held endings and their effects (cooldown, Acknowledged, truce, bandwagon votes), duty cancels NAP/Trade but not Alliance, shared range, strike pair selection |
| Undo | Every command kind: submit then undo restores the hash; random submit/undo/redo sequences then End Turn equal a fresh run of the surviving commands; no `Cmd` subclass defines `revert`; AI precompute equals End-Turn computation |
| Save | Round trip; migrations; gzip |
| UI smoke | Every screen builds against fixtures headless |

---

## 16. Phased build plan

Each phase ends **exported to web, captured, playable or testable**, all prior tests green, one PR-sized change. Product files listed; tests/data additional.

**P0 — Skeleton, export, copy, font**: `project.godot` (Compatibility renderer, 1280x720, canvas_items), `export_presets.cfg` (Web threads off, include `*.json`, exclude `test/*,tools/*,docs/*,addons/gut/*,assets/audio/licensed/*` for public builds), GUT vendored, `Main.tscn/gd`, autoload stubs, `sim/core/*`, `sim/defs/*`, `ui/kit/{Ui,ThemeFactory,Palette}.gd`, `ui/screens/{ScreenBase,UiRouter,MainMenu}.gd`, `data/{balance,audio,credits}.json`, `data/copy/en.json` (Grok's lines), `tools/{run_tests,export_web}.py`. Accept: GUT green (rng, intmath, content, licensing); exported web build boots to a main menu showing en.json strings in Atkinson Hyperlegible; boot check passes.

**P1 — Galaxy and map**: model/{GameState, GameSettings, StarSystem, Planet}, gen/*, save/Serializer, render/galaxy/*, NewGameScreen (presets, seed), GalaxyScreen, CaptureMode. Accept: generator tests over 200 seeds (counts, separation, race-aware fair start, 30% habitable beyond 9 pc, Orn central, wormhole); save round trip; capture.

**P2 — Colonies and economy**: model/{Empire, Species, Colony, QueueItem}, rules/{Modifiers, Economy, Growth, Production, Governor, Specialization, MilitaryBudget}, turn/*, commands/{Cmd, CmdColony}, data/{traits, races (4 first-wave empires), buildings, presets, specializations}, screens/{TopBar, ColonyPanel, ColoniesListScreen, TurnSummaryScreen}, kit/{DataTable, StatTooltip}. Accept: economy tests incl. expansion costs, specialisation, budget; undo delta tests; 150-turn solo run invariant-clean; captures with breakdown tooltip.

**P3 — Research**: data/techs.json (36 nodes, 108 techs), model/TechState, rules/Research, CmdResearch, ResearchScreen. Accept: fork/Creative/One-Note/transfer tests; no-dead-option content test; capture.

**P4 — Ships, fleets, movement, colonisation, fog, refit**: data/{hulls, parts}, model/{ShipDesign, Ship, Fleet, BattlePlan, Knowledge}, rules/{DesignRules, AutoDesign, Refit, Movement, Colonization, Visibility}, commands/{CmdDesign, CmdFleet}, screens/{ShipDesignerScreen, FleetPanel, FleetsListScreen}, render/galaxy/{FleetLayer, OverlayLayer}, render/common/*. Accept: movement/range/colonise (pop drain)/outpost/refit tests; auto-explore covers Tiny by T60; captures.

**P5 — Combat and siege**: rules/combat/*, rules/{Blockade, Bombardment, GroundCombat}, commands/CmdBattle, data/monsters.json, screens/{BattleOrdersCard, BattleScreen}, render/battle/*, TurnRunner pause. Accept: combat and siege tests (§15.2); Battle Orders pause round-trips through the command log; viewer replay final HP equals resolver result; captures of the card, strip and first Horizon wave.

**P6 — AI v1, soak, probes; FIRST EVENING milestone (4 empires)**: sim/ai/* (incl. AiBattle), data/{personalities, difficulty}, tools/soak/*. Accept: AI tests; 20-game smoke soak (4 first-wave empires) with zero hard failures; probes P1-P6 pass; **owner plays one browser Evening Standard to the end** (Conquest or Called Game).

**P7 — Diplomacy, Grand Roost, Coalition, espionage, victory**: rules/{Diplomacy, Council, Coalition, Espionage, Victory, Score}, ai/{AiDiplomacy, AiEspionage, AiWar coalition duty}, CmdDiplo, screens/{DiplomacyScreen, CouncilScreen, VictoryClockPanel, VictoryScreen}. Accept: diplomacy/council/coalition tests; probe P7; smoke soak shows all three victory types.

**P8 — Remaining four empires and events**: trait plumbing for creative, piscivore, tolerant, heat_intolerant, huddle, cache, scavengers, informants, distrusted, uncreative, prefab_coops, nothing_wasted, night_hours; Evening Standard seating; rules/Events (6 MVP events). Accept: trait tests incl. yield precedence; event fixtures; all 8 race cards captured.

**P9 — Presentation, audio, settings**: Sfx full + tools/audio/* + fetch_licensed_audio, CreditsScreen, Settings/SaveLoad/Avipedia/Help, screenshot cards, accessibility. Accept: licensing tests; open-only build sounds complete; UI scale captures 75/100/200%; hotkey table bound. **Mechanics frozen at the end of P9.**

**P10 — Balance gate**: data-only tuning until `run_soak --design balanced280` and `--probes` PASS; Seat-the-Swans report reviewed. No code changes except bug fixes.

**P11 — Web hardening and human playtests**: reference laptop perf (H9), size check (`.pck` ≤ 15 MB with licensed audio, zip ≤ 25 MB), copy-coverage failure on missing keys, 5 recorded playtests against GDD §17.4 H1-H10, owner trademark check on title/faction names, release.

STRETCH phases after P11, one per GDD §18 item.

---

## 17. Builder traps

1. JSON numbers are floats: cast `int()`; JSON object keys are strings.
2. No floats, global RNG or time in `src/sim/`.
3. Integer division truncates toward zero: use `floor_div` for negatives.
4. Dictionary order is insertion order: iterate sorted ids.
5. Empire 0 is the player: never test ids with `> 0`.
6. Explicit types from untyped containers.
7. No `assert()` in product code.
8. No threads (single-threaded web); time-slice.
9. Non-resource files need the export include filter: `*.json` (subfolders too).
10. Web audio has no bus effects.
11. Run `--import` after adding a `class_name`.
12. `-s` tool scripts must not reference autoloads.
13. Do not mutate Defs.
14. Browser-reserved keys: no F-keys, Ctrl+S/W/T/N/R.
15. Never `--check-only`.
16. Fixed widths for dynamic containers; numbers in tooltips.
17. **Never commit anything under `assets/audio/licensed/`**, never copy licensed sources into `open/`; every audio slot needs an open fallback.
18. A battle's orders must be fixed for both sides before `CombatResolver.resolve()` runs; never let the viewer or the card read the other side's orders.
19. Never ship a do-not-ship name (COPY_PLAN list) in data ids that surface in UI, or in `en.json`.
20. Never write an undo delta or a `revert` method on a command; undo is restore + replay (§4.5).
21. AI economy precompute may read only the AI's own entities and its Knowledge; never let it read another empire's orders or the player's uncommitted UI state.
22. `RangeTrack.step` is the GDD §9.3 code verbatim; do not "simplify" it back to a simultaneous sum (that froze equal-speed fights at D = 10).

---

## 18. Architecture questions

Round 2's questions (Battle Orders pause, AI planning time, undo, browser smoke, audio tiers) are answered in GDD §23 (rows AQ1-AQ5).
