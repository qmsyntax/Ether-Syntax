# Runes v0 — writing a skill in the ethercosm

> **2026-10-21: §2-3 superseded by design/14** (base runes per affinity and universal runes; the skill is the verb,
> runes are its means). The cage, facets, flaws and forms below are parked until that layer settles.

Pitch for Brent to approve or redline, 2026-10-21. Nothing here is built. Every number is a first guess.
Tags: **[B]** Brent's ruling, **[C]** read in the books (paraphrased notes only: design/01 LAW 4c,
research/book5-ch226-230-notes.md), **[MODEL]** our invention. Untagged text under a [MODEL] heading is [MODEL].
The rune alphabet, its names, glyphs, words and forms are original to this project. The books' alphabet is not used.

Brent's brief (2026-10-21):
- Concepts (runes) must be placed in the proper positions in the skill, in the ethercosm.
- A skill can be malformed, or formed uniquely for interesting results.
- The system must be very, very robust.
- The base is a set of runes for base concepts, like vestiges (friction, speed, destruction). The runes are like the
  letters of those concepts.

---
## 1. The pitch on one page

1. **Sixteen letters.** Every concept in the game is spelled from 16 root runes in four houses: Motion, Force, Form
   and Measure. A single letter is a weak concept on its own: *Motion* is speed. Two letters make a word:
   *Motion+More* is Acceleration, *Motion+Rest* is Friction, *Ruin+More* is Destruction. A few three-letter words
   are rare and strong. **Order matters**: *Rest+Motion* is not Friction. It is Lurch: the skill waits, then goes.
2. **A skill is a cage with four places** [C: an ability is a spherical cage of concepts; MODEL: the four]. Unravelled
   in the ethercosm, every skill shows a fixed **core** (its affinity and its form) and four **facets** around it:
   - **Call**: the casting itself (wind-up, cost, recovery, reflux).
   - **Course**: how it travels or spreads (speed, path, range, area).
   - **Contact**: what it does to what it touches.
   - **Wake**: what it leaves behind (zones, statuses, how long things last).
   The same word does different things in different places. Acceleration in Call is a faster wind-up; in Course a
   faster bolt; in Contact a harder shove.
3. **Proper position.** Each house is at home in two neighbouring facets: Motion in Call and Course, Force in Course
   and Contact, Form in Contact and Wake. Measure words are adverbs, at home anywhere. A rune set where it belongs is
   clean. A rune set anywhere else still works, but it adds **dissonance**.
4. **Malformed skills.** Dissonance comes from misplaced runes and from opposed letters fighting in one facet
   (Motion against Rest, Push against Pull, Form against Ruin, Bond against Breach, More against Less) without a word or
   a mark to reconcile them. Enough of it gives the skill a **flaw**: a named, predictable quirk such as Recoil,
   Stutter, Surge or Drift. Flaws never hurt the caster [B: no skill hurts its caster], and **every flaw can be used**:
   Recoil throws you back, which is also a disengage.
5. **Unique forms.** Particular words in particular places make a skill **settle into a form**: a named variant that
   changes what the skill *does*, not just its numbers. Water Bolt with a returning, turning course and a breaching
   contact becomes *Eddy*, a bolt that stops at the first enemy and circles it. Forms are hidden until someone makes
   one. **Crooked forms** are forms that need a flaw to exist.
6. **The ink is constructs; the rule is the chain** [C: constructs advance stages; chains are what levels].
   - The skill's runechain still fills as you spend essence through it.
   - At each stage it **suffulates** [C]: a gap opens, and you set a construct.
   - A **vestige carries a letter**, a **remnant a two-letter word**, a **spirit a three-letter word**.
   - Setting it advances the stage **and** writes its rune into a facet you choose.
   - The stage cap (stars + 1) [C] therefore caps how much can be written.
7. **Knowledge is power** [C: runeology is studied; a self-taught fighter has the instinct but not the theory].
   **Runeology** decides how much of the outcome you can see before you commit, and what you can do with a rune.
   - With no theory you write blind.
   - With theory you see the words, the dissonance and the predicted flaw.
   - With an affinity's dialect you get hints that a form is near.
