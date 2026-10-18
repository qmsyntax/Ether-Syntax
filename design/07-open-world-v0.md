# Open world v0 — the Tithe Country: a world of zones, with dungeons in it

Draft of 2026-10-12; section 1 approved by Brent 2026-10-18 with the changes boxed there. **Nothing here is built and nothing here has been played.** Every number is a
first guess. Design and data drafts only; no file under `game/` was changed.

Tags: **[B]** Brent's ruling, **[C]** read in the books (through the project's paraphrased notes only — the note is named),
**[F]** fan source, **[MODEL]** our invention, **[?]** unknown. Anything untagged inside a section headed [MODEL] is [MODEL].
**Every place name, person, creature and item named in this document is original to this project.** No named place or character
from the books is used; where the setting's own *kinds* of thing are used (passages, hubs, anomalous realms, deviants, ether
density) the note they came from is cited. Short forms for the notes: `intro` = `research/intro-ch1-6-mechanics-notes.md`,
`b5` = `research/book5-mechanics-notes.md`, `b5b` = `research/book5-ch226-230-notes.md`, `2nd` = `research/secondary-sources.md`,
`bible` = `design/01-systems-bible-v0.md`.

Asked for by Brent 2026-10-12: *"I also want an agent to begin building a world...a real world. Open...like EQ. I love the idea
of D2 or EQ style open worlds with dungeons etc. start large then lets work small."*

Companion data draft (not loaded by the game): `design/data-drafts/world-v0.json` — the zone graph, and section 6 as data.

**Designed against** the code at commit `e9eecae`: one town (a menu over a 28 m square of cobbles), a 36 m practice arena, a
ten-chamber passage 16 m wide and 154 m long, six biome kits, eight enemy kinds, a Netherecho with one site per chamber, a fixed
camera showing about 19 m of world top to bottom, a player who walks 6.5 m/s, and **no pathfinding** — enemies walk straight at
you and know one doorway rule (`scripts/route.gd`).

Contents: 1 Decisions · 2 The world at map scale · 3 How the world works · 4 What the engine has to learn · 5 The starting
region · 6 The first zone to build · 7 Build order · 8 Risks and open questions · 9 What was and was not checked

---
## 1. The decisions (one page)

**Brent's rulings, 2026-10-18** — section 1 approved, with these changes. They override anything below that disagrees
(sections 3-8 still describe dawn rent, a collection crew and a 24-minute day; read them through this box):

- **[B] Nothing pays cash.** Kills and dungeon clears pay **loot** — items, corpses, beast parts. Money comes only from selling
  that loot in a town. (Replaces row 6's "dungeons still pay at the exit" and the passage's cash payout.)
- **[B] A day is 90 real minutes**, not 24. (Row 5.)
- **[B] Corpse runs.** You respawn **naked** in town; your body, with everything you wore and carried, lies where you fell. Walk
  back for it, or pay for retrieval — a **flat fee that may scale with level (stars)**, never a percentage of what you had.
  Hardcore is unchanged. (Replaces row 7.)
- **[B] No rent outdoors, and no rent clock.** The only rent is for a place to sleep and keep things: a room at an inn, an
  apartment, living quarters in an area. (Replaces the dawn rent in rows 5 and 13 and section 3.4.)
- **[B] Passages are owned, wild, or public.** Owned passages near the city charge (the ticket and the meter); wild ones are
  nobody's and free; some public ones are free for low levels. Tenwall Cut (today's passage) is owned. (Replaces row 13.)
- **[B] Build pathfinding now** rather than at step 6. (Replaces row 14.)

Each line is a decision, then my recommendation. "Go with your recommendations" approves the right-hand column.

| # | Decision | Recommendation |
|---|---|---|
| 1 | **Zone lines or one seamless map?** | **Zone lines** (EQ). Each zone is one level, built the way levels are built today. It suits the setting — the world is places joined by gates and passages [C: `b5` §6] — and it needs no streaming. |
| 2 | **Where is this?** | **An invented fringe city, Tithebarrow, and the country round it** — "the Tithe Country". Not on any map from the books; no canon place is named or visited. The land is New Earth [C: `intro` §1]; dungeons are anomalous realms behind passage mouths that stand *in* the land [B: realms hold both wilderness and bounded dungeons; C: `b5` §6]; only the last region is interspace proper. |
| 3 | **How big?** | **5 regions, 34 zones**, baby one-star to high three-star. Design all of it at map scale now (section 2); detail **one** region (section 5); build **one** zone (section 6). |
| 4 | **Fast travel?** | **No free travel, no recall.** Paid **carriage posts** [C: drake-drawn carriages, `intro` §1] that you must first reach on foot. A ride costs money, charges by weight, and moves the clock. |
| 5 | **A clock?** | **Yes, one world clock: a day is 24 real minutes.** Rent falls due at dawn wherever you are. Night changes who is out. A 20-30 minute sitting [B] is about one day and one rent. |
| 6 | **What does the open country pay?** | **What you can carry home.** No cash for a kill out of doors; the pay is loot, by weight, sold in town. Dungeons still pay at the exit, as now [C: `b5` §6]. This is what makes distance and the pack matter. |
| 7 | **Dying out there?** | **A collection crew drags you home; the bill grows with distance.** You keep what you wear. Your pack stays where you fell for two days — walk back for it, or pay half its value to have it fetched. Hardcore is unchanged. |
| 8 | **What is fixed and what is rolled?** (the D2 question) | **The map is fixed; the dressing is rolled per day.** Fixed: the zone graph, each zone's outline, zone lines, landmarks, dungeon mouths, the list of camp sites. Rolled from (zone, day): which camp sites are live, roamers, named spawns, props, and dungeon interiors. |
| 9 | **Respawn and named spawns?** | **Camps refill on the world clock** (eight hours after the last one falls, never while you stand near). **Named rares are deviants** [F: `2nd`] on a placeholder roll. Killing a lot of one people in a day brings a named avenger [C: the invaders' revenge ethic, `intro` §7]. |
| 10 | **Where do today's pieces live?** | The passage becomes **Tenwall Cut**, a ticketed dungeon whose mouth is in the yard. The arena becomes **the Chalk Ring** in your home district. The town menu becomes **the Ninth**, a district you walk. The Netherecho is everywhere; its best sites are landmarks far from town. |
| 11 | **What do we build first?** | **The Stubble** — the yard outside the city gate, 240 x 160 m, with the door to the existing passage at its far end. It needs no pathfinding. Seven build steps, each playable (section 7). |
| 12 | **New enemy kinds?** | **Three**, each asking one question the corridor never asked: the **Gleaner** (a runner), the **Sod-Lurker** (an ambush in the ground) and the **Thornback** (a neutral herd beast). |
| 13 | **The per-second rent inside the passage?** | **Leave it as it is for now**, re-described as the hub's meter [B: a hub's rules are whatever its owner says]. It is 30 times dearer per minute than the world's rent would be; that needs your call once the clock exists (section 8). |
| 14 | **Real pathfinding?** | **Not yet.** All of the starting region is shaped so that straight-line enemies work. Pathfinding is step 6 of 7, and it is what unlocks dungeons with rooms off a corridor and streets with corners. |

---
## 2. The world at map scale [MODEL]

### 2.1 The idea in five lines
- **Tithebarrow** is a low-rent passage town at the edge of the Empire [F: the Empire, `2nd`], built on a mound of sealed passages
  [C: known passages are sealed behind reinforced doors; cities sit on or near passages — `intro` §7, `b5` §6].
- The country round it is an **ether desert**: thin ether, so what comes through is weak and what you earn is poor [C: ether
  density; deserts are tame, rich zones are lethal and pay best — `b5` §1, §6]. **Ether thickens with distance from the city.**
  That is the world's difficulty curve, and it is the setting's own.
- The land is full of small **leaks** — wild passages nobody has paid to seal. Things come through and make camp. That is why a
  cleared camp fills again [MODEL, from C: cities on passages suffer periodic invasions — `b5` §6; that unsealed passages leak is only an inference in that note].
- **Dungeons** are anomalous realms: bounded, ruled, resetting, paying at the exit [C: `b5` §6]. Their mouths stand in the open
  country, usually with someone's toll-house built over them [C: good passages are owned and ticketed].
- Each region is one biome kit and one kind of ether, so **where you go to grow depends on your affinities** [C: local ether
  a water arch grows near water and earns in dry country — `intro` §5; F: local ether mirrors the place — `bible` LAW 1].

There are no levels in this setting [F: `bible` LAW 0]. A zone's **band** is a recommendation in the setting's own words —
low / mid / high / peak within a star, solo or party [C: `b5` §1; B: difficulty is a recommended rank and party, not a grade].

