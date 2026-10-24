# Dark skills v2: the assassin

Draft for Brent, 2026-10-24, to `ROLES-BRIEF.md`. Nothing here is built. Data: `dark.json`, `dark-runes.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention; everything untagged is [MODEL]. All names are original.

**Role [B 2026-10-24]: assassin - stealth, rear hits, darkness.** Make the dark, vanish into it, come out at a back
for an Ambush, and finish what is left. Enchanting is Dream's now [B]; Dark keeps none of it.

**Rule:** Dark is strongest where the light is weakest: every spot is Lit, Dim or Dark; dark hits do +25% to a target standing in Dark and -20% in Lit; you are Unseen while you stand in Dark, and your first hit out of Unseen is an Ambush - it counts as from behind and does +50%.

**Reflux: middling** (as before). **Bands:** single-target hits sit high (Hungry Dark 2.2x before the rear and Ambush
multipliers; an Ambush from behind is 2.2 x rear x 1.5), area damage stays low; costs cheap to mid, so the
vanish-strike-vanish loop can run.

## Skills (10: 8 serve the role directly)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Blot | Darken | projectile | A blot of darkness, thrown: 60 damage, and where it lands the ground goes Dark in a circle 2.5 m across for 6 s. Hit them again while they stand in it. | ranged | existing |
| Daybreak | Lighten | detonate | Every pool of your darkness within 12 m lifts at once. Each enemy standing in one is caught in the sudden light: Dazed for 1.5 s and Exposed for 4 s. You lose the dark you made. |  | existing |
| Pall | Obscure | ground_zone | Darkness pours out of you: a pall 3.5 m across at your feet for 6 s. Every enemy that had you in its sights loses you at once and goes to where it last saw you. Nothing sees into it or through it, those inside are Blinded, and you are Unseen in it - so your first hit out is an Ambush. |  | changed |
| Silhouette | Expose | new:smite | One enemy within 12 m is outlined against the dark for 6 s: every hit on it counts as from behind (+30%, and a raised shield does not help). If it stands in Dark it is Blinded as well. |  | existing |
| Shadow Slip | Shadowstep | blink | Sink into the dark and rise from another shadow up to 10 m away: a Dark spot, or the shadow behind an enemy, which puts you at its back. Your first hit within 1 s counts as from behind. It cannot take you into the light. | movement | existing |
| Shadownail | Pin | delayed_blast | Point, 9 m: a black nail is driven into the shadows in a circle 1.5 m across. Whatever stands there after a quarter second takes 50 and is Shadowbound for 2.5 s (4 s in Dark): rooted where it stands, though it can still turn and swing. |  | existing |
| Muffle | Hush | self_buff | For 6 s you make no sound. Striking no longer reveals you while you are Unseen, so every hit can be an Ambush; an enemy you hit that was not facing you takes +50%; and anything you kill raises no alarm - no call for help, and nobody within 10 m wakes. |  | changed |
| Stray Echo | Resound | prop | Throw a sound into the dark - a footstep, a dropped blade - at a spot up to 14 m away. For 3 s every enemy within 8 m of it that is not in melee with you turns to face it and goes to look, its back to you. Anything within 1.5 m of the spot is interrupted. It is heard, not seen: it needs no sight line. |  | new |
| Hungry Dark | Devour | targeted_strike | One enemy in reach: the dark bites. 2.2x strike damage (more from behind, and an Ambush out of Unseen), and it swallows 1 light. If the bite leaves it under 20% health it is swallowed whole: it dies, you get 4 essence back and a second light, and the dark closes over you - Unseen for 1.5 s wherever you stand. The ground under it goes Dark for 4 s. | close | changed |
| Night Spill | Disgorge | melee_burst | Let out what the dark swallowed in a narrow gout 6 m long: 30, plus 35 for each light swallowed, to everything in it. At 3 or more they are Dazed; one left under 15% health is finished. The ground it covers goes Dark for 5 s. |  | changed |

Starters: **Blot** (ranged - makes the dark you hide in), **Hungry Dark** (close - the bite that executes and
vanishes), **Shadow Slip** (movement - to its back).

The loop: Blot the pack (Dark ground) -> stand in it, Unseen -> Shadow Slip behind the archer -> Hungry Dark as an
Ambush -> under 20% it is swallowed and you vanish -> Stray Echo turns the rest away -> again.

### Dropped

- **Knell** (Resound): A tolling area-damage zone is not an assassin's, and Resound is re-meant as a thrown sound that turns heads (Stray Echo). Area damage in Dark is Night Spill's.

## Runes: 10, one re-meant

| Rune | Meaning | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|---|
| Darken | make it darker | Lighten | link | +0.5 | power x1.15; duration x1.2 | kept |
| Lighten | let the light back in | Darken | branch | -0.6 | status dazed; windup x0.85 | kept |
| Obscure | hide a thing in darkness | Expose | frame | +0.3 | status blinded; duration x1.2 | kept |
| Expose | make a hidden target stand out | Obscure | cap | -0.4 | status exposed | kept |
| Shadowstep | move through shadows | Pin | link | -0.3 | reach x1.35; windup x0.9 | kept |
| Pin | nail a target's shadow, and the target with it | Shadowstep | cap | +0.9 | status shadowbound | kept |
| Hush | smother sound | Resound | cap | +0.4 | windup x0.8; duration x1.2 | kept |
| Resound | a sound thrown into the dark that draws every ear | Hush | branch | -0.5 | interrupts; reach x1.15 | re-meant |
| Devour | swallow light and energy | Disgorge | cap | +1.0 | cost x0.85; reflux x0.85 | kept |
| Disgorge | release what was swallowed | Devour | branch | -1.0 | power x1.25; reflux x1.15 | kept |

- **Resound** (re-meant): Was 'sound carries and echoes in the dark' (Knell, an area-damage bell). Re-meant to the assassin's thrown sound: it turns heads away from you. Role and draw kept (a branch that spreads outward). Effect was 'reach x1.2; poise x1.2': a sudden noise now breaks concentration (interrupts) and carries farther.

## New mechanics

Mechanics from the 2026-10-22 drafts (Soaked, Chilled, Lit, Unseen, light level, sees_caster...) are built and not repeated; only what is new in v2 is listed.

- **ambush** (field, affinity rule): Affinity key 'ambush_mult' (Dark 1.5): the caster's first hit while Unseen (standing in Dark, Vanished, or any other unseen rule) counts as a rear hit (rear_mult, frontal block ignored) and is multiplied by ambush_mult; the hit then reveals you as now (1 s), unless Muffled. Light level, dark ground and Unseen are already built (2026-10-22 drafts) and are not redefined.
- **drops_aggro** (field, from Pall): On cast, every enemy whose target is the caster loses it and goes to the last place it saw you (as when Unseen begins); melee enemies give up their slot.
- **echo** (behaviour, from Stray Echo): Prop shape 'echo': an unseen Lure (the existing Lure, read in enemy._pick_target) that is heard: every enemy within lure_radius that does not hold a melee slot on the caster faces it and walks to it for turn_s, then resumes; a hit on one ends it for that one. on_hit lands once on enemies within crack_radius when it is set.
- **on_kill** (field, from Hungry Dark): A payload applied to the caster when the skill's hit kills: 'essence' back (never more than the cost), 'swallow' added to the swallowed store, 'self_unseen_s' of Vanish.
- **vanish** (status, from Hungry Dark): On the player, 'self_unseen_s' long: Unseen anywhere (not only in Dark), with the Unseen rule's 4 m; ends on your next hit (that hit is an Ambush) unless Muffled.

## Notes and open questions

- **Light's Bent Light (unseen beyond 3 m) is dropped in the Light v2 draft**: stealth is Dark's alone now. The
  merged player 'unseen' rule (statuses.json `_note`) loses that source.
- **Ambush stacks with the rear bonus** (2.2 x rear_mult x 1.5 from behind). If that is too much, make Ambush the rear
  hit itself (no extra 1.5) and keep +25% in Dark.
- `execute_below` is an existing payload key; Hungry Dark's 20% and Night Spill's 15% are first guesses.
- Pall moved to your feet. The old point-cast blind-the-archers use is lost; Pall can still be dropped where you
  stand next to them after a Shadow Slip.
