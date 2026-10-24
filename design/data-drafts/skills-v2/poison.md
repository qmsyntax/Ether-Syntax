# Poison v2: the weapon coater (draft, 2026-10-24)

Data: `poison.json`, `poison-runes.json`. Brief: `ROLES-BRIEF.md`. Nothing is built. All [MODEL] unless marked; the
role and parents are Brent's framework [B 2026-10-24]. All names are original.

**Role:** weapon coater. Your weapon hits and ranged shots carry poison for a time, and the poison pays out later.

**Rule:** Poison rides your weapon: a coat puts its payload on every weapon hit and ranged shot for a time, the first dose in a body starts a 6 s clock that later doses add to but never reset, and when it runs out every dose is paid at once (20 each). It never spreads on its own.

**Reflux:** low (0.7), unchanged.

## How each parent shows

- **Water**: Tainted water: a liquid that wets the edge and soaks in (Soak, Seep), is carried along a line (Wave), fills an area and changes it (Flood), is drawn to one place (Drain) and is pushed on all at once (Surge). Cited against Water's v2 runes (Gush, Drip and Sweep are dropped there).
- **Death**: Death's ending, deferred: the dose clock is a death that is owed. Purge is the finishing blow (Kill), Counterdose calls the ending off (Spare), Sap is slow decay (Rot), Bitter Tonic is a poison kept from killing you (Preserve).

## Poison and Disease, kept apart

| | Poison | Disease |
|---|---|---|
| Gets in by | your weapon and shots (the coat) | clouds, the ground, touch |
| Pays | once, later, as a lump (the dose clock) | every half second, as a tick |
| Spreads | never (only Funnel moves it, on purpose) | body to body, from corpses, from soured ground |
| Armour | Corrode thins it | flesh cuts every tick |

## Skills

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Venom Edge | Envenom | burst | Wet the blade and cut across the front: 1.6x and 2 doses to everything in a 100-degree arc. The blade stays coated for 8 s or 8 hits: every weapon hit and ranged shot gives a dose. | **close** | new |
| Black Purge | Purge | strike | One enemy in reach: a heavy weapon blow that drives every dose in it through at once - the whole bill now, at half again (30 a dose) - and interrupts. Your coat goes in after the purge, so the next bill starts at once. |  | changed |
| Fouling Slide | Contaminate | dash | Slide 5 m straight through enemies with your blade out, fouling each one you brush: 2 doses each, and your coat as well. | **movement** | changed |
| Clean Air | Cleanse | zone | Point, 9 m: air 4 m across for 8 s that nothing foul can use. Enemies in it cannot be healed or Frenzied, a Censer-Bearer that dies inside bursts for nothing, and bills paid inside it are 20% larger. |  | changed |
| Caustic Sweep | Corrode | burst | Your weapon dripping with acid, a wide sweep in front of you, 3.1 m: a solid hit, a dose, and Corroded - each stack takes a third off their armour, shields included. It carries your coat. |  | changed |
| Counterdose | Neutralise | bolt | A shot of counter-agent from your ranged weapon (or thrown, without one): 45, and the target's doses are cancelled - no bill - while its body seizes for 0.3 s a dose (2.5 s at most), interrupting whatever it was doing. |  | changed |
| Sting Dart | Linger | bolt | A barbed dart from your ranged weapon (or thrown, without one): 50 and a dose, and the barb stays in - a dose every 1.5 s for 4.5 s more. The first dose starts the 6 s clock; when it runs out, every dose in the body is paid at once, 20 each. | **ranged** | changed |
| Funnel | Flush | detonate | One enemy within 10 m: every other dosed enemy within 6 m of it is flushed clean, and all their doses pour into it - up to 20. Its clock does not change. |  | existing |
| Sapping Tether | Sap | channel (held) | Hold on one enemy within 7 m: a thin thread drips a dose into it every half second, and while it holds the target deals 30% less damage and moves 30% slower. You walk at half speed; the thread breaks past 9 m or behind stone. |  | existing |
| Bitter Tonic | Stimulate | buff | Drink it: for 8 s you move 15% faster, recover from skills a quarter sooner, your weapon hits 15% harder and your shots fly 15% further, and your coat is not worn off by hits (its time still runs). |  | changed |
| Steeped Blade | Steep | strike | A slow thrust with a blade left to steep: one enemy in reach takes 1.8x and 2 doses and is Steeped - its clock runs 3 s longer and its bill pays 30 a dose instead of 20. The blade keeps the slow venom for 20 s or 15 hits: each one doses and Steeps. |  | new |
| Venom Spur | Spur | detonate | Spur the venom on. Every Dosed enemy within 8 m has its clock cut to half a second: every bill comes due at once, at 80% (16 a dose). No blow, no line of sight needed. |  | new |

