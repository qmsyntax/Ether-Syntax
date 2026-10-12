# Loot and equipment v0 — a paper doll, weapon families, ranged weapons, armour, and the catalogue

Draft for Brent to approve or redline, 2026-10-11. Nothing here is built; nothing here has been played. Every number is a first guess.
Tags: **[B]** Brent's ruling, **[C]** read in the books (paraphrased notes only), **[F]** fan source, **[MODEL]** our invention.
Anything untagged inside a section headed [MODEL] is [MODEL]. Every item name, description and effect is original to this
project; no item name from the books is used. Companion data draft (not loaded by the game): `design/data-drafts/items-v2.json`.

Asked for by Brent 2026-10-11: *"have another agent build out a loot list of items etc. We also need more equipment slots to
equip weapons, armor etc. These should affect the melee and ranged options (need to add ranged weapons). Add this to the build target."*

**What this was designed against.** The code as of commit `dbab153` (4 slots, 15 items, 3 enemy kinds); `design/05-affinity-skills-and-combat-v0.md`,
which appeared while I was reading and is itself an unapproved draft — I hook into its poise, Staggered, rear-hit, "Opening" and
"working it off" rules and its seven enemy archetypes, and say so wherever I do; and the health redesign in progress (**one health
bar plus lasting wounds, each with a hidden pool healing must fill**), which I have not seen written down. §5 lists the five
things gear needs from that redesign. Nothing here refers to superficial / structural / catastrophic layers.

---
## 1. Summary

1. **Twelve slots instead of four** [MODEL]: main hand, off hand, ranged, head, body, hands, feet, back, belt, satellite, two trinkets.
2. **Seven melee families**, each with one trait a player can feel in a click-to-attack game: knuckles, daggers, blades, axes, hammers, polearms, great weapons.
3. **The base strike stays single-target** [B]. No weapon cleaves. Big weapons widen your *strike skills* instead.
4. **Five ranged families** that cost no essence: thrown, slings, bows, crossbows, and **flues** — runed pipes that fire your own reflux.
5. **One ranged control scheme**: hold **Shift** and the strike button shoots at the cursor instead of walking to a target. No modes, no swap key.
6. **Armour in three weights.** Light helps you shed reflux and move; medium is plain protection; heavy protects most against *lasting wounds* and holds your heat in.
7. **Shields have no block button** (design/05 rules one out): a shield is a small guard pool that soaks hits from the front and comes back on its own.
8. **Gear is a floor, not a ladder** [B: less than the body]. A shop-bought kit to the best runed kit is about +20%; one ascension is worth more. Nothing has a rank requirement — but the *body* decides how much weight you can wear.
9. **Five tiers**: Salvage, Plain, Fine, Runed, Cursed — plus eight named uniques that bend one rule each and grow with use [C: uniques grow].
10. **The catalogue: 158 pieces of gear** and 33 other things (ammunition, four consumables, trade goods, materials). All 15 existing item ids are kept.
11. **Consumables are few and cost growth** [F: shortcuts stunt growth]: three of the four shrink what the delve teaches you.
12. **First build step**: two new slots, a coat and a sling — about a day's work, and both asks are in the player's hands.

---
## 2. Equipment slots [MODEL]

| # | Slot (id) | Why it exists | What lives on it |
|---|---|---|---|
| 1 | **Main hand** (`weapon` — id kept so saves load) | How your base strike feels | Strike damage, recovery, reach, poise damage, the family trait |
| 2 | **Off hand** (`off_hand`) | The price of a two-hander; the choice between safety and casting | Shield guard, or one small casting effect (sumps, slates) |
| 3 | **Ranged** (`ranged`) | Brent's ask. Its own slot so you never swap sets | Shot damage, interval, range, ammunition |
| 4 | **Head** (`head`) | Wounds to the head are the ones you fear | Wound resistance first, a little armour |
| 5 | **Body** (`body`) | The one big armour decision | Most of your armour, poise, reflux shedding (up or down) |
| 6 | **Hands** (`hands`) | Handling | Strike recovery, shot interval, poise damage, a little guard |
| 7 | **Feet** (`feet`) | Footing | Movement, poise |
| 8 | **Back** (`back`, exists) | Carry capacity is an economic stat [F] | Carry capacity; the starting backpack [B] |
| 9 | **Belt** (`belt`) | Where the few consumables go | Quick slots (1-3), small carry or handling |
| 10 | **Satellite** (`satellite`, exists) | Essence throughput is an item you find or buy [B] | Essence per second |
| 11-12 | **Trinket ×2** (`trinket`, `trinket2`) | One small effect each [C] | Affinity cost or damage, reflux, wounds, tempering, Netherecho |

**Rules.**
- **Two-handed** weapons (polearms, great weapons) fill main hand and off hand. Equipping one sends whatever was in the off hand to the pack, and is refused if the pack cannot take it. Bows, crossbows and staff slings need **both arms** to shoot but sit in the ranged slot, so they do not empty your hands.
- **A lost arm** [existing rule]: the main-hand weapon counts for nothing while the striking arm is gone. Extended: a two-hander or a both-arms ranged weapon cannot be used with either arm gone; one-handed ranged weapons work at 60% damage; a shield still guards. Knuckles are a pair and keep working at the off-hand rate.
- **`trinket2`** accepts any item whose slot is `trinket`. The same item cannot be worn twice.
- **No rank requirements on anything.** A one-star can wear any satellite [B]; the same goes for all gear. What limits you is weight (below).
- **A third trinket slot is deliberately left out.** Canon sets are three items fused with a binding gem [C]; that system is parked, and a third slot is its natural home.

**A new character starts wearing** [B: backpack, no storage ring; no satellite] `canvas_pack` (back), **Patched Coat** (body),
**Street Boots** (feet), **Rope Belt** (belt, one quick slot), **Cord Sling** (ranged), and carries two **Field Dressings**. Bare fists, as now.
So every character can shoot something from the first minute, and the first shop visit has seven empty slots to think about.

### 2.1 Keeping gear below the body [B]

1. **The ladder is flat.** Salvage is 8% under Plain; Fine is 6% over; a rune adds one line of at most 10% [C: artifacts carry one effect, usually ≤10%]. Worst-to-best on a weapon's main number is about 20%. The big jump is *naked → equipped at all*, which happens in the first shop visit, as it should: a sword beats a fist.
2. **Nothing on gear scales with stars.** Weapons multiply the body's own strike (`balance.json` `melee_damage`); if ascension later raises that, every weapon rises with it and none overtakes it. Crossbows and flues do *flat* damage on purpose — strong at one star, ordinary at three.
3. **Hard caps on every percentage** (§5): armour 30%, wound resistance 50%, ability cost −25%, and so on. A full Plain medium kit sits at 12% armour; the cap is a ceiling you approach, not a target.
4. **The body carries the gear.** Worn weight is free up to **14 kg at one star, +8 kg per star** (22, 30...). Each kilogram over slows you 1.5%, to at most 30%. A one-star in full plate (about 26 kg, more with a maul) walks like a mortal; a three-star does not notice it. Heavy armour is something you grow into.
5. **One reference check**: Plain kit → best Runed kit is roughly +15-20% damage and +10 points of armour. One ascension is ×1.3 health, a second essence tank, and +1 stage on every ability and technique. The body wins by a wide margin, at every rank.

---
## 3. Weapons [MODEL]

### 3.1 Melee families

Numbers are the **Plain** tier, as multipliers on today's bare-handed strike (60 damage, 0.45 s recovery, 2.3 m reach). "Poise" multiplies
the base strike's 20 poise damage from design/05 §6.3. Bare fists are 1.00 / 1.00 / +0 / 1.0.

| Family | Hands | Damage | Recovery | Reach | Poise | Feels like | Trait |
|---|---|---|---|---|---|---|---|
| **Knuckles** | 1 (a pair) | ×1.20 | ×0.90 | +0 | ×0.8 | Your fists, improved. The caster's weapon | **Working hands**: a landed strike sheds 2 reflux, not 1 (design/05 "working it off"). Still works with the striking arm gone |
| **Daggers** | 1 | ×1.18 | ×0.80 | +0 | ×0.5 | Fastest clicks, weakest stagger | **Back work**: the rear-hit bonus is doubled (+60%; design/05 rear hits) |
| **Blades** | 1 | ×1.40 | ×1.00 | +0.3 m | ×1.0 | The honest middle | **Turn aside**: a 12-point guard of its own, back after 2 s (see shields) |
| **Axes, cleavers** | 1 | ×1.60 | ×1.15 | +0 | ×1.25 | Slower, and the hit keeps working | **Open up**: each hit adds 1 Bleeding (5 a second, 4 s, 5 stacks). Bleeding you caused pays talents [B: DoTs pay out] |
| **Hammers, maces** | 1 | ×1.70 | ×1.30 | +0 | ×2.0 | Two hits and it reels | **Dent**: enemy front armour and shields count half (Brute 30% → 15%, Pavise 80% → 40%) |
| **Polearms** | 2 | ×1.50 | ×1.20 | +1.2 m | ×1.0 | You hit first, from where they cannot | **Tip**: +20% to a target further away than bare-handed reach |
| **Great weapons** | 2 | ×2.40 | ×1.60 | +0.6 m | ×2.5 | One decision per swing | **Follow-through**: your *strike skills* reach 0.6 m further and sweep 20° wider. The base strike stays single-target [B] |

Damage per second, relative to fists: knuckles 1.33, daggers 1.48, blades 1.40, axes 1.39 (+bleed), hammers 1.31 (+stagger), polearms 1.25
(1.50 at the tip), great 1.50 (no shield, and overkill is wasted). Deliberately close: the families differ in *how*, not *how much*.

**What the brief asked for that a ruling forbids.** The request suggested "single target vs cleave" as a family property. Brent
ruled on 2026-09-23 that area hits belong to skills and never to the base attack. I kept the ruling: no family cleaves, and the
great weapon's area lives in the strike skill it is used with. See §11 Q1 if Brent wants one exception.

**Traits and build timing.** Reach, speed, damage and two-handedness work on the code as it is today (`weapon_stat`, `reach_now`,
`_strike_target`). Tip needs one distance check. The other five traits depend on things design/05 introduces (poise, rear hits,
enemy front armour, the status set, "working it off") and should ship after its step 2. **Bleeding is one status I am adding** to
design/05's set; that document does not define it, though its Brine Blood technique already mentions bleeding.

### 3.2 Ranged families

A basic shot costs **no essence and makes no reflux**. Body-thrown families do `ranged_damage` (new `balance.json` key, 50) × the
weapon's multiplier; crossbows and flues do a flat number. Shots go through `deal_damage` tagged `ranged`, so talents see them.

