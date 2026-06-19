# Scripts Layout

This directory is organized to separate portable gameplay logic from Godot-specific integration and rendering code.

## Main Areas

- `scripts/core/` contains portable gameplay logic that should stay as engine-agnostic as practical.
- `scripts/godot_runtime/` contains Godot-specific adapters, scene integration, node lifecycle handling, and runtime glue.
- `scripts/rendering/` contains rendering-specific code for world, terrain, minimap, and HUD presentation.

## Intent

- Keep new gameplay systems in `scripts/core/` when possible.
- Let `World.gd` and other scene scripts focus on orchestration and glue instead of accumulating new gameplay rules.
- Keep rendering concerns isolated from portable core logic.

This file documents the intended structure only. Existing behavior should remain unchanged.
