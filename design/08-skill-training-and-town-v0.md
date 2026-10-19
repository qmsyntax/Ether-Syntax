# Skill training and the walkable town v0

Draft of 2026-10-18, written and built the same day on branch `feat/skills-town`. **Built, not played.** Every number
is a first guess and lives in `game/data/skill_tree.json` or `game/data/town.json`.

Tags: **[B]** Brent's ruling, **[C]** read in the books (through the project's paraphrased notes only), **[F]** fan source,
**[MODEL]** our invention, **[?]** unknown. Anything untagged inside a section headed [MODEL] is [MODEL].
Every person and place named here is original to this project.

Asked for by Brent 2026-10-18: *"Skills should not be auto assigned. You should be given skill points and a skill tree for
training. You should be able to pick 2 skills when you start. Then leveling future skills comes from training in town etc.
Also, the town needs to not be a menu. Make the town a place with people we interact with to do the menu functions."*

This overrides design/05 section 1 where it says each affinity's kit is given at the start and the rest come only from
scrolls [C: scrolls]: scrolls stay, but they are now the second way in, not the only one.

---
## 1. Decisions (one page)

| # | Decision | Tag |
|---|---|---|
| 1 | No skill is given automatically. A new character picks **exactly two** starting skills. | [B] |
| 2 | The two are picked at character creation, on a new **Skills** step after the Prime (so the affinities are known), from the **root skills** of the affinities the prime carries. They go on hotbar slots 1 and 2. | [B] two skills; [MODEL] roots only, the step's place |
| 3 | Further skills come from **skill points** spent on a **skill tree**, and only at a **trainer in town**. | [B] |
| 4 | Skill points are earned by **star growth**: every `points.per_star_pct` (10) percentage points of star capacity grown, on any star, earns one point; **ascending** earns `points.on_ascend` (2) more. A new character starts with `points.start` (0). | [MODEL] |
| 5 | One tree per affinity; a character sees and can learn only the trees of affinities it holds (the existing `can_learn` rule). | [B] affinity restriction (2026-10-11); [MODEL] one tree each |
| 6 | Tree shape: tier 1 = the three kit skills (the roots); tier 2 = three skills, each hanging off one root; tier 3 = one capstone that needs **either** of two tier-2 skills. 7 nodes per affinity, all 35 abilities placed. | [MODEL] |
| 7 | Price of a node: tier 1 and 2 cost 1 point, tier 3 costs 2; plus money ($300 / $600 / $1,200). | [MODEL] |
| 8 | A trainer can also **drill** a skill you know: 1 point + $200 for +40% stage progress. The stage itself still only advances when a construct is bound into a full bar (Brent 2026-09-23); drilling never raises a stage on its own, and progress by use keeps working. | [MODEL] |
| 9 | **Scrolls still work** anywhere, as before: no points, no prerequisites, only the affinity rule, and they cost more money ($1,200 in the shop). A skill learned from a scroll counts as learned on the tree and opens its children. | [B] keep scrolls (task brief); [MODEL] no prerequisites |
| 10 | The skill tree can be **looked at anywhere** (key `skills`, default L, and from the soul screen); the Learn and Drill buttons only work at a trainer. | [B] no learning in the field; [MODEL] viewing anywhere |
| 11 | The town is a **walkable level**: the same movement, camera and click-to-walk as everywhere else. Each service is a person standing at a stall or a door; walk up and press `interact` (F), or click them, to talk. Walking away closes their panel. | [B] |
| 12 | The exits are places: the **Dross Gate** (north-east) and the **practice arena gate** (north) are walked through; the **assault passage door** (west) is shut and needs a ticket: interact at the door, or buy from the ticket clerk beside it. | [B] exits walkable; [MODEL] which gate needs a key press |

## 2. The trees [MODEL]

`requires` is "any one of". Roots have no prerequisite.

