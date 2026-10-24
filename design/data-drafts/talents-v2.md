# Talent pool v2: clustered by affinity role (DRAFT)

Status: draft for Brent, 2026-10-24. Nothing here is in the game: `game/data/talents.json` and the code are untouched. Data: `design/data-drafts/talents-v2.json`. Brent's request: "expand the prime talent pool ... use the affinity roles as a clustering guide for talents" [B].

Provenance: the roles and parents are Brent's (design/affinities/framework.md) [B]; talents and affinities are rolled independently (2026-10-11) [B]; every cluster boundary, new talent, verse, rule, number and hook here is ours [MODEL]. Setting mechanics used (stars, essence, reflux, primes evolving with rank, fine print found by experiment, the Netherecho, constructs) are [C]/[F] per design/01. No canon talent names or wording; no book text.

## How to read it

- A talent's **cluster** is the playstyle it serves best; **roles** lists the affinity roles it fits. Neither ties the talent to an affinity. A Bulwark talent rolled with Wind is meant to be a strange, playable mix (design/04 point 6).
- New talents have `evolve_2`, `evolve_3`, `evolve_4` and `evolve_onward` (how it keeps growing toward 10 stars, the build plan's target). Evolutions widen the rule or remove a limit; none replaces the rule (design/04 point 5).
- `build.hooks` = existing `TalentEffect` hooks used; `build.needs` = new hooks or world APIs (merged below). "Buildable today" in a note means existing hooks and existing world scripts are enough.

## Clusters: counts before and after

| Cluster | Roles (affinity) | Before | New | After |
|---|---|---:|---:|---:|
| Bulwark (tank / area control) | area_tank (earth) | 5 | 1 | 6 |
| Bruiser | bruiser (water) | 1 | 4 | 5 |
| Burst and ranged caster | burst_caster (fire), ranged_caster (light) | 4 | 1 | 5 |
| Control caster | control (ice) | 0 | 5 | 5 |
| Healer and sustain | healer (life) | 2 | 3 | 5 |
| Support / wards | paladin_support (holy) | 0 | 5 | 5 |
| Assassin | assassin (dark) | 0 | 5 | 5 |
| Summoner / necromancer | necromancer (death) | 2 | 3 | 5 |
| Druid / growth | druid (nature) | 0 | 5 | 5 |
| Berserker | berserker (blood) | 1 | 4 | 5 |
| Enchanter | enchanter (dream) | 0 | 5 | 5 |
| Spellblade | spellblade (lightning) | 0 | 5 | 5 |
| Evasive / mobility | evasive_monk (wind) | 3 | 2 | 5 |
| Duellist | armoured_duellist (metal) | 1 | 4 | 5 |
| Drain / shadow knight | shadow_knight (unholy) | 1 | 4 | 5 |
| Damage over time / coating / plague | coating (poison), plague (disease) | 0 | 5 | 5 |
| General / utility / economy | none | 20 | 3 | 23 |
| **Total** | | **40** | **64** | **104** |

Thin before (0 or 1 talent): Bruiser; Control caster; Support / wards; Assassin; Druid / growth; Berserker; Enchanter; Spellblade; Duellist; Drain / shadow knight; Damage over time / coating / plague. Half the existing pool (20 of 40) was general / economy, so the new talents go almost entirely into the role clusters; general gets only three junk-grade oddities.

Merges: Fire's burst caster and Light's ranged caster share **Burst and ranged caster** (both play 'one big cast'); Poison's coating and Disease's plague share **Damage over time**; Earth's area tank absorbed 'area control' (Ice's control stays its own cluster because stopping enemies is a different job from standing in front of them). Holy (support) and Unholy (shadow knight) are not in the game yet but have clusters, since the talents serve the playstyle whatever the affinity.

## Values: the weighted roll

| Value | Before | New | After | Share of the pool after | Chance per draw after (weights low 3, mid 2, high 1, junk 1*) |
|---|---:|---:|---:|---:|---:|
| junk | 1 | 3 | 4 | 4% | 2% |
| low | 8 | 25 | 33 | 32% | 46% |
| mid | 20 | 26 | 46 | 44% | 43% |
| high | 11 | 10 | 21 | 20% | 10% |

