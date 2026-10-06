# Foul Fowl: Fly, Flock, Forage, Fight — Copy Plan

Revision 4 (red team round 2), 2026-10-06. Maps every player-facing string to its source. All strings ship in **`data/copy/en.json`** (flat `{key: string}`); mechanics files hold no display text.

## Sources and status

| Status | Meaning |
|---|---|
| **BIBLE** | Verbatim from `MEME_BIBLE.md` (cited `MB§section #n`) |
| **GROK1** | Verbatim from `redteam/grok_redteam_and_copy_1.md` Part B (cited `B1`..`B8`) |
| **GROK2** | Verbatim from `redteam/grok_redteam_2.md` §Copy (cited `R2 #n`); §M below |
| **REWRITE** | A BIBLE or GROK1 line that must change to match GDD revision 3; the new text or the required fix is given here |
| **GAP** | Not written yet; the *needs* column says what. Until filled, the builder ships the prettified id via `Copy.t(key, fallback)` |
| **UNUSED** | Written but not shipped in MVP (kept for STRETCH) |

Tokens like `{place}` are filled by the builder and must be kept by the writer. Functional UI labels (`ui.label.*`: buttons, column headers, settings) are the builder's job. Voice: `MEME_BIBLE.md` lines 7-22.

## Do-not-ship list (enforced by a content test, ARCHITECTURE §15.2)

From Grok B intro, plus the MoO-coined terms: Merculite, Pulson, Zeon, Zortrium, Neutronium, Hellbore, Adamantium, Tritanium, Phasor, Phaser, Death Ray, Galactic Cybernet, Recyclotron, Autolab, Time Warp Facilitator, Inertial Stabilizer, Inertial Nullifier, Inertial Damper, Aegis, Psilon, Silicoid, Darlok, Klackon, Alkari, Mrrshan, Bulrathi, Sakkra, Meklar, Gnolam, Antaran, Orion (as a place or name; "Orn" is ours). "Antimatter" is not a part name. The owner checks the title and faction names for trademark confusion before release (ARCHITECTURE P11).

## Key scheme

`menu.*`, `difficulty.<id>.{name,tip}`, `race.<id>.{name,species,leader,leader_tip,pitch,footer,confirm,signature,signature_tip,patch_line}`, `trait.<id>.{name,tip}`, `personality.<id>.name`, `diplo.<race>.{greeting,threat,peace,war,defeat}`, `taunt.<race>.<situation>`, `diplo.reason.<id>`, `field.<id>.{name,blurb}`, `tech.<id>.{name,flavor}`, `tier.hyper_preened.{label,flavor}`, `building.<id>.{name,tip}`, `part.<id>.{name,tip}`, `hull.<id>.name`, `role.<id>.{name,tip}`, `spec.<id>.{name,tip}`, `budget.<id>.{name,tip}`, `battle.orders.*`, `battle.autopsy.*`, `climate.<id>.name`, `star.<type>.name`, `star.name.<n>`, `special.<id>.{name,tip}`, `place.orn.name`, `monster.<id>.{name,roar,warning}`, `event.<id>.{title,body,choice.<n>,result.<n>}`, `news.*`, `notify.*`, `summary.*`, `ui.*`, `council.*`, `coalition.*`, `victory.*`, `defeat.*`, `credits.*`, `tip.loading.<n>`, `ach.<id>.*` (STRETCH).

## A. Menu, difficulty, credits

| Key | Status | Source / text |
|---|---|---|
| `menu.splash.1..3`, `menu.tagline`, `menu.tagline2` | BIBLE | MB§2 #1-5 |
| `menu.preset.evening_standard.name` | BIBLE | MB§2 #6 (name) |
| `menu.preset.evening_standard.sub` | GROK1 | B8 ("Twenty-four stars. One sitting...") |
| `menu.preset.evening_standard.seats` | GAP | Names the seating rule: Swans, an early-war bird, a schemer (GDD §2.1) |
| `menu.toggle.seat_swans` / `.tip`, `menu.quit_confirm` | BIBLE | MB§2 #7, #8 |
| `victory.one_more_turn` | GROK1 | B7 |
| `difficulty.<4>.name` | BIBLE | MB§2 #9 |
| `difficulty.nestling.tip`, `difficulty.flighted.tip` | GROK1 | B7 |
| `difficulty.honk_admiral.tip` | BIBLE | MB§2 #22 |
| `difficulty.lights_off_ledger.tip` | GROK1 | B8 |
| `credits.1`, `credits.2` | BIBLE | MB§2 #10, #11 |
| `credits.attribution.*` | GAP | Plain attribution lines generated from `data/credits.json` (Atkinson Hyperlegible / Braille Institute / OFL; Kenney CC0; owner music; licensed vendors when bundled). Functional, not jokes |

