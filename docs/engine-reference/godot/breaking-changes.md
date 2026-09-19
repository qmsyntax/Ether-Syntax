# Godot — Breaking Changes

Last verified: 2026-09-18 (4.6 → 4.7 section added; older sections last verified 2026-02-12)

Changes between Godot versions, focused on post-LLM-cutoff changes (4.4+).

## 4.6 → 4.7 (Jun 2026 — POST-CUTOFF, HIGH RISK)

Source: official migration guide (read directly 2026-09-18).
4.7.1 and 4.7.2 are bug-fix releases with no known incompatibilities.

| Subsystem | Change | Details |
|-----------|--------|---------|
| Input | Mouse/keyboard device IDs changed | Device ID `0` is no longer reserved for mouse/keyboard — some joypads use `0` too. Compare against `InputEvent.DEVICE_ID_MOUSE` / `InputEvent.DEVICE_ID_KEYBOARD`, never `0`. |
| GDScript | Overriding a typed-return method requires an explicit `return` | An override inherits the base method's return type. Falling through without a `return` (previously tolerated) is now flagged. |
| GDScript | Packed array element writes no longer call the property setter | `arr[i] = x` on a `Packed*Array` property used to re-invoke the whole-property setter; it no longer does. Call the setter explicitly if it must react. |
| Animation | BlendSpace `sync` (bool) replaced by `sync_mode` (`SyncMode` enum) | `AnimationNodeBlendSpace1D`/`2D`. Existing blend spaces may transition differently — re-check each one. |
| Rendering | `LinearToSRGB` shader function no longer clamps to `[0.0, 1.0]` | Mobile/Forward+. Custom shaders relying on the implicit clamp need an explicit `clamp()`. |
| Rendering | `CanvasItem` line drawing lost its antialiasing feather | Lines from `draw_line`/`draw_polyline` render visibly thinner than in 4.6. |
| Rendering | Clearcoat is energy-conserving and picks up sky/reflection probes | Clearcoat materials carried over from 4.6 may look different. |
| Physics (Jolt) | `WorldBoundaryShape3D.plane.d` sign interpretation reversed | Jolt only; GodotPhysics3D unaffected. |
| Physics (Jolt) | `SoftBody3D` default mass 0 kg → 1 kg; `linear_stiffness` application adjusted | Jolt only. Re-tune soft bodies. |
| Physics (Jolt) | `Area3D` now reports overlaps with `SoftBody3D` | Previously silent. |
| Audio | `AudioStreamPlayer2D`/`3D` `area_mask` default changed `1` → `0` | Area-based bus/reverb routing is now opt-in. Single-source claim (migration guide only). |
| UI | `RichTextLabel.add_image()` / `update_image()` signature changed | `width`/`height` are `float` (were `int`); bool `width_in_percent`/`height_in_percent` replaced by `width_unit`/`height_unit` (`RichTextLabel.ImageUnit`). Positional callers break. |
| Project defaults | New projects default to `stretch_mode = canvas_items`, `stretch_aspect = expand` | Only projects created in the 4.7 editor. Existing `project.godot` files are untouched. |
| Platform | Minimum macOS raised 10.13 → 11 | Only matters for macOS builds. |

Omitted as minor (new optional parameters or editor-plugin/XR-only signature changes):
`ZIPPacker.start_file()`, `Image.save_exr()`, `RenderingServer.viewport_set_size()`,
`add_blend_point()` optional `name`, `Object.is_class()` taking `StringName`,
`OptimizedTranslation.generate()` returning `bool`, `AudioEffectSpectrumAnalyzer.tap_back_pos`
removed, `EditorSceneFormatImporter` / `EditorVCSInterface` / `OpenXRExtensionWrapper` changes.

**Unconfirmed**: third-party coverage also mentions particle angular-velocity corrections,
shader preprocessor restrictions and Android OBB removal as 4.7 compatibility breaks. These
were not found in the migration guide as read — verify against the guide before relying on either version.