### 2.2 The regions

| # | Region | Band | Kit | Ether | What it is | New to see there |
|---|---|---|---|---|---|---|
| 1 | **The Barrow Marches** | baby 1★ - peak 1★ | scrubland (+ city, + a swamp edge, + a mountain foot) | desert | Tithebarrow and the dry country round it. The starting region | A city you walk; camps in the open; a herd; the first dungeon mouth |
| 2 | **The Sallow Fen** | peak 1★ - mid 2★ | swamp | fair, water | Wet lowland to the south-east. Slow ground, narrow ways | Boardwalk lanes, fog banks that hide a pack, a stilt village, a trap maze |
| 3 | **The Hackle** | low 2★ - peak 2★ | mountain (+ city) | fair, earth and lightning | The range to the north and the hub town in it | Height: ledges and shots from above; a second city with an auction house |
| 4 | **The Rimeward** | peak 2★ - mid 3★ | snow | rich, water and wind | The cold side of the range | Tracks that tell you what is ahead; ice that changes a shove; the last shelter |
| 5 | **The Understeps** | mid 3★ and up | dungeon kit out of doors, scrubland recoloured | rich, mixed | Interspace proper, reached by steps from the hub [C: `b5` §6] | A sky that is wrong; distance that does not add up [C: non-Euclidean] |

Why this order: scrubland is the kit the game began on; swamp and mountain each change *movement* (slow ground, height) before
snow changes *physics* (ice); the dungeon kit used out of doors is saved for the place that should feel least like home.

### 2.3 The map

```
                                          N

  THE RIMEWARD (snow, rich ether)
  ------------------------------------------------------------------------------------
     <Thawless Gate>===(The Glass Flats)-----[Cairnfast]
            :                 |
            :            (Whitefold)---{The Buried Nave}
            :                 |
  THE HACKLE (mountain, fair ether)
  ------------------------------------------------------------------------------------
            :   <The Cornice>===(Windscour Saddle)-----[[WINCHGATE]]~ ~ ~ hub ~ ~ ~ ~ +
            :                                               |                         :
            :   {Lastwatch Redoubt}---(The Scree Shelves)---+                         :
            :                            |         \                                  :
            :     {Paydown Deep}---(Crowstep Pass)   \  the fen back way              :
            :                            |             \                              :
  THE BARROW MARCHES (scrub, ether desert)               \    THE SALLOW FEN (swamp)  :
  --------------------------------------------------      \  ------------------------ :
            :                      (Hackle Foot)            (Gallmire)---{Eeler's Deep}:
            :                            |                      |                     :
            :  [[TITHEBARROW]]           |                  [Pilings]                 :
            :   Passage Row -------(Longacre Drove)---+         |                     :
            :   the Ninth --+         |  {Old Counting-House} (The Slow Mile)         :
            :    |          |         |               |         |                     :
            :  (Chalk     (The Stubble)     (Carrion Flats)   (Reedwake)---{The Sunk Chapel}
            :   Ring)       |  {Tenwall Cut}   |   \           |                     :
            :             (Sumpside)-----------+   <The Muster> |                     :
            :               |  {Drowned Lock}                   |                     :
            :               +-----------------------------------+                     :
            :                                                                         :
  THE UNDERSTEPS (interspace, rich ether) - not on the map: reached by steps          :
  ------------------------------------------------------------------------------------
     (Tawny Reach)-----------------------(First Landing) < ~ ~ ~ ~ ~ hub ~ ~ ~ ~ ~ ~ ~+
           |                                    |
     <Vault of the Unpaid>                 {The Spindle}

  [[CITY]]  [outpost]  (overland, yard or arena)  {dungeon}  <raid-like>
  ---  a zone line          ===  or \  entered from inside that zone
  ~ ~  the hub gate (a fee, and steps)      : :  Thawless Gate's far side also opens on Tawny Reach
```

The Understeps are drawn below the map because they are not *anywhere*: the hub in Winchgate and the far side of Thawless Gate
both open onto them [C: a few steps in may let out across the planet — `b5` §6].

### 2.4 The connection graph

```
 the Ninth ─┬─ Passage Row ── Longacre Drove ─┬─ {Old Counting-House}
            ├─ (Chalk Ring)        │          ├─ Hackle Foot ── Crowstep Pass ─┬─ {Paydown Deep}
            └─ The Stubble ────────┘          │                                └─ The Scree Shelves ─┬─ {Lastwatch Redoubt}
                 ├─ {Tenwall Cut}             └─ Carrion Flats ─┬─ <The Muster>          │           └─ WINCHGATE ─┬─ Windscour Saddle ─┬─ <The Cornice>
                 └─ Sumpside ─┬─ {Drowned Lock}                 │                        │                         │                    └─ Whitefold ─┬─ {The Buried Nave}
                              ├─ Carrion Flats (loop) ──────────┘                        │                         │                                  └─ The Glass Flats ─┬─ [Cairnfast]
                              └─ Reedwake ─┬─ {The Sunk Chapel}                          │                         │                                                      └─ <Thawless Gate> ─┐
                                           └─ The Slow Mile ── [Pilings] ── Gallmire ────┘ (the fen back way)      └~ hub ~ First Landing ─┬─ {The Spindle}                                    │
                                                                              └─ {Eeler's Deep}                                           └─ Tawny Reach ─┬─ <Vault of the Unpaid>            │
                                                                                                                                                          └───────────────────────────────────┘
```

Three loops, on purpose: Stubble - Longacre - Carrion - Sumpside (the starting region is a ring, not a corridor); Marches - Fen -
Hackle (the fen back way saves the pass, at a higher band); Hackle - Rimeward - Understeps (the deep loop). A world you can
walk round is a world you can plan a route through. The exact graph, with shortest distance from home for every zone, is in
`world-v0.json` (`connects`, `zones_out`).

### 2.5 All 34 zones

Type: **city**, **outpost** (a safe spot with a few services), **yard**, **overland**, **dungeon**, **raid-like** (rated for a
party; alone it is a feat), **arena**. Sizes are in the JSON. "Out" is zone lines from your room by the shortest way.

**Region 1 — The Barrow Marches** (detailed in section 5)

| Zone | Type | Band | Kit | Out | The one thing it is for |
|---|---|---|---|---|---|
| Tithebarrow: the Ninth | city | safe | city | 0 | Home. Rent, healer, tempering yard, merchant — the town menu, made walkable |
| Tithebarrow: Passage Row | city | safe | city | 1 | The hub quarter: tickets, the collection office, the carriage post, the bank |
| The Chalk Ring | arena | any | scrubland | 1 | Today's practice arena, as a place. Teaches; grows nothing [C: `b5` §12] |
| **The Stubble** | yard | baby - low 1★ | scrubland | 1 | Learn the open country. **Built first.** Holds the mouth of Tenwall Cut |
| Longacre Drove | overland | low - mid 1★ | scrubland | 2 | The road east. First runner, first side dungeon, first carriage post |
| Carrion Flats | overland | mid - high 1★ | scrubland | 3 | The hauling zone: big carcasses a long walk from the buyer. Fire wisps on the Scorch |
| Sumpside | overland | mid - high 1★ | swamp | 2 | Water wisps for water characters; boardwalk lanes; the way to the Fen |
| Hackle Foot | overland | high - peak 1★ | mountain | 3 | Shots from above; lightning on the ridge; the way to the Hackle |
| Tenwall Cut | dungeon | mid 1★ to the gate, high 1★ to clear | rolled | 2 | Today's ten-wall passage, unchanged [C: scenario assault, `b5` §6] |
| The Old Counting-House | dungeon | low - mid 1★ | dungeon | 3 | The D2 side dungeon: five rooms, a boss, a chest at the bottom |
| Drowned Lock | dungeon | high 1★ | swamp | 3 | A resetting resource cache [C]: the reward is what you can carry out |
| The Muster | raid-like | peak 1★, a party of 1★s | scrubland | 4 | An invader war-camp in the open. The region's exam |

**Region 2 — The Sallow Fen**

| Zone | Type | Band | Kit | Out | The one thing it is for |
|---|---|---|---|---|---|
| Reedwake | overland | peak 1★ - low 2★ | swamp | 3 | Standing water and fog: you stop seeing a pack before it sees you |
| The Slow Mile | overland | low 2★ | swamp | 4 | A causeway. Travel *is* the fight: planks, no room to back up |
| Pilings | outpost | safe | swamp | 5 | Stilt village: ferry post, a bonesetter at double price, a buyer for fen goods |
| Gallmire | overland | mid 2★ | swamp | 6 | The richest water ether in the first half of the world; the back way up to the Hackle |
| The Sunk Chapel | dungeon | low - mid 2★ | dungeon | 4 | A trap maze [C: mazes that want a scout]: read the floor |
| Eeler's Deep | dungeon | mid 2★ | swamp | 7 | A mystery instance [C]: layout and rule card rolled fresh on every entry |

