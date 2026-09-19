# Working title: PASSAGE (a 1% Lifesteal dungeon crawler) — concept draft v0

Status: exploratory. Unlicensed fan-concept for internal evaluation only. Nothing here ships,
is shown publicly, or is monetised without a written licence from Robert Blaise (and whoever
else holds rights — see research/secondary-sources.md).

## 1. The pitch in one breath
A grim, economically brutal dungeon crawler where you are a nobody who just became an
archhuman. You pick (or get fleeced into) ONE permanent talent whose exact rules you don't know,
and you learn what it really does by bleeding for it inside passages — while rent, healer bills,
the Trading Association and the city lord all take their cut.

## 2. Why this universe suits a crawler (pillars drawn from canon)
| Canon law | Game pillar |
|---|---|
| Talent is permanent, unique, and its fine print is unknown even to the vestige | **Discoverable build.** Each run/character has one talent with hidden "technicality" flags. You reveal them by experiment (does bleed count? does overkill count? does it cure poison?). Knowledge is the real loot. |
| Skills/spells/techniques are learnable from imprint scrolls, gated by affinity, improve by bodily adaptation, and can be self-authored | **Loadout layer.** Scrolls are drops/purchases. Using a technique before your body is tempered hurts you. Understanding a training spell unlocks crafting your own variant. |
| Healing is ruinously expensive; unbacked archs die or retire early | **Attrition economy.** HP doesn't reset for free between delves. Injuries persist. Lifesteal-type sustain is *the* budget answer — and the reason the title talent is good. |
| Stars in the soul; first star is an empty cup filled by gathering wisps of your affinity | **Progression = gathering.** XP is not from kills alone: you harvest affinity wisps, and the biome you delve decides how fast you grow vs how much you earn (water arch: lakes to grow, deserts to get paid). |
| The Netherecho: a concept-layer where objects have talking vestiges, your projection is fragile, and death there is death | **Second map layer.** Every dungeon room has a Netherecho overlay you can project into: see wisps, read item histories, bargain with or flee from wild vestiges. High reward, one-hit-kill risk. |
| Passages → realms with catalogue codes and step counts; breaks spill into the city | **Dungeon structure.** Realms = biomes/tilesets, step count = depth/remoteness, uncleared pressure = break events that hit your home district. |
| Blood-soaked objects from passage slaughter become catalysts for unique vestiges | **Relic system.** Mundane items present at massacres can become run-defining relics (the can of beans is the mascot). |
| ATA, city lords, clans, contracts; everyone scams the newcomer | **Hub meta-game.** Selling loot blind vs paying for appraisal; contracts with factions that give access but take rights to what you find. |
| Aura pressure from higher stars | **Threat readability.** Out-ranked enemies apply a fear/nausea debuff just by proximity — you feel a boss before you see it. |

## 3. Core loop (draft)
1. **Hub (district)** — pay rent/tax/healer, read contracts, buy scrolls, choose a passage by realm code, step count and affinity match.
2. **Delve** — room-by-room tactical combat; attrition matters; decide when to project into the Netherecho to gather wisps or appraise finds.
3. **Extract or die** — carry out materials, catalysts, invader gear (legal status matters: confiscation vs fence).
4. **Convert** — sell blind, pay for appraisal, or gamble at auction; temper body; fill the star; test a hypothesis about your talent.
5. **Pressure ticks** — neglected passages build toward a break in your city.

## 4. Revision after the Book 5 read — the dungeon layer is canon, use it as written
The late series defines dungeons ("anomalous realms") with rules that are already a crawler spec.
Adopt them directly rather than inventing our own:

| Canon dungeon rule | Implementation |
|---|---|
| Entrance seals at a marker; exit unlocks only after minimum progress (e.g. 5 of 10 walls) | No retreat before the halfway gate. After it: cash out or push on — the core risk decision. |
| Stages escalate troops → elites → commander, spike past midpoint, enemies adapt their gear | Room generator with an adaptation director that counters what you've been using. |
| Reward appears per person at the exit, scaled to contribution; repeats pay less; feats can close a dungeon forever | Loot computed from a contribution ledger. Diminishing returns push players to new tickets. "Closing" a dungeon is the prestige clear. |
| Types: resetting, resource cache, instance/mystery, scenario (defence, assault, chambers+boss, trap maze), trial, auctioned tower | Six content templates; mystery instances are the high-variance roguelike mode. |
| Tickets auctioned; faction standing multiplies your bid | The hub economy. Standing is earned with badges and contracts, lost by making enemies. |
| Per-affinity reflux builds with every ability; kills purge it (with the right construct) | Heat gauges per element instead of mana/cooldowns. |
| Items: one small effect each; three fuse into a set at ≤90% success; uniques grow by condition and plateau | Tight itemisation. The fusion roll is a real gamble. Uniques are long-term pets. |
| Arena is safe and gives no growth | Sandbox/PvP/test mode that cannot be farmed. |
| Soul damage heals only through significant events | Long-term scar system across runs. |

**Camera/genre call (recommendation):** single-character, top-down or isometric tactical-action crawler, solo-first, with an optional hired party that raises income and lowers growth. The character sheet is the notebook.

**Scope for a first playable:** one affinity (water), one talent (the title talent, with 4–5 hidden technicality flags), one assault-type dungeon with the halfway-gate rule, reflux heat, limb-cost overcharge, and lifesteal-off-scenery recovery between rooms. That slice proves or kills the central idea: *a heal too slow to save you, that makes every other cost affordable.*

## 5. Open design questions
See design/02-open-questions-for-brent.md
