# Crafting depth v0: twenty skills, the subcombine chain, gathering, and what EverQuest teaches

Draft for Brent to approve or redline, 2026-10-18. **Nothing here is built and nothing here has been played.** Every number is a
first guess. Design and data drafts only: no file under `game/` was changed and the drafts are not loaded by the game.

Tags: **[B]** Brent's ruling or ask, **[C]** read in the books (through the project's paraphrased notes; the note is named),
**[F]** fan source - here mostly **EverQuest community wikis and guides, cited by URL** (section 15) - and **[MODEL]** our
invention. **[F?]** marks an EverQuest detail I know from the community's general understanding but could not confirm on a page
I could open; treat those as soft. Anything untagged inside a section headed [MODEL] is [MODEL].

**Originality.** EverQuest is a reference for *how a tradeskill system works* - skills, trivials, subcombines, containers, tools,
cross-skill dependencies. No EverQuest item name, recipe name, flavour text or exact number is used: every skill name, item,
recipe, formula constant and description here is ours (CLAUDE.md: nothing taken from other games). Nothing comes from the
1% Lifesteal books' text either.

Asked for by Brent 2026-10-18: *"Have the crafting agent look at EQ crafting, alchemy, Smith ingredients and other skills and make
sure we are as robust."* This builds on design/10 (the item catalogue, merged as v0.40.0) and supersedes its section 7 on crafting.

**Companion files** (none is loaded by the game):

| File | What changed |
|---|---|
| `tools/items/crafting_tables.py` | **New.** Skills, tools, the per-band chain, raws, byproducts, gear shapes, trivial offsets, the rules |
| `tools/items/build_items_draft.py` | Builds the chain, tools, bait, kits, pattern books, and stamps every recipe with skill, trivial, attempt level and tool; every gathered item with its skill |
| `design/data-drafts/items-full-v0.json` | **1,984 items** (was 1,390): +594 ingredients, intermediates, tools, kits, pattern books, bait, suppers |
| `design/data-drafts/recipes-v0.json` | **1,392 recipes** (was 955), with `rules`, `skills`, `tools` and 13 `stations` |
| `tools/items/validate_items.py` | New checks (section 11). Run 2026-10-18: **PASS, 0 errors** |

---
## 1. Summary

