# Object Pooling

## Goal

Reduce runtime spikes caused by frequent `instantiate()` and `queue_free()` calls.

## Initial scope

The first pooled objects are:

- `meat_drop`
- `bone_drop`

These are created during animal death and removed after being collected or consumed.

## Rules

- Do not pool everything.
- Only pool objects that are frequently created and destroyed.
- Hidden pooled objects must be invisible.
- Hidden pooled objects must have collision disabled.
- Hidden pooled objects must have processing disabled.
- Every pooled object must implement:
  - `reset_for_pool()`
  - `activate_from_pool(data: Dictionary)`
- Pools must have a max size.
- If the pool is full, the object can be freed normally.

## Manual validation

1. Start New Game.
2. Kill animals until meat or bone drops appear.
3. Collect the drops.
4. Open Debug Panel with `F3`.
5. Go to `Tools`.
6. Press `Test object pool`.
7. Confirm the pool debug text shows reused objects.
8. Confirm no hidden drops can be collected.
9. Confirm creatures do not consume hidden pooled meat.
10. Save and load the game.
11. Confirm no pooled inactive drops are saved as active resources.

## Expected debug result

The debug summary should show:

- created > 0
- returned > 0
- reused > 0 after the second acquire cycle
- inactive <= max size
- discarded only when max size is exceeded
