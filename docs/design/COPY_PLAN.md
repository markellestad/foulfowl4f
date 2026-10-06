# Foul Fowl 4X — Copy Plan

Merge pass, 2026-10-06. Maps every `[COPY: key]` slot in `GDD.md` (and the copy layer in `ARCHITECTURE.md` §5.4) to a line in `MEME_BIBLE.md`, or marks it as a gap for the writer.

## How to read this

- All player-facing strings live in **`data/copy/en.json`**, a flat `{ "key": "string" }` map. Mechanics files never hold display text.
- Status values:
  - **BIBLE**: use the meme-bible line verbatim. The source is cited as `MB§<section> #<n>` (meme strings) or `MB§1 <empire>` / `MB§3 <field>` / `MB§4 ev<n>` / `MB§6 <item>`.
  - **REWRITE**: the bible line exists but contradicts a mechanic in the GDD. The *why* column says what must change. The builder ships the bible line with that fix applied; the writer may polish it.
  - **GAP**: no line exists yet. The *needs* column says what to write. Until the writer fills it, the builder ships the id, prettified, as a fallback (`Copy.t(key, fallback)`).
  - **UNUSED**: a bible line with no home in this design. It is kept in the bible, not shipped.
- Placeholders use `{name}` tokens. The builder fills them; the writer must keep them.
- Plain functional UI labels (button text such as "End Turn", column headers, settings labels) are written by the builder under `ui.label.*`. They are not the writer's job unless a row below asks for flavour.
- Voice rules are `MEME_BIBLE.md` lines 7-22. No real trademarks or product names.

## Key scheme

| Prefix | Shape | Example |
|---|---|---|
| `menu.*` | splash, tagline, presets, toggles, quit | `menu.splash.2` |
| `difficulty.<id>.{name,tip}` | `nestling`, `flighted`, `honk_admiral`, `lights_off_ledger` | `difficulty.honk_admiral.tip` |
| `race.<id>.{name,species,leader,leader_tip,pitch,footer,confirm,signature,signature_tip}` | 8 race ids | `race.swans.footer` |
| `trait.<id>.{name,tip}` | GDD §4.1 ids | `trait.v_formation.tip` |
| `personality.<id>.name` | `unbothered`, `sportsman`, `dealmaker`, `librarian`, `patient_rock`, `borrower`, `neighbor`, `floor` | |
| `diplo.<race>.{greeting,threat,peace,war,defeat}` | | `diplo.geese.threat` |
| `taunt.<race>.<situation>` | triggers in §D | `taunt.crows.steal` |
| `diplo.reason.<id>` | AI deal-evaluation reasons | `diplo.reason.distrust` |
| `field.<id>.{name,blurb}` | 6 field ids | `field.propulsion.name` |
| `tech.<id>.{name,flavor}` | techs.json ids | `tech.pecking_logs.name` |
| `tier.hyper_preened.{label,flavor}` | | |
| `building.<id>.{name,tip}` / `part.<id>.{name,tip}` / `hull.<id>.name` / `role.<id>.{name,tip}` | | |
| `climate.<id>.name` / `star.<type>.name` / `special.<id>.{name,tip}` / `place.orn.name` | | |
| `monster.<id>.{name,roar,warning}` | `guardian`, `leviathan` | |
| `event.<id>.{title,body,choice.<n>,result.<n>}` | GDD §20 ids | `event.placid_until.choice.1` |
| `news.*` / `notify.*` / `summary.*` | PNN ticker, toasts, turn summary | `news.pnn.ident` |
| `ui.*` | flavour tooltips | `ui.fleet.doomstack` |
| `council.*` / `coalition.*` / `battle.autopsy.*` | | |
| `victory.<id>.{title,body}` / `victory.banner.<race>` / `defeat.<id>.body` | | |
| `tip.loading.<n>` | loading-tip rotation | `tip.loading.4` |
| `ach.<id>.{name,unlock}` | STRETCH (local Feats) | |
| `star.name.<n>` | NameGen pool | |

