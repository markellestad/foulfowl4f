# QA notes (orchestrator review, carried to later phases)

Each item names the phase expected to fix it. Builders: check this file at the start of every phase.

## From P01 review
- [P10 polish, or earlier if cheap] Galaxy map readability: stars render as tiny dots with no name labels; show star names (fade by zoom), larger star glyphs sized by star type, owner colour ring/halo per controlled system (not a lazy ring effect on everything: a subtle owner tint), and a legend for map lines (the dashed line in P01_galaxy.png is unexplained to a player).
- [P10] New Game: "Tiny (Sub)" preset label is unclear; give it player-facing copy.
- [P10] Main menu title should be visually a title (larger, bold), not the same size as the splash lines.
- [P10] Title presentation: show "Foul Fowl" as the large title and "Fly, Flock, Forage, Fight" as a subtitle line under it (copy key menu.title currently holds the full string; split into menu.title + menu.subtitle when styling the menu).
- [P11] Web size: wasm is 37.7 MB uncompressed (stock Godot engine). Measure the gzipped/zipped upload against the ~25 MB target; consider a custom export template with unused modules disabled if over.
- [copy pass] Posture names inconsistent across cards ("Talon range" vs "Close" on the Battle Orders card); resolve in the Fable copy pass / P05.
- [P05] Battle viewer is readable but static; judge feel in the owner's P05 browser evening.
