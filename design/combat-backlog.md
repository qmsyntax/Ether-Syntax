# Combat backlog (from the 2026-11-03 review)

The source is `design/combat-review-2026-11-03.md`; each item's full row is in its section 7, and the evidence in sections 1-6.

On 2026-11-03 Brent approved **R1, Q1, Q2, R3 and R4** for building [B]. The items below are logged for later; none
is approved yet.

| Id | Change | Why (from the review) | What it needs before it can start |
|---|---|---|---|
| R2 | **Essence from kills**: a small mote rises from each kill, worth the kind's `aura_value` x k, walked through or gathered within 2 m | Chains kill -> cast -> kill; the setting harvests essence from kills [F] | Brent's ruling on essence from kills (it changes how essence enters the game). Measure after R1 lands, which may be enough on its own |
| R5 | **Draughts that heal in a fight**: a consumable with charges, healing the bar only and never a wound's sink, refilled in town or from kills | No defensive tools: in-fight healing is 16-30 health a run against 300-520 lost a minute | **Brent's ruling** under CLAUDE.md "Health" (natural healing refills the bar only) |
| R6 | **Juice pass**: sound on hit, kill and cast; a death burst in the affinity's colour; knockback on the killing blow; bigger, coloured numbers for skill hits | There is no audio or particles anywhere; a kill barely registers | **Brent's yes for each download** (CC0, recorded in `tools/assets/MANIFEST.csv`); feel needs Brent |
| R7 | **Density with a reason**: swarm camps of 6-10 weak beasts beside today's camps, and one affixed champion per camp (a few data affixes with our own names) | About 1.9 enemies within 10 m on average, so AoE never pays | Do it **after R1-R3**, or a new character dies faster. The Stubble stays unstarred [B] |
| R8 | **Show growth on a kill**: a visible star-fill tick; a skill point sooner (`points.per_star_pct` 10 -> 5) | About 3 hours to fill the first star; one skill point every ~23 minutes | Latent aura stays hidden [B]: show the star's capacity, never the aura threshold |
| Q3 | **A faster breather**: meditation 4/s -> 8/s; `settle_s` 0.8 -> 0.5; the 1.0 s block after a hit moved from code into data | Mid characters spend 45-62% of their time meditating | Re-measure after Q2, which may cover most of it |
| Q4 | **A bigger first tank**: `first_star_start_pct` 20 -> 40 | A new character can't afford a cast for 94-96% of fight time | **Brent's ruling**: his 2026-10-11 ruling set the baby star at 20%. Re-measure after R1 and Q1 first |
| Q5 | **Draw the swing**: grunt and beast swings get a small floor arc during their wind-up, as the brute's circle does | Stepping off the drawn archer lines doubled survival; melee swings draw nothing | Nothing. A small change; feel needs Brent |

Measurement: the probes are in `tools/combat-review/` (see its README; copy them into `game/tests/` to run).