## A. Menu, difficulty, credits

| Key | Status | Source | Why / needs |
|---|---|---|---|
| `menu.splash.1..3` | BIBLE | MB§2 #1-3 | |
| `menu.tagline`, `menu.tagline2` | BIBLE | MB§2 #4, #5 | |
| `menu.preset.evening_standard.name` / `.sub` | REWRITE | MB§2 #6 | Change "Thirty-two stars" to "Twenty-four stars" (GDD §2.1). |
| `menu.toggle.seat_swans` / `.tip` | BIBLE | MB§2 #7 | |
| `menu.quit_confirm` | BIBLE | MB§2 #8 | The One More Turn button exists after victory (GDD §14). |
| `victory.one_more_turn` | GAP | — | Button tooltip; can echo MB§2 #71. |
| `difficulty.<4>.name` | BIBLE | MB§2 #9 | |
| `difficulty.lights_off_ledger.tip` | REWRITE | MB§2 #9 | Ledger now also has +40/+40/+20 bonuses and vision; "None of them are gentle" still fits. Add the vision. |
| `difficulty.honk_admiral.tip` | BIBLE | MB§2 #22 | Matches: printed bonuses plus design vision. |
| `difficulty.nestling.tip`, `difficulty.flighted.tip` | GAP | — | Nestling: AI is handicapped and passive. Flighted: fair, no bonuses, the default. |
| `credits.1`, `credits.2` | BIBLE | MB§2 #10, #11 | |

## B. Races (8 x 9 keys)

`name`, `leader` and `pitch` come from MB§1 for all eight races: BIBLE. Species names are the plain bird names.

| Race | `leader_tip` | `footer` | `confirm` | `signature` / `signature_tip` |
|---|---|---|---|---|
| swans | BIBLE MB§2 #17 | BIBLE #12 | BIBLE #13 | REWRITE #18: "Movement +1. Research costs -15%" becomes "Movement +1. Scientists +1. Accuracy +20. The rest of the card is also a problem." (GDD §4.3) |
| pheasants | GAP (cockade line in MB§1 works) | BIBLE #14 | GAP | REWRITE MB§1 Flush: add "+20% damage in round 1 when attacking" and "enemy retreat delayed one round in the first battle of a war" |
| ducks | GAP | BIBLE #15 | GAP | REWRITE MB§1 Any Puddle: "every habitable world supports at least 3 per size" instead of the 50% habitability floor |
| owls | GAP | GAP | GAP | Wide-Eyed = `trait.creative.tip`: BIBLE #62. Night Hours: BIBLE MB§1 |
| penguins | GAP | GAP | GAP | REWRITE MB§1 Piscivore ("fisheries/hydroponics still work") and Huddle (8% repair becomes full repair at own colonies) |
| crows | GAP (the murder pun in MB§1) | GAP | GAP | Cache: BIBLE MB§1 (50% cost; "seen" = battle, spy, or diplomacy) |
| geese | GAP | BIBLE #16 | GAP | V-Formation: BIBLE #19 |
| chickens | GAP | GAP | GAP | REWRITE MB§1 One-Note (drop the -15% research) and Nothing Wasted (now "rush-buying costs 1.5x and is never doubled") |