8. **Writing is permanent** [C: an irreversible mistake in development].
   - A chain only comes undone from its **newest** rune. A runesetter scours runes off the end, one at a time, for a
     fee and that stage's progress.
   - A severing elixir [C] wipes the whole skill back to stage 0 for a clean rebuild.
   - A slip when setting (low runeology, a hard word) can put a rune in the wrong place. That is how most malformed
     skills happen.
9. **Robust by construction.**
   - Any arrangement of runes in any skill resolves to a defined result. Letters always have an effect; words
     replace letters; forms replace words.
   - Hard caps hold every number in range.
   - The preview and the cast use the same function.
   - An exhaustive test runs every letter and word in every facet of every skill, plus a large random fuzz.

---
## 2. The alphabet [MODEL]

Sixteen root runes in four houses of four. Each house has two **opposed pairs**.

| House | Letters (opposed pairs in brackets) | What the house is about | At home in |
|---|---|---|---|
| **Motion** | Motion, Rest (opposed); Turn, Return | how things move and when | Call, Course |
| **Force** | Push, Pull (opposed); Weight, Edge | what strikes and how hard | Course, Contact |
| **Form** | Form, Ruin (opposed); Bond, Breach (opposed) | what is made, broken, held or opened | Contact, Wake |
| **Measure** | More, Less (opposed); Far, Long | how much, how far, how long | anywhere |

The houses sit around the cage in order, so each house is at home in two neighbouring facets:
Call → Course → Contact → Wake → Call. Measure is the exception: it modifies whatever it sits next to.

**Glyphs.** Each letter gets an original glyph built from strokes on the 3x3 grid the ethercosm already draws
(`ethercosm_screen.gd _draw_rune`). Houses share a stroke family, so a reader learns to see a house at a glance.

### 2.1 What a single letter does in its home facets

These are the fallback effects. Every letter has a defined effect in every facet, so nothing is ever a dead write.

| Letter | In its first home | In its second home |
|---|---|---|
| **Motion** | Call: wind-up and recovery −20% | Course: speed +40% (bolt, dash, shove travel) |
| **Rest** | Call: reflux left −25% | Course: it stops at its end and stays 1 s (a bolt hangs; a dash ends Braced) |
| **Turn** | Call: you can walk while it winds up | Course: the path bends gently toward the nearest enemy; arcs +30° |
| **Return** | Call: a second cast within 1.5 s costs half | Course: it comes back to you at the end, hitting again on the way |
| **Push** | Course: shoves what it passes 1 m aside | Contact: +1.5 m shove |
| **Pull** | Course: drags what it passes 1.5 m along | Contact: pulls the target 2 m toward you |
| **Weight** | Course: speed −20%, damage +30% | Contact: poise damage +50%; light enemies knocked flat 0.5 s |
| **Edge** | Course: areas −20% and lines thinner, damage +25% | Contact: ignores a frontal block |
| **Form** | Contact: the hit leaves a small made thing (by affinity, §2.3) | Wake: what it leaves is solid: blocks shots for its life |
| **Ruin** | Contact: +40% to armour, shields and standing stone | Wake: what it leaves eats: zones +40%; statuses also deal damage |
| **Bond** | Contact: roots light enemies 1 s; holds heavy ones 0.3 s | Wake: statuses it applies last +30% and cannot be cleansed |
| **Breach** | Contact: passes through the first target (pierce 1) | Wake: what it leaves spreads to an enemy standing close |

Measure letters act on the facet's **main number**:
- in Call, power;
- in Course, range, area or speed (whichever the skill has, in that order);
- in Contact, damage or shove;
- in Wake, duration and strength.

| Letter | Effect in any facet |
|---|---|
| **More** | Main number +25%, the skill's cost +10% |
| **Less** | Cost −20%, main number −10% |
| **Far** | The facet's distance +50% (range, shove, tether, reach) |
| **Long** | The facet's duration +50% (wind-up excepted: in Call, Long means the effect lasts longer once cast) |

### 2.2 Out of place

A letter outside its houses' facets still gives its house's **raw effect**:
- Motion: +10% speed.
- Force: +10% damage.
- Form: +10% duration.

It also adds **+1 dissonance**, and it marks the facet with its house's **misplacement flaw** (section 4).

### 2.3 Affinity dialects [C: runeology is taught per affinity; MODEL: the dialects]

The Form house reads differently in each affinity. What a "made thing" is:

