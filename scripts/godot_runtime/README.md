# Godot Runtime Adapters

This directory is intended for Godot-specific glue code.

## Purpose

- Handle scene tree integration.
- Handle node lifecycle methods and runtime orchestration.
- Bridge portable core logic to Godot scenes and nodes.
- Keep engine-specific concerns out of `scripts/core/`.

This directory documents the runtime adapter layer only. Existing behavior should remain unchanged.
