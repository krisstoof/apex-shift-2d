# Core Modules

This directory is intended for portable gameplay logic.

## Rules

- Code in `scripts/core/` should not depend on Godot `Node` lifecycle methods such as `_ready()`, `_process()`, `_physics_process()`, `_enter_tree()`, or `_exit_tree()`.
- Core modules should avoid direct dependencies on scene tree state, nodes, signals tied to specific scenes, or rendering-specific logic.
- Core code should be written so it can be tested separately from Godot scenes where possible.
- Godot-specific adapters, scene integration, node lifecycle handling, and runtime glue should live in `scripts/godot_runtime/`.
- Rendering-specific code should live in `scripts/rendering/`.
- New gameplay systems should be placed under `scripts/core/` instead of being added directly into `World.gd`.
- `World.gd` should gradually become orchestration/glue code, not the place where new gameplay logic accumulates.

## Intent

The goal is to make future gameplay systems easier to test, reuse, refactor, and eventually port outside of Godot-specific scene code.

This README documents the intended architecture only. Existing gameplay behavior should remain unchanged.
