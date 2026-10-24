# Holy v2: the paladin (NEW, draft, 2026-10-24)

Data: `holy.json`, `holy-runes.json`. Nothing is built; Holy does not exist in the game yet. Tags: **[B]** Brent,
**[MODEL]** ours. All names original.

**Role** [B: framework.md]: paladin / support - shields, wards, buffs, cleansing. **Parents: Light + Life.**

## How each parent shows

- **Light: the straight line, Lit, clean power.** Condemning Ray is an instant line that stops on the first opaque
  thing; Rebuke only reaches what it can see; a ward that breaks bursts into light and Lights what is near; blessed
  strikes Light their targets; Hallowed Ground Lights enemies inside. Reflux low (0.7), Light's.
- **Life: the body kept whole.** Wards keep wounds from opening; a ward's leftover sinks in as health; Kind Light
  gives back what it softened; Absolution is a cleanse; Penance wastes a foe's blows (Life's Weaken). Holy's heals
  obey Life's living-only rule.

## Rule

**Holy wards what is yours**: a ward takes blows before your bar, so a blow it wholly stops opens no wound, and when
a ward breaks it pays out its light - 30 and Lit to every enemy within 3 m. Wards cover you and your summons, living
or not; Holy's healing touches only the living. Ward cap 60 per body. [MODEL]

**Holy against Life.** Holy never heals over time. It guards (wards), it buffs (Benediction), it lifts binds
(Absolution), and it heals only in moments: a ward's leftover when it ends, Kind Light's bank when it ends. Life
heals the body over time, closes wounds, cures afflictions and drains the living.

**Five-axis position** (proposed, for the workbook): the midpoint of its parents, [0.35, -0.2, 0.65, 0.6, 0.2].

## Skills (12 on 12 runes; 9 serve the role)

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Dawnward | Ward | self buff | 40 ward for 8 s (20 on each summon in 6 m); leftover: half back as health | |
| Guardbreaker | Humble | targeted strike | 2.0x; Exposed 5 s and every enemy boon stripped | |
| Benediction | Bless | self buff | 8 s, you and summons in 8 m: +20% damage, half poise loss, strikes Light | |
| Condemning Ray | Condemn | beam | 14 m instant, 50; Condemned: your hits on it give you 4 ward (up to 30) | **ranged** |
| Absolution | Absolve | self buff | Lift every bind on you and summons; 10 ward + 8 per bind; turn away the next | |
| Penitent Mark | Penance | smite | 8 s: each attack it starts burns it 25; its blows on yours -30% | |
| Hallowed Ground | Hallow | ground zone | 3.5 m, 8 s: yours take 20% less and gain 5 ward/s; enemies Lit | |
| Casting Out | Exile | melee burst (cone) | 30, shove 3 m, Exiled 4 s: keeps 4 m off you | |
| Kind Light | Mercy | self buff | 6 s: blows 30% softer; 60% of what it softened comes back as health | |
| Rebuke | Wrath | melee burst | 1.7x all round, Lit; half again while you are warded | **close** |
| Zealous Charge | Zeal | dash | 6 m Braced charge; 1.5x and interrupt; arrive with 15 ward | **movement** |
| Abiding Guard | Patience | self buff (counter) | 1 s: stop the first blow whole and answer it 2.5x; ward either way | |

Role: Dawnward, Benediction, Condemning Ray, Absolution, Penitent Mark, Hallowed Ground, Kind Light, Zealous Charge,
Abiding Guard. Damage and utility: Guardbreaker, Casting Out, Rebuke.

The loop: Condemn a foe at range -> fight it to build ward -> Rebuke hits hardest while warded -> a ward that breaks
bursts -> what is left heals you.

## Runes (all new; 12, six pairs)

| Rune | Role | Draw | EN | Effect | Opposite |
|---|---|---|---|---|---|
| Ward | frame | +0.4 | 2.66 | braced; reflux x0.9 | Humble |
| Humble | branch | -0.6 | 2.08 | status exposed; poise x1.15 | Ward |
| Bless | link | -0.5 | 2.0 | power x1.15; duration x1.15 | Condemn |
| Condemn | cap | +0.8 | 3.7 | status condemned | Bless |
| Absolve | cap | -0.7 | 1.45 | cost x0.9; reflux x0.8 | Penance |
| Penance | link | +0.6 | 3.1 | status penitent | Absolve |
| Hallow | frame | +0.3 | 2.62 | duration x1.3 | Exile |
| Exile | branch | -0.8 | 1.94 | shove +1; status exiled | Hallow |
| Mercy | link | +0.4 | 2.9 | reflux x0.75; power x0.9 | Wrath |
| Wrath | branch | -0.9 | 1.87 | power x1.2; status lit | Mercy |
| Zeal | link | -0.5 | 2.0 | speed x1.2; windup x0.8 | Patience |
| Patience | cap | +0.6 | 3.4 | windup x1.25; power x1.25 | Zeal |

Roles: 2 frames, 3 caps, 4 links, 3 branches. "Sunder" was the first name for Humble; Metal has it.

## New mechanics [MODEL]

- **Ward** (Body.ward; the same mechanic as Unholy's ward key and Water's Crush ward): one pool per body, cap 60, spent after armour and before the bar; a wholly stopped blow opens
  no wound; breaking it fires the rule's burst. Keys `ward`, `summon_ward`, `arrive_ward`, `ward_per_cleansed`,
  `expire_heal_frac`.
- **Statuses**: Condemned (counts as Lit; your hits on it feed your ward), Penitent (its attacks burn it; its blows on
  yours x0.7), Exiled (keeps 4 m from you). Reused: Exposed, Lit, Staggered.
- **Buffs**: Blessed (`strike_status` reused), Absolved (turns away the next bind), Kind Light (`incoming_mult`
  reused, banks what it softened).
- **purge** (strip `enemy_boons`: Frenzied, Drummed, Roused), **ally_payload** on a ground zone, **warded_mult**,
  **counter** (a parry window).
- **cleanse "binds"** (the list is defined in life.json).

## Unsure

- One ward pool with per-source timers is the simplest honest model; whether several small wards should instead
  refresh one another is open.
- Abiding Guard's 1 s window against enemy wind-ups (telegraphs are 0.5-1.2 s) needs hands on the controls -
  untested, needs Brent.
- The axis position is a midpoint proposal; the workbook is not mine to edit.
