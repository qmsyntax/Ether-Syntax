# Ice skills, one per base rune: draft v0

Draft for Brent, 2026-10-22, to the brief in `BRIEF.md`. Nothing here is built. Data: `ice.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention. Everything not tagged is [MODEL]. All skill names are original.

Ice is new. It takes water's old Freeze rune [B 2026-10-21] and the revised rune set's ten ice runes. Kept apart from water (ice never moves a body, it holds it still), earth (no blocking walls: Rime makes spikes) and light.

## Rule

**Cold stays: every ice hit adds Chill, which never wears off by itself; at 5 Chill the target freezes solid, and a frozen thing is Brittle, so the next hard hit Shatters it.** [MODEL]

*Refined from the first pass* (design/14: 'what it freezes stays frozen; cold builds up on a target until it locks solid; frozen things turn brittle and break'). The first pass is kept and made countable. 'Stays' becomes a concrete promise the player can see: Chill has no timer (only fire, Melt and Thaw take it off), where lightning's marks fade in 8 s. That is the line between the two build-up affinities: lightning's third mark goes off by itself and spreads; ice's fifth Chill only locks, and paying it out takes a deliberate hard hit. 'Hard hit' is defined with numbers the game already has (a bare strike, or 40+ poise), so base strikes and heavy skills from any affinity can Shatter. A frozen body takes half damage from everything but a Shatter, so freezing is control first and the payout must be chosen. Elites never lock; they go Brittle instead, so ice still has an answer to them.

**Reflux: low.** Low (x0.7). Ice wins by laying cold over several casts and cashing it in once, so it must be able to cast four or five times in a row without locking; and cold is the opposite end of the heat axis from fire, which runs high. Its skills sit cheap to mid in essence.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Set Solid *(new)* | Freeze (ICE-1a) | melee_burst | The air around you sets. Everything within 3.5 m takes 30 damage and 3 Chill: two more and it freezes solid. | **close burst** |
| False Spring *(new)* | Thaw (ICE-1b) | detonate | Every Frozen enemy within 10 m thaws at once, and the cold it held pours out: 50 damage and 3 Chill to every other enemy within 3 m of it. It frees what you froze, to freeze the ones beside it. |  |
| Hoarline *(new)* | Frost (ICE-2a) | projectile | A line of frost races 10 m along the ground: 45 damage and 2 Chill to everything on it. The line stays frosted for 4 s, adding a Chill a second to anyone standing on it. Walls stop it. | **ranged** |
| Black Ice *(new)* | Glaze (ICE-2b) | dash | Lay a strip of glaze 6 m ahead and slide the length of it. The glaze stays 5 s: you move 30% faster on it, and enemies standing on it keep slipping, losing poise every half second. | **movement** |
| Whiteout *(new)* | Snow (ICE-3a) | ground_zone | Point, 10 m: snow falls over a circle 3.5 m across for 6 s. Enemies inside cannot see past 2 m (Blinded) and gain a Chill every second. Archers inside lose you. |  |
| Runoff *(new)* | Melt (ICE-3b) | beam | An instant line 8 m long melts the cold out of everything on it: 25 damage plus 30 for every Chill it carried, and the Chill is gone. A Frozen one counts as 5 and is freed. All of them are left Soaked. |  |
| Icicle *(new)* | Rime (ICE-4a) | projectile | A spike of ice grown in your hand and thrown, slow and heavy: 80 damage, 45 poise and a Chill. It is a hard hit, so it Shatters anything Brittle or Frozen it reaches. |  |
| Fracture *(new)* | Shatter (ICE-4b) | targeted_strike | One enemy in reach: a hammer blow, 2.0x strike damage and 60 poise. If it is Frozen or Brittle it Shatters for +120 more, and the shards fly 4 m instead of 2.5. |  |
| Craze *(new)* | Brittle (ICE-5a) | delayed_blast | Point, 9 m: fine cracks race through a 3 m circle for half a second, then everything in it is Brittle for 5 s: its next hard hit Shatters it, frozen or not. The way to break what will not freeze. |  |
| Ice Shell *(new)* | Toughen (ICE-5b) | self_buff | A shell of ice closes over you for 8 s and takes the next 80 damage. When it breaks it bursts: 40 damage and 2 Chill to everything within 2.5 m. |  |

## Rune effects (as a modifier)

| Rune | Meaning | Effect |
|---|---|---|
| Freeze | lock solid | `status chilled 2` |
| Thaw | release, melt free | `reach x1.2; windup x0.85` |
| Frost | creeping cold on the ground that grips and slows | `status chilled; duration x1.2` |
| Glaze | glazed ice: fast and slippery | `speed x1.3; windup x0.9` |
| Snow | a fall of snow that blinds and buries | `reach x1.2; status blinded` |
| Melt | turn ice and snow to water | `bonus chilled +0.3; status soaked` |
| Rime | build ice: walls, armour, spikes | `power x1.15; poise x1.2` |
| Shatter | break ice; brittle things burst | `bonus frozen +0.5; poise x1.25` |
| Brittle | make a thing fragile | `status brittle` |
| Toughen | cold-harden it | `duration x1.4; speed x0.9` |

Each effect also names what the skills built on that rune do, so when another rune out-pulls the anchor, the right part of the skill shrinks (the `signature`).

## New mechanics

- **chilled** (status, from Set Solid): Up to 5 stacks, no timer: each stack slows movement 8%. At 5 the target is Frozen and the stacks clear. Only fire (any Alight), Melt, Thaw, a Shatter, or 10 s with no enemy in sight takes Chill off.
- **frozen** (status, from Set Solid): 1 stack, 3 s (heavy enemies 1.5 s): cannot move or act, takes half damage from everything except a Shatter, and counts as Brittle. If it runs out it leaves 2 Chill. Elites never freeze: at 5 Chill they are Brittle for 4 s instead.
- **brittle** (status, from Set Solid): 1 stack, 5 s: the next hard hit on it (a bare strike, or any hit with 40+ poise damage) Shatters it.
- **shatter** (behaviour, from Set Solid): A hard hit on a Frozen or Brittle enemy: 100 damage to it, not halved, and shards hit every other enemy within 2.5 m for 40 and 1 Chill. Ends Frozen and Brittle. Talents see it as damage you dealt.
- **thaw burst** (behaviour, from False Spring): detonate with consume_status 'frozen': each Frozen enemy in range is freed (it keeps the 2 Chill Frozen leaves) and on_hit is applied to every other enemy within burst_radius of it.
- **projectile trail** (behaviour, from Hoarline): A projectile may carry 'trail' (as Flashover's dash does): a strip of ground along its path that applies trail.payload every tick_s for trail.life.
- **frosted ground** (field, from Hoarline): Ground left by an ice skill: 1 Chill a second to an enemy standing on it. Fire on it clears it.
- **glaze** (field, from Black Ice): A glazed strip: the caster moves trail.caster_speed_mult faster on it; an enemy on it loses trail.payload.poise every tick_s (it keeps slipping). Fire on it clears it.
- **beam consume** (behaviour, from Runoff): A beam may 'consume_status': each enemy it hits loses that status and takes per_stack_damage per stack (a Frozen enemy counts as frozen_counts_as stacks and is freed), as a detonate does.
- **absorb shell** (behaviour, from Ice Shell): self_buff 'absorb': takes that much damage before health does (after armour); when it is used up, 'on_break' bursts around you; if the time runs out first it melts with no burst.
- **blinded** (status): used by Whiteout and the Snow effect; defined once in `dark.json` (Pall).

## Modifiers, checked

Every good and bad modifier was run through a copy of `effects_v1.gd`'s rules (one rune bonded straight to the skill's own rune; bond kind from electronegativity; universal runes at their placeholder 2.5). Every good one applies all its ops. Every bad one either falls back to the quarter-power consolation, is cancelled by an ionic bond, or out-pulls the skill's own rune; where the maths would accept a bad one, its entry says why it still makes no sense.

## Notes and open questions

- **The starter loop costs 19 essence**, like lightning's 20: Hoarline (2 Chill) + Set Solid (3 Chill) = Frozen, then a bare strike Shatters it.
- **A status op cannot add stacks to a status a skill already applies** (`effects_v1.gd`: 'already applies it'). So Freeze and Frost, ice's own cold runes, fall back on most ice skills, which already chill. They work on other affinities' skills (a dual-affinity character) and on Fracture, Craze and Black Ice. If ice should be able to stack its own cold, the status op needs a 'more stacks' case.
- **Icicle and earth's Slingstone are close cousins** (slow, heavy, poise). Icicle is cheaper, weaker, does not interrupt, and its job is to Shatter from range.
- **Chill with no timer** needs a safety: it clears after 10 s with no enemy in sight, so it cannot follow an enemy between rooms forever.
- **Frozen takes half damage from everything but a Shatter.** This makes freezing control first, and makes other affinities' area damage weaker on frozen bodies. It may want testing against a dual ice/fire character, since fire also removes Chill.
