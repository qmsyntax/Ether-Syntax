# Water — affinity deep dive v0

Draft with Brent, 2026-10-21. Nothing new here is built. Replaces water's first-pass entry in design/14 §3.
Tags: **[B]** Brent's ruling, **[C]** read in the books (paraphrased notes only, cited by file),
**[MODEL]** our invention. Rune and skill names are original; the books' ability names are not used.

---
## 1. What water is

Water is the patient element. It is heavy and it is everywhere. It takes the shape of whatever holds it, wears down
whatever stands in its way, and moves things far bigger than itself. A water fighter does not out-hit an enemy: they
put the enemy where they want it, against a wall, off a ledge, into a crowd, under the surface.

From the books (research notes):
- Water is tied to the **origin of life**. Its primordial domain is an endless rain-swept ocean watched over by a
  titan [C: book5-mechanics-notes §primordial domains].
- Water archs **grow best near big water**, **earn well in deserts**, and have an easy time against fire
  elementals [C: intro-ch1-6 notes §5].
- A water arch's first lesson is **materialising water from essence**, then building their own way of making it
  [C: intro notes, "Squirt" and Create Water].
- Water's body art uses **the momentum of water inside the body** [C: intro notes, the Flowing Rain package].
- The 1% Lifesteal prime is a single-affinity **water** prime [C: intro notes §4].

## 2. Water in the world [MODEL, on Brent's ethertech and modern-town rulings]

- **Work.** Water archs run city water: mains, pumps, flood barriers and the fire brigade. A water arch on a fire
  crew is worth three engines. They haul fresh water on desert contracts, which pay well [C]. They clean hulls and
  dredge harbours. Ethertech: pressure tools, filtration rigs, purifiers.
- **Standing.** A common affinity, steady rather than glamorous. Every town needs some, and nobody envies them.
- **Where it grows.** Water wisps gather where water is: rivers, rain, the sea, wet cellars. In the Netherecho they
  drip, pool and run downhill like paint. In region 1: Sumpside (the swamp zone), Drowned Lock (its dungeon) and any
  zone in rain.
- **The primordial domain** [C] is a late-game place: the rain ocean and its watcher, where a water arch's trials and
  a prime remnant wait.

## 3. Water's rule

**Water moves bodies** [existing, design/05 §2.1]. Its skills shove and drag. A body shoved into a wall, a block or
another body is **Crushed**. Enemies have `shove_resist` (light 1.0, heavy 0.5, elite 0.25).

**New: water works the water that is already there** [MODEL, from C: water archs thrive near water and earn in
deserts]. Every place has a **wetness**:
- **Dry**: a desert, the Scorch.
- **Damp**: ordinary ground.
- **Wet**: rain, swamp, standing water.
- **Drowned**: in a pool, a river, a flooded hall.

| Where you cast | Cost | Effect |
|---|---|---|
| Dry | +30% (you make every drop from essence) | −10% |
| Damp | as now | as now |
| Wet | −15% | +10% |
| Drowned | −25% | +20% and shoves +25% |

- **A Soaked target counts as Wet** wherever it stands.
- **Water skills can make wetness.** Pools left behind make ground Wet. The Well rune (below) makes water from
  essence.

So a water fighter in the desert pays to bring their own water, and in the swamp they are at their best. This is
the books' "grows near water, earns in deserts", turned into play.

**Statuses water owns**:
- **Soaked** (exists): slower; shoves on it go further; lightning's cross rule conducts through it.
- **Waterlogged** [MODEL]: Soaked three times over. Heavy: the target counts as one weight class lighter for shoves,
  because it is carrying the water.

## 4. Base runes: eight pairs

Each rune has two uses:
- **As a skill**: the verb a water skill is built on.
- **As a means**: what it does when added to another water skill.

**Together** says what a skill holding both a rune and its opposite releases.

