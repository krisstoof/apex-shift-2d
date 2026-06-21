# Core Portability Rules

`scripts/core/` is reserved for portable gameplay logic and data structures.
Code in this layer should be reusable outside the full Godot scene runtime.

## Why this matters

Keeping `scripts/core/` free of scene-tree and rendering dependencies makes it easier to:

- unit test logic without booting the full game,
- reuse rules in adapters, tooling, or future platforms,
- keep Godot-specific code isolated in scene-facing modules,
- reduce accidental coupling between data rules and node lifecycle.

## Forbidden dependencies in `scripts/core/`

Core modules should not directly depend on:

- scene tree APIs such as `get_tree()`, `get_nodes_in_group()`, `get_node()`, `add_child()`, or `queue_free()`,
- rendering and UI types such as `Sprite2D`, `ImageTexture`, `Control`, or `CanvasItem`,
- scene instancing APIs such as `PackedScene`, `load("res://scenes/...")`, or `preload("res://scenes/...")`,
- node-specific spatial types such as `Node2D`, `Area2D`, `StaticBody2D`, or `CharacterBody2D` when the module is intended to remain pure data/logic,
- direct scene or texture path references when they imply runtime presentation dependencies.

## Where those dependencies belong

- scene tree access belongs in node scripts and runtime controllers,
- rendering belongs in rendering adapters and view layers,
- scene loading belongs in bootstrap, UI, or gameplay-facing orchestration code,
- node lifecycle logic belongs in resource nodes, creatures, world nodes, or other Godot-facing modules.

## Enforcement

The repository includes a static portability test that scans only `scripts/core/` and fails on forbidden patterns.
The test reports:

- file path,
- line number,
- forbidden token or pattern,
- the offending line snippet.

That test is intentionally simple and easy to extend when new forbidden dependencies are discovered.
