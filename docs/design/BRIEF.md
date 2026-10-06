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
- Sounds: pull freely from `<FOULFOWL_SOUND_ASSETS>\` (fully licensed: Kenney packs, Shapeforms, Sci-Fi UI/Combat packs, Explosion pack, and the owner's Suno music folders IESunoMusic / SnakeSunoMusic). Copy only what is used into the repo, converted to OGG; keep the web build small.
- Art: no external image assets required; procedural/vector art drawn in Godot (bird silhouettes from simple shapes, star map, planets as shaded circles are fine for planets — planets are round; effects must not be lazy rings).
- Single-player vs AI. No networking.
- No real company/product trademarks as names; parody names are fine.
- Process: architect -> red team -> engineer -> build to plan -> QA -> revise -> final. The builder is agy (Gemini Flash); design and copy are by Opus 5.5 and Grok 4.7.
