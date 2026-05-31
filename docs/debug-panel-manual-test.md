# Debug Panel Manual Test Checklist

Use this checklist to verify the F3 debug panel after gameplay, UI, or balance changes.

## Toggle And Display

1. Run `res://scenes/main.tscn`.
   Expected: The game starts with the normal HUD visible and the debug panel hidden.

2. Press `F3`.
   Expected: The debug panel appears without pausing gameplay.

3. Press `F3` again.
   Expected: The debug panel hides and the normal HUD remains visible.

4. Open the debug panel again and watch the state text for a few seconds.
   Expected: Day, phase, player stats, inventory, torch, campfire, traps, Varnaks, and adaptation values update while the game runs.

## Resource And Item Buttons

1. Press `Add wood`.
   Expected: Wood increases in the HUD and debug panel.

2. Press `Add stone`.
   Expected: Stone increases in the HUD and debug panel.

3. Press `Add plant fiber`.
   Expected: Fiber increases in the HUD and debug panel.

4. Press `Add meat`.
   Expected: Meat increases in the HUD and debug panel.

5. Press `Add torch`.
   Expected: Torch count increases, and the `8/T` torch slot is available.

6. Press `Add spear`.
   Expected: Spear status changes to yes in the HUD and debug panel.

## World State Buttons

1. Press `Next phase`.
   Expected: The phase changes and the clock/night values update.

2. Press `Next day`.
   Expected: The day count increases and day-related debug values refresh.

3. Press `Increase adaptation`.
   Expected: Varnak adaptation values increase and the debug panel profile/pressure values update.

4. Press `Spawn aggressive animal`.
   Expected: A Varnak appears near the player and the Varnak count increases.

5. Press `Spawn neutral animal`.
   Expected: A lower-aggression test Varnak appears and the Varnak count increases.

## Player State Buttons

1. Press `Damage player`.
   Expected: Player health decreases in the HUD and debug panel.

2. Press `Heal player`.
   Expected: Player health increases, capped at max health.

3. Press `Reduce h/energy`.
   Expected: Hunger, stamina, and rest decrease in the debug panel and HUD where shown.

4. Press `Restore h/energy`.
   Expected: Hunger, stamina, and rest increase, capped at their max values.

## HUD Sync

1. Use any resource, world, or player debug button.
   Expected: The normal HUD updates on the next frame.

2. Use a torch-related debug action, then activate or deactivate the torch with `T`.
   Expected: HUD torch count/status and debug panel torch status stay consistent.

3. Spawn Varnaks and change adaptation.
   Expected: The debug panel Varnak count, state summary, generation, pressure, and profile values stay readable and up to date.