| Family | Damage | Interval | Range | Moving while firing | Ammunition | Poise | Feels like / trait |
|---|---|---|---|---|---|---|---|
| **Thrown** (knives, hatchets, javelins) | ×0.8-1.9 | 0.45-0.9 s | 7-11 m | Full speed | A **brace**: 3-8 throws per fight; all of them are back when the fight ends. Nothing to buy | 10-30 | A burst before the melee. Fits wind's Slipstream |
| **Slings** | ×0.9-1.3 | 0.7-1.1 s | 12-16 m | 70% | **Stones are free and endless.** Lead shot (bought, not recovered) hits 25% harder | 25 | The weapon you start with. Never dry; good at interrupting |
| **Bows** | ×1.35-1.7 | 0.55-0.8 s | 14-18 m | 45% | **Arrows**, bought in bundles of 20, weigh 0.04 kg each; half come back after the fight | 10 | Sustained damage if you stand. **Long sight**: +2% per metre past 6 m, up to +20% |
| **Crossbows** | 80-240 flat | 1.2-3.6 s | 12-22 m | Full when loaded, 50% reloading | **Bolts**, cases of 12, 0.08 kg each; 60% come back | 40-60 | One instant, heavy, piercing shot — then a wait. **Loaded**: it stays spanned while you fight |
| **Flues** | 55-70 flat | 0.55-0.6 s | 9-10 m | 80% | **Your own reflux**: each shot burns 3-4 from your hottest affinity. Below that it clicks dry | 10 | Cast, then cough the heat out as shot. Our setting-flavoured family: a runed pipe [C: enchanting is runes written onto items] |

Reference: a Plain bow standing still is about 107 damage a second against 133 for bare fists — ranged is safer, so it is weaker.
A flue shot is tinted with the affinity it vents and takes fire's Heat bonus (design/05 §2.2) when it vents fire — and cools you as it does.
Weapon shots never apply an affinity's status (no Soaked, no Live marks), and they stop on stone and on a Pavise, like everyone's shots.

