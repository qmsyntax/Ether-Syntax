# Revised base rune set, side by side (proposal, 2026-10-22)

Brent asked for a revised rune set beside the current one, and for runes that make sense ("fire not having burn as
a core one is suspect"). Burn was in Fire's core and the earlier list of specific verbs left core words out; it is
Fire's first rune here.

**Rules used to pick each rune.**
1. The affinity's defining verb is its first rune (Fire: Burn; Water: Flood; Light: Shine).
2. Prefer verbs the data assigns to that affinity (`tools/runes/rune_candidates.py`, from forced-affinities.json).
   Skip off-sense matches: stampede, salute, liquidate, kidnap, hijack, kiss and smile.
3. Opposites come from WordNet antonyms where one exists. Otherwise one is designed within the domain.
4. A rune must be something a power can do in a fight or to the world.
5. Every rune name is unique, across affinities and against the universal runes.
6. Same sizes as now: Water 8 pairs, the rest 5.

**Source marks.**
- **c**: a core word of the affinity.
- **d**: among the data's most specific verbs for the affinity.
- **a**: the opposite is a WordNet antonym.
- **k**: kept from the current set.
- **x**: designed, where the data had nothing usable.

## Water

| Current | Proposed | Sources |
|---|---|---|
| Surge ↔ Ebb | **Flood ↔ Drain** | c, d |
| Flow ↔ Pool | **Surge ↔ Ebb** | d, a, k |
| Soak ↔ Wring | **Soak ↔ Dry** | d, a |
| Crush ↔ Mist | **Float ↔ Drown** | d, k |
| Well ↔ Dry | **Gush ↔ Drip** | d |
| Mirror ↔ Murk | **Sweep ↔ Settle** | d, a (settle is float's antonym) |
| Erode ↔ Coat | **Splash ↔ Seep** | d, x |
| Drown ↔ Float | **Wave ↔ Slack** | c, x (slack water: the still moment at the turn of the tide) |

## Fire

| Current | Proposed | Sources |
|---|---|---|
| Ignite ↔ Quench | **Burn ↔ Quench** | c, k (the data has "quell") |
| Radiate ↔ Absorb | **Ignite ↔ Snuff** | d, a |
| Consume ↔ Fuse | **Explode ↔ Implode** | d, a |
| Burst ↔ Implode | **Blaze ↔ Smoulder** | c (flame), x |
| Flare ↔ Smoke | **Flare ↔ Smother** | k, x |

Radiate and Absorb move to Light (the data puts emit and absorb there); Fuse moves to Metal.

## Earth

| Current | Proposed | Sources |
|---|---|---|
| Raise ↔ Sink | **Raise ↔ Sink** | k, a (mount/climb ↔ descend) |
| Harden ↔ Crumble | **Harden ↔ Crumble** | k |
| Root ↔ Quake | **Root ↔ Quake** | k |
| Weigh ↔ Buoy | **Dig ↔ Bury** | d, x |
| Shard ↔ Sand | **Tunnel ↔ Collapse** | d, x |

Language has few earth verbs. Most of Earth stays designed.

## Wind

| Current | Proposed | Sources |
|---|---|---|
| Gust ↔ Lull | **Blow ↔ Lull** | c (the defining verb), k |
| Updraft ↔ Downdraft | **Lash ↔ Buffer** | d (lash, whip), k |
| Shear ↔ Buffer | **Lift ↔ Drop** | x (Updraft and Downdraft as plain verbs) |
| Tailwind ↔ Headwind | **Carry ↔ Stall** | x (Tailwind and Headwind as verbs) |
| Whirl ↔ Disperse | **Whirl ↔ Disperse** | k |

## Lightning

| Current | Proposed | Sources |
|---|---|---|
| Charge ↔ Discharge | **Strike ↔ Ground** | d, x |
| Arc ↔ Insulate | **Charge ↔ Discharge** | k (the data has generate, induce) |
| Positive ↔ Negative | **Arc ↔ Insulate** | k (the data has connect ↔ disconnect) |
| Quicken ↔ Paralyse | **Quicken ↔ Stun** | k (the data has stimulate ↔ stifle) |
| Sense ↔ Jam | **Thunder ↔ Silence** | c, d (boom, rumble) |

## Ice

| Current | Proposed | Sources |
|---|---|---|
| Freeze ↔ Thaw | **Freeze ↔ Thaw** | d, k |
| Rime ↔ Shatter | **Frost ↔ Glaze** | c, d (glaze replaces Slick) |
| Frost ↔ Slick | **Snow ↔ Melt** | c, d |
| Brittle ↔ Toughen | **Rime ↔ Shatter** | k |
| Stasis ↔ Frostbite | **Brittle ↔ Toughen** | k |

## Dark

| Current | Proposed | Sources |
|---|---|---|
| Deepen ↔ Dawn | **Darken ↔ Lighten** | c, a |
| Cloak ↔ Silhouette | **Obscure ↔ Expose** | d |
| Shadowstep ↔ Pin | **Shadowstep ↔ Pin** | c (shadow), k |
| Devour ↔ Disgorge | **Hush ↔ Resound** | d, a (hush ↔ louden) |
| Dread ↔ Hush | **Devour ↔ Disgorge** | k, x |

## Metal

| Current | Proposed | Sources |
|---|---|---|
| Forge ↔ Rust | **Forge ↔ Rust** | k, d |
| Draw ↔ Spurn | **Fuse ↔ Sunder** | d, a (merge ↔ break apart) |
| Hone ↔ Dull | **Seal ↔ Breach** | d, a (seal ↔ unseal) |
| Plate ↔ Strip | **Hone ↔ Dull** | k, a (sharpen ↔ dull) |
| Ring ↔ Deaden | **Plate ↔ Strip** | k (the data has wrap ↔ unwrap) |

Ring leaves (the data puts ringing with Lightning's sound); magnetism (Draw ↔ Spurn) has no support in the data.

## Blood

| Current | Proposed | Sources |
|---|---|---|
| Bleed ↔ Staunch | **Bleed ↔ Staunch** | c, k |
| Drink ↔ Spill | **Drink ↔ Spill** | k (the data has suck) |
| Thicken ↔ Thin | **Clot ↔ Thin** | d (clot) |
| Race ↔ Stall | **Pulse ↔ Still** | d (heartbeat), x |
| Brand ↔ Disown | **Choke ↔ Breathe** | d (moved here from Disease) |

## Life

| Current | Proposed | Sources |
|---|---|---|
| Mend ↔ Wither | **Heal ↔ Wither** | c, k |
| Swell ↔ Waste | **Renew ↔ Exhaust** | d, k |
| Vigour ↔ Exhaust | **Strengthen ↔ Weaken** | d, a |
| Regrow ↔ Arrest | **Cure ↔ Sicken** | d, x |
| Rouse ↔ Numb | **Regrow ↔ Arrest** | k (the data has rebuild) |

## Death

| Current | Proposed | Sources |
|---|---|---|
| Reap ↔ Spare | **Kill ↔ Spare** | d, k (reap reads as harvest, so it goes to Nature) |
| Raise ↔ Lay | **Animate ↔ Lay** | k (renamed so Raise stays Earth's alone) |
| Rot ↔ Preserve | **Rot ↔ Preserve** | k |
| Haunt ↔ Exorcise | **Haunt ↔ Exorcise** | d, k |
| Doom ↔ Reprieve | **Vanish ↔ Manifest** | d, a (vanish ↔ appear) |

## Nature

| Current | Proposed | Sources |
|---|---|---|
| Sprout ↔ Wilt | **Grow ↔ Shrink** | c, a (expand ↔ shrink) |
| Tangle ↔ Unravel | **Sprout ↔ Wilt** | k |
| Bloom ↔ Seed | **Flourish ↔ Blight** | d, x |
| Thorn ↔ Moss | **Harvest ↔ Sow** | d (harvest, reap), x |
| Feed ↔ Starve | **Tangle ↔ Unravel** | k |

## Light

| Current | Proposed | Sources |
|---|---|---|
| Shine ↔ Shade | **Shine ↔ Dim** | c, a (bright ↔ dull) |
| Lance ↔ Glow | **Flash ↔ Glow** | d |
| Expose ↔ Mirage | **Radiate ↔ Absorb** | d, a (emit ↔ absorb) |
| Dazzle ↔ Clarity | **Glare ↔ Clarity** | d, k |
| Halo ↔ Eclipse | **Reflect ↔ Bend** | x |

## Dream

| Current | Proposed | Sources |
|---|---|---|
| Sleep ↔ Wake | **Sleep ↔ Wake** | c, a, k |
| Phantasm ↔ Dispel | **Conjure ↔ Dispel** | c (illusion), d (imagine, simulate), k |
| Nightmare ↔ Reverie | **Dread ↔ Soothe** | d |
| Muddle ↔ Clarify | **Mimic ↔ Unmask** | d (imitate, disguise) |
| Whisper ↔ Shut | **Whisper ↔ Shut** | k |

## Poison

| Current | Proposed | Sources |
|---|---|---|
| Envenom ↔ Purge | **Poison ↔ Purge** | c, k |
| Sap ↔ Stimulate | **Contaminate ↔ Cleanse** | d (contamination) |
| Steep ↔ Spike | **Corrode ↔ Neutralise** | d (acid), x |
| Spread ↔ Inure | **Linger ↔ Flush** | d (residue), k |
| Linger ↔ Flush | **Sap ↔ Stimulate** | k |

Poison is the thinnest affinity in the data (41 words).

## Disease

| Current | Proposed | Sources |
|---|---|---|
| Billow ↔ Clear | **Infect ↔ Disinfect** | c, d, a |
| Fester ↔ Seal | **Spread ↔ Contain** | d (Plague ↔ Quarantine as plain verbs) |
| Choke ↔ Breathe | **Fester ↔ Lance** | k, x (lancing a boil) |
| Cling ↔ Lift | **Billow ↔ Clear** | k |
| Plague ↔ Quarantine | **Overrun ↔ Immunise** | d, x |

## Totals

- 166 runes, as now.
- About two-thirds of the proposed runes are backed by the data or WordNet, or are core words; the rest are designed
  (x) where language is thin, mostly in Earth, Wind, Poison and Dark.
- All 166 names are unique, and none repeats a universal rune. Four clashes were renamed:
  - Raise: Death's became Animate.
  - Sink: Water's pair became Float ↔ Drown.
  - Reveal: Dark's pair became Obscure ↔ Expose.
  - Calm: Water's pair became Wave ↔ Slack.
- **Nothing in the workbook has changed.** Once Brent approves, the chosen pairs go into `design/runes-workbook.xlsx`
  through Excel, and each new rune gets a role and draw.