\* `balance.json` "primes" `talent_weight_by_value` has no `junk` entry, so `PrimeRoll._pick_talent` falls back to 1.0: junk talents are exactly as rare as high ones today. Proposed fix in Open questions.

Every role cluster has a low and a mid talent, and all but Support and Drain have a high one, so each playstyle can turn up at most prices. Value is the market's opinion (design/04), so several 'looks weak, is not' talents are priced low on purpose (Quiet Tally, Census, Small Change, After the Storm, Last Drop).

Categories after (design/04 asks 12+ each at content-complete): body 10, bond 8, defense 11, mobility 8, netherecho 3, offense 38, perception 8, sustain 10, trade 8. Offense is crowded and netherecho thin (3, none new); see Open questions.

## Talents by cluster

### Bulwark (tank / area control) (6)

Taking hits and owning ground: damage thresholds, delays, immunity, and claimed space enemies must cross.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Stubborn Bone | mid | Structural damage below a threshold per hit is ignored entirely. | area_tank, bruiser | data only |
| The Last Inch | mid | The final 10% of each wound layer takes 90% less damage. | area_tank, berserker | data only |
| Debt of Pain | high | Incoming damage is delayed 5 s, then arrives at 80%. | area_tank, berserker, shadow_knight | scripted |
| Salt Skin | mid | Immune to damage-over-time. | area_tank, armoured_duellist | data only |
| Slow Blood | low | Damage-over-time on you ticks at quarter speed for the same total. | area_tank, healer | data only |
| **Held Ground** (new) | mid | Stand still to claim a circle; enemies entering are Slowed, and you break their poise faster inside. | area_tank, control | adjust:poise_out |

### Bruiser (5)

Heavy blows, shoves, Crushes, poise and trading hits up close.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Grudge | mid | +2% damage against a specific enemy for every hit that enemy has landed on you. | bruiser, area_tank | scripted |
| **Rebound** (new) | mid | Crushes refund essence and make your next hit heavy. | bruiser, area_tank | on_event:crush, on_event:cast |
| **Weight Kept** (new) | high | Immovable; enemies shoved into you are Crushed against you. Walk a little slower. | bruiser, area_tank, armoured_duellist | adjust:shove_in, adjust:move_speed, adjust:crush_surface, on_event:crush |
| **Bell Ring** (new) | low | Hitting a Staggered enemy strips poise from everyone near it. | bruiser, control | today |
| **Change Given** (new) | mid | Hit back within 1.5 s and your strike adds the damage you just took. | bruiser, berserker, armoured_duellist | today |

### Burst and ranged caster (5)

Big numbers from skills: openers, essence and reflux spent hard, echoes. Fire's burst and Light's ranged smite merge here; both are 'one big cast' players.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Glass Hour | mid | For the first 6 s of any fight you deal x3 damage and take x3 damage. | burst_caster, assassin, berserker | scripted |
| Echo Hand | high | Every ability repeats once at 25% power after 1 s, from where you stood. | burst_caster, control, spellblade | data only |
| Furnace Gut | mid | Reflux never locks an affinity. | burst_caster, spellblade | scripted |
| Clean Channel | high | Essence supplied by your satellite generates no reflux. | burst_caster, ranged_caster, enchanter | data only |
| **Last Drop** (new) | low | A skill that nearly empties your essence hits x2.5. | burst_caster, ranged_caster | on_event:cast, HitContext.cast_serial |

### Control caster (5)

Stops, interrupts, slows and statuses that keep enemies from acting.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Remainder** (new) | mid | Stops broken early bank their unused time for your next stop. | control, enchanter | on_event:status_out, adjust:status_time_out |
| **Crowd Sum** (new) | mid | Big area casts give extra status stacks from the third enemy hit. | control, burst_caster, area_tank | HitContext.cast_serial, adjust:status_stacks_out |
| **Broken Sentence** (new) | high | Interrupted enemies are Dazed and lose the attack; chains grow. | control, spellblade, armoured_duellist | on_event:interrupt |
| **Tangle** (new) | low | Each extra status you stack on an enemy slows it 10%. | control, enchanter, plague | on_event:status_out |
| **Quiet Room** (new) | low | Enemies you have stopped cannot call for help or wake their camp. | control, assassin | adjust:alert |