## 4.5 → 4.6 (Jan 2026 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Physics | Jolt is now the DEFAULT 3D physics engine | New projects use Jolt automatically. Existing projects keep their setting. Some HingeJoint3D properties (like `damp`) only work with GodotPhysics. |
| Rendering | Glow processes BEFORE tonemapping | Was after tonemapping. Scenes with glow will look different. Adjust intensity/blend in WorldEnvironment. |
| Rendering | D3D12 default on Windows | Was Vulkan. For better driver compatibility. |
| Rendering | AgX tonemapper new controls | White point and contrast parameters added. |
| Core | Quaternion initializes to identity | Was zero. Unlikely to affect most code but technically breaking. |
| UI | Dual-focus system | Mouse/touch focus now separate from keyboard/gamepad focus. Visual feedback differs by input method. |
| Animation | IK system fully restored | CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK via SkeletonModifier3D nodes. |
| Editor | New "Modern" theme default | Grayscale replaces blue-tint. Restore: Editor Settings → Interface → Theme → Style: Classic |
| Editor | "Select Mode" keybind changed | New "Select Mode" (v key) prevents accidental transforms. Old mode renamed "Transform Mode" (q key). |
| 2D | TileMapLayer scene tile rotation | Scene tiles can now be rotated like atlas tiles. |
| Localization | CSV plural form support | No longer requires Gettext for plurals. Context columns added. |
| C# | Automatic string extraction | Translation strings auto-extracted from C# code. |
| Plugins | New EditorDock class | Specialized container for plugin docks with layout control. |

## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Variadic arguments added | Functions can accept `...` arbitrary params — new language feature |
| GDScript | `@abstract` decorator | Abstract classes and methods now enforceable |
| GDScript | Script backtracing | Detailed call stacks available even in Release builds |
| Rendering | Stencil buffer support | New capability for advanced visual effects |
| Rendering | SMAA 1x antialiasing | New post-processing AA option |
| Rendering | Shader Baker | Pre-compiles shaders — reportedly 20x faster startup on some demos |
| Rendering | Bent normal maps, specular occlusion | New material features |
| Accessibility | Screen reader support | Control nodes work with accessibility tools via AccessKit |
| Editor | Live translation preview | Test GUI layouts in different languages in-editor |
| Physics | 3D interpolation rearchitected | Moved from RenderingServer to SceneTree. API unchanged but internals differ. |
| Animation | BoneConstraint3D | New: AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D |
| Resources | `duplicate_deep()` added | New explicit method for deep duplication of nested resources |
| Navigation | Dedicated 2D navigation server | No longer a proxy to 3D navigation; smaller export for 2D games |
| UI | FoldableContainer node | New accordion-style container for collapsible UI sections |
| UI | Recursive Control behavior | Disable mouse/focus interactions across entire node hierarchies |
| Platform | visionOS export support | New platform target |
| Platform | SDL3 gamepad driver | Delegated gamepad handling to SDL library |
| Platform | Android 16KB page support | Required for Google Play targeting Android 15+ |

## 4.3 → 4.4 (Mid 2025 — NEAR CUTOFF, VERIFY)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.store_*` return `bool` | Was `void`. Methods: `store_8`, `store_16`, `store_32`, `store_64`, `store_buffer`, `store_csv_line`, `store_double`, `store_float`, `store_half`, `store_line`, `store_pascal_string`, `store_real`, `store_string`, `store_var` |
| Core | `OS.execute_with_pipe` | Added optional `blocking` parameter |
| Core | `RegEx.compile/create_from_string` | Added optional `show_error` parameter |
| Rendering | `RenderingDevice.draw_list_begin` | Many parameters removed; `breadcrumb` parameter added |
| Rendering | Shader texture types | Parameter/return types changed from `Texture2D` to `Texture` |
| Particles | `.restart()` method | Added optional `keep_seed` parameter (CPU/GPU 2D/3D) |
| GUI | `RichTextLabel.push_meta` | Added optional `tooltip` parameter |
| GUI | `GraphEdit.connect_node` | Added optional `keep_alive` parameter |

## 4.2 → 4.3 (In Training Data — LOW RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Animation | `Skeleton3D.add_bone` returns `int32` | Was `void` |
| Animation | `bone_pose_updated` signal | Replaced by `skeleton_updated` |
| TileMap | `TileMapLayer` replaces `TileMap` | One node per layer instead of multi-layer single node |
| Navigation | `NavigationRegion2D` | Removed `avoidance_layers`, `constrain_avoidance` properties |
| Editor | `EditorSceneFormatImporterFBX` | Renamed to `EditorSceneFormatImporterFBX2GLTF` |
| Animation | AnimationMixer base class | AnimationPlayer and AnimationTree now extend AnimationMixer |