| Affinity | Tier 1 (roots, the kit) | Tier 2 (needs) | Tier 3 capstone (needs either) |
|---|---|---|---|
| Water | Water Bolt, Breaker, Sluice Step | Undertow (Water Bolt), Riptide Lash (Breaker), Backwash (Sluice Step) | Standing Pool (Undertow / Riptide Lash) |
| Fire | Cinder Spit, Kiln Fist, Flashover | Stoke (Cinder Spit), Backdraft (Kiln Fist), Slag Pool (Flashover) | Pyre Call (Backdraft / Slag Pool) |
| Earth | Slingstone, Landslide Blow, Raise Slab | Pillar (Slingstone), Bedrock Shove (Landslide Blow), Stonehide (Raise Slab) | Tremor (Pillar / Bedrock Shove) |
| Wind | Cutting Gust, Crosscut, Tailwind | Downdraft (Cutting Gust), Crosswind Veil (Crosscut), Gale Lane (Tailwind) | Updraft (Downdraft / Gale Lane) |
| Lightning | Arc Lash, Thunderclap Palm, Stepped Leader | Forked Path (Arc Lash), Static Coat (Thunderclap Palm), Ground Rod (Stepped Leader) | Dead Short (Forked Path / Static Coat) |

Pacing check (unmeasured): Brent set the first star to take about two hours (balance.json "stars", 2026-10-11), growing
20% -> 99%, so roughly 8 points over the first star, +2 at ascension. A one-affinity character needs 6 points to finish its
tree after its two picks (1 + 1 + 1 + 1 + 2), so the first tree fills around ascension. A two-affinity character has to
choose. That pressure is intended; the knob is `points.per_star_pct`.

## 3. The town [MODEL]

A 36 x 30 m square of the city kit (`data/town.json`): street fronts on the north and west, low walls to the camera's
side, stalls, lamps, a well in the middle. One person per service, each a real character body (sex, look and clothes
from data, looks varied by a fixed seed so the town looks the same every visit), with a name plate over their head.

| Who | Where | Does (the old town menu's buttons) |
|---|---|---|
| Sister Aud, healer | stall, north-west | the healer |
| Haskel Brandt, merchant | stall, north | the shop; sell your loot |
| Morrow Pell, innkeeper | inn door, north | a room for the night; save / load; start a new character; your ledger |
| Tamsin Ree, skill trainer | training ground, west | the skill tree with Learn and Drill live |
| Gorran Vell, yard master | tempering yard, south-west | the tempering yard |
| Nils Ostry, corpse clerk | by a cart, east | corpse retrieval |
| Edda Kell, ticket clerk | beside the passage door, west | a ticket into the assault passage |
| (the Dross Gate) | north-east gap | walk through: out into the Stubble |
| (the arena gate) | north gap | walk through: the practice arena |

Inventory (I), soul (K), skill tree (L) and controls (Esc) are keys, as everywhere. Every panel shows the ledger (purse,
pack, condition, soul) on the right, which used to be the town menu's right half.

Arrival: back from the passage you stand at its door; from the arena at its gate; from the Stubble just inside the Dross
Gate; a new character, a load or a death wakes in the square by the well.

## 4. Not decided / open for Brent

1. Is star growth the right source of points, or should points come from something you can see coming (a level, delves made)?
2. Should drilling exist at all, and should it cost a point (it competes with new skills) or only money and time?
3. Should scrolls ignore prerequisites (now) or obey them?
4. Should the trainer be one person for every affinity (now), or one per affinity, perhaps in different towns?
5. Respec: none is offered. Unlearning is not possible.
6. In town you can still swing at the air and meditate. Nothing in town can be hurt.

## 5. What was and was not checked

See the commit message on `feat/skills-town` and the session report. Rules are covered by `tests/selftest.gd`
(`_test_skill_tree`, `_test_town`); picking two skills by clicking is covered by `tests/creation_probe.gd`; learning at
the trainer by clicking is covered by `tests/ui_click_probe.gd`. How the town feels to walk round, whether the people read as
people from the game camera, and whether the pacing of points is right are **untested - need Brent**.