| Rune | As a skill | As a means | Opposite | As a skill | As a means | Together |
|---|---|---|---|---|---|---|
| **Surge** | push bodies away | adds a shove away from you | **Ebb** | draw bodies in | adds a drag toward you | **Churn**: a whirlpool that spins bodies and holds them in place |
| **Flow** | water in motion: travel on a current, slip past | it follows the ground and slides round obstacles | **Pool** | water that gathers and stays | leaves standing water (Wet ground) | **Spring**: water wells up and keeps welling: a pool that grows |
| **Soak** | saturate a target | applies Soaked | **Wring** | pull the water out of a body: damage by how wet it is | consumes Soaked for extra damage, leaving a pool at your feet | **Rinse**: washes every status off, good and bad |
| **Crush** | pressure: water hard as stone | heavier: poise damage +50%, Crush damage +50% | **Mist** | water as vapour: cover, broken sight lines | turns to fog where it lands; smothers fire | **Rain**: dense vapour falls over an area, soaking everyone in it |
| **Well** | make water from essence [C: materialising water] | it brings its own water (cast as if Wet anywhere) | **Dry** | unmake water back to ether | dries what it touches; drained pools refund essence | **Flux**: the water flickers in and out of being and passes guards and shields |
| **Mirror** | a still surface that reflects | turns shots aside; reflects one projectile | **Murk** | clouded water that hides | blinds what it hits for a moment | **Glimmer**: a reflection of you that enemies attack |
| **Erode** | wear things down | strips armour and guard a little per hit | **Coat** | a film of water over a body | the first hit is softened; burning is put out | **Polish**: worn smooth: the target slides, and shoves on it go twice as far |
| **Drown** | water in the lungs | silences: no casting, no calls for help, damage over time | **Float** | buoyancy | lifts: lightens, walks on water, slows falls | **Depth**: pinned under: the target cannot jump, blink or be lifted |

**Changes from design/14's first pass**: Freeze goes to the Ice affinity [B]. Flow's opposite is now Pool. Well ↔
Dry, Erode ↔ Coat and Drown ↔ Float are new. 16 base runes in all.

## 5. Skills

The 40 skills in design/05 stay. Water's eight, on their runes:

| Skill | Form | Base rune | Notes |
|---|---|---|---|
| W1 Water Bolt *(starter)* | projectile | Surge | |
| W2 Breaker *(starter)* | melee burst | Surge | |
| W3 Sluice Step *(starter)* | dash | Flow | |
| W4 Undertow | displace | Ebb | |
| W5 Riptide Lash | displace | Ebb | |
| W6 Standing Pool | ground zone | Pool | was "Soak" in design/14; a pool is its truer verb |
| W7 Pressure Jet | channel | Crush | |
| W8 Backwash | self buff | Coat | a film that throws attackers back (Coat with Surge as its means) |

**Runes with no skill yet**: Soak, Wring, Mist, Well, Dry, Mirror, Murk, Erode, Drown, Float. That is room for
about ten new water skills. Five worth building first:

| Skill (working name) | Form | Rune | What it does |
|---|---|---|---|
| **Draw Water** | point | Well | raises a pool where you point, from essence. The books' first water spell, made a skill |
| **Wringing Grip** | target | Wring | pulls the water out of one enemy: heavy damage on a Soaked or Waterlogged target, nothing much on a dry one |
| **Fogbank** | ground zone | Mist | a fog that blocks sight lines (archers lose you) and puts out fire |
| **Glass Water** | self buff | Mirror | the next projectile that hits you is turned back at its shooter |
| **Drowning Hold** | target | Drown | a held enemy cannot cast or call for help; a quiet answer to the Gleaner, the camp's runner |

**Tempering** (passive, body):
- **Slow Tide** exists: reflux sheds faster.
- Two to add [MODEL]:
  - **Water Body**: health and recovery, through the water inside you [C: water's body art].
  - **Deep Lungs**: hold breath; resist Drown and Choke.

## 6. Strengths, weaknesses, meetings

- **Strong**: control by movement; using the level (walls, ledges, crowds); putting out fire (fire enemies are easy
  [C]); the swamp and the rain.
- **Weak**: low raw damage; heavy and elite enemies resist shoves; deserts cost more; open ground with nothing to
  Crush against.
- **Meets lightning**: Soaked conducts (the design/05 cross rule, kept).
- **Meets fire**: water puts it out. Steam is the hybrid.
- **Meets ice**: ice turns water's pools to ice: Wet ground becomes slick, Soaked becomes brittle.
- **Meets earth**: mud (hybrid). Earth's stone is the best wall to Crush against.
- **Meets wind**: rain driven sideways. Wind's Mist is broken by Gust.

## 7. Where water shows up

- **Region 1**: Sumpside and Drowned Lock are water country. The Scorch on Carrion Flats is its worst ground.
- **Enemies**: anything on fire fears it. Pavise and heavy kinds shrug off shoves, so they need Crush or Erode.
- **Items**: anything that lowers water's cost (the books have such charms [C]). Water-affinity tools for the
  civilian trades.
- **Crafting**: brewing and alchemy want clean water; a water arch can supply it.

## 8. Questions for Brent

1. **Wetness.** Does "water works the water that's there" belong as water's second rule?
2. **Eight pairs.** Is this the right depth for every affinity's deep dive?
3. **The Together column.** What a rune and its opposite release when held together. Worth keeping for every
   affinity?
4. **Five new skills.** Draw Water, Wringing Grip, Fogbank, Glass Water and Drowning Hold: the right first five?