`diplo.<race>.{greeting,threat,peace,war,defeat}`: BIBLE for all 40 lines (MB§1, each race's five lines).

## C. Traits

| Key | Status | Source / needs |
|---|---|---|
| `trait.notorious` | BIBLE name "Notorious Perfection" (MB§1 Swans) | REWRITE the tip: -20 relations, not -40; Coalition at 30% with +15. |
| `trait.flush`, `trait.any_puddle`, `trait.night_hours`, `trait.piscivore`, `trait.huddle`, `trait.cache`, `trait.territorial` (bible "Airspace"), `trait.v_formation`, `trait.uncreative` (bible "One-Note"), `trait.nothing_wasted`, `trait.creative` (bible "Wide-Eyed") | BIBLE names | Tips per section B: rewrite wherever numbers changed (GDD §21.2). |
| `trait.scavengers` | GAP | Name and tip. MB§1 calls it "salvage". |
| `trait.distrusted`, `trait.heat_intolerant`, `trait.tough_hulls`, `trait.high_upkeep`, `trait.prefab_coops`, `trait.talon_adepts`, `trait.beak_adepts`, `trait.horizon_adepts` | GAP | Bird-punned names and tips. |
| All generic traits (growth, farming, industry, science, taxes, ship attack/defense, ground, spying, governments, aquatic, subterranean, tolerant, gravity, homeworld, charismatic, repulsive, fantastic_traders, lucky, omniscient, stealthy_ships, warlord, fast_ships) | GAP | ~35 names and tips. MoO-style names are fine as parody; no trademarks. |
| `trait.swan_privilege.tip` | GAP | Explains the 13 picks. Can borrow the voice of MB§2 #11. |

## D. Personalities and taunts

| Key | Status | Source / trigger |
|---|---|---|
| `personality.<8>.name` | BIBLE | MB§1 "AI - The ..." |
| `taunt.swans.contact` | BIBLE MB§2 #41 | First contact with Swans |
| `taunt.swans.losing_war` | BIBLE #42 | Player wins 3 battles in a row against Swans |
| `taunt.geese.border` | BIBLE #43 ("Honk.") | Foreign fleet enters a system within 6 pc of a Goose colony (once per fleet) |
| `taunt.owls.refuse_war` | BIBLE #44 | Owls reject a war-related demand or alliance call |
| `taunt.crows.steal` | BIBLE #45 | A Crow steal succeeds against the player |
| `taunt.ducks.credit_lead` | BIBLE #46 | Ducks' treasury is at least 2x the player's on contact refresh |
| `taunt.penguins.warm_world` | BIBLE #47 | Player asks Penguins for a tech or treaty while owning a Desert or Arid colony near them |
| `taunt.chickens.accept_war` | BIBLE #48 | War declared on Chickens |
| `taunt.pheasants.declare_war` | BIBLE #49 | Pheasants declare war |
| Other race x situation pairs | GAP (optional) | |
| `diplo.reason.*` (value, distrust, coalition, pledge, tribute, territorial, ...) | GAP | Short and dry, one per AI reason line in GDD §12.2. |

## E. Research

| Key | Status | Source / needs |
|---|---|---|
| `field.{computers,construction,planetology,propulsion,weapons}.name` | BIBLE | Flocknet, Nestworks, Plumage, Flightcraft, Broodheat (MB§3) |
| `field.<5>.blurb` | BIBLE | The one-line intro under each MB§3 heading |
| `field.force_fields.name` / `.blurb` | GAP | Placeholder "Downfield". Needs a name and blurb; shields and defensive fields. |
| `tier.hyper_preened.label` / `.flavor` | BIBLE | MB§2 #61 |
| `tech.hyper_<field>.name` | GAP | Pattern "Hyper-Preened <Field> II, III...". Needs one flavour per field. |
| 37 adopted tech names (bold in GDD §6.3) | BIBLE names; flavours below | |
| Remaining ~107 tech names and flavours (plain in GDD §6.3) | GAP | Include every Downfield tech. |

Bible tech flavours that contradict their new effect (REWRITE):

| Tech | Why |
|---|---|
| Second Shift | It is now the Automated Factory. Overflow carry-over belongs to everyone, so the Chicken line is wrong. |
| Better Feed | It is the Hydroponic Farm, which Penguins *do* use. Drop "Penguins do not use this". |
| Titan Perch | "Counts as three against the fleet cap" becomes "takes two battle-line slots". |
| The Unsinkable Argument | Drop the Swan discount. |
| Spreadsheet of Fate | Now Horizon +10 accuracy (Thesis Range), not a building. |
| Battle Transcriber | Now +30 spy score plus enemy loadouts in the autopsy. There is no offense/defense choice. |
| Toxic Preening | Crow framing is STRETCH. Keep the relations hit. |
| Heart of the Roost | Now the Very Polite Warhead (bombardment), not a planet-killer chassis or system shield. |
| Hyper-Preened Thermals | Now Death Ray. The warhead is the sibling option. |

**Placed but unchanged** (BIBLE): Pecking Logs, Research Roost, The Shared Glance, Everyone Can Miss, Predictive Peck, Hyper-Preened Cognition, Reinforced Roost, Drydock of Regret, Proper Joinery, Automated Incubators, Standards and Talons, Self-Sealing Nest, Molt Management, Climate Tailoring, Deep Down, Hyper-Preened Genesis, Downrange Charts, Warm Current, Tailwinds, The Folded Sky, Migratory Math, Instant Regret, Roost Lanes, Hyper-Preened Kinematics, Second Sun, Focused Glare, The Long Honk, Quiet Star.

**UNUSED**: Shared Body Heat, Pinion Reactor, Hyper-Preened Mandate, and all Roost Law techs.

## F. Buildings, parts, hulls, roles

| Key | Status | Source / needs |
|---|---|---|
| `building.automated_factory.name` = "Second Shift Hall", `.tip` | BIBLE | MB§2 #53 |
| `building.departure_roost.name` | BIBLE | MB§3 terminal keys. The tip is a GAP. |
| `building.star_gate.name` | BIBLE | "Roost Lanes" gate. The tip is a GAP. |
| `building.hydroponic_farm.name_piscivore` | GAP | "Fishery" variant for Penguins |
| Other 20 buildings (GDD §5.8) | GAP | Names and tips |
| `part.very_polite_warhead` | BIBLE | MB§2 #56 |
| `part.orn_plating` | BIBLE | MB§2 #59 |
| `ui.retreat.receipt_tip` | BIBLE | MB§2 #58 (the Straggler Coupling line, used as the retreat tooltip) |
| `role.horizon_boat.tip` | BIBLE | MB§2 #60 (Pure Missile Honesty) |
| `event.letter_of_marque.choice.1` tip | REWRITE | MB§2 #57 becomes an event-choice tooltip, not a part. |
| Weapon part names: Laser, Fusion Beam, Phasor, Plasma Cannon, Death Ray, Mass Driver, Gauss, Hellbore, Graviton, Nuclear/Merculite/Pulson/Zeon missiles, Antimatter Torpedo | GAP, **priority** | Placeholders. Several are coined terms from the MoO series (Merculite, Pulson, Zeon, Zortrium, Neutronium, Hellbore). Replace them with parody bird-band names (Talon / Beak / Horizon families). |
| Armor (Titanium ... Adamantium), shields, computers, engines, specials (GDD §7.3) | GAP | Same rule: bird or parody names. Drop Zortrium. |
| `hull.titan.name` = "Titan Perch" | BIBLE | MB§3 Nestworks 6 |
| `hull.{small,medium,large,huge}.name` | GAP | Placeholders: Sparrow, Kestrel, Heron, Albatross |
| `role.<8>.name` / `.tip` | GAP | Except the Horizon Boat tip |

**UNUSED**: Thesis Range as a building (MB§2 #50), Lane Perch #51, Still Perch #52, Council Minutes Office #54, Review Desk #55. Thesis Range survives as a modifier: its tooltip is a REWRITE of #50 that drops "6% range" in favour of "+10 accuracy".

## G. World

| Key | Status | Source / needs |
|---|---|---|
| `place.orn.name` | BIBLE | "Orn" (MB vocabulary) |
| `monster.guardian.name` | BIBLE | "Guardian of Orn" |
| `monster.guardian.warning` | BIBLE | MB§4 ev3 body |
| `monster.guardian.roar` | GAP | |
| `notify.guardian_marked` | GAP | Name the -10% for 10 turns. |
| `monster.leviathan.name` | BIBLE | "Pond-Scum Leviathan" (MB§4 ev2) |
| `monster.leviathan.roar` | GAP | |
| `climate.<11>.name` | GAP | Decide the display names. The bible uses "Ice" (id `tundra`) and "Jungle" (id `swamp`). |
| `star.<type>.name` | GAP | 6 star types |
| `star.name.<n>` | GAP | Pool of about 80 star names for NameGen, bird-punned |
| `special.<7>.{name,tip}` | GAP | GDD §3.4 |

## H. Events (GDD §20)

| Event id | Status | Source / needs |
|---|---|---|
| tier_list_leaks | BIBLE | MB§4 ev1 title and body |
| pond_scum_leviathan | REWRITE | MB§4 ev2: "drifted into a lane" becomes "drifted into a system". Add `choice.tag`. |
| guardian_of_orn | BIBLE | MB§4 ev3 |
| tall_shapes | BIBLE (STRETCH) | MB§4 ev4 and MB§2 #63 |
| henhouse_war | UNUSED (STRETCH) | MB§4 ev5 |
| placid_until | BIBLE | MB§4 ev6 with choices Arm / Mothball |
| midgame_sit | BIBLE | MB§4 ev7 with choices Rivalry / Pull the Grand Roost |
| while_you_were_away | BIBLE | MB§2 #38 goes to `summary.digest.title/body` |
| letter_of_marque | BIBLE | MB§4 ev9 with choices Pay / Decline |
| corner_colonist | BIBLE | MB§4 ev10 |
| snowball_named | BIBLE | MB§4 ev11 and MB§2 #32 |
| perch_review | BIBLE | MB§4 ev12. `result.5`, `result.3`, `result.2` are GAPs (star-rating lines). |
| pure_missile_honesty | UNUSED | Its line becomes the role tooltip (section F). |
| spreadsheet_you_wanted | BIBLE | MB§4 ev14 with choices Adopt / Shred |
| called_to_the_grand_roost | REWRITE | MB§4 ev15: drop "threaten" (STRETCH). Bribe means pledge. |
| mineral_strike, derelict_hull, data_moult, bountiful_season, feather_plague | GAP | Title, two-sentence body, and result line each |

## I. Grand Roost, Coalition, battle, victory clock

| Key | Status | Source / needs |
|---|---|---|
| `council.name` = "Grand Roost" | BIBLE | |
| `council.title` = "Supreme Bird" | BIBLE | |
| `council.abstain_tip` | BIBLE | MB§2 #24 |
| `notify.elected` | BIBLE | MB§2 #35 |
| `council.accept` / `council.defy` (button tips) | GAP | Defy means war with every voter for the winner. |
| `council.pledge_tip` | GAP | Can lean on loading tip #16. |
| `coalition.label.tier_list` / `.label.snowball` | BIBLE | Labels from MB§5 idea 8 |
| `coalition.tip` | BIBLE | MB§2 #28 (the Snowball tooltip) |
| `coalition.formed` | BIBLE | Via event tier_list_leaks |
| `ui.fleet.doomstack` / `ui.fleet.doomstack_tip` | BIBLE | MB§2 #20 |
| `ui.battle_line.tip` | REWRITE | MB§2 #21: "Ships over the cap arrive next turn" becomes "ships beyond the line wait in reserve and fill gaps as the line dies". |
| `ui.battle.pause_tip` | BIBLE | MB§2 #25 |
| `ui.trade.locked` | BIBLE | MB§2 #23, for Exodus keys |
| `ui.automation_tip` | BIBLE | MB§2 #27 |
| `battle.autopsy.{decided_by,standout,receipt,no_retreat}` | GAP | Templates with `{band}`, `{ship}` |
| `ui.victory_clock.{title,grand_roost,exodus,conquest}` | GAP | Templates |

## J. News and flavour notifications

| Key | Status | Source | Trigger |
|---|---|---|---|
| `news.pnn.ident` | BIBLE | MB§2 #30 | Ticker header |
| `notify.scout_war` | BIBLE | MB§2 #31 | War declared on the player by an empire whose visible armed fleet is zero |
| `notify.snowball` | BIBLE | MB§2 #32 | snowball_named fires |
| `notify.tech_done` | BIBLE | MB§2 #34 | Research complete (the flavour suffix) |
| `notify.swans_lead` | BIBLE | MB§2 #36 | Swans are score leader for 10 straight turns (once per game) |
| `news.swans_seated` | BIBLE | MB§2 #39 | First PNN item of a game with Swans present |
| `news.leviathan` | BIBLE | MB§2 #40 | pond_scum_leviathan fires |
| `notify.moulted`, `notify.crisis` | BIBLE (STRETCH) | MB§2 #33, #37 | The Moulted / The Big Quiet |
| `news.<kind>` (war between others, Grand Roost result, Guardian killed, Exodus started, capitulation) | GAP | — | One PNN line each |
| `notify.*` functional (colony founded, starvation, strike, invasion won/lost, treaty offered/ended) | GAP | — | Short, factual, a light joke at most |
| `summary.digest.title/body` | BIBLE | MB§2 #38 | |

**UNUSED**: pollution tooltip #26 (no pollution system) and abandon-colony tooltip #29 (abandoning a colony is STRETCH; keep the line for then).

## K. Victory, defeat, banners

| Key | Status | Source / needs |
|---|---|---|
| `victory.conquest.body` | BIBLE | MB§6 Conquest. The extra line "Against the swans." is BIBLE. |
| `victory.grand_roost.body` | REWRITE | MB§6: drop "You hold Hyper-Preened Mandate". |
| `victory.exodus.body` | BIBLE | The rule text shown beside it must say all fields at tier 7 or above. |
| `victory.called_game.body` | REWRITE | "Turn 200" becomes "the horizon" (the cap is 250 on Evening Standard). |
| `victory.banner.{swans,pheasants,ducks,against_swans}` | BIBLE | MB§6 banner variants |
| `victory.banner.<other 5>` | GAP | Optional |
| `defeat.capitals_gone`, `defeat.called_game`, `defeat.as_swans`, `defeat.as_pheasants` | BIBLE | MB§6 |
| `defeat.accepted_supreme_bird` | REWRITE | MB§6 "refused vassalage": the condition is now *Accepting* the vote (GDD §12.3). |
| `defeat.big_quiet` | BIBLE (STRETCH) | |

## L. Loading tips (`tip.loading.1..20`)

BIBLE for MB§6 tips 1-3, 6-18 and 20. The rest need a REWRITE:

| Tip | Why |
|---|---|
| 4 | "thirty-two stars" becomes twenty-four |
| 5 | The cap is now the battle line. Suggested: "A fleet of eight renames itself. The battle line keeps the rename a choice." |
| 19 | Lanes do not exist. Rewrite around fuel range or the wormhole: "the corridor you notice during the invasion is a traffic report". |

## M. Achievements (`ach.*`, STRETCH as local Feats)

BIBLE for all 12 (MB§2 #64-75). Their triggers map to existing mechanics. "Long Way Round" needs a definition of a rim system; use a star within 4 pc of the map edge.

## Gap summary for the writer (priority order)

1. Weapon, armor, shield and special part names to replace MoO-coined terms (section F).
2. A name and blurb for the Force Fields field, plus all 24 Downfield tech names and flavours.
3. The ~107 other tech names and flavours, and the four Hyper-Preened repeatable flavours.
4. Generic trait names and tips (~45), plus Swan Privilege.
5. Building, hull, role and special names and tips; climate, star-type and star-name pools.
6. Five classic events; Perch Review result lines; autopsy and victory-clock templates.
7. Functional notifications and PNN lines; council Accept / Defy / pledge tips.
8. The REWRITE rows above (small edits to existing bible lines).
9. Optional: missing race footers and confirms, extra taunts, and banners for the five other races.
