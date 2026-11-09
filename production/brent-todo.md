# Brent's to-do

Kept by Claude; last updated 2026-11-08 (build v0.56.0-groundwork). Tick a box by telling Claude the answer, and
Claude records the ruling in the design doc it belongs to and moves it to "Done" at the bottom. The order is the order
they unblock work in (`production/finish-plan.md`).

## 1. Play (nothing since v0.52 has had hands on it)

- [ ] **The fun gate** (in progress: Brent is playing the S:\Passage build, 2026-11-08) - a session or two on the current build: create a character, the trainer, the Stubble, the
      assault passage, the arena, a death and the corpse run, a level lock. Then a verdict: keep going as is / change
      direction / stop. Everything in the plan assumes "keep going".
- [ ] **Sidestep (v0.54)**: Space. Does the 0.32 s roll look smooth or frantic? Is 38 of 100 endurance a step right
      (two quick steps, then a pause)? Should a step drop the foe you were closing on (today it does)?
- [ ] **Level locks (v0.54)**: bind a ring with open bonds and empty places; bond the skill's own rune straight to
      ring 2. Does "bind no matter what" feel right?
- [ ] **Construct words (v0.55)**: subdue a few constructs in the Netherecho; set one as a keystone. Do the names read
      well? Does the keystone list feel usable (its last row hides behind Bind until you scroll)?
- [ ] **Watch for a twitch while running**: the tests found the shoulders and hips swing about 80 degrees for a few
      frames when the run switches between sprint and run (worst when sliding along a wall or prop). Tell Claude
      if you see it; the fix is small (a gap between the two speeds).
- [ ] **Combat fixes (v0.53)**: strikes now gather essence, starters are cheaper, reflux sheds faster, close skills
      walk you in. Does a new character feel like it can fight?

## 2. Rulings the code is waiting on

**Construct words (v0.55)**
- [ ] Should rune order change a word's *effect*, not just its name? (Friction and Lurch do the same thing today.)
- [ ] A keystone scales a word's drawbacks with its upsides (Delay's longer wind-up gets longer). Keep?
- [ ] Subduing any construct can teach a universal rune, so universal runes are easier to find than the planned
      "rarer and deeper". Gate them by tier?
- [ ] An ice word on a fire skill, for a character holding both: fit or unfit? (Fits today.)
- [ ] Should eidolons and asuras ever spawn wild? (Nothing spawns them yet.)
- [ ] Look over the word names and the 55 / 35 / 10 wild split (own affinities / universal / others).

**Seals**
- [ ] Should a fully closed word earn a bonus of its own? (Only the ring-shape traits reward filling today.)
- [ ] Is +1 bond per ring enough for the skill's own rune?
- [ ] A failed bind (the 80% roll) uses up the construct and wounds you. Keep that price?
- [ ] A cap on keystones per skill? On the ward pool?

**Combat** (`design/combat-backlog.md`)
- [ ] R2 essence motes from kills - yes / no.
- [ ] R5 healing draughts usable in a fight (bar only, never a wound's sink) - yes / no.
- [ ] Q4 a bigger first tank (20% -> 40%); your 2026-10-11 ruling set 20%.
- [ ] Movement starters' price (the review named none; unchanged).
- [ ] Should enemies put statuses on the player (Absolution and Fever Break stay simplified until they do)?
- [ ] **A lone drummer** (found 2026-11-09): a drummer with no fighter or commander within 14 m stands still and
      never comes to you. If it is behind a block you can end up with a wave you can't finish without walking
      round. Keep (it is a support, it hangs back), or should a lone drummer close in or move to where it can see you?

**Smaller ones, still open**
- [ ] Hybrid affinity midpoints; Holy / Unholy colours; talent pool weighting at creation.
- [ ] Six of the old talents' wording.
- [ ] Clicks above the horizon (today: "that way").
- [ ] Test characters in save slots; the innkeeper's confirm; saving in the field (town only today).
- [ ] **Saves (v0.56)**: starting a new character or loading another slot used to overwrite the autosave silently.
      Now the old character is kept in the first empty slot (or a `displaced` folder if all are full), with a note.
      Keep that, or go back to overwriting?
- [ ] **Saves inside a passage**: reading a rune stone, settling an ascension, the ethercosm and equipping still save
      wherever you are, which breaks "nothing is saved inside a passage". On load you are put in town, and no
      character is lost. Should those saves wait until you are back in town?

**Design questions never ruled on** (each has a recommendation; "go with your recommendations" settles a list)
- [ ] `design/10-item-catalogue-v0.md` section 16 (14 questions: bands at +5%, money x4 a star, the Loud rule, weight
      by band, armour cap, storage rings, ...). Gates every item above band 1 and every star past 2.
- [ ] `design/08` Q1-6 (skill point pace, drill, scroll prerequisites, trainers per affinity, respec, town actions).
- [ ] `design/07` section 8.2 (the passage meter, does the clock run in dungeons, a trunk in your room, herds,
      bands per region).
- [ ] `design/05` section 8 and `design/06` section 11.
- [ ] Canon for later stars: how long stars 3+ take (design/10 Q2), spirit abilities (design/02 Q29/Q30), the soul
      construct (Q17), whether skill progress carries across ascension.

## 3. Sources and set-up (downloads and new tools need your yes each time)

- [ ] **What "finished" means** - pick the ship target in `production/finish-plan.md` ("What finished means").
- [ ] **A creature source** for real beasts (today's are procedural stand-ins). Needed before region 1's zones fill up.
- [ ] **Audio**: a CC0 library (e.g. Freesound's CC0 subset) or generated. The game has no sound at all.
- [ ] **UI font** from Google Fonts (design/09 Q1).
- [ ] **Git LFS** for the big binaries (the repo is 484 MB and every model re-export adds 10-13 MB).

## Done

(moved here with the date and where the ruling was recorded)

- [x] **A Windows export** - yes (2026-11-08, "do all the work to make it safe"). Templates from the official
      4.7.2 release (checksum matched); `build\EtherSyntax.exe` is on S:\Passage from v0.56.0-groundwork on.
