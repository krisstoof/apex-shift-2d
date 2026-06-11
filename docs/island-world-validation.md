# Island World Validation

This checklist validates the island-shaped world layout, water edge balance, safe player starts, and spawn rules.

## What The Validator Checks

- Player start is on playable terrain.
- World edges are mostly deep ocean or shallow water.
- The center of the map keeps enough playable land.
- Resources, creatures, and buildings do not appear in blocked water zones.
- Pond landmarks do not dominate the map layout.

## How To Run It

1. Open the game and wait for the world to finish booting.
2. Open the Debug Panel.
3. Go to the `World` tab.
4. Click `Validate island world`.
5. Read the summary in the panel and inspect the detailed report if it fails.

## Expected Result

- The summary should report `PASS`.
- Any warning should be limited to a borderline layout balance issue, not a blocked spawn or invalid player start.
- If the report fails, fix the world data or terrain rules before treating the build as valid.

## Notes For Review

- The validator is diagnostic only. It does not rewrite the generator automatically.
- If the world fails consistently, treat the report as the source of truth before changing generation logic.