**How a shot works — the recommended scheme: hold Shift to shoot.**
- A new action, `ranged_stance`, **held**, default **Shift**, rebindable like the rest. While it is held, the strike button (LMB) **fires the ranged weapon toward the cursor** instead of walking to a target; hold LMB to keep firing. Release Shift and you are back to click-to-attack. There is no mode to forget.
- **Aim**: the shot flies in a straight line from you toward the cursor's ground point; if the cursor is on an enemy, toward that enemy. It hits the first enemy in its path and dies at maximum range. No homing, no lead. A thin ring on the ground shows the range while Shift is held.
- **Moving**: WASD still works in the stance, at the family's speed factor.
- **Timing**: half the interval is the draw (the shot leaves at the end of it), half is recovery. A crossbow is the exception: it fires at once, then **reloads only while Shift is held** (or by itself out of combat).
- **One pair of hands**: a shot delays your next strike by 0.25 s and a strike delays your next shot by 0.25 s, so weaving is possible and not free.
- **Overcharge stays on RMB** and stays melee. (Later, cheaply: RMB in the stance as an overcharged throw for the thrown family — the books' "tension" idea [C] — at the same health price.)

| Alternative | Why not |
|---|---|
| Swap key (two weapon sets) | A hidden mode; the player clicks an enemy and the wrong thing happens |
| Automatic by distance | Takes away the decision to walk in; undefined at middle range |
| Right mouse button | Taken by overcharge, which design/05 keeps as the health-as-ammunition route |
| A slot on the 1-6 bar | Costs a skill slot, and skills are the scarce thing [B: too many plates] |

**Smallest version that proves it** (build step 1): the `ranged` slot, the Cord Sling, Shift + LMB spawning today's `Projectile` toward
the cursor every 0.8 s for 45 damage at 70% movement, a range ring, no ammunition, no draw animation. If that feels wrong in the hand, nothing else in §3.2 is worth building.

### 3.3 Shields and the off hand

design/05 §6.3 rules out a block or parry button and any timing window under a third of a second. So, in the smallest workable form:

- **Guard** is a pool on the shield (18-80 points). A hit arriving from your **front 120°** drains the guard before your health (after armour). Heavy attacks drain double.
- It **refills in full** after `block_recover_s` (2-6 s) without being hit.
- When a hit empties it, the guard is **broken**: you are staggered 0.4 s (design/05's player stagger) and it returns after the recovery time.
- The guard is **down while you fire a both-arms ranged weapon**, and for half a second after.
- Shown as a short arc in front of the character that thins as it drains. Facing follows your target or your movement, so running away turns your guard away — the same anti-kiting pressure design/05 is after.
- **"Parry" without timing**: bucklers and the blade family's Turn aside are tiny guards that come back fast (2 s) — one hit soaked per exchange, forever, rather than a wall that breaks.
- **Sumps and slates** are the caster's off hand: one small effect (less reflux per essence, or lower costs), no guard.

---
## 4. Armour [MODEL]

Three weights, four slots. Numbers are a full **Plain** set of one weight.

| | Light | Medium | Heavy |
|---|---|---|---|
| **Armour** (percent of every hit removed) | 6 | 12 | 20 |
| **Wound resistance** (percent chance a wounding hit leaves no wound) | 0 | 12 | 26 |
| **Poise** (yours is 100) | +0 | +12 | +33 |
| **Worn weight** | 3.1 kg | 10.9 kg | 25.4 kg |
| **Reflux** | Sheds 9% faster | — | Sheds 8% slower (plate holds heat) |
| **Movement** | +3% (soft shoes) | — | See the worn-weight rule |
| **Typical price** | $700 | $1,500 | $4,100 |
| **Who wants it** | Casters, wind, anyone at one star | The default | Two stars and up; earth; **fire, which wants its heat kept** (design/05 §2.2); anyone tired of carrying wounds home |

**The real trade-offs.**
- **Weight against the body, not the pack.** Worn gear does not count against carry capacity (as now), but everything worn except the pack counts toward the worn-weight allowance (§2.1). Medium armour with a blade and shield is about 17 kg: 4% slow at one star, free at two. Heavy with a maul is 33 kg: 28% slow at one star, 16% at two, 4% at three.
- **Heavy armour is mostly about wounds.** Against the health bar it is only 8 points better than medium. What it buys is coming home without a lasting wound — which, with wounds that cut maximum health until mended, is the thing that actually ends a delve early.
- **Reflux.** Light cloth breathes; plate does not. A water or lightning caster in plate will feel it. A fire character will buy plate *because* of it.
- **Wind** wants to keep moving (Slipstream) and so wants to stay under its allowance. **Earth** stands still and braces, and loses least.
- **Salvage armour is heavy for what it is** (the Invader's Breastplate is 18 kg for 9 armour) — worth wearing, rarely worth carrying out to sell. That is a hauling decision the pack screen should make visible ($ per kg).

**Per slot.**

| Slot | Light (kg) | Medium (kg) | Heavy (kg) | The slot's own job |
|---|---|---|---|---|
| Head | armour 1, shed +3% (0.3) | armour 2, wound resist 3 (1.2) | armour 4, wound resist 6, poise +5 (3.0) | Wound resistance |
| Body | armour 3, shed +6% (2.0) | armour 6, wound resist 5, poise +8 (7.0) | armour 10, wound resist 12, poise +20, shed −8% (16.0) | Armour and poise |
| Hands | armour 1, recovery −3% (0.2) | armour 2, wound resist 2 (0.9) | armour 3, wound resist 4 (2.4) | Handling |
| Feet | armour 1, move +3% (0.6) | armour 2, wound resist 2, poise +4 (1.8) | armour 3, wound resist 4, poise +8 (4.0) | Footing |

Mixing weights is allowed and expected: a plate cuirass over soft shoes is a perfectly good one-star compromise.
What armour looks like on the model is an art task of its own (the creator's coats are cosmetic today); step 1 changes numbers only.

---
## 5. Stats [MODEL]

**A** = added across all equipped items; **M** = multiplied across them. "Slot" means the stat is read from one slot only.
Caps apply to the gear total, before tempering. Seven keys exist in code today; everything else is new.

| Key | Meaning | Unit | Stack | Sensible range per item | Cap on gear total | In code? |
|---|---|---|---|---|---|---|
| `melee_damage_mult` | Base strike damage | × | main hand only | 1.10-2.6 | — | **yes** |
| `melee_cooldown_mult` | Time between base strikes (below 1 is faster) | × | main hand × other slots (M) | 0.78-1.6 weapon; 0.92-0.97 gloves | other slots ≥ 0.90 | **yes** (weapon only) |
| `melee_range_bonus` | Added reach | m | main hand only | 0-1.6 | — | **yes** |
| `carry_capacity` | Weight the pack can hold | kg | A | 4-140 | — | **yes** |
| `satellite_rate` | Essence per second | essence/s | A (one slot) | 0.5-3 | — | **yes** |
| `cost_mult` | Essence cost of every ability | × | M | 0.88-0.96 | ≥ 0.75 | **yes** |
| `reflux_shed_mult` | How fast reflux leaves | × | M | 0.85-1.15 | ≤ 1.40 | **yes** |
| `strike_poise_mult` | Poise damage of the base strike (× family × 20) | × | M | 1.05-1.15 | — | new (needs design/05 poise) |
| `armour` | Share of every hit removed before health | % points | A | 0-12 | 30 | new |
| `wound_resist` | Chance a hit that would leave a lasting wound does not | % points | A (adds with design/05's Seared Shut) | 1-14 | 50 | new (needs the health redesign) |
| `poise` | Added to the player's poise of 100 | points | A | 4-20 | +60 | new (design/05) |
| `max_health` | Maximum health | points | A | −10 to −8 (tolls only, so far) | — | new |
| `move_speed_mult` | Walking speed | × | M | 0.85-1.10 | ≤ 1.12 | new on gear (tempering has it) |
| `block`, `block_recover_s` | Guard pool; seconds unhit before it refills | points; s | A; lowest wins | 5-80; 2-6 | 100 | new |
| `ranged_damage_mult` | Shot damage × `ranged_damage` | × | ranged slot × M elsewhere | 0.8-1.9 | — | new |
| `ranged_damage_flat` | Shot damage that ignores the body | points | ranged slot | 55-240 | — | new |
| `ranged_interval`, `ranged_interval_mult` | Seconds between shots; multiplier from other slots | s; × | slot; M | 0.45-3.6; 0.94-0.96 | mult ≥ 0.85 | new |
| `ranged_range`, `ranged_range_mult` | How far a shot flies | m; × | slot; M | 7-22 | — | new |
| `ranged_move_factor`, `ranged_poise`, `pierce`, `brace`, `vent_per_shot` | Per-weapon overrides of the family's defaults (§3.2) | — | ranged slot | see §3.2 | — | new |
| `cost_mult_<affinity>` | Essence cost of that affinity's abilities | × | M | 0.90-0.92 | ≥ 0.75 with `cost_mult` | new |
| `ability_damage_mult_<affinity>` | Damage of that affinity's abilities | × | M | 1.06 | ≤ 1.15 | new |
| `reflux_gain_mult` | Reflux left per essence spent | × | M | 0.92-0.95 | ≥ 0.80 | new |
| `reflux_pain_shift` | Reflux pain starts this much later | points | A | 5 | +10 | new (rune only) |
| `wound_mend_mult` | Healing poured into a wound's hidden pool counts for more | × | M | 1.10 | ≤ 1.25 | new (health redesign) |
| `regen_mult` | Natural healing between fights | × | M | 0.80 | — | new (a toll) |
| `temper_cost_mult`, `temper_progress_mult` | Health a training session costs; progress it gives | × | M | 0.90; 1.08 | ≥ 0.80; ≤ 1.15 | new |
| `nether_leash_bonus` | Projection's leash | m | A | 2 | +5 | new |
| `projection_hp_bonus` | Projection's life (base 12) | points | A | −3 to +3 | +6 | new |
| `wisp_reach_bonus`, `nether_strike_mult` | Wisp gathering reach; soul strike damage | m; × | A; M | 0.4; 1.10 | +0.8; ≤ 1.2 | new |
| `quick_slots` | Consumables usable from the belt | count | A | 1-3 | 3 | new |
| `worn_allowance` | Extra worn weight carried free | kg | A | 4 | +6 | new |
| `satellite_reflux_mult` | Reflux a satellite's flow leaves [B: it does leave some] | × | M | 1.5 (a toll) | — | new |
| `aura_gain_mult` | Hidden growth earned (never shown as a number) | × | M | 0.90 (a toll) | — | new |
| `bounty_mult`, `rear_taken_mult`, `ammo_recover_add` | Kill bounty cash; damage you take from behind; share of ammunition recovered | ×; ×; fraction | M; M; A | 1.10; 1.25; +0.15 | — | new |
| `bleed_stacks_bonus`, `stagger_time_bonus`, `tip_bonus_add`, `opening_mult_add` | Four cursed-item modifiers of a family trait or a design/05 rule | — | A | one item each | — | new |

**What gear needs from the health redesign** (five things; none depends on how the pools work inside):
1. One place where an incoming hit is scaled before it reaches health — `armour` multiplies in beside tempering's `incoming_mult`.
2. A yes/no moment, "this hit would leave a lasting wound", where `wound_resist` gets a roll.
3. A maximum-health number gear can add to or subtract from.
4. A multiplier on healing that goes into a wound's hidden pool (`wound_mend_mult`).
5. A count of lasting wounds currently carried (one unique reads it).

**Existing data this exposes.** `river_stone` says it discounts water abilities, but its stat is the global `cost_mult` — today it
discounts everything. The draft gives it `cost_mult_water`. `cooling_coil` sheds reflux 50% faster, five times anything else
here; the draft sets it to 15%. Both are flagged in the draft's `_note`; both are Brent's call.

---
## 6. Rarity, affixes and special items [MODEL]

### 6.1 Tiers

| Tier | Name colour | What it adds | Where it comes from | Sells for |
|---|---|---|---|---|
| **0 Salvage** | grey | Main number 8% under Plain; often heavier | What invaders carried; early walls | Almost nothing |
| **1 Plain** | bone white | The baseline every table in §3-§4 is written at | The merchant; mid walls | Half its price (existing rule) |
| **2 Fine** | grey-green | Main number +6%, a little lighter; can take one rune | Late walls, commanders, full-clear rewards, one shelf at the merchant | Half |
| **3 Runed** | pale blue | A Fine item with **one rune** written on it — one clean line, at most 10% [C] | Commanders, full clears, deviants; rarely the merchant; later the runesetter | Half |
| **4 Cursed** | old gold | An artifact: one stronger or stranger effect, **and a toll** | Commanders (3%), full clears, deviants. Never sold in a shop | Half — if you can find a buyer |
| **Unique** | old gold, named | A cursed item that bends one rule and **grows** with a stated condition, with plateaus [C] | Full clears (rare), deviants, feats | — |

**The catalogue is fixed, not rolled.** Every runed and cursed item in §7 is a specific item with its numbers baked in. The pack
stores item ids today (`Array[String]`); random affixes would need per-item instances and a save-format change. The rune table
below is the vocabulary the fixed items are written in, so that rolling can be added later without renaming anything.

### 6.2 Runes (written onto Fine gear) [C: enchanting = runes on items; the runes themselves are ours]

A runed item is named *rune word + base name* ("Venting Brass Flue").

| Rune word | Goes on | Effect | Tied to |
|---|---|---|---|
| Keen | main hand | Strike damage +5% | combat |
| Quick | main hand, hands | Strike recovery −5% | combat |
| Long | main hand | Reach +0.2 m | combat |
| Staggering | main hand, hands | Base strike poise damage +15% | design/05 poise |
| True | ranged | Shot damage +6% | ranged |
| Light-Drawn | ranged | Shot interval −6% | ranged |
| Stubborn | main hand, off hand, body, feet | Your poise +10 | design/05 poise |
| Warded | off hand, head, body | Wound resistance +6 | **wounds** |
| Knitting | body, trinket | Wound mending +10% | **wounds** |
| Sure-Footed | feet | Movement +3% | — |
| Hauler's | back, belt | Carry +6 kg | hauling |
| Venting | main hand, ranged, body, trinket | Reflux sheds 10% faster | **reflux** |
| Cool-Running | off hand, hands, trinket | 7% less reflux per essence spent | **reflux** |
| Late-Aching | head, trinket | Reflux pain starts 5 points later | **reflux** |
| Tide- / Cinder- / Stone- / Gale- / Storm-Written | off hand, head, trinket | That affinity's abilities cost 8% less | **affinities** |
| Tide- / Cinder- / Stone- / Gale- / Storm-Edged | main hand, ranged, hands | That affinity's abilities do 6% more | **affinities** |
| Yard-Worn | body, hands, trinket | A tempering session costs 10% less health | **tempering** |
| Lesson-Keeping | head, trinket | A tempering session gives 8% more progress | **tempering** |
| Tethered | head, trinket | Projection's leash +2 m | **Netherecho** |
| Second-Skinned | body, trinket | Projection's life +3 | **Netherecho** |
| Beckoning | hands, trinket | Wisps come from 0.4 m further | **Netherecho** |
| Echo-Edged | main hand, trinket | Soul strike +10% | **Netherecho** |

Twenty-two runes; thirteen are used by catalogue items so far. The other nine (Cool-Running, Late-Aching, the two affinity runes,
Yard-Worn, Lesson-Keeping, Second-Skinned, Beckoning, Echo-Edged) exist for the runesetter (§8.5) and for later items.

### 6.3 Cursed items and their tolls

In the books "cursed item" is simply the word for an artifact [C]; a drawback is not part of the definition. **The toll is ours**
[MODEL], added because the brief asks for a real cost and because it lets a cursed effect be larger than a rune without breaking
"less than the body". A toll is always visible on the item — except Safe Hands, which is described only the way the notebook
describes aura: qualitatively.

| Toll | Cost |
|---|---|
| **Leeching** | Maximum health −8 to −10 while worn |
| **Thirsty** | Reflux sheds 15% slower |
| **Safe Hands** | Hidden growth earned is a tenth smaller [F: shortcuts stunt growth] — money now, a weaker star later |
| **Slow Mending** | Natural healing a fifth slower |
| **Heavy** | Weighs about double; the worn-weight rule does the rest |
| **Reluctant** | You move 5% slower |
| **Blinkered** | Ranged weapons reach 30% less far |
| **Turned Back** | Hits from behind do 25% more to you |
| **Running Hot** | A satellite's flow leaves 50% more reflux |
| **Thin Soul** | The projection has 3 less life |
| *Bound* (reserved) | Cannot be removed except by a runesetter, for a fee. No item uses it yet |

Twelve cursed items are in the catalogue (six weapons, a helm, a coat, shoes, a satellite, two trinkets).

### 6.4 Uniques

Each bends one rule, shows its growth condition, and grows in steps to a cap [C: growth with diminishing returns and plateaus].
Each needs a small effect script (`game/scripts/items/<id>.gd`, a `TalentEffect` — the project already says items will be effects).

| Unique | Slot | The rule it bends | Grows with |
|---|---|---|---|
| **Marrow Spike** | main hand (dagger) | Every base strike costs 1 health and hits 25% harder. Health as ammunition on the *plain* attack | Your own health spent through it (to +45%) |
| **Long Refusal** | off hand (shield) | The guard never breaks: damage past the pool becomes reflux on your hottest affinity instead of reaching health. If that affinity locks, the guard drops for 8 s | Damage it has turned (pool 45 → 80) |
| **Dead Man's Lung** | ranged (flue) | With no reflux to burn it still fires — for 2 health a shot | Kills made with a dry shot (damage 70 → 100) |
| **Quiet Mote** | satellite | Its flow leaves **no reflux** (every other satellite does [B]) | Passages cleared in full without sitting to meditate (1 → 2 essence/s) |
| **Borrowed Face** | head | In the Netherecho, docile constructs never turn on you; hostile ones notice you from half as far | Constructs subdued while wearing it (leash +0 → +3 m) |
| **Stitchwork Coat** | body | +3 armour for every lasting wound you are carrying | Lasting wounds mended without a healer (counts 4 → 6 wounds) |
| **Creditor's Ring** | trinket | Works only while you are in debt: +10% damage, −10% cost | Debt paid off in full (to 15%) |
| **Undertaker's Ledger** | trinket | Overkill is banked (up to 100) and added to your next base strike. (Talents still ignore overkill [B]) | Commanders killed (bank 100 → 200) |

**Parked, on purpose**: three-item sets and binding gems [C]; the soul construct eating one regular and one unique item [C];
gear being destroyed [C]. All three fit this structure later; none is needed to prove it.

---
## 7. The loot list [MODEL]

All names and descriptions are ours. Tier, weight (kg), price ($; gear sells for half, loot for full — existing rule).
"Family" traits are in §3 and are not repeated per row. Bold text in a stats cell is an effect that needs its own code.
Existing items keep their ids, names and descriptions; three have changed numbers (§5, last paragraph).

**Counts.** Gear by slot and tier:

| Slot | Salvage | Plain | Fine | Runed | Cursed | Unique | Total |
|---|---|---|---|---|---|---|---|
| Main hand | 7 | 9 | 8 | 7 | 6 | 1 | 38 |
| Ranged | 2 | 7 | 7 | 5 | 0 | 1 | 22 |
| Off hand | 1 | 4 | 4 | 2 | 0 | 1 | 12 |
| Head | 2 | 3 | 3 | 2 | 1 | 1 | 12 |
| Body | 3 | 3 | 3 | 3 | 1 | 1 | 14 |
| Hands | 2 | 3 | 3 | 2 | 0 | 0 | 10 |
| Feet | 2 | 3 | 3 | 2 | 1 | 0 | 11 |
| Back | 1 | 2 | 2 | 1 | 0 | 0 | 6 |
| Belt | 1 | 2 | 2 | 0 | 0 | 0 | 5 |
| Satellite | 1 | 1 | 2 | 0 | 1 | 1 | 6 |
| Trinket | 0 | 10 | 8 | 0 | 2 | 2 | 22 |
| **All gear** | **22** | **47** | **45** | **24** | **12** | **8** | **158** |

Plus 4 ammunition, 4 consumables, 16 loot and trade goods (2 of them catalysts), 9 materials: **191 entries** in all.
Melee by family: knuckles 5, daggers 5, blades 6, axes 5, hammers 5, polearms 6, great weapons 6. Ranged: thrown 5, slings 4,
bows 5, crossbows 4, flues 4. Off hand: shields 8, sumps and slates 4.

**Consumables, and how they respect "shortcuts stunt growth"** [F; spec §4 already counts "no consumables used" toward risk]:
there are four, the belt holds one to three, and three of the four carry an **aura penalty** — each use makes the rest of that
delve teach 10% less (hidden; the notebook only says the star feels lighter). The Field Dressing is exempt: it is slow, works only
out of a fight, and is ordinary first aid rather than a shortcut. Nothing here heals in combat, restores a wound, or raises a
star. Drugs keep their ordinary downsides [B]: the draught leaves reflux, the salt deepens the wounds it hid.
Skill scrolls and tempering manuals (design/05) are *learned*, not drunk, and are not consumables in this sense; they appear in
the drop tables as "a scroll / manual this character can use" and are not catalogued here.

### 7.1 Main hand (38)

| id | Name | Family | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `knuckle_wraps` | Knuckle Wraps | knuckles | Salvage | 0.2 | 25 | strike x1.10, recovery x0.90 | Cloth and tape. Saves the skin, not the bone. |
| `iron_knuckles` | Iron Knuckles | knuckles | Plain | 1 | 350 | strike x1.20, recovery x0.90 | Banded iron over the fist. Honest work. |
| `notched_dusters` | Notched Dusters | knuckles | Fine | 1.3 | 1,100 | strike x1.27, recovery x0.90 | Each notch was somebody. The maker left room for more. |
| `venting_dusters` | Venting Notched Dusters | knuckles | Runed | 1.3 | 3,200 | strike x1.27, recovery x0.90, shed x1.10 | The runes run warm after a cast. That is the heat leaving. |
| `debtors_knuckles` | Debtor's Knuckles | knuckles | Cursed | 1.6 | 9,000 | strike x1.32, recovery x0.85, health -8, **Faster and harder than any plain pair.**, toll: Leeching | They hit as if something were owed. Something is. |
| `serrated_dagger` | Serrated Dagger | dagger | Salvage | 1.2 | 90 | strike x1.10, recovery x0.80 | An invader's blade. Light, quick, and legal to keep when it comes out of a passage. |
| `gutting_knife` | Gutting Knife | dagger | Plain | 0.6 | 260 | strike x1.18, recovery x0.80 | Made for fish. Nobody checks. |
| `needle_dirk` | Needle Dirk | dagger | Fine | 0.5 | 950 | strike x1.25, recovery x0.78 | Narrow enough to find the gap. You still have to find the gap. |
| `quick_needle_dirk` | Quick Needle Dirk | dagger | Runed | 0.5 | 2,900 | strike x1.25, recovery x0.74 | It is back in your hand before you have decided. |
| `notched_hanger` | Notched Hanger | blade | Salvage | 1.4 | 110 | strike x1.29, reach +0.3 m | A short sword that has been used as a pry bar, and remembers. |
| `militia_blade` | Militia Blade | blade | Plain | 1.5 | 480 | strike x1.40, reach +0.3 m | Stamped, numbered, issued, lost, sold. |
| `commander_blade` | Commander's Blade | blade | Fine | 3.5 | 1,800 | strike x1.60, reach +0.5 m | Long, balanced, and made for someone taller than you. |
| `duelling_sword` | Duelling Sword | blade | Fine | 1.3 | 1,900 | strike x1.48, recovery x0.95, reach +0.4 m | Built for one opponent and a referee. Passages supply neither. |
| `keen_duelling_sword` | Keen Duelling Sword | blade | Runed | 1.3 | 4,200 | strike x1.55, recovery x0.95, reach +0.4 m | The edge is written on as well as ground. |
| `bailiffs_sabre` | Bailiff's Sabre | blade | Cursed | 1.6 | 12,000 | strike x1.50, reach +0.4 m, bounties x1.10, hidden growth x0.90, **Kill bounties pay a tenth more.**, toll: Safe Hands | It prefers work that pays. It will see that you do too. |
| `invader_cleaver` | Invader's Cleaver | axe | Salvage | 5 | 420 | strike x1.45, recovery x1.20 | Too heavy for the thing that carried it. Slow, and it ends arguments. |
| `felling_axe` | Felling Axe | axe | Plain | 2.6 | 420 | strike x1.60, recovery x1.15 | The tree never fought back. Adjust your expectations. |
| `bearded_axe` | Bearded Axe | axe | Fine | 2.4 | 1,500 | strike x1.70, recovery x1.12 | The hooked lower edge is for shields. Or ankles. |
| `staggering_bearded_axe` | Staggering Bearded Axe | axe | Runed | 2.4 | 3,600 | strike x1.70, recovery x1.12, poise dmg x1.15 | Things it hits take a moment to remember where they were. |
| `butchers_share` | Butcher's Share | axe | Cursed | 2.8 | 11,000 | strike x1.70, recovery x1.12, +1 bleed stack, natural healing x0.80, **Each hit opens two bleeding stacks, not one.**, toll: Slow Mending | The cut is generous. The butcher keeps a portion. |
| `fence_post_club` | Fence-Post Club | hammer | Salvage | 3 | 60 | strike x1.56, recovery x1.30 | Somebody's boundary dispute, repurposed. |
| `flanged_mace` | Flanged Mace | hammer | Plain | 3.2 | 520 | strike x1.70, recovery x1.30 | Six flanges. It does not care which one arrives. |
| `lead_cored_mace` | Lead-Cored Mace | hammer | Fine | 3.6 | 1,700 | strike x1.80, recovery x1.28 | Heavier than it looks, which is the entire design. |
| `stubborn_lead_cored_mace` | Stubborn Lead-Cored Mace | hammer | Runed | 3.6 | 3,300 | strike x1.80, recovery x1.28, poise +10 | Swinging it plants your feet for you. |
| `assessors_gavel` | Assessor's Gavel | hammer | Cursed | 3.4 | 10,500 | strike x1.80, recovery x1.28, stagger +0.5 s, shed x0.85, **Enemies it staggers stay staggered half a second longer.**, toll: Thirsty | When it comes down, proceedings stop. |
| `boar_stick` | Boar Stick | polearm | Salvage | 2.2 | 90 | strike x1.38, recovery x1.20, reach +1.2 m, two-handed | A pole, a point, and a crossbar so the boar stops there. |
| `ash_spear` | Ash Spear | polearm | Plain | 2.4 | 450 | strike x1.50, recovery x1.20, reach +1.2 m, two-handed | The oldest idea there is: be further away than the other one. |
| `wall_hook` | Wall-Hook | polearm | Plain | 3.2 | 600 | strike x1.45, recovery x1.25, reach +1.4 m, two-handed | For pulling things off ramparts. Works at ground level too. |
| `partisan` | Partisan | polearm | Fine | 2.8 | 1,800 | strike x1.59, recovery x1.18, reach +1.3 m, two-handed | A spear that went to a good school. |
| `long_partisan` | Long Partisan | polearm | Runed | 2.8 | 4,000 | strike x1.59, recovery x1.18, reach +1.5 m, two-handed | A hand's width longer than it measures. |
| `pike_of_the_last_rank` | Pike of the Last Rank | polearm | Cursed | 4.5 | 9,500 | strike x1.59, recovery x1.20, reach +1.6 m, tip bonus +20%, move x0.95, two-handed, **The bonus for striking at the tip is doubled.**, toll: Reluctant | Carried by the one who stood behind everyone else. It has opinions about advancing. |
| `quarry_maul` | Quarry Maul | great | Salvage | 8 | 140 | strike x2.20, recovery x1.60, reach +0.6 m, two-handed | It broke stone for forty years. You are softer. |
| `war_maul` | War Maul | great | Plain | 7.5 | 700 | strike x2.40, recovery x1.60, reach +0.6 m, two-handed | One swing, one decision, no revisions. |
| `greatblade` | Greatblade | great | Plain | 5.5 | 850 | strike x2.30, recovery x1.50, reach +0.8 m, two-handed | A plain yard and a half of steel. Both hands, all of your attention. |
| `tithe_cutter` | Tithe-Cutter | great | Fine | 5.2 | 2,600 | strike x2.45, recovery x1.48, reach +0.8 m, two-handed | Takes a tenth of whatever stands in front of it. Sometimes more. |
| `keen_tithe_cutter` | Keen Tithe-Cutter | great | Runed | 5.2 | 5,800 | strike x2.57, recovery x1.48, reach +0.8 m, two-handed | The fuller is full of small careful writing. |
| `landlord` | Landlord | great | Cursed | 14 | 14,000 | strike x2.60, recovery x1.60, reach +0.6 m, opening +x1.0, two-handed, **A strike on a staggered enemy does triple, not double.**, toll: Heavy | It takes everything, and it is never satisfied with the state of the place. |
| `marrow_spike` | Marrow Spike | dagger | Unique | 0.7 | 26,000 | strike x1.25, recovery x0.78, **Each base strike costs 1 health and hits 25% harder (grows to 45%). The health is paid even on a miss.**, grows with your own health spent through it | A sliver of something's thighbone. It asks a little of yours. |

### 7.2 Ranged (22)

| id | Name | Family | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `brace_of_nails` | Brace of Nails | thrown | Salvage | 0.6 | 20 | shot x0.80, every 0.45 s, 7 m, brace 8 | Six-inch roofing nails. They fly badly and arrive anyway. |
| `throwing_knives` | Throwing Knives | thrown | Plain | 0.9 | 300 | shot x1.00, every 0.50 s, 8 m, brace 6 | Six, balanced. You will get most of them back. |
| `camp_hatchets` | Camp Hatchets | thrown | Plain | 2.1 | 380 | shot x1.50, every 0.80 s, 7 m, brace 3, poise dmg 30 | Three. For kindling, officially. |
| `short_javelins` | Short Javelins | thrown | Fine | 2.7 | 1,300 | shot x1.90, every 0.90 s, 11 m, brace 3, pierce 1 | Three. Each goes through the first thing and has a word with the second. |
| `true_throwing_knives` | True Throwing Knives | thrown | Runed | 0.9 | 2,900 | shot x1.06, every 0.50 s, 8 m, brace 6 | They correct themselves a little. Do not ask how. |
| `cord_sling` | Cord Sling | sling | Plain | 0.1 | 40 | shot x0.90, every 0.80 s, 12 m | A cord, a pouch, and whatever is on the ground. |
| `braided_sling` | Braided Sling | sling | Fine | 0.1 | 700 | shot x1.00, every 0.75 s, 13 m | Someone's grandmother made this, and meant it. |
| `staff_sling` | Staff Sling | sling | Fine | 1.2 | 900 | shot x1.30, every 1.10 s, 16 m, poise dmg 35, both arms | A sling on a pole. Throws a rock the size of a fist over a wall. |
| `light_drawn_braided_sling` | Light-Drawn Braided Sling | sling | Runed | 0.1 | 2,400 | shot x1.00, every 0.70 s, 13 m | The cord comes round sooner than it should. |
| `bent_stave` | Bent Stave | bow | Salvage | 0.8 | 70 | shot x1.35, every 0.80 s, 14 m, both arms | It was a bow once. It is still mostly a bow. |
| `hunting_bow` | Hunting Bow | bow | Plain | 0.9 | 520 | shot x1.50, every 0.70 s, 16 m, both arms | For deer. The principle carries over. |
| `short_recurve` | Short Recurve | bow | Fine | 0.8 | 1,900 | shot x1.45, every 0.55 s, 14 m, move x0.60 firing, both arms | Short enough to shoot while leaving. |
| `rampart_bow` | Rampart Bow | bow | Fine | 1.2 | 1,600 | shot x1.62, every 0.70 s, 18 m, both arms | Taken off a wall, along with the one who was using it. |
| `true_rampart_bow` | True Rampart Bow | bow | Runed | 1.2 | 4,300 | shot x1.72, every 0.70 s, 18 m, both arms | The grip has been written on by someone who shot better than you. |
| `latchbow` | Latchbow | crossbow | Plain | 1.4 | 650 | shot 80 flat, every 1.20 s, 12 m | One hand, one bolt, one opinion. |
| `gate_crossbow` | Gate Crossbow | crossbow | Plain | 3.5 | 900 | shot 150 flat, every 2.40 s, 18 m, pierce 1, both arms | The lever does the work. It does not care how many stars you have. |
| `windlass_arbalest` | Windlass Arbalest | crossbow | Fine | 6.5 | 2,800 | shot 240 flat, every 3.60 s, 22 m, pierce 2, poise dmg 60, both arms | Crank, crank, crank, crank. Then one very final noise. |
| `light_drawn_gate_crossbow` | Light-Drawn Gate Crossbow | crossbow | Runed | 3.5 | 4,600 | shot 150 flat, every 2.25 s, 18 m, pierce 1, both arms | The string wants to be back. |
| `tin_flue` | Tin Flue | flue | Plain | 1 | 800 | shot 55 flat, every 0.60 s, 9 m, vents 3 | A runed pipe. It coughs your own reflux at whatever you point it at. |
| `brass_flue` | Brass Flue | flue | Fine | 1.3 | 2,400 | shot 65 flat, every 0.55 s, 10 m, vents 4 | Better seams. Less of it comes back up your arm. |
| `venting_brass_flue` | Venting Brass Flue | flue | Runed | 1.3 | 5,200 | shot 65 flat, every 0.55 s, 10 m, vents 4, shed x1.10 | It breathes for you even when you are not shooting. |
| `dead_mans_lung` | Dead Man's Lung | flue | Unique | 1.6 | 24,000 | shot 70 flat, every 0.55 s, 10 m, vents 4, **With no reflux to vent it still fires, at 2 health a shot.**, grows with kills made with a dry shot | A flue with one breath of its own left in it, every time. |

### 7.3 Off hand (12)

| id | Name | Family | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `barrel_lid` | Barrel Lid | shield | Salvage | 2.5 | 30 | guard 20, back in 5.0 s | Oak, iron hoop, rope handle. Smells of herring. |
| `buckler` | Buckler | shield | Plain | 1.2 | 320 | guard 18, back in 2.0 s | Small, quick, and back in place before the next one lands. |
| `plank_shield` | Plank Shield | shield | Plain | 4 | 380 | guard 40, back in 4.5 s | Three boards and a boss. It will take what it is given. |
| `banded_round_shield` | Banded Round Shield | shield | Fine | 4.2 | 1,300 | guard 50, back in 4.0 s | Iron rim, rawhide face, somebody's initials. |
| `cut_down_pavise` | Cut-Down Pavise | shield | Fine | 8 | 1,700 | guard 80, back in 6.0 s, armour 2 | Sawn to fit a person. Still a door. |
| `warded_buckler` | Warded Buckler | shield | Runed | 1.2 | 2,800 | guard 18, back in 2.0 s, wound resist 6 | What gets past it gets past it gently. |
| `stubborn_banded_round_shield` | Stubborn Banded Round Shield | shield | Runed | 4.2 | 3,400 | guard 50, back in 4.0 s, poise +10 | It leans back. |
| `clay_sump` | Clay Sump | focus | Plain | 1 | 450 | reflux made x0.95 | A stoppered jar. Some of what your casting leaves behind settles in it instead of you. |
| `brass_sump` | Brass Sump | focus | Fine | 1.4 | 1,500 | reflux made x0.92 | Holds more, leaks less, hums when full. |
| `chalk_slate` | Chalk Slate | focus | Plain | 0.8 | 500 | cost x0.96 | Your working, written out where you can see it. Fewer mistakes, less waste. |
| `runesetters_slate` | Runesetter's Slate | focus | Fine | 0.9 | 1,900 | cost x0.93 | Someone else's working. Theirs was better. |
| `long_refusal` | Long Refusal | shield | Unique | 5 | 30,000 | guard 45, back in 4.0 s, **The guard never breaks: damage past the pool becomes reflux on your hottest affinity (1 per 2 damage) instead of reaching your health. If that affinity locks, the guard drops for 8 s.**, grows with damage it has turned | A shield that will not be told. What it cannot hold, it hands to you another way. |

### 7.4 Head (12)

| id | Name | Class | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `rag_hood` | Rag Hood | light | Salvage | 0.2 | 15 | armour 1 | Keeps the dust out. Arguably. |
| `oilcloth_hood` | Oilcloth Hood | light | Plain | 0.3 | 90 | armour 1, shed x1.03 | Sheds rain and, for reasons nobody has written down, a little heat. |
| `quilted_coif` | Quilted Coif | light | Fine | 0.4 | 420 | armour 2, shed x1.03 | Padding for under a helm. Many stop here. |
| `dented_pot_helm` | Dented Pot Helm | medium | Salvage | 1.6 | 40 | armour 2, wound resist 2 | The dent is the previous owner's review. |
| `boiled_cap` | Boiled Cap | medium | Plain | 1.2 | 300 | armour 2, wound resist 3 | Leather cooked until it gave up being skin. |
| `banded_helm` | Banded Helm | medium | Fine | 1.5 | 1,000 | armour 3, wound resist 4 | Iron straps over hide. Looks like a barrel. Works like one. |
| `kettle_helm` | Kettle Helm | heavy | Plain | 3 | 850 | armour 4, wound resist 6, poise +5 | A wide brim for things falling off walls. |
| `visored_sallet` | Visored Sallet | heavy | Fine | 3.2 | 2,400 | armour 5, wound resist 8, poise +5 | You see a slot of the world. The slot is enough. |
| `tethered_quilted_coif` | Tethered Quilted Coif | light | Runed | 0.4 | 2,200 | armour 2, shed x1.03, leash +2.0 m | The soul goes a little further from a head that is wearing this. |
| `warded_banded_helm` | Warded Banded Helm | medium | Runed | 1.5 | 3,000 | armour 3, wound resist 10 | Blows to the head are remembered less. |
| `blinkered_helm` | Blinkered Helm | heavy | Cursed | 3.6 | 8,000 | armour 5, wound resist 14, range x0.70, **The best wound protection a helm can give.**, toll: Blinkered | Nothing gets in. That includes most of the view. |
| `borrowed_face` | Borrowed Face | light | Unique | 0.6 | 22,000 | armour 2, wound resist 4, **In the Netherecho, docile constructs never turn on you; hostile ones notice you from half as far.**, grows with constructs subdued while wearing it | A plain mask with no expression. Constructs look at it and see nothing to object to. |

### 7.5 Body (14)

| id | Name | Class | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `patched_coat` | Patched Coat | light | Salvage | 1.8 | 20 | armour 2 | More patch than coat. It is yours. |
| `padded_jack` | Padded Jack | light | Plain | 2 | 240 | armour 3, shed x1.06 | Quilted linen. Breathes, which matters more than you would think. |
| `delvers_long_coat` | Delver's Long Coat | light | Fine | 2.2 | 950 | armour 4, shed x1.06, carry +4 kg | Waxed, vented, and mostly pockets. |
| `husk_hide_jack` | Husk-Hide Jack | medium | Salvage | 7.5 | 90 | armour 5, wound resist 4 | Invader hide, badly cured. It kept one of them alive for a while. |
| `boiled_leather_cuirass` | Boiled Leather Cuirass | medium | Plain | 7 | 650 | armour 6, wound resist 5, poise +8 | Stiff as a door for the first month. |
| `ringed_hauberk` | Ringed Hauberk | medium | Fine | 9 | 2,100 | armour 8, wound resist 6, poise +8 | Ten thousand rings, every one closed by hand. |
| `invaders_breastplate` | Invader's Breastplate | heavy | Salvage | 18 | 220 | armour 9, wound resist 10, poise +15, shed x0.90 | Fitted to a different shape of chest. You will know by evening. |
| `plate_cuirass` | Plate Cuirass | heavy | Plain | 16 | 1,800 | armour 10, wound resist 12, poise +20, shed x0.92 | Steel front and back. The heat has nowhere to go, and neither do you. |
| `fitted_harness` | Fitted Harness | heavy | Fine | 15 | 4,800 | armour 12, wound resist 14, poise +20, shed x0.94 | Measured for you. The price says so twice. |
| `knitting_padded_jack` | Knitting Padded Jack | light | Runed | 2 | 2,200 | armour 3, shed x1.06, wound mending x1.10 | Wounds under it close as if they had somewhere to be. |
| `warded_ringed_hauberk` | Warded Ringed Hauberk | medium | Runed | 9 | 4,400 | armour 8, wound resist 12, poise +8 | One ring in every hundred is written on. |
| `venting_plate_cuirass` | Venting Plate Cuirass | heavy | Runed | 16 | 5,200 | armour 10, wound resist 12, poise +20, shed x1.01 | Plate that lets the heat out. Somebody finally asked. |
| `paupers_shroud` | Pauper's Shroud | light | Cursed | 1 | 9,000 | armour 3, cost x0.90, health -10, **Every ability costs a tenth less.**, toll: Leeching | Thin enough to cast through. Thin enough for most things. |
| `stitchwork_coat` | Stitchwork Coat | light | Unique | 2.4 | 28,000 | armour 3, shed x1.06, **+3 armour for each lasting wound you are carrying (up to 4 wounds; grows to 6).**, grows with lasting wounds mended without a healer | Every tear has been sewn shut with a different thread. It keeps count for you. |

### 7.6 Hands (10)

| id | Name | Class | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `work_gloves` | Work Gloves | light | Salvage | 0.3 | 15 | armour 1 | Split palm, one finger missing. The glove's, so far. |
| `kid_gloves` | Kid Gloves | light | Plain | 0.2 | 160 | armour 1, recovery x0.97 | Soft enough to feel the grip. That is the point of them. |
| `draw_glove` | Draw Glove | light | Fine | 0.2 | 700 | armour 1, shot interval x0.95 | Three fingers of horn. The string leaves cleanly. |
| `rope_bound_bracers` | Rope-Bound Bracers | medium | Salvage | 1 | 35 | armour 2, wound resist 1 | Slats and cord. An invader's idea of a forearm. |
| `hide_bracers` | Hide Bracers | medium | Plain | 0.9 | 280 | armour 2, wound resist 2 | Something to put between an edge and the arm you need. |
| `splinted_vambraces` | Splinted Vambraces | medium | Fine | 1.2 | 900 | armour 3, wound resist 3, guard 5 | Steel strips sewn in. You can stop a blade with these, once or twice. |
| `plate_mitts` | Plate Mitts | heavy | Plain | 2.4 | 700 | armour 3, wound resist 4 | No fingers to lose track of. |
| `articulated_gauntlets` | Articulated Gauntlets | heavy | Fine | 2.6 | 2,200 | armour 4, wound resist 5, poise dmg x1.08 | Every knuckle its own little hinge, every hinge a little hammer. |
| `quick_kid_gloves` | Quick Kid Gloves | light | Runed | 0.2 | 2,100 | armour 1, recovery x0.92 | Stitched with a line of very small writing along each seam. |
| `staggering_plate_mitts` | Staggering Plate Mitts | heavy | Runed | 2.4 | 2,600 | armour 3, wound resist 4, poise dmg x1.15 | Whatever you are holding lands as if it weighed more. |

### 7.7 Feet (11)

| id | Name | Class | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|---|
| `street_boots` | Street Boots | light | Salvage | 0.9 | 20 | armour 1 | Resoled twice. The uppers are original. |
| `soft_runners` | Soft Runners | light | Plain | 0.6 | 220 | armour 1, move x1.03 | No heel, no nails, no noise. |
| `couriers_boots` | Courier's Boots | light | Fine | 0.6 | 900 | armour 1, move x1.05 | Made for people who are paid by the mile. |
| `dead_mans_boots` | Dead Man's Boots | medium | Salvage | 2 | 40 | armour 2, wound resist 1 | They were his size. Close enough. |
| `hobnailed_boots` | Hobnailed Boots | medium | Plain | 1.8 | 300 | armour 2, wound resist 2, poise +4 | They grip. You stay where you stood. |
| `shod_marching_boots` | Shod Marching Boots | medium | Fine | 1.9 | 1,000 | armour 2, wound resist 3, poise +6, move x1.02 | Twenty miles a day, every day, without comment. |
| `greave_boots` | Greave Boots | heavy | Plain | 4 | 800 | armour 3, wound resist 4, poise +8 | Shin plates riveted to the boot. Kicking things becomes an option. |
| `sabatons` | Sabatons | heavy | Fine | 4.2 | 2,300 | armour 4, wound resist 5, poise +10 | Steel to the toe. Stairs become a negotiation. |
| `sure_footed_hobnailed_boots` | Sure-Footed Hobnailed Boots | medium | Runed | 1.8 | 2,300 | armour 2, wound resist 2, poise +4, move x1.03 | The nails are set in a pattern that means something. |
| `stubborn_sabatons` | Stubborn Sabatons | heavy | Runed | 4.2 | 4,000 | armour 4, wound resist 5, poise +20 | Something would have to move the floor. |
| `runaways_shoes` | Runaway's Shoes | light | Cursed | 0.4 | 8,500 | move x1.10, hits from behind x1.25, **A tenth faster on your feet.**, toll: Turned Back | Fast. They assume you will use them. |

### 7.8 Back (6)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `flour_sack` | Flour Sack | Salvage | 0.5 | 10 | carry +18 kg | A sack and a length of rope. Technically a pack. |
| `canvas_pack` | Canvas Pack | Plain | 1.5 | 60 | carry +30 kg | A cheap backpack. Everything you own fits, for now. |
| `drovers_pack` | Drover's Pack | Plain | 2.5 | 520 | carry +50 kg | Wide straps and a hip band. Built for people who walk for a living. |
| `delver_frame` | Delver's Frame | Fine | 4 | 1,400 | carry +75 kg | A load-bearing frame built for hauling corpses out. |
| `corpse_sledge` | Corpse Sledge | Fine | 9 | 2,600 | carry +140 kg, move x0.85 | Two runners and a harness. You are the animal. |
| `haulers_delver_frame` | Hauler's Delver's Frame | Runed | 4 | 3,800 | carry +81 kg | The straps are written on. The load is not lighter; you mind it less. |

### 7.9 Belt (5)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `rope_belt` | Rope Belt | Salvage | 0.2 | 5 | quick slots 1 | Holds your trousers up and one thing besides. |
| `tool_belt` | Tool Belt | Plain | 0.6 | 180 | quick slots 2 | Loops for things you want without looking. |
| `quiver_belt` | Quiver Belt | Plain | 0.7 | 350 | quick slots 1, shot interval x0.96, ammo recovered +15% | The next one is always where your hand already is. |
| `delvers_harness` | Delver's Harness | Fine | 1.2 | 1,100 | quick slots 3, carry +5 kg | Belt, braces and more rings than anyone has found a use for. |
| `lifting_belt` | Lifting Belt | Fine | 1 | 1,300 | quick slots 1, worn allowance +4 kg | Four inches of hide round the middle. Plate sits easier over it. |

### 7.10 Satellite (6)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `guttering_mote` | Guttering Mote | Salvage | 0.2 | 600 | +0.5 essence/s | Half a satellite, on a good day. Somebody dropped it. |
| `dim_mote` | Dim Mote | Plain | 0.2 | 2,400 | +1.0 essence/s | A one-star satellite. It trickles essence into you whether you ask or not. |
| `paired_mote` | Paired Mote | Fine | 0.3 | 9,500 | +2.0 essence/s | A two-star satellite. Rank does not matter to the wearer - only the price does. |
| `trine_mote` | Trine Mote | Fine | 0.4 | 38,000 | +3.0 essence/s | A three-star satellite. Whoever lost this is looking for it. |
| `fevered_mote` | Fevered Mote | Cursed | 0.3 | 5,000 | +2.0 essence/s, its reflux x1.50, **A two-star flow at a one-star price.**, toll: Running Hot | Two stars of flow, and it runs hot. Cheap for a reason. |
| `quiet_mote` | Quiet Mote | Unique | 0.2 | 45,000 | +1.0 essence/s, **Its flow produces no reflux.**, grows with passages cleared in full without sitting to meditate | A one-star satellite that leaves nothing behind. Nobody can say where the residue goes. |

### 7.11 Trinkets (22)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `river_stone` | River Stone Charm | Plain | 0.3 | 700 | water cost x0.90 | Water abilities cost a tenth less essence. |
| `hearth_coal_charm` | Hearth Coal Charm | Plain | 0.3 | 700 | fire cost x0.90 | A coal that never quite went out. Fire abilities cost a tenth less essence. |
| `plumb_weight_charm` | Plumb Weight Charm | Plain | 0.5 | 700 | earth cost x0.90 | A mason's lead on a string. Earth abilities cost a tenth less essence. |
| `kite_bone_charm` | Kite Bone Charm | Plain | 0.1 | 700 | wind cost x0.90 | Hollow, and it whistles. Wind abilities cost a tenth less essence. |
| `fulgurite_charm` | Fulgurite Charm | Plain | 0.2 | 700 | lightning cost x0.90 | Sand that was struck once. Lightning abilities cost a tenth less essence. |
| `brine_phial` | Brine Phial | Fine | 0.2 | 1,800 | water abilities x1.06 | Sea water from somewhere deep. Water abilities hit a little harder. |
| `tinder_knot` | Tinder Knot | Fine | 0.1 | 1,800 | fire abilities x1.06 | Char cloth, tied tight. Fire abilities hit a little harder. |
| `keystone_chip` | Keystone Chip | Fine | 0.4 | 1,800 | earth abilities x1.06 | From an arch that is still standing without it. Earth abilities hit a little harder. |
| `reed_whistle` | Reed Whistle | Fine | 0.1 | 1,800 | wind abilities x1.06 | One note. Wind abilities hit a little harder. |
| `split_nail` | Split Nail | Fine | 0.1 | 1,800 | lightning abilities x1.06 | Out of a barn door, after the storm. Lightning abilities hit a little harder. |
| `cooling_coil` | Cooling Coil | Plain | 0.5 | 850 | shed x1.15 | Reflux bleeds off a little faster. A little is what you can afford. |
| `hauliers_knot` | Haulier's Knot | Plain | 0.2 | 400 | carry +6 kg | A knot that does not slip. You carry a little more than you should. |
| `ballast_coin` | Ballast Coin | Plain | 0.6 | 500 | poise +10 | Too heavy for what it buys. Kept low in a pocket, it helps. |
| `tether_knot` | Tether Knot | Plain | 0.1 | 600 | leash +2.0 m | Tie it round the wrist before you sit. The soul strays a little further. |
| `wisp_lure` | Wisp Lure | Plain | 0.1 | 650 | wisp reach +0.4 m | A bead of something wisps like. They drift toward the projection's hand. |
| `menders_thread` | Mender's Thread | Fine | 0.1 | 1,600 | wound mending x1.10 | Wound round the wrist. Healing spent on a lasting wound goes a tenth further. |
| `yard_token` | Yard Token | Fine | 0.1 | 1,500 | training cost x0.90 | A brass tag from a tempering yard. Sessions take a tenth less out of you. |
| `paper_effigy` | Paper Effigy | Fine | 0.1 | 2,000 | projection life +3 | A folded figure. In the Netherecho it takes the first of what was meant for you. |
| `pawned_ring` | Pawned Ring | Cursed | 0.1 | 12,000 | cost x0.88, hidden growth x0.90, **Every ability costs 12% less.**, toll: Safe Hands | Somebody else's promise. It makes everything cheaper, and it is not yours. |
| `moth_lamp` | Moth Lamp | Cursed | 0.4 | 10,000 | projection life -3, **Wisps of affinities you do not hold can be gathered as plain ether.**, toll: Thin Soul | Unlit, it does nothing. In the Netherecho every wisp comes to it. |
| `creditors_ring` | Creditor's Ring | Unique | 0.1 | 20,000 | **While your money is below zero: strikes and abilities hit 10% harder and abilities cost 10% less. While solvent: nothing.**, grows with debt paid off in full | Worn by people who are owed. It only works for people who owe. |
| `undertakers_ledger` | Undertaker's Ledger | Unique | 0.8 | 25,000 | **Damage past what a kill needed is banked (up to 100) and added to your next base strike.**, grows with commanders killed | A small black book. Whatever was left over is written down, and carried forward. |

### 7.12 Ammunition (4)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `arrow_bundle` | Bundle of Arrows | - | 0.8 | 40 | 20 per bundle, 50% recovered | Twenty, tied with cord. About half come back. |
| `barbed_arrows` | Barbed Arrows | - | 0.6 | 90 | 12 per bundle, 0% recovered | Twelve. They do not come out the way they went in, so they do not come back. |
| `bolt_case` | Case of Bolts | - | 1 | 60 | 12 per bundle, 60% recovered | Twelve short, heavy bolts. Most can be dug out. |
| `lead_shot` | Pouch of Lead Shot | - | 1.5 | 30 | 30 per bundle, 0% recovered | Thirty cast bullets. A sling throws them a quarter harder than gravel. They are gone once thrown. |

### 7.13 Consumables (4)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `field_dressing` | Field Dressing | - | 0.2 | 25 | - | Clean linen and a pin. Out of a fight: stops bleeding and returns 15 health over 8 seconds. Ordinary first aid; the star does not mind. |
| `cooling_paste` | Cooling Paste | - | 0.3 | 180 | - | Grey, cold, smells of pennies. Takes 30 reflux off your hottest affinity. The delve teaches you a little less for it. |
| `bitter_draught` | Bitter Draught | - | 0.4 | 260 | - | Thirty essence, now. It leaves 15 reflux on every affinity, and the delve teaches you a little less. |
| `numbing_salt` | Numbing Salt | - | 0.1 | 140 | - | For 60 seconds your wounds cost you nothing. Then each one is a tenth deeper, and the delve teaches you a little less. |

### 7.14 Loot and trade goods (16)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `husk_plate` | Husk Plate | - | 3 | 55 | - | A slab of invader hide. Tanners buy it. |
| `sinew_cord` | Sinew Cord | - | 1 | 30 | - | Tough, stringy, sells by the length. |
| `brute_tusk` | Brute Tusk | - | 6 | 280 | - | Heavy. Worth it if you can still walk. |
| `commander_sigil` | Commander's Sigil | - | 2 | 950 | - | Proof you put one down. Collectors pay. |
| `golden_seed` | Golden Grass Seed | - | 0.1 | 20 | - | Passage flora. The rich plant it to show off. |
| `cracked_mask` | Cracked Mask | - | 0.4 | 25 | - | A skirmisher's face. Children's parties, mostly. |
| `pavise_boss` | Pavise Boss | - | 2.5 | 90 | - | The iron dome off the middle of a wall shield. Smiths melt them. |
| `fletching_bundle` | Bundle of Fletchings | - | 0.2 | 35 | - | Feathers off a bird nobody here has seen. Fletchers want them. |
| `harrier_claw` | Harrier Hook-Claw | - | 0.5 | 120 | - | Curved, hollow, sharp on the inside edge. Sold as a letter opener. |
| `censer_chain` | Censer Chain | - | 1.8 | 160 | - | Blackened links that still smell of the smoke. |
| `drum_skin` | Drum Skin | - | 1.2 | 140 | - | Nobody asks what it was the skin of. |
| `wall_banner` | Wall Banner | - | 3 | 400 | - | A commander's colours, with holes. Looks well above a fireplace. |
| `slate_fern_root` | Slate Fern Root | - | 0.3 | 45 | - | Passage flora. Apothecaries grind it; do not ask them for what. |
| `grey_lichen` | Grey Lichen | - | 0.1 | 12 | - | Scraped off a chamber wall. Dyers pay by the handful. |
| `blood_soaked_mask` | Blood-Soaked Mask | - | 0.5 | 300 | - | A mask from the middle of a slaughter. Carry it while you project: a construct is more likely to be waiting. |
| `slaughter_stone` | Slaughter-Stone | - | 2 | 800 | - | A floor stone that drank a whole wall's worth. Carry it while you project: what waits is more likely to be a remnant. |

### 7.15 Materials (9)

| id | Name | Tier | kg | $ | Stats | Description |
|---|---|---|---|---|---|---|
| `scrap_iron` | Scrap Iron | - | 2 | 15 | - | Bent, rusted, sold by weight. |
| `steel_billet` | Steel Billet | - | 2 | 120 | - | A clean bar. A smith can do something with this. |
| `cured_hide` | Cured Hide | - | 2 | 60 | - | Husk plate after somebody patient has been at it. |
| `heartwood_stave` | Heartwood Stave | - | 1.5 | 80 | - | Straight grain, no knots. Bows and hafts. |
| `binding_wire` | Binding Wire | - | 0.3 | 40 | - | Soft iron wire. Holds grips, rims and tempers together. |
| `flux_salt` | Flux Salt | - | 0.5 | 55 | - | Burns white. Smiths and runesetters both use it and neither says for what. |
| `censer_ash` | Censer Ash | - | 0.3 | 70 | - | What the censer was burning. The base of rune ink. |
| `blank_slate` | Blank Slate | - | 0.8 | 90 | - | Split thin and polished. Runes are practised here before they go anywhere that matters. |
| `rune_ink` | Rune Ink | - | 0.2 | 350 | - | Enough to write one rune onto one thing. The runesetter does not give refunds. |
---
## 8. Where it comes from [MODEL]

Gear is crafted, quested for, awarded and dropped by monsters [B]. This build covers dropped, awarded and bought; crafted is a stub;
quested waits for quests. What comes out of a passage is legal to keep (the existing Serrated Dagger already says so; in the books
it is gear taken during a *break* that gets confiscated [C]).

### 8.1 Drops by enemy kind

Today each enemy has `loot: [{item, chance}]`, every entry rolled on its own. That stays. Two new entry forms: `{table, chance}`
(one weighted pick from a named pool in `loot_tables`) and `{learnable, chance}` (a skill scroll or tempering manual the character
can use — design/05). Pools are built from the catalogue by slot group and tier: `arms_t0-2` (main hand, ranged, off hand),
`armour_t0-2`, `worn_t1-2` (trinket, belt, back), `shields`, `runed`, `cursed`, `unique`, `satellites`, `materials`, `flora`.

| Enemy | Always-there goods | Gear | What the table says about it |
|---|---|---|---|
| **Masked Skirmisher** (`grunt`) | Sinew Cord 30%, Cracked Mask 25%, Husk Plate 20%, a material 8% | Salvage arms 12%, Salvage armour 8% | The baseline: scrap, and now and then something to hold |
| **Hide-Bound Brute** (`brute`) | Brute Tusk 55%, Husk Plate 45%, a material 20% | Salvage arms 15%, Salvage armour 15%, Plain arms 5% | Heavy goods — the hauling question |
| **Wall Commander** (`commander`) | Commander's Sigil 100%, Wall Banner 50%, Brute Tusk 40%, Slaughter-Stone 5% | Fine arms 30%, Fine armour 25%, Fine trinket/belt/pack 15%, Runed 10%, **Cursed 3%** | The only ordinary source of Fine and better inside a passage |
| **Pavise Bearer** | Pavise Boss 50%, Husk Plate 30% | A shield 10%, Plain armour 6% | Shields come from shield-carriers |
| **Rampart Archer** | Fletchings 50%, **Bundle of Arrows 35%**, Sinew Cord 30% | Bent Stave 12%, Hunting Bow 5%, Draw Glove 3%, Rampart Bow 2% | Feeds a bow user's ammunition as they go |
| **Harrier** | Hook-Claw 45%, Sinew Cord 30% | Throwing Knives 5%, Soft Runners 4% | Light, fast things |
| **Censer-Bearer** | Censer Ash 80%, Censer Chain 40%, Flux Salt 25% | Cooling Paste 8%, Clay Sump 4% | Rune-ink ingredients and reflux gear |
| **War Drummer** | Drum Skin 70%, Binding Wire 20% | Plain trinket/belt/pack 8%, a skill scroll 5%, a tempering manual 3% | The learning drops |
| **Any deviant** (bonus rolls) [F: deviants are the dangerous off-pattern ones] | Blood-Soaked Mask 30% | Runed 50%, Cursed 15%, **Unique 3%** | The headline drop |

The five archetypes after the first three come from design/05 §6.1 and do not exist yet; their ids in the data draft are my guesses.

### 8.2 By depth

The assault passage has ten walls with the exit unlocking at five [C: minimum progress; existing].

| Walls | Highest tier that can drop | Table chances | Chance a table roll is bumped one tier |
|---|---|---|---|
| 1-4 | Plain | ×1.0 | 0% |
| 5-7 | Fine | ×1.2 | 30% |
| 8-10 | Runed | ×1.4 | 50% |

Cursed and unique items ignore the bands — they come only from the sources that name them. So leaving at the gate means leaving
before anything Fine has had a chance to drop: the same "go deeper" pressure as the payout, now in the loot.

### 8.3 Exit rewards

Unchanged in shape [C: per person, at the exit, scaled to contribution; existing]: one roll per 2.5 walls cleared, on a table that now reads
flora 6, Sinew Cord 5, Husk Plate 4, a material 4, Plain arms 3, Plain armour 3, Plain trinket/belt/pack 2, arrows 2, a satellite 0.5.
The **two bonus rolls for a full clear** move to a better table: Fine arms 6, Fine armour 6, Fine trinket/belt/pack 4, Runed 4,
a skill scroll 3, a tempering manual 2, Cursed 1, a satellite 1, **a unique 0.2** (about 1 in 140 per roll).
Repeats pay less [C]: the cash payout already falls 20% per repeat (existing); for loot, from the third run of the same passage
the two bonus rolls are taken from the ordinary table instead. A farmed passage still gives things, just plainer ones.

### 8.4 The merchant

- **Always in stock** (the existing `shop` list, extended): Iron Knuckles, Cord Sling, Padded Jack, Canvas Pack, Tool Belt, Delver's Frame, both motes, River Stone Charm, Cooling Coil, arrows, bolts, lead shot, Field Dressing.
- **A rotating shelf**, re-rolled each night when rent is charged, seeded by the day so a reload shows the same shelf: 3 Plain arms, 3 Plain armour, 2 Plain trinkets/belts/packs, 1 Fine arm, 1 Fine armour, **1 Runed item**, and 2 of the 3 costly consumables.
- **Never sells Cursed items or uniques.** Buys gear at half, loot and materials at full (existing rule).
- Passing a night to see a new shelf costs rent — so shopping around has a price, in the fiction's own currency.
- Later, and cheap once badges exist: the shelf's Fine and Runed slots gated by badge rank [C: badges gate vendors].

### 8.5 Crafting and enchanting (stub only)

One service, one screen row, later: a **runesetter** in town writes a rune onto a Fine item [C: enchanting; runesetting]. You bring
the item, one Rune Ink and the fee ($1,200 first guess); you choose from the runes allowed on that slot (§6.2). It **fails 10% of
the time** [C: even factory binding tops out at 90%] — the ink and fee are lost, the item is not. With a fixed catalogue this only
works where the runed version already exists as an item (the draft's `rune` + `base` fields record the pairs: 24 today); every
other combination needs item instances first. Smithing from materials is not designed; materials sell, and Rune Ink has this one use.

### 8.6 What the Netherecho gives

**Nothing you can wear.** It stays about wisps and constructs [B: constructs are subdued, not looted]. Gear touches it from the
outside only:
- four small stats (leash, projection life, wisp reach, soul strike) on a few trinkets, one coif and one unique;
- two **catalysts** [C: blood-soaked objects from passage slaughter become catalysts tied to rarer constructs]: carried in the pack while you project, the Blood-Soaked Mask raises the chance that a site holds a construct (+25 points), the Slaughter-Stone the chance that it is a remnant (+15 points). They are loot with a use, and sell if you would rather have the money.

---
## 9. Inventory and UI changes [MODEL]

**The screen today**: a column of four slot panels, a list of the pack, a soul column. Click, right-click or drag to equip.

**What it needs.**
1. **A paper doll** in place of the slot list: the character's turntable model (the creator already has one) with slots around it —
   head above; main hand, body, off hand across the middle; hands and belt below that; feet at the bottom; ranged and back on the left edge;
   satellite and the two trinkets on the right. Each slot keeps today's behaviours (click to remove, drop target lights up when a dragged item fits).
   A two-hander shows in the main hand and greys the off hand with "held by the Greatblade".
2. **A comparison panel**, not a hover tooltip (the project avoids hover-only interactions): selecting a pack item shows its stats beside
   the item in that slot, each changed line as *before → after* in green or red — the same pattern as the bind preview on the ethercosm screen.
   For trinkets it compares against whichever trinket slot is selected.
3. **Three totals** under the doll: **Armour 12% · Wound resist 12% · Guard 40**; **Worn 16.4 / 14 kg — 4% slower**; **Pack 21 / 38 kg**.
4. **Sort and filter** on the pack: filter chips All / Gear / Ammunition / Quick items / Loot / Materials; sort by slot, tier, value, weight, and **$ per kg** — the number that decides what stays on the floor of a passage.
5. **Tier colour** on item names everywhere (pack, shop, ground labels, pickup messages).
6. **`item_stats_text`** grows a line per new stat key (the draft's catalogue script has a label for every key), and shows the family trait under the stats.
7. **HUD**: a guard arc in front of the character; a small ranged readout by the skill bar (weapon icon, ammunition count or brace pips, reload sweep); quick-slot icons with their keys (new actions `quick_1..3`, defaults Z / X / C); the range ring while Shift is held.
8. **Icons**: `UiDraw.item_icon` picks a glyph by slot today. It needs eight more glyphs (shield, bow, helm, coat, glove, boot, belt, flask) and should pick by family where one exists.

**Tests to extend**: the inventory click probe (equip into each new slot, two-hander displacing a shield, trinket into the second slot,
refusal when the pack is full); `--shot-ui=inventory`; the self-test (armour arithmetic, worn-weight slow at one and two stars, caps, ammunition counts).

**Weight and capacity.** Keep the base 8 kg and the Canvas Pack's 30 (38 kg at the start). New gear is heavy on purpose: one salvage
breastplate is half a starting pack. The ladder is Flour Sack 18, Canvas 30, **Drover's Pack 50 ($520 — the first real upgrade)**,
Delver's Frame 75, Corpse Sledge 140 at −15% movement. Ammunition weighs (40 arrows = 1.6 kg). Worn gear stays outside pack weight,
as now, and has its own allowance (§2.1). A reasonable first-run target: a full clear should produce about 1.5 packs' worth of things worth carrying, so there is always a decision.

---
## 10. Build order

S = a day or two, M = up to a week, L = more. Each step is playable and testable alone. Steps 2-4 can go in any order after 1.

| Step | Size | What gets built | Proves | How to test |
|---|---|---|---|---|
| **1. A coat and a sling** | **S** | Two slots added to `Inventory.SLOTS` (`body`, `ranged`); `armour` read in `take_hit`; the `ranged_stance` action (Shift) and a basic shot through the existing `Projectile` (§3.2 smallest version); `ranged_damage` in `balance.json`; four items — Patched Coat and Cord Sling (starting kit), Padded Jack (shop), Husk-Hide Jack (Brute drop); two more slot panels in today's list UI; two lines in `item_stats_text` | That armour and a no-essence ranged attack both feel right in the hand before anything is built on them | Self-test: a 20-damage hit through 5 armour lands as 19; a sling shot does 45; old saves load with the new slots empty. By hand: **Brent** — does Shift + click feel natural beside click-to-attack? |
| **2. The paper doll and all armour** | **M** | The remaining slots; worn-weight rule; `wound_resist`, `poise`, `max_health`, `move_speed_mult` on gear (the first two only as far as the health redesign and design/05 have landed); paper-doll screen, comparison panel, totals; the 47 armour pieces, packs and belts (belts without quick slots yet) | The three weights are a real choice; the screen is usable with 12 slots | Self-test: caps, worn-weight slow by star; click probe extended; inventory screenshot |
| **3. Melee families and shields** | **M** | `family` on items and the family table; two-handed rule; arm-loss extensions; Tip; the 38 main-hand items; shields with the guard pool and arc; sumps and slates. The five traits that need design/05 (Working hands, Back work, Open up + Bleeding, Dent, Follow-through) land here if its step 2 is in, otherwise they are listed as inactive on the item | Seven families feel different to click with | Self-test per trait and for the guard; by hand, one wall with each family |
| **4. Ranged in full** | **M** | Draw and recovery timing, the hand-change delay, family move factors; ammunition counts and weight, recovery after a fight, the brace; crossbow reload; flues venting reflux; the 22 ranged items and 4 ammunition items; the HUD readout; Rampart Archer drops when that enemy exists | Five ranged families, each a different rhythm; ammunition is a hauling decision, not a chore | Self-test: counts, recovery share, dry flue, both-arms rule; by hand |
| **5. Loot tables, tiers and the shop** | **M** | `{table, chance}` and `{learnable, chance}` entries; depth bands; the full-clear table; tier colours; merchant rotation; pack sort, filter and $ per kg; consumables, quick slots and the aura penalty; catalysts | The loot loop: what drops, what you leave, what you buy | Self-test: 20,000 rolls per table match the weights and respect the band cap; bots still pass; shop screenshot on two different days |
| **6. Runed, cursed and unique items** | **L** | Item effect scripts loaded like talents; the remaining stat keys; tolls; growth counters saved per character; the eight uniques; the runesetter stub. Random affixes on item instances only if Brent wants them (Q8) | Items that change how you play, not just by how much | Self-test per effect script; each unique by hand |

Step 1 is the recommendation for "add this to the build target": it is small enough to ride alongside whatever else is in the sprint.

---
## 11. Open questions for Brent

1. **No weapon cleaves — keep that?** Your 2026-09-23 ruling says area hits belong to skills, never the base attack; the request
   mentioned cleave as a weapon property. *Recommend:* keep the ruling. Great weapons widen strike skills instead. If you want one
   exception, make it a single unique item later, not a family.
2. **Shift to shoot, and everyone starts with a sling?** *Recommend:* yes to both. Shift is where the left hand already is, RMB stays
   overcharge, and a starting sling means the ranged slot is never an empty promise. Step 1 exists to let you feel it before we commit.
3. **Shields with no button** — a guard pool that soaks front hits and refills on its own. *Recommend:* yes; it is the only form that
   fits click-to-attack and design/05's "no block button". If it plays as too passive, the fix is a smaller pool, not a button.
4. **"Cursed" items carry a toll.** In the books a cursed item is just an artifact, with no built-in drawback. *Recommend:* keep our
   toll, call the clean ones Runed, and let Cursed mean "stronger, and it costs you" — it reads better in a shop window and keeps gear
   under the body.
5. **Ammunition.** Slings free and endless; thrown weapons a per-fight brace; bows and crossbows use bought arrows and bolts that
   weigh something and half come back. *Recommend:* as written. If counting arrows turns out to be a chore in play, switch bows to a
   per-fight quiver (the brace rule) — one line of data.
6. **The body decides how much you can wear** — a worn-weight allowance that grows with stars, instead of rank requirements on items.
   *Recommend:* yes. It matches your satellite ruling (any rank can wear anything) and makes heavy armour something you grow into.
7. **Consumables cost growth.** Three of the four make the rest of the delve teach 10% less, without ever showing a number; the Field
   Dressing is exempt. *Recommend:* yes, and keep the list at four. Also confirm the two retunes in §5 (River Stone Charm becomes
   water-only as its text says; Cooling Coil drops from 50% to 15%).
8. **Fixed catalogue or rolled affixes?** *Recommend:* fixed for now — 158 hand-written pieces, no save-format change. Rolled items
   (a base plus random runes) are a step-6 option once we know whether the fixed list feels thin.

---
## What has and has not been checked

- **Checked**: the data draft parses as JSON; every item, table, rune, toll and family referenced in it exists; the set and DPS figures quoted in §3-§4 were recomputed from the draft's numbers; all 15 existing ids are present.
- **Not checked**: anything in play. No number here has been in the game. The traits that lean on design/05 assume its draft is approved as written; the wound stats assume a health redesign I have not read. `enemies.json`, `balance.json`, `inventory.gd` and every other existing file are untouched.
