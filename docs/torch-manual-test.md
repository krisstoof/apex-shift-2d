# Torch Manual Test Checklist

Use this checklist to verify the torch loop after gameplay or UI changes.

## Setup

1. Run `res://scenes/main.tscn`.
   Expected: The player spawns on the test map and the HUD is visible.

2. Gather wood and fiber from nearby trees and bushes with `E`, or open the debug panel with `F3` and use `Add wood` plus `Add plant fiber`.
   Expected: The HUD inventory counts increase.

## Crafting

1. Press `8` to craft a torch.
   Expected: One wood and one fiber are removed.

2. Check the HUD and debug panel.
   Expected: The torch count increases by 1 and the `8/T` torch slot is available.

3. Try crafting without enough wood or fiber.
   Expected: No torch is added and a "Not enough resources" message appears.

## Activation

1. Press `T` while at least one torch is in inventory.
   Expected: Torch count decreases by 1, torch status changes to active, and the HUD shows the remaining time.

2. Press `T` again while the torch is active.
   Expected: The torch deactivates and the HUD/debug panel show it as inactive.

3. Press `T` with no torch in inventory and no active torch.
   Expected: No torch activates and a "No torch to activate" message appears.

## Duration

1. Activate a torch and watch the HUD timer.
   Expected: The remaining time counts down from the configured duration.

2. Wait until the timer reaches 0.
   Expected: The torch burns out, the light visual disappears, and torch status becomes inactive.

3. Add or craft another torch, then press `T`.
   Expected: A new torch activates with a fresh duration.

## Night Protection

1. Open the debug panel with `F3` and press `Next phase` until dusk or night.
   Expected: The debug panel shows a dusk/night phase and `night` is above 0.

2. Activate a torch and approach a Varnak.
   Expected: A nearby Varnak outside immediate attack range flees from the player or is less likely to chase.

3. Let the torch expire or press `T` to deactivate it.
   Expected: The torch protection stops and Varnaks resume normal behavior.

4. Compare the same situation near an active campfire.
   Expected: Campfire fear is stronger than torch protection.
