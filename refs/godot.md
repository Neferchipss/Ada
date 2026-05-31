# Reference — Godot (for Nefer's Godot 4.x games)

> Distilled from the CCGS godot / gdscript / shader specialists (2026-06-01). Apply this on any Godot project (indian-road-simulator, project-anomaly). Lean, actionable. Not the soul — a knowledge reference.

## Critical gotchas (these bite immediately)
- **ripgrep has NO `gdscript` type.** `*.gd` files are under the `gap` type. `--type gdscript` / `type: "gdscript"` is a HARD ERROR — search never runs. **Always use `glob: "*.gd"`.**
- **Verify engine APIs against the actual version, not training data.** Godot 4.6 post-cutoff: D3D12 default on Windows; glow processes before tonemapping (4.6); Shader Baker (4.5); SMAA 1x + stencil buffer (4.5); shader texture types `Texture2D`→`Texture` (4.4); variadic args (`...`), `@abstract`. If unsure an API exists in the project's version, check/ WebSearch — don't assert.

## GDScript
- Static typing EVERYWHERE: `var hp: float = 100.0`, `func hit(amount: float) -> void:`, typed arrays `Array[Enemy]`. Untyped disables optimizations.
- `class_name` per file; file name = class in snake_case. Section order: class_name → extends → const/enum → signals → @export → public vars → _private → @onready → virtuals → public methods → private → `_on_` callbacks.
- `@onready var x: Type = %UniqueName` (or typed `$path`) — never `get_node()` in `_process`.
- `@export` with hints/ranges for tunables; group with `@export_group`.
- `await` for async (timers/tweens/signals); never Godot-3 `yield`. Don't chain >3 awaits.
- Naming: PascalCase class, snake_case func/var, SCREAMING_SNAKE const, signals snake_case past-tense (`health_changed`).

## Architecture
- Composition over inheritance (max ~3 levels); attach behavior via child component nodes (`%HealthComponent`).
- Scenes self-contained + reusable; shallow tree; one root with one responsibility; `PackedScene` to instance.
- Signals UP (child→parent / system→listeners), method calls DOWN. Declare typed signals at top, connect in `_ready()` (code, not editor), use `CONNECT_ONE_SHOT` / check `is_connected()`. Never connect in `_process`.
- Autoloads sparingly — only EventBus, GameManager, SaveManager, AudioManager. No scene-specific refs in them. Never a god-class.
- Data-driven content = custom `Resource` subclasses saved as `.tres`, not dicts/hardcoded. `duplicate()` for per-instance. Use resource UIDs (rename-safe).
- State machines: enum+match for simple; node-based (enter/exit/process per state) for complex.

## Performance
- Minimize `_process`/`_physics_process`; `set_process(false)` when idle. `_physics_process` for movement, `_process` for visuals/UI.
- Object pooling for projectiles/particles/enemies. `Tween` not manual interpolation. `VisibleOnScreenNotifier` to cull. `MultiMeshInstance` for many identical meshes.
- `StringName` (`&"name"`) for hot string compares; Dictionary lookups over `Array.find()` in hot paths; typed arrays faster.
- GDScript→GDExtension (C++/Rust) threshold: a function running >~1000×/frame (heavy math, pathfinding, procgen). Keep game logic/UI/state in GDScript.

## Rendering / shaders
- Renderers: **Forward+** (desktop — clustered lights, SDFGI/SSR/SSAO/glow/volumetrics), **Mobile** (≤8 omni+8 spot, no volumetrics), **Compatibility** (web/WebGL2/old HW — no compute shaders; design web visuals around this).
- Shaders: `shader_type spatial|canvas_item|particles|fog|sky`. `uniform ... : source_color / hint_range / hint_normal`; `group_uniforms` to organize. Name `[type]_[category]_[name].gdshader`.
- GPU particles for 100+; CPU particles for <50 or Compatibility. Cull with `visibility_aabb`; minimize lifetime.
- Avoid: texture reads in loops, dynamic branching per-pixel (use `mix()`/`step()`), `highp` everywhere on mobile, overdraw from unsorted transparents (set `render_priority`), multi-sample blur (use two-pass). Screen/depth via `hint_screen_texture`/`hint_depth_texture`.
- Frame GPU budget ~16.6ms@60: geometry 4-6, lighting 2-3, shadows 2-3, VFX 1-2, post 1-2, UI <1.

## Anti-patterns to flag
Untyped code · `$NodePath` in `_process` · deep inheritance · signals for synchronous request/response · string compares vs enums/StringName · dicts for structured data · god-class autoloads · editor signal connections (invisible in code) · not `queue_free()`-ing (orphan leaks).