### Healer and sustain (5)

Recovery between fights and at a price: wounds, sinks, rest. Never in-fight healing that outpaces damage (design/04 balance rule).

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Scar Ledger | mid | Each structural wound fully healed adds +0.5% max HP to that body region, permanently. | healer, area_tank, bruiser | data only |
| Hunger Engine | mid | Eating monster flesh heals superficial damage and grants resistance to that monster's affinity for 10 min. | healer, druid, necromancer | data only |
| **After the Storm** (new) | low | Heal 30% of the damage a fight cost you when it ends. | healer, bruiser, area_tank | on_event:fight_end |
| **Night Surgeon** (new) | high | Each night closes your oldest wound, lost arm included, for a little tempering progress. | healer | on_event:rest |
| **Graft** (new) | mid | Natural healing on a full bar banks a hidden reserve that pours back when you are hurt. | healer, druid, area_tank | adjust:natural_heal_overflow, on_event:wound_opened |

### Support / wards (5)

Wards on the ground, buffs shared with thralls and lures, refusing harm. In a single-player game 'allies' are your thralls and lures.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Chalk Line** (new) | mid | Your first skill in a fight draws a ward: less damage taken, enemies inside Lit. | paladin_support, area_tank, ranged_caster | on_event:fight_start, on_event:cast, adjust:poise_in |
| **Planted Standard** (new) | low | Self-buffs are also planted as a circle that outlasts them and covers your thralls. | paladin_support, druid, necromancer | on_event:cast, world:thralls read buffs |
| **Stand-In** (new) | low | Take half of a blow that would kill your thrall or lure. | paladin_support, necromancer | on_event:ally_lethal |
| **Unwelcome** (new) | mid | Periodically bounces the first harmful status on you back to its sender. | paladin_support, healer, shadow_knight | on_event:status_in |
| **Watch Fire** (new) | low | Standing still lights the area and marks enemies in it as Lit. | paladin_support, ranged_caster | world:Light.add_source |

### Assassin (5)

Rear hits, being unseen, darkness, one target marked for death.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Quiet Tally** (new) | low | Unwitnessed kills permanently raise your rear damage. | assassin | save:talent_state |
| **Any Side** (new) | high | Every 8 s, one hit counts as from behind. | assassin, evasive_monk, armoured_duellist | today |
| **Clean Exit** (new) | mid | Kills from behind make you unseen for 2 s. | assassin, evasive_monk | world:timed unseen |
| **Appointment** (new) | mid | One marked enemy per fight takes +60%; everything else -20%. | assassin, armoured_duellist | on_event:fight_start, reveals |
| **Soft Dark** (new) | low | In darkness, sleepers stay asleep and camps notice you at half range. | assassin, enchanter | adjust:aggro_radius |

### Summoner / necromancer (5)

Thralls, lures and corpses: more of them, longer, and hitting with you.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Loyal Dead | high | The last thing you killed fights for you for 30 s at half strength. | necromancer | data only |
| Swarm Keeper | low | Vermin and insects in the environment obey simple commands. | necromancer, druid | data only |
| **Spare Room** (new) | high | One extra thrall; the oldest bursts when replaced. | necromancer | adjust:thrall_cap, on_event:thrall_died |
| **Second Shift** (new) | mid | Dead thralls leave a corpse you can raise again cheaply. | necromancer, plague | on_event:thrall_died, adjust:essence_cost |
| **Chorus** (new) | mid | Your bare strikes make your thralls and lures strike too. | necromancer, druid, paladin_support | today |

### Druid / growth (5)

