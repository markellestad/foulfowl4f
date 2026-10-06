# QA notes (orchestrator review, carried to later phases)

Each item names the phase expected to fix it. Builders: check this file at the start of every phase.

## From P01 review
- [P10 polish, or earlier if cheap] Galaxy map readability: stars render as tiny dots with no name labels; show star names (fade by zoom), larger star glyphs sized by star type, owner colour ring/halo per controlled system (not a lazy ring effect on everything: a subtle owner tint), and a legend for map lines (the dashed line in P01_galaxy.png is unexplained to a player).
- [P10] New Game: "Tiny (Sub)" preset label is unclear; give it player-facing copy.
- [P10] Main menu title should be visually a title (larger, bold), not the same size as the splash lines.
- [P10] Title presentation: show "Foul Fowl" as the large title and "Fly, Flock, Forage, Fight" as a subtitle line under it (copy key menu.title currently holds the full string; split into menu.title + menu.subtitle when styling the menu).