**Region 3 — The Hackle**

| Zone | Type | Band | Kit | Out | The one thing it is for |
|---|---|---|---|---|---|
| Crowstep Pass | overland | low - mid 2★ | mountain | 4 | The long climb. A zone that is one decision: push on or turn back |
| The Scree Shelves | overland | mid 2★ | mountain | 5 | Terraces between the pass and the hub town; where the fen back way arrives |
| Winchgate | city | safe | city | 6 | Second city, on a portal hub [C]: ticket auctions, standing, the gate to the Understeps |
| Windscour Saddle | overland | high 2★ | mountain | 7 | Lightning and wind ether; the way over to the snow |
| Paydown Deep | dungeon | mid 2★ | dungeon | 5 | A debt mine [F: debtors are indentured to mine, `2nd`]. Where deep debt can send you |
| Lastwatch Redoubt | dungeon | high 2★ | mountain | 6 | Fortress defence [C: a scenario type]: this time you hold the wall |
| The Cornice | raid-like | peak 2★, a party | mountain | 8 | One giant-class thing on a ridge [C: the class exists; this one is ours] |

**Region 4 — The Rimeward**

| Zone | Type | Band | Kit | Out | The one thing it is for |
|---|---|---|---|---|---|
| Whitefold | overland | peak 2★ - low 3★ | snow | 8 | Tracks in the snow: the zone tells you what is ahead if you look |
| The Glass Flats | overland | low 3★ | snow | 9 | A frozen lake: a shove goes twice as far and so do you |
| Cairnfast | outpost | safe | snow | 10 | The last shelter: a carriage post, a fire, a buyer. No healer |
| The Buried Nave | dungeon | low - mid 3★ | dungeon | 9 | Chambers then boss; the ruins above are the plan of the rooms below |
| Thawless Gate | raid-like | mid 3★, a party | snow | 9 | A held gate. Past it the land stops being New Earth |

**Region 5 — The Understeps**

| Zone | Type | Band | Kit | Out | The one thing it is for |
|---|---|---|---|---|---|
| First Landing | overland | mid 3★ | dungeon kit, open sky | 7 | Where the hub lets out. The first place that is not the world |
| Tawny Reach | overland | mid - high 3★ | scrubland, recoloured | 8 | Grass to every horizon, things above and below [C: such a realm is shown, `intro` §7; this one is ours] |
| The Spindle | dungeon | mid 3★ | dungeon | 8 | A tower with auctioned entry; earlier entrants do better [C: such a tower exists; this one is ours] |
| Vault of the Unpaid | raid-like | high 3★, twenty | dungeon | 9 | Chambers then boss rated for twenty [C: that rating exists]. The far end, for now |

