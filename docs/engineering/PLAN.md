# Foul Fowl 4X — Engineering Plan

Revision 1, 2026-10-06. Written for the builder (agy: Gemini 3.8 Flash, no memory between runs, one git worktree and one PR per phase) and the orchestrator who reviews and merges each PR.

**Authority.** `docs/design/GDD.md` (revision 4) decides mechanics and numbers. `docs/design/ARCHITECTURE.md` (revision 4) decides contracts. This plan decides order, files, APIs and acceptance. A phase brief (`phases/PNN.md`) is the work order for one run. If two of them disagree, GDD > ARCHITECTURE > PLAN > brief: build what the higher document says and list the conflict under **Design conflicts** in the PR body. Never edit anything under `docs/design/`.

---

## 1. Phases

Each phase ends with a web export that boots and stays under 25 MB, a green test run, a scripted scenario, screenshots of named screens at 1280x720, and (orchestrator) a 4x-throttled browser check against §1a. The playable vertical slice (galaxy, colonies, ships, combat, 4 empires, Conquest/Called Game) is **P05**. Research arrives in P06 so the slice is not blocked behind the tree.

| Phase | Goal | Playable / testable at the end | Headline acceptance |
|---|---|---|---|
| P00 | Skeleton: project, export, tests, RNG, content, copy, UI kit, font, audio tiers | Web build boots to a main menu in Atkinson Hyperlegible | `gate.ps1` green: RNG goldens, content, copy, licensing, purity; `BOOT_OK` from the exported pck; `main_menu` + `credits` captures |
| P01 | Galaxy generation, model, save/load, New Game, galaxy map | Generate Tiny/Evening Standard galaxies and browse them | 200-seed generator invariants; save round trip hash-equal; captures `new_game`, `galaxy`, `system_panel` |
| P02 | Empires, species, colonies, economy, turn pipeline, commands, undo, autosave | Pick one of 4 races, run colonies, End Turn, undo | Economy + undo/replay tests; 150-turn headless run invariant-clean; captures `galaxy_topbar`, `colony_panel`, `colonies_list`, `turn_summary` |
| P03 | Ships, designs, fleets, movement, fuel range, colonisation, outposts, fog, auto-explore | Explore and expand | Scenario `p03_expand` (every star in fuel range explored by T60; capital + 2 colonies by T35 with the pop drain observed; an outpost by T45); captures `fleet_panel`, `designer`, `range_overlay` |
| P04 | Combat, Battle Orders stop, viewer, autopsy, blockade, bombardment, invasion, monsters | Fight, besiege and invade (scripted war) | Range table fixture (7,488 rows) exact; one stop per turn round-trips through the log; viewer HP = resolver HP; scenario `p04_invasion`; captures `battle_orders`, `battle_viewer`, `autopsy` |
| P05 | AI v1, war/peace, military budget, governor, Conquest, Called Game, capitulation, soak smoke, probes — **VERTICAL SLICE** | A full Evening Standard vs 3 AIs (Swans, Pheasants, Ducks, Geese), ending in Conquest or Called Game | 20-game smoke soak: 0 hard failures, every game ends; probes P1a, P2-P5, P10 pass (P1b, P9 reported; P6 is P04's range test); undo bench ≤ 80 ms native; owner plays one browser game to the end |
| P06 | Research: 36 nodes / 108 techs, fork rules, Creative/One-Note, tech effects, Research screen, AI research + design, refit, miniaturisation | The tree drives the arms race | Fork REFUSE/ALLOW tests incl. final forks; no-dead-option test; 20-game soak still ends; captures `research`, `designer_upgraded` |
| P07 | Economy depth and QoL: specialisations, retooling, supply lines, prospect line, specials, templates, bulk colonies, full turn summary, next-decision, hotkeys, victory clock (P05 doors) | An evening without chores | Specialisation/supply/prospect tests; probe P8 report; scenario `p07_automation`; captures `colonies_list_bulk`, `turn_summary_full`, `victory_clock` |
| P08 | Diplomacy, treaties, Grand Roost, Coalition (Cut Down / Held), espionage, Exodus, Defy | All four doors open | Council/Coalition REFUSE/ALLOW tests; probe P7; scenario `p08_coalition`; `smoke40` victory mix (≥ 1 Grand Roost and ≥ 1 Exodus, else a Known issue for P11); captures `diplomacy`, `council`, `defy_card`, `coalition_news` |
| P09 | Remaining 4 empires (Owls, Penguins, Crows, Chickens), their traits, Evening Standard seating, 6 MVP events, race select | All 8 empires playable | Trait + yield precedence tests; event fixtures; 8-race soak smoke ends; captures `race_select`, 8 race cards, `perch_review` |
| P10 | Presentation: audio (two tiers), music, settings, save/load UI, credits, Avipedia, help, accessibility, screenshot cards, VFX pass. **Mechanics freeze** | Feature-complete itch candidate | Licensing tests; open-only build sounds complete; UI scale captures 75/100/200%; copy coverage report; captures of every screen |
| P11 | Balance gate (balanced280 + probes), data-only tuning, web hardening, size, playtest kit, release zip | Release candidate for the 5 human playtests | `run_soak --design balanced280` PASS or inconclusive→pooled PASS; probes PASS; web build and zip < 25 MB; throttled-browser perf numbers recorded |

Dependency rule: phase N may use any public API of phases < N; it may modify earlier files only where its brief says so.

---

## 1a. Performance and platform target (BRIEF "Performance target"; binds every phase)

No named reference machine (owner: "max compatibility"). Every phase's acceptance checks against this **low-end target**:
- Godot Compatibility renderer (WebGL 2); single-threaded web export (no SharedArrayBuffer, no special headers).
- Chrome, Firefox, Edge, Safari on desktop; a ~2018 laptop with integrated graphics and 4 GB RAM.
- Galaxy map steady **60 fps**; battle viewer **≥ 30 fps**; **no frame over 50 ms** during End Turn.
- Minimum window **1280x720**, UI scale option (from P10; layouts must already fit 1280x720 at 100% from P00); **mouse-only playable**: every action reachable by mouse, keyboard shortcuts optional.
- Initial web download **< 25 MB** (`.pck` + `.wasm` + audio; compressed OGG).
- **Local stand-in**: the dev machine running the exported build in Chrome with DevTools Performance **CPU throttling 4x**. The in-game perf overlay (P00: `?perf=1` in the page URL, or the backquote key on desktop) shows fps, the worst frame of the last 5 s, and during End Turn the worst frame of that turn.
- Builder side: `tools/export_web.ps1` fails above 25 MB; screens are built for 1280x720 and every capture is taken at 1280x720. Orchestrator side: the browser check (§9) runs with the 4x throttle and records the overlay numbers in the PR review.

## 2. Builder operating rules (every phase)

1. **Start**: read this file §1a-§9, then your phase brief in full, then the GDD/ARCHITECTURE sections the brief lists under *Read first*. Do not skim: the briefs are literal work orders.
2. **Worktree and branch**: work in your own git worktree on branch `phase/PNN-<slug>` (slug given in the brief), created from the current `main`. Never commit to `main`.
3. **Commits**: small, in build order; message `PNN: <what>`; end every commit message with your agent attribution line.
4. **No design changes.** If the brief is impossible or contradicts GDD/ARCHITECTURE, build the closest thing the higher document allows and record it under *Design conflicts*. Never edit `docs/design/*`. Never invent player-facing jokes, flavour, names or lore (§8).
5. **Scope**: create and modify only the files the brief lists, plus tests, fixtures, `data/` rows and `tools/captures.json` entries it asks for. If you need another file, add it and name it under *Deviations* with one line of why.
6. **Verification**: `tools/gate.ps1` (§4) must exit 0 on your final commit. Paste its summary block into the PR body. A failing gate is reported with the failing output, never hidden or skipped. Never weaken, skip, or delete a test to get green unless the brief says so.
7. **Blocked?** If something cannot be done (missing tool, engine bug), stop that item, finish the rest, and report it as a **Blocker** with: what fails, the exact command and output, and your proposed default.
8. **PR body** (exact headings):
   ```
   ## PNN <title>
   Needs: <decisions/blockers for the orchestrator, or "none">
   ### Gate
   <gate.ps1 summary block: import, tests (Scripts/Tests/Passing/Failing), scenario lines, export BOOT_OK line, capture list>
   ### Changed
   - <file or area>: <one line>
   ### Acceptance
   - [x]/[ ] each acceptance item from the brief, with its evidence (command + result line)
   ### Deviations
   - <none, or one line each>
   ### Design conflicts
   - <none, or one line each with the doc § and your choice>
   ### Known issues
   - <none, or one line each>
   ```
9. **Captures** land in `build/captures/PNN_<id>.png` (gitignored). List their paths in the PR body; the orchestrator views them in your worktree and runs the real-browser check (§4.6) before merging.

---

## 3. Repository conventions

### 3.1 Layout
As `ARCHITECTURE.md` §2, with these refinements (they win over §2 where they differ):
- `src/sim/SimGame.gd` (`class_name SimGame`): the whole game without nodes or autoloads: state, content, command submission, **undo/redo (ARCHITECTURE §4.5)**, headless end turn. `Session` (autoload) wraps one `SimGame` and adds signals, frame-sliced turns, autosave files. Tools and tests use `SimGame` directly.
- One command class per file: `src/sim/commands/<area>/Cmd<Name>.gd`, `class_name Cmd<Name> extends Cmd`. `src/sim/commands/CmdRegistry.gd` maps `kind` → script for `from_dict`.
- Turn steps: `src/sim/turn/steps/Step<Name>.gd` extending `TurnStep`.
- Content defs are **normalised read-only Dictionaries**, not typed Def classes: `DefLoader` converts every JSON number to `int` (non-integral numbers are a content error) and `ContentDB` serves them. `Stats.gd` holds the closed stat/flag vocabulary (Appendix A).
- Tests: `test/unit/test_<system>.gd`, `test/integration/test_<flow>.gd`, `test/fixtures/`, `test/scenarios/<name>.json`, `test/probes/`. **Extend the system's existing test file**; do not create a test file per phase.
- Tools: `tools/run_tests.py`, `tools/gate.ps1`, `tools/export_web.ps1`, `tools/serve_web.ps1`, `tools/scenario_run.gd`, `tools/captures.json`, `tools/fetch_licensed_audio.py`, `tools/audio/*`, `tools/soak/*` (P05), `tools/perf/*` (P05).
- Reference implementations the GDScript must match: `docs/engineering/reference/rng_reference.py`, `range_reference.py`.

### 3.2 GDScript style
- Static typing everywhere: every `var`, parameter and return has a type. `:=` only when the right side has an obvious type (constructor, literal, typed function).
- `class_name` on every sim/ui class, never on autoload scripts (an autoload named `Session` plus `class_name Session` is a parse error).
- Model classes are `RefCounted`, hold **ids, not object references** to other model objects (no cycles, clean save), and implement `to_dict() -> Dictionary` and `static func from_dict(d: Dictionary) -> <Class>`.
- Ids are ints, never reused, `-1` (`Ids.NONE`) = none. **Empire 0 is the player and is valid**: never test an id with `> 0`; use `>= 0` or `!= Ids.NONE`.
- No `assert()` in product code. Invalid input: return a refusal key / safe default and record with `SimLog.warn()`; `push_error` only for genuine bugs (a run's log must contain no `ERROR:` lines).
- Signals: `sig.connect(callable)`; never the string form.
- UI: inject data (`screen.setup(params)`) **before** `add_child`.

### 3.3 Data
- All content in `data/*.json`, listed in `data/manifest.json` (ContentDB loads exactly those files; listing directories is unreliable in exported packs).
- Ids are `snake_case`, stable. Display text never lives in `data/` except `data/copy/en.json`.
- Every tunable number lives in `data/balance.json` (flat `{ "key": int }`) or a content row. Percentages are ints (`25` = 25%). Distances in **deci-parsecs** (`1 pc = 10`).

### 3.4 Copy
- `Copy.t(key, fallback := "")` everywhere a player reads text; `Copy.f(key, args: Dictionary, fallback := "")` fills `{token}`s. The sim stores keys and args, never text.
- `en.json` is a flat `{ "key": "string" }`. Phases add the keys their screens use, copying text **verbatim** from the source `COPY_PLAN.md` names (MEME_BIBLE line, Grok part/section). `GAP` keys stay out of `en.json`; the UI shows `Copy.t`'s prettified-id fallback.
- Functional labels (`ui.label.*`: button names, column headers, settings) are yours to write: plain, short, no jokes.

---

## 4. Commands (Windows PowerShell, from the worktree root)

Godot: `C:\Dev\InfiniteEmpire\GodotExe\Godot_v4.6.2-stable_win64_console.exe` (scripts read `$env:GODOT_EXE` first). Python 3.13 is `python`. ffmpeg is on PATH.

1. **Import** (after creating any `class_name`, or the first time in a worktree):
   `& $GODOT --headless --path . --import`
2. **Tests**: `python tools/run_tests.py` (all), `python tools/run_tests.py --file res://test/unit/test_rng.gd`, `python tools/run_tests.py --select rng`. Exit 0 = measured green; 2 = failures; 3 = instrument failure (nothing ran, parse error, Godot died, `ERROR:` in the log). It runs GUT as `--headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit` and checks the log's positive signature.
3. **Scenario**: `& $GODOT --headless --path . -s res://tools/scenario_run.gd -- --scenario=res://test/scenarios/<name>.json` → prints `SCENARIO PASS <name>` and exits 0, or `SCENARIO FAIL <name>: <check>` and exits 1.
4. **Web export + boot check**: `powershell -File tools/export_web.ps1` → `build/web/index.html` + `.pck` + `.wasm`, then runs `& $GODOT --headless --main-pack build/web/index.pck -- --boot-check` and requires the line `BOOT_OK` and exit 0.
5. **Captures**: `& $GODOT --path . --resolution 1280x720 -- --capture=<id> --out=build/captures/<file>.png` (windowed, not headless: the dummy renderer cannot draw). `tools/captures.json` lists every capture with its phase.
6. **Gate (the one command a phase must pass)**: `powershell -File tools/gate.ps1` runs 1 → 2 → every scenario in `test/scenarios/` → 4 → every capture in `tools/captures.json`, and prints a summary block. Exit 0 only if all pass.
7. **Real browser** (orchestrator, during review): `powershell -File tools/serve_web.ps1` serves `build/web` at `http://localhost:8060`; the single-threaded build needs no special headers.
8. Never run `--check-only` (it boots the game and hangs). Never leave a Godot process running: every command above is foreground and exits.

---

## 5. Test conventions

- **Invariants, not snapshots.** Assert contracts that stay true when numbers are tuned: conservation (pop, PP, credits), never-negative, determinism (hash equality), rule shape (the closer always gains), REFUSE/ALLOW boundaries. Do not assert a tuning value copied from `balance.json`; read it from ContentDB in the test.
- **Every rule or refusal ships with a pair**: one case it must REFUSE and one it must ALLOW at the boundary. Name them `test_<rule>_refuses_<case>` and `test_<rule>_allows_<case>`.
- Golden values are allowed only for **format contracts** (RNG outputs, range table, save format), always generated by the reference scripts in `docs/engineering/reference/`.
- Tests build state with `test/helpers/Fixtures.gd` (`class_name Fixtures`, from P01): small hand-made galaxies and empires. Never load a save written by a previous phase's code unless it is a migration fixture.
- No timing assertions in GUT. Performance budgets are measured by tools (`tools/perf/`, soak) and reported.
- No `pending()` placeholders; no tests that pass when nothing ran.

---

## 6. Determinism contract (ARCHITECTURE §1, §4.3-4.4)

- `src/sim/` never calls `randi`, `randf`, `randomize`, `RandomNumberGenerator`, `Time`, `OS`, `get_tree`, autoloads, or uses `float`. A purity test greps for these (P00).
- All randomness: `Rng.keyed(seed, turn, Rng.<STREAM>, a, b)` with `a`, `b` naming the subject (system id, empire id, battle index). Never reuse one `Rng` object across subjects whose order could change.
- Iterate dictionaries through `Ids.sorted_keys(d)`. Every `sort_custom` comparator breaks ties by id (Godot's sort is not stable).
- Integer division: `IntMath.floor_div` / `ceil_div` / `pct`; `%` only on non-negative values (`IntMath.floor_mod` otherwise).
- Never use `hash()` or `String.hash()` for anything persisted or compared across runs: use `StateHash` / `Rng.hash_ints` (FNV-1a).

---

## 7. GDScript and engine traps (read before every phase)

1. JSON numbers parse as `float`: everything goes through `DefLoader.ints_only()`; values read in `from_dict` are cast with `int()`.
2. JSON object keys are strings: a `Dictionary` keyed by int ids must convert keys with `int(k)` in `from_dict`.
3. Untyped `Array` / `Dictionary` element access needs an explicit type: `var c: Dictionary = list[i]`, never `var c := list[i]`.
4. Assigning an untyped `Array` to `Array[int]` needs `typed.assign(untyped)`.
5. Inject data before `add_child` (`_ready` runs on add).
6. No `assert()` in product code. Signals: `sig.connect(callable)`.
7. After adding a `class_name`, run the import (§4.1) or other scripts fail to resolve it.
8. `-s` scripts (tools) compile before autoloads exist: they must not reference `Session`, `Settings`, `Copy`, `Sfx`.
9. Integer `/` truncates toward zero and warns: use `IntMath`.
10. Web is single-threaded: no `Thread`, no `WorkerThreadPool`. Long work is sliced (ARCHITECTURE §7.3).
11. Web audio has no bus effects; volume only.
12. Browser-reserved keys: never bind F-keys, Ctrl+S/W/T/N/R.
13. Dynamic text never widens a container: fixed column widths, numbers in tooltips (ARCHITECTURE §11).
14. `Array.sort_custom` is unstable: tie-break by id.
15. RefCounted cycles leak: models store ids.
16. Never commit anything under `assets/audio/licensed/`; every audio slot has an open fallback.
17. Never ship a do-not-ship name (COPY_PLAN list) in `en.json` or in an id that reaches the UI.

---

## 8. Copy and content authorship

The builder never writes jokes, flavour, names, taunts, news or lore. Those come only from `MEME_BIBLE.md`, `redteam/grok_redteam_and_copy_1.md` Part B and `redteam/grok_redteam_2.md` §Copy, as mapped by `COPY_PLAN.md`. Where the plan says GAP, leave the key out. Where it says REWRITE with given text, use that text. Numbers inside copy must match the data; if a source line states a number the GDD has since changed, leave that key out and list it under *Known issues*.

---

## 9. Acceptance protocol (orchestrator)

For each PR: (1) read the PR body; (2) run `tools/gate.ps1` in the worktree; (3) open the captures; (4) `tools/serve_web.ps1`, load `http://localhost:8060/?perf=1` in Chrome with DevTools CPU throttling 4x, play the phase's flow **with the mouse only**, record the overlay's fps and worst frame (map 60 fps, viewer ≥ 30 fps, End Turn worst frame ≤ 50 ms, §1a), screenshot; from P05 also spot-check Firefox (and Edge/Safari before P11); (5) check *Deviations* and *Design conflicts* against the docs; (6) merge (squash) or return with numbered findings. P05 and P11 additionally need the owner's playtest.

---

## 10. Risks the builder will hit first

1. **Godot web export settings** (P00): wrong preset keys, thread support left on, JSON missing from the pack. The boot check catches the last; the first two show as an export error or a browser that hangs on load.
2. **JSON float leakage** into the sim (every phase): a float in state breaks determinism and hashes. `DefLoader.ints_only` and int-casting `from_dict` are the guard; the purity test cannot see a float that arrives from data.
3. **Typed-array and inference parse errors** (§7.3-7.4): the most common Flash-builder failure; the import step reports them.
4. **Unstable iteration** (dictionary order, unstable sort) breaking the save/load and replay hash tests (P02 onward).
5. **Captures need a window** (P00): run them windowed, never `--headless`.
6. **Phase size** at P04 (combat) and P05 (AI): build in the brief's order and commit each step green.
7. **AI command hygiene** (P05): planners emitting commands that fail validation; the soak fails hard on `AI_REJECT`.
8. **Frame spikes on the throttled browser** (P02 onward): any loop over all colonies/fleets/stars inside one frame, `_draw()` of the whole map every frame, or building Controls per turn instead of reusing them. Slice work (ARCHITECTURE §7.3), redraw on change, pool UI rows.

---

## Appendix A. Stat and flag vocabulary (`src/sim/defs/Stats.gd`)

An **effect** is `{ "stat": <id>, "op": "add" | "pct" | "floor" | "cap", "value": int, "filter": { ... } (optional) }`. A **flag** is a string rule switch, granted by a tech or building, read by one named rule file. Content validation fails on any stat or flag not listed here. Precedence (GDD §3.4): base → `floor` → `add` → `cap` → `pct` (summed, applied once) → floor to int → the stat's minimum. `filter` keys: `climates: [ids]`, `climate_class: "habitable" | "hostile"`, `band: "talon" | "beak" | "horizon"`, `hulls: [ids]`.

| Stat id | Scope | Min | Introduced | Used for |
|---|---|---|---|---|
| `pop_per_size` | colony (species x climate) | 0 | P01 | climate table, aquatic, any_puddle, tolerant floor, heat cap, Old Green, Climate Tailoring, Deep Down, Genesis, Dome Perches |
| `max_pop_flat` | colony | 0 | P02 | flat max-pop bonuses (none in MVP data; More Perch is `pop_per_size` add 1 at colony scope) |
| `food_per_farmer` | colony | 0 | P02 | farm/fish table, farming traits, Richer Dirt, Climate Lever, Kind Soil, aquatic |
| `food_flat` | colony | 0 | P02 | Grand Nest, Feed Hall, Root Scratch |
| `food_pct` | colony | — | P02 | unification |
| `industry_per_worker` | colony | 1 | P02 | minerals, industry traits, Second Shift Hall, Tireless Picks, Deep Scratch |
| `industry_flat` | colony | 0 | P02 | Grand Nest, buildings |
| `industry_pct` | colony | — | P02 | government, specialisation, supply lines, occupation, Strike, difficulty, events |
| `research_per_scientist` | colony | 1 | P02 | science traits, Research Roost, Loud Abacus, Flock Brain |
| `research_flat` | colony | 0 | P02 | Grand Nest, Night Lab, buildings |
| `research_pct` | colony | — | P02 | government, specialisation, night_hours, supply lines, difficulty |
| `job_yield_all` | colony | 0 | P06 | Every Job, Up (+1 to food/PP/RP per job) |
| `taxes_pct` | colony | — | P02 | tax traits, government, Seed Exchange, supply lines |
| `credits_flat` | colony | 0 | P02 | Grand Nest, Pretty Rocks, Rude Wealth |
| `growth_pct` | colony | — | P02 | growth traits, Second Clutch, The Dose, Quick Genes, difficulty, Snowball |
| `building_cost_pct` | empire | — | P02 | prefab_coops, Kit Nests |
| `building_upkeep_pct` | empire | — | P02 | reserved (no MVP source; keep for STRETCH Thrift Nest) |
| `ship_cost_pct` | empire / colony | — | P03 | feudal, Drydock of Regret, Yard Swarm, Yard spec, Yard Scrap, Ugly Perch |
| `ship_upkeep_pct` | empire | — | P03 | warlord, high_upkeep, The Upkeep Diet |
| `fuel_range` | empire | 0 | P03 | Downrange Charts..Far Cells (`cap`-style: use `floor` op with the tier range) |
| `nest_range_add` | empire | 0 | P06 | Far Nests |
| `map_speed_add` | empire (filter hulls) | 0 | P03 | fast_ships, Courier Wings |
| `combat_speed_add` | empire | 0 | P04 | fast_ships, The Kick, Lean-In (part) |
| `scan_add` | empire / colony | 0 | P03 | Grand Nest, Glance Pod, The Shared Glance, Destination Board |
| `ship_hp_pct` | empire | — | P04 | tough_hulls, Hard Down |
| `evasion_add` | empire | — | P04 | ship_defense traits, Null Glide, Soft Bones, Steady Bird |
| `accuracy_add` | empire | — | P04 | ship_attack traits, Drill Roost (new ships), veterancy |
| `band_damage_pct` | empire (filter band) | — | P04 | talon/beak/horizon_adepts |
| `marine_str_add` | empire | 0 | P04 | Standards and Talons, Personal Down, Boot Frame |
| `militia_str_add` | empire | 0 | P04 | Personal Down, Boot Frame |
| `troops_pct` | empire | — | P04 | ground traits |
| `ground_def_pct` | empire | — | P04 | subterranean |
| `planet_def_hp_pct` | empire | — | P04 | Fortified Nests, huddle |
| `planet_horizon_pct` | empire | — | P06 | Horizon Perch II |
| `trade_income_pct` | empire | — | P08 | fantastic_traders (x2 = +100), Trade Winds |
| `spy_score_add` | empire | — | P08 | spy traits, Battle Transcriber |
| `security_add` | empire | — | P08 | Security Nest, democracy (-20) |
| `relations_base` | empire | — | P08 | charismatic, notorious, repulsive, distrusted |

| Flag | Read by | Source |
|---|---|---|
| `dome_perches_1`, `dome_perches_2`, `crackle_shutters` | `Habitability` | PL2 core, PL3 opt A, PL4 opt A |
| `gravity_manners` | `Modifiers` (gravity) | FF4 core building |
| `plague_immune` | `Events` | The Dose |
| `two_chick_pods` | `Colonization` | PL6 opt B |
| `see_fleet_destinations` | `Visibility` | Destination Board |
| `scouts_read_planets_3pc` | `Visibility` | The Shared Glance |
| `reveal_enemy_designs` | `Visibility` | Loadout Glance (part), informants |
| `autopsy_loadouts` | `Autopsy` | Battle Transcriber |
| `beak_ignores_shields_100` / `beak_ignores_shields_75` | `CombatResolver` | Between the Feathers / Between the Ribs |
| `talon_extra_shot_alternate` | `CombatResolver` | The Long Honk |
| `early_mantle` | `CombatResolver` | FF2 opt A |
| `enemy_retreat_plus_2` | `Retreat` | Tractor Etiquette |
| `no_exit_home` | `Retreat` | No Exit |
| `two_steps_back_home` | `RangeTrack` start | Two Steps Back |
| `instant_regret` | `Retreat` | Instant Regret |
| `overpreen` | ship stats (+2 shield class) | FF6 opt A |
| `scatter_molt` | `CombatResolver` (incoming Horizon -20 acc) | FF1 opt B |
| `line_slots_plus_1` | `CombatResolver` line | Hyper-Preened Cognition |
| `toxic_preening` | `Bombardment`, `Diplomacy` | PL3 opt B |
| `drill_roost` | ship creation (new ships +5 accuracy veterancy) | CO2 opt B |
| `rock_picking` | `Economy` (outpost bodies feed the system's best colony) | CN2 opt B |
| `placid_trigger` | `Events` (Placid, Until) | WE6 opt B |

**Traits are not flags.** Rule code asks `empire.has_trait("<trait id>")` (or, for species traits, the colony's species); a trait row carries only the stat effects it has. Every trait id in `traits.json` is therefore valid wherever a rule checks for it, and the flag table above lists only tech and building switches.

## Appendix B. Command kinds (`CmdRegistry`)

| Phase | Kinds |
|---|---|
| P02 | `set_preset`, `set_jobs`, `queue_add`, `queue_remove`, `queue_move`, `queue_set_repeat`, `buy` |
| P03 | `design_save`, `design_delete`, `fleet_move`, `fleet_split`, `fleet_merge`, `fleet_auto_explore`, `colonize`, `outpost`, `set_battle_plan`, `set_line_order` |
| P04 | `battle_orders` (pipeline-answer only, never on the undo list), `fleet_bombard`, `fleet_invade` |
| P05 | `declare_war`, `propose_peace`, `answer_proposal`, `set_military_budget`, `accept_capitulation` |
| P06 | `research_set`, `research_queue`, `refit`, `upgrade_queued_designs` |
| P07 | `set_specialization`, `apply_template`, `bulk_colonies` |
| P08 | `propose_treaty`, `cancel_treaty`, `exchange`, `pledge_buy`, `council_vote`, `council_defy`, `council_accept`, `coalition_join`, `spy_target`, `spy_funding`, `security_level`, `steal_choose` |
| P09 | `event_choose` |

## Appendix C. `data/` files by phase

P00 `manifest`, `balance`, `audio`, `credits`, `copy/en` · P01 `galaxy`, `climates`, `traits` (governments are traits), `races`, `difficulty` · P02 `buildings`, `presets` · P03 `hulls`, `parts`, `roles` · P04 `monsters` · P05 `personalities` · P06 `techs` · P07 `specializations`, `specials`, `templates` · P08 (balance keys only) · P09 `events` · P10 audio rows, `credits` rows.