## B. Races

| Key group | Status | Source |
|---|---|---|
| `race.<8>.{name,leader,pitch}` | BIBLE | MB§1 |
| `race.swans.{leader_tip,footer,confirm}` | BIBLE | MB§2 #17, #12, #13 |
| `race.swans.signature_tip` | GROK1 | B8 |
| `race.swans.patch_line` | GROK1 | Part A §6: "They get hunted. That is the patch." |
| `race.pheasants.footer`, `race.ducks.footer`, `race.geese.footer` | BIBLE | MB§2 #14, #15, #16 |
| All other `leader_tip`, `footer`, `confirm` | GROK1 | B7 race-screen gaps |
| `race.pheasants.signature_tip`, `race.ducks.signature_tip` | GROK1 | B8 |
| `race.crows.confirm` | REWRITE | B7 line is fine; add nothing about omniscience (Crows now have informants, not full-map vision) |
| `diplo.<race>.*` (40 lines) | BIBLE | MB§1 |
| `victory.banner.<race>` | BIBLE (swans, pheasants, ducks, against_swans) + GROK1 B7 (owls, penguins, crows, geese, chickens) | |

## C. Traits

| Key | Status | Source / fix |
|---|---|---|
| Generic trait names and tips (growth ... warlord, fast_ships, tough_hulls, high_upkeep, prefab_coops, scavengers, distrusted, heat_intolerant, weapon bands, governments, homeworlds, charismatic, repulsive, fantastic_traders, lucky, omniscient, stealthy_ships, swan_privilege) | GROK1 | B4 |
| Bible-named traits (notorious "Notorious Perfection", flush, any_puddle, night_hours, piscivore, huddle, cache, territorial "Airspace", v_formation, uncreative "One-Note", nothing_wasted, creative "Wide-Eyed") | BIBLE names | MB§1 |
| `trait.notorious.tip`, `trait.flush.tip`, `trait.any_puddle.tip`, `trait.piscivore.tip`, `trait.huddle.tip`, `trait.v_formation.tip`, `trait.territorial.tip`, `trait.nothing_wasted.tip` | GROK1 | B8 |
| `trait.uncreative.tip` | REWRITE | B8 → "You choose one application. The sibling is never offered to your labs. Trade and theft can still fetch it." |
| `trait.creative.tip` | BIBLE | MB§2 #62 |
| `trait.informants.name` / `.tip` | GAP | New Crow trait: treasuries, treaties and ship designs of every met empire are visible |

## D. Personalities, taunts, deal reasons

| Key | Status | Source |
|---|---|---|
| `personality.<8>.name` | BIBLE | MB§1 |
| `taunt.<race>.<situation>` (9 triggers in revision 2) | BIBLE | MB§2 #41-49 |
| `taunt.swans.coalition`, `taunt.owls.peace_broken`, `taunt.crows.cache` | GROK1 | B7 |
| `diplo.reason.{value,distrust,coalition,pledge,tribute,territorial,relation,exodus_locked,backstab,war,price}` | GROK1 | B7 |
| `diplo.reason.transfer_limit` | GAP | "We already sent you something this decade" style: one tech per 10 turns |
| `diplo.reason.pledge_cap` | GAP | Refusal: pledge cap reached (`not_kingmaker` is deleted with the rule in revision 4) |

## E. Research

