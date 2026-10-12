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

## Part D — art pass 2
Sub-agent still running when Part B was committed; integration (weapons in hand, projection / wisp / construct
models) follows in its own commit.

Verified: self-test 146/146, smoke run, three bots, both UI click tests, `ui-nether.png` and `ui-hud.png` looked at.
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
