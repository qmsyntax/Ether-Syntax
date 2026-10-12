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

## Part I — playtest fixes (Brent 2026-10-11, second round)

| # | Report | Finding / change | Evidence |
|---|--------|------------------|----------|
| S06-28 | "Ability 2 on 1% lifesteal on multiple enemies is not granting me the lifesteal it should" | Not a code fault: measured 1.8 health back per target from a 180-damage Tsunami Strike (1%), on every target. The strike's own 6 self-harm outweighs it until four targets are hit, and nothing on screen showed the heal. Added a green "+N" number for health returned, summed per swing. No balance number changed | selftest: 1 target and 3 targets pay exactly 1% each |
| S06-29 | "Vestiges should be labeled as to what they are in the netherecho" | Every construct shows its name above it ("Vestige of Tension"); remnants in gold | `shots/ui-nether.png` |
| S06-30 | "Cant pick up this one... looks like a bug" (a pale wisp beside the projection) | Most likely a wisp of an affinity the character does not hold - by rule those cannot be gathered, but nothing said so after the first touch. Wisps near the projection are now labelled ("water wisp", "lightning wisp - not yours", "ether") and the refusal message repeats while you keep trying. Not reproduced as an actual pickup fault | `shots/ui-nether.png` |
| S06-31 | "We should be given a preview of what will happen to a skill if I bind the vestige" | The ethercosm lists, under each bind button, every number that would move (stage, damage, bolt speed, range, reach, dash, self-harm, cost, reflux), before -> after, green or red, plus the success chance | selftest (7 checks, incl. the bind then matching the preview), `shots/ui-ethercosm.png` |

Verified: self-test 200/200, smoke, three bots, inventory and creation click tests; both screenshots inspected.
Not verified: the green heal number in live play; whether the wisp in Brent's screenshot really was a foreign one.

## Part J — no default self-harm; tempering techniques (Brent 2026-10-11)

Brent: "why is tsunami strike doing self harm? Thats a book artifact from a very specific combination of concepts
and skills the MC put together. It should not by default do self harm. We also need tempering techniques."

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-32 | Self-harm removed from all five strike abilities and from the tension concept; `self_harm` stays as an optional key nothing uses. Verses and the fire description reworded to match | selftest | Done |
| S06-33 | Tempering techniques: six of our own (one plain, one per affinity), each with a stage, a progress bar and one effect - more superficial or structural health, faster reflux shedding, less damage taken, faster movement, faster strikes. All active at once | selftest (tempering: 19 checks) | Done |
| S06-34 | Training: a session in the town's tempering yard costs structural health (8, +4 per stage) and adds progress (25%, x0.7 per stage); refused if it would leave less than 1 structural; stage cap stars + 1 | selftest, `shots/ui-temper.png` | Done |
| S06-35 | A character starts knowing the plain technique and one per affinity held; tempering is saved; older saves start at stage 0 | selftest | Done |

Canon vs ours: [C] techniques are passive, grouped by affinity, have a stage and a progress bar, and work by
harming the body so it adapts; one speeds reflux shedding. [B] all run at once and simply make the body tougher.
[I] cap of stars + 1. [MODEL] every technique, name, effect and number here; sessions; the yard; the starting set.
None of the books' named techniques is used.

Not done: learning further techniques (scrolls), training anywhere but town, "using a technique your body is not
tempered for injures you" [C], and the clinic's tempering aid.

Verified: self-test 220/220, smoke, three bots, inventory and creation click tests; `ui-temper.png` inspected.
Not verified: the Train button by hand, or whether the costs feel right.

## Part K — art pass 4 and the female body (Brent 2026-10-11: "Really want this to look better quality ... the female setting does nothing")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-36 | Player model rebuilt at higher fidelity: smooth lofted anatomy, a sculpted head with eyes, nose, lips and ears, fingered hands, layered hair, clothing with collar, folds, belt and buckles, per-material surface detail. About 39,000 triangles, 14 draw calls | `shots/ui-create-1.png`, `ui-create-2-face.png`, `art-looks-body.png` | Done (sub-agent) |
| S06-37 | Female body for all four body types and every face (look key `sex`); choosing Woman switches to it, and it carries into play and saves | `creation_probe` (2 new checks), `shots/ui-create-1.png` | Done |
| S06-38 | Stubble and beard are not offered on the female face; a "Face" button zooms the turntable to head and shoulders; better turntable lighting | selftest, `shots/ui-create-2-face.png` | Done |

