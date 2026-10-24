# Unholy: the shadow knight (new affinity, draft, 2026-10-24)

Data: `unholy.json`, `unholy-runes.json`. Brief: `ROLES-BRIEF.md`. Nothing is built, and Unholy does not exist in the
game yet. All [MODEL] unless marked; the affinity, its parents and its role are Brent's framework [B 2026-10-24].
All names are original.

**Role:** shadow knight: life-drain melee, fear and dark auras. It does not summon; Death owns the dead.

**Rule:** Unholy feeds on what it hurts: every Unholy hit drains 10% of the damage it deals to the living back to you as health, twice that from the Dying or from anything standing in Dark, and what it drains is also banked as stolen life for your skills to spend.

**Reflux:** Middling (1.0), between Dark's middling and Death's high. A shadow knight casts often in melee; its staying power comes from the health it drains, not from cheap essence, and high reflux on top of melee range would leave it locked out at the worst moment.

**Five-axis position (proposed):** [-0.4, -0.05, -0.6, -0.7, -0.2] - [MODEL] the midpoint of Dark [-0.3, -0.3, -0.2, -1, -0.4] and Death [-0.5, 0.2, -1, -0.4, 0] on (heat, substance, vitality, light, mind_matter); not yet in runes.json affinity_positions.

## How each parent shows

- **Dark**: The ground goes Dark round you and behind you (Gloom Mantle, Night Charge, Forsaken Ground); what is swallowed is let out again (Leech and Outpour, from Devour and Disgorge); the shadow holds a target (Beckon, from Pin); fear of the dark lasts longer in it (Dreadcry).
- **Death**: The Dying give up twice as much; blows that finish the failing (Reave, from Kill); a life kept failing on purpose (Torment, from Spare); dread that lingers where you were (Daunt, Forsake, from Haunt); a body that will not end (Shroud, from Preserve).

