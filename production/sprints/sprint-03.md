# Sprint 03 — Playtest fixes: click-to-attack, construct-gated stages, baby star

> 2026-09-23, from Brent's first proper playtest of v0.6.0 ("the gameplay is good"). Inserted ahead of the
> inventory sprint because it changes core rules that inventory and the ethercosm screen will build on.

## Stories
| # | Story | Type | Evidence | Status |
|---|-------|------|----------|--------|
| S03-1 | Base melee single-target; Diablo-style click an enemy to walk to it and strike it (hold to repeat), click ground to walk; WASD overrides; overcharge hits the clicked / hovered / nearest-in-reach target | Logic + feel | selftest (click picks target, only the clicked enemy is hit, ground click = walk goal) | Done |
| S03-2 | `constructs.json`: tier order (canon) and six concepts with stat mods (MODEL) | Config | selftest | Done |
| S03-3 | Ability bar stops at 100; `pending_tier`; `bind_construct` (tier must match, can fail and wound, irreversible); concept mods applied through `ability_stats` | Logic | selftest (8 checks) | Done |
| S03-4 | PLACEHOLDER construct source until the Netherecho: brutes 15% vestige, commanders a vestige + 35% remnant; Bind key (B) binds the first carried construct into the first ability waiting for that tier | Config / UI | smoke + bots | Done |
| S03-5 | Baby star: capacity % per star, tank = 400 × capacity; first star starts 5%, a new star 1%, cap 99%; grows from kills and meditation; ascension needs 99% + aura | Logic | selftest (7 checks) | Done |
| S03-6 | HUD: star capacities, carried constructs, "FULL - needs a vestige" on hotbar slots | UI | screenshot | Done |

## Verified
Self-test 75/75, smoke clean, three bots PASS with unchanged payouts, dungeon screenshot (star 1 at 9%, tank 36).

## Found along the way
A test-only bug: a dummy enemy queued for deletion by an earlier test was still clickable at the same spot for the
rest of its frame. Tests now let a frame pass before click tests. Worth remembering for the game too: anything
queue_freed stays in its groups until the frame ends.

## Not verified
The feel of click-to-attack and click-to-move with WASD mixed in; whether a 20-essence start is too tight; whether
placeholder drop rates make binding happen often enough to matter in a 20–30 minute sitting.