Plants, growth patches, clouds and the slow turn of a fight; some foraging.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Turning Year** (new) | high | A fight cycles four seasons: healing, damage, loot, defence. | druid, healer | adjust:natural_heal_in_combat, adjust:loot_rolls |
| **Weedheart** (new) | low | Cut plants seed growth that slows enemies. | druid, control | today |
| **Pollen** (new) | low | Shed a cloud every few seconds that Dulls living enemies. | druid, paladin_support, plague | adjust:poise_regen |
| **Wild Pantry** (new) | low | Cleared walls grow a plant that drops crafting materials. | druid | on_event:wall_cleared |
| **Grass Remembers** (new) | mid | Enemies that stand still near you get pinned. | druid, control, area_tank | today |

### Berserker (5)

Momentum, kill streaks, pain turned into power, never backing off.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Borrowed Breath | high | On lethal damage, keep fighting for 10 s. | berserker, shadow_knight | data only |
| **Fever Count** (new) | mid | Quick kills build a streak of damage and speed. | berserker, bruiser | adjust:move_speed |
| **Spent Pain** (new) | mid | Damage taken charges your next skill. | berserker, shadow_knight | on_event:cast, HitContext.cast_serial |
| **Forward Only** (new) | low | Take less damage advancing, more retreating. | berserker, bruiser, armoured_duellist | today |
| **Butcher's Floor** (new) | low | Bare-strike kills leave blood pools that speed your strikes. | berserker, bruiser | adjust:strike_interval |

### Enchanter (5)

Mind statuses (asleep, dazed, terrified, commanded) that turn enemies on each other, and misdirection.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Wrong Waking** (new) | mid | Enemies waking from your sleep or daze attack each other first. | enchanter, control | on_event:status_out, world:forced target |
| **Toll of Sleep** (new) | low | First mind status on each enemy refunds essence. | enchanter, control | on_event:status_out |
| **Passed Along** (new) | high | Killing a mind-controlled enemy passes the control on. | enchanter, necromancer | today |
| **Rumour** (new) | low | Your Terrified enemies spread Dread as they flee. | enchanter, control, assassin | today |
| **Left Behind** (new) | mid | Dashing leaves a decoy that draws enemies. | enchanter, evasive_monk, assassin | on_event:dash_start |

### Spellblade (5)

Weaving bare strikes, dashes and skills so each feeds the next.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Lent Edge** (new) | mid | After a skill, bare strikes carry its affinity and extra damage. | spellblade, armoured_duellist | on_event:cast |
| **Weave** (new) | mid | Alternating strikes and skills makes skills cheaper. | spellblade, evasive_monk | on_event:cast, adjust:essence_cost |
| **Out of the Step** (new) | high | A skill right after a dash has no wind-up. | spellblade, evasive_monk, assassin | on_event:dash_end, adjust:windup_s, adjust:recovery_s |
| **Fifth Leap** (new) | mid | Every 5th skill hit arcs to another enemy. | spellblade, burst_caster, control | today |
| **Banked Blow** (new) | low | Bare strikes bank damage for your next skill. | spellblade, bruiser, armoured_duellist | HitContext.cast_serial |

### Evasive / mobility (5)

Movement, dodging, travel and getting out.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Doorframe | high | Step between any two doorways you have touched in the current dungeon. | evasive_monk, assassin | data only |
| Long Step | low | Every 7th step covers 5 m instantly in the direction of travel. | evasive_monk | data only |
| Unfalling | low | No fall damage. | evasive_monk, assassin | data only |
| **Close Shave** (new) | mid | Narrowly dodging a telegraphed attack gives speed and a free rear hit. | evasive_monk, assassin, armoured_duellist | on_event:near_miss, adjust:move_speed |
| **Stored Stride** (new) | low | Walking banks free dashes for the next fight. | evasive_monk, spellblade, ranged_caster | on_event:dash_start, adjust:essence_cost, adjust:winded |

### Duellist (5)

One opponent at a time: reading, cutting wind-ups, finding seams, wearing armour well.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Tenth Strike | high | Every 10th hit on the same target deals x5 damage. | armoured_duellist, bruiser, assassin | scripted |
| **Narrow Room** (new) | mid | Fighting one enemy alone: deal more, take less. | armoured_duellist, assassin | today |
| **Cut the Word** (new) | high | Bare strikes interrupt wind-ups. | armoured_duellist, spellblade, control | today |
| **Seam Finder** (new) | mid | Three clean hits in a row and you pass its guard. | armoured_duellist, assassin, bruiser | adjust:poise_out |
| **Second Skin** (new) | low | Armour counts 50% more; gear changes only in town. | armoured_duellist, area_tank, bruiser | adjust:armour, adjust:can_equip |