Rough edges: eyebrows alias badly at face zoom and faces are still stylised; upper arms a little tubular; gauntlet
fingers claw-like; male and female differ clearly side by side but subtly alone on the Heavy body. Enemies were
not touched this pass. At gameplay zoom almost none of the new detail is visible.

The art agent reported the creator click test failing during its run; it passes now (re-run three times after
merging main) and the cause was not found - most likely it ran while files were mid-edit.

Verified: self-test 223/223 (every sex x body builds; slowest first build of a look 103 ms), smoke, three bots,
inventory and creation click tests; creator screenshots inspected. Not verified: by hand; animation in motion;
weapons and the lost arm on the female and non-default bodies.

## Part L — one health bar plus wounds; slower ascension (Brent 2026-10-11)

Brent: the three health buckets never made a noticeable difference; wounds, each with "an invisible HP hole that
needs to be filled with healing that is not visible in the HP bar"; lifesteal "should go toward the sink first if
its not dynamic. If it is dynamic, it should go for the health bar up to 50% then to the sink"; the second star
"only took about 10 mins ... it should be after like 2 hours".

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-39 | `Body` rebuilt: one bar; wounds that cut its ceiling and carry a hidden sink; fill, merge, close, cap, save, and reading of old three-layer saves | selftest (body: 15 checks) | Done |
| S06-40 | What wounds you: one blow worth a fifth of your full health, or one that leaves you under a fifth; a failed bind; a lost arm (a wound rest cannot mend); a tempering session (a strain wound) | selftest | Done |
| S06-41 | What mends: the bar refills at rest, never a wound; a night closes 15 points of sink; the healer works on the oldest wound (10 points a visit) or patches the bar; talent healing in Brent's order for Supreme and Dynamic | selftest (natural healing, healer, arm, death) | Done |
| S06-42 | HUD: a single-colour orb showing the whole body, one mark per wound, a tooltip naming each wound and how it is doing in words; town ledger and tempering yard reworded | `shots/ui-hud-low.png`, `ui-temper.png` | Done |
| S06-43 | Tempering on the new model: a session leaves a strain wound instead of structural damage; Callus adds health; Bedrock Bones makes wounds shallower | selftest | Done |
| S06-44 | Ascension slowed about twelvefold (aura threshold 100 -> 1200, star growth per kill 0.5 -> 0.04, meditating 0.05 -> 0.005, attuned wisp 1.5 -> 0.12). Skill progress left fast for testing | selftest (a guard on the numbers only) | Done - UNMEASURED |

Found on the way: ascending called a body function the rebuild had removed, so it would have stopped half-way
(star added, body not remade, reflux not cleared). The old test did not notice. Fixed, and the test now checks the
body after ascension.

Not verified: any of it by hand. The two-hour target is arithmetic from one data point (ten minutes), not a
measurement - it needs a real play session. Whether a fifth of your health is the right size for a wounding blow
is a guess. Enemies still only walk up and swing, so wounds will mostly come from brutes and commanders.

## Part M — biomes (Brent 2026-10-11: "snow levels, dungeons, mountain levels, cities ... swamps ... a lot of assets")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-45 | Six biome kits - scrubland, dungeon, snow, swamp, mountain, city - each with a patterned floor, walls, a gate in its own language, 10-13 props in three variants, and its own light and fog. One draw call per prop | `shots/biome-*.png`, `props-*.png` | Done (sub-agent) |
| S06-46 | Levels are built from a biome: the passage rolls one of six per delve, the arena one of four, the town is the city. Floors, walls and gates come from the kit; colliders are separate | six `shots/game-*.png`, bots | Done |
| S06-47 | Chamber gates open and shut in place of the red box; decorative props scattered per chamber; cuttable props (crates, barrels, reeds, scrub) stand in for grass and bushes outside scrubland, and only plant-like ones count as living | bots, screenshots | Done |
| S06-48 | `--biome=<id>` forces a biome for tests; `--shot-ui=biome-<id>` screenshots the passage in it | used below | Done |

