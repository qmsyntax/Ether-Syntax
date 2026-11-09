# Session state - rewritten 2026-11-09 (at v0.57.0-untangle, cdac5a9)

The old handoff (2026-09-18) is in git history. This file is the checkpoint to read first after a break. The plan is
`production/finish-plan.md`. Brent's questions and play tests are in `production/brent-todo.md`.

<!-- STATUS -->
Epic: Finish plan
Feature: Phase 2 done; Phase 3 next
Task: Waiting on Brent's play (the fun gate) and rulings
<!-- /STATUS -->

## Where things stand
- **Phase 0 (safe to build on): done**, v0.56.0-groundwork (2026-11-08). Crash-safe saves (`UserFiles`, schema 2,
  displacement), the one-command suite (`bash tools/test/run_all.sh`), the pinned physics engine, the build stamp,
  the Windows .exe (`tools/release/export_windows.sh`), and the performance budget and probe.
- **Phase 1 (the fun gate): in progress.** Brent has been playing the S:\Passage build since 2026-11-08. No verdict yet.
- **Phase 2 (untangle): done**, v0.57.0-untangle (2026-11-09):
  - Player, main and enemy are each split by concern (`docs/architecture/player-split.md`, `main-split.md`,
    `enemy-split.md`).
  - Typed calls (`typed-calls.md`).
  - The data is checked against `game/data/schema.json` on every load; silent numeric fallbacks are gone
    (`data-schema.md`).
  - No gameplay script is over 1,018 lines. Three UI scripts are just over 1,500.
  - The suite has 24 tests and all pass, including the new `loadall`.
- **Phase 3 (systems), 4 (Region 1) and 5 (sound and look): not started.** Most of their streams wait on Brent: the
  combat rulings, design/10 section 16, the design/07 answers, a creature source and an audio source.

## Release routine
1. Look at the screenshots, merge with `--no-ff`, and run the full suite plus the perf probe.
2. Stamp (`tools/release/stamp_version.sh <tag> <sha>`), commit, tag, then push main and the tags.
3. Export, mirror to S:\Passage (`tools/release/mirror_passage.ps1`), relaunch.
4. Update brent-todo's build line, this file and the memory.
5. Don't export while Brent's game is running from `build/windows/`: the export writes over that exe.

## Known noise in the evidence
- bot_full money: $272 or $273 (rent is charged per real frame).
- `--shot-ui` prop scatter is not seeded.
- perf skills scene: +/-10%.
- Duels are deterministic only at `--fixed-fps 60`, which the suite now uses.

## Open items found by the work (not fixed, reported)
- `_on_reinforcements` clamps reinforcements to the arena square outside the passage.
- Passage rent is charged per frame delta.
- Dead enemy state: `_base_color`, `_burn_t`, `_spread_t`, `_tick_alight`.
- Status text shows some missing keys as 0 where gameplay uses another default (`docs/architecture/data-schema.md`
  table).
- The lone drummer stands still: a ruling for Brent, in the to-do.
- `.claude/docs/technical-preferences.md` says the renderer is D3D12; it is actually Vulkan.
