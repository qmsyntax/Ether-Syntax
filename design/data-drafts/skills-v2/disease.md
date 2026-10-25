# Disease v2: the plague caster (draft, 2026-10-24)

Data: `disease.json`, `disease-runes.json`. Brief: `ROLES-BRIEF.md`. Nothing is built. All [MODEL] unless marked;
the role and parents are Brent's framework [B 2026-10-24]; that miasma is flesh-only and full armour defeats it is
[C: book5-mechanics-notes, ch218]. All names are original.

**Role:** plague caster: spreading attrition, built from Earth's rot.

**Rule:** Disease spreads through flesh: Infected ticks (times flesh, so armour cuts it and stone and constructs ignore it), passes a stack to any enemy that stays within 1.5 m of a carrier for 1 s, and rises as clouds from the ground and from the bodies it kills.

**Reflux:** high (1.4), unchanged.

## How each parent shows

- **Earth**: Rot in the ground: the sickness heaves up from the floor (Plaguebloom, Exhume), stays where it is put Braced (Plague Barrow), breaks poise the way Earth does (Overrun, Crisis, Plaguebloom), hardens you (Inured Blood), and is lobbed like thrown stone (Fever Flask).
- **Death**: What dies feeds the next: corpses and death-sites are its material (Exhume, the Infected corpse cloud), the Dying pass on more (Contagion), wounds rot (Fester), and a full fever ends all at once (Crisis).

## Disease and Poison, kept apart

Poison is weapon-borne, one body, and pays once, later. Disease ticks every half second, passes body to body by
touch, and comes up out of the ground and the dead. Disease never rides your weapon (Festering Hands is the one
touch skill, and it spreads what is already there).

## Skills

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Fever Flask | Infect | marked blast | Lob a flask up to 12 m: it bursts over shields and heads for 45 and 2 Infected, and leaves a sick cloud 2.5 m across that hangs 6 s and drifts slowly away from you. | **ranged** | existing |
| Crisis | Disinfect | detonate | Every Infected enemy within 10 m has its fever broken at once: 30 a stack, all now, and the stacks are gone. Armour still cuts it. A body broken at 5 stacks is Staggered as well. |  | changed |
| Contagion | Spread | chain | One enemy within 9 m catches it (2 Infected); then every enemy within 3 m of it catches it, and every enemy within 3 m of those - up to 8 bodies, 20 and 1 Infected each. A Dying body passes 2 stacks instead of 1. |  | changed |
| Sealing Clot | Contain | bolt | A clot that sticks to one enemy: 45 and 3 Infected, and for 10 s the sickness is sealed in - it can climb to 10 stacks and burns half again as hard, but never leaves that body. |  | existing |
| Festering Hands | Fester | buff | For 8 s every hit you land on an Infected enemy - bare strikes too - adds a stack, its poise stops refilling while the wound festers, and the nearest other enemy within 2 m catches a stack from it. |  | changed |
| Lancing Cut | Lance | strike | One enemy in reach: a cut that lances its sickness - +25 a stack, the stacks drained - and what drains out hangs around it as a 2.5 m cloud for 5 s. |  | existing |
| Plaguebloom | Billow | burst | A sick cloud heaves up out of the ground round you: everything within 3.5 m takes a blow, 25 poise damage and 1 Infected, and the cloud stays 6 s, drifting the way you face. | **close** | changed |
| Dispersal | Clear | dash | Come apart into fog and gather again 5.5 m away, straight through enemies: each one you pass catches 1 Infected, and a little cloud hangs where you stood for 4 s. | **movement** | existing |
| Teeming Fog | Overrun | zone | Point, 10 m: a thick fog 5 m across for 8 s, drifting slowly away from you. Flesh in it catches a stack every second, and anything that reaches 5 stacks inside it is overrun: its poise breaks once. |  | existing |
| Inured Blood | Immunise | buff | For 8 s you take 5% less damage for each Infected enemy within 8 m, up to 30%. Stand in the sick crowd you made. |  | existing |
| Plague Barrow | Inter | marked blast | Point, 9 m, 0.4 s wind-up (Braced): grave-earth heaves up over a 2.5 m circle. Everything there takes 40, 2 Infected and is Mired. A barrow stays for 10 s: nothing walks through it (shots pass over), and every 2 s it breathes out a 2.5 m puff that gives 1 Infected. |  | new |
| Exhume | Exhume | detonate | Every corpse within 10 m, and every spot where an Infected enemy died in the last 15 s, bursts up out of the ground (up to 4): 50 and 2 Infected to everything within 2.5 m, and a cloud 2.5 m across that hangs 6 s. The corpses are spent. |  | new |

The loop: Fever Flask or Plaguebloom into a packed wall; the wall passes it on by itself (the rule); Contagion jumps
it to the back rank; Plague Barrow holds a doorway and keeps breathing it; when the sick die, Exhume brings it back
up out of their graves; Crisis ends a long fight at once.

## Runes (12)

