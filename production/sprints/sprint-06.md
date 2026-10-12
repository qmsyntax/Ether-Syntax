# Sprint 06 — weapon slot, the Netherecho, art pass 2

Asked for by Brent 2026-10-11: "lets do the weapon slot then the netherecho, have the agent do another pass on the
art making it higher res if possible." Two playtest bugs arrived mid-sprint and were fixed in it.

## Part A — weapon slot
Done and committed earlier in the sprint (`ae4a285`): four weapons, per-item selling, a lost arm disarms.

## Part B — the Netherecho

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-1 | `Netherecho` node per level: wisps and wild constructs seeded per chamber (and four sites in the arena); invisible from the waking world | selftest | Done |
| S06-2 | Projecting (key N, rebindable): only in the field and out of combat; the body sits, meditates and takes no orders; the camera follows the soul | selftest, `shots/ui-nether.png` | Done |
| S06-3 | The projection: 12 hp, fast, leashed to the body (10 m + 3 per star), a plain soul strike, same click / WASD controls as the body | selftest | Done |
| S06-4 | Wisps gathered by touch: water wisps grow the star and refill essence, plain ones refill a little | selftest | Done |
| S06-5 | Wild constructs (vestige, rare remnant; six concepts): some attack on sight, some are docile and may snap; beaten down they are subdued and added to the constructs you can bind. Enemies no longer drop constructs - this is the only source | selftest | Done |
| S06-6 | Ways back: N, walking onto the body, the body being hurt (pain drags you back). A destroyed projection kills the character through the normal death path (debt, or permadeath in hardcore) | selftest (signal + exit); the kill itself is untested | Done |
| S06-7 | HUD: violet veil, projection hp and tether panel, construct health bars and target frame; world goes dark violet, living enemies and loose loot are hidden | `shots/ui-nether.png` | Done |

Canon vs ours: projecting from a meditating body, range growing with stars, gathering, and death of the projection
being death are from the books (design/01 LAW 5). [B] constructs are subdued not killed, want nothing, and the place
has no tiers. [MODEL] every number in `balance.json` "nether" and `constructs.json` "wild", docile constructs that
snap, pain pulling the soul back, walking onto the body to return.

Known gaps: projection, wisps and constructs are placeholder glowing shapes until art pass 2 lands. Enemies that
spawn while you are out are not hidden. Nothing can attack the body yet except a wall you triggered before sitting,
so the "defenceless body" risk is mostly theoretical in this build.

## Part C — playtest fixes (Brent 2026-10-11)

| # | Report | Fix | Evidence |
|---|--------|-----|----------|
| S06-8 | "my essence got above 100 at star 1" (238 at 59%) | `stars.full_tank` 400 -> 100, so a full star is 99. The baby star now starts at 20% (was 5%) so the opening tank is still 20 essence and can pay for one ability | selftest: baby star, growth, "one star never holds more than 100" |
| S06-9 | "I can also meditate while running around which feels like cheating" (click-to-move kept walking while M was held) | Holding meditate roots you at once (move goal, attack and pickup targets dropped) and nothing is gathered until you have been still for `meditation.settle_s` (0.8 s) | selftest: 5 checks |

## Part D — art passes 2 and 3 (sub-agent; integration in the main session)

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-12 | Pass 2: higher-detail meshes (`MeshKit`), four weapon models, projection, wisps, and a construct model per tier and concept | `shots/art-weapons.png`, `art-nether.png` | Done (sub-agent) |
| S06-13 | Pass 3 (Brent: "too cartoonish"): realistic proportions, desaturated worn materials, one accent per character, dry scrub, colder nether models. Tone taken from the published covers viewed as thumbnails - notes only, no images kept, no canon character or costume recreated | `shots/art-close.png`, `art-preview.png` | Done (sub-agent) |
| S06-14 | Equipped weapon shown in the model's hand; Netherecho uses the real models; bare-earth floors, dark slate walls, filmic tonemap, SSAO, light fog, lower warm sun | selftest (models), `shots/ui-hud.png`, `ui-nether.png` | Done |

