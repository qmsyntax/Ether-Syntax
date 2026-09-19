# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.2 (standard build, GDScript) |
| **Release Date** | 4.7.0: 2026-06-21 · 4.7.2 (maintenance): 2026-08-18 |
| **Project Pinned** | 2026-09-18 |
| **Last Docs Verified** | 2026-09-18 |
| **LLM Knowledge Cutoff** | Varies by model in use (May 2025 – mid 2026). Treat 4.7 as beyond or at the edge of every model's training data. |
| **Risk Level** | HIGH — 4.7 is post-cutoff; 4.4–4.6 are post-cutoff for the older model tiers |

## Knowledge Gap Warning

Depending on the model, training data covers Godot up to somewhere between ~4.3
and ~4.6. Version 4.7 (June 2026) is not reliably known to any of them, and
4.4–4.6 introduced significant changes older tiers do NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |
| 4.7 | Jun 2026 | HIGH | HDR output, AreaLight3D, Control offset transforms, input device ID renumbering, stricter typed-return overrides |

## Migration Notes — 4.6 → 4.7.2

The reference docs in this directory were first written against 4.6 (2026-02-12).
The project itself was started directly on 4.7.2, so there is no project code to
migrate — this note exists so agents know the 4.6-era docs were extended, not
that a port happened.

- Migration guide: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html
- Compatibility breaks per the guide (read directly 2026-09-18): keyboard/mouse
  device ID numbering, typed-return overrides needing an explicit `return`, packed
  array element writes no longer calling setters, BlendSpace `sync` → `sync_mode`,
  Jolt `WorldBoundaryShape3D.plane.d` sign and `SoftBody3D` defaults,
  `RichTextLabel.add_image()` signature, `LinearToSRGB` clamp, `CanvasItem` line
  antialiasing, clearcoat, `AudioStreamPlayer2D/3D.area_mask` default.
- Mentioned by third-party coverage but NOT confirmed in the guide as read: particle
  angular velocity corrections, shader preprocessor restrictions, Android OBB removal.
- 4.7.1 → 4.7.2: no known incompatibilities (57 bug fixes).
- Details per subsystem: `breaking-changes.md`, `deprecated-apis.md`,
  `current-best-practices.md`.

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.6→4.7 migration: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.7 release notes: https://godotengine.org/releases/4.7/
- 4.7.1 maintenance release: https://godotengine.org/article/maintenance-release-godot-4-7-1/
- 4.7.2 maintenance release: https://godotengine.org/article/maintenance-release-godot-4-7-2/
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
