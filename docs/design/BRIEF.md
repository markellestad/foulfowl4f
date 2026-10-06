# Foul Fowl 4X — Brief (owner, 2026-10-06)

> "Foul Fowl 4X?
> Ducks.
> Pheasants for the win.
> Swans OP."

## What it is
A **Master of Orion-style space 4X** (MoO1/MoO2 lineage) where every empire is a bird species, built as a **marketing meme for the eXplorminate Discord** — a server full of serious 4X enthusiasts. It ships on **itch.io** as a free browser game (Godot 4.6 web export, single-threaded, plus an optional Windows download).

## Priorities, in order
1. **Excellent core gameplay by classic 4X standards.** This audience knows MoO, MoO2, Stellaris, Endless Space, GalCiv, SotS, Aurora, Distant Worlds. The game must be genuinely good to play for an evening: meaningful explore/expand/exploit/exterminate decisions, asymmetric races that play differently, a tech tree with real choices, ship design that matters, readable combat, a competent AI, and victory conditions that end the game.
2. **Modern ease of use.** No 1993 micromanagement pain: build queues with repeat, colony-wide automation toggles, auto-explore scouts, a turn summary/notifications, tooltips everywhere, hotkeys, undo-friendly UI, clear numbers, fast turns, save/load, a short "standard" game (roughly 150-250 turns, an hour or two) on a small galaxy.
3. **Genre reference copy and memes.** Fill it with in-jokes the 4X crowd will screenshot and share: the opening quote ("Swans OP" — swans really are strong, and the game should be in on it), MoO/MoO2 references (the Orion guardian, the Antarans, the Galactic Council vote, Psilons/Silicoids, "Creative" trait, the Hyper-Advanced tech levels), Stellaris/Paradox jokes (end-game crises, "the war in heaven", Space Amoebas), Civ ("one more turn", Gandhi's nukes), Endless/GalCiv/Sins/Aurora/Distant Worlds nods, doomstacks, AI cheating, "4X = eXplore eXpand eXploit eXterminate", eXplorminate itself (respectfully), the "Snowball" problem, mid-game slog, Space Elves, the inevitable "just one more turn" — all bird-punned. Funny, affectionate, never mean, never using real trademarks as product names.
4. **Simple but clear VFX.** Readable at a glance; style over fidelity. No ring/doughnut-default effects.

## Hard constraints
- Engine: Godot 4.6 (exe at `C:\Dev\InfiniteEmpire\GodotExe\`), GDScript with static typing, web export for itch.io (single-threaded: no SharedArrayBuffer requirement), runs at 60 fps in a browser on a mid laptop.
- Sounds: pull freely from `<FOULFOWL_SOUND_ASSETS>\` (fully licensed: Kenney packs, Shapeforms, Sci-Fi UI/Combat packs, Explosion pack, and the owner's Suno music folders IESunoMusic / SnakeSunoMusic). Only the open tier (Kenney CC0 + owner Suno music) is committed to the repo; licensed packs are fetched at build time (see "Open source and licensing" below). Convert used sounds to OGG; keep the web build small.
- Art: no external image assets required; procedural/vector art drawn in Godot (bird silhouettes from simple shapes, star map, planets as shaded circles are fine for planets — planets are round; effects must not be lazy rings).
- Single-player vs AI. No networking.
- No real company/product trademarks as names; parody names are fine.
- Process: architect -> red team -> engineer -> build to plan -> QA -> revise -> final. The builder is agy (Gemini Flash); design and copy are by Opus 5.5 and Grok 4.7.

## Open source and licensing (owner, 2026-10-06: the repo will be a public open-source GitHub repo)
- **Code license: MIT** (LICENSE file at the root).
- **Font:** Atkinson Hyperlegible (SIL OFL 1.1), `assets/fonts/` with `OFL.txt`. Default UI font.
- **Audio, two tiers (hard rule):**
  - **Committed to the repo:** only redistributable audio: the Kenney packs (CC0: `kenney_impact-sounds`, `kenney_interface-sounds`, `kenney_sci-fi-sounds`) and the owner's own Suno music (`IESunoMusic`, `SnakeSunoMusic`). Put these under `assets/audio/open/`.
  - **NOT committed:** sounds from the paid/licensed packs (David Dumais "Explosion SFX Pack", Shapeforms packs, `SCI-FI_UI_SFX_PACK`, "Sci-Fi Combat Systems Sound Effects Pack"). Their licenses allow use in a shipped game but not redistribution of the raw files, which a public repo would do. They live under `assets/audio/licensed/` (gitignored), copied and converted at build time by `tools/fetch_licensed_audio` from a committed manifest (source path + target name per sound) pointing at the owner's local SoundAssets folder. The game must run and sound acceptable WITHOUT the licensed folder (fall back to the open sound for each slot), so a fresh clone of the public repo works.
  - Credits screen lists Kenney (CC0, credited anyway), the font, and the licensed packs by vendor name.
- No real trademarks as product names (parody/reference in copy is fine).

## Performance target (owner, 2026-10-06: "max compatibility")
No specific reference machine. Target the lowest common denominator so the itch page works for everyone:
- Godot **Compatibility** renderer (WebGL 2), single-threaded web export (no SharedArrayBuffer, no special itch headers).
- Runs on Chrome, Firefox, Edge and Safari (desktop), on a ~2018 laptop with integrated graphics and 4 GB RAM: steady 60 fps on the galaxy map, battle viewer >= 30 fps, no single frame over 50 ms during End Turn.
- Minimum window 1280x720, UI scale option; mouse-only playable (keyboard shortcuts optional).
- Download small: initial web build under ~25 MB, audio streamed/compressed OGG.
- The local performance check uses the dev machine with the browser's CPU throttled 4x as the stand-in for the low-end target.