Rough edges (agent's report): the realistic player is thin at game zoom, so the lost arm reads less strongly; the
brute is still rounded; bloom is heavy on the hit flash. Frame rate with a full wall of enemies and all animation
in motion are unverified.

Verified (Part B, at its commit): self-test 146/146, smoke run, three bots, both UI click tests, `ui-nether.png` and `ui-hud.png` looked at.
Not verified: anything by hand - how the Netherecho plays, whether 12 hp is too fragile, whether the settle time
feels right, and the ability costs against a 99-essence star (costs were tuned against a 400 tank).

## Part E — save slots and a starting purse (Brent 2026-10-11)

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-10 | Five manual save slots beside the autosave. Town: "Save / load" (save here / overwrite / load). Title: "Load a saved character" when any slot is filled. Loading a slot puts that character in town | selftest (paths, description), `shots/ui-saves.png`, `ui-town.png` | Done |
| S06-11 | A new character starts with $10,000 (`town.starting_money`) so later content can be reached quickly. A testing convenience, not a balance decision | selftest | Done |

Verified in a clean copy of the last commit plus these files (the art agent had the working tree mid-edit):
self-test 149/149, smoke, three bots, UI click test. Not verified: pressing Save here / Overwrite / Load with a mouse.
Saving is town-only - there is no mid-passage save.

## Part F — character creation (Brent 2026-10-11: "feel a lot like BG3 ... naming, character design (look), gender ... then the prime selection")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-15 | Four-step creator replacing the talent card grid: Origin (name with random pool, identity, body type), Appearance, Prime, Embark (summary, hardcore, Begin); draggable 3D turntable of the character | `shots/ui-create-1..4.png`, `creation_probe` (13 checks) | Done |
| S06-16 | Customisable player model: 4 body types, 8 skin tones, 6 faces, 8 hair styles, 8 hair colours, headband on/off, 8 coats, 6 accents | `shots/art-looks.png` | Done (sub-agent) |
| S06-17 | Name, identity, look and affinities live on the character, are saved, and older saves load with defaults; name on the HUD plate and in the save list | selftest (character: 15 checks) | Done |
| S06-18 | Affinity plumbing: `affinities.json`, a prime carries affinities, the character stores them, the creator shows them. Only water is defined, so every prime carries water | selftest | Done - other affinities are NOT built |

Identity and body type are cosmetic: no stat differs. All names and option labels are ours.

Verified: self-test 168/168, smoke, three bots, both inventory click tests, creation click test, four creator
screenshots and the looks sheet inspected. Not verified: the creator by hand; every look combination; body types
other than the default in live play; hair styles "undercut" and "swept" are weak close up (agent's report).
Open with Brent: which affinities to build next, fixed per prime or chosen, one or two at the start.

## Part G — affinities (Brent 2026-10-11: "go with your recommendations on the affinities")

Rulings recorded [B]: fire, earth, wind and lightning join water; affinities are fixed per prime; most primes carry
one, a couple carry two.

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-19 | Five affinities, each with a colour, a description and a three-ability kit (ranged, strike, movement): 12 new abilities, all names and verses ours | selftest (affinities) | Done |
| S06-20 | The six playable primes carry fixed affinities: 1% Lifesteal water, Tenth Strike lightning, Grudge fire, Debt of Pain earth, Glass Hour wind + lightning, Furnace Gut fire + earth. A character starts with its affinities' kits on the bar (a dual prime fills all six slots) | selftest, `shots/ui-create-3.png` | Done |
| S06-21 | Reflux per affinity: each heats, sheds and locks on its own; one ring per affinity on the essence orb; Furnace Gut vents the affinity that capped | selftest, `shots/ui-hud-dual.png` | Done |
| S06-22 | An ability can only be cast with its affinity; ability icons, projectiles and tooltips take the affinity's colour | selftest, screenshots | Done |
| S06-23 | Netherecho wisps carry an affinity: your own grow the star, foreign ones will not come to you, plain ether still refills a little | selftest | Done |

Limits, stated plainly: the new abilities reuse the three existing behaviours (projectile, melee burst, dash) with
different numbers and colours - no affinity has a mechanic of its own yet (no burning, no chaining, no knockback).
They share three icons, tinted. Numbers are first guesses and nothing is balanced. The other 34 talents in the
roster have no affinity list and would default to water. Characters saved before this keep water.

Verified: self-test 186/186, smoke, three bots, both inventory click tests, creation click test; `ui-hud-dual.png`
and `ui-create-3.png` inspected. Not verified: any new ability by hand.

## Part H — rolled primes (Brent 2026-10-11, correcting Part G)

Brent: affinities lead to which skills you can learn and are often unrelated to the prime; creation should roll
three primes, then a number of affinity slots each (max 3; 1 common, 2 rare, 3 "VERY VERY rare"), then fill them at
random. This replaces S06-20's fixed affinity per prime.

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-24 | `PrimeRoll`: three different talents off a weighted table; slots rolled 87.5 / 12 / 0.5 %; each slot a random, non-repeating affinity | selftest (20,000 rolls: distribution, no repeats, every talent seen with every affinity) | Done |
| S06-25 | Creator prime step shows the three offers with their affinities and a rarity line; "Ask for three others" rerolls (3 allowed, a testing knob in `balance.json`) | `shots/ui-create-3.png`, `creation_probe` (16 checks) | Done |
| S06-26 | Affinities live on the character, not the talent (`set_affinities`); three affinities give nine skills, six on the bar | selftest | Done |
| S06-27 | Non-binary identity removed for now | - | Done |

Not done: the female body - "the female setting does nothing" is true, identity is still cosmetic text. It needs a
model change and goes with art pass 4. Starter kits per affinity are still our stand-in for "skills you can learn";
there is no way to learn a further skill yet.

Verified: self-test 191/191, smoke, three bots, both inventory click tests, creation click test, `ui-create-3.png`.
