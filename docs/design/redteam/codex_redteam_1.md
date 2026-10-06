**Verdict: REWORK.** The core has promise, but the current rules do not support the promised 75-120 minute veteran 4X game. Fix the pacing, combat agency, AI acceptance tests, and contradictory balance gates before handing phases to the builder.

1. **BLOCKER - GDD 2.2-2.3, 14:** The time estimate assumes about 25 seconds per turn, while late turns are budgeted at 30-60 seconds and the cap is 250. A capped game could run well past two hours before battle replays. Set a target for *measured human decision time* and require browser playtests; move the cap closer to the intended ending only after victory rates are measured.

2. **MAJOR - GDD 2.2, 5.5-5.6:** Everyone starts with a colony ship, the second is affordable around T5, and governors fill queues automatically. Expansion risks becoming a sequence of accepting obvious targets. Make early settlement compete with a scarce military, range, or development investment; test whether players actually choose to postpone a colony.

3. **MAJOR - GDD 5.3, 5.6:** Pooled food removes a chore, but preset selection may be the last meaningful colony decision. Rich worlds default to Industry, while Empire food balancing erases most local tradeoffs. Keep pooled food; give each colony a consequential specialization choice with an opportunity cost and a useful bulk interface.

4. **MAJOR - GDD 5.6, 13.3:** The Capital preset repeats warships indefinitely, while Industry and Research fall into Trade Goods. That can quietly consume upkeep and override the AI's stated military production share. Require empire level production budgets and visible "why this is queued" explanations; governors must stop ship production at a target.

5. **BLOCKER - GDD 9.2:** With advance capped at 5 per side, a Stand Off fleet at zero advance can keep the range at **5 forever**. Beak's desired 0-2 is unreachable regardless of its speed. Redefine range movement so faster ships can close against a stationary or slower opponent, then test every doctrine pairing.

6. **MAJOR - GDD 7, 9:** One HP pool, automatic target selection, doctrine, and retreat leave little battle agency across 150-220 turns. Shields and missile counters may decide designs before the battle starts. Add a small number of prebattle orders-target priority, range posture, and missile/PD emphasis-with readable autopsy evidence; keep replay optional.

7. **MAJOR - GDD 9.3, 9.6:** Retreat "always escapes" but Tractor Lock delays it and Warp Dissipator forbids it; cloak says a ship may fire, while round resolution excludes cloaked ships from firing. Resolve both rule conflicts before implementation and pin them with combat fixtures.

8. **MAJOR - GDD 10:** A starting corvette's four Lasers can kill roughly two population per bombardment turn under the printed formula. That makes conquest through troop ships easy to bypass by erasing small colonies. Reduce early bombardment sharply or require dedicated bomb parts; preserve invasion as the way to acquire productive worlds.

9. **MAJOR - GDD 6.1:** "Choose one" loses force when every rejected option remains researchable at 150% and tradeable. Creative then grants dozens of free options, while ordinary empires eventually converge. Make a smaller set of genuinely exclusive branches; price Creative against their measured value and restrict easy tech laundering.

10. **BLOCKER - GDD 12.3:** Grand Roost pledges are priced at about 10 credits per vote, and votes can produce victory at the first T50 session. Population growth and diplomacy may buy an early win before wars or high tiers matter. Limit pledgeable votes, make prices reflect victory leverage, and require a minimum strategic milestone before a winning vote.

11. **MAJOR - GDD 4.3, 12.4:** Swans get 13 picks plus a rich large home. The Coalition supplies relations and a war threshold modifier, not coordinated military action; its 30% trigger may also fire early and stay on for most of the game. Give coalition members an explicit shared war plan, or reduce Swan advantages until counterplay works in human games.

12. **BLOCKER - GDD 17.3:** The soak targets are arithmetically incompatible at 40 games: Swans need at least 14 wins; each of seven other races needs at least four, totaling **42**. Also, random four empire lineups cannot fairly measure every race's win rate. Use balanced race appearances, more seeds, confidence intervals, and conditional win rates.

13. **MAJOR - GDD 17.3, Architecture 15-16:** AI vs AI soak can verify termination, stability, and gross balance; it cannot establish a 1-2 hour session, interesting decisions, or whether Flighted AI threatens a competent human. Add scripted strategic probes and recorded human browser playtests as acceptance gates.

14. **MAJOR - GDD 13; Architecture 8:** Fog limited `AiView` is a sound boundary, but one unseen fleet isolation test proves little about war competence. The planner needs stale intelligence, scouting, uncertainty in defense estimates, invasion logistics, and reactions to failed commands. Test AI recovery from surprise defenses and whether it can take a defended capital without bonuses.

15. **MAJOR - Architecture 7.3, 10:** Time slicing by whole AI empire still permits a stated 150 ms web planning step, enough to visibly stall a frame. Split planning into bounded stages and measure actual browser frame times. Single threaded web export is supported, but it has a performance cost. [Godot web export guidance](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html)

16. **MAJOR - Architecture 4.5, 14:** Thirty full state undo snapshots at an estimated 200-400 KB each mean at least 6-12 MB of serialized data per turn, before Godot object overhead; copying on every click may hitch. Profile this in the browser early and cap by bytes, or undo planning commands with compact deltas. Include save/load and IndexedDB persistence tests on the actual itch page; browser storage may be evicted. [Godot web export guidance](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html)

17. **MAJOR - Architecture 11, 16; COPY_PLAN F:** Code built UI can be workable, but one scene plus large scripted screens postpones visual iteration; copy and web polish arrive at P10 after balance. Make each phase exportable and visually reviewable, establish the UI kit with real screens early, and put final mechanics before the balance gate. Verify `data/copy/en.json` is included in exports; Godot requires explicit inclusion of non-resource JSON. [Godot export guidance](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html)

18. **MINOR - COPY_PLAN F; BRIEF "Priorities":** Merculite, Pulson, Zeon, Zortrium and similar MoO terms remain in proposed content; the plan already flags them. Replace them before public copy or screenshots. Also check the final game title and prominent faction names before release: trademark risk turns on likely consumer confusion, not just exact spelling. [USPTO guidance](https://www.uspto.gov/trademarks/search/likelihood-confusion)

**Recommended MVP cuts:** Four distinct premade empires first; no custom race builder, espionage, random events, Guardian, wormhole, nebula, repeatable techs, or hyper tier 8. Use roughly four research fields and five tiers, three meaningful victories at most, a smaller part catalog with clear counters, and two colony specializations. Retain the playable spine: exploration, differentiated worlds, fleet design, readable combat, one competent fog bound AI, diplomacy, a decisive ending, browser saves, and turn summaries. Add cut systems only after a complete browser game repeatedly finishes in the promised time.

