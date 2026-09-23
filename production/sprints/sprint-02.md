# Sprint 02 — Abilities as data, hotbar, meditation gathers

> Roadmap Milestone 2, sprint 2b. 2026-09-23. Systems index #20 (Abilities), #44 (Hotbar), #7 (Essence).

## Goal
Abilities stop being one hard-coded bolt. Each is data with a cost, reflux, stage and progress bar; progress is
bought by spending essence through it (Brent 2026-09-23), so a wide loadout is slower to finish. Four hotbar
slots are rebindable actions. Meditation gathers wisps and refills essence (Brent 2026-09-23).

## Stories
| # | Story | Type | Evidence | Status |
|---|-------|------|----------|--------|
| S02-1 | `abilities.json`: Water Bolt, Tsunami Strike (big melee blow that wounds you), Hydraulic Flex (dash); starting loadout | Config | selftest | Done |
| S02-2 | `Player.abilities` / `hotbar` / `cast_slot()`; kinds projectile, melee_burst, dash through the damage pipeline | Logic | selftest | Done |
| S02-3 | Progress = essence spent × use multiplier (×1 with a live enemy, ×0.25 with nothing); cap = stars + 1; stage adds +10% damage | Logic | selftest | Done |
| S02-4 | Stage-up **stubbed**: a full bar advances the stage until construct binding exists (canon needs a bound construct) | Logic | selftest | Done |
| S02-5 | Hotbar actions `ability_1..4` (Q, C, V, G) in the controls menu; HUD hotbar with key, name, stage, cost, progress; red when unaffordable or locked | UI | screenshot | Done |
| S02-6 | Meditation refills essence (`meditation.gather_per_s`) | Logic | selftest | Done |

## Verified
Self-test 58/58 (10 new: loadout, cost/reflux, both use multipliers, stage-up with carry-over, stage cap, stage
damage, Tsunami damage and self-wound, meditation gather), smoke clean, three bots PASS with unchanged payouts,
screenshot of the hotbar in the passage.

## Not verified
Hand feel of the dash and Tsunami Strike; whether 12 essence per stage point is a sensible pace; whether ×0.25
without enemies is punishing enough to stop "grind on empty rooms".

## Carried forward
Assigning abilities to slots needs a screen — the ethercosm screen (sprint 3b). The free 1/s satellite is still
in, as a placeholder, until inventory exists (sprint 3a).