| Key | Status | Source / fix |
|---|---|---|
| `field.<5>.name/blurb` | BIBLE | MB§3 |
| `field.force_fields.name` = Mantle, `.blurb` | GROK1 | B2 |
| `tier.hyper_preened.label` / `.flavor` | BIBLE | MB§2 #61 (applies to tiers 5-6 now) |
| Tech names and flavours for every node in GDD §6.3 | BIBLE (MB§3) or GROK1 (B2, B3) | The name in GDD §6.3 is the key's id; flavours from the same source |
| `tech.second_shift`, `tech.better_feed`, `tech.titan_perch`, `tech.the_unsinkable_argument`, `tech.battle_transcriber`, `tech.toxic_preening`, `tech.heart_of_the_roost`, `tech.hyper_preened_thermals`, `tech.the_shared_glance`, `tech.molt_management`, `tech.climate_tailoring`, `tech.roost_lanes` flavours | GROK1 | B8 rewrites |
| `tech.hyper_preened_thermals.flavor` | REWRITE | B8 line still says "the polite warhead is the other option" — true (WE6 option B). Keep. |
| `tech.instant_regret.flavor` | REWRITE | Bible line + add "The receipt is still paid." (GDD §9.6) |
| `tech.the_long_honk.flavor` | REWRITE | Now an option: "Talons take an extra shot every other round." Keep the bible's geese prior-art joke |
| `tech.quiet_star.flavor` | BIBLE | MB§3 (unlocks Indoor Torpedo) |
| `tech.second_sun.flavor` | REWRITE | Bible line + note it also brings the Swat Mount ("The mail now has a predator.") |
| `tech.hatch_dart.name/flavor` | GAP | Now a WE1 option tech (first Horizon). Part tip B1 exists |
| `tech.the_large_keel`, `tech.the_wide_keel`, `tech.keel_plate`, `tech.marrow_plate`, `tech.ugly_perch`, `tech.boot_frame`, `tech.deep_scratch`, `tech.yard_swarm`, `tech.rock_picking`, `tech.kit_nests`, `tech.fortified_nests` | GROK1 | B3 Nestworks |
| `tech.miss_field_2`, `tech.grudge_ledger`, `tech.night_lab`, `tech.flock_brain`, `tech.between_the_feathers`, `tech.security_nest`, `tech.drill_roost`, `tech.loud_abacus`, `tech.loadout_glance`, `tech.seed_exchange`, `tech.destination_board` | GROK1 | B3 Flocknet |
| `tech.richer_dirt`, `tech.old_green`, `tech.dome_perches`, `tech.the_dose`, `tech.more_perch`, `tech.dome_perches_2`, `tech.crackle_shutters`, `tech.root_scratch`, `tech.climate_lever`, `tech.quick_genes`, `tech.every_job_up`, `tech.two_chick_pods` | GROK1 | B3 Plumage |
| `tech.lean_in`, `tech.soft_bones`, `tech.crop_tanks`, `tech.courier_wings`, `tech.trade_winds`, `tech.the_upkeep_diet`, `tech.steady_bird`, `tech.far_nests`, `tech.the_kick`, `tech.far_cells` | GROK1 | B3 Flightcraft |
| `tech.peck_driver`, `tech.horizon_perch`, `tech.ink_dart`, `tech.primary_mount`, `tech.clatter_bill`, `tech.talon_batteries`, `tech.rude_sun`, `tech.cited_dart`, `tech.between_the_ribs`, `tech.gizzard_bore`, `tech.horizon_perch_2` | GROK1 | B3 Broodheat |
| `tech.anvil_beak.flavor` | GROK1 | B3 (now part of the WE6 core with Last Glare) |
| `tech.downrange_charts` ... `tech.hyper_preened_kinematics` (bible names) | BIBLE | MB§3 |
| Mantle techs (`dust_cover`, `personal_down`, `scatter_molt`, `colony_mantle`, `early_mantle`, `null_glide`, `half_mantle`, `tractor_etiquette`, `hard_down`, `gravity_manners`, `no_exit`, `two_steps_back`, `full_mantle`, `gone_to_molt`, `storm_mantle`, `closed_season`, `overpreen`, `not_this_feather`) | GROK1 | B2 |
| `tech.no_exit.flavor` | REWRITE | B2 says "the door is decorative"; rule is now "cannot retreat before round 8". Keep the line, add nothing that promises no retreat at all |
| `tech.hyper_<field>.*` (B3 stems, B2 Mantle stem) | UNUSED | Repeatables are STRETCH |
| Dropped techs: Miss Field III, Annotated Grudge, Every Perch, Loose Feathers, Second Reader, Thrift Nest, The Extra Shift, Boot Frame II, Barrier Nest, Hold Still, Extra Coverts, The Closed Sky, Beak-Proof, Reflective Plumage, Absolute No, Midlife Molt, Made Ground, Garden Intent, Table Manners, Rapid Hatching, dome_perches_3, Ash Drive, Empty Perch, Home Stretch, Nebula Runners, The Map Is Yours, Round-One Encore, Long Quill, Appendix Dart, Spread Quill, Keel Gun, Opening Web, Spreadsheet of Fate | UNUSED | Kept for STRETCH |
| `ui.research.fork_locked` | GAP | Tooltip: the unchosen option (tiers 1-4) unlocks after two more tiers in this field, at 150% |
| `ui.research.fork_final` | GAP | Tooltip: Hyper-Preened forks (tiers 5-6) are final; the other option only arrives by trade, theft, capture or Cache |

