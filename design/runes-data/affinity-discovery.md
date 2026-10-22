# Affinity discovery, run 2 (2026-10-22)

Brent asked for a greenfield look: which affinities does language data suggest, before our list is forced on it,
and how well does our list line up? Script: `tools/runes/discover_affinities.py`. Raw output:
`affinity-discovery.json`.

**Data** (downloaded with Brent's yes; kept outside the repo in `E:/Code/passage-data/raw`):
- WordNet 3.0, Princeton, WordNet licence (permissive): word categories and how often each sense is used.
- GloVe 6B 300-dimension vectors, Stanford NLP via its Hugging Face mirror, public domain (PDDL).
- ConceptNet not used, as Brent asked.

**Method.**
1. **Candidates.** 715 common nouns whose main use in WordNet is a natural phenomenon, substance, state, process,
   body part, feeling, plant or animal.
2. **Clustering.** Spectral clustering of their word vectors, with the number of clusters set by the data (the
   eigengap). Then each cluster is split again the same way.
3. **Run 1 discarded.** It let in chemical symbols and words like "in" (indium); run 2 keeps only words that real text
   mostly uses as such nouns.

## What the data finds: 11 domains, 27 sub-clusters

| Domain (data) | Splits into | Our affinities that land here |
|---|---|---|
| **Weather and the elements** | storm (rain, wind, snow, flood, drought) · ground (mud, sand, soil, dust, water) · light-and-smoke (mist, fog, darkness, sunlight, smoke, flame, shadow) | Water, Wind, Lightning, Ice (storm); Earth, Water (ground); Fire, Light, Dark (light-and-smoke) |
| **Materials** | metals (copper, iron, steel, ore, coal) · worked materials (wood, glass, marble, concrete, leather) | Metal |
| **Chemistry** | gases and combustion (hydrogen, vapor, plasma, radiation) · biochemistry (acid, enzyme, insulin) | Poison (weakly), Gravity (weakly) |
| **Disease and organs** | illness (infection, fever, malaria, nausea) · organs (liver, brain, marrow, bone) | Disease, Blood |
| **Body** | face and head · torso · limbs and injury | Blood (weakly) |
| **Animals** | wild (cat, snake, owl, lion) · livestock (sheep, cattle, horse) | Beast (proposed) |
| **Plants** | trees · crops and seed · flowering and pollen | Nature |
| **Fear and turmoil** | panic, anxiety, chaos, tension | none |
| **Grief** | despair, anguish, sorrow, shame | none |
| **Anger** | anger, resentment, indignation | none |
| **Desire and glory** | passion, longing, joy · glory, fame, pride | Dream, Mind, Spirit (all weakly) |
| **Situations** | threat, danger, crisis, survival, existence | Life, Death, Time, Space (weakly) |

## How aligned our list is

- **Close matches** (a clear cluster of their own, or a clear sub-cluster): Water, Wind, Lightning, Metal, Disease,
  Light, Dark, Nature (as plants), Beast (proposed).
- **Present, but not as we cut them**:
  - Fire, Light and Dark fall in **one** sub-cluster (light, flame, smoke, shadow).
  - Earth is the ground sub-cluster (soil, sand, mud); the word "earth" itself reads as the planet.
  - Ice sits inside storm weather.
  - Blood sits with organs and disease.
- **No home of their own in this data**: Life, Death, Dream, Mind, Spirit, Time, Space, Sound, Gravity, Poison. Some
  were filtered out because WordNet files them under other categories ("fire" and "death" as events, "dream" as
  cognition, "sound" as communication). Widening the categories is the next run.
- **Emotions form four clear domains we do not have**: fear/turmoil, grief, anger, desire/glory.

**Our hand-made affinity positions barely match word similarity**: correlation 0.09 over the 120 pairs. The biggest
reason is a known property of word vectors: **opposites count as closely related**. In this data:
- Life–Death (0.52) and Light–Dark (0.53) are the two most related pairs;
- our axes make them the most opposed.

Both readings are true at once. Light and dark are one domain with two ends. That is what our "affinity with its
opposite inside it" structure already says about runes, now said about affinities.

## What this suggests (for Brent)

1. Affinities may be best read as **domains with two ends**: Visibility (light ↔ dark), Vitality (life ↔ death).
   Not as separate opposed affinities.
2. The data supports adding **Beast** and some **emotion** affinities, and finds no natural cluster for Time, Space,
   Gravity or Sound at this level.
3. Our elemental set is close to the classical one the data rediscovers: weather (air and water in motion), ground
   (earth), and light-and-flame (fire and light).
