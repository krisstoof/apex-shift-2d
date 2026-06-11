# Apex Shift 2D v0.1.2 - Tester Instructions

Thanks for helping test `Apex Shift 2D v0.1.2`.

This is a 2D survival prototype built in Godot. The goal of this test is to verify that the main features of `v0.1.2` work correctly and that a tester can complete a basic session without crashes, blockers, or obvious regressions.

---

## How To Run The Game

1. Unpack the tester package.
2. Run:

```text
ApexShift2D.exe
```

3. The game should open to the start menu.
4. The start menu should display:

```text
Apex Shift 2D v0.1.2
```

If the game does not start, report it as a critical bug.

---

## What To Test

Use this checklist:

```text
docs/testing/v0.1.2-smoke-test.md
```

Main test areas:

- start menu,
- new game,
- expanded HUD,
- resource icons,
- gathering resources,
- inventory,
- crafting,
- eating meat,
- storage box,
- save/load,
- pause menu,
- game over,
- debug panel,
- minimap and map screen,
- living world.

---

## What Matters Most In v0.1.2

Please pay special attention to:

- whether the HUD shows correct values,
- whether HUD values match the inventory screen,
- whether gathering resources updates inventory,
- whether crafting changes resource amounts,
- whether eating meat updates player state and inventory,
- whether the storage box opens with `E`,
- whether items can be deposited and withdrawn from storage,
- whether inventory and storage still work after save/load,
- whether the left side of the debug panel shows only player data.

---

## What Not To Report As A New Bug

Before reporting an issue, check:

```text
KNOWN_ISSUES.md
```

Known prototype limitations include:

- placeholder icons,
- simple storage UI,
- no drag and drop,
- no item weight,
- no rarity system,
- prototype-level UI,
- possible issues with older saves.

Report these only if they cause a crash, data loss, or block testing.

---

## How To Report Bugs

Each bug report should include:

### Title

Short summary of what is broken.

Example:

```text
Storage box content disappears after loading save
```

### Repro Steps

Write exactly what you did.

Example:

```text
1. Start New Game.
2. Gather wood and stone.
3. Craft storage box with 5.
4. Open storage box with E.
5. Deposit wood.
6. Save game.
7. Return to menu.
8. Continue game.
9. Open storage box again.
```

### Expected Result

What should have happened.

### Actual Result

What actually happened.

### Extra Details

If possible, add:

- screenshot,
- log,
- save file,
- game version,
- operating system,
- whether it was a fresh save or an old save,
- whether the bug happens every time or only sometimes.

---

## Bug Priority Guide

### Critical

- game does not start,
- crash,
- cannot begin a game,
- save/load destroys data,
- player gets stuck with no way to continue.

### High

- inventory does not work,
- storage box does not work,
- save/load does not preserve inventory or storage,
- HUD shows wrong values,
- the core game loop is broken.

### Medium

- UI is confusing,
- values do not refresh sometimes,
- debug panel shows data in the wrong place,
- map or minimap shows stale data.

### Low

- typos,
- small layout problems,
- placeholder art,
- non-blocking visual issues.

---

## Helpful Files

- `README.md` - game overview and controls.
- `CHANGELOG.md` - what changed in v0.1.2.
- `KNOWN_ISSUES.md` - known limitations.
- `docs/testing/v0.1.2-smoke-test.md` - main smoke test checklist.
