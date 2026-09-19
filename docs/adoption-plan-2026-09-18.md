# Adoption Plan

> **Generated**: 2026-09-18
> **Project phase**: Concept (per `production/stage.txt`)
> **Engine**: Godot 4.7.2, GDScript
> **Template version**: v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

**A note on ordering**: this project has no malformed existing GDDs/ADRs/stories to
repair — it has substantial pre-template design content (`design/00-04`) and a
working prototype (`game/`) that haven't been ported into template format yet.
So the natural order here is content-first (get the concept and systems into
`design/gdd/`), then infrastructure bootstrap (which itself depends on ADRs
existing), rather than infra-first. Two infra items below (control manifest,
architecture traceability) are folded into Step 3 rather than listed twice.

---

## Step 1: Fix Blocking Gaps

None found. No GDDs, ADRs, or stories exist yet in a state that would make a
template skill silently misfire.

---

## Step 2: Fix High-Priority Gaps

### 2a. Pin the 3D physics engine
`game/project.godot` has no `[physics]` section — the 3D physics engine (Jolt vs.
GodotPhysics) is unset. `technical-preferences.md` currently records this as an
open item rather than a real answer, which leaves architecture decisions about
physics with nothing definite to check against.

**Fix**: In the Godot editor — Project Settings → Physics → 3D → Physics Engine.
Jolt is the 4.6+ default and is recommended unless there's a reason to keep
GodotPhysics3D (e.g. a specific `HingeJoint3D.damp` dependency). Then update the
Physics line in `.claude/docs/technical-preferences.md` to state the actual choice.

**Time**: 5 min
- [ ] Physics engine set in `project.godot` and reflected in `technical-preferences.md`

### 2b. Port the game concept into `design/gdd/game-concept.md`
The concept currently exists only as `design/00-game-concept-draft.md`, in
pre-template format. Nothing reads that path.

**Fix**: Manually port its content into `design/gdd/game-concept.md`. This is a
port, not a re-brainstorm — do not run `/brainstorm` fresh, it would regenerate
a concept you and Brent already settled. If the target section structure is
unclear, run `/help` or check an existing template example before authoring, but
prefer keeping this as an edit/port task in-session.

**Time**: 1 session
- [ ] `design/gdd/game-concept.md` created from `design/00-game-concept-draft.md`

### 2c. Create `design/gdd/systems-index.md`
Required by `/gate-check`, `/create-stories`, and `/architecture-review`. Depends
on 2b (systems index typically derives from the concept doc).

**Fix**: Run `/map-systems` once 2b is done.

**Time**: 30 min – 1 session
- [ ] `design/gdd/systems-index.md` created

### 2d. Author system GDDs for the systems already built
The prototype (`game/`) already implements several systems that only exist today
as prose across `design/01-systems-bible-v0.md`, `03-core-mechanics-spec-v0.1.md`,
and `04-talent-design-framework.md` — not as `design/gdd/*.md` files with the 8
required sections. At minimum, based on what's in `game/scripts/`: the wound
model / combat resolution, the essence tank + reflux economy, the meditate /
healer economy, ascension, and the talent framework (40-entry JSON roster, 6
wired in).

**Fix**: For each system identified in 2c's systems index, run
`/design-system [system-slug]`, drawing on the corresponding `design/01/03/04`
content plus the `[C]/[F]/[B]/[MODEL]/[?]` provenance tags already in place
(CLAUDE.md Rule 2 — preserve these tags when porting, don't drop them).

**Time**: 1 session per system (multi-session total — 5+ systems)
- [ ] Combat / wound-model GDD
- [ ] Essence / reflux economy GDD
- [ ] Meditate + healer economy GDD
- [ ] Ascension GDD
- [ ] Talent framework GDD

### 2e. Create the control manifest
Covered by Step 3b below — listed here only so it's counted. No separate action.
- [ ] See Step 3b

---

## Step 3: Bootstrap Infrastructure

Run this after Step 2's GDDs exist and at least the first ADRs have been written
against them (ADRs aren't in scope of this plan yet — none exist — but Step 3a
is where they'd first get registered).

### 3a. Register requirements and build the traceability matrix
Run `/architecture-review` — bootstraps `docs/architecture/tr-registry.yaml`
(currently an empty skeleton) from the GDDs and ADRs that exist at the time, and
produces `docs/architecture/architecture-traceability.md`.
**Time**: 1 session
- [ ] `tr-registry.yaml` populated
- [ ] `architecture-traceability.md` created

### 3b. Create control manifest
Run `/create-control-manifest`.
**Time**: 30 min
- [ ] `docs/architecture/control-manifest.md` created

### 3c. Create sprint tracking file
Run `/sprint-plan update`.
**Time**: 5 min
- [ ] `production/sprint-status.yaml` created

### 3d. Confirm project stage
`production/stage.txt` currently reads `Concept` — plausible for a project with a
concept prototype but no approved GDDs yet, but it's a carried-over guess. Run
`/gate-check` once Step 2 is far enough along to test it.
**Time**: 5 min
- [ ] `stage.txt` reconfirmed via `/gate-check`

---

## Step 4: Medium-Priority Gaps

### 4a. Formalize the Godot project root as `game/`
`CLAUDE.md` already notes this project uses `game/` (not `src/`) as the Godot
project root, "until `/adopt` decides otherwise." Decision: **keep `game/`
permanently.** Godot requires its project root to be `res://`; moving the live
GDScript files into `src/` would break the Godot project for no benefit. `src/`
stays effectively unused for this project (it currently holds only `.gitkeep`
and `CLAUDE.md`).

**Fix**: No file moves needed — this step is just formally closing the open
question CLAUDE.md flagged. Optionally note in `directory-structure.md` or
`src/CLAUDE.md` that `src/` is intentionally unused here.
**Time**: 5 min
- [ ] Decision recorded (this plan is the record; optionally cross-reference from `src/CLAUDE.md`)

### 4b. Sprint tracking and traceability
Already covered by Step 3a/3c — no separate action.
- [ ] See Step 3a, 3c

---

## Step 5: Optional Improvements

### 5a. Carry open design questions into GDDs
`design/02-open-questions-for-brent.md` has unresolved questions Q14, 15, 17, 21,
26, 29–36. As each affected system's GDD is authored (Step 2d), carry the
relevant open questions into that GDD rather than leaving them stranded in the
old file.
**Time**: folded into Step 2d, no separate session
- [ ] Open questions distributed into their systems' GDDs as authored

### 5b. Point stale CLAUDE.md wording at the real content
`src/CLAUDE.md` and `design/CLAUDE.md` describe the generic template layout
(`src/`, `design/gdd/`) without acknowledging that current-phase content lives
in `game/` and `design/00-04`. Low-friction confusion risk for a future reader
or agent skimming those files in isolation.
**Time**: 15 min
- [ ] `src/CLAUDE.md` / `design/CLAUDE.md` cross-reference the real locations

---

## What to Expect from Existing Stories

No stories exist yet (`production/epics/` is empty), so there's nothing to
grandfather in. Once `/create-stories` starts producing them, they'll pick up
TR-ID and control-manifest checks automatically since Step 2/3 will already be
in place by then — no retrofit will be needed for stories written after this
plan is worked through.

---

## Re-run

Run `/adopt` again after completing Step 2 to verify the HIGH gaps are resolved.
The new run will reflect the current state of the project.
