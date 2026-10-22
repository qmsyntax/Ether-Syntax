# Modifier cross-check

**Planned rules** (`--planned`): classed under the rule changes going to the build, not today's effects_v1. See the module docstring.
Made by `tools/runes/check_modifiers.py`. For each skill, every rune that could be added to it (its affinity's other base runes and the universal runes) is classed: **direct** (all its ops act on something real in the skill), **partial**, or **fallback** (none do; it only turns into a little extra power).

## Blood

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Thinblood Rush | Thin | dash | 33 of 65 (50%) |
| Tourniquet | Staunch | self_buff | 45 of 65 (69%) |
| Long Breath | Breathe | self_buff | 45 of 65 (69%) |
| Hammering Heart | Pulse | detonate | 50 of 65 (76%) |
| Heavy Heart | Still | ground_zone | 59 of 65 (90%) |
| Deep Draught | Drink | channel | 64 of 65 (98%) |
| Outpour | Spill | melee_burst | 64 of 65 (98%) |
| Clotblade | Clot | melee_burst | 64 of 65 (98%) |
| Gullet Knot | Choke | new:hex | 64 of 65 (98%) |
| Red Lancet | Bleed | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Still 5/9, Choke 5/9, Bleed 5/9, Drink 6/9, Staunch 9/9, Spill 9/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Hammering Heart + Choke (`interrupts; status choked`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Red Lancet + Staunch: closing wounds on the skill that exists to open them. A projectile has no duration, so mos
- Red Lancet + Self: a lancet thrown at yourself. A projectile has no duration for Self to lengthen, so all of 
- Deep Draught + Spill: giving blood out while drinking it in. The numbers would still apply (wider, dearer) but t
- Deep Draught + Clot: clotted blood cannot be drunk. A channel has no wind-up to brace and no poise payload, so 
- Deep Draught + Loose: let go at once, on a skill that is nothing but holding. There is no wind-up to cut, so it 
- Outpour + Drink: drinking back what you are pouring out. The numbers would land (+25% on the bleeding, more
- Outpour + Staunch: a closed wound spills nothing. Outpour has no duration to lengthen, so that half falls bac
- Outpour + Within: a wave is not a shot; pierce does nothing on a burst and falls back to a small damage bonu
- Clotblade + Staunch: it closes the cuts the blade is meant to harden. No duration to lengthen, so that falls ba
- Clotblade + Within: pierce means nothing on a sweep; it falls back to a small damage bonus.
- Clotblade + Many: a sweep already hits everything in its arc. Extra jumps do nothing here and fall back; the
- Heavy Heart + Haste: hurrying a skill whose point is slowness; the zone has no wind-up, so it falls back to a s
- Gullet Knot + Breathe: giving breath to the throat you are closing. The reflux cut lands; the wind-up cut has not
- Gullet Knot + Many: one throat at a time: a hex does not jump, so that falls back, and the 15% damage loss lan
- Long Breath + Fury: a frenzy is the opposite of a long breath. There is no damage to raise, so that half falls

## Dark

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Shadow Slip | Shadowstep | blink | 38 of 65 (58%) |
| Muffle | Hush | self_buff | 46 of 65 (70%) |
| Hungry Dark | Devour | melee_burst | 51 of 65 (78%) |
| Blot | Darken | projectile | 53 of 65 (81%) |
| Daybreak | Lighten | detonate | 59 of 65 (90%) |
| Pall | Obscure | ground_zone | 59 of 65 (90%) |
| Silhouette | Expose | new:smite | 64 of 65 (98%) |
| Shadownail | Pin | delayed_blast | 64 of 65 (98%) |
| Knell | Resound | ground_zone | 64 of 65 (98%) |
| Night Spill | Disgorge | melee_burst | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Expose 5/9, Pin 5/9, Obscure 8/9, Resound 8/9, Darken 8/9, Lighten 9/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Blot + Haste: No wind-up to shorten; it leaves the hand at once. Falls back.
- Daybreak + Expose: Daybreak already Exposes everything it catches; the status op does not stack. Falls back.
- Daybreak + Within: Not a shot. Falls back.
- Pall + Expose: Expose is Obscure's opposite: outlining what you are hiding. Obscure keeps the pull, but t
- Pall + Within: Not a shot. Falls back.
- Silhouette + Obscure: Obscure is Expose's opposite and pulls harder (2.62 vs 1.9): hiding the thing you are outl
- Silhouette + Within: Not a shot. Falls back.
- Silhouette + Haste: Nothing to quicken; it is instant. Falls back.
- Shadownail + Shadowstep: Shadowstep is Pin's opposite: moving the thing you nail down. The maths would lengthen its
- Shadownail + Within: Not a shot. Falls back.
- Knell + Hush: Hush is Resound's opposite and pulls harder (3.1 vs 2.15): a hushed bell. Its echo shrinks
- Knell + Within: Not a shot. Falls back.
- Knell + Haste: The zone has no wind-up; Haste cannot speed the tolls. Falls back.
- Hungry Dark + Disgorge: Disgorge is Devour's opposite and the bond is ionic (4.0 vs 1.8): Devour takes the whole p
- Night Spill + Devour: Devour is Disgorge's opposite and the bond is ionic (4.0 vs 1.8): it eats the spill. Disgo
- Night Spill + Within: Not a shot. Falls back.
- Night Spill + Haste: No wind-up to shorten. Falls back.

## Death

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Gravestep | Vanish | blink | 34 of 65 (52%) |
| Rise Again | Animate | new:summon | 41 of 65 (63%) |
| Embalm | Preserve | self_buff | 46 of 65 (70%) |
| Death Mask | Manifest | prop | 50 of 65 (76%) |
| Lay to Rest | Lay | new:field_pulse | 53 of 65 (81%) |
| Endstroke | Kill | targeted_strike | 59 of 65 (90%) |
| Last Mercy | Spare | new:hex | 59 of 65 (90%) |
| Banishing Line | Exorcise | beam | 59 of 65 (90%) |
| Lingering Shade | Haunt | ground_zone | 64 of 65 (98%) |
| Rotting Bolt | Rot | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Animate 5/9, Lay 5/9, Rot 5/9, Kill 5/9, Spare 7/9, Exorcise 7/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Endstroke + Spare: a killing blow that holds the life at the edge. The numbers would land (Spared, 15% weaker
- Endstroke + Many: a finishing blow is on one body. Extra jumps do nothing and fall back; the 15% damage loss
- Last Mercy + Kill: finishing the life you are holding. Last Mercy deals no damage on a hit, so the bonus has 
- Rotting Bolt + Preserve: stopping the decay the bolt is made of. A projectile has no duration, so that falls back t
- Rotting Bolt + Pure: cleansing the rot. The reflux cut lands; the word contradicts itself.
- Lingering Shade + Exorcise: banishing the spirit you called up. The numbers would land (interrupts, 10% harder) but th
- Lingering Shade + Attract: pulling enemies into ground they flee. The pull would land and fight the Dread every tick;
- Death Mask + Vanish: a likeness nobody can see draws nobody. The 20% reach would land (it pulls from further) w
- Death Mask + Veil: hiding the thing that must be seen. No wind-up to cut; it falls back to a small damage bon

## Disease

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Festering Hands | Fester | self_buff | 27 of 65 (41%) |
| Lancing Cut | Lance | targeted_strike | 49 of 65 (75%) |
| Inured Blood | Immunise | self_buff | 49 of 65 (75%) |
| Fever Break | Disinfect | detonate | 50 of 65 (76%) |
| Teeming Fog | Overrun | ground_zone | 59 of 65 (90%) |
| Dispersal | Clear | dash | 60 of 65 (92%) |
| Fever Flask | Infect | delayed_blast | 64 of 65 (98%) |
| Contagion | Spread | chain | 64 of 65 (98%) |
| Plaguebloom | Billow | melee_burst | 64 of 65 (98%) |
| Sealing Clot | Contain | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Spread 5/9, Overrun 5/9, Infect 5/9, Disinfect 6/9, Contain 8/9, Lance 8/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Fever Break + Fall (`poise x1.3`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Fever Flask + Disinfect: Its own opposite: a flask that kills the disease it carries. The fallback is a bonus again
- Fever Flask + Within: There is no projectile to pierce; a burst has no line, so the fallback does nothing.
- Fever Break + Persist: An instant breaking has nothing to make last; the fallback does nothing.
- Fever Break + Billow: Spreading a cloud on the skill that ends the sickness contradicts it; the fallback widens 
- Contagion + Contain: Its own opposite: keeping the sickness in one body. The fallback shrinks the jump radius t
- Contagion + One: One body taking all of it is the opposite of a spread; the fallback adds damage the 20-a-b
- Contagion + Focus: Concentrating on a point shrinks the jump radius to 2.4 m; the spread chokes.
- Sealing Clot + Spread: Its own opposite: a sickness that jumps on a skill that seals it in one body. The fallback
- Sealing Clot + Billow: A cloud from a sealed clot contradicts it; there is no area to widen, so the fallback only
- Sealing Clot + Many: Sealing it in many bodies is not containing it; the fallback hits a second target for less
- Lancing Cut + Contain: Lancing lets the sickness out; sealing it in contradicts that, and the fallback shrinks th
- Plaguebloom + Clear: Its own opposite: dispersing the cloud it makes. The fallback shoves everyone out of the c
- Plaguebloom + Contain: A billowing cloud kept in one body is a contradiction; the fallback shrinks the bloom to 2
- Dispersal + Stillness: Held in place is the opposite of dispersing; the fallback slows the dash by 20%.
- Teeming Fog + Immunise: Its own opposite: building their resistance in the fog meant to overwhelm it. The fallback
- Teeming Fog + Clear: Dispersing the fog contradicts it; the fallback shoves bodies out of it every tick.

## Dream

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Doubling Step | Conjure | dash | 26 of 65 (40%) |
| Shattered Dream | Dispel | detonate | 41 of 65 (63%) |
| Quiet Hour | Soothe | ground_zone | 59 of 65 (90%) |
| Changeling Mask | Mimic | new:gaze | 59 of 65 (90%) |
| Read the Tell | Unmask | new:gaze | 59 of 65 (90%) |
| Errand | Whisper | new:gaze | 59 of 65 (90%) |
| Rousing Blow | Wake | targeted_strike | 64 of 65 (98%) |
| Night Terror | Dread | melee_burst | 64 of 65 (98%) |
| Shutter | Shut | delayed_blast | 64 of 65 (98%) |
| Dozing Mote | Sleep | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Wake 7/9, Dread 7/9, Unmask 7/9, Whisper 7/9, Shut 7/9, Sleep 7/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Doubling Step + Persist (`duration x1.5`)
- Doubling Step + Elsewhere (`reach x1.3`)
- Doubling Step + Remember (`duration x1.3`)
- Shattered Dream + Wake (`bonus asleep +0.5; poise x1.2`)
- Shattered Dream + Fall (`poise x1.3`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Dozing Mote + Wake: Its own opposite: a sleep bolt that rudely wakes its sleepers. The fallback adds +50% agai
- Dozing Mote + Dread: Terror and sleep fight each other: the fallback makes the target flee instead of nodding, 
- Dozing Mote + Repel: Shoving a body you are lulling makes no sense; the fallback knocks the target out of your 
- Rousing Blow + Sleep: Its own opposite: the blow that wakes puts it back to sleep - and the target is Wakeful, s
- Rousing Blow + Scatter: One waking spread thin: the strike has one target, so the fallback only takes 15% off the 
- Rousing Blow + Soothe: A soothing blow is a contradiction, and Soothed ends the moment it is hit; the fallback do
- Night Terror + Soothe: Its own opposite: calm and terror cancel. The fallback Soothes them, which ends at once be
- Night Terror + Attract: Pulling in the very enemies you are sending running is a contradiction; the fallback drags
- Night Terror + Fury: Enraging what you are terrifying makes no sense (and frenzy is the enemy's tool); the fall
- Quiet Hour + Dread: Its own opposite: terror in a zone of calm. The fallback sends everyone in it running, out
- Quiet Hour + Repel: A shove every tick is a hit that breaks Soothed, so the zone would undo itself.
- Changeling Mask + Unmask: Its own opposite: revealing the disguise you are laying. The fallback (Read) ends the mask
- Changeling Mask + Repel: Shoving the masked one away from the allies you want to fight it defeats the skill.
- Changeling Mask + Within: A gaze has no projectile to pierce, and Dream already ignores armour; the fallback does no
- Read the Tell + Mimic: Its own opposite: putting a mask on the face you are unmasking; the fallback Masks the tar
- Read the Tell + Repel: A gaze has no force; the fallback is a free shove that moves the target out of the reach y
- Errand + Sleep: Putting it to sleep (or Dazing it) at the moment of the order means it never walks; the tw
- Errand + Dread: A Terrified enemy runs away from you, not to your spot; the fallback overrides the errand.
- Errand + Repel: A shove is a hit, and a hit breaks the command; the fallback undoes the skill.
- Shutter + Whisper: Its own opposite: planting a command in a mind you are closing; the fallback pulls them to
- Shutter + Rise: Lifting bodies has nothing to do with the mind; the fallback is a free Updraft.

## Earth

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Stonehide | Harden | self_buff | 43 of 65 (66%) |
| Bedrock Shove | Root | dash | 46 of 65 (70%) |
| Burrow | Tunnel | dash | 56 of 65 (86%) |
| Landslide Blow | Crumble | melee_burst | 60 of 65 (92%) |
| Slingstone | Dig | projectile | 62 of 65 (95%) |
| Raise Slab | Raise | prop | 64 of 65 (98%) |
| Pillar | Raise | delayed_blast | 64 of 65 (98%) |
| Tremor | Quake | melee_burst | 64 of 65 (98%) |
| Quarry Throw | Dig | charge_release | 64 of 65 (98%) |
| Sinkhole | Sink | prop | 64 of 65 (98%) |
| Cairn | Bury | new:seize | 64 of 65 (98%) |
| Cave-In | Collapse | delayed_blast | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Raise 9/10, Sink 10/11, Crumble 10/11, Quake 10/11, Bury 10/11, Tunnel 10/11

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Slingstone + Root: it is already Braced; nothing to add, falls back to a little power
- Landslide Blow + Tunnel: a blow has nothing to pierce; falls back to a little power
- Raise Slab + Crumble: its own opposite in spirit (a wall that breaks as it rises), and a slab has no poise field
- Raise Slab + Tunnel: nothing to pierce; falls back
- Pillar + Sink: its own opposite: a column that rises into a pit. Maths lets it act (Mired); it should not
- Pillar + Tunnel: nothing to pierce; falls back
- Bedrock Shove + Tunnel: it is meant to stop at the body; going under it has nothing to act on and falls back
- Bedrock Shove + Haste: it has no wind-up to shorten; falls back
- Tremor + Root: its own opposite, and it is already Braced: falls back to a little power
- Tremor + Tunnel: nothing to pierce; falls back
- Quarry Throw + Tunnel: a lobbed boulder has nothing to pierce; falls back to a little power
- Quarry Throw + Root: it is already Braced while it charges; falls back
- Sinkhole + Raise: its own opposite: a pit that rises. Maths lets it act (poise); it should not
- Sinkhole + Tunnel: nothing to pierce; falls back to a little power
- Cairn + Dig: its own opposite: tearing up the ground you are covering them with. Maths lets it act (pow
- Cairn + Tunnel: nothing to pierce; falls back
- Burrow + Collapse: its own opposite: the tunnel caving in on you. Maths lets it act (a Stun on surfacing); it
- Burrow + Root: it is already Braced, and anchoring is the opposite of travelling: falls back to a little 
- Cave-In + Tunnel: its own opposite, and nothing to pierce: falls back to a little power
- Cave-In + Rise: lifts Aloft what the rock is falling on. Maths lets it act; it should not

## Fire

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Wickpinch | Snuff | new:seize | 38 of 65 (58%) |
| Stoke | Blaze | self_buff | 41 of 65 (63%) |
| Pyre Call | Explode | detonate | 48 of 65 (73%) |
| Backdraft | Implode | melee_burst | 56 of 65 (86%) |
| Smokepall | Smother | ground_zone | 59 of 65 (90%) |
| Flashover | Ignite | dash | 60 of 65 (92%) |
| Hiss | Quench | new:seize | 61 of 65 (93%) |
| Kiln Fist | Burn | targeted_strike | 64 of 65 (98%) |
| Bellows Breath | Blaze | channel | 64 of 65 (98%) |
| Slag Pool | Smoulder | ground_zone | 64 of 65 (98%) |
| Flashpan | Flare | melee_burst | 64 of 65 (98%) |
| Cinder Spit | Ignite | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Snuff 9/11, Implode 9/11, Flare 9/11, Smother 9/11, Burn 9/11, Blaze 9/10

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Kiln Fist + Snuff: its own opposite in spirit, and it already interrupts: nothing to add, falls back to a lit
- Kiln Fist + Smoulder: it already sets Alight and nothing on it lasts; falls back to a little power
- Kiln Fist + Persist: nothing lasts; falls back to a little power
- Cinder Spit + Burn: it already sets Alight; falls back to a little power
- Cinder Spit + Persist: a coal in flight has nothing that lasts; falls back
- Cinder Spit + Snuff: its own opposite: a spit that puts the fire out as it lights it. Maths lets it act; it sho
- Flashover + Snuff: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Flashover + Implode: a trail that drags everyone standing in it toward its middle line every tick. Maths lets i
- Pyre Call + Persist: one blast; nothing lasts. Falls back to a little power
- Bellows Breath + Smother: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Bellows Breath + Ignite: it already sets Alight every tick and has no wind-up; falls back to a little power
- Bellows Breath + Snuff: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Slag Pool + Snuff: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Slag Pool + Haste: no wind-up to shorten; falls back to a little power
- Hiss + Burn: its own opposite: relights what it just put out. Maths lets it act; it should not
- Hiss + Persist: one moment; nothing lasts. Falls back to a little power
- Wickpinch + Ignite: its own opposite: lights the thing it puts out. Maths lets it act (status and recovery); i
- Flashpan + Smother: its own opposite: smoke over the flash. Maths lets it act (interrupt and slow); it should 
- Flashpan + Persist: a flash has nothing that lasts on the skill itself; falls back to a little power
- Flashpan + Hold: a flash is instant; there is no wind-up to hold. Only the damage half lands
- Smokepall + Flare: its own opposite: a flash inside the smoke. Maths lets it act (Dazed); it should not
- Smokepall + Haste: no wind-up to shorten; falls back to a cost cut

## Ice

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Ice Shell | Toughen | self_buff | 44 of 65 (67%) |
| Whiteout | Snow | ground_zone | 59 of 65 (90%) |
| Craze | Brittle | delayed_blast | 59 of 65 (90%) |
| Black Ice | Glaze | dash | 60 of 65 (92%) |
| Set Solid | Freeze | melee_burst | 64 of 65 (98%) |
| False Spring | Thaw | detonate | 64 of 65 (98%) |
| Runoff | Melt | beam | 64 of 65 (98%) |
| Fracture | Shatter | targeted_strike | 64 of 65 (98%) |
| Hoarline | Frost | projectile | 65 of 65 (100%) |
| Icicle | Rime | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Snow 8/9, Melt 8/9, Shatter 8/9, Brittle 8/9, Freeze 8/9, Thaw 9/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Set Solid + Within: Not a shot; nothing to pierce. Falls back.
- Set Solid + Persist: The ring is a moment; the Chill it leaves already stays. No duration field; falls back.
- False Spring + Freeze: Freeze is Thaw's opposite, and the Chill it would add is already what the burst gives; a s
- False Spring + Within: Not a shot. Falls back.
- Hoarline + Within: It already passes everything on the line. Falls back.
- Hoarline + Haste: There is no wind-up to shorten; it leaves the hand at once. Falls back.
- Black Ice + Frost: Frost is Glaze's opposite and pulls harder (2.9 vs 2.0, polar): Glaze keeps only half its 
- Black Ice + Within: A dash that stops at bodies has nothing to pierce. Falls back.
- Whiteout + Melt: Melt is Snow's opposite and pulls harder: melted snow is slush, not a blind, and its damag
- Whiteout + Within: Not a shot. Falls back.
- Runoff + Within: A beam is not a shot, and it already passes through everything. Falls back.
- Runoff + Persist: Nothing of an instant line stays. Falls back.
- Icicle + Persist: A thrown spike has no duration. Falls back.
- Icicle + Self: Acts on the caster; the spike leaves you. No duration to grant; falls back.
- Icicle + Melt: A melted icicle is a splash of water. The maths would let it through (a damage bonus on Ch
- Fracture + Rime: Rime is Shatter's opposite and pulls harder (2.62 vs 1.87, polar): the hammer grows spikes
- Fracture + Within: Not a shot. Falls back.
- Fracture + Persist: A blow has no duration. Falls back.
- Craze + Within: Not a shot. Falls back.

## Life

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Fresh Stride | Renew | dash | 31 of 65 (47%) |
| Knit | Heal | self_buff | 45 of 65 (69%) |
| Corded Muscle | Strengthen | self_buff | 45 of 65 (69%) |
| Fever Break | Cure | self_buff | 45 of 65 (69%) |
| Regrowth | Regrow | channel | 45 of 65 (69%) |
| Wearying Sweep | Exhaust | melee_burst | 64 of 65 (98%) |
| Wasting Grip | Weaken | targeted_strike | 64 of 65 (98%) |
| Turn the Stomach | Sicken | new:hex | 64 of 65 (98%) |
| Unmending | Arrest | delayed_blast | 64 of 65 (98%) |
| Withering Needle | Wither | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Exhaust 4/9, Weaken 4/9, Sicken 4/9, Arrest 4/9, Wither 8/9, Strengthen 8/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Withering Needle + Heal: healing the body you are withering. It has no duration to lengthen, so that half falls bac
- Withering Needle + Self: a needle turned on yourself, which no skill may do. A projectile has no duration, so it al
- Wearying Sweep + Within: pierce means nothing on a burst, and the skill is already inside; it falls back to a small
- Wasting Grip + Heal: mending the body you are wasting. No duration to lengthen, so that falls back to a small d
- Wasting Grip + Many: a grip is on one body. Extra jumps do nothing and fall back; the 15% damage loss lands.
- Turn the Stomach + Cure: curing the sickness as you give it. The numbers would land (cheaper, less reflux) but the 
- Turn the Stomach + Within: it is already inside, and a hex is not a shot: pierce falls back to a small damage bonus.
- Regrowth + Haste: regrowth cannot be hurried, and this channel has no wind-up to cut; it falls back to a sma
- Unmending + Regrow: restoring what the skill stops from mending. The numbers would land (40% longer) but the v

## Light

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Dusk Well | Dim | ground_zone | 44 of 65 (67%) |
| Still Lamp | Glow | prop | 44 of 65 (67%) |
| Gathered Light | Absorb | detonate | 44 of 65 (67%) |
| Clear Eye | Clarity | self_buff | 46 of 65 (70%) |
| Bent Light | Bend | self_buff | 46 of 65 (70%) |
| Glint | Flash | new:streak | 59 of 65 (90%) |
| Dayline | Shine | beam | 64 of 65 (98%) |
| Noonburst | Radiate | melee_burst | 64 of 65 (98%) |
| Hard Glare | Glare | melee_burst | 64 of 65 (98%) |
| Glancing Ray | Reflect | beam | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Glare 4/9, Reflect 4/9, Shine 4/9, Dim 9/9, Flash 9/9, Glow 9/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Dayline + Curve: Light that bends breaks the affinity's rule; on an instant line it only nudges reach and d
- Dayline + Attract: A ray of light that hauls its target 1.5 m toward you has no meaning; the fallback is a fr
- Dayline + Rise: Light does not lift bodies; the fallback is a free Aloft on a cheap bolt, a second skill h
- Noonburst + Reflect: A burst in every direction has no single path to bounce; the fallback hands one random ene
- Noonburst + Within: There is no projectile to pierce; Pierce on a burst does nothing.
- Gathered Light + Radiate: Its own opposite: sending light out on a skill that draws it in. The fallback only stretch
- Hard Glare + Clarity: Its own opposite: restoring sight on a skill that takes it away; the fallback only adds 10
- Hard Glare + Dim: A dimmed glare is a contradiction; the fallback just weakens it.
- Hard Glare + Within: A cone has no projectile to pierce; the fallback does nothing.
- Glancing Ray + Curve: A bent ray stops being a reflection: the bank shot depends on straight legs. The fallback 
- Glancing Ray + Absorb: Absorbing light on a skill that throws it back is contradictory; the fallback is a bonus a
- Glancing Ray + Near: A shorter path ruins the bank shot (11.9 m); +20% damage does not make up for missing the 

## Lightning

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Dead Short | Discharge | detonate | 41 of 65 (63%) |
| Static Coat | Charge | self_buff | 44 of 65 (67%) |
| Stepped Leader | Quicken | blink | 58 of 65 (89%) |
| Dead Line | Silence | ground_zone | 58 of 65 (89%) |
| Plumb Bolt | Strike | new:smite | 60 of 65 (92%) |
| Stored Bolt | Charge | charge_release | 60 of 65 (92%) |
| Arc Lash | Arc | beam | 60 of 65 (92%) |
| Forked Path | Arc | chain | 60 of 65 (92%) |
| Ground Rod | Ground | rod | 64 of 65 (98%) |
| Bell Jar | Insulate | new:smite | 64 of 65 (98%) |
| Seize Up | Stun | melee_burst | 64 of 65 (98%) |
| Thunderclap Palm | Thunder | targeted_strike | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Strike 8/11, Arc 8/10, Stun 9/11, Thunder 9/11, Silence 9/11, Charge 9/10

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Plumb Bolt + Arc: Plumb Bolt is the one lightning skill that does not jump, and the jump op only works on a 
- Plumb Bolt + Within: There is no shot to pass through bodies; it already ignores what is between. Falls back to
- Ground Rod + Within: Nothing it throws to pass through bodies. Falls back.
- Stored Bolt + Within: It already passes through everything on the line, and it is not a shot. Falls back.
- Stored Bolt + Arc: A line through everything has nothing left to jump to, and the jump op needs a chain. Fall
- Stored Bolt + Discharge: It reads well (release the stored marks) but Charge and Discharge are opposites with an io
- Dead Short + Insulate: An insulated short does not short. The bond is ionic (2.95 vs 1.0), so Insulate takes the 
- Arc Lash + Insulate: Insulate is Arc's opposite and pulls harder (2.95 vs 2.15, polar): Arc's hold on the skill
- Arc Lash + Within: A beam is not a shot to pierce with; it already hits what it touches. Falls back.
- Forked Path + Insulate: Insulate is Arc's opposite and pulls harder (polar): the jumps are halved, which is the wh
- Forked Path + Within: Not a shot. Falls back.
- Bell Jar + Arc: Arc is the jump the jar exists to block, and the jump op needs a chain. Falls back to a sl
- Bell Jar + Within: Not a shot. Falls back.
- Stepped Leader + Within: Nothing to pierce. Falls back.
- Stepped Leader + Persist: Nothing of the blink stays. (Quickened's 2 s is not in a stat group.) Falls back.
- Seize Up + Within: Not a shot. Falls back.
- Seize Up + Persist: The lock is a moment; there is no duration field to stretch. Falls back.
- Thunderclap Palm + Silence: Silence is Thunder's opposite and pulls harder (3.25 vs 2.01): a silent thunderclap. Its o
- Thunderclap Palm + Within: Not a shot. Falls back.
- Thunderclap Palm + Persist: A blow has no duration. Falls back.
- Dead Line + Charge: The maths would accept it (the zone has a payload) but the payload ticks every 0.5 s: a ma
- Dead Line + Thunder: Thunder is Silence's opposite: a crack inside a hush undoes it. The maths would Daze every
- Dead Line + Within: Not a shot. Falls back.

## Metal

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Plating | Plate | self_buff | 42 of 65 (64%) |
| Breakthrough | Breach | dash | 50 of 65 (76%) |
| Rust Bloom | Rust | ground_zone | 59 of 65 (90%) |
| Splitting Blow | Sunder | melee_burst | 60 of 65 (92%) |
| Whetted Cut | Hone | charge_release | 60 of 65 (92%) |
| Iron Slug | Forge | projectile | 62 of 65 (95%) |
| Spot Weld | Fuse | chain | 64 of 65 (98%) |
| Iron Clasp | Seal | new:smite | 64 of 65 (98%) |
| Turn the Edge | Dull | melee_burst | 64 of 65 (98%) |
| Wrench | Strip | targeted_strike | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Rust 8/9, Fuse 8/9, Sunder 8/9, Seal 8/9, Breach 8/9, Dull 8/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Iron Slug + Haste: No wind-up to shorten; it leaves the hand at once. Falls back.
- Rust Bloom + Within: Not a shot. Falls back.
- Spot Weld + Sunder: Sunder is Fuse's opposite: splitting the seam you weld. Fuse keeps the pull; there is no p
- Spot Weld + Sever: Sever cuts and separates: the opposite of a weld. No poise field; falls back.
- Spot Weld + Within: Not a shot. Falls back.
- Splitting Blow + Fuse: Fuse is Sunder's opposite and pulls harder (2.7 vs 2.01): welding what you split. The weld
- Splitting Blow + Within: Not a shot. Falls back.
- Iron Clasp + Breach: Breach is Seal's opposite: breaking the seal you close. Seal keeps the pull; Breach's pier
- Iron Clasp + Within: Not a shot. Falls back.
- Breakthrough + Seal: Seal is Breach's opposite and pulls harder (3.4 vs 1.9): sealing as you break through. The
- Breakthrough + Persist: A drive has no duration. Falls back.
- Whetted Cut + Dull: Dull is Hone's opposite: sharpening a blunt edge. Hone keeps the pull; the maths would sti
- Whetted Cut + Within: Not a shot. Falls back.
- Turn the Edge + Hone: Hone is Dull's opposite and pulls harder (3.0 vs 2.1): sharpening the blow that blunts. It
- Turn the Edge + Within: Not a shot. Falls back.
- Wrench + Plate: Plate is Strip's opposite: armouring the thing you strip. Strip keeps the pull; there is n
- Wrench + Within: Not a shot. Falls back.
- Wrench + Haste: No wind-up to shorten. Falls back.

## Nature

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Greening | Flourish | new:field_pulse | 44 of 65 (67%) |
| Sere Ground | Wilt | new:field_pulse | 45 of 65 (69%) |
| Reaping Sweep | Harvest | melee_burst | 60 of 65 (92%) |
| Vine Reach | Tangle | new:grapple | 60 of 65 (92%) |
| Heartwood | Grow | prop | 64 of 65 (98%) |
| Dwindling Gall | Shrink | new:hex | 64 of 65 (98%) |
| Thornburst | Sprout | delayed_blast | 64 of 65 (98%) |
| Heartrot | Blight | chain | 64 of 65 (98%) |
| Scatter Seed | Sow | new:seed | 64 of 65 (98%) |
| Unwinding | Unravel | detonate | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Shrink 7/9, Blight 7/9, Tangle 7/9, Sprout 8/9, Wilt 9/9, Flourish 9/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Sere Ground + Blight (`status blighted`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Heartwood + Shrink: making smaller the thing that is Grow. The numbers would land (Dwindled on whoever it shov
- Heartwood + Wilt: a wilting tree. The rise hits 15% harder but the trunk lives 30% shorter; the word kills w
- Dwindling Gall + Grow: making larger the thing you are shrinking. The numbers would land (more range, more damage
- Dwindling Gall + Within: a hex is not a shot; pierce falls back to a small damage bonus.
- Thornburst + Wilt: killing the plants the skill grows. The 15% damage would land, but the word contradicts it
- Thornburst + Within: a burst from the ground is not a shot; pierce falls back to a small damage bonus.
- Heartrot + Flourish: making thrive the wood you are rotting. The numbers would land (harder, longer) but the ve
- Heartrot + Unravel: freeing what the rot binds. The 1 m shove would land on each body it reaches; the wind-up 
- Reaping Sweep + Within: pierce means nothing on a sweep; it falls back to a small damage bonus.
- Scatter Seed + Harvest: reaping seed before it has grown. The numbers would land (harder, cheaper) but the verbs c
- Scatter Seed + Wilt: seeds that die in the ground. The bursts hit 15% harder but the seeds wait 30% less; the w
- Vine Reach + Unravel: a vine that lets go of what it is holding. The 1 m shove would land on the enemies beside 
- Vine Reach + Stillness: held in place, on the skill that moves you. It slows the haul by 20%, and the duration hal
- Unwinding + Tangle: binding again what you release. Rooted would land on everything it throws, and the two ver
- Unwinding + Attract: pulling in what you are flinging out. The pull lands against the shove; the word contradic

## Poison

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Clean Air | Cleanse | ground_zone | 42 of 65 (64%) |
| Funnel | Flush | detonate | 42 of 65 (64%) |
| Bitter Tonic | Stimulate | self_buff | 44 of 65 (67%) |
| Sapping Tether | Sap | channel | 48 of 65 (73%) |
| Residue | Linger | ground_zone | 59 of 65 (90%) |
| Fouling Slide | Contaminate | dash | 60 of 65 (92%) |
| Black Purge | Purge | targeted_strike | 64 of 65 (98%) |
| Caustic Spew | Corrode | melee_burst | 64 of 65 (98%) |
| Sting Dart | Poison | projectile | 65 of 65 (100%) |
| Counterdose | Neutralise | projectile | 65 of 65 (100%) |

This affinity's runes that act on the fewest of its skills: Purge 5/9, Corrode 5/9, Poison 5/9, Sap 6/9, Neutralise 7/9, Flush 8/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Funnel + Attract (`pull +1.5`)
- Sapping Tether + Poison (`status dosed 2`)
- Sapping Tether + Bind (`status pinned`)
- Sapping Tether + Essence (`cost x0.85`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Sting Dart + Purge: Its own opposite: clearing doses on the skill that gives them. The fallback is +40% agains
- Sting Dart + Neutralise: An antidote on the dosing dart: the meaning cancels. The fallback is an interrupting dart 
- Sting Dart + Rise: A dart does not lift a body; the fallback is a free Aloft on a 6-essence bolt.
- Black Purge + Linger: Its own opposite in spirit: residue that stays, on a skill that empties the body at once; 
- Black Purge + Persist: Nothing on an all-at-once blow lasts; the fallback lengthens nothing.
- Black Purge + Many: A purge is one body's bill; jumping to a second target splits the blow, and the fallback c
- Fouling Slide + Cleanse: Its own opposite: cleaning the bodies you foul. The fallback only cools reflux, which read
- Fouling Slide + Stillness: A held, slow slide contradicts it: the fallback cuts its speed by 20%.
- Caustic Spew + Neutralise: Its own opposite: rendering the acid harmless. The fallback interrupts and weakens a spray
- Caustic Spew + Rise: Acid does not lift; the fallback is a free Aloft burst.
- Counterdose + Poison: Dosing with the dart that cancels doses: the fallback lands 2 fresh doses after the cancel
- Counterdose + Purge: Calling the bill due on a skill that cancels it: the two cancel, and the fallback is only 
- Counterdose + Fade: Shortens the seizure by 40%, the skill's whole effect, for +25% on a 45-damage hit.
- Residue + Flush: Its own opposite: cleaning the area out. The fallback shoves everyone out of the slick eve
- Sapping Tether + Stimulate: Its own opposite: strengthening the body you are sapping; the fallback only speeds and hea

## Water

18 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Slack Water | Slack | melee_burst | 59 of 71 (83%) |
| Undertow | Ebb | displace | 64 of 71 (90%) |
| Standing Pool | Flood | ground_zone | 64 of 71 (90%) |
| Drawdown | Drain | detonate | 64 of 71 (90%) |
| Drench | Soak | delayed_blast | 64 of 71 (90%) |
| Steady Drip | Drip | new:seize | 64 of 71 (90%) |
| Siltfall | Settle | detonate | 64 of 71 (90%) |
| Breaker | Surge | melee_burst | 66 of 71 (92%) |
| Sluice Step | Sweep | dash | 66 of 71 (92%) |
| Pressure Jet | Gush | channel | 66 of 71 (92%) |
| Riptide Lash | Ebb | displace | 70 of 71 (98%) |
| Backwash | Splash | self_buff | 70 of 71 (98%) |
| Wringing Grip | Dry | targeted_strike | 70 of 71 (98%) |
| Upwelling | Float | displace | 70 of 71 (98%) |
| Drowning Hold | Drown | new:seize | 70 of 71 (98%) |
| Seepage | Seep | new:seize | 70 of 71 (98%) |
| Water Bolt | Surge | projectile | 71 of 71 (100%) |
| Tidal Bore | Wave | projectile | 71 of 71 (100%) |

This affinity's runes that act on the fewest of its skills: Gush 10/17, Flood 17/17, Drain 17/17, Ebb 16/16, Soak 17/17, Dry 17/17

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Water Bolt + Self: a thrown bolt does nothing to its caster; no duration to stretch, falls back to a little p
- Water Bolt + Persist: a bolt has nothing that lasts; falls back to a little power
- Water Bolt + Ebb: pull 1.5 on a bolt that shoves 1.5: the two cancel and the target stays put. Maths lets it
- Breaker + Seep: a melee arc has nothing to pierce; falls back to a little power
- Breaker + Ebb: a pull added to a 4 m throw: the blow drags in and throws out at once. Maths lets it act; 
- Sluice Step + Seep: it already passes through bodies; pierce has nothing to add and falls back to a little pow
- Sluice Step + Persist: a dash lasts 0.18 s and leaves nothing; falls back to a little power
- Sluice Step + Settle: its own opposite: Mired in the moment they are swept along - the current both carries and 
- Undertow + Surge: a push away from the point inside a pull toward it: the two fight. Maths lets it act; it s
- Undertow + Seep: nothing to pierce; falls back to a little power (and it deals no damage, so to cost)
- Undertow + Self: it acts on a spot on the floor, not on you; falls back
- Riptide Lash + Surge: shove 1.5 on a body you are hauling in: it lands a step short of you, which undoes the ski
- Riptide Lash + Seep: nothing to pierce; falls back to a little power
- Riptide Lash + Persist: a yank has nothing that lasts; falls back to a little power
- Standing Pool + Seep: nothing to pierce; falls back to a cost cut
- Standing Pool + Drown: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Backwash + Seep: nothing to pierce; falls back to a cost cut
- Backwash + Ebb: a pull on a skill whose point is throwing attackers off you: it drags them back into reach
- Pressure Jet + Ebb: a pull added to a stream that pushes: each tick drags in and pushes out. Maths lets it act
- Drawdown + Surge: shoves the drained bodies away while the water drags them in. Maths lets it act; it should
- Drawdown + Seep: nothing to pierce; falls back to a cost cut
- Drawdown + Persist: it is one pull, nothing lasts; falls back to a cost cut
- Drench + Seep: nothing to pierce; falls back to a cost cut
- Drench + Self: a cloudburst over a spot, not over you; falls back to a cost cut
- Wringing Grip + Soak: its own opposite: Soaks the body as you wring it dry. Maths lets it act; it undoes the ski
- Wringing Grip + Seep: a grip has nothing to pierce; falls back to a little power
- Wringing Grip + Persist: nothing lasts; falls back to a little power
- Upwelling + Drown: its own opposite: held under while being floated. Maths lets it act; it should not
- Upwelling + Fall: knocks flat what it just lifted, and it has no poise field: falls back to a little power
- Upwelling + Seep: nothing to pierce; falls back to a little power
- Drowning Hold + Float: its own opposite: Aloft while held under. Maths lets it act; it should not
- Drowning Hold + Seep: nothing to pierce; falls back to a little power
- Drowning Hold + Haste: there is no wind-up to shorten; falls back to a little power
- Steady Drip + Haste: no wind-up to shorten; falls back
- Steady Drip + Seep: nothing to pierce; falls back
- Siltfall + Sweep: its own opposite: a current that carries them on, the moment they settle. Maths lets it ac
- Siltfall + Seep: nothing to pierce; falls back to a cost cut
- Seepage + Splash: its own opposite: bursting outward on contact is exactly what seeping in is not. Maths let
- Seepage + Fall: no poise to raise and nothing to knock down; falls back to a little power
- Tidal Bore + Seep: it already passes through everything it meets; falls back to a little power
- Tidal Bore + Self: nothing lasts on you; falls back to a little power
- Tidal Bore + Ebb: drags back toward you the bodies it is carrying away. Maths lets it act; it should not
- Slack Water + Seep: nothing to pierce; falls back to a cost cut

## Wind

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Tailwind | Carry | dash | 27 of 65 (41%) |
| Crosswind Veil | Buffer | self_buff | 27 of 65 (41%) |
| Dead Air | Lull | ground_zone | 42 of 65 (64%) |
| Gale Lane | Blow | ground_zone | 43 of 65 (66%) |
| Updraft | Lift | displace | 58 of 65 (89%) |
| Crosscut | Lash | targeted_strike | 60 of 65 (92%) |
| Spindrift | Blow | channel | 60 of 65 (92%) |
| Blowout | Disperse | melee_burst | 60 of 65 (92%) |
| Cutting Gust | Lash | projectile | 62 of 65 (95%) |
| Downdraft | Drop | delayed_blast | 64 of 65 (98%) |
| Headwind | Stall | melee_burst | 64 of 65 (98%) |
| Dust Devil | Whirl | ground_zone | 64 of 65 (98%) |

This affinity's runes that act on the fewest of its skills: Lash 6/10, Lift 7/11, Drop 7/11, Stall 7/11, Blow 7/10, Whirl 9/11

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Cutting Gust + Within: it already passes through everything; falls back to a little power
- Cutting Gust + Buffer: its own opposite: cushioned air has no edge, and it has no wind-up to shorten: falls back
- Crosscut + Buffer: its own opposite: a cushioned cut. Maths lets it act (shorter recovery); the word is nonse
- Downdraft + Lift: its own opposite: throws Aloft what it slams flat. Maths lets it act; it should not
- Downdraft + Self: it lands on a spot, not on you; falls back
- Updraft + Drop: its own opposite, and it has no poise field: falls back to a cost cut
- Updraft + Within: nothing to pierce; falls back
- Gale Lane + Lull: its own opposite: dead air in a wind lane. Maths lets it act (less reflux); the word is no
- Spindrift + Lull: its own opposite: dead air while you run. Maths lets it act (less reflux); the word is non
- Spindrift + Here: it moves with you; no wind-up to shorten, falls back
- Headwind + Persist: nothing on the skill lasts; falls back to a little power
- Dust Devil + Disperse: its own opposite: blowing apart what it gathers. Maths lets it act (reach, power); it shou
- Dust Devil + Lift: maths lets it through, but on a payload that repeats every tick, so nothing in it ever act
- Dust Devil + Within: nothing to pierce; falls back
- Blowout + Whirl: its own opposite: pulls in what it blows apart. Maths lets it act; it should not

