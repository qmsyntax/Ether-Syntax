# Ice skills v2: control (Water + Dark)

Draft for Brent, 2026-10-24, to `ROLES-BRIEF.md`. Nothing here is built. Data: `ice.json`, `ice-runes.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention; everything untagged is [MODEL]. All names are original.

**Role [B 2026-10-24]: control, built from Water's flow and Dark's stillness.** Ice decides where bodies go and when
they stop: it slides them, walls them, holds them still, and freezes what stays.

**Rule:** Cold stays: every ice hit adds Chill, which never wears off by itself (Dark's stillness); at 5 Chill the target freezes solid, and a frozen thing is Brittle, so the next hard hit Shatters it. Wet freezes fast (Water's flow): an ice hit on a Soaked target adds one more Chill and ends the Soak.

## How each parent shows

- **Water's flow**: ice moves bodies as water's child - Floe Drive shoves and Crushes, Black Ice doubles shoves like a
  frozen pool, Rime Wall is a wall to Crush against, Runoff leaves them Soaked, and the rule makes the wet freeze fast.
- **Dark's stillness**: cold that never wears off by itself (the rule), Dead Calm's total halt, Frost's grip on the
  ground (Pin), Whiteout's blind (Obscure), Craze's hidden cracks (Expose).
- Skills by parent trait: Dark 3, Water 7, Water + Dark 2.

**Reflux: low** (as before): control is laid over several casts. **Bands:** damage low (30-50 a hit, Runoff and
Fracture the cash-outs); costs cheap to mid.

## Skills (12: 9 serve the role directly)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Set Solid | Freeze | melee_burst | The air around you sets. Everything within 3.5 m takes 30 damage and 3 Chill: two more and it freezes solid. | close | existing |
| False Spring | Thaw | detonate | Every Frozen enemy within 10 m thaws at once, and the cold it held pours out: 50 damage and 3 Chill to every other enemy within 3 m of it. It frees what you froze, to freeze the ones beside it. |  | existing |
| Hoarline | Frost | projectile | A line of frost races 10 m along the ground: 45 damage and 2 Chill to everything on it. The line stays frosted for 4 s, adding a Chill a second to anyone standing on it. Walls stop it. | ranged | existing |
| Black Ice | Glaze | dash | Lay a strip of glaze 6 m ahead and slide the length of it. The glaze stays 5 s: you move 30% faster on it; enemies on it keep slipping, losing poise every half second, and a shove that starts on it goes twice as far. | movement | changed |
| Whiteout | Snow | ground_zone | Point, 10 m: snow falls over a circle 3.5 m across for 6 s. Enemies inside cannot see past 2 m (Blinded) and gain a Chill every second. Archers inside lose you. |  | existing |
| Runoff | Melt | beam | An instant line 8 m long melts the cold out of everything on it: 25 damage plus 30 for every Chill it carried, and the Chill is gone. A Frozen one counts as 5 and is freed. All of them are left Soaked. |  | existing |
| Rime Wall | Rime | prop | Point, 10 m: a wall of rime 5 m long rises across your aim in a quarter second and stands 6 s. It blocks walking and every shot, as standing stone does. Anyone it rises under is shoved 1 m clear and gains 2 Chill; a body shoved into it is Crushed, as against stone. A hard hit (yours or theirs) shatters it early: 40 and a Chill to everyone within 2.5 m. Two at a time. |  | new |
| Fracture | Shatter | targeted_strike | One enemy in reach: a hammer blow, 2.0x strike damage and 60 poise. If it is Frozen or Brittle it Shatters for +120 more, and the shards fly 4 m instead of 2.5. |  | existing |
| Craze | Brittle | delayed_blast | Point, 9 m: fine cracks race through a 3 m circle for half a second, then everything in it is Brittle for 5 s: its next hard hit Shatters it, frozen or not. The way to break what will not freeze. |  | existing |
| Ice Shell | Toughen | self_buff | A shell of ice closes over you for 8 s: a 60 Ward (the shared cap). When it is broken it bursts: 40 damage and 2 Chill to everything within 2.5 m. |  | changed |
| Dead Calm | Stasis | smite | One enemy within 10 m goes utterly still for 2.5 s: it cannot move or act, whatever it was winding up is lost, and every status on it stops running down. It gains 2 Chill, and when the calm breaks it is Stilled - the next shove or drag on it goes twice as far. Heavy enemies hold half as long; an elite is only Stilled. |  | new |
| Floe Drive | Floe | projectile | A sheet of ice 3 m wide slides out 9 m along the floor: everything it meets takes 30 and 2 Chill and is shoved 3 m along with it. A body it drives into a wall, stone or another body is Crushed, as water's are. |  | new |

Starters: **Hoarline** (ranged), **Set Solid** (close), **Black Ice** (movement).

### Dropped

- **Icicle** (Rime): A heavy damage bolt is a burst caster's; Ice is control. Its rune Rime now builds the wall (Rime Wall). Ranged Shatters come from any hard hit, and Fracture up close.

## Runes: 10 -> 12

| Rune | Meaning | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|---|
| Freeze | lock solid | Thaw | frame | +0.5 | status chilled 2 | kept |
| Thaw | release, melt free | Freeze | link | -0.6 | reach x1.2; windup x0.85 | kept |
| Frost | creeping cold on the ground that grips and slows | Glaze | link | +0.4 | status chilled; duration x1.2 | kept |
| Glaze | glazed ice: fast and slippery | Frost | link | -0.5 | speed x1.3; windup x0.9 | kept |
| Snow | a fall of snow that blinds and buries | Melt | branch | -0.5 | reach x1.2; status blinded | kept |
| Melt | turn ice and snow to water | Snow | link | +0.4 | bonus chilled +0.3; status soaked | kept |
| Rime | build ice: walls, armour, spikes | Shatter | frame | +0.3 | power x1.15; poise x1.2 | kept |
| Shatter | break ice; brittle things burst | Rime | branch | -0.9 | bonus frozen +0.5; poise x1.25 | kept |
| Brittle | make a thing fragile | Toughen | link | -0.3 | status brittle | kept |
| Toughen | cold-harden it | Brittle | frame | +0.3 | duration x1.4; speed x0.9 | kept |
| Stasis | deep cold that halts everything | Floe | cap | +0.8 | interrupts; status stilled | new |
| Floe | drifting ice carried by the current | Stasis | link | -0.5 | shove +1.5; status chilled | new |

- **Freeze** (kept): The lock. Draws on: Dark: stillness (Pin's hold, made cold).
- **Thaw** (kept): The release that spreads the cold. Draws on: Water: flow, set going again.
- **Frost** (kept): Ground that grips. Draws on: Dark: Pin (the ground holds you).
- **Glaze** (kept): Ground that slides. Draws on: Water: a pool set hard (shoves on it go twice as far).
- **Snow** (kept): Blinds and buries. Draws on: Dark: Obscure (blinds); Water: Flood (falls over an area).
- **Melt** (kept): The cash-out that leaves them wet. Draws on: Water: Soak.
- **Rime** (kept): Now the wall (Rime Wall). Draws on: Water: built up and set; a wall to Crush against.
- **Shatter** (kept): The payoff. Draws on: Water: Splash (bursts outward on contact).
- **Brittle** (kept): Breaks what will not freeze. Draws on: Dark: Expose (a hidden weakness made to show).
- **Toughen** (kept): The shell. Draws on: Water: the bruiser's hardness (Backwash).
- **Stasis** (new): Ice's hold on one body. Ice had no Cap; Stasis ends a structure the way a full stop ends motion. Draw +0.8, near Dark's Pin (+0.9): it holds inward. Effect gives Water's Stilled. Draws on: Dark: Pin and Hush (stillness); Water: Slack (the still moment at the turn of the tide, dropped from Water).
- **Floe** (new): Ice that moves bodies, as Water's child: a Link that carries along (as Sweep was), draw -0.5, between Water's Surge (-0.6) and Sweep (-0.4). Draws on: Water: Surge and Sweep (dropped from Water).

## New mechanics

Mechanics from the 2026-10-22 drafts (Soaked, Chilled, Lit, Unseen, light level, sees_caster...) are built and not repeated; only what is new in v2 is listed.

- **wet_freezes** (field, affinity rule): Affinity key 'chill_bonus_vs' {soaked: 1}: an ice hit on a target that counts as Soaked (Waterlogged included) adds that many more Chill, and the Soak ends (the water is now ice). Chilled, Frozen, Brittle and Shatter are built and unchanged.
- **ice_wall (prop shape)** (behaviour, from Rime Wall): A Stone (scripts/stone.gd: blocks walking, rays and shots; enemies go round by Stone.way_round) with material ice, a 'life' after which it melts, and 'shatter_burst' when a hard hit (40+ poise, a bare strike, a Crush into it) breaks it early. on_rise hits what it rises under, as Raise Slab's does.
- **stasis** (status, from Dead Calm): 1 stack, 2.5 s: cannot_act, control, and 'freezes': 'all' (no other status on it runs down while it lasts); heavy_lasts_mult 0.5; elite_status 'stilled'; on_expire {status: 'stilled'} (Water's Stilled: 60% slower, the next shove or pull x2, once).
- **crushes** (field, from Floe Drive): A skill of any affinity with crushes: true uses Water's Crush rule (Player.on_crush, balance.json 'shove') for its shoves: a body it shoves into a wall, stone or body is Crushed. The Ward from crush_ward stays Water's.

## Notes and open questions

- **Stilled** (Water's Slack Water status) stays in statuses.json for Ice even though Slack Water is dropped from Water.
- **Floe Drive and Rime Wall give Ice the Crush** through `crushes`. If Crush should stay Water's alone, drop the
  flag and Floe Drive is a chilling shove only.
- **Rime Wall reuses Stone.** Earth (the area tank) owns lasting walls; ice's melts in 6 s and shatters.
- **Stasis and Floe have no workbook ids**; `ICE-6a` / `ICE-6b` are proposals.
- 'freezes: all' generalises Life's Arrested ('freezes' a list of statuses).
