# Dream skills v2: the enchanter (Light + Dark)

Draft for Brent, 2026-10-24, to `ROLES-BRIEF.md`. Nothing here is built. Data: `dream.json`, `dream-runes.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention; everything untagged is [MODEL]. All names are original.

**Role [B 2026-10-24]: enchanter, built from Light and Dark's twilight.** Dream does little damage; it puts minds to
sleep, sends them running, turns them on each other, slows them with doubt, and makes you and what you have turned
better at it. Enchanting moved here from Dark [B].

**Rule:** A Dream skill takes hold only of a mind that can see it (Light's half: you, or the thing you made, in its front arc with a clear line) or that is asleep (Dark's half); it ignores armour and shields, does +30% to the Dazed and the Asleep, its statuses last half again as long on them and a quarter longer on a target standing in Dim light - the twilight. Mindless things never feel it.

## How each parent shows

- **Light**: the target must *see* (the rule's first half), false images (Doubling Step, Conjure - Bend's old
  meaning), reveal (Read the Tell), the clear waking mind (Lucid), breaking spells (Shattered Dream).
- **Dark**: sleep (Dozing Mote, the rule's second half), fear of the dark (Night Terror), hiding in another's shape
  (Changeling Mask), the voice in the quiet (Errand), the shut mind (Shutter).
- **Both, the twilight**: Dim light lengthens every Dream status (the rule); Quiet Hour (glow and hush), Sweet Lie
  (the warm light and the half-truth), Misgiving (half-seen, so nothing is certain).
- Skills by parent trait: Dark 5, Light 4, Light + Dark 3.

**Reflux: middling** (as before). **Bands:** damage low (15-50); statuses are the power; costs mid, Sweet Lie dear-ish
(14) because it takes an enemy out of the fight and puts it on yours.

## Skills (12: 10 serve the role directly)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Dozing Mote | Sleep | projectile | A slow, drifting mote: 45, and the target nods. The first mote Dazes it; a second on a Dazed target puts it to sleep for 4 s. It must see the mote coming. | ranged | existing |
| Lucid | Wake | self_buff | For 6 s you are wide awake while they dream: your Dream statuses last 30% longer and your casts recover 30% faster. Your phantoms and every mind you have turned within 12 m share it: they deal 30% more, and a phantom takes one more blow to break. |  | new |
| Doubling Step | Conjure | dash | Step 5 m aside and leave a phantom of yourself behind for 3 s. Enemies that were watching you go for the phantom instead; it breaks at the first blow. | movement | existing |
| Shattered Dream | Dispel | detonate | Every enemy within 10 m under one of your Dream spells wakes from it at once: 50 each, 100 to sleepers, and all of them are Dazed for 2 s. Your phantoms burst for 40. |  | existing |
| Night Terror | Dread | melee_burst | For a moment you are the thing under the bed: everything within 4 m that sees you takes a blow and is Terrified for 2 s - it turns, runs, and will not attack. | close | existing |
| Quiet Hour | Soothe | ground_zone | Point, 9 m: a hush 3.5 m across for 7 s. Enemies in it that see it are Soothed: they move 30% slower and start no attacks. Hitting one snaps it out. |  | existing |
| Changeling Mask | Mimic | new:gaze | One enemy within 10 m that sees you wears your face for 4 s. Its friends within 8 m that see it take it for you and attack it, and it fights back. |  | existing |
| Read the Tell | Unmask | new:gaze | One enemy within 12 m that sees you shows its hand for 8 s: every attack it starts can be interrupted, and any hit during its wind-up staggers it. Works on elites. |  | existing |
| Errand | Whisper | new:gaze | Point, 10 m: the enemy nearest that spot that can see you (or is asleep) walks to it and stands there 2 s without attacking - into your pool, out of the line, away from the Drummer. A hit breaks it. |  | existing |
| Shutter | Shut | delayed_blast | Point, 10 m: minds within 3.5 m that see it close up: 25, and for 8 s they cannot be Drummed or Roused, and cannot call for help or answer a call. |  | existing |
| Sweet Lie | Charm | smite | One enemy within 10 m that sees you believes, for 5 s, that it is on your side. It turns on the nearest of its friends, and they answer it. It counts as your summon (Lucid reaches it); hit it yourself and the lie ends. Heavy enemies believe half as long; an elite is only Dazed. |  | new |
| Misgiving | Doubt | melee_burst | A cone 7 m long of things half-seen: every enemy in it that sees you takes 15 and is Doubting for 6 s - its wind-ups take half again as long and its blows land 30% softer. Heavy enemies and elites doubt for half as long. |  | new |

Starters: **Dozing Mote** (ranged), **Night Terror** (close), **Doubling Step** (movement).

Buffs on yourself and your summons: **Lucid** (you, your phantoms and your Charmed). There are no party allies.

### Dropped

- **Rousing Blow** (Wake): A heavy melee strike is a bruiser's; the enchanter does not hit hard. The sleeper payoff is Shattered Dream (100 to sleepers) and the rule's +30%; Wake now rouses your own mind and your summons (Lucid).

## Runes: 10 -> 12

| Rune | Meaning | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|---|
| Sleep | put to sleep | Wake | cap | +0.6 | status asleep | kept |
| Wake | rouse; break a trance - your own mind included | Sleep | link | -0.5 | bonus asleep +0.5; poise x1.2 | re-meant |
| Conjure | an illusion | Dispel | branch | -0.5 | jumps +1; cost x0.9 | kept |
| Dispel | break illusions | Conjure | cap | +0.5 | interrupts; bonus dazed +0.2 | kept |
| Dread | terror | Soothe | link | +0.5 | status terrified | kept |
| Soothe | calm, bliss | Dread | link | -0.5 | status soothed; reflux x0.85 | kept |
| Mimic | take another's look or voice | Unmask | link | +0.4 | status masked; cost x1.15 | kept |
| Unmask | reveal a disguise | Mimic | cap | -0.4 | status read | kept |
| Whisper | plant a command | Shut | link | -0.6 | pull +2; interrupts | kept |
| Shut | close the mind to others | Whisper | cap | +0.7 | status shut | kept |
| Charm | win a mind over: for a while it is yours | Doubt | frame | +0.5 | status charmed; cost x1.15 | new |
| Doubt | plant doubt: nothing is done with conviction | Charm | branch | -0.6 | status doubting | new |

- **Sleep** (kept): The mesmerise. Draws on: Dark: night and rest (Hush).
- **Wake** (re-meant): Meaning widened to your own mind and your summons (Lucid, the enchanter's self and summon buff). Role, draw and effect kept. Draws on: Light: dawn (Dark's Lighten, Light's Shine).
- **Conjure** (kept): The phantom. Draws on: Light: Bend's false images (moved here from Light).
- **Dispel** (kept): The cash-in. Draws on: Light: Clarity.
- **Dread** (kept): Fear. Draws on: Dark: fear of the dark.
- **Soothe** (kept): Pacify. Draws on: Light: Glow (a steady soft light); Dark: Hush.
- **Mimic** (kept): Turn them on one of their own. Draws on: Dark: Obscure (hide in another shape).
- **Unmask** (kept): Read the tell. Draws on: Light: Shine; Dark: Expose.
- **Whisper** (kept): The errand. Draws on: Dark: Hush (a voice in the quiet).
- **Shut** (kept): Cut off the drum and the call. Draws on: Dark: Obscure (a mind shut in the dark).
- **Charm** (new): The enchanter's turn-coat: a charmed enemy fights for you and counts as your summon. A Frame (it holds a mind in your structure); Dream had none. Draw +0.5: it takes a mind in. Draws on: Light: Glow (the light that draws the eye); Dark: the half-truth.
- **Doubt** (new): The enchanter's slow: wind-ups longer, blows softer. A Branch (doubt spreads), giving outward (-0.6), opposite in draw to Charm. Draws on: Light and Dark at once: the twilight, where you cannot trust your eyes.

## New mechanics

Mechanics from the 2026-10-22 drafts (Soaked, Chilled, Lit, Unseen, light level, sees_caster...) are built and not repeated; only what is new in v2 is listed.

- **twilight** (field, affinity rule): Affinity key 'status_time_dim' (Dream 1.25): a status a Dream skill applies lasts that much longer on a target standing in Dim light (Light.level_at, neither Lit nor Dark); it multiplies with status_time_vs. needs_seen, bonus_vs_status and status_time_vs are built and unchanged.
- **buff_targets** (field, from Lucid): A self_buff with buff_targets ['self', 'summons'] also applies to the caster's summons within 'radius' (and any that come within it while it lasts): Thralls, phantoms (leave_decoy) and Charmed enemies. Keys that mean nothing on a summon are ignored; summon_deals_mult and phantom_extra_hits are read only on summons.
- **charmed** (status, from Sweet Lie): 1 stack, 5 s: it fights for the caster - targets the nearest of its former allies, and they treat it as an enemy (Masked's lure, turned round); it counts as the caster's summon (buff_targets); it ends if the caster hits it; heavy_lasts_mult 0.5; elite_status 'dazed'. Uses the gaze check (sees_caster).
- **doubting** (status, from Misgiving): 1 stack, 6 s: windup_mult 1.5, deals_mult 0.7 (both existing keys); heavy_lasts_mult 0.5, and elites keep it at half time too (no elite_status), so the enchanter has a slow for big enemies.

## Notes and open questions

- **Changeling Mask and Sweet Lie both turn enemies on each other**: Mask makes its friends attack the masked one
  (it does not fight back, simplified in the game); Sweet Lie makes the charmed one attack its friends and makes it
  your summon. If that is one idea too many, Mask could become a self-disguise.
- **Charm and Doubt have no workbook ids**; `DRM-6a` / `DRM-6b` are proposals.
- **buff_targets** is defined here; Death's Thralls and any Holy self-buff could use it. If another draft defines its
  own summon buff, merge.
- Twilight (Dim light) needs the light level, which Dark already uses (Light.level_at).
