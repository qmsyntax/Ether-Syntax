# Brief: skills built on base runes (2026-10-22)

Brent's ruling: **the skill is the verb.** Every skill is built on one base rune of its affinity and must actually do
what that rune means. Arc Lash, built on Arc ("jump between targets"), must jump, not be a straight beam. Brent asked
for a large number of skills per affinity, made in this way, that make sense, and with rune modifications that make
sense.

## Read first

| File | What it gives you |
|---|---|
| `CLAUDE.md` | project rules: original names only, no canon characters or the books' ability names, no book text; skills never hurt their caster; blood does **not** pay in health |
| `design/05-affinity-skills-and-combat-v0.md` | how skills are designed: behaviours, cost tiers, each affinity's one rule, the 40 skills |
| `game/data/abilities.json` | the 35 skills in the game: field names and real numbers. Match these field names |
| `game/data/statuses.json` | the statuses that exist |
| `design/14-rune-sets-v0.md` | affinity rules (first pass); the rulings in §7 |
| `game/data/runes.json` | every base rune: id, affinity, name, meaning, role, valence, electronegativity, effect. Read only; it is generated from the workbook |
| `design/runes-data/revised-rune-set.md` | the current rune set |

## Your job, for each of your affinities

**1. One skill per base rune** (10 per affinity; Water has 16), each built on that rune.

- Existing skills keep their place. Approved changes:
  - Arc Lash arcs to 1 more enemy within 4 m.
  - Stepped Leader leaves you Quickened for 2 s after landing.
  - Thunderclap Palm also Dazes and staggers everyone within 2.5 m of the target.
  - Backdraft draws enemies within 5 m 2 m inward before the blast.
  - Sluice Step sweeps passed enemies 2 m along.
  - Backwash's splash also hits everyone within 2 m of you.
  - Stoke moves to Blaze.
- design/05 skills not in abilities.json (Pressure Jet, Bellows Breath, Quarry Throw, Spindrift, Stored Bolt) count as existing designs: place them on their rune.
- A rune may carry a second skill only if every rune of the affinity already has one.

**2. Starter kit.** Mark exactly three skills per affinity as `starter`: one ranged, one close burst, one movement, as now.

**3. Effects.** For the runes of your affinities whose `effect` in runes.json is empty (every affinity except water, fire, earth, wind and lightning), write an effect in the syntax below. Each is what that rune does when **added** to a skill as a modifier.

## Skill entry

One JSON object per skill. Use real field names from abilities.json.

```json
{
  "id": "arc_lash", "name": "Arc Lash", "affinity": "lightning", "base_rune": "LIG-3a", "rune": "Arc",
  "status": "existing | changed | new", "starter": false,
  "kind": "projectile | melee_burst | dash | targeted_strike | delayed_blast | beam | blink | prop | displace | detonate | chain | ground_zone | self_buff | rod | channel | charge_release | new:<name>",
  "targeting": "aimed | point | target | self | feet",
  "summary": "one or two plain sentences a player reads",
  "verb_fit": "why this IS the rune's verb",
  "numbers": {"cost": 8, "reflux_per_cost": 1.0, "damage": 85, "range": 9, "jumps": 1, "jump_radius": 4, "on_hit": {"marks": 1}},
  "signature": ["jumps"],
  "new_mechanics": [{"name": "...", "kind": "status | behaviour | field", "definition": "one line"}],
  "good_modifiers": [{"rune": "Charge", "word": "what the pair becomes and why it makes sense"}],
  "bad_modifiers": [{"rune": "Ground", "why": "what makes no sense, and what the fallback would do"}]
}
```

- **signature**: the field path(s) the base rune's nature lives in for this skill. When other runes out-pull the skill's
  own rune, these are what shrink.
- **good_modifiers**: 3 to 5 runes, from the affinity's own base runes and the universal runes. Each should make a word
  that changes the skill in a way a player would call sensible or exciting.
- **bad_modifiers**: 2 or 3 runes that make no sense on this skill. Say so honestly; the cross-check uses these.

## Numbers

- **Cost tiers.** cheap 6-8, mid 10-14, dear 18-26 essence. Reflux per cost: low 0.4 to 0.7, middling 1.0, high 1.4.
  A new affinity picks one reflux tier as its usual and says why.
- **Bands.** Stay in the bands of the existing 35 skills: bolt damage 45-120, strike damage_mult 1.6-3.2, zones about
  3 m for 6-8 s, buffs 5-8 s.
- **New affinities.** Most need statuses or behaviours that do not exist yet (Frozen, Brittle, Blinded, Poisoned dose,
  Infected, Bleeding, Rooted by vines...). Define each once in `new_mechanics` with a one-line rule. Reuse an existing
  status wherever one fits (slowed, pinned, stunned, dazed, mired, aloft, soaked, alight, live).

## Effect syntax (step 3)

One op per `;`.

| Op | Meaning |
|---|---|
| `<group> x<m>` | multiply a stat group. Groups: power, reach, speed, cost, reflux, windup, duration, poise |
| `status <id> [n]` | apply a status. The id must exist in statuses.json or in your `new_mechanics` |
| `shove +<m>`, `pull +<m>`, `marks +<n>`, `jumps +<n>`, `pierce +<n>` | add to the hit |
| `interrupts`, `braced` | flags |
| `bonus <status> +<fraction>` | extra damage against a target with that status |

Keep each rune to 1 to 3 ops, matching its meaning; the five game affinities' effects in runes.json show the scale.
A modifier must be a small, sensible change, not a second skill.

## Output

Write **only** these files (create the folder if needed; touch nothing else in the repo):
- `design/data-drafts/skills/<affinity>.json`: `{"affinity": ..., "reflux_tier": ..., "rule": "the affinity's one rule, one line", "skills": [...], "effects": {"<rune name>": "<ops>"}}`
- `design/data-drafts/skills/<affinity>.md`: a short readable table (skill, rune, kind, what it does, starter) and the new mechanics.

Do not edit the game, the workbook, or any other design file. Do not commit. Report: the files written, the counts,
every new mechanic, and anything you were unsure of.
