# Item catalogue v0: the full-game item list, one star to ten and beyond

Draft for Brent to approve or redline, 2026-10-18. **Nothing here is built and nothing here has been played.** Every number is a
first guess. Design and data drafts only: no file under `game/` was changed, and the draft is not loaded by the game.

Tags: **[B]** Brent's ruling, **[C]** read in the books (through the project's paraphrased notes only; the note is named),
**[F]** fan source, **[MODEL]** our invention, **[?]** unknown or a guess about the setting. Anything untagged inside a
section headed [MODEL] is [MODEL]. Short forms for the notes: `intro` = `research/intro-ch1-6-mechanics-notes.md`,
`b5` = `research/book5-mechanics-notes.md`, `b5b` = `research/book5-ch226-230-notes.md`, `bible` = `design/01-systems-bible-v0.md`.

**IP hygiene.** Every item name, description, material, creature and effect in this document and its data is original to this
project. No canon character is ported and no canon item is named. Where the setting supplies a *kind* of thing (satellites,
storage rings, ascension elixirs, soul elixirs, binding gems, catalysts, spirit abilities) the note it came from is cited and the
item that fills the slot has our own name and our own wording. The validator refuses any name or description that contains a
name from the research notes (section 14).

Asked for by Brent 2026-10-18: *"We need someone to build a starting full game items list. It needs to be long, include crafting
items, alchemy items, weapons, armor, consumables for skills and what not....and be full game (to 10 Star plus level), so scaling
in power and efficacy."*

**Companion files** (none is loaded by the game):

| File | What it is |
|---|---|
| `design/data-drafts/items-full-v0.json` | The list: **1,390 items** in the `game/data/items.json` schema plus the new fields of section 13 |
| `design/data-drafts/recipes-v0.json` | The **955 recipes** grouped by station, and the station table. Generated from the items' own `recipe` fields; the item is the source of truth |
| `tools/items/build_items_draft.py` | Makes both files from tables (bands, materials, bestiary, base lines, specials). Edit a table and re-run; hand edits to the JSON are lost |
| `tools/items/validate_items.py` | Checks the draft and prints the summary in section 14. Stdlib only |

**Designed against** commit `70a0f92`: twelve slots and 59 live items (`game/data/items.json`), the approved design/06 catalogue
(`items-v2.json`, 191 entries, not loaded), two stars in the build (`player.try_ascend` stops at 2; `balance.json`
`ascension_2.body_scale` 1.3), 100 essence per star, 35 abilities, 6 tempering techniques, 8 enemy kinds with `remains`, and
Brent's 2026-10-18 money rule (kills and clears pay loot; cash only from selling in town).

Contents: 1 Summary · 2 What this changes · 3 The star ladder · 4 What scales · 5 Rarity, runes, tolls, uniques, sets ·
6 Materials · 7 Crafting · 8 Alchemy · 9 Skill consumables and ammunition · 10 Remains and trade goods · 11 Keys and quest
items · 12 Economy · 13 Schema · 14 Counts · 15 Wiring it later · 16 Open questions · 17 Lore I was unsure of · 18 What was checked

---
## 1. Summary

1. **A band is a star.** Every item has a `band` from 1 to 10, plus 11 and 12 for "ten stars and beyond". Band 1 is the
   approved design/06 catalogue, unchanged in numbers, with the live ids kept. Bands 2-12 are new. [B: to ten stars and beyond]
2. **Gear rises 5% a band; the body rises far more.** A band-10 sword multiplies the body's strike by 2.17 where the band-1 one
   multiplies it by 1.40, but the 10-star body underneath hits about 7.5 times as hard and has about 10.6 times the health.
   The rule of thumb: **one ascension is worth about five bands of gear**. Gear stays below the body [B: gear matters less than the body].
3. **Everything that pays or costs rises four times a star.** Sell values, prices, fees and the reference income of a trip
   (about $5,000 at one star, $1.3 billion at ten). The existing satellites already sit on this curve ($2,400, $9,500, $38,000).
4. **Weight rises too** (the square root of the worn-weight allowance), so heavy gear stays something you grow into at every star
   and gear from far above your star is too heavy to wear well. No item has a rank requirement [B: any rank can wear anything].
5. **One soft gate**: an item more than two bands above your stars is **Loud** (section 4.3). Its base numbers still work; its
   effect line sleeps and it draws attention. Satellites are exempt by Brent's ruling.
6. **Consumables scale with the body**: a band-N draught restores the same share of a band-N character that a band-1 draught
   restores of a one-star (30 essence per star held). Heals are written as shares of the bar or in wound-sink points that grow with health.
7. **Shortcuts still cost growth** [F: shortcut consumables stunt growth; B: approved in design/06]: every essence, reflux,
   painkilling, empowering or ascension consumable makes the delve teach less. Ordinary medicine (dressings, salves, regrowth,
   clotting) does not. Nothing refills the health bar in a fight.
8. **Crafting exists**: seven stations, six grades, 955 recipes. Raw remains and ores are refined into the band's metal, leather,
   wood and cloth; those make the band's gear. You craft yourself at a rented station; the fee is the station and, for Fine work,
   the master's time. Satellites, cursed items and uniques are never made [B: satellites are found or bought].
9. **Remains are materials**: a beast's hide is both something to sell and the leather of its band; a made thing's parts are a
   smith's masterwork piece. Sell or craft is a real choice.
10. **Alchemy**: 25 product lines across the bands - salves for wounds, regrowth, essence and cooling draughts, painkillers, tonics
    with a crash, tempering liniment, two tiers of ascension aid, soul and severing elixir placeholders, weapon coatings,
    throwables, Netherecho aids and food [C: alchemists, elixirs and tonics exist - `b5b` §3, `b5` §8].
11. **Skill consumables**: one empowering charge per affinity that bends that affinity's own rule (shove further, Heat higher,
    stone tougher, pips now, more marks), plus an ether sliver that pays a skill's cost - six grades each.
12. **The economy stays sane by one invariant**: nothing you can make sells for more than its inputs plus fee. That needs one
    rule change before alchemy goes live: **consumables and ammunition sell at half, like gear** (section 12.3).

---
## 2. What this changes in approved rulings

Brent's request of 2026-10-18 asks for a list that "scales in power and efficacy" to ten stars and beyond. Four approved
design/06 decisions stood in the way. Each change below is a proposal; each keeps the reason the old rule existed.

| Approved rule (source) | Change here | Why the reason still holds |
|---|---|---|
| "Nothing on gear scales with stars" (design/06 §2.1 rule 2) | Gear has bands; its main number rises 5% a band | It was there to keep gear below the body. Section 4.2 shows the body still wins by a wide margin at every band: one star ≈ five bands |
| "Consumables are few... keep the list at four" (design/06 §7.13, Q7 [B 2026-10-12]) | 181 consumables (145 alchemical, 36 skill consumables) | Superseded by the new request. Kept: no in-combat healing of the bar, growth cost on every shortcut [B], drugs keep their ordinary downsides [B] |
| "Smithing from materials is not designed; materials sell" (design/06 §8.5) | Seven stations and 955 recipes | Materials still sell at full value; crafting is a second use, never a money press (section 12.4) |
| Armour cap 30% (design/06 §5, `balance.json` gear.armour_cap) | Proposed: 30 + 2 per star above one (48 at ten stars) | Armour is a share of each hit, so it scales with enemies by itself; the cap only has to leave room for the 5% a band (section 4.1) |