Life-drain is never the caster paying health. Every drain is the enemy losing health and you gaining it; the stolen
store is a separate number (like Dark's swallowed light) that you spend on Black Reckoning or Black Shroud, and
spending it costs you nothing.

## Numbers

Strikes 1.4-2.4x (a shadow knight's blows are middling: it stays by draining, not by hitting hard), costs mostly mid (8-14), nothing dear: its dear resource is the stolen store, not essence.

## Skills

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Reaving Cleave | Leech | burst | A wide, heavy cleave in front of you (150 degrees): 1.8x, and it drains - a fifth of the damage it deals comes back to you as health (twice that from the Dying or from anything standing in Dark), up to 20 a swing. | **close** | new |
| Black Reckoning | Outpour | burst | Let out everything you took. A cone of black 5 m long: 30, plus all your stolen life, to everything in it, and they lose that much poise too (up to 60). Your stolen life is spent. |  | new |
| Dreadcry | Daunt | burst | A cry that carries the dark in it. Everything within 4.5 m takes 25 and is Terrified for 2 s - it turns and runs from you, and cannot attack (heavy enemies 1 s, elites only Dazed). In Dark it runs for 3 s. |  | new |
| Grasping Dark | Beckon | displace | One enemy within 12 m: a hand of shadow takes it and hauls it to arm's length in front of you: 45, it drains, and it is Leashed to you for 4 s - it cannot get more than 4 m from you. | **ranged** | new |
| Gloom Mantle | Gloom | buff | For 8 s the dark hangs round you, 3.5 m across, and goes where you go. The ground in it counts as Dark, and every enemy in it loses 10 a second - drained to you, like every Unholy hit, and doubled because they stand in Dark. |  | new |
| Black Shroud | Shroud | buff | Draw the dark tight round you: a ward of 40, plus all your stolen life (100 at most), that takes blows before your health does, for 8 s. While it holds nothing staggers you. If it breaks, the dark bursts off you: everything within 3 m is Terrified for 1.5 s. |  | new |
| Reaping Blow | Reave | strike | One enemy in reach: a slow, heavy blow, 2.4x, that drains 30% of what it deals (60% from the Dying), up to 30. If it kills, all the health it had left before the blow is stolen. |  | new |
| Torment | Torment | smite | One enemy within 10 m: 20, and it is Tormented for 8 s - it loses 8 a second, half of which comes to you as health, and its poise does not refill. Nothing spreads; it is one body's slow ending. |  | new |
| Night Charge | Stalk | dash | Charge 6.7 m along your aim through the dark and stop on the first enemy you reach: 1.4x, it drains, and it is Leashed to you for 2 s. The ground you crossed stays Dark for 5 s. | **movement** | new |
| Forsaken Ground | Forsake | dash | Break off: leap 5 m back, away from your aim, and leave the ground you stood on forsaken - a Dark circle 3 m across for 4 s. Enemies in it take 10 a second and are Dreading: they back out and will not walk in. |  | new |

The loop: Grasping Dark or Night Charge to reach them; Gloom Mantle so everything round you stands in Dark (the
drain doubles); Reaving Cleave to drain and bank stolen life; Black Shroud to turn the store into a ward when the
blows come, or Black Reckoning to pour it back out when they are close; Reaping Blow for the one that is failing;
Dreadcry or Forsaken Ground when it is too many.

## Runes (10, all new)

| Rune | Meaning | Opposite | Role | Draw | Effect | Change | Why |
|---|---|---|---|---|---|---|---|
| Leech | draw the life out of what you strike, into yourself | Outpour | link | +0.80 | `status leeched` | new | The shadow knight's own verb. From Dark's Devour (swallow) and Death's ending. A Link (it takes in from the target and passes on to you), draw +0.8 because it pulls inward. |
| Outpour | let out what you took, as harm | Leech | branch | -0.80 | `power x1.2; reach x1.15` | new | Spends the stolen store. From Dark's Disgorge. A Branch (it spreads into a cone), draw -0.8: it gives outward; opposite Leech, so the pair bonds ionically. |
| Daunt | fear that drives them back from you | Beckon | branch | -0.60 | `status terrified; power x0.85` | new | Fear is in the role. From Death's Haunt and Dark's fear of the dark. Named Daunt, not Dread, because Dread is Dream's rune. A Branch (it spreads to all round you), draw -0.6: it pushes outward. It applies Dream's existing Terrified rather than a new fear status. |
| Beckon | the dark calls them in, and does not let them go | Daunt | link | +0.70 | `pull +1.5; status leashed` | new | A tank's way to reach a runner. From Dark's Pin (the shadow holds). A Link, draw +0.7: it draws inward. |
| Gloom | darkness that hangs about you and goes where you go | Shroud | branch | -0.40 | `reach x1.15; duration x1.2` | new | Dark auras are in the role. From Dark's Darken and Obscure. A Branch (it spreads round you), draw -0.4: outward, but gently. |
| Shroud | darkness drawn tight onto your own body | Gloom | frame | +0.50 | `braced; duration x1.15` | new | The ward. From Dark's Obscure and Death's Preserve. A Frame (it holds the structure, and you, together), draw +0.5: it holds inward. Gloom and Shroud are one dark, spread out or drawn in. |
| Reave | tear out the last of a failing life and keep it | Torment | cap | +1.00 | `bonus dying +0.3; status leeched` | new | From Death's Kill. A Cap (it ends: a killing blow), draw +1.0 like Kill and Devour, the two runes it comes from: it takes everything inward. |
| Torment | keep a life failing slowly | Reave | link | -0.30 | `status tormented` | new | From Death's Spare, turned cruel. A Link (it passes the life on to you a little at a time), draw -0.3: it lets the life go slowly rather than taking it. |
| Stalk | come at your prey through the dark and do not let it go | Forsake | link | +0.40 | `reach x1.3; speed x1.15` | new | Movement for a melee fighter: in, not away. From Dark's Shadowstep. A Link, draw +0.4: it closes inward. |
| Forsake | break away, and leave dread on the ground behind you | Stalk | link | -0.60 | `status dread; windup x0.85` | new | The disengage, still in role (it leaves fear). From Death's Haunt and Vanish. A Link, draw -0.6: it goes outward, away. |

Valence: 1 Cap, 5 Links, 3 Branches, 1 Frame. Each pair has opposite draws, so a rune bonded to its own opposite is
ionic, as in the other sets.

## New mechanics

- **drain_frac** (behaviour, Reaving Cleave): Life's payload key (life.json v2, Lifeline), read the same way, plus drain_cap (the most one cast heals) and the Unholy rule's base 0.1 on every Unholy hit. After the hit, the caster is healed drain_frac x the damage actually dealt (after armour, flesh and every multiplier), up to drain_cap per cast. The rule's doubling (Dying, or standing in Dark) multiplies it, capped at 0.5. Unliving targets give nothing. Unlike Life's, Unholy's drain fills the health bar only (affinity key drain_heals: bar), never a wound's sink, so it is not talent healing and does not compete with 1% Lifesteal.
- **stolen** (field, Reaving Cleave): A player store, like Dark's swallowed light: every point an Unholy drain heals - or would have healed, at full health - is also banked as stolen life, up to 100. It fades 12 s after the last gain. Black Reckoning and Black Shroud spend it. It is never your own health: spending it costs you nothing.
- **consume stolen** (behaviour, Black Reckoning): consume 'stolen' spends the whole stolen store: per_stack_damage and per_stack_poise per point, poise up to poise_max (the same rule as Night Spill's consume of swallowed light).
- **leashed** (status, Grasping Dark): 1 stack, the skill's status_s: the target cannot move further than leash_m from whoever applied it (a step beyond is undone, as a wall would stop it); ranged enemies keep shooting, but from inside the leash.
- **aura dark** (field, Gloom Mantle): Earth's aura key (earth.json v2, Stonehide: {radius, tick_s, payload, pull_per_s}, moving with you), with one key added: dark - the circle counts as Dark ground (Dark's light level) while it lasts. Its payload goes through apply_hit like any hit, so it drains.
- **ward_from** (field, Black Shroud): Holy's ward pool (holy.json v2, Dawnward: Body.ward takes blows before the bar, and a blow wholly stopped opens no wound), filled by the ward key, with three Unholy keys: ward_from spends the named player store into the ward at cast (ward_max in all, Unholy's own cap, not Holy's ward_cap 60); no_stagger, heavy blows do not stagger you while it holds; on_break, this skill's payload round you when a blow empties it (instead of Holy's rule payload, which is Holy's).
- **kill_steals** (field, Reaping Blow): A strike key: if the hit kills, the target's health before the hit is added to the caster's stolen store (it heals nothing beyond the hit's own drain).
- **tormented** (status, Torment): 1 stack, status_s (default 8 s), living only: 8 damage a second every 0.5 s through whoever applied it (tags dot, unholy, tormented); each tick drains half its damage to the applier (status key drain_frac, the drain rule's cap per cast does not apply to ticks); poise does not refill. Never spreads.
- **dark trail** (field, Night Charge): A dash trail (as Flashover's) with dark: the strip counts as Dark ground for its life; it deals nothing on its own.
- **dash dir back** (field, Forsaken Ground): A dash key: dir 'back' moves the caster directly away from the aim point instead of toward it (facing kept).
- **leeched** (status, the rule): 1 stack, 6 s: every hit its applier lands on it drains 15% of the damage to the applier (key drain_to_source), on top of any drain the hit already has, capped as the drain rule is. This is how Leech and Reave work as modifiers on another affinity's skill.
- **Dark ground for Unholy** (field, the rule): Unholy reads Dark's light level (Lit / Dim / Dark) only for the drain rule; Unholy's dark zones (aura, trail, leave_zone with dark) are the same dark ground Dark's skills make, so a character holding both gets both rules from them.

Reused: terrified (Dream), dread (Death), dying (Death), Dark's light level and dark ground, displace pull_target
(Water's Riptide Lash), dash trail (Fire's Flashover), smite, consume of a player store (Dark's Night Spill).

## Unsure

- **Drain against 1% Lifesteal.** The 1% Lifesteal talent is a canon talent; a whole affinity that drains could
  make it look small. Drain here heals the bar only (never a wound's sink, which talent healing fills) and is
  capped per cast, but the numbers (10%, x2, 20-30 a cast against a 100-health bar) are guesses that need play.
- **Taunt.** The role brief offered taunt; with no party allies a taunt only matters against thralls and decoys, so
  Unholy uses a leash instead (Leashed: it cannot get away from you). Earth's v2 defines Taunted; Grasping Dark
  could apply it as well.
- **Aura and ward** reuse Earth's `aura` and Holy's `ward` pool (both v2 drafts, read 2026-10-24) and add only
  `dark`, `ward_from`, `no_stagger` and a skill `on_break`. Holy caps a ward at 60 by its rule; Black Shroud's own
  cap is 100. A character holding both needs one cap for the one pool.
- **Dark v2** (read 2026-10-24) keeps every Dark rune Unholy cites (Darken, Obscure, Pin, Shadowstep, Devour,
  Disgorge) and the light level. Its new Ambush (first hit out of Unseen) is Dark's alone: Unholy is never Unseen.
- **Daunt** borrows Dream's Terrified. If Dream's v2 changes Terrified, Daunt follows it.
- Unholy's five-axis position is the plain midpoint and is not in runes.json; the runes have no characters
  (glyphs) yet.