Dropped:
- **Residue** (Linger): A slick on the ground that doses whoever stands in it is area attrition, which is Disease's ground (clouds, barrows, soured earth). Poison is weapon-borne and one body at a time; its Linger rune now lives in Sting Dart's barb.

The loop: Venom Edge (or Steeped Blade for a slow fight) puts the coat on; bare strikes and shots then dose
everything you touch for free; Sting Dart's barb keeps paying into a runner's bill; Black Purge cashes one big bill
early, Venom Spur cashes the whole pack, and Funnel pours a pack's doses into one body first.

## Runes (12)

| Rune | Meaning | Opposite | Role | Draw | Effect | Change | Why |
|---|---|---|---|---|---|---|---|
| Envenom | coat a blade or a shot so what it strikes is dosed | Purge | link | -0.60 | `status dosed 2` | renamed | Renamed and re-meant: 'Poison' was the affinity's own name, and 'dose a target' now happens through a coat. Role (link) and draw (-0.6, gives outward) kept; its effect is unchanged, so a word that carried it still reads the same. |
| Purge | clear doses | Envenom | cap | +0.60 | `bonus dosed +0.4` | kept | Kept: the cash-in, the opposite of putting doses in. |
| Contaminate | foul an area or a thing | Cleanse | branch | -0.70 | `status dosed; duration x1.3` | kept | Serves the role as it is. |
| Cleanse | make it clean again | Contaminate | branch | +0.40 | `reflux x0.7` | kept | Kept as the utility pair (anti-heal, anti-Frenzy). |
| Corrode | acid that eats armour and metal | Neutralise | link | +0.50 | `status corroded` | kept | Kept; its skill is now a weapon sweep. |
| Neutralise | render a poison or acid harmless | Corrode | frame | +0.30 | `interrupts; power x0.9` | kept | Kept; its skill is now a weapon shot. |
| Linger | leave residue that stays | Flush | frame | +0.30 | `duration x1.6; status dosed` | kept | Kept, meaning and all; Sting Dart moved onto it (the barb is residue that stays), and the ground slick is dropped. |
| Flush | clean an area out | Linger | branch | -0.60 | `reach x1.2; shove +1` | kept | Serves the role as it is. |
| Sap | weaken | Stimulate | link | +0.60 | `status sapped` | kept | Kept as the range-and-utility rune (the tether). |
| Stimulate | strengthen (poison as a drug) | Sap | link | -0.60 | `windup x0.75; reflux x1.15` | kept | Kept; its skill loses the dose clock (Spur owns timing now) and keeps the coat on instead. |
| Steep | let a poison soak in slowly, so it does more when it comes due | Spur | frame | +0.50 | `duration x1.3; status steeped` | new | The dose clock needs a rune for 'later and dearer'. From Water's Soak and Seep. A Frame (it holds a structure: a word built round a slow venom), draw +0.5 because it holds the poison in. |
| Spur | make a poison act sooner | Steep | cap | -0.60 | `windup x0.8; bonus dosed +0.2` | new | The other end of the clock: 'now, for a little less'. From Water's Surge (Gush, the obvious source, is dropped in Water v2). A Cap (it ends what is running), draw -0.6 because it lets the poison out; opposite Steep, so the pair bonds ionically. |

Renamed: **Poison -> Envenom**. New: **Steep**, **Spur**. None dropped.

## New mechanics