Found on the way: the first mountain bot run stalled at wall 1. Mountain has the largest blocking props, and two of
them could form a pocket that trapped a fighter (nothing in this game can path around an obstacle). Blocking props
are now set against a side wall and kept apart; mountain then passed three runs in a row. The dungeon was so dark
from the game camera that the player disappeared; its ambient light is raised in data.

Rough edges: the dungeon is still moody rather than clear; gate lintels hide a little floor behind them; the city
facade has no building depth; scatter is random, not composed; snow has nothing to cut down. Enemies still walk
in straight lines, so props are scenery, not cover.

Verified: self-test 250/250; `--bot-dungeon` in all six biomes; `--bot-full` in dungeon, city and snow; `--bot-die`;
smoke; inventory and creation click tests; dungeon, snow and mountain screenshots inspected from the game camera.
Not verified: any of it by hand; frame rate in play; the arena and town in their new look beyond one screenshot;
gate animation in motion; swamp, city and scrubland were not inspected after integration.

## Part N — crash on death in the Netherecho (Brent 2026-10-12)

| # | Report | Finding / change | Evidence |
|---|--------|------------------|----------|
| S06-49 | "when I died in netherecho the game crashed" | A construct's blow destroyed the projection in the middle of the echo's own update; the update then read the position of a projection that no longer existed. In an editor run that script error halts the game. The update now stops once the trip is over | selftest; `nether_death_probe` standard and hardcore; both fail with the fix removed |
| S06-50 | (found while fixing) tests passed over script errors | `ErrorCatcher`: the self-test and the death probe now fail on any script error. The same blind spot hid the half-finished ascension on 2026-10-11 | proven by removing the fix |

Why the earlier test missed it: it destroyed the projection by calling its damage function directly, not through a
construct's attack during the update - the one path that matters in play.

Not verified: by hand. The death probe covers the passage; dying in the arena's echo goes through the same code
but was not run separately.

## Part O — skills step 1: water versus lightning (design/05, approved by Brent 2026-10-12)