| | Form makes | Ruin is | Bond is | Breach is |
|---|---|---|---|---|
| Water | a puddle (slows, Soaks) | erosion (armour stripped over time) | an undertow (drags) | seepage (gets behind shields) |
| Fire | embers (Alight on touch) | burning down (damage over time) | a brand (the mark spreads Alight) | flashover (jumps to the nearest) |
| Earth | a shard of standing stone (a small `Stone`) | crumbling (shatters stone and guard) | rooting (stone grips the feet) | fissure (travels along the ground) |
| Wind | an eddy (deflects shots) | scouring (strips buffs) | a tether of air | a draught (passes walls up to 1 m) |
| Lightning | a rod (`GroundRod`) | burnout (Live marks also burn) | a circuit (marks link) | arcing (a mark jumps once) |

Only the Form house has a dialect. The other twelve letters mean the same in every affinity, which keeps the alphabet
learnable.

---
## 3. Words, the lexicon [MODEL]

A **word** is two or three letters in one facet, read in order. The **first letter is the stem** and the rest modify
it. A lexicon word lists **its own home facets** (the Home column below), which can differ from its stem's house:
Tension is at home in Call, though Push is a Force letter. For a spelling not in the lexicon, the stem's house decides
where it is at home. A word in the **lexicon** replaces its letters' separate effects with
one authored effect: stronger, cleaner, and often a new behaviour. A spelling that is not in the lexicon is read
letter by letter (section 2) with dissonance for anything that fights.

**Sanctioned paradoxes.** Some lexicon words are built from opposed letters, Friction (*Motion+Rest*) among them.
A word in the lexicon is never dissonant, whatever it is made of. Opposed letters only fight when they do not spell a
word.

### 3.1 Starting lexicon (about 40 two-letter words, 10 three-letter)

The six concepts the game already has [existing, design/05 §3] are words here, so nothing built is lost:
- Acceleration: Motion+More
- Piercing: Edge+Breach
- Compression: Pull+Less
- Tension: Push+Bond
- Reach: Far (a single-letter word)
- Stillness: Rest+Long

Brent's three examples:
- Speed: Motion
- Friction: Motion+Rest
- Destruction: Ruin+More

| Word | Spelling | Home | Effect at home (generic; skills may override, §3.2) |
|---|---|---|---|
| Speed | Motion | Call/Course | as the letter |
| Acceleration | Motion+More | Course | speed +40%, wind-up −30%, shove doubled in Contact |
| Friction | Motion+Rest | Course | it slows as it travels and hits harder the slower it is (up to +60% at the end) |
| Lurch | Rest+Motion | Call | the cast holds 0.5 s, then goes at +50% speed and +25% damage |
| Momentum | Motion+Weight | Course | damage grows with distance travelled (+5% per metre, to +50%) |
| Stillness | Rest+Long | Wake | reflux left −30%; statuses +50%; what it leaves lingers +50% |
| Inertia | Rest+Weight | Contact | the target cannot move for 0.8 s (heavy enemies 0.3 s) |
| Rebound | Turn+Push | Course | it bounces off the first wall or stone it meets, once |
| Ricochet | Turn+Motion+Return | Course | it bounces between up to three enemies |
| Echo | Return+Long | Wake | it happens again, smaller (40%), 1 s later in the same place |
| Resonance | Return+More | Contact | each hit on the same target within 3 s adds +15% (up to 4) |
| Repulsion | Push+More | Contact | shove +3 m and Crush damage +50% |
| Shockwave | Push+Far | Contact | the shove also hits everything within 2.5 m of the target |
| Tension | Push+Bond | Call | can be held up to 1 s for up to +50% |
| Compression | Pull+Less | Course | cost −25%; areas 20% smaller and 25% harder |
| Gravity | Pull+Weight | Wake | what it leaves draws enemies in, 1.5 m/s |
| Vortex | Pull+Turn | Course | enemies it passes spiral toward its path |
| Collapse | Pull+Weight+More | Wake | at its end, everything within 4 m is pulled to one point and Crushed against each other |
| Piercing | Edge+Breach | Course/Contact | passes through targets; ignores a frontal block; poise damage +50% |
| Severance | Edge+Ruin | Contact | cuts guard: shields and frontal blocks are broken for 3 s |
| Keenness | Edge+More | Contact | damage +30% to a target already below half health |
| Construction | Form+Weight | Wake | what it leaves is a solid wall piece for 4 s (a `Stone`) |
| Growth | Form+More | Wake | what it leaves grows 50% over its life |
| Multiplicity | Form+Return | Course | it splits into three weaker copies (35% each) |
| Destruction | Ruin+More | Contact | +60% to armour, shields, stone and things made by skills |
| Erosion | Ruin+Long | Wake | targets lose 2% armour a second while inside (to −20%) |
| Shatter | Ruin+Breach | Contact | a killing blow bursts the body for 50% damage around it |
| Binding | Bond | Contact | as the letter |
| Tether | Bond+Far | Contact | the target is leashed to the spot it was hit, 4 m, for 3 s |
| Snare | Bond+Rest | Wake | the first enemy to enter what it leaves is rooted 1.5 s |
| Division | Breach+More | Course | on the first hit it splits into two at ±30° |
| Passage | Breach+Motion | Course | passes walls up to 1 m thick |
| Reach | Far | any | as the letter |
| Duration | Long | any | as the letter |
| Thrift | Less | Call | cost −30%, nothing else lost |
| Annihilation | Ruin+More+More | Contact | +100% to anything made, worn or raised; −20% to flesh |