### Drain / shadow knight (5)

Taking from enemies: essence, strength, healing into sinks, fear as armour. The title talent lives here.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| 1% Lifesteal | mid | Gain heal points equal to 1% of damage dealt to anything alive. | shadow_knight, berserker, healer | scripted |
| **Small Change** (new) | low | Hits on badly hurt enemies return a little essence. | shadow_knight, necromancer, assassin | today |
| **Hollowing** (new) | mid | Each hit weakens the target and strengthens you. | shadow_knight, bruiser, berserker | world:status deals_mult per stack |
| **Slow Sip** (new) | mid | Your damage-over-time slowly mends your wounds. | shadow_knight, coating, plague | today |
| **Feared Company** (new) | low | Each frightened enemy near you cuts your damage taken. | shadow_knight, enchanter, area_tank | today |

### Damage over time / coating / plague (5)

Damage-over-time that waits, spreads, coats a weapon or grows with every death. Poison's coating and Disease's plague merge here.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| **Withheld** (new) | high | Damage-over-time waits 4 s, then lands at once at x1.5. | coating, plague, burst_caster | adjust:dot_delay |
| **Inheritance** (new) | mid | Dying enemies pass their damage-over-time stacks on. | plague, coating, necromancer | today |
| **Stained Edge** (new) | low | After applying a DoT, your strikes keep applying it. | coating, assassin, armoured_duellist | on_event:status_out |
| **Census** (new) | low | DoT kills permanently strengthen your DoTs. | plague, coating | save:talent_state, adjust:status_stack_cap |
| **Bad Air** (new) | low | Enemies who stay close become Sick. | plague, area_tank, druid | today |

### General / utility / economy (23)

Talents no combat role owns: trade, perception, the Netherecho, the body's oddities. The economy and odd talents the books are known for.

| Talent | Value | Rule (one line) | Roles | Build |
|---|---|---|---|---|
| Weight of Coin | low | Thrown currency deals damage proportional to its face value. | ranged_caster | data only |
| Ledger Eyes | mid | See exact HP, by layer, of anything alive. | assassin, armoured_duellist | data only |
| Yesterday Sight | mid | Overlay of the room as it was 60 s ago: patrol paths, sprung traps, who was here. | assassin | data only |
| Price Sense | high | See the true market value of any item, and who would pay it. | - | data only |
| Wrongness | mid | Sense deviants nearby and hidden clauses on a dungeon's rule card. | - | data only |
| Super Farmer | low | Crops you tend yield far more. | druid | data only |
| Clean Cut | mid | Corpses you butcher yield double materials. | necromancer | data only |
| Packmule | mid | Carry capacity x5; hauled weight never slows you. | - | data only |
| Fine Print | high | Hidden clauses in contracts, auction terms and rule cards are visible to you. | - | data only |
| Mender | mid | Spend essence to restore gear durability. | armoured_duellist | data only |
| Borrowed Hands | mid | A pair of spectral hands holds and uses one extra item. | armoured_duellist, spellblade | data only |
| Thick Soul | high | Your Netherecho projection has ten times the durability. | - | data only |
| Concept Tongue | mid | See a construct's concept and tier before it notices you. | - | data only |
| Anchor | high | Project into the Netherecho while your body keeps walking on simple orders. | - | data only |
| Rat Tail | junk | You grow a prehensile tail. | - | data only |
| Twin Clock | mid | Sleep need halved. | - | data only |
| Spare Parts | mid | Your severed limbs obey you for 60 s: crawl, grab, hold a door. | necromancer, berserker | data only |
| Heavy Name | mid | Your aura presses as if you were one star higher. | - | data only |
| Lucky Floor | low | The first trap you trigger fails. | - | data only |
| Coupon | low | 10% chance a consumable is not used up. | - | data only |
| **Homing Things** (new) | junk | The first item you lose each passage comes home to your inn bed. | - | on_event:item_lost, on_event:rest |
| **Lodestone Head** (new) | junk | Always know the way out. | evasive_monk | reveals |
| **Taste of Iron** (new) | junk | Bite items to learn their band and a secret. | - | reveals |

