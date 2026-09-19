# Session state — handoff written 2026-09-18

## Where things stand
- **Design (pre-template format, in `design/`)**: 00 concept draft, 01 systems bible (canon/fan/Brent-ruling tagged), 02 open questions (Q1–28 answered by Brent; Q14, 15, 17, 21, 26, 29–36 open), 03 core mechanics spec v0.1, 04 talent design framework.
- **Research (`research/`)**: paraphrased mechanics notes for RR ch 1–6 and Book 5 ch 203–225; secondary-source + rights research. No book text stored anywhere.
- **Prototype (`game/`, Godot 4.7.2, GDScript)**: walled arena, living scenery, wave spawner, three-layer wound model, essence tank + satellite, per-affinity reflux with lockout, meditate, paid healer between waves, hidden latent aura + ascension to 2-star, notebook HUD, 40-talent JSON roster with 6 wired in (1% Lifesteal, Tenth Strike, Grudge, Glass Hour, Debt of Pain, Furnace Gut).
- **Verified**: project imports and runs headless with no script errors; enemies spawn, chase and hit; spawn-time "player carried off on an enemy's head" bug found by position trace and fixed (build + place enemies before `add_child`; separate collision layers). Brent ran it and said it "looked fine".
- **NOT verified (needs Brent's hands)**: melee, overcharge, water bolt, reflux thresholds, meditate, healer pricing, ascension, talent select screen, death/restart, and five of the six talents in actual play. No balance pass has happened. Only Lifesteal's 2-star evolution is implemented.

## Template adoption (Claude Code Game Studios v1.0.0)
- Installed: `.claude/` (39 agents — Unity/Unreal ones removed —, 73 skills, 12 hooks, 11 rules, settings), `docs/`, `production/`, `src/`, `design/registry`. Hooks were read before install: no network, no file writes, no destructive commands.
- `production/review-mode.txt` = lean. `production/stage.txt` = Concept (a guess — let `/adopt` or `/gate-check` correct it).
- The template currently sees a "fresh project" because our artifacts are not where it looks.

## Next steps, in order
1. `/setup-engine` — **DONE 2026-09-18.** `.claude/docs/technical-preferences.md` filled (PC only, KB/M primary, partial gamepad, 60fps defaults, GUT chosen but not installed); `docs/engine-reference/godot/` re-pinned 4.6 → 4.7.2 with the 4.6→4.7 delta added to `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (sourced from the official migration guide + release page; snippets not run). All five godot-* agents already had Version Awareness. Grep of `game/` found no use of any API changed in 4.7. Open items: (a) 3D physics engine is not set in `game/project.godot` — pin Jolt or GodotPhysics explicitly; (b) three third-party-reported 4.7 breaks (particle angular velocity, shader preprocessor, Android OBB) not confirmed in the guide; (c) GUT not installed — `/test-setup`.
2. `/adopt` — **audit DONE 2026-09-18**: plan at `docs/adoption-plan-2026-09-18.md` (0 blocking, 5 high). Decision recorded there: Godot root stays `game/`. **Concept port IN PROGRESS**: `design/gdd/game-concept.md` is fully drafted from `design/00`, `design/03`, and web research saved to `research/audience-and-comparables.md`. Everything marked PROPOSED/DRAFT in it awaits Brent: the four pillars, aesthetics ranking, motivation profile, target player, MVP scope drift (build has outgrown v0 MVP), permadeath, session length. Brent found the abstract framework questions confusing — bring him concrete choices, not MDA jargon. Original step text: audit our existing docs against the template's formats and produce the migration plan (`docs/adoption-plan-*.md`). Expect: concept → `design/gdd/game-concept.md`, systems index, GDDs with the 8 required sections, and a decision on whether the Godot root stays `game/` or moves.
3. The arena build is, in template terms, a **concept prototype**: write its `REPORT.md` with a PROCEED / PIVOT / KILL verdict after Brent's hands-on playtest (`/playtest-report`).
4. `/sprint-plan` for sprint 1 once the adoption plan is agreed.

## Decisions waiting on Brent
- Baseline git commit (nothing is committed yet; repo is initialised on `main`).
- How strict the approval protocol should be (template default: ask before every file write; CLAUDE.md currently relaxes this to per-changeset).
- Review mode: `lean` runs four director agents at each phase gate (costly); `solo` is artifact checks only.