The full lexicon is a data table (`runes.json "words"`) and grows with the game. Three-letter words need Advanced
runeology to set (section 6) and a spirit-tier construct, or a split remnant plus a letter.

### 3.2 Per-skill readings

design/05 already gives every one of the 40 skills the two concepts that transform it most, with the place they
work. Those become **per-skill readings**: a word in a named facet of a named skill does something authored instead
of its generic line. Water Bolt + Piercing in Course: "passes through and shoves every body in the line" (design/05
§3.1). That is 80 readings already designed. This is where "the proper position" lives for each skill.

---
## 4. Dissonance and flaws [B: you can malform a skill; MODEL: how]

**Dissonance** is counted per skill, from the cage as written:

| Source | Dissonance |
|---|---|
| A letter or word outside its house's home facets | +1 each |
| Two opposed letters in one facet that do not spell a lexicon word | +2 per pair |
| A facet's stem house opposed to its neighbour's (Motion stem beside a Rest stem, round the ring) | +1 |
| A three-letter spelling that is not a word | +1 |
| A **Hinge** mark between two runes (section 7) | −1, never below 0 |
| One of the soul's native letters (section 8) | that letter's misplacement is free |

| Total | State | What happens |
|---|---|---|
| 0 | **True** | Clean. A true skill also gets +5% to everything (a well-made thing works better) |
| 1-2 | **Quirked** | One flaw, mild |
| 3-4 | **Faulted** | Up to two flaws, full strength; reflux left +20% |
| 5+ | **Fractured** | Flaws as faulted; 15% of casts fizzle (essence spent, nothing happens); nothing more can be written until a rune is scoured |

**Which flaw.** Flaws are deterministic: they come from what fights, never from a random table. The worst source
picks the first flaw, the next the second.

| What fights | Flaw | The quirk | How it can be used |
|---|---|---|---|
| Motion vs Rest | **Stutter** | the cast goes off 0-0.4 s late, unpredictably | it ruins an enemy's read of your timing as much as yours |
| Push vs Pull | **Recoil** | you are shoved 1.5 m opposite your aim on each cast | a free disengage |
| Form vs Ruin | **Crumble** | what it leaves lasts half as long, but hits 30% harder | short, sharp zones |
| Bond vs Breach | **Snap** | statuses it applies may drop off early (50%), but each drop refunds 2 essence | an essence engine on fast skills |
| More vs Less | **Surge** | output swings 60-140% per cast | a gamble; crooked forms feed on it |
| Motion out of place (Contact, Wake) | **Drift** | what it leaves wanders 1 m/s | roaming zones |
| Force out of place (Call, Wake) | **Kick** | casting staggers you for 0.2 s (no damage) | none; it is the honest bad one |
| Form out of place (Call, Course) | **Clot** | the bolt or dash slows to 60% over its course | combines with Friction and Momentum oddly |
| Neighbouring stems at odds | **Grate** | reflux left +15% | none; the cost of a crowded cage |

Flaws are shown in the skill's description like any other line, in a dull red, and the cast **looks** wrong: Stutter
flickers, Recoil kicks, Drift smears. A player can recognise a malformed skill on someone else.

