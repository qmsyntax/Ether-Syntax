# Forcing our 16 affinities onto the data (2026-10-22)

Brent: force our list of affinities onto the data, make it all there is, and list the associated runes N edges deep
from each core. Script: `tools/runes/forced_affinities.py` (shared loaders in `wn_glove.py`). Output:
`forced-affinities.json` and the workbook `design/rune-candidates.xlsx`, which has a summary plus one sheet per
affinity.

## Method

- **Vocabulary.** 3,717 common nouns, verbs and adjectives whose main WordNet sense is in the physical world, the body,
  feelings, plants, or verbs of change, motion, contact, emission, consumption, perception or creation.
- **Graph.**
  - Nearest-neighbour links (8 per word) over context-blended vectors (half GloVe, half WordNet context).
  - WordNet's own links, through each word's main sense: synonyms, related forms, attributes, broader and narrower
    terms, antonyms, similar-to.
  - Edge length is 1 minus the cosine of the two vectors.
- **Cores.** Each affinity's name plus two pinning words, the only hand-chosen input. Two cores were changed after
  the first run because the data read the word another way: Earth's "earth" (the planet) became "rock", and Ice's
  "freeze" (halting, as in freezing assets) became "snow".
- **Assignment.** Every word goes to the affinity whose core it is nearest to along the graph ("all there is"). Each
  word also gets:
  - **depth**: edges from that core;
  - **specificity**: how much more it belongs to its affinity than to the average affinity;
  - **its next-nearest affinity.**
- **A first run had a bug and was replaced.** It linked words through all their senses, so "wind" pulled in coil and
  loop.

## What falls out

The most specific verbs per affinity are the base-rune candidates. Nouns are in the workbook.

| Affinity | Words | Most specific verbs |
|---|---|---|
| Water | 228 | overflow, surge, drain, float, gush, splash, boil, plunge, pour, stir, drift, dip, soak |
| Fire | 88 | ignite, explode, detonate, destroy, demolish, burst, wreck, quell, shatter |
| Earth | 103 | dig, tunnel, climb, mount, skid, stain, wash |
| Wind | 82 | lash, whip, knock, ram, smack, bump, grind |
| Lightning | 97 | boom, buzz, blast, bang, rattle, ring, whiz, generate, strike, smash |
| Ice | 20 | thaw, melt, glaze, freeze, suspend |
| Dark | 96 | obscure, hush |
| Metal | 88 | mesh, rust, nail, glue, mold, fuse, seal, merge, blend |
| Blood | 97 | breathe, choke, suck, digest, transplant, peel, scratch |
| Life | 486 | revive, renew, mend, cure, rebuild, strengthen, enrich, inspire |
| Death | 157 | kill, slaughter, vanish, bury, haunt, suffer, release |
| Nature | 1,377 | cultivate, thrive, flourish, develop, build, evolve, expand, produce |
| Light | 182 | glow, flash, glitter, glare, blink, emit, wink, polish, highlight |
| Dream | 353 | imagine, envision, conceive, contemplate, invent, wish, wake |
| Poison | 41 | spill, exhaust (few: poison is a small domain in this vocabulary) |
| Disease | 222 | infect, cough, spread, overrun, beset, stifle, torture |

## Agreement with the hand-made runes

- 91 of our 166 base-rune names exist in the vocabulary. **The data puts 30 of those 91 (33%) in the same affinity we
  did.** Chance would be about 6%.
- Best agreement: Water (5 of 9: surge, flow, soak, float, ...), Light (4 of 7), Ice (3 of 6) and Dream (3 of 5).
- Worst: Poison (0 of 5) and Earth (1 of 7).
- Many misses go to **Nature**: generic growth and change verbs (raise, root, forge, reap) are drawn to its "grow"
  core.

## What it says

1. **The elemental affinities hold up when forced.** Water, Fire, Light, Metal, Disease, Death and Blood get coherent,
   game-usable verbs at the top.
2. **Some affinities take on a different character than we gave them:**
   - **Wind's** verbs are about striking (lash, whip, ram);
   - **Lightning's** are about sound (boom, buzz, rattle), because thunder is in its core;
   - **Fire's** are about destruction (explode, demolish).
3. **Hubs.** Life (486 words) and Nature (1,377) soak up generic words, because "all there is" makes every abstract
   word land somewhere. Their low-specificity words are the natural **universal runes**: concepts that belong to no
   one affinity.
4. **Thin affinities.** Ice (20), Poison (41) and Dark (96, mostly nouns and colours) have few verbs of their own in
   language. Their runes would need designing more than finding.