Unchanged: twelve slots, the seven melee and five ranged families and their traits, the guard pool, the worn-weight rule, the
fixed (not rolled) catalogue, the rune vocabulary, the tolls, the band-1 numbers, Shift to shoot, and "no rank requirements".

---
## 3. The star ladder [MODEL, on B]

**Canon tops out lower than this game.** In the notes stars run to about six, a five-star rules the empire and no human is known
to be six [F: `bible` LAW 2]. Brent asked for ten and beyond [B 2026-10-18], so **bands 7-12 are wholly our invention**: the world
there is not designed, the constructs met there are guesses past the canon ladder, and the names are placeholders that describe a
mood (Still, Echoing, Heart-Sealed, First-Struck, Unwritten, Unmade). Within a star the setting also uses low / mid / high / peak
[C: `b5` §1]; the catalogue keeps one band per star and leaves the sub-bands to zones and enemies (Q16).

The factors are data (`items-full-v0.json` `bands` and `rules.factors`):

| Band | G gear | W weight | V value | Body health | Strike | Tanks | Satellite /s | Worn allowance kg | Trip income $ | Station grade | Metal | Leather | Wood | Cloth | Constructs met |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 1.00 | 1 | 1.00 | 1.00 | 1 | 1 | 14 | 5,000 | 1 | Iron | Cured Hide | Heartwood | Linen | vestige |
| 2 | 1.05 | 1.25 | 4 | 1.30 | 1.25 | 2 | 2 | 22 | 20,000 | 1 | Gatesteel | Reedback | Bog-Oak | Fen-Silk | remnant |
| 3 | 1.10 | 1.46 | 16 | 1.69 | 1.56 | 3 | 3 | 30 | 80,000 | 2 | Steeped Steel | Whiteback | Rimepine | Rime-Floss | remnant to spirit |
| 4 | 1.16 | 1.65 | 64 | 2.20 | 1.95 | 4 | 4 | 38 | 320,000 | 2 | Wardsilver | Stalker-Hide | Tawny Ash | Moth-Silk | spirit |
| 5 | 1.22 | 1.81 | 256 | 2.86 | 2.44 | 5 | 5 | 46 | 1.28 M | 3 | Veiniron | Drakeskin | Veinwood | Lantern-Silk | spirit to eidolon |
| 6 | 1.28 | 1.96 | 1,024 | 3.71 | 3.05 | 6 | 6 | 54 | 5.12 M | 3 | Duskmetal | Gloamhide | Gloamwood | Pale Fleece | eidolon |
| 7 | 1.34 | 2.10 | 4,096 | 4.83 | 3.81 | 7 | 7 | 62 | 20.5 M | 4 | Stillsteel | Wyrmhide | Stillwood | Still-Silk | eidolon to asura [?] |
| 8 | 1.41 | 2.24 | 16,384 | 6.28 | 4.77 | 8 | 8 | 70 | 81.9 M | 4 | Echo-Iron | Twinhide | Echo-Ash | Echo-Floss | asura [?] |
| 9 | 1.48 | 2.36 | 65,536 | 8.16 | 5.96 | 9 | 9 | 78 | 328 M | 5 | Heartmetal | Gianthide | Crownroot | Heartsilk | beyond asura [?] |
| 10 | 1.55 | 2.48 | 262,144 | 10.6 | 7.45 | 10 | 10 | 86 | 1.31 B | 5 | Firstmetal | Coilhide | Firstwood | Dawn-Floss | beyond asura [?] |
| 11 | 1.63 | 2.59 | 1.05 M | 13.8 | 9.31 | 11 | 11 | 94 | 5.24 B | 6 | Unwritten Alloy | Unwritten Hide | Unwritten Wood | Unwritten Cloth | unknown [?] |
| 12 | 1.71 | 2.70 | 4.19 M | 17.9 | 11.6 | 12 | 12 | 102 | 21.0 B | 6 | Unmade Metal | Unmade Hide | Unmade Wood | Unmade Cloth | unknown [?] |

Where the columns come from:
- **Body health ×1.3 a star**: the one ascension in the build (`balance.json` ascension_2.body_scale) carried on. **Strike ×1.25
  a star** is a proposal - the build does not raise strike damage at ascension yet. [MODEL]
- **Tanks**: each star is an independent 100-essence tank [B; `balance.json` stars.full_tank].
- **Satellite N essence a second at band N** [B: a two-star satellite supplies 2% a second].
- **Worn allowance** 14 kg + 8 kg a star (design/06 §2.1, approved).
- **Trip income**: what one ordinary trip out (a cleared dungeon or an evening of camps, carried home) should sell for. Band 1 is
  an estimate from today's numbers (remains $150-$1,500 each, a 38 kg pack, Tenwall's spoils) - **unmeasured**. ×4 a star after that.
  [C: money inflates absurdly with rank - catalogue items in the billions, `b5` §9]
- **Station grade** = half the band, rounded up. Grade 1 is Tithebarrow, grade 2 Winchgate (design/07); 3-6 are cities not designed.
- **Constructs met**: the threat parity of the fan sources [F: `bible` LAW 5] - vestige to peak 1★, remnant 2★, spirit to early
  4★, eidolon peak 4★, asura 5-6★ - stretched over twelve bands. Past six stars it is a guess [?].

---
## 4. What scales, and how [MODEL]

### 4.1 Per stat

`b` is the band; G, W, V, B, S are the factors in section 3. Band-1 numbers are design/06's; each band-N item is its band-1
line exemplar scaled like this (the code is `scale_stat` in the build script).

| What | Rule | Band 1 → band 10 example |
|---|---|---|
| Weapon strike or shot multiplier (`melee_damage_mult`, `ranged_damage_mult`) | × G | blade 1.40 → 2.17; maul 2.40 → 3.72; bow 1.50 → 2.33 |
| Flat shot damage (crossbows, flues - they ignore the body) | × S × G | gate crossbow 150 → 1,734 |
| Recovery, interval, reach, range, brace, pierce, vent per shot | unchanged - they are the family's identity | blade recovery ×1.00 at every band |
| Guard pool (`block`) | × B × G (it soaks enemy damage, which grows with the body it is aimed at) | plank shield 40 → 658 |
| `armour`, `wound_resist`, `poise`, leash, projection life | × G (one decimal) | plate cuirass armour 10 → 15.5, wound resist 12 → 18.6 |
| Small multipliers (reflux shed, cost, reflux gain, movement, wound mending, strike poise, tempering) | the part away from 1 × G | River Stone water cost ×0.90 → ×0.845; plate's shed ×0.92 → ×0.876 (it holds more heat too) |
| `carry_capacity`, `worn_allowance` | × W | Delver's Frame 75 kg → 186 kg |
| `max_health` tolls | × B | Leeching −8 → −8 × the band's health |
| `satellite_rate` | = the band | 1 → 10 essence a second |
| Item weight | × W | plate 16 kg → 39.5 kg |
| Value | × V, rounded to two figures | blade $480 → $130 M |
| Runes | the rune's part away from 1 × G, **never more than 10%** [C: artifacts carry one effect, usually ≤10% - `b5` §8] | Keen +5% → +7.8% |
| Consumable amounts | as the body: essence 30 × stars; wound sink 12 × B; heal as a share of the bar; venom damage × B × G | Bitter Draught 30 → 300 essence |

