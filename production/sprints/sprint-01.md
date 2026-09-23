# Sprint 01 — Foundations: hook pipeline + data definitions

> Roadmap Milestone 2, sprint 2a. Started 2026-09-23 on Brent's "let's get rolling". Written lightweight
> rather than via `/sprint-plan` (no epics or stories exist yet); the systems index rows are #1 and #2.
> Fun-gate note: Brent's reaction to v0.4.0 was "not half bad"; a formal playtest report is still owed.

## Goal
Every talent, item and summon in the future plugs into one damage pipeline instead of editing the player
script, and every tuning number lives in `game/data/` instead of a `const`. Nothing the player can feel
should change in this sprint — same numbers, same behaviour, new plumbing.

## Stories
| # | Story | Type | Evidence | Status |
|---|-------|------|----------|--------|
| S01-1 | `HitContext` + `TalentEffect` base: outgoing / incoming / kill / cast / reflux-cap / tick hooks | Logic | selftest | Done |
| S01-2 | Six wired talents become `game/scripts/talents/<id>.gd` effects loaded by id | Logic | selftest | Done |
| S01-3 | `GameData` autoload; player, reflux, arm, healer, arena, passage and town numbers → `data/balance.json` | Config | smoke + bots | Done |
| S01-4 | Enemy kinds → `data/enemies.json`; water bolt → `data/abilities.json`; scenery HP → balance | Config | smoke + bots | Done |
| S01-5 | Player, enemy, scenery, projectile, main read data; behaviour unchanged (bots' payouts identical) | Integration | bots PASS with same numbers | Done |
| S01-6 | Selftest: effects load for all six talents; Tenth Strike, Glass Hour, Debt of Pain, Grudge assert through the pipeline | Logic | selftest | Done |

## Out of scope
Hidden-flag rolling, new talents, inventory, hotbar, ethercosm screen (sprints 2b, 3a, 3b).

## Definition of done
Self-test, smoke check and all three bot scenarios green; bot payouts unchanged (3000 / 16500 / fee 600);
commit tagged `v0.5.0-foundations`. Tuning numbers in JSON only — a grep for `const .* := [0-9]` in
gameplay scripts finds nothing but structural constants (layer names, groups, colours).
