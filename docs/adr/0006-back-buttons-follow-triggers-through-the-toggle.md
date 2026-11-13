---
status: superseded by ADR 0007 (the hold-only mode below is now built)
---

# Back buttons follow the triggers only through the trigger toggle

A back button has an action on each controller bar, so RT with L4 can do something else than L4.
Which bar a press is for has to be known in secure code, in combat. Forever's triggers don't act as
modifiers: they are plain keys bound to `GAMEPADLEFTMOD` and `GAMEPADRIGHTMOD`, and the game picks the
bar in its own Lua by `IsKeyDown`, which secure code can't read. The only way for us to see a held
trigger is to own the trigger key with an override binding, which hides it from the game, so the
game's bars then never switch by themselves. The trigger toggle already does exactly that and drives
the game's bars itself, so the back buttons read its state (held or on) on the press. With the toggle
off they act on Top only, as before, and a player who wants RT with L4 has to turn the toggle on.

## Considered options

- **Owning the triggers whenever a back button has an action off Top**: works with the toggle off,
  but it's the toggle's machinery with pressing-to-switch left out: our relays would have to drive the
  game's bars on every hold. Kept for later as a hold-only mode of the same header, if it's wanted.
- **Steam Input sending another key while a trigger is held**: no code of ours, but only on the Steam
  Deck, set up outside the game, and a fourth key per back button for the player to bind.
- **Bindings per modifier (`SHIFT-F13` and so on)**: never fire, since no modifier arrives with a
  trigger.
