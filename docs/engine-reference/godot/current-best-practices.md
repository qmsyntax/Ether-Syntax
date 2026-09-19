# Godot — Current Best Practices

Last verified: 2026-09-18 | Engine: Godot 4.7.2 (4.7 sections added; 4.5/4.6 sections last verified 2026-02-12)

Practices that are **new or changed** since the model's training data (~4.3).
This supplements (not replaces) the agent's built-in knowledge.

4.7 sections are sourced from the official migration guide and the 4.7 release page.
Code snippets in them are illustrative and have **not** been run in this project —
check the class reference before relying on an exact signature.

## GDScript (4.7)

- **Typed-return overrides need an explicit `return`.** An override inherits the base
  method's return type; falling through is no longer tolerated.
  ```gdscript
  func get_attack_pattern() -> Array[Attack]:
      return []  # required even in trivial overrides
  ```
- **Packed array element writes no longer re-invoke the property setter.** If a setter on a
  `Packed*Array` property must react to `arr[i] = x`, call it explicitly.

## Input (4.7)

- **Never hardcode device `0` for mouse/keyboard.** Use `InputEvent.DEVICE_ID_MOUSE` /
  `InputEvent.DEVICE_ID_KEYBOARD`; joypads may now be device `0`.
- New project setting to ignore joypad input while the window is unfocused.
- Built-in `VirtualJoystick` node and gyro/accelerometer aiming (mobile — not a target here).

## Physics (4.7)

- Jolt only: `WorldBoundaryShape3D.plane.d` sign is reversed; `SoftBody3D` mass defaults to
  1 kg (was 0) and `linear_stiffness` is applied differently; `Area3D` now overlaps `SoftBody3D`.
- `CollisionShape2D` gained a one-way collision direction property.

## Rendering (4.7)

- **HDR output** on Windows, macOS, iOS, visionOS and Linux (Wayland) — opt-in.
- **`AreaLight3D`**: real-time rectangular area light; replaces emissive-plane + GI workarounds.
- Nearest-neighbor viewport scaling option for crisp low-res 3D output.
- Clearcoat is energy-conserving and respects sky/reflection probes — 4.6 materials may shift.
- `LinearToSRGB` no longer clamps to `[0,1]` (Mobile/Forward+) — add `clamp()` where needed.
- `CanvasItem` lines lost their antialiasing feather — debug/gizmo lines look thinner; widen if needed.

## Animation (4.7)

- BlendSpace `sync_mode` (enum) replaces boolean `sync`.
- `Tween.tween_await()` pauses a tween until a signal fires (per the release page; signature unverified):
  ```gdscript
  var tween := create_tween()
  tween.tween_await(dialogue_box.finished)
  ```

## UI (4.7)

- **`Control` offset-transform properties** animate translate/scale/rotate without disturbing
  container layout — prefer these over repositioning controls inside containers.
- `RichTextLabel` images accept font-relative units, e.g. `[img height=1em]`.
- `PopupMenu` search filtering for long lists.

## Editor Workflow (4.7)

- Inline real-time previews in the shader editor; dedicated MeshLibrary editor for GridMap;
  2D scene painter (default key `B`); Asset Store replaces the Asset Library.
- Non-exported enum variables show readable names in the Remote Inspector.

## Maintenance patches (4.7.1 / 4.7.2)

Bug-fix only, no known incompatibilities. Worth knowing:

- 4.7.2 fixed Windows input lag with high-polling-rate mice — don't add (or keep) a throttle workaround for it.
- 4.7.2 corrected `BaseButton` long-press handling; `DirAccess.create_temp()` accepts an empty prefix.
- 4.7.1 bumped mbedTLS to 3.6.7; 4.7.2 makes mbedTLS use the OS entropy source. No API impact.

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]:
      pass  # Subclasses MUST override
  ```

- **Script backtracing**: Detailed call stacks available even in Release builds

## Physics (4.6)

- **Jolt Physics is the default 3D engine** for new projects
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)

## Rendering (4.6)

- **D3D12 is the default backend on Windows** (was Vulkan) — for better driver compatibility
- **Glow now processes before tonemapping** with screen blending mode — existing glow setups may look different
- **SSR overhauled** — significant improvement in realism, stability, and performance
- **AgX tonemapper** — new white point and contrast controls

## Rendering (4.5)

- **Shader Baker**: Pre-compile shaders to eliminate startup hitching
- **SMAA 1x**: New AA option — sharper than FXAA, cheaper than TAA
- **Stencil buffer**: Available for advanced masking/portal effects
- **Bent normal maps**: Directional occlusion in normal map textures
- **Specular occlusion**: Ambient occlusion now affects reflections

## Accessibility (4.5+)

- **Screen reader support**: Control nodes integrate with accessibility tools via AccessKit
- **Live translation preview**: Test GUI layouts in different languages directly in-editor
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control disable**: Disable mouse/focus interactions for entire node hierarchies with a single property

## Animation (4.5+)

- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D

## Animation (4.6)

- **IK system fully restored**: Complete inverse kinematics reintroduced for 3D
  - Available modifiers: CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate()` behavior retained for backward compatibility
  - Use `duplicate_deep()` when you need per-instance copies of nested resources

## Navigation (4.5+)

- **Dedicated 2D navigation server**: No longer proxied through 3D NavigationServer
  - Reduces export binary size for 2D-only games

## UI (4.6)

- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs depending on input method
  - Consider this when designing custom focus behavior

## Editor Workflow (4.6)

- Flexible dock drag-and-drop with blue outline preview (including bottom panel)
- Most panels support floating windows (except Debugger)
- New keyboard shortcuts: Alt+O (Output), Alt+S (Shader)
- Export variable auto-generation: drag resource from FileSystem into script editor
- Live preview in Quick Open dialog when "Live Preview" enabled
- New "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)

## Tooling

- **ripgrep has no `gdscript` type**: `*.gd` is registered under `gap` (GAP programming language).
  `rg --type gdscript` is a hard error — the search never executes.
  Always use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool) to filter GDScript files.

## Platform (4.5+)

- **visionOS export**: First new platform since open-sourcing (windowed app mode)
- **SDL3 gamepad driver**: Better cross-platform gamepad support
- **Android**: Edge-to-edge display, camera feed access, 16KB page support (Android 15+)
- **Linux**: Wayland subwindow support for multi-window capability