**No flaw hurts the caster** [B 2026-10-11: abilities do not hurt their caster]. If Brent wants a darker version, a
"Backlash" flaw that wounds is one line of data. It is not in this pitch.

---
## 5. Unique forms [B: form a skill uniquely; MODEL: how]

A **form** is an authored pattern: required words in required facets of one skill (or of a whole skill form, such
as "any projectile"), with a dissonance tolerance. When a cage matches, the skill **settles**. It is renamed, its
icon gains a mark, and it changes what it does. Forms are checked after words and before caps.

| Form | Of | Needs | What it becomes |
|---|---|---|---|
| **Eddy** | Water Bolt | Course: Turn+Return; Contact: Breach | the bolt stops in the first enemy and circles it for 3 s, Soaking it and anything that comes close |
| **Riptide** | Breaker | Course: Pull+Turn; Contact: Repulsion | first draws everything in the arc to you, then throws it all out at once |
| **Standing Flame** | any fire dash | Course: Rest; Wake: Form+Long | where the dash ends, you leave a burning copy of yourself that enemies attack for 3 s |
| **Kickshot** *(crooked)* | any projectile | Call: Push (misplaced, so Kick or Recoil); Course: Acceleration | the recoil becomes a 4 m backward leap and the shot flies 50% faster |
| **Wildfire** *(crooked)* | any fire area | Surge, plus Wake: Growth | each Surge above 120% spawns a second, smaller area beside the first |

- **Discovery.** The first time a form settles, the game names it and writes it into your **runepedia**. The
  runepedia keeps every form, word and flaw you have met, with what you wrote.
- **Knowing forms.** Forms can also be read in pattern books, bought from a runesetter or found in realms, or taught.
  That gives them trade value: [C] a runepedia costs millions.
- **Scale.** Aim for 2-3 forms per skill (80-120 for the 40) plus about 10 that work on any skill of a form. Authored
  as data. The first build ships about a dozen.
- **Near a form.** With an affinity's dialect learned, the preview says "the cage leans toward something" when the
  cage is one word from a form of that affinity. It never says which word.

---
## 6. Setting a rune: the chain, the ink, the risk [C: chains, suffulation, constructs; MODEL: the rest]

1. **The chain fills.** Spending essence through a skill fills its runechain (as now; `progress_per_essence`).
2. **It suffulates.** At 100% the chain closes a stage and a **spacer** opens [C]. The skill needs a construct of
   the matching tier to advance (as now: vestige for 0→1, remnant 1→2, spirit 2→3, eidolon 3→4, asura 4→5).
3. **The ink.** Constructs carry concepts [C]. In this system:
   - A **vestige carries a letter** ("a vestige of Motion"). Wild vestiges are common.
   - A **remnant carries a two-letter word** ("a remnant of Friction").
   - A **spirit carries a three-letter word**.
   - Eidolons and asuras carry a word **and** a mark (section 7).
4. **The setting.** In the ethercosm you drag the construct onto a facet. The preview shows what you are allowed to
   see (section 6.1). You confirm. The stage advances and the rune is written. Optional, with Advanced runeology:
   - **Split a remnant**: write its two letters into two different facets.
   - **Fold** a letter into a word already in a facet, as long as the result spells a lexicon word.
5. **The risk.** The existing bind roll stays (80% now; `binding.success_chance`). It gains a modifier: +5% per
   runeology level above the rune's difficulty, −10% per level below. On a failed roll:
   - **Clean failure** (most failures): the construct is lost and you take the burn wound (existing). Nothing is
     written.
   - **Slip** (one failure in four with no runeology, one in ten with Basic, never with Advanced): the rune is
     written, but into a **neighbouring facet**, or a letter of a word is **dropped**. This is how most malformed
     skills are made. The game tells you what landed and where.

**Undoing.** A chain unwinds only from its end. A runesetter in town can **scour** the newest rune, for a fee
and the stage it bought: the skill drops a stage and the construct is not returned. To reach an older rune you scour
everything after it. A **severing elixir** [C] wipes the skill to stage 0 and an empty cage. It is rare and costly.
This makes the first runes on a skill the weightiest choice in it.

### 6.1 Runeology [C: runeology is studied, basic and advanced, per affinity; MODEL: the levels]