**Caps.** Every design/06 cap stays except two that would otherwise strangle the 5% a band: `armour_cap` 30 + 2 per star above
one, and the guard cap (100) × the band's body health. Proposed in `rules.caps_per_star`; Q8.

### 4.2 The check that gear stays below the body [B: gear matters less than the body]

| | One star, best band-1 kit | Ten stars, naked | Ten stars, band-10 Plain kit | One star wearing band-10 Plain |
|---|---|---|---|---|
| Strike with a sword | 60 × 1.40 = 84 | 60 × 7.45 = 447 | 447 × 2.17 = **971** | 60 × 2.17 = 130 (Loud: base number only) |
| Health | 100 | 1,060 | 1,060 | 100 |
| Medium kit armour | 12% | 0 | 18.6% | 18.6% |
| Worn weight (medium kit, sword, shield) | 16.4 kg of 14 allowed | - | 41 kg of 86 | 41 kg of 14: **30% slower** (the cap) |

The ten-star's own body is 5.3 times the band-1 strike; band-10 gear adds a factor of 1.55 on top. A one-star who somehow holds a
band-10 sword hits 55% harder than with its band-1 sword and walks like a mortal in the armour. Neither is a ladder you can skip.

### 4.3 The Loud rule (the one soft gate) [MODEL, from C]

[C: a powerful item outside a storage ring broadcasts to the whole neighbourhood - `b5b` §2; higher stars press on lower ones - `bible` LAW 2.]
An item whose band is **more than two above your stars** is Loud:
- its base numbers work (a sword is still a sword; a satellite still flows - Brent's satellite ruling is kept whole);
- its rune, effect line and toll are dormant ("the notebook says it will not answer you yet");
- enemies of the item's band notice you from half as far again.

A Hollow Band (storage ring, section 5.5) hides what is inside it, so Loud loot can be carried home quietly. The alternative - a
hard rank requirement - breaks "any rank can wear anything" [B]; having no gate at all lets one lucky drop skip a star's worth of
effects. Q5.

---
## 5. Rarity, runes, tolls, uniques, sets [MODEL, fitting design/06 §6]

### 5.1 Rarity and band are two different things

`band` is how strong the material and the making are; `rarity` is how well made and what is written on it. Every band has the same
rarity ladder, with design/06's meanings (`rarity` replaces design/06's numeric `tier`: 0 salvage, 1 plain, 2 fine, 3 runed, 4 cursed, plus unique):

| Rarity | What it adds | Where it comes from | Count |
|---|---|---|---|
| Salvage | 8% under Plain, often heavier | Band 1 only (what invaders carried) | 22 |
| Plain | The line's baseline | Shop, drops, crafting at any station grade of its band | 404 |
| Fine | The line's better form (Dirk, Sword, Recurve, Harness...) | Drops, the shop's rotating shelf, crafting with a masterwork piece and stars ≥ band | 265 |
| Runed | A Fine item plus one rune (≤10%) | Drops; the runesetter writes one onto your own Fine item | 51 |
| Cursed | One stronger effect and a visible **toll** | Commanders, deviants; never sold in a shop, never crafted | 24 |
| Unique | Bends one rule, **grows** with a stated condition, plateaus [C: uniques grow, with diminishing returns - `b5` §8] | Deviants, feats, auctions | 19 |

Every line exists at every band 1-10 (46 weapon, shield, armour, pack and belt lines, plus charms, talismans, coils, threads and satellites). Bands 11-12 carry 16 of the 46, the five charms and a satellite, plus their cursed and unique items.

### 5.2 Runes

The design/06 rune table is kept word for word (22 runes; `rules.runes` in the draft). Three runed items are catalogued per band
2-10 (a weapon, a ranged weapon, a body armour), rotating through the runes that fit; any other combination is the runesetter's
job once items have instances (design/06 Q8). A rune's strength is its band-1 value with the part away from 1 times G, never past
10% [C]; flat runes (Stubborn, Warded) take × G. Writing one fails 10% of the time (design/06 §8.5).

### 5.3 Cursed items (12 new; the toll vocabulary is design/06's)

| Band | Item | Slot | What it does | Toll |
|---|---|---|---|---|
| 2 | Toll-Pike | polearm | Longest reach of its band; tip bonus doubled | Reluctant |
| 3 | Frostbitten Brigandine | body | +10 wound resistance over its kind | Slow Mending |
| 4 | The Second Mouth | trinket | Every ability +12%, any affinity | Thirsty |
| 5 | Gutter Star | satellite | 7 essence a second from a five-star stone | Running Hot |
| 5 | Grasping Gauntlets | hands | Base strikes break poise a fifth faster | Reluctant |
| 6 | Widow's Draw | bow | Shots +18% over its band | Turned Back |
| 7 | Unmooring Shoes | feet | A tenth faster on your feet | Leeching |
| 8 | Choir Crown | head | Reflux pain starts 10 points later | Thin Soul |
| 9 | Debt Wall | shield | Guard 60% deeper than its band | Heavy |
| 10 | Last Word | greatsword | Strikes 8% harder than its band | Safe Hands |
| 11 | Unwritten Name | trinket | Every ability costs 15% less | Leeching |
| 12 | Unmade Coat | body | +3 armour, +4 wound resistance over its band | Safe Hands |

### 5.4 Uniques (11 new; each needs an effect script, design/06 §6.4)

