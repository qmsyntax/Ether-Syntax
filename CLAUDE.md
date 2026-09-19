# Passage (working title) — dungeon crawler in the "1% Lifesteal" universe

Exploratory, **unlicensed** game design + prototype. Process framework: Claude Code Game Studios
template (MIT, see `.claude/LICENSE-ccgs`), adapted. Owner / product lead / lore authority / playtester: Brent.

## Project rules (these override anything in the template)

1. **IP hygiene.** The setting belongs to Robert Blaise (publisher: Aethon Books). No licence exists.
   - Never store, paste or reproduce book text. No bulk downloads, no DRM stripping, no piracy sites.
   - Work only from paraphrased mechanics notes with chapter citations (`research/`), fan sources, and Brent's recollection.
   - Do not port canon characters into the game. Player characters, talents' wording, names and art are original.
   - Nothing is published, distributed or pitched, and nobody (author, publisher) is contacted, unless Brent explicitly asks.
2. **Provenance tags are mandatory** in design docs: `[C]`/`[CANON]` read directly, `[F]` fan source, `[B]` Brent's ruling, `[MODEL]` our invention, `[?]` unknown. Brent's rulings override fan sources. See `design/01-systems-bible-v0.md`.
3. **Say what was and wasn't tested.** A headless run proves scripts load; it does not prove a mechanic works or feels right. Anything that needs hands on the controls is reported as "untested — needs Brent". Never claim a feature works on the strength of it compiling.
4. **The first real gate is fun, not paperwork.** The core-loop questions in `design/03-core-mechanics-spec-v0.1.md` §8 are answered by Brent playing the build. Rights/outreach stay parked until then.
5. **Talents are data** (`game/data/talents.json`), many and varied — 1% Lifesteal is one entry, not the premise.

## Technology Stack

- **Engine**: Godot 4.7.2 (standard build, installed via winget — no `godot` alias on PATH; use `open-editor.cmd`, or the console exe under `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\`)
- **Language**: GDScript, statically typed
- **Godot project root**: `game/` (this is `res://`). The template's `src/` and `assets/` conventions map to `game/scripts/` and `game/data/` until `/adopt` decides otherwise.
- **Version Control**: Git, trunk-based on `main`, local only (no remote). See "Version Control" below.
- **Smoke check**: `--headless --path game --import`, then `--headless --path game --quit-after 400 -- --shot` must produce no `ERROR` / `SCRIPT ERROR` lines.
- **Rules self-test**: `--headless --path game res://tests/selftest.tscn` must end `0 failed` (exit code 0). It drives wound maths, natural healing, arm loss/regrowth, healer credit and rent directly. Add a check there whenever a rule changes. It is a stopgap until GUT is installed (`/test-setup`), and it proves arithmetic, not feel.
- **Style**: D2-style real-time isometric combat in low-poly 3D; BG3-style depth in the hub. Nodes are built in code so the project stays plain text. Position nodes *before* `add_child` (a physics body that exists at the origin for one step can carry the player off as a platform passenger).

## Project Structure

@.claude/docs/directory-structure.md

Project-specific additions: `research/` (sourced, paraphrased notes), `design/00–04` (concept, systems bible, open questions, mechanics spec, talent framework — written before the template was adopted, not yet in its GDD format), `game/` (Godot project), `shots/` (debug screenshots).

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Tasks follow: **Question -> Options -> Decision -> Draft -> Approval**

- Show a draft or summary and get approval **per changeset** (a story, a doc, a feature) before writing — not per individual file.
- Review mode is set in `production/review-mode.txt` (`full` | `lean` | `solo`).

## Version Control

Standing instruction from Brent (2026-09-19): **keep good version control** — commit as work lands, don't wait to be asked each time.

- **Commit each approved changeset** (a story, a doc, a fix) as its own commit, straight after it is approved and the smoke check passes. Never batch unrelated work into one commit.
- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`, with a scope where it helps (`feat(game):`, `docs(design):`, `docs(research):`, `chore(process):`). Reference the story/task ID or design doc in the body.
- **Never commit a broken build.** Game changes must pass the headless smoke check first; if something is knowingly incomplete, say so in the commit body.
- **Tags**: annotated tags at every playable build handed to Brent (`vX.Y.Z-<label>`) and at every phase gate passed (`gate/<stage>`).
- **Still ask first**: adding a remote, pushing anywhere, rewriting history (amend/rebase/reset of committed work), deleting branches or tags. This repo contains unlicensed third-party-setting work — any remote must be **private**.
- **Never commit**: book text, anything under `game/.godot/`, credentials.
- Line endings are governed by `.gitattributes` (bash hooks must stay LF).

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for the template's full protocol.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