| Level | How you get it | What you can see and do |
|---|---|---|
| **Unread** | everyone | the letter you are placing and its house. The cage "hums" (true), "rattles" (quirked) or "grinds" (worse). No numbers. Slips 1 in 4 |
| **Basic** | a primer bought in any town, or a trainer's lesson | every letter's effect in every facet; the dissonance number; slips 1 in 10 |
| **Advanced** | the university in the big city [B 2026-10-18: one very big city], or a master | lexicon words named with their effects; the predicted flaws; split and fold; three-letter words; no slips |
| **Dialect (per affinity)** | a course per affinity, after Advanced | that affinity's Form-house readings in advance, and "leans toward" hints for its forms |

Runeology is knowledge, not a crafting skill. It does not count up 0-300; it is bought with time and money. That fits
the setting: an education you pay for [C], and a reason to travel to the big city.

---
## 7. Marks (microrunes) [C: a microrune alphabet exists; MODEL: these four]

Small marks go in the **spacers** a suffulated chain leaves between stages. A stage-3 skill has 3 spacers, and each
holds one mark. Marks are made by **Auragraphy** (design/11: rune ink is already in its recipe list) and set by
anyone with Basic runeology, with no roll. Unlike runes, marks can be lifted out for free.

| Mark | What it does |
|---|---|
| **Hinge** | −1 dissonance: separates two runes that would fight |
| **Tie** | links two neighbouring facets, so a Measure letter in one also applies to the other at half strength |
| **Plumb** | +10% to one facet's main number |
| **Seal** | the facet cannot be slipped into or written over by accident. Also makes scouring it cost double |

---
## 8. The soul's own hand [MODEL; optional, for Brent]

Every character rolls two **native letters**, hidden, like the per-save talent flags. In your own skills:
- a native letter is never misplaced (no dissonance, no flaw from being out of place);
- it is 25% stronger.

You find them by writing them: the first time you set one, the ethercosm shows it in your hand's colour. Two
characters with the same talent and affinities still end up writing different skills.

**Talent letters** [C: some concepts are gated behind manipulation talents; MODEL: the shape]. A few talents add a
seventeenth letter only their holder can write, a hook for later talent design (design/04). None are proposed here.

---
## 9. What it looks like [MODEL]

The ethercosm stays as it is (stars, satellite, abilities in orbit). Clicking a skill **unravels its cage** into a
flat plate in the right panel:
- **Centre**: the core, showing the affinity glyph and the form glyph.
- **Four arms**: Call at the top, Course on the right, Contact at the bottom, Wake on the left. Each has three letter
  sockets.
- **Around the plate**: the runechain ring, as now, with a spacer notch per closed stage for marks.
- **Under it**: the skill's text, rebuilt from the resolved cage (numbers, words, flaws in red, the form's name in
  gold) and a dissonance gauge.

Dragging a construct over an arm previews it live, at your runeology level. Releasing asks once. The plate is drawn
like everything else (`UiDraw`); glyphs come from the existing generator, seeded per letter instead of per skill.

---
## 10. Making it robust [B: very, very robust; MODEL: the rules]

1. **One pure resolver.** `Runes.resolve(ability_def, cage, affinity, hand) -> {stats, grants, flaws, form,
   dissonance, lines}`. It has no side effects and no randomness, so preview and cast cannot disagree.
   - `ability_stats` calls it, replacing the concept mods in `constructs.json`.
   - The cast reads `grants` (pierce, split, return, linger, tether...) through the existing `apply_hit` pipeline and
     behaviour hooks. A rune never adds a branch inside a behaviour.
2. **Every input has an answer.** Resolution layers from most general to most specific:
   - letters (always defined for every facet, §2.1-2.2);
   - then words (§3);
   - then per-skill readings (§3.2);
   - then forms (§5).
   A missing entry falls through to the layer below, never to nothing.
3. **Fixed order.**
   - Facets resolve in Call, Course, Contact, Wake order.
   - Within a facet: multipliers multiply, flat amounts add, grants union.
   - Flaws apply after words.
   - Caps apply last.
4. **Caps** (data, `runes.json "caps"`), applied to the resolved skill:
   - cost ≥ 40% of base and ≥ 1;
   - damage and effect ×0.4-×2.5 of base from runes;
   - projectile copies ≤ 3;
   - bounces ≤ 3;
   - durations ≤ 2.5x;
   - shove ≤ 10 m;
   - a skill can never trigger itself: Echo, Return and Multiplicity have depth 1.