| Band | Unique | Slot | The rule it bends | Grows with |
|---|---|---|---|---|
| 2 | Tallyman's Thumb | trinket | Remains you pick up weigh 15% less (to 30%) | Kilograms of remains sold |
| 3 | The Patient Spear | polearm | Standing still charges your next base strike, +5% a half second to +50% (to 80%) | Kills made from standing still |
| 4 | Borrowing Star | satellite | No flow of its own; each kill lends 4 essence a second for 5 s, loans stack to five (to 8/s) | Kills made with three loans running |
| 5 | Drake's Second Skin | body | Once a minute a wounding hit is taken by the coat, which then weighs 2 kg more until you sleep (to every 30 s) | Wounds refused |
| 6 | Choir Pipe | flue | Vents every affinity at once; +40% per affinity above 50 (to 60%) | Minutes above 80 without a lock |
| 7 | The Still Mask | head | After 2 s standing, archers and casters lose their aim on you (to 1 s) | Shots that lost you |
| 8 | Echo Coin | trinket | Every tenth base strike lands twice, the echo at half (to every seventh, 70%) | Strikes echoed |
| 9 | Heartmetal Tithe | sword | A base strike also takes 1% of what the target has left, capped at the strike (to 2%) | Deviants killed |
| 10 | First Word | focus | The first skill of each fight costs nothing and leaves no reflux (to the first two) | Fights opened that way and won |
| 11 | Unwritten Page | trinket | Copies your other trinket's stats at half strength (to full) | Different trinkets worn beside it |
| 12 | The Unmade Thing | maul | Takes the family of the last weapon you held; its numbers are that family's at band 12 | Families mastered |

### 5.5 Placeholders for parked canon systems

- **Sets** [C: three items fused with a binding gem; a superior gem binds four; a factory gem is ≤90% and needs a master artificer -
  `b5` §8]: three placeholders, the **Lesser Concord Stone** (band 5), **Concord Stone** (8) and **Greater Concord Stone** (11, binds four),
  priced at 50 trips of their band. Not craftable. Sets stay parked.
- **Storage rings** [C: rings used by sinking attention, items stowed deep, aura fully masked - `b5b` §2; B: a new character has a
  backpack, not a ring]: four **Hollow Bands** (bands 4, 6, 8, 10) that take the back slot, hold 1.5 times the band's frame, weigh
  nothing and hide Loud items. Priced at eight trips. Category `storage`. Q10.

---
## 6. Materials [MODEL]

### 6.1 The ladder