- **coat** (behaviour, Venom Edge): A skill key: the cast also puts on a self_buff carrying Fire's strike_payload (fire.json v2, Stoke: applied by every bare strike and every ranged-weapon shot that lands) for duration, with two Poison keys added: charges (the coat ends after that many hits, whichever comes first) and weapon (skills marked weapon carry it too). One Poison coat at a time: a new one replaces the old (another affinity's strike_payload buff is separate). Shown as a ring round the weapon on the HUD.
- **weapon** (field, Venom Edge): A Poison skill marked weapon is made with your weapon: its damage_mult is on your strike damage (as now), and its hit also carries your coat (and uses one charge). A weapon skill that also carries on_hit applies on_hit first, then the coat.
- **no_heal** (field, Clean Air): A zone with no_heal stops every heal on enemies inside it (the Censer-Bearer's burst among them), and its blocks_status list cannot be applied inside (ends_status is removed on entry).
- **dose_bonus** (field, Clean Air): A zone key: a Dosed bill paid on an enemy standing in the zone is multiplied by 1 + dose_bonus.
- **corroded** (status, Caustic Sweep): Corroded (up to 3 stacks, 10 s, refreshed): front armour, and worn armour (Disease's flesh), each lose a third per stack - a Pavise Bearer's 80% shield is 53%, 27%, then gone. Applies even through a frontal block, because the acid is on the shield.
- **statuses** (field, Caustic Sweep): A hit payload may carry statuses, a list of {id, stacks}, when it applies more than one status; each is applied in order.
- **stun_per_stack** (behaviour, Counterdose): A hit with consume_status and stun_per_stack removes that status and Stuns the target for stun_per_stack seconds per stack removed, up to stun_max, instead of paying any damage the status would have done.
- **barbed** (status, Sting Dart): 1 stack, barb_s (default 4.5 s): every barb_every seconds it adds 1 Dosed in the name of whoever applied it. Black Purge and Counterdose pull the barb (it ends when Dosed is consumed).
- **shot** (field, Sting Dart): A projectile marked shot is loosed from the ranged weapon when one is worn (its ranged_damage_mult scales damage, and it counts as a ranged shot for the coat); without one it is thrown at its own damage. It does not need the ranged stance.
- **gather_into** (behaviour, Funnel): A detonate with gather_into removes consume_status from every enemy within gather_radius of the target and adds those stacks to the target, up to gather_cap (above the status's usual cap); the target's own clock is kept.
- **sapped** (status, Sapping Tether): Sapped (1 stack, while tethered and 2 s after): deals 30% less damage and moves at 70%.
- **tether** (field, Sapping Tether): Channel shape tether: locks onto one enemy within range at the start and follows it; ends if it gets farther than break_range or a wall or stone comes between.
- **coat_free** (field, Bitter Tonic): While a buff with coat_free is on the caster, hits do not use the coat's charges; only its duration ends it.
- **shot_range_mult** (field, Bitter Tonic): While the buff lasts, the caster's ranged weapon shots and shot skills fly this many times as far.
- **steeped** (status, Steeped Blade): 1 stack, lasts until its Dosed bill is paid: the first time it is applied it adds clock_add seconds to the target's Dosed clock (once, never again while it holds); the bill is multiplied by bill_mult when it comes due. No effect on a body with no doses.
- **clock_to** (behaviour, Venom Spur): A detonate key: every enemy within range holding needs_status has that status's time left cut to clock_to (never lengthened); bill_mult multiplies what its on_expire pays this once.

Kept and still used: dosed, corroded, sapped, statuses (payload list), no_heal, gather_into, stun_per_stack,
tether.

## Unsure

- The coat rides bare strikes and ranged shots. "No affinity owns bows / thrown weapons yet" (framework, Open), so
  `shot` skills fall back to a thrown dart without a ranged weapon. Whether Poison should own thrown darts is
  Brent's call.
- Bitter Tonic no longer shortens the dose clock (Venom Spur does that now). Its new power number (`strike_mult`
  1.15) is there so ascension has something to boost.
- Clean Air gained `dose_bonus` (+20% bills inside) for the same reason; it was a no-damage zone.
- Only one coat at a time. Two coats (one per hand) would be a later rule.