5. **No dead writes, no soft-locks.** A rune that has nothing to act on (Far in a skill with no distance) falls back to
   its house's raw effect, as constructs do now (`fallback`). A fractured skill can always be scoured.
6. **Tests.**
   - **Exhaustive:** every letter and every word in every facet of all 40 skills: resolve, cast in a test world, check
     the invariants (caps held, no script errors, essence and reflux sane, preview text equals the applied numbers).
   - **Fuzzed:** 100,000 random cages a run, seeded and repeatable.
   - **Forms:** every form settles from its listed pattern and from no shorter one.
   All of these join the self-test.
7. **Data validated on load** (build plan, Phase 2): every word's spelling uses real letters; every form names real
   words and facets; every flaw names a real conflict; every effect key is one the resolver knows.
8. **Saves.** A skill's state gains `cage` (letters per facet, in write order) and `marks`.
   - Existing `bound` constructs migrate: each old concept becomes its word in its home facet (Acceleration → Course,
     Piercing → Course, Compression → Course, Tension → Call, Reach → Course, Stillness → Wake).
   - Existing characters keep their numbers to within a few percent.

---
## 11. How it fits what exists

| System | Change |
|---|---|
| **Constructs** (`constructs.json`) | concepts become letters (vestiges) and words (remnants up). Wild constructs carry them; the Netherecho loop is unchanged. The six concepts become six words |
| **Skills** (design/05) | unchanged behaviours; the 80 concept lines become per-skill readings |
| **Skill tree** (design/08) | unchanged. Training gives you skills; runes shape them |
| **Crafting** (design/11) | Auragraphy makes marks and rune ink. A runesetter station scours. Pattern books carry forms |
| **Items** (design/06 §6.2) | later, optionally: item runes ("Keen", "Venting") respelled in the same alphabet, so one runeology reads both |
| **Talents** (design/04) | hooks only: talent letters (§8) |
| **Tempering, spirit abilities** | not in scope. Spirit abilities may later get a fifth facet, **Price** [C: they always carry a price] |

---
## 12. Build steps

| Step | What | Size | Done when |
|---|---|---|---|
| **R1** | `runes.json` (16 letters, home facets, letter effects, the six old concepts as words, caps); `Runes.resolve`; save migration from `bound` | M | every existing skill resolves to today's numbers within 5%; exhaustive letter test passes |
| **R2** | the cage plate in the ethercosm; setting letters from vestiges into chosen facets; live preview at Basic | M | click test sets a letter and the skill changes; screenshots looked at |
| **R3** | the lexicon (the first ~25 words), remnants carry words, dissonance and the nine flaws, slips | L | exhaustive word test and fuzz pass; every flaw visible in a shot |
| **R4** | per-skill readings for the 15 starter skills (design/05's lines), the first dozen forms, the runepedia | L | every form settles from its pattern and from no shorter one |
| **R5** | marks (Auragraphy recipes), the runesetter (scour, severing elixir) | M | scour and sever round-trip through a save |
| **R6** | runeology levels and where they are taught, dialects, the soul's native letters | M | the preview hides exactly what the level says |

R1-R3 make it playable. R4 makes it surprising. It sits in build plan Phase 3 (systems), in place of design/05's
"per-skill concept rules" line, and replaces how constructs bind.

---
## 13. Questions for Brent

1. **Is the shape right?** Letters → words → forms, four facets, written into the chain as it grows.
2. **Permanence.** Only the newest rune can be scoured, at a stage's cost; a severing elixir resets the whole skill.
   Too harsh, or right for "an irreversible mistake"?
3. **Flaws never hurt the caster.** Keep it that way, or allow one wounding flaw for the truly malformed?
4. **Where letters come from.** Constructs only (as pitched), or can a trainer also teach you to write a letter
   without one?
5. **The soul's native letters** (§8): in or out?
6. **Canon check.** design/01 says Brent holds the ch230 rune material. Is there anything there about how runes
   combine, what positions are or how a skill goes wrong that this should match? If you'd like, I can read the
   chapter in the browser pane and take paraphrased notes only, as with the other research notes.
