# Life v2: the healer by regrowth (draft, 2026-10-24)

Data: `life.json`, `life-runes.json`. Nothing is built. Tags: **[B]** Brent, **[MODEL]** ours. All names original.

**Role** [B: framework.md]: healer by regrowth, affecting the living only. Base affinity (no parents).

## Rule

Life works inside living bodies: its harm passes armour and hits the hale 25% harder, it does nothing to the
unliving, and it **heals over time** - you and your living summons, the bar fast and wounds slowly - **half as fast
again for 2 s after each hit you land** [MODEL]. The last clause is new: there are no allies, so a heal must pay in a
fight, and Life's heals pay most to a healer who keeps hitting. Reflux middling (1.0), unchanged.

**Life against Holy.** Life heals the *body* over *time*: regrowth ticking in, wounds closing, drain from a living
enemy. Holy never heals over time: it guards (wards that take blows before the bar and so prevent wounds), and its
only healing comes in *moments* (a ward's leftover sinking in, Kind Light giving back what it softened). Life closes
wounds; Holy keeps them from opening. Life cures afflictions of the body (poison, burning, bleeding, sickness); Holy
lifts binds (holds, slows, stagger, fear).

## Skills (12 on 12 runes; 8 serve the role)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Knit | Heal | self buff | 6 s of 5 health/s to you and living summons in 6 m; bar first, then wounds at a quarter | | changed |
| Withering Needle | Wither | projectile | 45 + Withering past armour; a kill while Withering regrows you 10 | **ranged** | changed |
| Fresh Stride | Renew | dash | 5.2 m, clears Winded; 3 s of +15% speed and 3 health/s | **movement** | changed |
| Wearying Sweep | Exhaust | melee burst | 1.7x all round, Spent; each living enemy hit regrows you 3 (up to 5) | **close** | changed |
| Corded Muscle | Strengthen | self buff | 7 s: strikes +40%, half poise loss; your heals refill poise; living summons share | | changed |
| Wasting Grip | Weaken | targeted strike | 2.0x; Wasted 6 s | | existing |
| Fever Break | Cure | self buff | Ends afflictions on you and living summons; each ended regrows 4 | | changed |
| Turn the Stomach | Sicken | smite | Sick 8 s: retches every 2.5 s | | existing |
| Regrowth | Regrow | channel | 1.5 sink/s into wounds, an arm too; now walkable (40%) and a blow only stalls it | | changed |
| Unmending | Arrest | delayed blast | 3 m: Arrested, no healing or poise back | | existing |
| Lifeline | Tithe | channel | A thread on one living enemy: 12/s past armour, you regrow half | | new |
| Heartseed | Bestow | summon | A living mote for 15 s: 3 health/s to you, +2 per hit you land; it can be struck | | new |

Role: Knit, Needle, Stride, Sweep, Fever Break, Regrowth, Lifeline, Heartseed. Range and utility: Corded Muscle,
Wasting Grip, Turn the Stomach, Unmending.

## Rune changes

- **Cure** re-meant: afflictions of the body only (role and draw kept), so Holy's Absolve owns binds.
- **New pair Tithe / Bestow**: Tithe (link, draw +0.8, EN 3.3) takes life from a living body into yours; Bestow
  (branch, draw -0.6, EN 2.08) gives life outward into a body of yours. Now 12 runes.
- Everything else kept, with its role and draw.

## New mechanics [MODEL]

- **heal_mult_after_hit** (affinity rule): Life heals over time x1.5 for 2 s after you land a hit.
- **Shared buff (radius)**: a self buff with a radius also lands on your summons in range (living only for Life).
  Shared with Nature and Holy.
- **on_kill_heal**, **after_heal_per_s**, **heal_per_target**, **heal_to_poise**: skill keys for regrowth that comes
  from killing, moving, hitting and healing.
- **cleanse lists**: balance.json `afflictions` (Life's Cure) and `binds` (Holy's Absolve).
- **pause_on_hit_s**: a channel stalls on a blow instead of ending.
- **drain** (Unholy's key, with Life's healing order) and the status **Tithed** (hits from you heal you 15%).
- **Summon, generalised** (death.json's kind): optional `needs`, `living`, `model`, `behaviour` (fight | follow) and
  heal keys on the thrall. Used by Heartseed and by Nature's beasts.

## Unsure

- Heartseed is a body enemies may strike but that holds no slot; whether enemies should go for it at all is a feel
  question - untested, needs Brent.
- The after-hit rule makes Life's heals depend on hitting; whether that reads on the HUD (a small glow on the
  health bar?) is a UI question.
- Regrowth in a fight may close wounds too fast; 1.5 sink a second is unchanged from the old draft.