| Rune | Meaning | Opposite | Role | Draw | Effect | Change | Why |
|---|---|---|---|---|---|---|---|
| Infect | give a disease | Disinfect | link | -0.60 | `status infected 2` | kept | Serves the role as it is. |
| Disinfect | kill it | Infect | cap | +0.60 | `bonus infected +0.4` | kept | Serves the role as it is. |
| Spread | it jumps body to body | Contain | branch | -0.70 | `jumps +1; status infected` | kept | Kept: the role's own verb. The rule now spreads Infected by touch too. |
| Contain | it stays in one body | Spread | cap | +0.60 | `reach x0.75; power x1.3` | kept | Kept as the single-target utility. |
| Fester | wounds rot | Lance | link | +0.30 | `status infected; duration x1.3` | kept | Serves the role as it is. |
| Lance | open and drain a festering wound | Fester | cap | -0.60 | `pierce +1; power x1.1` | kept | Serves the role as it is. |
| Billow | spread the cloud | Clear | branch | -0.80 | `reach x1.35; power x0.9` | kept | Serves the role as it is. |
| Clear | disperse it | Billow | cap | +0.50 | `shove +1; reach x1.15` | kept | Kept, though design/14 section 5 flags Clear / Clarity (Light) / Clarify as too alike; a rename is still owed before the game. |
| Overrun | overwhelm the body's defences | Immunise | link | +0.50 | `poise x1.4; through` | kept | Kept: the place where Earth's poise-breaking shows most. |
| Immunise | build resistance | Overrun | frame | +0.40 | `braced; cost x1.1` | kept | Serves the role as it is. |
| Inter | bury the sick under sick earth, which goes on breathing it out | Exhume | frame | +0.60 | `status mired; status infected` | new | Disease is Earth + Death, and nothing in the old set came from Earth. Inter is Earth's Raise and Bury through Death's Lay: a barrow. A Frame (it holds a structure up: the mound), draw +0.6 because it holds the sickness in the ground. |
| Exhume | dig up the buried, and the grave-rot with it | Inter | branch | -0.60 | `poise x1.2; status infected` | new | Earth's Dig through Death's corpses: the rot that is already in the ground and the dead comes up. A Branch (one cast opens several graves), draw -0.6 because it releases outward; opposite Inter, so the pair bonds ionically. |

No rune renamed or dropped. New: **Inter**, **Exhume** (the Earth pair the set lacked). Clear still owes a rename
(design/14 section 5).

## New mechanics

- **flesh** (field, Fever Flask): New enemy key flesh (0-1): the share of the body not under worn armour. Every Disease hit and tick is multiplied by it. Proposed: Skirmisher, Archer, Harrier, Censer-Bearer, Drummer 1.0; Brute 0.8 (hide); Pavise Bearer 0.6 (mail behind the shield, which a cloud goes round); Wall Commander 0.3 (plate); constructs 0. Corroded raises it toward 1.
- **infected** (status, Fever Flask): Infected (up to 5 stacks, 6 s, refreshed by any new stack): 6 damage a second per stack, times flesh, dealt every 0.5 s through whoever infected it (tags disease, dot). When an Infected body dies it leaves a corpse cloud 2 m across for 4 s that does not drift.
- **cloud** (behaviour, Fever Flask): A cloud is a ground_zone that gives 1 Infected a second to every enemy inside (no faster, however many clouds overlap), drifts at drift_speed (away from the caster, along the aim, or not at all), stops against walls and stone, and ignores shields, facing and armour except through flesh.
- **lobbed** (field, Fever Flask): A lobbed delayed_blast flies over bodies and shields to its point; only walls and stone taller than 1.8 m stop it.
- **stagger_at** (field, Crisis): A consume_status key: a target that held at least this many stacks when they were consumed is Staggered (the existing status).
- **fan** (field, Contagion): A chain with fan jumps from each body hit to every not-yet-hit enemy within jump_radius of it, for depth generations, up to jumps bodies in all (Forked Path jumps to one at a time).
- **dying_stacks** (field, Contagion): A chain key: a jump that starts from a Dying body (below half health) carries this many stacks of on_hit's status instead of its own.
- **contained** (status, Sealing Clot): Contained (1 stack, 10 s): its Infected cap is 10 and its ticks are x1.5; nothing spreads from it and it leaves no corpse cloud; when Contained ends, stacks above 5 fall away.
- **festering** (status, Festering Hands): Festering (1 stack, 3 s, refreshed): its poise does not refill.
- **on_infected_hit spread** (field, Festering Hands): A self_buff key pair: with spread_radius, each on_infected_hit also gives spread_stacks Infected to the nearest other enemy within spread_radius of the target.
- **overrun_at** (field, Teeming Fog): A cloud with overrun_at staggers (poise broken, the existing Staggered) each enemy whose Infected reaches that many stacks while inside it, once per enemy per cast.
- **dr_per_infected** (field, Inured Blood): While the buff lasts, damage taken is cut by dr_per_infected for each Infected enemy within radius, up to dr_max; counted when each hit lands.
- **vents** (field, Plague Barrow): A prop key: every 'every' seconds the prop applies payload to every enemy within radius of it, flesh and the cloud rules applying (no faster than 1 Infected a second in all, as for clouds).
- **grave sites** (behaviour, Exhume): A detonate key set: every corpse within range (spent if spends_corpse) and every point where an Infected enemy died within recent_infected_death_s count as sites, nearest first, up to max_sites; each bursts on_hit within burst_radius and leaves leave_zone. Refused before essence is spent when there is no site.
- **infected spreads** (status, the rule): Infected (changed): an enemy within 1.5 m of an Infected one for 1 s catches 1 stack in the carrier's name (once a second, whatever the number of carriers); times flesh as every Disease tick.

Kept and still used: flesh, infected, cloud, lobbed, fan, contained, festering, overrun_at, dr_per_infected.

## Unsure

- Touch-spread on the status itself is a big change: a tight Pavise line will infect itself. 1.5 m and 1 s are
  Alight's numbers; it may need to be slower than fire.
- Crisis is still a cash-in (all stacks now). It is the one place Disease pays like Poison; it stays dear (18)
  and ticks are still the main damage.
- Plague Barrow is a mound that blocks walking, like Earth's stone. It does not count toward Earth's three-stone
  limit (that is Earth's rule, not Disease's); a character holding both might need one shared limit.
- Exhume uses corpses as Death does. For a character without Death a corpse lies 8 s, so the death-site rule (15 s)
  is what makes it work.