## New hooks (merged)

17 of the 64 new talents need nothing new (existing hooks plus existing world scripts): Bell Ring, Change Given, Any Side, Chorus, Weedheart, Grass Remembers, Forward Only, Passed Along, Rumour, Fifth Leap, Narrow Room, Cut the Word, Small Change, Slow Sip, Feared Company, Inheritance, Bad Air.

The rest need six additions to `TalentEffect` / `HitContext` (rows 1-6), each serving many talents, plus a few world APIs (row 7). All follow the CLAUDE.md rule: gameplay code calls the hook, never branches on `talent_id`.

| # | Hook | What it does | New talents using it (count) |
|---|---|---|---|
| 1 | `on_event(name: String, data: Dictionary)` | One broadcast for happenings, raised by whichever system owns the event: `fight_start`, `fight_end`, `cast` (ability, affinity, kind, cost, essence before/after, serial, target), `status_out` (by you: target, id, stacks, ended_early, seconds_left), `status_in` (on you; cancellable via data.cancel), `interrupt`, `crush`, `dash_start` / `dash_end`, `near_miss`, `thrall_died`, `ally_lethal` (cancellable), `wound_opened`, `rest`, `wall_cleared`, `item_lost`. | Rebound, Weight Kept, Last Drop, Remainder, Broken Sentence, Tangle, After the Storm, Night Surgeon, Graft, Chalk Line, Planted Standard, Stand-In, Unwelcome, Appointment, Spare Room, Second Shift, Wild Pantry, Spent Pain, Wrong Waking, Toll of Sleep, Left Behind, Lent Edge, Weave, Out of the Step, Close Shave, Stored Stride, Stained Edge, Homing Things (28) |
| 2 | `adjust(key: String, value: float, data: Dictionary) -> float` | Any system about to use a named number asks the effects first: `essence_cost`, `windup_s`, `recovery_s`, `winded`, `move_speed`, `strike_interval`, `poise_out`, `poise_in`, `poise_regen`, `shove_in`, `crush_surface`, `status_time_out`, `status_stacks_out`, `status_stack_cap`, `dot_delay`, `alert`, `aggro_radius`, `thrall_cap`, `armour`, `can_equip`, `natural_heal_in_combat`, `natural_heal_overflow`, `loot_rolls`. Default returns value unchanged. Also the natural home for items' and tempering's number changes. | Held Ground, Weight Kept, Remainder, Crowd Sum, Quiet Room, Graft, Chalk Line, Soft Dark, Spare Room, Second Shift, Turning Year, Pollen, Fever Count, Butcher's Floor, Weave, Out of the Step, Close Shave, Stored Stride, Seam Finder, Second Skin, Withheld, Census (22) |
| 3 | `HitContext.cast_serial: int` (+ `ability_id`) | Data, not a hook: every hit a cast makes carries the cast's serial, so an effect can tell 'hits of this cast' (multiply, bank, count targets). `_perform_cast` stamps it; thralls' and zones' hits carry their cast's serial too. | Last Drop, Crowd Sum, Spent Pain, Banked Blow (4) |
| 4 | `on_lethal(amount: float, source: Node) -> float` | Last say before the body dies, from `_apply_damage` / `_check_death`, so every path (delayed debt, damage-over-time, self-harm) is caught. Returns the damage still applied. Not needed by a new talent here except through `ally_lethal`, but Borrowed Breath and The Last Inch (existing, data only) need it, and today's on_incoming misses delayed damage. | - (0) |
| 5 | `reveals(node: Variant) -> Dictionary` | Perception: what this effect lets the HUD or a tooltip show about an enemy, item or place (outline through walls, an arrow, a fact). Serves the existing perception talents too (Ledger Eyes, Price Sense, Wrongness, Concept Tongue, Fine Print) - five data-only talents waiting on one hook. | Appointment, Lodestone Head, Taste of Iron (3) |
| 6 | `save_state() -> Dictionary` / `load_state(d)` | A talent's own permanent counters (ledgers: Quiet Tally, Census; existing Scar Ledger and Grudge's hidden 'persists' flag). Saved with the player. | Quiet Tally, Census (2) |
| 7 | World APIs (not hooks) | A timed 'unseen' on the player (`Player.unseen_from`); a talent-added light source (`Light`); a one-attack forced target on an enemy; thralls reading `buffs`; a status whose `deals_mult` scales with stacks. | Planted Standard, Watch Fire, Clean Exit, Wrong Waking, Hollowing (5) |