## F. Parts, hulls, roles, buildings

| Key | Status | Source / fix |
|---|---|---|
| `part.<id>.{name,tip}` for every part in GDD §7.3 | GROK1 | B1 |
| `part.migration_drive.tip` | REWRITE | B1 → "Map 6, combat 3. The victory drive is this one." |
| `part.hatch_dart.tip` | GROK1 | B1 (still apt: it is now an option, not starter kit) |
| `part.swat_mount.tip` | GROK1 | B1 |
| `part.bomb_bay.name` / `.tip` | GAP | New start part: the only way to kill pop (250 milli per turn). Joke target: bombing as rudeness, never cruelty |
| `part.ash_drive`, `part.long_quill`, `part.appendix_dart`, `part.empty_perch`, `part.miss_field_3`, `part.annotated_grudge` | UNUSED | |
| `hull.<5>.name` | GROK1 / MB§3 | B5 (Sparrow, Kestrel, Heron, Albatross) + Titan Perch |
| `role.<8>.{name,tip}` | GROK1 | B5 (Horizon Boat tip stays MB§2 #60) |
| Building names/tips | GROK1 | B5, keyed by the new ids below |
| `building.flock_brain.tip` | REWRITE | B5 line garbled → "Scientists here, up by two each." |
| `building.roost_gate.*` | GROK1 | B5 `star_gate` lines → key `roost_gate` |

Old id → new id (B5 used the old ids): automated_factory → second_shift_hall, shipyard → the_yard, marine_barracks → boot_barracks, hydroponic_farm → feed_hall, research_lab → research_roost, missile_base → horizon_perch, planetary_shield → colony_mantle, soil_enrichment → richer_dirt, cloning_center → second_clutch, robotic_mines → tireless_picks, supercomputer → loud_abacus, biospheres → more_perch, ground_batteries → talon_batteries, gravity_generator → gravity_manners, autolab → night_lab, weather_controller → climate_lever, star_fortress → ugly_perch, galactic_cybernet → flock_brain, planetary_flux_shield → storm_mantle, deep_core_mines → deep_scratch, star_gate → roost_gate.

## G. New revision-3 systems (all GAP unless noted)

| Key | Needs |
|---|---|
| `spec.forge/academy/yard.{name,tip}`, `spec.retooling.tip` | Specialisation names (Forge/Academy/Yard are placeholders) and the retooling warning |
| `budget.peace/guarded/war.{name,tip}`, `summary.why_queued.<reason>` | Military budget policy names; "why queued" templates with `{target}`, `{current}` |
| `summary.digest.title/body` | BIBLE MB§2 #38 (governor log) |
| `ui.expansion.nest_drain`, `ui.expansion.admin_upkeep`, `ui.expansion.supply_lines` | Tooltips for the expansion costs (GDD §5.5) |
| `notify.outpost_razed`, `notify.blockaded`, `notify.blockade_lifted` | Frontier-risk notices |
| `battle.orders.title`, `battle.orders.posture.<auto/close/talon/standoff/retreat>`, `battle.orders.priority.<auto/biggest/swat/band/defenses/transports>`, `battle.orders.swat.<missiles/ships>`, `battle.orders.retreat.<never/half/even>`, `battle.orders.odds`, `battle.orders.accept` | The Battle Orders card. Short; the card is a screenshot target |
| `ui.battle.range_strip.<beak/talon/horizon>` | Band words on the strip (could just be the vocabulary words) |
| `battle.autopsy.*` | GROK1 B6 |
| `ui.battle_line.tip` | GROK1 B8 |
| `ui.retreat.receipt_tip` | BIBLE MB§2 #58 |
| `ui.fleet.doomstack`, `.doomstack_tip` | BIBLE MB§2 #20 |
| `ui.refit.tip`, `notify.refit_done` | Refit: pay the difference, two turns in dock |
| `ui.steal.choose_title` | Pick one of three stolen techs |
| `council.session.nonbinding` | First session: the count is published, nobody is crowned |
| `council.electability_tip` | Must have met everyone and hold 30% of the votes |
| `council.pledge_cap_tip` | 15% cap |
| `council.accept`, `council.defy`, `council.pledge_tip` | GROK1 B7 |
| `council.defy_card.title` | Card that lists the leaders now at war with you |
| `coalition.label.tier_list` / `.snowball`, `coalition.tip` | BIBLE (MB§5 idea 8, MB§2 #28) |
| `coalition.target.news` | PNN: the Coalition names its target system |
| `coalition.duty_tip` | Why a peaceful AI just declared war (Coalition duty) |
| `capitulation.card.title/body` | Two-line surrender card |
| `ui.victory_clock.*` | GROK1 B6; add `ui.victory_clock.eta` ("~{turns} turns at this pace") |

## H. World

| Key | Status | Source |
|---|---|---|
| `climate.<11>.name` | GROK1 | B5 (Garden, Temperate, Ocean, Jungle, Arid, Ice, Desert, Bare, Cinder, Sour, Crackle) |
| `star.<type>.name` | GROK1 | B5 |
| `star.name.1..64` | GROK1 | B5 (suffix " Reach" on collision) |
| `special.<6 MVP>.{name,tip}` | GROK1 | B5 (Old Nest, Pretty Rocks, Rude Wealth, Kind Soil, Spare Nest, Yard Scrap) |
| `special.natives.*` | UNUSED | STRETCH |
| `place.orn.name`, `monster.guardian.name`, `monster.leviathan.name` | BIBLE | |
| `monster.guardian.warning` | BIBLE | MB§4 ev3 |
| `monster.guardian.roar`, `monster.leviathan.roar`, `notify.guardian_marked` | GROK1 | B5 |
| `notify.guardian_loot` | GAP | Orn-Plating and two techs awarded; no weapon skipped |

## I. Events

| Event | Status | Source |
|---|---|---|
| tier_list_leaks, guardian_of_orn, placid_until, midgame_sit, snowball_named, perch_review (MVP) | BIBLE bodies (MB§4) + GROK1 B6 Perch Review results | |
| `event.perch_review.*` | REWRITE | Five-star trigger is now "a ≥ 2:1 battle or a T5+ tech" (was T7+); results text unchanged |
| STRETCH events (pond_scum_leviathan, letter_of_marque, corner_colonist, spreadsheet_you_wanted, called_to_the_grand_roost, tall_shapes, henhouse_war, mineral_strike, derelict_hull, data_moult, bountiful_season, feather_plague) | UNUSED | Bible bodies + GROK1 B6/B8 lines kept for later |

## J. News and notifications

| Key | Status | Source / trigger |
|---|---|---|
| `news.pnn.ident` | BIBLE | MB§2 #30 |
| `news.{war,council,guardian_killed,exodus,capitulation}` | GROK1 | B7 |
| `news.swans_seated`, `news.leviathan` | BIBLE | MB§2 #39, #40 |
| `notify.scout_war`, `notify.snowball`, `notify.tech_done`, `notify.swans_lead`, `notify.elected` | BIBLE | MB§2 #31, #32, #34, #36, #35 (triggers as revision 2) |
| `notify.{colony_founded,starvation,strike,invasion_won,invasion_lost,treaty_offered,treaty_ended}` | GROK1 | B7 |
| `notify.moulted`, `notify.crisis` | UNUSED | STRETCH |

## K. Victory and defeat

| Key | Status | Source |
|---|---|---|
| `victory.conquest.body`, `victory.exodus.body`, `defeat.{capitals_gone,called_game,as_swans,as_pheasants}` | BIBLE | MB§6 |
| `victory.grand_roost.body`, `victory.called_game.body`, `defeat.accepted_supreme_bird.body` | GROK1 | B8 |
| `victory.exodus.rule` | REWRITE | B8 suggestion → "Both last keys, every field to the fifth rung, and a finished Departure Roost." |
| `defeat.big_quiet` | UNUSED | STRETCH |

## L. Loading tips

`tip.loading.1..20`: BIBLE MB§6, with GROK1 B8 replacements for tips 4, 5 and 19. Tip 7 ("Retreat always works, and it always leaves someone last") → REWRITE: "Retreat works on round two, and it always leaves someone last."

## Gap list for the writer (priority order)

1. Battle Orders card strings, band words on the range strip (§G).
2. Specialisation names and tips, military budget names, "why queued" templates.
3. Expansion-cost tooltips, outpost razed / blockade notices, refit strings.
4. Grand Roost non-binding / electability / pledge-cap / Defy card; Coalition target and duty lines; capitulation card.
5. `part.bomb_bay`, `trait.informants`, `tech.hatch_dart`, `notify.guardian_loot`, `ui.research.fork_locked`, new deal reasons.
6. `menu.preset.evening_standard.seats`, victory clock ETA token, credits attribution lines.
7. The REWRITE rows (small edits).

## M. Red team round 2 (revision 4)

| Key | Status | Source / text |
|---|---|---|
| `battle.orders.title` | GROK2 | R2 #1 |
| `battle.orders.accept` | GROK2 | R2 #3 |
| `battle.orders.odds` | REWRITE | R2 #2 described the old rule. New: "{odds}. Same speed still closes, one step a round. Faster closes sooner." |
| `battle.orders.projection` | GAP | One line with `{talon_round}`, `{beak_round}`: the worst-case rounds to each band (GDD §9.2) |
| `ui.battle.range_rule` | GAP | The spoken range rule of GDD §9.3, tightened; strip tooltip and battle help |
| `ui.expansion.nest_drain` | GROK2 | R2 #4 |
| `ui.expansion.supply_lines` | REWRITE | R2 #5 says "every output"; food is now exempt: "Past 15 pc from the Grand Nest, industry, research and taxes drop 10% per 5 pc, to -30%. Food travels free." |
| `ui.expansion.prospect` | GAP | Prospect line with `{food}`, `{credits}`, `{pp}` at pop 3 and at max pop (GDD §5.5) |
| `council.electability_tip` | GROK2 | R2 #6, plus a second sentence naming the routes: "52% alone, 30% with friends, or survive the hunt." |
| `council.defy_card.title` | GROK2 | R2 #7 |
| `coalition.duty_tip` | REWRITE | R2 #8 predates the NAP rule. New: "Not allied with the leader. Coalition duty tore up the paper and made the declaration." |
| `coalition.end.cut_down` | GAP | PNN: the Coalition took a colony (or the leader shrank); it disbands; `{leader}`, `{place}` |
| `coalition.end.held` | GAP | PNN: 25 turns and the leader held; truce; the leader is Acknowledged; `{leader}` |
| `coalition.acknowledged_tip` | GAP | Tooltip: no more Coalitions against this empire; AIs at peace with it vote for it |
| `capitulation.card.title` / `.body` | GROK2 | R2 #9 |
| `menu.preset.evening_standard.seats` | GROK2 | R2 #10 |