Per band (2-12) the draft has: an **ore** and a **log** (raw: veins, resource caches [C: a resource cache lets ore or lumber be
carried out every reset - `b5` §6], felling), a **bar**, **wire**, **leather**, a **stave**, a **bolt of cloth**, an **ether salt**,
a **rune ink**, four **flora** (knit, bitter, cold, and a cache fruit), and five **remains** (section 10). Every odd band adds a
new grade of **settled ether** for each affinity. Band 1 uses design/06's materials (scrap iron, steel billet, binding wire, cured
hide, heartwood stave, flux salt, rune ink) plus a Flax Bundle, a Linen Bolt, Lockweed (the Drowned Lock's cache, design/07 §5.5),
the Barrow Sloe and five Flecked stones.

| Class | Raw → refined | Goes into |
|---|---|---|
| Metal | 2 ore → 1 bar → 4 wire | Weapons (not bows, slings), heavy armour, bucklers and heater shields, flues, charms, coils, ammunition |
| Leather | 1 hide (the band's beast "A" remains) → 4 leather | Medium armour, frames, belts, grips |
| Wood | 1 log → 2 staves | Bows, crossbows, spear and javelin shafts, round shields, ammunition |
| Cloth | 1 fibre (the band's beast "C" remains) → 4 bolts | Light armour, slings, dressings, thread |
| Masterwork | the band's bone/horn ("B") or made-thing parts ("M") remains, used whole | One per Fine item: parts for metal work, bone for wood, leather and cloth |
| Essence-bearing | ether salt (any band); settled ether per affinity (grades at bands 1, 3, 5, 7, 9, 11) | Flux, alchemy, rune ink, sumps and tablets; charms, talismans, skill charges |

**Settled ether** [MODEL; ?]: ether that pooled in rich ground and set hard, taking its affinity - Brinepearl (water), Emberite (fire),
Loamstone (earth), Galequill (wind), Fulgurite (lightning) - in six grades: Flecked, Clouded, Clear, Bright, Singing, Unblemished.
Canon has ether that becomes like what it touches [C: `intro`; `bible` LAW 1] and solid, aura-bearing things (minted aura coins,
crystallised miasma) [C: `b5` §4, §8], but not this material; it is ours. It is gathered in the real world at ether-rich sites,
**never looted from the Netherecho**, which still gives nothing you can carry [B: constructs are subdued, not looted; design/06 §8.6].

### 6.2 "Construct parts"

The request lists construct parts. Brent ruled that ether constructs are subdued, never looted [B 2026-09-23], so the draft reads
the word as **parts of made things**: the guardians and engines of realms (Toll-Effigy, Cairn Warden, Spindle Sentinel, Iron
Sexton, Mirror Knight, Quiet Colossus, Echo Engine, Throne Warden, Unsleeping Engine). Their remains are the smith's masterwork
piece of their band. Whether such made things exist in the books is unknown [?] - anomalous realms conjure their inhabitants
[C: `b5` §6], which fits. Q9.

---
## 7. Crafting [MODEL]

### 7.1 Who crafts, where

**You do, at a rented station.** The fee pays for the station, and for Fine work the master who stands over you. The setting
counts crafting among the hardships that build a star [F: latent aura from crafting - `bible` LAW 2], which is the reason to make
the player the crafter rather than a menu that takes money; a first guess is that a recipe at or above your band teaches a little,
like a fight a little below your star (Q6). A recipe states:

| Field | Meaning |
|---|---|
| `station` | camp, forge, leatherworks, bowyer (bowyer-fletcher), loom, alchemist, runesetter (`recipes-v0.json` `stations`) |
| `grade` | The station grade needed: half the band rounded up (camp is 0: anywhere you can sit) |
| `stars` | The stars you need to work the materials yourself: band − 1 for refining, Plain gear and alchemy; the band itself for Fine and Runed work. Settled and steeped materials "only yield to an essence close to their own" |
| `inputs` | Item id → count. Every input exists (the validator checks) |
| `fee` | Dollars |
| `makes` | How many come out |
| `hours` | World-clock hours (a day is 90 real minutes [B]) |

Recipes per station: forge 296, alchemist 189, runesetter 170, bowyer 114, leatherworks 94, loom 76, camp 16.

### 7.2 The arithmetic (so crafting is worth doing and never prints money)

| Output | Inputs | Fee | Result |
|---|---|---|---|
| Gear | The line's shape (e.g. a blade: bars + wire; a Fine sword adds a made-thing part). The primary input is scaled so inputs come to about 45% of the item's value | Whatever brings inputs + fee to **75%** of the value (never less than 10%) | Making it costs three-quarters of buying it; selling it returns half. A saving to use, a loss to sell |
| Refined material | Raw | 5-15% of inputs | Worth 95% of inputs + fee: refining to sell is a small loss |
| Alchemy, ammunition | Flora, salt, bone, cloth... | 20% of inputs | Worth 125% of inputs + fee at the shop; under the proposed sell rule it sells for 62.5%: a saving to use, a loss to sell |
| Runed item | The Fine item + one rune ink of its band | **60% of the value the rune adds** | Always cheaper than buying the runed item, never profitable to sell |

Example, band 2: **Gatesteel Blade** ($1,900): 2 Gatesteel Bars ($390 each) + 1 Gatesteel Wire ($100) + $545 at a grade-1 forge, one star,
two hours. **Gatesteel Sword** (Fine, $7,600): 5 bars, 1 wire, 1 Toll-Effigy Ironwork + $2,450, two stars, four hours.

### 7.3 Never crafted

Satellites [B: found or bought], cursed items and uniques (they come from deviants and feats), true ascension elixirs, soul and
severing elixirs (clinics and auctions), spirit imprints, Concord Stones, Hollow Bands, keys, and remains (obviously). Band-1
Salvage gear is not made either.

---
## 8. Alchemy [MODEL, on C and B]

[C: alchemists are a profession; elixir makers use dungeon-grown ingredients; tonics and steroids exist - `b5` §8, `b5b` §3.
B: drugs have ordinary downsides; archhumans can abuse far more than mortals. F, B approved: shortcuts cost growth.]

**Principles**, kept from design/06: nothing refills the health bar during a fight; every shortcut (essence, reflux, pain,
empowering, ascension) carries an `aura_penalty` - the rest of that delve teaches that much less, shown only as "the star feels
lighter"; ordinary medicine carries none. **Proposed stacking**: penalties multiply within a delve and never take more than half
(Q12). Reagents: four flora per band (knit, bitter, cold, fruit) plus the band's ether salt, bone and cloth.

| Line | Bands | What it does (band 1 → top) | Growth cost |
|---|---|---|---|
| Field Dressing → Poultice | 1; 2-12 | Out of a fight: 15 health over 8 s (dressing); a poultice returns 20-31% of the bar over 10 s and speeds natural healing 1.5× for five minutes | none |
| Knitting Salve | 1-12 | Fills 12 × body-health points of your oldest wound's hidden sink (12 → 127 at band 10) | none |
| Regrowth Draught | 1, 4, 7, 10 | Regrows a lost arm overnight (the healer's job, $1,200 today) | none |
| Clotting Powder | 2, 4, 6, 8, 10 | In a fight: stops bleeding; the next wound is a quarter shallower | none |
| Bitter Draught line | 1-12 | 30 essence × the band, leaves 15 reflux on every affinity | 10% |
| Cooling Paste line | 1-12 | Takes 30 → 60 reflux off the hottest affinity; from band 6, off every affinity | 10% |
| Numbing Salt line | 1, 3, 5, 7, 9, 11 | 60 → 110 s of wounds costing nothing, then each a tenth deeper | 10% |
| Iron Tonic | 1, 3, 5, 7, 9 | Strikes +10% → +18% for 2 min, then −10% for 2 min | 10% |
| Steadying Tonic | 2, 4, 6, 8, 10 | +25 → +45 poise for 2 min, then −25 for 1 min | 10% |
| Yard Liniment | 1, 2, 4, 6, 8, 10 | The next tempering session's strain ×0.7, its progress ×0.9 [C: clinics sell tempering aid - `b5` §4] | its own price |
| Pale Tincture (ascension aid) | 1-10 | Blank growth: 8% of the star's threshold; −5% ascension quality and one point of talent wear each; at most five a star [C: ordinary aids inject blank aura and overuse can degrade a talent - `b5b` §3] | the aid is the cost |
| Unbroken Seed / Root / Crown (true elixir) | 3, 6, 9 | Placeholder: fills half the threshold and improves the ascension [C: a rare true elixir also amplifies the evolution]. 100 trips; auction or feat only | - |
| Blank Draught (soul elixir) | 2, 5, 8 | Placeholder: patches soul damage with blank tissue; large patches slowly change who you are [C: soul elixirs - `b5` §5]. Clinic only | - |
| Root-Cut Elixir (severing) | 5 | Placeholder: removes every star and the path you climbed by [C: severing elixirs exist; severed powerhouses are a known type - `b5` §1, `b5b` §4] | - |
| Bleeding Oil | 1, 3, 5, 7, 9, 11 | Coats a weapon: 20 → 30 base strikes add a bleeding stack | none |
| Sap Venom | 2, 4, ..., 12 | Coats a weapon: 15 strikes poison for 6 × B × G a second for 5 s; pays the talent like any harm you caused [B: DoTs pay] | none |
| Lead Lacquer | 1, 4, 7, 10 | Coats a weapon: 20 strikes break poise 1.5× | none |
| Smoke Pot / Caltrops / Flash Powder | 1, 4, 7, 10 / 2, 5, 8 / 3, 6, 9 | Thrown: blocks shots for 4-8 s / slows walkers 40% / breaks every wind-up within 4 m | none |
| Tether Incense / Second-Skin Wax | 1, 3, 5, 7, 9 / 2, 4, 6, 8, 10 | Next projection: leash +3 → +7 m / life +3 → +7 | none |
| Binding Salts | 1, 3, 5, 7, 9, 11 | Next construct binding +5% to hold (`balance.json` binding.success_chance 0.8) | none |
| Trail Ration | 1, 4, 7, 10 | Natural healing a quarter faster for an hour of the clock [C: food pills exist - `b5` §8] | none |
| Short-Night Pill | 3, 6, 9 | Placeholder: a night's rest in an hour [C: sleep-compression pills exist] | - |

Two things are flagged for the programmer: `venom` is a new status (`statuses.json` has none), and "talent wear" is a new hidden
counter with no effect designed yet (Q14).

---
## 9. Skill consumables and ammunition [MODEL]

### 9.1 Learned, not drunk

- **Skill scrolls**: the 20 live scrolls (band 1, $1,200, kind `scroll`, `teaches` an ability id - all checked against
  `abilities.json`). New skills will come as new scrolls; no ability exists to teach past the starter sets, so none is invented here.
- **Tempering manuals**: the 12 techniques design/05 §5 proposes (Hard Knit ... Scorched Channels), $2,500, kind `manual`,
  `teaches_technique`. None is in `tempering.json` yet (the validator lists them as warnings).
- **Spirit imprints** (bands 4, 6, 8, 10; placeholders): spirit abilities are spoken aloud, always carry a price, slow the next star,
  and are bought and sold [C: `b5` §4; F, B: 33% compression each]. How one is acquired is unknown [?]; an imprint is a guess.
  Each has an original effect and its price (The Long Count, Bargain Struck, Toll Bell, Unwitnessed). 20 trips each.

### 9.2 Charges that bend an affinity's own rule (design/05 §2)

One per affinity at each settled-ether grade (bands 1, 3, 5, 7, 9, 11): made of that grade's stone and an ether salt, usable only
by a character who holds the affinity, **5% growth cost** each.

| Affinity | Charge | Band 1 → band 11 |
|---|---|---|
| Water (Shove and Crush) | Brine Charge | Next three water skills shove 30% → 80% further |
| Fire (Heat) | Pitch Wick | For 10 s, Heat counts 20 → 45 reflux higher, without the reflux |
| Earth (Standing stone) | Mason's Grit | Next two stones: 50% → 100% more life, stand 1.5× as long |
| Wind (Slipstream) | Gale Quill | 4 → 9 pips at once |
| Lightning (Live marks) | Charged Filament | Next three lightning hits leave 2 marks (3 from band 7) |
| any | Ether Sliver | Pays your next skill's essence cost, up to 12 × the band; the reflux is still yours |

### 9.3 Ammunition

Design/06 §3.2 is kept: slings throw stones for free, thrown weapons have a per-fight brace, bows and crossbows use bundles that
weigh something and partly come back. Per band 2-12: Tipped Arrows (20), Bolts (12) and Shot (30), each +2% damage a band
(`ammo_damage_mult` 1.02 → 1.22) - the bow's own multiplier carries the band; ammunition is a hauling cost, not a second ladder.
Specials at bands 1, 4, 7, 10: Barbed Arrows (bleeding; never recovered), **Bodkins** (front armour and shields count half) and
**Blunt Bolts** (+30 poise damage; nearly all recovered).

---
## 10. Remains, trade goods, spoils, catalysts [MODEL]

Kills pay remains; the passage exit pays spoils; money only comes from selling [B 2026-10-18]. Every band has five remains roles,
each priced from today's band-1 remains: **A** a hide (8 kg, $500 → the band's leather), **B** bone, horn or fang (2 kg, $250 →
masterwork for wood, leather, cloth), **C** fibre (1 kg, $200 → the band's cloth), **M** a made thing's parts (3 kg, $300 → smith's
masterwork), **E** an elite's trophy (2 kg, $1,500, only for selling). Weights × W, values × V.

| Band | A (hide) | B (bone) | C (fibre) | M (made thing) | E (trophy) |
|---|---|---|---|---|---|
| 1 | Brute Hide 8 kg $500; Thornback Hide 25 kg $900 | Thornback Horn, Sod-Lurker Jaw | Harrier Pelt | Pavise Boss | Commander's Sigil $1,500 |
| 2 | Reedback Hide 10 kg $2,000 | Ridge Ram Horn | Spinner Silk Skein | Toll-Effigy Ironwork | Fen Reeve's Chain $6,000 |
| 3 | Whiteback Pelt | Glass Elk Antler | Rime Floss Tuft | Cairn Warden Rivets | Gate Marshal's Brand |
| 4 | Tawny Stalker Hide | Step-Hound Fang | Spindle Moth Cocoon | Sentinel Clockwork | Collector's Seal |
| 5 | Vein Drake Hide | Borer Tooth | Lantern Weaver Silk | Sexton Bell-Metal | Drake Matron's Crest |
| 6 | Gloam Stag Hide | Duskwing Bone | Pale Shearling Fleece | Mirror Knight Plate | Lamplighter's Lantern |
| 7 | Mantle Wyrm Hide | Hush Cat Claw | Still Spider Silk | Quiet Colossus Joint | Choir Mother's Bell |
| 8 | Twinned Elk Hide | Echo Hound Fang | Echo Moth Floss | Echo Engine Escapement | Counterpart's Mask |
| 9 | Crag Giant Hide | Sky Ray Spine | Heartsilk Cocoon | Throne Warden Heartplate | Crag Matriarch's Torc |
| 10 | Deepcoil Serpent Hide 20 kg $130 M | Firstbone | Dawn Moth Floss | Unsleeping Cog | Tithe-Taker's Scale $390 M |
| 11 | Unwritten Beast's Hide | Unwritten Bone | Unwritten Thread | Unwritten Cog | Blank Herald's Seal |
| 12 | Hide of an Unmade Thing | Unmade Bone | Unmade Thread | Unmade Gear | Last Creditor's Ledger $6.3 B |

The band-1 row keeps the eight live remains (`enemies.json` `remains`, values as live) and adds the three kinds design/07 §5.4
proposes (Gleaner's Hoard, Sod-Lurker Jaw, the Thornback's hide and horn - a carcass more than a starting pack holds, as 07 wants).
The bestiary for bands 2-12 is a set of names waiting for enemy designs; nothing in `enemies.json` refers to them.

Also in this section of the data: **proofs** of design/07's eight named deviants and bosses (Old Ha'penny's Purse ... the
Muster-Captain's Standard, $1,200-$4,000, bought by the Collection Office); **spoils** per band (Strongbox, Relic Case, Salvage
at $2,000 / $500 / $100 × V, the live three kept); **catalysts** per band [C: blood-soaked objects from passage slaughter are tied to
rare constructs - `intro` §4] raising the chance of that band's construct tier (the two design/06 ones kept). Ten design/06 trade
goods stay at band 1 (Cracked Mask, Drum Skin and others); some now duplicate live remains (Q15).

---
## 11. Keys and quest items (placeholders)

Value 0, `sellable: false`, `placeholder: true`. Band 1: the Counting-House Vault Key (the Auditor's chest, design/07 §5.5), the
Sluice-Wheel Handle (Drowned Lock), the Muster Pass, Registry Papers [C: registration is a slog - `intro` §2] and a Sealed Letter
(courier work). Bands 2-12: a **Passage Writ** each - entry to an owned passage of that band [B: owned passages charge]. They are
left out of the value checks.

---
## 12. Economy: why it stays sane [MODEL]

### 12.1 Income and prices per band

Measured from the draft (`trip` = the reference income of section 3):

| Band | Trip | Remains $/kg (mean) | Plain at-band kit* | Fine at-band kit** | Satellite | Draught | Salve |
|---|---|---|---|---|---|---|---|
| 1 | $5,000 | 190 | 0.72 trip | 0.98 trip | 0.48 trip | 0.05 | 0.07 |
| 2 | $20,000 | 786 | 0.72 | 0.97 | 0.47 | 0.06 | 0.05 |
| 5 | $1.28 M | 34,978 | 0.72 | 0.98 | 0.48 | 0.05 | 0.05 |
| 10 | $1.31 B | 25.8 M | 0.72 | 0.98 | 0.48 | 0.05 | 0.05 |

\* sword, medium head/body/hands/feet, frame, belt. \*\* the same with a Fine sword and a Fine brigandine.

Because every price and every sell value moves by the same ×4, **the ratios hold at every band**: a new star's Plain kit costs
about three-quarters of a trip, its Fine kit about one trip, its satellite half a trip, a shortcut consumable a twentieth. If a
star takes 20-40 trips (two hours for the second star [B]; later stars longer, Q2), gear is a few trips of each star and the rest
is for sinks.

### 12.2 Sinks that must scale with it (today they do not)

Rent ($150), the healer ($60 a sink point), arm regrowth ($1,200), tickets ($300), carriage ($40 a line) and the corpse fee
($250 × stars) are flat in `balance.json`. At ten stars they round to nothing. Proposal: each is priced in its band's money -
rent and tickets × V of the district or passage's band; the healer's price per sink point × (4 / 1.3)^(stars − 1) because sinks
grow with the body while money grows four times; the corpse fee × V (Brent ruled a flat fee "that may scale with level"). Q3.

### 12.3 The sell rule needs one change

Today `inventory.gd` sells anything with no slot at **full** value (only scrolls are excepted). Every alchemical consumable and
every bundle of ammunition has no slot, so under today's rule 222 of the 955 recipes would make money from nothing (the
validator lists them). Proposed `rules.sell_factor_by_kind`: gear, consumables, ammunition, scrolls, manuals, imprints and binding
stones at **half**; materials, reagents, remains, trade goods, proofs, spoils and catalysts at full; keys and quest items not sold.
"Made goods sell at half, raw goods at full" is easy to explain in the Tallyman's voice. **This must land before any recipe does.**

### 12.4 The invariants the validator enforces

1. **No money from nothing**: for every recipe, output sale × makes ≤ inputs' sale + fee (proposed sell rule). 0 violations.
2. **Values rise with band** inside every category (median) and along every line (each step). 0 violations.
3. **Every input exists**, no recipe uses itself, no recipe cycle.
4. Crafting gear costs less than buying it (warning only; 0 left).

### 12.5 Why low-band loot stops mattering, and why that is fine

A ten-star could farm the Stubble, but its remains are worth 1/262,144 of a ten-star's per kilogram, and the pack has the same room.
Growth there is near zero too [C: latent aura only from real risk]. Nothing needs a level filter: dollars per kilogram does it.

---
## 13. Schema: the fields this draft adds

Everything in `game/data/items.json` is kept as it is (`name`, `slot`, `weight`, `value`, `stats`, `desc`, `kind`, `teaches`,
`rank`). Slots are the live twelve (`offhand`, not design/06's `off_hand`; `trinket2` takes `trinket` items). The design/06 draft
fields are kept: `family`, `class`, `two_handed`, `needs_both_arms`, `rune`, `base`, `toll`, `effect`, `effect_text`, `grows`,
`use`, `ammo_kind`, `count`, `recover`, `ammo_damage_mult`, `on_hit`, `catalyst`. New:

| Field | On | Meaning | Read by the game today? |
|---|---|---|---|
| `kind` | all | gear, scroll, manual, spirit_imprint, consumable, ammo, material, reagent, remains, trade, proof, spoils, catalyst, key, quest, binding | `scroll` only |
| `category` | all | Catalogue group (melee, ranged, offhand, head, body, hands, feet, back, belt, satellite, trinket, storage, ammo, consumable, skill_consumable, scroll, manual, material, raw, settled_ether, reagent, remains, trade, proof, spoils, catalyst, binding, key, quest). For the shop filter, the pack filter and the validator | no |
| `band` | all | 1-12: the star the item is made for (section 3) | no |
| `rarity` | gear | salvage, plain, fine, runed, cursed, unique (replaces design/06's numeric `tier`) | no |
| `stack` | all | How many share one pack entry once the pack stacks; weight is per unit. Today the pack holds one id per entry | no |
| `line` | most | The same thing at every band (e.g. `blade_p`, `essence_draught`). The validator checks value rises along it | no |
| `material` | made gear | The band material it is made of | no |
| `look` | wearables | The `wardrobe.json` piece it can borrow until it has its own (live ids keep their real mapping; 13 live items have real looks) | no (wardrobe.json is) |
| `source` | all | Where it comes from: shop, shop_rotation, drop, deviant, feat, craft, exit, cache, gather, auction, clinic, quest | no |
| `recipe` | craftables | `{station, grade, stars, inputs{id: n}, fee, makes, hours, note?}` (section 7.1) | no |
| `role` | remains, reagents | hide, bone, fibre, made, trophy; knit, bitter, cold, fruit | no |
| `affinity` | affinity items | The affinity a charm, talisman, charge, manual or stone belongs to | no |
| `teaches_technique` | manuals | A tempering technique id | no |
| `placeholder` | parked items | True: an item whose system does not exist (true elixirs, soul and severing elixirs, imprints, Concord Stones, keys, short-night pills) | no |
| `sellable` | keys, quest | False: the merchant will not take it | no |
| `aura_compression`, `binds` | imprints, Concord Stones | 0.33 per spirit ability [B]; items a stone fuses | no |
| Top level `bands` | file | The factors of section 3, per band | no |
| Top level `rules` | file | `factors`, `sell_factor_by_kind`, `loud`, `caps_per_star`, `rune_cap`, `crafting`, and design/06's `tolls`, `runes`, `families` | no |

New stat keys beyond design/06 §5: `ability_damage_mult` and `cost_mult` without an affinity (two cursed items), `tip_bonus_add`,
`rear_taken_mult`, `regen_mult`, `aura_gain_mult`, `satellite_reflux_mult`, `reflux_pain_shift` (all already named in design/06 §5).
New `use` effects: poultice, mend_wound, regrow_arm, clot, tonic, temper_aid, blank_aura, true_ascension, soul_patch, sever_path,
coat, throw, nether, bind_aid, food, short_night, empower, pay_cost (plus design/06's dressing, essence, shed_reflux, ignore_wounds).

---
## 14. Counts (validator output, 2026-10-18)

`python tools/items/validate_items.py` - **RESULT: PASS**, 0 errors, 234 warnings (222 are the live-sell-rule arbitrage of 12.3,
12 are the tempering techniques not yet in `tempering.json`).

```
1390 items, 955 recipes, 785 pieces of gear

Counts per category per band
category             1    2    3    4    5    6    7    8    9   10   11   12  total
ammo                 6    3    3    6    3    3    6    3    3    6    3    3     48
back                 6    1    1    1    1    1    1    1    1    1    .    .     15
belt                 5    1    1    1    1    1    1    1    1    1    .    .     14
binding              .    .    .    .    1    .    .    1    .    .    1    .      3
body                14    7    8    7    8    7    7    7    7    7    3    4     86
catalyst             2    1    1    1    1    1    1    1    1    1    1    1     13
consumable          15   12   13   14   13   13   14   12   13   14    7    5    145
feet                11    3    3    3    3    3    4    3    3    3    .    .     39
hands               10    3    3    3    4    3    3    3    3    3    .    .     38
head                12    3    3    3    3    3    4    4    3    3    1    1     43
key                  3    1    1    1    1    1    1    1    1    1    1    1     14
manual              12    .    .    .    .    .    .    .    .    .    .    .     12
material             7    6    6    6    6    6    6    6    6    6    6    6     73
melee               38   16   16   15   15   15   15   15   16   16    7    8    192
offhand             12    5    5    5    5    5    5    5    6    6    .    .     59
proof                8    .    .    .    .    .    .    .    .    .    .    .      8
quest                2    .    .    .    .    .    .    .    .    .    .    .      2
ranged              22   11   11   11   11   13   11   11   11   11    5    5    133
raw                  2    2    2    2    2    2    2    2    2    2    2    2     24
reagent              4    4    4    4    4    4    4    4    4    4    4    4     48
remains             12    5    5    5    5    5    5    5    5    5    5    5     67
satellite            3    2    1    2    2    1    1    1    1    1    1    1     17
scroll              20    .    .    1    .    1    .    1    .    1    .    .     24
settled_ether        6    1    6    1    6    1    6    1    6    1    6    1     42
skill_consumable     6    .    6    .    6    .    6    .    6    .    6    .     36
spoils               3    3    3    3    3    3    3    3    3    3    3    3     36
storage              .    .    .    1    .    1    .    1    .    1    .    .      4
trade               10    .    .    .    .    .    .    .    .    .    .    .     10
trinket             22   13   12   13   12   12   12   13   12   12    7    5    145
ALL                273  103  114  109  116  105  118  105  114  109   69   55   1390

Value per band (dollars; keys and quest items left out)
band  items              min           median                max
   1    268                5              825             45,000
   2    102              100            2,100             60,000
   3    113              420            6,700          8,000,000
   4    108            1,600           32,000          6,400,000
   5    115            6,800          120,000         64,000,000
   6    104           26,000          530,000        510,000,000
   7    117          100,000        1,400,000         20,000,000
   8    104          420,000        9,750,000      4,100,000,000
   9    113        1,600,000       28,000,000     33,000,000,000
  10    108        6,800,000      130,000,000     26,000,000,000
  11     68       26,000,000      260,000,000    260,000,000,000
  12     54      110,000,000    1,250,000,000     35,000,000,000

Gear by rarity: salvage 22, plain 404, fine 265, runed 51, cursed 24, unique 19
```

The maxima are the placeholders priced at many trips (true elixirs, Concord Stones, uniques).

---
## 15. Wiring it later (not done; other sessions own the game code)

Bring it over step by step, as design/06 asked of items-v2 - "do not put a stat on a live item until the game reads it":
1. The sell rule (12.3), before any recipe. 2. `band`, `rarity`, `category` read by the shop and pack filters (design/06 §9).
3. Band-aware drop tables and spoils: `main.grant_spoils` reads one `spoils` list today; it would pick by the passage's band.
4. A stacking pack (`stack`), then the crafting screen (`recipe`), then `use` effects one at a time, starting with the ones that
already have a number in the game (essence, reflux, wound sink). 5. Stars past two (`player.try_ascend` stops at two;
`ascension_2` is the only ascension block), and the per-star body curve of section 3. 6. Loud, caps per star, scaled sinks.

---
## 16. Open questions for Brent

Each has my recommendation. "Go with your recommendations" approves all of them.

1. **Gear in bands, +5% a band, one star ≈ five bands?** *Recommend:* yes - it is the smallest scaling that makes a new star's gear
   worth fetching, and section 4.2 shows the body still dominates.
2. **Ten stars and beyond.** Canon stops near six. *Recommend:* invent 7-12 as placeholders now (as here) and design them only when
   the game reaches five stars; keep 11-12 thin. Also: how long should later stars take? (Second star ≈ two hours [B].) A first guess
   of +50% per star puts ten stars near 150 hours.
3. **Money ×4 a star, billions by nine stars** (canon-like late wealth). And **sinks priced by band** (rent, healer, tickets,
   carriage, corpse fee). *Recommend:* yes to both.
4. **Made goods sell at half** (consumables and ammunition join gear). *Recommend:* yes, and before any recipe goes live.
5. **The Loud rule** as the only gate on far-above-your-star gear. *Recommend:* yes. Alternatives: no gate, or rank requirements.
6. **The player crafts at a rented station**, and crafting at or above your band teaches a little [F]. *Recommend:* yes to the first;
   the second only after growth from fights has been played.
7. **Weight grows with band** (×2.5 by ten stars), so heavy gear stays a choice. *Recommend:* yes.
8. **Armour cap 30 + 2 per star; guard cap × body health.** *Recommend:* yes.
9. **"Construct parts" = parts of made things**, because constructs are never looted [B]. *Recommend:* yes.
10. **Storage rings (Hollow Bands) from four stars, in the back slot**, at eight trips. *Recommend:* yes; they are a wealth marker in
    canon and they make Loud loot safe to carry.
11. **Remains double as materials** (sell the hide, or tan it). *Recommend:* yes.
12. **Shortcut penalties stack** multiplicatively in a delve, floor one half; many more consumables now exist. *Recommend:* yes.
13. **Appraisal** [C: appraisal is slow and costly] - unidentified high-band items? Not in this draft. *Recommend:* leave out.
14. **Ascension aids** with talent wear and lower ascension quality, at most five a star. *Recommend:* yes, and decide what wear
    does when talents evolve past two stars.
15. **Band-1 duplicates**: design/06's Cracked Mask, Drum Skin and Censer Ash-as-material overlap the live remains
    (Skirmisher's Mask, War Drumhead, Censer Ash). *Recommend:* drop the three design/06 entries when band 1 goes live.
16. **One band per star**, not low / mid / high / peak sub-bands. *Recommend:* yes for items; zones keep the sub-bands.

---
## 17. Lore I was unsure of [?]

- **Anything past six stars** (bands 7-12): canon tops out near six [F]; all of it is [MODEL] on Brent's request.
- **Constructs past asura**: the tiers stop at asura in the notes [F]; "beyond asura" and "unknown" are placeholders.
- **Settled ether as a material** and **made things with parts**: plausible in the setting (ether shifts; realms conjure their
  inhabitants) but not in the notes.
- **How spirit abilities are acquired** is not in the notes; the "imprint" item is a guess. Canon says they are bought and sold [C].
- **Whether a satellite can be made**: Brent ruled they are found or bought [B]; I read that as "never crafted".
- **Ascension aids at every star**: canon names two tiers [C] but not a per-star ladder; the Pale Tincture line is ours.
- **Whether storage rings are within reach of a four-star**: canon shows them as everyday for the wealthy [C]; the price is a guess.
- **The ×4 money curve** against canon prices (a mid two-star dungeon pays $3-6 M per clear [C: `b5` §9]): the game has been far
  below canon from its first number ($10,000 starting money, $150 rent), so I followed the game, not the books.

---
## 18. What was and was not checked

- **Checked** (by `tools/items/validate_items.py`, run 2026-10-18): unique ids and names; required fields; every slot a known slot;
  every recipe input exists; no recipe cycles; the recipes file agrees with the items; no NaN or negative numbers except the keys
  meant to be negative (tolls, crashes, growth steps); values rise with band in every category and along every line; no recipe
  sells for more than its inputs plus fee under the proposed sell rule; no canon name from the research notes in any name or
  description; every `teaches` is a real ability; every `look` is a real wardrobe piece; all 59 live ids and all 191 design/06
  ids are in the draft.
- **Not checked**: anything in play. No number here has been in the game; the trip income at one star is an estimate; the two
  hours a star and the 20-40 trips a star are assumptions. The draft is not loaded, `game/data/items.json` is untouched, and no
  game code was changed. Whether a band-5 fight feels like a band-5 fight is for Brent's hands, once there is a band 5.