Keys in use, with how many new talents read each: `HitContext.cast_serial` 4, `adjust:aggro_radius` 1, `adjust:alert` 1, `adjust:armour` 1, `adjust:can_equip` 1, `adjust:crush_surface` 1, `adjust:dot_delay` 1, `adjust:essence_cost` 3, `adjust:loot_rolls` 1, `adjust:move_speed` 3, `adjust:natural_heal_in_combat` 1, `adjust:natural_heal_overflow` 1, `adjust:poise_in` 1, `adjust:poise_out` 2, `adjust:poise_regen` 1, `adjust:recovery_s` 1, `adjust:shove_in` 1, `adjust:status_stack_cap` 1, `adjust:status_stacks_out` 1, `adjust:status_time_out` 1, `adjust:strike_interval` 1, `adjust:thrall_cap` 1, `adjust:winded` 1, `adjust:windup_s` 1, `on_event:ally_lethal` 1, `on_event:cast` 7, `on_event:crush` 2, `on_event:dash_end` 1, `on_event:dash_start` 2, `on_event:fight_end` 1, `on_event:fight_start` 2, `on_event:interrupt` 1, `on_event:item_lost` 1, `on_event:near_miss` 1, `on_event:rest` 2, `on_event:status_in` 1, `on_event:status_out` 5, `on_event:thrall_died` 2, `on_event:wall_cleared` 1, `on_event:wound_opened` 1, `reveals` 3, `save:talent_state` 2, `world:Light.add_source` 1, `world:forced target` 1, `world:status deals_mult per stack` 1, `world:thralls read buffs` 1, `world:timed unseen` 1.

Suggested order if Brent wants talents wired in batches: `on_event` (fight_start/fight_end/cast first) and `HitContext.cast_serial` unlock the most; `adjust` next (start with essence_cost, poise_out, move_speed, status_time_out); `reveals` unlocks five existing perception talents at once.

## Proposed weighting between clusters and rolled affinities (PROPOSAL - Brent decides)

Today `PrimeRoll.roll_offer` picks the talent first, then rolls affinities, and the two never meet [B 2026-10-11]. Three options, from none to light:

- **A. None (status quo).** Clusters are a design tool only; they guarantee the pool covers every playstyle, nothing more. Keeps design/04 point 6 ('it pairs with affinities it didn't choose') at full strength.
- **B. Light nudge, recommended if any.** Roll the affinity slots first, then multiply the talent weight by 1.5 for a talent whose `roles` include a role of a rolled affinity. Because creation rolls the eight bases only, a hybrid's role counts if the rolled base is one of its parents (Fire matches spellblade talents through Lightning, Earth matches duellist talents through Metal). General talents are never nudged. With 1 slot (87.5% of primes) a matching talent goes from roughly 1 in 3 of the pool to roughly 2 in 5 - a lean, not a rule. The number would live in balance.json "primes" (e.g. `role_match_mult: 1.5`, 1.0 = off).
- **C. One of three.** Leave each offer independent, but if none of the three offers has a role match, re-roll the talent of the third once. Guarantees one 'natural' pick on the creation screen without touching the other two.

Measured on this pool (value weights as today, one base slot, averaged over the eight bases): a role match is 32% of draws with no nudge, 41% at x1.5, 48% at x2. It is uneven by base: Earth matches 49% (area tank, plus Metal, Nature and Disease as a parent) but Wind only 16% (evasive, plus Lightning). Under B, Wind characters would still rarely see a matching talent; if that matters, the multiplier could be per base or the pool could grow in the mobility and spellblade clusters.

Our lean is A or B at a low multiplier: the setting's appeal is the odd pairing, and a strong nudge would make primes read like classes.

## Talents we were unsure about (fit with the setting or the rules)

- **Night Surgeon** regrows a lost arm by sleeping. Regrowth is the title talent's edge (design/03 section 2); this competes with it. The tempering toll is the price; it could instead stop short of lost limbs.
- **Any Side** and **Close Shave** hand out rear hits. They may flatten Wind's and Dark's positional play (Lee, rear bonus). The 8 s cooldown is the guard; playtest needed.
- **Weight Kept** needs the shove's swept check to treat the player as a wall. Physics change; untested.
- **Turning Year** (seasons inside a fight) is the most 'gamey' rule in the set; it may read as a video-game buff cycle rather than a vestige's odd rule.
- **Taste of Iron** assumes items have something undisclosed to reveal. design/06 says the catalogue is fixed and items show their stats; only cursed tolls are hidden today.
- **Watch Fire**, **Clean Exit**, **Wrong Waking**, **Hollowing** need small world APIs (light source, timed unseen, forced target, stacking deals_mult) listed above.
- **Stand-In**, **Planted Standard**, **Chorus**: support in a single-player game means helping thralls and lures. Thralls do not read buffs yet, so Planted Standard is weaker than it reads until they do.
- **Change Given** is close in spirit to Grudge (both answer being hit). Kept because one is instant and flat, the other a permanent, per-enemy percentage.
- Graft, After the Storm and Slow Sip were checked against design/04's balance rule (no in-fight healing that outpaces damage): Graft pours at 2%/s and only below half; After the Storm pays after the fight; Slow Sip fills sinks only. Untested in play.

## Open questions for Brent

1. **Weighting**: A, B or C above, and if B, what multiplier.
2. **Junk weight**: add `"junk": 4.0` (or similar) to balance.json "primes" `talent_weight_by_value`? Today junk rolls at 1.0, as rarely as high. Junk primes are cheap and common in the setting's market.
3. **The playable pool**: creation draws only from `main.gd` `TALENT_CHOICES` (the six scripted talents), so none of the 34 data-only or 64 new talents can be rolled yet. Should the pool become 'every talent with a script', read from data?
4. **Retired wound layers**: existing rules still say structural / superficial / catastrophic and 'any layer' (1% Lifesteal, Borrowed Breath, Scar Ledger, Hunger Engine, Stubborn Bone, The Last Inch). Health is one bar plus wounds since 2026-10-11 [B]. They are unchanged here as asked; rewrite them in a follow-up?
5. **Evolution depth**: we gave stars 2-4 explicitly and an `evolve_onward` pattern. Do you want every talent written out to 10 stars (the build plan's target), or is a pattern past 4 enough until play shows the curve?
6. **Support and allies**: is 'ally' in a single-player game thralls and lures only, or is co-op or a companion planned? It changes how strong the support cluster can be.
7. **Holy and Unholy**: the support and drain clusters are named for affinities not in the game yet. Keep the clusters regardless (our view), or fold them into healer and assassin until those affinities exist?
8. **Perception and the diegetic rule**: design/01 says there is no system UI. Do perception talents (Lodestone Head's arrow, Appointment's outline) show on the HUD, or only in the notebook?
9. **Hidden flags**: design/04 says one or two per talent stay hidden. Do you want us to mark which, per new talent, or roll which at creation?
10. **Count**: 104 talents total. The build plan says 108+; design/04 says 12+ per category. Want the last few in thin categories (perception, netherecho: the new set adds no Netherecho talent) next?

## Not tested

Nothing here has been built or played. The JSON was checked by script for unique ids, valid clusters, roles and categories, 3-5 hidden flags each, and that the 40 existing entries are unchanged apart from the two added fields. Whether any talent is fun, fair or priced right is untested - needs Brent.