1. **EverQuest's tradeskills are deep because the skills need each other** - a smith needs a potter's moulds and somebody's
   leather padding; a jeweller needs metal bars - and because almost nothing is made in one step [F: EQ smithing chain - Almar's].
   design/10 had seven stations and no skills; every recipe was one step from a refined material. That was the headline gap.
2. **Twenty skills now**: fifteen crafting (Smithing, Leatherwork, Tailoring, Bowyery, Fletching, Pottery and Stonework,
   Rendering, Brewing and Distilling, Cookery, Alchemy, Poisoncraft, Etherwork, Setting, Auragraphy, Artifice) and five gathering
   (Mining, Felling, Foraging, Fishing, Dowsing). Each is 0-300, 25 points to a star band.
3. **A chain of 34 recipes per band** (36 items with the byproducts): hides are scraped (and give tallow), bones are ground (and give marrow), ore is smelted with flux
   in a crucible, bars become wire, sheet, rivets, fittings, folded alloy and arrowheads; clay becomes crucibles, vials and moulds;
   fruit becomes spirit; resin and herbs become tanning liquor; tallow becomes quench oil; salt and spirit become ether quench.
   A band-2 sword is now five intermediates from four skills, plus a pattern book, plus a made thing's part from a kill.
4. **Every recipe has a skill, a trivial, an attempt threshold and a tool tier**; every raw has a gathering skill, a trivial and a
   tool; fishing needs bait; anyone may dowse for an affinity's settled stone (an affinity shard), but it is very, very hard [B].
5. **Rules are kinder than EverQuest's where EverQuest was tedious** (section 12): no 5% failure on a mastered recipe; a failed
   combine returns about half the inputs; the first success of each recipe always teaches; recipes are learned from pattern books
   instead of guessed; skill caps come from stars, not from an arbitrary "only one skill above X".
6. **Kept from EverQuest because it works**: trivials, failure that costs something, tools that come back and stations that do
   not, portable kits that are worse than stations, region-specific patterns (EverQuest's cultural recipes), and a trophy that
   raises effective skill (ours are guild marks, tied to the setting's badges [C]).
7. **The economy still cannot be broken by crafting**: 0 recipes sell for more than inputs plus fee under the half-price rule for
   made goods; values still rise with band in every category and along every line; every ingredient has a source.

---
## 2. EverQuest's tradeskills, as a reference [F]

What follows is mechanics only, paraphrased from community wikis and guides (URLs in section 15). EverQuest changed over 25
years; where sources disagree I say so.

- **The skills.** Baking, Brewing, Fletching, Jewelcraft, Pottery, Smithing and Tailoring are open to everyone; Alchemy is shaman
  only (from about level 25); Poison Making is rogue only; Tinkering is gnome only; Research (spell research) is for the
  intelligence casters; Fishing and Foraging are gatherers (foraging only for some classes) [F: everquest.com tradeskill
  article; allakhazam Make Poison; official forum post on foraging].
- **Caps.** Most skills reach 200; one skill may go past it (to 250 or 300 depending on era) until a crafting-mastery advancement
  lifts the rest. Later expansions took caps from 300 to 350, but only for players who had *learned* roughly 98% of a skill's
  recipes, and no-fail, special-container and cultural combines do not count [F: eqlwiki Tradeskills; everquest.com; Almar's EoK].
- **Trivial.** Each recipe has a skill at which it stops teaching ("trivial"); combines below it can raise skill, on success or failure [F: everquest.com].
- **Success.** A published player formula: for trivial ≥ 68, success = min(95%, skill − 0.75 × trivial + 51.5%); below that,
  min(95%, skill − trivial + 66%); never under 5%; **trivial combines still fail 5% of the time**; stats do not affect success [F: eqlwiki Tradeskills].
- **Skill-ups.** Governed by the higher of Intelligence or Wisdom (Strength also counts for smithing, Dexterity for fletching);
  players observe the chance falls as skill approaches the trivial. The exact formula is not published [F: eqlwiki; lurkerlounge thread].
- **Failure** can destroy everything in the container; an advancement ("Salvage") and later a store potion return some or all
  of it [F: everquest.com; allakhazam Salvage; RedGuides].
- **Containers and stations.** Forge, kiln, pottery wheel, loom, sewing kit, fletching kit, oven, mixing bowl, spit, brew barrel,
  jeweller's kit, toolbox, tackle box, medicine bag; some are fixed in cities, some portable with fewer slots; special "always
  works" stations make certain quest combines no-fail [F: P1999 wiki container list; allakhazam containers].
- **Subcombines and tools.** Smithing works through intermediates - folded sheet metal, metal bits and rings, moulds bought from a
  supplies vendor, leather padding that has to be farmed - and nearly every combine wants a water flask; a smithing hammer and
  files are tools [F: Almar's classic smithing; eqlwiki rings-chains book]. Tools are returned on a combine while components are
  consumed [F?].
- **Sourcing**: vendor supplies, drops, foraged and fished goods, and other skills' outputs; some final items need several
  tradeskills [F: everquest.com].
- **Cultural recipes**: each race's armour is made at its home city's cultural forge, with good faction recommended [F: eqlwiki].
- **Trophies**: a series of tradeskill tests per skill awards a trophy that adds a percentage to effective skill and summons
  weight-reducing bags; the best augment in the game was only obtainable by maxing tradeskills [F: Almar's jewelcraft; allakhazam Artisan's Prize].
- **Later additions**: a searchable recipe window with favourites and an "experiment" mode for unknown recipes [F: everquest.com];
  a Tradeskill Component Depot (account-wide component storage usable from anywhere, huge stack sizes) [F: everquest.com depot FAQ].
- **Economy**: players were advised to sell crafted goods to players rather than vendors, and to vendor practice items for a
  part refund; raising a skill costs a great deal of money [F: everquest.com, Almar's]. Complaints: dropped gear outclassing
  crafted, ingredients only some classes can gather, the cost and tedium of thousands of combines [F: Shards of Dalaya forum (a
  different server); official forum].

---
## 3. Side by side: EverQuest -> our catalogue as merged (design/10) -> the gap -> what we do

| EverQuest mechanic [F] | design/10 as merged | Gap | What we do now [MODEL] |
|---|---|---|---|
| ~12 skills, each with its own container | 7 stations, **no skills** | No skill, no progression, nothing to learn | **20 skills** (15 craft, 5 gather), 13 stations (section 5) |
| Skill 0-300 (later 350), trivials | Recipes had a `stars` requirement only | No trivials | 0-300, **25 points a band**; every recipe has `trivial` and `min_skill` |
| Cap: one skill above 200 until an advancement | none | - | Cap from **stars**: 50 + 25 × stars (75 at one star, 300 at ten). No "only one skill" rule - **EQ's is arbitrary; don't copy** |
| Success formula, 5% floor, 5% fail even when trivial | Always succeeded | No risk | Success from skill vs trivial, 5% floor; **no failure at trivial + 13** (EQ's 5% fail on mastered recipes is pure tedium) |
| Failure destroys inputs; Salvage advancement returns some | none | - | Failure: fee spent, **each input back on a 50% roll** (+10% per station grade above the recipe's); field kits salvage nothing |
| Skill-up on success or failure, falling near trivial; stat-driven | none | - | Below trivial only: 0.35 × √((trivial − skill)/25), capped 60%, halved on failure; **first success of each recipe +1 for sure** (rewards breadth, not grind). No stats - we have none [F: no stat sheet - bible LAW 0] |
| Recipe learning: experiment, later a recipe book; 300-350 needs ~98% of recipes known | All recipes known | Nothing to find | Plain recipes known on joining a guild; **Fine recipes from pattern books** (70: one per skill per band, sold by that region's guild hall) |
| Containers: fixed stations and portable kits | Stations only | No field crafting except camp | Stations in towns (grade = half the band); **field kits** (alchemy, flensing, fletching) stand in for a low-grade station and salvage nothing |
| Tools returned; components consumed | none | - | **80 tools** (20 kinds × 4 tiers); returned each combine, lose a use, break at 0; tier needed = band's tier; a better tool adds success |
| Subcombines (sheet metal, bits, rings, padding) | One step from a refined material | Shallow | **34-recipe chain per band**, 446 subcombines across the draft (section 6) |
| Cross-skill dependencies (moulds, padding, bars for jewellery, arrowheads) | Weak (smith used leather) | Skills did not need each other | Every craft skill takes at least two other skills' outputs (section 8) |
| Moulds, water flasks, sharpening | none | - | Pottery moulds and crucibles (consumed), whetstones (consumed), quench oil (rendering), ether quench (etherwork). No water flask - a token ingredient in every recipe adds clicks, not choices |
| Vendor-bought supplies | Shop sold gear only | No bootstrap | The guild vendors sell **band-1 basics only** (clay, fluxstone, scrap iron, flax, linen, bait, tier-1 tools, pattern books). Money comes from loot [B], so above band 1 you gather or kill for inputs |
| Forage and fishing; forage limited to some classes | "gather" was a word | No gathering rules | 5 gathering skills with trivials and tools; **open to everyone** (EQ's class gate made people buy alts) |
| Cultural recipes at a home forge, faction-gated | none | - | Pattern books are **regional** (Tithebarrow, Winchgate, Cairnfast, then each band's city) and sold to members in good standing [C: standing gates vendors - b5 s10] |
| Trophies: % to effective skill | none | - | **Guild marks**: +5 effective skill each, at 50/100/150/200/250, each needing a witnessed masterwork; a badge-like record [C: badges, audited, gate services - b5 s10] |
| Specialisations (alchemy, research, poison by class) | none | - | No class locks (there are no classes [F: bible LAW 0]). Specialisation is opportunity cost: skill-ups cost hours on the world clock, the same hours delves need [B: "too many plates" is an opportunity cost] |
| Research makes spells | Skills come from scrolls | - | **Not added**: who can make an ether-imprint scroll is unknown in the setting [?]. Auragraphy writes runes on items only. Q7 |
| Component depot (later EQ) | Pack only | Storage for ingredients | Proposed later: stacking (`stack` field) and a trunk; not built (Q10) |
| Crafted worth less than drops; bazaar flooding | Crafted ≈ 75% of buying, sells at half | - | Kept: crafting **saves** a quarter, never **earns** (section 9). No bazaar (no players), so no flooding - the Tallyman is the only buyer |

---
## 4. The rules [MODEL]

All of them are data in `recipes-v0.json` `rules`.

| Rule | Value |
|---|---|
| Skill range | 0-300 for every skill; a band's recipes sit between 25 × (band − 1) and 25 × band |
| Skill cap | min(300, 50 + 25 × stars). One star 75 (bands 1-3), two 100, ten 300. Tied to stars because materials of a band only yield to an essence close to their own (design/10 §7.1) |
| Trivial | 25 × (band − 1) + gather 6, refine 8, subcombine 12, plain 16, fine 22, runed 24 |
| May try from | trivial − 30 |
| Success | clamp(5%, 95%, 70% + (effective skill − trivial) / 50 + 3% per tool tier above the one needed + station bonus); **at trivial + 13 a combine cannot fail**. So: 20% at 25 under trivial, 70% at trivial, certain 13 past it |
| Effective skill | skill + 5 per guild mark held in that skill |
| Failure | Fee spent; each input returned on a 50% roll, +10% per station grade above the recipe's; tools lose a use; a field kit returns nothing |
| Skill-up | Only below trivial: 0.35 × √((trivial − skill)/25), at most 60%; halved on a failure; at most +1 a combine; **the first success of a recipe always +1** |
| Tools | Returned every combine, one use lost (150 uses × tier); tier needed by band: 1 (bands 1-3), 2 (4-6), 3 (7-9), 4 (10-12) |
| Stations | Town stations by grade (1 Tithebarrow, 2 Winchgate, 3-6 cities not designed); camp (grade 0) for field food and dressings |
| Field kits | Field Alchemy Kit, Flensing Kit, Fletcher's Roll in three tiers: stand in for a station of grade 1 / 2 / 4, no salvage |
| Time | Every combine takes its recipe's hours on the world clock (1-12; a day is 90 real minutes [B]) |
| Growth | Proposed: a combine of your own band or above and below trivial adds a little latent aura [F: crafting is a source of latent aura - bible LAW 2] (Q5) |
| Patterns | A Fine recipe needs its pattern book read; Plain and subcombines are known when you join the skill's guild |

**Why the numbers.** A band's recipes span 25 points so one band is about 25 skill-ups; at 0.35 × √(…) and a first-make bonus on
~37 new recipes a band, a band takes roughly 60-100 combines for a focused crafter - a few evenings, not EverQuest's thousands.
The 5% floor keeps a stretch recipe possible; the no-fail band past trivial removes the chore of failing things you have mastered.

---
## 5. The skills [MODEL]

| Skill | Kind | Station | Tool | Makes | Needs from (in the data) |
|---|---|---|---|---|---|
| Smithing | craft | forge | Smith's Hammer | Bars (ore + fluxstone + crucible), wire, sheet, rivets, fittings, folded alloy, arrowheads, shot; metal weapons, heavy armour, bucklers, heater shields, flues; most tools | mining, pottery, rendering, etherwork, leatherwork, bowyery, tailoring, artifice, dowsing, kills |
| Leatherwork | craft | leatherworks | Currier's Knife | Leather (scraped hide + tanning liquor), grip wraps, straps; medium armour, staff slings, frames, belts | rendering, brewing, smithing, tailoring, bowyery |
| Tailoring | craft | loom | Needle Case | Cloth, padding, bowstrings, vanes; light armour, slings | kills (fibre), leatherwork, smithing, foraging |
| Bowyery | craft | bowyer | Drawknife | Staves, hafts, arrow shafts; bows, crossbows, round shields, fishing rods | felling, tailoring, artifice, smithing, leatherwork |
| Fletching | craft | bowyer | Fletcher's Jig | Arrows, bolts, barbed, bodkins, blunt bolts | bowyery, smithing, tailoring, pottery, leatherwork |
| Pottery and Stonework | craft | kiln | Potter's Ribs and Wires | Crucibles, vials, blade / head / plate / fitting moulds, whetstones, sumps, mortars, settling dishes | mining, dowsing |
| Rendering | craft | flensing yard (or Flensing Kit) | Flensing Knife | Scraped hides (+tallow), bone meal (+marrow), quench oil | kills only - the gateway skill |
| Brewing and Distilling | craft | still | Hydrometer | Spirits (from cache fruit), tanning liquor (resin + bitter herb) | foraging, felling |
| Cookery | craft | hearth, camp | Cook's Knife | Trail rations, Delver's Suppers | fishing, foraging, rendering |
| Alchemy | craft | alchemist's bench, camp | Mortar and Pestle | Dressings, poultices, salves, regrowth, draughts, pastes, painkillers, tonics, liniment, pale tinctures, mender's thread | foraging, rendering, brewing, pottery, dowsing, tailoring |
| Poisoncraft | craft | alchemist's bench | Venom Kit | Bleeding oil, sap venom, lead lacquer | fishing, foraging, rendering, brewing, pottery, felling, smithing |
| Etherwork | craft | settling vat | Settling Dish | Ether quench, affinity charges, ether slivers, tether incense, second-skin wax, binding salts | dowsing, brewing, rendering, felling |
| Setting | craft | runesetter | Setter's Loupe | Charms, talismans, cooling coils | dowsing, smithing |
| Auragraphy | craft | runesetter | Rune Stylus | Rune ink, runed gear, focus tablets [C: auragraphy is writing runes - bible LAW 4c] | dowsing, foraging, mining, smithing, every gear skill (the item it writes on) |
| Artifice | craft | workbench | Fitter's Case | Trigger locks, windlasses, flue throats, smoke pots, caltrops, flash powder, field kits, loupes, styluses, dowsing rods [C: artificers exist - b5 s8] | smithing, bowyery, pottery, leatherwork, felling, foraging, dowsing |
| Mining | gather | veins, resource caches | Miner's Pick | Ore, fluxstone, clay, grit-stone | smithing (the pick) |
| Felling | gather | living trees | Felling Saw | Logs, resin. Felling harms a living thing, so it pays the talent [C: anything alive counts - bible LAW 3] | smithing (the saw) |
| Foraging | gather | flora | Gatherer's Sickle | Knit, bitter and cold herbs, cache fruit, flax | smithing (the sickle) |
| Fishing | gather | fen, lake and realm water | Fishing Rod + bait | One fish per band: venom, oil and supper | bowyery (the rod), vendor (bait) |
| Dowsing | gather | ether-rich sites | Dowsing Rod | Ether salt, settled ether; **affinity shards for anyone, very, very rarely** [B 2026-10-18]: trivial 100 over the band's (to 300), found on 0.2% of dowses below trivial and 1% at or past it | artifice (the rod) |

Not a skill, on purpose: **binding a construct into an ability** - it is the soul's own act, irreversible and dangerous [B], not a
workshop recipe; Etherwork only makes the Binding Salts that help it. **Satellites** are never made [B].

---
## 6. Ingredients and the chain [MODEL]

### 6.1 Per band, every band 1-12

| Skill | Ingredients it makes (each band) | Raw inputs |
|---|---|---|
| Smithing | bar, wire, sheet, rivets, fittings, folded alloy, arrowheads | ore, fluxstone, crucible, fitting mould, whetstone, ether salt |
| Pottery and Stonework | crucible, vial, blade mould, head mould, plate mould, fitting mould, whetstone | clay, grit-stone |
| Rendering | scraped hide (+2 tallow), bone meal (+1 marrow), quench oil | the band's hide and bone remains |
| Brewing | spirit, tanning liquor | cache fruit; resin + bitter herb |
| Leatherwork | leather, grip wrap, straps | scraped hide + liquor |
| Bowyery | stave, haft, arrow shafts | log |
| Tailoring | cloth, padding, bowstring, vanes | the band's fibre remains |
| Etherwork | ether quench | ether salt + spirit |
| Artifice | trigger lock, windlass, flue throat | fittings, wire, haft, sheet, salt |
| Auragraphy | rune ink | ether salt + bitter herb |
| Gathered | ore, fluxstone, clay, grit-stone, log, resin, fish, four flora, ether salt; settled ether at odd bands | - |

**Smithing ingredients, as asked**: ores (12, one a band), metals (bars, sheet, wire), alloys (folded metal, one a band, for all
Fine metal work), fluxes (fluxstone; band 1 uses flux salt), moulds (four kinds a band, from Pottery), sharpening and grinding
(whetstones, from grit-stone), temper mediums (quench oil from Rendering for Plain, ether quench from Etherwork for Fine), fittings
(guards, pommels, buckles), hafts (Bowyery), grips (Leatherwork), padding (Tailoring), rivets.
**Alchemy ingredients**: herbs (knit, bitter, cold), roots and fruit (cache fruit), minerals (ether salt, bone meal), animal and
monster parts (marrow, tallow, fish venom, the elite's trophy for ascension aids), solvents (spirit), binders (tallow, resin),
vials (Pottery), essence-bearing catalysts (settled ether, ether salt).

### 6.2 One tree, top to bottom: the band-2 Gatesteel Sword (Fine)

```
Gatesteel Sword  [smithing 47, forge grade 1, two stars, Winchgate Smithing Patterns, hammer tier 1]
 |- Folded Gatesteel             [smithing]   <- 2 Gatesteel Bar + Iron-Bound Ether Salt [dowsing]
 |    '- Gatesteel Bar  x2       [smithing]   <- 4 Gatesteel Ore [mining] + Fluxstone [mining] + Crucible [pottery <- clay]
 |- Iron-Bound Blade Mould       [pottery]    <- 2 Iron-Bound Clay [mining]
 |- Iron-Bound Ether Quench      [etherwork]  <- Ether Salt [dowsing] + Tithe Plum Spirit [brewing <- 2 Tithe Plum, foraging]
 |- Reedback Grip Wrap           [leatherwork]<- Reedback Leather <- Scraped Reedback Hide [rendering <- a kill] + Bog-Oak Tanning Liquor [brewing <- resin, felling + Bitterbog, foraging]
 |- Gatesteel Fittings           [smithing]   <- Gatesteel Bar + Fitting Mould [pottery]
 '- Toll-Effigy Ironwork         (a made thing's parts - a kill)
```
Ten skills and two kills for one sword - as tangled as EverQuest's plate, and every link is something you can also sell.

### 6.3 Band 5 as an example of the scaling (values from the draft)

Raw: Veiniron Ore $12,000; Veined Fluxstone $7,700; Veined Clay $2,600; Grit-Stone $3,800; Veinwood Log $15,000; Resin $6,400;
Vein Loach $10,000. Made: Bar $33,000; Sheet $34,000; Folded Veiniron $100,000; Fittings $8,900; Rivets $2,200; Crucible $5,400;
Vial $670; Plate Mould $8,100; Whetstone $1,900; Quench Oil $5,300; Ether Quench $29,000; Drakeskin Leather $29,000; Scraped
Vein Drake Hide $110,000 (+2 Veined Tallow $5,100); Lantern-Silk Bolt $12,000; Rune Ink $76,000. Every value is ×4 a band
(design/10), so ratios hold at every band.

---
## 7. Gathering [MODEL]

- **Nodes, not drops.** Ore veins, clay banks, grit outcrops, trees, flora patches, fishing water and ether-rich sites are placed
  in zones by band (design/07's regions for bands 1-5; later regions not designed). Each node's trivial is 25 × (band − 1) + 6;
  the same success and skill-up rules apply; a failure wastes the time and a tool use, not a node.
- **Tools and bait**: every gathering skill has a tool kind in the same four tiers; Fishing also spends one bait a catch (four
  bait items, vendor-sold).
- **Felling and foraging harm living things**, so a lifesteal character heals a little doing them [C: anything alive pays]; mining
  and fishing do not (fish are caught, then they are dead - [?] whether catching counts as harm).
- **Dowsing is open to all** [B 2026-10-18]: ether salt and settled ether for anyone; an affinity shard for anyone too, but very,
  very hard - its trivial sits 100 over the band's (capped at 300) and even past it a dowse turns one up only 1% of the time
  (0.2% below). Numbers are first guesses for the balance pass.
  The Netherecho still gives nothing you can carry [B].
- **Rendering in the field is a hauling decision**: a Flensing Kit turns a 10 kg Reedback Hide into a 7.5 kg scraped hide and
  two tallow on the spot, with no salvage on failure. Worth it when the pack is the limit, not when the money is.

---
## 8. Cross-skill dependencies (computed from the draft)

| Skill | Takes inputs made by |
|---|---|
| Smithing | mining, pottery, rendering, etherwork, leatherwork, bowyery, tailoring, artifice, dowsing, kills |
| Leatherwork | rendering, brewing, smithing, tailoring, bowyery, kills |
| Tailoring | leatherwork, smithing, foraging, kills |
| Bowyery | felling, tailoring, artifice, smithing, leatherwork, kills |
| Fletching | bowyery, smithing, tailoring, pottery, leatherwork |
| Pottery | mining, dowsing, smithing, leatherwork |
| Rendering | kills |
| Brewing | felling, foraging |
| Cookery | fishing, foraging, rendering |
| Alchemy | foraging, rendering, brewing, pottery, dowsing, tailoring, kills |
| Poisoncraft | fishing, foraging, rendering, brewing, pottery, felling, smithing |
| Etherwork | dowsing, brewing, rendering, felling |
| Setting | dowsing, smithing |
| Auragraphy | dowsing, foraging, mining, smithing, leatherwork, bowyery, tailoring, kills |
| Artifice | smithing, bowyery, pottery, leatherwork, felling, foraging, dowsing, kills |

Tools close the loop: smithing makes most tools, pottery makes mortars, hydrometers, venom kits and settling dishes, bowyery the
jig and the rod, artifice the loupe, the stylus and the dowsing rod. A tier-1 set is sold by the guilds, so nobody is locked out
at the start.

---
## 9. The economy, unchanged in its invariants [MODEL]

- **Crafting saves, never earns.** Gear inputs are set near 45% of the item's value and the fee brings the total to 75%: a
  quarter cheaper than buying, half back when sold. Intermediates are worth 95% of inputs plus fee (less any byproduct), and
  never round up. Alchemy is worth 125% at the shop and sells at half. The validator finds **0 recipes that make money** under the
  half-price rule for made goods (design/10 §12.3); 323 would under today's live sell rule, which is why that rule must change first.
- **Failure is the money sink** EverQuest's crafting was, without the bitterness: half the inputs on average, plus the fee.
- **Crafted versus dropped**: Plain, Fine and Runed can be made; cursed and unique items only drop - the same split EverQuest
  players complained about, kept on purpose, because "gear is a floor" [B]. What crafting buys is *timing*: the Fine sword when you
  want it, not when a commander drops it.
- **No market flooding**: there are no other players; the Tallyman's prices are fixed.

---
## 10. Data fields (new in this draft)

| Field | On | Meaning |
|---|---|---|
| `recipe.skill` | every recipe | The crafting skill (a key of `recipes-v0.json` `skills`) |
| `recipe.trivial`, `recipe.min_skill` | every recipe | Where it stops teaching and can no longer fail; the least skill that may try it |
| `recipe.tool` | every recipe | `{kind, tier}`: the tool kind of the skill and the tier the band needs |
| `recipe.pattern` | Fine recipes | The pattern book that teaches it |
| `recipe.byproducts` | rendering | `{id: n}` that also come out |
| `gather` | raws, flora, salts, stones | `{skill, trivial, tool, bait?, attuned_only?}` |
| `tool` | kind `tool` | `{skill, kind, tier, uses, success_add_per_tier}` |
| `kit` | kind `kit` | `{station, grade, salvage}` |
| `teaches_patterns` | kind `pattern` | `{skill, band}` |
| kinds | - | `tool`, `kit`, `pattern` (sell at half; `rules.sell_factor_by_kind`); category `bait` |
| `recipes-v0.json` | file | `rules` (section 4), `skills`, `tools`, 13 `stations` with their grades |

---
## 11. Validator (run 2026-10-18): PASS, 0 errors

New checks: every recipe's skill exists, is a crafting skill and is done at that station; the station grade exists; trivial ≥
min_skill and ≤ 300 (and inside its band's range, as a warning); the recipe's tool is that skill's tool and a tool of that tier
exists; the pattern exists; byproducts exist and count in the arbitrage check; every gathered item names a gathering skill that
exists, with a tool tier and bait that exist; every tool's skill and kind agree; every kit's station exists; **every ingredient
has a source** (a recipe, a byproduct, or a drop, gather, cache, shop or other source); plus all design/10 checks (unique ids
and names, slots, inputs exist, no cycles, no NaN or negatives, values rise with band in every category and along every line, no
arbitrage, no canon names, live and design/06 ids kept). A file with six faults planted (unknown skill, trivial below the
attempt level, a missing tool tier, a missing pattern, an ingredient with no source, a skill at the wrong station) fails on all six.

```
1984 items, 1392 recipes, 785 pieces of gear

Crafting per band
band      recipes  subcombines  ingredients     gathered        tools     patterns
   1          155           54           82           16           20            7
   2          110           37           56           12            0            7
   3          117           37           61           17            0            7
   4          139           37           56           12           20            7
   5          116           37           61           17            0            7
   6          111           37           56           12            0            7
   7          145           37           61           17           20            7
   8          110           37           56           12            0            7
   9          117           37           61           17            0            7
  10          136           37           56           12           20            7
  11           72           30           52           17            0            0
  12           64           29           46           12            0            0
 ALL         1392          446          704          173           80           70

20 skills (15 crafting, 5 gathering); recipes or gathered items per skill:
  smithing 412, leatherwork 118, tailoring 112, bowyery 98, fletching 36, pottery 110, rendering 36, brewing 24, cookery 16,
  alchemy 101, poisoncraft 16, etherwork 64, setting 109, auragraphy 73, artifice 67, mining 47, felling 23, foraging 49,
  fishing 12, dowsing 42
```
"Subcombines" are recipes whose output is an input to another recipe; "ingredients" are distinct items used as an input. Gathered
counts are higher at odd bands because settled ether arrives there. Warnings: 335 - 323 are the live-sell-rule arbitrage, 12 the
tempering techniques not yet in `tempering.json`. Category counts per band are in the validator's full output (materials 433, raw 83,
tools 80, patterns 70, kits 9, bait 4).

---
## 12. Where EverQuest's way is worse, and we do not copy it

| EverQuest | Why not | Ours |
|---|---|---|
| Trivial combines still fail 5% | A chore with no decision in it | Certain past trivial + 13 |
| A failure destroys everything | Players bought a potion to undo it; that says it all | Half back on average; the fee always goes |
| Thousands of combines per skill | Tedium was the top complaint | ~60-100 combines a band; first-make bonus |
| Guessing recipes in an experiment window | Wiki-checking, not discovery | Pattern books you buy and read |
| Class and race locks (alchemy, poison, tinkering, research) | Forced alts; the setting has no classes | Everyone can learn everything; time is the limit |
| One skill above 200 until an advancement | Arbitrary | The star cap, which is the setting's own gate |
| Water flasks in nearly every recipe | Clicks, not choices | No token ingredients; every input is something else's output |
| Stat-driven skill-ups | We have no stats [F: bible LAW 0] | Guild marks and tools instead |
| No-fail quest stations that also give no skill | A special case players had to learn | Not needed |

Things EverQuest got right and we keep: trivials, tools versus components, stations versus kits, moulds and padding from other
skills, regional patterns, trophies that matter, recipes that make a final item from four trades.

---
## 13. Open questions for Brent

> **Brent's rulings, 2026-10-18** [B]: "go with your recommendations, keep the balance questions for later. Allow full sale
> price. No cap based on stars for skill level on crafting."
> - Approved as recommended: 2 (kinder failure), 3 (no class or race locks), 4 (regional pattern books), 6 (guild marks, with the
>   badge system), 7 (no research skill for now), 8 (field rendering), 10 (component trunk later), 11 (build order - minus the
>   sell-rule step, see below).
> - 9, changed (Brent, same day): "dowsing should not be limited to your affinities ... it should be open. And you should be able
>   to dowse for affinity shards (but this should be VERY VERY hard to do)." Dowsing is open to all; affinity shards are dowsable
>   by anyone at a trivial 100 over the band's and a 0.2% / 1% find chance (section 9).
> - 1, changed: twenty skills at 0-300, **no cap by stars** - any crafting skill can reach 300 at any star.
> - Sell price: **full** - made goods are not marked down; the live rule stays (worn gear at items.json `gear_sell_factor`,
>   everything else in full). design/10 §12.3's half-price proposal is withdrawn.
> - Kept for later (balance): 5 (crafting and latent aura), the skill-up and success numbers, the 323 recipes that turn a profit
>   at full price (the validator lists them as PROFIT / LIVE-RULE warnings), fees and prices per band.

Each with my recommendation; "go with your recommendations" approves all of them.
1. **Twenty skills at 0-300, 25 a band, capped by stars.** *Recommend:* yes.
2. **Kinder failure** (half back, nothing fails past trivial + 13). *Recommend:* yes.
3. **No class or race locks**; specialisation is only time. *Recommend:* yes - the setting has no classes.
4. **Pattern books for Fine recipes, regional and standing-gated** (our cultural recipes). *Recommend:* yes.
5. **Crafting grows you a little** at or above your band, below trivial [F]. *Recommend:* yes, but after fight growth has been played.
6. **Guild marks as badge ranks** (+5 effective skill each, witnessed masterworks). *Recommend:* yes; fold into the badge system when it exists.
7. **No scroll-making (research) skill** until we know whether the setting lets anyone make ether-imprint scrolls [?]. *Recommend:* leave it out.
8. **Field rendering** as the hauling trade-off (lighter loads, no salvage). *Recommend:* yes.
9. **Dowsing gated by affinity** for settled stones. *Recommend:* yes, it mirrors attuned wisps.
10. **A component trunk** (EverQuest's depot) once the pack stacks. *Recommend:* later, with the trunk design/07 already proposes.
11. **Order of building**: the sell rule, then rendering + leatherwork + smithing at band 1 (the shortest chain to a usable item), then
    the rest. *Recommend:* that order.

---
## 14. Lore I was unsure of [?]

- Whether anyone in the setting **makes ether-imprint scrolls**, and so whether a research skill fits.
- Whether **felling and fishing count as harm** to a living thing for the talent (felling surely; a caught fish is less clear).
- **Settled ether** and **made things** are ours (design/10 §17); dowsing for them inherits that.
- Whether **crafting gives latent aura** comes from a fan source only [F]; Brent has not ruled.
- Guild halls and their standing are invented; the setting's badges and vendor gating are canon [C], our use of them is not.

---
## 15. Sources (EverQuest mechanics reference; paraphrased, nothing copied)

- EverQuest Legends wiki, Tradeskills - https://eqlwiki.com/Tradeskills (success formula, stat effects, caps and mastery, cultural forges, container list)
- EverQuest official site, tradeskills article - https://www.everquest.com/news/imported-eq-enus-50549 (requirements per skill, trivial, failure, skill-ups on success and failure, training to 21, one skill above 200, recipe window and experiment mode, selling advice)
- Almar's Guides, classic smithing - https://almarsguides.com/eq/tradeskills/smithing/Classic/ (sheet metal, bits, moulds from a vendor, hammer, water flask, leather padding to farm, resale advice)
- Almar's Guides, research 300-350 - https://almarsguides.com/eq/Tradeskills/Research/EoK/ (cap 350 needs ~98% of recipes; which combines do not count)
- EverQuest Legends wiki, Rings, Chains and Arrowheads - https://eqlwiki.com/Rings%2C_Chains%2C_and_Arrowheads (files, water flasks, rings from ore; read through a search summary)
- Allakhazam, Salvage - https://everquest.allakhazam.com/wiki/eq:Salvage (recovery on failure)
- RedGuides thread - https://www.redguides.com/community/threads/trade-skillin.68354/latest (full return with potion and Salvage)
- Allakhazam, Make Poison - https://everquest.allakhazam.com/wiki/EQ:Make_Poison (class-only skills, alchemy level gate; read through a search summary)
- Project 1999 wiki, containers - https://wiki.project1999.com/Brew_Barrel and https://wiki.project1999.com/Grand_Forge ("always works" stations; read through search results only, the page would not open)
- Allakhazam, containers - https://everquest.allakhazam.com/wiki/EQ:Items_Containers_Tradeskill
- Almar's Guides, jewelcraft (trophies) - https://almarsguides.com/EQ/Tradeskills/Jewelcrafting/HoT/ ; Allakhazam, Artisan's Prize - https://wow.allakhazam.com/wiki/eq:Artisan's_Prize
- EverQuest, Tradeskill Depot FAQ - https://www.everquest.com/news/eq-tradeskill-depot-faq
- Tunare forum, trivial and difficulty (2004) - https://www.tapatalk.com/groups/tunare/tradeskills-t448.html ; Lurker Lounge, skill-up observations - https://lurkerlounge.com/forums/thread-6830.html
- Complaints: official forum post on foraging - https://www.everquest.com/news/imported-eq-enus-50037 ; Shards of Dalaya forum (a different server) - https://forum.shardsofdalaya.com/threads/tradeskill-update-suggestions-and-feedback.27932/latest

---
## 16. What was and was not checked

- **Checked**: the validator (section 11) passes on the generated drafts, and fails on a file with planted faults. The EverQuest
  mechanics in section 2 were read from the pages listed; where I could not open a page (the Project 1999 wiki, eqtraders) the
  claim is from search summaries or marked [F?].
- **Not checked**: anything in play. Skill-up and success numbers are untested guesses; "a band takes 60-100 combines" is
  arithmetic, not a measurement. Nothing is loaded; `game/` is untouched.