**Walking time, unopposed** (6.5 m/s, straight through each zone's long side): the Ninth to the far edge of Hackle Foot is about
940 m, two and a half minutes; to Winchgate about 1.9 km, five minutes; to Cairnfast about 3.5 km, nine minutes. With camps in
the way, a first trip to Winchgate is an evening. That is the EQ feeling at the size of a 20-30 minute sitting [B].

---
## 3. How the world works [MODEL]

### 3.1 Zone lines, not seamless
A zone is one level. Crossing a **zone line** — a gate, a gap in a bank, a defile, a door — unloads this zone and builds the
next, and puts you at the matching line on the other side. A zone line is drawn as a real opening with the next zone's name over
it when you are close. Nothing follows you across: a zone line is an escape, as it was in EQ, and it costs you the ground you
gave up. Why not seamless: every level today is built whole in one call (`_new_level`, then the biome kit), each kit has its
own light and fog, and the Netherecho is one controller per level. Zone lines keep all of that. Seamless would need streaming,
and it would buy nothing a 240-560 m zone does not already give.

### 3.2 What makes distance matter
No number in the game says "far". These five things do, and they are all already in the setting or the build:

| Pressure | What it does out there | Where it comes from |
|---|---|---|
| **Wounds** | A wound cuts your health ceiling until it is treated. Rest closes natural wounds only in a bed; the healer is in the city. The further out, the longer you carry them | Existing (`body.gd`); [C: healing is ruinously dear, `intro` §2] |
| **The pack** | The pay is what you carry. 38 kg at the start; a brute's goods are heavy. Every fight on the way home is fought loaded | Existing capacity; [F: delvers haul whole corpses; carry capacity is an economic stat] |
| **Rent** | Due at dawn, in the Ninth or not. A three-day trip is three rents you were not home to earn | Existing night rent ($150) [C: money is always concrete] |
| **Reflux** | It sheds slowly and only meditation clears it fast — and meditating out of doors is sitting still where things roam | Existing; [B: reflux is a real limiter] |
| **The bill for dying** | The collection fee grows with every zone line between you and the city (3.6) | Existing rescue fee, extended |

And one thing pulls the other way: **ether**. The further out, the thicker it is — more wisps, better ones, and enemies that
teach your star something [C: richer ether is deadlier and more lucrative; latent aura comes only from real risk — `b5` §1].

### 3.3 Travel: carriage posts, no recall
- **On foot** is the default and is free.
- **Carriage posts** [C: drake-drawn carriages for ordinary people — `intro` §1] stand in Passage Row, Longacre Drove, Sumpside,
  Hackle Foot, Winchgate and Cairnfast; Pilings has a **ferry post** that links only to Sumpside and Gallmire's landing. You can
  ride **only between posts you have walked to**. First guess: **$40 per zone line crossed, plus $2 for every kilogram over 20,
  and one hour on the clock per zone line.** A loaded ride home from Hackle Foot is $80 plus freight — about $120 with a full starting pack, most of a
  night's rent — which is the right size of decision.
- **The hub gate** in Winchgate is the same thing for the Understeps, dearer, and it takes the hub's cut of what you bring back
  [F: one hub takes half of what delvers carry out, `2nd`; B: the owner sets the rule].
- **No town portal, no recall, no map-click travel.** Teleporting is rare in the setting [C: `b5` §5]; and every one of the
  pressures in 3.2 dies the moment you can blink home.
- **Waypoints in the D2 sense: no.** The posts are the waypoints. They are few, they cost, and you earn each by arriving.

### 3.4 Time: one clock, a day is 24 real minutes
| | Real time | What changes |
|---|---|---|
| Day (06-18) | 12 min | The baseline. Camps sit at their fires. Herds graze |
| Dusk (18-21) | 3 min | Light drops; roamers start to move |
| Night (21-05) | 8 min | Harriers hunt in the open. Camps post one sentry further out. Wisps are easier to see. Lamps matter (the city kit already has them) |
| Dawn (05-06) | 1 min | **Rent is charged.** Camps that are due refill. The merchant's shelf turns over (design/06 §8.4) |

Day and night earn their place for one reason: **rent needs a clock you can see**. Everything else is cheap dressing on a sun
that already exists (`_sun` in `main.gd`). A night's rest in your room skips to dawn. Being out at dawn costs the same rent and
heals nothing. The clock stops in menus and — first guess — **inside a dungeon**, which keeps its own meter (3.9; decision 13).

### 3.5 Camps, respawn, named spawns
- A **camp** is a fixed spot with a small pack — a front line, a back line, at most one problem (the wall-recipe rule of
  design/05 §6.2, kept). Each zone has more camp *sites* than live camps: about two in three are live on a given day.
- A camp is **asleep** until you come within its wake radius, the way a wall is asleep until you reach it today. It has an
  **aggro radius** (about 12 m — just past the edge of the screen) and a **leash** (22-40 m). Past the leash they turn round, walk
  home and mend. Enemies of the same camp come together; a neighbouring camp does not, unless a Gleaner fetches it (5.4).
- **Refill**: eight world hours after its last member falls, at the next moment you are more than 60 m away. Never in your face.
- **Named rares** are **deviants** — one of a kind with an off-pattern talent [F: `2nd`; B: monsters have stars, affinities and
  talents]. Each has one home camp. When that camp refills there is a 12% chance the named takes the place of an ordinary
  member. So you learn where it lives, you clear the placeholder, and you come back. That is the EQ camp.
- **The grudge.** Kill 25 of the masked people in one zone in one day and their answer comes looking for you — a named avenger
  that crosses the zone to find you [MODEL, from C: they have a revenge ethic, `intro` §7]. It is the game telling you that
  farming one spot has a price, in the setting's voice rather than with a timer.
- **Growth does not come from safe camps** [C: latent aura only from real risk]. The rule in design/03 §4 that gain falls toward
  zero against things that cannot hurt you is what stops the yard being farmed for a star (whether the build applies it today I
  did not check). Loot still drops.
- **How you read a camp before you fight it**: the setting has no level numbers, but it has **aura** — anything a star above you
  presses on you before you see it [C: `intro` §2]. A queasy edge to the screen is this world's "it would wipe the floor with you".

### 3.6 Death, and getting your things back
| | Standard | Hardcore |
|---|---|---|
| You die out of doors | A **collection crew** [C: collection companies tally and recover — `b5` §7, §9] brings you to the Ninth. You wake at half health, in debt for the fee | The character ends (existing) |
| The fee | $600 (existing) + $150 for every zone line between where you fell and the city; + $300 if it was inside a dungeon | — |
| What you keep | Everything you are **wearing**, and your money | — |
| What you lose | Your **pack** stays where you fell, as a marked bundle, for **two days**. Walk back and pick it up — or pay the collection office **half its sale value** and it is in your room at dawn. After two days it is gone | — |
| Inside a dungeon | As today: what you had banked stays inside [existing]. The pack rule is the same, but the bundle waits at the **mouth**, outside — nothing but the reward leaves an anomalous realm [C] | — |
| In the Netherecho | The projection dying is the character dying (existing) [C] | Same |
| Debt you cannot pay | Later, not now: enough debt and the choice is **Paydown Deep**, a mine where you work it off [F: indenture] | — |

The corpse run is here, and it is cheaper than EQ's: you are never naked. What is at stake is the *trip's takings*, which is
exactly what the trip was for.

### 3.7 Overland against dungeon
| | Overland zone | Dungeon |
|---|---|---|
| What it is | Real country with leaks in it | An anomalous realm: made, ruled, false [C] |
| Shape | Open ground, 240-560 m, landmarks, edges | Chambers; a start and an end |
| Can you leave? | Any time, by any zone line | By its rule card: Tenwall seals you in until wall five [C; existing] |
| Enemies | Camps, roamers, herds. They leash | Stages that escalate; nothing leashes [C: troops, elites, commander] |
| Come back | Refill on the world clock | **Reset** whenever you re-enter [C: resetting dungeons] |
| Pay | Loot by weight, sold in town | At the exit, by how far you got; repeats pay less [C; existing] |
| Clock | The world clock: rent at dawn | Its own meter (existing rent per second) |
| Rolled | Which camps are live, roamers, named, props | The interior, each entry |
| Netherecho | Sites at landmarks; a parked body can be found by a roamer | One site per chamber (existing); nothing roams between walls |
| Growth | Thin near the city, real further out | Real — it is sealed and it escalates |
| Death | Pack left where you fell | Banked pay lost; pack waits at the mouth |

### 3.8 What is fixed and what is rolled
| Fixed for good | Rolled once per character | Rolled per (zone, day) | Rolled per entry |
|---|---|---|---|
| The zone graph and every zone's outline | Which of a dungeon's two or three possible mouths in its host zone is the real one | Which camp sites are live (about 2 in 3) | A dungeon's chamber order, recipes and biome (Tenwall already rolls its biome) |
| Zone lines, roads, landmarks, service doors | | Roamer routes; lurker patches | A mystery instance's rule card [C; design/03 §6] |
| The list of camp sites and what band they are | | Named spawn rolls | |
| Named spawns' home camps | | Prop scatter, weather, the merchant's shelf | |

The seed is (zone id, day), so a reload shows the same zone, as the merchant's shelf does in design/06. The D2 answer, then: a
fixed skeleton you can learn and give directions in, with flesh that is different every morning.

### 3.9 Where today's pieces go
- **The passage** is **Tenwall Cut**. Nothing about it changes: ten walls, the seal, the gate at five, the exit pad, the payout.
  It gets a *door*: a walled toll-house, **the Cut House**, at the far end of the Stubble. The ticket ($300, existing) is sold
  in the Ticket Hall on Passage Row [C: owners sell tickets]; the Cut House sells one at the door for a quarter more, for the
  forgetful. Its per-second "rent" is re-read as **the house's meter**: you are on their clock inside.
- **The arena** is **the Chalk Ring**, a fenced practice ground off the Ninth. It stays exactly what it is and keeps the canon
  rule that a safe fight grows nothing [C: `b5` §12]. It is where the first hour teaches the controls.
- **The town** is **the Ninth** and **Passage Row** (5.2). Every button on today's town screen becomes a door.
- **The Netherecho** is in every zone. A zone hands the controller its **sites** — the still places: wells, waystones, cairns,
  old trees, the dead ground of a camp [F: only stationary things show there, `2nd`]. What drifts at a site follows the zone's
  ether (`ether_mix` in the JSON) [F: local ether mirrors the place]. The leash (10 m + 3 per star, existing) and the rule that
  the body is parked and can be disturbed (existing) are what make *where* you sit a decision out of doors: a roamer can find
  your body. The best sites are far from the city, because that is where the ether is [C].
- **The tempering yard, healer, merchant, rest** keep their rules and numbers and become places (5.2).

---
## 4. What the world needs from the engine

Stated once, here, because it constrains every shape in sections 5 and 6.

**The rule today**: nothing pathfinds. `Route.step_toward` steers through one kind of doorway — the gap in a dividing wall across
a corridor that runs along one axis. Blocking props are kept hard against a side wall so nothing gets stuck behind one.

**So zones are shaped to that rule until step 6 of the build order:**
1. **Overland zones are open ground.** One convex field, or fields joined by gaps wider than 8 m. No interior walls.
2. **Blockers are small and few**: a collider no wider than 1.2 m (the existing cap), none inside a camp's leash, none on a road.
   A walker that meets one slides round it (a small steering rule — task E4a — not pathfinding).
3. **A camp's leash never crosses an edge.** Enemies never have to get round anything to come home.
4. **Dungeons are chains of chambers along one axis**, like the passage, or one large room. No side rooms, no corners.
5. **The city has no enemies in it**, so its streets can have corners; only the player has to walk them, and WASD does.
   (Click-to-walk across a corner will stop at the wall until pathfinding exists. Say so on the tin.)

**What it has to learn** — each a build task. Size: S about a day, M two to four days, L a week or more. None is started.

| ID | Task | Size | Depends on | Why the world needs it |
|---|---|---|---|---|
| E1 | **Zone data and a zone builder**: read a zone from data (size, kit, edges, zone lines, landmarks, camp sites) and build it with the existing kit calls | M | — | Everything. Today each level is a hand-written function |
| E2 | **Zone transitions**: a zone-line trigger; unload, build, place the player at the paired line | S | E1 | Zone lines |
| E3 | **World position in the save**: zone id + line id, written on every transition; save version 2 with a reader for version 1 | S | E2 | Today a save always wakes in town |
| E4a | **Slide-round steering**: a walker blocked by a small prop steps sideways round it | S | — | Open ground with boulders in it |
| E4b | **Real pathfinding**: bake a navigation mesh from a zone's colliders when it is built; enemies and click-to-walk follow paths; `Route` retires | L | E1 | Rooms off corridors, streets with corners, cliffs. *Whether baking a procedural zone at load is fast enough in 4.7.2 is unverified* |
| E5 | **Camps**: asleep / awake by distance, aggro radius, leash and walk-home-and-mend, same-camp assist | M | E1 | The open country. Today enemies exist only as an active wall |
| E6 | **Respawn and zone memory**: per zone, who is dead and when they are due; saved | M | E5, E7 | Camps that refill; a zone that remembers you |
| E7 | **The world clock**: time of day, dawn rent, sun and ambient by hour; stops in menus | M | — | Rent at dawn; night. Touches the rent self-test |
| E8 | **A camera for large places**: nothing new for following, but an **off-screen threat marker** (an archer holds at 9-12 m; the screen shows about 9.5 m above and below you) and a hold-to-look-ahead | S | — | In a corridor the threat is always "up". In a field it is anywhere |
| E9 | **Drawing a large zone**: props as MultiMesh by kind (the kit is built for it), scatter in tiles, prop lights capped at eight near the player (the kit's own stated ceiling), shadow distance | M | E1 | A 240 x 160 m zone is about 950 props at 2.5 per 100 m² (the passage runs at about 4); Tawny Reach would be 5,900 |
| E10 | **A map screen**: the zone outline, lines, landmarks you have seen, yourself; and a world page showing the graph | M | E1, E3 | You cannot give or follow directions without one |
| E11 | **Walkable services**: a door you walk up to opens the screen that exists today; the town screen is split into its parts | M | E1, E2 | The Ninth |
| E12 | **A dungeon behind a door**: the existing passage entered from a zone and leaving back to it | S | E2 | Tenwall Cut in the Stubble |
| E13 | **Field death**: the collection fee by distance; the pack bundle left in a zone and saved | M | E3, E6 | 3.6 |
| E14 | **Named spawns and deviants**: a placeholder roll at refill; a deviant flag that adds a talent and the bonus loot rows of design/06 §8.1; the grudge counter | M | E5, E6 | 3.5 |
| E15 | **Netherecho sites from zone data** | S | E1 | 3.9. The controller already takes sites one at a time |
| E16 | **Carriage posts** | S | E2, E7, E10 | 3.3 |
| E17 | **A zone bot**: `--bot-zone=<id>` walks gate to dungeon door to the far zone line and prints PASS; per kit | S | E1, E2, E5 | The passage bots are what keep the passage honest; a zone needs the same |
| E18 | **Unreachable perches**: an archer on a cliff piece that a walker cannot reach — ranged or a skill only. No real height | S | E5 | Hackle Foot's whole point |
| — | **Streaming / seamless loading** | — | — | **Not needed.** Listed so nobody builds it |

---
## 5. The starting region: the Barrow Marches [MODEL]

### 5.1 The region in one paragraph
A dry plain under a low sun, a city on a mound in the middle of it, and nothing growing that anyone wanted. Tithebarrow exists
because the mound is full of passages; the country round it is poor because the ether is thin [C: ether deserts]. Everybody
who becomes an archhuman here starts by walking out of the Dross Gate with a borrowed weapon and a room they cannot afford.
The region is a **ring** of four overland zones round the city's east and south, with the yard inside it:

```
                         (Hackle Foot) ───> Crowstep Pass, the Hackle
                               │
   [the Ninth]──[Passage Row]──(Longacre Drove)─────────(Carrion Flats)══<The Muster>
     │    │                       │  {Old Counting-House}      │
 (Chalk  (The Stubble)────────────┘                            │
  Ring)   │  {Tenwall Cut}                                     │
          (Sumpside)───────────────────────────────────────────┘
            │  {Drowned Lock}
            └───> Reedwake, the Sallow Fen
```

Every starting affinity has somewhere thin to gather, because a character's affinities are rolled, not chosen [B]: earth and
wind in the Stubble and Longacre; **water in Sumpside**; **fire on the Scorch** in Carrion Flats; **lightning on the ridge** at
Hackle Foot. A water character and a fire character leave the same gate and turn different ways. That is the canon rule that
affinity decides where you live and hunt [C: `intro` §5], doing a job.

### 5.2 Tithebarrow
A city of numbered districts, the low numbers at the top of the mound [C: numbered districts, brutal stratification; a district
can be closed to those without business there — `intro` §1]. The game gives you two of them and shows you a third.

**The Ninth** — 90 x 60 m, city kit. One wide street with a yard off it. Where you live.

| Place | What it is today | What it becomes | Notes |
|---|---|---|---|
| **The Stack** | "Rest the night" ($150) | A rooming house; your door. Rest, save, and — new — a **trunk** that holds 60 kg | An open world needs somewhere to leave things. The trunk is the only storage |
| **The Landlord's Window** | Rent, charged when you rest | A hatch in the Stack's front. Shows what you owe; takes payment; is where debt lives | Rent is charged at dawn whether you slept or not (3.4). Behind on rent for three days: the trunk is locked until you pay |
| **The Bonesetter** | Healer | A shopfront under the sign of a splint | Prices unchanged. Open all hours [C: arch-facing offices run round the clock, `intro` §2] |
| **The Breaking Yard** | Tempering yard | An open yard behind a fence at the street's end | Unchanged; you can see other people's training posts |
| **The Tallyman** | Merchant, and "sell your loot" | A stall with a scale. Buys by weight, sells the shelf of design/06 §8.4 | The pack's $ per kg sort (design/06 §9) is for standing here |
| **The Chalk Ring** | Practice arena | A gate at the side of the Breaking Yard; a zone line | Unchanged |
| **The Dross Gate** | "Enter the passage" (in part) | The city gate to the Stubble | Named for what goes out of it |
| **The Sixth Stair** | — | A gate uphill, shut, with a porter who wants to see a reason | You cannot go up. That is the point, and it is free content [C: closed districts] |

**Passage Row** — 80 x 50 m, city kit. The business end: a paved row of offices with the old sealed passage doors bricked into
the mound behind them [C: sealed passage doors].

| Place | What it does | Status |
|---|---|---|
| **The Ticket Hall** | Sells tickets to the region's owned dungeons: Tenwall Cut ($300, existing), later the Old Counting-House | Tenwall's ticket exists; the hall is new |
| **The Collection Office** | Brought you home (3.6); will fetch your pack for half its value; buys proof of deviants | New |
| **The Carriage Post** | Paid travel between posts you have reached (3.3) | New |
| **The Counting Bank** | Holds money where nothing can take it [F: banks are untouchable, `2nd`]; lends, at a rate | New, later. Debt is in the game already; a lender is its natural face |
| **The Runesetter** | Writes one rune on a Fine item (design/06 §8.5) | A stub there, a shut door here |
| **The Registry** | Where an archhuman is put on paper [C: registration is a slog, `intro` §2]. Later: badges [C: `b5` §10] | Dressing now |
| **The Drove Gate** | The east gate, to Longacre Drove | New |

Nobody in either district fights, so neither needs pathfinding (section 4, rule 5).

### 5.3 The overland zones

Enemy strength is the existing multiplier on health and damage; the passage runs 1.0 before its gate and 1.3 after it.

| Zone | Size | Strength | Camps (live / sites) | Mix | Roamers | What is new here |
|---|---|---|---|---|---|---|
| **The Stubble** (yard) | 240 x 160 | 0.6 - 0.9 | 7 / 9 | Skirmishers in twos and threes; two Archers; one Pavise; one Brute by the Cut House | 2 Gleaners; 1 Harrier at night; a Thornback herd of 4 | Everything: a camp, a leash, a herd, the ground that bites (section 6) |
| **Longacre Drove** | 400 x 220 | 0.9 - 1.1 | 9 / 13 | Skirmisher + Archer camps; two Pavise pairs; a Censer-Bearer camp; a Brute at the Counting-House steps | 3 Gleaners; a Harrier pair | **The runner matters**: camps are close enough here that a Gleaner brings a second one |
| **Carrion Flats** | 440 x 320 | 1.0 - 1.2 | 8 / 12 | Harrier packs of three; Brute pairs; a Drummer camp | 3 Thornback herds of 5-7; Harriers day and night | **The herd**: big, slow money a long way from the scale. The Scorch — a burnt strip with fire wisps |
| **Sumpside** | 360 x 260 | 1.0 - 1.2 | 8 / 11 | Censer-Bearer + Skirmishers; Archers across water; Pavise on the boardwalks | Sod-Lurkers thick off the planks | **The lane**: boardwalks 4 m wide, shallow water that slows you (new, small); a Pavise on a plank cannot be walked round |
| **Hackle Foot** | 300 x 340 | 1.1 - 1.3 | 9 / 12 | Archers on perches; Brute + Drummer; Pavise lines across the climb | Harrier pairs; one deviant | **The perch** (E18): an Archer you cannot walk to. Sling, skill or go round |

**The four ring zones, a line each on shape** (all open ground, per section 4):
- **Longacre Drove** is a long field with the road down its middle and the Old Counting-House — a ruin with one standing
  front — on a rise at its eastern third. The carriage post is at the west end by the Drove Gate. Lines: west to Passage Row
  and the Stubble, north to Hackle Foot, east to Carrion Flats.
- **Carrion Flats** is the biggest and emptiest: no road. The Scorch runs across it north to south; the Muster's palisade
  stands in the north-east and can be seen from half the zone. Lines: west to Longacre, south-west to Sumpside.
- **Sumpside** is water with ground in it: three islands of firm mud joined by boardwalks (the swamp kit has them). Drowned
  Lock is on the furthest island. Lines: north to the Stubble, east to Carrion Flats, south to Reedwake.
- **Hackle Foot** climbs from south to north in three shelves (drawn with the mountain kit's cliff pieces; the play is flat).
  The ridge at the top is the lightning site. Lines: south to Longacre, north to Crowstep Pass.

### 5.4 Three new kinds [MODEL]
All three are original designs. Each exists because the open country asks something the corridor could not.

| Kind | What it does | The question it asks | Needs |
|---|---|---|---|
| **Gleaner** — 90 hp, fast (7.5), no attack | A scavenger that hangs at the edge of a camp. When the camp is attacked it turns and **runs for the next camp**; if it gets there, that camp comes | *Can you stop it before it gets home?* A sling, a pull, a shove, a blink — or kill it first and take the camp second | A "flee to a point" behaviour (straight line, so no pathfinding). EQ's runner |
| **Sod-Lurker** — 200 hp, 30 damage, does not move far | Lies under a patch of **visibly turned earth** off the road. Step on the patch and it comes up under you for a heavy hit and a stagger; it will not chase past 8 m | *Were you reading the ground, or running?* It is why the road is the safe way and the short cut is not. And it punishes fleeing blind | A dormant state and a trigger area. [C: burrowing predators exist in one realm, `intro` §7; this one is ours] |
| **Thornback** — 1,600 hp, slow, **neutral** | A grazing herd beast. Ignores you until one of the herd is hit; then the herd lowers its heads and charges in straight lines (the Commander's charge, smaller) | *Is this worth the weight and the walk?* A carcass is 45 kg of hide and horn — more than the starting pack holds. And it is a great deal of living thing to harm, for talents that care [B: bigger creatures carry more vitality] | A neutral state; herd assist. The charge exists |

The **Sapper** proposed in design/05 §6.1 (it breaks standing stone) remains the fourth candidate; it belongs to dungeons.

### 5.5 The dungeons

| Dungeon | Mouth | Kind | Shape (to section 4's rules) | Fights | The bottom |
|---|---|---|---|---|---|
| **Tenwall Cut** | The Cut House, the Stubble | Scenario: assault [C] | **As built**: ten chambers 14 x 16 m in a row | As built (`passage.wall_recipes`) | As built: the exit pad, the payout; design/06 §8.2-8.3 for loot |
| **The Old Counting-House** | A ruin on a rise in Longacre Drove | Chambers then boss [C] | **Five chambers in a row, of different sizes** — 12, 18, 12, 24, 16 m long — so it reads as rooms, not a corridor, and still obeys the one doorway rule. No seal: you may walk out. No meter | 1: Skirmishers. 2: Archers behind a Pavise pair. 3: a Censer-Bearer in a crowd. 4: Brute + Drummer. 5: the boss | **The Auditor** — a Wall Commander at strength 0.9 with a ledger chained to its arm — and **the vault chest**: one Fine item always, a Runed item 15% |
| **Drowned Lock** | The far island, Sumpside | Resetting resource cache [C: one resource may be carried out every reset] | **One room**, 60 x 60 m, a flooded lock basin with firm ground round the rim | Waves, as the arena does them, for as long as you stay. They get worse | **Lockweed** grows on the basin wall: 2 kg a bundle, $90 each, as much as you can cut and carry. It resets at dawn. The whole dungeon is the pack screen |

**The Muster** (raid-like, in Carrion Flats): a palisaded war-camp 140 x 120 m, open inside. Five camps close enough that each
calls the next (the `reinforcements` signal exists), two Wall Commanders, and the **Muster-Captain** at the back. Rated for a
party of one-stars [B: difficulty is a recommended party]. There are no parties in the build; alone it is meant to be the
region's exam, and passing it alone is the kind of thing the setting says a star is made of [C: latent aura from real risk].

### 5.6 Named spawns
All deviants [F], all original. Each is an ordinary kind with one rule bent — the way design/06 writes its unique items.

| Name | Home | Base | The bend | The question |
|---|---|---|---|---|
| **Old Ha'penny** | The hanging tree, the Stubble | Skirmisher | Every hit knocks $40 out of your purse onto the ground; at half health he grabs what has fallen and runs for the nearest zone line | Can you finish what you start? (And: the game's first joke about money) |
| **The Widow-Mask** | Wherever you are, the Stubble | Harrier | The grudge (3.5). She does not circle. She comes straight across the zone for you, and she pounces twice | You have been farming. Are you ready to be hunted? |
| **Dray** | The Counting-House steps, Longacre | Brute | Drags a loaded sledge; the slam cannot be interrupted, but he cannot turn with the sledge on — his back is always open | Do you know where to stand? Then: 60 kg of goods, 2 zones from the scale |
| **Long Sorrow** | The Scorch, Carrion Flats | Harrier | Leads a pack of four; while she lives, the pack pounces one after another instead of waiting for you to run | Can you find the one that matters in a moving crowd? |
| **Wet Wick** | The middle island, Sumpside | Censer-Bearer | Its burst does not heal the others; it puts out every light and sets a fog bank for 10 s | Can you fight what you cannot see — or kill it somewhere else? |
| **The Unseen Fletcher** | The top shelf, Hackle Foot | Archer | No aim line until the last 0.4 s; range 24 m | Do you listen? (The draw has a sound) [C: light-affinity stalkers exist; this one is ours] |
| **The Auditor** | The Old Counting-House | Commander | A boss, not a rare: always there | — |
| **The Muster-Captain** | The Muster | Commander | A boss: calls a whole camp, not four | — |

### 5.7 What drops where
Tied to the tiers of design/06 §6.1 (Salvage, Plain, Fine, Runed, Cursed, Unique) and its per-kind rows (§8.1), which stay as
they are. The zone sets the **ceiling** and the **bump**, the way wall depth does in the passage (§8.2).

| Place | Highest tier that can drop | Chance a gear roll is bumped a tier | Its own goods |
|---|---|---|---|
| The Stubble | Plain (Salvage is the rule) | 0% | Thornback hide and horn; scrub flora |
| Longacre Drove | Plain | 10% | Drove-side flora; scrap iron at the ruin |
| Carrion Flats | Fine | 15% | Hide and horn in bulk; Scorch-glass (a material) |
| Sumpside | Fine | 15% | Fen flora; rune-ink ingredients from Censer-Bearers (design/06) |
| Hackle Foot | Fine | 30% | Arrows and bows from the perches; ridge flora |
| The Old Counting-House | Fine; the chest can be Runed | 30% | The vault chest (5.5) |
| Tenwall Cut | As design/06 §8.2: Plain / Fine / Runed by wall | As §8.2 | As §8.3 |
| Drowned Lock | Fine | 30% | Lockweed by the kilogram |
| The Muster | Runed; Commanders as §8.1 (Cursed 3%) | 50% | The Captain: one Runed item always |
| A named deviant | The bonus rows of §8.1 (Runed 50%, Cursed 15%, Unique 3%) — **halved in the Stubble** | — | Its proof, which the Collection Office buys |

Two things to notice. Nothing better than Plain drops in the yard, so the yard is never where you gear up. And the *goods*
column is the open country's real pay: by weight, a walk from the scale (decision 6).

### 5.8 The first hour
A walkthrough of intent, not of anything built. Times are guesses.

| Minute | Where | What happens |
|---|---|---|
| 0-5 | Creation | As today: three primes rolled, one chosen |
| 5-8 | **The Ninth** | You wake in the Stack with $10,000 (existing) and a note of what the room costs. The Landlord's Window is the first door you pass. You own a coat and a sling (design/06) and the Tallyman would like to sell you more. You see the Sixth Stair and are not let up it |
| 8-11 | **The Chalk Ring** | Optional. One wave. It teaches the strike, the skill keys and the sling, and says in so many words that nothing here will grow you |
| 11-14 | **The Stubble**, by the gate | Out of the Dross Gate. The road runs away east. Camp 1 — two Skirmishers at the tip — is in sight of the gate. First loot on the ground; first look at the pack's weight |
| 14-20 | The Stubble, the middle | The dry well: the first place to sit, and the first Netherecho site, with a wisp or two of what you can use. Camp 3 has an Archer and a Gleaner at its edge — the Gleaner runs, and now there are five of them. First lesson in pulling. A patch of turned earth off the road; the second one you walk round |
| 20-26 | The Stubble, the far end | The Thornback herd, left alone or not. Camp 7 — a Brute and two Skirmishers — stands between you and the Cut House. It is the yard's test: beat this and you may knock |
| 26-30 | Walk home | Pack near full, one wound. The road is 33 seconds long with nothing on it; it feels longer loaded. The Tallyman's scale; the Bonesetter, or not; bed. **Dawn: rent** |
| 30-45 | Day 2: **Tenwall Cut** | Ticket from the Hall, out through the Stubble (the camps have refilled — you walk round two of them now), in at the Cut House. The passage as it plays today, to the gate at wall five, and out. The payout lands; the meter has taken its share |
| 45-60 | **Longacre Drove** | The Drove Gate, the carriage post (now yours), the first camp that is properly dangerous, and the Old Counting-House on its rise with Dray on the steps, perhaps. You see the gap north to Hackle Foot and the aura off it turns your stomach [C]. You go home the long way, through the Stubble, because your pack is at the tree where you died |

By the end of the hour the player has walked a city, crossed three zone lines, been inside a dungeon that stands in the world,
carried something home by weight, paid rent twice, and chosen not to go somewhere. That last one is the open world working.

---
## 6. The first zone to build: The Stubble [MODEL]

**Why this one.** It is the smallest thing that is honestly "an open world with a dungeon in it": a field you cross, things
camped in it, a city gate behind you, a dungeon door ahead and two ways on. It uses the kit the game began on, five of the eight
enemy kinds that exist, the passage as it stands, and **no pathfinding**. The same coordinates are in `world-v0.json` under
`first_build`.

### 6.1 Size and frame
- **240 m east-west by 160 m north-south.** About 7 screens by 8 (the camera shows roughly 34 x 19 m). Gate to Cut House is
  214 m in a straight line: 33 seconds unopposed, six to ten minutes the first time.
- Origin at the north-west corner; x east, y south. The level is turned 45 degrees, as the passage is, so north is straight up
  the screen and the city wall is the **far** edge — the tall one. The south fence is the near edge and stays low
  (`wall_height_near`), so it never hides the floor.
- **Edges**: north, the city wall (city kit, 3.2 m, with the Dross Gate in it); east and west, a dry-stone bank (scrubland
  wall, 2.4 m); south, a stake fence (scrubland's own gate piece run long, 1.1 m).
- **Ground**: scrubland floor. Props at about 2.5 per 100 m² — a little under the passage's density, about 950 in all, nine in
  ten of them scrub and stones that block nothing. **Blocking props only along the edges and round the Cut House.**
- **Ether**: desert; earth and wind wisps. **Strength** 0.6 by the gate rising to 0.9 by the Cut House.

### 6.2 Layout sketch
One character is 4 m across and 8 m down. Approximate; the table in 6.3 is the authority.

```
    0         40        80        120       160       200       240 m
    ###########G##################################################  y=0    city wall (far side, tall)
    #          ............                                      #
    #                     ............                           #
    #               H                ............                #
    #                                           ............     #
    #                                                      ......>  y=36   DROVE STILE -> Longacre Drove
    #                   1               s           W            #
    #                                               ::           #
    #       s                    3            5      ::          #
    #                        o                        ::  s      #
    #                                                  ::        #  y=80
    #                                                   ::       #
    #                                                   7::      #
    #             2                       T               ::     #
    #                      s               6               ::    #
    #                                                      CCC   #  y=112  CUT HOUSE -> Tenwall Cut
    #                              4                             #
    #                                             s              #
    #                 s                                          #
    #                                                            #
    #                                                            #  y=160
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~v~~~~~~~~~~~~~~~~~~~~~~~  fence (near side, low)
                                          ^ WET GAP -> Sumpside (x=150)

    G Dross Gate   .... the road   :: the Cut track   H the dross heap   o the dry well   W the waystone
    T the hanging tree   CCC the Cut House   1-7 camps   s a Sod-Lurker patch (six, re-rolled daily)
```

### 6.3 Zone lines, landmarks, camps

**Zone lines**

| Line | At (x, y) | Width | Leads to | Drawn as |
|---|---|---|---|---|
| The Dross Gate | 40, 0 | 6 m | The Ninth | The city kit's gatehouse arch (exists) |
| The Drove Stile | 240, 36 | 8 m | Longacre Drove | A gap in the east bank where the road goes through |
| The Wet Gap | 150, 160 | 8 m | Sumpside | A gap in the south fence; the ground darkens toward it |
| The Cut House door | 222, 112 | 4 m | Tenwall Cut | The dungeon kit's portcullis in a city-kit wall. **Ticket checked here** |

**Landmarks** — each is something you can name when giving directions, and four of them are Netherecho sites.

| Landmark | At | Built from | Job |
|---|---|---|---|
| The dross heap | 62, 22 | Scrubland stones, skulls | The city's tip: the first thing past the gate, and why the gate has its name. Site |
| The road | 40, 0 to 240, 36 | A lane 8 m wide swept of props | The safe way: no camp within 30 m, no lurker within 6 m |
| The dry well | 98, 70 | The city kit's well | The place to sit. Site. Camp 3 watches it from 18 m |
| The waystone | 188, 44 | Scrubland's waystone | Where the Cut track leaves the road. Site. A map marker |
| The hanging tree | 150, 96 | Scrubland's dead tree, biggest variant | Old Ha'penny's home. Site. Visible from the well |
| The Cut House | 222, 112 | Three sides of city-kit wall round a 20 x 16 m yard; the dungeon gate in the back | The toll-house over the mouth of Tenwall Cut. Safe inside the yard: nothing leashes that far |

**Camps** — seven live each day out of nine sites (the two spares are at 96, 132 and 196, 140; the roll never leaves camp 7 out).

| Camp | At | Strength | Who | Leash | Job |
|---|---|---|---|---|---|
| 1 The tip-pickers | 78, 40 | 0.6 | 2 Skirmishers | 22 m | The first fight. In sight of the gate, so you can run home |
| 2 The ditch | 52, 96 | 0.6 | 3 Skirmishers | 22 m | Off the road, for those who go looking. Three at once is the slot ring's first use |
| 3 The well-watch | 112, 58 | 0.7 | 2 Skirmishers, 1 Archer, + a Gleaner at its edge | 24 m | The first back line, and the first runner (it runs for camp 5, 54 m away) |
| 4 The herd | 120, 122 | 0.8 | 4 Thornbacks, neutral | 40 m | The first choice that is not a fight |
| 5 The shield pair | 166, 60 | 0.7 | 2 Skirmishers, 1 Pavise Bearer | 24 m | The first enemy you must get round |
| 6 The tree camp | 154, 104 | 0.8 | 3 Skirmishers, 1 Archer | 26 m | Old Ha'penny's placeholder (12% per refill) |
| 7 The Cut pickets | 204, 92 | 0.9 | 1 Hide-Bound Brute, 2 Skirmishers | 26 m | The gate before the gate. On the Cut track; the Cut House is 27 m past it |

Eighteen hostile enemies at most, plus the herd and two Gleaners; never more than four awake together unless a Gleaner gets
home. Camps are at least 38 m apart — further than a screen — so two are never on screen at once, and no hostile camp's leash
reaches the next camp.

**Roamers**: two Gleaners (above); one Harrier, at night only, walking between camps 5 and 7 — the reason the Cut track is a
different walk after dusk. **Lurker patches**: six, re-rolled each day, never within 6 m of the road or 20 m of a zone line.
**Named**: Old Ha'penny and the Widow-Mask (5.6). **Refill**: eight world hours; not while you are within 60 m.

### 6.4 What it must teach, in order
The gate is safe → a camp has an edge you can stand outside → things go home if you run → the road is safe and the short cut is
not → not everything wants to fight → a runner must be stopped → the pack fills → there is a door at the far end, and something
is standing in front of it.

### 6.5 What the engine needs for this zone
From the table in section 4. **Bold** is needed before the zone can be walked at all.

| Task | Size | Depends on | For the Stubble it means |
|---|---|---|---|
| **E1 Zone data and builder** | M | — | Build 240 x 160 from `first_build` instead of a hand-written function |
| **E2 Zone transitions** | S | E1 | The Dross Gate (to the town menu at first), the two far lines (shut, with a sign, until those zones exist) |
| **E12 A dungeon behind a door** | S | E2 | The Cut House door calls the existing `_enter_dungeon`; the exit pad returns you to the yard |
| **E9 Drawing a large zone** | M | E1 | About 950 props and one long wall run per side; first place a level is bigger than the screen in both directions |
| E5 Camps | M | E1 | Seven camps asleep until approached; leash and walk home |
| E4a Slide-round steering | S | — | Enemies and boulders in the same field |
| E8 Off-screen threat marker | S | — | An Archer at 12 m is off the top of the screen |
| E3 World position in the save | S | E2 | Save and wake in the Stubble |
| E7 The world clock | M | — | Dawn rent; the night Harrier |
| E6 Respawn and zone memory | M | E5, E7 | Camps refill; the zone remembers |
| E13 Field death | M | E3, E6 | The bundle at the tree |
| E15 Netherecho sites from data | S | E1 | Four sites |
| E14 Named spawns | M | E5, E6 | Old Ha'penny; the Widow-Mask |
| E17 A zone bot | S | E1, E2, E5 | Gate → Cut House → in → out → stile, prints PASS |
| New kinds: Gleaner, Sod-Lurker, Thornback | S each | E5 | Camp 3's runner, the patches, camp 4. The zone works without them; it teaches less |

Not needed for this zone: pathfinding (E4b), the map screen (E10 — though it will be missed by the second zone), walkable
services (E11), carriage posts (E16), perches (E18).

---
## 7. Build order

Seven steps. Each one ends with something Brent can play, and each is the smallest thing that answers one question.

| Step | What is built | Tasks | Playable result | The question it answers |
|---|---|---|---|---|
| **1. A field with a door in it** | The Stubble as empty ground with its edges, road and landmarks. The town menu gains "Walk out of the Dross Gate". The Cut House door opens the existing passage and its exit returns you to the field | E1, E2, E12, E9 (plain version) | Walk 214 m across a zone to the dungeon, do the passage, walk back to the gate | Does walking to the dungeon feel like something, or like a loading screen with legs? |
| **2. Things live there** | The seven camps, leash, same-camp assist, slide-round steering, the off-screen marker. Existing kinds only | E5, E4a, E8, E17 | A newbie yard: fight your way to the Cut House | Is a fight in open ground with these enemies any good? (The slot ring and the pouncer were tuned in a corridor) |
| **3. The world keeps time and remembers** | The world clock, dawn rent, night; respawn; position in the save; field death and the bundle | E7, E6, E3, E13 | Leave, come back tomorrow, find it refilled; die and go back for your pack | Do rent, weight and the walk home make a trip a *decision*? This is the EQ question |
| **4. The Ninth** | The home district as a place; each service a door onto the screen that exists | E11 | Wake in your room, walk to the Bonesetter, walk out of the gate. The town menu retires | Does a walkable town earn the seconds it costs in a 20-minute sitting? |
| **5. A second zone and a second dungeon** | Longacre Drove; the Old Counting-House (a chain of chambers, no seal); the map screen; named spawns; the Gleaner; Netherecho sites from data | E10, E14, E15, + content | Two zones, two dungeons, a rare to camp, a runner to stop | Is it a *world* yet — do you plan a route? |
| **6. Pathfinding** | Navigation baked per zone; enemies and click-to-walk follow paths; `Route` retires; the passage bots must still pass | E4b | Nothing new to see — and then the Counting-House can grow side rooms and the Ninth can have a corner | Was it worth a week? Only build it when step 5 says the world is |
| **7. The rest of the ring** | Carrion Flats, Sumpside, Hackle Foot, Drowned Lock, the Muster, Passage Row; carriage posts; the Thornback and Sod-Lurker; perches | E16, E18, + content | The whole starting region: a first star's worth of world | Does the region hold two hours [B: the second star should take about two]? |

After step 7, regions 2-5 are content on a finished engine: about 22 zones, none needing a system this document has not listed.

**What to cut if it has to be smaller**: step 4 (the town can stay a menu for a long time) and the map screen from step 5. Not
step 3 — without the clock, the pack and the death rule, it is a bigger arena, not a world.

---
## 8. Risks and open questions

### 8.1 Risks
1. **Walking is dead time.** A 20-30 minute sitting [B] cannot spend six of them walking through cleared camps. The mitigations
   here — a short safe road, refills that never happen in your face, carriage posts — are guesses. Step 1 exists to find out.
2. **Combat was tuned in a corridor 16 m wide.** The slot ring, the Harrier's "moving away from the pack" rule, the Archer's
   hold range and the Commander's wall-crash all assume walls close by. In a field there is no wall to crush against (water),
   no wall for the Commander to hit, and running away is always possible. Open-ground fights may be too easy or just odd.
   Likely fix: landmarks that are also fighting ground — the well, the tree, the heap — but that is a claim, not a result.
3. **No pathfinding is a real ceiling.** Sections 5 and 6 are bent round it. If it turns out camps need fences, or the Ninth
   needs alleys, to feel like places, step 6 moves up and is the biggest single item here.
4. **The camera shows 19 m.** An open world is partly the pleasure of seeing far. This one will be read off a map screen and
   landmarks at arm's length. Pulling the camera out costs the model detail the art passes were for.
5. **Solo growth against an EQ world.** EQ's world was built to make people group. This setting pays growth for going alone
   [C]. "Raid-like" zones here are solo exams with a party rating on the door. That may read as a tease.
6. **Thirty-four zones is a lot of content for a prototype.** The map is cheap; zones are not. Only region 1 is specified, and
   it alone is about nine zones of real work after the first.
7. **Two rents.** The passage charges $3 a second inside (about $1,800 for ten minutes); the world's rent is $150 a day. Side
   by side the passage's meter will look absurd, or the world's rent will look like nothing. See question 3.
8. **Drawing a big zone is untested.** 950 props is my arithmetic from a density a little under the passage's, not a measurement; whether the
   kit's MultiMesh path is used by `_scatter_props` today I did not check.
9. **Saves grow teeth.** Zone memory, bundles and a clock mean a save is no longer "a character in town". Version 2 of the
   save needs a migration and more tests than version 1 ever had.
10. **Names.** Every name here is invented, and I checked them against the names in `research/` — not against the books
    themselves, which this project does not hold. If any collides with something in books 1-4, Brent is the one who would know.

### 8.2 Open questions for Brent
1. **Is the Tithe Country in the right place?** I invented a fringe city rather than use the frozen northern fringe the notes
   describe [F], because that one has canon towns and people in it. If you would rather the game sat there, the map survives;
   the names and the snow-last ordering would change.
2. **Does the open country really pay nothing per kill?** (decision 6). Today a kill pays a bounty in the arena. The setting
   says mortals get no bounty in a break and says nothing I can find about archhumans in the open [?].
3. **The passage's meter.** Keep $3 a second, cut it, or stop the world clock inside and charge the ticket only?
4. **Should the clock run inside a dungeon?** I stopped it. The books have dungeons where time runs differently [C: `b5b` §3],
   which could be a rule-card line later rather than a global rule.
5. **Is two days right for a dropped pack, and is losing it at all too harsh for standard mode?** The current death costs money
   only.
6. **A trunk in your room** — the first storage in the game. Fine? Rooms the size of your rent?
7. **Parties.** The concept draft has a hired party that raises income and lowers growth. Raid-like zones are the natural home
   for it. Parked here; say if it should not be.
8. **Do herds belong?** The Thornback is the first thing in the game that is not an invader and does not want to fight. I think
   an open world needs one; it is also the furthest thing here from the notes.
9. **How much of the city should be shut?** I show one closed gate. More closed doors is more tone and no more work.
10. **Bands.** I put the whole first star in region 1 and stretched 2★ and 3★ over four regions. With the second star at two
    hours [B], is a region per star nearer what you want?

---
## 9. What was and was not checked

- **Read**: `CLAUDE.md`; `design/00`, `01`, `02`, `03`; the tier, drop and merchant sections of `design/06` and the archetype and
  encounter sections of `design/05` (not either document in full); all four mechanics notes in `research/`;
  `game/data/enemies.json`; the `biomes`, `passage`, `town`, `healer`, `night`, `arena`, `camera` and `nether` blocks of
  `balance.json`; `scripts/route.gd`; the head of `scripts/art/biomes.gd` and each kit's prop list; `_enter_town`,
  `_enter_dungeon`, `_new_level`, `_build_town`, `_build_world` and `_on_player_died` in `main.gd`; `save_game.gd`; the service
  list in `ui/town_screen.gd`.
- **Not read**: `enemy.gd`, `player.gd`, the Netherecho scripts, `_scatter_props`, `research/audience-and-comparables.md`,
  `docs/engine-reference/` beyond confirming a navigation page exists. Claims about what those can do are taken from `CLAUDE.md`.
- **Not run**: the game, the bots, the self-test, any screenshot. No file under `game/` was changed, so there was nothing to
  smoke-check.
- **Not measured**: every size, time, price, count and percentage. Walking times are distance divided by the move speed in
  `balance.json`, nothing more.
- **Checked by a script**: `world-v0.json` parses; it has 34 zones and 37 links; every link is listed from both ends; every
  dungeon's host is among its links; every zone can be reached from the Ninth.
- **Untested — needs Brent**: all of it. Above all whether crossing the Stubble is a pleasure (step 1) and whether an
  open-ground fight holds up (step 2).