Brent: "go with your recommendations on both docs, start building". This is step 1 of design/05's build order:
make two affinities play differently in the same fight. His complaint was that lightning "was basically the same
as water".

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-51 | One hit payload for every skill (`apply_hit`): damage, status, shove, Live marks, interrupt - defined in data per skill | selftest | Done |
| S06-52 | Statuses on enemies (Soaked, Live, stunned), interrupts, and how far each enemy kind can be shoved | selftest | Done |
| S06-53 | Water - shove and Crush. Water Bolt soaks and knocks back; Breaker (was Tsunami Strike) throws a 120-degree arc of enemies 4 m; Sluice Step (was Hydraulic Flex) dashes through enemies and soaks them. A shove that ends against a wall, a block or another body crushes: 15 + 10 per metre it had left, half to a body it hit | selftest (shove distance by weight and Soaked, crush on wall and on body, each skill) | Done |
| S06-54 | Lightning - marks and Overload. Arc Lash is an instant 9 m line (1 mark); Thunderclap Palm hits one enemy in reach (2 marks, interrupts); Stepped Leader puts you 6 m away at once and marks what you land beside. The third mark: 150 damage, 1 s stun, a 60-damage arc to every other marked enemy within 12 m, and 12 reflux grounded. Lightning reflux does not shed in a fight | selftest | Done |
| S06-55 | Cross rule 1: a lightning hit on a Soaked enemy marks the other Soaked enemies within 4 m | selftest | Done |
| S06-56 | Approved rulings applied: the two water skills renamed (they carried the books' names; ids kept so saves load); running above 80 reflux no longer damages you - skills take longer to recover from instead | selftest | Done |
| S06-57 | Marks, Soaked and stun drawn over enemies; each skill's one-line rule in its tooltip and in the ethercosm; three blocks in the arena to crush against | `shots/ui-skills.png` | Done |

Found on the way, all by the new tests:
- Thunderclap Palm, pointed at an enemy out of reach, hit a different, nearer enemy instead of refusing. If you
  point at someone, the skill now goes for them or does not fire (and costs nothing).
- A shoved enemy travelled about 4 m on a 2.25 m budget: the engine function used to move it chooses its own time
  step outside a physics frame. Shoves now move an exact distance.
- Sluice Step could jump clean over an enemy on a long step and fail to soak it (one run in three). The dash now
  checks the whole stretch it covered. Eight clean runs afterwards.

Rough edges: the arena blocks are plain cubes. Fire, earth and wind are unchanged - still the three plain
behaviours with different numbers - until step 3. Enemies do not yet have poise, so "interrupt" only breaks a
wind-up (step 2). Skill costs dropped (Water Bolt 12 -> 8) to fit a 20-essence start; untested for feel.

Verified: self-test 296/296, eight runs in a row; three bots; Netherecho death test; inventory and creation click
tests; `ui-skills.png` inspected. Not verified: any of it by hand - whether water and lightning now FEEL different
is the whole point of this step and only Brent can say. Blink and beam aim with the mouse, which no test exercises.

## Part P — equipment step 1: a coat and a sling (design/06, approved by Brent 2026-10-12)

Step 1 of design/06's build order: put armour and a no-essence ranged attack in the player's hands before anything
is built on them.

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-58 | Two new slots, ranged and body; a new character starts wearing a Patched Coat and carrying a Cord Sling; saves from before load with the slots empty | selftest | Done |
| S06-59 | Armour: the percent a worn piece takes off each hit, capped at 30. Applied to the blow before talents see it | selftest ("20 through 5 armour lands as 19"; cap; a delayed hit) | Done |
| S06-60 | Shooting: hold Shift and the strike button fires the sling at the cursor (at the enemy under it, if any) - 45 damage every 0.8 s out to 12 m, for no essence or reflux. In the stance you do not walk to clicks or close to strike, you move at 70% speed, and a ring shows the range | selftest (damage, interval, range, first enemy in path, no ranged weapon, mid-skill, arm lost) | Done |
| S06-61 | Four items: Patched Coat and Cord Sling (starting), Padded Jack (merchant, 3 armour and faster reflux shedding), Husk-Hide Jack (brute drop, 5 armour) | selftest | Done |
| S06-62 | Inventory shows the two new slots with their own icons and hints; item text says what armour and a sling do; Shift is in the controls menu and the hint line | `shots/ui-inventory.png` | Done |

Found on the way: a talent that swallows a hit and delivers it later (Debt of Pain) skipped armour entirely, and
skipped the fire tempering technique's damage reduction the same way - a gap that already existed. Armour and
tempering now come off the blow before any talent sees it.

Left out on purpose: the draft gives the Husk-Hide Jack 4 wound resistance; the game does not read that stat until
step 2, so it is not on the live item. No ammunition, draw time or hand-change delay yet (step 4). The six-panel
slot list is full - twelve slots need the paper doll (step 2).

Verified: self-test 318/318, four runs; three bots; Netherecho death test; both inventory click tests; creation
click test; inventory screenshot inspected. Not verified: anything driven by the real mouse and keyboard - the
Shift stance, aiming at the cursor, holding to keep firing, the range ring. Whether Shift + click feels natural
beside click-to-attack is the question this step exists to answer, and only Brent can.

## Part Q — skills step 2: the combat rules (design/05 section 6; Brent 2026-10-12: "go with the combat rules next")

Aimed at his complaint that combat was "run around and dodge in and out ... landing aoe blows on them as they
group".

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-63 | Enemies turn at 240 degrees a second, so they have a back. A hit on the back arc does 30% more | selftest | Done |
| S06-64 | Poise and stagger: hits remove poise (a bare strike 20, a skill 15); at zero the enemy is Staggered for 1.5 s - it cannot act and takes 30% more. Poise returns after 3 s unhit. A thin gold bar shows it | selftest, `shots/ui-combat.png` | Done |
| S06-65 | The Opening: a bare strike on a Staggered enemy does double. Working it off: each bare strike that lands sheds 1 reflux from your hottest affinity | selftest | Done |
| S06-66 | Interrupts: an attack flagged interruptible shows white; an interrupting skill (Thunderclap Palm) or a poise break cancels it and staggers its owner | selftest | Done |
| S06-67 | The slot ring: at most six melee enemies stand in striking range; the rest wait a few metres out | selftest (ten skirmishers) | Done |
| S06-68 | Hide-Bound Brute reworked: 30% less damage from the front, and one slow slam - a 3 m circle drawn on the ground for 1.2 s, 45 damage, interruptible. It does not track you once committed; a miss leaves it stuck for 1.5 s | selftest | Done |
| S06-69 | Rampart Archer (new): holds 9-12 m, aims along a line for 1 s that leads where you are going and locks 0.3 s before release, then looses for 18. Walls and blocks stop the shot. Backs away and cannot attack inside 4 m | selftest | Done |
| S06-70 | Harrier (new): circles at 7 m and does nothing; when you run from the pack for 1.5 s it crouches and leaps 8 m for 20 and a stagger. Hit it in the crouch or the air and it is knocked down for 2 s; a miss leaves it stuck 1 s. With no pack left it attacks anyway | selftest | Done |
| S06-71 | You have poise too: a heavy blow staggers you for 0.4 s (no moving, striking or casting). A movement skill commits you for 0.25 s after it ends, and a second one inside 2.5 s costs double essence and reflux | selftest | Done |
| S06-72 | Passage walls follow recipes: archers from wall 2, a harrier from wall 4; arena waves add them too. Archers start at the back of the chamber | selftest (no wall introduces more than one new kind), bots | Done |
| S06-73 | Doorway routing (`Route`): enemies and the bot walk to the gap in a dividing wall instead of at the wall | selftest, 12 full-passage bot runs | Done |

Found on the way:
- THE BIG ONE: the full ten-wall bot run stalled about one time in five. The diagnostics showed the bot standing
  against a dividing wall, 4.9 m off-centre, pushing straight at two archers in the next chamber. Nothing in this
  game pathfinds; it never mattered while every enemy charged the player, and it started to matter the moment
  pouncers circled and archers held range. Enemies had the same blindness. Fixed with doorway routing; twelve
  clean full runs afterwards (a 7% chance if nothing had changed, so strong evidence, not proof).
- An enemy with no valid target never recovered poise (the recovery sat after an early return).
- The brute's new frontal armour broke nine arithmetic tests that used a brute as their dummy target.

Rough edges: the archer and the harrier have no models - they are plain figures. The harrier's pounce rule can
feel arbitrary until you learn it; there is no on-screen hint. Poise numbers and the six-slot ring are untuned.
Fire, earth and wind still have no interrupting skill or signature mechanic (step 3). Pavise Bearer, Censer-Bearer,
War Drummer and the phased Wall Commander are step 4. Enemies can still strike through a dividing wall at very
close range (hits are distance checks).

Verified: self-test 383/383, four runs; the full-passage bot twelve times; the gate bot in all six biomes; the death
bot; the Netherecho death test in both modes; inventory and creation click tests; `ui-combat.png` inspected.
Not verified: any of it by hand. Whether fights now feel less like "kite and area-hit the clump" is the point of the
step and is Brent's call. Arena waves with the new enemies were not run by a bot.

## Part R — skills step 3a: fire (design/05 2.2 and 3.2; Brent 2026-10-12: "go with that order")

Step 3 is the largest so far, so it is built and merged one affinity at a time. Fire first.

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-74 | Heat: fire reflux multiplies fire damage (+30% at 50, +48% at 80) and sheds at half speed in a fight. Counted at the moment of impact | selftest | Done |
| S06-75 | Alight: up to five stacks, 8 damage a second each for 5 s, dealt in the caster's name (so it pays talents and scales with heat). One stack jumps to an enemy that stands within 1.2 m for a second, and to the nearest such enemy when the burning one dies | selftest | Done |
| S06-76 | Cinder Spit: a quick cheap bolt, 55 and one Alight, half the recovery of other bolts | selftest | Done |
| S06-77 | Kiln Fist: one enemy in reach, three strikes' worth, two Alight, interrupts. On a burning enemy every stack is spent for +40 and the blow bursts 2 m, lighting those beside it | selftest | Done |
| S06-78 | Flashover: a 4.2 m dash that leaves a strip of flame for 3 s (one Alight a second to anything in it) and does not carry you through enemies | selftest | Done |
| S06-79 | HUD: the reflux ring warms with heat, "fire +N%" above the essence orb, flames over burning enemies; the stale "burning" label at 80 reflux now reads "slow to recover" | `shots/ui-fire.png` | Done |

Found on the way: the player's dash travelled 23 m on a 4.2 m budget in a test - the same cause as the earlier
shove bug (movement by velocity, with the engine choosing the time step). Dashes now cover an exact distance, which
also holds on a frame hitch in real play. The first fire screenshot hid the heat readout behind a tooltip I had
forced on; it was re-shot.

Rough edges: the flame trail is a flat orange strip. Backdraft (the skill that spends heat on purpose) is one of
the later five. Furnace Gut still vents reflux at the cap and wants a second look now that fire runs on heat.
Kiln Fist's 0.2 s wind-up is not built - it lands at once.

Verified: self-test 416/416, three runs; gate, death and four full-passage bot runs; Netherecho death test; inventory
and creation click tests; `ui-fire.png` inspected. Not verified: by hand - whether riding heat near the lock
actually feels like a gamble.

## Part S — enemy art: archer and harrier (Brent 2026-10-12: "go with that order, start the art agent")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-80 | Rampart Archer model: hooded and veiled, a bow as tall as itself, a quiver high on the back (the tell from behind). Its wind-up is the draw: side-on, bow arm out, string back | `shots/art-enemies-new.png` | Done (sub-agent) |
| S06-81 | Harrier model: a long grey body carried level on bent legs, clawed arms, a bone beak-mask and a red crest. Its wind-up is a crouch that drops it 0.3 m; staggered, it rolls onto its side | `shots/art-enemies-new.png` | Done (sub-agent) |
| S06-82 | Backs: the brute's iron is on its chest and gut only - the back is bare scarred hide, where the opening is; the grunt has a mask-tie on the back of its hood | `shots/art-enemies-back.png` | Done (sub-agent) |
| S06-83 | A staggered or stunned enemy slumps (`ModelRig.set_staggered`), driven from `enemy.gd` | wired; not seen in a still | Done - unseen |

Not done: the fidelity rebuild of grunt, brute and commander. They were only smoothed (about 1.75x the triangles
on round forms) and are still the pass-3 builds, not lofted anatomy like the player.

The sub-agent also found why it kept reporting the creation click test as failing: it ran it headless, where
synthetic clicks do not land. Run in a window it passes. Recorded in CLAUDE.md.

Rough edges (agent's report, and mine): the archer is small and dark at game zoom - the aim line picks it out more
than its shape does; its release flings the drawing arm out sideways; the harrier runs with a generic biped swing,
not a bounding gait; the staggered pose is subtle on the big enemies. The staggered pose only eases in while an
enemy is animating, so no screenshot of mine shows it.

Triangles / draw calls: grunt 5,661 / 11, brute 14,364 / 11, commander 8,747 / 14, archer 8,672 / 15, harrier
5,396 / 12. Twelve enemies plus the player measured 0.46 ms CPU + 0.38 ms GPU of render time at 1600x900.

Verified: self-test 416/416; gate, death and three full-passage bot runs; Netherecho death test; inventory and
creation click tests; `art-enemies-new.png` and the combat screen inspected. Not verified: any of it in motion.

## Part T — skills step 3b: wind (design/05 2.4 and 3.4; Brent 2026-10-12: "keep going with wind then earth")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-84 | Slipstream: ten pips, one for every 1.5 m actually travelled (walking or dashing); after half a second standing they drain one every half second. Five or more: 10% faster on your feet | selftest | Done |
| S06-85 | Wind reflux sheds three times as fast while you move and not at all while you stand, in a fight | selftest | Done |
| S06-86 | Lee: a wind hit on an enemy's back does 50% more, on top of the ordinary rear bonus | selftest | Done |
| S06-87 | Cutting Gust: a 12 m gust that passes through every enemy in its line; 45, and spends up to 3 pips for +15 each | selftest | Done |
| S06-88 | Tailwind: the longest dash (6.6 m), +3 pips, and the only one with no recovery after it. It does not carry you through enemies | selftest | Done |
| S06-89 | Crosscut (replaces Downdraft in the kit): one enemy within 7 m - you cut through and stop 2 m behind it; always counts as a hit from behind; spends every pip for +10% each. With a wall behind the target you strike but stay on your side | selftest | Done |
| S06-90 | Aloft: a light enemy is thrown up for 1.2 s - it cannot act and takes 25% more; a heavier one loses 50 poise instead. No starter skill applies it yet | selftest | Done (rule only) |
| S06-91 | Projectiles now fly by exact distance, check the whole stretch covered, strike nearest-first and stop on walls and blocks. Before this, the player's bolts flew through walls | selftest | Done |
| S06-92 | HUD: a row of pips over the skill bar ("swift" at five), an aloft marker over enemies | `shots/ui-wind.png` | Done |

A consequence worth knowing: your own bolts no longer pass through walls or the arena blocks. That is what the
design says ("stone blocks shots - theirs and yours") and earth needs it, but it changes water and fire too.

Rough edges: no wind starter skill throws anything Aloft (that arrives with a construct or the later skills), so
the rule is tested but will not be seen in play yet. Crosscut moves you at once - there is no cutting motion.
Downdraft sits in the data unused.

Verified: self-test 452/452, three runs (five before the HUD work); gate, death and four full-passage bot runs;
Netherecho death test; inventory and creation click tests; `ui-wind.png` inspected. Not verified: by hand - and wind
is the affinity that most depends on feel: whether keeping the pips up while fighting is fun or a chore.

## Part U — skills step 3c: earth (design/05 2.3 and 3.3; Brent 2026-10-12: "keep going with wind then earth")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-93 | Wind-ups: a skill can take time to go off. It is paid for at once; you stand where you were and stay aimed where you aimed until it does. A stagger loses it | selftest | Done |
| S06-94 | Braced: through an earth wind-up you take 40% less and heavy blows do not stagger you | selftest | Done |
| S06-95 | Standing stone: a slab 3 m across, up in 0.35 s. It blocks walking and every shot - theirs and yours - for 12 s. 150 health, worn down by enemy shots. Three at a time; a fourth crumbles the oldest | selftest | Done |
| S06-96 | Whoever stands where a slab rises takes 20 and is pushed a metre off it | selftest | Done |
| S06-97 | Shatter: an earth skill that hits your stone breaks it - 80 damage and 40 poise to everything within 4 m on the far side | selftest | Done |
| S06-98 | Slingstone: 0.3 s wind-up, the slowest bolt (14 m/s, 24 m) and the heaviest (120); takes 45 poise and interrupts. Into your own stone, it shatters it | selftest | Done |
| S06-99 | Raise Slab (new, third key): a wall across your aim, 1.5 to 8 m away, short of any wall in the way. Cheapest skill in the game | selftest | Done |
| S06-100 | Landslide Blow: 0.6 s wind-up, a narrow arc (60 degrees, 3.5 m), 3.2x a strike, 80 poise - staggers a skirmisher outright, moves nobody, shatters your stone in the arc | selftest | Done |
| S06-101 | Earth's starter kit has no movement skill (Bedrock Shove waits for scrolls). Its reflux is small (0.4 per essence) and sheds at half the rate | selftest | Done |
| S06-102 | Enemies walk round the end of a slab, and a swing no longer lands through a wall or stone | selftest | Done |
| S06-103 | HUD: stone count and "braced" over the skill bar, a wind-up bar, a wall icon; the tooltip names the wind-up. (The melee-skill tooltip still said "and wounds you" - removed.) | `shots/ui-earth.png` | Done |

Changes that reach past earth: enemy swings now need a clear line to you (they used to land through thin walls);
your shots leave from your chest when something solid is right in front of you (they could start beyond a thin wall).

Rough edges: the slab is a plain grey block with rubble at its foot. Enemies get round stone by heading for its
nearer end - with two slabs side by side or a slab against a wall they can stall behind it for its 12 s, which is
arguably the point but will look dim. A brute's ground slam still reaches through stone. Nothing breaks stone on
purpose (the Sapper is a later enemy). Your own melee still reaches enemies through your own slab. The bot never
casts, so the passage runs do not exercise any of this.

Verified: self-test 509/509 (two runs; 507 three times before the last two checks were added); gate, death and four
full-passage bot runs; Netherecho death test both ways; inventory and creation click tests; `ui-earth.png`
inspected. Not verified: by hand. In particular whether 0.3 to 0.6 s of standing still feels like commitment or
like lag, and whether a wall that takes 0.45 s to become solid comes up fast enough to matter.


## Part V — archer steering and skill icons (Brent 2026-10-12: "work on the archer pathing... the icons for the skills are not right")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-104 | An archer that cannot see you looks for the nearest spot it can walk straight to and shoot from, and goes there, instead of walking into the cover | selftest (fails on the old code) | Done |
| S06-105 | An archer backing off with a wall behind it slips along the wall; boxed in on every side it stands and shoots | selftest (fails on the old code) | Done |
| S06-106 | Every skill has its own icon (17; they had shared three), centred in the slot and clear of the key and the cost | `shots/ui-icons.png`, `shots/ui-skills.png` | Done |

This is still not pathfinding: the archer only considers spots within 8 m that it can reach in one straight line.
In a maze of cover it will fall back to walking at you, as before. Brent did not say what he saw the archers do;
this fixes the two failures visible in the code (stuck against cover, pinned against a wall). `--shot-ui=icons`
draws every skill icon on one sheet.

Verified: self-test 516/516 (three runs), three full-passage bot runs, gate and death bots, click tests, both
screenshots inspected. Not verified: by hand.


## Part W — skills step 4: the rest of the enemies (design/05 6.1; Brent 2026-10-12: "keep going with skills step 4")

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S06-107 | Pavise Bearer: a shield that takes 80% off anything from the front and stops shots, even piercing ones. Slow to turn. Break its poise and the shield is down for 3 s. Its bash does 14 and throws you 2 m (not if you are Braced) | selftest | Done |
| S06-108 | Censer-Bearer: a ring on the ground at 4 m. When it dies the censer flares for 0.8 s, then every enemy inside the ring gets 40% of its health back and is frenzied (30% faster on its feet and to attack) for 6 s | selftest | Done |
| S06-109 | War Drummer: never attacks; stands 6 m behind the line. Enemies within 6 m attack 25% faster and lose a third less poise. Every 10 s it winds up a roll for 1 s (interruptible - an interrupt staggers it) that makes one skirmisher's next blow heavy | selftest | Done |
| S06-110 | Wall Commander, phase 1 (above 60%): blocks 60% from the front and answers a blocked hit with a quick swing | selftest | Done |
| S06-111 | Phase 2 (60-30%): calls three skirmishers and a drummer, once; stops blocking; adds a 6 m sweep drawn on the floor as a cone for 0.8 s, 35 damage | selftest | Done |
| S06-112 | Phase 3 (under 30%): marks a lane for 1 s, then charges 22 m down it for 60. Only a stun or a poise break stops it. If the charge ends in a wall or in standing stone it is stunned 3 s and takes half again as much | selftest | Done |
| S06-113 | The player can be shoved (an exact distance, like everything else) | selftest | Done |
| S06-114 | Wall recipes for all ten walls use the new kinds, never more than one censer or one drummer a wall; arena waves bring them in too | selftest, bot runs | Done |
| S06-115 | HUD: cone and lane telegraphs, marks for frenzied and roused; rings on the ground for the censer and the drum; each new kind has its own look (a skirmisher with a shield, a censer, a drum) | `shots/ui-enemies4.png` | Done |

Not built from step 4: cover inside the passage chambers. The bot walks straight at the nearest enemy and would
stall on it; that wants real steering first. Two Pavise Bearers "covering each other's flank" is left to chance.
Nothing turns a Pavise Bearer round except walking round it (the skill that does is in step 5).

Rough edges: the three new models are the skirmisher with one prop added, not their own bodies. A lone drummer
stands still. The commander's reinforcements appear in a ring round it with no entrance. The commander was a big
skirmisher before; it is now a much longer fight (it blocks 60% for the first 40% of its health) and nobody has
played it.

Verified: self-test 572/572 (three runs); six full-passage bot runs, gate and death bots; Netherecho death test;
inventory and creation click tests; `ui-enemies4.png` inspected. Not verified: by hand. The bot does not cast,
dodge or get hurt, so it proves these packs can be cleared and do not jam - nothing about whether they are fun
or fair.
