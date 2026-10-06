I'll read the revision-3 GDD and the copy plan, then answer only the eight fun questions you named.I would play one Evening Standard this week and post the Swan card. I would not post a battle, and I would not start a second map, until equal-speed fleets can be forced to a conclusion. The Defy card and the capitulation card become posts the day their lines exist.

Round-1 fun findings still open: **G5** (the card landed; equal speed still ignores it), **G6** (aggression 8 landed; a treaty still cancels the hunt, and the fleets do not arrive together), **G3** (the two-tier wait landed; the next tier still sells a substitute, so Creative's 8 picks buy a head start), **G12** (tech is out of Coalition power; the seating line is still unwritten, and a NAP still adjourns the table), **G13** (the shots are listed in 15; the words are still gaps). Closed, and should stay closed: G1, G2, G4, G7, G8, G9, G10, G11, G14. G7's early buyout is dead. Finding 5 is the over-correction. Do not loosen the 15% cap to "fix" it.

## Findings

**1. Medium. One Battle Orders card is enough agency, and it is the right number of pauses.** Five orders, pre-filled, Enter to accept, nothing clickable in the replay. That is a veteran layer for a 80-minute evening. The 15-second budget breaks if the card is also a line editor. Dragging eight hulls is a fleet-panel job. Leave it there.

The card also has to show the range those orders will actually produce, in one line, from 9.3, using the enemy as "holds." Odds alone are a lie while Stand Off exists. Cut the colony trigger so a scout does not pause the turn. Fire the card when your side has at least 3 armed ships, or the attacker does, or a bomb part is in the fight.

**2. Blocker. Equal speed freezes distance at 10, two short of the wall, for the whole midgame.** Start `D = 10`. Combat speeds are Walk 1, Current 2, Fold 2, Migration 3. For `s = 2`, Close wants `-2` and Stand Off wants `+2` (only 2 pc of room to the edge). The sum is 0. The "kiter at 12" exception never runs. They sit at 10, outside Beak (hit floor 5%) and outside the Talon band, for all 8 rounds. Round-8 stalemate grants no orbit, so there is no blockade and no invasion. Next turn `D` resets to 10 and the same fight is scheduled again.

Fold does not beat Current. Lean-In on a Walk drive is still speed 2, so it changes nothing. Lean-In plus Current is speed 3, and that is the first hull that can gain a single pc a round. Swans get that for free after Flightcraft 2. Everyone else is locked out of taking a star unless they spent the tier-1 Flightcraft option on Lean-In. Soft Bones is then a trap pick, and the fork is fake. Talon range cannot anchor either. Against Close, both wants are negative, so the pair falls through 5 and into a beak brawl.

Same-speed drift, brace when you are already on your number, and a stalemate resumes `D`.

```gdscript
intent_a = clampi(P_a - D, -s_a, s_a)
intent_b = clampi(P_b - D, -s_b, s_b)
var braced := false
if intent_a == 0 and intent_b != 0:
    intent_a = clampi(-intent_b, -s_a, s_a)
    braced = true
elif intent_b == 0 and intent_a != 0:
    intent_b = clampi(-intent_a, -s_b, s_b)
    braced = true
var raw := intent_a + intent_b
if raw == 0 and not braced and s_a == s_b and P_a != P_b and D != mini(P_a, P_b):
    raw = -1 if D > mini(P_a, P_b) else 1
D = clampi(D + raw, 0, 12)
```

Spoken rule: same speed, the distance drops one notch a round toward the shorter preference. A fleet holds its number when it is already there and at least as fast. A kite requires being strictly faster. Leave the drive numbers alone. Retune P6 to this table.

**3. Medium. Wide play is gated, and one of the four costs should come off food.** Pop drain on the capital regrows in about 3 turns at pop 8 of 12 (the "~8 turns" in 5.5 is the frontier case). Admin of 1 credit, later 2, is right. Razing an undefended outpost is right. Thirty percent habitable past 9 pc is the real brake, and it is the right one. Ducks and Penguins are the wide test. Pheasants are the early war.

The over-punishment is supply lines on food. A medium Temperate world at -20% with farm 2 needs every farmer it has just to eat, and then it produces nothing you settled it for. Arid is a credit leak at 2 credits a food. I would postpone the third Nest Ship forever, so H3 passes for the wrong reason.

Keep pop, admin, razing, and the 30% habitability. Apply the distance malus to industry, research, and taxes only. Food stays the pooled constraint it already is. Put one prospect line on the Nest order: net food, net credits, net PP, after the malus.

**4. Major. Forced Coalition aggression declares wars the strikers cannot finish, and a NAP deletes it.** Duty overrides the polite personalities, which is what G6 asked for. The war check uses combined power. The launch check is still `own ò 1.5x defense`. Three empires declare, and the small one never leaves the perch. The leader eats that small fleet and comes out larger. A human, or the Ducks, buys a NAP or a Trade treaty at relation 0 or 10 and is exempt, because any treaty blocks duty. Notorious Swans cannot buy that NAP early. Everyone else can. You get a permanent war season against Swans, and no check on a diplomatic leader.

Ignore NAP and Trade for duty. Alliance is the exemption. Commit the two nearest members, size the strike on their combined fleets, and make them arrive the same turn on the announced system. The third member stays home. Keep the 25-turn cap and the 15-turn cooldown. Soak success is "the leader lost a colony, or won a defensive battle," which replaces "power fell by 5." That 5 points is one border rock, and it will green-light a dogpile that never converts.

**5. Major. Thirty percent and the 15% cap are the right gates. The refusal makes the door the GDD just described illegal.** Electability at 30% stops a small empire being crowned. The pledge cap means an unallied candidate needs about 52% of the population plus a bought 15% to reach two thirds. 12.3 says that path works. The same paragraph says an AI refuses any pledge that would carry a non-ally over two thirds. That refusal is exactly the 52% to 67% purchase. What remains is 67% of the population in one empire, or an alliance. Sixty-seven percent of a four-empire map is conquest with the counters still on the board.

Coalition power is `pop + 3xcolonies + fleet/20`. Votes are pop. The only electable empire is the Coalition target, and it is at war on election day. The council and the hunt are aimed at the same bird.

Delete the non-ally refusal. The 15% cap is the anti-buyout. A 30% empire plus 15% in pledges is 45%, still short of two thirds. Keep electability, the cap, the non-binding first session, and no self-charisma. Split the hunt off the ballot: `coalition_power = fleet_pp/20 + 3xcolonies + pop/2`. Write the 52% path on `council.electability_tip` so the card and the rule match.

**6. Medium. Creative is a 5-pick trait wearing an 8-pick price.** The wait is real and the catch-up cost is not. Ink Dart, on the next Weapons tier, opens the missile line for anyone who skipped Hatch Dart. A sibling at 150% of a low tier is a few turns of labs. Trade, theft, and Cache bypass the wait. Exodus keys are cores, so Wide-Eyed does not move the victory. Owls also have poor industry, so the second building option sits in a queue they cannot clear. One-Note's sibling is gone forever, which is a harsher penalty than Creative's bonus is a prize.

Set Creative to +5. On the Owl card, spend the freed 3 on `ship_defense_+1`. The premade still sums to 10, and the few ships they can build live long enough for the extra parts to matter. Grant both options on the same completion, with no second prompt. Leave `creative_tier_cost_pct` at 0 until the soak says the Owls ran away with the tree.

**7. Major. P1 will pass an AI that shows up late to a real war. Plan the economy during the player turn. Plan the wars at End Turn.** P1 gives a Flighted AI double income against a passive capital with two Horizon Perches and a Colony Mantle, and allows 40 turns and 2 failed seeds. Unlimited planetary missiles make it a Swat-tech check, which is a fair lesson, and 40 turns hides a planner that marches on turn 35. A passive turret never punishes a bad interception.

Make the fixture fixed, the bar 10 of 10, the limit 25 turns, and park a 4-ship guard squadron on the capital. Keep H6 as the only test of whether a human feels hunted. P1 is a floor.

On timing: research, colonies, design, and budgets can run on the turn-start snapshot while the player is thinking, inside the 6 ms slice. Military, war, and interception run at End Turn on the committed orders, so a fleet you just sent is visible if their sensors say so. Speculative plans must not read uncommitted edits, and a Ctrl+Z must not invalidate a plan that was never based on the undone order. The 0.6-second end-turn budget and the 50 ms frame bar are the fun requirements. A one-turn-late admiral is how an evening goes quiet.

**8. Major. Hand-written `revert` will not stay the inverse of `apply` under a Gemini Flash builder.** 4.5 asks every command to return a dictionary of prior values and to implement its own `revert`. Revision 3 already added specialisation, military budget, battle plans, and refit. The failure is a partial delta. Apply changes the queue, `retool_until`, and the treasury. Revert puts the queue back. Rush-buy is the trap, because a Flash builder will recompute the refund, and the second time the cost is different. The hash test catches this only when the fixture touches every field the command writes.

One recorder. Commands implement `apply` only, and every mutation goes through `set_value`, which stores the old value. `revert` walks that list backward. It never recomputes a price. The existing hash test stays, on the full `GameState`. Add a lint that `revert` is not overridden per command. Battle Orders and anything the pipeline resolved do not push the stack. The stack still clears at End Turn, and the cap stays 50 entries or 256 KB. Governor revert remains STRETCH.

```gdscript
func set_value(obj: Object, key: StringName, new_value: Variant) -> void:
    changes.append([obj_id, key, obj.get(key)])
    obj.set(key, new_value)

func revert(gs: GameState) -> void:
    for i in range(changes.size() - 1, -1, -1):
        restore(gs, changes[i])
```

## Copy

True of revision 3 as written. If findings 2 and 4 land, change `battle.orders.odds` and `coalition.duty_tip` in the same pass.

1. `battle.orders.title`: "One card. Then it is fought."
2. `battle.orders.odds`: "{odds}. Same speed holds the range. Faster is how you close it."
3. `battle.orders.accept`: "Fight it this way."
4. `ui.expansion.nest_drain`: "Takes 1 pop from this colony when it finishes. Waits if pop is under 3. The starting Nest Ship was exempt."
5. `ui.expansion.supply_lines`: "Past 15 pc from the Grand Nest, every output drops 10% per 5 pc, to -30%."
6. `council.electability_tip`: "Electable at 30% of all votes, held by you, after you have met every empire still alive. Pledges do not count toward the 30."
7. `council.defy_card.title`: "{leaders} are at war with you."
8. `coalition.duty_tip`: "No treaty with the leader. Coalition duty made the declaration."
9. `capitulation.card.title`: "The rest of the nest." `capitulation.card.body`: "{leader} has lost the capital and is down to a remnant. Accept, and what they still hold is yours."
10. `menu.preset.evening_standard.seats`: "Swans, one early-war bird, one schemer. Take one of those seats and the chair refills."

