# Element discovery with a context layer (2026-10-22)

Brent asked: can the clustering get close to the core elemental affinities (earth, fire, wind, water, lightning,
light, dark, ice) once a context layer is blended in? Script: `tools/runes/discover_elements.py`. Raw output:
`element-discovery-{narrow,wide,wide+time}.json`.

## Method

1. **Vocabulary.**
   - Words whose main sense in WordNet is in the physical world.
   - "narrow" (434 words): phenomena, natural objects, substances, processes, weather verbs.
   - "wide" (1,459 words): also states, attributes, events, and verbs of emitting and changing.
2. **Context layer.** Each word's vector is a blend: α × its own GloVe vector + (1 − α) × the mean GloVe vector of
   what WordNet says around its main sense: its definition, synonyms, broader terms, related forms, attribute links
   and up to 12 narrower terms. The context pins a word to its main sense ("fire" the flames, not the sacking).
3. **Clustering.** Spectral clustering over a nearest-neighbour graph, run across a grid of settings: α 1.0 / 0.7 /
   0.5 / 0.3, 10 or 15 neighbours, 8 to 40 clusters, and the eigengap's own choice.
4. **Probe scoring.** Each setting is scored with eight elemental probe word groups (fire, water, earth, wind,
   lightning, light, dark, ice). The probes never shape the vectors or seed the clusters; they only grade each
   setting:
   - **purity**: how much of each group lands in one cluster;
   - **distinct**: how many groups get a cluster of their own.

**What was tuned, plainly:** the cluster count and α were chosen by the probe score, which is light supervision. The
eigengap on its own prefers fewer, coarser clusters, which merge the elements into one weather domain (run 2).

## Results

| Setting | Purity | Distinct | Elemental clusters found |
|---|---|---|---|
| narrow, no context, 10 neighbours, 32 clusters | 0.62 | **1.00** | fire, water, earth, wind, lightning, light, ice each separate (dark has no words in this vocabulary) |
| wide, α 0.5, 15 neighbours, 40 clusters | 0.66 | 0.75 | all separate except **light and dark share one** |
| wide, no context, best setting | 0.54 | 0.75 | the context layer helps the wide vocabulary (score 0.41 → 0.49) |

Distinct = 1.00 holds across five different settings for the narrow vocabulary, not just one lucky run.

## The 40 natural clusters (wide, best setting), physical and vital ones

| Cluster | Central words | Our affinity |
|---|---|---|
| Fire | flame, fire, blaze, combustion, explosion, ignite | Fire |
| Weather | rain, wind, fog, snow, storm, hurricane | Wind |
| Temperature | cooling, heating, freezing, melting, thaw, chill | Ice (the cold end of one heat ↔ cold domain) |
| Ground | sand, dirt, mud, soil, dust, gravel, clay | Earth |
| Sea | sea, ocean, lake, shore, stream | Water |
| Liquid | liquid, fluid, dripping, evaporate, moisture, foam | Water |
| Light and dark | light, brightness, glare, darkness, glow, sunlight | Light and Dark, **one domain** |
| Energy | radiation, resonance, conductivity, infrared, spectrum | Lightning (electricity lands here) |
| Metal | metal, zinc, copper, iron, steel, silver | Metal |
| Chemistry | hydrogen, acid, chlorine, gas, ozone | Poison (loosely) |
| Growth | grow, mature, flowering, thrive, rooting | Nature |
| Disease | disease, infection, illness, symptom | Disease |
| Injury | injury, wound, pain, bruise, bite | Blood (loosely) |
| **Sound** (three clusters) | noise, roar, thud, rumble · bang, rattle, smash · sound, voice, ring, whistle | not ours: proposed |
| **Cosmos** | planet, moon, sun, star, sky, universe, meteor | not ours |
| **Force** | might, momentum, strength, force, drag, elasticity | not ours (near the proposed Gravity) |
| Heights | slope, climb, elevation, mountain, cliff | not ours |
| Turmoil, despair | chaos, panic, frenzy · despair, loneliness, misery | not ours (mind) |

The other clusters are abstract (circumstances, qualities, improving and reducing, size): language that is not
about the physical world.

## What it says

- **Yes: the classical elements are really in the data** once the resolution is fine enough. Fire, water, earth,
  wind, lightning, light and ice each form a cluster of their own.
- **Light and dark are one domain** at every resolution tried. So are heat and cold: ice is the cold end of a
  temperature cluster, while fire stands apart as combustion.
- **Water has two faces**: bodies of water (sea) and liquid in action (dripping, evaporating).
- **The data adds Sound (strongly), Cosmos, and Force/Momentum**, and two mind domains (turmoil, despair).
- **Life, Death and Dream** still have no physical cluster. In language they are states and ideas, not stuff.
